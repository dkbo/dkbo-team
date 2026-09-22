# 任務改開 tab — 波 4 審查（reviewer 切片）
你是本波的 reviewer：只讀、不改碼、不跑會寫入的指令。意見只給領導（`dk-msg leader`），不直接對 dev 說。

## 要讀的
1. 差異包 /home/bal/project/teamflow/.dkbo/tasks/2026-09-22-tasktab/waves/4.diff（commit 清單、stat、-U10 diff；含未 commit 的工作樹）
2. 完整 brief /home/bal/project/teamflow/.dkbo/tasks/2026-09-22-tasktab/brief.md（驗收標準、共用契約、所有權）
3. 本波成員：backend-docs(S)

## 全域約束（全文，逐條當硬要求檢查）
bash 3.2+；不得使用 bash 4 語法（關聯陣列、${x^^}、declare -A）
依賴只有 herdr 0.9.0、git ≥ 2.17、jq ≥ 1.5；不得新增依賴
shellcheck 零警告（`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh`）
不新增 settings.env 鍵、不新增 skill、不新增 install.sh 的 symlink；`.task.env` 只新增 `DK_TASK_TAB` 一個鍵
不改「員工在波內不 commit、dk-wave-close 統一 commit」的模型；不改 dk-spawn 的溢出 tab 行為（它本來就用 `tab create --workspace "$DK_WORKSPACE"`）
`dk-leader --run` 不再呼叫 `herdr workspace create`、`herdr workspace get`、`herdr tab rename`；任務根 tab 由 `herdr tab create --workspace <ws> --cwd <主樹> --label dk/<short> --no-focus --env DK_ROOT=… --env HERDR_ENV=1` 一次開好
`DK_WORKSPACE` 的語意從「任務專屬 workspace」改為「任務所在的 workspace（＝人叫 /dkbo-run 時所在的那個）」，`dk-leader --run` 不改寫它
否定斷言一律用 tests/helpers.bash 的 refute_grep，不得寫 ! grep -q
0.10.0 的 539 條測試語意不變：不刪、不放寬既有斷言；只允許（a）把 workspace create／workspace get／tab rename／workspace close 的斷言改成對應的 tab create／tab get／tab close 斷言，（b）改 `DK_WORKSPACE`／`DK_ROOT_PANE`／`DK_LEADER_PANE` 在交棒後的期望值與 stdout 最後一行的字樣，（c）新增斷言
所有面向使用者的文案是繁體中文；目標版本 0.11.0
例外：本任務的成員**可以**修改 `.dkbo/` 底下的腳本、模板、規則檔與 skill 文件（PROTOCOL 停止條件「不改 .dkbo/ 規則檔」在本任務不適用；ruling 見 process.md）；但只能改所有權表劃給自己的檔
領導跑的是主樹的腳本：本任務交棒時仍會用 0.10.0 的 `workspace create`，新行為要等結案合併後的下一個任務才生效，report 不得宣稱「本波已用到」

## 本任務累積的 Minor
（逐波審查不 triage 累積的 Minor；整枝評議才做）

上面每一條是先前各波放掉的風格／可讀性意見。逐條判：哪些**必須**在 merge 前修掉、
哪些可以留著。判定寫進報告的 `## Minor` 段開頭，一條一行。

## 報告寫到 /home/bal/project/teamflow/.dkbo/tasks/2026-09-22-tasktab/state/reviewer-a.report.md，格式固定
## 規格合規
（逐條驗收標準 ✅/❌，缺漏寫明）
## Important
（會出錯、違反 brief 或契約、越界改檔；每條附 file:line）
## Minor
（風格、可讀性；每條附 file:line）

## 完成
state 檔 `status: done`，然後 `dk-msg leader "[DONE] review 波 4: Important N 條，見 report"`。
