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
  refute_grep -q '^agent prompt login-frontend' "$HERDR_STUB_LOG"
}
@test "undelivered when wait fails" {
  HERDR_STUB_FAIL="agent wait" DK_AGENT=login-qa DK_MSG_RETRY_SEC=0 run dk-msg login-frontend "[BUG] x"
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
  refute_grep -q '^agent prompt' "$HERDR_STUB_LOG"
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
  DK_MSG_BG=1 HERDR_STUB_MISSING="reviewer-a" run dk-msg reviewer-a "[TASK] 對 AC1–AC8 逐條"
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

@test "交棒之後領導的退路是 DK_LEADER_PANE，不是版面錨點 DK_ROOT_PANE" {
  # dk-leader --run 把領導搬到任務 workspace 的根 pane。DK_ROOT_PANE 是版面錨點，
  # 「領導在哪」是 DK_LEADER_PANE —— 借用版面變數會把訊息打到空 shell。
  d="$DK_ROOT/tasks/$(date +%F)-login"
  echo 'DK_LEADER_PANE="wC:p1"' >> "$d/.task.env"
  DK_AGENT=login-qa HERDR_STUB_MISSING="leader-login" run dk-msg leader "[DONE] 驗收全過"
  [ "$status" -eq 0 ]
  grep -q '^agent prompt wC:p1 \[DONE\] from login-qa: 驗收全過$' "$HERDR_STUB_LOG"
  refute_grep '^agent prompt wB:p1 ' "$HERDR_STUB_LOG"
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

# --- dev 的 [DONE] 不再逐筆吵領導：只落盤，等 dk-watch 在全員完成時推一則 ---

dev_panes() { printf 'login-backend wC:p2 0 dev 1 1\nlogin-qa wC:p3 0 review 1 2\n' > "$1/.panes"; }

@test "dev 的 [DONE] 寫進 log 但不投遞給領導" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  echo x > "$d/state/backend.report.md"
  printf 'status: done\ntouched: []\nreport: state/backend.report.md\n' > "$d/state/backend.md"
  DK_AGENT=login-backend run dk-msg leader "[DONE] POST /login 完成"
  [ "$status" -eq 0 ]
  refute_grep '^agent prompt' "$HERDR_STUB_LOG"
  grep -Eq '^[0-9T:-]+ login-backend -> leader-login \[DONE\] POST /login 完成$' "$d/messages.log"
}

@test "dev 的 state 還不是 done 就送 [DONE]：當場拒收，不落盤也不投遞" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  printf 'status: working\n' > "$d/state/backend.md"
  DK_AGENT=login-backend run dk-msg leader "[DONE] POST /login 完成"
  [ "$status" -eq 2 ]
  [[ "$output" == *"status: done"* ]]
  refute_grep '^agent prompt' "$HERDR_STUB_LOG"
  refute_grep 'DONE' "$d/messages.log"
}

@test "dev 連 state 檔都還沒建就送 [DONE]：一樣拒收" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  rm -f "$d/state/backend.md"
  DK_AGENT=login-backend run dk-msg leader "[DONE] x"
  [ "$status" -eq 2 ]
  refute_grep 'DONE' "$d/messages.log"
}

@test "dev 送給 qa 的 [DONE] 改背景送：當場返回，之後仍會送達並記 log" {
  # qa 忙著時前景等它閒下來，dev 的 pane 會卡 12–30 分（panova autofold、gamemore 實測）。
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  printf 'status: done\n' > "$d/state/backend.md"
  DK_AGENT=login-backend run dk-msg login-qa "[DONE] API 好了，可以驗"
  [ "$status" -eq 0 ]
  [[ "$output" == *"背景"* ]]
  for _ in $(seq 1 50); do grep -q 'login-backend -> login-qa \[DONE\]' "$d/messages.log" 2>/dev/null && break; sleep 0.1; done
  grep -q '^agent prompt login-qa \[DONE\] from login-backend: API 好了，可以驗$' "$HERDR_STUB_LOG"
  [ "$(grep -c 'login-backend -> login-qa \[DONE\]' "$d/messages.log")" -eq 1 ]
}

