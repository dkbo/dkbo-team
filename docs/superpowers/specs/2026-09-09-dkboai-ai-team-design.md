# dkboai：以 herdr 為底的多模型 AI 團隊 — 設計規格

日期：2026-09-09
狀態：待審

## 1. 目標與範圍

建立可攜套件 `dkboai/`，放進任何目標專案根目錄後，能在 herdr 終端機中組成一個仿公司團隊的 AI 開發組：一位領導（主 pane，Claude Code）審查需求、拆波次、派工、決策、合併；多位員工（各自 pane，claude / codex / agy）實作、測試、互相溝通；人只在三個關卡介入。所有記憶落地為精簡的 markdown，領導 `/clear` 後可用一支腳本恢復。

範圍內：目錄結構、角色與通訊協定、任務與波次生命週期、雜務路徑、持久記憶格式、擴增 skill、工具對應表、測試策略。
範圍外：兩位以上領導同時運作（設計上已留餘地，但不在本次驗證）、MCP 設定同步、模型輸出品質評測。

### 已定案的關鍵決策

| 決策 | 選擇 |
|---|---|
| 定位 | 可攜套件，本 repo（teamflow）是開發與測試場 |
| 主模型 | 所有角色預設 claude；codex、agy 作第二、第三意見（評議波） |
| 隔離 | 一個任務一個 git worktree（分支 `dk/<短名>`），同一波成員共用該 worktree |
| 防衝突 | brief 劃檔案所有權，範圍不得重疊；共用契約指定擁有者 |
| pane 生命週期 | 波結束關 pane，不重用 |
| 人的介入 | 三關卡：① brief 確認 ② 員工升報決策 ③ 結案合併 |
| 通訊拓撲 | 同一波員工可互通，跨波自然星狀；可對個別員工 `--isolated` |
| 領導行為 | 事件驅動，不阻塞等待；不寫程式、不親自產出內容 |
| 實作方式 | markdown 規範 + `bin/` 薄 bash 腳本封裝 herdr，不引入 node/python |
| 員工限制 | 禁用 subagent |

## 2. 目錄結構

```
dkboai/
├── ENTRY.md               # 唯一入口：執行 dk-whoami，依輸出讀 LEADER.md 或 roles/<角色>.md
├── LEADER.md              # 領導規範
├── PROTOCOL.md            # 通訊協定與升報規則（領導與員工共用）
├── PROJECT.md             # 專案事實，≤40 行（init 預填，領導 / it 維護）
├── decisions.md           # 跨任務決策，一行一則
├── README.md              # 安裝三步
├── roles/
│   ├── README.md          # 團隊表：角色 | kind | 三檔 | 一句職責
│   ├── pm.md frontend.md backend.md qa.md it.md reviewer.md
├── kinds/                 # 一個 AI 工具一檔，bash 可 source
│   ├── claude.sh codex.sh agy.sh
├── bin/
│   ├── dk-whoami dk-task-new dk-leader dk-spawn dk-msg
│   ├── dk-wave-close dk-task-close dk-chore dk-resume dk-watch
├── skills/
│   ├── init/SKILL.md      # 專案首次啟用
│   └── add-role/SKILL.md  # 擴增角色
├── templates/             # brief.md process.md state.md report.md chore.md
├── tasks/
│   ├── INDEX.md           # 一行一任務 / 雜務
│   ├── BACKLOG.md         # 延後事項，處理完刪行
│   ├── _chores/<yyyy-mm-dd>-<名>.md
│   └── <yyyy-mm-dd-任務名>/
│       ├── brief.md process.md report.md messages.log
│       └── state/<agent>.md
└── .sessions/<pane_id>    # 領導 pane → 任務資料夾綁定；gitignore
```

任務記憶放主工作樹的 `dkboai/tasks/` 下，不放 worktree 內，worktree 被丟棄時記憶不消失。員工以絕對路徑寫入（由環境變數 `DK_TASK_DIR` 提供）。

### 目標專案側

