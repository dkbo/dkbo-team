load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"; b="$d/brief.md"; }
teardown() { teardown_project; }

@test "a good brief prints OK, exit 0, touches nothing" {
  before=$(md5sum "$b"); run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]; [ "$(md5sum "$b")" = "$before" ]
  run dk-brief-check "$b"; [ "$status" -eq 0 ]   # explicit path works too
}
@test "overlapping 可改 globs fail (** prefix vs literal, ** vs **)" {
  sed -i 's#| frontend-cart | src/web/\*\* |#| frontend-cart | src/** |#' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 所有權 backend/frontend-cart"* ]]; [[ "$output" == *"重疊"* ]]; [[ "$output" == *"1 FAIL"* ]]
  fixture_brief "$d"; printf '| it | src/api/types.ts | — |\n' | sed -i '/^| qa | tests/r /dev/stdin' "$b"   # literal path inside backend's src/api/** tree
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 所有權 backend/it"* ]]
}
@test "unknown role, duplicate member, empty 可改" {
  sed -i 's#^| qa | tests/\*\* | — |#| designer | ui/** | — |#' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 所有權 designer: 找不到角色檔"* ]]; [[ "$output" == *"FAIL 波次表 1 qa: 成員不在所有權表"* ]]
  fixture_brief "$d"; printf '| backend | db/** | — |\n' | sed -i '/^| qa | tests/r /dev/stdin' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"成員重複"* ]]
  fixture_brief "$d"; sed -i 's#^| qa | tests/\*\* | — |#| qa |  | — |#' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"可改欄為空"* ]]
}
@test "wave table: tier, contiguity, review column, unknown kind, missing review" {
  sed -i 's#| S | 全過 | |#| X | 全過 | |#' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"難度只能 S/M/L"* ]]
  fixture_brief "$d"; sed -i 's#^| 2 | 實作 | frontend-cart#| 3 | 實作 | frontend-cart#' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"波號不連續"* ]]
  fixture_brief "$d"; sed -i 's#| 測試過 | 預設 |#| 測試過 | always |#' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"審查欄須為"* ]]
  fixture_brief "$d"; sed -i 's#kinds: claude codex#kinds: claude nope#' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"未知 kind nope"* ]]
  fixture_brief "$d"; sed -i 's#kinds: claude codex#kinds: claude codex agy claude#' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"kinds 須 1 至 3 個"* ]]
  fixture_brief "$d"; sed -i 's#| 測試過 | 預設 |#| 測試過 | |#' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 波次表 1: 審查欄未填"* ]]
}
@test "全域約束: 段落不存在只警告，段落在但沒填要擋" {
  run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]
  sed -i '/^## 全域約束$/,+1d' "$b"        # 舊 brief：整段不存在
  run dk-brief-check; [ "$status" -eq 0 ]; [[ "$output" == *"WARN 全域約束"* ]]; [ "$output" != OK ]
  fixture_brief "$d"                        # 新 brief：段落在，只剩指引行
  sed -i 's/^bash 3.2+；不得使用 bash 4 語法$/（橫切所有波的硬要求）/' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 全域約束"* ]]; [[ "$output" == *"1 FAIL"* ]]
}
@test "acceptance and contract must be present" {
  sed -i '/^- \[ \] /d' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 驗收標準"* ]]
  # 表格化之後「段落為空」＝連表頭都沒有；只留指引行也算空
  fixture_brief "$d"; sed -i '/^| /d; /^|---|---|---|---|---|$/d' "$b"
  sed -i 's/^## 共用契約$/## 共用契約\n（誰定稿、放哪、變更流程）/' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 共用契約"* ]]
}
@test "more dev members than DK_TAB1_SLOTS in one wave is a WARN, exit 0" {
  for m in a b c d; do printf '| backend-%s | db/%s/** | — |\n' "$m" "$m" | sed -i '/^| qa | tests/r /dev/stdin' "$b"; done
  for m in a b c d; do printf '| 1 | 實作 | backend-%s | 表 | S | 過 | |\n' "$m" | sed -i '/^| 1 | 實作 | qa/r /dev/stdin' "$b"; done   # keep wave 1 rows contiguous
  run dk-brief-check; [ "$status" -eq 0 ]; [[ "$output" == *"WARN 波次表 1: dev 成員 5 位超過 tab 1 的 4 格"* ]]; [[ "$output" != OK ]]
  echo 'DK_TAB1_SLOTS="6"' >> "$DK_ROOT/settings.env"; run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]
}
@test "dies cleanly without a bound task or brief" {
  rm "$DK_ROOT/.sessions/wB:p1"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"no task bound"* ]]
  run dk-brief-check /nonexistent.md; [ "$status" -eq 1 ]; [[ "$output" == *"no brief"* ]]
}

