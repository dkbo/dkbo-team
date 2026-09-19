# 守望誤判與任務計時 結案
結果：merged   分支：dk/watchtime   波數：2

## 完成
兩件事出 0.9.2，16 條驗收標準全數達成。

| 波 | commit | 內容 |
|---|---|---|
| 1 | `5e7890c` | backend-watch：dk-watch 做額度／審批的畫面判定前先看 herdr 的 agent_status，working 不判；state done 不判；status 取不到照舊判；事件路徑同受約束；解除熔斷後 `.limit` 留著。backend-time：`dk_ts_minutes` 純算術換算、dk-resume 印任務／本波／每位員工時長、dk-wave-close 記每波耗時、新腳本 dk-timeline、dk-task-close 結案附 `## 時間`、0.9.2 版本與文件 |
| 2 | `adbf411` | 整枝評議 Important 1：skip_screen_check 的 done 判定改成比對 `.redispatch` 快照（與逾時路徑同一條），被重派的員工撞額度照常 `[LIMIT]`；dk-msg 的重派快照擴到 `[BUG]` |

流程上的第一次：0.9.1 的 dev 聚合在多人波上生效（兩位分別 23:07／23:15 done，只推一則）；員工間用 QUESTION→TASK 交接 CHANGELOG 條目。

## 未完成 / 遺留
**triage 後判不修的 Minor**：wave-close 與 dk-timeline 各一份審查欄判斷邏輯（各有測試守）；逾時路徑的 working 前提連審批逃生口一起關（reviewer 傾向維持）；`review N skipped:` 冒號後不空格會退回 `—`；dk-resume 的 `e` 沒 local；backend-time 的 state 26 行（規則衝突已記 BACKLOG）。

**未經整枝視角審查的範圍**：波 2 是整枝評議 Important 1 的修復波，經 reviewer 以 `waves/2.diff` 逐條核過，未再跑第二輪整分支評議。

**本任務實跑記進 BACKLOG 的**：`tests/run.sh` 不跑 shellcheck、沒有機械閘；state ≤20 行與 touched 完整性衝突。

**流程事故**：領導 session 在整枝評議回報後重啟，重啟後的實例重複記了一組「不修直接合併」的裁定與 gate3（process 23:46），已於 23:48 記更正作廢；波 2 照重啟前的決定完成。

## 驗證
- `tests/run.sh`：399 → 426（波 1）→ **429 ok**（波 2），零 `not ok`；兩波 wave-close gate c 都在 worktree 實跑過。
- shellcheck（dev 與 reviewer 各手跑）：零警告。目前沒有機械閘守它，已記 BACKLOG。
- 版本：dkbo 八處 0.9.2；herdr 六處 0.9.0，新測試比對 `DK_HERDR_MIN`。
- `dk_ts_minutes` 由整枝 reviewer 拿 GNU `date -u -d` 對照八個值全符、跨年 span 正確；dk-timeline 對 highfix／flowgap fixture 的數字與領導人手算相同。
- 審查覆蓋：計畫審查 1 位（M，抓 2 處）、波 1（M，0）、整枝評議（L，1 Important）、波 2（M，0）。全程單一模型（codex／agy 額度未恢復）。
- 本任務內主樹仍跑舊腳本：假 `[LIMIT]` 又發生一次（backend-watch 寫測試字串），是本任務修的行為，合併後才生效；wave-close 沒印耗時行、task-close 不附 `## 時間`，下面的時間表是拿 worktree 版 dk-timeline 對本任務跑的。

## 重要決策
1. 員工可改 `.dkbo/`，以所有權表為準。
2. 一波兩位 dev 並行、CHANGELOG 集中給 backend-time、watch 那條用 dk-msg 交過去。
3. 計時只從 process.md 時間戳與 epoch 算，不新增員工欄位；換算不用 date -d／-j。
4. 剛轉 idle 畫面殘留的邊界補成 AC13，不留給下次。
5. flowgap 波 2–4 假聚合留下的 dev 分鐘不修正，時間表是 log 的鏡子。
6. 整枝評議 Important 1 補成 AC15、AC16 開波 2 修掉，不帶病合併；23:46 那組「不修直接合併」作廢。
7. 不再跑第二輪整枝評議。

## 給下次的話（≤3 行）
done 有本輪與殘留兩種，同檔逾時路徑早就分了；寫新判定前先 grep 同檔有沒有現成的同型判定。
領導 session 重啟後第一件事是 dk-resume 看 process 最後十行，不要憑記憶接手 —— 這次重複記了一組裁定。
多人波第一次跑順了：聚合、員工互傳、四道閘都沒出事，之後可以放心用兩到三位 dev。

## 時間
任務 2026-09-19-watchtime
| 階段 | 開始 | 結束 | 時長 | dev | 審查 |
|---|---|---|---|---|---|
| 任務 | 2026-09-19T21:56 | 2026-09-19T23:59 | 123m（進行中） | — | — |
| 計畫 | 2026-09-19T21:56 | 2026-09-19T22:42 | 46m | — | — |
| 波 1 | 2026-09-19T22:42 | 2026-09-19T23:24 | 42m | 33m | 7m |
| 波 2 | 2026-09-19T23:45 | 2026-09-19T23:59 | 14m | 7m | 6m |
| 結案 | 2026-09-19T23:59 | — | — | — | — |
