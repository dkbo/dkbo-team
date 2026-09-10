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
  cat >> "$d/process.md" <<'P'
2026-09-10T11:00 ruling: old — before the wave — n/a
2026-09-10T11:01 wave-open 1 base abc1234 members frontend(M) qa(S)
2026-09-10T11:02 ruling: 用 JWT — brief 指定 — 低
2026-09-10T11:03 ruling: 錯誤碼 422 — 契約 — 中
P
  sed -i 's/^DK_WAVE=.*/DK_WAVE="1"/; s/^DK_KIND_DOWN=.*/DK_KIND_DOWN="codex"/' "$d/.task.env"
  printf 'login-frontend wC:p2 0 dev 1 1\nlogin-qa wC:p3 0 review 1 2\nlogin-reviewer-a wB:p10 %s review 2 1\n' "$(( $(date +%s) - 1800 ))" > "$d/.panes"
  printf 'status: working\n' > "$d/state/reviewer-a.md"
}
teardown() { teardown_project; }

@test "resume prints the recovery pack under 150 lines" {
  run dk-resume; [ "$status" -eq 0 ]
  [ "${#lines[@]}" -le 150 ]
  [[ "$output" == *"## 你是 leader-login"* ]]; [[ "$output" == *".dkbo/LEADER.md"* ]]
  [[ "$output" == *"# 使用者登入"* ]]
  [[ "$output" == *" ev30"* ]]; [[ "$output" != *" ev5"* ]]
  [[ "$output" == *"[ESCALATE] 修一次未好"* ]]; [[ "$output" != *"[DONE] old"* ]]; [[ "$output" != *"[BUG] x"* ]]
  [[ "$output" == *"frontend: status: working"* ]]
  [[ "$output" == *"wave: 1  base: abc1234  kinds down: codex"* ]]
  [[ "$output" == *"login-reviewer-a working 30 min TIMEOUT?"* ]]
  [[ "$output" == *"ruling: 用 JWT"* ]]; [[ "$output" == *"ruling: 錯誤碼 422"* ]]; [[ "$output" != *"ruling: old"* ]]
  [[ "$output" == *"tab 1: login-frontend(working) login-qa(blocked)"* ]]; [[ "$output" == *"tab 2: login-reviewer-a(?)"* ]]
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
@test "no open wave and empty .panes fall back to plain text and the agent list" {
  sed -i 's/^DK_WAVE=.*/DK_WAVE=""/' "$d/.task.env"; : > "$d/.panes"
  run dk-resume; [ "$status" -eq 0 ]; [[ "$output" == *"沒有開著的波"* ]]; [[ "$output" == *"login-frontend working"* ]]
}
@test "rulings are trimmed to the last 5 only as the final degradation step" {
  for i in $(seq 1 60); do echo "2026-09-10T12:00 ruling: r$i — x — y" >> "$d/process.md"; done
  for a in a b c d e f g h i j k l m n o p q r s t; do for i in $(seq 1 8); do echo "line $i" >> "$d/state/dev-$a.md"; done; done
  run dk-resume; [ "$status" -eq 0 ]; [ "${#lines[@]}" -le 150 ]
  [[ "$output" == *"ruling: r60 —"* ]]; [[ "$output" != *"ruling: r30 —"* ]]   # 裁定段只剩最後 5 行；process 尾 10 行也不含 r30
}
