# Changelog

## 0.5.1 — 2026-09-12
- fix(chore): 完成訊號綁上這件雜務的生命期。記錄檔多一欄 `logline=`（建立當下 `_chores/messages.log` 的行數），`dk-chore-close` 只看那之後的行。0.5.0 的撞號守衛擋的是「記錄檔還在就拒絕同名」，但有一條路徑繞過它：一件雜務正常跑完關閉後記錄檔就刪了，而它的 `[DONE]` 永遠留在 append-only 的 `messages.log` 裡；等有人整理逐漸變大的 `_chores/*.md`（agent 編號正是 `count(_chores/*.md) + 1` 算出來的），編號重算回同一個數字，新雜務的記錄檔是乾淨的、守衛不會觸發，而閘門會撿到上一輪的 `[DONE]` 立刻放行 —— `--code` 的話等於合併一個員工從沒回報過的分支。`messages.log` 只增不減、`_chores/*.md` 是人會去清的那一個，所以這不是「會不會」而是「什麼時候」。順帶讓閘門對任何陳舊 `[DONE]` 免疫，不只這個情境。
- fix(chore): `dk-chore-close` 在讀取端也驗 agent 名。`dk-chore` 早就有 `[[ "$agent" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]`，但那是**寫入端**；操作者打的字是從 `dk-chore-close <agent>` 進系統的，而 `$agent` 會組成 `rm -f` 的路徑、也會被內插進 `sed` program。同一條規則在讀取端再擋一次。
- fix(chore): `rollback()` 補上雜務檔與記錄檔。它的契約是「還沒有人進去過就清乾淨」，但先前只清 worktree 與分支；`--code` 雜務在 trap 掛上之後、`herdr agent start` 之前若被 Ctrl+C 或磁碟出事，`$cf` 與 `$crec` 會留下來 —— 而 0.5.0 之後「記錄檔存在 ⟺ 雜務在跑」，一個孤兒記錄檔會讓 `dk-watch --chores` 永遠不退出，且那時 `dk_index_add` 還沒跑，INDEX 裡看不到它。
- 這三條都是 0.5.0 最終審查延後、實跑前重新評估後決定收掉的；其餘延後項維持延後。
- 測試：256 bats（+3）；shellcheck 零警告。

