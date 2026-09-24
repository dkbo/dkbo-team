# BACKLOG 剩餘六條（測試與守望） — 計畫審查（reviewer 切片）
你審的是**還沒開工的計畫**，不是程式碼，也不是差異包。只讀、不改任何檔（包含 brief）、
不派工、不寫程式。意見只給領導（dk-msg leader），不要直接對任何人說。

## 要讀的（就這兩份，依序）
1. 需求原文 /home/bal/project/teamflow/.dkbo/tasks/2026-09-24-rest/request.md —— 人講的原話，領導逐字抄下來的
2. brief /home/bal/project/teamflow/.dkbo/tasks/2026-09-24-rest/brief.md —— 領導的轉換產物

## 全域約束（全文）
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

你不需要讀專案程式碼。你要回答的是「這份計畫做出來會不會是人要的東西」，
不是「這段碼寫得好不好」。每條意見都要指名 brief 的哪一段或波次表的哪一列。

## 報告寫到 /home/bal/project/teamflow/.dkbo/tasks/2026-09-24-rest/state/reviewer-p1.report.md，格式固定
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
