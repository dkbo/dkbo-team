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

@test "dk-msg retries a message that does not land before giving up" {
  # e2e 實測：codex reviewer 的 [DONE] 一次就被判定失敗、整筆遺失，領導從不知道它交過報告
  # （RESULTS-2026-09-11 ⑦）。送不到要重試幾次才認輸。
  HERDR_STUB_FAIL="agent wait" DK_MSG_TRIES=3 DK_MSG_RETRY_SEC=0 run dk-msg login-qa "[DONE] x"
  [ "$status" -eq 1 ]
  [ "$(grep -c '^agent wait login-qa ' "$HERDR_STUB_LOG")" -eq 3 ]
  [ "$(grep -c 'UNDELIVERED' "$DK_ROOT/tasks/$(date +%F)-login/messages.log")" -eq 1 ]
}

# panova2/sportswitch 實跑：13 筆訊息 12 筆 UNDELIVERED。兩個獨立的洞，兩個方向各壞一邊。
@test "leader addressing an employee by its short role name reaches the registered agent" {
  # 領導照 PROTOCOL 打 `dk-msg reviewer-a`，但 herdr 裡註冊的是 login-reviewer-a：
  # 實跑中三筆 [TASK] 就這樣全滅，reviewer-b 整場沒收到工作還被記成「codex down」。
  d="$DK_ROOT/tasks/$(date +%F)-login"
  printf 'login-reviewer-a wB:pT 0 review 1 2\n' > "$d/.panes"
  HERDR_STUB_MISSING="reviewer-a" run dk-msg reviewer-a "[TASK] 對 AC1–AC8 逐條"
  [ "$status" -eq 0 ]
  grep -q '^agent prompt login-reviewer-a \[TASK\] from leader-login: 對 AC1–AC8 逐條$' "$HERDR_STUB_LOG"
  grep -Eq '^[0-9T:-]+ leader-login -> login-reviewer-a \[TASK\] ' "$d/messages.log"
}

@test "falls back to the leader pane id when the leader has no registered agent name" {
  # 領導 pane 是人手開的 claude，沒經過 herdr agent start，dk-task-new 的 rename 又沒生效
  # → leader-login 不存在 → 員工回報 100% 送不到。.task.env 的 DK_ROOT_PANE 一直都在。
  d="$DK_ROOT/tasks/$(date +%F)-login"
  DK_AGENT=login-qa HERDR_STUB_MISSING="leader-login" run dk-msg leader "[DONE] 驗收全過"
  [ "$status" -eq 0 ]
  grep -q '^agent prompt wB:p1 \[DONE\] from login-qa: 驗收全過$' "$HERDR_STUB_LOG"
  grep -Eq '^[0-9T:-]+ login-qa -> leader-login \[DONE\] 驗收全過$' "$d/messages.log"
}

@test "falls back to the employee pane id from .panes when its agent name is gone" {
  d="$DK_ROOT/tasks/$(date +%F)-login"
  printf 'login-frontend wB:pS 0 dev 1 1\n' > "$d/.panes"
  DK_AGENT=login-qa HERDR_STUB_MISSING="login-frontend" run dk-msg login-frontend "[BUG] 空密碼未擋"
  [ "$status" -eq 0 ]
  grep -q '^agent prompt wB:pS \[BUG\] from login-qa: 空密碼未擋$' "$HERDR_STUB_LOG"
}

@test "still gives up when neither the name nor the pane id can be reached" {
  d="$DK_ROOT/tasks/$(date +%F)-login"
  printf 'login-frontend wB:pS 0 dev 1 1\n' > "$d/.panes"
  DK_AGENT=login-qa HERDR_STUB_MISSING="login-frontend wB:pS" DK_MSG_TRIES=2 DK_MSG_RETRY_SEC=0 \
    run dk-msg login-frontend "[BUG] x"
  [ "$status" -eq 1 ]
  grep -q 'login-qa -> login-frontend \[UNDELIVERED\] \[BUG\] x' "$d/messages.log"
}