```
目標專案/
├── AGENTS.md                         # 一行：讀 dkboai/ENTRY.md（codex、agy 讀）
├── CLAUDE.md                         # 一行：@AGENTS.md（Claude Code 讀）
├── .claude/skills/dkboai-init        → ../../dkboai/skills/init
├── .claude/skills/dkboai-add-role    → ../../dkboai/skills/add-role
├── .agents/skills/dkboai-init        → ../../dkboai/skills/init
├── .agents/skills/dkboai-add-role    → ../../dkboai/skills/add-role
└── dkboai/
```

SKILL.md 格式三家相同（Agent Skills 標準），來源只有 `dkboai/skills/` 一份。Claude Code 不讀 `.agents/skills` 也不讀 `AGENTS.md`，所以需要 `.claude/skills` 連結與 `CLAUDE.md` 匯入。

## 3. 角色

### 角色檔格式（`roles/<role>.md`）

```yaml
---
name: frontend
kind: claude
tiers:
  S: sonnet/low      # 小改、照範例做
  M: sonnet/medium   # 一般功能
  L: opus/high       # 跨模組、需設計判斷
worktree: true
split: right
mcp: []              # 預期需要的 MCP server 名稱，僅供檢查
---
## 職責（3–5 行）
## 完成定義（何時可送 DONE）
## 交接對象
```

難度是任務屬性，不是角色屬性：brief 波次表每列標 S/M/L，dk-spawn 據此選檔；`--tier` 可臨時覆寫，覆寫記 process.md。claude 不使用 haiku，effort 上限 high。

### 出廠角色與三檔預設（kind=claude）

| 角色 | S | M | L | 一句職責 |
|---|---|---|---|---|
| pm | sonnet/low | sonnet/medium | opus/high | 需求釐成驗收標準，不寫碼 |
| frontend | sonnet/low | sonnet/medium | opus/high | 介面實作 |
| backend | sonnet/low | sonnet/medium | opus/high | API、資料層 |
| qa | sonnet/low | sonnet/medium | sonnet/high | 依驗收標準驗證、送 BUG，自己不修 |
| it | sonnet/low | sonnet/low | sonnet/medium | 環境、依賴、CI、合併衝突修復 |
| reviewer | — | sonnet/medium | opus/high | 評議波用，只出意見不改碼 |

init skill 可依人選的主模型把六個角色檔的 kind 與三檔改寫成對應工具的等級。

### 領導（LEADER.md）

不是角色檔。規定：

- 只做：讀需求、寫 brief、拆波、派工、處理 ESCALATE、決策、寫 process / report / decisions、每波 commit、結案合併。
- 不做：寫程式、改業務檔案、親自翻譯或畫圖等產出。任何產出都派員工。
- 收到人的請求時分流：進行中任務的一部分 → 調波次表並記 process；獨立且不改程式 → `dk-chore`；獨立且改程式且小 → `dk-chore --code`；範圍大 → 建議新任務並問人。
- 對「先修這個 bug」類請求：先評估（涉及檔案、是否落在在線成員所有權、嚴重度），給「立刻修 / 併入當前任務 / 延後進 BACKLOG」三選一附建議，人選後執行。
- 角色檔不存在時，先用 add-role 建立再派工，不用通用員工矇混。
- 上下文吃緊時 `/clear` 後執行 `dk-resume`。

### 命名

- 任務短名：`dk-task-new <短名> "<顯示名>"`，短名為 ascii 小寫、≤12 字元，用於 herdr 名稱與分支；顯示名可為中文，寫在 brief 標題與 INDEX。任務資料夾為 `<yyyy-mm-dd>-<短名>`。
- 領導：`dk-task-new` 時把當前 pane 的 agent 改名為 `leader-<任務短名>`（由 `dk-leader` 啟動者已具名則略過）。員工的 `dk-msg leader` 由腳本解析為所屬任務的領導。
- 員工：herdr agent 名為 `<任務短名>-<角色>[-<別名>]`（如 `login-frontend-cart`）；state 檔名為 `<角色>[-<別名>].md`。同一波可派多位同角色，別名區分，所有權必須切開。
- 雜務員工：`chore-<角色>-<序號>`。
- herdr 名稱規則 `[a-z][a-z0-9_-]{0,31}`，腳本負責轉換與截斷。

