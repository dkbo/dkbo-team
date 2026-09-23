load ../helpers
setup() { setup_project; . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/kinds.sh"; }
teardown() { teardown_project; }

# --- AC2: 恢復時間解析，純算術，不依賴 date -d ------------------------------

@test "agy: 有小時的 Resets in（實測原文）" {
  [ "$(dk_kind_parse_agy_reset 'Individual quota reached, Resets in 102h11m1s')" = "$((102*3600 + 11*60 + 1))" ]
}
@test "agy: 沒有小時的 Resets in（構造樣本，沒有實測過）" {
  [ "$(dk_kind_parse_agy_reset 'Resets in 45m10s')" = "$((45*60 + 10))" ]
  [ "$(dk_kind_parse_agy_reset 'Resets in 7m')" = "$((7*60))" ]
}
@test "agy: 解析不到就回非零" {
  run dk_kind_parse_agy_reset 'thinking...'; [ "$status" -ne 0 ]
}

@test "codex: 構造樣本 11th（非實測原文，任務記憶只留過 flowgap 的轉述）" {
  [ "$(dk_kind_parse_codex_reset 'Try again at Nov 11th, 2026 3:15 PM')" = "2026-11-11T15:15" ]
}
@test "codex: 非 th 序數 22nd 與 1st" {
  [ "$(dk_kind_parse_codex_reset 'Try again at Mar 22nd, 2026 1:05 AM')" = "2026-03-22T01:05" ]
  [ "$(dk_kind_parse_codex_reset 'Try again at Apr 1st, 2026 11:59 PM')" = "2026-04-01T23:59" ]
}
@test "codex: 12 AM / 12 PM 邊界" {
  [ "$(dk_kind_parse_codex_reset 'Try again at Jan 1st, 2027 12:00 AM')" = "2027-01-01T00:00" ]
  [ "$(dk_kind_parse_codex_reset 'Try again at Jan 1st, 2027 12:00 PM')" = "2027-01-01T12:00" ]
}
@test "codex: 解析不到就回非零" {
  run dk_kind_parse_codex_reset 'thinking...'; [ "$status" -ne 0 ]
}

@test "dk_kind_recover_epoch: agy 算術得 exact" {
  read -r epoch tag <<< "$(dk_kind_recover_epoch agy 'Individual quota reached, Resets in 1h0m0s')"
  [ "$tag" = exact ]
  now=$(date +%s); diff=$(( epoch - (now + 3600) )); [ "${diff#-}" -le 5 ]
}
@test "dk_kind_recover_epoch: codex 算術得 exact，用 dk_ts_minutes 差值不用 date -d" {
  now_epoch=$(date +%s); now_min=$(dk_ts_minutes "$(dk_now)")
  target_min=$(dk_ts_minutes "2026-11-11T15:15")
  expected=$(( now_epoch + (target_min - now_min) * 60 ))
  read -r epoch tag <<< "$(dk_kind_recover_epoch codex 'Your usage limit will reset. Try again at Nov 11th, 2026 3:15 PM.')"
  [ "$tag" = exact ]
  diff=$(( epoch - expected )); [ "${diff#-}" -le 120 ]
}
@test "dk_kind_recover_epoch: 兩種都解析不到就現在+5小時，標 guess" {
  now=$(date +%s)
  read -r epoch tag <<< "$(dk_kind_recover_epoch agy 'thinking...')"
  [ "$tag" = guess ]; diff=$(( epoch - (now + 5*3600) )); [ "${diff#-}" -le 5 ]
  read -r epoch tag <<< "$(dk_kind_recover_epoch codex 'thinking...')"
  [ "$tag" = guess ]
  read -r epoch tag <<< "$(dk_kind_recover_epoch unknown-kind 'whatever')"
  [ "$tag" = guess ]
}
@test "dk_kind_recover_epoch: codex 目標時間已過（時區不一致等）改走 guess，不誤標 exact" {
  now=$(date +%s)
  read -r epoch tag <<< "$(dk_kind_recover_epoch codex 'Try again at Jan 1st, 2020 12:00 AM.')"
  [ "$tag" = guess ]; diff=$(( epoch - (now + 5*3600) )); [ "${diff#-}" -le 5 ]
}
@test "AC2: 拒絕 -d 的假 date 下，codex 樣本算出的 epoch 與正常環境相差 ≤ 60 秒" {
  normal=$(dk_kind_recover_epoch codex 'Try again at Nov 11th, 2026 3:15 PM.')
  read -r normal_epoch _ <<< "$normal"
  real_date=$(command -v date)
  fakedir="$PROJECT/fakedate"; mkdir -p "$fakedir"
  cat > "$fakedir/date" <<EOF
#!/bin/sh
for a in "\$@"; do
  case "\$a" in -d|--date|--date=*) echo "fake date: -d not supported" >&2; exit 1;; esac
done
exec "$real_date" "\$@"
EOF
  chmod +x "$fakedir/date"
  fake=$(PATH="$fakedir:$PATH" bash -c '. "'"$DK_ROOT"'/lib/common.sh"; . "'"$DK_ROOT"'/lib/kinds.sh"; dk_kind_recover_epoch codex "Try again at Nov 11th, 2026 3:15 PM."')
  read -r fake_epoch _ <<< "$fake"
  diff=$(( fake_epoch - normal_epoch )); [ "${diff#-}" -le 60 ]
}