## 0.5.0 — 2026-09-12
- fix(chore): 雜務檔不再一檔兩主。實跑收尾發現兩件事——`dk-chore-close chore-it-19` 回 `no chore file for chore-it-19`（員工把雜務檔整份重寫成自己的報告格式，`成員：`／`branch:`／`pane:` 全沒了）；人工補回欄位關掉之後，`tasks/INDEX.md` 那列仍停在 `working`，而 `dk-chore-close` 回了 0。查下來是**同一個結構缺陷的兩個出口**：雜務檔同時裝著系統的識別碼（`成員：` `branch:` `workspace:` `pane:` `leader:`）與員工的進度（`status:` `touched:` `結果：`），而 `dk-chore` 的第一段提示與 `PROTOCOL.md:60` 正是叫員工去寫那個檔案的。員工要「更新」一個檔案，最自然的動作就是重寫整份。對照組是任務那側：`dk-spawn` 把 agent→pane 寫進 `.panes`，員工從不碰它——**雜務沒有 `.panes` 的對應物**。
- 另外三個出口當時沒被觸發：(1) `dk-watch --chores` 同樣從雜務檔 `sed` 出 `成員：` 與 `leader:`，員工重寫後那件雜務靜默地從 blocked 名單消失；(2) 更糟的是 `[ "$working" = 1 ] || exit 0` 的 `working` 來自掃描所有雜務檔的 `^status: working`，**一個員工重寫自己的檔案會讓整個守望行程退出，連帶放掉同時在跑的其他雜務的 blocked 偵測**；(3) 若 `成員：` 僥倖留著而 `branch:` 掉了，`git merge --no-ff ""` 失敗會吐出 `merge conflict on ; ask the human`——訊息是錯的，而 `herdr pane close ""` 靜默 no-op、pane 留著不關。五個出口裡只有 `no chore file` 那個會誠實報錯。
- feat(chore): 執行狀態搬到 `.dkbo/.sessions/chores/<agent>`（gitignored，`key=value` 純文字，用 `sed` 讀**不 source**——`instr` 來自領導打的字，可能含引號與 `$`）。完成訊號改讀 `tasks/_chores/messages.log` 的 `[DONE]` 行（`dk-msg` 寫的，員工的 markdown 碰不到；`[UNDELIVERED]` 也算完成，因為員工確實交差了只是投遞失敗）。雜務檔從此**整份是員工的，機器完全不讀**。收尾從 `sed -i` 改成 append 一行 `關閉：<時間> done|abandoned — <結果>`：append 不管員工把檔案改成什麼樣都會成功。
- fix(index): `dk_index_set` 沒命中時回非零，六個呼叫點全部接上警告。名稱是 INDEX 的主鍵，而主鍵對不上是靜默的——這是上面第二件事能活到事後才被發現的原因，而六個呼叫點裡有四個在任務那側（人手動整理過 `INDEX.md` 就會踩到同一顆雷）。
- 為什麼**不**把提示語寫得更嚴厲叫員工別重寫整份檔案：那是把正確性押在一個 LLM 對格式的自制力上，對不同 kind、不同檔位、不同上下文長度的員工效果不同，而失敗是靜默的。為什麼**不**多加幾條 fallback 反查（用 branch 或 pane 倒推 agent）：那是在同一個壞結構上疊防線，真相仍住在員工的寫入面，每加一條「真相在哪」就更模糊一分。為什麼**不**給 INDEX 加 id 主鍵：名稱現在由記錄檔供應、開檔時寫一次就不再變，主鍵已經穩定，要補的是失敗的音量不是主鍵。
- `dk-chore-close` 保留 legacy 分支（0.5.0 之前開的雜務沒有記錄檔，走舊的 grep 反查 + `status: done` 閘門），但 **`dk-watch` 刻意不做**：做了就等於「誰在跑」又有兩個真相來源，正是這次要消滅的病。在途舊雜務升級後失去 blocked 守望直到被關掉為止，關閉不受影響。
- 已知代價：雜務檔的 `status:` 從此可能永遠停在 `working`（那是員工的欄位，機器不再改它，真相在 `關閉：` 那行與 INDEX）；員工做完卻忘記跑 `dk-msg` 就關不掉（`--abandon` 會跳過 merge），不加 `--done` 人工覆寫是刻意的——那等於在新界線上開一個後門。
- fix(chore): 最終審查收掉這次改動自己新開的兩個出口（同一個結構缺陷的殘餘）。`[DONE]` 的判定從此錨定在行首的 timestamp（`^[^ ]*`），不再是不設防的 `^.*`——員工可寫的訊息本文含一句偽造的 `-> … [DONE] …` 就能騙過閘門，正是這次要消滅的病換了個地方。`dk-chore` 撞號時（員工刪了自己的雜務檔，agent 編號重算撞上正在跑的那個）現在會先拒絕，不會覆蓋或牽連活著的執行記錄。記錄檔寫入改成 `.tmp` + `mv` 的原子寫，`dk-chore-close` 對 legacy 分支的空 `branch` 也加了防呆，不再把「記錄檔遺失」誤判成「merge 衝突」。
- 測試：253 bats（+13，其中三條是事故本體：員工重寫雜務檔後仍關得掉、員工刪掉雜務檔後仍留下可 commit 的記憶、員工重寫雜務檔不影響守望名單；另兩條是最終審查加的：偽造的 `[DONE]` 不算數、撞號時拒絕且不留第二個 pane）；shellcheck 零警告。

## 0.4.0 — 2026-09-12
- feat(review): 新增第八個設定鍵 `DK_REVIEW_TIER`（`M` 或 `L`，預設 `M` 維持相容）。`dk-review` 的檔位改從它來，`--tier` 仍逐次覆寫。審查是全隊最吃推理的位置，卻跟 dev 同樣預設 M；而 reviewer 是 `--isolated` 唯讀、只讀一個 diff pack + brief、單輪，升到 L 的邊際成本遠低於一個要跑 20–60 分鐘的 dev pane。現在這是一個設定，不是一次改角色檔的手術。
- 為什麼**不**把 `roles/reviewer.md` 的 `M: sonnet/medium` 直接改成 `opus/high`（這是收到的原始提案）：`dk-review` 收 `--tier M|L`，兩個值會解析到同一組旗標，旗標變成**靜默的 no-op**；結案評議的 `dk-review --task --tier L` 從此與例行波審查無異，失去加碼的意義；而 tier 在別處一律是「切片難度」（`dk-spawn`、`dk-chore` 都預設 M），讓某一個角色的 M 改指頂配，同一個字在不同角色就不同義。審查政策本來就住在 `settings.env`（`DK_REVIEW_KINDS` / `DK_REVIEW_MIN` / `DK_REVIEW_TIMEOUT_MIN`），第四把鑰匙也該放在那裡。
- `/dkbo-init` 第 3 步改問八鍵，並在問 `DK_REVIEW_TIER` 時要求先確認 `DK_REVIEW_KINDS` 已有第二個 kind：**密度先於天花板**。0.2.2 加 `dk-wave-close` 第五道閘，正是因為實跑兩波都派了 claude + codex、兩波都只有 claude 進裁定，`DK_REVIEW_MIN=1` 讓領導每次都合法地靜默放行，多模型審查的實際生效率是 0。換一個不同模型抓到的錯誤類別，跟同一個模型想得更久抓到的，不是同一批。
- 測試：240 bats（+6，其中一條釘住出廠預設仍是 M、一條釘住 `roles/reviewer.md` 的 tier 語義沒被動過）；shellcheck 零警告。