@test "同一波兩位成員不得宣告同一個獨佔資源" {
  # 外部比較排入：worktree 隔離檔案，不隔離執行環境 —— 同波兩位 dev 仍會對同一個 dev DB
  # 跑 migration、搶同一個 port、重啟同一組 docker
  sed -i 's#^| backend | src/api/\*\* | src/web/\*\* |$#| backend | src/api/** | src/web/** | db, port:3000 |#' "$b"
  sed -i 's#^| qa | tests/\*\* | — |$#| qa | tests/** | — | db |#' "$b"
  run dk-brief-check "$b"
  [ "$status" -eq 1 ]; [[ "$output" == *"獨佔資源"* ]]; [[ "$output" == *"db"* ]]
}
@test "不同波宣告同一個獨佔資源是可以的" {
  sed -i 's#^| backend | src/api/\*\* | src/web/\*\* |$#| backend | src/api/** | src/web/** | db |#' "$b"
  sed -i 's#^| frontend-cart | src/web/\*\* | src/api/types.ts |$#| frontend-cart | src/web/** | src/api/types.ts | db |#' "$b"
  run dk-brief-check "$b"; [ "$status" -eq 0 ]   # backend 在波 1、frontend-cart 在波 2
}
@test "沒有獨佔資源欄的舊 brief 照常通過" {
  run dk-brief-check "$b"; [ "$status" -eq 0 ]
}

@test "共用契約: 表格的擁有者與消費者都要在所有權表" {
  sed -i 's/^| login API | backend |/| login API | nobody |/' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL 共用契約 login API: 擁有者 nobody 不在檔案所有權表"* ]]
  fixture_brief "$d"; sed -i 's/frontend-cart, qa/frontend-cart, ghost/' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"消費者 ghost 不在檔案所有權表"* ]]
}
@test "共用契約: 只有表頭是合法的「無契約」，自由文字只警告" {
  sed -i '/^| login API |/d' "$b"            # 只留表頭
  run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]
  fixture_brief "$d"
  sed -i '/^| 契約 | 擁有者 |/d; /^|---|---|---|---|---|$/d; /^| login API |/d' "$b"
  sed -i 's/^## 共用契約$/## 共用契約\n無/' "$b"
  run dk-brief-check; [ "$status" -eq 0 ]; [[ "$output" == *"WARN 共用契約"* ]]
}

@test "共用契約: 欄內 \| 不錯位（形狀欄與契約欄各一），裸管線要擋" {
  # 形狀欄寫 \| 很常見：描述回傳格式、正規表示式、shell pipe
  sed -i 's#POST /login {user,pw} → {token}#每列 `契約\\|擁有者\\|消費者`#' "$b"
  run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]
  # \| 在更前面的欄位時，錯位會直接汙染擁有者／消費者判定
  fixture_brief "$d"; sed -i 's#^| login API |#| login\\|API |#' "$b"
  run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]
  # 裸管線在 markdown 裡就是欄位分隔，切出第六欄 —— 要擋，不能靜默錯位
  fixture_brief "$d"; sed -i 's#POST /login {user,pw} → {token}#契約|擁有者#' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"欄數"* ]]
}