@test "dev 送給 dev 夥伴的 [DONE] 照常前景送（附交接內容，對方要等它）" {
  d="$DK_ROOT/tasks/$(date +%F)-login"
  printf 'login-backend wC:p2 0 dev 1 1\nlogin-frontend wC:p4 0 dev 1 2\n' > "$d/.panes"
  printf 'status: done\n' > "$d/state/backend.md"
  DK_AGENT=login-backend run dk-msg login-frontend "[DONE] API 好了"
  [ "$status" -eq 0 ]
  [[ "$output" != *"背景"* ]]
  grep -q '^agent prompt login-frontend \[DONE\] from login-backend: API 好了$' "$HERDR_STUB_LOG"
}

@test "review 組（qa、reviewer）的 [DONE] 照響" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  DK_AGENT=login-qa run dk-msg leader "[DONE] 驗收全過"
  [ "$status" -eq 0 ]
  grep -q '^agent prompt leader-login \[DONE\] from login-qa: 驗收全過$' "$HERDR_STUB_LOG"
}

@test "dev 的其他類型不受影響：state 沒 done 也照送 ESCALATE" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  printf 'status: working\n' > "$d/state/backend.md"
  DK_AGENT=login-backend run dk-msg leader "[ESCALATE] 要改共用契約"
  [ "$status" -eq 0 ]
  grep -q '^agent prompt leader-login \[ESCALATE\] from login-backend: 要改共用契約$' "$HERDR_STUB_LOG"
}

# --- [TASK] 開啟新的一輪：.panes 的 epoch 是「最後一次指派」而不是「spawn 以來」（BACKLOG 2026-09-14） ---

epoch_of() { awk -v n="$2" '$1==n{print $3; exit}' "$1/.panes"; }
rv_panes() { printf 'login-reviewer-a wC:p4 100 review 1 3\nlogin-frontend wC:p2 100 dev 1 1\n' > "$1/.panes"; }

@test "[TASK] 送達後重設該列的 epoch，其餘欄位與其餘列一字不改" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; rv_panes "$d"
  DK_MSG_BG=1 run dk-msg login-reviewer-a "[TASK] 複看第二輪"
  [ "$status" -eq 0 ]
  now=$(date +%s); [ "$(epoch_of "$d" login-reviewer-a)" -ge "$((now - 10))" ]
  [ "$(awk '$1=="login-reviewer-a"{print $2, $4, $5, $6}' "$d/.panes")" = "wC:p4 review 1 3" ]
  [ "$(epoch_of "$d" login-frontend)" = 100 ]
}

@test "送不到的 [TASK] 不重設 epoch：卡住的員工不能被藏起來" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; rv_panes "$d"
  DK_MSG_BG=1 HERDR_STUB_MISSING="login-reviewer-a wC:p4" DK_MSG_TRIES=2 DK_MSG_RETRY_SEC=0 \
    run dk-msg login-reviewer-a "[TASK] 複看第二輪"
  [ "$status" -eq 1 ]
  [ "$(epoch_of "$d" login-reviewer-a)" = 100 ]
}

@test "TASK／BUG 以外不動 epoch：[ANSWER] 不開新一輪" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; rv_panes "$d"
  run dk-msg login-reviewer-a "[ANSWER] 用現有 users 表"
  [ "$status" -eq 0 ]
  [ "$(epoch_of "$d" login-reviewer-a)" = 100 ]
  [ ! -f "$d/.blocked/login-reviewer-a.redispatch" ]
}

@test "AC16: [BUG] 也開啟新的一輪（領導轉 reviewer Important 給 dev）" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; rv_panes "$d"
  DK_MSG_BG=1 run dk-msg login-reviewer-a "[BUG] 重現方式見 report"
  [ "$status" -eq 0 ]
  now=$(date +%s); [ "$(epoch_of "$d" login-reviewer-a)" -ge "$((now - 10))" ]
  [ -f "$d/.blocked/login-reviewer-a.redispatch" ]
}

@test "[TASK] 存下指派當下的 state cksum，並清掉上一輪的逾時標記" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; rv_panes "$d"
  printf 'status: done\n' > "$d/state/reviewer-a.md"
  mkdir -p "$d/.blocked"; printf 'notified\ndelivered\n' > "$d/.blocked/login-reviewer-a.timeout"
  DK_MSG_BG=1 run dk-msg login-reviewer-a "[TASK] 複看第二輪"
  [ "$status" -eq 0 ]
  [ ! -f "$d/.blocked/login-reviewer-a.timeout" ]
  [ "$(cat "$d/.blocked/login-reviewer-a.redispatch")" = "$(cksum < "$d/state/reviewer-a.md")" ]
}

