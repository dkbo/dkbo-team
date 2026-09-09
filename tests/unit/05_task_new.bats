load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "task-new creates folder, env, worktree, binding, index, rename" {
  run dk-task-new login "使用者登入" --from docs/plan.md
  [ "$status" -eq 0 ]
  d="$DK_ROOT/tasks/$(date +%Y-%m-%d)-login"; [ "$output" = "$d" ]
  [ -f "$d/brief.md" ]; [ -f "$d/process.md" ]; [ -f "$d/messages.log" ]; [ -d "$d/state" ]; [ -f "$d/.panes" ]
  grep -q '^# 使用者登入$' "$d/brief.md"; grep -q 'docs/plan.md' "$d/brief.md"; grep -q 'dk/login' "$d/brief.md"
  grep -q '^DK_SHORT="login"$' "$d/.task.env"; grep -q "^DK_WORKTREE=\"$WORKTREE_PATH\"$" "$d/.task.env"; grep -q '^DK_WORKSPACE="wC"$' "$d/.task.env"
  [ "$(cat "$DK_ROOT/.sessions/wB:p1")" = "$(basename "$d")" ]
  grep -q '| 使用者登入 | task | planning |' "$DK_ROOT/tasks/INDEX.md"
  grep -q '^worktree create --branch dk/login --base main --cwd .* --no-focus$' "$HERDR_STUB_LOG"
  grep -q '^agent rename wB:p1 leader-login$' "$HERDR_STUB_LOG"
  grep -q 'task-new login' "$d/process.md"
}
@test "task-new rejects bad short names and duplicates" {
  run dk-task-new Login x; [ "$status" -eq 1 ]
  run dk-task-new averyveryverylongname x; [ "$status" -eq 1 ]
  run dk-task-new login 'bad "quote'; [ "$status" -eq 1 ]
  run dk-task-new login 'abc\'; [ "$status" -eq 1 ]
  run dk-task-new login "with space & hash #1"; [ "$status" -eq 0 ]; grep -q '^DK_DISPLAY="with space & hash #1"$' "$output/.task.env"
  run dk-task-new login x; [ "$status" -eq 1 ]
}
@test "task-new tolerates agent rename failure" {
  HERDR_STUB_FAIL="agent rename" run dk-task-new login x
  [ "$status" -eq 0 ]
  grep -q '| x | task | planning |' "$DK_ROOT/tasks/INDEX.md"
  grep -q 'rename failed' "$DK_ROOT/tasks/$(date +%F)-login/process.md"
}
@test "task-new skips rename when agent already named" {
  echo '{"result":{"agent":{"name":"leader-login","agent_status":"idle","pane_id":"wB:p1"}}}' > "$HERDR_STUB_RESPONSES/agent_get.json"
  dk-task-new login x >/dev/null
  ! grep -q '^agent rename' "$HERDR_STUB_LOG"
}
@test "dk-process appends to the bound task" {
  dk-task-new login x >/dev/null; dk-process "decision: 用現有 users 表"
  grep -Eq '^[0-9T:-]+ decision: 用現有 users 表$' "$DK_ROOT/tasks/$(date +%Y-%m-%d)-login/process.md"
}
@test "task-new --gate1 flips index to running" {
  dk-task-new login "使用者登入" >/dev/null
  dk-task-new login --gate1
  grep -q '| 使用者登入 | task | running |' "$DK_ROOT/tasks/INDEX.md"
  grep -q 'gate1 approved' "$DK_ROOT/tasks/$(date +%Y-%m-%d)-login/process.md"
}
@test "task-new --gate1 on unknown short dies cleanly" {
  run dk-task-new nosuch --gate1; [ "$status" -eq 1 ]; [[ "$output" == *"no task nosuch"* ]]
}
@test "hyphenated short names do not collide" {
  dk-task-new brand-new x >/dev/null
  run dk-task-new new y; [ "$status" -eq 0 ]
  run dk-task-new new --gate1; [ "$status" -eq 0 ]
  grep -q 'gate1 approved' "$DK_ROOT/tasks/$(date +%F)-new/process.md"
  ! grep -q 'gate1 approved' "$DK_ROOT/tasks/$(date +%F)-brand-new/process.md"
}
