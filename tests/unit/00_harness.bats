load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "stub herdr logs calls and returns canned json" {
  run herdr pane split --current --direction right
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.result.pane.pane_id == "wC:p2"'
  grep -q '^pane split --current --direction right$' "$HERDR_STUB_LOG"
}

@test "stub herdr can be told to fail" {
  HERDR_STUB_FAIL="agent start" run herdr agent start x --kind claude --pane wC:p2
  [ "$status" -eq 1 ]
}
