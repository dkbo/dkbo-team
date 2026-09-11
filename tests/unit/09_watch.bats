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

chore_file() { # $1=agent $2=status [$3=leader] — a chore file without running dk-chore
  mkdir -p "$DK_ROOT/tasks/_chores"
  local f="$DK_ROOT/tasks/_chores/2026-09-10-$1.md"
  {
    echo "交代：翻譯 README"; echo "成員：$1 (claude / M)"; echo "branch: -"; echo "workspace: -"; echo "pane: wC:p3"
    [ -z "${3:-}" ] || echo "leader: $3"
    echo "status: $2"; echo "touched:"; echo "結果："
  } > "$f"
}
blocked_chore() { sed -i 's/login-qa/chore-frontend-1/' "$HERDR_STUB_RESPONSES/agent_list.json"; }
cmark="$DK_ROOT/.sessions/chores.blocked"

@test "--chores: first sighting records a marker, no notify" {
  blocked_chore; chore_file chore-frontend-1 working leader-login
  run dk-watch --chores --once; [ "$status" -eq 0 ]
  [ -f "$DK_ROOT/.sessions/chores.blocked/chore-frontend-1" ]
  ! grep -q '^notification show' "$HERDR_STUB_LOG"
}
@test "--chores: blocked past the threshold notifies the chore's own leader once" {
  blocked_chore; chore_file chore-frontend-1 working leader-login
  mkdir -p "$DK_ROOT/.sessions/chores.blocked"; echo 0 > "$DK_ROOT/.sessions/chores.blocked/chore-frontend-1"
  dk-watch --chores --once; dk-watch --chores --once
  [ "$(grep -c '^notification show dkbo: chore-frontend-1 blocked' "$HERDR_STUB_LOG")" -eq 1 ]
  [ "$(grep -c '^agent prompt leader-login \[BLOCKED\] from dk-watch: chore-frontend-1' "$HERDR_STUB_LOG")" -eq 1 ]
  grep -q 'chore-frontend-1' "$DK_ROOT/tasks/_chores/messages.log"
}
@test "--chores: a chore file with no leader line still raises the desktop notification" {
  blocked_chore; chore_file chore-frontend-1 working
  mkdir -p "$DK_ROOT/.sessions/chores.blocked"; echo 0 > "$DK_ROOT/.sessions/chores.blocked/chore-frontend-1"
  run dk-watch --chores --once; [ "$status" -eq 0 ]
  grep -q '^notification show dkbo: chore-frontend-1 blocked' "$HERDR_STUB_LOG"
  ! grep -q '^agent prompt' "$HERDR_STUB_LOG"
}
@test "--chores: a chore that is not working is not watched" {
  blocked_chore; chore_file chore-frontend-1 done leader-login
  run dk-watch --chores --once; [ "$status" -eq 0 ]
  [ ! -f "$DK_ROOT/.sessions/chores.blocked/chore-frontend-1" ]
}
@test "--chores --ensure starts one chore watcher and is idempotent" {
  unset DK_NO_WATCH; chore_file chore-frontend-1 working leader-login
  run dk-watch --chores --ensure; [ "$status" -eq 0 ]; [[ "$output" == *"chores started"* ]]
  pid=$(cat "$DK_ROOT/.sessions/chores.watch.pid"); ps -p "$pid" -o args= | grep -q -- '--chores'
  run dk-watch --chores --ensure; [ "$status" -eq 0 ]; [[ "$output" == *"chores running (pid $pid)"* ]]
  [ "$(cat "$DK_ROOT/.sessions/chores.watch.pid")" = "$pid" ]
  kill "$pid" 2>/dev/null || true
}
@test "dk-chore records its leader and ensures the chore watcher" {
  unset DK_NO_WATCH
  run dk-chore frontend "翻譯 README"; [ "$status" -eq 0 ]
  f=$(ls "$DK_ROOT/tasks/_chores/"*.md); grep -q '^leader: wB:p1$' "$f"
  pid=$(cat "$DK_ROOT/.sessions/chores.watch.pid"); ps -p "$pid" -o args= | grep -q -- '--chores'
  kill "$pid" 2>/dev/null || true
}

old=$(( $(date +%s) - 1500 ))   # 25 minutes ago
reviewer_row() { printf 'login-reviewer-b wC:p4 %s review 1 3\n' "$1" >> "$d/.panes"; echo "2026-09-10T10:00 spawn login-reviewer-b (codex M) override-kind isolated" >> "$d/process.md"; }

@test "reviewer past DK_REVIEW_TIMEOUT_MIN is reported once with (quota?) and its kind goes down" {
  reviewer_row "$old"
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
  reviewer_row "$old"
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
  blocked_chore; chore_file chore-frontend-1 working leader-login
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
