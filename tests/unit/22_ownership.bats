load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"; dk-wave-open 1 >/dev/null
  wt() { git -C "$WORKTREE_PATH" -c user.name=t -c user.email=t@t "$@"; }
  . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/repos.sh"; . "$DK_ROOT/lib/ownership.sh"
}
teardown() { teardown_project; }

@test "dk_wave_base reads the sha dk-wave-open recorded; empty for an unknown or non-numeric wave" {
  base=$(dk_wave_base "$d" 1); [ -n "$base" ]
  git -C "$WORKTREE_PATH" rev-parse HEAD | grep -q "^$base"
  [ -z "$(dk_wave_base "$d" 7)" ]
  [ -z "$(dk_wave_base "$d" 'x; echo boom')" ]
}

@test "dk_wave_base takes the last line when a wave was recorded twice" {
  echo "2026-09-10T10:00 wave-open 1 base deadbee members backend" >> "$d/process.md"
  [ "$(dk_wave_base "$d" 1)" = deadbee ]
}

# ── dk_changed_files WORKTREE BASE：0.9.2 原樣（波 2 之前 dk-wave-close 還在用它）────
@test "dk_changed_files lists committed, dirty and untracked work since the base" {
  mkdir -p "$WORKTREE_PATH/src/api"
  echo hello > "$WORKTREE_PATH/src/api/login.ts"; wt add -A; wt commit -q -m 'api: login'
  echo dirty >> "$WORKTREE_PATH/src/api/login.ts"
  echo new > "$WORKTREE_PATH/untracked.txt"
  run dk_changed_files "$WORKTREE_PATH" "$(dk_wave_base "$d" 1)"
  [ "$status" -eq 0 ]
  [[ "$output" == *"src/api/login.ts"* ]]; [[ "$output" == *"untracked.txt"* ]]
  wt status --porcelain | grep -q '^?? untracked.txt'   # the employee's real index was not touched
}

@test "dk_changed_files skips ignored files and leaves non-ASCII paths unescaped" {
  printf 'ignored.txt\n' > "$WORKTREE_PATH/.gitignore"
  echo junk > "$WORKTREE_PATH/ignored.txt"
  echo z > "$WORKTREE_PATH/文件.ts"
  run dk_changed_files "$WORKTREE_PATH" "$(dk_wave_base "$d" 1)"
  [ "$status" -eq 0 ]
  [[ "$output" == *".gitignore"* ]]; [[ "$output" == *"文件.ts"* ]]; [[ "$output" != *"ignored.txt"* ]]
}

@test "dk_changed_files reports nothing when the worktree is untouched" {
  run dk_changed_files "$WORKTREE_PATH" "$(dk_wave_base "$d" 1)"
  [ "$status" -eq 0 ]; [ -z "$output" ]
}

# ── dk_changed_repo_files TASK_DIR N：長出 repo 維度（領導 09:41 ruling 的新名字）──
@test "dk_changed_repo_files 單 repo 模式不加前綴，路徑與 0.9.2 相同" {
  mkdir -p "$WORKTREE_PATH/src/api"; echo hello > "$WORKTREE_PATH/src/api/login.ts"
  run dk_changed_repo_files "$d" 1
  [ "$status" -eq 0 ]; [ "$output" = "src/api/login.ts" ]
}

@test "dk_changed_repo_files 空的波回空、不回非零" {
  run dk_changed_repo_files "$d" 1; [ "$status" -eq 0 ]; [ -z "$output" ]
}

