# backend-watch 報告（波 1）
## 做了什麼
- **AC1（#16）** `.dkbo/bin/dk-watch` reviewer 逾時區塊：超過門檻且 `agent_status` 是 `working` 時，不動 `DK_KIND_DOWN`、不寫 kinds-down、不記 `timeout … → kind … down`、不發桌面通知；改記 process `timeout <agent> working (no kind down)` 並推 `[TIMEOUT] from dk-watch: <agent> 逾時但仍在工作（未熔斷）`。標記 `.blocked/<agent>.working` 第一行存這一輪的 `.panes` epoch，同 epoch 只記／推一次（送不到下一 tick 重試）；epoch 變了自動重新武裝。之後不再 working 且仍未交就落到既有熔斷路徑。status 拿不到（不在名單）照舊熔斷；`herdr agent list` 失敗時 tick 本來就整輪跳過（既有行為，未改）。
- **AC2（#10）** `dk-watch` 新函式 `idle_check`（只在 `DK_WAVE` 開著時跑，接在聚合之後）：group=dev 與 group=review 但名字不是 reviewer 的成員；`agent_status` 為 idle/done；dev 用 `dev_delivered`、qa 用 state＋`.redispatch` 判準；起點 dev＝`.panes` 第 3 欄、qa＝max(第 3 欄, `wave-N.devdone` 的 `at=`)，沒聚合不計時；超過 `DK_REVIEW_TIMEOUT_MIN` → process `idle <agent> <N>min`、推 `[TIMEOUT] from dk-watch: <agent> 閒置 <N> 分鐘未交（state 不是這一輪的 done）`，永不熔斷。標記 `.blocked/<agent>.idle`：第 1 行＝當時 `.panes` 第 3 欄（契約），第 2 行 `min=<N>`（重試時訊息一致），送達追加 `delivered`。聚合標記建立時改寫成 `notified` + `at=<epoch>` 兩行。
- **AC3（#25）** `.dkbo/bin/dk-kind down <kind> [--until YYYY-MM-DDTHH:MM] [--note <文字>]`：未知 kind、缺值、未知旗標、格式錯、已過去都 exit 2；`--until` 以 `dk_ts_minutes` 分鐘差換 epoch（無 `date -d`）標 exact，沒給則現在＋5h 標 guess；經 `dk_kinds_down_set` 寫列（任務名或 `-`、agent `leader`、hit＝note 或 `leader 人工登記`）；綁任務時 `DK_KIND_DOWN` 補上（不重複）、process `kind <k> down (leader) until <本地時間>[ (guess)]`；stdout `kind <k> down until …`。印的是**實際生效列**的時間與標記（同 kind 已有較晚列時是那一列）。usage 列出三個子指令。
- **AC4（#26）** `.dkbo/lib/review.sh`：新 `dk_review_prev LABEL`（最新 `<LABEL> spawned` 行的名單）；`dk_review_aliases` 多一個 LABEL 參數，跳過已用別名，池不夠分就 `dk_die`（不重用別名）；`dk_review_spawn` 的 spawned 行與 stdout＝舊名單＋新派。`dk-review` 池 `a`–`f`（label `review <N>`／`review task`），`dk-brief-review` 池 `p1`–`p6`（label `brief-review`）。不關、不重派既有 reviewer。
- `.dkbo/lib/kinds.sh` 沒有改。

