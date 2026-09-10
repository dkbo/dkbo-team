load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"
  printf 'login-backend wC:p2 0 dev 1 1\nlogin-qa wC:p3 0 review 1 2\n' > "$d/.panes"
  printf 'status: done\nwave: 1\ntouched:\n  - src/api/login.ts\nreport: state/backend.report.md\n' > "$d/state/backend.md"
  printf 'status: done\nwave: 1\ntouched:\n  - tests/login.test.ts\n' > "$d/state/qa.md"
  printf '# backend 報告\n## 做了什麼\nlogin\n## 測試\nnpm test → 3 passed\n## 自我審查\n## 疑慮\n' > "$d/state/backend.report.md"
  sed -i 's/^DK_WAVE=.*/DK_WAVE="1"/' "$d/.task.env"
  echo "$(date +%Y-%m-%dT%H:%M) review 1 verdict a: ok" >> "$d/process.md"
}
teardown() { teardown_project; }

@test "all gates pass: panes closed, DK_WAVE cleared, tests skipped without DK_TEST_CMD" {
  run dk-wave-close; [ "$status" -eq 0 ]; [ "$output" = "closed 2" ]
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
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"lacks content under '## 測試'"* ]]
  printf '# r\n## 測試\nbats 12 ok\n' > "$d/state/backend.report.md"; run dk-wave-close; [ "$status" -eq 0 ]
}
@test "gate c: DK_TEST_CMD runs in the worktree; failure keeps panes and shows the tail" {
  echo 'DK_TEST_CMD="cat marker.txt"' >> "$DK_ROOT/settings.env"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"tests failed (cat marker.txt)"* ]]; [[ "$output" == *"No such file"* ]]
  ! grep -q '^pane close' "$HERDR_STUB_LOG"; grep -q ' wave-close 1 tests failed (cat marker.txt)$' "$d/process.md"; [ -f "$d/waves/1.test.log" ]
  echo ok > "$WORKTREE_PATH/marker.txt"; run dk-wave-close; [ "$status" -eq 0 ]; grep -q ' wave-close 1 tests ok (cat marker.txt) 2 agents closed$' "$d/process.md"
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
  run dk-wave-close; [ "$status" -eq 0 ]; [[ "$output" == *"legacy"* ]]; grep -q 'wave-close: 2 agents closed' "$d/process.md"
}
@test "ownership violations and long state are still reported" {
  printf 'status: done\ntouched:\n  - src/web/x.ts\n' > "$d/state/backend.md"
  for i in $(seq 1 25); do echo "notes: line $i" >> "$d/state/qa.md"; done
  run dk-wave-close; [ "$status" -eq 0 ]; grep -q 'violation login-backend: src/web/x.ts' "$d/process.md"; [[ "$output" == *"state too long"* ]]
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
