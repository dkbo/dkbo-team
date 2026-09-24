# 測試可信度 — 需求原文

把人講的原話**逐字**抄在下面。不要摘要、不要改寫、不要先做技術轉換 ——
brief 才是轉換的產物，這一份是用來比對「brief 有沒有漏掉人要的東西」的基準。
外部文件（spec、issue、對話紀錄）請把相關段落整段貼進來，不要只留連結：
連結會死，而這個檔案要活到任務歸檔之後還有人讀得懂。

---

（原文從這裡開始）

## 人的原話（2026-09-24 同一場對話，依序逐字）

1. 「分析一下目前專案所建構的流程」
2. 「先 review backlog」
3. 「1」（回應領導「要我直接動手清理 BACKLOG（A、B 類和 L29 的更正）嗎？」）
4. 「先複查」
5. 「測試可信度」（回應領導「要 commit 嗎？還是直接開「測試可信度」任務（`/dkbo-plan`）？」）

## 人選中的那一項提議（領導在第 2 則之後的回覆，逐字）

> 2. **開一個「測試可信度」任務**，處理 L29 和 L30。這兩條都會讓測試綠了卻沒驗到東西，而其他所有修補都靠這些測試當閘。

## 外部文件：`.dkbo/tasks/BACKLOG.md` 的兩列（fb60415，逐字）

| 2026-09-22 | tasktab 整枝評議 Minor（2026-09-24 複查改寫） | `tests/unit/` 有 **74 處** `! cmd` 形式的否定斷言，不是原記的三處。bats 在 `set -e` 下跑，而 bash 的 `set -e` 忽略 `!` 開頭的指令，所以它不是測試的最後一條時，失敗也不會讓測試變紅 —— 逐條掃過有 **50 處**不是測試的最後一條、**根本沒在驗**（bats 1.14.0 實測：`! true; true` 綠；13 個檔，最多的是 `11_chore.bats` 13 處、`09_watch.bats` 8 處、`08_wave_close.bats` 7 處，例如 `09_watch.bats:230` 的「不該推 TIMEOUT」）。違反「否定斷言一律用 `refute_grep`」的全域約束 | 高：全部換成 `refute_grep`（`tests/helpers.bash:172`），非 grep 的 `! cmd` 改 `run cmd; [ "$status" -ne 0 ]`；再給 `tests/run.sh` 加一條掃描式 meta 測試擋住新增。與 fixture 漂移那條併成一個「測試可信度」任務 |
| 2026-09-22 | tasktab 波 2 ESCALATE | `tests/helpers.bash` 的 `fixture_task()` 自己手寫一份 `.task.env` heredoc，而不是套用 `.dkbo/templates/task.env`，於是兩者持續漂移：fixture 目前缺 `DK_TASK_TAB` 與 `DK_LEADER_PANE` 兩個鍵。任何「改既有那一行」的測試寫法（`sed -i 's/^DK_TASK_TAB=.*/…/'`）都會靜默變成空操作，測試看起來在驗東西其實沒有。實測：0.11.0 波 2 一條 Minor 清理就因此把 AC14 弄紅，且誤導成「helpers.bash 無人擁有」的升報 | 讓 `fixture_task()` 改由 `templates/task.env` 套模板產出（跟 `dk-task-new` 走同一條路），fixture 只覆寫需要的欄位；或至少補一條測試斷言 fixture 的 `.task.env` 鍵集合與模板一致。動它會碰到全部 547 條測試，要獨立一個任務做 |

## 領導在計畫前的試跑（scratchpad 副本，不動倉庫；供 brief 引用，不是人的原話）

- bats 1.14.0：`! true; true` 綠、`! true || false` 紅、`true; ! true` 紅 —— `!` 開頭的指令只有在測試最後一條時才有效。
- 把 76 處裡 72 處 `! X` 機械改成 `! X || false`（另 4 處已帶 `|| {…; false; }`）後全套 642 條全綠：沒有被遮住的真失敗。
- `fixture_task()` 的 `.task.env` 改由 `dk_render templates/task.env` 產出後全套 642 條仍全綠；但 06、09、12、16、20、28、29 七個檔的 setup 沒 source `common.sh`，`dk_render` 不存在，**它們拿到的是空的 `.task.env` 卻照樣全綠** —— fixture 壞掉沒有任何測試會紅。
- 更正（計畫審查 p1 查核）：上面「另 4 處已帶 `|| {…}`」不準，HEAD 只有 2 處（`24_portability.bats:22`、`25_docs_policy.bats:10`）；72＋4 的差額來自試跑的 perl 對一行兩處與管線形狀的切法，不影響「無被遮住的失敗」這個結論。
