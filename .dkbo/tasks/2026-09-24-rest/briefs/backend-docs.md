# BACKLOG 剩餘六條（測試與守望） — 給 backend-docs 的切片（波 1）
由 dk-wave-open 產生，只讀。完整 brief 在 /home/bal/project/teamflow/.dkbo/tasks/2026-09-24-rest/brief.md。

## 目標
收掉 BACKLOG 裡現在就能動手的六條（request.md 逐字列出）：gate c 不再把 `HERDR_*` 傳給專案測試、shellcheck 進測試套件、測試夾具不再帶進主樹的進行中任務、chore-close 空 branch 的守衛有測試守著、
守望程序死掉會留遺言且有人把它叫回來、所有權比對看得懂 `\|` 跳脫。
不做：BACKLOG 其餘四條（agy 信任詢問、codex 只有時分、多 repo 交棒實跑、`setup.<名>.log` 體積）；`DK_SETUP_CMD`（dk-leader）的環境不動；不 push（人說全部處理完才 push，結案後由人決定）。

## 全域約束（全文）
bash 3.2+；不得使用 bash 4 語法（關聯陣列、${x^^}、declare -A、mapfile）；依賴只有 herdr 0.9.0、git ≥ 2.17、jq ≥ 1.5、flock，不得新增必要依賴；`setsid` 是選用的（有才用，沒有照舊 `nohup`，macOS 沒有它）；`date -d`／`date -r` 不得使用
shellcheck 零警告（`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh tests/run.sh`）
不新增 settings.env 鍵、不新增 `.task.env` 鍵、不新增 bin、不新增 skill；新測試檔只准 `tests/unit/37_shellcheck.bats` 一個
否定斷言一律用 tests/helpers.bash 的 refute_grep（grep 類）或 refute（其他指令），不得寫 `! cmd`；`35_test_hygiene.bats` 會擋
既有測試語意不變：不刪、不放寬，只允許新增斷言；`04_docs.bats` 的行數上限不得放寬（`skills/run/SKILL.md` ≤60、`PROTOCOL.md` ≤120）——補規則要改寫既有句子收進去
改任何檔之前先 `grep -l <檔名> tests/unit/*.bats`：引用它的測試檔不在你的可改欄、而你的改動會讓它紅，就 `[ESCALATE]`，不要自己改
面向使用者的文案是繁體中文；不升版：變更併入 CHANGELOG 既有的 0.16.0 節（0.16.0 還沒 push、沒打 tag，ruling 見 process.md），`.dkbo/VERSION` 與 README 的 `VER=` 不動
例外：本任務的成員**可以**修改 `.dkbo/` 底下的腳本、規則檔與 skill 文件，以及 `.dkbo/tasks/BACKLOG.md`（PROTOCOL 停止條件「不改 .dkbo/ 規則檔」在本任務不適用；ruling 見 process.md）；但只能改所有權表劃給自己的檔
編輯一律用切片「## 倉庫」段的 worktree 路徑；`$DK_ROOT` 指向主樹，只拿來跑 `dk-msg`，不得當編輯路徑
取紅一律 cp 到獨立目錄或 `git archive <base>` 解到暫存目錄做，不在 worktree 用 `git stash`／`git checkout -- <檔>`（同波四人共用一個 worktree）
領導跑的是主樹的腳本：本任務的新行為（setsid、watch.log、dk-msg 叫回守望、gate c 剝 `HERDR_*`）在本任務內一次都不會生效；report 不得宣稱「本波已用到」
backend-watch、backend-gate、backend-test 送出 `[DONE]` 給 leader 之後，再前景送一則同內容的 `[DONE]` 給 backend-docs（dev→dev 前景送）；backend-docs 等三則都到了才跑完整測試填條數

