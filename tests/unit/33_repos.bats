load ../helpers
setup() { setup_project; . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/repos.sh"; }
teardown() { teardown_project; }

# ── dk_repos_parse ────────────────────────────────────────────────────────────
@test "dk_repos_parse: 空字串是單 repo 模式，回一列 main" {
  DK_REPOS=""
  run dk_repos_parse; [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]; [ "${lines[0]}" = "main $PROJECT" ]
  run dk_repos_multi; [ "$status" -eq 1 ]
}
@test "dk_repos_parse: 三列，相對路徑相對 DK_PROJECT_ROOT 解析成絕對路徑" {
  setup_multirepo
  mkdir -p "$PROJECT/sub"
  DK_REPOS="app=. api=$REPO_API rel=sub"
  run dk_repos_parse; [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [ "${lines[0]}" = "app $PROJECT" ]
  [ "${lines[1]}" = "api $REPO_API" ]
  [ "${lines[2]}" = "rel $PROJECT/sub" ]
  run dk_repos_multi; [ "$status" -eq 0 ]
}
@test "dk_repos_parse: 缺 = 的項目路徑欄留空，由 dk_repos_check 點名" {
  DK_REPOS="app=. api"
  [ "$(dk_repos_parse | sed -n 2p)" = "api " ]
  run dk_repos_check; [ "$status" -eq 1 ]; [[ "$output" == *"「api」"* ]]; [[ "$output" == *"<名>=<路徑>"* ]]
}

# ── dk_repos_check（AC4：五種拒絕各自點名 repo）────────────────────────────────
@test "dk_repos_check: 單 repo 模式與乾淨的多 repo 都過" {
  DK_REPOS=""; run dk_repos_check; [ "$status" -eq 0 ]
  setup_multirepo
  DK_REPOS="main=. api=$REPO_API shared=$REPO_SHARED"
  run dk_repos_check; [ "$status" -eq 0 ]
}
@test "dk_repos_check: 名字不合法要點名" {
  setup_multirepo
  DK_REPOS="main=. Api=$REPO_API"
  run dk_repos_check; [ "$status" -eq 1 ]; [[ "$output" == *"「Api」"* ]]; [[ "$output" == *"名字"* ]]
}
@test "dk_repos_check: 名字重複要點名" {
  setup_multirepo
  DK_REPOS="main=. api=$REPO_API api=$REPO_SHARED"
  run dk_repos_check; [ "$status" -eq 1 ]; [[ "$output" == *"「api」"* ]]; [[ "$output" == *"重複"* ]]
}
@test "dk_repos_check: 第一個不是主 repo 要點名" {
  setup_multirepo
  DK_REPOS="api=$REPO_API main=."
  run dk_repos_check; [ "$status" -eq 1 ]; [[ "$output" == *"「api」"* ]]; [[ "$output" == *"主 repo"* ]]
}
@test "dk_repos_check: 不是 git 根要點名（含 repo 的子目錄）" {
  setup_multirepo
  mkdir -p "$REPO_API/src"
  DK_REPOS="main=. api=$REPO_API/src"
  run dk_repos_check; [ "$status" -eq 1 ]; [[ "$output" == *"「api」"* ]]; [[ "$output" == *"git"* ]]
  DK_REPOS="main=. gone=$PROJECT-nonexistent"
  run dk_repos_check; [ "$status" -eq 1 ]; [[ "$output" == *"「gone」"* ]]
}
@test "dk_repos_check: 工作樹不乾淨要點名" {
  setup_multirepo
  repo_dirty_tracked "$REPO_SHARED"
  DK_REPOS="main=. api=$REPO_API shared=$REPO_SHARED"
  run dk_repos_check; [ "$status" -eq 1 ]; [[ "$output" == *"「shared」"* ]]; [[ "$output" == *"乾淨"* ]]
  refute_grep -q '「api」' <<< "$output"   # 乾淨的 repo 不該被點名
}

@test "dk_repos_check --no-clean 跳過乾淨檢查，其餘四項照驗（dk-task-new 的早失敗）" {
  setup_multirepo; repo_dirty_tracked "$REPO_API"
  DK_REPOS="main=. api=$REPO_API shared=$REPO_SHARED"
  run dk_repos_check; [ "$status" -eq 1 ]; [[ "$output" == *"乾淨"* ]]
  run dk_repos_check --no-clean; [ "$status" -eq 0 ]
  DK_REPOS="main=. Api=$REPO_API"
  run dk_repos_check --no-clean; [ "$status" -eq 1 ]; [[ "$output" == *"「Api」"* ]]
}

@test "乾淨檢查只看已追蹤檔：未追蹤檔不算髒（.dkbo/ 不進版控的專案）" {
  # 領導 2026-09-20T09:41 ruling：員工的 worktree 只看得到 HEAD，未追蹤檔本來就不影響它；
  # 照 AC4 的字面把未追蹤也算髒，panova 那種 .dkbo/ 不進版控的專案每次 --run 都會被自己擋下。
  setup_multirepo                      # $PROJECT 的 .dkbo/ 自始至終是未追蹤的
  echo junk > "$REPO_API/untracked.txt"
  DK_REPOS="main=. api=$REPO_API shared=$REPO_SHARED"
  run dk_repos_check; [ "$status" -eq 0 ]
  repo_dirty_tracked "$REPO_API"       # 但已追蹤檔改了就是髒
  run dk_repos_check; [ "$status" -eq 1 ]; [[ "$output" == *"「api」"* ]]
}

@test "乾淨檢查對主 repo 排除 .dkbo/ 底下的路徑（Important 1 回歸：.dkbo/ 進版控的專案，如本倉）" {
  DK_REPOS=""
  git -C "$PROJECT" add .dkbo
  git -C "$PROJECT" -c user.name=t -c user.email=t@t commit -q -m "track .dkbo"
  echo more >> "$DK_ROOT/settings.env"   # .dkbo/ 底下已追蹤且已修改，不該算髒
  run dk_repos_check; [ "$status" -eq 0 ]
  echo v2 > "$PROJECT/tracked.txt"; git -C "$PROJECT" add tracked.txt
  git -C "$PROJECT" -c user.name=t -c user.email=t@t commit -q -m tracked
  echo v3 > "$PROJECT/tracked.txt"       # .dkbo/ 之外的已追蹤檔仍要點名
  run dk_repos_check; [ "$status" -eq 1 ]; [[ "$output" == *"「main」"* ]]; [[ "$output" == *"乾淨"* ]]
}

# ── .repos 讀寫 ───────────────────────────────────────────────────────────────
@test "dk_repos_write: 單 repo 一列，名字 main，worktree 是 <root>/<short>" {
  d=$(fixture_task login 使用者登入); rm -f "$d/.repos"
  DK_REPOS=""
  dk_repos_write "$d" login "$PROJECT/.worktrees"
  [ "$(wc -l < "$d/.repos")" -eq 1 ]
  [ "$(dk_repos_names "$d")" = main ]
  [ "$(dk_repo_field "$d" main root)" = "$PROJECT" ]
  [ "$(dk_repo_field "$d" main wt)" = "$PROJECT/.worktrees/login" ]
  [ "$(dk_repo_field "$d" main base)" = "$(git -C "$PROJECT" rev-parse HEAD)" ]
}
@test "dk_repos_write: 多 repo 逐列，worktree 是 <root>/<short>/<名>，主 repo 在第一列" {
  setup_multirepo
  d=$(fixture_task login 使用者登入); rm -f "$d/.repos"
  DK_REPOS="main=. api=$REPO_API shared=$REPO_SHARED"
  dk_repos_write "$d" login "$PROJECT/.worktrees"
  [ "$(dk_repos_rows "$d" | wc -l)" -eq 3 ]
  [ "$(dk_repos_names "$d" | tr '\n' ' ')" = "main api shared " ]
  [ "$(dk_repo_field "$d" api root)" = "$REPO_API" ]
  [ "$(dk_repo_field "$d" api wt)" = "$PROJECT/.worktrees/login/api" ]
  [ "$(dk_repo_field "$d" api base)" = "$(git -C "$REPO_API" rev-parse HEAD)" ]
  [ -z "$(dk_repo_field "$d" nosuch wt)" ]
  refute_grep -q 'worktrees/login/api' <<< "$(dk_repo_field "$d" main wt)"
}
@test "dk_repos_write 不切 worktree，只算路徑" {
  setup_multirepo
  d=$(fixture_task login 使用者登入); rm -rf "$PROJECT/.worktrees"; rm -f "$d/.repos"
  DK_REPOS="main=. api=$REPO_API"
  dk_repos_write "$d" plan2 "$PROJECT/.worktrees"
  [ ! -d "$PROJECT/.worktrees/plan2" ]
  refute_grep -q 'dk/plan2' <<< "$(git -C "$REPO_API" branch --list)"
}
@test "dk_repos_rows 跳過空行；沒有 .repos 時回空且非零" {
  d=$(fixture_task login 使用者登入)
  printf '\n\n' >> "$d/.repos"
  [ "$(dk_repos_rows "$d" | wc -l)" -eq 1 ]
  rm -f "$d/.repos"
  run dk_repos_rows "$d"; [ "$status" -ne 0 ]; [ -z "$output" ]
}

# ── glob 前綴（共用契約：<名>:<glob>）────────────────────────────────────────
@test "dk_glob_split: 有前綴切兩欄，沒前綴第一欄留空" {
  [ "$(dk_glob_split 'api:src/**')" = "$(printf 'api\tsrc/**')" ]
  [ "$(dk_glob_split 'src/**')" = "$(printf '\tsrc/**')" ]
  # 路徑裡的冒號不是前綴：前綴限 [a-z][a-z0-9_]{0,15}
  [ "$(dk_glob_split 'src/a:b.ts')" = "$(printf '\tsrc/a:b.ts')" ]
  [ "$(dk_glob_split 'API:src/**')" = "$(printf '\tAPI:src/**')" ]
}
@test "dk_glob_check: 多 repo 缺前綴 FAIL、未知名字 FAIL、正確的過" {
  setup_multirepo
  d=$(fixture_task login 使用者登入)
  DK_REPOS="main=. api=$REPO_API shared=$REPO_SHARED"
  run dk_glob_check "$d" 'api:src/**'; [ "$status" -eq 0 ]; [ -z "$output" ]
  run dk_glob_check "$d" 'src/**'; [ "$status" -ne 0 ]; [[ "$output" == *"前綴"* ]]
  run dk_glob_check "$d" 'nope:src/**'; [ "$status" -ne 0 ]; [[ "$output" == *"nope"* ]]; [[ "$output" == *"DK_REPOS"* ]]
}
@test "dk_glob_check: 單 repo 帶前綴 FAIL" {
  d=$(fixture_task login 使用者登入)
  DK_REPOS=""
  run dk_glob_check "$d" 'src/**'; [ "$status" -eq 0 ]
  run dk_glob_check "$d" 'main:src/**'; [ "$status" -ne 0 ]; [[ "$output" == *"單 repo"* ]]
}
@test "dk_glob_check: 計畫階段還沒有 .repos，名字改查 DK_REPOS" {
  setup_multirepo
  d=$(fixture_task login 使用者登入); rm -f "$d/.repos"
  DK_REPOS="main=. api=$REPO_API shared=$REPO_SHARED"
  run dk_glob_check "$d" 'shared:lib/**'; [ "$status" -eq 0 ]
  run dk_glob_check "$d" 'nope:lib/**'; [ "$status" -ne 0 ]
}

# ── setup 鉤子與 per-repo base ─────────────────────────────────────────────────
@test "dk_repo_setup_cmd: 主 repo 讀 DK_SETUP_CMD，其餘讀 DK_SETUP_CMD_<名>，沒設回空" {
  setup_multirepo
  printf 'DK_SETUP_CMD="pnpm install --frozen-lockfile --prefer-offline"\nDK_SETUP_CMD_api="make deps"\n' >> "$DK_ROOT/settings.env"
  dk_settings
  [ "$(dk_repo_setup_cmd main)" = "pnpm install --frozen-lockfile --prefer-offline" ]
  [ "$(dk_repo_setup_cmd api)" = "make deps" ]
  [ -z "$(dk_repo_setup_cmd shared)" ]
  [ -z "$(dk_repo_setup_cmd nosuch)" ]
}
@test "dk_wave_base 第三參數讀 per-repo 那一行，沒帶時行為不變" {
  d=$(fixture_task login 使用者登入)
  cat >> "$d/process.md" <<P
2026-09-20T10:00 wave-open 1 base aaaa111 members backend
2026-09-20T10:00 wave-open 1 repo main base aaaa111
2026-09-20T10:00 wave-open 1 repo api base bbbb222
P
  [ "$(dk_wave_base "$d" 1)" = aaaa111 ]
  [ "$(dk_wave_base "$d" 1 api)" = bbbb222 ]
  [ "$(dk_wave_base "$d" 1 main)" = aaaa111 ]
  [ -z "$(dk_wave_base "$d" 1 nosuch)" ]
  [ -z "$(dk_wave_base "$d" 1 'x/../y')" ]    # 非法名字不得拼進 sed
}

# ── /dkbo-init 問這兩把鑰匙（AC20 的文件那一半）──────────────────────────────
@test "init skill 問 DK_REPOS 與每個 repo 的 DK_SETUP_CMD，pnpm 給預填寫法" {
  f="$DK_ROOT/skills/init/SKILL.md"
  grep -q 'DK_REPOS' "$f"
  grep -q 'DK_SETUP_CMD' "$f"
  grep -q 'DK_TEST_CMD_' "$f"
  grep -q 'pnpm install --frozen-lockfile --prefer-offline' "$f"
}
