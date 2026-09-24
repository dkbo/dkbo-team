# backend-msg 報告（波 2）
## 做了什麼
整枝評議 Minor 三項（波 1 審查＝整枝評議）：
- **① 鎖檔搬家** `.dkbo/bin/dk-msg` `redispatch()`：`flock` 的鎖檔從 `$dir/.panes.lock`（任務目錄根，結案時會被 commit 進記憶）改成 `$dir/.blocked/panes.lock`；`.blocked/` 在 `dk-task-close` 會整個刪掉。先 `mkdir -p .blocked`。註解改寫：所有改寫 `.panes` 的人都拿同一把鎖；mv 前重比內容的迴圈保留（拿鎖逾時仍照做，屬保險）。
- **② 同一把鎖** `.dkbo/bin/dk-spawn`：`--resume`／`--handoff` 刪舊列（grep -v → mv）與最後的 `>> .panes` append 都包進 `( flock -w 5 9 || true; … ) 9>"$dir/.blocked/panes.lock"`。`.dkbo/bin/dk-wave-close`：`--agent` 的改寫 `.panes`，以及整波收尾的 `: > .panes`（同檔、同類寫入，順手一併）也拿同一把鎖。逾時語意與 dk-msg 一致：等 5 秒拿不到仍照做，不讓鎖卡死流程。
- **③ 詞界比對** `.dkbo/bin/dk-wave-close` gate a2：`case "$vline" in *"$al:"*` 改成 `case " $vline" in *" $al:"*`（前面是行首或空白才算），`note:`／`if:` 不再冒充 `e:`／`f:` 的交代。
- 測試：06 +1（鎖檔在 `.blocked/panes.lock`、任務目錄根沒有 `.panes.lock`）；07 +1（另一行程拿著鎖兩秒，`dk-spawn` 的 append 與 `--resume` 各等到鎖才寫，且 `.panes` 只有一列）；08 +2（`--agent` 等鎖；`note:`／`if:` 反例：spawned a/e/f、裁定 `a: ok note: … if: …` → 擋下並點名 e、f，補上 `e: ok f: skipped (limit)` 才放行）。
## 測試
### 紅
$ tests/lib/bats-core/bin/bats tests/unit/06_msg.bats -f '整枝評議 Minor'
1..1
not ok 1 整枝評議 Minor①：redispatch 的鎖檔在 .blocked/panes.lock，不在任務目錄根（結案不被 commit 進記憶）
# (in test file unit/06_msg.bats, line 554)
#   `[ -f "$d/.blocked/panes.lock" ]' failed
$ tests/lib/bats-core/bin/bats tests/unit/07_spawn.bats -f '整枝評議 Minor'
1..1
not ok 1 整枝評議 Minor②：spawn 的 append 與 --resume 刪舊列都拿 .blocked/panes.lock
# (in test file unit/07_spawn.bats, line 286)
#   `[ "$status" -eq 0 ]; [ "$((t1 - t0))" -ge 1 ]' failed
$ tests/lib/bats-core/bin/bats tests/unit/08_wave_close.bats -f '整枝評議 Minor'
1..2
not ok 1 整枝評議 Minor②：--agent 改寫 .panes 前拿 .blocked/panes.lock
# (in test file unit/08_wave_close.bats, line 331)
#   `[ "$status" -eq 0 ]; [ "$((t1 - t0))" -ge 1 ]' failed
not ok 2 整枝評議 Minor③：裁定行的別名要詞界比對，note:／if: 不算交代了 e／f
# (in test file unit/08_wave_close.bats, line 337)
#   `run dk-wave-close; [ "$status" -eq 1 ]' failed
### 綠
$ tests/lib/bats-core/bin/bats tests/unit/06_msg.bats -f '整枝評議 Minor'
1..1
ok 1 整枝評議 Minor①：redispatch 的鎖檔在 .blocked/panes.lock，不在任務目錄根（結案不被 commit 進記憶）
$ tests/lib/bats-core/bin/bats tests/unit/07_spawn.bats -f '整枝評議 Minor'
1..1
ok 1 整枝評議 Minor②：spawn 的 append 與 --resume 刪舊列都拿 .blocked/panes.lock
$ tests/lib/bats-core/bin/bats tests/unit/08_wave_close.bats -f '整枝評議 Minor'
1..2
ok 1 整枝評議 Minor②：--agent 改寫 .panes 前拿 .blocked/panes.lock
ok 2 整枝評議 Minor③：裁定行的別名要詞界比對，note:／if: 不算交代了 e／f

