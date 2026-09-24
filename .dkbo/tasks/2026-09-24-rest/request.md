# BACKLOG 剩餘六條（測試與守望） — 需求原文

把人講的原話**逐字**抄在下面。不要摘要、不要改寫、不要先做技術轉換 ——
brief 才是轉換的產物，這一份是用來比對「brief 有沒有漏掉人要的東西」的基準。
外部文件（spec、issue、對話紀錄）請把相關段落整段貼進來，不要只留連結：
連結會死，而這個檔案要活到任務歸檔之後還有人讀得懂。

---

（原文從這裡開始）

## 人的原話（2026-09-24，逐字）

1. 「review backlog 事實上還剩下那些沒處理」
2. 「繼續看還有哪些 bklog 沒有處理」
3. 領導列出剩 10 條、建議「現在就能動手的是第 1–5 條和第 8 條，都集中在測試和守望，可以開一個任務一起處理」後，人回：「6條規畫先進行~~都處理完才會 push」

## 領導當時列給人的六條（人回「6條規畫先進行」所指的範圍，逐字）

**測試可信度**
1. `HERDR_*` 仍會傳給專案測試：gate c 只拿掉 `DK_*`。
2. `tests/run.sh` 還是不跑 shellcheck。
3. `setup_project` 會把主樹裡未追蹤的任務資料夾和還沒 commit 的 INDEX、decisions 帶進測試夾具。
4. `dk-chore-close` 裡「空 branch 當成 `-`」那段沒有測試：現有的 legacy 測試用的舊範本本來就有 `branch:` 那一行。

**守望與執行期**
5. 守望程序死了沒人發現：沒有 `setsid`、沒有日誌、沒有人去檢查它還活著。

**brief 工具**
8. **新記的**：`lib/ownership.sh:12` 的 `dk_owned` 和 `dk-spawn` 的 `first_glob` 還是用裸 `awk -F'|'` 切可改欄。這是第 5 條（`dk-wave-open`）同類問題的剩餘部分。

（「都處理完才會 push」：本任務結案前不 push；本機 master 目前比 origin 多 bklog 的 5 個 commit，一併等本任務結案後由人決定。）

## 外部文件：`.dkbo/tasks/BACKLOG.md` 對應的 6 列（810b931，逐字）

| 2026-09-12 | 0.5.0 最終審查 | 記錄檔遺失時把空 branch 正規化成 `-` 的那道守衛沒有測試守著，改壞了出口 4 會悄悄回來 | 補一條測試，下次動 `dk-chore-close` 時一起 |
| 2026-09-19 | highfix 波 1 疑慮 | `dk-wave-close` gate c 的 `env -u` 只剝 `DK_*`，`HERDR_*`（`HERDR_PANE_ID`、`HERDR_ENV` 等）照樣傳給 `DK_TEST_CMD`；專案測試若讀 `HERDR_*` 同類問題還在 | 契約目前只寫 `DK_*`；若要擴到 `HERDR_*` 先確認 dkbo 自己的測試（`tests/stub/herdr`）不依賴繼承的 `HERDR_*` |
| 2026-09-19 | watchtime 波 1 疑慮 | `tests/run.sh` 只 `exec bats`，沒有任何一處跑 shellcheck；每個任務的「shellcheck 零警告」都是員工手動跑的，漏跑沒人吭聲。領導的 PROJECT.md 之前還寫錯說 run.sh 會跑（已改） | 把 shellcheck 併進 `tests/run.sh`（有裝才跑、沒裝印 WARN 不擋），或加一條 bats 測試呼叫它 |
| 2026-09-24 | testtrust 波 1 審查（reviewer-a Minor 4） | `setup_project`（`tests/helpers.bash:14` 的 `cp -r "$REPO_ROOT/.dkbo"`）清掉了 `.sessions/`，但仍把主樹**未追蹤**的進行中任務資料夾（含 `.panes`、`.task.env`）與未 commit 的 `tasks/INDEX.md`、`decisions.md` 帶進夾具：任何列舉 `tasks/*/` 或讀 INDEX 的測試，結果取決於領導在主樹跑的那一刻開發機上有哪些任務 | 只複製追蹤中的檔（`git -C "$REPO_ROOT" ls-files .dkbo` 或 `git archive HEAD .dkbo`）能根治，但取捨是：員工在 worktree **未 commit** 的 `.dkbo/` 改動會進不了夾具，測的變成上一個 commit 而不是正在改的碼（`dk-wave-close` 才 commit）；折衷是複製後只清掉 `tasks/` 下未追蹤的任務資料夾、把 INDEX／decisions 還原成追蹤版，並補一條「髒主樹」測試（比照 `36_fixture` 的 `.sessions/` 那條） |
| 2026-09-24 | testtrust 波 1 實跑 | 守望程序死了沒人知道：`dk-watch` 與 `dk-watch --events`（`dk-watch:37,48` 以 `nohup … >/dev/null 2>&1 &` 起、無 `setsid`、無日誌）在 08:45 開波後某時靜默死亡，08:55 backend 的 `[DONE]` 沒有觸發 dev-done 聚合，領導 pane 也就沒被叫醒，任務空轉 53 分鐘，直到 09:48 手動 `dk-watch --ensure` 才接上，還連帶推了一則假的整波 `[TIMEOUT]`（60min）。`.task.env` 的 `DK_WATCH_PID`／`DK_EVENTS_PID` 在，但沒有任何東西去確認它們還活著。死因未確認（猜是啟動它的那次 Bash 工具呼叫結束時整個行程群組被收掉，未驗證） | 起法改 `setsid` 並把輸出導到 `.sessions/` 或任務目錄下的 watch.log，下次死掉至少有遺言；`dk-msg`（任何人送 `[DONE]` 時）、`dk-resume`、`dk-spawn` 順手 `kill -0` 兩個 pid，死了就 `--ensure` 重啟並記 process；釐清死因後再決定要不要更強的保活 |
| 2026-09-24 | bklog 波 2 審查 Minor 3 | `lib/ownership.sh:12` 的 `dk_owned` 與 `dk-spawn:57` 的 `first_glob` 仍用裸 `awk -F` 以管線字元切可改欄，可改欄含跳脫管線時會錯位 | 改用 `lib/brief.sh` 的 `DK__BRIEF_SPLIT` 切欄（同 0.16.0 `dk-wave-open`／`all_globs` 的改法） |
