# reviewer-a — 波 4 審查（修復整枝評議的 2 條 Important、4 條 Minor）

審的是 `waves/4.diff`（16 檔、+93/−17、工作樹含未 commit；base 245cff2）。逐條核 AC18–AC24，並在 worktree 實跑測試與 shellcheck。

## 規格合規
- AC18 ✅ `skills/run/SKILL.md:16` 第 4 步裁定句後補「reviewer 的 Minor 逐條 `dk-process "minor N: <一句> <file:line>"`（格式需對齊 `dk-review` 讀它的正規表示式）」；測試 `tests/unit/04_docs.bats:88-92`。
- AC19 ✅ `roles/backend.md:18`、`roles/frontend.md:18`、`roles/qa.md:19` 都改成「修復迴圈兩輪（見 PROTOCOL.md，領導會視情況換人）」，不再寫「修一次」；測試 `tests/unit/04_docs.bats:79-86`（`refute_grep '修一次'` × 3 ＋ `grep '兩輪'` × 3）。
- AC20 ✅ `bin/dk-task-close:15`：`grep -v '^（' "$dir/report.md" | grep -qi 'minor'`，忽略範本指引行後再比對；測試 `tests/unit/12_task_close.bats:94-99` 用只留指引行的 report.md 驗證警告不被消掉。
- AC21 ✅ `bin/dk-wave-close:60`：`/^不適用[:：]/`，半形／全形冒號都豁免；測試 `tests/unit/08_wave_close.bats:148-152`。
- AC22 ✅ `lib/prompt.sh:2,11`：新增第 10 個位置參數 GROUP，`local tdd=""; [ "${10:-dev}" = dev ] && tdd="..."`；`bin/dk-spawn:92` 把既有的 `$group` 變數傳進第 10 位。測試 `tests/unit/07_spawn.bats:135-143`：backend（group dev）收到「先寫一條會失敗的測試」，qa（group review）不收到（`refute_grep`）。
- AC23 ✅ `bin/dk-spawn` 的 `[ -z "$handoff" ] || dk_process "ruling: …"` 一行從 pane split／agent start 之前（原 `resume` 區塊後）移到 `agent start` 成功、`echo … >> .panes` 之後（現行 :83 行，緊接在 :76 行 panes 記錄之後）；spawn 失敗（`dk_die`）不再走到這一行。測試 `tests/unit/07_spawn.bats:144-151`：`HERDR_STUB_FAIL="agent start"` 時 `status=1` 且 `process.md` 不含 `ruling: 換 codex`。
- AC24 ✅ `lib/common.sh:11-15` 新增 `DK_MINOR_RE`／`dk_minor_lines`／`dk_minor_count`，`bin/dk-review:32` 與 `bin/dk-task-close:11-12` 都改用它，不再各養一份正規表示式。測試 `tests/unit/01_common.bats:348-362`：四行 process.md（編號冒號、無編號冒號、漏冒號、不相關行）驗證兩支函式對「漏冒號」的判斷一致（都不算）。

檔案所有權：16 個變更檔全落在 backend 的 `.dkbo/**`、`tests/**`、`CHANGELOG.md`，無越界 ✅（`README.md`／`README.en.md` 本波未動，無需改）。

跨波契約：`dk_first_prompt` 前八個位置參數順序未動，第 9 個 HANDOFF 沿用波 3、新增第 10 個 GROUP（契約表只登記到波 2 為止，波 3/波 4 的擴充屬同一函式的向後相容擴充，不違反「要動前八個先 ESCALATE」）；`### 紅`／`### 綠` 形狀未動 ✅。

## Important
（無）

## Minor
（本波未發現新增項目；累積的 minor 1、minor 2 已由整枝評議 triage 為「可留、merge 前不必修」，非本波範圍，未複查）

## 測試
### 紅
不適用: reviewer 只讀不改碼，沒有「先寫一條會失敗的測試」這一步；以下是對本分支實跑的驗證。
### 綠
```
$ cd /home/bal/project/teamflow/.worktrees/flowgap && ./tests/run.sh 2>&1 | grep -E '^not ok|^1\.\.'
1..384
$ ./tests/run.sh 2>&1 | grep -c '^ok '
384
$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh && echo SHELLCHECK_CLEAN
SHELLCHECK_CLEAN
$ grep -n handoff .dkbo/bin/dk-spawn .dkbo/lib/prompt.sh
（確認 AC23/AC22 相關程式碼確實在檔案內，見上方逐條引用）
```
CHANGELOG.md 記「測試：384 bats（+7）；shellcheck 零警告」，與實跑結果一致。

## 自我審查
- 逐條 AC 都開了實際檔案確認行號，不是只看 diff 片段。
- 特別交叉核對過 AC22／AC23：位置參數順序（第 9 HANDOFF、第 10 GROUP）與落盤時機（pane/agent 起來之後）都用 `grep -n` 取實際行號驗證，不是只信 diff 的加號。
- `dk_minor_lines`／`dk_minor_count` 的正規表示式改動有反面測試（漏冒號的行兩邊都不算），不是只驗正面案例。
- 排除了一個一開始懷疑但查證後不成立的：擔心 `${10:-dev}` 在 bash 3.2 下位置參數語法是否需要跳脫——`${10}` 本來就是合法的花括號語法，非 `$10`，shellcheck 對此檔零警告已間接佐證。

## 疑慮
- 無。本波是 39 行的小修復波，7 條驗收標準逐一對應 7 個獨立小改動，範圍清楚、測試齊全。
