# dkbo：每波審查閘、事前防線與多人版面 — 設計規格

日期：2026-09-10
狀態：待審
前置：`docs/superpowers/specs/2026-09-09-dkboai-ai-team-design.md`（原設計；該文件寫 `dkboai/` 之處，實際目錄為 `.dkbo/`）

## 1. 目標與範圍

第一版 dkbo 已能開任務、派工、傳訊、關波、結案。用 superpowers 的 subagent-driven-development（SDD）實作它的過程顯示：18 個任務裡 13 個在「每步審查」被抓出真實缺陷，6 個計畫缺陷在派工前的預檢被攔下。本規格把這幾個讓 SDD 穩定的機制搬進 dkbo 的初始結構：

- 每個實作波內建審查閘（1 至 3 位 reviewer，可用不同 kind 當第二、第三意見），與 qa 並行。
- 事前防線：brief 機械預檢、員工個人 brief 切片、報告檔與 state 分離、關波時自動跑測試。
- 裁定（ruling）成為 process.md 的固定格式，結案時彙整給人。
- reviewer 逾時偵測與 kind 熔斷，避免因模型用量到頂而卡波。
- 多人時的 herdr 版面：領導佔滿高的一欄，員工依容量填格、動態均分。

範圍外：查詢模型用量（三家 CLI 沒有可 script 的介面）；reviewer 之間互相反駁（評議波已有）；自動重派逾時的 reviewer；改動 dk-msg 的訊息類型。

### 已定案的關鍵決策

| 決策 | 選擇 |
|---|---|
| 範圍 | 核心審查閘 + 事前防線；純文件規則（修復升級路徑、小事合併派工、員工停止條件）直接改 LEADER/PROTOCOL，不入計畫 |
| 審查位置 | 與 qa 並行；dev DONE 後領導同時派 reviewer 與 qa |
| reviewer 人數 | 1 至 3 位，kind 可不同，領導彙整裁定 |
| 設定存放 | 新增 `.dkbo/settings.env`（init 寫、bash 可 source） |
| 防呆層級 | 法定人數 + 逾時 + kind 熔斷；不查用量 |
| 整體做法 | 混合型：無聲且昂貴的失敗機械化，需判斷的留給文件；`--skip-review` 逃生口需記理由 |
| 版面 | 領導所在 tab 1：領導佔滿高左欄，右側 2×2 放 4 位員工；tab 2 起每 tab 6 位（3×2）；動態均分 |
| 填位順序 | dev 先填 tab 1，溢出的 dev 進 tab 2 之首，qa/reviewer 接在最後一位 dev 之後 |

## 2. 資料檔與格式

### 2.1 `.dkbo/settings.env`

init skill 寫入；所有值加引號；`lib/common.sh` 新增 `dk_settings`：source 此檔，缺檔時用預設值並警告一次。

```
DK_TEST_CMD=""                  # wave-close 在 worktree 執行；空字串表示不跑
DK_REVIEW_KINDS="claude"        # 預設 reviewer kind，依偏好排序，1 至 3 個
DK_REVIEW_MIN="1"               # 至少幾位意見回來才算審查完成
DK_REVIEW_TIMEOUT_MIN="20"      # reviewer 逾時分鐘
DK_TAB1_SLOTS="4"               # tab 1 右側可放的員工格數（4 = 2×2，6 = 3×2）
```

### 2.2 `.task.env` 新增欄位

```
DK_WAVE=""            # 目前波號；dk-wave-open 寫、dk-wave-close 清空
DK_KIND_DOWN=""       # 本任務內熔斷的 kind，空白分隔
DK_TABS=""            # 本任務開的溢出 tab，格式 "<tab_id>:<root_pane> …"，依序 tab2 tab3 …
```

### 2.3 `.panes` 行格式

`<agent> <pane_id> <epoch> <group> <tab_no> <slot>`。`epoch` 是 spawn 時間（逾時計算），`group` 是 `dev|review`，`tab_no` 從 1 起，`slot` 是該 tab 內的格號（tab 1 為 1–`DK_TAB1_SLOTS`，其他 tab 為 1–6）。

### 2.4 process.md 事件詞彙（只追加）

