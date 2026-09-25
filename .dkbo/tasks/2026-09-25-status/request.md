# dk-status --json（dashboard 資料出口） — 需求原文

把人講的原話**逐字**抄在下面。不要摘要、不要改寫、不要先做技術轉換 ——
brief 才是轉換的產物，這一份是用來比對「brief 有沒有漏掉人要的東西」的基準。
外部文件（spec、issue、對話紀錄）請把相關段落整段貼進來，不要只留連結：
連結會死，而這個檔案要活到任務歸檔之後還有人讀得懂。

---

（原文從這裡開始）

## 人的原話（2026-09-25，逐字，依時間順序）

1. 「我想開發一個 dkbo-team-dashboard  建議獨立一個 repo 還是 在目前專案就好呢」
2. 「你可以讀取一下 http://100.94.121.113:2501/ 我要參考這頁面的功能」
3. 「所以獨立 repo 好還是 ?」
4. 「好，先做 dk-status --json」
5. 領導問「要走 dkbo 自己的流程開發，還是直接在主樹實作？」，人選：「走 dkbo 流程 (Recommended)」

## 領導當時的提議（人回「好，先做 dk-status --json」所指的內容，逐字）

第 1 則之後：
> 在 dkbo 這邊加一支 `dk-status --json`（名字再定），輸出任務、wave、成員狀態、ruling、kinds-down 等資料，JSON 裡帶 `schema_version`。之後的分工是：
> - dkbo 負責 JSON 的格式和測試，寫進 `tests/`。
> - dashboard 只讀這份 JSON，也可以加上 herdr 的 `events.subscribe` 做即時更新。它只宣告自己支援哪些 `schema_version`。

第 3 則之後：
> **dkbo 倉只放一樣東西**：`dk-status --json`，唯讀，JSON 帶 `schema_version`，並且有自己的測試。dashboard 的後端就呼叫它，或是讀它輸出的檔案，不直接解析 markdown。

第 4 則之後、開任務前（範圍提議）：
> - `dk-status --json` 輸出所有任務的摘要清單。
> - `dk-status --json <short>` 輸出單一任務的詳情：成員、波次、ruling、訊息、閘門事件。
> - JSON 帶 `schema_version`，並補 bats 測試。
> - 用量和逐字稿不做，這部分之後由 dashboard 自己讀。

## 外部文件：參考頁面 SDD Dashboard（http://100.94.121.113:2501/，2026-09-25 由領導讀前端原始碼整理，API 需登入未讀到資料）

領導整理給人的功能清單（逐字）：

**1. 首頁：Plan 清單 `/`**
- 最上面四張統計卡：執行中、BLOCKED、完成數／總數、API 等值費用總計。
- 可以搜尋 slug，也可以依狀態篩選（全部、執行中、BLOCKED、完成、未開始）。
- 表格欄位：Plan、Repos、進度條（完成 task 數／總數）、狀態、Token、API 等值、更新時間。5 分鐘內有動靜的 plan 前面會有閃爍的綠點。

**2. Plan 詳情 `/plans/:slug`，分四個分頁**
- **Tasks**：每個 Task 是一張可以摺疊的卡，執行中或 BLOCKED 的預設展開。
  - 卡片標題列有狀態、commit hash、預估和實際耗時。
  - 展開後有 `subproject`、`depends_on`、`resources`、`Verify` 和 Files 欄位。
  - Ruling、QUESTION、minor 分成三組列出，Plan 層級也有同樣一組。
  - 下面是這個 task 的 agent 表：角色、agentType、model、token、費用、耗時、描述。
- **Plan**：plan.md 渲染成 markdown，左邊是 Task 目錄，點了會跳到對應段落。
- **Ledger**：預設顯示 `plan-progress.md` 原文，也可以切換看其他帳本檔。
- **Usage**：token 分別依 task、agentType、model 彙總。每列有堆疊長條，分成 input、output、cache read、cache write 5m、cache write 1h。另外會警告沒有定價的 model 和略過的壞行。

**3. Agent 逐字稿 `/plans/:slug/agents/:id`**
- 標頭顯示 model、token（含費用）、耗時、事件數。
- 下面是時間軸，事件分四種：user 文字、assistant 文字（渲染成 markdown）、tool_use（可展開看 input）、tool_result（可展開看內容，錯誤會標紅，也會標示是否截斷）。
- agent 還在跑的話，畫面會自動捲到最新一筆。

**4. 右側常駐欄：執行中的 agent**
- 列出 5 分鐘內有活動的 agent，包括所屬 plan、角色、task、最後一次動作的時間和最後呼叫的工具。每 30 秒重抓一次。

領導整理的對應表（逐字）：

| SDD Dashboard | dkbo 對應 | 備註 |
|---|---|---|
| Plan | `.dkbo/tasks/<short>/` 任務 | slug 就是 short |
| Task N 卡片 | wave 裡的成員（backend、qa、reviewer…） | 要多一層 **wave** |
| Ledger | `process.md`、`messages.log`、`state/`、`report.md` | messages.log 可以做成訊息時間軸（`[DONE]`、`[BUG]`、`[ESCALATE]`） |
| Ruling / QUESTION | `ruling:` 和 `ruling: [自主]` | 自主裁定要**醒目列出**，對應 gate 3 要複核的項目 |
| Agent 逐字稿 | 成員 pane | 麻煩的地方在這裡 |
| live（5 分鐘窗） | herdr pane 狀態 | 可以用 `events.subscribe` 推播，不用輪詢 |

它沒有、但 dkbo 值得加的：閘門狀態（`dk-wave-close` 的四道閘）、所有權（每個成員的 glob 對照實際 diff）、kind 額度（`dk-kind` 和 kinds-down）。
