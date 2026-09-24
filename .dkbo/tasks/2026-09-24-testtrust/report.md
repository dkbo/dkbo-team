# 測試可信度 結案
結果：merged d887626   分支：dk/testtrust   波數：2（波 1 實作、波 2 審查 Minor 修復）
## 完成
- AC1／AC2：`tests/` 的 76 處（74 行）`!` 開頭否定斷言全數換成 `refute_grep` 或新增的 `refute`；其中 **48 處原本失效**（`set -e` 豁免 `!` 述句，不是測試最後一條時命中也照綠），26 處是測試最後一條、2 處已帶 `|| …false`。與 request.md 的 50 差 2：`24_portability:22`、`25_docs_policy:10` 在 `for` 內但已帶 `|| { …; false; }`，實際有效。reviewer-a 以機械比對驗過 74/74 行只動否定前綴。轉換後沒有任何一條變紅——沒有被遮住的真缺陷。
- AC3：`tests/unit/35_test_hygiene.bats` 守門，掃描器 `bang_scan` 掃 `git ls-files`（多帶 `--others --exclude-standard` 讓未 commit 的 35／36 也被掃），兩向自我驗證樣本都在執行期寫臨時檔。
- AC4／AC5：`fixture_task()` 改在子 shell source `lib/common.sh` 呼叫真的 `dk_render` 套 `templates/task.env`；新增 `fixture_env_check`，缺鍵或殘留 `{{` 就把名字印到 stderr 並回非零。順手修掉既有的迴圈變數 `e` 外洩到呼叫端（新測試抓到）。
- AC9：`setup_project()` 複製後清掉 `$DK_ROOT/.sessions/` 裡 `.gitkeep` 以外的檔；主樹不動。
- AC6：BACKLOG 刪了 L29（否定斷言）、L30（fixture 漂移）兩列；波 2 另加一列（reviewer-a 波 1 Minor 4）。
- AC7：CHANGELOG 0.15.0 節加 `test:` 條目，「測試：」改成 656（相對 0.14.0 +18，其中本任務 +14：35 共 5 條、36 共 9 條）。不升版。
- AC10（波 2，自主裁定加的）：35 的分隔符後允許零空白、補 `{`／`(`／`|`／`else`；自檢只要含 `{{` 就報（含半截 `{{FOO`、`{{FOO}`）；36 的鍵集合測試另擋非 `DK_` 雜行。新規則對既有 tests 0 處。
## 未完成 / 遺留
- 沒有未經審查的波（波 1、波 2 都經 reviewer-a claude L 檔審查）。審查全程只有 claude 一個 kind：codex（至 2026-10-11）、agy（至 2026-09-30）額度耗盡，同模型盲點沒有第二視角。
- 不修的 Minor（前提皆實測）：35 的 `(` 分隔符會多報 `(( ! x ))` 與 `f() { ! grep; }`（現 0 處）`tests/unit/35_test_hygiene.bats:11`；36 沒測 `{{FOO}` 形狀（reviewer 直接呼叫驗過回 1）`tests/unit/36_fixture.bats:44`；同行混合佔位符只印名字不印整行（rc 仍 1）`tests/helpers.bash:133`；`echo "a;! b"`（引號內）會被 35 誤判（逐行 grep 分不出引號，誤判方向是多報）。
- 已記 BACKLOG：`setup_project` 仍把主樹未追蹤的進行中任務資料夾與未 commit 的 `tasks/INDEX.md`、`decisions.md` 帶進夾具（AC9 範圍外，根治要在「只複製追蹤檔」與「worktree 未 commit 的 `.dkbo/` 改動進不了夾具」之間取捨）。
- 執行期故障（未查明、未記 BACKLOG）：08:44 啟動的 watch／events 兩個守望程序在 08:55 前後已死，backend 的 `[DONE]` 沒被推送，空等到 09:48 才靠人詢問發現、`dk-watch --ensure` 重啟；守望輸出導 `/dev/null`，無日誌可查死因。重啟後全程正常。
## 驗證
- wave-close 1、2 都在 worktree 跑 `tests/run.sh` 全綠（波 2 後 656 條）；檔案所有權閘通過。
- 取紅（backend report）：35 對 base 列出 74 行 76 處；36 對舊 heredoc fixture 7 條紅 5 條（AC8(b)：舊版會紅，因為 heredoc 不讀模板）；AC8(c) 副本把套模板換成空檔 → `06_msg`（`>/dev/null` 形狀）與 `09_watch`（`d=$(…)` 形狀）111 條 setup 全紅、stderr 列出全部缺鍵；AC9 主樹副本（kinds-down 有未過期 agy、codex）修前 `10_resume` 紅 2 條（AC6/Minor、AC18/Minor）、修後 16 條全綠；AC10 新樣本在 `b169571` 版全部漏判。
- reviewer-a 獨立重現 AC8(a)、AC8(c) 與 AC2 分類（有效 26+2／失效 48）。
## 自主裁定（待你複核）
1. 06:52 計畫審查 p2(codex) 真撞額度，關掉改派 agy 當 p3 補第二視角 — 若錯代價：agy 也耗盡則只採 claude 單一 kind 進關卡①（後來確實如此）
2. 09:57 波 1 Minor 1–3 開修復波 2（M）一次收掉，Minor 4 記 BACKLOG — 若錯代價：多一波（實際 12 分）；覺得 Minor 不必修就 revert `5476c6c` 回到波 1 狀態
3. 09:57 brief 新增 AC10 與波 2 列 — 若錯代價：AC10 措辭與你預期不符，改寫
4. 10:09 波 2 Minor 3 條不修、不記 BACKLOG（前提實測）— 若錯代價：將來寫到 `(( ! x ))` 被 35 擋一次要改寫
## 重要決策
- 06:51 本任務成員可改 `.dkbo/tasks/BACKLOG.md`（僅此一檔不適用「不改 .dkbo/」停止條件）
- 06:51 不升版，併入 CHANGELOG 0.15.0 節
- 06:56 非 grep 的否定斷言一律用新增的 `refute` helper，不准用 `run` 取代
- 06:56 `fixture_task` 在子 shell source common.sh 呼叫真的 `dk_render`，不另寫替換邏輯
- 06:56 計畫審查只採 claude 單一 kind 進關卡①（codex、agy 先後真撞額度）
- 08:01 關卡①前把 AC9（`setup_project` 不帶主樹 `.sessions/`）併進本任務
- 09:54 波 1 審查通過（Important 0，AC2 機械比對 74/74）
- 10:07 波 2 審查通過；`echo "a;! b"` 誤判接受
- 加上「自主裁定」段的 4 條
## 給下次的話（≤3 行）
守望程序會無聲死掉：交件後 10 分鐘內沒收到聚合推送，就查 `DK_WATCH_PID`／`DK_EVENTS_PID` 是否還活著，別乾等。
35 守門上線後，新測試寫否定只能用 `refute_grep`／`refute`；`(( ! x ))` 也會被擋，改寫成 `(( x == 0 ))`。
## 時間
任務 2026-09-24-testtrust
| 階段 | 開始 | 結束 | 時長 | dev | 審查 |
|---|---|---|---|---|---|
| 任務 | 2026-09-24T06:49 | 2026-09-24T14:22 | 453m | — | — |
| 計畫 | 2026-09-24T06:49 | 2026-09-24T08:04 | 75m | — | — |
| 波 1 | 2026-09-24T08:44 | 2026-09-24T09:57 | 73m | 64m | 6m |
| 波 2 | 2026-09-24T09:57 | 2026-09-24T10:09 | 12m | 7m | 3m |
| 結案 | 2026-09-24T10:09 | 2026-09-24T14:22 | 253m | — | — |