@test "指派時還沒有 state 檔：標記留空，之後出現的 state 就算這一輪寫的" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; rv_panes "$d"
  DK_MSG_BG=1 run dk-msg login-reviewer-a "[TASK] 第一次派工"
  [ "$status" -eq 0 ]
  [ -f "$d/.blocked/login-reviewer-a.redispatch" ]
  [ ! -s "$d/.blocked/login-reviewer-a.redispatch" ]
}

@test "不在 .panes 裡的對象（雜務、已收工）不會憑空生出一列" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; rv_panes "$d"
  run dk-msg login-qa "[TASK] 去驗一下"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$d/.panes")" -eq 2 ]
  [ ! -f "$d/.blocked/login-qa.redispatch" ]
}

# --- AC8：切片過期提示 ---

@test "AC8: brief.md 比對方的切片新，領導送 [TASK] 時提醒但照送" {
  d="$DK_ROOT/tasks/$(date +%F)-login"
  mkdir -p "$d/briefs"; echo old > "$d/briefs/backend.md"; sleep 1.1; echo new > "$d/brief.md"
  run dk-msg login-backend "[TASK] 補一塊"
  [ "$status" -eq 0 ]
  [[ "$output" == *"brief.md 比 briefs/backend.md 新"* ]]
  [[ "$output" == *"dk-wave-open"* ]]; [[ "$output" == *"--refresh"* ]]
  grep -q '^agent prompt login-backend' "$HERDR_STUB_LOG"   # 沒被擋，照送
}
@test "AC8: 切片比 brief.md 新就不提醒" {
  d="$DK_ROOT/tasks/$(date +%F)-login"
  mkdir -p "$d/briefs"; echo old > "$d/brief.md"; sleep 1.1; echo new > "$d/briefs/backend.md"
  run dk-msg login-backend "[TASK] 補一塊"
  [ "$status" -eq 0 ]
  refute_grep '比 briefs/backend.md 新' <(printf '%s\n' "$output")
}
@test "AC8: 員工互傳不提示（只有領導送才算）" {
  d="$DK_ROOT/tasks/$(date +%F)-login"
  mkdir -p "$d/briefs"; echo old > "$d/briefs/frontend.md"; sleep 1.1; echo new > "$d/brief.md"
  DK_AGENT=login-qa run dk-msg login-frontend "[TASK] 幫個忙"
  [ "$status" -eq 0 ]
  refute_grep '比 briefs' <(printf '%s\n' "$output")
}

# --- AC9：未讀提示 ---

@test "AC9: 領導最後一次 [ACK] 之後還有訊息沒讀，送 [TASK] 前先提醒" {
  d="$DK_ROOT/tasks/$(date +%F)-login"
  DK_AGENT=login-qa run dk-msg leader "[DONE] 驗收全過"; [ "$status" -eq 0 ]
  DK_AGENT=login-backend run dk-msg leader "[ESCALATE] 要改共用契約"; [ "$status" -eq 0 ]
  run dk-msg login-frontend "[TASK] 補一塊"
  [ "$status" -eq 0 ]
  [[ "$output" == *"你有 2 則未 ack 的訊息"* ]]
  [[ "$output" == *"login-backend"* ]]   # 最新一則來自誰
}
@test "AC9: dev 只落盤的 [DONE] 也算未讀" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  echo x > "$d/state/backend.report.md"
  printf 'status: done\ntouched: []\nreport: state/backend.report.md\n' > "$d/state/backend.md"
  DK_AGENT=login-backend run dk-msg leader "[DONE] POST /login 完成"; [ "$status" -eq 0 ]
  run dk-msg login-qa "[DECISION] 用現有 users 表"
  [ "$status" -eq 0 ]
  [[ "$output" == *"你有 1 則未 ack 的訊息"* ]]
}
@test "AC9: ack 過之後同一則不會再算未讀" {
  d="$DK_ROOT/tasks/$(date +%F)-login"
  DK_AGENT=login-qa run dk-msg leader "[DONE] 驗收全過"; [ "$status" -eq 0 ]
  dk-msg --ack
  run dk-msg login-frontend "[TASK] 補一塊"
  [ "$status" -eq 0 ]
  refute_grep '未 ack' <(printf '%s\n' "$output")
}
@test "AC9: BUG 不受這條規則影響（只驗 TASK／DECISION）" {
  d="$DK_ROOT/tasks/$(date +%F)-login"
  DK_AGENT=login-qa run dk-msg leader "[DONE] 驗收全過"; [ "$status" -eq 0 ]
  run dk-msg login-frontend "[BUG] 重現方式見 report"
  [ "$status" -eq 0 ]
  refute_grep '未 ack' <(printf '%s\n' "$output")
}

