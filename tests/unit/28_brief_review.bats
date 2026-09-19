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
