# BACKLOG A–C 清理 結案
結果：merged 8dc8442   分支：dk/bklog   波數：2（波 1 實作＋文件 4 人、波 2 整枝評議修復 3 人）
## 完成
- AC1–AC19 全數達成（reviewer-a 逐條驗過，見 `state/reviewer-a.report.md`）：dk-watch 對 working 的 reviewer 不熔斷、dev／qa 閒置逾時提醒、`dk-kind down`、審查補派別名累加、領導→員工訊息背景送（含 FIFO 與 `undelivered` process 行）、重派已交付 dev 會清 latch 重新聚合、`dk-process` 拒收格式錯的 minor 行、`dk-brief-check` 無主測試 WARN／欄數閘／契約 `@波N`、跳脫感知切欄、`--run` 開在當下 workspace、state 行數規則、PROTOCOL／LEADER／SKILL／README 三份／CHANGELOG 0.16.0／VERSION，BACKLOG 刪 17 列。
- 範圍外順修：`lib/repos.sh` 的 `dk_glob_check` 在 pipefail 下 SIGPIPE 偶發誤判（base 就有，實測 3000 次 20 次）。
- 波 1 審查的 Important 1（背景佇列：未排隊的子行程空等 1 小時、`queue_leave` 留 pid）修一輪即綠；整枝評議累積 Minor 13 條中 11 條已修（含 `.panes` 讀改寫統一拿 `.blocked/panes.lock`、wave-close 裁定閘改詞界比對）。
## 未完成 / 遺留
- 無未經審查的波（波 1、波 2 都是 claude L 審查；波 2 審查即第 2 輪整枝評議）。
- 整枝評議不修的 Minor：`dk-wave-close:56` 詞界只收空白，全形標點接別名會 fail-closed（實測：全倉 51 行 verdict 無一如此）；`tests/unit/07_spawn.bats:278` 與 `08_wave_close.bats:323` 各一份 `hold_panes_lock`（`tests/helpers.bash` 無人擁有）。
- 記進 BACKLOG：`lib/ownership.sh:12` 的 `dk_owned` 與 `dk-spawn:57` 的 `first_glob` 仍裸 `awk -F'|'`（實測：歷來 brief 的所有權欄無一含跳脫管線；base 既有行為）。
- 超出全域約束 (a)(b)(c) 字面的既有測試改動三處，皆有 ruling、reviewer 同意不算放寬：06 六處與 09 一處前綴 `DK_MSG_BG=1`（斷言不動）、`20_review.bats:18` 期望值改 AC4 新語意、`13_leader.bats:84` 改寫成 AC11 新語意。
- AC8 的 WARN 清單 15 條＝計畫時模擬的 14 條＋`33_repos.bats`（因 `lib/repos.sh` 中途劃給 backend-brief），差異已說明。
- 本任務的新行為都在 worktree，領導跑的是主樹舊腳本，本任務內一次都沒用到（例：`dk-wave-close` 仍用舊的 state 行數規則對 backend-docs 報 `state too long`）。
## 驗證
- 最後一次 wave-close（波 2，16:02）：`tests/run.sh` 全過，`bats --count` 724 條＝CHANGELOG 填的 724（+68）；shellcheck 零警告（每位 dev 與 reviewer 實跑）。
- 每位 dev 的 report「## 測試」都有取紅紀錄，取紅皆在獨立副本做，沒有動 stash／checkout。
- reviewer 用 scratchpad 探針重現 Important 1 並在修後重跑轉綠；07 那條鎖測試附拿掉鎖的突變探針紅／綠。
## 自主裁定（待你複核）
1. 14:34 AC5 讓 06／09 的既有前景斷言變競態：這些呼叫前綴 `DK_MSG_BG=1`（同步投遞核心），斷言一字不改，背景路徑由新測試守。若錯代價：前景返回路徑只由新測試覆蓋，要補斷言。
2. 14:37 准改 `20_review.bats:18` 期望值為 AC4 新語意（第二次派得 `c(agy)`），並補斷言 spawned 行累加 a b c。若錯代價：若認定是放寬，改成拆成獨立 wave 的寫法。
3. 14:52 准改寫 `13_leader.bats:84`（DK_WORKSPACE 不被改寫）成守 AC11 新語意——與你拍板的 25 Important4 反轉是同一個決定，brief 漏列。若錯代價：語意再反轉時一併改回。
4. 14:52 `lib/repos.sh` 劃給 backend-brief，修 `dk_glob_check` 的 SIGPIPE 誤判（一行 here-string），超出 17 條範圍。若錯代價：多一行範圍外 diff。
5. 15:32 累積 Minor 9 條：7 已修，其餘 8 條全修，開一個修復波 2（「毫秒級競態不會發生」是推測，不當不修的理由）。若錯代價：多一波約 30 分鐘（實際 30m）。
6. 15:32 波 2 所有權重劃：`dk-wave-close`、`dk-spawn`、07、08 歸 backend-msg（`.panes` 鎖一人改完），`lib/review.sh`、20 從 backend-watch 移給 backend-brief。若錯代價：成員讀新檔多花時間。
7. 15:32 CHANGELOG 測試條數由 backend-docs 在波 2 等另兩位 `[DONE]` 後自己跑全套填入，不另下 `[TASK]`。若錯代價：修復後條數過時要再補（實際未發生，724 相符）。
8. 15:53 波 2 新 Minor：1 照修（改寫既有 @test、不新增）；2 不修（fail-closed、實測無人這樣寫）；3 記 BACKLOG（實測無人用跳脫管線、改它要再開一輪整枝評議）；4 不修。若錯代價：2 若有人寫全形分隔，wave-close 擋下多打一行。
## 重要決策
- 08:08 成員可改 `.dkbo/` 下劃給自己的規則檔（dogfood，PROTOCOL 停止條件本任務不適用）。
- 08:08 #17 tab 開在 `--run` 當下所在的 workspace、#4 契約欄允許 `<成員>@波N`（你在計畫階段選的推薦項）。
- 08:08 bklog 在 testtrust 合併後才交棒；計畫審查只派 claude（codex、agy 專案層熔斷）。
- 08:16 AC2 qa 閒置計時從本波聚合起算、dev 從最後指派起算；CHANGELOG 測試條數以最後一次 wave-close 實跑值為準。
- 15:17 波 1 Important 1 屬實，回原 dev 修並順修同路徑 Minor 7；15:27 複看通過關波 1。
- 15:53 修復波 2 的 L 檔審查即第 2 輪整枝評議，Important 0 → 關卡③。
- 以上 9 條加「自主裁定」8 條，共 17 條 ruling（`grep ' ruling: ' process.md`）。
## 給下次的話（≤3 行）
- 背景送的改動會讓「送完當場斷言」的舊測試全變競態，計畫時就該把 06／09 的前綴改法寫進全域約束的允許清單。
- 主樹 dk-watch 對 reviewer 的 20 分鐘逾時這次沒觸發（兩波的審查段 22m／6m，單次審查都在 20 分鐘內交件），0.16.0 合併後才真正免疫。
## 時間
任務 2026-09-24-bklog
| 階段 | 開始 | 結束 | 時長 | dev | 審查 |
|---|---|---|---|---|---|
| 任務 | 2026-09-24T08:06 | 2026-09-24T16:42 | 516m | — | — |
| 計畫 | 2026-09-24T08:06 | 2026-09-24T08:44 | 38m | — | — |
| 波 1 | 2026-09-24T14:32 | 2026-09-24T15:30 | 58m | 33m | 22m |
| 波 2 | 2026-09-24T15:32 | 2026-09-24T16:02 | 30m | 15m | 6m |
| 結案 | 2026-09-24T16:02 | 2026-09-24T16:42 | 40m | — | — |