# --- AC10：dev 的 [DONE] 先驗 state 格式 ---

state_ok() { # DIR — 一份合法的 dev state
  echo x > "$1/state/backend.report.md"
  printf 'status: done\ntouched:\n  - src/api/login.ts\nreport: state/backend.report.md\n' > "$1/state/backend.md"
}
@test "AC10: 缺 touched 鍵，state 格式錯拒收" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  echo x > "$d/state/backend.report.md"
  printf 'status: done\nreport: state/backend.report.md\n' > "$d/state/backend.md"
  DK_AGENT=login-backend run dk-msg leader "[DONE] x"
  [ "$status" -eq 2 ]
  [[ "$output" == "dk-msg: state 格式錯："* ]]
  refute_grep 'DONE' "$d/messages.log"
}
@test "AC10: touched 沒有兩個空白加 '- ' 開頭，拒收" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  echo x > "$d/state/backend.report.md"
  printf 'status: done\ntouched:\n- src/api/login.ts\nreport: state/backend.report.md\n' > "$d/state/backend.md"
  DK_AGENT=login-backend run dk-msg leader "[DONE] x"
  [ "$status" -eq 2 ]
  [[ "$output" == *"state 格式錯"* ]]
}
@test "AC10: touched 路徑含萬用字元，拒收" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  echo x > "$d/state/backend.report.md"
  printf 'status: done\ntouched:\n  - src/api/*.ts\nreport: state/backend.report.md\n' > "$d/state/backend.md"
  DK_AGENT=login-backend run dk-msg leader "[DONE] x"
  [ "$status" -eq 2 ]
  [[ "$output" == *"state 格式錯"* ]]
}
@test "AC10: report 路徑不存在，拒收" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  printf 'status: done\ntouched: []\nreport: state/nope.md\n' > "$d/state/backend.md"
  DK_AGENT=login-backend run dk-msg leader "[DONE] x"
  [ "$status" -eq 2 ]
  [[ "$output" == *"state 格式錯"* ]]
}
@test "AC10: report 路徑存在但是空檔，拒收" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  : > "$d/state/backend.report.md"
  printf 'status: done\ntouched: []\nreport: state/backend.report.md\n' > "$d/state/backend.md"
  DK_AGENT=login-backend run dk-msg leader "[DONE] x"
  [ "$status" -eq 2 ]
  [[ "$output" == *"state 格式錯"* ]]
}
@test "AC10: touched 零項（裸 touched: 與 touched: [] 皆合法）與 touched 有多筆都放行" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  state_ok "$d"
  DK_AGENT=login-backend run dk-msg leader "[DONE] 都合法"
  [ "$status" -eq 0 ]
  grep -q 'DONE' "$d/messages.log"
}
@test "AC10: touched:  [] （冒號後多個空白）也合法" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  printf 'status: done\ntouched:  []\nreport: state/backend.report.md\n' > "$d/state/backend.md"
  printf 'x' > "$d/state/backend.report.md"
  DK_AGENT=login-backend run dk-msg leader "[DONE] 都合法"
  [ "$status" -eq 0 ]
}
@test "AC17: 裸 touched:（沒有任何子項）合法" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  printf 'status: done\ntouched:\nreport: state/backend.report.md\n' > "$d/state/backend.md"
  printf 'x' > "$d/state/backend.report.md"
  DK_AGENT=login-backend run dk-msg leader "[DONE] 裸 touched 合法"
  [ "$status" -eq 0 ]
  grep -q 'DONE' "$d/messages.log"
}
@test "AC17: report: 路徑後有行尾空白，去掉再判仍放行" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  printf 'x' > "$d/state/backend.report.md"
  printf 'status: done\ntouched: []\nreport: state/backend.report.md   \n' > "$d/state/backend.md"
  DK_AGENT=login-backend run dk-msg leader "[DONE] report 行尾空白"
  [ "$status" -eq 0 ]
  grep -q 'DONE' "$d/messages.log"
}
@test "AC17: 缺 touched／report 鍵的錯誤各附正確寫法" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  echo x > "$d/state/backend.report.md"
  printf 'status: done\nreport: state/backend.report.md\n' > "$d/state/backend.md"
  DK_AGENT=login-backend run dk-msg leader "[DONE] x"
  [ "$status" -eq 2 ]
  [[ "$output" == *"缺 touched 鍵"*"touched:"* ]]
  printf 'status: done\ntouched: []\n' > "$d/state/backend.md"
  DK_AGENT=login-backend run dk-msg leader "[DONE] x"
  [ "$status" -eq 2 ]
  [[ "$output" == *"缺 report 鍵"*"report: state/"* ]]
}
@test "AC10: 只驗 dev，不驗 qa 與 reviewer" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  printf 'status: done\n' > "$d/state/qa.md"
  DK_AGENT=login-qa run dk-msg leader "[DONE] 驗收全過"
  [ "$status" -eq 0 ]
}

