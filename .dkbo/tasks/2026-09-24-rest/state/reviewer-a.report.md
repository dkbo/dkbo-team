# rest-reviewer-a 報告（波 1）
審查對象：`waves/1.diff`（810b931 起、含未 commit 工作樹，22 檔）＋ brief.md 全文＋四位 dev 的 report。

## 複看（修復輪，差異包 2026-09-24T19:28，24 檔）
- ✅ Important 1 已修（AC5 ⑦）：`.dkbo/bin/dk-task-new:97-103` 兩段 `nohup … &` 加 `sed` 改成一行 `DK_TASK_DIR="$dir" "$DK_ROOT/bin/dk-watch" --ensure </dev/null >/dev/null 2>&1 3>&- || true`。`DK_NO_WATCH` 判斷、fd 3 與 stdin 的處理照舊；pid 由 `--ensure` 的 `dk_env_set` 寫進 `.task.env`，剛建的任務 pid 為空，所以不會記 `watch died`。`grep -rn 'nohup.*dk-watch' .dkbo/bin` 除了 dk-watch 本身已經沒有別處。05 新增的測試用 `ps -o sid=` 等於 pid 證明兩隻都是 session 首領，並驗 process 兩行與 start 行；我實跑 `-f '⑦'` → ok 1。dk-task-new 已補進 backend-watch 的可改欄（brief 所有權表），沒有越界。
- ✅ M1 已修（AC5 ⑧）：`wake_watch` 多了 `[ -f "$dir/.panes" ]` 條件（`.dkbo/bin/dk-msg:79`）。06 新增一條：刪掉 `.panes` 後分別走送達出口與 `[UNDELIVERED]` 出口，pid 不變、process 沒有 `watch` 行、沒有 dk-watch 行程；我實跑 05／06 的 `-f 'AC5'` 全 ok，跑完查過沒有殘留夾具行程。
- ✅ 驗證：shellcheck（全域約束的集合）rc=0；`@test` 總數 756。backend-watch 實跑全套 `1..756` 全 ok。
- ❌ AC7 待補（簿記，不是程式錯）：`CHANGELOG.md` 0.16.0 節的測試行仍寫 `754 bats（+98`，實際已是 756（應為 +100，括號內要補 `05_task_new` +1、`06_msg` 改 +5）；feat(watch) 條目也還沒提 dk-task-new 改走 `--ensure`，以及結案後（沒有 `.panes`）dk-msg 不叫回守望。依 AC7 應由領導對 backend-docs 下 `[TASK] 補測試條數` 重填，21_version 要不要多斷言一個字串由領導決定。結案前一定要補，否則違反「條數＝最後一次實跑值」。
- 複看後 Important：0 條程式問題；只剩上面這筆 AC7 簿記待補。M2–M5 維持「可留」。

## 規格合規（初審）
- ✅ AC1：gate c 的剝除迴圈改成 `${!DK_@} ${!HERDR_@}`，單 repo 與多 repo 共用同一個 `clean` 陣列（`.dkbo/bin/dk-wave-close:120-122`），註解補上理由。08 加兩條（單 repo、多 repo），呼叫端有 `HERDR_PANE_ID`／`HERDR_ENV`／`HERDR_SOCKET_PATH`，斷言裡有 `refute_grep '^HERDR_'`、`refute_grep '^DK_'` 和 `^PATH=`。「dkbo 自己的測試不靠繼承的 `HERDR_*`」的確認方式寫在 backend-gate report：`grep` 過 run.sh，也比對過 helpers 在每條測試的 setup 裡重新 export；另外拿剝光 `DK_*`／`HERDR_*` 的環境實跑整套，752 條中 749 條 ok，3 條紅都是 06 的 AC5 當時還沒實作。紅綠紀錄都有。
- ✅ AC2：`tests/unit/37_shellcheck.bats` 的 skip 訊息逐字相符。檔案集合只寫在 `sc_targets` 一處；②③ 共用同一個 `sc_run`；自我驗證用的是 SC2086 的暫存腳本。`tests/run.sh` 沒改。我實跑 `tests/run.sh tests/unit/35_test_hygiene.bats tests/unit/37_shellcheck.bats`，8/8 ok，37 是實際執行，不是 skip。
- ✅ AC3：`fixture_copy_dkbo` 照舊整份 `cp -r` 並清 `.sessions/`，只用 `--no-optional-locks` 加 plumbing（`rev-parse`／`ls-files --others --exclude-standard`／`diff-index`／`cat-file`／`show`），只動 `.dkbo/tasks/`；來源不是 git 倉時 `return 0`（`tests/helpers.bash:46-63`）。helpers 的註解寫明了例外。36 加三條：髒主樹、不刷新 index 的探針、非 git 來源，涵蓋 AC 要求的全部情境，也驗了來源本身不被動到。
- ✅ AC4：11 加一條新版模板的 legacy 測試：exit 0、INDEX 是 done、分支名稱清單不變、main 上沒有 merge commit、沒印 `merge conflict`。report 附了突變探針（在獨立目錄刪掉守衛那行 → 紅，輸出 `merge conflict on ;`）。
- ✅ AC5：①–⑥ 都實作了，測試對得上 AC 列的每一項。
  - ① `bg_start` 用 setsid（沒用 `-f`），沒有才退回 nohup。`$!` 就是 dk-watch 本身，已實測 `ps -o args=`。
  - ② 輸出改寫到 `.sessions/<任務目錄名>.watch.log`／`chores.watch.log`。
  - ③ start／signal／exit 行照契約的格式寫；HUP 記完照跑，INT／TERM 記完結束。
  - ④ `watch died` 用詞界比對，排在 `watch restarted`／`events started` 之前。
  - ⑤ dk-msg 七個寫 log 的出口都有 `wake_watch`（`.dkbo/bin/dk-msg:83,130,210,224,266,274`）。
  - ⑥ flock 用 fd 8、鎖檔另立，鎖內重讀 `.task.env`，`bg_settle` 等它 exec 完才放鎖。
  - 與 brief 字面不同的有兩處，我判合規。一是把「poll 模式 trap 要等前景 sleep」改成背景 `sleep & wait`，讓 trap 當場生效，註解也改寫成仍會延後的實際情況。二是選用的 `env --default-signal`，有才用、不是必要依賴，理由有實測（SigIgn=0x6）。
  - AC5 條文本身有涵蓋不到的地方，見 Important 1。