## 0.3.1 — 2026-09-12
- fix(chore): `dk-chore` 不再把正在工作的員工腳下的 worktree 與分支刪掉。兩個缺陷疊在一起造成一次實際的資料遺失（`sport-frontend-panova` 的 `chore/chore18`，員工改完 `GameModule.vue` 尚未 commit，整個 worktree 與分支消失，`git branch -a` 也查無此分支）：(1) 第一段提示用的是 `--wait --timeout 60000`，而 `herdr agent prompt --wait` 的預設語意是等**這一輪跑完**（`--help`：matches idle, done, or blocked），任何真的要動手的雜務第一輪都超過 60 秒，於是必然回 timeout；(2) 那個非零在 `set -e` 下觸發了還掛著的 `trap rollback EXIT`，rollback 執行 `worktree remove --force` 與 `branch -D`。**0.2.2 已經針對 `dk-spawn` 修過同一條**（「等這一輪結束 ≠ 提示送到了沒」），但 `dk-chore` 與 `dk-leader` 兩處漏掉了；在 `dk-chore` 這一處它不只是誤判，而是會毀掉工作。
- fix(chore): rollback 的契約收斂成「還沒有人進去過就清乾淨」——`herdr agent start` 一成功就 `trap - EXIT`，而不是拖到腳本最後一行。此後任何一步失敗（`dk_index_add`、`dk-watch`、Ctrl+C）都只報錯不動 worktree：那裡有一個活著的 agent 和它還沒 commit 的改動。提示失敗時 pane 與 worktree 都留著，INDEX 也已寫入（在提示之前），領導可以讀 pane 診斷後重送提示，或 `dk-chore-close <agent> --abandon` 收乾淨。
- fix(leader): `dk-leader` 的第一段提示同樣改成 `--wait --until working --timeout 15000`。領導第一輪要讀 `LEADER.md`、跑 `dk-task-new`、開始寫 brief，一定超過任何合理逾時；舊行為讓一個開得好好的領導 pane 被回報成失敗。這一處沒有破壞性 trap，只是誤報。
- 前例：`_chores/messages.log` 顯示 09-10 23:45 `chore-translator-12` 出過形狀相同的 ESCALATE（`chore-hi-in-144-key` 環境消失）。同一個坑吃掉兩次雜務。
- 測試：234 bats（+3）；shellcheck 零警告。

## 0.3.0 — 2026-09-11
- feat(brief-check): 檔案所有權表新增「獨佔資源」欄（`db`、`port:3000`、`docker`…，逗號分隔），同一波內兩位成員宣告同一個資源即 FAIL。worktree 隔離檔案，**不隔離執行環境** —— 同波兩位 dev 仍會對同一個 dev DB 跑 migration、搶同一個 port、重啟同一組 docker。舊的三欄 brief 照常通過（欄位缺就是沒宣告）。
- feat(watch): 新增 `DK_WAVE_TIMEOUT_MIN`（第七個設定鍵，預設 60 分鐘，0 表示關閉）。`dk-wave-open` 記下 `DK_WAVE_STARTED`，`dk-watch` 超過門檻就推一次 `[TIMEOUT] wave N` 給領導、發一次桌面通知、記一行 process，`dk-wave-close` 收尾時清掉。補的是「員工沒 blocked、reviewer 也沒逾時，但這一波就是卡著不動」這個先前沒有任何守望覆蓋的狀態。訊息走 0.2.1 的 `notify_leader`，送不到會重試。
- feat(herdr): 新增 `lib/herdr.sh` —— `dk_h_soft` 與 `dk_h_note`。dkbo 對 herdr 的呼叫有一種特別危險：吞掉失敗之後還裝作正常。`herdr agent list` 一壞，`dk-watch` 的 `|| return 0` 會讓它每 30 秒安靜地什麼都不做，blocked 與 timeout 永遠偵測不到，而 `process.md` 乾乾淨淨 —— 0.1.5 的 CHANGELOG 已經點名過這件事但沒有動作。現在這類呼叫走 `dk_h_soft`：照樣不崩，但在 `process.md` 留一行 `herdr-degraded: <呼叫>`（每個行程樹只記一次，不洗版），`LEADER.md` 故障段也補了對應處理。
- 範圍裁定（見 `decisions.md`）：**不做**全面收攏 51 個 herdr 呼叫點。失敗就該死的那些非零會自然往上傳，收尾與桌面通知吞掉是對的，硬包一層只是拿 51 處改寫的回歸風險換一個假的抽象；外部評論原本的理由（單一適配點）已由 herdr 版本硬閘與 layer-2 形狀測試涵蓋。
- BACKLOG 清空。
- 測試：231 bats（+8）；shellcheck 零警告。

