load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "whoami: leader when DK_ROLE unset" {
  run dk-whoami; [ "$status" -eq 0 ]; [ "$output" = "leader" ]
}
@test "whoami: employee with role/agent/task" {
  DK_ROLE=frontend DK_AGENT=login-frontend DK_TASK_DIR=/t run dk-whoami
  [ "$output" = "employee frontend login-frontend /t" ]
}