@test "dk_changed_repo_files 多 repo 逐 repo 用各自的 base，輸出帶 <名>: 前綴" {
  teardown_project; setup_project; setup_multirepo
  d=$(fixture_task login 使用者登入); fixture_brief "$d"
  . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/repos.sh"; . "$DK_ROOT/lib/ownership.sh"
  dk_settings
  local api_wt shared_wt main_wt
  main_wt=$(dk_repo_field "$d" main wt)   # 多 repo 的主 repo worktree 是 .worktrees/<short>/main
  api_wt=$(dk_repo_field "$d" api wt); shared_wt=$(dk_repo_field "$d" shared wt)
  # 每 repo 一行 base（dk-wave-open 在多 repo 模式下記的形狀）
  { echo "2026-09-20T10:00 wave-open 1 repo main base $(dk_repo_field "$d" main base)"
    echo "2026-09-20T10:00 wave-open 1 repo api base $(dk_repo_field "$d" api base)"
    echo "2026-09-20T10:00 wave-open 1 repo shared base $(dk_repo_field "$d" shared base)"; } >> "$d/process.md"
  mkdir -p "$main_wt/src"; echo m > "$main_wt/src/m.ts"
  mkdir -p "$api_wt/src"; echo a > "$api_wt/src/a.ts"
  run dk_changed_repo_files "$d" 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"main:src/m.ts"* ]]; [[ "$output" == *"api:src/a.ts"* ]]
  refute_grep -q 'shared:' <<< "$output"        # 沒動過的 repo 不出現
  [ -z "$(ls -A "$shared_wt/src" 2>/dev/null)" ] || false
}

# ── dk_owned：前綴只跟同一個 repo 的 glob 比 ──────────────────────────────────
@test "dk_owned 單 repo 模式行為不變" {
  b="$d/brief.md"
  run dk_owned "$b" backend 'src/api/login.ts'; [ "$status" -eq 0 ]
  run dk_owned "$b" backend 'src/web/x.ts'; [ "$status" -eq 1 ]
  run dk_owned "$b" nobody 'src/api/login.ts'; [ "$status" -eq 1 ]
}

@test "dk_owned 前綴相同才算擁有，跨 repo 的同名路徑不算" {
  b="$d/brief.md"
  sed -i 's#^| backend | src/api/\*\* | src/web/\*\* |$#| backend | api:src/** , shared:lib/** | main:src/web/** |#' "$b"
  run dk_owned "$b" backend 'api:src/login.ts'; [ "$status" -eq 0 ]
  run dk_owned "$b" backend 'shared:lib/t.ts'; [ "$status" -eq 0 ]
  run dk_owned "$b" backend 'main:src/login.ts'; [ "$status" -eq 1 ]   # 同一個 glob、不同 repo
  run dk_owned "$b" backend 'src/login.ts'; [ "$status" -eq 1 ]        # 沒前綴的路徑不配帶前綴的 glob
  run dk_owned "$b" backend 'api:db/x.sql'; [ "$status" -eq 1 ]
}

# ── dk_owned：只讀「## 檔案所有權」段，欄內的 \| 不當分隔（rest AC6）─────────────
@test "rest AC6: 可改欄含 \\| 時兩個 glob 都認得，\\| 還原成字面 |" {
  b="$d/brief.md"
  sed -i 's#^| backend | src/api/\*\* | src/web/\*\* |$#| backend | src/a\\|b/**, src/c/** | src/web/** |#' "$b"
  grep -qF '| backend | src/a\|b/**, src/c/** |' "$b"
  run dk_owned "$b" backend 'src/c/x'; [ "$status" -eq 0 ]
  run dk_owned "$b" backend 'src/a|b/y'; [ "$status" -eq 0 ]
  run dk_owned "$b" backend 'src/a/y'; [ "$status" -eq 1 ]
}

@test "rest AC6: 所有權段之前的表格第一格等於成員名也不算（誘餌）" {
  b="$d/brief.md"
  sed -i 's#^登入 API 與表單。$#&\n\n| 成員 | 備註 |\n|---|---|\n| backend | bait/** |#' "$b"
  grep -qx '| backend | bait/\*\* |' "$b"
  run dk_owned "$b" backend 'bait/x'; [ "$status" -eq 1 ]
  run dk_owned "$b" backend 'src/api/login.ts'; [ "$status" -eq 0 ]
}