```
wave-open 2 base a1b2c3d members backend(M) qa(S)
review 2 spawned login-reviewer-a(claude) login-reviewer-b(codex)
review 2 verdict a: ok / b: important 2
review 2 skipped: 純文件波
ruling: <決定> — <原因> — <若錯代價>
timeout login-reviewer-b (quota?) → kind codex down
wave-close 2 tests ok (npm test) 3 agents closed
wave-close 2 tests skipped (no DK_TEST_CMD) 2 agents closed
```

`ruling:` 是唯一必要的裁定格式；影響其他任務者另複製一行進 `decisions.md`。

### 2.5 成員 brief 切片 `tasks/<t>/briefs/<agent>.md`

`dk-wave-open` 依 `templates/brief-member.md` 渲染，員工只讀。內容：任務標題與目標、該成員的波次列、該成員的所有權列、共用契約全文、驗收標準全文、同波其他成員一行清單。首段提示改指此檔；brief.md 仍可讀。

### 2.6 報告檔 `tasks/<t>/state/<agent>.report.md`

不限行數，員工自寫，依 `templates/report-employee.md`：`## 做了什麼`、`## 測試`（指令與輸出，必填）、`## 自我審查`、`## 疑慮`。`state.md` 維持 ≤20 行，新增一行 `report: state/<agent>.report.md`。reviewer 的 report 格式另見 §5.2。

### 2.7 brief.md 範本

波次表新增「審查」欄，值為 `預設`、`skip: <理由>` 或 `kinds: <k1> [k2] [k3]`。所有權表下方加一列範例（成員欄 `（範例）backend`，`dk_owned` 以字串等值比對，不會誤中）。

### 2.8 角色檔

`split:` 改為 `group: dev|review`。出廠值：pm、frontend、backend、it 為 `dev`；qa、reviewer 為 `review`。`worktree: false` 的角色（pm）不進員工格，維持在領導 pane 旁切一格。

## 3. 腳本

### 3.1 新增

**`dk-brief-check`**（關卡①前，只讀 brief.md 與 roles/）
- 所有權表：成員欄為 `<角色>[-<別名>]` 且角色檔存在；可改欄 glob 兩兩不重疊（`**` 前綴與字面路徑比對）；同一路徑不得出現在兩人的可改欄。
- 波次表：成員都在所有權表；難度只能 S/M/L；審查欄格式合法；波號連續。
- 驗收標準至少一條；共用契約段非空（可寫「無」）。
- 某波 dev 成員超過 `DK_TAB1_SLOTS` → WARN（不阻擋，建議拆波）。
- 輸出 `OK`、`WARN …` 或逐條 `FAIL <位置>: <原因>`；有 FAIL 時非零退出。不改任何檔。

**`dk-wave-open N`**
- 要求 `.panes` 為空、`DK_WAVE` 為空。
- `base=$(git -C "$DK_WORKTREE" rev-parse HEAD)`；寫 `DK_WAVE=N`；渲染每位成員的 `briefs/<agent>.md`；process 記 `wave-open N base <sha> members …`。
- 重複開同一波拒絕。

**`dk-review-pack [N]`**
- 從 process.md 找 `wave-open N base <sha>`（預設目前波）；在 worktree 產生 `tasks/<t>/waves/N.diff`（commit 清單、stat、`-U10` diff，`<sha>..HEAD`）；印路徑。無 commit 時仍產出但警告。
- `--task` 模式：base 改為任務建立時的分支基底（`.task.env` 新增 `DK_BASE` 由 dk-task-new 寫入），供結案前整分支評議。

**`dk-review [--kinds "a b"] [--tier M|L] [N]`**
- kind 清單來源優先序：`--kinds` > 波次表審查欄 `kinds:` > `DK_REVIEW_KINDS`；扣掉 `DK_KIND_DOWN`；上限 3。
- 對每個 kind 依序以別名 a/b/c 呼叫 `dk-spawn reviewer <別名> --isolated --kind <k> [--tier T]`；首段提示指向 `waves/N.diff`、`briefs/<agent>.md`、report 格式（§5.2）。
- process 記 `review N spawned …`。派不出任何 reviewer 時非零退出並提示領導記 `review N skipped: all kinds down`。

**`lib/layout.sh`**
- `dk_layout_slot GROUP` → 依 `.panes` 現況與 §6 規則回傳 `<tab_no> <slot> <anchor_pane> <direction> <ratio>`；需要新 tab 時回傳 `NEWTAB`。
- `dk_layout_even TAB_NO` → 讀 `herdr pane layout`，對該 tab 剩餘員工 pane 以 `herdr pane resize` 調成每欄等寬、每列等高；tab 1 的領導欄不動。

