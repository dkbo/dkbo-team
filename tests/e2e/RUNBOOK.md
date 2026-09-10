# 端對端示範（層 4，人工一次）

前置：在 herdr 內、`example/` 已 `git init` 並 commit、從 repo 根目錄執行 `cp -r .dkbo example/.dkbo && cd example && .dkbo/install.sh`。開 Claude Code（S 檔即可：`claude --model sonnet --effort low`）。

1. 對領導說：「開任務 login，顯示名『使用者登入』。需求：POST /login 接 JSON {user,pass}，空密碼回 400，正確回 200；web.js 的 renderLogin 產出含 user/pass 欄位的表單；qa 寫測試驗證兩者。」
2. 預期：領導執行 dk-task-new，寫 brief（所有權：backend=src/api.js，frontend=src/web.js，qa=test/**；波次表 wave1 backend(M)+qa(S)，wave2 frontend(S)+qa(S)），問你確認（關卡①）。回「OK」。
3. 預期：領導 `dk-task-new login --gate1`，`dk-spawn backend`、`dk-spawn qa`，然後閒置。切到 worktree workspace 觀察兩個 pane。切到 tab 1 觀察：領導佔左欄、backend 與 qa 在右側上下兩格。
4. 故意製造一次 BUG 迴圈：在 qa 的 state 出現前對 qa pane 說「空密碼要回 400，請嚴格驗」。看 messages.log 出現 `[BUG]` → `[FIXED]`。
5. 若 qa 第二次仍失敗會 `[ESCALATE]` 給領導；領導應在 pane 裡問你（關卡②）。回一個決策，看 `[DECISION]` 進 log、decisions.md 多一行。
6. 兩人 DONE 後：領導 `dk-review-pack 1`、`dk-review`；reviewer DONE 後領導記 verdict 與 ruling，才 `dk-wave-close` 並 commit `wave 1: ...`。檢查 process.md 有 `review 1 spawned`、`review 1 verdict`、`ruling:`、`wave-close 1 tests`。
7. 在領導 pane 執行 `/clear`，再說「執行 .dkbo/bin/dk-resume 然後繼續」。預期：領導讀回恢復包，正確開 wave2（frontend + qa）。
8. wave2 DONE、wave-close 後，領導寫 report.md 給你看（關卡③）。回「合併」。預期 `dk-task-close` 合併回 main、worktree 移除、INDEX 為 done。
9. 雜務：對領導說「請翻譯 README.md 成英文」。預期領導發現沒有 translator 角色 → 跑 add-role → `dk-chore translator "..."`；完成後 INDEX 多一行 chore。
10. 逾時與熔斷：在 wave2 用一個未登入（或已到用量上限）的 kind 當 reviewer（`settings.env` 的 `DK_REVIEW_KINDS` 加上它，或 brief 審查欄 `kinds: claude <那個 kind>`），`DK_REVIEW_TIMEOUT_MIN` 先調成 2。預期：約 2 分鐘後領導 pane 收到 `[TIMEOUT] from dk-watch: … 逾時 (quota?)`、桌面通知一次、`.task.env` 的 `DK_KIND_DOWN` 出現該 kind、process 有 `timeout … → kind <k> down`；領導 `dk-wave-close --agent <reviewer>` 後 tab 版面重新均分。把該 CLI 實際印出的用量訊息字樣抄一行進 `.dkbo/README.md` 疑難排解表。
11. 記錄：把每步實際發生與預期的差異寫到 `tests/e2e/RESULTS-<日期>.md`。

驗收：process.md 有 task-new / gate1 / wave1 / escalate / wave-close / wave2 / task-close 各一行以上；messages.log 有 BUG、FIXED、ESCALATE、DECISION、DONE；report.md 存在；`git log` 有兩個 wave commit 與一個 merge commit；dk-resume 輸出 ≤150 行。process.md 另有 wave-open / review … spawned / review … verdict / ruling: / wave-close … tests / timeout 各一行以上；每位 dev 有 state/<成員>.report.md。