## 你的波次
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
| 1 | 文件 | backend-docs | AC7、AC8：run SKILL 的 watcher 句改寫（守住 ≤60 行）、PROJECT.md 的測試慣例、CHANGELOG 0.16.0 節追加條目、刪 BACKLOG 6 列。條目與行格式照「共用契約」表逐字抄；等另三位的 `[DONE]` 都到了，在 worktree 跑完整 `tests/run.sh`，把 CHANGELOG 的測試條數填成實跑值再送 `[DONE]` | M | 04/21/25 全過；全套實跑綠（helpers 回歸在這裡把關，紅了對擁有者送 `[BUG]` 並回報 leader）；CHANGELOG 測試條數等於實跑值 |  |

## 倉庫
/home/bal/project/teamflow/.worktrees/rest
編輯一律用上面的 worktree 路徑；$DK_ROOT 指向主樹的 .dkbo/，只拿來跑 dk-msg 等 bin，不得當編輯路徑

## 你的檔案所有權
| 成員 | 可改 | 只讀 |
|---|---|---|
| backend-docs | CHANGELOG.md, .dkbo/skills/run/**, .dkbo/PROJECT.md, .dkbo/tasks/BACKLOG.md, tests/unit/21_version.bats | .dkbo/bin/**, .dkbo/lib/**, tests/** |

## 共用契約（全文）
（一列一個契約。擁有者填一個成員短名；消費者填一個或多個、逗號分隔；沒有就填 —。任一方可寫 `<成員>@波<N>` 標出它在第幾波定稿或消費（那一波要有它的列）。完全沒有契約時只留表頭）
| 契約 | 擁有者 | 消費者 | 形狀／簽名 | 變更流程 |
|---|---|---|---|---|
| watch.log 與 watch died | backend-watch | backend-docs | 路徑 `$DK_ROOT/.sessions/<任務目錄名>.watch.log`（雜務 `chores.watch.log`）；行 `<dk_now> start <mode> pid <pid>`、`<dk_now> signal <SIG> <mode> pid <pid>`、`<dk_now> exit <mode> pid <pid> rc=<rc>`，mode ∈ `poll`／`events`／`chores`；process 行 `watch died: <poll\|events> pid <舊 pid> last: <最後一行或 no log>` | 動它要先 ESCALATE |
| fixture_copy_dkbo | backend-test | backend-docs | `fixture_copy_dkbo SRC_REPO DEST_DKBO`：`cp -r` 後清 `.sessions/`；SRC 是 git 倉時刪 `.dkbo/tasks/` 下未追蹤項目、tasks/ 下與 HEAD 不同的追蹤檔還原成 HEAD 版 | 動它要先 ESCALATE |

## 驗收標準（全文）
- [ ] AC1 （gate c 的 `HERDR_*`）`dk-wave-close` gate c 交給 `DK_TEST_CMD`（單 repo）與 `DK_TEST_CMD_<名>`（多 repo）的環境，除了既有的 `DK_*`，也剝掉所有 `HERDR_*`（沿用同一個 `clean` 陣列，`${!HERDR_@}` 同 `${!DK_@}` 的手法）；`PATH`、`HOME` 等其他變數照舊。上方註解補一句理由（`HERDR_PANE_ID` 等繼承值會讓專案測試以為自己在領導的 pane 裡，打到真 herdr）。08 補兩條（單 repo、多 repo 各一）：呼叫端設了 `HERDR_PANE_ID`／`HERDR_ENV`／`HERDR_SOCKET_PATH`，測試指令把 `env` 寫進檔案，檔案裡沒有任何 `^HERDR_` 與 `^DK_` 行、有 `^PATH=`。先確認 dkbo 自己的測試不靠繼承的 `HERDR_*`：helpers 自己 export 的 `HERDR_STUB_LOG`／`HERDR_STUB_RESPONSES`／`HERDR_ENV`／`HERDR_PANE_ID` 等也會被剝，要核對每條測試都在 setup 重新 export、不依賴 gate c 傳進來，且 `tests/run.sh` 本身不讀 `HERDR_*`；report 寫出確認方式
- [ ] AC2 （shellcheck）新檔 `tests/unit/37_shellcheck.bats`：① 沒裝 shellcheck 時 `skip "shellcheck 未安裝，跳過（CI 與開發機請裝）"`；② 對全域約束那一行列出的檔案集合跑 shellcheck，零警告才過，失敗時輸出列出 shellcheck 的原文；③ 自我驗證：同一個呼叫函式對一個含已知警告（未加引號的 `$x`，SC2086）的暫存腳本回非零——證明②不是空轉。檔案集合寫在 37 裡一處，不硬編成兩份。`tests/run.sh` 不改（`tests/run.sh <單檔>` 仍只跑那一檔，完整套件自然含 37）
- [ ] AC3 （夾具帶進主樹狀態）`tests/helpers.bash` 把「複製 `.dkbo` 進夾具」抽成 `fixture_copy_dkbo SRC_REPO DEST_DKBO`，`setup_project` 改呼叫它：照舊 `cp -r` 整個 `.dkbo`（worktree 未 commit 的 `.dkbo/` 改動仍要進夾具）、照舊清 `.sessions/`；另外在 SRC_REPO 是 git 倉時（git 呼叫一律用 plumbing 或 `git --no-optional-locks`：`ls-files --others --exclude-standard`、`diff-index --name-only HEAD`，不得用會刷新 index 的 `git status`／`git diff`——每條測試的 setup 都跑、同波四人並跑，不能搶 `.git/index.lock`），（a）刪掉 `.dkbo/tasks/` 底下 `git ls-files --others --exclude-standard` 列出的未追蹤項目，（b）`.dkbo/tasks/` 底下追蹤中但與 HEAD 不同（含被刪）的檔還原成 `git show HEAD:<路徑>` 的內容。`.dkbo/tasks/` 以外一律不動（未追蹤的新 bin 照樣進夾具）；SRC_REPO 不是 git 倉時只做 `cp -r` 與清 `.sessions/`、不報錯。36_fixture 補：在暫存 git 倉裡造「未追蹤任務資料夾（含 `.panes`、`.task.env`）＋改過的 `tasks/INDEX.md` 與 `decisions.md`＋未追蹤的 `.dkbo/bin/newtool`」→ 複製後任務資料夾不在、INDEX 與 decisions 等於 HEAD 版、newtool 在；非 git 來源照樣複製成功。helpers 註解寫明例外：`tasks/` 底下（含 `BACKLOG.md`）worktree 未 commit 的改動不會進夾具，目前沒有測試讀夾具裡的 BACKLOG 內容。helpers 改動是否造成全套回歸，由 backend-docs 在三則 `[DONE]` 到齊後的完整實跑把關（波內夥伴的紅測試不算 backend-test 的回歸）
- [ ] AC4 （chore-close 空 branch）`11_chore.bats` 補一條 legacy 測試：沒有執行記錄檔、雜務檔是**新版**模板（沒有 `branch:` 行，其餘同既有 legacy 那條）→ `dk-chore-close` exit 0、INDEX 那一列是 done、分支清單不變（沒有嘗試 merge 或刪分支）、沒有印 `merge conflict`。report 附突變探針：把 `dk-chore-close` 的 `[ -n "$branch" ] || branch="-"` 那行刪掉（在獨立目錄做），這條新測試會紅
- [ ] AC5 （守望程序靜默死亡）`dk-watch` 的三種背景啟動（`--ensure` 的輪詢、`--events`、`--chores`）：① `command -v setsid` 成功時用 `setsid`（**不得用 `setsid -f`**：它一定 fork，`$!` 會變成 setsid 自己）起，沒有就照舊 `nohup`；記下的 pid 必須是 dk-watch 行程本身；② stdout／stderr 不再丟 `/dev/null`，追加到 `$DK_ROOT/.sessions/<任務目錄名>.watch.log`（雜務模式 `$DK_ROOT/.sessions/chores.watch.log`；`.sessions/` 已 gitignore、結案不刪）；③ 每個背景行程啟動時追加一行 `<dk_now> start <poll|events|chores> pid <pid>`，結束時（trap EXIT）追加 `<dk_now> exit <mode> pid <pid> rc=<rc>`；收到 **HUP** 追加 `<dk_now> signal HUP <mode> pid <pid>` 後**繼續跑**（等同 nohup 語意，不得因 HUP 退出）；收到 INT／TERM 追加 `<dk_now> signal <SIG> <mode> pid <pid>` 後結束（poll 模式的 trap 要等前景 `sleep` 結束才跑、events 模式的 `herdr pane wait-output` 子行程會變孤兒，兩件事在註解交代）；④ `--ensure` 發現記錄中的 pid 已死（pid 非空但 `alive` 為假）時，在既有的 `watch restarted (pid N)`／`events started (pid N)` 之前另記 process 一行 `watch died: <poll|events> pid <舊 pid> last: <log 裡該 pid 的最後一行，沒有就寫 no log>`（比對 pid 要看詞界 ` pid <舊>( |$)`，pid 12 不得吃到 pid 123 的行；既有兩行的格式不變）；⑤ `dk-msg` 綁著任務（非雜務）時，**每一個**寫進 messages.log 的出口（含 dev 對 leader 的 `[DONE]` 只落盤就 `exit 0` 那條——事故走的正是它——以及背景送、送達、`[UNDELIVERED]` 各出口）之後都跑一次 `dk-watch --ensure >/dev/null 2>&1 || true`（`DK_NO_WATCH` 設了就不跑，`--ensure` 本身已處理）；⑥ `--ensure`（poll、events、chores 三條）整段用 flock 串行化（鎖檔 `$DK_ROOT/.sessions/<任務目錄名>.watch.lock`，雜務 `$DK_ROOT/.sessions/chores.watch.lock`；鎖內呼叫 `dk_env_set` 注意不要自鎖）：⑤ 之後每則 dk-msg 都會呼叫它，四人波幾秒內接連送 `[DONE]` 時不能起兩隻守望、後寫的 pid 蓋掉先寫的。09／26／06 補：`--ensure` 印出的 pid 在 2 秒內（輪詢）成為 `ps -o args=` 以 `dk-watch`（poll）或 `dk-watch --events` 結尾的行程，再跑一次 `--ensure` 印 `running (pid 同一個)`（不得寫成「啟動後立刻 alive」——fork 未 exec 前 args 仍是父行程，會偶發紅）；啟動寫 start 行；TERM 寫 signal 與 exit 行（用很小的 `--interval`）；HUP 只寫 signal 行、行程仍活著；`--ensure` 遇到死 pid 記 `watch died` 且帶該 pid 的最後一行、不吃到前綴相同的別的 pid；守望已死時並行跑兩個 `dk-watch --ensure`，結束後這個任務的 `dk-watch$` 行程只有一隻、process 只有一行 `watch restarted`；06：守望已死時 **dev 對 leader 送 `[DONE]`（只落盤、不送達）** 把它叫回來，另一條走一般 `[QUESTION]` 送達路徑也叫回來；`DK_NO_WATCH` 設了時 `dk-msg` 不起守望。⑦（波 1 審查 Important 1）`dk-task-new` 起第一對守望的兩段 `nohup … &` 改成呼叫 `dk-watch --ensure`（沿用 setsid、watch.log、flock；`DK_NO_WATCH` 與 fd 3／stdin 的處理照舊），pid 照樣落進 `.task.env`；05 補：task-new 起的守望是 setsid 起的（與 `--ensure` 同一條路，例如寫了 start 行、process 記了啟動），既有 05／09／26 斷言不放寬。⑧（波 1 審查 M1）`dk-msg` 的 `wake_watch` 只在任務目錄還有 `.panes` 時跑（結案後的背景送不再對已 commit 的任務目錄記 `watch died`、改 `.task.env`、起守望）；06 補一條：刪掉 `.panes` 後送訊息，process 沒有新的 `watch` 行、沒有新行程
- [ ] AC6 （所有權比對的裸 `awk -F'|'`）`lib/ownership.sh` 的 `dk_owned` 改成只讀 `## 檔案所有權` 段（經 `dk_brief_owners`）並用 `lib/brief.sh` 的跳脫感知切欄（`$DK__BRIEF_SPLIT` 或既有的共用函式），不再對整份 brief 用裸 `awk -F'|'`；`dk-spawn` 的 `first_glob` 與 `dk-brief-check` 取波次成員的兩處（現在的 136、143 行附近）同樣改用跳脫感知切欄。欄內的 `\|` 還原成字面 `|` 的時機與 `dk_brief_md_rows` 一致。22 補：可改欄 `src/a\|b/**, src/c/**` 時 `src/c/x` 判為擁有、`src/a|b/y` 判為擁有；誘餌：在 `## 檔案所有權` **之前**的段落（例如 `## 目標` 底下）放一張表，其中一列的**第一格**等於成員名、第二格是別的 glob（如 `bait/**`）→ 舊碼判 `bait/x` 為擁有（紅）、新碼判不擁有。07 補：成員第一個 glob 含 `\|` 時 `first_glob` 取到完整的第一個 glob。dk-brief-check 136／143 的改動只為一致（舊碼只取第 1、3 欄，「做什麼」欄的 `\|` 本來就不影響），**不是修 bug**：16 補一條回歸守護（「做什麼」欄含 `\|` 時成員檢查照常），註明舊碼本來就綠、不要求取紅
- [ ] AC7 （文件）run SKILL「每次醒來先做」第 1 條講 watcher 的那一句改寫（不加行，守住 ≤60）：就地重啟的時機加上 `dk-msg`（員工送 `[DONE]` 時），死因看 `.sessions/<任務>.watch.log`，process 會記 `watch died` 那一行；改完的 run SKILL 第 1 條同時含 `dk-msg`、`watch.log`、`watch died` 三個字串；`.dkbo/PROJECT.md` 測試指令那行改成「shellcheck 由 `tests/unit/37_shellcheck.bats` 守（沒裝就 skip），檔案集合同全域約束」，刪掉「shellcheck 不在 run.sh 裡……目前沒有機械閘守它」那句與少了 `install.sh`、`tests/run.sh` 的舊集合；目錄慣例把 `tests/helpers.bash` 那句補上「複製 `.dkbo` 時丟掉主樹未追蹤的任務資料夾、tasks/ 追蹤檔還原成 HEAD 版」。CHANGELOG 0.16.0 節追加條目（`fix(wave-close)` 剝 `HERDR_*`、`feat(watch)` setsid／watch.log／`watch died`／dk-msg 叫回守望、`fix(ownership)` 跳脫感知、`test` shellcheck 進套件／夾具不帶主樹任務／chore-close 空 branch），測試那一行的條數改成本任務**最後一次**完整 `tests/run.sh` 的實跑值，增量寫整節累計（實跑值 − 656，0.15.0 的條數），括號內補本任務新增的測試檔與條目；有修復波新增測試時由領導對 backend-docs 下 `[TASK] 補測試條數` 重填。`21_version.bats` 的「首節列出本版每一條變更」清單補上本任務新增的條目類別
- [ ] AC8 BACKLOG：刪掉 `.dkbo/tasks/BACKLOG.md` 裡 request.md 列出的 6 列，其餘每一行一字不動（其餘 4 列加表頭與說明句）
- [ ] AC9 `tests/run.sh` 全綠（含 `35_test_hygiene.bats` 與新的 `37_shellcheck.bats`，37 在裝了 shellcheck 的開發機上是實跑、不是 skip）；每位 dev 的 report「## 測試」附自己 AC 的取紅紀錄

## 同波成員
backend-watch(L) backend-gate(M) backend-test(M) backend-docs(M)
