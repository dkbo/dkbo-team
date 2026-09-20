# 多 repo workspace — 給 backend-ws 的切片（波 4）
由 dk-wave-open 產生，只讀。完整 brief 在 /home/bal/project/teamflow/.dkbo/tasks/2026-09-20-multirepo/brief.md。

## 目標
讓一個任務擁有自己的 herdr workspace（label 與 tab 名 `dk/<short>`，`/dkbo-run` 時交棒給該 workspace 根 pane 的執行領導），
並讓一個任務跨 N 個獨立 git repo（`DK_REPOS`，每個 repo 同名分支的 worktree；所有權、touched、差異包、四道閘、合併都長出 repo 維度）。
時序：`dk-task-new` 只建任務資料夾（計畫完可能不做，不先付成本）；`/dkbo-run` 那一刻由 `dk-leader <short> --run` 切 worktree、跑依賴鉤子、開 workspace 與 tab、在其根 pane 起執行領導交棒（plan.md 決策①②③）。單 repo 專案的行為除 workspace 與交棒外與 0.9.2 相同。出貨版本 0.10.0。

## 全域約束（全文）
bash 3.2+；不得使用 bash 4 語法（關聯陣列、${x^^}、declare -A）
依賴只有 herdr 0.9.0、git ≥ 2.17、jq ≥ 1.5；不得新增依賴
shellcheck 零警告（`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh`）
settings.env 只新增 `DK_REPOS`、`DK_TEST_CMD_<名>`、`DK_SETUP_CMD`／`DK_SETUP_CMD_<名>` 三種鍵；不新增 skill、不新增 install.sh 的 symlink
不改「員工在波內不 commit、dk-wave-close 統一 commit」的模型
否定斷言一律用 tests/helpers.bash 的 refute_grep，不得寫 ! grep -q
所有面向使用者的文案是繁體中文
目標版本 0.10.0
`DK_REPOS` 空字串時，0.9.2 的既有測試語意不變：不刪、不放寬既有斷言；只允許把 05 的 worktree／base 斷言原樣搬到 13 的 `--run` 測試、改 `DK_WORKSPACE`／`DK_ROOT_PANE`／`DK_WORKTREE`／`DK_BASE` 在計畫階段的期望值、新增斷言（AC1）
計畫階段（`dk-task-new` 到關卡①）不得有 git worktree、分支、herdr workspace 的副作用；這些全在 `dk-leader --run` 發生
不用 `herdr worktree create`；workspace 用 `herdr workspace create --cwd <主樹>`，worktree 用 `git worktree add`（plan.md 決策①）
例外：本任務的成員**可以**修改 `.dkbo/` 底下的腳本、lib、kinds、模板、規則檔與 skill 文件（PROTOCOL 停止條件「不改 .dkbo/ 規則檔」在本任務不適用；ruling 見 process.md）；但只能改所有權表劃給自己的檔
單 repo 模式下任何面向人的輸出都不印 repo 前綴；多 repo 模式下都印
領導跑的是主樹的腳本：本任務內做出來的新行為要等結案合併後的下一個任務才生效，不要在 report 裡宣稱「本波已用到」

## 你的波次
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
| 4 | 修復 | backend-ws | 整枝評議 Important 1、2（state/reviewer-a.report.md）：(1) lib/repos.sh 的乾淨檢查對主 repo 排除 .dkbo/ 底下的路徑（`git status --porcelain --untracked-files=no -- . ':!.dkbo'`），補「主 repo 的 .dkbo/tasks/INDEX.md 已追蹤且已修改時 dk-leader --run 仍要過」的回歸測試（fixture 要先 git add .dkbo）；(2) dk-leader 的 run_setup 與 dk-wave-close gate c 在 while read 迴圈內跑的使用者指令加 </dev/null（含 gate c 的 git commit），各補一條鉤子／測試指令會讀 stdin（cat >/dev/null）仍能跑完 N 個 repo 的測試；(3) 順手把累積的兩條 Minor（dk-task-close:148、dk-leader:121 英文開頭訊息）改成繁中 | M | 13/08/33/12 全過；tests/run.sh 全綠；shellcheck 零警告 | 預設 |

