# 任務改開 tab — 計畫審查（reviewer 切片）
你審的是**還沒開工的計畫**，不是程式碼，也不是差異包。只讀、不改任何檔（包含 brief）、
不派工、不寫程式。意見只給領導（dk-msg leader），不要直接對任何人說。

## 要讀的（就這兩份，依序）
1. 需求原文 /home/bal/project/teamflow/.dkbo/tasks/2026-09-22-tasktab/request.md —— 人講的原話，領導逐字抄下來的
2. brief /home/bal/project/teamflow/.dkbo/tasks/2026-09-22-tasktab/brief.md —— 領導的轉換產物

## 全域約束（全文）
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

你不需要讀專案程式碼。你要回答的是「這份計畫做出來會不會是人要的東西」，
不是「這段碼寫得好不好」。每條意見都要指名 brief 的哪一段或波次表的哪一列。

## 報告寫到 /home/bal/project/teamflow/.dkbo/tasks/2026-09-22-tasktab/state/reviewer-p1.report.md，格式固定
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
