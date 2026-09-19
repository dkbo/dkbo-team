load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入); export DK_TASK_DIR="$d"
  printf 'login-qa wC:p3 %s review 1 2\n' "$(date +%s)" > "$d/.panes"
  echo "2026-09-10T10:00 spawn login-qa (agy M)" >> "$d/process.md"
  sed -i 's/"blocked"/"idle"/' "$HERDR_STUB_RESPONSES/agent_list.json"   # herdr 認不出來的那種卡法
}
teardown() { teardown_project; }

screen() { printf '{"id":"cli:agent:read","result":{"read":{"text":"%s"}}}\n' "$1" > "$HERDR_STUB_RESPONSES/agent_read.json"; }

# --- kind 畫面特徵 ---

@test "dk_kind_re 給出各 kind 的審批與額度特徵，未知 kind 退回通用式" {
  run bash -c '. "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/kinds.sh"; dk_kind_re agy block'
  [ "$status" -eq 0 ]; [[ "$output" == *"Requesting permission"* ]]
  run bash -c '. "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/kinds.sh"; dk_kind_re codex quota'
  [ "$status" -eq 0 ]; [[ "$output" == *"usage limit"* ]]
  run bash -c '. "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/kinds.sh"; dk_kind_re "" block'
  [ "$status" -eq 0 ]; [ -n "$output" ]          # 未知 kind 仍要有式子，不能空手而回
}

# --- tick：畫面成為 blocked 的第二訊號（panova2 的 agy） ---

@test "審批 UI 在畫面上、herdr 卻回 idle：仍偵測得到" {
  screen 'Requesting permission for:\n rg foo src\nRun this command?\n> 1. Yes'
  dk-watch --once; [ -f "$d/.blocked/login-qa" ]
  echo 0 > "$d/.blocked/login-qa"; dk-watch --once
  grep -q '^agent prompt leader-login \[BLOCKED\] from dk-watch: login-qa' "$HERDR_STUB_LOG"
}
@test "畫面乾淨時 marker 照樣清掉，不會卡住不放" {
  screen 'thinking...'
  mkdir -p "$d/.blocked"; echo 0 > "$d/.blocked/login-qa"
  dk-watch --once; [ ! -f "$d/.blocked/login-qa" ]
}

# --- tick：額度不必等 DK_REVIEW_TIMEOUT_MIN ---

@test "撞額度的畫面當場熔斷並送 [LIMIT]，不等逾時" {
  screen "You've hit your usage limit. Upgrade to Plus to continue"
  dk-watch --once
  grep -q '^agent prompt leader-login \[LIMIT\] from dk-watch: login-qa 撞額度' "$HERDR_STUB_LOG"
  grep -q '^DK_KIND_DOWN="agy"$' "$d/.task.env"
  grep -q ' limit login-qa → kind agy down$' "$d/process.md"
}
@test "[LIMIT] 只送一次、桌面通知也只響一次" {
  screen "You've hit your usage limit"
  dk-watch --once; dk-watch --once
  [ "$(grep -c '\[LIMIT\] from dk-watch: login-qa' "$HERDR_STUB_LOG")" -eq 1 ]
  [ "$(grep -c '^notification show dkbo: login-qa limit' "$HERDR_STUB_LOG")" -eq 1 ]
  [ "$(grep -c ' limit login-qa → kind agy down$' "$d/process.md")" -eq 1 ]
}
@test "沒送到的 [LIMIT] 下一 tick 重試，熔斷本身不等領導" {
  screen "rate limit reached"
  HERDR_STUB_FAIL="agent wait" dk-watch --once
  grep -q '^DK_KIND_DOWN="agy"$' "$d/.task.env"
  ! grep -q '^delivered$' "$d/.blocked/login-qa.limit"
  dk-watch --once; grep -q '^delivered$' "$d/.blocked/login-qa.limit"
}
@test "額度優先於審批：兩種字樣同時在畫面上時判額度" {
  screen "Run this command?\nYou've hit your usage limit"
  dk-watch --once
  grep -q '\[LIMIT\]' "$HERDR_STUB_LOG"; ! grep -q '\[BLOCKED\]' "$HERDR_STUB_LOG"
}

# --- AC13: state 已 status: done 的 agent 不做額度與審批的畫面判定（highfix 第二次誤判）---