# --- AC6（#23、#3）：重派已交付的 dev，聚合要等他這一輪再交一次 ---

wait_log() { # PATTERN FILE — 等背景那一份寫進 log（最多 5 秒）
  for _ in $(seq 1 50); do grep -q "$1" "$2" 2>/dev/null && return 0; sleep 0.1; done; return 1
}
delivered_wave() { # DIR — 兩個 dev 都已交付、波 1 的聚合已推過
  local now; now=$(date +%s)
  printf 'login-backend wC:p2 %s dev 1 1\nlogin-frontend wC:p5 %s dev 1 2\nlogin-qa wC:p3 %s review 1 3\n' \
    "$now" "$now" "$now" > "$1/.panes"
  sed -i 's/"blocked"/"idle"/' "$HERDR_STUB_RESPONSES/agent_list.json"
  sed -i 's/^DK_WAVE=.*/DK_WAVE="1"/' "$1/.task.env"
  printf 'status: done\n' > "$1/state/backend.md"; printf 'status: done\n' > "$1/state/frontend.md"
  DK_TASK_DIR="$1" dk-watch --once
  grep -q '全員完成' "$HERDR_STUB_LOG"
  : > "$HERDR_STUB_LOG"
}

@test "AC6: 已交付的 dev 被 [TASK] 後不推聚合，改寫 state 為 done 後推一次" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; delivered_wave "$d"
  [ -f "$d/.blocked/wave-1.backend.done" ]; [ -f "$d/.blocked/wave-1.devdone" ]
  run dk-msg login-backend "[TASK] 補錯誤碼"
  [ "$status" -eq 0 ]
  wait_log 'leader-login -> login-backend \[TASK\]' "$d/messages.log"
  [ ! -f "$d/.blocked/wave-1.backend.done" ]
  [ ! -f "$d/.blocked/wave-1.devdone" ]
  [ -f "$d/.blocked/wave-1.frontend.done" ]   # 沒被重派的夥伴不動
  [ "$(cat "$d/.blocked/login-backend.spawn")" = "$(cksum < "$d/state/backend.md")" ]
  DK_TASK_DIR="$d" dk-watch --once
  refute_grep '全員完成' "$HERDR_STUB_LOG"
  printf 'status: done\nnotes: 錯誤碼補好了\n' > "$d/state/backend.md"
  DK_TASK_DIR="$d" dk-watch --once; DK_TASK_DIR="$d" dk-watch --once
  [ "$(grep -c '全員完成' "$HERDR_STUB_LOG")" -eq 1 ]
}

@test "AC6: 已交付的 dev 收到的 [TASK] 尾端附「你已交付過」" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; delivered_wave "$d"
  run dk-msg login-backend "[TASK] 補錯誤碼"
  [ "$status" -eq 0 ]
  wait_log 'leader-login -> login-backend \[TASK\]' "$d/messages.log"
  grep -q '^agent prompt login-backend \[TASK\] from leader-login: 補錯誤碼（你已交付過：做完先改寫 state 再回 \[FIXED\]）$' "$HERDR_STUB_LOG"
}

