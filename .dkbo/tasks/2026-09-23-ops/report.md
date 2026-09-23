# 營運回饋修補（panova headermerge） 結案
結果：merged   分支：dk/ops   波數：4

## 完成
- 0.12.0：AC1–AC18 全數合規，四波逐波審查＋三輪 L 檔整枝評議，最後一輪的 Important 在波 4 修掉並經逐波審查確認。
- 專案層熔斷 `.dkbo/.sessions/kinds-down`（flock＋tmp/mv），恢復時間用純算術解析 agy「Resets in」與 codex「try again at …」，解析不到或目標已過標 `guess`＝現在＋5h；`dk_review_kinds` 與 `dk-spawn` 會查它（明寫 `--kind` 拒絕、角色預設只警告照派）；reviewer 逾時不寫專案層。
- `[LIMIT]` 留證據：`.limit` 追加 ≤5 行 `hit:`、訊息尾端附第一條；截斷**按字元**（`dk_utf8_trunc`），`LC_ALL=C` 下也不切半個 UTF-8 字元（第三輪整枝評議 I1：按位元組截會讓 herdr 拒收、`[LIMIT]` 永遠送不到）。
- codex `KIND_QUOTA_RE` 拿掉第 3 分支，Switch model 選單不再被判撞額度。
- 新 bin `dk-kind`（status／up，100755），`dk-kind up` 同時清專案層與任務層；`dk-resume` 在波內與兩波之間都印專案層熔斷。
- `dk-wave-open <N> --refresh`：重產切片、重設 `DK_WAVE_STARTED`、刪整波逾時標記；**不刪** devdone，改由 `dk-spawn` 在波開著時加入「還沒有 latch 的」dev 時刪（關卡② 裁定；`--handoff`／`--resume` 重派已交付者不刪）。
- dk-msg：切片過期提示、未 ack 提示、dev `[DONE]` 前驗 state 格式（三鍵、touched 文法、report 存在非空，錯誤附正確寫法）。
- `dk-task-close` 在 task-close 行之後補跑 `fill_timeline` 並改寫 `結果：` 行。
- run/SKILL.md：`[LIMIT]` 先讀 `hit:` 判真假、`dk-kind up` 解誤判、不叫員工跑 `dk-kind`、送 TASK 前先讀未 ack、視覺任務結案前先請人看畫面、波中改 brief 走 `--refresh`／新成員接著 spawn／原 dev 重做叫他回 `[FIXED]`。三份 README、PROTOCOL、state 範本、CHANGELOG、VERSION 同步。

## 未完成 / 遺留
- 無未經審查的波（波 1–4 都有逐波審查裁定）。
- **本任務的新閘一次都沒生效**：領導跑主樹腳本，AC10 的 state 驗證、AC11 的結果行改寫、專案層熔斷、`--refresh` 都要等合併後的下一個任務才用得到。本份 report 的「結果：」與「## 時間」由主樹舊版 dk-task-close 處理，時間表的任務列可能仍帶「（進行中）」。
- Minor 不修（記 BACKLOG）：codex 同日重置可能只印 `try again at 3:15 PM`（未驗證，落 guess 是安全退路）`.dkbo/lib/kinds.sh:89`
- Minor 不修：`dk_epoch_to_local` 以現在的時區偏移換算未來 epoch，跨夏令時間顯示差 1 小時（台灣無 DST）`.dkbo/lib/kinds.sh:133`
- Minor 不修（既有缺口）：`09_watch.bats:531` 那條只守反向、正向拿掉整行也不會紅
- 其餘 Minor（task／task2 共 12 條）皆已修，見 process.md 的 `minor:` 行與第三輪整枝評議的逐條判定。

