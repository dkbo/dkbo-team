# rest-backend-watch 報告（波 1）
## 做了什麼
AC5（守望程序靜默死亡），只動所有權內五個檔：`.dkbo/bin/dk-watch`、`.dkbo/bin/dk-msg`、`tests/unit/09_watch.bats`、`tests/unit/26_watch_events.bats`、`tests/unit/06_msg.bats`。

dk-watch：
- ① 三種背景啟動（`--ensure` 輪詢、`--events`、`--chores`）收進 `bg_start`：`command -v setsid` 成功用 `setsid`（不用 `-f`），否則 `nohup`。非 job control 的 `&` 不是行程組長，setsid 直接 exec，`$!` 就是 dk-watch 本身（測試以 `ps -o args=` 結尾驗證）。
  額外（選用，同 setsid 有才用）：GNU `env --default-signal` 存在時經由它 exec —— 實測 `&` 起的子行程 SigIgn=0x6（INT、QUIT 進場即忽略），bash 不准 trap 進場前已忽略的訊號，不還原的話 ③ 的 INT 永遠不生效；用 setsid 時連 HUP 一起還原（呼叫者是 nohup 起的 dk-msg 背景那一份時，HUP 以「已忽略」繼承）。env 也是 exec，pid 不變。
- ② stdout／stderr 追加到 `$DK_ROOT/.sessions/<任務目錄名>.watch.log`（雜務 `chores.watch.log`）。
- ③ 常駐迴圈（非 `--once`）開頭寫 `<dk_now> start <mode> pid <pid>`；trap EXIT 寫 `exit <mode> pid <pid> rc=<rc>`；HUP 寫 `signal HUP …` 後照跑；INT／TERM 寫 `signal <SIG> …` 後 `exit 130／143`。行由行程自己用明確路徑追加，所以 dk-task-new 直接起的那兩隻（不在我的所有權，照舊 `>/dev/null`）也會留 start／exit 行。
  輪與輪之間的 `sleep` 改成背景 `sleep & wait`：前景 sleep 會讓 TERM 的 trap 晚一整個 interval 才跑，既有測試 26「dk-task-close 兩條都收」因此紅（見自我審查）。events_tick 的 `wait` 改 `until wait; do :; done`，否則 HUP 打斷 wait 回 129、set -e 下整隻退出。仍會延後／孤兒化的兩件事寫在註解（前景 herdr／jq 跑完才輪到 trap；`herdr pane wait-output` 子行程 TERM 後成孤兒到自己的 timeout）。
- ④ `--ensure` 看到記錄的 pid 非空但 `alive` 為假，在 `watch restarted`／`events started` 之前記 `watch died: <poll|events> pid <舊> last: <該 pid 最後一行|no log>`；比對用 `grep -E " pid <舊>( |$)"`，非數字 pid 一律 no log。既有兩行格式不變。
- ⑥ `--ensure` 三條都 flock：鎖檔 `.sessions/<任務目錄名>.watch.lock`／`chores.watch.lock`，fd 8（dk_env_set 用 fd 9、鎖檔也不同，不自鎖）；拿到鎖後 `dk_task_env` 重讀 pid；起完用 `bg_settle` 等它 exec 成 dk-watch（最多 3 秒）才放鎖 —— 否則 fork 未 exec 前 args 還是 `dk-watch --ensure`，下一個 --ensure 會判它死、再起一隻。背景行程一律 `8>&-`，鎖不跟著常駐行程活。

dk-msg：
- ⑤ `wake_watch`：綁任務（非雜務）且 `DK_NO_WATCH` 未設時跑 `dk-watch --ensure </dev/null >/dev/null 2>&1 || true`。掛在每一個寫 messages.log 的出口：`--ack`、dev→leader `[DONE]` 只落盤那條、送達、`[UNDELIVERED]`，以及兩個背景送的前景出口（dev→qa `[DONE]`、領導的指派型訊息；背景那一份送達／送不到時自己也會再叫一次）。

