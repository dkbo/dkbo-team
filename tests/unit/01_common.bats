load ../helpers
setup() { setup_project; . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/frontmatter.sh"; }
teardown() { teardown_project; }

@test "dk_slug makes herdr-safe names" {
  [ "$(dk_slug 'Login/Page Cart')" = "login-page-cart" ]
  [ "$(dk_slug '123abc')" = "abc" ]
  [ "$(dk_slug "$(printf 'a%.0s' {1..40})")" = "$(printf 'a%.0s' {1..32})" ]
}

@test "dk_ver_ge compares versions numerically, without sort -V" {
  dk_ver_ge 0.10.0 0.9.0        # the trap: lexically "0.10.0" < "0.9.0"
  ! dk_ver_ge 0.9.0 0.10.0
  dk_ver_ge 0.9.0 0.9.0
  dk_ver_ge 1.0 0.9.9
  ! dk_ver_ge 0.8.9 0.9.0
  dk_ver_ge 0.9 0.9.0           # a missing component counts as 0
  ! dk_ver_ge 0.9 0.9.1
  dk_ver_ge 0.9.10 0.9.9
  dk_ver_ge 1.2.0-rc1 1.2.0     # a suffix is ignored, not treated as older
  dk_ver_ge 0.09.0 0.9.0        # a leading zero is decimal, not octal
}
@test "dk_require_herdr passes in silence on the verified herdr series" {
  run dk_require_herdr; [ "$status" -eq 0 ]; [ -z "$output" ]
}
@test "dk_require_herdr still dies outside a herdr pane" {
  HERDR_ENV=0 run dk_require_herdr; [ "$status" -eq 1 ]; [[ "$output" == *HERDR_ENV* ]]
}
@test "dk_require_herdr dies when herdr's version cannot be read" {
  HERDR_STUB_VERSION= run dk_require_herdr; [ "$status" -eq 1 ]; [[ "$output" == *"herdr --version"* ]]
  HERDR_STUB_VERSION=garbage run dk_require_herdr; [ "$status" -eq 1 ]; [[ "$output" == *"herdr --version"* ]]
}
@test "dk_require_herdr dies below the floor, passes at exactly the floor" {
  HERDR_STUB_VERSION=0.8.9 run dk_require_herdr
  [ "$status" -eq 1 ]; [[ "$output" == *"older than"* ]]; [[ "$output" == *0.8.9* ]]
  HERDR_STUB_VERSION="$DK_HERDR_MIN" run dk_require_herdr; [ "$status" -eq 0 ]
  HERDR_STUB_VERSION=0.10.0 run dk_require_herdr; [ "$status" -eq 0 ]   # 0.10 > 0.9 numerically, not lexically
}
@test "dk_require_herdr warns once when herdr is newer than the verified series" {
  HERDR_STUB_VERSION=1.2.0 run dk_require_herdr
  [ "$status" -eq 0 ]; [[ "$output" == *"newer than"* ]]; [[ "$output" == *herdr-real.sh* ]]
  export HERDR_STUB_VERSION=1.2.0
  dk_require_herdr 2>/dev/null            # marks this process tree as warned
  run dk_require_herdr; [ "$status" -eq 0 ]; [ -z "$output" ]
}

@test "dk_task_dir dies when unbound" {
  run dk_task_dir
  [ "$status" -eq 1 ]; [[ "$output" == *"no task bound"* ]]
}

@test "dk_process and dk_task_env fail cleanly when unbound" {
  run dk_process "x"; [ "$status" -ne 0 ]; [[ "$output" == *"no task bound"* ]]; [ ! -e /process.md ]
  run dk_task_env;   [ "$status" -ne 0 ]; [[ "$output" == *"no task bound"* ]]
}

@test "dk_task_dir resolves .sessions binding and env" {
  d=$(fixture_task login 使用者登入)
  [ "$(dk_task_dir)" = "$d" ]
  dk_task_env
  [ "$DK_SHORT" = login ]; [ "$(dk_leader_name)" = leader-login ]
  [ "$(dk_agent_name frontend cart)" = login-frontend-cart ]
  [ "$(dk_state_name frontend cart)" = frontend-cart ]
  [ "$(dk_agent_name qa)" = login-qa ]
}

@test "dk_process appends timestamped line" {
  d=$(fixture_task login x); dk_process "wave1 start"
  grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2} wave1 start$' "$d/process.md"
}

