load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"
  printf 'login-backend wC:p2 0 dev 1 1\nlogin-qa wC:p3 0 review 1 2\n' > "$d/.panes"
  printf 'status: done\nwave: 1\ntouched:\n  - src/api/login.ts\nreport: state/backend.report.md\n' > "$d/state/backend.md"
  printf 'status: done\nwave: 1\ntouched:\n  - tests/login.test.ts\n' > "$d/state/qa.md"
  printf '# backend 報告\n## 做了什麼\nlogin\n## 測試\n### 紅\n$ npm test -- login\nFAIL login not defined\n### 綠\n$ npm test -- login\n3 passed\n## 自我審查\n## 疑慮\n' > "$d/state/backend.report.md"
  sed -i 's/^DK_WAVE=.*/DK_WAVE="1"/' "$d/.task.env"
  echo "$(date +%Y-%m-%dT%H:%M) wave-open 1 base $(git -C "$WORKTREE_PATH" rev-parse --short=7 HEAD) members backend qa" >> "$d/process.md"
  echo "$(date +%Y-%m-%dT%H:%M) review 1 verdict a: ok" >> "$d/process.md"
  wt() { git -C "$WORKTREE_PATH" -c user.name=t -c user.email=t@t "$@"; }
}
teardown() { teardown_project; }

