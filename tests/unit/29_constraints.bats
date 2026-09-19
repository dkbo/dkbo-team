load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"; }
teardown() { teardown_project; }

@test "全域約束進成員切片" {
  run dk-wave-open 1; [ "$status" -eq 0 ]
  grep -q '^## 全域約束（全文）$' "$d/briefs/backend.md"
  grep -q 'bash 3.2+' "$d/briefs/backend.md"
  grep -q 'bash 3.2+' "$d/briefs/qa.md"
}
@test "全域約束進波審查切片" {
  dk-wave-open 1 >/dev/null; mkdir -p "$d/waves"; echo diff > "$d/waves/1.diff"
  run dk-review 1; [ "$status" -eq 0 ]
  grep -q 'bash 3.2+' "$d/briefs/reviewer-a.md"
}
@test "全域約束進計畫審查切片" {
  printf '把登入做出來\n（原文從這裡開始）\n人的原話在這裡\n' > "$d/request.md"
  run dk-brief-review; [ "$status" -eq 0 ]
  grep -q 'bash 3.2+' "$d/briefs/reviewer-p1.md"
}
