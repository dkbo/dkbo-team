#!/usr/bin/env bats
load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"; }
teardown() { teardown_project; }

@test "wave-open sets DK_WAVE, records base, renders one slice per member" {
  run dk-wave-open 1; [ "$status" -eq 0 ]
  grep -q '^DK_WAVE="1"$' "$d/.task.env"
  sha=$(git -C "$WORKTREE_PATH" rev-parse --short=7 HEAD)
  grep -q " wave-open 1 base $sha members backend(M) qa(S)$" "$d/process.md"
  [ -f "$d/briefs/backend.md" ]; [ -f "$d/briefs/qa.md" ]; [ ! -f "$d/briefs/frontend-cart.md" ]
  grep -q '^| 1 | 實作 | backend | POST /login | M | 測試過 | 預設 |$' "$d/briefs/backend.md"
  ! grep -q 'frontend-cart |' "$d/briefs/backend.md"
  grep -q '^| backend | src/api/\*\* | src/web/\*\* |$' "$d/briefs/backend.md"; ! grep -q '^| qa |' "$d/briefs/backend.md"
  grep -q 'POST /login 空密碼回 400' "$d/briefs/backend.md"; grep -q '^無$' "$d/briefs/backend.md"; grep -q 'backend(M) qa(S)' "$d/briefs/backend.md"
  grep -q "$d/brief.md" "$d/briefs/backend.md"; grep -q '登入 API 與表單' "$d/briefs/qa.md"
}
@test "refuses a second open, an open with live panes, and a wave without members" {
  dk-wave-open 1 >/dev/null
  run dk-wave-open 2; [ "$status" -eq 1 ]; [[ "$output" == *"wave 1 is open"* ]]
  sed -i 's/^DK_WAVE=.*/DK_WAVE=""/' "$d/.task.env"
  run dk-wave-open 1; [ "$status" -eq 1 ]; [[ "$output" == *"already opened"* ]]
  echo "login-qa wC:p3 0 review 1 1" > "$d/.panes"
  run dk-wave-open 2; [ "$status" -eq 1 ]; [[ "$output" == *"live panes"* ]]
  : > "$d/.panes"; run dk-wave-open 9; [ "$status" -eq 1 ]; [[ "$output" == *"no members"* ]]
  run dk-wave-open x; [ "$status" -eq 1 ]
}
@test "只剩計畫審查 pane 時指得出路：dk-wave-close --agent" {
  echo "login-reviewer-p1 wC:p9 0 review 1 1" > "$d/.panes"
  run dk-wave-open 1
  [ "$status" -eq 1 ]; [[ "$output" == *"dk-wave-close --agent"* ]]; [[ "$output" == *"login-reviewer-p1"* ]]
}
@test "a tab-0 advisor pane (pm) does not block wave-open; a grid pane does" {
  echo "login-pm wC:p9 0 dev 0 0" > "$d/.panes"
  run dk-wave-open 1; [ "$status" -eq 0 ]
  sed -i 's/^DK_WAVE=.*/DK_WAVE=""/' "$d/.task.env"; sed -i '/ wave-open 1 /d' "$d/process.md"
  echo "login-qa wC:p3 0 review 1 1" >> "$d/.panes"
  run dk-wave-open 1; [ "$status" -eq 1 ]; [[ "$output" == *"live panes remain (1)"* ]]
}

@test "wave-open 記下這一波的開始時間" {
  run dk-wave-open 1; [ "$status" -eq 0 ]
  v=$(sed -n 's/^DK_WAVE_STARTED="\([0-9]*\)"$/\1/p' "$d/.task.env"); [[ "$v" =~ ^[0-9]+$ ]]
  [ "$v" -ge "$(( $(date +%s) - 60 ))" ]
}
