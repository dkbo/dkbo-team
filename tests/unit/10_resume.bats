load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入)
  for i in $(seq 1 30); do echo "2026-09-10T10:$i ev$i" >> "$d/process.md"; done
  cat > "$d/messages.log" <<'L'
2026-09-10T10:00 login-qa -> leader-login [DONE] old
2026-09-10T10:01 leader-login [ACK]
2026-09-10T10:02 login-qa -> login-frontend [BUG] x
2026-09-10T10:03 login-qa -> leader-login [ESCALATE] 修一次未好
L
  printf 'status: working\nwave: 1\ncurrent: 修 bug\ntouched:\n  - a\ntodo:\n  - b\nnotes: n\n' > "$d/state/frontend.md"
}
teardown() { teardown_project; }

@test "resume prints the recovery pack under 150 lines" {
  run dk-resume; [ "$status" -eq 0 ]
  [ "${#lines[@]}" -le 150 ]
  [[ "$output" == *"## 你是 leader-login"* ]]; [[ "$output" == *".dkboai/LEADER.md"* ]]
  [[ "$output" == *"# 使用者登入"* ]]
  [[ "$output" == *" ev30"* ]]; [[ "$output" != *" ev5"* ]]
  [[ "$output" == *"[ESCALATE] 修一次未好"* ]]; [[ "$output" != *"[DONE] old"* ]]; [[ "$output" != *"[BUG] x"* ]]
  [[ "$output" == *"frontend: status: working"* ]]
  [[ "$output" == *"login-frontend working"* ]]
}
@test "resume <task> rebinds the pane" {
  rm "$DK_ROOT/.sessions/wB:p1"
  run dk-resume; [ "$status" -eq 1 ]
  run dk-resume login; [ "$status" -eq 0 ]
  [ "$(cat "$DK_ROOT/.sessions/wB:p1")" = "$(basename "$d")" ]
}
@test "employee ACK does not cut the leader's unprocessed messages" {
  printf '2026-09-10T10:04 login-frontend [ACK]\n' >> "$d/messages.log"
  run dk-resume; [ "$status" -eq 0 ]
  [[ "$output" == *"[ESCALATE] 修一次未好"* ]]
}
@test "resume trims state and process to stay under 150 lines" {
  for a in a b c d e f g h i j k l m n o p q r s t; do
    for i in $(seq 1 8); do echo "line $i" >> "$d/state/dev-$a.md"; done
  done
  run dk-resume; [ "$status" -eq 0 ]
  [ "${#lines[@]}" -le 150 ]
  [[ "$output" == *"dev-a: line 3"* ]]; [[ "$output" != *"dev-a: line 4"* ]]
}
