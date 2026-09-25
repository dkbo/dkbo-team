# dk-status --json（dashboard 資料出口） — 給 backend-docs 的切片（波 1）
由 dk-wave-open 產生，只讀。完整 brief 在 /home/bal/project/teamflow/.dkbo/tasks/2026-09-25-status/brief.md。

## 目標
新增唯讀指令 `dk-status --json [<任務>]`，把 `.dkbo/tasks/` 的任務記憶（INDEX、.task.env、brief、process、messages、state、.panes、.repos）與專案層 kinds-down 轉成帶 `schema_version` 的 JSON，給獨立 repo 的 dkbo-team-dashboard 讀，dashboard 不再直接解析 markdown。
不做：用量（token／費用）、逐字稿、herdr 即時狀態、人讀的非 JSON 輸出、雜務（`tasks/_chores/`）、所有權對照實際 diff（要跑 git diff 且 worktree 結案即刪；dashboard 以 `brief.owners`＋`members[].touched` 呈現自報版）、dashboard 本身；不 push。

## 全域約束（全文）
bash 3.2+；不得使用 bash 4 語法（關聯陣列、${x^^}、declare -A、mapfile）；依賴只有 herdr 0.9.0、git ≥ 2.17、jq ≥ 1.5、flock，不得新增必要依賴；`date -d`／`date -r` 不得使用
shellcheck 零警告（`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh tests/run.sh`；`tests/unit/37_shellcheck.bats` 會擋）
新增檔只准三個：`.dkbo/bin/dk-status`、`.dkbo/status-schema.md`、`tests/unit/38_status.bats`；不新增 settings.env 鍵、不新增 `.task.env` 鍵、不新增 lib 檔、不新增 skill
`dk-status` 唯讀：不寫、不建、不刪任何檔（含 `.sessions/`、`process.md`），不呼叫 `herdr`、`dk-watch`、`dk_require_herdr`，不需要 `HERDR_ENV`／`HERDR_PANE_ID`，也不看 session 綁定（`.sessions/<pane>`）；讀 `.sessions/kinds-down`（經 `dk_kinds_down_rows`）是允許的
JSON 一律由 jq 產生（`jq -n --arg`／`--argjson`／`-R -s` 等），不得用 printf／echo 手拼 JSON 字串；list 模式不得逐行呼叫 jq（每個任務至多固定次數的 jq 呼叫）
否定斷言一律用 tests/helpers.bash 的 refute_grep（grep 類）或 refute（其他指令），不得寫 `! cmd`；`35_test_hygiene.bats` 會擋
既有測試語意不變：不刪、不放寬，只允許新增斷言；例外：`21_version.bats`「首節列出本版每一條變更」的清單隨升版整份換成 0.17.0 的條目、版號字串總數維持 8（ruling 見 process.md）
改任何檔之前先 `grep -l <檔名> tests/unit/*.bats`：引用它的測試檔不在你的可改欄、而你的改動會讓它紅，就 `[ESCALATE]`，不要自己改
面向使用者的文案是繁體中文；JSON 的鍵名一律英文 snake_case
升版 0.17.0：新 CHANGELOG 節 `## 0.17.0 — <結案日>`，`.dkbo/VERSION` 與三份 README 的版號同步（ruling 見 process.md）
例外：本任務的成員**可以**修改 `.dkbo/` 底下所有權劃給自己的檔（PROTOCOL 停止條件「不改 .dkbo/ 規則檔」在本任務不適用；ruling 見 process.md）
編輯一律用切片「## 倉庫」段的 worktree 路徑；`$DK_ROOT` 指向主樹，只拿來跑 `dk-msg`，不得當編輯路徑
取紅一律 cp 到獨立目錄或 `git archive <base>` 解到暫存目錄做，不在 worktree 用 `git stash`／`git checkout -- <檔>`
領導跑的是主樹的腳本：本任務的 `dk-status` 在本任務內不存在於主樹，report 不得宣稱「本任務已用到」
backend-status 送出 `[DONE]` 給 leader 之後，再前景送一則同內容的 `[DONE]` 給 backend-docs（dev→dev 前景送）；backend-docs 等它到了才跑完整測試填條數。backend-status 之後每一則 `[FIXED]` 也同樣前景送一則給 backend-docs；backend-docs 收到就重跑完整 `tests/run.sh`、更新 CHANGELOG 條數，再回 `[FIXED]` 給 leader

