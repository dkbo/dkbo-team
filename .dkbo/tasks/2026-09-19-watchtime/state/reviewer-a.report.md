# reviewer-a 報告（波 2）

## 規格合規
- ✅ AC15：`skip_screen_check()`（dk-watch:126-131）的 `status: done` 認定改成與逾時路徑（dk-watch:219-221）同一條件形狀：`sf` 存在且 `status: done`，且（沒有 `.blocked/<agent>.redispatch` 或現在的 cksum 已跟標記內容不同）才跳過畫面判定。兩處條件逐字比對一致，只差 `continue` vs `return 0`。`26_watch_events.bats` 新增兩條測試（AC15 正反例）與既有 AC13 兩條、AC14 一條全綠，行為未受影響。
- ✅ AC16：`dk-msg` 的 `redispatch()` 觸發條件從只認 `[TASK]` 擴成 `[TASK]` 或 `[BUG]`（dk-msg:76）；相鄰註解同步改成「[TASK]／[BUG] 開啟新的一輪」。`06_msg.bats` 新增一條 `[BUG]` 正例（epoch 重設、`.redispatch` = cksum），既有「只有 [TASK] 開啟新的一輪」測試改名為「TASK／BUG 以外不動 epoch：[ANSWER] 不開新一輪」並保留 `[ANSWER]` 反例。CHANGELOG 未動，符合波次表「不動 CHANGELOG」。

## 測試
### 紅（dev 報告內已附，reviewer 這裡複驗綠側與迴歸）
不適用：reviewer 只讀，不重跑先紅步驟；紅綠證據見 dev report。

### 綠
- `tests/run.sh tests/unit/06_msg.bats tests/unit/09_watch.bats tests/unit/26_watch_events.bats` → 全綠（AC15 兩條、AC16 一條新測試皆 `ok`；既有 AC13/AC14/reviewer timeout/事件路徑測試無迴歸）。
- `tests/run.sh`（全量）→ `429 ok, 0 not ok`，exit=0。
- `shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh` → 零警告，exit=0。

## Important
（無）

## Minor
（本波累積清單為空，無需 triage）

## 疑慮
- 無。所有權檢查：本波差異包只動 `.dkbo/bin/dk-msg`、`.dkbo/bin/dk-watch`、`tests/unit/06_msg.bats`、`tests/unit/26_watch_events.bats`，四檔皆在 backend-watch 的可改清單內，未越界。
