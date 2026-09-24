# 測試可信度 — 給 backend 的切片（波 2）
由 dk-wave-open 產生，只讀。完整 brief 在 /home/bal/project/teamflow/.dkbo/tasks/2026-09-24-testtrust/brief.md。

## 目標
讓 `tests/run.sh` 的綠燈真的代表有驗到東西：`tests/` 裡 76 處（74 行；`07_spawn.bats:104`、`20_review.bats:48` 一行兩處）`!` 開頭的否定斷言全部換成在 bats 下有效的寫法，並加一道會自我驗證的守門測試擋住新增（BACKLOG L29）。
`fixture_task()` 的 `.task.env` 改由 `.dkbo/templates/task.env` 套模板產出，寫壞時自己回非零讓 setup 紅（BACKLOG L30，以及 request.md 試跑發現的「七個檔拿到空 `.task.env` 仍全綠」）。
`setup_project()` 不再把主樹 gitignore 的執行期狀態（`.dkbo/.sessions/`）帶進夾具（關卡①前實測：主樹的真實 `kinds-down` 讓 `10_resume.bats` 兩條紅）。
不做：產品程式碼（`.dkbo/bin`、`lib`、`kinds`、`templates`）的任何改動；不升版。

## 全域約束（全文）
bash 3.2+；不得使用 bash 4 語法（關聯陣列、${x^^}、declare -A、mapfile）；不得新增依賴
只改 `tests/`、`CHANGELOG.md`、`.dkbo/tasks/BACKLOG.md`；`.dkbo/bin/**`、`.dkbo/lib/**`、`.dkbo/kinds/**`、`.dkbo/templates/**` 一個字都不動
既有 642 條測試語意不變：不刪、不放寬、不改期望值；只允許（a）把否定斷言換成有效寫法，（b）新增測試與斷言，（c）改 `fixture_task()` 本身
轉換後某條在 base 上變紅：不得改期望值或刪斷言，停手並 `[ESCALATE]`，附 `檔:行` 與失敗輸出——那是被遮住的真缺陷或測試寫錯，由領導裁定（request.md 的試跑預期不會有）
否定斷言一律用 tests/helpers.bash 的 refute_grep（grep 類，含 `cmd | grep` 管線改成 `cmd | refute_grep …`）；非 grep 指令一律用新增的 `refute <cmd> [args…]`（放在 `tests/helpers.bash` 緊接 `refute_grep` 之後；指令成功就把指令印到 stderr 並回 1）。不得用 `run …; [ "$status" -ne 0 ]` 取代 `!`——`run` 會覆寫 `$status`／`$output`，而且這是領導已定案的單一寫法（ruling 見 process.md）
例外：本任務的成員**可以**修改 `.dkbo/tasks/BACKLOG.md`（PROTOCOL 停止條件「不改 .dkbo/」在本任務只對這一個檔不適用；ruling 見 process.md）
編輯一律用切片「## 倉庫」段的 worktree 路徑；`$DK_ROOT` 指向主樹，只拿來跑 `dk-msg`，不得當編輯路徑
取紅（證明新斷言會紅）一律 cp 到獨立目錄或 `git archive <base>` 解到暫存目錄做，不在 worktree 用 `git stash`／`git checkout -- <檔>`
面向人的文案是繁體中文

## 你的波次
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
| 2 | 修復 | backend | AC10：收掉波 1 審查 Minor 1–3（35 掃描器分隔符與空白、fixture 自檢 `{{` 判定、36 鍵集合測試擋雜行），Minor 4 記 BACKLOG，CHANGELOG 條數更新。只動 `tests/unit/35_test_hygiene.bats`、`tests/unit/36_fixture.bats`、`tests/helpers.bash` 的 `fixture_env_check`、`.dkbo/tasks/BACKLOG.md`、`CHANGELOG.md`；新規則若掃出既有述句照 AC1 轉換。編輯一律用 worktree 路徑 | M | tests/run.sh 全綠；AC10 各項有測試或 report 紀錄；取紅對 b169571 | 預設 |

## 倉庫
/home/bal/project/teamflow/.worktrees/testtrust

