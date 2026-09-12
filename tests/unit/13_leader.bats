load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "dk-leader opens a named leader pane" {
  run dk-leader pay "金流"; [ "$status" -eq 0 ]; [ "$output" = "leader-pay wC:p2" ]
  grep -q -- "--current --direction right --cwd $PROJECT --no-focus --env DK_ROOT=$DK_ROOT --env HERDR_ENV=1" "$HERDR_STUB_LOG"
  grep -q '^agent start leader-pay --kind claude --pane wC:p2 -- --model opus --effort high --permission-mode auto --add-dir '"$PROJECT"'$' "$HERDR_STUB_LOG"
  grep -q 'dk-task-new pay "金流"' "$HERDR_STUB_LOG"
}
@test "dk-leader validates short name" { run dk-leader Pay x; [ "$status" -eq 1 ]; }
@test "dk-leader rejects a display name with backslash/quote/dollar/backtick" {
  run dk-leader pay 'abc\'; [ "$status" -eq 1 ]
}
@test "dk-leader rejects unknown model/effort and unknown kind" {
  run dk-leader pay x --model gpt-5; [ "$status" -eq 1 ]; [[ "$output" == *"unknown model"* ]]
  run dk-leader pay x --effort max; [ "$status" -eq 1 ]; [[ "$output" == *"unknown effort"* ]]
  run dk-leader pay x --kind nope;  [ "$status" -eq 1 ]
  ! grep -q '^agent start' "$HERDR_STUB_LOG"
}
@test "dk-leader dies cleanly when pane split fails" {
  HERDR_STUB_FAIL="pane split" run dk-leader pay x; [ "$status" -eq 1 ]; [[ "$output" == *"no pane_id"* ]]
}
@test "dk-leader's first prompt waits for the leader to start, and a failure keeps the pane" {
  dk-leader pay "金流" >/dev/null
  p=$(grep '^agent prompt leader-pay ' "$HERDR_STUB_LOG")
  [[ "$p" == *"--wait --until working"* ]]
  : > "$HERDR_STUB_LOG"
  HERDR_STUB_FAIL="agent prompt" run dk-leader pay "金流"
  [ "$status" -eq 1 ]; [[ "$output" == *"first prompt"* ]]
  ! grep -q '^pane close' "$HERDR_STUB_LOG"
}
