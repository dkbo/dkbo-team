# rest-reviewer-p1 報告（計畫審查）

審查對象：`request.md`（人的原話＋BACKLOG 6 列逐字）與 `brief.md`。依 brief 切片不讀程式碼的原則，但每條意見的**前提**都在主樹 master（810b931）核對過，核對方式寫在各條後面。

## 需求覆蓋

| request 項 | brief 對應 | 判定 |
|---|---|---|
| 1 gate c 的 `HERDR_*` | AC1 | ✅ 含 BACKLOG「先確認 dkbo 自己的測試不靠繼承的 `HERDR_*`」 |
| 2 run.sh 不跑 shellcheck | AC2（ruling：做成 37 bats、沒裝 skip） | ✅ BACKLOG「沒裝印 WARN 不擋」由 skip 接住，process.md 有 ruling |
| 3 `setup_project` 帶進主樹狀態 | AC3 | ✅ 採 BACKLOG 的折衷做法，髒主樹測試也有 |
| 4 chore-close 空 branch 沒測試 | AC4 | ✅ 前提已核對：`dk-chore-close:36` 就是 `[ -n "$branch" ] \|\| branch="-"`，拿掉後空 branch 會走 `merge` 分支、印 `merge conflict` exit 3，所以新測試能紅 |
| 5 守望靜默死亡 | AC5 | ✅ 大致有。BACKLOG 建議的 dk-resume／dk-spawn 檢查，目前已經有了（run SKILL:16「dk-resume、dk-wave-open、dk-spawn 都會就地重啟」），brief 只補 dk-msg 是對的 |
| 8 `dk_owned`／`first_glob` 裸 `awk -F'\|'` | AC6 | ✅ 前提已核對（`lib/ownership.sh:12`、`dk-spawn:57`）；另外擴到 dk-brief-check 136/143，見下方可驗證性 ④ |
| 「都處理完才會 push」 | 目標「不做」 | ✅ |
| 文件＋BACKLOG 收尾 | AC7、AC8 | ⚠ 見下方 ① |

**① 必改：PROJECT.md 會留下一句不再成立的話。** `.dkbo/PROJECT.md` 第 4 行（測試指令）現在寫的是「shellcheck **不在** run.sh 裡……目前沒有機械閘守它」，而且列的檔案集合少了 `install.sh` 與 `tests/run.sh`。37 上線之後這句就錯了，但 AC7 只要求在「目錄慣例」那行補 37，沒有要求改這句。BACKLOG 那一列本身就點過「PROJECT.md 之前還寫錯說 run.sh 會跑」，同一種文件漂移不該再來一次。
改寫：AC7 加一句「PROJECT.md 測試指令那行改成：shellcheck 由 `tests/unit/37_shellcheck.bats` 守（沒裝就 skip），檔案集合同全域約束；刪掉『目前沒有機械閘守它』」。

## 驗收標準可驗證性

AC1、AC2、AC4、AC8 能明確判定過或不過。AC3 可以驗（有一點副作用，列在 Minor）。AC7、AC9 可以驗（有一個用詞歧義，列在 Minor）。有問題的是下面幾條：

**② 必改：AC5 ⑤ 讓 `--ensure` 多了很多個呼叫端，但 `--ensure` 沒有鎖，會起兩隻守望。** 核對：`dk-watch:45-51` 與 `ensure_events`（`:34-41`）都是「`alive` 判定 → `nohup … &` → `dk_env_set` 寫 pid」三步，中間沒有任何鎖（`dk_env_set` 的 flock 只包住寫檔那一步）。原本只有領導的腳本會依序呼叫；AC5 ⑤ 之後，每一則 `dk-msg` 都會呼叫。四人波的 dev 常在幾秒內接連送 `[DONE]`，如果那時守望剛好死了，兩個 dk-msg 會各起一隻 poll（和一隻 events）。後寫的 pid 蓋掉先寫的，先起的那隻就沒人追蹤：`dk-task-close` 殺不到它，它會一直推重複的 `[BLOCKED]`／`[TIMEOUT]`／聚合 `[DONE]`（`.blocked` 標記的「檢查再寫」不是原子的）。events 還會兩隻同時 `assess` 同一個審批畫面。
改寫：AC5 加「⑥ `--ensure`（poll、events、chores 三條）整段用 flock 串行化（鎖檔沿用 `$DK_ROOT/.sessions/<任務目錄名>.lock`，或另開 `.watch.lock`；`dk_env_set` 在鎖內呼叫時注意不要自鎖）」。09 加一條：守望已死，並行跑兩個 `dk-watch --ensure`，結束後 `ps` 裡這個任務的 `dk-watch$` 行程只有一隻，process 只有一行 `watch restarted`。