## 你的檔案所有權
| 成員 | 可改 | 只讀 |
|---|---|---|
| backend | tests/unit/**, tests/helpers.bash, CHANGELOG.md, .dkbo/tasks/BACKLOG.md | .dkbo/templates/task.env, .dkbo/lib/common.sh, .dkbo/bin/dk-task-new, tests/stub/**, tests/run.sh |

## 共用契約（全文）
（一列一個契約。擁有者填一個成員短名；消費者填一個或多個、逗號分隔；沒有就填 —。完全沒有契約時只留表頭）
| 契約 | 擁有者 | 消費者 | 形狀／簽名 | 變更流程 |
|---|---|---|---|---|

## 驗收標準（全文）
- [ ] AC1 否定斷言全數有效：`git ls-files 'tests/*.bats' tests/helpers.bash` 裡不再有以 `!` 開頭的述句——行首（去掉縮排後）或 `;`、`&&`、`||`、`then`、`do` 之後緊接 `! ` 的都算；`[ ! … ]`、`[[ ! … ]]` 裡的 `!` 與註解行不算。`24_portability.bats:22`、`25_docs_policy.bats:10` 那種 `! grep -q … || { echo …; false; }` 也一併換掉（它們有效，但守門規則不留例外）。diff 裡不出現用來取代 `!` 的 `run …; [ "$status" -ne 0 ]`
- [ ] AC2 未轉換的斷言一字不動：diff 裡除了否定斷言那一段、新增的測試與 `fixture_task()` 之外，沒有對既有斷言的改動；report 列出轉換總數，並分成「原本就有效」（測試最後一條，或已帶 `|| …false`）與「原本失效」兩類的各自數量（request.md 的試跑：76 處裡 50 處失效；數字不同就說明差在哪）。分類規則：只有它是整個 `@test` 最後執行的述句才算原本有效；位於測試最後一行但在 `for`／`if` 內的，歸原本失效
- [ ] AC3 守門測試 `tests/unit/35_test_hygiene.bats`：（a）掃 `git ls-files 'tests/*.bats' tests/helpers.bash`（不硬編檔名清單），出現 AC1 定義的否定述句就紅並列出每一處 `檔:行`；（b）掃描器是可對任意檔呼叫的函式，並對臨時檔自我驗證兩個方向：植入 `  ! grep -q x f; true`、`true; ! foo`、`true && ! foo`、`false || ! foo`、`if true; then ! foo; fi`、`for i in 1; do ! foo; done` 必須判出；植入 `[ ! -f x ]`、`[[ ! -d y ]]`、`refute_grep x f`、`  # ! 註解`、`echo "a ! b"` 必須不判。35 自己也在（a）的掃描集合裡：樣本一律用 `printf` 之類在執行期寫進臨時檔，35 的原始碼不得以字面行出現違規樣本，（a）掃到 35 自己也要乾淨
- [ ] AC4 `fixture_task()`（`tests/helpers.bash`）的 `.task.env` 改由 `.dkbo/templates/task.env`（測試裡是 `$DK_ROOT/templates/task.env`）套模板產出，直接用 `lib/common.sh` 的 `dk_render`，在子 shell 裡 source（`( . "$DK_ROOT/lib/common.sh"; dk_render … )`），不得在 helpers.bash 另寫一份替換邏輯——跟 `dk-task-new` 走同一條路，才不會多出第三份再漂移；fixture 給的值：`SHORT`、`DISPLAY`、`BRANCH=dk/<short>`、`WORKTREE`、`WORKSPACE=wB`、`ROOT_PANE=wB:p1`、`BASE=<主 repo HEAD>`，`TASK_TAB`、`LEADER_PANE`、`NO_WORKTREE` 給空字串（`LEADER_PANE` 空字串是刻意的：`dk-task-new:67` 給的是根 pane，但 heredoc 版根本沒有這個鍵，而 `setup_project` 洗掉了 `DK_*`，現況等同空值；照填根 pane 會改變既有測試的語意，不要「修正」它）；`DK_WATCH_PID` 等模板本來就寫死 `""` 的鍵照模板。不得依賴呼叫端 source 過 `lib/common.sh`（06、09、12、16、20、28、29 的 setup 都沒 source），也不得在呼叫端 shell 留下新的變數或函式（06 的 setup 是 `fixture_task … >/dev/null`，不在子 shell）
- [ ] AC5 fixture 自檢：寫完 `.task.env` 後若仍含 `{{`，或缺少模板裡的任一 `DK_*` 鍵，`fixture_task` 把缺的鍵名或殘留的佔位符名印到 stderr 並回非零；兩種呼叫形狀（`d=$(fixture_task …)` 與 `fixture_task … >/dev/null`）下這個非零都讓 setup 失敗。新增測試：（a）fixture 產出的 `.task.env` 鍵集合與順序和模板一致；（b）在測試的 `$DK_ROOT/templates/task.env` 追加一行 `DK_PROBE="{{PROBE}}"` 後 `fixture_task` 回非零且 stderr 含 `PROBE`；（c）在 setup 沒 source `lib/common.sh` 的測試裡，fixture 產出的 `.task.env` 非空且含 `DK_SHORT=`；（d）呼叫 `fixture_task` 前後同一個 shell 的 `declare -F` 與 `compgen -v` 沒有新增項（守住 AC4「不留下新的變數或函式」）
- [ ] AC6 BACKLOG：刪掉 `.dkbo/tasks/BACKLOG.md` 裡「tasktab 整枝評議 Minor（2026-09-24 複查改寫）」（否定斷言）與「tasktab 波 2 ESCALATE」（fixture 漂移）兩列，其餘每一行一字不動
- [ ] AC7 CHANGELOG：不升版，併入 `## 0.15.0` 節：「測試：」那行的條數改成 wave-close 時 `tests/run.sh` 的實跑值，括號裡的差量與明細一併更新（現為相對 0.14.0 的 `+4；…`，改成含本任務新增的差量並列出新增的測試），並在該節加一條 `test:` 條目，寫明轉換幾處（其中幾處原本失效）、35 守門、fixture 套模板與自檢。`.dkbo/VERSION`、README 的 `VER=` 不動；`21_version.bats` 照舊全過
- [ ] AC9 夾具隔離：`setup_project()`（`tests/helpers.bash:14` 的 `cp -r "$REPO_ROOT/.dkbo"`）複製完後，`$DK_ROOT/.sessions/` 裡除了 `.gitkeep` 沒有任何從主樹帶來的檔（`kinds-down`、`kinds-down.lock`、`chores/`、pane 綁定、`*.watch.pid` 等）；做法不限（複製後清掉、或只複製追蹤中的檔），但不得改動主樹的 `.sessions/`。新增測試：`setup_project` 之後 `$DK_ROOT/.sessions/` 只剩 `.gitkeep`（以及 setup 自己寫的東西，逐一列明）。report 附取紅：主樹 `.dkbo/.sessions/kinds-down` 存在一筆未過期的 `agy` 列時（關卡①當下就有：agy 到 2026-09-30、codex 到 2026-10-11），修前在**主樹**跑 `tests/unit/10_resume.bats` 有 2 條紅（`AC6/Minor`、`AC18/Minor`），修後全綠——這一項要在主樹的副本上做，worktree 的 `.sessions/` 本來就乾淨、重現不出來
- [ ] AC8 `tests/run.sh` 全綠；report 的「## 測試」附取紅紀錄：（a）35 的掃描器對 base（未轉換）的 `tests/` 列出多少行、多少處（35 的輸出以行為單位）；（b）AC5 的（b）在舊 heredoc 版 fixture 上會紅或會綠（說明為何）；（c）在副本（照全域約束 cp 或 git archive）把 fixture 套模板那一步換成產出空檔，重現 request.md 的試跑：`06_msg.bats`（`>/dev/null` 形狀）與 `09_watch.bats`（`d=$(…)` 形狀）的 setup 都必須紅，stderr 列出缺的鍵——自檢的「缺鍵」分支就是靠這一項證明活著
- [ ] AC10 波 1 審查 Minor 收尾（ruling 見 process.md）：（a）35 的 `bang_scan` 分隔符與 `!` 之間允許零個空白（`true;! foo`、`a &&! b`、`a ||! b` 必須判出），分隔符集合補 `{`、`(`、`|`、`else`（`{ ! foo; }`、`(! foo)`、`x | ! foo`、`if a; then b; else ! foo; fi` 必須判出），自我驗證（b）的必判樣本同步補上且照舊在執行期寫臨時檔；補完後對 `git ls-files` 集合仍為 0，若新規則掃出既有述句，照 AC1 轉換並列進 report；不判樣本照舊全過，另加 `echo "a;! b"`（引號內）若會誤判就在 report 說明取捨；（b）`fixture_env_check` 只要 `.task.env` 仍含 `{{` 就回非零（`{{FOO}`、`{{FOO` 也算），能抽出名字的印名字、抽不出的印該行；補一條測試在模板追加 `DK_PROBE2="{{PROBE2"` 後 `fixture_task` 回非零；（c）`36_fixture.bats` 的鍵集合測試另斷言 `.task.env` 除了 `DK_*=` 行之外沒有其他非空、非註解行（或整份去值後與模板逐行一致）；（d）`.dkbo/tasks/BACKLOG.md` 末尾加一列：`setup_project` 仍把主樹未追蹤的進行中任務資料夾與未 commit 的 `tasks/INDEX.md`、`decisions.md` 帶進夾具（reviewer-a Minor 4，`tests/helpers.bash:14`），建議處理寫明「只複製追蹤檔會讓 worktree 未 commit 的 `.dkbo/` 改動進不了夾具」的取捨；（e）CHANGELOG 0.15.0 的「測試：」條數與明細更新成 wave-close 實跑值、`test:` 條目補一句收尾內容。取紅：（a）（b）的新樣本在波 1 的 `b169571` 版（`git archive b169571` 解到暫存目錄）上會漏判／回 0，report 附紀錄

## 同波成員
backend(M)
