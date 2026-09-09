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
