# BACKLOG 三條高嚴重度缺陷 — 波 2 審查（reviewer 切片）
你是本波的 reviewer：只讀、不改碼、不跑會寫入的指令。意見只給領導（`dk-msg leader`），不直接對 dev 說。

## 要讀的
1. 差異包 /home/bal/project/teamflow/.dkbo/tasks/2026-09-19-highfix/waves/2.diff（commit 清單、stat、-U10 diff；含未 commit 的工作樹）
2. 完整 brief /home/bal/project/teamflow/.dkbo/tasks/2026-09-19-highfix/brief.md（驗收標準、共用契約、所有權）
3. 本波成員：backend(M)

## 全域約束（全文，逐條當硬要求檢查）
- 本任務的產出就是 `.dkbo/` 下的腳本與規則檔。`PROTOCOL.md` 停止條件「不改 `.dkbo/` 下的規則檔」對本任務不適用，以下方檔案所有權表為準（領導已記 ruling）。
- bash 3.2 相容（macOS 內建版本）：不用 `declare -A`、不用 `${var^^}`、不用 `mapfile`。只依賴 bash / jq / git / herdr，不新增外部依賴。
- 每支 `bin/dk-*` 開頭固定是 `set -euo pipefail` 與 `. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"`。shellcheck 零警告（`tests/run.sh` 會跑，設定在 `.dkbo/.shellcheckrc`）。
- 檔案新舊不靠 mtime（`date -r` 在 GNU 與 BSD 語義不同；`decisions.md` 2026-09-19 已裁定），用 `cksum` 或等價的內容比對。
- dkbo 不代員工改 state 檔（`PROTOCOL.md`「只有本人能寫自己的 state 與 report 檔」）。
- 不新增 `settings.env` 鍵、不新增 skill、不改 herdr 呼叫的 JSON 形狀假設、不改 `tests/stub/herdr` 對 herdr 的模擬語意。
- 測試檔放 `tests/unit/`，檔名兩位數遞增（目前到 31），新測試優先加進既有對應檔（`09_watch.bats`、`08_wave_close.bats`、`03_kinds.bats`）。
- 使用者可見字串一律繁體中文；程式碼註解解釋「為什麼」時寫中文，語法說明寫英文，照既有檔案的密度。
- 版本字串一致：`.dkbo/VERSION`、`CHANGELOG.md` 首節、`README.md`、`README.en.md`、`.dkbo/README.md` 全部 0.9.1（`21_version.bats` 守著）。

## 本任務累積的 Minor
（逐波審查不 triage 累積的 Minor；整枝評議才做）

上面每一條是先前各波放掉的風格／可讀性意見。逐條判：哪些**必須**在 merge 前修掉、
哪些可以留著。判定寫進報告的 `## Minor` 段開頭，一條一行。

## 報告寫到 /home/bal/project/teamflow/.dkbo/tasks/2026-09-19-highfix/state/reviewer-a.report.md，格式固定
## 規格合規
（逐條驗收標準 ✅/❌，缺漏寫明）
## Important
（會出錯、違反 brief 或契約、越界改檔；每條附 file:line）
## Minor
（風格、可讀性；每條附 file:line）

## 完成
state 檔 `status: done`，然後 `dk-msg leader "[DONE] review 波 2: Important N 條，見 report"`。