### 3.2 修改

**`dk-task-new`**：不再用 `herdr worktree create` 開 workspace；改為 `git -C "$DK_PROJECT_ROOT" worktree add -b dk/<short> <path> <base>`（路徑 `.worktrees/<short>` 或 `DK_WORKTREE_DIR` 設定）。`.task.env` 新增 `DK_BASE=<sha>`；`DK_WORKSPACE`/`DK_ROOT_PANE` 改記領導所在 workspace 與 pane。

**`dk-spawn`**：首段提示指向 `briefs/<agent>.md`（不存在則退回 brief.md）；呼叫 `dk_layout_slot` 決定 anchor、方向、ratio；需要新 tab 時 `herdr tab create --workspace $DK_WORKSPACE --cwd $DK_WORKTREE --label <short>-<n> --no-focus` 並記入 `DK_TABS`；`.panes` 寫六欄；`--split right|down` 可臨時覆寫方向（不覆寫 tab 與 slot）。

**`dk-wave-close`**：新增三檢查，任一失敗且無 `--force` 就不關 pane：(a) process 有 `review N verdict` 行，或審查欄為 `skip` 且有 `review N skipped:` 行；(b) 每位 group=dev 成員的 report 存在且含 `## 測試`；(c) `DK_TEST_CMD` 非空時於 worktree 執行，失敗印最後 20 行。通過後 process 記 `wave-close N tests ok|skipped …`、清空 `DK_WAVE`、對每個受影響 tab 呼叫 `dk_layout_even`。`.task.env` 無 `DK_WAVE` 欄（舊任務）時退回舊行為並警告一次。

**`dk-watch`**：對 `.panes` 中 group=review 且名稱含 `-reviewer-` 的成員，`now - epoch > DK_REVIEW_TIMEOUT_MIN*60` 且 state 非 done 時：`herdr agent read <agent> --lines 30`，含 `rate limit|quota|429|usage limit`（不分大小寫）則標 `(quota?)`；`herdr agent prompt <leader> "[TIMEOUT] from dk-watch: <agent> 逾時 (quota?)"`、`herdr notification show`、process 記 `timeout …`、把該 kind 加進 `DK_KIND_DOWN`；每位只通知一次（marker 同 blocked 機制）。

**`dk-resume`**：新增「本波」段（`DK_WAVE`、base、每位 reviewer 狀態）、「裁定」段（最後一個 `wave-open` 以來的 `ruling:` 行）、「在線員工」改為每 tab 一行。總行數上限仍 150，降級順序：state 3 行 → process 10 行 → 裁定段只印最後 5 行。

**`dk-task-close`**：清 `DK_TABS` 中的 tab（`herdr tab close`），`git worktree remove` 取代 `herdr worktree remove`。

## 4. 一波的流程與錯誤處理

### 4.1 流程（LEADER.md「跑一波」）

1. `dk-wave-open N`。
2. 對該波每位 dev/qa 成員 `dk-spawn`；結束 turn，閒置。
3. 收到 dev `[DONE]`（state done、report 有 `## 測試`）：`dk-review-pack N` 再 `dk-review`。qa 同時在驗，不必等。
4. 收到 reviewer `[DONE]`：讀其 state/report。達 `DK_REVIEW_MIN` 且無 Important，或所有 reviewer 皆回覆，即裁定：process 記 `review N verdict …` 與 `ruling:`。有 Important → `dk-msg <dev> "[BUG] review: …"` 指向 reviewer 的 report；dev `[FIXED]` 後領導重跑 `dk-review-pack` 給原 reviewer 複看（同一 bug 一次修復上限照 PROTOCOL）。
5. qa `[DONE]` 且審查已裁定：`dk-wave-close N`；看測試結果與越界警告；在 worktree commit `wave N: …`；`dk-msg --ack`。
6. 純文件波：審查欄 `skip: <理由>`，領導 `dk-process "review N skipped: <理由>"`。

### 4.2 錯誤處理

