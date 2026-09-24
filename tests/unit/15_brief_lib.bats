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

@test "templates/brief.md 說明 repo 前綴的兩條規則" {
  # 多 repo 必帶、單 repo 禁帶 —— 這一段是人在寫 brief 時唯一看得到的說明
  grep -q '<名>:' "$DK_ROOT/templates/brief.md"
  grep -q 'DK_REPOS' "$DK_ROOT/templates/brief.md"
}

@test "AC12: 員工首段提示的 state 行數規則是「touched 清單以外 ≤20 行」" {
  . "$DK_ROOT/lib/prompt.sh"
  out=$(dk_first_prompt login-backend backend "$d" "$d/state/backend.md" 0 "$d/briefs/backend.md" "$d/state/backend.report.md")
  [[ "$out" == *"你的 state 檔是 $d/state/backend.md（touched 清單以外 ≤20 行，每完成一個子步驟就覆寫）"* ]]
}

@test "bklog AC9: dk_brief_md_rows 跳脫感知地挑列、拼回 markdown 列" {
  rows=$(printf '%s\n' '1|實作|backend|a \| b|M|過|預設' '1|實作|qa|x|S|過|' '2|實作|backend|y|S|過|')
  # 按欄位值挑列：\| 不算分隔，所以第 5 欄仍是難度
  [ "$(printf '%s\n' "$rows" | dk_brief_md_rows 7 1 1 3 backend)" = '| 1 | 實作 | backend | a \| b | M | 過 | 預設 |' ]
  [ "$(printf '%s\n' "$rows" | dk_brief_md_rows 7 5 M)" = '| 1 | 實作 | backend | a \| b | M | 過 | 預設 |' ]
  # 只取前 N 欄（所有權表的獨佔資源欄不進切片）
  [ "$(printf '%s\n' 'backend|src/**|a\|b|db' | dk_brief_md_rows 3 1 backend)" = '| backend | src/** | a\|b |' ]
  [ -z "$(printf '%s\n' "$rows" | dk_brief_md_rows 7 1 9)" ]
}
@test "bklog AC9: 做什麼欄的 \| 不讓 wave_members 的難度錯位" {
  sed -i 's#^| 1 | 實作 | backend | POST /login | M |#| 1 | 實作 | backend | a\\|b | M |#' "$b"
  [ "$(dk_brief_wave_members "$b" 1 | tr '\n' ' ')" = "backend(M) qa(S) " ]
  [ "$(dk_brief_wave_review "$b" 1)" = "預設" ]
}

@test "bklog AC10: templates/brief.md 的共用契約說明句講得出 <成員>@波<N>" {
  dk_brief_section "$DK_ROOT/templates/brief.md" "## 共用契約" | grep -q '^（一列一個契約。.*`<成員>@波<N>`'
}
@test "bklog Minor②: dk_brief_ncols 印欄數（\| 不算分隔），再附上指定欄的值" {
  [ "$(printf '%s\n' 'a|b\|c|d' | dk_brief_ncols)" = 3 ]
  [ "$(printf '%s\n' 'a|b\|c|d' 'x|y' | dk_brief_ncols 1 2)" = "$(printf '3\ta\tb\\|c\n2\tx\ty')" ]
}