## 0.2.3 — 2026-09-11
- feat(task-close, chore-close): 結案時把記憶 commit 進主樹。新增 `dk_commit_memory`（`lib/common.sh`）：只 `git add` 並 commit 指定的那幾條路徑（任務目錄、`tasks/INDEX.md`、`decisions.md`；雜務則是雜務檔、`_chores/messages.log`、INDEX），**不碰工作樹上的其他改動**（有測試守住這一點）。先前 `dk-wave-close` 在 worktree 內 commit 程式碼，但任務記憶住在主樹的 `.dkbo/tasks/`，沒有任何腳本碰過它 —— 實跑結案後整個 `tasks/<t>/`（brief、process.md 的 7 條 ruling、每位員工的 state 與 report、report.md）仍是 untracked，一個 `git clean -fd` 就會抹掉，而 README 與 `decisions.md` 都聲稱記憶「進 git」。commit 失敗只警告不擋結案。
- fix(task-new): 領導 pane 的 rename 條件從「完全沒有 agent 名字」改成「還不叫 `leader-<short>`」。pane 只要曾被命名過（例如用 `herdr agent rename` 取過名、或用 `agent start <name>` 起的），rename 就被靜默跳過，而 `dk_leader_name` 固定回 `leader-<short>` —— 員工的 `dk-msg leader` 與 `dk-watch` 的 `[BLOCKED]`／`[TIMEOUT]` 會全部送不到，**且沒有任何警告**，`process.md` 照樣寫得像一切正常。實跑時是手動改名才把訊息接回來的。
- fix(protocol): `[FIXED]` 的方向從「員工→員工」補成「員工→員工、dev→領導」。`LEADER.md` 早就規定領導把 reviewer 的 Important 轉成 `[BUG]` 給 dev、等 dev 的 `[FIXED]` 再重打差異包請 reviewer 複看，但 `PROTOCOL.md` 的類型表沒有這個方向 —— 員工照自己的規範回了 `[DONE]`，於是實跑中 `[FIXED]` 一次都沒出現，RUNBOOK 的驗收條件結構上不可能成立。兩份文件現在對齊，並加了一條測試釘住。
- 測試：223 bats（+4）；shellcheck 零警告。

## 0.2.2 — 2026-09-11
- fix(kinds): claude 員工的權限模式從 `acceptEdits` 改成 `auto`，並加 `--add-dir $DK_PROJECT_ROOT`。實跑（`tests/e2e/RESULTS-2026-09-11.md` ①）顯示 `acceptEdits` 下員工的**每一個協定動作**都在授權之外：讀自己的切片、讀 `PROJECT.md`、寫自己的 state、跑任何 shell —— 因為員工的 cwd 是 worktree 而任務記憶在主樹的 `.dkbo/`。批准一個路徑只會跳出下一個，實跑共人工介入 7 次才走得完一個任務，「領導閒置、員工自己做」根本不成立。對照組是 codex（`-a never -s workspace-write`），整趟零審批。**這是刻意放寬權限**：員工跑在隔離的 worktree 內，`PROTOCOL.md` 的停止條件仍禁止 push／改寫歷史／刪分支／裝依賴／動 `.dkbo/`；要改回嚴格模式就改 `kinds/claude.sh` 一行。
- fix(spawn): `agent start` 失敗時**不再關掉 pane**。實跑中 codex 連續四次 spawn 失敗，原因是 codex CLI 的 `✨ Update available!` 升級提示擋在啟動 —— 但舊行為把 pane（連同那個畫面）關掉，領導只看得到「失敗」兩個字，現場完全無從診斷。現在 pane 保留、`process.md` 記 `spawn <agent> failed: pane <id> kept for diagnosis`，錯誤訊息直接告訴領導怎麼讀它、怎麼收掉。`LEADER.md` 故障段補一條。
- fix(spawn): 第一段提示的等待從 `--wait --timeout 60000` 改成 `--wait --until working --timeout 15000`。`herdr agent prompt --wait` 的預設語意是等**這一輪跑完**（`--help`：matches idle, done, or blocked），不是「提示送到了沒」—— 所以第一輪超過 60 秒的員工會被誤判成 `prompt-failed`，而 `LEADER.md` 會教領導去「重新提示」一個正在工作的 agent，claude 又會把提示排隊，於是它做完後再收到一次同樣的任務。
- fix(msg): `dk-msg` 送不到改成重試（`DK_MSG_TRIES` 預設 3 次、`DK_MSG_RETRY_SEC` 預設 5 秒）才認輸。實跑中 codex reviewer 的 `[DONE]` 在一分鐘內就被判失敗、整筆遺失，而它的報告好端端躺在磁碟上 —— 領導從不知道它交過，於是 `review 1 verdict` 只有一位。
- feat(wave-close): 新增第五道閘：裁定行必須交代每一位真的派出去的 reviewer（`review N spawned` 列出誰就要有誰，沒回來的寫 `<別名>: skipped (<理由>)`）。實跑中兩波都派了 claude + codex，兩波都只有 claude 進入裁定，而 `DK_REVIEW_MIN=1` 讓領導每次都合法地靜默放行 —— 多模型審查的實際生效率是 0，且整個系統看起來一切正常。這道閘讓退化必須被寫下來。
- 測試：219 bats（+2 淨增，另改寫 6 條以對齊新行為）；shellcheck 零警告。

