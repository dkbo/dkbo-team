load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); printf 'login-frontend wC:p2\nlogin-qa wC:p3\n' > "$d/.panes"; export DK_TASK_DIR="$d"; }
teardown() { teardown_project; }

@test "first sighting records marker, no notify" {
  run dk-watch --once; [ "$status" -eq 0 ]
  [ -f "$d/.blocked/login-qa" ]; [ ! -f "$d/.blocked/login-frontend" ]
  ! grep -q '^notification show' "$HERDR_STUB_LOG"
}
@test "blocked past threshold notifies once" {
  mkdir -p "$d/.blocked"; echo 0 > "$d/.blocked/login-qa"
  dk-watch --once; dk-watch --once
  [ "$(grep -c '^notification show dkbo: login-qa blocked' "$HERDR_STUB_LOG")" -eq 1 ]
  grep -q '^agent prompt leader-login \[BLOCKED\] from dk-watch: login-qa' "$HERDR_STUB_LOG"
  grep -q 'blocked login-qa' "$d/process.md"
}
@test "[BLOCKED] 的 pane 退路優先讀 DK_LEADER_PANE" {
  echo 'DK_LEADER_PANE="wC:p1"' >> "$d/.task.env"
  mkdir -p "$d/.blocked"; echo 0 > "$d/.blocked/login-qa"
  HERDR_STUB_MISSING="leader-login" dk-watch --once
  grep -q '^agent prompt wC:p1 \[BLOCKED\] from dk-watch: login-qa' "$HERDR_STUB_LOG"
  refute_grep '^agent prompt wB:p1 ' "$HERDR_STUB_LOG"
}
@test "沒有 DK_LEADER_PANE 的舊任務，[BLOCKED] 退回 DK_ROOT_PANE" {
  mkdir -p "$d/.blocked"; echo 0 > "$d/.blocked/login-qa"
  HERDR_STUB_MISSING="leader-login" dk-watch --once
  grep -q '^agent prompt wB:p1 \[BLOCKED\] from dk-watch: login-qa' "$HERDR_STUB_LOG"
}
@test "marker clears when unblocked" {
  mkdir -p "$d/.blocked"; echo 0 > "$d/.blocked/login-qa"
  sed -i 's/"blocked"/"idle"/' "$HERDR_STUB_RESPONSES/agent_list.json"
  dk-watch --once; [ ! -f "$d/.blocked/login-qa" ]
}
@test "dk-task-new launches dk-watch and records its pid" {
  rm -rf "$DK_ROOT/tasks/"*-login "$DK_ROOT/.sessions/wB:p1"; unset DK_TASK_DIR
  git -C "$PROJECT" worktree remove --force "$WORKTREE_PATH"; git -C "$PROJECT" branch -D dk/login >/dev/null
  DK_NO_WATCH= run dk-task-new login 使用者登入; [ "$status" -eq 0 ]
  pid=$(sed -n 's/^DK_WATCH_PID="\([0-9]*\)"$/\1/p' "$output/.task.env"); [[ "$pid" =~ ^[0-9]+$ ]]
  kill "$pid" 2>/dev/null || true
}
wpid() { sed -n 's/^DK_WATCH_PID="\([0-9]*\)"$/\1/p' "$d/.task.env"; }

@test "--ensure starts the watcher and records its pid" {
  unset DK_NO_WATCH
  run dk-watch --ensure; [ "$status" -eq 0 ]; [[ "$output" == *restarted* ]]
  pid=$(wpid); [[ "$pid" =~ ^[0-9]+$ ]]
  ps -p "$pid" -o args= | grep -q dk-watch
  grep -q 'watch restarted' "$d/process.md"
  kill "$pid" 2>/dev/null || true
}
@test "--ensure is a no-op while the watcher is alive" {
  unset DK_NO_WATCH
  dk-watch --ensure >/dev/null; pid1=$(wpid)
  run dk-watch --ensure; [ "$status" -eq 0 ]; [[ "$output" == *"running (pid $pid1)"* ]]
  [ "$(wpid)" = "$pid1" ]
  kill "$pid1" 2>/dev/null || true
}
@test "--ensure restarts a watcher whose pid is gone" {
  unset DK_NO_WATCH
  sh -c 'exit 0' & dead=$!; wait "$dead" 2>/dev/null || true
  sed -i "s/^DK_WATCH_PID=.*/DK_WATCH_PID=\"$dead\"/" "$d/.task.env"
  run dk-watch --ensure; [ "$status" -eq 0 ]; [[ "$output" == *restarted* ]]
  pid=$(wpid); [ "$pid" != "$dead" ]
  kill "$pid" 2>/dev/null || true
}
@test "--ensure does not trust a recycled pid that is not a watcher" {
  unset DK_NO_WATCH
  sleep 30 & other=$!
  sed -i "s/^DK_WATCH_PID=.*/DK_WATCH_PID=\"$other\"/" "$d/.task.env"
  run dk-watch --ensure; [ "$status" -eq 0 ]; [[ "$output" == *restarted* ]]
  pid=$(wpid); [ "$pid" != "$other" ]
  kill "$other" "$pid" 2>/dev/null || true
}
@test "--ensure honours DK_NO_WATCH" {
  run dk-watch --ensure; [ "$status" -eq 0 ]; [[ "$output" == *disabled* ]]
  grep -q '^DK_WATCH_PID=""$' "$d/.task.env"
}

