# 守望誤判與任務計時 — 計畫審查（reviewer 切片）
你審的是**還沒開工的計畫**，不是程式碼，也不是差異包。只讀、不改任何檔（包含 brief）、
不派工、不寫程式。意見只給領導（dk-msg leader），不要直接對任何人說。

## 要讀的（就這兩份，依序）
1. 需求原文 /home/bal/project/teamflow/.dkbo/tasks/2026-09-19-watchtime/request.md —— 人講的原話，領導逐字抄下來的
2. brief /home/bal/project/teamflow/.dkbo/tasks/2026-09-19-watchtime/brief.md —— 領導的轉換產物

## 全域約束（全文）
- 本任務的產出就是 `.dkbo/` 下的腳本與規則檔。`PROTOCOL.md` 停止條件「不改 `.dkbo/` 下的規則檔」對本任務不適用，以下方檔案所有權表為準（領導已記 ruling）。
- bash 3.2 相容（macOS 內建版本）：不用 `declare -A`、不用 `${var^^}`、不用 `mapfile`。只依賴 bash / jq / git / herdr，不新增外部依賴。
- **時間換算不得用 `date -d`（GNU 限定）或 `date -j`（BSD 限定），也不得用 gawk 限定的 `mktime`／`strftime`**：把 `YYYY-MM-DDTHH:MM` 轉成分鐘用純算術（bash 或 POSIX awk），跨月、跨年要對。檔案新舊不靠 mtime（`decisions.md` 2026-09-19）。
- 每支 `bin/dk-*` 開頭固定是 `set -euo pipefail` 與 `. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"`。shellcheck 零警告（`.dkbo/.shellcheckrc`）。
- 不改 `tests/stub/herdr` 的模擬語意（測試要改 agent 狀態就改 `$HERDR_STUB_RESPONSES/agent_list.json`，`09_watch.bats:19` 已這樣做）。不新增 `settings.env` 鍵、不新增 skill、不新增員工要填的 state 欄位。
- `dk-resume` 輸出維持 ≤150 行預算（腳本尾端的四段 render 降級不得拿掉）。
- 測試檔放 `tests/unit/`，檔名兩位數遞增（目前到 31，新檔從 32 起）；新測試優先加進既有對應檔。真實 process.md 樣本放 `tests/fixtures/`。
- 使用者可見字串一律繁體中文；程式碼註解解釋「為什麼」時寫中文，語法說明寫英文，照既有檔案的密度。
- 版本字串：dkbo 八處全部 0.9.2（`21_version.bats`）；herdr 版號維持 0.9.0（`21_version.bats` 新測試守著），不要動。

你不需要讀專案程式碼。你要回答的是「這份計畫做出來會不會是人要的東西」，
不是「這段碼寫得好不好」。每條意見都要指名 brief 的哪一段或波次表的哪一列。

## 報告寫到 /home/bal/project/teamflow/.dkbo/tasks/2026-09-19-watchtime/state/reviewer-p1.report.md，格式固定
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
