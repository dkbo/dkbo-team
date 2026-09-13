| 日期 | 來源 | 一句描述 | 建議處理 |
|---|---|---|---|
| 2026-09-12 | 0.5.0 最終審查 | 記錄檔遺失時把空 branch 正規化成 `-` 的那道守衛沒有測試守著，改壞了出口 4 會悄悄回來 | 補一條測試，下次動 `dk-chore-close` 時一起 |
| 2026-09-12 | 0.5.0 最終審查 | `PROTOCOL.md:60-63` 的 `dk-msg leader "[DONE] …"` 在同一段出現兩次 | 延後，下次動 PROTOCOL 時一起收 |
| 2026-09-12 | 0.5.0 任務審查 | `LEADER.md:13` 的替換句跨三行，周圍 bullet 都是單行 | 延後（lazy continuation 渲染正確，讀者是 LLM） |
| 2026-09-12 | 0.5.0 任務審查 | `11_chore.bats`「keeps the live worker's worktree」多一行冗餘斷言 | 延後（`grep branch=` 已涵蓋它） |
| 2026-09-12 | 0.5.0 最終審查 | `01_common.bats` 的 `dk_index_set` 沒命中測試用 `$(cat)` 比對，會吃掉結尾換行，`cmp` 才名副其實 | 延後（`dk_index_add` 一定寫換行，目前不可達） |
| 2026-09-12 | 0.5.0 任務審查 | `&` 測試守著一個不可能失敗的機制（`printf` 與 `awk -v` 都不把 `&` 當元字元） | 保留當 tripwire，防有人改回 `sed -i` |
| 2026-09-12 | 0.5.0 任務審查 | `dk_index_set` 六個呼叫點的警告字串近乎逐字重複 | 已裁定保留（與 `dk_commit_memory` 既有體例一致）；日後改措辭要改六處 |
| 2026-09-12 | ChatGPT 討論 + 0.6 brainstorm | 自主巡檢：第九鍵 `DK_PATROL_MIN`、`dk-watch --patrol` 第三模式、bash 掃描有變化才叫醒領導、只寫 BACKLOG 不動手 | 0.6.x（設計已到 §1，見對話紀錄；0.6.0 給了雜務佈局） |
