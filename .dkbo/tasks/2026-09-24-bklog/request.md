# BACKLOG A–C 清理 — 需求原文

把人講的原話**逐字**抄在下面。不要摘要、不要改寫、不要先做技術轉換 ——
brief 才是轉換的產物，這一份是用來比對「brief 有沒有漏掉人要的東西」的基準。
外部文件（spec、issue、對話紀錄）請把相關段落整段貼進來，不要只留連結：
連結會死，而這個檔案要活到任務歸檔之後還有人讀得懂。

---

（原文從這裡開始）

## 人的原話（2026-09-24，逐字）

1. 「目前還有甚麼 backlog」
2. 「A-C 全部處理掉」
3. 對領導四題的回答（AskUserQuestion，逐字選項）：
   - 「#17：在 workspace A 計畫、之後從 workspace B 叫 /dkbo-run，任務 tab 要開在哪？」＝「開在你當下所在的 (Recommended)」——說明：--run 時以當下的 HERDR_WORKSPACE_ID 為準，並回寫 DK_WORKSPACE。你在哪裡叫 run，tab 就出現在眼前
   - 「#4：單一成員跨多波時，共用契約是「波 1 產出、波 3 消費」，現在的 schema 放不下。怎麼處理？」＝「允許擁有者／消費者填波次 (Recommended)」——說明：擁有者、消費者欄可以寫 `<成員>@波N`，dk-brief-check 照樣驗成員存在，不新增欄位
   - 「A–C 要怎麼切任務？」＝「一個任務、四位成員並行 (Recommended)」——說明：守望／訊息／brief 工具／文件四位，所有權各自集中。testtrust 合併後才交棒，因為兩者都動大量測試檔
   - 「testtrust 的關卡①…可以通過嗎？」＝「通過，先跑 testtrust (Recommended)」

更早一則（同一場對話）：「應該是確認額度耗盡，可以由 leader 寫進紀錄，之後可以避免再開才對」——即 BACKLOG A 類 #25 的來源。

## 領導當時列給人的 A–C 分組（人回「A-C 全部處理掉」所指的範圍，逐字）

A. 守望與訊息：#16 reviewer working 仍被逾時熔斷；#25 kinds-down 缺 `dk-kind down`；#10 dev／qa 沒有靜默逾時；#14 `dk-msg` 5 分鐘就放棄；#23 `[TASK]` 重派不重設 latch；#3 排隊的 `[TASK]` 在員工剛 `[DONE]` 時送達；#26 審查無法只補派一位
B. 員工規範與文件：#20 `$DK_ROOT` 當編輯路徑；#21 共用 worktree `git stash` 取紅；#24 `minor task:` 不警告；#9 state 20 行與 touched 衝突；#2 PROTOCOL `[DONE]` 句重複；#12 README 沒提 tab 不自動關
C. 計畫與 brief 工具：#15 無主測試檔 WARN；#5 `dk-wave-open` 裸 `awk -F'|'`；#4 契約表沒有「波」；#17 `DK_WORKSPACE` 語意

## 外部文件：`.dkbo/tasks/BACKLOG.md` 對應的 17 列（6aa3eca，逐字）

