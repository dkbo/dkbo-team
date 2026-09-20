load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"; dk-wave-open 1 >/dev/null
  wt() { git -C "$WORKTREE_PATH" -c user.name=t -c user.email=t@t "$@"; }
}
teardown() { teardown_project; }

@test "pack holds commits, stat and -U10 diff, including uncommitted and untracked work" {
  mkdir -p "$WORKTREE_PATH/src/api"; echo 'hello' > "$WORKTREE_PATH/src/api/login.ts"; wt add -A; wt commit -q -m 'api: login'
  echo 'dirty' >> "$WORKTREE_PATH/src/api/login.ts"; echo 'new' > "$WORKTREE_PATH/untracked.txt"
  run dk-review-pack; [ "$status" -eq 0 ]; [ "$output" = "$d/waves/1.diff" ]
  f="$d/waves/1.diff"; grep -q '^## commits' "$f"; grep -q 'api: login' "$f"; grep -q '^## stat' "$f"; grep -q '^## diff (-U10)' "$f"
  grep -q '^+hello' "$f"; grep -q '^+dirty' "$f"; grep -q '^+new' "$f"; grep -q 'untracked.txt' "$f"
  wt status --porcelain | grep -q '^?? untracked.txt'   # the employee's real index was not touched
  run dk-review-pack 1; [ "$status" -eq 0 ]   # explicit wave number
}
@test "no changes: file still written, warning on stderr" {
  run dk-review-pack; [ "$status" -eq 0 ]; [ -f "$d/waves/1.diff" ]; [[ "$output" == *"no changes"* ]]
}
@test "unknown wave or no open wave dies" {
  run dk-review-pack 7; [ "$status" -eq 1 ]; [[ "$output" == *"wave-open 7"* ]]
  sed -i 's/^DK_WAVE=.*/DK_WAVE=""/' "$d/.task.env"; run dk-review-pack; [ "$status" -eq 1 ]; [[ "$output" == *"usage"* ]]
}
@test "--task diffs the whole branch from DK_BASE; legacy task dies" {
  echo 'x' > "$WORKTREE_PATH/a.txt"; wt add -A; wt commit -q -m 'wave 0'
  run dk-review-pack --task; [ "$status" -eq 0 ]; [ "$output" = "$d/waves/task.diff" ]; grep -q 'wave 0' "$d/waves/task.diff"; grep -q '^+x' "$d/waves/task.diff"
  sed -i '/^DK_BASE=/d' "$d/.task.env"; run dk-review-pack --task; [ "$status" -eq 1 ]; [[ "$output" == *"DK_BASE"* ]]
}

# ── 多 repo（AC10）───────────────────────────────────────────────────────────
multirepo_open() {   # 重建成多 repo 的 fixture 並開波 1
  teardown_project; setup_project; setup_multirepo
  d=$(fixture_task login 使用者登入); fixture_brief "$d"
  . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/repos.sh"
  dk-wave-open 1 >/dev/null
}

@test "AC10: 每個有變更的 repo 各一段 ## repo <名>，files changed 是總和" {
  multirepo_open
  main_wt=$(dk_repo_field "$d" main wt); api_wt=$(dk_repo_field "$d" api wt)
  mkdir -p "$main_wt/src"; echo m > "$main_wt/src/m.ts"
  mkdir -p "$api_wt/src"; echo a > "$api_wt/src/a.ts"; echo b > "$api_wt/src/b.ts"
  run dk-review-pack; [ "$status" -eq 0 ]
  f="$d/waves/1.diff"
  grep -q '^# files changed: 3 (working tree included)$' "$f"
  grep -q '^## repo main$' "$f"; grep -q '^## repo api$' "$f"
  refute_grep '^## repo shared$' "$f"          # 沒動過的 repo 不出段
  [ "$(grep -c '^## commits$' "$f")" -eq 2 ]
  grep -q '^+m$' "$f"; grep -q '^+a$' "$f"; grep -q 'src/b.ts' "$f"
}

@test "AC10: 多 repo 全都沒變更時仍寫檔並警告" {
  multirepo_open
  run dk-review-pack; [ "$status" -eq 0 ]; [ -f "$d/waves/1.diff" ]; [[ "$output" == *"no changes"* ]]
  grep -q '^# files changed: 0 (working tree included)$' "$d/waves/1.diff"
}

@test "AC10: 單 repo 模式不印 repo 段（面向人的輸出不帶前綴）" {
  echo x > "$WORKTREE_PATH/a.txt"
  run dk-review-pack; [ "$status" -eq 0 ]
  refute_grep '^## repo ' "$d/waves/1.diff"
  grep -q '^## commits$' "$d/waves/1.diff"
}

@test "AC10: --task 也逐 repo 分段，base 取 .repos 記的實體化 sha" {
  multirepo_open
  api_wt=$(dk_repo_field "$d" api wt)
  mkdir -p "$api_wt/src"; echo a > "$api_wt/src/a.ts"
  git -C "$api_wt" -c user.name=t -c user.email=t@t add -A
  git -C "$api_wt" -c user.name=t -c user.email=t@t commit -q -m 'api: a'
  run dk-review-pack --task; [ "$status" -eq 0 ]; [ "$output" = "$d/waves/task.diff" ]
  grep -q '^## repo api$' "$d/waves/task.diff"; grep -q 'api: a' "$d/waves/task.diff"
  refute_grep '^## repo main$' "$d/waves/task.diff"
}