相關檔全跑：
$ tests/lib/bats-core/bin/bats -c tests/unit/06_msg.bats tests/unit/07_spawn.bats tests/unit/08_wave_close.bats
132（全數 ok，無 not ok）
$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh
（無輸出，零警告）
$ tests/run.sh
1..724，723 ok，1 not ok：`not ok 487 bklog Minor②: 欄數閘走 dk_brief_ncols，不再內聯一份切欄 awk`（16_brief_check.bats:272，斷言 dk-brief-check 不含 `print nf`）——那是同波 backend-brief 本波正在改的 dk-brief-check／16，不在我的所有權，也不受我的改動影響。

取紅方式：新測試直接加在 worktree 跑、實作尚未動，沒有用 git stash／checkout。
### 修復輪 1（reviewer 波 2 Minor 1）
原本 07 那條的 `--resume` 段只量耗時 ≥1 秒，但最後的 `>> .panes` append 本身就會等鎖，拿掉刪舊列的鎖也照樣過——斷言分不出來。改寫同一條 @test（沒有新增 @test）：先把舊列的 pane 改成 `wC:p9`（stub 會再發 `wC:p2`，要分得出新舊列），持鎖 3 秒時在背景跑 `dk-spawn backend --resume`，約 1 秒後斷言舊列還在；等背景跑完再斷言只剩一列、舊列不在、`pane close wC:p9` 有記。

突變探針（在 scratchpad 的整倉副本裡做，worktree 沒動）：
#### 紅（拿掉 dk-spawn:77-79 的鎖）
$ # 突變：暫存副本裡拿掉 dk-spawn:77-79 的 flock 包裝（刪舊列不拿鎖）
$ tests/lib/bats-core/bin/bats tests/unit/07_spawn.bats -f '整枝評議 Minor'
1..1
not ok 1 整枝評議 Minor②：spawn 的 append 與 --resume 刪舊列都拿 .blocked/panes.lock
# (in test file tests/unit/07_spawn.bats, line 294)
#   `grep -q "^login-backend $old " "$d/.panes"' failed

#### 綠（原碼）
$ # 原碼（worktree，dk-spawn:77-79 有鎖）
$ tests/lib/bats-core/bin/bats tests/unit/07_spawn.bats -f '整枝評議 Minor'
1..1
ok 1 整枝評議 Minor②：spawn 的 append 與 --resume 刪舊列都拿 .blocked/panes.lock

$ tests/lib/bats-core/bin/bats -c tests/unit/07_spawn.bats
34（全數 ok）
$ tests/run.sh
1..724，全數 ok（rc=0；波 1 回報的 16:487 已被 backend-brief 修好）

## 自我審查
- 鎖的逾時沿用 dk-msg 既有的 `flock -w 5 9 || true`：寧可偶發競態也不讓 spawn/wave-close 卡死；dk-msg 那邊的內容重比迴圈仍能兜住。
- 07/08 的等鎖測試用秒級計時（持鎖 2 秒、斷言 ≥1 秒），只量下限，不會因機器慢而假紅；背景持鎖行程關掉 fd 3 與 stdout，不會讓 bats 掛住。
- `: > .panes`（整波收尾）加鎖是切片沒點名的，但同檔同類寫入、改動一行，列出供審查。
- dk-watch、dk-resume 只讀 `.panes`，沒改。
## 疑慮
- 無。16 的 487 請 backend-brief 那邊確認。