| 狀況 | 處置 |
|---|---|
| reviewer `[TIMEOUT]` | 領導關 pane（該 kind 已熔斷）；達 `DK_REVIEW_MIN` 照常裁定，否則 `dk-review --kinds <未熔斷者>` 補一位；全部熔斷 → `review N skipped: all kinds down`，report.md 遺留段標「本波未經審查」 |
| reviewer 意見矛盾 | 以 brief 為準裁定並記 `ruling:`；不能依 brief 判者升關卡② |
| wave-close 測試失敗 | 不關 pane；`dk-msg <擁有者> "[BUG] wave-close tests: …"`；連續兩次失敗升關卡② |
| dev report 缺 `## 測試` | wave-close 拒絕；`dk-msg <dev> "[TASK] 補 report 測試段"` |
| `dk-brief-check` FAIL | 修 brief 重跑，全 OK 才給人 |
| `/clear` | `dk-resume` 印本波 base、reviewer 狀態、裁定；從第 3 或 4 步接續 |
| 熔斷解除 | 任務層級，`dk-task-close` 清掉；同任務內領導手動編輯 `.task.env` 並 `dk-process "kind <k> up"` |

## 5. 文件與 skill

### 5.1 LEADER.md（≤120 行）
- 開任務：寫完 brief 先 `dk-brief-check`；審查欄三種寫法。
- 跑一波：§4.1 六步。
- 裁定小節：格式；何時只記 process、何時進 decisions.md；report.md「重要決策」列出本任務所有 ruling。
- 評議波：引用 `settings.env`，init 不再改寫 prose。
- 故障：reviewer 逾時、熔斷、測試失敗三條。
- 結案：關卡③前 `dk-review-pack --task` 派 L 檔 reviewer 做整分支評議，其 Important 修掉或記 ruling 才寫 report.md。
- 開頭一句：`dk-*` 皆在 `.dkbo/bin/`。

### 5.2 PROTOCOL.md（≤120 行）
- 首段提示指向 `briefs/<agent>.md`；state ≤20 行、report 不限且必含 `## 測試`；DONE 前兩者都寫好。
- reviewer 專節：只讀、不改碼、不跑寫入指令；report 格式 `## 規格合規`（✅/❌ 與缺漏）、`## Important`、`## Minor`，每條附 `file:line`；意見只給領導，不直接對 dev 說。
- 停止條件：不 push、不改寫歷史、不刪分支、不動所有權外的檔、不裝依賴（it 除外）；遇到就 ESCALATE。
- chore 員工無任務綁定，以 `herdr agent prompt "$DK_LEADER"` 回報（沿用）。

### 5.3 其他
- `roles/reviewer.md`：職責改「實作波審查與結案評議」，完成定義加 report 格式；`group: review`。
- templates：`brief.md` 加審查欄與範例列；新增 `report-employee.md`、`brief-member.md`；`state.md` 加 `report:` 行。
- `skills/init`：步驟 3 改為寫 `settings.env`（測試指令、reviewer kind 清單與順序、法定人數、逾時、tab 1 格數），結束摘要列出這些值。
- `.dkbo/README.md`：日常使用加「每波自動附審查」；更新段 rsync 排除加 `settings.env`。
- `tests/e2e/RUNBOOK.md`：加第 11 步「讓一位 reviewer 用未登入的 kind，觀察 `[TIMEOUT]` 與熔斷」。

## 6. 多人版面

### 6.1 配置
- **tab 1**（領導所在的原 tab，領導 workspace）：領導 pane 靠左佔滿高；右側區域放 `DK_TAB1_SLOTS` 位員工（4 = 2×2：左上、右上、左下、右下；6 = 3×2）。
- **tab 2、3、…**：`herdr tab create --workspace <領導 workspace> --cwd $DK_WORKTREE --label <short>-<n>`，每 tab 6 位（3 欄 × 2 列），滿了開下一個；記入 `DK_TABS`。
- 員工 pane 皆以 `--cwd $DK_WORKTREE` 切出；不再另開 worktree workspace。
- `worktree: false` 的角色（pm）在領導 pane 旁切一格，不佔員工格。

### 6.2 填位順序
dev 依 spawn 順序填 tab 1 的員工格 → 溢出的 dev 填 tab 2 之首 → qa 與 reviewer 接在最後一位 dev 之後 → 滿 6 開新 tab。`dk-brief-check` 對 dev 超過 `DK_TAB1_SLOTS` 的波給 WARN。

