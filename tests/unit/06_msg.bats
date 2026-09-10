load ../helpers
setup() { setup_project; fixture_task login 使用者登入 >/dev/null; }
teardown() { teardown_project; }

@test "msg from employee to employee: waits, prompts, logs" {
  DK_AGENT=login-qa run dk-msg login-frontend "[BUG] 空密碼未擋，見 state/qa.md"
  [ "$status" -eq 0 ]
  grep -q '^agent wait login-frontend --until idle --until done --timeout 300000$' "$HERDR_STUB_LOG"
  grep -q '^agent prompt login-frontend \[BUG\] from login-qa: 空密碼未擋，見 state/qa.md$' "$HERDR_STUB_LOG"
  grep -Eq '^[0-9T:-]+ login-qa -> login-frontend \[BUG\] 空密碼未擋，見 state/qa.md$' "$DK_ROOT/tasks/$(date +%F)-login/messages.log"
}
@test "leader alias resolves and leader sender defaults" {
  DK_AGENT=login-qa run dk-msg leader "[DONE] 驗收全過"
  grep -q '^agent prompt leader-login ' "$HERDR_STUB_LOG"
  run dk-msg login-qa "[DECISION] 用現有 users 表"
  grep -q 'leader-login -> login-qa \[DECISION\]' "$DK_ROOT/tasks/$(date +%F)-login/messages.log"
}
@test "refuses >200 chars, unknown type, isolated peer" {
  long=$(printf 'x%.0s' {1..201})
  DK_AGENT=login-qa run dk-msg login-frontend "[BUG] $long"; [ "$status" -eq 2 ]
  DK_AGENT=login-qa run dk-msg login-frontend "[HELLO] hi"; [ "$status" -eq 2 ]
  DK_AGENT=login-qa DK_ISOLATED=1 run dk-msg login-frontend "[BUG] x"; [ "$status" -eq 2 ]
  DK_AGENT=login-qa DK_ISOLATED=1 run dk-msg leader "[DONE] x"; [ "$status" -eq 0 ]
  ! grep -q '^agent prompt login-frontend' "$HERDR_STUB_LOG"
}
@test "undelivered when wait fails" {
  HERDR_STUB_FAIL="agent wait" DK_AGENT=login-qa run dk-msg login-frontend "[BUG] x"
  [ "$status" -eq 1 ]
  grep -q 'login-qa -> login-frontend \[UNDELIVERED\] \[BUG\] x' "$DK_ROOT/tasks/$(date +%F)-login/messages.log"
}
@test "ack writes marker" {
  dk-msg --ack
  grep -Eq '^[0-9T:-]+ leader-login \[ACK\]$' "$DK_ROOT/tasks/$(date +%F)-login/messages.log"
}
@test "counts characters not bytes even when the caller's LC_ALL=C" {
  body=$(printf '測%.0s' $(seq 1 150))
  LC_ALL=C DK_AGENT=login-qa run dk-msg login-frontend "[TASK] $body"
  [ "$status" -eq 0 ]
}
@test "chore worker: dk-msg leader resolves DK_LEADER, waits for idle, logs under _chores" {
  rm -f "$DK_ROOT/.sessions/"*   # a chore has no task binding
  DK_AGENT=chore-it-1 DK_ROLE=it DK_CHORE_FILE="$DK_ROOT/tasks/_chores/x.md" DK_LEADER=wB:p1 \
    run dk-msg leader "[DONE] 5 處文件已改，未 commit"
  [ "$status" -eq 0 ]
  grep -q '^agent wait wB:p1 --until idle --until done --timeout 300000$' "$HERDR_STUB_LOG"
  grep -q '^agent prompt wB:p1 \[DONE\] from chore-it-1: 5 處文件已改，未 commit$' "$HERDR_STUB_LOG"
  grep -Eq '^[0-9T:-]+ chore-it-1 -> wB:p1 \[DONE\] 5 處文件已改，未 commit$' "$DK_ROOT/tasks/_chores/messages.log"
}
@test "chore worker may only message the leader" {
  rm -f "$DK_ROOT/.sessions/"*
  DK_AGENT=chore-it-1 DK_ROLE=it DK_CHORE_FILE="$DK_ROOT/tasks/_chores/x.md" DK_LEADER=wB:p1 \
    run dk-msg login-frontend "[QUESTION] x"
  [ "$status" -eq 2 ]
  ! grep -q '^agent prompt' "$HERDR_STUB_LOG"
}