## 4. 通訊協定（PROTOCOL.md）

### 員工如何獲得指令

`dk-spawn <角色> [別名] [--kind K] [--tier S|M|L] [--isolated]`：

1. 在任務 worktree 的 workspace 中 `pane split`，注入環境變數 `DK_TASK_DIR`、`DK_ROLE`、`DK_AGENT`、`DK_LEADER`、`DK_ISOLATED`。
2. `agent start` 以角色檔 tier 對應的旗標啟動（含免審批模式）。
3. 送第一段固定提示（三種模型相同），只指路：
   > 你是 `<agent>`。角色說明 `dkboai/roles/<role>.md`、協定 `dkboai/PROTOCOL.md`、專案事實 `dkboai/PROJECT.md`、任務 `$DK_TASK_DIR/brief.md`。你的 state 檔是 `$DK_TASK_DIR/state/<agent>.md`。只能修改 brief 劃給你的檔案。禁止使用 subagent。讀完後建立 state 檔並開始做波次表分給你的項目。
4. `agent prompt --wait` 等到 working。領導確認方式是 state 檔出現，沒有 READY 握手。
5. 若角色宣告的 MCP 在該 kind 缺少，警告領導並記 process，不阻擋。

重啟同名員工時，提示多一句「從 state 檔續作」。

### 訊息

一律經 `dk-msg <對象> "[類型] 內文"`。腳本自動補寄件人、任務、時間，追加到 `messages.log`，並先 `agent wait <對象> --until idle --until done --timeout 300000`，對方閒置才送。內文一到三句，細節指向 state 檔；超過 200 字元腳本拒送。送給 leader 的訊息只有一行標頭。

| 類型 | 方向 | 意義 |
|---|---|---|
| TASK | 領導→員工 | 派工（通常已含在第一段提示，補充時用） |
| DONE | 員工→領導 | 完成並已更新 state |
| BUG | 員工→員工 | 附重現方式，指向 state |
| FIXED | 員工→員工 | 修好，請重驗 |
| QUESTION / ANSWER | 任意 | 釐清介面、契約 |
| ESCALATE | 員工→領導 | 需決策、越界需求、修一次未好、上下文吃緊（`[ESCALATE] context`） |
| DECISION | 領導→員工 | 決策結果 |
| STOP | 領導→員工 | 停手、寫 state 收尾 |
| BLOCKED | dk-watch→領導 | 某員工卡在審批超過 60 秒 |
| ACK | 領導（只寫 log） | 標記已處理到此的訊息，供 dk-resume 切點 |

### 路由與上限

- 同一波員工可自由互通；`--isolated` 員工只能對領導說話。
- 修復迴圈上限一次，計數單位是同一個 bug：BUG → FIXED → 再驗仍失敗 → qa 直接 ESCALATE，不再回 dev。
- QUESTION 若 brief 無答案，被問者不得自行決定，提問者 ESCALATE；同一波同一對員工 QUESTION 上限兩則。
- 任何 A 或 B 的選擇、共用契約變更，一律 ESCALATE。
- 對方 `blocked` 導致送不進：重試等待 60 秒，仍失敗則 log 標 `[UNDELIVERED]`、回傳非零，寄件人寫進 state 後繼續其他事。
- 員工不得寫 process.md；state 檔只有本人寫。

### 領導如何聽

事件驅動。派工後結束 turn 閒置；員工的 dk-msg 與人的輸入都是推進來的 prompt，先到先處理。不輪詢、不主動讀員工終端，僅在收到訊息需要細節時 `agent read`。`dk-watch`（dk-task-new 啟動的背景 bash 迴圈，每 30 秒 `agent list`）負責偵測 blocked 員工，推 `[BLOCKED]` 給領導並 `herdr notification show`；dk-task-close 收掉它。

## 5. 任務生命週期