---
# 附：波 1 報告（原文，標題降一級）
### 做了什麼
- **AC7** `.dkbo/bin/dk-process`：以 `minor ` 或 `minor:` 開頭、但不合 `DK_MINOR_RE` 本文部分的行拒收（exit 2，stderr `dk-process: minor 行格式不符（要 "minor: …" 或 "minor <波號>: …"），整枝評議讀不到這種行`）。本文正規式由 `DK_MINOR_RE` 去掉 `^[^ ]+ ` 前綴得出，沒有另寫一份。
- **AC6** `.dkbo/bin/dk-msg` 的 `redispatch()`：對象是 `.panes` 裡 group=dev 且 `DK_WAVE` 開著時，刪 `.blocked/wave-N.<state 名>.done` 與 `wave-N.devdone`，並把 `.blocked/<agent>.spawn` 改寫成此刻 state 的 cksum。`deliver()` 在 `agent wait` 成功、`agent prompt` 之前（＝送達當下）判斷：TASK／BUG、收件者 group=dev、state 已是 `status: done` → 訊息尾端附 `（你已交付過：做完先改寫 state 再回 [FIXED]）`。200 字元限制照舊只驗領導打的本文。
- **AC5** `.dkbo/bin/dk-msg`：寄件者是領導、類型 TASK／BUG／DECISION／STOP、對象在 `.panes` 裡（＝本任務員工；雜務、已收工的人不在 `.panes`，維持前景）→ `nohup` 背景重跑自己（`DK_MSG_BG=1`，預設 `DK_MSG_TRIES=6` × `DK_MSG_WAIT_MS=300000` ＝ 30 分，兩者都可被呼叫端覆寫），前景印契約那一句後 exit 0。送達才 `redispatch`（沿用既有迴圈）。最終送不到：照舊記 `[UNDELIVERED]`，另外 `dk_process "undelivered <target> [<type>]"`（只在寄件者是領導時）；`dk-resume` 的 process 尾段印得出來（有測試）。
  - FIFO：每位收件者一個佇列檔 `.blocked/msgq-<target>`（每行一個背景 pid），前景在 spawn 後以 flock 附上 `$!`——連送兩則時排隊順序由前景決定，不看背景誰先醒。背景那一份只有自己是佇列頭才投遞；佇列頭的 pid 已不在（`kill -0` 失敗）就剔掉，免得後面整排卡死；佇列檔消失（任務被收）或等超過 `DK_MSG_QUEUE_SEC`（預設 3600 秒）就不排了、直接送。結束時（成功或失敗）由 `trap EXIT` 把自己移出佇列。
- 既有測試處理（ruling 見 process：`ruling: [自主] AC5 既有測試走提案 A`）：06 裡以領導身分送 TASK／BUG 並當場斷言的 6 條（「leader addressing … short role name」「[TASK] 送達後重設該列的 epoch…」「送不到的 [TASK] 不重設 epoch…」「AC16: [BUG] 也開啟新的一輪」「[TASK] 存下指派當下的 state cksum…」「指派時還沒有 state 檔…」）的 `run dk-msg` 前綴 `DK_MSG_BG=1`（直接走背景那一份的同步投遞核心），斷言與期望值一字未改。09 的 `redispatched()` 由 backend-watch 依領導 TASK 加同一前綴（不在我的可改欄）。05、11 不受影響（沒有以領導身分送指派型訊息給 `.panes` 成員），全套只看到 09 那兩條。

### 測試
新增：06 末尾 AC6 三條、AC5 五條；新檔 `tests/unit/36_process.bats` AC7 四條。

