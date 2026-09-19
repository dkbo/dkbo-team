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
  now=$(date +%s)
  printf 'login-frontend wC:p2 %s dev 1 1\nlogin-qa wC:p3 %s review 1 2\nlogin-reviewer-a wB:p10 %s review 2 1\n' \
    "$((now - 90))" "$((now - 150))" "$((now - 1800))" > "$d/.panes"
  printf 'status: working\n' > "$d/state/reviewer-a.md"
}
teardown() { teardown_project; }

@test "resume prints the recovery pack under 150 lines" {
  run dk-resume; [ "$status" -eq 0 ]
  [ "${#lines[@]}" -le 150 ]
  [[ "$output" == *"## 你是 leader-login"* ]]; [[ "$output" == *".dkbo/skills/run/SKILL.md"* ]]
  [[ "$output" == *"# 使用者登入"* ]]
  [[ "$output" == *" ev30"* ]]; [[ "$output" != *" ev5"* ]]
  [[ "$output" == *"[ESCALATE] 修一次未好"* ]]; [[ "$output" != *"[DONE] old"* ]]; [[ "$output" != *"[BUG] x"* ]]
  [[ "$output" == *"frontend: status: working"* ]]
  [[ "$output" == *"wave: 1  base: abc1234  kinds down: codex"* ]]
  [[ "$output" == *"login-reviewer-a working 30 min TIMEOUT?"* ]]
  rul=$(printf '%s\n' "$output" | awk '/^## 裁定/{s=1; next} /^## process/{exit} s')
  [[ "$rul" == *"ruling: 用 JWT"* ]]; [[ "$rul" == *"ruling: 錯誤碼 422"* ]]; [[ "$rul" != *"ruling: old"* ]]
  printf '%s\n' "$output" | grep -qx '## process（最後 20 行）'
  [[ "$output" == *"tab 1: login-frontend(working 等了 1 min) login-qa(blocked 等了 2 min)"* ]]; [[ "$output" == *"tab 2: login-reviewer-a(? 等了 30 min)"* ]]
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
@test "本波段印任務與本波已進行的時間，在線員工每位附等了 N min" {
  # 時間戳用「今天 00:00」與「今天 HH:00」湊：epoch→字串的轉換要 date -d／-r，兩者各自限定
  # GNU／BSD，測試也要能在別人的機器上跑。這樣算出來的分鐘數只靠 date +%H／%M，純算術。
  H=$(date +%H); M=$(date +%M)
  sed -i "1i $(date +%Y-%m-%d)T00:00 task-new login" "$d/process.md"
  echo "$(date +%Y-%m-%d)T$H:00 wave-open 1 base abc1234 members frontend(M)" >> "$d/process.md"
  printf 'login-frontend wC:p2 %s dev 1 1\n' "$(( $(date +%s) - 600 ))" > "$d/.panes"
  run dk-resume; [ "$status" -eq 0 ]
  [[ "$output" =~ 任務已進行\ ([0-9]+)h\ ([0-9]+)m（自\ task-new） ]] || { echo "no 任務已進行 line"; false; }
  tot=$(( 10#${BASH_REMATCH[1]} * 60 + 10#${BASH_REMATCH[2]} )); exp=$(( 10#$H * 60 + 10#$M ))
  [ "$tot" -ge "$exp" ] && [ "$tot" -le "$((exp+1))" ]   # 跨分鐘時容一分
  [[ "$output" =~ 本波已進行\ ([0-9]+)m（自\ wave-open） ]] || { echo "no 本波已進行 line"; false; }
  w=$(( 10#${BASH_REMATCH[1]} )); [ "$w" -ge "$((10#$M))" ] && [ "$w" -le "$((10#$M+1))" ]
  [[ "$output" == *"login-frontend(working 等了 10 min)"* ]]
}
@test "沒有開波時只印任務那行" {
  sed -i "1i $(date +%Y-%m-%d)T00:00 task-new login" "$d/process.md"
  sed -i 's/^DK_WAVE=.*/DK_WAVE=""/' "$d/.task.env"
  run dk-resume; [ "$status" -eq 0 ]
  [[ "$output" == *"任務已進行 "* ]]; [[ "$output" != *"本波已進行"* ]]
}