```
需求（人的一段話 / superpowers plan 檔）
 → dk-task-new：建任務資料夾（複製範本）、worktree 分支 dk/<短名>、.sessions 綁定、
   agent 改名 leader-<短名>、INDEX 登錄 planning、啟動 dk-watch
 → 領導寫 brief.md
 → 關卡① 人確認 → brief 凍結，INDEX 改 running
 → 每一波：dk-spawn 成員 → 成員工作、互通、寫 state → 領導收 DONE / ESCALATE
     ESCALATE → 依 brief 可判者回 DECISION 記 process；否則 關卡② 問人，答案回 DECISION 並記 decisions.md
     全員 DONE → dk-wave-close → 領導 commit "wave N: ..." → 依結果增刪下一波（記 process）
 → 關卡③ 領導寫 report.md，人拍板
 → dk-task-close：合併 dk/<短名> 回 main、移除 worktree、INDEX 改 done、關 dk-watch、刪 .sessions
```

- 有 superpowers plan 時，brief 不重寫內容，只對應驗收標準、劃所有權、把 plan 的 task 分組成波。
- brief 的需求與驗收凍結；波次表可由領導在波間修改，記 process，不改 brief。
- 波型態：實作波（dev 一至多人 + qa，qa DONE 結束）、評議波（3 reviewer，第一輪 isolated 各寫意見到 state，第二輪開放互通每人一則反駁，領導決策記 process 與 decisions）、修復波（同實作波）。
- dk-wave-close：檢查每位 state `status: done`（缺者不關）；比對 touched 與 brief 所有權，越界記 process 並提示；關 pane；process 追加波次摘要。不 commit。state 超過 20 行只警告。
- 兩種啟動：人在現有 Claude 說「開任務 X」→ 領導執行 dk-task-new；人在 shell 執行 `dk-leader Y` → 開新 pane、注入環境、啟動 claude 命名 `leader-Y`、首段提示讀 LEADER.md 後 dk-task-new。

### 故障處理

| 狀況 | 處理 |
|---|---|
| 員工 pane 掛掉或 `[ESCALATE] context` | 領導關 pane，同名重新 dk-spawn，提示「從 state 續作」 |
| 員工 blocked | dk-watch 通知人；記 process |
| 合併衝突 | dk-task-close 停下；領導不自行解，問人或開 it 修復波 |
| 人放棄任務 | `dk-task-close --abandon`：不合併、刪 worktree、INDEX 標 abandoned、report 寫原因 |
| 領導上下文爆 | `/clear` → `dk-resume` |

### dk-resume 輸出（≤150 行）

1. LEADER.md 位置提醒（不印全文）
2. 綁定的任務名與 brief.md 全文
3. process.md 最後 20 行
4. messages.log 中最後一則 `[ACK]` 之後寄給 leader 的訊息
5. 每個 state 檔前 5 行
6. `herdr agent list` 精簡版（本任務員工的狀態）
7. BACKLOG.md 全文

無參數時依 `.sessions/$HERDR_PANE_ID` 定位；可帶任務名供人手動接管。

## 6. 雜務路徑（dk-chore）

`dk-chore <角色> "<一句話交代>" [--kind K] [--tier S|M|L] [--code] [--cwd 路徑]`

- 開 pane、啟動 agent `chore-<角色>-<序號>`，首段提示指向角色檔、PROJECT.md 與交代。
- 記憶只有 `tasks/_chores/<yyyy-mm-dd>-<名>.md`，由雜務員工自己寫；INDEX 加一行型態 chore。
- 無 brief / process / wave；做完 DONE 給領導，領導看結果、回人、關 pane。修復上限與升報規則照 PROTOCOL。
- 預設不開 worktree，在主工作樹或 `--cwd` 作業，不得改程式碼。
- `--code`：自動開 worktree 分支 `chore/<名>`；單一成員自己跑測試；DONE 後領導檢查 touched 未越界即直接合併回 main、刪 worktree，不需關卡③。成員回報範圍過大時領導停止 chore，改建議開任務。

## 7. 持久記憶格式

原則：每檔回答一個問題，有行數上限，超過就刪或搬。範本頂端以註解標明上限。

### brief.md（領導寫，關卡①後凍結需求與驗收）

```markdown
# <任務名>
來源：<人的一句話 / plan 檔路徑>
分支：dk/<短名>   worktree：<路徑>
## 目標（≤3 行）
## 驗收標準
- [ ] AC1
## 檔案所有權
| 成員 | 可改 | 只讀 |
## 共用契約
<誰定稿、放哪、變更流程>
## 波次表
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 |
```

