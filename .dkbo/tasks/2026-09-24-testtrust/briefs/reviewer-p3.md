# 測試可信度 — 計畫審查（reviewer 切片）
你審的是**還沒開工的計畫**，不是程式碼，也不是差異包。只讀、不改任何檔（包含 brief）、
不派工、不寫程式。意見只給領導（dk-msg leader），不要直接對任何人說。

## 要讀的（就這兩份，依序）
1. 需求原文 .dkbo/tasks/2026-09-24-testtrust/request.md —— 人講的原話，領導逐字抄下來的
2. brief .dkbo/tasks/2026-09-24-testtrust/brief.md —— 領導的轉換產物

## 全域約束（全文）
bash 3.2+；不得使用 bash 4 語法（關聯陣列、${x^^}、declare -A、mapfile）；不得新增依賴
只改 `tests/`、`CHANGELOG.md`、`.dkbo/tasks/BACKLOG.md`；`.dkbo/bin/**`、`.dkbo/lib/**`、`.dkbo/kinds/**`、`.dkbo/templates/**` 一個字都不動
既有 642 條測試語意不變：不刪、不放寬、不改期望值；只允許（a）把否定斷言換成有效寫法，（b）新增測試與斷言，（c）改 `fixture_task()` 本身
轉換後某條在 base 上變紅：不得改期望值或刪斷言，停手並 `[ESCALATE]`，附 `檔:行` 與失敗輸出——那是被遮住的真缺陷或測試寫錯，由領導裁定（request.md 的試跑預期不會有）
否定斷言一律用 tests/helpers.bash 的 refute_grep（grep 類，含 `cmd | grep` 管線改成 `cmd | refute_grep …`）；非 grep 指令用 `run <cmd>; [ "$status" -ne 0 ]`，或在 helpers.bash 新增 `refute <cmd> [args…]`（指令成功就印出指令並回 1），二選一後全倉一致
改成 `run` 時留意它會覆寫 `$status`／`$output`：同一個測試後面還在讀前一個 `run` 的結果的，不能這樣換
例外：本任務的成員**可以**修改 `.dkbo/tasks/BACKLOG.md`（PROTOCOL 停止條件「不改 .dkbo/」在本任務只對這一個檔不適用；ruling 見 process.md）
編輯一律用切片「## 倉庫」段的 worktree 路徑；`$DK_ROOT` 指向主樹，只拿來跑 `dk-msg`，不得當編輯路徑
取紅（證明新斷言會紅）一律 cp 到獨立目錄或 `git archive <base>` 解到暫存目錄做，不在 worktree 用 `git stash`／`git checkout -- <檔>`
面向人的文案是繁體中文

你不需要讀專案程式碼。你要回答的是「這份計畫做出來會不會是人要的東西」，
不是「這段碼寫得好不好」。每條意見都要指名 brief 的哪一段或波次表的哪一列。

## 報告寫到 .dkbo/tasks/2026-09-24-testtrust/state/reviewer-p3.report.md，格式固定
## 需求覆蓋
（逐條對照 request：人要的每一件事，brief 有沒有對應的驗收標準？
  漏的列出來，指明 request 的哪一段沒有被接住）
## 驗收標準可驗證性
（逐條 AC：能不能明確判定過或不過？不能的指出來，並給一個可驗證的改寫）
## 檔案所有權
（成員之間有無重疊或遺漏？有沒有哪條 AC 要動的檔沒有任何人擁有？獨佔資源欄有無漏）
## 波次切法
（順序合理嗎？同一波裡有沒有人其實要等另一個人的產出？共用契約有沒有指定擁有者）
## Minor
（其餘建議）
## 結論
一行，只能是 `可以開工` 或 `要改 N 處`（N = 前四段裡你認為**必須**改的條數）

## 完成
state 檔 `status: done`，然後
dk-msg leader "[DONE] brief-review: <可以開工|要改 N 處>，見 report"