- ✅ AC6：`dk_owned` 改走 `dk_brief_owners` 加 `$DK__BRIEF_SPLIT`，切完才把 `\|` 還原（`.dkbo/lib/ownership.sh:17-21`）。`first_glob`（`.dkbo/bin/dk-spawn:57-60`）與 dk-brief-check 那兩處（`:136`、`:143`）也都改了；awk 變數名避開了 SPLIT 內部佔用的 `m/c/p/i/j/v/nf/line`（`w`／`who`／`n`）。22 加兩條，含誘餌，取紅紀錄齊全。07 那條守護舊碼本來就綠，另附突變探針。16 那條回歸守護有註明「舊碼本來就綠」。
- ✅ AC7：run SKILL 第 1 條同時含 `dk-msg`、`watch.log`、`watch died`，檔案 58 行（≤60）。PROJECT.md 的測試指令與目錄慣例改寫到位。CHANGELOG 0.16.0 節追加五條、測試行寫 754（+98）。我逐檔對 HEAD 數 `^@test`，新增 30 條，現在總數 754，與實跑相符。21 的首節清單也補齊了。VERSION 與 README 的 `VER=` 沒動。
- ✅ AC8：BACKLOG 只刪掉 request.md 列的 6 列（`git diff` 只有 6 行 `-`），其餘 4 列、表頭與說明句都沒變。
- ✅ AC9：backend-docs 與 backend-watch 各自實跑完整套件，`1..754` 全 ok。我另外跑 `shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh tests/run.sh`，rc=0。每位 dev 的「## 測試」都有自己 AC 的取紅紀錄。
- ✅ 全域約束：
  - 沒有 bash 4 語法；陣列、`read -d ''`、`< <(…)`、`${!X@}` 都是 3.2 就有的。
  - 沒有新 bin、新鍵或新 skill；新測試檔只有 37。
  - `numstat` 顯示既有測試只有新增（21 那一行是往清單加字串），沒有 `! cmd`，35 綠。
  - 22 個檔都在各自擁有者的可改欄內，沒有越界。
  - report 沒有宣稱「本波已用到」新行為。

## Important
1. **brief 缺口，不是 dev 違規：每個任務的第一對守望仍用舊方式啟動**。位置在 `.dkbo/bin/dk-task-new:97-104`（不在本波任何人的所有權內）。
   - 現象：`dk-task-new` 建任務時直接 `nohup "$DK_ROOT/bin/dk-watch" … >/dev/null 2>&1 &` 起輪詢與訂閱兩隻，沒有 setsid、stderr 丟 `/dev/null`，也不拿 `--ensure` 的鎖。只要這兩隻還活著，後面 dk-wave-open、dk-spawn、dk-msg 的 `--ensure` 都判定 running，不會換成 setsid 版。
   - 後果：每個任務從建立到第一次死亡，跑的都是舊啟動方式的守望。BACKLOG 猜測的死因是「啟動它的那次 Bash 呼叫結束時，整個行程群組被收掉」，setsid 正是為此加的，但這第一對不受保護。它們死前的 stderr（`set -e` 退出時的錯誤訊息）也照樣丟失。好在 `wline` 寫在 dk-watch 裡，這兩隻仍會留 start／exit／signal 行；死後也會被下一則 dk-msg 用 setsid 叫回，所以不是全失效。
   - 失敗情境：`dk-task-new` → 領導在 Bash 工具裡跑的那次呼叫結束，行程群組被收 → 兩隻守望沒有 setsid 保護而死，watch.log 只剩 start 行、沒有錯誤原文 → 要等到有人送 dk-msg 才被叫回。這段空窗正是事故裡那 53 分鐘的形狀；只是現在第一則 `[DONE]` 就會把它叫回來。
   - 建議（請領導裁定）：把 `dk-task-new` 那兩段改成 `"$DK_ROOT/bin/dk-watch" --ensure >/dev/null 2>&1 || true`（`--ensure` 已經會處理 events、鎖與 setsid），需要補所有權並檢查引用它的 `05_task_new`、`09`、`26` 等測試；或者記進 BACKLOG，並在 CHANGELOG 的 feat(watch) 條目註明「任務建立時的第一對除外」。