@test "dk_slug never lets a newline into a file name" {
  [ "$(dk_slug $'sync docs\nline two')" = "sync-docs-line-two" ]
}

@test "index add and set" {
  dk_index_add 2026-09-10 使用者登入 task planning —
  grep -q '| 2026-09-10 | 使用者登入 | task | planning | — |' "$DK_ROOT/tasks/INDEX.md"
  dk_index_set 使用者登入 done "merged abc123"
  grep -q '| 使用者登入 | task | done | merged abc123 |' "$DK_ROOT/tasks/INDEX.md"
}

@test "dk_index_set 命中時回 0" {
  dk_index_add 2026-09-12 使用者登入 task planning —
  run dk_index_set 使用者登入 done "merged abc123"
  [ "$status" -eq 0 ]
  grep -q '| 使用者登入 | task | done | merged abc123 |' "$DK_ROOT/tasks/INDEX.md"
}

# 用 $(cat) 比對會吃掉結尾換行，嚴格說要 cmp 才名副其實。不改是因為 dk_index_add 一定寫
# 換行，"結尾換行被改掉"在今天不可達；哪天有別的寫入路徑進來，這裡要換成 cmp。
@test "dk_index_set 沒命中時回非零，且 INDEX 一個字都不動" {
  dk_index_add 2026-09-12 使用者登入 task planning —
  before=$(cat "$DK_ROOT/tasks/INDEX.md")
  run dk_index_set 使用者登出 done "merged abc123"
  [ "$status" -eq 1 ]
  [ "$(cat "$DK_ROOT/tasks/INDEX.md")" = "$before" ]
}

@test "index add flattens newlines so a row never spans lines" {
  dk_index_add 2026-09-10 $'第一行\n第二行' chore working —
  grep -q '^| 2026-09-10 | 第一行 第二行 | chore | working | — |$' "$DK_ROOT/tasks/INDEX.md"
  ! grep -q '^第二行' "$DK_ROOT/tasks/INDEX.md"
}

# tripwire：printf 與 awk -v 都不把 & 當元字元，所以這條在今天不可能失敗 —— 它守的是
# 「有人把 dk_render 改回 sed -i」那一天，& 會突然變成「整個比對到的字串」。刻意留著。
@test "dk_render replaces tokens and tolerates sed metacharacters" {
  printf '# {{DISPLAY}}\nsrc={{SOURCE}}\n' > "$PROJECT/t.md"
  out=$(dk_render "$PROJECT/t.md" 'DISPLAY=登入 & 註冊 #1' 'SOURCE=a/b\\c')
  [ "$out" = "$(printf '# 登入 & 註冊 #1\nsrc=%s' 'a/b\\c')" ]
}

