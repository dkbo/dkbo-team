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
@test "acceptance and contract must be present" {
  sed -i '/^- \[ \] /d' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 驗收標準"* ]]
  fixture_brief "$d"; sed -i 's/^無$/（誰定稿、放哪、變更流程）/' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 共用契約"* ]]
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
