# dk-status --json（dashboard 資料出口） 結案
結果：merged（待關卡③）   分支：dk/status   波數：1（含一輪波內 Minor 修復）
## 完成
- AC1 新唯讀指令 `.dkbo/bin/dk-status`：`--json` 印 list、`--json <資料夾名|短名>` 印 detail（短名取日期最晚）；stdout 單行 JSON；用法錯 exit 2、找不到任務 exit 1，文案逐字；herdr 外照樣成功
- AC2 list：`schema_version`（1）、`dkbo_version`、`generated_at`、`kinds_down`（只列未過期，本地時間＋`until_epoch`）、`tasks`（任務摘要，依資料夾名升冪，不含 `_chores`）
- AC3 detail：任務摘要＋`repos`、`brief`、`waves`、`members`、`panes`、`rulings`、`events`、`messages`、`skipped_lines`
- AC4 欄位來源：status 取 INDEX、波時間戳與 dk-timeline 同規則、「波關閉 ⟺ `wave-close N tests … K agents closed`」、`[自主]` 標 `autonomous`、members 依檔名（含 `.md`，碼點序）升冪
- AC5 容錯：缺檔給 null／`[]`，壞行略過並計 `skipped_lines`；檔尾沒換行不黏行（dev 自己抓到、38 第 15 條守）
- AC6 JSON 安全：原文一律經 `jq -R` 讀入，`"`、`\`、tab、`$(...)`、中文、emoji 逐字取回
- AC7 唯讀：不寫任何檔、不呼叫 herdr、不看 session 綁定；38 以 `find -newer`、檔案清單、herdr stub log 驗
- AC8 新檔 `.dkbo/status-schema.md`：每個鍵的型別／可否 null／來源／說明、相容規則（只加欄位不升版）、until 時區、續行計 skipped、閘門事件 `wave-close`／`violation`／`unreported`／`review`；38 反向防漂移（輸出的所有鍵名都在文件裡）
- AC9 新檔 `tests/unit/38_status.bats` 16 條，含「list 不逐行叫 jq」的計數測試（對任務數線性、與行數無關）
- AC10 三份 README 指令表加 `dk-status`、`.dkbo/README.md` 新段「給 dashboard 讀的 JSON」；升版 0.17.0（VERSION、八處版號、CHANGELOG 新節，測試行 `772 bats（+16）`）；21_version 首節清單換成 0.17.0
- AC11 `tests/run.sh` 772/772 全綠（35_test_hygiene、37_shellcheck 實跑、38_status）
## 未完成 / 遺留
- 沒有未經審查的波
- 整枝評議 triage 後不修的 Minor：
  - M3 `.dkbo/bin/dk-status:56` 第 1 欄不是合法 `YYYY-MM-DDTHH:MM` 的 process 行，dk-status 略過並計 skipped，`dk-timeline` 仍會取（只在人手改壞 process.md 時出現；AC5 明訂這樣做）
- jq 1.5／1.6 沒實測：本機只有 jq 1.7；reviewer 逐項對過用到的語法（`splits`、具名 `capture`、`inputs`、`def f($x)`），沒找到不相容點，但沒有測試守
- 本任務的 `dk-status` 在本任務內沒有被流程用到：領導跑的是主樹腳本。合併後才能對真實任務記憶跑（reviewer 已用 worktree 腳本唯讀讀過主樹 11 個任務，rc 全 0、欄位與 INDEX／process 對得上）
- dashboard 本身（獨立 repo `dkbo-team-dashboard`）不在本任務範圍
- 不 push：由人決定
## 驗證
- `dk-wave-close` 在 worktree 實跑 `tests/run.sh`：772 條全 ok（`wave-close 1 tests ok`），shellcheck 零警告
- reviewer-a（claude L）波 1 審查：AC1–AC11 全合規，Important 0、Minor 3 → Minor 1、2 波內修 → 複看 Important 0，reviewer 自己在 worktree 實跑全套 772/772
- 兩位 dev 的 report「## 測試」都附紅綠紀錄
- 單波任務，波 1 的 L 檔審查（含複看）即整枝評議（`review task skipped` 見 process）
## 自主裁定（待你複核）
1. 10:12 單波任務，Minor 1（members 排序與 AC4「依檔名升冪」字面不符，實測 `qa.md`／`qa-b.md` 順序相反）與 Minor 2（38 夾具含 `$(rm -rf /)`、原斷言沒驗到東西）不開新波，趁波 1 未關由 backend-status 就地修，reviewer-a 複看即整枝評議 — 若錯代價：修出回歸，由複看與 wave-close 全套測試擋下（實際 772/772 綠）
2. 10:12 park Minor 3（非法時間戳行 dk-status 略過、dk-timeline 仍取）— 實測：機器寫的行一律 `dk_now` 格式，只有人手改壞才出現；AC5 明訂略過並計 skipped — 若錯代價：dashboard 與 dk-timeline 對手改過的 process 差一筆，改成一致只動一行
## 重要決策
- 09:13 本任務成員可改 `.dkbo/` 下劃給自己的檔（PROTOCOL「不改 .dkbo/」在本任務不適用）
- 09:13 升版 0.17.0（0.16.0 已在 origin/master，不能併入舊節）；21_version 首節清單整份換成 0.17.0
- 09:13 dk-status 不呼叫 herdr、不寫檔、不綁 session；即時狀態由 dashboard 自己訂 herdr events
- 09:13 計畫審查只派 claude（codex 熔斷至 10/11、agy 至 9/30）
- 09:20 所有權對照實際 diff 列入「不做」，dashboard 用 `brief.owners`＋`members[].touched` 呈現自報版
- 09:20 波關閉 ⟺ `wave-close N tests … K agents closed`；`tests` 存原文另給 `tests_ok`，`commits` 為帶 repo 的陣列
- 09:20 測試增量基準 756
- 10:30 波 1 審查通過、放行 wave-close
## 給下次的話（≤3 行）
- dashboard repo 開工前先讀 `.dkbo/status-schema.md`，只認 `schema_version` 1，遇到不認識的欄位忽略
- 交接波（docs 等 dev 的條數）必然觸發 docs 的閒置逾時與整波逾時，是預期內的；修復輪加測試時條數要跟著改，brief 已寫好轉送流程，這次運作正常
## 時間
任務 2026-09-25-status
| 階段 | 開始 | 結束 | 時長 | dev | 審查 |
|---|---|---|---|---|---|
| 任務 | 2026-09-25T09:10 | 2026-09-25T13:45 | 275m（進行中） | — | — |
| 計畫 | 2026-09-25T09:10 | 2026-09-25T09:22 | 12m | — | — |
| 波 1 | 2026-09-25T09:29 | 2026-09-25T10:39 | 70m | 52m | 31m |
| 結案 | 2026-09-25T10:39 | — | — | — | — |