**③ 必改：AC5 ③ 規定收到 HUP 就結束，這會讓守望比現在更容易死。** 現在是用 `nohup` 起，HUP 被忽略；BACKLOG 猜的死因正好是啟動它的那次呼叫結束時整個行程群組被收掉。③ 寫的是「收到 HUP／INT／TERM 時先追加 signal 行再結束」。照這樣做，setsid 路徑上的守望收到 HUP 就會自己退出，跟本條要修的問題方向相反。（nohup 路徑上 HUP 在進程啟動時就被忽略，bash 的 trap 設不上去，所以兩條路徑的行為還會不一致。）
改寫：「HUP：追加 `signal HUP` 行後**繼續跑**（等同 nohup 的語意）；INT／TERM：追加 signal 行後結束」。09 的 signal 測試改成兩條：TERM 會寫 signal 與 exit 行；HUP 只寫 signal 行，行程仍然活著。

**④ 必改：AC6 的三條新測試有兩條在舊碼上紅不了，和 AC9「每位 dev 附取紅紀錄」衝突。**
- 16（「波次表『做什麼』欄含 `\|` 時成員檢查照常」）：`dk-brief-check:136/143` 用 `awk -F'|'` 只取第 1 欄（波號）和第 3 欄（成員），「做什麼」是第 4 欄，它裡面的 `\|` 只會讓第 4 欄之後的欄位錯位，第 1、3 欄不受影響。所以這條測試在舊碼上本來就會過，backend-gate 取不到紅，只能 ESCALATE 或硬湊。
- 22（「別的表第 2 欄剛好等於成員名時不會被當成所有權列」）：舊的 `dk_owned` 是對整份 brief 找**第一個**符合的列就 `exit`，而模板裡 `## 檔案所有權` 排在共用契約和波次表**前面**，所以舊碼一樣會先命中正確的那列，測試照樣過。另外「第 2 欄」可以讀成 awk 的 `$2`（第一格），也可以讀成表格的第二格，兩種讀法不同。
改寫：22 的誘餌列要放在 `## 檔案所有權` **之前**的段落（例如 `## 目標` 裡一張表），而且誘餌列的**第一格**等於成員名、第二格是別的 glob。斷言：舊碼判斷那個 glob 為「擁有」（紅），新碼判斷為「不擁有」。16 那條改成明寫「回歸守護，舊碼本來就綠、不要求取紅」，或者直接刪掉；如果要改成紅得了的案例，就把 `\|` 放在第 3 欄之前的欄位，但現實裡不會出現這種 brief，所以不建議。dk-brief-check 的改動本身可以留著（為了一致），只是 AC 要說清楚它不是修 bug。

**⑤ 必改：AC5 有兩個測試描述，照字面寫會變成競態或抓錯路徑。**
- ①「啟動後立刻 `alive` 判定為真」：`alive` 看的是 `ps -o args=`。`&` fork 出來、還沒 exec 之前的那一瞬間，子行程的 args 仍然是父行程的 `dk-watch --ensure`，不符合 `dk-watch$`，所以「立刻」判定會偶發紅。本專案已經被「改送法讓舊測試變競態」咬過。
  改寫：「`--ensure` 印出的 pid，在 2 秒內（輪詢）會成為 `ps -o args=` 以 `dk-watch`（poll）或 `dk-watch --events` 結尾的行程；接著再跑一次 `--ensure` 會印 `running (pid 同一個)`」。另外寫明不要用 `setsid -f`，因為它一定 fork，`$!` 會變成 setsid 自己。
- ⑤「寫完 messages.log 之後跑一次」：`dk-msg` 有好幾個寫 log 的出口（`:122` dev 對 leader 的 `[DONE]` 只落盤就 `exit 0`、`:202`、`:216`、`:258`）。事故的路徑正是 `:122`。如果實作者只把 ensure 放在檔尾的送達路徑，事故路徑照樣叫不回守望，而現在的測試描述「`dk-msg` 在守望已死時把它叫回來」用任何一條路徑都能通過。
  改寫：「06 的叫回測試走 **dev 對 leader 送 `[DONE]`（只落盤、不送達）** 那條路徑」，另外加一條一般 `[QUESTION]` 送達路徑。

## 檔案所有權

- 四人的可改欄沒有重疊，每條 AC 要動的檔都有人擁有：AC1、AC6 → backend-gate；AC5 → backend-watch；AC2–AC4 → backend-test；AC7、AC8 → backend-docs。✅
- 交叉引用核對過（`grep -l`）：`dk-msg` 也被 04／05／11／18／25 引用，但 `tests/helpers.bash:36` 預設 `export DK_NO_WATCH=1`，AC5 ⑤ 在那些測試裡是 no-op，不會讓它們變紅。✅ `ownership.sh` 只被 08、22 引用，都在 backend-gate 手上。✅ `CHANGELOG` 被 21、25 引用，21 會驗 `^- 測試：N bats（+M；` 的格式，backend-docs 照格式填就不會紅。✅
- 獨佔資源：四人都填 `—`。唯一的共用執行環境是 09 的一條會起真守望的測試（在夾具裡跑，不碰主樹），沒有問題。✅
- 小缺口（不是必改）：`tests/unit/21_version.bats` 的「首節列出本版每一條變更」清單沒有人擁有，所以本任務新增的 CHANGELOG 條目沒有測試守著。想守就把 21 劃給 backend-docs，並寫進 AC7。