## 0.2.1 — 2026-09-11
- fix(watch): 送給領導的 `[BLOCKED]` 與 `[TIMEOUT]` 不再可能被靜靜吃掉。`dk-watch` 的三處推送（blocked ×2、reviewer timeout）原本直接 `herdr agent prompt` 領導、結果丟棄、標記照寫 —— 而守望觸發的前提正是領導忙著，且「提示送給 working 的 agent 會排隊還是被丟掉」在三個 kind 上都還是 `KIND_PROMPT_QUEUES=unknown`。現在一律走 `notify_leader`：先 `agent wait --until idle --until done`（**有界**，`DK_WATCH_WAIT_MS` 預設 5000 毫秒，背景迴圈不會被卡住），送到才寫 `delivered`；沒送到就留著，下一 tick 重試到送達為止。
- fix(watch): 標記檔從「兩行就算通知過」改成分開的 `notified`（桌面通知已發）與 `delivered`（領導已收到）。桌面通知、`dk_process` 的事件行、以及 reviewer 逾時的 kind 熔斷都只做一次，**且不等領導** —— 熔斷是任務狀態的改變，領導收不收得到訊息都一樣成立。逾時訊息的 `(quota?)` 標記存進標記檔，重試時訊息與第一次逐字相同。
- fix(watch): 雜務那一側同理；`messages.log` 改成送達才記，沒送到不留半筆。0.1.4 之前沒有 `leader:` 行的舊雜務檔沿用原行為（記一行「（無 leader 紀錄）」就收工，不無限重試）。
- docs(leader): 領導回雜務員工那條（`LEADER.md`）是同一個問題的第二處，改成先 `herdr agent wait --until idle` 再 prompt。
- 為什麼不先跑 layer-3 smoke 問出答案：兩條路的終點都是「讓 dk-watch 不要在乎這件事」。直接走那一步是零 token，而且未知數從此不在關鍵路徑上。`KIND_PROMPT_QUEUES` 仍是 unknown，但已不再是安全網的單點。
- 測試：217 bats（+4，含「等 idle 才送」「沒送到就重試且不重複桌面通知」「熔斷不受送達與否影響」「雜務側重試」）；shellcheck 零警告。