#### 紅
AC7（實作前，worktree 裡 dk-process 尚未動，只新增測試檔）：
```
$ tests/run.sh tests/unit/36_process.bats
not ok 1 AC7: minor task: x 拒收，process.md 沒多一行
#   `[ "$status" -eq 2 ]' failed
not ok 2 AC7: minor:x（冒號後沒空白）也拒收
#   `[ "$status" -eq 2 ]' failed
ok 3 AC7: minor: x 與 minor 2: x 照收，且整枝評議讀得到
ok 4 AC7: 一般行與 minority report 照收（不以 minor 空白或 minor: 開頭）
```
（3、4 是「其餘行為不變」的守門，實作前本來就該過。）

AC6（實作前，只新增測試）：
```
$ tests/run.sh tests/unit/06_msg.bats
not ok 47 AC6: 已交付的 dev 被 [TASK] 後不推聚合，改寫 state 為 done 後推一次
#   `[ ! -f "$d/.blocked/wave-1.backend.done" ]' failed
not ok 48 AC6: 已交付的 dev 收到的 [TASK] 尾端附「你已交付過」
#   `grep -q '^agent prompt login-backend \[TASK\] from leader-login: 補錯誤碼（你已交付過：做完先改寫 state 再回 \[FIXED\]）$' ...' failed
```
（49「還沒交付的 dev 與已交付的 qa 都不附尾註」是反向守門，實作前本來就過。）

AC5（把 worktree 複製（rsync）到獨立目錄 scratchpad/ac5 裡取紅，沒在共用 worktree 動 stash／checkout）：
```
$ tests/run.sh tests/unit/06_msg.bats
not ok 50 AC5: 領導的 [TASK] 當場返回並印背景提示，送達之後才 redispatch
#   `[ "$output" = "dk-msg: 改在背景等 login-reviewer-a 閒下來再送（結果記在 messages.log），你直接往下做" ]' failed
not ok 51 AC5: DECISION／STOP／BUG 也背景送；送給雜務與員工互傳照常前景
not ok 52 AC5: 背景那一份最終送不到：記 [UNDELIVERED] 與 process undelivered，epoch 不動
#   `[ "$status" -eq 0 ]' failed
not ok 53 AC5: 背景那一份預設最多等 30 分鐘（6 次 × 300000 ms），DK_MSG_TRIES 可覆寫
not ok 54 AC5: 同一收件者排著多則背景訊息時一次只送一則，照送出順序
```

#### 綠
```
$ tests/run.sh tests/unit/36_process.bats
ok 1 … ok 4（4/4）
$ tests/run.sh tests/unit/06_msg.bats tests/unit/36_process.bats
1..58，not ok 0 條
$ shellcheck .dkbo/bin/dk-msg .dkbo/bin/dk-process
（無輸出，rc=0）
```
完整測試（送 DONE 前一次，worktree 含同波夥伴未完成的變更）：`tests/run.sh` → 1..709，706 過；紅 3 條都不在我的檔：
- 09 #272「被重新指派後，上一輪留下的 status: done 不再擋住逾時」、#275「上一輪的 .timeout 已 delivered…」：`redispatched()` 以領導身分送 `[TASK]`，AC5 後變背景送、與後面的 `sed` 改 epoch 競態。領導已派 backend-watch 加 `DK_MSG_BG=1` 前綴（我在副本裡驗過：09 換成最新版後只有這兩條紅，其他 09 測試不受 AC5 影響）。
- 25 #552 Important4（backend-docs 進行中）。
全套 shellcheck 目前有一條 SC2016 在 `.dkbo/lib/brief.sh:29`（backend-brief 的檔，進行中），我的兩個檔零警告。

### 自我審查
- 背景送的判斷點放在收件者解析之後：`dk-msg reviewer-a` 這種短名先補成 `bklog-reviewer-a` 再查 `.panes`，才不會把短名誤判成雜務而走前景。
- `DK_MSG_BG=1` 同時是「背景子行程」與既有 dev→qa 背景送的防遞迴旗標；子行程重跑整支腳本，AC8／AC9 的提醒會再印一次但輸出進 /dev/null，無副作用。
- FIFO 的觀測：第一版 54 仍紅，是測試的觀測點錯了（gate 墊層在呼叫 stub 之前就擋住，stub log 當然沒有 wait 紀錄），改成墊層自己記 wait 次數後綠——不是實作問題。同一次排查發現：佇列檔被刪時背景那一份會空轉到 `DK_MSG_QUEUE_SEC`，已補「佇列檔不見就不排了」。
- `$!` 與背景那一份的 `$$` 是同一個 pid：`VAR=… nohup "$0" … &` 是簡單指令，fork 後 exec nohup 再 exec 腳本，pid 不變（54 綠即證明佇列頭比對成立）。
- 尾註判斷在「送達當下」：放在 `deliver()` 裡 `agent wait` 成功之後才讀 state，背景等了半小時也用當時的 state。
- 排除過的做法：「前景先試一次、忙才轉背景」——違反 AC5「一律…當場返回並印…」，而且既有「送不到 status 1」那條照樣會紅，沒有解掉衝突。

### 疑慮
- `DK_MSG_QUEUE_SEC` 是 dk-msg 內部的環境變數預設（同 `DK_MSG_TRIES` 類），沒寫進 settings.env，不算新增 settings 鍵；若 reviewer 認為算，可改成寫死一小時。
- 背景送之後，領導 `dk-msg` 的回傳碼永遠是 0（送不到只在 log 與 process 看得到）。run SKILL 的說明由 backend-docs 依契約補（AC15）。
- 本任務內領導跑主樹 dk-msg，這些新行為一次都沒生效；以上只由單元測試驗證。

### 修復輪 1（reviewer-a Important 1、Minor 7）
#### 根因
- I1 前半：背景子行程以「`.blocked/msgq-<target>` 在不在」決定要不要排隊，但只有領導→員工那條路徑會寫 pid，而佇列檔一建就永遠在 → 之後沒排隊的背景子行程（dev→qa 的 `[DONE]`、測試裡的 `DK_MSG_BG=1`）空等到 `DK_MSG_QUEUE_SEC`。改成前景排隊時一併傳 `DK_MSG_QUEUED=1`，子行程只憑這個旗標進佇列（保留「前景還沒寫下 pid 時子行程先等」的語意）。
- I1 後半：`queue_leave` 在 `set -e` 下，佇列只剩自己時 `grep -vx` 回 1，subshell 在 `mv` 前退出，pid 與 `.tmp` 留下。改成 `{ grep -vx … || true; }`。
- Minor 7：`redispatch` 的 `.panes` 讀改寫改用 `flock`（`.panes.lock`）讓多位收件者的背景那一份互斥；dk-spawn 的 `>> .panes` 不拿這把鎖（dk-spawn 不在我的可改欄），所以 mv 前再比一次 `.panes` 的 cksum，變了就重讀重寫（最多 5 次）。這條沒有新測試：競態視窗是毫秒級，寫不出不 flaky 的斷言；既有 epoch 測試全綠證明讀改寫本身沒壞。
#### 紅（在獨立副本 scratchpad/ac5，未改碼前）
```
$ tests/run.sh tests/unit/06_msg.bats
not ok 55 AC5 review I1: 佇列檔已存在時，dev→qa 的 [DONE] 背景那一份立刻送（沒排隊就不進佇列）
#   `wait_log 'login-backend -> login-qa \[DONE\]' "$d/messages.log"' failed
not ok 56 AC5 review I1: 最後一位送完離開佇列，自己的 pid 與 .tmp 都不留
#   `[ ! -s "$d/.blocked/msgq-login-reviewer-a" ]' failed
```
#### 綠
```
$ tests/run.sh tests/unit/06_msg.bats tests/unit/36_process.bats   → 全部 ok（06 共 56 條）
$ tests/run.sh   → 1..716，716 ok，not ok 0
$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh   → rc=0
```
