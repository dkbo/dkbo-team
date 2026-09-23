# 營運回饋修補（panova headermerge） — 波 4 審查（reviewer 切片）
你是本波的 reviewer：只讀、不改碼、不跑會寫入的指令。意見只給領導（`dk-msg leader`），不直接對 dev 說。

## 要讀的
1. 差異包 /home/bal/project/teamflow/.dkbo/tasks/2026-09-23-ops/waves/4.diff（commit 清單、stat、-U10 diff；含未 commit 的工作樹）
2. 完整 brief /home/bal/project/teamflow/.dkbo/tasks/2026-09-23-ops/brief.md（驗收標準、共用契約、所有權）
3. 本波成員：backend-kinds(S) backend-docs(S)

## 全域約束（全文，逐條當硬要求檢查）
bash 3.2+；不得使用 bash 4 語法（關聯陣列、${x^^}、declare -A、mapfile）
依賴只有 herdr 0.9.0、git ≥ 2.17、jq ≥ 1.5、flock；不得新增依賴。`date -d` 是 GNU 專屬，用到時必須先試、失敗有退路
shellcheck 零警告（`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh`）
不新增 settings.env 鍵、不新增 skill、install.sh 不新增 symlink；`.task.env` 不新增鍵
新增的 bin 只有 `dk-kind` 一支；新增的執行期檔只有 `.dkbo/.sessions/kinds-down` 與它的鎖 `.dkbo/.sessions/kinds-down.lock` 兩個（`.sessions/` 已被 .gitignore，不進版控）
不改「員工在波內不 commit、dk-wave-close 統一 commit」的模型；不改 `DK_KIND_DOWN` 在 `.task.env` 的既有語意（本任務內熔斷）——專案層熔斷是**另加**一層，不是取代
reviewer 逾時（`[TIMEOUT]`）造成的熔斷只記本任務，不寫進專案層：逾時不代表額度用完
否定斷言一律用 tests/helpers.bash 的 refute_grep，不得寫 ! grep -q
0.11.2 的 552 條測試語意不變：不刪、不放寬既有斷言；只允許（a）新增斷言，（b）`03_kinds.bats` 裡 codex 額度式子那幾條依 AC4 改期望值，（c）`12_task_close.bats` 裡斷言時間表「進行中」的地方依 AC11 改期望值
面向使用者的文案是繁體中文；目標版本 0.12.0
例外：本任務的成員**可以**修改 `.dkbo/` 底下的腳本、模板、規則檔與 skill 文件（PROTOCOL 停止條件「不改 .dkbo/ 規則檔」在本任務不適用；ruling 見 process.md）；但只能改所有權表劃給自己的檔
領導跑的是主樹的腳本：本任務的新閘（專案層熔斷、`--refresh`、state 驗證）在本任務內一次都不會生效，要等結案合併後的下一個任務；report 不得宣稱「本波已用到」
已知風險：本任務要改 `kinds/*.sh` 的額度式子與它的測試夾具，員工畫面必然出現這些字樣；員工剛轉 idle、state 還沒寫 done 的空檔可能被 dk-watch 判成 `[LIMIT]`。領導收到 `[LIMIT]` 一律先 `herdr agent read` 看畫面再決定要不要關 pane

## 本任務累積的 Minor
（逐波審查不 triage 累積的 Minor；整枝評議才做）

上面每一條是先前各波放掉的風格／可讀性意見。逐條判：哪些**必須**在 merge 前修掉、
哪些可以留著。判定寫進報告的 `## Minor` 段開頭，一條一行。

## 報告寫到 /home/bal/project/teamflow/.dkbo/tasks/2026-09-23-ops/state/reviewer-a.report.md，格式固定
## 規格合規
（逐條驗收標準 ✅/❌，缺漏寫明）
## Important
（會出錯、違反 brief 或契約、越界改檔；每條附 file:line）
## Minor
（風格、可讀性；每條附 file:line）

## 完成
state 檔 `status: done`，然後 `dk-msg leader "[DONE] review 波 4: Important N 條，見 report"`。