## 波次切法

**⑥ 必改：backend-test 的完成條件「全套綠」在波內做不到。** 同一波四人共用一個 worktree，而 backend-watch 和 backend-gate 都是「先寫紅測試再實作」。backend-test 跑全套的時候，夥伴的紅測試、還沒寫完的 bin，以及 37 對夥伴半成品跑出的 shellcheck 警告，都可能讓全套變紅，而這些都不在 backend-test 的控制範圍內。它會卡住，或者去 ESCALATE 一件不是它的問題。AC3 的「改完後所有既有測試仍綠（report 附全套結果）」也是同樣的問題。
改寫：backend-test 的完成條件改成「36／11／37 全過；全套跑一次，report 逐條列出失敗、標明屬於哪位夥伴的檔。helpers.bash 造成的回歸由 backend-docs 在三則 `[DONE]` 到齊後的完整實跑把關」。這和 backend-docs 最後跑全套的安排剛好接得上。

其他：
- 順序合理。四個 dev 之間沒有產出依賴：AC5、AC1+AC6、AC2–4 各自獨立。backend-docs 靠兩個共用契約逐字抄寫，而且等三則 `[DONE]` 到齊才填條數，安排是對的。✅
- 兩個共用契約都有指定擁有者，形狀寫得夠具體。✅ 如果採納 ②，鎖檔路徑屬於 backend-watch 的內部細節，不必進契約。

## Minor

1. AC7「測試那一行的條數與**增量**」：0.16.0 節現在是 `724 bats（+68；…`，+68 是相對 0.15.0 的 656。併進同一節之後，增量應該寫「實跑值 − 656」（整節累計），不是本任務自己的增量。建議明寫，免得 backend-docs 寫成 `(+N)` 本任務增量，和節內的其他數字不一致。另外，如果之後有修復波新增測試，這個條數會過期；修復波要重填（backend-docs 要回來，或由領導在結案前重填）。
2. AC3 的副作用：`.dkbo/tasks/BACKLOG.md` 也在 `tasks/` 底下，(b) 會把夾具裡的 BACKLOG 還原成 HEAD 版，而 backend-docs 在 worktree 裡改的 BACKLOG 不會進夾具。目前沒有測試讀夾具裡 BACKLOG 的內容（10_resume 是自己覆寫，14 讀的是安裝後的專案），所以不會出錯。但這和 AC3 自己說的「未 commit 的 `.dkbo/` 改動仍要進夾具」原則有例外，建議在 helpers 的註解裡寫一句。
3. AC3 的 git 呼叫會在**每一條**測試的 setup 裡跑，而同波四人共用一個 worktree、可能同時在跑測試。建議用 `git --no-optional-locks` 或 plumbing（`ls-files --others --exclude-standard`、`diff-index --name-only HEAD`），避免 `git status`／`git diff` 順手刷新 index 去搶 `.git/index.lock`。
4. AC5 ④「log 裡該 pid 的最後一行」：比對要看詞界（` pid 12( |$)`），不然 pid 12 會吃到 pid 123 的行。
5. AC5 ③ poll 模式收到 TERM 時，bash 要等前景的 `sleep "$interval"` 結束才會跑 trap；09 的 signal 測試要用很小的 `--interval`，不然會等滿一個 interval。events 模式的 `wait` 會馬上被打斷，但子行程 `herdr pane wait-output` 會變孤兒；可以接受，建議在註解裡交代一句。
6. AC1：helpers 自己 export 的 `HERDR_STUB_LOG`／`HERDR_STUB_RESPONSES` 也是 `HERDR_*`，一樣會被剝掉。確認方式裡應該點名「測試端每條都在 setup 重新 export，不依賴 gate c 傳進來」，並核對 `tests/run.sh` 本身不讀 `HERDR_*`（核對過，它不讀）。
7. AC7 可以加兩條 grep 條件讓它可以機械判定：run SKILL 第 16 行同時含 `dk-msg`、`watch.log`、`watch died`。

## 結論
要改 6 處

## 測試
不適用: 計畫審查，沒有程式碼可測。唯讀核對用的指令：`grep -l <檔名> tests/unit/*.bats`（交叉引用）、`shellcheck …`（現況 rc=0，37 會實跑而不是 skip）、`sed -n` 讀 `dk-watch:18-56,330-390`、`dk-msg:110-146`、`dk-chore-close:36`、`lib/ownership.sh:12`、`dk-spawn:57`、`dk-brief-check:136,143`、`tests/helpers.bash:27-36`、`tests/unit/21_version.bats:44-56`。