## 0.2.0 — 2026-09-11
- feat(leader): 領導這一側的 AI CLI 可選。`settings.env` 新增第六鍵 `DK_LEADER_KIND`（預設 `claude`，`dk_settings` 補預設與 export），`dk-leader` 不再寫死 `claude/opus/high`：kind 取 `DK_LEADER_KIND`，model/effort 取該 kind `KIND_DEFAULT_TIERS` 的 **L 檔**（領導用最高檔），`--kind` / `--model` / `--effort` 仍可逐次覆寫。它也不再自己拼 `--model/--effort`，改走 `dk_kind_args` —— 原本那樣對 codex 會送出它不認的旗標，而且漏掉 `kind_args` 該帶的權限模式。`dk-leader` 先前完全沒呼叫 `dk_settings`，順帶補上。
- feat(init): `/dkbo-init` 第 2 步拆成兩問（領導 kind，預設偵測目前 pane 的 CLI；員工主模型），第 3 步從五鍵變六鍵，並新增入口檔佈線一步。佈線放在 init 而不是 `install.sh`：install 跑在 init 之前，那時還不知道領導是誰，讓它無條件生出 `GEMINI.md` 會在 claude-only 的專案裡塞垃圾。
- refactor(docs): `LEADER.md` 去 claude 化。`/dkbo-init`、「用 add-role skill」這類 Claude Code 專屬呼叫改成指路 `.dkbo/skills/<name>/SKILL.md`（括號註明 Claude Code 的斜線指令），`/clear` 改成「清掉自己的上下文」。一份規範三種 kind 共用，不做 if/else 分歧。
- fix(kinds): `KIND_MODELS` × `KIND_EFFORTS` 的笛卡兒積驗證換成逐 model 宣告的 `KIND_MODEL_EFFORTS`。`agy models` 實測：`gemini-3.1-pro` 只有 `high` 與 `low`，**沒有 medium**，但笛卡兒積會放行 `gemini-3.1-pro/medium`，錯誤要等到 `herdr agent start` 才爆 —— 而那時 pane 已經切出去、`.panes` 也寫了。出廠檔位剛好都避開，所以這個洞一直沒被觸發。`agy` 的 `kind_args` 同時從 `--model <id>-<effort>` 改成 `--model <id> --effort <e>`（實測兩種都可用，但後綴與 `--effort` 同時給會衝突；分開傳較乾淨）。兩件都做才有意義：改傳法不會讓本地擋下不存在的組合。
- fix(docs): README 的 `bash 5` 比實際需求嚴格三個大版本，改成 `bash 3.2+`。`dk_ver_ge` 刻意避開 `sort -V` 就是為了 macOS，而 macOS 內建的正是 bash 3.2 —— 程式碼跑得動，是文件把門檻寫高了。新增 bats 掃 `.dkbo/` 不得出現 bash 4+ 語法（`declare -A`、`mapfile`、`${x,,}` 等），把文件宣稱變成機械閘，跟 0.1.5 對 herdr 做的事同一個路數；該測試會先種一個違規再掃，確認掃描真的有牙齒。
- fix(docs): 補查證出來、README 沒列的真實依賴：`git ≥ 2.17`、`jq ≥ 1.5`、`flock`（軟依賴，缺了 `dk_env_set` 退化成無鎖寫入不會崩）。早先以為需要的 `column`、coreutils `timeout`、python、node 經逐字查證並未被任何程式碼使用（grep 命中的全是註解與 herdr 自己的 `--timeout` 旗標），不列入。
- chore(docs): `docs/` 移出版控（`git rm -r --cached docs/design` + `.gitignore`）。已定案的結論寫進 `.dkbo/decisions.md`，待實作的寫成任務的 `plan.md`；README 與 BACKLOG 的九處引用改成不帶路徑的描述，CHANGELOG 的歷史條目不動（那是當時的事實）。新增 bats 擋住任何進版控的文件再指向 `docs/design`。
- test: 新增 `CHANGELOG` 最上面的版本段必須等於 `.dkbo/VERSION`。先前 `VERSION` 是 0.1.4 而 CHANGELOG 頂端已是未發布的 0.1.5，版本一致性測試只比對 VERSION 與三份 README，抓不到這個落差 —— 那個狀態下推 `v0.1.5` tag 會被 CI 擋。
- 測試：+13 bats；shellcheck 零警告。

