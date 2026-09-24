# testtrust-reviewer-a 報告（波 2）
審查範圍：`waves/2.diff`（base `b169571`，5 檔，未 commit 工作樹）對 brief 的 AC10 與全域約束。

## 規格合規
- ✅ AC10(a) `tests/unit/35_test_hygiene.bats:11` 新正規式：`;`／`&&`／`||`／`|`／`{`／`(` 後允許零個空白，`then`／`do`／`else` 後要空白。scratchpad 抽出新舊 `bang_scan` 逐樣本比對：7 個新必判樣本（`true;! foo`、`a &&! b`、`a ||! b`、`{ ! foo; }`、`(! foo)`、`x | ! foo`、`if a; then b; else ! foo; fi`）新版全判出，`b169571` 版全部漏判；5 個不判樣本兩版都不判。自我驗證樣本仍以 `b='!'` 在執行期寫臨時檔（`35:34-37`），35 的原始碼沒有字面違規；(a) 對 `git ls-files` 集合仍是 0（`ok 1`）。`echo "a;! b"` 會誤判，backend report 已說明取捨（逐行 grep 分不出引號、誤判方向是多報），我同意。grep 對 `\{`、`\(`、`\|` 沒有警告。
- ✅ AC10(b) `tests/helpers.bash:124-138` `fixture_env_check`：只要有一行含 `{{` 就回 1。實測 `{{FOO}`→印 FOO、`{{FOO`→FOO、`{{}`／`{{9x`→印整行、`}}{{`→印整行、無 `{{`→rc 0，全部只用 `local`。新增測試 `36_fixture.bats:44`（`DK_PROBE2="{{PROBE2"`）與 `:52`（`{{}` 印整行）；兩條在 `b169571` 副本上 `not ok 4`、`not ok 5`（我自己重跑的，與 backend 一致）。
- ✅ AC10(c) `36_fixture.bats:16` 另加 `refute_grep -vE '^(DK_[A-Z_]*=|[[:space:]]*#|[[:space:]]*$)'`。取紅：副本的 `fixture_task` 在子 shell 多印一行 `stray output` → `not ok 1`，stderr 點出那一行的樣式。
- ✅ AC10(d) `.dkbo/tasks/BACKLOG.md` 在表格最後一列之後加一列（4 欄，對得上表頭），寫明 reviewer-a Minor 4、`tests/helpers.bash:14`，也寫了「只複製追蹤檔會讓 worktree 未 commit 的 `.dkbo/` 改動進不了夾具」的取捨；diff 只有 1 行 `+`，其他行都沒動。
- ✅ AC10(e) `CHANGELOG.md` 0.15.0：「測試：」654→656（+18＝4＋14；36 列 9 條），`grep '^@test' tests/unit/*.bats` 合計 656，35 有 5 條、36 有 9 條，數字對得上；`test:` 條目補了收尾那一句。VERSION／README 沒動。最後要以 wave-close 實跑的數字為準。
- ✅ 全域約束：只動了波 2 列出的 5 個檔；`git diff b169571 -- .dkbo/bin .dkbo/lib .dkbo/kinds .dkbo/templates` 是空的；helpers.bash 只動 `fixture_env_check` 和它的註解；沒有 bash 4 語法（用的是 `<<<`、`${x:-y}`，3.2 都能跑）；沒新增 `!` 述句，也沒有 `run …; [ "$status" -ne 0 ]`；沒有改動或刪除既有斷言（35 只在樣本清單尾端加項，36 只在第 1 條尾端加一行、另外插兩條新測試）。

## Important
（無）

## Minor
累積 Minor 判定：切片註明逐波審查不 triage 累積 Minor，留給整枝評議。波 1 的 Minor 1–3 本波已修掉，Minor 4 已記進 BACKLOG。
1. `tests/unit/35_test_hygiene.bats:11` `(` 分隔符會把 `(( ! x ))` 判成違規，但算術指令的狀態 `set -e` 抓得到，是有效斷言；`f() { ! grep …; }`（helper 用否定當回傳值、呼叫端照樣會被 errexit 抓到）也會被判。AC 要求判出 `{ ! foo; }`，而且守門不留例外，現在也是 0 處，**可以留**：碰到時改寫就好（例如 `(( x == 0 ))`）。backend 疑慮段已提到前一種。
2. `tests/unit/36_fixture.bats:44` 只測了 `{{PROBE2`（沒結尾），沒有測 `{{FOO}`（只有一個 `}`）這種形狀；AC10(b) 只要求 PROBE2 那條，我在 scratchpad 直接呼叫 `fixture_env_check` 驗過會回 1 並印 FOO，**可以留**。
3. `tests/helpers.bash:133` 同一行混著可抽名字與抽不出名字的佔位符時（如 `{{X}} {{}`），只印 `X`、不印整行；rc 仍是 1、setup 照樣紅，只是訊息少了一點，**可以留**。

## 測試
不適用: reviewer 只讀、不改碼，沒有自己的紅／綠；以下是審查時實跑的驗證。
- worktree：`tests/run.sh tests/unit/35_test_hygiene.bats tests/unit/36_fixture.bats` → `1..14`，14 ok。
- `git archive b169571` 解到 scratchpad、放入本波的 36：`tests/run.sh tests/unit/36_fixture.bats` → `1..9`，`not ok 4`（PROBE2）、`not ok 5`（`{{}`），其餘 7 條 ok。
- 新舊 `bang_scan` 抽出來對 27 個樣本逐一比對（見規格合規 AC10(a)；另驗 `${!x}`、`[ "$a" != b ]`、`if ! foo`、`while ! foo`、`elif ! c` 新版都不判，`$(! foo)`、`(( ! x ))`、`f() { ! …; }` 會判）。
- 破壞副本（`fixture_task` 子 shell 多 echo 一行）跑 36 → `not ok 1`，是雜行斷言讓它紅的。
- 全套沒有重跑：backend 送 DONE 前已跑過 656 ok，wave-close 還會再跑一次當閘。

## 自我審查
- AC10 五項都有獨立驗證，不是照抄 backend report：(a)(b) 取紅我自己在 b169571 重跑過，(c) 自己做了破壞副本。
- 所有實驗都在 scratchpad 副本裡做，worktree 沒有任何寫入。

## 疑慮
（無）

---
# 波 1 報告（原文保留）
波 1：Important 0、Minor 4（皆可留），AC1–AC9 全 ✅；詳見 messages.log 09:54 的 verdict 與 minor 列。