@test "AC6: 還沒交付的 dev 與已交付的 qa 都不附尾註" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; delivered_wave "$d"
  printf 'status: working\n' > "$d/state/frontend.md"; printf 'status: done\n' > "$d/state/qa.md"
  run dk-msg login-frontend "[BUG] 空密碼未擋"; [ "$status" -eq 0 ]
  run dk-msg login-qa "[TASK] 再驗一次"; [ "$status" -eq 0 ]
  wait_log 'leader-login -> login-frontend \[BUG\]' "$d/messages.log"
  wait_log 'leader-login -> login-qa \[TASK\]' "$d/messages.log"
  grep -q '^agent prompt login-frontend \[BUG\] from leader-login: 空密碼未擋$' "$HERDR_STUB_LOG"
  grep -q '^agent prompt login-qa \[TASK\] from leader-login: 再驗一次$' "$HERDR_STUB_LOG"
  refute_grep '已交付過' "$HERDR_STUB_LOG"
}

# --- AC5（#14）：領導送給員工的指派型訊息一律背景送，領導不再卡在「等對方閒下來」 ---

gate_herdr() { # 在 PATH 前面墊一層：agent wait 要等 $BATS_TEST_TMPDIR/open 出現才放行（最多 10 秒）
  mkdir -p "$BATS_TEST_TMPDIR/gate"
  cat > "$BATS_TEST_TMPDIR/gate/herdr" <<SH
#!/usr/bin/env bash
if [ "\$1 \$2" = "agent wait" ]; then
  echo "\$3" >> "$BATS_TEST_TMPDIR/gate/waits"
  for _ in \$(seq 1 100); do [ -f "$BATS_TEST_TMPDIR/open" ] && break; sleep 0.1; done
fi
exec "$REPO_ROOT/tests/stub/herdr" "\$@"
SH
  chmod +x "$BATS_TEST_TMPDIR/gate/herdr"
  export PATH="$BATS_TEST_TMPDIR/gate:$PATH"
}

@test "AC5: 領導的 [TASK] 當場返回並印背景提示，送達之後才 redispatch" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; rv_panes "$d"; gate_herdr
  run dk-msg login-reviewer-a "[TASK] 複看第二輪"
  [ "$status" -eq 0 ]
  [ "$output" = "dk-msg: 改在背景等 login-reviewer-a 閒下來再送（結果記在 messages.log），你直接往下做" ]
  [ "$(epoch_of "$d" login-reviewer-a)" = 100 ]
  [ ! -f "$d/.blocked/login-reviewer-a.redispatch" ]
  refute_grep -q '^agent prompt' "$HERDR_STUB_LOG"
  : > "$BATS_TEST_TMPDIR/open"
  wait_log 'leader-login -> login-reviewer-a \[TASK\] 複看第二輪' "$d/messages.log"
  grep -q '^agent prompt login-reviewer-a \[TASK\] from leader-login: 複看第二輪$' "$HERDR_STUB_LOG"
  now=$(date +%s); [ "$(epoch_of "$d" login-reviewer-a)" -ge "$((now - 10))" ]
  [ -f "$d/.blocked/login-reviewer-a.redispatch" ]
}

@test "AC5: DECISION／STOP／BUG 也背景送；送給雜務與員工互傳照常前景" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; rv_panes "$d"
  for t in DECISION STOP BUG; do
    run dk-msg login-frontend "[$t] x"; [ "$status" -eq 0 ]; [[ "$output" == *"改在背景"* ]]
  done
  run dk-msg login-reviewer-a "[ANSWER] 用 users 表"; [ "$status" -eq 0 ]; [[ "$output" != *"背景"* ]]
  DK_AGENT=login-reviewer-a run dk-msg login-frontend "[QUESTION] x"; [ "$status" -eq 0 ]; [[ "$output" != *"背景"* ]]
  run dk-msg chore-it-1 "[TASK] 不在 .panes 的對象"; [[ "$output" != *"背景"* ]]
}