### 0.1.5 的內容（未單獨發版，併入 0.2.0）
- feat(herdr): herdr 版本從「文件上的期望」變成實際的閘。`lib/common.sh` 新增 `DK_HERDR_MIN="0.9.0"`（低於即拒跑）與 `DK_HERDR_VERIFIED="0.9"`（`tests/integration/herdr-real.sh` 實測過 JSON 形狀的系列）；`dk_herdr_check` 解析 `herdr --version`，讀不到版本或低於下界就 `dk_die`，高於已驗證系列則每個行程樹提醒一次去跑整合測試。`dk_require_herdr`（每支 dk-* 都會過）與 `install.sh` 都呼叫它 —— install 不要求 `HERDR_ENV`，從普通 shell 安裝仍可。版本比較用自帶的 `dk_ver_ge`（純 bash，逐段十進位比較）而不是 `sort -V` —— `sort -V` 是 GNU 擴充、macOS 的 sort 不保證有，缺了會讓 `dk_herdr_check` 把每一支 dk-* 都判成「herdr 太舊」而全面停擺；字串比較則會把 0.10.0 判成小於 0.9.0。兩個陷阱測試都有覆蓋，另加前導零不被當八進位、`-rc1` 這類後綴忽略、`0.9` 等於 `0.9.0`（刻意與 `sort -V` 不同：對下界檢查而言短版本不是舊版本）。實測 `herdr --version` 20 次共 17ms，擋在每支指令上的成本可以忽略。
- 為什麼需要這道閘：dkbo 對 herdr 的假設（`pane split --ratio` 是 anchor 保留的份、`--amount` 是面積比例、`pane read` 回純文字）是實測 0.9.0 得到的，而 herdr 呼叫的失敗是刻意吞掉的（`dk_layout_even || true`、`agent list || return 0`，見測試「herdr failure is swallowed」）。換版時的表現不是報錯，而是版面悄悄歪掉、`agent list` 取不到 agents 之後 **dk-watch 永遠偵測不到 blocked** —— 整套安全網變成 no-op 而看起來一切正常。
- test(integration): `herdr-real.sh` 開頭印出實際 herdr 版本是否落在 `DK_HERDR_VERIFIED`，超出時提示驗完就把常數往上調。stub 支援 `HERDR_STUB_VERSION` 假裝任何版本。
- 測試：200 個 bats（+7）；shellcheck 零警告。

## 0.1.4 — 2026-09-11
- fix(wave-close): 越界比對從「員工自報的 `touched:` 清單 + 只印警告」改成真正的機械閘。新增 `dk_changed_files`（`lib/ownership.sh`）用丟棄式 index 取 worktree 自本波 base 起的真實變更檔，含未 commit 與未追蹤、`.gitignore` 照舊生效、不碰員工的 index；本波沒有任何成員擁有的檔案一律 `exit 1`（`--force` 例外，並在 process 記 `violation unowned:`）。改到不屬於自己的檔、在 worktree 裡動 `.dkbo/` 規則檔，現在都關不掉這一波。
- feat(wave-close): 自己擁有但沒寫進 `touched` 的檔列為 `unreported change`（警告、不阻擋，記 process）。
- feat(wave-close): 波的 commit 收進腳本。四道閘全過、pane 關完後在 worktree 內 `git add -A && git commit`，訊息預設 `wave N: <成員>`，`-m "<訊息>"` 可覆寫；無變更不空 commit；commit 失敗回非零並記 process。領導不再手動 commit，波的邊界等於 commit 邊界。
- refactor: `wave-open N base <sha>` 的解析收攏成 `dk_wave_base`（`lib/common.sh`），`dk-review-pack`、`dk-resume`、`dk-wave-close` 共用。
- docs: LEADER.md 第 5 步與三則新故障處理、PROTOCOL.md 的 `touched` 說明、兩份 README、`.dkbo/README.md`；`docs/design/2026-09-10-external-review-response.md` 加第 6 節，更正該文第 3 節「三道機械閘」的說法。
- 無主但預期會變的檔（lockfile 之類）不另開設定鍵：要動就在 brief 的檔案所有權表列給某位成員。
- ci: 新增 `.github/workflows/ci.yml` —— 每次 push 與 PR 跑 `tests/run.sh` 與 shellcheck（含 `install.sh`、`kinds/*.sh`，與 README 記載的範圍對齊）；推 `v*` tag 時另驗 tag 等於 `.dkbo/VERSION` 且 CHANGELOG 有該版條目。版本字串一致性做成 bats 測試（`.dkbo/VERSION` 與兩份 README 的版本行、三處 `VER=v…` pin、`install.sh` 與 `dk-version` 的範例輸出共八處必須一致），本機 `tests/run.sh` 就會抓。
- fix(watch): 守望不再會無聲消失。`dk-watch --ensure` 幂等重啟：用 `ps -p <pid> -o args=` 比對完整命令列（不是 `kill -0` —— PID 會被回收，`kill -0` 會把一個無關行程當成 watcher 還活著），死了就重啟並記 `watch restarted`。`dk-spawn`、`dk-wave-open`、`dk-resume` 都會呼叫；`dk-resume` 另外在「本波」段印一行 `watch:` 狀態。原本 watcher 只由 `dk-task-new` 啟動一次，機器睡眠或行程被殺之後 `[BLOCKED]`／`[TIMEOUT]`／kind 熔斷整層就靜靜不見了，而領導的判斷依賴它存在。
- feat(watch): 雜務也有守望了。`dk-watch --chores` 掃 `tasks/_chores/*.md` 裡 `status: working` 的雜務做 blocked 偵測（沒有 reviewer 逾時那套），推 `[BLOCKED]` 給該件雜務自己的領導並記進 `_chores/messages.log`；由 `dk-chore` 幂等啟動，最後一件雜務關掉後自己退出。pid 與 marker 放 `.sessions/`（已被 gitignore）。`templates/chore.md` 新增 `leader:` 欄（`dk-chore` 本來就算出這個值，只是沒寫下來）；0.1.4 之前的雜務檔沒這欄，退化成只發桌面通知。
- 測試：193 個 bats（+29）；shellcheck 零警告。

