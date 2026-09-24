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

# ── repo 前綴（AC5）──────────────────────────────────────────────────────────
# dk-brief-check 跑在關卡①之前，任務還沒實體化 —— 那時還沒有 .repos，repo 名字只能查
# settings.env 的 DK_REPOS。fixture_task 落的那一份是「已實體化」的樣子，這裡先拿掉。
multirepo_mode() { setup_multirepo; rm -f "$d/.repos"; }
# 多 repo 用的所有權表：可改與只讀每個 glob 都帶 <名>: 前綴
multirepo_brief() {
  sed -i 's#^| backend | src/api/\*\* | src/web/\*\* |$#| backend | api:src/** | main:src/web/** |#' "$b"
  sed -i 's#^| frontend-cart | src/web/\*\* | src/api/types.ts |$#| frontend-cart | main:src/web/** | api:src/types.ts |#' "$b"
  sed -i 's#^| qa | tests/\*\* | — |$#| qa | main:tests/** | — |#' "$b"
}

@test "多 repo：缺前綴的 glob 要 FAIL，補上前綴就過" {
  multirepo_mode
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"前綴"* ]]; [[ "$output" == *"所有權 backend"* ]]
  multirepo_brief
  run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]
}
@test "多 repo：未知的 repo 名字要 FAIL（可改與只讀兩欄都驗）" {
  multirepo_mode; multirepo_brief
  sed -i 's#| backend | api:src/\*\* |#| backend | nope:src/** |#' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"nope"* ]]
  multirepo_brief
  sed -i 's#| main:src/web/\*\* |$#| ghost:src/web/** |#' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"ghost"* ]]
}
@test "單 repo：帶前綴的 glob 要 FAIL" {
  multirepo_brief
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"單 repo"* ]]
}
@test "多 repo：重疊只在同一個 repo 內判" {
  multirepo_mode; multirepo_brief
  # 跨 repo 的同一條 glob 不算重疊
  sed -i 's#^| qa | main:tests/\*\* | — |$#| qa | shared:src/** | — |#' "$b"
  run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]
  # 同一個 repo 內就算
  multirepo_brief
  sed -i 's#^| frontend-cart | main:src/web/\*\* |#| frontend-cart | api:src/web/** |#' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"重疊"* ]]; [[ "$output" == *"所有權 backend/frontend-cart"* ]]
}

@test "已實體化的任務以 .repos 為準（DK_REPOS 之後被改動也不影響本任務）" {
  setup_multirepo; multirepo_brief           # .repos 是 fixture 落的單列 main
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"未知的 repo 名字 api"* ]]
}

@test "所有權的 glob 不被 cwd 的真實檔名展開（reviewer-a Important 1）" {
  # dk-brief-check 不 cd，執行時的 cwd 就是專案根。未加引號的 $(…) 在 word splitting 之後
  # 還會做 pathname expansion，所以 cwd 底下真的存在符合的檔時，`.dkbo/kinds/**` 會被換成
  # 三個實際檔名 —— 真正的 glob 字串反而沒被驗到，多 repo 的前綴檢查形同虛設。
  multirepo_mode
  sed -i 's#^| backend | src/api/\*\* | src/web/\*\* |$#| backend | .dkbo/kinds/** | — |#' "$b"
  [ -f "$PWD/.dkbo/kinds/agy.sh" ]          # 前提：cwd 底下真的有符合的檔
  run dk-brief-check
  [ "$status" -eq 1 ]
  [[ "$output" == *".dkbo/kinds/**"* ]]                    # 訊息指的是 brief 裡那條 glob
  refute_grep -q 'kinds/agy\.sh' <<< "$output"             # 不是被展開出來的檔名
  [ "$(printf '%s\n' "$output" | grep -c '^FAIL 所有權 backend')" -eq 1 ]   # 一條 glob 一條 FAIL
}

