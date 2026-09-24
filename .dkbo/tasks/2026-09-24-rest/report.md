# BACKLOG 剩餘六條（測試與守望） 結案
結果：merged 82bd82b   分支：dk/rest   波數：1（含一輪波內修復）
## 完成
- AC1 `dk-wave-close` gate c 除了 `DK_*` 也剝 `HERDR_*`（單／多 repo 共用 `clean` 陣列）；08 +2
- AC2 新檔 `tests/unit/37_shellcheck.bats`：沒裝就 skip、全域約束的檔案集合零警告、SC2086 自我驗證；`tests/run.sh` 不動
- AC3 `tests/helpers.bash` 抽出 `fixture_copy_dkbo`：夾具不再帶進主樹未追蹤的任務資料夾，tasks/ 追蹤檔還原成 HEAD 版（只用 plumbing／`--no-optional-locks`）；36 +3
- AC4 `11_chore` 補新版模板（沒有 `branch:` 行）的 legacy 測試，附突變探針
- AC5 守望程序：setsid 起（沒有照舊 nohup）、`.sessions/<任務>.watch.log` 記 start／signal／exit（HUP 不退出）、`--ensure` 遇死 pid 記 `watch died … last: …` 並以 flock 串行化、`dk-msg` 每個寫 log 的出口都叫回守望；波內修復再補 ⑦ `dk-task-new` 起第一對守望也走 `--ensure`、⑧ 任務結案（`.panes` 已刪）後 `dk-msg` 不再叫回；09 +10、26 +3、06 +5、05 +1
- AC6 `dk_owned`、`dk-spawn` 的 `first_glob`、`dk-brief-check` 取波次成員改用跳脫感知切欄（`\|`），`dk_owned` 只讀 `## 檔案所有權` 段；22 +2（含別段誘餌）、07 +1、16 +1（回歸守護）
- AC7 run SKILL 第 1 條補 `dk-msg`／`watch.log`／`watch died`（58 行 ≤60）；PROJECT.md 測試慣例改寫；CHANGELOG 0.16.0 節追加五條，測試行 756（+100，本任務 +32）；21 首節清單補齊
- AC8 BACKLOG 刪掉 request.md 列的 6 列，其餘不動
- AC9 `tests/run.sh` 全綠
## 未完成 / 遺留
- 沒有未經審查的波
- 整枝評議 triage 後不修的 Minor（皆 park，理由見下方自主裁定）：
  - M2 `dk-msg:258,268` 背景排隊的 `wake_watch` 在 `queue_leave` 之前跑，守望已死時同收件者下一則多排幾秒
  - M3 `dk-watch:454` HUP 打斷 `wait` 後殺掉本輪 sleep，下一輪提前跑；註解沒提
  - M4 `tests/unit/36_fixture.bats:133` 用 GNU 專屬 `touch -d`、`stat -c`（CI 全是 ubuntu）
  - M5 `dk-watch:30` 沒有 setsid 的平台（macOS），員工 pane 叫回的守望留在員工的行程群組；未在 macOS 實測
- 本任務的新行為（setsid、watch.log、`dk-msg` 叫回守望、gate c 剝 `HERDR_*`）在本任務內沒有生效過：領導跑的是主樹腳本。合併後的第一個任務才是第一次實跑，屆時看 `.sessions/<任務>.watch.log` 有沒有 start 行
- 不 push：照人的要求，全部處理完由人決定
## 驗證
- `dk-wave-close` 在 worktree 實跑 `tests/run.sh`：756 條全 ok（`tests ok`），37_shellcheck 是實跑、不是 skip
- reviewer-a（claude L）波 1 審查：AC1–AC9 全合規，Important 1 條 → 波內修掉 → 複看 Important 0
- 每位 dev 的 report「## 測試」都附紅綠紀錄；AC4／AC6 的守護型測試附突變探針
- 單波任務，波 1 的 L 檔審查即整枝評議（`review task skipped` 見 process）
## 自主裁定（待你複核）
1. 19:21 reviewer-a Important 1 波內修：`dk-task-new` 起第一對守望改呼叫 `dk-watch --ensure`，所有權補 `dk-task-new`、`05_task_new.bats` 給 backend-watch — 若錯代價：05／09／26 若依賴 task-new 直接寫 pid 會多一輪修測試（實際沒有轉紅）
2. 19:21 reviewer-a M1 併入同一個修復：`wake_watch` 加 `[ -f "$dir/.panes" ]` 條件 — 若錯代價：多一條測試的工
3. 19:38 park M2（`wake_watch` 在 `queue_leave` 之前）— 讀碼確認只在守望已死時多排最多約 16 秒 — 若錯代價：對調兩行的小修
4. 19:38 park M3（HUP 後下一輪提前跑）— 讀碼確認只多跑一輪輪詢 — 若錯代價：補一句註解
5. 19:38 park M4（36 用 GNU 專屬指令）— 實測 CI 三個 job 都是 ubuntu-latest — 若錯代價：macOS 開發機跑 36 會紅
6. 19:38 park M5（沒有 setsid 的平台守望留在員工行程群組）— brief 明文接受 setsid 選用；macOS 行為是推測、未實測 — 若錯代價：macOS 上守望隨員工 pane 關閉而死，等下一則訊息才回來
## 重要決策
- 17:49 本任務成員可改 `.dkbo/` 下劃給自己的腳本、規則檔、skill 與 BACKLOG.md
- 17:49 不升版，併入 CHANGELOG 0.16.0 節（0.16.0 還沒 push、沒打 tag）
- 17:49 shellcheck 做成 bats 測試（37_shellcheck，沒裝就 skip）而不是塞進 `tests/run.sh`
- 17:49 watch.log 放 `.sessions/`（不放 `.blocked/`，結案不會被刪）
- 17:49 計畫審查只派 claude（codex、agy 熔斷中）
- 17:56 AC5 HUP 記一行後繼續跑、INT／TERM 才結束
- 17:56 AC5 加 `--ensure` 的 flock 串行化
- 17:56 backend-test 完成條件不含全套綠，helpers 回歸由 backend-docs 的完整實跑把關
- 18:46 backend-watch 難度 M → L
- 19:21–19:38 自主裁定六條（見上）
- 19:29 波 1 審查通過，CHANGELOG 條數由 backend-docs 補、不另送審
## 給下次的話（≤3 行）
- 計畫時列「會起守望的地方」要掃全倉 `grep -n 'dk-watch' .dkbo/bin/*`，這次漏了 `dk-task-new`，靠 reviewer 抓到
- 合併後第一個任務留意 watch.log 與 `watch died`：守望死因至今仍未確認，這次只是讓它留遺言
- dk-msg 內文上限 200 字元，給員工的修復指令把細節寫進 brief、訊息只指路
## 時間
任務 2026-09-24-rest
| 階段 | 開始 | 結束 | 時長 | dev | 審查 |
|---|---|---|---|---|---|
| 任務 | 2026-09-24T17:46 | 2026-09-24T20:14 | 148m | — | — |
| 計畫 | 2026-09-24T17:46 | 2026-09-24T18:46 | 60m | — | — |
| 波 1 | 2026-09-24T18:47 | 2026-09-24T19:37 | 50m | 46m | 16m |
| 結案 | 2026-09-24T19:37 | 2026-09-24T20:14 | 37m | — | — |
