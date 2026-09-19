# backend-watch 報告（波 2）
## 做了什麼
- AC15：`.dkbo/bin/dk-watch` 的 `skip_screen_check()` 對 `status: done` 的認定改成跟
  `tick()` 逾時區塊（`dk-watch:219-221`）同一條 —— done 且（沒有 `.blocked/<agent>.redispatch`
  或 state 的 cksum 已跟標記內容不同）才跳過畫面判定。被 `[TASK]`／`[BUG]` 重新指派、state
  還停在上一輪 done（cksum 與 `.redispatch` 一致）的員工不再豁免，撞額度照常 `[LIMIT]`。
- AC16：`.dkbo/bin/dk-msg` 的 `redispatch()` 觸發條件從只認 `[TASK]` 擴成 `[TASK]` 與
  `[BUG]`（`if [ "$type" = TASK ] || [ "$type" = BUG ]`）——領導轉 reviewer 的 Important
  給 dev 用的是 `[BUG]`，同樣是派新活，需要重設 epoch、清逾時標記、存 state 快照。
  `[ANSWER]`、`[DECISION]`、`[DONE]` 等其他類型不動。
- 未動 `.dkbo/lib/kinds.sh`、`.dkbo/kinds/**`：這兩條驗收標準不涉及額度/審批式子本身。
- CHANGELOG 沒動：0.9.2 的 `fix(watch)` 那行波 1 已交給 backend-time 涵蓋。

## 測試
### 紅
- `./tests/run.sh tests/unit/26_watch_events.bats`
  → `not ok 11 AC15: state done 但 .redispatch 快照跟現在一致（被重派卻沒交差）LIMIT 照常`
    (`` `grep -q '\[LIMIT\] from dk-watch: login-qa' "$HERDR_STUB_LOG"' failed` ``)
- `./tests/run.sh tests/unit/06_msg.bats`
  → `not ok 23 AC16: [BUG] 也開啟新的一輪（領導轉 reviewer Important 給 dev）`
    (`` `now=$(date +%s); [ "$(epoch_of "$d" login-reviewer-a)" -ge "$((now - 10))" ]' failed` ``)

### 綠
- `./tests/run.sh tests/unit/26_watch_events.bats` → `1..24` 全數 `ok`（含 AC15 兩條）
- `./tests/run.sh tests/unit/06_msg.bats` → `1..26` 全數 `ok`（含 AC16、改名後的 ANSWER 反例）
- `./tests/run.sh tests/unit/09_watch.bats` → 全數 `ok`（未改動，確認沒有回歸）
- `./tests/run.sh tests/unit/03_kinds.bats` → 全數 `ok`（未改動，確認沒有回歸）
- `./tests/run.sh`（全套）→ `1..429` 全數 `ok`
- `shellcheck -x .dkbo/bin/dk-watch .dkbo/bin/dk-msg` → 無輸出（零警告）

## 自我審查
- AC15 的判準刻意跟 `dev_delivered()`／`tick()` 逾時區塊用同一組概念（done + redispatch
  快照比對），沒有另創一套命名或邏輯；沿用 `cksum`、`.blocked/<agent>.redispatch` 這組既有
  的檔案格式，不新增檔案或欄位。
- 沒有把 AC15 的前提套進 reviewer 逾時區塊（`(quota?)` 標記那段）：波 1 已確認共用契約
  只把 「state done」 豁免限定在 `assess()`（額度／審批的畫面判定），逾時區塊本來就有它
  自己的 done 判定（`dk-watch:219-221`），本波沒有理由重複改它。
- AC16 只加 `[BUG]` 一種類型，其餘型別（`[ANSWER]`、`[DECISION]`、`[DONE]`、`[FIXED]`、
  `[QUESTION]`、`[ESCALATE]`、`[STOP]`、`[BLOCKED]`）維持不觸發 `redispatch()`，符合驗收
  標準「其他類型不動」的字面。
- 全套 `tests/run.sh` 跑過一次，429 條全綠，確認沒有波及其他測試檔。

## 疑慮
- 無。AC15、AC16 都照驗收標準逐條落地，先紅後綠，未動共用契約與所有權外的檔案。