@test "all gates pass: panes closed, DK_WAVE cleared, tests skipped without DK_TEST_CMD" {
  run dk-wave-close; [ "$status" -eq 0 ]; [[ "$output" == *"closed 2"* ]]
  grep -q '^pane close wC:p2$' "$HERDR_STUB_LOG"; grep -q '^pane close wC:p3$' "$HERDR_STUB_LOG"
  [ ! -s "$d/.panes" ]; grep -q '^DK_WAVE=""$' "$d/.task.env"
  grep -q ' wave-close 1 tests skipped (no DK_TEST_CMD) 2 agents closed$' "$d/process.md"
}
@test "gate 0: a state not done refuses unless --force" {
  sed -i 's/^status: done/status: working/' "$d/state/qa.md"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"not done: login-qa"* ]]; ! grep -q '^pane close' "$HERDR_STUB_LOG"
  run dk-wave-close --force; [ "$status" -eq 0 ]
}
@test "gate a: needs a review verdict or a recorded skip" {
  sed -i '/review 1 verdict/d' "$d/process.md"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"review 1 verdict"* ]]; ! grep -q '^pane close' "$HERDR_STUB_LOG"
  echo "2026-09-10T10:00 review 1 skipped: 純文件波" >> "$d/process.md"; run dk-wave-close; [ "$status" -eq 0 ]
}
@test "gate b: every dev needs a report with content under ## 測試; review-group members do not" {
  rm "$d/state/backend.report.md"; run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"no report"*"backend.report.md"* ]]
  printf '# r\n## 測試\n（必填）\n\n## 自我審查\nok\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"的 '## 測試' 缺證據"* ]]
  printf '# r\n## 測試\n### 紅\n$ bats\nFAIL 12\n### 綠\n$ bats\n12 ok\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 0 ]
}
@test "gate c: DK_TEST_CMD runs in the worktree; failure keeps panes and shows the tail" {
  echo 'DK_TEST_CMD="cat tests/marker.txt"' >> "$DK_ROOT/settings.env"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"tests failed (cat tests/marker.txt)"* ]]; [[ "$output" == *"No such file"* ]]
  ! grep -q '^pane close' "$HERDR_STUB_LOG"; grep -q ' wave-close 1 tests failed (cat tests/marker.txt)$' "$d/process.md"; [ -f "$d/waves/1.test.log" ]
  mkdir -p "$WORKTREE_PATH/tests"; echo ok > "$WORKTREE_PATH/tests/marker.txt"   # under qa's ownership, or gate d refuses it
  run dk-wave-close; [ "$status" -eq 0 ]; grep -q ' wave-close 1 tests ok (cat tests/marker.txt) 2 agents closed$' "$d/process.md"
}
@test "gate c: --force closes despite failing tests and says so" {
  echo 'DK_TEST_CMD="echo boom; exit 1"' >> "$DK_ROOT/settings.env"
  run dk-wave-close --force; [ "$status" -eq 0 ]; [[ "$output" == *"boom"* ]]; grep -q 'tests failed (echo boom; exit 1, forced) 2 agents closed' "$d/process.md"
}
@test "no open wave refuses" {
  sed -i 's/^DK_WAVE=.*/DK_WAVE=""/' "$d/.task.env"; run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"no wave open"* ]]
}
@test "legacy: two-column .panes or no DK_WAVE key → old behaviour with a warning" {
  printf 'login-backend wC:p2\nlogin-qa wC:p3\n' > "$d/.panes"; rm "$d/state/backend.report.md"; sed -i '/review 1 verdict/d' "$d/process.md"
  mkdir -p "$WORKTREE_PATH/src/web"; echo x > "$WORKTREE_PATH/src/web/x.ts"   # no diff gate, no commit either
  run dk-wave-close; [ "$status" -eq 0 ]; [[ "$output" == *"legacy"* ]]; grep -q 'wave-close: 2 agents closed' "$d/process.md"
  [[ "$output" != *"unowned"* ]]; [[ "$output" != *"committed"* ]]; [ "$(wt log -1 --pretty=%s)" = init ]
}
@test "long state is still reported" {
  for i in $(seq 1 25); do echo "notes: line $i" >> "$d/state/qa.md"; done
  run dk-wave-close; [ "$status" -eq 0 ]; [[ "$output" == *"state too long"* ]]
}
@test "越界閘: a real change nobody in the wave owns refuses unless --force" {
  mkdir -p "$WORKTREE_PATH/src/web"; echo x > "$WORKTREE_PATH/src/web/x.ts"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"unowned change: src/web/x.ts"* ]]
  ! grep -q '^pane close' "$HERDR_STUB_LOG"
  run dk-wave-close --force; [ "$status" -eq 0 ]; grep -q 'violation unowned: src/web/x.ts' "$d/process.md"
}
@test "越界閘: an owned change nobody reported warns but still closes" {
  mkdir -p "$WORKTREE_PATH/src/api"; echo x > "$WORKTREE_PATH/src/api/other.ts"
  run dk-wave-close; [ "$status" -eq 0 ]
  [[ "$output" == *"unreported change: src/api/other.ts (owner backend)"* ]]
  grep -q 'unreported src/api/other.ts' "$d/process.md"
}
@test "越界閘: a touched path that never really changed is no longer a violation" {
  printf 'status: done\ntouched:\n  - src/web/x.ts\n' > "$d/state/backend.md"
  run dk-wave-close; [ "$status" -eq 0 ]; [[ "$output" != *"violation"* ]]; ! grep -q 'violation' "$d/process.md"
}
@test "越界閘: a wave with no recorded base skips the diff gate with a warning" {
  sed -i '/ wave-open 1 base /d' "$d/process.md"
  mkdir -p "$WORKTREE_PATH/src/web"; echo x > "$WORKTREE_PATH/src/web/x.ts"
  run dk-wave-close; [ "$status" -eq 0 ]; [[ "$output" == *"no recorded base"* ]]
}
@test "越界閘: a wave member with no state file still gets the normal refusal" {
  rm "$d/state/qa.md"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"not done: login-qa"* ]]
}
@test "越界閘: an unreadable worktree refuses rather than passing the gate silently" {
  rm -rf "$WORKTREE_PATH"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"cannot read the worktree diff"* ]]
}
@test "commit: the wave is committed in the worktree once the gates pass" {
  mkdir -p "$WORKTREE_PATH/src/api"; echo x > "$WORKTREE_PATH/src/api/login.ts"
  run dk-wave-close; [ "$status" -eq 0 ]; [[ "$output" == *"committed"* ]]
  [ "$(wt log -1 --pretty=%s)" = "wave 1: backend qa" ]
  [ -z "$(wt status --porcelain)" ]
  grep -qE ' commit [0-9a-f]{7} wave 1$' "$d/process.md"
}
@test "commit: -m overrides the message" {
  mkdir -p "$WORKTREE_PATH/src/api"; echo x > "$WORKTREE_PATH/src/api/login.ts"
  run dk-wave-close -m "wave 1: 登入 API 完成"; [ "$status" -eq 0 ]
  [ "$(wt log -1 --pretty=%s)" = "wave 1: 登入 API 完成" ]
}
@test "commit: an unchanged worktree is not committed" {
  run dk-wave-close; [ "$status" -eq 0 ]; [[ "$output" == *"nothing to commit"* ]]
  [ "$(wt log -1 --pretty=%s)" = init ]
}
@test "an emptied overflow tab is closed after the wave" {
  echo 'login-reviewer-a wB:p10 0 review 2 1' >> "$d/.panes"; printf 'status: done\n' > "$d/state/reviewer-a.md"
  sed -i 's/^DK_TABS=.*/DK_TABS="2=wB:t2"/' "$d/.task.env"
  run dk-wave-close; [ "$status" -eq 0 ]; grep -q '^tab close wB:t2$' "$HERDR_STUB_LOG"; grep -q '^DK_TABS=""$' "$d/.task.env"
}
@test "--agent closes one pane, drops its row, re-balances its tab" {
  run dk-wave-close --agent login-qa; [ "$status" -eq 0 ]; [ "$output" = "closed login-qa" ]
  grep -q '^pane close wC:p3$' "$HERDR_STUB_LOG"; ! grep -q '^login-qa ' "$d/.panes"; grep -q '^login-backend ' "$d/.panes"
  grep -q 'pane-close login-qa' "$d/process.md"; grep -q '^pane layout --pane wB:p1$' "$HERDR_STUB_LOG"
  run dk-wave-close --agent nobody; [ "$status" -eq 1 ]
}
@test "ownership matches member names exactly" {
  . "$DK_ROOT/lib/ownership.sh"
  printf '| qa-a | docs/** | — |\n' | sed -i '/^| qa | tests/r /dev/stdin' "$d/brief.md"
  dk_owned "$d/brief.md" qa tests/x.ts; ! dk_owned "$d/brief.md" qa docs/x.md; dk_owned "$d/brief.md" qa-a docs/x.md
}

