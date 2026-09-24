# BACKLOG 剩餘六條（測試與守望） — 波 1 審查（reviewer 切片）
你是本波的 reviewer：只讀、不改碼、不跑會寫入的指令。意見只給領導（`dk-msg leader`），不直接對 dev 說。

## 要讀的
1. 差異包 /home/bal/project/teamflow/.dkbo/tasks/2026-09-24-rest/waves/1.diff（commit 清單、stat、-U10 diff；含未 commit 的工作樹）
2. 完整 brief /home/bal/project/teamflow/.dkbo/tasks/2026-09-24-rest/brief.md（驗收標準、共用契約、所有權）
3. 本波成員：backend-watch(L) backend-gate(M) backend-test(M) backend-docs(M)

## 全域約束（全文，逐條當硬要求檢查）
bash 3.2+；不得使用 bash 4 語法（關聯陣列、${x^^}、declare -A、mapfile）；依賴只有 herdr 0.9.0、git ≥ 2.17、jq ≥ 1.5、flock，不得新增必要依賴；`setsid` 是選用的（有才用，沒有照舊 `nohup`，macOS 沒有它）；`date -d`／`date -r` 不得使用
shellcheck 零警告（`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh tests/run.sh`）
不新增 settings.env 鍵、不新增 `.task.env` 鍵、不新增 bin、不新增 skill；新測試檔只准 `tests/unit/37_shellcheck.bats` 一個
否定斷言一律用 tests/helpers.bash 的 refute_grep（grep 類）或 refute（其他指令），不得寫 `! cmd`；`35_test_hygiene.bats` 會擋
既有測試語意不變：不刪、不放寬，只允許新增斷言；`04_docs.bats` 的行數上限不得放寬（`skills/run/SKILL.md` ≤60、`PROTOCOL.md` ≤120）——補規則要改寫既有句子收進去
改任何檔之前先 `grep -l <檔名> tests/unit/*.bats`：引用它的測試檔不在你的可改欄、而你的改動會讓它紅，就 `[ESCALATE]`，不要自己改
面向使用者的文案是繁體中文；不升版：變更併入 CHANGELOG 既有的 0.16.0 節（0.16.0 還沒 push、沒打 tag，ruling 見 process.md），`.dkbo/VERSION` 與 README 的 `VER=` 不動
例外：本任務的成員**可以**修改 `.dkbo/` 底下的腳本、規則檔與 skill 文件，以及 `.dkbo/tasks/BACKLOG.md`（PROTOCOL 停止條件「不改 .dkbo/ 規則檔」在本任務不適用；ruling 見 process.md）；但只能改所有權表劃給自己的檔
編輯一律用切片「## 倉庫」段的 worktree 路徑；`$DK_ROOT` 指向主樹，只拿來跑 `dk-msg`，不得當編輯路徑
取紅一律 cp 到獨立目錄或 `git archive <base>` 解到暫存目錄做，不在 worktree 用 `git stash`／`git checkout -- <檔>`（同波四人共用一個 worktree）
領導跑的是主樹的腳本：本任務的新行為（setsid、watch.log、dk-msg 叫回守望、gate c 剝 `HERDR_*`）在本任務內一次都不會生效；report 不得宣稱「本波已用到」
backend-watch、backend-gate、backend-test 送出 `[DONE]` 給 leader 之後，再前景送一則同內容的 `[DONE]` 給 backend-docs（dev→dev 前景送）；backend-docs 等三則都到了才跑完整測試填條數

## 本任務累積的 Minor
（逐波審查不 triage 累積的 Minor；整枝評議才做）

上面每一條是先前各波放掉的風格／可讀性意見。逐條判：哪些**必須**在 merge 前修掉、
哪些可以留著。判定寫進報告的 `## Minor` 段開頭，一條一行。

## 報告寫到 /home/bal/project/teamflow/.dkbo/tasks/2026-09-24-rest/state/reviewer-a.report.md，格式固定
## 規格合規
（逐條驗收標準 ✅/❌，缺漏寫明）
## Important
（會出錯、違反 brief 或契約、越界改檔；每條附 file:line）
## Minor
（風格、可讀性；每條附 file:line）

## 完成
state 檔 `status: done`，然後 `dk-msg leader "[DONE] review 波 1: Important N 條，見 report"`。