## 0.1.3 — 2026-09-10
- docs(decisions): 定調路線：一位人類、一位領導、同時 3 到 6 位員工、一個 herdr 視窗；不做 event bus、agent registry 評分、任務 DAG、金額預算。
- docs(design): 新增 `docs/design/2026-09-10-external-review-response.md`，記錄對外部評論的四處事實更正（wave-close 三道機械閘已存在、wave close 與 merge 本來分開、reviewer 為隔離的不同 kind、版本）與逐點裁定。
- docs(backlog): 排入 herdr 呼叫收攏進 `lib/herdr.sh`、整波逾時 `DK_WAVE_TIMEOUT_MIN` 兩項。
- docs(readme): `dk-resume` 隨時可跑當狀態總覽，不必等失憶才用。
- 不改任何腳本。

## 0.1.2 — 2026-09-10
- docs(protocol): 停止條件加「不跑會跳權限確認的指令」（`rm -rf`、`git push`、`git reset --hard`、`git clean`、部署類）。員工跑在 acceptEdits，專案的 `ask` 規則會讓指令停在確認提示等人按，pane 沒人看就永遠卡住；改用不加 `-f` 的單一路徑刪除或工具自帶清理，否則 ESCALATE。
- fix(close): `dk-task-close`、`dk-chore-close` 在 worktree 有未 commit 變更時拒絕結案（exit 1），不再被 `worktree remove --force` 無聲丟掉；要丟才用 `--abandon`。
- fix(close): 合併成功後刪掉 `dk/<short>`、`chore/<slug>` 分支（`branch -d`，只刪已合併的），分支不再隨任務數累積。
- fix(task-new): `worktree add` 之後任何一步失敗都會回收 worktree、分支與半寫的任務資料夾，同名任務可以直接重開。
- refactor(chore): `--code` 雜務改用原生 `git worktree add`（`.worktrees/chore-<slug>`，同樣吃 `DK_WORKTREE_DIR`），不再經 `herdr worktree create` 另開 workspace；員工 pane 從領導 pane 切出。同 slug 的雜務尚未關閉時拒絕重開。舊的 herdr workspace 雜務仍由 `dk-chore-close` 用 herdr 移除並 `git worktree prune`。

## 0.1.1 — 2026-09-10
- fix(chore): 雜務員工改用 `dk-msg leader` 回報。舊做法直接 `herdr agent prompt` 領導，領導忙碌或剛 `/clear` 時訊息會被吃掉，領導永遠不知道要 `dk-chore-close`；dk-msg 會等領導閒置再送，並記到 `tasks/_chores/messages.log`。
- fix(chore): 多行交代不再撐壞 `tasks/INDEX.md`（名稱只取第一行、`dk_index_add` 壓平換行），也不再讓 chore 檔名帶換行（`dk_slug`）。之前多行交代會讓 `dk-chore-close` 找不到檔、INDEX 狀態永遠停在 working。

## 0.1.0 — 2026-09-10
第一個標版本。

- 領導／員工基本流程：`dk-task-new`、`dk-spawn`、`dk-msg`、`dk-wave-close`、`dk-watch`、`dk-resume`、`dk-chore`、`dk-task-close`、`dk-leader`。
- 每波審查閘：`dk-wave-open`、`dk-review-pack`、`dk-review`（1–3 位 reviewer、kind 熔斷）、`dk-wave-close` 三檢查（裁定、dev 報告 `## 測試`、`DK_TEST_CMD`）。
- 事前防線：`dk-brief-check`、成員 brief 切片、員工報告檔、`.dkbo/settings.env`。
- 多人版面：領導佔 tab 1 左欄，員工依格填位，第 5 位起自動開新 tab，關 pane 後動態均分。
- 任務 worktree 改用 `git worktree add`（`.worktrees/<short>`）。
- 真 herdr 0.9.0 驗證：`pane split --ratio` 是 anchor 保留的份、`pane resize --amount` 是面積比例、`pane read` 回純文字。
- 套件名統一為 dkbo，repo `dkbo/dkbo-team`；shellcheck 零警告。
