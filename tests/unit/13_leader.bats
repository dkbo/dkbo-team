load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "dk-leader opens a named leader pane" {
  run dk-leader pay "金流"; [ "$status" -eq 0 ]; [ "$output" = "leader-pay wC:p2" ]
  grep -q -- "--current --direction right --cwd $PROJECT --no-focus --env DK_ROOT=$DK_ROOT --env HERDR_ENV=1" "$HERDR_STUB_LOG"
  grep -q '^agent start leader-pay --kind claude --pane wC:p2 -- --model opus --effort high$' "$HERDR_STUB_LOG"
  grep -q 'dk-task-new pay "金流"' "$HERDR_STUB_LOG"
}
@test "dk-leader validates short name" { run dk-leader Pay x; [ "$status" -eq 1 ]; }
