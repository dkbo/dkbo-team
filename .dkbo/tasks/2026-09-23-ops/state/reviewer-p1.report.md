# reviewer-p1 計畫審查 — 營運回饋修補（panova headermerge）

## 做了什麼
讀 request.md、brief.md、process.md，並唯讀核對 brief 引用的現況前提（dk-watch `handle_limit`／整波逾時／dev 聚合、dk-msg 的 dev `[DONE]` 閘與 `--ack`、dk-task-close 第 12／108／173 行、dk-timeline、`lib/common.sh` 的 `dk_env_set` 鎖與 `dk_ts_minutes`、`templates/state.md`、`lib/ownership.sh` 的 `dk_touched`、`kinds/*.sh` 的額度式子、install.sh、既有測試對 dev `[DONE]` 的使用）。沒有改任何檔。
標記：【必改】計入結論 N；【建議】不計。

## 測試
計畫審查，沒有 diff、沒有測試可跑。唯讀核對用的指令：`grep`／`sed -n` 讀 `.dkbo/bin/{dk-watch,dk-msg,dk-task-close,dk-timeline,dk-wave-open}`、`.dkbo/lib/{common,ownership,brief,review}.sh`、`.dkbo/templates/state.md`、`.dkbo/install.sh`；`grep -ln DONE tests/unit/*.bats` → 用 dk-msg 送 `[DONE]` 的只有 06_msg（backend-flow 擁有）與 11_chore（走雜務分支、不受 AC10 影響），所以 AC10 不會打到別人擁有的測試檔。

## 需求覆蓋
| request 條目 | brief 對應 | 判定 |
|---|---|---|
| 一.1 熔斷跨任務＋恢復時間＋派 reviewer 前先查 | AC1、AC2、AC3、AC6 | ✅（但 AC3 超出範圍，見 R1） |
| 一.2 `[LIMIT]` 證據（`.blocked/<agent>.limit`＋訊息帶命中行） | AC5、AC12 | ✅ |
| 一.2 附帶：codex 快到額度選單在寬 pane 被誤判 | AC4 | ✅ |
| 一.3 改 brief 不同步切片（重產指令，或 dk-msg 警告） | AC7、AC8 | ✅ 兩條建議都做了 |
| 一.4 state 格式不驗證（touched 一行 brace glob，**缺 current／todo／report**） | AC10 | ❌ 只接住一半，見 R2 |
| 一.5 波中加範圍，逾時不重新起算 | AC7 | ❌ 漏了「加人」那一半，見 R3 |
| 一.6 結案後 report 是舊的（結果行、時間表） | AC11 | ✅ 前提已核對：第 108 行 `fill_timeline` 確實在第 173 行 `task-close merged` 之前；`dk_ts_pick` 取最後一筆，失敗重試後再結案也對 |
| 二.7 發訊息前先讀收件匣 | AC9、AC12 | ✅（`dk-msg --ack` 已存在、LEADER.md 第 9 行已叫領導 ack，AC9 的錨點成立） |
| 二.8 UI 任務先請人看畫面 | AC12 | ✅（措辭見 Minor 5） |
| 三 panova 專案面（dev server curl 等） | 無 | 可接受（人沒要求動），但建議目標段明寫「不做」，見 Minor 6 |
| 0.11.2 已知仍未處理那句 | AC4、AC14 | ✅ |

- **R1【必改】AC3 的 `dk-spawn` 拒絕超出需求，而且把誤判的代價從「本任務」放大到「整個專案、每個角色」。** request 一.1 只說「派 reviewer 前先查、沒過恢復時間就跳過」。AC3 另外讓 `dk-spawn` 對**角色檔預設的 kind** 也拒絕 —— 所有角色預設都是 claude。已知的誤判前例正是 claude reviewer（highfix：交報告後被自己引用的額度字樣熔斷），而本任務自己的「已知風險」段也承認員工畫面必然出現這些字樣。0.12.0 之後，一次這種誤判會寫一列 `guess`（+5h），下一個任務的 `dk-spawn backend` 就直接被拒，要領導先 `dk-kind up claude` 才派得動任何人；而領導自己就是 claude，claude 真的撞額度時拒絕也沒有保護到什麼。建議改寫（二選一，這是選 A 或 B，請領導裁定並寫進 brief）：
  - A：`dk-spawn` 只在 `--kind` **明寫**且該 kind 專案層未恢復時拒絕；角色檔預設的 kind 命中時只在 stderr 印同一句（加 `dk-kind up <k>`）然後照派。
  - B：`dk-spawn` 只拒絕 `exact` 列；`guess` 列一律只警告。
  兩案都要在 AC3 寫清楚，並在 07_spawn 各給一條「拒絕」與「只警告」的斷言。