### process.md（只有領導寫，只追加，一事件一行）

```
2026-09-09T13:00 task-new
2026-09-09T13:20 gate1 approved
2026-09-09T13:21 wave1 start backend(M)
2026-09-09T14:05 escalate backend: 缺 DB schema → decision: 用現有 users 表
2026-09-09T14:40 wave1 done  commit a1b2c3
2026-09-09T14:41 wave-table amend: 新增 wave3 修復波
```

### state/<agent>.md（員工自己覆寫，≤20 行）

```markdown
status: working | blocked | done
wave: 1
current: <一句>
touched:
  - src/api/login.ts
todo:
  - <項目>
blocked_by: <無則省略>
notes: <給接手者的必要事實，≤5 行>
```

### report.md（領導寫，結案）

```markdown
# <任務名> 結案
結果：merged | abandoned   分支：dk/<短名>   波數：N
## 完成
## 未完成 / 遺留
## 驗證
<qa 最後一次 DONE 的依據，一行>
## 重要決策
<指向 decisions.md 條目>
## 給下次的話（≤3 行）
```

### messages.log（dk-msg 自動寫）

```
2026-09-09T14:03 login-frontend -> login-qa [DONE] 登入表單完成
2026-09-09T14:20 login-qa -> login-frontend [BUG] 空密碼未擋，見 state/qa.md
2026-09-09T14:41 login-qa -> leader [ESCALATE] 同 bug 修一次未好
2026-09-09T14:45 leader [ACK]
```

### tasks/INDEX.md

```
| 日期 | 名稱 | 型態 | 狀態 | 一句結論 |
| 2026-09-09 | 使用者登入 | task | running | — |
| 2026-09-09 | 翻譯 README | chore | done | docs/README.en.md |
```

狀態：planning / running / done / abandoned。

### tasks/BACKLOG.md（領導寫，處理完刪行）

```
| 日期 | 來源 | 一句描述 | 建議處理 |
```

### decisions.md（跨任務，只寫影響未來的）

```
2026-09-09 [使用者登入] 密碼雜湊用 argon2，不用 bcrypt。原因：既有依賴。
```

### PROJECT.md（≤40 行）

技術棧、安裝 / 啟動、測試指令、目錄慣例、已知坑。init 預填，過長就搬進 decisions 或刪。

### tasks/_chores/<日期>-<名>.md（雜務員工寫）

```markdown
交代：<一句>
成員：chore-frontend-2 (claude / sonnet / medium)
branch: chore/<名>          # --code 時才有
status: working | done
touched:
  - <檔>
結果：<路徑或 commit>
```

### .sessions/<pane_id>

一行任務資料夾名。不進 git。

## 8. 工具對應表（kinds/<kind>.sh）

每檔提供同一介面，dk-spawn 與 add-role 只認此介面；新工具即加一檔，不做 add-kind skill。

```bash
KIND_MODELS="opus sonnet"
KIND_EFFORTS="low medium high"
kind_args() { # $1=model $2=effort → 印出 agent start -- 之後的參數
  echo "--model $1 --effort $2 --permission-mode acceptEdits"
}
kind_mcp_list() { claude mcp list; }
# 註解：working 中收到 prompt 的行為（層 3 測試結果）
```

已查證的旗標（實作時以層 2 / 層 3 測試再確認）：

| | claude | codex | agy |
|---|---|---|---|
| model | `--model opus\|sonnet` | `-m gpt-5.5` | `--model gemini-3.1-pro-high`（名稱含 effort） |
| effort | `--effort low\|medium\|high` | `-c model_reasoning_effort=…` | `--effort low\|medium\|high` |
| 免審批 | `--permission-mode acceptEdits` | `-a never -s workspace-write` | `--mode accept-edits` |
| 專案 skills | `.claude/skills/` | `.agents/skills/` | `.agents/skills/` |
| 指令檔 | `CLAUDE.md`（`@AGENTS.md` 匯入） | `AGENTS.md` | `AGENTS.md`（待驗證） |
| MCP 設定 | `.mcp.json` / `~/.claude.json` | `~/.codex/config.toml` | `~/.gemini/antigravity-cli/mcp/` |