# --- AC1: kinds-down 檔（形狀、更新較晚不重複、過期不當場刪） ------------------

@test "dk_kinds_down_set 寫一列，dk_kinds_down_rows 只印未過期的" {
  dk_kinds_down_set codex "$(( $(date +%s) + 3600 ))" exact taskA agentA "hit line 1"
  rows=$(dk_kinds_down_rows)
  [ "$(printf '%s\n' "$rows" | wc -l)" -eq 1 ]
  [[ "$rows" == codex\ * ]]; [[ "$rows" == *" exact "* ]]; [[ "$rows" == *" taskA "* ]]; [[ "$rows" == *" agentA "*"hit line 1" ]]
  # 過期列不進 rows，但檔案裡還留著（讀的人略過就好，不必當場刪）
  dk_kinds_down_set agy "$(( $(date +%s) - 10 ))" exact taskB agentB "old hit"
  rows=$(dk_kinds_down_rows)
  refute_grep '^agy ' <<< "$rows"
  grep -q '^agy ' "$(dk_kinds_down_file)"
}
@test "同一 kind 已有未過期列就取較晚的恢復時間，不重複" {
  now=$(date +%s)
  dk_kinds_down_set codex "$((now + 1000))" exact taskA agentA "hit1"
  dk_kinds_down_set codex "$((now + 5000))" exact taskB agentB "hit2"
  rows=$(dk_kinds_down_rows)
  [ "$(printf '%s\n' "$rows" | wc -l)" -eq 1 ]
  [[ "$rows" == *"$((now + 5000))"* ]]
  # 較早的恢復時間不會覆蓋較晚的
  dk_kinds_down_set codex "$((now + 2000))" exact taskC agentC "hit3"
  rows=$(dk_kinds_down_rows)
  [[ "$rows" == *"$((now + 5000))"* ]]
}
@test "dk_kind_down_notice：沒熔斷回非零；熔斷時印共用契約的整句" {
  run dk_kind_down_notice codex; [ "$status" -ne 0 ]
  dk_kinds_down_set codex "$(( $(date +%s) + 3600 ))" exact my-task agentA "撞額度樣本"
  msg=$(dk_kind_down_notice codex)
  [[ "$msg" == "kind codex 在專案層熔斷到"*"（my-task），跳過" ]]
}
@test "dk_kinds_down_remove：拿掉所有該 kind 列（含過期的）；沒東西可拿回 1" {
  now=$(date +%s)
  dk_kinds_down_set codex "$((now + 3600))" exact taskA agentA hit1
  dk_kinds_down_set codex "$((now - 10))" exact taskB agentB hit2
  dk_kinds_down_set agy "$((now + 3600))" exact taskC agentC hit3
  run dk_kinds_down_remove codex; [ "$status" -eq 0 ]
  refute_grep '^codex ' "$(dk_kinds_down_file)"
  grep -q '^agy ' "$(dk_kinds_down_file)"
  run dk_kinds_down_remove codex; [ "$status" -eq 1 ]
}

# --- dk-watch 整合：AC1 + AC5 --------------------------------------------------

fixture_login() { d=$(fixture_task login 使用者登入); export DK_TASK_DIR="$d"; }
screen() { printf '{"id":"cli:agent:read","result":{"read":{"text":"%s"}}}\n' "$1" > "$HERDR_STUB_RESPONSES/agent_read.json"; }

@test "dk-watch 撞額度時寫入專案層 kinds-down，形狀符合共用契約" {
  fixture_login
  printf 'login-frontend wC:p2 %s dev 1 1\n' "$(date +%s)" > "$d/.panes"
  echo "2026-09-10T10:00 spawn login-frontend (agy M)" >> "$d/process.md"
  screen "Individual quota reached, Resets in 2h0m0s"
  sed -i 's/"name":"login-frontend","agent_status":"working"/"name":"login-frontend","agent_status":"idle"/' \
    "$HERDR_STUB_RESPONSES/agent_list.json"
  dk-watch --once
  row=$(cat "$DK_ROOT/.sessions/kinds-down")
  set -- $row
  [ "$1" = agy ]; [ "$3" = exact ]; [ "$5" = "$(basename "$d")" ]; [ "$6" = login-frontend ]
  [[ "$row" == *"Individual quota reached"* ]]
  now=$(date +%s); diff=$(( $2 - (now + 7200) )); [ "${diff#-}" -le 5 ]
}
@test "reviewer 逾時造成的熔斷不寫進專案層 kinds-down" {
  fixture_login
  old=$(( $(date +%s) - 1500 ))
  printf 'login-reviewer-b wC:p4 %s review 1 3\n' "$old" > "$d/.panes"
  echo "2026-09-10T10:00 spawn login-reviewer-b (codex M) override-kind isolated" >> "$d/process.md"
  echo '{"result":{"read":{"text":"thinking..."}}}' > "$HERDR_STUB_RESPONSES/agent_read.json"
  dk-watch --once
  grep -q '^DK_KIND_DOWN="codex"$' "$d/.task.env"          # 本任務層照舊熔斷
  [ ! -f "$DK_ROOT/.sessions/kinds-down" ]                  # 專案層完全不動
}