- **R2【必改】request 一.4 明寫的「缺 current／todo／report」沒有被接住。** AC10（b）只在 state「有 `report:` 鍵時」驗路徑；translator 那份 state 恰好**沒有** `report:`，照 AC10 會直接放行。請補（c）：dev 的 state 必須有 `status`、`touched`、`report` 三個頂格鍵（缺任一就 exit 2，訊息指出缺哪個）；`current`／`todo` 要不要必備請一併裁定。如果決定不驗，brief 要寫一句理由，不能靜默丟掉。
- **R3【必改】AC7 刪了 `.blocked/wave-N.timeout`，卻沒刪 `.blocked/wave-N.devdone`，panova 的「加 designer」那一半會壞。** 現況（dk-watch 第 255–270 行，標記在第 264 行）：本波 dev 全員 done 後推一次聚合 `[DONE]`，並在 `wave-N.devdone` 寫 `delivered`，之後不再推。panova 波 2 正是 dev 2 分鐘就交、之後才加範圍與加 designer。照 AC7 refresh 後再 spawn 新成員，新成員交 `[DONE]` 時 devdone 早已是 `delivered`，dev 的 `[DONE]` 又只落盤不叫醒領導 —— 領導永遠收不到。請在 AC7 的「刪掉 `.blocked/wave-N.timeout`」後面加「與 `.blocked/wave-N.devdone`」，並在 18_wave_open 或 09_watch 補一條：refresh 後新加的 dev 寫 done → dk-watch 再推一次聚合。注意 `.blocked/` 的語意在 dk-watch（backend-kinds），刪檔在 dk-wave-open（backend-flow），要進共用契約「wave-open --refresh」那一列的形狀欄。