@test "verdict must account for every reviewer that was spawned" {
  # e2e 實測：兩位 reviewer 派出去，領導只對 a 裁定就放行，codex 那位的意見整筆蒸發
  # 而流程看起來完全正常（RESULTS-2026-09-11 ⑧）
  echo "2026-09-11T10:00 review 1 spawned login-reviewer-a(claude) login-reviewer-b(codex)" >> "$d/process.md"
  run dk-wave-close                      # setup 已寫了 "review 1 verdict a: ok"，缺 b
  [ "$status" -eq 1 ]; [[ "$output" == *"reviewer b"* ]]; ! grep -q '^pane close' "$HERDR_STUB_LOG"
  echo "2026-09-11T10:02 review 1 verdict a: ok b: skipped (spawn-failed)" >> "$d/process.md"
  run dk-wave-close; [ "$status" -eq 0 ]
}

@test "gate b: 缺 ### 紅 或 ### 綠 都不放行，不適用可以過" {
  # 錯誤訊息同時提到兩個小節名，所以不能拿訊息裡有沒有「### 紅」來分辨是哪一邊缺 ——
  # 斷言改成「這份 report 被擋下來了」，並用 refute_grep 確認沒有其他 gate 一起叫。
  printf '# backend 報告\n## 測試\n### 綠\n3 passed\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 1 ]
  [[ "$output" == *"state/backend.report.md 的 '## 測試' 缺"* ]]
  refute_grep 'unowned change' <<< "$output"
  printf '# backend 報告\n## 測試\n### 紅\nFAIL\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 1 ]
  [[ "$output" == *"state/backend.report.md 的 '## 測試' 缺"* ]]
  # 兩節都在、但各只有一行（沒有輸出）：這正是 AC5 要擋的
  printf '# backend 報告\n## 測試\n### 紅\n跑過了會失敗\n### 綠\n跑過了會過\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 1 ]
  [[ "$output" == *"兩行以上"* ]]
  # 指令列＋輸出：放行
  printf '# backend 報告\n## 測試\n### 紅\n$ npm test -- login\nFAIL not defined\n### 綠\n$ npm test -- login\n3 passed\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 0 ]
}
@test "gate b: 不適用 是單行豁免" {
  printf '# backend 報告\n## 測試\n### 紅\n不適用: 純文件波\n### 綠\n不適用: 純文件波\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 0 ]
}

@test "wave-close 清掉本波的 dev 聚合標記" {
  mkdir -p "$d/.blocked"; printf 'notified\ndelivered\n' > "$d/.blocked/wave-1.devdone"
  run dk-wave-close; [ "$status" -eq 0 ]
  [ ! -f "$d/.blocked/wave-1.devdone" ]
}

@test "--agent 關掉一位員工後重置聚合標記：換 kind 重派才不會啞掉" {
  # dev 撞額度 → dk-wave-close --agent 關它 → 用未熔斷的 kind 重派。
  # 標記還停在 delivered 的話，補上的那位做完也不會再有人通知領導。
  mkdir -p "$d/.blocked"; printf 'notified\ndelivered\n' > "$d/.blocked/wave-1.devdone"
  run dk-wave-close --agent login-backend; [ "$status" -eq 0 ]
  [ ! -f "$d/.blocked/wave-1.devdone" ]
}
