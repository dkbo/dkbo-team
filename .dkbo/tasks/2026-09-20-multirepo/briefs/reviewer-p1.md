# 多 repo workspace — 計畫審查（reviewer 切片）
你審的是**還沒開工的計畫**，不是程式碼，也不是差異包。只讀、不改任何檔（包含 brief）、
不派工、不寫程式。意見只給領導（dk-msg leader），不要直接對任何人說。

## 要讀的（就這兩份，依序）
1. 需求原文 /home/bal/project/teamflow/.dkbo/tasks/2026-09-20-multirepo/request.md —— 人講的原話，領導逐字抄下來的
2. brief /home/bal/project/teamflow/.dkbo/tasks/2026-09-20-multirepo/brief.md —— 領導的轉換產物

## 全域約束（全文）
bash 3.2+；不得使用 bash 4 語法（關聯陣列、${x^^}、declare -A）
依賴只有 herdr 0.9.0、git ≥ 2.17、jq ≥ 1.5；不得新增依賴
shellcheck 零警告（`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh`）
settings.env 只新增 `DK_REPOS` 與 `DK_TEST_CMD_<名>` 兩種鍵；不新增 skill、不新增 install.sh 的 symlink
不改「員工在波內不 commit、dk-wave-close 統一 commit」的模型
否定斷言一律用 tests/helpers.bash 的 refute_grep，不得寫 ! grep -q
所有面向使用者的文案是繁體中文
目標版本 0.10.0
`DK_REPOS` 空字串時，0.9.2 的既有測試語意不變：不刪、不放寬既有斷言；只允許改 `DK_WORKSPACE`／`DK_ROOT_PANE` 的期望值與新增斷言（AC1）
不用 `herdr worktree create`；workspace 用 `herdr workspace create --cwd <主樹>`，worktree 用 `git worktree add`（plan.md 決策①）
例外：本任務的成員**可以**修改 `.dkbo/` 底下的腳本、lib、kinds、模板、規則檔與 skill 文件（PROTOCOL 停止條件「不改 .dkbo/ 規則檔」在本任務不適用；ruling 見 process.md）；但只能改所有權表劃給自己的檔
單 repo 模式下任何面向人的輸出都不印 repo 前綴；多 repo 模式下都印
領導跑的是主樹的腳本：本任務內做出來的新行為要等結案合併後的下一個任務才生效，不要在 report 裡宣稱「本波已用到」

你不需要讀專案程式碼。你要回答的是「這份計畫做出來會不會是人要的東西」，
不是「這段碼寫得好不好」。每條意見都要指名 brief 的哪一段或波次表的哪一列。

## 報告寫到 /home/bal/project/teamflow/.dkbo/tasks/2026-09-20-multirepo/state/reviewer-p1.report.md，格式固定
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