## 驗收標準可驗證性
- AC1：**R4【必改】與全域約束打架。**「寫檔走 flock（同 `dk_env_set` 用的 `.sessions/*.lock` 手法）」—— `dk_env_set` 的鎖是 `$DK_ROOT/.sessions/<任務目錄名>.lock`（common.sh 第 156 行），照抄就會多出 `.sessions/kinds-down.lock`，違反「新增的執行期檔只有 `.dkbo/.sessions/kinds-down` 一個」。reviewer 用任一種寫法都會被另一條判不合規。請擇一寫死：（i）約束改成「kinds-down 與它的鎖 `kinds-down.lock`」；或（ii）直接對 `kinds-down` 本身 `flock`，且寫入就地改寫（不能 `mv` 換 inode，否則鎖失效）。其餘可判定（「更新成較晚的恢復時間，不重複」清楚）。
- AC2：**R5【必改】codex 的退路沒有定義，「date -d 不可用走退路」那條測試的期望值因此無法判定。**「先試 `date -d`，失敗或非 GNU 就走退路」—— 退路是什麼？如果是「+5h 標 guess」，那麼 macOS 上 codex 的「Oct 11」會被當成 5 小時後恢復，request 一.1 的核心（codex 要到 Oct 11 才恢復）在 BSD 上等於沒做。本倉已有可攜的純算術：`lib/common.sh` 的 `dk_ts_minutes`（days_from_civil，只要時區一致就能相減）。可驗證的改寫：「codex 樣本先試 `date -d`；不可用時用月份表把它轉成 `YYYY-MM-DDTHH:MM`（12 小時制換 24 小時制），以 `dk_ts_minutes(目標) − dk_ts_minutes(dk_now)` 加到 `date +%s`，結果標 `exact`；只有兩種都解析不到才 +5h 標 `guess`。測試：同一段 codex 樣本在『`date -d` 可用』與『PATH 上的假 `date` 拒絕 `-d`』兩種環境算出的 epoch 相差 ≤ 60 秒」。另外序數後綴要寫成 `st|nd|rd|th`（1st、2nd、3rd、22nd），不是只有 `th`，並補一條非 `th` 的樣本。
- AC3：可判定，但範圍問題見 R1。stderr 原句是英中夾雜（`is down until …; skipped`），若是沿用既有句型請在 AC 註明「沿用 dk_review_kinds 既有句型」，否則違反「面向使用者的文案是繁體中文」。
- AC4：可判定（三條樣本、三個期望）。刻意不寫出那個片語可以理解；但請在 AC 寫「移除的是 `KIND_QUOTA_RE` 的第 3 個分支」這種位置描述，讓 reviewer 不必看畫面也能對照（目前寫「兩個英文字的通用片語」，而四個分支裡有兩個都是兩個英文字）。
- AC5：可判定。建議補一句「輪詢路徑（09_watch）與事件路徑（26_watch_events）各一條斷言都寫出 `hit:` 行」，兩條路徑都會進 `handle_limit`，只測一條會漏。
- AC6：**R6【必改】`dk-kind up <k>` 的「不在清單裡」指哪張清單沒寫。** 全域約束規定 reviewer 逾時造成的熔斷**只記本任務**，所以會出現「k 在 `.task.env` 的 `DK_KIND_DOWN`、不在 kinds-down」的狀態 —— 那正是領導最想用 `dk-kind up` 解的情況。照現文，實作者可以印「不在清單」然後什麼都不做，也可以照樣從 `DK_KIND_DOWN` 拿掉，兩種都說得通，員工會在波中 ESCALATE。建議改寫：「兩張清單（kinds-down、綁著任務時的 `DK_KIND_DOWN`）都拿掉；兩張都沒有才印說明、exit 0；process 的 `kind <k> up` 只在真的拿掉東西時記」。另外 `<k>` 不是 `kinds/*.sh` 裡的 kind 時要 exit 2 還是 0，也寫一句。
- AC7：除了 R3，其餘可判定。
- AC8、AC9：可判定。AC9 建議補一句「dev 只落盤的 `[DONE]` 也算未 ack」（這是想要的行為，但現文沒說，實作者可能以為要排除）。
- AC10：**R7【必改】`touched` 的合法文法沒定義清楚，而且跟 `templates/state.md` 打架。** 範本（與 PROTOCOL 的範例、`08_wave_close.bats` 第 229 行的夾具）都是**裸的** `touched:`、底下零項。AC10（a）說「必須是 `touched: []` 或其下接 `  - <路徑>` 清單」—— 裸 `touched:` 零項算不算？照字面不算，那麼每個還沒改檔的 dev、以及照範本起手的 state 都會被擋。另外兩種同樣會讓 `dk_touched`（ownership.sh 第 30 行）靜默吃掉的寫法沒被涵蓋：頂格的 `- path`（`/^[^ ]/` 會直接結束清單），以及清單項本身是 brace glob／萬用字元（`  - src/i18n/{a,b}.json`，panova 的正是 glob，只是寫在同一行）。可驗證的改寫：「`touched:` 那一行冒號後只能是空白或 `[]`；從下一行到下一個頂格行之間，每個非空行都必須符合 `^  - ` 開頭、且路徑不含 `{`、`}`、`*`、`?`；零項合法」。這條文法要由 backend-flow（驗證端）擁有、backend-docs（寫範本與 PROTOCOL）消費，請在共用契約加一列，否則同一波兩人各寫各的。
- AC11：可判定，前提已核對屬實。
- AC12：可判定性靠 AC13 的斷言；請在 AC13 寫出三條新規範各自要 grep 的關鍵字（例如 `wave-open <N> --refresh`、`未 ack`、`請人看`），否則「補斷言守住」沒有對照物。另外改寫 `[LIMIT]` 那條時要保住 `04_docs.bats` 第 41 行已斷言的 `dk-wave-close --agent`。
- AC13、AC14、AC15：可判定。

