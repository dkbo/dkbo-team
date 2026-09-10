load ../helpers
setup() { setup_project; . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/frontmatter.sh"; }
teardown() { teardown_project; }

@test "dk_slug makes herdr-safe names" {
  [ "$(dk_slug 'Login/Page Cart')" = "login-page-cart" ]
  [ "$(dk_slug '123abc')" = "abc" ]
  [ "$(dk_slug "$(printf 'a%.0s' {1..40})")" = "$(printf 'a%.0s' {1..32})" ]
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

@test "index add and set" {
  dk_index_add 2026-09-10 使用者登入 task planning —
  grep -q '| 2026-09-10 | 使用者登入 | task | planning | — |' "$DK_ROOT/tasks/INDEX.md"
  dk_index_set 使用者登入 done "merged abc123"
  grep -q '| 使用者登入 | task | done | merged abc123 |' "$DK_ROOT/tasks/INDEX.md"
}

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
}
@test "dk_legacy_task detects a task folder without DK_BASE" {
  run dk_legacy_task; [ "$status" -eq 1 ]; [[ "$output" == *"no task bound"* ]]
  d=$(fixture_task login x); ! dk_legacy_task
  sed -i '/^DK_BASE=/d' "$d/.task.env"; dk_legacy_task
}
@test "task.env template carries the new keys" {
  for k in DK_BASE DK_WAVE DK_KIND_DOWN DK_TABS; do grep -q "^$k=" "$DK_ROOT/templates/task.env"; done
}