@test "獨佔資源欄同樣不被 cwd 的真實檔名展開（Important 1 的同類洞）" {
  # 同一個未加引號的 for，line 85。獨佔資源是自由文字（db、port:3000、docker…），
  # 可以含 * 與 ? —— 波號與成員名那幾個迴圈是數字與 [a-z0-9_-]，不會被展開，這個會。
  : > "$PWD/build-a"; : > "$PWD/build-b"
  sed -i 's#^| backend | src/api/\*\* | src/web/\*\* |$#| backend | src/api/** | src/web/** | build-* |#' "$b"
  sed -i 's#^| qa | tests/\*\* | — |$#| qa | tests/** | — | build-* |#' "$b"
  run dk-brief-check
  [ "$status" -eq 1 ]
  [[ "$output" == *"獨佔資源 build-* 同時被"* ]]      # 訊息指的是宣告的那個字串
  refute_grep -q 'build-a' <<< "$output"              # 不是 cwd 展開出來的檔名
}

# ── bklog AC9：欄數閘 ───────────────────────────────────────────────────────
@test "bklog AC9: 所有權表每列 3 或 4 欄，其他欄數 FAIL 並指出哪一列" {
  run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]                       # 3 欄（fixture）
  sed -i 's#^| backend | src/api/\*\* | src/web/\*\* |$#| backend | src/api/** | src/web/** | db |#' "$b"
  run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]                       # 4 欄（獨佔資源選填）
  sed -i 's#^| backend | src/api/\*\* | src/web/\*\* | db |$#| backend | src/api/** | src/web/** | db | x |#' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 所有權 backend: 每列須 3 或 4 欄"* ]]; [[ "$output" == *"得到 5 欄"* ]]
  fixture_brief "$d"; sed -i 's#^| qa | tests/\*\* | — |$#| qa | tests/** |#' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 所有權 qa: 每列須 3 或 4 欄"* ]]; [[ "$output" == *"得到 2 欄"* ]]
}
@test "bklog AC9: 波次表每列固定 7 欄，\| 不算分隔" {
  sed -i 's#^| 1 | 實作 | backend | POST /login | M |#| 1 | 實作 | backend | 拆 a\\|b | M |#' "$b"
  run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]                       # 跳脫的管線：仍 7 欄，難度沒錯位
  fixture_brief "$d"; sed -i 's#^| 1 | 實作 | backend | POST /login | M |#| 1 | 實作 | backend | 拆 a|b | M |#' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 波次表 1 backend: 每列須 7 欄，得到 8 欄"* ]]
  fixture_brief "$d"; sed -i 's#^| 1 | 實作 | qa | 驗 API | S | 全過 | |$#| 1 | 實作 | qa | 驗 API | S | 全過 |#' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 波次表 1 qa: 每列須 7 欄，得到 6 欄"* ]]
}

# ── bklog AC10：契約欄的 <成員>@波<N> ──────────────────────────────────────
@test "bklog AC10: 擁有者／消費者寫 <成員>@波<N> 合法時照過" {
  sed -i 's/^| login API | backend | frontend-cart, qa |/| login API | backend@波1 | frontend-cart@波2, qa@波1 |/' "$b"
  run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]
}
@test "bklog AC10: @波N 的成員不存在要 FAIL" {
  sed -i 's/^| login API | backend | frontend-cart, qa |/| login API | ghost@波1 | frontend-cart, qa |/' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 共用契約 login API: 擁有者 ghost@波1 不在檔案所有權表"* ]]
}
@test "bklog AC10: @波N 的波號不存在要 FAIL" {
  sed -i 's/^| login API | backend | frontend-cart, qa |/| login API | backend | frontend-cart@波9, qa |/' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 共用契約 login API: 消費者 frontend-cart@波9 的波 9 不在波次表"* ]]
}
@test "bklog AC10: @波N 的成員不在那一波要 FAIL" {
  sed -i 's/^| login API | backend | frontend-cart, qa |/| login API | backend@波2 | frontend-cart, qa |/' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 共用契約 login API: 擁有者 backend@波2 不在第 2 波"* ]]
}