## 檔案所有權
- 三列之間沒有可改檔重疊；每條 AC 要動的檔都有擁有者（AC1–6 → backend-kinds；AC7–11 → backend-flow；AC12–14 → backend-docs）。`tests/unit/34_kind_down.bats` 編號未被佔用（現有到 33）。
- AC10 新驗證只會打到 06_msg（flow 自有）；11_chore 走雜務分支不受影響；波次表那句「先 grep、不在所有權內先 ESCALATE」核對後不會觸發。
- AC11 的 `結果：` 行錨點在 `templates/report.md` 第 2 行（`結果：merged | abandoned   分支：…   波數：`），三個空白分隔成立，不需要動範本 —— 沒有遺漏。
- 新 bin `dk-kind`：install.sh 第 35 行是 `chmod +x .dkbo/bin/*`，不需要新 symlink，符合約束；但 backend-kinds 建檔時要自己 `chmod +x`（git 記的是檔案模式），見 Minor 3。
- 獨佔資源欄全是 `—`：純 bash＋假 herdr、零 token，沒有 port／db，合理。
- 見 R3、R7：兩個跨成員的語意（`.blocked/wave-N.devdone` 誰刪、`touched` 文法誰定）目前沒有落在共用契約表。

## 波次切法
- 三人同一波並行合理：kinds／flow 碰的檔不相交，docs 只依共用契約的原句寫文件，契約都有指定擁有者。
- docs 的 CHANGELOG「其餘每一條變更」在實作者交差前就要寫，只能照 brief 寫；可接受，但建議 dk-wave-close 前領導對一次 CHANGELOG 與兩份 report 的「做了什麼」。
- 審查欄只填在第一列 `預設`，本倉 `DK_REVIEW_KINDS` 只有 claude，與 process.md 的 ruling 一致。
- R3、R7 補進共用契約後，波次不必改。

## Minor
1. AC2 的 agy 樣本：「Resets in <N>h<M>m」建議寫成小時可省（剩不到一小時時可能只印 `<M>m`），並補一條無小時的樣本；若實測從沒出現過，就在 AC 寫明「只認有 h 的形狀，其餘走 guess」。
2. AC4 移除該分支後，codex 真的只印那個片語的暫時性限流也不再熔斷 —— 這是想要的（暫時性限流不代表額度用完），建議 CHANGELOG 明寫，免得下一個人以為是回歸。
3. `dk-kind` 要 `chmod +x` 才會以 100755 進 commit；建議 backend-kinds 的完成條件加一句 `git ls-files -s .dkbo/bin/dk-kind` 是 100755（或讓 34_kind_down 直接執行它而不是 `bash dk-kind`）。
4. AC5／AC6：`dk-kind status` 會把第一條 hit 原文印在執行者的畫面上；領導不在 `.panes` 裡不會被 dk-watch 判，但請在 run/SKILL.md 提一句「不要叫員工跑 `dk-kind`」，否則員工 pane 會自己把自己熔斷。
5. AC12「最後一波結波後」建議改成「計畫中的最後一波結波後、跑 `dk-review-pack --task` 之前」—— panova 的情況是波 1 當時就是計畫中的最後一波，後來才長出波 2。
6. 目標段建議加一句「不做：request 三的 panova 專案面（dev server curl 等）」，讓結案時的需求覆蓋有明確出口。
7. AC8 只寫了「領導 dk-msg <員工>」，建議明寫判斷依據（寄件者＝`dk_leader_name`），員工之間互傳不提示。

## 結論
要改 7 處

## 自我審查
- R1–R7 每條都核對過現況碼或範本，不是憑 brief 字面推測：R3 對 dk-watch 第 255–270 行，標記在第 264 行、R4 對 common.sh 第 156 行、R5 對 common.sh 的 `dk_ts_minutes`、R7 對 templates/state.md 與 ownership.sh 第 30 行。
- R1 是「選 A 或 B」的設計題，我給了建議但沒替領導決定。

## 疑慮
- AC4 刻意不寫出被移除的片語，我無法從 brief 單獨確認移除的是哪一個分支是對的（需要 panova spike 樣本），只能判定 AC 的三條期望本身可驗證。