| 2026-09-22 | tasktab 整枝評議 | `dk-watch` 的 reviewer 逾時路徑只在**決定要不要看畫面貼 `(quota?)` 標籤**時問 `agent_status`，判「要不要熔斷」時完全不問。所以一個 `agent_status=working`、正在正常寫 report 的 reviewer，只要超過 `DK_REVIEW_TIMEOUT_MIN` 就照樣被 `[TIMEOUT]` 並熔斷它的 kind。實測發生：`tasktab-reviewer-a`（claude L 檔，讀整枝 `task.diff`）在 22:50 被判逾時，當下 state 是 `status: working / current: 寫 report`、notes 已列出 Important 4 條，herdr 回報 working、usage 5h:40%。因為 codex 與 agy 先前已熔斷，這一下讓**三個 kind 全倒**，領導得手動解熔斷才能繼續 | 逾時熔斷比照額度偵測加同一道 `agent_status != working` 前提（AC2 那條註解已經寫了這個道理，只套在畫面檢查上、沒套在熔斷上）；或至少 working 時只推 `[TIMEOUT]` 提醒領導、不寫 `DK_KIND_DOWN`。另：L 檔整枝評議讀 task.diff 本來就會超過 20 分鐘，`DK_REVIEW_TIMEOUT_MIN` 對 `--tier L` 應該有獨立（較長）的門檻 |
| 2026-09-24 | testtrust 計畫審查 | 專案層熔斷（`.sessions/kinds-down`）只有一個寫入者：`dk-watch` 在某個 pane **當場**撞額度時寫。從其他來源確認的耗盡（CLI 狀態列、前一個任務的 ruling、人告知）沒有任何路徑寫進去 —— ops 07:53 的 ruling 已寫明「codex 要到 Oct 11 才恢復」，但 0.12.0 做出 kinds-down 後沒人補登，testtrust 的計畫審查照樣派了 codex 與 agy、各白燒一個 pane 才重新撞出來。讀取端（`dk_review_kinds` 跳過、`dk-spawn --kind` 拒絕）早就在，缺的只是寫入端 | 高：`dk-kind down <k> [--until <YYYY-MM-DDTHH:MM>] [--note <證據>]` 經 `dk_kinds_down_set` 寫一列（給 `--until` 標 exact，沒給走 +5h guess），process 記 `kind <k> down (leader)`；LEADER.md 的裁定段或 plan／run SKILL 補一句「任何來源確認某 kind 額度耗盡，當下 `dk-kind down`，不能只寫在 ruling 裡」，並在派 reviewer 前先 `dk-kind` |
| 2026-09-19 | watchtime 整枝審查 | `dk-watch` 只有 reviewer 有逾時路徑（第二個 while 只收 `*-reviewer-*`），qa／dev 卡住或靜默時，在整波 `DK_WAVE_TIMEOUT_MIN` 之前沒有任何出口，領導看到的是「這個人怎麼都不動」而不是「它卡了」。Important 1（done 判定沒比對 .redispatch）之所以在 dev 身上比 reviewer 深，就是因為沒有這條兜底 | 評估給 dev／qa 一條以 `.panes` epoch 為基準的靜默逾時（門檻可比 reviewer 長、不熔斷 kind、只推 `[TIMEOUT]`），或至少讓 `dk-resume` 的「等了 N min」超過門檻時標出來 |
| 2026-09-20 | multirepo 實跑 | `dk-msg` 對 working 中的員工預設只等 5 分鐘（`DK_MSG_WAIT_MS`）就放棄並標 `[UNDELIVERED]`；本任務三則 `[DECISION]`／`[TASK]` 都是這樣送不到，領導得背景重送並拉長等待 | 評估把預設拉到 15 分鐘，或讓 `dk-msg` 在逾時後自己排隊重試而不是放棄；另：dev 送出 ESCALATE 後照協定繼續做別的事，所以「等它閒置」本來就等不到 |
| 2026-09-23 | ops 整枝評議第一輪疑慮 | dev 交付 latch（`.blocked/wave-N.<sname>.done`）在 `[TASK]` 重派時不重設，任何「dev 交付後又被派重做」都不會再推聚合，領導只能靠 dev 回 `[FIXED]` 才醒；0.12.0 已把這個做法寫進 run/SKILL.md，但仍是靠人記得 | 評估讓 dk-msg 在領導對已交付 dev 送 `[TASK]`／`[BUG]` 時清該成員 latch 並刪 devdone（與 AC17 的 spawn 規則對稱） |
| 2026-09-19 | flowgap 實跑 | `dk-msg` 的「等對方閒置才送」語意，讓工作期間排入的 `[TASK]` **必然**在員工剛送出 `[DONE]` 的瞬間才送達：一個已完成的員工被重新喚醒，epoch 被重設、state cksum 被存下，於是 dk-watch 從此把它算成「這一輪還沒交」 | 要嘛 `dk-msg` 對 state 已 `status: done` 的收件者改送前警示（像 `[DONE]` 那道 exit 2 的反向閘），要嘛在 `dk-spawn` 前就把補充資訊寫進切片。先記著，下次動 dk-msg 時一起看 |
| 2026-09-24 | testtrust 計畫審查 | `dk-brief-review`（與 `dk-review`）沒辦法只補派一位失敗的 reviewer：別名由 `dk_review_aliases` 依 kind 數從 p1 起配，`--kinds codex` 重跑會命名成 p1，而 `dk-spawn` 會先關掉同名舊 pane，等於殺掉正在跑的 claude p1。實際繞法是手動 `dk-spawn reviewer p2 --isolated --kind codex --tier L` 再手補一行完整的 `brief-review spawned …`（`--gate1` 只讀最後一行） | 加 `--alias <pN>`（或自動跳過 `.panes` 裡已在的別名），並讓補派把 spawned 行累加成完整名單 |
| 2026-09-23 | ops 波 1 ESCALATE | 員工 pane 的 `DK_ROOT` 指向主樹 `.dkbo`；S 檔員工拿 `$DK_ROOT/…` 當編輯路徑，把 10 個檔全寫進主樹，自己在 worktree 看不到就誤報「worktree 被 reset」。只有「改的正是 `.dkbo/`」的任務（dkbo 原始碼倉 dogfood）會中 | 切片範本在「## 倉庫」段加一句「編輯一律用上面的 worktree 路徑；`$DK_ROOT` 只拿來跑 bin」；或 dk-wave-close 前檢查主樹是否出現本波成員所有權內的改動 |
| 2026-09-23 | ops 波 4 人旁觀 | 員工在**共用 worktree** 用 `git stash push -- <檔>` 暫退修法取紅，stash 期間同波夥伴並跑 `tests/run.sh` 讀到舊碼而假紅（34_kind_down:58 兩次，被當成 flaky）；stash 堆疊還跨 worktree 與主樹共用，裸 `git stash pop` 可能 pop 到別人的 | PROTOCOL 的 report 段與 `templates/report-employee.md` 寫明取紅一律 cp 到獨立目錄（`git archive <base>` 或複製 worktree），不在共用 worktree 動 stash／checkout |
| 2026-09-23 | ops 整枝評議 | 領導記 Minor 時寫成 `minor task: …`，不合 `DK_MINOR_RE`（只認 `minor: ` 或 `minor <數字>: `），dk-process 照收不警告，整枝評議的累積 Minor 表會靜默漏掉 | `dk-process` 對以 `minor` 開頭但不合 `DK_MINOR_RE` 的行印警告；或把正規式放寬成 `minor( [^:]+)?: ` |
| 2026-09-19 | watchtime 波 1 疑慮 | PROTOCOL 的 state ≤20 行與 gate d 要求 `touched` 完整互相衝突：一波動 24 個檔的成員寫不進 20 行 | 把行數上限改成「`touched` 以外 ≤20 行」，或讓 `touched` 允許用 glob 收攏 |
| 2026-09-12 | 0.5.0 最終審查 | `PROTOCOL.md:60-63` 的 `dk-msg leader "[DONE] …"` 在同一段出現兩次 | 延後，下次動 PROTOCOL 時一起收 |
| 2026-09-20 | multirepo 結案（2026-09-24 改寫） | `README.md`／`README.en.md` 指令一覽的 `dk-task-close` 列沒提「任務 tab 不自動關」（0.11.0 起任務開的是 tab 不是 workspace；`dk-task-close` 最後一行會印 `herdr tab close <id>`） | 下次動 README 時補一句 |
| 2026-09-20 | multirepo 實跑 | 無主測試檔升報三次（`30_isolation`、`23_leader_kind` ×2）：改既有腳本行為時，斷言舊行為的測試檔沒被劃進所有權，員工只能 ESCALATE | 給 `dk-brief-check` 加一條 WARN：可改欄列出的 `.dkbo/bin/*`、`.dkbo/lib/*` 若被 `tests/unit/*.bats` 引用（grep 檔名）而該 bats 不在任何人的可改欄，列出來提醒領導 |
| 2026-09-19 | flowgap 波 1 | `dk__brief_rows` 修成跳脫感知後，回傳值刻意保留 `\|`，但下游不是每個消費者都跳脫感知 —— `dk-wave-open:27` 仍用裸 `awk -F'|'` 取 $1..$7 重組切片的波次表列，波次表「做什麼」欄寫 `a\|b` 會靜默少一欄。所有權表與波次表也還沒有欄數閘門 | 非退步（修復前同樣會錯），但現在契約寫明「保留跳脫」之後，下游不一致就變成明確的債。下次動 dk-wave-open 或 brief 閘門時一起收 |
| 2026-09-19 | flowgap 實跑 | 共用契約表的「擁有者／消費者」依 AC3 必須是成員短名，但單一成員跨多波的任務，契約跨的是**波**不是人 —— schema 沒有地方放「波 1 產出、波 3 消費」，只能把波次塞進契約名的括號裡 | 評估加一個選填的「波」欄，或允許那兩欄填 `波 N`；先觀察第二個這種形狀的任務再決定，不要為一個案例改 schema |
| 2026-09-22 | tasktab 整枝評議 Important 4 | `DK_WORKSPACE` 是 `dk-task-new`（＝計畫那一刻）寫死的 `HERDR_WORKSPACE_ID`，`dk-leader --run` 不刷新它。人在 workspace A 計畫、幾天後從 workspace B 叫 `/dkbo-run`，任務 tab 會開在 A，人眼前的 B 什麼都不會出現。0.11.0 的 AC1 逐字指定 `--workspace "$DK_WORKSPACE"`，所以本任務只改文案不改行為 | 決定語意：`--run` 時 `HERDR_WORKSPACE_ID` 與 `.task.env` 的 `DK_WORKSPACE` 不同，tab 該開在哪？目前沒有任何一份文件回答。若答案是「開在人當下所在的」，`dk-leader` 要改成以 `HERDR_WORKSPACE_ID` 優先並回寫 `DK_WORKSPACE` |