## 測試
### 紅
（實作前，新測試寫好先跑；輸出節錄）
```
$ tests/run.sh tests/unit/09_watch.bats
not ok 66 AC1: working 的 reviewer 逾時只提醒一次，不熔斷任何一層
#   `[ "$(grep -c "^agent prompt leader-login $working_msg\$" "$HERDR_STUB_LOG")" -eq 1 ]' failed
not ok 69 AC2: dev 閒置超過門檻未交 → 推一次、記 process、不熔斷
not ok 71 AC2: 聚合建立時記 at=，qa 的計時從聚合起算
#   `grep -q "^at=[0-9][0-9]*\$" "$d/.blocked/wave-1.devdone"' failed
not ok 72 AC2: 同一 epoch 只推一次；重新指派（epoch 變了）自動重新武裝
not ok 74 AC2: 失敗送不到時下一 tick 重試，process 只記一次
$ tests/run.sh tests/unit/34_kind_down.bats
not ok 30 AC3: --until 給定 → exact，列與輸出都用那個本地時間
#   `run dk-kind down codex --until "$t"; [ "$status" -eq 0 ]' failed
not ok 31/33/34/35/36（同樣是 dk-kind down 不存在 → usage exit 2；36 是 usage 沒列 down）
$ tests/run.sh tests/unit/20_review.bats
not ok 13 AC4: 同一波補派 → 別名跳過已派的、spawned 行累加、第一位的 pane 不被關
#   `[ "$output" = "review 1: login-reviewer-a(claude) login-reviewer-b(agy)" ]' failed
not ok 14 AC4: 別名池擴到 a–f；不同 label（別的波）各算各的
$ tests/run.sh tests/unit/28_brief_review.bats
not ok 14 AC4: 補派計畫審查 → 別名 p2、spawned 行兩位都在、p1 的 pane 不被關
not ok 15 AC4: 計畫審查別名池到 p6 為止
```
紅階段就過的新測試（回歸護欄，不是新行為的證據）：09 #67「轉 idle 後照常熔斷」、#68「status 未知照常熔斷」、#70「qa 未聚合不推」、#73「working/blocked/已交/reviewer 不走閒置」；34 #32「錯誤輸入 exit 2」（舊 usage 本來就 exit 2）。
取紅方式：先寫測試、原始碼未動時直接跑，沒有用 stash／checkout。

### 綠
```
$ tests/run.sh tests/unit/09_watch.bats        → 74/74 ok
$ tests/run.sh tests/unit/26_watch_events.bats → 26/26 ok
$ tests/run.sh tests/unit/34_kind_down.bats    → 36/36 ok
$ tests/run.sh tests/unit/28_brief_review.bats → 全 ok
$ tests/run.sh tests/unit/20_review.bats       → 14/14 ok
$ tests/run.sh tests/unit/06_msg.bats / 07_spawn.bats → 全 ok（AC2 沒讓 06 多推 [TIMEOUT]）
$ shellcheck dk-watch dk-kind kinds.sh review.sh dk-review dk-brief-review → 零警告
```
綠階段踩到一次：idle_check 對「還沒聚合」的 qa 讀 `wave-N.devdone` 用 `$(sed … | head -1)`，檔案不存在 → pipefail＋set -e 讓 dk-watch exit 2（09 #44、#49 與 AC2 四條紅）。根因是 assignment 的 command substitution 會觸發 errexit；補 `|| true`。
**20_review.bats:18 期望值變更（AC4 改行為，leader [DECISION] 2026-09-24T14:44 准）**：同波第二次 `dk-review --kinds agy 2` 的期望輸出由 `review 2: login-reviewer-a(agy)` 改為 `review 2: login-reviewer-a(claude) login-reviewer-b(codex) login-reviewer-c(agy)`；另補一條斷言最新 `review 2 spawned` 行＝a、b、c 三位；`--kind agy` 那條保留未動。

### 送 DONE 前的完整測試
```
$ tests/run.sh                → 1..704，703 ok；唯一 not ok 547「Important4（0.16.0 反轉）」在 25_docs_policy.bats（backend-docs 的 AC16，進行中，非我的檔）
$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh → 只剩 lib/brief.sh 的 SC2016（backend-brief 的檔）；我的六個檔零警告
```

### AC5 配合（leader [TASK]：以領導身分送 TASK/BUG 的呼叫前綴 DK_MSG_BG=1、斷言不改）
我擁有的測試檔裡只有一處：`tests/unit/09_watch.bats:406` 的 `redispatched()` 改成 `DK_MSG_BG=1 dk-msg login-reviewer-b "[TASK] 複看第二輪"`，斷言一字未改（26/34/20/28 沒有 dk-msg 呼叫）。
```
$ tests/run.sh tests/unit/09_watch.bats → 74/74 ok
$ tests/run.sh                          → 1..714，714 ok（含 AC5 落地後的 dk-msg 與 25 的新語意）
```

## 自我審查
- 排除：09 #44 的 exit 2 不是 dev_delivered 的 latch 副作用 —— 用暫存目錄 `bash -x` 重現，最後一行停在 `at=` 的 sed，確認是 pipefail。
- AC2 只在 `DK_WAVE` 開著時跑：沒有開著的波就沒有「這一輪要交的東西」，且 `dev_delivered` 的 latch 路徑用到 `DK_WAVE`。AC 原文沒寫這個前提，這是我的判斷。
- AC2 額外跳過 `.blocked/<agent>`（審批中）與 `.blocked/<agent>.limit`（撞額度）已在的成員：領導已經收到 [BLOCKED]／[LIMIT]，不再多吵一則。
- AC1 的 working 提醒沒發桌面通知（只推領導＋process），避免既有「notification show … timeout 只一次」的斷言在轉 idle 熔斷時變兩次。
- `.blocked/<agent>.working` 是 dk-watch 內部標記，不在任何共用契約裡；`.idle` 第 2 行 `min=` 是契約之外的附加行（契約只規定存 epoch，我放在第 1 行）。
- AC4：`dk_review_aliases` 在池不夠時 die（exit 1），訊息含「別名」；stdout 改為印累加後的整份名單（與 spawned 行一致）。

## 疑慮
- 20_review.bats:18 與 AC4 的衝突已依 leader 裁定處理（見「## 測試」）。
- AC5 背景送的配合已依 leader [TASK] 完成（見「## 測試」最後一節）。
- `lib/brief.sh` 目前有 SC2016（backend-brief 的檔、進行中），全倉 shellcheck 會因它不過；我的六個檔零警告。
- 本任務的新行為由主樹腳本跑時一次都不會生效（全域約束），以上都是測試環境驗證。