## 你的檔案所有權
| 成員 | 可改 | 只讀 |
|---|---|---|
| backend-ws | .dkbo/lib/repos.sh, .dkbo/bin/dk-wave-close, tests/unit/33_repos.bats, tests/unit/08_wave_close.bats, .dkbo/bin/dk-task-new, .dkbo/bin/dk-leader, .dkbo/bin/dk-msg, .dkbo/bin/dk-watch, .dkbo/bin/dk-task-close, .dkbo/bin/dk-resume, .dkbo/templates/task.env, .dkbo/skills/run/**, .dkbo/skills/plan/**, tests/stub/**, tests/unit/05_task_new.bats, tests/unit/13_leader.bats, tests/unit/06_msg.bats, tests/unit/09_watch.bats, tests/unit/12_task_close.bats, tests/unit/10_resume.bats, tests/unit/26_watch_events.bats, tests/unit/30_isolation.bats, tests/unit/23_leader_kind.bats | .dkbo/lib/**, tests/helpers.bash |

## 共用契約（全文）
（一列一個契約。擁有者填一個成員短名；消費者填一個或多個、逗號分隔；沒有就填 —。完全沒有契約時只留表頭）
| 契約 | 擁有者 | 消費者 | 形狀／簽名 | 變更流程 |
|---|---|---|---|---|
| lib/repos.sh API | backend-repos | backend-ws, backend-gates | plan.md 第 6 節列出的函式與簽名：dk_repos_parse、dk_repos_multi、dk_repos_check [--no-clean]、dk_repos_write、dk_repos_rows、dk_repo_field、dk_repos_names、dk_glob_split、dk_glob_check、dk_repo_setup_cmd；逐 repo 的變更清單是 dk_changed_repo_files TASK_DIR N（輸出帶前綴），舊的 dk_changed_files WT BASE 原樣保留到波 2 backend-gates 換完呼叫再刪；乾淨檢查只看已追蹤檔 | 動它要先 ESCALATE |
| .repos 檔格式 | backend-repos | backend-ws, backend-gates | 一列一 repo：`<名> <repo 根> <worktree> <base sha>`，空白分隔，主 repo 第一列；單 repo 模式一列、名字固定 `main` | 動它要先 ESCALATE |
| glob 前綴語法 | backend-repos | backend-gates, backend-docs | 所有權與 touched 一律 `<名>:<glob>`；多 repo 必帶、單 repo 禁帶；拆解走 dk_glob_split，驗證走 dk_glob_check | 動它要先 ESCALATE |
| DK_ADD_DIRS | backend-repos | backend-gates | 空白分隔的絕對路徑，預設 `$DK_PROJECT_ROOT`；kind_args 每一項輸出一個 `--add-dir`；由 dk-spawn 組好並 export 後才呼叫 dk_kind_args | 動它要先 ESCALATE |
| kind_session_args | backend-repos | backend-ws | `kinds/<kind>.sh` 的 `kind_session_args NAME`：claude 印 `--name NAME`，codex 與 agy 印空字串；dk-leader 在 dk_kind_args 之後接上它 | 動它要先 ESCALATE |
| DK_SETUP_CMD 鉤子 | backend-repos | backend-ws, backend-docs | `dk_settings` 讀 `DK_SETUP_CMD` 與 `DK_SETUP_CMD_<名>`（bash 3.2 用 `${!v}` 間接展開）；`dk_repo_setup_cmd NAME` 回該 repo 的指令或空；執行點在 dk-leader --run（每個 worktree 切好之後；dk-task-new 已不切 worktree），乾淨環境的組法與 dk-wave-close gate c 相同 | 動它要先 ESCALATE |
| dk_wave_base 第三參數 | backend-repos | backend-gates | `dk_wave_base DIR N [REPO]`；有 REPO 讀 `<ts> wave-open N repo <名> base <sha>`，無 REPO 行為不變；寫端是 dk-wave-open | 動它要先 ESCALATE |
| .task.env 的 DK_LEADER_PANE 與「尚未實體化」判別 | backend-ws | backend-gates, backend-docs | `DK_LEADER_PANE="<pane id>"`；讀端退路寫成 `${DK_LEADER_PANE:-${DK_ROOT_PANE:-}}`。計畫階段 `DK_WORKTREE=""`、`DK_BASE=""` 且沒有 `.repos`；`dk-leader --run` 之後五個欄位改寫、`.repos` 出現。`dk_legacy_task` 只看 `DK_BASE=` 這一行存不存在，空值不是 legacy | 動它要先 ESCALATE |
| stub workspace_create.json | backend-ws | backend-gates | `.result.workspace.workspace_id` 與 `.result.root_pane.pane_id`，比照 worktree_create.json；workspace_get.json 有 `.result.workspace.active_tab_id` | 動它要先 ESCALATE |
| dk-task-close 退出碼 | backend-ws | backend-docs | 0 合併成功；1 前置不過（同今天）；3 預檢衝突（列出全部衝突 repo，未合併任何 repo）；4 真合併中途失敗（印 merged／failed／not attempted）；5 主樹有本地變更會被覆蓋 | 動它要先 ESCALATE |

## 驗收標準（全文）
- [ ] AC1 `DK_REPOS` 空字串時，0.9.2 的 426 條測試語意不變：不刪、不放寬既有斷言；只允許（a）把 `05_task_new` 裡 worktree／base 的斷言原樣搬到 `13_leader` 的 `--run` 測試，（b）改 `DK_WORKSPACE`／`DK_ROOT_PANE`／`DK_WORKTREE`／`DK_BASE` 在計畫階段的期望值，（c）新增斷言
- [ ] AC2 `dk-task-new` 只建任務資料夾：不切 worktree、不開 workspace、`DK_WORKTREE`／`DK_BASE` 為空、`DK_LEADER_PANE` 為呼叫者 pane、brief 標頭印「交棒時建立」；計畫階段 `dk-task-close --abandon` 不需要任何 worktree 或 workspace 就能收乾淨
- [ ] AC3 `dk-leader <short> --run` 實體化：對 `DK_REPOS` 每個 repo（單 repo 就是主 repo）切出 `dk/<short>` 的 worktree（多 repo 在 `.worktrees/<short>/<名>`，單 repo 在 `.worktrees/<short>`）、寫 `.repos`、用 `herdr workspace create` 開 label 與 tab 名皆為 `dk/<short>` 的 workspace、改寫 `.task.env` 的 `DK_WORKSPACE`／`DK_ROOT_PANE`／`DK_LEADER_PANE`／`DK_WORKTREE`／`DK_BASE`；agent start 之前任一步失敗 rollback 全部 worktree、分支、workspace 並還原 `.task.env`；多 repo 下 `DK_NO_WORKTREE` 拒絕
- [ ] AC4 `dk_repos_check` 對名字不合法、重複、第一個非主 repo、非 git 根、工作樹不乾淨各自拒絕並點名 repo
- [ ] AC5 `dk-brief-check` 多 repo 模式下缺前綴或未知名字 FAIL；單 repo 模式下帶前綴 FAIL；重疊只在同 repo 內判
- [ ] AC6 `dk-leader <short> --run` 交棒：清掉呼叫者 pane 的 herdr 註冊名 `leader-<short>`、在新 workspace 根 pane 起 herdr 註冊名同為 `leader-<short>` 的執行領導（CLI 那側的 session 名是 `dk/<short>`，見 AC19）、改綁 `.sessions`；缺 `gate1 approved` 或有開著的波時拒絕；重跑幂等（已實體化就跳過實體化，已交棒就只印「已交棒」）
- [ ] AC7 `dk-msg leader` 與 `dk-watch` 的 pane 退路讀 `DK_LEADER_PANE`，缺席時退回 `DK_ROOT_PANE`
- [ ] AC8 `dk-spawn` 的 pane cwd 是成員第一個可改 glob 所在 repo 的 worktree，`DK_WORKTREE` 為空（計畫階段的 reviewer）時是 `DK_PROJECT_ROOT`；三個 kind 對 `.repos` 每一列各出一個 `--add-dir`
- [ ] AC9 `dk-wave-open` 在 `DK_WORKTREE` 為空時拒絕並指向 `dk-leader --run`；每 repo 記一行 `wave-open N repo <名> base <sha>`；`dk_wave_base DIR N REPO` 讀得到；切片含「## 倉庫」段
- [ ] AC10 `dk-review-pack` 對每個有變更的 repo 各出一段 `## repo <名>`，`files changed` 是總和
- [ ] AC11 `dk-wave-close` gate c 只對本波有變更的 repo 跑 `DK_TEST_CMD`（主）／`DK_TEST_CMD_<名>`（其餘），缺指令記 skipped 不擋，log 檔 `N.<名>.test.log`
- [ ] AC12 `dk-wave-close` gate d 逐 repo 比對，`unowned change`／`unreported change` 訊息帶 `<名>:` 前綴；每個有變更的 repo 各 commit 一次
- [ ] AC13 `dk-task-close` 在合併前先 commit 任務記憶；沒有 `.repos`（計畫階段就 `--abandon`）時只標 INDEX、commit 記憶、清 `.sessions` 與 pane 名字；預檢任一 repo 衝突就全部不合併、exit 3 並列出全部衝突 repo；主樹本地變更 exit 5；真合併中途失敗 exit 4 並印 merged／failed／not attempted；全過時逐 repo 刪 worktree 與分支
- [ ] AC14 `dk-task-close` 不呼叫 `herdr workspace close`；成功結案的 stdout 最後一行含字樣 `herdr workspace close <DK_WORKSPACE 的值>`
- [ ] AC15 `skills/run/SKILL.md` 有第 0 步交棒；`skills/plan/SKILL.md`、`skills/init/SKILL.md`、`PROTOCOL.md`、`LEADER.md`、`roles/reviewer.md`、三份 README、CHANGELOG 都提到 repo 前綴或交棒（各自對應的那一段），`tests/unit/04_docs.bats` 或 `25_docs_policy.bats` 有斷言守著
- [ ] AC16 版號 0.10.0：`VERSION`、`dk-version`、README 安裝段、CHANGELOG 一致，`21_version.bats` 全過
- [ ] AC17 `tests/integration/herdr-real.sh` 加 `workspace create`／`workspace get`／根 pane `agent start` 三個探針；發版前在真 herdr 跑過一次並把 NOTE 行貼進 report.md
- [ ] AC20 `dk-leader --run` 在每個 worktree 切好之後，於該 worktree 內、以 gate c 同一套 `env -u DK_*` 乾淨環境跑一次 `DK_SETUP_CMD`（主 repo）／`DK_SETUP_CMD_<名>`（其餘 repo）；沒設就跳過；失敗不 rollback，stderr 警告並記 process 行 `setup <名> failed`；單 repo 模式同樣適用 `DK_SETUP_CMD`；`/dkbo-init` 會問這一項，README 與 `.dkbo/README.md` 給 pnpm 的建議寫法 `pnpm install --frozen-lockfile --prefer-offline` 並說明 node_modules 不會被 worktree 複製、symlink 主樹 node_modules 的兩個坑
- [ ] AC19 `dk-leader`（含 `--run`）起 claude 領導時 `agent start` 帶 `--name dk/<short>`（session 名＝workspace 名）；kind 為 codex／agy 時不帶；`kind_session_args` 三個 kind 各有測試
- [ ] AC18 `tests/run.sh` 全綠、`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh` 零警告

## 同波成員
backend-ws(M)
