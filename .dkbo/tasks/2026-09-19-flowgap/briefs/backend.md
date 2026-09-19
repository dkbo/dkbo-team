# 流程缺口補齊 — 給 backend 的切片（波 4）
由 dk-wave-open 產生，只讀。完整 brief 在 /home/bal/project/teamflow/.dkbo/tasks/2026-09-19-flowgap/brief.md。

## 目標
把 dkbo 相對 superpowers 的六個流程缺口補齊：brief 的全域約束與介面契約、TDD 骨架、
除錯方法論、Minor 匯總、修復迴圈的中間層。設計見 plan.md，逐 task 的實作步驟見
implementation.md（13 個 task，程式碼可直接貼）。出貨版本 0.9.0。

## 你的波次
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
| 4 | 修復 | backend | 整枝評議的 2 條 Important 與 4 條 Minor，逐條見 state/reviewer-a.report.md | M | AC18–AC24、tests/run.sh 全綠、shellcheck 零警告 | kinds: claude |

## 你的檔案所有權
| 成員 | 可改 | 只讀 |
|---|---|---|
| backend | .dkbo/**, tests/**, CHANGELOG.md, README.md, README.en.md | example/**, .github/** |

## 共用契約（全文）

**本任務的停止條件例外（先讀這一條）**
`PROTOCOL.md` 的停止條件寫著「不改 `.dkbo/` 下的規則檔」。**這一條對本任務不適用** ——
本任務的產出就是 `.dkbo/` 下的規則檔與腳本本身。以上面的檔案所有權為準：劃給你的就改，
沒劃給你的一律不動。其餘停止條件（不 push、不改寫歷史、不刪分支、不裝依賴、不跑會跳權限
確認的指令）照舊全部有效。領導已就此記 ruling，見 process.md。

**跨波的介面（前一波產出、後一波消費）**
| 契約 | 擁有者 | 消費者 | 形狀／簽名 | 變更流程 |
|---|---|---|---|---|
| `dk_brief_constraints`（波 1 產出） | backend | backend | `dk_brief_constraints BRIEF` → 段落內文；段落不存在時輸出空、exit 0 | 波 2 與波 3 消費；要改簽名先 ESCALATE |
| `dk_brief_interfaces`（波 1 產出） | backend | backend | `dk_brief_interfaces BRIEF` → 每列五個欄位，依序是 契約／擁有者／消費者／形狀／變更流程 | 波 1 內自用；要改簽名先 ESCALATE |
| `{{CONSTRAINTS}}` token（波 1 產出） | backend | backend | 三份切片模板的 token；`dk-review` 的 `dk_render` 呼叫已帶它 | 波 3 在同一個 `dk_render` 上加 `{{MINORS}}`，不要移除它 |
| `dk_first_prompt` 參數表（波 2 產出） | backend | backend | 波 2 只改 printf 內文；波 3 新增第 9 個位置參數 HANDOFF，前八個順序不變 | 要動前八個先 ESCALATE |
| `## 測試` 的紅綠小節（波 2 產出） | backend | backend | `### 紅` 與 `### 綠` 各至少兩行非空內容；首行 `不適用: <理由>` 為單行豁免 | 波 3 的 report 照這個格式寫 |

**為什麼擁有者與消費者都是 backend**：這個任務只有一位成員，跨的是**波**不是人，而契約表的兩欄
依 AC3 必須是所有權表的成員短名。波次資訊改放在契約名與變更流程欄。schema 容不下「跨波契約」
這件事本身是發現，已記進 BACKLOG。

## 驗收標準（全文）
- [ ] AC1 `## 全域約束` 進 brief 範本，且流到成員切片、波審查切片、計畫審查切片三處
- [ ] AC2 `dk_brief_constraints()` 有 reader 與測試
- [ ] AC3 共用契約表格化；`dk-brief-check` 驗擁有者／消費者都在所有權表內
- [ ] AC4 舊 brief（段落／表頭不存在）得到 WARN 且 exit 0；新 brief（存在但空／格式不符）得到 FAIL 且 exit 1
- [ ] AC5 `## 測試` 分成 `### 紅` / `### 綠`；`dk-wave-close` 要求每一小節**至少兩行非空內容**（指令列與其輸出），缺小節或只有一行即拒絕
- [ ] AC6 小節首行是 `不適用: <理由>` 時，該小節豁免兩行規則，`dk-wave-close` 放行
- [ ] AC7 `lib/prompt.sh` 的首輪提示可 grep 到字串 `先寫一條會失敗的測試` 與 `methods/debugging.md`
- [ ] AC8 `.dkbo/methods/debugging.md` 存在；`PROTOCOL.md` 的 BUG 列指向它
- [ ] AC9 `dk-review --task` 的切片帶本任務累積的 Minor；逐波審查不帶
- [ ] AC10 `dk-task-close` 對「有 minor 行但 report 沒提」只警告不阻擋
- [ ] AC11 `dk-spawn --handoff "<原因>"` 寫出符合 `^[^ ]+ ruling: 換 <kind>/<tier> 接手 <agent> 的修復 — <原因> — ` 的 process 行，且首輪提示可 grep 到 `上一位修過一次沒成功`（一般 resume 的提示不含這句）
- [ ] AC12 `--handoff` 不帶原因時 exit 非零
- [ ] AC13 `PROTOCOL.md` 與 `skills/run/SKILL.md` 的修復迴圈都是兩輪
- [ ] AC14 `tests/run.sh` 全綠、`shellcheck .dkbo/bin/* .dkbo/lib/*.sh` 零警告
- [ ] AC15 `dk_brief_interfaces()` 有 reader 與測試（與 AC2 平行；它被共用契約表列為波 1 產出、後續消費的正式契約）
- [ ] AC16 `PROTOCOL.md` 的 `[FIXED]` 列要求內文附根因一句，且有測試守著
- [ ] AC17 測試套件在帶有領導環境變數（`DK_PROJECT_ROOT` 等）時仍完全隔離：不在真實 repo 建 worktree／分支，且有一條回歸測試守著
- [ ] AC18 `skills/run/SKILL.md` 第 4 步教領導把 reviewer 的 Minor 寫成 `dk-process "minor N: <一句> <file:line>"`，格式與 `dk-review` 讀它的 pattern 對齊（整枝 Important 1：這條 process 行目前沒有生產者）
- [ ] AC19 `roles/backend.md`、`roles/frontend.md`、`roles/qa.md` 的修復迴圈文字與 `PROTOCOL.md` 一致（兩輪、第二輪換腦袋），不再寫「修一次不過就升報」（整枝 Important 2：角色檔在首輪提示的必讀第一項，員工讀到的是一輪）
- [ ] AC20 `dk-task-close` 的 minor 警告不被 `templates/report.md` 自己的指引行消掉（比對時忽略 `^（` 開頭的行），且有測試守著
- [ ] AC21 `dk-wave-close` 的 `不適用` 豁免同時接受半形 `:` 與全形 `：`
- [ ] AC22 首輪提示的 TDD 那一句只發給 `group: dev` 的成員；reviewer 與 qa 不再收到與自己報告格式矛盾的指示
- [ ] AC23 `dk-spawn --handoff` 的 ruling 在 pane 與 agent 真的起來之後才落盤，spawn 失敗不留下「換人」的假裁定
- [ ] AC24 `dk-review` 與 `dk-task-close` 對 `minor` process 行使用同一個 pattern（抽進 `lib/`）

## 同波成員
backend(M)