# --- AC3: dk_review_kinds 把專案層熔斷視同已熔斷 ------------------------------

@test "dk_review_kinds: 專案層熔斷的 kind 被跳過，訊息是共用契約那句" {
  . "$DK_ROOT/lib/review.sh"
  dk_kinds_down_set codex "$(( $(date +%s) + 3600 ))" exact other-task agentX hitX
  run dk_review_kinds "codex claude" dk-review review; [ "$status" -eq 0 ]
  [[ "$output" == *"kind codex 在專案層熔斷到"*"（other-task），跳過"* ]]
  [[ "$output" == *$'\n'"claude "* ]]
}
@test "dk_review_kinds: 只剩專案層熔斷的 kind 時，跟既有的任務層一樣全滅回非零" {
  . "$DK_ROOT/lib/review.sh"
  dk_kinds_down_set codex "$(( $(date +%s) + 3600 ))" exact other-task agentX hitX
  run dk_review_kinds codex dk-review review; [ "$status" -eq 1 ]
  [[ "$output" == *"all kinds down"* ]]
}

# --- AC6: dk-kind status / up -------------------------------------------------

@test "dk-kind status：全部恢復時印沒有熔斷" {
  run dk-kind; [ "$status" -eq 0 ]; [ "$output" = "沒有專案層熔斷" ]
  run dk-kind status; [ "$status" -eq 0 ]; [ "$output" = "沒有專案層熔斷" ]
}
@test "dk-kind status：列出未恢復的 kind，含 guess 標記與來源任務、第一條證據" {
  now=$(date +%s)
  dk_kinds_down_set codex "$((now + 3600))" exact my-task agentA "hit line here"
  dk_kinds_down_set agy "$((now + 3600))" guess my-task agentB "another hit"
  run dk-kind status; [ "$status" -eq 0 ]
  [[ "$output" == *"codex  down until "* ]]; [[ "$output" == *"from my-task — hit line here"* ]]
  [[ "$output" == *"agy  down until "*" (guess)"*"from my-task — another hit"* ]]
}
@test "dk-kind up：拿掉 kinds-down 與綁著任務時的 DK_KIND_DOWN，process 記一行" {
  d=$(fixture_task login 使用者登入); export DK_TASK_DIR="$d"
  sed -i 's/^DK_KIND_DOWN=.*/DK_KIND_DOWN="codex agy"/' "$d/.task.env"
  now=$(date +%s)
  dk_kinds_down_set codex "$((now + 3600))" exact my-task agentA hit1
  run dk-kind up codex; [ "$status" -eq 0 ]; [ "$output" = "kind codex up" ]
  refute_grep '^codex ' "$DK_ROOT/.sessions/kinds-down"
  grep -q '^DK_KIND_DOWN="agy"$' "$d/.task.env"
  grep -q ' kind codex up$' "$d/process.md"
}
@test "AC16 I1: DK_KIND_DOWN 只有目標 kind 時 up 仍要成功" {
  d=$(fixture_task login 使用者登入); export DK_TASK_DIR="$d"
  sed -i 's/^DK_KIND_DOWN=.*/DK_KIND_DOWN="codex"/' "$d/.task.env"
  run dk-kind up codex; [ "$status" -eq 0 ]; [ "$output" = "kind codex up" ]
  grep -q '^DK_KIND_DOWN=""$' "$d/.task.env"
  grep -q ' kind codex up$' "$d/process.md"
}
@test "dk-kind up：兩張清單都沒有這個 kind 就印說明並 exit 0" {
  d=$(fixture_task login 使用者登入); export DK_TASK_DIR="$d"
  run dk-kind up codex; [ "$status" -eq 0 ]
  [[ "$output" == *"沒有熔斷"* ]]
  refute_grep 'kind codex up' "$d/process.md"
}
@test "dk-kind up：沒綁任務時只動 kinds-down，不因為 dk_task_dir 失敗而死" {
  rm -f "$DK_ROOT/.sessions/${HERDR_PANE_ID:?}"
  now=$(date +%s)
  dk_kinds_down_set codex "$((now + 3600))" exact my-task agentA hit1
  run dk-kind up codex; [ "$status" -eq 0 ]; [ "$output" = "kind codex up" ]
  refute_grep '^codex ' "$DK_ROOT/.sessions/kinds-down"
}
@test "dk-kind up：不是 kinds/*.sh 裡的 kind 就 exit 2" {
  run dk-kind up not-a-kind; [ "$status" -eq 2 ]
}
@test "dk-kind：usage 錯誤 exit 2" {
  run dk-kind bogus; [ "$status" -eq 2 ]
  run dk-kind up; [ "$status" -eq 2 ]
}
@test "dk-kind 以 100755 的權限存在（git ls-files -s 在結案 commit 後會看到這個 mode）" {
  [ -x "$DK_ROOT/bin/dk-kind" ]
}