@test "frontmatter readers" {
  cat > "$PROJECT/r.md" <<'R'
---
name: frontend
kind: claude
tiers:
  S: sonnet/low
  M: sonnet/medium
  L: opus/high
worktree: true
mcp: [playwright, github]
---
body
R
  [ "$(dk_fm "$PROJECT/r.md" kind)" = claude ]
  [ "$(dk_fm_tier "$PROJECT/r.md" L)" = opus/high ]
  [ "$(dk_fm_list "$PROJECT/r.md" mcp | tr '\n' ' ')" = "playwright github " ]
  [ -z "$(dk_fm "$PROJECT/r.md" missing)" ]
}
@test "dk_settings: defaults, one warning when missing, file overrides" {
  rm "$DK_ROOT/settings.env"
  run dk_settings; [ "$status" -eq 0 ]; [[ "$output" == *"settings.env missing"* ]]
  dk_settings 2>/dev/null
  [ "$DK_TEST_CMD" = "" ]; [ "$DK_REVIEW_KINDS" = claude ]; [ "$DK_REVIEW_MIN" = 1 ]; [ "$DK_REVIEW_TIMEOUT_MIN" = 20 ]; [ "$DK_TAB1_SLOTS" = 4 ]
  run dk_settings; [ -z "$output" ]   # warned already in this process tree
  printf 'DK_TEST_CMD="npm test"\nDK_REVIEW_KINDS="claude codex"\nDK_TAB1_SLOTS="6"\n' > "$DK_ROOT/settings.env"
  dk_settings; [ "$DK_TEST_CMD" = "npm test" ]; [ "$DK_REVIEW_KINDS" = "claude codex" ]; [ "$DK_TAB1_SLOTS" = 6 ]; [ "$DK_REVIEW_MIN" = 1 ]
}
@test "shipped settings.env has the five keys, all quoted" {
  for k in DK_TEST_CMD DK_REVIEW_KINDS DK_REVIEW_MIN DK_REVIEW_TIMEOUT_MIN DK_TAB1_SLOTS; do grep -Eq "^$k=\"[^\"]*\"" "$DK_ROOT/settings.env"; done
  dk_settings; [ "$DK_REVIEW_KINDS" = claude ]
}
@test "dk_env_set rewrites or appends a .task.env key" {
  d=$(fixture_task login x)
  dk_env_set DK_WAVE 2; grep -q '^DK_WAVE="2"$' "$d/.task.env"; [ "$(grep -c '^DK_WAVE=' "$d/.task.env")" -eq 1 ]
  dk_env_set DK_NEWKEY "a b"; grep -q '^DK_NEWKEY="a b"$' "$d/.task.env"
  dk_env_set DK_WAVE ""; grep -q '^DK_WAVE=""$' "$d/.task.env"
  dk_task_env; [ -z "$DK_WAVE" ]; [ "$DK_NEWKEY" = "a b" ]
  run dk_env_set DK_X 'a"b'; [ "$status" -eq 1 ]; ! grep -q '^DK_X=' "$d/.task.env"
}
@test "dk_legacy_task detects a task folder without DK_BASE" {
  run dk_legacy_task; [ "$status" -eq 1 ]; [[ "$output" == *"no task bound"* ]]
  d=$(fixture_task login x); ! dk_legacy_task
  sed -i '/^DK_BASE=/d' "$d/.task.env"; dk_legacy_task
}
@test "task.env template carries the new keys" {
  for k in DK_BASE DK_WAVE DK_KIND_DOWN DK_TABS; do grep -q "^$k=" "$DK_ROOT/templates/task.env"; done
}
@test "dk_minor_lines/dk_minor_count 是 dk-review 與 dk-task-close 共用的同一套 pattern" {
  # Minor 5：兩支腳本各養一份正規表示式，漏冒號的 process 行一邊算一邊不算，
  # 領導看到的 minor 數跟 reviewer 切片實際帶的內容對不上。抽進 lib/ 共用一份。
  d=$(fixture_task login x)
  cat > "$d/process.md" <<'P'
2026-09-19T10:00 minor 1: 變數命名不一致 src/a.sh:12
2026-09-19T10:01 minor: 沒有編號也算
2026-09-19T10:02 minor 命名不一致
2026-09-19T10:03 something else
P
  [ "$(dk_minor_lines "$d/process.md" | wc -l)" -eq 2 ]
  [ "$(dk_minor_count "$d/process.md")" -eq 2 ]
  dk_minor_lines "$d/process.md" | grep -q '變數命名不一致'
  refute_grep '^2026-09-19T10:02' <<< "$(dk_minor_lines "$d/process.md")"   # 第三行漏冒號，兩邊都不該算
}
@test "dk_env_set survives 20 concurrent writers without losing a key" {
  d=$(fixture_task login x)
  for i in $(seq 1 20); do ( dk_env_set "DK_K$i" "$i" ) & done; wait
  for i in $(seq 1 20); do grep -q "^DK_K$i=\"$i\"$" "$d/.task.env"; done
  [ -f "$DK_ROOT/.sessions/$(basename "$d").lock" ]
}
