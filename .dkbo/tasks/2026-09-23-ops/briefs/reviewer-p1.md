# 營運回饋修補（panova headermerge） — 計畫審查（reviewer 切片）
你審的是**還沒開工的計畫**，不是程式碼，也不是差異包。只讀、不改任何檔（包含 brief）、
不派工、不寫程式。意見只給領導（dk-msg leader），不要直接對任何人說。

## 要讀的（就這兩份，依序）
1. 需求原文 /home/bal/project/teamflow/.dkbo/tasks/2026-09-23-ops/request.md —— 人講的原話，領導逐字抄下來的
2. brief /home/bal/project/teamflow/.dkbo/tasks/2026-09-23-ops/brief.md —— 領導的轉換產物

## 全域約束（全文）
bash 3.2+；不得使用 bash 4 語法（關聯陣列、${x^^}、declare -A、mapfile）
依賴只有 herdr 0.9.0、git ≥ 2.17、jq ≥ 1.5、flock；不得新增依賴。`date -d` 是 GNU 專屬，用到時必須先試、失敗有退路
shellcheck 零警告（`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh`）
不新增 settings.env 鍵、不新增 skill、install.sh 不新增 symlink；`.task.env` 不新增鍵
新增的 bin 只有 `dk-kind` 一支；新增的執行期檔只有 `.dkbo/.sessions/kinds-down` 一個（`.sessions/` 已被 .gitignore，不進版控）
不改「員工在波內不 commit、dk-wave-close 統一 commit」的模型；不改 `DK_KIND_DOWN` 在 `.task.env` 的既有語意（本任務內熔斷）——專案層熔斷是**另加**一層，不是取代
reviewer 逾時（`[TIMEOUT]`）造成的熔斷只記本任務，不寫進專案層：逾時不代表額度用完
否定斷言一律用 tests/helpers.bash 的 refute_grep，不得寫 ! grep -q
0.11.2 的 552 條測試語意不變：不刪、不放寬既有斷言；只允許（a）新增斷言，（b）`03_kinds.bats` 裡 codex 額度式子那幾條依 AC4 改期望值，（c）`12_task_close.bats` 裡斷言時間表「進行中」的地方依 AC11 改期望值
面向使用者的文案是繁體中文；目標版本 0.12.0
例外：本任務的成員**可以**修改 `.dkbo/` 底下的腳本、模板、規則檔與 skill 文件（PROTOCOL 停止條件「不改 .dkbo/ 規則檔」在本任務不適用；ruling 見 process.md）；但只能改所有權表劃給自己的檔
領導跑的是主樹的腳本：本任務的新閘（專案層熔斷、`--refresh`、state 驗證）在本任務內一次都不會生效，要等結案合併後的下一個任務；report 不得宣稱「本波已用到」
已知風險：本任務要改 `kinds/*.sh` 的額度式子與它的測試夾具，員工畫面必然出現這些字樣；員工剛轉 idle、state 還沒寫 done 的空檔可能被 dk-watch 判成 `[LIMIT]`。領導收到 `[LIMIT]` 一律先 `herdr agent read` 看畫面再決定要不要關 pane

你不需要讀專案程式碼。你要回答的是「這份計畫做出來會不會是人要的東西」，
不是「這段碼寫得好不好」。每條意見都要指名 brief 的哪一段或波次表的哪一列。

## 報告寫到 /home/bal/project/teamflow/.dkbo/tasks/2026-09-23-ops/state/reviewer-p1.report.md，格式固定
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