## Minor
（本任務累積的 Minor：brief 該段為空，逐波審查沒有待 triage 的條目。以下是本波新發現的 Minor，一條一行判定：M1–M4 可留，M5 可留。）
- M1（可留）`.dkbo/bin/dk-watch:83` 與 `.dkbo/bin/dk-msg:78`：`--ensure` 不檢查 `$dir/.panes` 在不在，而現在每則 dk-msg 都會呼叫它。任務結案後，還在背景送的 dk-msg（例如領導排隊的 `[TASK]` 最後走 `[UNDELIVERED]` 出口）會對已 commit 的任務目錄追加 `watch died`／`watch restarted` 到 process.md、改寫 `.task.env`，並起兩隻第一輪就自己退出的守望。既有的 `undelivered` 那行 process 本來就有同類問題，所以影響不大；在 `wake_watch` 加一個 `[ -f "$dir/.panes" ]` 條件即可。
- M2（可留）`.dkbo/bin/dk-msg:256,266,274`：領導背景排隊的那一份，是在 `queue_leave`（trap EXIT）之前跑 `wake_watch`。守望已死時，它要等鎖（最多 10 秒）加上 `bg_settle`（最多 2×3 秒），同一收件者的下一則會多排幾秒。沒有錯，只是順序可以對調。
- M3（可留）`.dkbo/bin/dk-watch:454`：收到 HUP 時 `wait` 被打斷，`|| kill "$spid"` 會把這一輪的 sleep 殺掉，下一個 tick 提前跑。行為無害，但註解沒提。
- M4（可留）`tests/unit/36_fixture.bats:133-137`：用了 GNU 專屬的 `touch -d`、`stat -c`。CI 只跑 ubuntu，既有測試也大量用 GNU `sed -i`，backend-test 在疑慮裡自己提過，維持現狀。
- M5（可留）`.dkbo/bin/dk-watch:30-41`：在沒有 setsid 的平台（macOS），員工 pane 的 dk-msg 叫回的守望會留在員工那一側的行程群組裡。herdr 關掉員工 pane 時若收整個群組，這隻守望會一起死；死時會留 signal／exit 行，下一則 dk-msg 也會再叫回來。Linux 走 setsid，不受影響。這是 brief 已接受的「setsid 選用」取捨，記下備查。

## 測試
### 紅
不適用：reviewer 只讀、不寫測試。各 dev 的取紅紀錄已逐條核對（08／22／36／11 的紅、37／11／07 的突變探針、09／26／06 的紅），都是在獨立目錄或實作前做的，沒有在共用 worktree 用 stash 或 checkout。
### 綠
不適用於新測試；以下是我的獨立實證：
- `shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh tests/run.sh` → 無輸出，`sc_rc=0`
- `tests/run.sh tests/unit/35_test_hygiene.bats tests/unit/37_shellcheck.bats` → `1..8`，8 條全 ok（37 實際執行，不是 skip）
- 條數核對：`git show 810b931:tests/unit/<f>.bats | grep -c '^@test'` 對照工作樹，各檔增量合計 +30；`cat tests/unit/*.bats | grep -c '^@test'` → 754，與 CHANGELOG 相符
- `git diff --numstat 810b931 -- tests/`：除 helpers（29/4）與 21（3/1）外，全部 0 刪除

## 自我審查
- 只讀，沒有改任何程式或測試；只寫自己的 state 與本報告。
- Important 1 是 brief 的範圍缺口（AC5 只列三種 `--ensure` 啟動），四位 dev 都照 brief 做了；是否要修、在哪一波修，由領導裁定。

## 疑慮
- 員工 pane 叫回的守望會繼承員工的環境（`DK_AGENT`、`DK_ROLE`、`DK_ISOLATED`、員工的 `HERDR_PANE_ID`）。我查過 dk-watch 用到的 `DK_*`／`HERDR_*`，都來自 `.task.env`（每輪都重讀）或 settings，沒有讀這幾個變數，目前沒有影響；以後 dk-watch 若開始讀 `HERDR_PANE_ID`，要記得這件事。