@test "AC5: 背景那一份最終送不到：記 [UNDELIVERED] 與 process undelivered，epoch 不動" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; rv_panes "$d"
  HERDR_STUB_MISSING="login-reviewer-a wC:p4" DK_MSG_TRIES=2 DK_MSG_RETRY_SEC=0 \
    run dk-msg login-reviewer-a "[TASK] 複看第二輪"
  [ "$status" -eq 0 ]
  wait_log 'leader-login -> login-reviewer-a \[UNDELIVERED\] \[TASK\] 複看第二輪' "$d/messages.log"
  for _ in $(seq 1 20); do grep -q 'undelivered' "$d/process.md" && break; sleep 0.1; done
  grep -Eq '^[0-9T:-]+ undelivered login-reviewer-a \[TASK\]$' "$d/process.md"
  [ "$(epoch_of "$d" login-reviewer-a)" = 100 ]
  run dk-resume; [[ "$output" == *"undelivered login-reviewer-a [TASK]"* ]]
}

@test "AC5: 背景那一份預設最多等 30 分鐘（6 次 × 300000 ms），DK_MSG_TRIES 可覆寫" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; rv_panes "$d"
  HERDR_STUB_MISSING="login-reviewer-a wC:p4" DK_MSG_RETRY_SEC=0 run dk-msg login-reviewer-a "[TASK] x"
  wait_log 'UNDELIVERED' "$d/messages.log"
  [ "$(grep -c '^agent wait login-reviewer-a --until idle --until done --timeout 300000$' "$HERDR_STUB_LOG")" -eq 6 ]
}

@test "AC5: 同一收件者排著多則背景訊息時一次只送一則，照送出順序" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; rv_panes "$d"; gate_herdr
  run dk-msg login-reviewer-a "[TASK] 第一則"; [ "$status" -eq 0 ]
  run dk-msg login-reviewer-a "[DECISION] 第二則"; [ "$status" -eq 0 ]
  run dk-msg login-reviewer-a "[STOP] 第三則"; [ "$status" -eq 0 ]
  sleep 1
  [ "$(grep -c '^login-reviewer-a$' "$BATS_TEST_TMPDIR/gate/waits")" -eq 1 ]   # 後兩則在排隊，沒有一起搶
  : > "$BATS_TEST_TMPDIR/open"
  wait_log 'login-reviewer-a \[STOP\] 第三則' "$d/messages.log"
  [ "$(grep '^agent prompt login-reviewer-a' "$HERDR_STUB_LOG" | sed 's/.*: //' | tr '\n' ' ')" = "第一則 第二則 第三則 " ]
}

@test "AC5 review I1: 佇列檔已存在時，dev→qa 的 [DONE] 背景那一份立刻送（沒排隊就不進佇列）" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; dev_panes "$d"
  printf 'status: done\n' > "$d/state/backend.md"
  mkdir -p "$d/.blocked"; : > "$d/.blocked/msgq-login-qa"   # 領導之前背景送過 qa，佇列檔留著
  DK_AGENT=login-backend run dk-msg login-qa "[DONE] API 好了，可以驗"
  [ "$status" -eq 0 ]
  wait_log 'login-backend -> login-qa \[DONE\]' "$d/messages.log"
}

@test "AC5 review I1: 最後一位送完離開佇列，自己的 pid 與 .tmp 都不留" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; rv_panes "$d"
  run dk-msg login-reviewer-a "[TASK] 複看第二輪"; [ "$status" -eq 0 ]
  wait_log 'leader-login -> login-reviewer-a \[TASK\]' "$d/messages.log"
  for _ in $(seq 1 20); do [ -s "$d/.blocked/msgq-login-reviewer-a" ] || break; sleep 0.1; done
  [ ! -s "$d/.blocked/msgq-login-reviewer-a" ]
  [ ! -e "$d/.blocked/msgq-login-reviewer-a.tmp" ]
}

@test "整枝評議 Minor①：redispatch 的鎖檔在 .blocked/panes.lock，不在任務目錄根（結案不被 commit 進記憶）" {
  d="$DK_ROOT/tasks/$(date +%F)-login"; rv_panes "$d"
  DK_MSG_BG=1 run dk-msg login-reviewer-a "[TASK] 複看第二輪"
  [ "$status" -eq 0 ]
  [ -f "$d/.blocked/panes.lock" ]
  [ ! -e "$d/.panes.lock" ]
}