@test "AC13: state 已 done 的 agent，畫面含 usage limit 不觸發 LIMIT" {
  screen "You've hit your usage limit"          # login-qa 這裡的 agent_status 是 idle
  printf 'status: done\n' > "$d/state/qa.md"
  dk-watch --once
  refute_grep '\[LIMIT\] from dk-watch: login-qa' "$HERDR_STUB_LOG"
  [ ! -f "$d/.blocked/login-qa.limit" ]
}
@test "AC13: 同條件 state working 時 LIMIT 照常" {
  screen "You've hit your usage limit"
  printf 'status: working\n' > "$d/state/qa.md"
  dk-watch --once
  grep -q '\[LIMIT\] from dk-watch: login-qa' "$HERDR_STUB_LOG"
  [ -f "$d/.blocked/login-qa.limit" ]
}

# --- AC14: 領導解除熔斷後 .limit 標記留著，同一畫面下一輪不重新熔斷、不重送 [LIMIT] ---

@test "AC14: 解除熔斷後同一畫面下一輪不重新熔斷、不重送 LIMIT" {
  screen "You've hit your usage limit"
  dk-watch --once
  grep -q '^DK_KIND_DOWN="agy"$' "$d/.task.env"
  [ -f "$d/.blocked/login-qa.limit" ]
  sed -i 's/^DK_KIND_DOWN=.*/DK_KIND_DOWN=""/' "$d/.task.env"
  dk-watch --once
  grep -q '^DK_KIND_DOWN=""$' "$d/.task.env"
  [ "$(grep -c '\[LIMIT\] from dk-watch: login-qa' "$HERDR_STUB_LOG")" -eq 1 ]
  [ "$(grep -c '^notification show dkbo: login-qa limit' "$HERDR_STUB_LOG")" -eq 1 ]
}

# --- timeout：卡審批不該被當成 kind 掛了（panova2 誤熔斷 agy） ---

@test "reviewer 逾時但畫面是審批 UI：報 BLOCKED、不熔斷 kind" {
  printf 'login-reviewer-c wC:p4 %s review 1 3\n' "$(( $(date +%s) - 1500 ))" > "$d/.panes"
  echo "2026-09-10T10:00 spawn login-reviewer-c (agy L) isolated" >> "$d/process.md"
  screen 'Requesting permission for:\nRun this command?'
  dk-watch --once
  grep -q '^DK_KIND_DOWN=""$' "$d/.task.env"
  ! grep -q 'kind agy down' "$d/process.md"
  grep -q '\[BLOCKED\] from dk-watch: login-reviewer-c' "$HERDR_STUB_LOG"
}
@test "reviewer 逾時且畫面沒話說：維持原本的熔斷" {
  printf 'login-reviewer-c wC:p4 %s review 1 3\n' "$(( $(date +%s) - 1500 ))" > "$d/.panes"
  echo "2026-09-10T10:00 spawn login-reviewer-c (agy L) isolated" >> "$d/process.md"
  screen 'thinking...'
  dk-watch --once
  grep -q '^DK_KIND_DOWN="agy"$' "$d/.task.env"
  grep -q '\[TIMEOUT\] from dk-watch: login-reviewer-c' "$HERDR_STUB_LOG"
}

# --- --events：常駐訂閱器 ---

@test "--events --once 為每個 pane 掛上 wait-output 訂閱" {
  screen 'thinking...'
  run dk-watch --events --once; [ "$status" -eq 0 ]
  grep -q '^pane wait-output wC:p3 --regex .*Requesting permission' "$HERDR_STUB_LOG"
}
@test "--events 訂閱命中審批就當場處理，不必等 tick" {
  printf '{"id":"cli:pane:wait-output","result":{"matched_line":"Run this command?","pane_id":"wC:p3"}}\n' \
    > "$HERDR_STUB_RESPONSES/pane_wait-output.json"
  screen 'Requesting permission for:\nRun this command?'
  dk-watch --events --once
  [ -f "$d/.blocked/login-qa" ]
  grep -q '^agent prompt leader-login \[BLOCKED\] from dk-watch: login-qa' "$HERDR_STUB_LOG"
}
@test "--events 訂閱逾時（沒命中）不留下任何痕跡" {
  screen 'thinking...'
  HERDR_STUB_FAIL="pane wait-output" dk-watch --events --once
  [ ! -f "$d/.blocked/login-qa" ]
  ! grep -q 'BLOCKED\|LIMIT' "$HERDR_STUB_LOG"
}

# --- AC4: 事件路徑同樣受 agent_status 前提約束 ---