## 你的波次
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
| 1 | 文件 | backend-docs | AC10：三份 README 指令表與 `.dkbo/README.md` 新段、升版 0.17.0（VERSION、八處版號、CHANGELOG 新節）、21_version 首節清單。條目照「共用契約」的介面逐字；等 backend-status 的 `[DONE]` 到了，在 worktree 跑完整 `tests/run.sh`，把 CHANGELOG 的測試條數填成實跑值再送 `[DONE]` | M | 全套實跑綠（紅了對擁有者送 `[BUG]` 並回報 leader）；CHANGELOG 測試條數等於實跑值 |  |

## 倉庫
/home/bal/project/teamflow/.worktrees/status
編輯一律用上面的 worktree 路徑；$DK_ROOT 指向主樹的 .dkbo/，只拿來跑 dk-msg 等 bin，不得當編輯路徑

## 你的檔案所有權
| 成員 | 可改 | 只讀 |
|---|---|---|
| backend-docs | README.md, README.en.md, .dkbo/README.md, CHANGELOG.md, .dkbo/VERSION, tests/unit/21_version.bats | .dkbo/bin/**, .dkbo/lib/**, .dkbo/status-schema.md, tests/** |

## 共用契約（全文）
（一列一個契約。擁有者填一個成員短名；消費者填一個或多個、逗號分隔；沒有就填 —。任一方可寫 `<成員>@波<N>` 標出它在第幾波定稿或消費（那一波要有它的列）。完全沒有契約時只留表頭）
| 契約 | 擁有者 | 消費者 | 形狀／簽名 | 變更流程 |
|---|---|---|---|---|
| 指令介面 | backend-status | backend-docs | `dk-status --json` → list；`dk-status --json <資料夾名\|短名>` → detail；stdout 單行 JSON；exit 0／1（找不到任務）／2（用法錯） | 動它要先 ESCALATE |
| kinds_down 項 | backend-status | backend-docs | `{"kind":str,"until":"YYYY-MM-DDTHH:MM"（本地，經 dk_epoch_to_local）,"until_epoch":int,"exact":bool,"recorded_at":str,"from_task":str,"agent":str,"reason":str}`，依 kind 升冪 | 動它要先 ESCALATE |
| 任務摘要 | backend-status | backend-docs | `{"dir":資料夾名,"short":str,"display":str\|null,"date":"YYYY-MM-DD","status":"planning"\|"running"\|"done"\|"abandoned"\|"unknown","index_note":str\|null,"branch":str\|null,"worktree":str\|null,"task_tab":str\|null,"repo_names":[str],"current_wave":int\|null（`.task.env` 的 `DK_WAVE`，空則 null）,"waves_planned":int（brief 波次表不同波號數）,"waves_closed":int（關閉的不同波號數，關閉定義見 AC4）,"created_at":ts\|null（第一筆 `task-new`）,"gate1_at":ts\|null（最後一筆 `gate1 approved`）,"closed_at":ts\|null,"close_result":str\|null（兩者只認最後一筆 `task-close merged …`／`task-close in-tree …`／`task-close abandoned: …`，close_result 為 `task-close ` 之後的原文；`merge-failed`、`local-changes:` 不算結案）,"updated_at":ts\|null（process 最後一行合法時間戳）,"panes_open":int（.panes 列數）,"counts":{"rulings":int,"autonomous_rulings":int,"minors":int（dk_minor_count）,"undelivered":int（messages type=UNDELIVERED 的列數）,"escalations":int（messages type=ESCALATE 的列數）}}` | 動它要先 ESCALATE |
| 任務詳情 | backend-status | backend-docs | 任務摘要 ＋ `"repos":[{"name","path","worktree","base"}]`（.repos 四欄）、`"brief":{"goal":str\|null,"acceptance":[{"text":str,"checked":bool}],"owners":[{"member","writable":[glob],"readonly":[glob],"exclusive":[str]}],"waves":[{"wave":int,"type","member","what","tier","done","review":str\|null}]}`（切欄經 lib/brief.sh，跳脫的管線還原成字面管線）、`"waves":[{"wave":int,"opened_at","dev_done_at","review_spawned_at","review_verdict_at","review_verdict":str\|null,"closed_at","tests":str\|null,"tests_ok":bool\|null,"commits":[{"repo":str\|null,"sha":str}]}]`（時間戳皆 ts\|null；波號取 brief 波次表與 process `wave-open N` 的聯集升冪；`tests`＝關閉行 `tests ` 與 ` K agents closed` 之間的原文、未關則 null，`tests_ok`＝原文不含 `failed`；`commits` 取 `commit <sha> wave N[ repo <名>]`、略過 `commit failed`；`review_verdict` 取最後一筆 `review N verdict ` 之後的原文，沒有而有 `review N skipped:` 時給 `skipped: …` 原文）、`"members":[{"name","status","wave":int\|null（非整數給 null）,"current","touched":[str],"todo":[str],"blocked_by","notes":str\|null（同鍵後續縮排續行以 \n 串接）,"has_report":bool}]`、`"panes":[{"agent","pane","since_epoch":int\|null,"group":str\|null,"tab":str\|null,"slot":str\|null}]`（legacy 兩欄格式時後四欄 null）、`"rulings":[{"ts","text","autonomous":bool}]`、`"events":[{"ts","kind":第 2 欄去掉尾端冒號,"text":時間戳之後的整行}]`、`"messages":[{"ts","from","to":str\|null,"type":str,"text":str}]`（`<ts> <from> -> <to> [TYPE] 內文`；`<ts> <who> [ACK]` 給 to=null、type="ACK"、text=""；`[UNDELIVERED] [DONE] …` 的 type 是 UNDELIVERED、text 保留後面的原文）、`"skipped_lines":{"process":int,"messages":int}` | 動它要先 ESCALATE |

## 驗收標準（全文）
- [ ] AC1 （介面）`dk-status --json` 印 list 文件、`dk-status --json <任務>` 印 detail 文件，`<任務>` 接受任務資料夾名或短名（短名取日期最晚的那個，解析規則同 `dk-timeline`；但資料夾名必須符合 `YYYY-MM-DD-<短名>`，`_chores`、`.`、`..` 等一律視為找不到、exit 1）；stdout 只有一個 JSON 值（`jq -c` 單行）＋換行，exit 0。沒帶 `--json`、帶未知旗標、多於一個位置參數、`--json` 不在第一個參數 → exit 2、stderr 印 `dk-status: 目前只支援 --json（用法：dk-status --json [<任務>]）`；找不到任務 → exit 1、stderr 印 `dk: no task '<x>'`。在 herdr 外（`HERDR_ENV`、`HERDR_PANE_ID` 都 unset）照樣成功
- [ ] AC2 （list 文件）頂層鍵恰為 `schema_version`（整數 1）、`dkbo_version`（`.dkbo/VERSION` 內容去掉所有空白與換行，同 21_version 的 `tr -d '[:space:]'`；沒有檔就 `null`）、`generated_at`（`dk_now` 格式）、`kinds_down`、`tasks`。`tasks` 依資料夾名升冪，含 `tasks/` 下每個符合 `YYYY-MM-DD-<短名>` 的目錄（不含 `_chores`、`BACKLOG.md`），每筆是共用契約「任務摘要」的形狀；`kinds_down` 只列未過期的列（經 `dk_kinds_down_rows`），形狀見共用契約
- [ ] AC3 （detail 文件）頂層鍵恰為 `schema_version`、`dkbo_version`、`generated_at`、`kinds_down`、`task`；`task` 是「任務摘要」的所有欄位再加 `repos`、`brief`、`waves`、`members`、`panes`、`rulings`、`events`、`messages`、`skipped_lines`，形狀見共用契約「任務詳情」
- [ ] AC4 （欄位來源）`status` 取 INDEX 裡名稱欄等於 `.task.env` 的 `DK_DISPLAY` 的那一列（`|` 存成 `／` 的規則同 `dk_index_set`），INDEX 沒有就是 `"unknown"`；`waves[]` 的 opened_at／dev_done_at／review_spawned_at／review_verdict_at 與 `dk-timeline` 對同一份 process.md 取到的一致（取最後一筆，規則同 `dk_ts_pick`）；**波 N 算關閉 ⟺ 存在 `wave-close N tests … K agents closed` 行**（未強關的 `wave-close N tests failed (…)` 不帶 `agents closed`，不算關閉），`closed_at` 取最後一筆這種行，其餘欄位規則見共用契約「任務詳情」；`rulings[]` 是 process 裡第 2 欄為 `ruling:` 的行，`autonomous` 為本文是否以 `[自主]` 開頭；`members[]` 取 `state/*.md`（不含 `*.report.md`），依檔名升冪
- [ ] AC5 （容錯）任務目錄缺任一個檔（brief、process、messages、state/、.panes、.repos、.task.env）時對應欄位給 `null` 或 `[]`、不報錯；process／messages 裡第 1 欄不是 `YYYY-MM-DDTHH:MM` 的行、messages 裡解析不出寄件人或類型的行都略過，並計進 `skipped_lines`（`{"process":N,"messages":M}`）；state 缺鍵給 `null`，`touched`／`todo` 缺或為 `[]` 給 `[]`
- [ ] AC6 （JSON 安全）process 的 ruling、messages 內文、state 的 `current`／`notes` 含 `"`、`\`、tab、`$(...)`、中文與 emoji 時，輸出仍是合法 JSON（`jq -e .` 通過），且對應欄位以 `jq -r` 取回與原文逐字相同
- [ ] AC7 （唯讀）38 驗：跑 list 與 detail 前後，夾具專案整棵 `.dkbo/` 的 `find … -newer` 為空且檔案清單不變；herdr stub 記錄為空（沒被呼叫）；`HERDR_ENV`、`HERDR_PANE_ID` unset 時兩種模式都成功
- [ ] AC8 （schema 文件）新檔 `.dkbo/status-schema.md`：列出 list 與 detail 的每一個鍵（鍵名、型別、可否為 null、來源檔、一句說明），寫明相容規則（**只加欄位不升 `schema_version`；改名、刪欄、改型別、改語意才升**，消費端遇到不認識的欄位要忽略），並寫明三件事：`kinds_down[].until` 是跑 dk-status 那台機器的本地時間，跨時區請用 `until_epoch`；messages 內文含換行時續行沒有時間戳、會計進 `skipped_lines.messages`；閘門結果去 `events[]` 找，點名 `kind` 為 `wave-close`、`violation`、`unreported`、`review` 的行各代表什麼（對應 request「閘門狀態」）；38 補一條：對夾具的 list 與 detail 輸出取所有物件鍵名（`jq '[paths | .[] | strings] | unique'`），每一個都出現在 status-schema.md 裡（反向防漂移）
- [ ] AC9 （測試）新檔 `tests/unit/38_status.bats` 涵蓋 AC1–AC8：用 `fixture_task` 造至少兩個任務（一個 done、一個 running 且有開著的波、`.panes` 兩列、state 兩位、`[自主]` 與一般 ruling 各一、一則 `[UNDELIVERED]`、一行壞 process 行），並造一列未過期與一列已過期的 kinds-down。`fixture_task` 不寫 INDEX 列、資料夾日期固定今天：status 要手動 append INDEX 列，「短名取日期最晚」要手工再建一個舊日期的同短名資料夾。夾具要讓每個陣列至少一個元素（repos、brief.owners、brief.waves、brief.acceptance、waves、members、panes、rulings、events、messages 含一則 ACK、kinds_down），member 至少一位有 `blocked_by`，否則 AC8 的反向防漂移查不到空陣列裡的鍵。另加一條守「list 不逐行叫 jq」：PATH 前置一個計數 jq 包裝，N 個任務與 2N 個任務（每個任務 process 行數不同）的呼叫次數差 ≤ 固定常數 × N、且與行數無關。每條 AC 至少一條測試，report 附取紅紀錄
- [ ] AC10 （文件與版本）三份 README 的指令表各加一列 `dk-status`（一句：唯讀輸出任務記憶的 JSON 給 dashboard，schema 見 `.dkbo/status-schema.md`）；`.dkbo/README.md` 另加一段「給 dashboard 讀的 JSON」（兩種用法、不呼叫 herdr、相容規則一句、指向 status-schema.md）；升版 0.17.0：`.dkbo/VERSION`、三份 README 八處版號、CHANGELOG 新節（`feat(status)` 條目寫明兩種模式、唯讀、schema_version 1 與相容規則；`docs` 條目；`- 測試：<N> bats（+<增量>；…）` 行填本任務**最後一次**完整 `tests/run.sh` 的實跑值，增量＝實跑值 − 756（0.16.0 節的條數））；`21_version.bats` 首節清單換成 0.17.0 的條目（至少含 `feat(status)`、`dk-status --json`、`schema_version`、`status-schema.md`、`測試：`）；38 補一條：`dk-status` 在三份 README 都出現（同 32 對 dk-timeline 的寫法）
- [ ] AC11 `tests/run.sh` 全綠（含 `35_test_hygiene.bats`、`37_shellcheck.bats` 實跑非 skip、新的 `38_status.bats`）；每位 dev 的 report「## 測試」附自己 AC 的取紅紀錄

## 同波成員
backend-status(L) backend-docs(M)