# --- AC5（rest）：dk-msg 每個寫 messages.log 的出口都把守望叫回來 ---
# 事故走的正是 dev 對 leader 的 [DONE]：它只落盤就 exit 0，守望死了沒有任何人發現。
msg_task() { echo "$DK_ROOT/tasks/$(date +%F)-login"; }
kill_dead_watch() { # 把 .task.env 的輪詢 pid 換成一個已死的 pid
  local dead; sh -c 'exit 0' & dead=$!; wait "$dead" 2>/dev/null || true
  sed -i "s/^DK_WATCH_PID=.*/DK_WATCH_PID=\"$dead\"/" "$(msg_task)/.task.env"; echo "$dead"
}
watch_pid_now() { sed -n 's/^DK_WATCH_PID="\([0-9]*\)"$/\1/p' "$(msg_task)/.task.env"; }
watch_alive() { local p; p=$(watch_pid_now); [[ "$p" =~ ^[0-9]+$ ]] && ps -p "$p" -o args= | grep -q 'dk-watch$'; }
kill_watchers() { pkill -f "$PROJECT/.dkbo/bin/dk-watch" 2>/dev/null || true; }

@test "AC5: 守望已死時 dev 對 leader 的 [DONE]（只落盤、不送達）把它叫回來" {
  d=$(msg_task); dev_panes "$d"
  echo x > "$d/state/backend.report.md"
  printf 'status: done\ntouched: []\nreport: state/backend.report.md\n' > "$d/state/backend.md"
  unset DK_NO_WATCH; dead=$(kill_dead_watch)
  DK_AGENT=login-backend run dk-msg leader "[DONE] POST /login 完成"; [ "$status" -eq 0 ]
  refute_grep '^agent prompt' "$HERDR_STUB_LOG"
  [ "$(watch_pid_now)" != "$dead" ]; watch_alive
  grep -q "watch died: poll pid $dead" "$d/process.md"
  kill_watchers
}
@test "AC5: 一般 [QUESTION] 送達路徑也把守望叫回來" {
  d=$(msg_task)
  unset DK_NO_WATCH; dead=$(kill_dead_watch)
  DK_AGENT=login-qa run dk-msg login-frontend "[QUESTION] 錯誤碼用哪一套？"; [ "$status" -eq 0 ]
  grep -q '^agent prompt login-frontend \[QUESTION\]' "$HERDR_STUB_LOG"
  [ "$(watch_pid_now)" != "$dead" ]; watch_alive
  kill_watchers
}
@test "AC5: [UNDELIVERED] 出口也把守望叫回來" {
  d=$(msg_task)
  unset DK_NO_WATCH; dead=$(kill_dead_watch)
  DK_MSG_TRIES=1 HERDR_STUB_FAIL="agent wait" DK_AGENT=login-qa run dk-msg login-frontend "[QUESTION] 在嗎"
  [ "$status" -eq 1 ]; grep -q '\[UNDELIVERED\]' "$d/messages.log"
  [ "$(watch_pid_now)" != "$dead" ]; watch_alive
  kill_watchers
}
@test "AC5: DK_NO_WATCH 設了時 dk-msg 不起守望" {
  d=$(msg_task); dev_panes "$d"
  echo x > "$d/state/backend.report.md"
  printf 'status: done\ntouched: []\nreport: state/backend.report.md\n' > "$d/state/backend.md"
  dead=$(kill_dead_watch)
  DK_AGENT=login-backend run dk-msg leader "[DONE] POST /login 完成"; [ "$status" -eq 0 ]
  DK_AGENT=login-qa run dk-msg login-frontend "[QUESTION] 錯誤碼用哪一套？"; [ "$status" -eq 0 ]
  [ "$(watch_pid_now)" = "$dead" ]
  refute_grep 'watch died\|watch restarted' "$d/process.md"
}
@test "AC5 ⑧: 任務結案後（.panes 已刪）送訊息不叫回守望：process 沒有新的 watch 行、pid 不變" {
  d=$(msg_task)
  unset DK_NO_WATCH; dead=$(kill_dead_watch); rm "$d/.panes"
  DK_AGENT=login-qa run dk-msg login-frontend "[QUESTION] 錯誤碼用哪一套？"; [ "$status" -eq 0 ]
  DK_MSG_TRIES=1 HERDR_STUB_FAIL="agent wait" DK_AGENT=login-qa run dk-msg login-frontend "[QUESTION] 在嗎"; [ "$status" -eq 1 ]
  [ "$(watch_pid_now)" = "$dead" ]
  refute_grep 'watch' "$d/process.md"
  refute pgrep -f "$PROJECT/.dkbo/bin/dk-watch"
}
