load ../helpers
setup() { setup_project; . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/frontmatter.sh"; . "$DK_ROOT/lib/brief.sh"; d=$(fixture_task login 使用者登入); fixture_brief "$d"; b="$d/brief.md"; }
teardown() { teardown_project; }

@test "owners: header, separator and （範例） rows dropped, fields trimmed" {
  run dk_brief_owners "$b"; [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [ "${lines[0]}" = "backend|src/api/**|src/web/**" ]; [ "${lines[1]}" = "frontend-cart|src/web/**|src/api/types.ts" ]; [ "${lines[2]}" = "qa|tests/**|—" ]
}
@test "waves: members per wave with tier, review column of the wave" {
  [ "$(dk_brief_wave_members "$b" 1 | tr '\n' ' ')" = "backend(M) qa(S) " ]
  [ "$(dk_brief_wave_members "$b" 2)" = "frontend-cart(S)" ]
  [ -z "$(dk_brief_wave_members "$b" 3)" ]
  [ "$(dk_brief_wave_review "$b" 1)" = "預設" ]; [ "$(dk_brief_wave_review "$b" 2)" = "kinds: claude codex" ]
  [ "$(dk_brief_waves "$b" | wc -l)" -eq 3 ]
}
@test "sections and acceptance" {
  [ "$(dk_brief_section "$b" "## 目標" | tr -d '\n')" = "登入 API 與表單。" ]
  [ "$(dk_brief_section "$b" "## 共用契約" | grep -c '^|')" = 3 ]
  [ "$(dk_brief_acceptance "$b" | wc -l)" -eq 2 ]
}
@test "member → role/alias/group" {
  [ "$(dk_member_role frontend-cart)" = "frontend cart" ]
  [ "$(dk_member_role qa)" = "qa " ]
  run dk_member_role designer; [ "$status" -eq 1 ]
  [ "$(dk_member_group qa)" = review ]; [ "$(dk_member_group reviewer-a)" = review ]; [ "$(dk_member_group backend)" = dev ]
}
@test "templates: brief has 審查 column and example rows; member/report templates carry tokens; state has report line" {
  grep -q '| 審查 |' "$DK_ROOT/templates/brief.md"; grep -q '^| （範例）1 |' "$DK_ROOT/templates/brief.md"
  for t in MEMBER WAVE WAVE_ROWS OWNER_ROWS CONTRACT CONSTRAINTS ACCEPTANCE PEERS BRIEF GOAL; do grep -q "{{$t}}" "$DK_ROOT/templates/brief-member.md"; done
  grep -q '^## 測試' "$DK_ROOT/templates/report-employee.md"; grep -q '{{AGENT}}' "$DK_ROOT/templates/report-employee.md"
  grep -q '^report:' "$DK_ROOT/templates/state.md"
}
@test "readers fail loudly on a missing brief" {
  run dk_brief_owners /nonexistent/brief.md; [ "$status" -eq 1 ]; [[ "$output" == *"no brief at"* ]]
  run dk_brief_acceptance /nonexistent/brief.md; [ "$status" -eq 1 ]
}

@test "constraints: 段落讀得到，範本帶著它" {
  [ "$(dk_brief_constraints "$b" | grep -v '^[[:space:]]*$' | tr -d '\n')" = "bash 3.2+；不得使用 bash 4 語法" ]
  grep -q '^## 全域約束$' "$DK_ROOT/templates/brief.md"
}

@test "interfaces: 共用契約表格的資料列讀得到" {
  run dk_brief_interfaces "$b"; [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = "login API|backend|frontend-cart, qa|POST /login {user,pw} → {token}|動它要先 ESCALATE" ]
}

@test "rows: 欄內的 \| 是字面管線，不切欄" {
  # 鑑別點是 \| 兩側的空白：錯切之後每一段都會各自被 trim 一次，\| 後面的空白被吃掉。
  # （純看拼回來的字串分不出好壞 —— 錯切的碎片用 | 接回去剛好還原成同一個字串。）
  cat > "$d/t.md" <<'T'
## 共用契約
| 契約 | 擁有者 | 消費者 | 形狀／簽名 | 變更流程 |
|---|---|---|---|---|
| a \| b | backend | qa | x \| y | 動它要先 ESCALATE |
T
  run dk_brief_interfaces "$d/t.md"; [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = 'a \| b|backend|qa|x \| y|動它要先 ESCALATE' ]
}
