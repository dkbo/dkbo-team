load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"; }
teardown() { teardown_project; }

@test "roles/reviewer.md 認得計畫審查，且格式以切片為準" {
  grep -q '計畫審查' "$DK_ROOT/roles/reviewer.md"
  grep -q '以切片為準' "$DK_ROOT/roles/reviewer.md"
}
@test "計畫審查範本問的是計畫，不是程式碼" {
  t="$DK_ROOT/templates/brief-reviewer-plan.md"
  for s in '## 需求覆蓋' '## 驗收標準可驗證性' '## 檔案所有權' '## 波次切法' '## Minor' '## 結論'; do
    grep -qF "$s" "$t" || { echo "缺少段落：$s"; false; }
  done
  grep -q '{{REQUEST}}' "$t"; grep -q '{{BRIEF}}' "$t"; grep -q '{{REPORT}}' "$t"; grep -q '{{DISPLAY}}' "$t"
  grep -q '不需要讀專案程式碼' "$t"
  # 需求覆蓋必須排在其餘四段之前：那是唯一只有看了 request 才答得出來的一段
  [ "$(grep -n '## 需求覆蓋' "$t" | cut -d: -f1)" -lt "$(grep -n '## 檔案所有權' "$t" | cut -d: -f1)" ]
}

have_request() { printf '人要一個登入功能，空密碼要擋掉。\n' > "$d/request.md"; }

@test "沒有 request.md 就拒跑，一個 pane 都不開" {
  run dk-brief-review
  [ "$status" -eq 1 ]; [[ "$output" == *"需求原文"* ]]
  refute_grep '^agent start' "$HERDR_STUB_LOG"
}
@test "request.md 是空的也拒跑" {
  : > "$d/request.md"
  run dk-brief-review; [ "$status" -eq 1 ]; [[ "$output" == *"需求原文"* ]]
  refute_grep '^agent start' "$HERDR_STUB_LOG"
}
@test "dk-brief-check 沒過就不燒 token" {
  have_request
  sed -i '/^- \[ \] /d' "$d/brief.md"          # 拿掉全部驗收標準 → dk-brief-check 必 FAIL
  run dk-brief-review; [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL 驗收標準"* ]]; [[ "$output" == *"dk-brief-check"* ]]
  refute_grep '^agent start' "$HERDR_STUB_LOG"
}
@test "正常路徑：別名 p1/p2、切片指向 request 與 brief、process 記一行" {
  have_request; printf 'DK_REVIEW_KINDS="claude codex"\n' >> "$DK_ROOT/settings.env"
  run dk-brief-review; [ "$status" -eq 0 ]
  [ "$output" = "brief-review: login-reviewer-p1(claude) login-reviewer-p2(codex)" ]
  grep -q '^agent start login-reviewer-p1 --kind claude ' "$HERDR_STUB_LOG"
  grep -q '^agent start login-reviewer-p2 --kind codex ' "$HERDR_STUB_LOG"
  grep -q -- '--env DK_ISOLATED=1' "$HERDR_STUB_LOG"
  grep -q ' brief-review spawned login-reviewer-p1(claude) login-reviewer-p2(codex)$' "$d/process.md"
  grep -qF "$d/request.md" "$d/briefs/reviewer-p1.md"
  grep -qF "$d/brief.md" "$d/briefs/reviewer-p1.md"
  grep -qF "$d/state/reviewer-p1.report.md" "$d/briefs/reviewer-p1.md"
  grep -q '## 需求覆蓋' "$d/briefs/reviewer-p2.md"
  grep -qF "$d/briefs/reviewer-p1.md" "$HERDR_STUB_LOG"   # 首輪提示用的是切片
}
@test "--kinds 與 --tier 覆寫；最多三位" {
  have_request
  run dk-brief-review --kinds "agy"; [ "$status" -eq 0 ]; [ "$output" = "brief-review: login-reviewer-p1(agy)" ]
  : > "$HERDR_STUB_LOG"
  run dk-brief-review --kinds "claude codex agy claude" --tier L; [ "$status" -eq 0 ]
  [ "$(grep -c '^agent start login-reviewer-p' "$HERDR_STUB_LOG")" -eq 3 ]
  grep -q -- '--model opus --effort high' "$HERDR_STUB_LOG"
  run dk-brief-review --tier S; [ "$status" -eq 1 ]
}
@test "熔斷的 kind 被跳過；全滅回非零並給出該記的 process 行" {
  have_request; sed -i 's/^DK_KIND_DOWN=.*/DK_KIND_DOWN="codex"/' "$d/.task.env"
  run dk-brief-review --kinds "codex claude"; [ "$status" -eq 0 ]
  [[ "$output" == *"login-reviewer-p1(claude)"* ]]; [[ "$output" == *"codex is down"* ]]
  : > "$HERDR_STUB_LOG"
  run dk-brief-review --kinds codex; [ "$status" -eq 1 ]
  [[ "$output" == *'brief-review skipped: all kinds down'* ]]
  refute_grep '^agent start' "$HERDR_STUB_LOG"
}
@test "全數 spawn 失敗時退非零，且不留下 spawned 行" {
  have_request
  HERDR_STUB_FAIL="agent start" run dk-brief-review; [ "$status" -eq 1 ]
  [[ "$output" == *"no reviewer spawned"* ]]
  refute_grep ' brief-review spawned' "$d/process.md"
}
@test "首輪提示失敗的 reviewer 仍算派出，但標 prompt-failed" {
  have_request
  HERDR_STUB_FAIL="agent prompt" run dk-brief-review; [ "$status" -eq 0 ]
  [[ "$output" == *"login-reviewer-p1(claude,prompt-failed)"* ]]
  grep -q ' brief-review spawned login-reviewer-p1(claude,prompt-failed)$' "$d/process.md"
}
@test "不吃位置參數（波號是執行階段的概念）" {
  have_request; run dk-brief-review 1
  [ "$status" -eq 1 ]; [[ "$output" == *"unexpected argument"* ]]
}
