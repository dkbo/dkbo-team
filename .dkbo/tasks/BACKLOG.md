| 日期 | 來源 | 一句描述 | 建議處理 |
|---|---|---|---|
| 2026-09-12 | 0.5.0 最終審查 | 記錄檔遺失時把空 branch 正規化成 `-` 的那道守衛沒有測試守著，改壞了出口 4 會悄悄回來 | 補一條測試，下次動 `dk-chore-close` 時一起 |
| 2026-09-12 | 0.5.0 最終審查 | `PROTOCOL.md:60-63` 的 `dk-msg leader "[DONE] …"` 在同一段出現兩次 | 延後，下次動 PROTOCOL 時一起收 |
| 2026-09-12 | 0.5.0 任務審查 | `LEADER.md:13` 的替換句跨三行，周圍 bullet 都是單行 | 延後（lazy continuation 渲染正確，讀者是 LLM） |
| 2026-09-14 | panova2 流程審查 | reviewer 逾時分支對 `status: done` 的 state 無條件 skip；reviewer 交完首輪後被派複看又卡住，會永久靜默 | 把 skip 改成比對「本波指派時間」而不是無條件跳過 |
| 2026-09-14 | panova2 流程審查 | `.panes` 的 epoch 是 spawn 時間，第二輪派工不重置，逾時量的是「spawn 以來」而不是「這一輪等了多久」 | `dk-msg` 送 `[TASK]` 給 reviewer 時重置該列的 epoch |
| 2026-09-19 | dk/briefrev 全分支審查 | `dk-brief-review` 與 `dk-review` 的 spawn 迴圈有 14 行逐字重複（別名指派、`dk-spawn` 呼叫與 rc 捕捉、prompt-failed 三分支、`spawned` 累積、結尾 `dk_die`/`dk_process`/`echo`），只有 `dk_render` 那一句與標籤字串不同；已評估兩段式抽法可行（別名由 kind 清單位置決定、先跑 render 迴圈產出全部切片，再呼叫共用的 `dk_review_spawn`，它只假設切片已存在，無回呼、無 eval、bash 3.2 相容），這一輪選擇先出貨 | 下次動這兩支任一支時把共用邏輯抽進 `lib/review.sh` |

