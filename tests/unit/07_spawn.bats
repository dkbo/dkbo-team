load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); }
teardown() { teardown_project; }

@test "spawn splits with env, starts agent with tier flags, sends first prompt" {
  run dk-spawn frontend cart --tier L
  [ "$status" -eq 0 ]
  split=$(grep '^pane split' "$HERDR_STUB_LOG")
  [[ "$split" == *"--pane wC:p1 --direction right --cwd $WORKTREE_PATH --no-focus"* ]]
  [[ "$split" == *"--env DK_TASK_DIR=$d"* ]]; [[ "$split" == *"--env DK_ROLE=frontend"* ]]
  [[ "$split" == *"--env DK_AGENT=login-frontend-cart"* ]]; [[ "$split" == *"--env DK_LEADER=leader-login"* ]]
  [[ "$split" == *"--env DK_ISOLATED=0"* ]]
  grep -q '^agent start login-frontend-cart --kind claude --pane wC:p2 -- --model opus --effort high --permission-mode acceptEdits$' "$HERDR_STUB_LOG"
  p=$(grep '^agent prompt login-frontend-cart' "$HERDR_STUB_LOG")
  [[ "$p" == *"$DK_ROOT/roles/frontend.md"* ]]; [[ "$p" == *"$d/brief.md"* ]]
  [[ "$p" == *"$d/state/frontend-cart.md"* ]]; [[ "$p" == *"禁止使用 subagent"* ]]; [[ "$p" == *"--wait --timeout 60000" ]]
  grep -q '^login-frontend-cart wC:p2$' "$d/.panes"
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
}