## 驗證
- 波 4 wave-close gate c：worktree 跑 `tests/run.sh`，627 條全綠（0.11.2 為 552，+75）；`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh` 零警告；`git ls-files -s .dkbo/bin/dk-kind` 為 100755。
- 第三輪整枝評議的 I1 由 reviewer 以真 herdr 0.9.0 重現（`argument 4 is not valid UTF-8`, rc=2），領導以 GNU cut 9.4 複驗（60 個中文字截 160 → 161 bytes、iconv 報非法）；修後 09 有中文樣本與 `LC_ALL=C` 兩條斷言。
- 人旁觀回報的 34:55「疑似 flaky」查明是 kinds 在共用 worktree 用 `git stash` 暫退修法取紅所致；並行 2 份全套＋10 次單檔重跑全過，pop 後 worktree 與 `waves/4.diff` 逐行一致。

## 重要決策
- 07:53 本任務成員可改 `.dkbo/` 規則檔（原始碼倉 dogfood）
- 07:53 計畫審查只派 claude L（codex、agy 額度未恢復）
- 08:00 dk-spawn 只在明寫 `--kind` 命中專案層時拒絕，角色預設只警告（R1 選 A）
- 08:00 dev state 必備 status／touched／report，current／todo 不驗
- 08:00 kinds-down 用獨立鎖檔 `kinds-down.lock`
- 08:53 docs 的「worktree 被 reset」是誤判：它用 `$DK_ROOT` 路徑把 10 檔寫進主樹；領導 git apply 搬進 worktree 並還原主樹
- 09:21 波 1 Important（段落重複，搬移補丁與重做疊加）轉 docs 修
- 09:48 整枝評議 I2 經關卡② 採「改由 spawn 刪 devdone」，AC7 與 refresh 契約改寫，已寫進 decisions.md
- 09:48 整枝評議 I1（dk-kind up 單一 kind exit 1）與 5 條 Minor 併波 2；UTF-8 截斷那條原判記 BACKLOG
- 10:06 波 2 Important（README:109 [LIMIT] 列）是領導 brief 沒指明列，轉 docs 修
- 10:22 第二輪整枝評議 I1（handoff 重派推假聚合）判回歸、I2（缺回 [FIXED] 指引）補做；06:122 只補夾具不算放寬
- 10:39 CHANGELOG 條數以 wave-close 實跑為準
- 10:51 推翻 09:48 對 UTF-8 截斷「只影響顯示」的判斷，升 Important 波 4 修
- 11:29 波 4 後不再跑第四輪整枝評議
- 11:37 34:55 不是 flaky，是共用 worktree 裡 git stash 取紅

## 給下次的話（≤3 行）
員工 pane 的 `DK_ROOT` 指向主樹：在本倉改 `.dkbo/` 的任務，切片要寫明「編輯一律用 worktree 路徑」，取紅一律 cp 到獨立目錄、不在共用 worktree 用 git stash。
「只影響顯示」的 Minor 也要驗前提：UTF-8 截斷那條被判顯示問題，第三輪才實測出 herdr 整則拒收。
L 檔整枝評議三輪各抓到真 Important（設計洞、回歸、herdr 拒收），別因為逐波審查全綠就省。

## 時間
任務 2026-09-23-ops
| 階段 | 開始 | 結束 | 時長 | dev | 審查 |
|---|---|---|---|---|---|
| 任務 | 2026-09-23T07:50 | 2026-09-23T11:44 | 234m（進行中） | — | — |
| 計畫 | 2026-09-23T07:50 | 2026-09-23T08:45 | 55m | — | — |
| 波 1 | 2026-09-23T08:46 | 2026-09-23T09:30 | 44m | 28m | 12m |
| 波 2 | 2026-09-23T09:48 | 2026-09-23T10:13 | 25m | 9m | 13m |
| 波 3 | 2026-09-23T10:22 | 2026-09-23T10:44 | 22m | 11m | 6m |
| 波 4 | 2026-09-23T10:51 | 2026-09-23T11:40 | 49m | 31m | 7m |
| 結案 | 2026-09-23T11:40 | — | — | — | — |