# ── bklog AC8：無主測試檔 WARN ──────────────────────────────────────────────
# 測試檔要在 git ls-files 裡才算：fixture 的 $PROJECT 只有一個空 commit，這裡補進版控。
ac8_repo() {
  sed -i 's#^| backend | src/api/\*\* | src/web/\*\* |$#| backend | src/api/**, lib/auth.sh, docs/auth.md | src/web/** |#' "$b"
  mkdir -p "$PROJECT/spec" "$PROJECT/tests" "$PROJECT/lib"
  echo 'source lib/auth.sh' > "$PROJECT/spec/auth.spec.js"
  echo 'load auth.sh' > "$PROJECT/tests/auth.bats"
  echo 'see auth.sh' > "$PROJECT/spec/notes.md"             # 不是測試檔
  echo 'docs/auth.md' > "$PROJECT/spec/doc.test.js"         # 只引用 .md 來源
  echo 'lib/*.sh' > "$PROJECT/spec/glob.test.js"            # 只引用 glob 來源（src/api/** 的「**」）
  : > "$PROJECT/lib/auth.sh"
  git -C "$PROJECT" add spec tests lib && git -C "$PROJECT" commit -qm fixtures
}
@test "bklog AC8: 無人擁有的測試檔引用了成員的可改檔 → WARN，exit 0" {
  ac8_repo
  run dk-brief-check; [ "$status" -eq 0 ]
  [[ "$output" == *"WARN 所有權: spec/auth.spec.js 引用了 auth.sh（backend 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）"* ]]
  [ "$(printf '%s\n' "$output" | grep -c '^WARN 所有權:')" -eq 1 ]   # tests/auth.bats 有主（qa 的 tests/**）
}
@test "bklog AC8: 測試檔有人擁有就不 WARN" {
  ac8_repo
  sed -i 's#^| qa | tests/\*\* | — |$#| qa | tests/**, spec/** | — |#' "$b"
  run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]
}
@test "bklog AC8: glob 路徑與 .md 來源不觸發" {
  ac8_repo
  sed -i 's#| src/api/\*\*, lib/auth.sh, docs/auth.md |#| src/api/**, lib/*.sh, docs/auth.md |#' "$b"
  run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]
  refute_grep -q 'doc.test.js' <<< "$output"; refute_grep -q 'glob.test.js' <<< "$output"
}
@test "bklog AC8: 多 repo 各在自己的 ls-files 裡找，路徑帶 <名>:" {
  multirepo_mode; multirepo_brief
  sed -i 's#^| backend | api:src/\*\* |#| backend | api:src/**, api:lib/client.sh |#' "$b"
  api="$REPO_API"
  mkdir -p "$api/spec" "$PROJECT/spec"
  echo 'client.sh' > "$api/spec/client.spec.js"; git -C "$api" add spec && git -C "$api" commit -qm t
  echo 'client.sh' > "$PROJECT/spec/client.spec.js"; git -C "$PROJECT" add spec && git -C "$PROJECT" commit -qm t   # 別的 repo 的同名引用不算
  run dk-brief-check; [ "$status" -eq 0 ]
  [[ "$output" == *"WARN 所有權: api:spec/client.spec.js 引用了 client.sh（backend 的可改檔）"* ]]
  refute_grep -q 'main:spec/client.spec.js' <<< "$output"
}

@test "bklog: dk_glob_check 在 pipefail 下不會偶發誤判「未知的 repo 名字」（SIGPIPE 回歸）" {
  # printf … | grep -qx：grep 命中第一列就退出，printf 偶爾還沒寫完 → SIGPIPE → pipefail 下整條
  # 管線非零，合法的 main: 被判成未知（base 實測直呼 3000 次 20 次）。舊寫法下 1500 次實測紅率約九成（400 次約四成）。
  multirepo_mode
  run bash -c 'set -euo pipefail; . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/repos.sh"; dk_settings
    for i in $(seq 1 1500); do dk_glob_check "" "main:tests/**" >/dev/null || { echo "誤判 at $i"; exit 1; }; done; echo ok'
  [ "$status" -eq 0 ]; [ "$output" = ok ]
}
