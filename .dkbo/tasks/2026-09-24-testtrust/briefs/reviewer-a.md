# 測試可信度 — 波 2 審查（reviewer 切片）
你是本波的 reviewer：只讀、不改碼、不跑會寫入的指令。意見只給領導（`dk-msg leader`），不直接對 dev 說。

## 要讀的
1. 差異包 /home/bal/project/teamflow/.dkbo/tasks/2026-09-24-testtrust/waves/2.diff（commit 清單、stat、-U10 diff；含未 commit 的工作樹）
2. 完整 brief /home/bal/project/teamflow/.dkbo/tasks/2026-09-24-testtrust/brief.md（驗收標準、共用契約、所有權）
3. 本波成員：backend(M)

## 全域約束（全文，逐條當硬要求檢查）
bash 3.2+；不得使用 bash 4 語法（關聯陣列、${x^^}、declare -A、mapfile）；不得新增依賴
只改 `tests/`、`CHANGELOG.md`、`.dkbo/tasks/BACKLOG.md`；`.dkbo/bin/**`、`.dkbo/lib/**`、`.dkbo/kinds/**`、`.dkbo/templates/**` 一個字都不動
既有 642 條測試語意不變：不刪、不放寬、不改期望值；只允許（a）把否定斷言換成有效寫法，（b）新增測試與斷言，（c）改 `fixture_task()` 本身
轉換後某條在 base 上變紅：不得改期望值或刪斷言，停手並 `[ESCALATE]`，附 `檔:行` 與失敗輸出——那是被遮住的真缺陷或測試寫錯，由領導裁定（request.md 的試跑預期不會有）
否定斷言一律用 tests/helpers.bash 的 refute_grep（grep 類，含 `cmd | grep` 管線改成 `cmd | refute_grep …`）；非 grep 指令一律用新增的 `refute <cmd> [args…]`（放在 `tests/helpers.bash` 緊接 `refute_grep` 之後；指令成功就把指令印到 stderr 並回 1）。不得用 `run …; [ "$status" -ne 0 ]` 取代 `!`——`run` 會覆寫 `$status`／`$output`，而且這是領導已定案的單一寫法（ruling 見 process.md）
例外：本任務的成員**可以**修改 `.dkbo/tasks/BACKLOG.md`（PROTOCOL 停止條件「不改 .dkbo/」在本任務只對這一個檔不適用；ruling 見 process.md）
編輯一律用切片「## 倉庫」段的 worktree 路徑；`$DK_ROOT` 指向主樹，只拿來跑 `dk-msg`，不得當編輯路徑
取紅（證明新斷言會紅）一律 cp 到獨立目錄或 `git archive <base>` 解到暫存目錄做，不在 worktree 用 `git stash`／`git checkout -- <檔>`
面向人的文案是繁體中文

## 本任務累積的 Minor
（逐波審查不 triage 累積的 Minor；整枝評議才做）

上面每一條是先前各波放掉的風格／可讀性意見。逐條判：哪些**必須**在 merge 前修掉、
哪些可以留著。判定寫進報告的 `## Minor` 段開頭，一條一行。

## 報告寫到 /home/bal/project/teamflow/.dkbo/tasks/2026-09-24-testtrust/state/reviewer-a.report.md，格式固定
## 規格合規
（逐條驗收標準 ✅/❌，缺漏寫明）
## Important
（會出錯、違反 brief 或契約、越界改檔；每條附 file:line）
## Minor
（風格、可讀性；每條附 file:line）

## 完成
state 檔 `status: done`，然後 `dk-msg leader "[DONE] review 波 2: Important N 條，見 report"`。