## 9. Skills

### init（專案首次啟用跑一次）

1. 偵測可用工具：`herdr agent start --help` 的 kind 清單 ∩ `which` ∩ `kinds/` 有檔；確認登入狀態。
2. 問主模型（預設 claude）；若選別的，改寫六個角色檔的 kind 與三檔為該工具對應等級，可逐角色調整。
3. 問第二、第三意見工具，寫進 LEADER.md 的評議波預設成員；沒裝的不列。
4. 掃專案根目錄預填 PROJECT.md，人確認後存。
5. 對每個已選工具跑 `mcp list`，比對所有角色檔 `mcp:` 需求，列出缺的並印出對應 `xxx mcp add …` 指令；不代寫設定。

### add-role（隨時）

1. 問角色：名稱、一句職責、交接對象。
2. 偵測可用工具（同 init）。
3. 人選工具，預設推薦 claude。
4. AI 依職責難度建議 S/M/L 三檔的 model/effort 並說明理由。
5. 人逐檔確認或修改。
6. 產出 `roles/<name>.md`；登錄 `roles/README.md`。

## 10. MCP 立場

dkboai 本身不提供 MCP server（herdr CLI 經 bash 已是三家最大公約數），也不同步三家的 MCP 設定（格式互異、含認證）。只在角色檔聲明需求、init 檢查並印指令、dk-spawn 派工時警告。

## 11. 測試策略

| 層 | 內容 | 成本 |
|---|---|---|
| 1 腳本單元測試 | bats + 假 `herdr` stub；覆蓋所有 bin/ 腳本邏輯；TDD 主戰場 | 零 token，可 CI |
| 2 真 herdr 假 agent | `herdr --session dktest` 獨立 server，驗 JSON 欄位與 `--env`、`rename`、`notification` 真實行為 | 零 token，一次性 |
| 3 真 agent 煙霧 | 三 kind 各一次：spawn → 寫 state → DONE → wave-close；並測 working 中收 prompt 是否排隊 | 最低檔，三次 |
| 4 端對端示範 | repo 內 `example/` 小專案；兩波任務、故意觸發 BUG→FIXED→ESCALATE、中途 /clear 用 dk-resume 恢復 | S 檔，一次人工 |

不測模型輸出品質；評議波只在示範中手動跑一次。

## 12. 待實作時驗證的假設

- agy 是否讀 `AGENTS.md`；若不讀，找其對應指令檔並在安裝步驟加一個 symlink。
- 三 kind 在 working 中收到 `agent prompt` 的行為（決定 dk-msg 是否必須等 idle）。
- codex 免審批的正確旗標組合（`-a never -s workspace-write`）在目前版本是否足夠。
- `herdr pane split --env` 注入的變數是否被 agent 子進程繼承。
  - **已驗證（2026-09-10，真實 herdr 0.9.0，`tests/integration/herdr-real.sh`）**：`--env K=V` 注入的變數確實被新 pane 的 shell 繼承（`echo $VAR` 可讀到）。
- `herdr worktree create` 的回傳 JSON 形狀（`.result.workspace.workspace_id`、`.result.root_pane.pane_id` 是否存在；`.result.path` 是否存在）。
  - **已驗證（2026-09-10，真實 herdr 0.9.0）**：`.result.workspace.workspace_id` 與 `.result.root_pane.pane_id` 都存在，形狀與 stub 相符。真實 herdr **沒有** `.result.path`（路徑改放在 `.result.worktree.path` / `.result.workspace.worktree.checkout_path`），但 `dk-task-new`／`dk-chore` 本就對 `.result.path // empty` 的落空有 `git worktree list --porcelain` 的 fallback，實測可正確取得路徑，不需改動。另發現真實 herdr 的 `worktree create` 不接受 `--workspace` 與 `--cwd` 同時給（互斥，會回 usage error exit 2）；`.dkboai/bin/` 內的呼叫本來就只用 `--cwd`，不受影響，只有驗證腳本本身需要對應修正（已修正）。