## 測試
### 紅
先寫測試、實作前在 worktree 跑（當時實作一行未改）：
```
$ tests/run.sh tests/unit/09_watch.bats
ok 75 AC5: --ensure 印出的 pid 在 2 秒內成為 dk-watch 本身，再 ensure 印 running 同一個 pid   ← 舊碼本來就成立（守護用）
not ok 76 AC5: 背景守望啟動時在 .sessions/<任務>.watch.log 寫 start 行
not ok 77 AC5: TERM 寫 signal 與 exit 兩行後結束
not ok 78 AC5: HUP 只寫 signal 行，行程照跑（nohup 語意）
not ok 79 AC5: --ensure 遇到死 pid 先記 watch died 帶該 pid 最後一行，不吃到前綴相同的 pid
not ok 80 AC5: watch died 在 log 裡找不到該 pid 就寫 no log；pid 空白不記
not ok 81 AC5: 守望已死時並行兩個 --ensure，只起一隻、process 只一行 watch restarted
#   `[ "$n" -eq 1 ] || …' failed   → ps 列出兩隻 `bash …/dk-watch` 與兩隻 `--events`（真的競態）
not ok 82 AC5: --chores --ensure 起的守望寫 start chores 行進 chores.watch.log
$ tests/run.sh tests/unit/26_watch_events.bats
not ok 27 AC5: --events --ensure 印出的 pid 在 2 秒內成為 dk-watch --events，再 ensure 印 running 同一個 pid
not ok 28 AC5: --events --ensure 遇到死 pid 記 watch died: events 帶最後一行，排在 events started 之前
not ok 29 AC5: 訂閱器收到 TERM 寫 signal 與 exit 行
$ tests/run.sh tests/unit/06_msg.bats
not ok 58 AC5: 守望已死時 dev 對 leader 的 [DONE]（只落盤、不送達）把它叫回來
not ok 59 AC5: 一般 [QUESTION] 送達路徑也把守望叫回來
not ok 60 AC5: [UNDELIVERED] 出口也把守望叫回來
ok 61 AC5: DK_NO_WATCH 設了時 dk-msg 不起守望   ← 否定守護，舊碼本來就綠
```
實作中追加的兩條，各自先紅：
```
$ tests/run.sh tests/unit/09_watch.bats -f "收到 INT"      （bg_start 還沒加 env --default-signal 時）
not ok 1 AC5: --ensure 起的守望收到 INT 寫 signal 與 exit 行後結束（需要 env --default-signal）
# wait_line: …watch.log 裡等不到 /exit poll pid 348608 rc=…/: 2026-09-24T18:58 start poll pid 348608
$ (cd $SCRATCH/redcopy && tests/run.sh tests/unit/09_watch.bats -f "呼叫者是 nohup")
  # redcopy＝worktree 檔案 cp 到獨立目錄、把 sigs=INT,HUP 改回 sigs=INT
