# 守望誤判與任務計時 — 給 backend-watch 的切片（波 2）
由 dk-wave-open 產生，只讀。完整 brief 在 /home/bal/project/teamflow/.dkbo/tasks/2026-09-19-watchtime/brief.md。

## 目標
兩件事，出 0.9.2：(1) dk-watch 不再把員工**正在工作時**畫面上的字樣當成撞額度或卡審批 —— 以 herdr 的 agent_status 為前提，working 就不看畫面；
(2) 領導看得到時間 —— `dk-resume` 印任務／本波／每位員工的已進行時長，`dk-wave-close` 記每波耗時，新腳本 `dk-timeline` 從 process.md 算整張時間表並由 `dk-task-close` 附進 report.md。

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

## 你的波次
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
| 2 | 實作 | backend-watch | AC15、AC16：skip_screen_check 的 done 判定比對 .redispatch（與 dk-watch:219-221 同一條），dk-msg 的重派快照擴到 [BUG]；各補測試、先紅後綠。不動 CHANGELOG | M | 06/09/26 全綠、tests/run.sh 全綠、shellcheck 零警告、report 紅綠齊 | 預設 |

## 你的檔案所有權
| 成員 | 可改 | 只讀 |
|---|---|---|
| backend-watch | .dkbo/bin/dk-watch, .dkbo/bin/dk-msg, .dkbo/lib/kinds.sh, .dkbo/kinds/**, tests/unit/09_watch.bats, tests/unit/26_watch_events.bats, tests/unit/03_kinds.bats, tests/unit/06_msg.bats | .dkbo/**, tests/** |

## 共用契約（全文）
（一列一個契約。擁有者填一個成員短名；消費者填一個或多個、逗號分隔；沒有就填 —。完全沒有契約時只留表頭）
| 契約 | 擁有者 | 消費者 | 形狀／簽名 | 變更流程 |
|---|---|---|---|---|
| CHANGELOG 0.9.2 條目 | backend-time | backend-watch | CHANGELOG 只有 backend-time 能寫。backend-watch 做完後用 `dk-msg backend-time "[TASK] CHANGELOG: fix(watch): <一行>"` 把自己那條交過去，backend-time 原文寫進首節 | 格式或位置要變先 ESCALATE |
| process.md 時間行的 token | backend-time | backend-watch | `dk-timeline` 只認既有行首 token：`task-new`、`gate1 approved`、`wave-open N`、`dev-done wave N`、`review N spawned`、`review N verdict`、`review N skipped`、`wave-close N tests`、`task-close`。backend-watch 動到 dk-watch 寫的 `dev-done wave N` 與 `limit`／`blocked` 行時不得改這些 token 的形狀 | 改 token 先 ESCALATE |
| agent_status 前提 | backend-watch | — | `assess()` 與逾時 `(quota?)` 標記在 status 為 `working` 時跳過畫面判定；status 取不到照舊判定；herdr 回 `blocked` 的路徑不變 | 改語意先 ESCALATE |
| 分鐘換算函式 | backend-time | — | `lib/common.sh` 新增 `dk_ts_minutes "YYYY-MM-DDTHH:MM"` 回自 epoch 起的分鐘數（純算術），`dk-resume`、`dk-wave-close`、`dk-timeline` 共用一份 | 簽名要變先 ESCALATE |

## 驗收標準（全文）
- [ ] AC1 `dk-watch` 對某 agent 做 quota 畫面判定（`assess()`）之前，先看 herdr `agent list` 回的 `agent_status`：是 `working` 就**不做**畫面判定。測試：agent 狀態 working、畫面含 `You've hit your usage limit` → 不送 `[LIMIT]`、`DK_KIND_DOWN` 不變、不記 `limit` process 行、不建 `.blocked/<agent>.limit`；同一畫面把狀態改成 idle → `[LIMIT]` 照常。先紅後綠。
- [ ] AC2 同一道前提套用到 block 的畫面判定（`KIND_BLOCK_RE`）與 reviewer 逾時的 `(quota?)` 標記：working 且畫面含 `Do you want` → 不送 `[BLOCKED]`（immediate 路徑）；idle 同畫面 → 照常。herdr 直接回 `blocked` 的既有路徑（`handle_block … 0`，壓 `DK_BLOCK_SEC` 門檻）行為不變。有測試。
- [ ] AC3 `agent_status` 取不到（agent 不在 `agent list`、herdr 呼叫失敗）時**照舊做畫面判定**（寧可誤報，不可漏掉真卡住），有測試斷言這條路徑，測試名含 `unknown-status`。
- [ ] AC4 事件路徑（`26_watch_events.bats` 那條 herdr events 訂閱觸發的 assess）同樣受 AC1 前提約束；`09_watch.bats`、`26_watch_events.bats` 既有測試全綠。
- [ ] AC5 `dk-resume` 的「本波」段新增兩行：`任務已進行 Xh Ym（自 task-new）` 與 `本波已進行 Ym（自 wave-open）`；沒有開波時只印任務那行。「在線員工」每位附 `等了 N min`（`.panes` 第三欄 epoch 到現在），dev 與 reviewer 一致。有測試（`10_resume.bats`）。
- [ ] AC6 `dk-wave-close` 成功關波時 stdout 多印一行並記 process：`wave N 耗時 Mm（dev Am、審查 Rm）` —— M 是 `wave-open N` 到現在，A 是 `wave-open N` 到 `dev-done wave N`，R 是 `review N spawned` 到最後一個 `review N verdict`；缺任一來源該欄印 `—`。純文件波（`review N skipped`）審查欄印 `skip`。有測試（`08_wave_close.bats`）。
- [ ] AC7 新增唯讀腳本 `bin/dk-timeline [<task>]`：只讀 process.md 印 markdown 表：任務總時長（`task-new` → `task-close`，未結案則到現在並標「進行中」）、計畫階段（`task-new` → `gate1 approved`）、每波一列（開波→關波、dev、審查，缺則 `—`）、結案階段（最後一次 `wave-close` → `task-close`）。零 token、不寫任何檔。
- [ ] AC8 `dk-timeline` 對 `tests/fixtures/` 內兩份真實 process.md（highfix 與 flowgap，從 `.dkbo/tasks/` 複製）算出的數字與人手算一致：highfix 任務 66 分、計畫 6 分、波 1 27 分（審查 7 分）、波 2 16 分（審查 3 分）；flowgap（領導已從 process.md 人手算）：任務 279 分、計畫 15 分、結案 42 分、波 1 148 分（dev 22、審查 125，審查取最後一則 verdict）、波 2 16 分（dev 1、審查 4）、波 3 21 分（dev 0、審查 5）、波 4 23 分（dev 0、審查 6）—— 波 2–4 的 dev 分鐘是當時假聚合留下的，dk-timeline 忠實反映 log 即可。含至少一個跨日樣本（fixture 可手改時間戳製造跨日，註明）。
- [ ] AC9 `dk-task-close` 結案（非 `--abandon`）時把 `dk-timeline` 的輸出附到 report.md 尾端 `## 時間` 段，再 commit 任務記憶；`templates/report.md` 加 `## 時間`（註明由 dk-task-close 填）。有測試（`12_task_close.bats`）。
- [ ] AC10 `skills/run/SKILL.md` 與 `.dkbo/README.md`「日常使用」各補一句 `dk-timeline`；`README.md`／`README.en.md` 的 dk-resume 描述補上時間行。
- [ ] AC11 `tests/run.sh` 全綠、shellcheck 零警告；`.dkbo/VERSION` 0.9.2、CHANGELOG 首節 `## 0.9.2 — 2026-09-19` 含 `fix(watch)` 與 `feat(time)` 兩條、八處版本字串一致、herdr 六處仍 0.9.0。
- [ ] AC12 兩位 dev 的 report 紅綠：backend-watch 貼 AC1、AC2、AC13；backend-time 貼 AC5、AC6、AC8 各自先失敗後通過的實際指令與輸出。
- [ ] AC13 state 已 `status: done` 的 agent 不做額度與審批的畫面判定（它已交差，畫面殘留的字樣不影響本波；highfix 第二次誤判就是 reviewer 交報告後被自己引用的字樣熔斷）。測試：idle、state done、畫面含 `usage limit` → 不 `[LIMIT]`；同條件 state working → 照常。
- [ ] AC14 `.blocked/<agent>.limit` 標記在領導解除熔斷（`.task.env` 的 `DK_KIND_DOWN` 清空）後仍留著，dk-watch 下一輪對同一畫面不重新熔斷、不重送 `[LIMIT]`；有測試守著。`skills/run/SKILL.md` 故障段的「同任務內解除熔斷」補一句：標記檔不要刪。
- [ ] AC15 `dk-watch` 的 `skip_screen_check()` 對 `status: done` 的認定改成與逾時路徑（`dk-watch:219-221`）同一條：done **且**（沒有 `.blocked/<agent>.redispatch` **或** state 的 cksum 已與標記內容不同）才跳過畫面判定 —— 被 `[TASK]` 重新指派、state 還停在上一輪 done 的員工沒有交差，撞額度要照常 `[LIMIT]`（整枝審查 Important 1，reviewer 已實跑重現）。測試（加進 `26_watch_events.bats` 或 `09_watch.bats`）：idle、state `status: done`、`.redispatch` 內容 = 當下 state 的 cksum、畫面含 `usage limit` → `[LIMIT]` 照常、建 `.limit`、記 `limit` process 行；同條件把 state 改寫（cksum 變）→ 不 `[LIMIT]`；既有 AC13 兩條（沒有 `.redispatch` 檔）行為不變。先紅後綠，report 貼紅綠。
- [ ] AC16 `dk-msg` 的重派快照（`redispatch()`：重設 `.panes` epoch、清 `.timeout`、存 state cksum 到 `.blocked/<agent>.redispatch`）從只認 `[TASK]` 擴成 `[TASK]` 與 `[BUG]` —— 領導轉 reviewer 的 Important 給 dev 用的是 `[BUG]`，它同樣是派新活。其他類型（`[ANSWER]`、`[DECISION]`、`[DONE]`…）不動。`06_msg.bats` 補一條 `[BUG]` 正例（epoch 重設、`.redispatch` = cksum），既有「只有 [TASK] 開啟新的一輪」那條把名稱與斷言調成「TASK／BUG 以外不動」，`[ANSWER]` 反例保留。CHANGELOG 不用動（0.9.2 的 `fix(watch)` 那行已涵蓋）。

## 同波成員
backend-watch(M)
