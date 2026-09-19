load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); }
teardown() { teardown_project; }

@test "spawn splits with env, starts agent with tier flags, sends first prompt" {
  run dk-spawn frontend cart --tier L
  [ "$status" -eq 0 ]
  split=$(grep '^pane split' "$HERDR_STUB_LOG")
  [[ "$split" == *"--pane wB:p1 --direction right --ratio 0.500 --cwd $WORKTREE_PATH --no-focus"* ]]
  [[ "$split" == *"--env DK_TASK_DIR=$d"* ]]; [[ "$split" == *"--env DK_ROLE=frontend"* ]]
  [[ "$split" == *"--env DK_AGENT=login-frontend-cart"* ]]; [[ "$split" == *"--env DK_LEADER=leader-login"* ]]
  [[ "$split" == *"--env DK_ISOLATED=0"* ]]
  grep -q '^agent start login-frontend-cart --kind claude --pane wC:p2 -- --model opus --effort high --permission-mode auto --add-dir '"$PROJECT"'$' "$HERDR_STUB_LOG"
  p=$(grep '^agent prompt login-frontend-cart' "$HERDR_STUB_LOG")
  [[ "$p" == *"$DK_ROOT/roles/frontend.md"* ]]; [[ "$p" == *"$d/brief.md"* ]]; [[ "$p" == *"$d/state/frontend-cart.report.md"* ]]
  [[ "$p" == *"$d/state/frontend-cart.md"* ]]; [[ "$p" == *"禁止使用 subagent"* ]]; [[ "$p" == *"--wait --until working --timeout 15000" ]]
  grep -Eq '^login-frontend-cart wC:p2 [0-9]{10} dev 1 1$' "$d/.panes"
  grep -q 'spawn login-frontend-cart (claude L)' "$d/process.md"
}
@test "spawn defaults tier M, honours --kind and --isolated and --resume" {
  run dk-spawn qa --kind codex --isolated --resume
  [ "$status" -eq 0 ]
  grep -q -- '--kind codex --pane wC:p2 -- -m gpt-5.5 -c model_reasoning_effort=medium' "$HERDR_STUB_LOG"
  grep -q -- '--env DK_ISOLATED=1' "$HERDR_STUB_LOG"
  grep -q '從 state 檔續作' "$HERDR_STUB_LOG"
  grep -q 'spawn login-qa (codex M) override-kind isolated resume' "$d/process.md"
}
@test "spawn warns on missing mcp but continues" {
  sed -i 's/^mcp: \[\]/mcp: [playwright]/' "$DK_ROOT/roles/qa.md"
  run dk-spawn qa
  [ "$status" -eq 0 ]; [[ "$output" == *"mcp missing"* ]]; grep -q 'mcp-missing login-qa: playwright' "$d/process.md"
}
@test "spawn fails on unknown role or tier without S" {
  run dk-spawn designer; [ "$status" -eq 1 ]
  run dk-spawn reviewer --tier S; [ "$status" -eq 1 ]
}
@test "worktree:false role splits beside the leader in the main tree" {
  run dk-spawn pm; [ "$status" -eq 0 ]
  grep -q -- "^pane split --pane wB:p1 --direction right --cwd $PROJECT --no-focus" "$HERDR_STUB_LOG"
  grep -Eq '^login-pm wC:p2 [0-9]+ dev 0 0$' "$d/.panes"
}
@test "spawn records prompt failure but keeps the pane entry" {
  HERDR_STUB_FAIL="agent prompt" run dk-spawn qa
  [ "$status" -eq 1 ]; [[ "$output" == *"first prompt"* ]]
  grep -q '^login-qa wC:p2 ' "$d/.panes"; grep -q 'spawn login-qa (claude M) prompt-failed' "$d/process.md"
}
@test "spawn validates agent name before touching herdr" {
  run dk-spawn frontend 'Big Cart!'
  [ "$status" -eq 1 ]
  ! grep -q '^pane split' "$HERDR_STUB_LOG"
}
@test "spawn keeps the pane when agent start fails, so the startup prompt survives" {
  # e2e 實測：codex 卡在「Update available!」升級提示而 agent start 失敗，
  # 舊行為把 pane 關掉連證據一起銷毀，現場查不出原因（RESULTS-2026-09-11 ⑧）
  HERDR_STUB_FAIL="agent start" run dk-spawn qa
  [ "$status" -eq 1 ]
  ! grep -q '^pane close wC:p2$' "$HERDR_STUB_LOG"
  [[ "$output" == *"wC:p2"* ]] && [[ "$output" == *"pane read"* ]]
  grep -q 'spawn login-qa failed: pane wC:p2 kept' "$d/process.md"
  ! grep -q '^login-qa ' "$d/.panes"
}
@test "spawn --resume closes and dedupes the old pane entry" {
  echo "login-qa wC:p9" >> "$d/.panes"
  run dk-spawn qa --resume
  [ "$status" -eq 0 ]
  grep -q '^pane close wC:p9$' "$HERDR_STUB_LOG"
  [ "$(grep -c '^login-qa ' "$d/.panes")" -eq 1 ]
  grep -q '^login-qa wC:p2 ' "$d/.panes"
}
@test "first prompt points at the member slice when it exists" {
  mkdir -p "$d/briefs"; echo '# slice' > "$d/briefs/qa.md"
  dk-spawn qa >/dev/null
  p=$(grep '^agent prompt login-qa' "$HERDR_STUB_LOG"); [[ "$p" == *"$d/briefs/qa.md"* ]]; [[ "$p" != *"$d/brief.md"* ]]; [[ "$p" == *"report-employee.md"* ]]
}
@test "second employee hangs below the first; review group recorded" {
  echo "login-backend wC:p2 0 dev 1 1" > "$d/.panes"
  echo '{"result":{"pane":{"pane_id":"wC:p3"}}}' > "$HERDR_STUB_RESPONSES/pane_split.json"
  dk-spawn qa >/dev/null
  grep -q -- '--pane wC:p2 --direction down --ratio 0.500' "$HERDR_STUB_LOG"
  grep -Eq '^login-qa wC:p3 [0-9]+ review 1 2$' "$d/.panes"
}
@test "--split overrides only the direction" {
  echo "login-backend wC:p2 0 dev 1 1" > "$d/.panes"
  dk-spawn qa --split right >/dev/null
  grep -q -- '--pane wC:p2 --direction right --ratio 0.500' "$HERDR_STUB_LOG"; grep -Eq '^login-qa wC:p2 [0-9]+ review 1 2$' "$d/.panes"
}
@test "fifth employee opens tab 2 as its root pane and records DK_TABS" {
  printf 'a wC:p2 0 dev 1 1\nb wC:p3 0 dev 1 2\nc wC:p4 0 dev 1 3\nd wC:p5 0 dev 1 4\n' > "$d/.panes"
  run dk-spawn qa; [ "$status" -eq 0 ]; [ "$output" = "login-qa wB:p10" ]
  tc=$(grep '^tab create' "$HERDR_STUB_LOG")
  [[ "$tc" == "tab create --workspace wB --cwd $WORKTREE_PATH --label login-2 --no-focus --env DK_ROOT=$DK_ROOT --env DK_TASK_DIR=$d --env DK_ROLE=qa --env DK_AGENT=login-qa"* ]]
  ! grep -q '^pane split' "$HERDR_STUB_LOG"
  grep -q '^agent start login-qa --kind claude --pane wB:p10 ' "$HERDR_STUB_LOG"
  grep -Eq '^login-qa wB:p10 [0-9]+ review 2 1$' "$d/.panes"
  grep -q '^DK_TABS="2=wB:t2"$' "$d/.task.env"; grep -q 'tab 2 wB:t2 opened' "$d/process.md"
}
@test "tab create failure dies before starting an agent" {
  printf 'a wC:p2 0 dev 1 1\nb wC:p3 0 dev 1 2\nc wC:p4 0 dev 1 3\nd wC:p5 0 dev 1 4\n' > "$d/.panes"
  HERDR_STUB_FAIL="tab create" run dk-spawn qa; [ "$status" -eq 1 ]; ! grep -q '^agent start' "$HERDR_STUB_LOG"; [ "$(wc -l < "$d/.panes")" -eq 4 ]
}
@test "agent start failure on a new tab keeps the tab so the startup prompt survives" {
  printf 'a wC:p2 0 dev 1 1\nb wC:p3 0 dev 1 2\nc wC:p4 0 dev 1 3\nd wC:p5 0 dev 1 4\n' > "$d/.panes"
  HERDR_STUB_FAIL="agent start" run dk-spawn qa; [ "$status" -eq 1 ]
  ! grep -q '^tab close wB:t2$' "$HERDR_STUB_LOG"; ! grep -q '^pane close' "$HERDR_STUB_LOG"
  grep -q '^DK_TABS="2=wB:t2"$' "$d/.task.env"; [ "$(wc -l < "$d/.panes")" -eq 4 ]
  grep -q 'spawn login-qa failed: pane .* kept for diagnosis' "$d/process.md"
}
@test "--resume of an overflow tab's only occupant closes the stale tab and keeps one DK_TABS entry" {
  printf 'a wC:p2 0 dev 1 1\nb wC:p3 0 dev 1 2\nc wC:p4 0 dev 1 3\nd wC:p5 0 dev 1 4\nlogin-qa wB:p10 0 review 2 1\n' > "$d/.panes"
  sed -i 's/^DK_TABS=.*/DK_TABS="2=wB:t9"/' "$d/.task.env"
  run dk-spawn qa --resume; [ "$status" -eq 0 ]
  grep -q '^pane close wB:p10$' "$HERDR_STUB_LOG"; grep -q '^tab close wB:t9$' "$HERDR_STUB_LOG"; grep -q '^tab create ' "$HERDR_STUB_LOG"
  grep -q '^DK_TABS="2=wB:t2"$' "$d/.task.env"; [ "$(grep -c '^2=' <<< "$(sed -n 's/^DK_TABS="\(.*\)"$/\1/p' "$d/.task.env" | tr ' ' '\n')")" -eq 1 ]
  grep -q 'tab 2 wB:t9 closed (recreated)' "$d/process.md"; grep -Eq '^login-qa wB:p10 [0-9]+ review 2 1$' "$d/.panes"
}
@test "首輪提示帶 TDD 順序與除錯方法檔" {
  fixture_brief "$d"; dk-wave-open 1 >/dev/null
  run dk-spawn backend; [ "$status" -eq 0 ]
  grep -q '先寫一條會失敗的測試' "$HERDR_STUB_LOG"
  grep -q 'methods/debugging.md' "$HERDR_STUB_LOG"
}
@test "--handoff 落 ruling、隱含 resume、用接手版提示" {
  fixture_brief "$d"; dk-wave-open 1 >/dev/null
  dk-spawn backend >/dev/null
  run dk-spawn backend --handoff "claude 修一次沒好，換 codex" --kind codex
  [ "$status" -eq 0 ]
  grep -qE '^[^ ]+ ruling: 換 codex/M 接手 login-backend 的修復 — claude 修一次沒好，換 codex — ' "$d/process.md"
  grep -q '上一位修過一次沒成功' "$HERDR_STUB_LOG"
  grep -q 'methods/debugging.md' "$HERDR_STUB_LOG"
}
@test "--handoff 不帶原因就死" {
  fixture_brief "$d"; dk-wave-open 1 >/dev/null
  run dk-spawn backend --handoff; [ "$status" -ne 0 ]; [[ "$output" == *"--handoff"* ]]
}
@test "TDD 那一句只發給 group: dev，reviewer 與 qa 不收到" {
  # Minor 6：reviewer 依角色定義不寫任何碼，報告格式另由切片規定成規格合規／Important／
  # Minor，收到「兩次的指令與輸出貼進報告的紅綠」跟自己的切片矛盾。
  fixture_brief "$d"; dk-wave-open 1 >/dev/null
  run dk-spawn backend; [ "$status" -eq 0 ]
  grep -q '先寫一條會失敗的測試' "$HERDR_STUB_LOG"
  : > "$HERDR_STUB_LOG"
  run dk-spawn qa; [ "$status" -eq 0 ]
  refute_grep '先寫一條會失敗的測試' "$HERDR_STUB_LOG"
}
@test "--handoff 的 ruling 只在 pane 與 agent 真的起來後才落盤" {
  # Minor 7：ruling 原本在 pane split／agent start 之前就落盤，agent start 失敗時
  # process.md 會留下一行「換人」的假裁定，而那次換手其實沒發生。
  fixture_brief "$d"; dk-wave-open 1 >/dev/null
  dk-spawn backend >/dev/null
  HERDR_STUB_FAIL="agent start" run dk-spawn backend --handoff "claude 修一次沒好，換 codex" --kind codex
  [ "$status" -eq 1 ]
  refute_grep 'ruling: 換 codex' "$d/process.md"
}
