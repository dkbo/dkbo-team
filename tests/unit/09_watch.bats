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
  [ "$(grep -c '^notification show dkboai: login-qa blocked' "$HERDR_STUB_LOG")" -eq 1 ]
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
@test "tick survives an agent list without agents array" {
  echo '{"id":"cli:agent:list","result":{}}' > "$HERDR_STUB_RESPONSES/agent_list.json"
  run dk-watch --once; [ "$status" -eq 0 ]
  [ ! -f "$d/.blocked/login-qa" ]
}

old=$(( $(date +%s) - 1500 ))   # 25 minutes ago
reviewer_row() { printf 'login-reviewer-b wC:p4 %s review 1 3\n' "$1" >> "$d/.panes"; echo "2026-09-10T10:00 spawn login-reviewer-b (codex M) override-kind isolated" >> "$d/process.md"; }

@test "reviewer past DK_REVIEW_TIMEOUT_MIN is reported once with (quota?) and its kind goes down" {
  reviewer_row "$old"
  dk-watch --once; dk-watch --once
  [ "$(grep -c '^agent prompt leader-login \[TIMEOUT\] from dk-watch: login-reviewer-b 逾時 (quota?)$' "$HERDR_STUB_LOG")" -eq 1 ]
  [ "$(grep -c '^notification show dkboai: login-reviewer-b timeout' "$HERDR_STUB_LOG")" -eq 1 ]
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