not ok 1 AC5: 呼叫者是 nohup 起的（dk-msg 背景那一份），叫回的守望收到 HUP 仍記 signal 行、照跑
# wait_line: …等不到 /signal HUP poll pid 509811$/: 2026-09-24T19:02 start poll pid 509811
```
既有測試轉紅（實作第一版後）：
```
$ tests/run.sh tests/unit/26_watch_events.bats -f "dk-task-close 兩條都收"   （連跑三次都紅）
not ok 1 dk-task-close 兩條都收，訂閱器不會變成沒人管的常駐行程
#   `refute kill -0 "$epid" 2>/dev/null' failed
```
### 綠
```
$ tests/run.sh tests/unit/09_watch.bats        → 1..84，全 ok（兩輪）
$ tests/run.sh tests/unit/26_watch_events.bats → 1..29，全 ok（兩輪；含 dk-task-close 那條，單獨連跑三次 ok）
$ tests/run.sh tests/unit/06_msg.bats          → 1..61，全 ok（兩輪）
$ tests/run.sh tests/unit/09_watch.bats -f "收到 INT"       → ok 1
$ tests/run.sh tests/unit/09_watch.bats -f "呼叫者是 nohup" → ok 1
$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh tests/run.sh → 零輸出（rc=0）
$ tests/run.sh   （送 DONE 前一次，共用 worktree 含夥伴當下的改動）→ 754 條全 ok，rc=0
```
其他引用 dk-watch／dk-msg 的測試檔另外單跑過：03、04、05、10、11、18、25、34、35、37 全綠。測完 `ps` 查過沒有殘留的 `/tmp/tmp.*/.dkbo/bin/dk-watch` 行程。
本檔新增測試 17 條：09 +10、26 +3、06 +4。

## 自我審查
- 26「dk-task-close 兩條都收」轉紅：重現指令見上。假設「TERM 被 trap 接住後要等前景 `sleep "$interval"`（events 預設 2 秒）結束才跑，測試的緊迴圈等不到」→ 改成背景 sleep＋`wait`（wait 會被 trap 過的訊號當場打斷），同一條指令連三次綠。根因一句：trap 化的 TERM 在 bash 裡被前景 sleep 延後。
- 排除過：INT trap 無效不是我的 trap 寫錯 —— `/proc/<pid>/status` SigIgn=0x6，是 `&` 讓子行程進場即忽略 INT（bash 規則）；`env --default-signal=INT` 後 SigIgn=0x4、trap 生效。
- 排除過：`setsid` 在這裡不會 fork（`$!` 的 `ps -o args=` 就是 `bash …/dk-watch`），因為背景子行程不是行程組長。
- `grep -E " pid $1( |\$)"` 只在 `$1` 是純數字時跑，避免把非數字 pid 當 regex。
- 沒改：dk-task-new 自己起的那兩隻（不在所有權）仍 `nohup … >/dev/null`，它們的 HUP 被 nohup 忽略、不會有 signal HUP 行，但 start／exit 行照寫（行程用明確路徑寫 log）。
- 沒有測到的：沒有 setsid 的 nohup 退路（本機 setsid 在 /usr/bin，無法在 PATH 上單獨拿掉它）。

## 疑慮
- 契約形狀照 brief 實作，沒有變更。額外加的 `env --default-signal`（選用、有才用）不是新依賴，但屬於 brief 沒寫的做法；理由是不加的話 ③ 的「收到 INT 寫 signal 後結束」對 --ensure 起的守望永遠不成立。領導若認為越界，拿掉它只會讓 INT 那條測試 skip 不了（會紅），需要一併處理。
- 輪與輪之間改背景 sleep 後，brief 註解要求交代的「poll 模式 trap 要等前景 sleep」已不成立，註解改寫成實際仍會延後的情況（前景 herdr／jq、wait-output 孤兒）。
- 依全域約束：本任務的新行為（setsid、watch.log、dk-msg 叫回守望）領導跑主樹腳本，本任務內不會生效。

---
# 修復輪（review：reviewer-a Important 1 ＋ M1 → brief AC5 ⑦⑧）
## 做了什麼
- ⑦ `.dkbo/bin/dk-task-new`：起第一對守望的兩段 `nohup … &`＋`sed` 落 pid，改成一行 `DK_TASK_DIR="$dir" "$DK_ROOT/bin/dk-watch" --ensure </dev/null >/dev/null 2>&1 3>&- || true`。setsid、watch.log、flock、`watch restarted`／`events started` 兩行 process、兩個 pid 落 `.task.env` 全由 `--ensure` 做；`DK_NO_WATCH` 判斷與 fd 3／stdin 關閉照舊；stdout 關掉（task-new 只印任務目錄，測試拿 `$output` 當路徑）。
- ⑧ `.dkbo/bin/dk-msg` 的 `wake_watch` 多一個條件 `[ -f "$dir/.panes" ]`：結案後（dk-task-close 刪 `.panes`）的背景送不再對已 commit 的任務目錄記 `watch died`、改 `.task.env`、起守望。
- M2–M5 標「可留」，領導這輪只派 Important 1＋M1，沒動。

## 測試
### 紅
```
$ tests/run.sh tests/unit/05_task_new.bats -f "AC5 ⑦"
not ok 1 AC5 ⑦: task-new 起的第一對守望走 --ensure：setsid 的 session 首領、寫 start 行、process 記啟動
#   `[ "$(ps -o sid= -p "$wpid" | tr -d ' ')" = "$wpid" ]' failed     ← 舊碼 nohup 起，不是 session 首領
$ tests/run.sh tests/unit/06_msg.bats -f "AC5 ⑧"
not ok 1 AC5 ⑧: 任務結案後（.panes 已刪）送訊息不叫回守望：process 沒有新的 watch 行、pid 不變
#   `[ "$(watch_pid_now)" = "$dead" ]' failed                          ← 舊碼照樣叫回、改寫 .task.env
```
（實作前在 worktree 跑，當時 dk-task-new／dk-msg 尚未改。）
### 綠
```
$ tests/run.sh tests/unit/05_task_new.bats -f "AC5 ⑦"  → ok 1
$ tests/run.sh tests/unit/06_msg.bats -f "AC5 ⑧"       → ok 1
$ 單檔：05 1..31、06 1..62、09 1..84、26 1..29、13 1..37、28 1..15、30 1..3、33 1..23、04 1..10 全 ok（13/28/30/33 沒有轉紅，不需 ESCALATE）
$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh tests/run.sh → 零輸出
$ tests/run.sh → 1..756，ok=756、not ok=0，rc=0（共用 worktree，含夥伴當下改動）
```
本輪新增測試 2 條（05 +1、06 +1）；本人累計 19 條（09 +10、26 +3、06 +5、05 +1）。測後 `ps` 查過沒有殘留的夾具 dk-watch 行程。

## 自我審查
- 05 新測試用 `ps -o sid=` 等於 pid 直接證明是 setsid 起的（session 首領），不是只看 args；沒有 setsid 的平台 skip。
- 既有 05／09／26 斷言一字未改；09、26 的「dk-task-new 起兩隻並記 pid」那兩條走新路徑仍綠。
- task-new 現在會多兩行 process（`watch restarted (pid N)`、`events started (pid N)`），第一次啟動也叫 restarted —— 沿用 `--ensure` 既有格式，brief ⑦ 要的就是「同一條路」，沒另造字樣。

## 疑慮
- `--ensure` 在 task-new 裡最多會多等 `bg_settle` 2×3 秒（實測遠低於此，exec 在百毫秒內完成）；task-new 是領導在計畫開頭跑一次，影響可忽略。