### 6.3 切法（`dk_layout_slot`）
- tab 1 第 1 位：對領導 pane 向右切 `--ratio 0.5`（右側區域）；第 2 位：對右側區域向下 `0.5`（左上/左下）；第 3 位：對左上向右 `0.5`；第 4 位：對左下向右 `0.5`。`DK_TAB1_SLOTS=6` 時第 3、5 位以 `1/3`、`1/2` 比例切欄。
- tab n（n≥2）：根 pane 為第 1 位；第 2 位向下 `0.5`；第 3 位對第 1 欄上格向右 `1/3`、第 4 位對第 1 欄下格向右 `1/3`；第 5、6 位對第 2 欄上下格向右 `0.5`。任何人數下每格大小一致。
- `--split` 只覆寫方向，不覆寫 tab 與 slot。

### 6.4 動態均分（`dk_layout_even`）
`dk-wave-close` 與逾時關 pane 後，對受影響 tab 讀 `herdr pane layout`，以 `herdr pane resize --direction --amount` 讓剩餘員工 pane 每欄等寬、每列等高；tab 1 的領導欄寬度不動。tab 2 起若一位員工都不剩則 `herdr tab close`（並自 `DK_TABS` 移除）。

## 7. 測試策略

| 層 | 內容 |
|---|---|
| 1 bats（TDD） | `dk-brief-check` 各 FAIL/WARN 情境與通過案例；`dk-wave-open` 寫 `DK_WAVE`、process 行含 base、切片只含本人的列、`.panes` 非空/重複開波拒絕；`dk-review-pack` 用真 git 建 commit 產 diff 檔、找不到 wave-open 報錯、`--task` 模式；`dk-review` kind 來源優先序、扣熔斷、上限 3、全部熔斷非零；`dk-wave-close` 三檢查各自的拒絕與放行、`skip` 放行、`DK_TEST_CMD` 成敗（`true`/`false` 與印輸出的小腳本）、`--force`、舊任務相容；`dk-watch` 逾時一次通知、`(quota?)` 標記、`DK_KIND_DOWN` 寫入、done 不觸發；`dk-resume` 本波與裁定段、tab 地圖、降級；`dk_settings` 預設與覆寫；`dk_layout_slot` 對 1–10 位員工回傳的 tab/slot/anchor/方向/ratio 表；`dk_layout_even` 對假 layout JSON 發出的 resize 呼叫；`dk-spawn` 建新 tab 與 `DK_TABS` 寫入、`--split` 覆寫；現有 82 個測試維持通過（角色檔 `split:`→`group:` 需同步改 04_docs） |
| 2 真 herdr | `herdr-real.sh` 加：`tab create` 回傳形狀、在指定 tab 內 `pane split --ratio`、連切 4 格關 1 格後 `pane resize` 並讀 `pane layout` 驗比例、`agent read --lines` 的 JSON 形狀 |
| 3 / 4 | 不新增自動化；RUNBOOK 加逾時與熔斷的觀察步驟 |

## 8. 不做的事（YAGNI）
不查模型用量；不自動重派逾時 reviewer；不做 reviewer 互相反駁；不把 `ruling:` 結構化為 YAML；不改 dk-msg 類型（TIMEOUT 與 BLOCKED 同路徑由 dk-watch 直推）；不做 tab 之間搬移 pane。

## 9. 相容性
`settings.env` 缺檔時所有新腳本用預設值運作；舊任務資料夾缺 `DK_WAVE`/`DK_TABS`/`DK_BASE` 時 `dk-wave-close` 與 `dk-task-close` 退回舊行為並警告一次；`.panes` 舊的兩欄格式由 `dk_layout_*` 視為「未知位置」，只關不重排。

## 10. 待實作時驗證的假設
- `herdr tab create` 的 JSON 含 `tab_id` 與根 pane id，且 `--cwd` 生效於該 tab 的 shell。
- `herdr pane split --ratio` 的比例語意是「新 pane 佔原 pane 的比例」（若為相反，`dk_layout_slot` 只需取 1−r）。
- `herdr pane layout` 的 JSON 足以還原欄列結構；`pane resize --amount` 的單位（比例或格數）。
- `herdr agent read --lines N` 回傳純文字或 JSON；rate-limit 訊息的實際字樣（三家 CLI 各記一例到 README）。