@test "AC4: 事件路徑對 working 的 agent 跳過額度判定" {
  printf 'login-frontend wC:p2\n' > "$d/.panes"   # 只留一個 pane，agent_list.json 裡它預設是 working
  printf '{"id":"cli:pane:wait-output","result":{"matched_line":"usage limit","pane_id":"wC:p2"}}\n' \
    > "$HERDR_STUB_RESPONSES/pane_wait-output.json"
  screen "You've hit your usage limit"
  dk-watch --events --once
  [ ! -f "$d/.blocked/login-frontend.limit" ]
  refute_grep '\[LIMIT\]' "$HERDR_STUB_LOG"
}
@test "AC4: 事件路徑對 idle 的 agent 額度判定照常" {
  printf 'login-frontend wC:p2\n' > "$d/.panes"
  sed -i 's/"name":"login-frontend","agent_status":"working"/"name":"login-frontend","agent_status":"idle"/' \
    "$HERDR_STUB_RESPONSES/agent_list.json"
  printf '{"id":"cli:pane:wait-output","result":{"matched_line":"usage limit","pane_id":"wC:p2"}}\n' \
    > "$HERDR_STUB_RESPONSES/pane_wait-output.json"
  screen "You've hit your usage limit"
  dk-watch --events --once
  [ -f "$d/.blocked/login-frontend.limit" ]
  grep -q '\[LIMIT\] from dk-watch: login-frontend' "$HERDR_STUB_LOG"
}
@test "--events --ensure 起一個訂閱器並且冪等" {
  unset DK_NO_WATCH
  run dk-watch --events --ensure; [ "$status" -eq 0 ]; [[ "$output" == *started* ]]
  pid=$(sed -n 's/^DK_EVENTS_PID="\([0-9]*\)"$/\1/p' "$d/.task.env"); [[ "$pid" =~ ^[0-9]+$ ]]
  ps -p "$pid" -o args= | grep -q -- '--events'
  run dk-watch --events --ensure; [ "$status" -eq 0 ]; [[ "$output" == *"running (pid $pid)"* ]]
  kill "$pid" 2>/dev/null || true
}
@test "--ensure 同時把訂閱器帶起來" {
  unset DK_NO_WATCH
  run dk-watch --ensure; [ "$status" -eq 0 ]
  wpid=$(sed -n 's/^DK_WATCH_PID="\([0-9]*\)"$/\1/p' "$d/.task.env")
  epid=$(sed -n 's/^DK_EVENTS_PID="\([0-9]*\)"$/\1/p' "$d/.task.env")
  [[ "$epid" =~ ^[0-9]+$ ]]; ps -p "$epid" -o args= | grep -q -- '--events'
  kill "$wpid" "$epid" 2>/dev/null || true
}
@test "--events 認得 DK_NO_WATCH" {
  run dk-watch --events --ensure; [ "$status" -eq 0 ]; [[ "$output" == *disabled* ]]
}

# --- 兩條命脈的生老病死 ---

@test "dk-task-new 起輪詢也起訂閱，兩個 pid 都記進 .task.env" {
  rm -rf "$DK_ROOT/tasks/"*-login "$DK_ROOT/.sessions/wB:p1"; unset DK_TASK_DIR
  git -C "$PROJECT" worktree remove --force "$WORKTREE_PATH"; git -C "$PROJECT" branch -D dk/login >/dev/null
  DK_NO_WATCH= run dk-task-new login 使用者登入; [ "$status" -eq 0 ]
  wpid=$(sed -n 's/^DK_WATCH_PID="\([0-9]*\)"$/\1/p' "$output/.task.env")
  epid=$(sed -n 's/^DK_EVENTS_PID="\([0-9]*\)"$/\1/p' "$output/.task.env")
  [[ "$wpid" =~ ^[0-9]+$ ]]; [[ "$epid" =~ ^[0-9]+$ ]]; [ "$wpid" != "$epid" ]
  ps -p "$epid" -o args= | grep -q -- '--events'
  kill "$wpid" "$epid" 2>/dev/null || true
}

@test "dk-task-close 兩條都收，訂閱器不會變成沒人管的常駐行程" {
  unset DK_NO_WATCH
  git -C "$PROJECT" -c user.name=t -c user.email=t@t commit -q --allow-empty -m base
  printf '| 2026-09-10 | 使用者登入 | task | running | — |\n' >> "$DK_ROOT/tasks/INDEX.md"
  dk-watch --ensure >/dev/null
  epid=$(sed -n 's/^DK_EVENTS_PID="\([0-9]*\)"$/\1/p' "$d/.task.env")
  [[ "$epid" =~ ^[0-9]+$ ]]; kill -0 "$epid"
  : > "$d/.panes"; echo '# r' > "$d/report.md"
  run dk-task-close; [ "$status" -eq 0 ]
  for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$epid" 2>/dev/null || break; done
  ! kill -0 "$epid" 2>/dev/null
}