@test "dk-spawn ensures the watcher is alive" {
  unset DK_NO_WATCH
  run dk-spawn frontend cart; [ "$status" -eq 0 ]
  pid=$(wpid); [[ "$pid" =~ ^[0-9]+$ ]]; ps -p "$pid" -o args= | grep -q dk-watch
  kill "$pid" 2>/dev/null || true
}
@test "dk-wave-open ensures the watcher is alive" {
  unset DK_NO_WATCH; fixture_brief "$d"; : > "$d/.panes"
  run dk-wave-open 1; [ "$status" -eq 0 ]
  pid=$(wpid); [[ "$pid" =~ ^[0-9]+$ ]]; ps -p "$pid" -o args= | grep -q dk-watch
  kill "$pid" 2>/dev/null || true
}
@test "dk-resume prints the watcher's status once" {
  run dk-resume; [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^watch: ')" -eq 1 ]
  [[ "$output" == *"watch: disabled"* ]]
}

@test "tick survives an agent list without agents array" {
  echo '{"id":"cli:agent:list","result":{}}' > "$HERDR_STUB_RESPONSES/agent_list.json"
  run dk-watch --once; [ "$status" -eq 0 ]
  [ ! -f "$d/.blocked/login-qa" ]
}

# --- AC1/AC2/AC3: agent_status 前提 —— working 時不做畫面判定，狀態未知時照舊判定 ---
# panova2/highfix 誤判的根因：正在工作時畫面上的字（自己寫的測試字串、殘留輸出）被
# 當成撞額度或卡審批。agent_status 是比畫面更可信的第一訊號，working 就不必看畫面。

screen() { printf '{"id":"cli:agent:read","result":{"read":{"text":"%s"}}}\n' "$1" > "$HERDR_STUB_RESPONSES/agent_read.json"; }
set_status() { # AGENT STATUS — 改 agent_list.json 裡單一 agent 的 agent_status
  sed -i "s/\"name\":\"$1\",\"agent_status\":\"[a-z]*\"/\"name\":\"$1\",\"agent_status\":\"$2\"/" "$HERDR_STUB_RESPONSES/agent_list.json"
}

@test "AC1: agent_status working 時額度畫面不觸發 LIMIT" {
  screen "You've hit your usage limit"        # login-frontend 預設就是 working
  dk-watch --once
  refute_grep '\[LIMIT\] from dk-watch: login-frontend' "$HERDR_STUB_LOG"
  [ ! -f "$d/.blocked/login-frontend.limit" ]
}
@test "AC1: 同一畫面把狀態改成 idle，LIMIT 照常" {
  screen "You've hit your usage limit"
  set_status login-frontend idle
  dk-watch --once
  grep -q '\[LIMIT\] from dk-watch: login-frontend' "$HERDR_STUB_LOG"
  [ -f "$d/.blocked/login-frontend.limit" ]
}
@test "AC2: agent_status working 時審批畫面不觸發 BLOCKED（immediate 路徑）" {
  screen 'Requesting permission for:\nRun this command?'
  dk-watch --once
  [ ! -f "$d/.blocked/login-frontend" ]
  refute_grep '\[BLOCKED\] from dk-watch: login-frontend' "$HERDR_STUB_LOG"
}
@test "AC2: 同一畫面把狀態改成 idle，BLOCKED 照常（immediate 路徑）" {
  screen 'Requesting permission for:\nRun this command?'
  set_status login-frontend idle
  dk-watch --once
  [ -f "$d/.blocked/login-frontend" ]
  grep -q '\[BLOCKED\] from dk-watch: login-frontend' "$HERDR_STUB_LOG"
}
@test "AC2: herdr 直接回 blocked 的既有路徑不受前提影響" {
  screen 'thinking...'   # 畫面乾淨，靠 agent_status=blocked 本身判定
  mkdir -p "$d/.blocked"; echo 0 > "$d/.blocked/login-qa"
  dk-watch --once; dk-watch --once
  grep -q '\[BLOCKED\] from dk-watch: login-qa' "$HERDR_STUB_LOG"
}
@test "AC3 unknown-status: agent 不在 agent list 時照舊做畫面判定" {
  screen "You've hit your usage limit"
  printf 'login-mystery wC:p9\n' >> "$d/.panes"
  dk-watch --once
  grep -q '\[LIMIT\] from dk-watch: login-mystery' "$HERDR_STUB_LOG"
  [ -f "$d/.blocked/login-mystery.limit" ]
}

chore_rec() { # $1=agent [$2=leader] — 一個執行記錄檔，不跑 dk-chore
  mkdir -p "$DK_ROOT/.sessions/chores" "$DK_ROOT/tasks/_chores"
  { echo "file=$DK_ROOT/tasks/_chores/2026-09-10-$1.md"
    echo "instr=翻譯 README"; echo "branch=-"; echo "workspace=-"; echo "pane=wC:p3"
    echo "leader=${2:-}"
  } > "$DK_ROOT/.sessions/chores/$1"
}
blocked_chore() { sed -i 's/login-qa/chore-frontend-1/' "$HERDR_STUB_RESPONSES/agent_list.json"; }
cmark="$DK_ROOT/.sessions/chores.blocked"

@test "--chores: first sighting records a marker, no notify" {
  blocked_chore; chore_rec chore-frontend-1 leader-login
  run dk-watch --chores --once; [ "$status" -eq 0 ]
  [ -f "$DK_ROOT/.sessions/chores.blocked/chore-frontend-1" ]
  ! grep -q '^notification show' "$HERDR_STUB_LOG"
}
@test "--chores: blocked past the threshold notifies the chore's own leader once" {
  blocked_chore; chore_rec chore-frontend-1 leader-login
  mkdir -p "$DK_ROOT/.sessions/chores.blocked"; echo 0 > "$DK_ROOT/.sessions/chores.blocked/chore-frontend-1"
  dk-watch --chores --once; dk-watch --chores --once
  [ "$(grep -c '^notification show dkbo: chore-frontend-1 blocked' "$HERDR_STUB_LOG")" -eq 1 ]
  [ "$(grep -c '^agent prompt leader-login \[BLOCKED\] from dk-watch: chore-frontend-1' "$HERDR_STUB_LOG")" -eq 1 ]
  grep -q 'chore-frontend-1' "$DK_ROOT/tasks/_chores/messages.log"
}
@test "--chores: 記錄檔的 leader 是空的時仍發桌面通知，且不誤標 delivered" {
  blocked_chore; chore_rec chore-frontend-1
  mkdir -p "$DK_ROOT/.sessions/chores.blocked"; echo 0 > "$DK_ROOT/.sessions/chores.blocked/chore-frontend-1"
  run dk-watch --chores --once; [ "$status" -eq 0 ]
  grep -q '^notification show dkbo: chore-frontend-1 blocked' "$HERDR_STUB_LOG"
  ! grep -q '^delivered$' "$DK_ROOT/.sessions/chores.blocked/chore-frontend-1"
}
@test "--chores: 沒有記錄檔時守望直接退出" {
  blocked_chore
  run dk-watch --chores --once; [ "$status" -eq 0 ]
  [ ! -f "$DK_ROOT/.sessions/chores.blocked/chore-frontend-1" ]
}
@test "--chores: 員工重寫 chore 檔不影響守望名單" {
  blocked_chore; chore_rec chore-frontend-1 leader-login
  echo '# 我的報告' > "$DK_ROOT/tasks/_chores/2026-09-10-chore-frontend-1.md"   # 員工整份重寫
  run dk-watch --chores --once; [ "$status" -eq 0 ]
  [ -f "$DK_ROOT/.sessions/chores.blocked/chore-frontend-1" ]                    # 仍在守望名單裡
}
@test "--chores --ensure starts one chore watcher and is idempotent" {
  unset DK_NO_WATCH; chore_rec chore-frontend-1 leader-login
  run dk-watch --chores --ensure; [ "$status" -eq 0 ]; [[ "$output" == *"chores started"* ]]
  pid=$(cat "$DK_ROOT/.sessions/chores.watch.pid"); ps -p "$pid" -o args= | grep -q -- '--chores'
  run dk-watch --chores --ensure; [ "$status" -eq 0 ]; [[ "$output" == *"chores running (pid $pid)"* ]]
  [ "$(cat "$DK_ROOT/.sessions/chores.watch.pid")" = "$pid" ]
  kill "$pid" 2>/dev/null || true
}
@test "dk-chore records its leader and ensures the chore watcher" {
  unset DK_NO_WATCH
  run dk-chore frontend "翻譯 README"; [ "$status" -eq 0 ]
  grep -q '^leader=wB:p1$' "$DK_ROOT/.sessions/chores/chore-frontend-1"
  pid=$(cat "$DK_ROOT/.sessions/chores.watch.pid"); ps -p "$pid" -o args= | grep -q -- '--chores'
  kill "$pid" 2>/dev/null || true
}

old=$(( $(date +%s) - 1500 ))   # 25 minutes ago
quota_screen() { echo '{"result":{"read":{"text":"You have hit your usage limit. Rate limit reached."}}}' > "$HERDR_STUB_RESPONSES/agent_read.json"; }
reviewer_row() { printf 'login-reviewer-b wC:p4 %s review 1 3\n' "$1" >> "$d/.panes"; echo "2026-09-10T10:00 spawn login-reviewer-b (codex M) override-kind isolated" >> "$d/process.md"; }

@test "reviewer past DK_REVIEW_TIMEOUT_MIN is reported once with (quota?) and its kind goes down" {
  quota_screen; reviewer_row "$old"
  dk-watch --once; dk-watch --once
  [ "$(grep -c '^agent prompt leader-login \[TIMEOUT\] from dk-watch: login-reviewer-b 逾時 (quota?)$' "$HERDR_STUB_LOG")" -eq 1 ]
  [ "$(grep -c '^notification show dkbo: login-reviewer-b timeout' "$HERDR_STUB_LOG")" -eq 1 ]
  grep -q '^agent read login-reviewer-b --lines 30$' "$HERDR_STUB_LOG"
  grep -q ' timeout login-reviewer-b (quota?) → kind codex down$' "$d/process.md"; grep -q '^DK_KIND_DOWN="codex"$' "$d/.task.env"
  [ -f "$d/.blocked/login-reviewer-b.timeout" ]
}
@test "no quota words → no (quota?) tag; kinds accumulate without duplicates" {
  echo '{"result":{"read":{"text":"thinking..."}}}' > "$HERDR_STUB_RESPONSES/agent_read.json"
  sed -i 's/^DK_KIND_DOWN=.*/DK_KIND_DOWN="agy"/' "$d/.task.env"; reviewer_row "$old"
  dk-watch --once
  grep -q '^agent prompt leader-login \[TIMEOUT\] from dk-watch: login-reviewer-b 逾時$' "$HERDR_STUB_LOG"; grep -q '^DK_KIND_DOWN="agy codex"$' "$d/.task.env"
}
@test "fresh reviewers, done reviewers, qa and legacy rows never time out" {
  reviewer_row "$(date +%s)"; dk-watch --once; ! grep -q 'TIMEOUT' "$HERDR_STUB_LOG"
  sed -i "s/^login-reviewer-b wC:p4 [0-9]*/login-reviewer-b wC:p4 $old/" "$d/.panes"; printf 'status: done\n' > "$d/state/reviewer-b.md"
  dk-watch --once; ! grep -q 'TIMEOUT' "$HERDR_STUB_LOG"
  printf 'login-qa wC:p3 %s review 1 2\nlogin-frontend wC:p2\n' "$old" > "$d/.panes"; dk-watch --once; ! grep -q 'TIMEOUT' "$HERDR_STUB_LOG"
}
@test "a shorter DK_REVIEW_TIMEOUT_MIN is honoured" {
  echo 'DK_REVIEW_TIMEOUT_MIN="1"' >> "$DK_ROOT/settings.env"; reviewer_row "$(( $(date +%s) - 120 ))"
  dk-watch --once; grep -q 'TIMEOUT' "$HERDR_STUB_LOG"
}
@test "a reviewer spawned without an alias times out too" {
  printf 'login-reviewer wC:p4 %s review 1 3\n' "$old" >> "$d/.panes"; echo "2026-09-10T10:00 spawn login-reviewer (claude M) isolated" >> "$d/process.md"
  dk-watch --once; grep -q '^agent prompt leader-login \[TIMEOUT\] from dk-watch: login-reviewer 逾時' "$HERDR_STUB_LOG"
}

# --- 送給領導的通知：等 idle，沒送到就重試（BACKLOG 2026-09-11） ---

@test "blocked: waits for the leader to be idle before prompting" {
  mkdir -p "$d/.blocked"; echo 0 > "$d/.blocked/login-qa"
  dk-watch --once
  grep -q '^agent wait leader-login --until idle --until done --timeout 5000$' "$HERDR_STUB_LOG"
}

@test "blocked: an undelivered prompt retries next tick without repeating the desktop notification" {
  mkdir -p "$d/.blocked"; echo 0 > "$d/.blocked/login-qa"
  HERDR_STUB_FAIL="agent wait" dk-watch --once
  HERDR_STUB_FAIL="agent wait" dk-watch --once
  [ "$(grep -c '^notification show dkbo: login-qa blocked' "$HERDR_STUB_LOG")" -eq 1 ]
  [ "$(grep -c ' blocked login-qa$' "$d/process.md")" -eq 1 ]
  ! grep -q '^delivered$' "$d/.blocked/login-qa"
  dk-watch --once                      # 領導終於閒下來
  grep -q '^agent prompt leader-login \[BLOCKED\] from dk-watch: login-qa' "$HERDR_STUB_LOG"
  grep -q '^delivered$' "$d/.blocked/login-qa"
}

@test "timeout: the kind goes down and is logged once even when the prompt never lands" {
  quota_screen; reviewer_row "$old"
  HERDR_STUB_FAIL="agent wait" dk-watch --once
  grep -q '^DK_KIND_DOWN="codex"$' "$d/.task.env"
  [ "$(grep -c ' timeout login-reviewer-b (quota?) → kind codex down$' "$d/process.md")" -eq 1 ]
  ! grep -q '^delivered$' "$d/.blocked/login-reviewer-b.timeout"
  HERDR_STUB_FAIL="agent wait" dk-watch --once
  [ "$(grep -c '^notification show dkbo: login-reviewer-b timeout' "$HERDR_STUB_LOG")" -eq 1 ]
  [ "$(grep -c ' timeout login-reviewer-b (quota?) → kind codex down$' "$d/process.md")" -eq 1 ]
  dk-watch --once
  [ "$(grep -c '^agent prompt leader-login \[TIMEOUT\] from dk-watch: login-reviewer-b 逾時 (quota?)$' "$HERDR_STUB_LOG")" -eq 1 ]
  grep -q '^delivered$' "$d/.blocked/login-reviewer-b.timeout"
}

@test "--chores: an undelivered prompt retries and only logs the message once it lands" {
  blocked_chore; chore_rec chore-frontend-1 leader-login
  mkdir -p "$DK_ROOT/.sessions/chores.blocked"; echo 0 > "$DK_ROOT/.sessions/chores.blocked/chore-frontend-1"
  HERDR_STUB_FAIL="agent wait" dk-watch --chores --once
  ! grep -q '^delivered$' "$DK_ROOT/.sessions/chores.blocked/chore-frontend-1"
  ! grep -q 'chore-frontend-1' "$DK_ROOT/tasks/_chores/messages.log" 2>/dev/null
  dk-watch --chores --once
  [ "$(grep -c '^agent prompt leader-login \[BLOCKED\] from dk-watch: chore-frontend-1' "$HERDR_STUB_LOG")" -eq 1 ]
  [ "$(grep -c '^notification show dkbo: chore-frontend-1 blocked' "$HERDR_STUB_LOG")" -eq 1 ]
  [ "$(grep -c 'chore-frontend-1' "$DK_ROOT/tasks/_chores/messages.log")" -eq 1 ]
  grep -q '^delivered$' "$DK_ROOT/.sessions/chores.blocked/chore-frontend-1"
}

@test "整波逾時：超過 DK_WAVE_TIMEOUT_MIN 推一次 [TIMEOUT] wave 給領導" {
  echo 'DK_WAVE_TIMEOUT_MIN="30"' >> "$DK_ROOT/settings.env"
  sed -i 's/^DK_WAVE=.*/DK_WAVE="1"/' "$d/.task.env"
  sed -i "s/^DK_WAVE_STARTED=.*/DK_WAVE_STARTED=\"$(( $(date +%s) - 60 ))\"/" "$d/.task.env" 2>/dev/null || \
    echo "DK_WAVE_STARTED=\"$(( $(date +%s) - 60 ))\"" >> "$d/.task.env"
  dk-watch --once; ! grep -q 'TIMEOUT. from dk-watch: wave' "$HERDR_STUB_LOG"   # 才過 1 分鐘
  sed -i "s/^DK_WAVE_STARTED=.*/DK_WAVE_STARTED=\"$(( $(date +%s) - 2000 ))\"/" "$d/.task.env"
  dk-watch --once; dk-watch --once
  [ "$(grep -c '^agent prompt leader-login \[TIMEOUT\] from dk-watch: wave 1 ' "$HERDR_STUB_LOG")" -eq 1 ]
  grep -q 'timeout wave 1' "$d/process.md"
}

@test "herdr agent list 失敗時留下痕跡，而不是讓守望靜靜變成 no-op" {
  # 0.1.5 的 CHANGELOG 自己點名過：herdr 呼叫的失敗是刻意吞掉的，換版時的表現不是報錯，
  # 而是 dk-watch 永遠偵測不到 blocked —— 整套安全網變成 no-op 而看起來一切正常
  HERDR_STUB_FAIL="agent list" run dk-watch --once
  [ "$status" -eq 0 ]                       # 仍然不崩、不擋住別的事
  grep -q 'herdr-degraded: agent list' "$d/process.md"
  [[ "$output" == *"降級"* ]]
}
@test "降級只記一次，不會每個 tick 洗版" {
  HERDR_STUB_FAIL="agent list" dk-watch --once 2>/dev/null || true
  HERDR_STUB_FAIL="agent list" dk-watch --once 2>/dev/null || true
  [ "$(grep -c 'herdr-degraded' "$d/process.md")" -le 2 ]   # 每個行程樹一次
}

# panova2/sportswitch：領導 pane 沒被註冊成 leader-<short>，守望的三個出口全部靜默失效 ——
# reviewer-b 逾時的 .timeout 標記躺在磁碟上沒有 delivered，領導是自己發現它沒動的。
@test "blocked notification falls back to the leader pane id when leader-<short> is gone" {
  mkdir -p "$d/.blocked"; echo 0 > "$d/.blocked/login-qa"
  HERDR_STUB_MISSING="leader-login" dk-watch --once
  grep -q '^agent prompt wB:p1 \[BLOCKED\] from dk-watch: login-qa 卡在審批$' "$HERDR_STUB_LOG"
  grep -q '^delivered$' "$d/.blocked/login-qa"
}
@test "reviewer timeout falls back to the leader pane id too" {
  quota_screen; reviewer_row "$old"
  HERDR_STUB_MISSING="leader-login" dk-watch --once
  grep -q '^agent prompt wB:p1 \[TIMEOUT\] from dk-watch: login-reviewer-b 逾時 (quota?)$' "$HERDR_STUB_LOG"
  grep -q '^delivered$' "$d/.blocked/login-reviewer-b.timeout"
}
@test "still leaves no delivered mark when the pane id is unreachable too" {
  mkdir -p "$d/.blocked"; echo 0 > "$d/.blocked/login-qa"
  HERDR_STUB_MISSING="leader-login wB:p1" dk-watch --once
  ! grep -q '^delivered$' "$d/.blocked/login-qa"
}

# --- dev 波聚合：全員完成才推一則，取代員工逐筆的 [DONE] ---

dev_wave() {   # 兩個 dev、一個 qa，波 1 開著；全員 idle、畫面乾淨
  local now; now=$(date +%s)
  printf 'login-backend wC:p2 %s dev 1 1\nlogin-frontend wC:p5 %s dev 1 2\nlogin-qa wC:p3 %s review 1 3\n' \
    "$now" "$now" "$now" > "$d/.panes"
  sed -i 's/"blocked"/"idle"/' "$HERDR_STUB_RESPONSES/agent_list.json"
  sed -i 's/^DK_WAVE=.*/DK_WAVE="1"/' "$d/.task.env"
}
all_dev_done() { printf 'status: done\n' > "$d/state/backend.md"; printf 'status: done\n' > "$d/state/frontend.md"; }

@test "dev 波還沒全員完成就不推聚合" {
  dev_wave; printf 'status: done\n' > "$d/state/backend.md"
  run dk-watch --once; [ "$status" -eq 0 ]
  refute_grep '全員完成' "$HERDR_STUB_LOG"
  [ ! -f "$d/.blocked/wave-1.devdone" ]
}

@test "dev 全員完成推一則聚合 [DONE]，不等 qa" {
  dev_wave; all_dev_done; printf 'status: working\n' > "$d/state/qa.md"
  run dk-watch --once; [ "$status" -eq 0 ]
  grep -q '^agent prompt leader-login \[DONE\] from dk-watch: wave 1 dev 全員完成（2 位：backend, frontend）→ dk-review-pack 1$' "$HERDR_STUB_LOG"
  grep -q '^delivered$' "$d/.blocked/wave-1.devdone"
}

@test "聚合只推一次" {
  dev_wave; all_dev_done
  dk-watch --once; dk-watch --once
  [ "$(grep -c '全員完成' "$HERDR_STUB_LOG")" -eq 1 ]
}

@test "聚合送不到時下一 tick 重試" {
  dev_wave; all_dev_done
  HERDR_STUB_FAIL="agent wait" dk-watch --once
  refute_grep '全員完成' "$HERDR_STUB_LOG"
  [ -f "$d/.blocked/wave-1.devdone" ]; refute_grep '^delivered$' "$d/.blocked/wave-1.devdone"
  dk-watch --once
  grep -q '全員完成' "$HERDR_STUB_LOG"; grep -q '^delivered$' "$d/.blocked/wave-1.devdone"
}

@test "沒有 dev 成員的波不推聚合" {
  dev_wave
  printf 'login-qa wC:p3 %s review 1 3\n' "$(date +%s)" > "$d/.panes"
  run dk-watch --once; [ "$status" -eq 0 ]
  refute_grep '全員完成' "$HERDR_STUB_LOG"
}

@test "沒有開著的波就不推聚合" {
  dev_wave; all_dev_done; sed -i 's/^DK_WAVE=.*/DK_WAVE=""/' "$d/.task.env"
  run dk-watch --once; [ "$status" -eq 0 ]
  refute_grep '全員完成' "$HERDR_STUB_LOG"
}

# --- 複看：第一輪留下的 status: done 不該讓第二輪永久靜默（BACKLOG 2026-09-14） ---
# 實跑形狀：reviewer 交完首輪 → 領導派複看 → 它卡住沒動 → 逾時分支看到上一輪的 done 就 continue，
# 三個出口（熔斷、桌面通知、送領導的 [TIMEOUT]）全程空轉。

neutral_screen() { echo '{"result":{"read":{"text":"thinking..."}}}' > "$HERDR_STUB_RESPONSES/agent_read.json"; }
redispatched() { # 領導派了複看，然後過了 25 分鐘
  dk-msg login-reviewer-b "[TASK] 複看第二輪" >/dev/null
  sed -i "s/^login-reviewer-b wC:p4 [0-9]*/login-reviewer-b wC:p4 $old/" "$d/.panes"
}

@test "被重新指派後，上一輪留下的 status: done 不再擋住逾時" {
  neutral_screen; reviewer_row "$(( old - 1500 ))"; printf 'status: done\n' > "$d/state/reviewer-b.md"
  dk-watch --once; ! grep -q 'TIMEOUT' "$HERDR_STUB_LOG"     # 首輪交了，這時吵它才是錯的
  redispatched
  dk-watch --once
  grep -q '^agent prompt leader-login \[TIMEOUT\] from dk-watch: login-reviewer-b 逾時$' "$HERDR_STUB_LOG"
  grep -q ' timeout login-reviewer-b → kind codex down$' "$d/process.md"
}

@test "複看真的交了（state 被重寫）就不報逾時" {
  neutral_screen; reviewer_row "$(( old - 1500 ))"; printf 'status: done\n' > "$d/state/reviewer-b.md"
  redispatched
  printf 'status: done\nnotes: 第二輪也看完了\n' > "$d/state/reviewer-b.md"
  dk-watch --once
  ! grep -q 'TIMEOUT' "$HERDR_STUB_LOG"
}

@test "沒被重新指派過的 reviewer：首輪的 done 照樣擋住逾時" {
  neutral_screen; reviewer_row "$old"; printf 'status: done\n' > "$d/state/reviewer-b.md"
  dk-watch --once
  ! grep -q 'TIMEOUT' "$HERDR_STUB_LOG"
}

@test "上一輪的 .timeout 已 delivered，複看再卡住仍會重新報一次" {
  neutral_screen; reviewer_row "$(( old - 1500 ))"; printf 'status: done\n' > "$d/state/reviewer-b.md"
  mkdir -p "$d/.blocked"; printf 'notified\ntag=\ndelivered\n' > "$d/.blocked/login-reviewer-b.timeout"
  redispatched
  dk-watch --once
  grep -q '^agent prompt leader-login \[TIMEOUT\] from dk-watch: login-reviewer-b 逾時$' "$HERDR_STUB_LOG"
}

# --- 開波空窗的假聚合（BACKLOG 2026-09-19，flowgap 波 3／4 實測兩次）---
# state 檔跨波共用而 `.devdone` 標記逐波：波 N 的 `status: done` 還躺在檔裡，領導 dk-wave-open N+1
# 並 dk-spawn 之後、員工尚未動筆之前，守望就把「dev 全員完成」推了出去。誤發之後標記寫成
# delivered，真正完成時永遠不再通知 —— 既靜默放行空波，也讓真交付靜默。
# 判準不能是 state 的 `wave:` 欄（員工漏填就永遠不通知，比誤報更糟），所以沿用 0.8.0 reviewer
# 那套：dk-spawn 當下存 state 內容的 cksum，內容變過才是這一輪的交付。

wave2_spawned() { # 上一波留下 status: done，波 2 開著，員工剛被 spawn、還沒動筆
  printf 'status: done\nwave: 1\n' > "$d/state/backend.md"
  sed -i 's/^DK_WAVE=.*/DK_WAVE="2"/' "$d/.task.env"
  : > "$d/.panes"
  dk-spawn backend >/dev/null
  sed -i 's/"blocked"/"idle"/' "$HERDR_STUB_RESPONSES/agent_list.json"
}

@test "開波空窗：上一波留下的 status: done 不算這一波的交付" {
  wave2_spawned
  run dk-watch --once; [ "$status" -eq 0 ]
  refute_grep '全員完成' "$HERDR_STUB_LOG"
  refute_grep ' dev-done wave 2' "$d/process.md"
  [ ! -f "$d/.blocked/wave-2.devdone" ]
}

@test "員工在這一波重寫 state 之後，聚合照常推一次且只推一次" {
  wave2_spawned
  dk-watch --once
  printf 'status: done\nwave: 2\nnotes: 波 2 做完了\n' > "$d/state/backend.md"
  dk-watch --once
  grep -q ' dev-done wave 2 (1: backend)$' "$d/process.md"
  grep -q '^delivered$' "$d/.blocked/wave-2.devdone"
  dk-watch --once
  [ "$(grep -c '全員完成' "$HERDR_STUB_LOG")" -eq 1 ]
}

@test "state 漏填 wave: 欄也認得出這一輪的交付" {
  wave2_spawned
  printf 'status: done\nnotes: 交了，但忘了填 wave 欄\n' > "$d/state/backend.md"
  dk-watch --once
  grep -q '全員完成' "$HERDR_STUB_LOG"
}

@test "resume_unchanged_stays_done: 重派不把已認定的完成打回未完成" {
  printf 'status: done\nwave: 1\n' > "$d/state/backend.md"
  printf 'status: done\nwave: 1\n' > "$d/state/frontend.md"
  sed -i 's/^DK_WAVE=.*/DK_WAVE="2"/' "$d/.task.env"
  : > "$d/.panes"
  dk-spawn backend >/dev/null; dk-spawn frontend >/dev/null
  sed -i 's/"blocked"/"idle"/' "$HERDR_STUB_RESPONSES/agent_list.json"
  printf 'status: done\nwave: 2\n' > "$d/state/backend.md"   # backend 交了波 2
  dk-watch --once; refute_grep '全員完成' "$HERDR_STUB_LOG"   # frontend 還沒，不該推
  dk-spawn backend --resume >/dev/null                        # 重派；它的 state 從此不再變動
  printf 'status: done\nwave: 2\n' > "$d/state/frontend.md"
  dk-watch --once
  grep -q '全員完成' "$HERDR_STUB_LOG"
}

# --- latch 只豁免「內容與快照相同」，不豁免 status: done 本身 -----------------
# reviewer-a Important 1：dev_delivered() 原本是 `[ -f "$latch" ] && return 0`，一旦某位 dev
# 交過一次，latch 落下之後不論它的 state 變成什麼都算「已交付」。A 交件 → qa 退件 A 改回
# working → B 才交齊，這樣也會被判成全員完成 —— 跟 BACKLOG 那條開波空窗的洞同一個症狀，
# 只是觸發條件換成「qa 退件」。

@test "latch 落下後被退回 working，不再算已交付；同波夥伴交齊也不推聚合" {
  printf 'status: done\nwave: 1\n' > "$d/state/backend.md"
  printf 'status: done\nwave: 1\n' > "$d/state/frontend.md"
  sed -i 's/^DK_WAVE=.*/DK_WAVE="2"/' "$d/.task.env"
  : > "$d/.panes"
  dk-spawn backend >/dev/null; dk-spawn frontend >/dev/null
  sed -i 's/"blocked"/"idle"/' "$HERDR_STUB_RESPONSES/agent_list.json"
  printf 'status: done\nwave: 2\n' > "$d/state/backend.md"   # A 交件，latch 落下
  dk-watch --once; refute_grep '全員完成' "$HERDR_STUB_LOG"
  printf 'status: working\nwave: 2\n' > "$d/state/backend.md"   # qa 退件，A 改回 working
  printf 'status: done\nwave: 2\n' > "$d/state/frontend.md"     # B 交齊
  dk-watch --once
  refute_grep '全員完成' "$HERDR_STUB_LOG"
  refute_grep ' dev-done wave 2' "$d/process.md"
  [ ! -f "$d/.blocked/wave-2.devdone" ]
  printf 'status: done\nwave: 2\n' > "$d/state/backend.md"     # A 再改回 done 才推
  dk-watch --once
  grep -q '全員完成' "$HERDR_STUB_LOG"
}

# --- 逾時訊息的 (quota?) 標記走該 kind 的額度式子，不再自己寫一條寬鬆的 ---------
# dk-watch 原本另寫 'rate limit|quota|429|usage limit'：裸 quota 讓 agy 的啟動橫幅
# `bal@host (Antigravity Starter Quota)` 被標成疑似撞額度，領導會去換 kind 而不是去看它為什麼卡住。

@test "逾時標記：agy 的啟動橫幅不算額度" {
  echo '{"result":{"read":{"text":"bal@host (Antigravity Starter Quota)\nthinking..."}}}' > "$HERDR_STUB_RESPONSES/agent_read.json"
  printf 'login-reviewer-b wC:p4 %s review 1 3\n' "$old" >> "$d/.panes"
  echo "2026-09-10T10:00 spawn login-reviewer-b (agy M) override-kind isolated" >> "$d/process.md"
  dk-watch --once
  grep -q '^agent prompt leader-login \[TIMEOUT\] from dk-watch: login-reviewer-b 逾時$' "$HERDR_STUB_LOG"
  refute_grep 'quota?' "$HERDR_STUB_LOG"
  refute_grep 'LIMIT' "$HERDR_STUB_LOG"
}

@test "逾時標記：agy 真的耗盡時仍標 (quota?)" {
  echo '{"result":{"read":{"text":"Individual quota reached, Resets in 102h11m1s"}}}' > "$HERDR_STUB_RESPONSES/agent_read.json"
  printf 'login-reviewer-b wC:p4 %s review 1 3\n' "$old" >> "$d/.panes"
  echo "2026-09-10T10:00 spawn login-reviewer-b (agy M) override-kind isolated" >> "$d/process.md"
  dk-watch --once
  grep -q '\[LIMIT\] from dk-watch: login-reviewer-b 撞額度' "$HERDR_STUB_LOG"
  # reviewer-a Minor 1：AC8 改動的 dk-watch:212 只有反向（不該標）被守著，正向拿掉整行也不會紅。
  grep -q '\[TIMEOUT\] from dk-watch: login-reviewer-b 逾時 (quota?)' "$HERDR_STUB_LOG"
}
