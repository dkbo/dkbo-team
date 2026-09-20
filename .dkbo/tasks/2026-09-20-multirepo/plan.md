# 多 repo workspace — 一個任務一個 herdr workspace，N 個 repo 各一個 worktree

狀態：設計草案，待計畫審查與關卡①
日期：2026-09-20
來源：request.md（人的四條形狀）＋ 領導對 0.9.2 程式碼的逐支盤點
目標版本：0.10.0

## 1. 這是什麼

兩件事，刻意綁在同一個任務裡，因為它們改的是同一批腳本的同一段（任務的「地基」：worktree、workspace、pane 錨點）：

**A. 一個任務一個 herdr workspace，在 `/dkbo-run` 那一刻才建。** 計畫階段（寫 brief、計畫審查、關卡①）在人的 session 裡互動，`dk-task-new` 只建任務資料夾，不切 worktree、不開 workspace——計畫完可能不做，不先付那些成本。`/dkbo-run` 時 `dk-leader <short> --run` 把任務「實體化」：切 worktree、跑依賴鉤子、用 `herdr workspace create` 開 workspace（label 與 tab 名都是分支名 `dk/<short>`）、在根 pane 起一位執行領導、交棒。員工格子從此填在那個 workspace 的 tab 1 右側，人的 session 空出來開下一個任務。

**B. 一個任務 N 個 repo。** `settings.env` 新增 `DK_REPOS`，列出這個專案由哪幾個獨立 git repo 組成。設了它，`dk-leader --run` 對每個 repo 各切一個同名分支 `dk/<short>` 的 worktree；brief 的檔案所有權、state 的 `touched`、`dk-wave-close` 的越界比對、`dk-review-pack` 的差異包、`dk-task-close` 的合併，全部長出 repo 這個維度。**沒設 `DK_REPOS` 的專案（單 repo）行為與 0.9.2 相同**，只多了 A。

## 2. 為什麼

- 前後端分倉的專案（panova 那一類）今天沒辦法用 dkbo：一個任務只綁一個 worktree、一個 repo，所有權 glob 沒有地方寫「後端 repo 的 `src/api/**`」。這是 request.md 第 2 條。
- 員工 pane 寄生在領導的 workspace，領導同時只能帶一個任務；人想開第二個任務就得等，或用 `dk-leader` 在同一個 tab 再擠一欄。一個任務一個 workspace 之後，任務之間在 herdr 側邊欄上就是彼此獨立的一列（request.md 第 1、3、4 條）。
- 順手收掉 BACKLOG 兩條與 `dk-task-close` 有關的債：合併前先 commit 任務記憶（暫存中的改名會被誤報成 merge conflict）；把「本地變更會被覆蓋」與真衝突分成兩種訊息。這一版本來就要重寫 `dk-task-close` 的合併段，不收會再寫一次同樣的洞。

## 3. 已定案的決策

① **worktree 與 workspace 都在 `/dkbo-run`（`dk-leader --run`）才建立；workspace 用 `herdr workspace create --cwd <主樹>`，worktree 仍用 `git worktree add`，不用 `herdr worktree create`。** 計畫階段沒有任何 git 或 herdr 的副作用（除了人的 pane 改名與守望）：計畫完可能不做，`dk-task-close --abandon` 在那時只需要標記 INDEX 與 commit 記憶。base sha 也在 run 時取（計畫可能拖幾天，以交棒當下的 HEAD 為準比較對）。 `worktree create` 把 workspace 的 cwd 綁在 worktree 上，而領導必須站在主樹（`.dkbo/` 在主樹，領導跑的是主樹腳本，`PROJECT.md` 與 dogfood 記憶都寫死這件事）。0.2.x 已經為了控制權從 `herdr worktree create` 改回原生 git（CHANGELOG 0.2.x refactor(chore)），這裡不走回頭路。workspace 只是一個「cwd 指向主樹、label 是分支名」的容器，每個員工 pane 照舊自己 `--cwd`。`--env DK_ROOT=… HERDR_ENV=1` 一併給 workspace，根 pane 的 shell 從此就有領導需要的環境。

② **兩個 pane、兩種角色，拆成兩個變數。** `DK_ROOT_PANE` 是**版面錨點**（tab 1 左欄那格）；新增 `DK_LEADER_PANE` 記**領導在哪**。計畫階段兩者都是人的 pane（與今天相同，計畫審查的 reviewer 就填在人的 workspace 右側）；交棒時 `dk-leader --run` 把兩者都改寫成任務 workspace 的根 pane。分開的理由：交棒之後版面錨點與領導仍是同一格，但 `dk-msg`／`dk-watch` 的退路語意是「領導在哪」，不該借用版面變數的名字；而且 `DK_WORKSPACE`、`DK_ROOT_PANE`、`DK_WORKTREE`、`DK_BASE` 都會在 run 時被改寫一次，`dk-watch` 每輪重讀 `.task.env`，自動跟上。`dk-msg leader` 與 `dk-watch` 的 pane id 退路改讀 `DK_LEADER_PANE`（缺席時退回 `DK_ROOT_PANE`，舊任務不壞）。今天這兩個角色是同一個 pane，所以一個變數夠；分開之後一定要拆，否則計畫階段的守望會把 `[BLOCKED]` 推給一個空 shell。

③ **實體化與交棒都在 `/dkbo-run`，用 `dk-leader <short> --run`。** 依序：`dk_repos_check` → 每個 repo `git worktree add -b dk/<short>`（base＝該 repo 當下 HEAD）→ 每個 worktree 跑 `DK_SETUP_CMD` 鉤子（決策⑮）→ 寫 `.repos` → `herdr workspace create --cwd <主樹> --label dk/<short> --env …` → `tab rename` → 改寫 `.task.env`（`DK_WORKSPACE`、`DK_ROOT_PANE`、`DK_LEADER_PANE`＝根 pane；`DK_WORKTREE`、`DK_BASE`＝主 repo 的）→ 人的 pane 的 `leader-<short>` 名字 `--clear`（名字唯一）→ 根 pane 上 `herdr agent start leader-<short>`（kind `DK_LEADER_KIND`、L 檔、`--name dk/<short>`）→ `.sessions/<根 pane>` 綁任務、解綁人的 pane → 第一段提示「讀 LEADER.md 與 run/SKILL.md，`dk-resume <任務>`，開始跑波」。agent start 之前任一步失敗就 rollback（worktree、分支、workspace、`.task.env` 還原成計畫階段的值）；agent start 之後失敗照現行 `dk-leader`（pane 留著、印診斷、exit 1）。重跑幂等：worktree 已在且 workspace 活著就跳到 agent start；根 pane 已有 `leader-<short>` 就只印「已交棒」。`skills/run/SKILL.md` 加第 0 步：`.task.env` 的 `DK_WORKTREE` 為空（還沒實體化）或 `HERDR_PANE_ID` 不等於 `DK_ROOT_PANE` 就 `dk-leader <short> --run` 並結束 turn。計畫階段刻意留在人的 session：brief 要跟人來回改，關卡①要人看三份文件，那是互動不是背景工作。

④ **herdr 的 agent 名維持 `leader-<short>`；AI CLI 那側的 session 名改成 workspace 名 `dk/<short>`。** request.md 第 4 條「agent 名改成 workspace 名」指的是 CLI 那側（人補充：claude 有 rename），不是 herdr 的註冊名：`claude -n/--name <name>` 設 session 顯示名（session picker 與終端標題），`/rename` 是互動中的同一件事。所以 `dk-leader --run` 起執行領導時，kind 是 claude 就多帶 `--name "dk/<short>"`；codex／agy 沒有對應旗標就不帶。實作是 `kinds/<kind>.sh` 新增 `kind_session_args NAME`（claude 回 `--name NAME`，其餘回空），`dk-leader`（兩種模式都）與 `dk-spawn` 不動員工。herdr 註冊名不改：合法字元 `[a-z][a-z0-9_-]{0,31}` 放不進 `/`，而 `dk-msg`、`dk-watch`、`dk-resume`、`dk-task-new`、`dk-leader`、`dk-task-close` 六支都以 `leader-<short>` 為主鍵。人在側邊欄看到 workspace `dk/<short>`，pane 標題也是 `dk/<short>`，`claude --resume` 的清單裡也找得到它。

⑤ **`DK_REPOS` 是唯一的新設定鍵，空字串 = 單 repo 模式。** 格式 `DK_REPOS="app=. api=../sport-backend shared=../sport-shared"`：空白分隔、`<名>=<路徑>`，路徑相對 `DK_PROJECT_ROOT`（絕對路徑也收）。第一個必須是主 repo（路徑 `.`），主 repo 就是放 `.dkbo/` 的那個。名字 `[a-z][a-z0-9_]{0,15}`（要能當 shell 變數名的尾巴，見⑨）。`dk_settings` 讀它；`dk_repos_check` 驗每個路徑是 git repo 的根、工作樹乾淨（與今天對主 repo 的要求一致）、名字不重複；`/dkbo-init` 問它。**單 repo 模式下所有 repo 維度的語法都是 FAIL**（所有權 glob 帶前綴、`DK_TEST_CMD_<名>` 有值），不允許半套。

⑥ **worktree 佈局：多 repo 模式 `.worktrees/<short>/<名>`，全部（含主 repo）放在主 repo 底下；單 repo 模式維持 `.worktrees/<short>`。** 放主 repo底下有兩個實際好處：Claude Code 的信任按路徑前綴繼承（decisions 2026-09-13），其他 repo 的 worktree 開在主專案目錄下就不用逐個信任；`.gitignore` 的 `.worktrees/` 一條就蓋住全部。`DK_WORKTREE_DIR` 照舊可以改根。

⑦ **所有權與 `touched` 的 repo 維度是 `<名>:<glob>` 前綴。** 多 repo 模式下 brief 的可改、只讀兩欄每個 glob 都必須帶前綴且名字在 `DK_REPOS` 內（`dk-brief-check` FAIL）；單 repo 模式下帶前綴是 FAIL。重疊檢查只在同一 repo 內比。state 的 `touched` 同一套前綴。`dk_owned` 與 `dk_changed_files` 學會前綴：`dk_changed_files` 逐 repo 跑今天那個 throwaway index 的招，輸出加前綴；gate d 的 `unowned change: api:src/x.ts` 與 `unreported change` 訊息都帶前綴。`:` 與獨佔資源欄的 `port:3000` 是不同欄，不撞。

⑧ **成員的 pane cwd = 它第一個可改 glob 的 repo 的 worktree；所有 repo 的 worktree 都進 `--add-dir`。** 不新增「成員的家」欄位——第一個 glob 就是宣告。三個 kind 的 `kind_args` 改成讀 `DK_ADD_DIRS`（空白分隔，預設只有 `$DK_PROJECT_ROOT`，與今天相同），每一項一個 `--add-dir`。跨 repo 的成員（例如同時改 `api:` 與 `shared:`）可以直接在另一個 worktree 裡工作，邊界仍由 gate d 的真實 diff 守（decisions 2026-09-19：邊界靠 worktree 隔離與 diff 比對，不靠 CLI 審批 UI）。切片多一段「## 倉庫」列出 `<名> → <worktree 路徑>`，首輪提示點名「你的 pane 在 <名> 的 worktree」。

⑨ **測試指令每 repo 一條：主 repo 沿用 `DK_TEST_CMD`，其餘 `DK_TEST_CMD_<名>`。** gate c 只對**本波有變更**的 repo 跑它的指令（在該 repo 的 worktree 內、同一套 `env -u DK_*` 乾淨環境）；沒設指令的 repo 記 `tests: <名> skipped (no DK_TEST_CMD_<名>)` 並在 wave-close 輸出警告，不擋。**不做跨 repo 整合測試的鉤子**：gate c 刻意剝掉所有 `DK_*`，整合測試要知道別的 worktree 在哪就得再開一條傳遞管道，這一版不開；整合測試是專案自己的 CI 的事（見第 9 節）。

⑩ **差異包一份檔、分段。** `dk-review-pack` 對每個有變更的 repo 各出一段 `## repo <名>`（commits、stat、diff），reviewer 仍只讀 `waves/N.diff` 一個檔；`file:line` 寫成 `<名>:<路徑>:<行>`（`roles/reviewer.md` 補一句）。`wave-open N base <sha>` 那行維持記主 repo（`dk_wave_base` 舊呼叫不變），另加每 repo 一行 `wave-open N repo <名> base <sha>`，`dk_wave_base DIR N [REPO]` 多一個選填參數。

⑪ **`dk-wave-close` 在每個有變更的 repo 各 commit 一次**，訊息相同（`wave N: <成員>` 或 `-m`）。`commit failed` 的訊息點名是哪個 repo。

⑫ **`dk-task-close` 兩階段合併，先 commit 記憶。** 順序：(1) 任務記憶 `dk_commit_memory`（提前到合併之前——BACKLOG 2026-09-19「暫存中的改名擋住 merge」）；(2) 預檢：每個 repo 的 worktree 乾淨、主樹該分支可 fast-forward 或無衝突（`git merge --no-commit --no-ff` 後立即 `merge --abort`），任一 repo 衝突就列出**全部**衝突的 repo、什麼都不合、exit 3；「local changes would be overwritten」另給訊息與 exit 5，指人去 commit 或 stash 主樹的改動；(3) 逐 repo 真合併，中途意外失敗停在原地，印 `merged: a b / failed: c / not attempted: d`，exit 4，worktree 與分支一律不刪。**不自動關 workspace**：跑 `dk-task-close` 的執行領導就住在那個 workspace 的根 pane，關了它等於腳本殺掉自己、結案訊息沒人看到；結尾印一行「看完 report 之後 `herdr workspace close <id>`」。tab 2 起照舊關掉。

⑬ **`dk-chore` 不動。** 雜務本來就有 `--cwd`，`--code` 雜務只在主 repo 開 worktree；多 repo 的雜務需求出現再說。

⑮ **每個 worktree 切好後跑一次 `DK_SETUP_CMD`／`DK_SETUP_CMD_<名>`，策略由專案決定，dkbo 只給鉤子。** `git worktree add` 不複製 `node_modules`（gitignored），真正的成本是每個 worktree 各裝一次依賴。人選 pnpm：它的 content-addressable store 讓第二次 `pnpm install --frozen-lockfile --prefer-offline` 幾乎全是 hardlink，秒級、幾乎不佔磁碟，lockfile 在任務分支改了也正確。symlink 主樹的 `node_modules` 不採用：任務分支改了 lockfile 時 worktree 拿到舊依賴，而且 `node_modules` 變成全隊共用的執行環境。鉤子在 `dk-task-new` 於該 worktree 內、以 gate c 同一套 `env -u DK_*` 乾淨環境執行；失敗只警告並記 `setup <名> failed`，不 rollback（多半是網路，worktree 本身是好的）。

⑭ **版號 0.10.0**：新設定鍵、任務地基改形、`.task.env` 新欄位，是 minor 不是 patch。

## 4. 生命週期（多 repo 模式；單 repo 模式把「每個 repo」讀成「主 repo」即可）

```
人（自己的 session）
  /dkbo-plan ──▶ dk-task-new <short> "<顯示名>"
                  ├─ 只建任務資料夾：request.md、brief.md、process.md、.task.env、messages.log、state/
                  ├─ .task.env：DK_WORKSPACE／DK_ROOT_PANE／DK_LEADER_PANE＝人的 workspace 與 pane；DK_WORKTREE=""、DK_BASE=""
                  └─ 人的 pane 改名 leader-<short>（同今天）；dk-watch 起。沒有 git、沒有 herdr workspace 的副作用
              寫 request.md、brief.md（所有權帶 <名>: 前綴）
              dk-brief-check（前綴、名字、同 repo 重疊）
              dk-brief-review（reviewer 填在人的 workspace 右側，cwd 主樹；[DONE] 送到 leader-<short>＝人的 pane）
              裁定 → 關卡① → dk-task-new <short> --gate1
              （計畫完不做：dk-task-close --abandon "<原因>"，只標 INDEX、commit 記憶）
  /dkbo-run ──▶ 第 0 步：DK_WORKTREE 空或 HERDR_PANE_ID ≠ DK_ROOT_PANE → dk-leader <short> --run
                  ├─ dk_repos_check：DK_REPOS 每個 repo 是乾淨的 git 根
                  ├─ 每個 repo：git worktree add -b dk/<short> .worktrees/<short>/<名> <該 repo 當下 HEAD>
                  ├─ 每個 worktree：DK_SETUP_CMD／DK_SETUP_CMD_<名>（pnpm install …；失敗只警告）
                  ├─ .repos：<名> <repo 根> <worktree> <base sha>
                  ├─ herdr workspace create --cwd <主樹> --label dk/<short> --env DK_ROOT=… --env HERDR_ENV=1 --no-focus
                  │    → tab rename 成 dk/<short>；.task.env 改寫 DK_WORKSPACE、DK_ROOT_PANE、DK_LEADER_PANE、DK_WORKTREE、DK_BASE
                  ├─ herdr agent rename <人的 pane> --clear
                  ├─ herdr agent start leader-<short> --kind $DK_LEADER_KIND --pane <根 pane> -- <L 檔旗標> --name dk/<short>
                  ├─ .sessions 改綁根 pane、解綁人的 pane
                  └─ 提示：讀 LEADER.md + run/SKILL.md，dk-resume <任務>，開始跑波
              人的 session 結束這個 turn，可以開下一個任務

執行領導（任務 workspace 根 pane）
  dk-wave-open N ── 每 repo 記 base；切片多「## 倉庫」段（DK_WORKTREE 仍空就拒絕：先交棒）
  dk-spawn ──────── cwd = 成員第一個 glob 的 repo worktree；DK_ADD_DIRS = 主樹 + 全部 worktree
  dk-review-pack ── 每個有變更的 repo 一段
  dk-wave-close ─── gate c 每個變更 repo 跑自己的測試；gate d 逐 repo 比對前綴所有權；每 repo commit
  dk-task-close ─── 記憶先 commit → 全部預檢 → 全部合併 → 刪 worktree 與分支 → 印「請自己關 workspace」
```

## 5. 檔案佈局

```
.dkbo/settings.env                 DK_REPOS（新）、DK_TEST_CMD_<名>（新，多 repo 時）、DK_SETUP_CMD／DK_SETUP_CMD_<名>（新）
.dkbo/lib/repos.sh                 新：DK_REPOS 解析、.repos 讀寫、前綴 glob 的拆解
.dkbo/tasks/<日期-短名>/
  .repos                           新：<名> <repo 根> <worktree> <base sha>；單 repo 模式也寫（一列，名字用主 repo 的）
  .task.env                        新欄 DK_LEADER_PANE；計畫階段 DK_WORKTREE／DK_BASE 為空，run 時連同 DK_WORKSPACE／DK_ROOT_PANE 一起改寫
  briefs/<成員>.md                 新段「## 倉庫」（單 repo 模式也印一列，格式一致）
  waves/N.diff                     多 repo 時分「## repo <名>」段
  waves/N.<名>.test.log            gate c 每 repo 一個 log（單 repo 模式檔名不變：N.test.log）
.worktrees/<short>/<名>/           多 repo 模式；單 repo 模式維持 .worktrees/<short>
```

`.repos` 在 `dk-leader --run` 時才出現；存在與否就是「實體化了沒」的判別器（`dk-resume` 據此印「尚未交棒」）。第一列永遠是主 repo。名字欄在單 repo 模式用 `DK_REPOS` 沒設時的固定值 `main`——只是為了讓每個讀 `.repos` 的呼叫端只有一條路，不是給人看的；單 repo 模式下任何面向人的輸出都**不印**前綴。

## 6. `lib/repos.sh` 規格（共用契約，wave 1 產出）

```
dk_repos_parse                      # 讀 $DK_REPOS → 每行 "<名> <絕對路徑>"；空字串 → 一行 "main <DK_PROJECT_ROOT>"
dk_repos_multi                      # 0 ⟺ DK_REPOS 非空
dk_repos_check                      # 驗名字合法且唯一、第一個是主 repo（路徑解析後等於 DK_PROJECT_ROOT）、
                                    # 每個路徑是 git 根、工作樹乾淨；任一不過 dk_die 並點名
dk_repos_write TASK_DIR SHORT WT_ROOT   # 建 .repos（不切 worktree，只算路徑與 base sha；切 worktree 是 dk-task-new 的事）
dk_repos_rows TASK_DIR              # cat .repos（跳過空行）
dk_repo_field TASK_DIR NAME FIELD   # FIELD = root | wt | base
dk_repos_names TASK_DIR             # 名字一行一個，主 repo 在前
dk_glob_split GLOB                  # "<名>:<glob>" → 印 "<名>\t<glob>"；沒前綴 → "\t<glob>"
dk_glob_check TASK_DIR GLOB         # 多 repo：必須有前綴且名字存在；單 repo：不得有前綴。非零＝違規，stdout 是理由
dk_repo_setup_cmd NAME              # 回該 repo 的 DK_SETUP_CMD（主）／DK_SETUP_CMD_<名>（其餘），沒設回空
kind_session_args NAME              # kinds/<kind>.sh：該 CLI 設 session 顯示名的旗標；claude → "--name NAME"，codex／agy → 空
dk_wave_base DIR N [REPO]           # 移到 common.sh 之外太大，留在 common.sh，但加第三個選填參數；
                                    # 有 REPO 時讀 "wave-open N repo <名> base <sha>"，沒有時行為不變
```

`kinds/*.sh` 的 `kind_args` 改讀 `DK_ADD_DIRS`（`lib/kinds.sh` 在呼叫前組好：`$DK_PROJECT_ROOT` 加上 `.repos` 每一列的 worktree，去重）。`dk_kind_args` 的簽名不變。

## 7. 對既有檔案的改動

### `bin/dk-task-new`
- **瘦身**：不再 `git worktree add`、不取 base sha、不碰 herdr workspace。`.task.env` 的 `DK_WORKTREE`／`DK_BASE` 寫空字串，`DK_WORKSPACE`／`DK_ROOT_PANE`／`DK_LEADER_PANE` 寫人的 workspace 與 pane（`templates/task.env` 加 `DK_LEADER_PANE="{{LEADER_PANE}}"`）。rollback 只剩任務資料夾與 `.sessions`。
- brief 標頭的 `worktree：` 印 `（/dkbo-run 交棒時建立）`。
- `--no-worktree` 保留旗標，改成寫進 `.task.env` 的 `DK_NO_WORKTREE="1"`，由 `dk-leader --run` 讀（多 repo 模式下拒絕）。
- 開場先 `dk_repos_check` 的「名字合法、第一個是主 repo、路徑是 git 根」三項（便宜、早失敗）；「工作樹乾淨」留到 run 時再驗。
- `--gate1` 不變。

### `bin/dk-leader`
- 現行用法（開第二位計畫領導）不變，只多接 `kind_session_args`。
- 新增 `dk-leader <short> --run`（決策③）：前置——任務存在、process 有 `gate1 approved`、沒有開著的波。
  - 實體化：多 repo 對每列 `git -C <根> worktree add -q -b dk/<short> <wt> HEAD`（單 repo 就是今天 `dk-task-new` 那幾行搬過來）；任一 repo 的 `dk/<short>` 分支已存在就整個拒絕（訊息列出是哪個 repo）；`DK_NO_WORKTREE=1` 時不切 worktree、`DK_WORKTREE=$DK_PROJECT_ROOT`（多 repo 拒絕）。
  - 每個 worktree 切好後：`dk_repo_setup_cmd <名>` 非空就在該 worktree 內用 gate c 的乾淨環境跑它，log 寫 `tasks/<t>/setup.<名>.log`；失敗印警告、記 `setup <名> failed`，繼續。
  - 寫 `.repos`；`herdr workspace create --cwd "$DK_PROJECT_ROOT" --label "dk/$short" --no-focus --env DK_ROOT=… --env HERDR_ENV=1`；取 `.result.workspace.workspace_id` 與 `.result.root_pane.pane_id`，缺任一 → rollback 並 die；`herdr workspace get` 取 `active_tab_id` 後 `herdr tab rename <tab> "dk/$short"`（失敗只記 process）。
  - 改寫 `.task.env`：`DK_WORKSPACE`、`DK_ROOT_PANE`、`DK_LEADER_PANE`、`DK_WORKTREE`（主 repo）、`DK_BASE`（主 repo）。
  - 交棒：`herdr agent rename "$HERDR_PANE_ID" --clear`（只在它叫 `leader-<short>` 時）→ 根 pane `herdr agent start leader-<short> --kind … -- $(dk_kind_args …) $(kind_session_args "dk/$short")` → `.sessions` 改綁 → 提示 `--wait --until working --timeout 15000`。
  - rollback（agent start 之前任一步失敗）：逐 repo `worktree remove --force` 與 `branch -D`、`herdr workspace close`、刪 `.repos`、`.task.env` 五個欄位還原。agent start 之後失敗不 rollback（照現行）。
  - 幂等：`.repos` 已在且 `herdr workspace get $DK_WORKSPACE` 成功 → 跳過實體化；根 pane 上 `herdr agent get` 已是 `leader-<short>` → 印「已交棒」exit 0。
  - 記 `dk_process "materialize repos <名 …> workspace <id>"` 與 `dk_process "handoff run-leader pane <id>"`。

### `bin/dk-msg`、`bin/dk-watch`
- 領導的 pane id 退路改 `${DK_LEADER_PANE:-${DK_ROOT_PANE:-}}`。`dk-watch` 每輪已重讀 `.task.env`，交棒後自動換目標。

### `skills/run/SKILL.md`、`skills/plan/SKILL.md`、`skills/init/SKILL.md`
- run 加第 0 步（交棒）與「交棒後人的 session 不再是領導」的說明。
- plan 的第 1 步註明 `dk-task-new` **只建資料夾**，worktree 與 workspace 到 `/dkbo-run` 才建；關卡①後多一句「計畫完不做就 `dk-task-close --abandon`，什麼都沒切」。
- init 問 `DK_REPOS`（列出候選：主專案的同層目錄裡是 git 根的），與每個 repo 的測試指令。

### `bin/dk-brief-check`
- 所有權表可改、只讀兩欄每個 glob 過 `dk_glob_check`；重疊比對先按 repo 分組。
- 波次表不變。

### `lib/ownership.sh`
- `dk_owned BRIEF WHO PATH`：PATH 帶前綴；glob 拆前綴後只比同 repo。
- `dk_changed_files TASK_DIR N`（簽名改：呼叫端只有 `dk-wave-close`，直接改）：逐 repo 用各自的 base，輸出加 `<名>:`；單 repo 模式不加。
- `dk_touched` 不變（前綴由員工照 PROTOCOL 寫）。

### `bin/dk-wave-open`
- `DK_WORKTREE` 為空（還沒交棒）→ `dk_die "任務尚未實體化：先 dk-leader <short> --run"`。
- 每 repo 記 `wave-open N repo <名> base <sha>`（主 repo 的 sha 同時寫進既有那行）。
- 切片新段「## 倉庫」：`templates/brief-member.md` 加 `{{REPOS}}`。

### `bin/dk-spawn`、`lib/prompt.sh`、`lib/kinds.sh`、`kinds/*.sh`
- cwd：`dk_brief_owners` 取成員第一個可改 glob → `dk_glob_split` → `dk_repo_field wt`；單 repo 模式就是 `DK_WORKTREE`。`worktree: false` 的角色（pm）照舊 `DK_PROJECT_ROOT`。**`DK_WORKTREE` 為空時（計畫階段的 `--isolated` reviewer）cwd 用 `DK_PROJECT_ROOT`**，版面錨點仍是 `DK_ROOT_PANE`（此時＝人的 pane，與今天相同）。
- `DK_ADD_DIRS` 組好後 export 再叫 `dk_kind_args`；三個 kind 的 `kind_args` 迴圈輸出。
- 首輪提示多一句：「你的 pane 在 `<名>` 的 worktree（<路徑>）；其他 repo 的 worktree 見切片的『## 倉庫』段；`touched` 與所有權都以 `<名>:` 開頭」。單 repo 模式這句不印。

### `bin/dk-review-pack`
- 逐 repo（有變更者）出段；`files changed` 為總和；沒有任何 repo 有變更時的警告不變。

### `bin/dk-wave-close`
- gate c：見③⑨；log 檔名 `N.<名>.test.log`（單 repo 模式維持 `N.test.log`）。
- gate d：用新的 `dk_changed_files`；訊息帶前綴。
- commit：逐 repo；`wave N 耗時` 那行不變。

### `bin/dk-task-close`
- 第 3 節⑫。`--abandon` 也要逐 repo 刪 worktree 與分支，且**沒有 `.repos`（計畫階段就放棄）時只標 INDEX、commit 記憶、清 `.sessions`、清人的 pane 名字**。`legacy` 路徑（`.task.env` 沒有 `DK_BASE=` 這一行的舊任務）不動；`DK_BASE=""` 是「尚未實體化」不是 legacy。

### `bin/dk-resume`
- 本波段之前印一張 `.repos` 表（單 repo 模式一列，不印前綴欄）；`.repos` 不存在就印「尚未交棒（/dkbo-run 會 dk-leader <short> --run）」。

### `PROTOCOL.md`、`LEADER.md`、`roles/reviewer.md`、`templates/brief.md`、`templates/brief-member.md`、`README.md`、`README.en.md`、`.dkbo/README.md`、`CHANGELOG.md`、`VERSION`、`bin/dk-version`
- PROTOCOL：`touched` 與「只能修改切片劃給你的檔」兩處加前綴說明；「執行環境全隊共用」那段加一句「多個 repo 的 worktree 都在 `.worktrees/<short>/` 底下，都是本任務的」。
- LEADER：設定鍵清單加 `DK_REPOS`。
- README 三份：運作方式圖改成「人的 session → 任務 workspace（領導＋員工）」；日常使用加「交棒」；疑難排解加「`dk-task-close` 回 exit 3／4／5」三列與「workspace 沒關」一列。
- 版號 0.10.0。

## 8. 測試計畫（bats，假 herdr）

**stub**：`tests/stub/responses/workspace_create.json`（`.result.workspace.workspace_id`＝`wC`、`.result.root_pane.pane_id`＝`wC:p1`；形狀比照 `worktree_create.json`，實機形狀由整合腳本驗——見 AC17）、`workspace_get.json`（`active_tab_id`）。stub 的 `agent get` 在 `--pane` 目標沒 agent 時回空（`dk-leader --run` 的幂等判斷靠它）。

**helpers**：`setup_multirepo`（在 `$PROJECT` 之外另建兩個 git repo，`settings.env` 追加 `DK_REPOS="main=. api=<絕對路徑> shared=<絕對路徑>"` 與 `DK_TEST_CMD_api`），`fixture_task` 學會多 repo（寫 `.repos`）。

新增 `tests/unit/33_repos.bats`：
1. `dk_repos_parse` 空字串 → `main <root>`；三列格式；相對路徑解析
2. `dk_repos_check` 拒絕：名字不合法、重複、第一個不是主 repo、路徑不是 git 根、工作樹不乾淨（各一條，訊息點名 repo）
3. `dk_glob_check`：多 repo 缺前綴 FAIL、未知名字 FAIL；單 repo 帶前綴 FAIL
4. `dk_wave_base` 第三參數

既有檔補：
5. `05_task_new`：不再切 worktree、不叫 `workspace create`（既有的 worktree 斷言搬到 13）；`DK_WORKTREE=""`、`DK_BASE=""`、`DK_LEADER_PANE="wB:p1"`；brief 標頭印「交棒時建立」；`--no-worktree` 只寫 `DK_NO_WORKTREE`；名字不合法／第一個非主 repo／非 git 根在 task-new 就拒絕
6. `13_leader`：`--run` 單 repo 正常路徑（worktree 在 `.worktrees/<short>`、分支 `dk/<short>`、`.repos` 一列、`workspace create` 被叫且 `.task.env` 五個欄位改寫、`tab rename dk/<short>`、rename --clear、agent start 在根 pane 且含 `--name dk/<short>`、`.sessions` 改綁）；多 repo 三個 worktree 都在 `.worktrees/<short>/<名>`、`.repos` 三列、`DK_SETUP_CMD_api` 在 api 的 worktree 內被執行（用會落檔的假指令驗）、失敗時仍 exit 0 且 process 有 `setup api failed`、沒設不執行；`workspace create` 失敗 → 三個 worktree、分支、`.repos` 都清且 `.task.env` 還原；工作樹不乾淨拒絕；多 repo 下 `DK_NO_WORKTREE` 拒絕；沒 gate1 拒絕；有開著的波拒絕；重跑幂等
7. `06_msg`、`09_watch`：退路讀 `DK_LEADER_PANE`，缺席時退回 `DK_ROOT_PANE`
8. `16_brief_check`：前綴規則、同 repo 重疊 FAIL、跨 repo 同 glob 不算重疊
9. `22_ownership`：`dk_owned` 帶前綴；`dk_changed_files` 逐 repo 加前綴、單 repo 不加
10. `07_spawn`：cwd 取自第一個 glob 的 repo；`--add-dir` 三個 kind 各出 N 個
11. `18_wave_open`：每 repo 一行 base；切片有「## 倉庫」
12. `19_review_pack`：分段；只出有變更的 repo
13. `08_wave_close`：gate c 只跑變更的 repo、缺指令 skipped 不擋、log 檔名；gate d 前綴訊息；逐 repo commit
14. `12_task_close`：記憶先 commit；預檢一個 repo 衝突 → 全部不合、exit 3、列出名字；本地變更 exit 5；全過 → 三個都合併、worktree 與分支都刪、workspace **沒**被 close；`--abandon` 逐 repo 清
15. `03_kinds`：`DK_ADD_DIRS` 多項；`kind_session_args`：claude 回 `--name X`、codex 與 agy 回空
15b. `13_leader`：兩種模式的 `agent start` 對 claude 含 `--name dk/<short>`，`--kind codex` 時不含
16. `21_version`、`04_docs`、`25_docs_policy`：版號與文件一致

**整合**：`tests/integration/herdr-real.sh` 加三個探針：`workspace create --cwd --label --env` 的回傳欄位、`workspace get` 的 `active_tab_id`、對一個既有根 pane 做 `agent start`。發版前跑一次（零 token）。

## 9. 已知限制

- **跨 repo 整合測試沒有機械閘**（決策⑨）。gate c 對每個 repo 各跑各的；「前端改了 API 呼叫、後端改了路由，各自綠燈但接不起來」要靠 qa 或專案自己的 CI。
- **agy 的信任詢問每個 worktree 一次**：`trustedWorkspaces` 逐路徑精確比對、不繼承（decisions 2026-09-19），N 個 repo 就是 N 次；claude 靠路徑前綴繼承沒事。BACKLOG 既有那條的範圍變大，不在這一版解。
- **`herdr workspace create` 的回傳形狀未在真機驗過**（`api schema` 查不到 response 定義）。stub 比照 `worktree create`；AC17 要求發版前用整合腳本驗一次，形狀不同就改 `dk-task-new` 的 jq 路徑與 stub。
- **主樹合併不是真的原子**：預檢與真合併之間主樹若被別人 commit，理論上可能預檢過、真合併炸。一個人一台機器的設定下可忽略；exit 4 的訊息足夠人手收尾。
- **交棒後人的 session 失去 `dk-msg leader` 的收件身分**：員工的訊息都去執行領導那裡。人要看進度用 `dk-resume <任務>`（唯讀）或切到那個 workspace。

## 10. 不做什麼

- 不做「一個 workspace 綁 N 個 worktree」的 herdr 原生形狀——herdr 沒有，也不需要（每個 pane 自己 `--cwd`）。
- 不做每成員的「家」欄位（決策⑧）。
- 不做跨 repo 整合測試鉤子（決策⑨）。
- 不自動關 workspace（決策⑫）。
- 不動 `dk-chore`（決策⑬）。
- 不改 `lib/layout.sh` 的版面規則（tab 1 左欄仍是根 pane，`DK_TAB1_SLOTS` 照舊）——workspace 換了，版面形狀沒換。
- 不做 `--no-workspace` 退路：兩套版面等於兩套測試矩陣。
- 不寫 markdown parser 驗 `DK_REPOS` 以外的東西。

## 11. 驗收標準

- [ ] AC1 `DK_REPOS` 空字串時，0.9.2 的 426 條測試語意不變：不刪、不放寬既有斷言；只允許（a）把 `05_task_new` 裡 worktree／base 的斷言原樣搬到 `13_leader` 的 `--run` 測試，（b）改 `DK_WORKSPACE`／`DK_ROOT_PANE`／`DK_WORKTREE`／`DK_BASE` 在計畫階段的期望值，（c）新增斷言
- [ ] AC2 `dk-task-new` 只建任務資料夾：不切 worktree、不開 workspace、`DK_WORKTREE`／`DK_BASE` 為空、`DK_LEADER_PANE` 為呼叫者 pane；計畫階段 `dk-task-close --abandon` 不需要任何 worktree 或 workspace 就能收乾淨
- [ ] AC3 `dk-leader <short> --run` 實體化：對 `DK_REPOS` 每個 repo（單 repo 就是主 repo）切出 `dk/<short>` 的 worktree（多 repo 在 `.worktrees/<short>/<名>`，單 repo 在 `.worktrees/<short>`）、寫 `.repos`、用 `herdr workspace create` 開 label 與 tab 名皆為 `dk/<short>` 的 workspace、改寫 `.task.env` 的 `DK_WORKSPACE`／`DK_ROOT_PANE`／`DK_LEADER_PANE`／`DK_WORKTREE`／`DK_BASE`；agent start 之前任一步失敗 rollback 全部 worktree、分支、workspace 並還原 `.task.env`
- [ ] AC4 `dk_repos_check` 對名字不合法、重複、第一個非主 repo、非 git 根、工作樹不乾淨各自拒絕並點名 repo
- [ ] AC5 `dk-brief-check` 多 repo 模式下缺前綴或未知名字 FAIL；單 repo 模式下帶前綴 FAIL；重疊只在同 repo 內判
- [ ] AC6 `dk-leader <short> --run` 交棒：清掉呼叫者 pane 的 herdr 註冊名 `leader-<short>`、在新 workspace 根 pane 起 herdr 註冊名同為 `leader-<short>` 的執行領導（session 名 `dk/<short>`，AC19）、改綁 `.sessions`；缺 `gate1 approved` 或有開著的波時拒絕；重跑幂等（已實體化就跳過實體化，已交棒就只印「已交棒」）
- [ ] AC7 `dk-msg leader` 與 `dk-watch` 的 pane 退路讀 `DK_LEADER_PANE`，缺席時退回 `DK_ROOT_PANE`
- [ ] AC8 `dk-spawn` 的 pane cwd 是成員第一個可改 glob 所在 repo 的 worktree；三個 kind 對 `.repos` 每一列各出一個 `--add-dir`
- [ ] AC9 `dk-wave-open` 在 `DK_WORKTREE` 為空時拒絕並指向 `dk-leader --run`；每 repo 記一行 `wave-open N repo <名> base <sha>`；`dk_wave_base DIR N REPO` 讀得到；切片含「## 倉庫」段
- [ ] AC10 `dk-review-pack` 對每個有變更的 repo 各出一段 `## repo <名>`，`files changed` 是總和
- [ ] AC11 `dk-wave-close` gate c 只對本波有變更的 repo 跑 `DK_TEST_CMD`（主）／`DK_TEST_CMD_<名>`（其餘），缺指令記 skipped 不擋，log 檔 `N.<名>.test.log`
- [ ] AC12 `dk-wave-close` gate d 逐 repo 比對，`unowned change`／`unreported change` 訊息帶 `<名>:` 前綴；每個有變更的 repo 各 commit 一次
- [ ] AC13 `dk-task-close` 在合併前先 commit 任務記憶；預檢任一 repo 衝突就全部不合併、exit 3 並列出全部衝突 repo；主樹本地變更 exit 5；真合併中途失敗 exit 4 並印 merged／failed／not attempted；全過時逐 repo 刪 worktree 與分支
- [ ] AC14 `dk-task-close` 不呼叫 `herdr workspace close`，結尾印出要人自己關的指令
- [ ] AC15 `skills/run/SKILL.md` 有第 0 步交棒；`skills/plan/SKILL.md`、`skills/init/SKILL.md`、`PROTOCOL.md`、`LEADER.md`、`roles/reviewer.md`、三份 README、CHANGELOG 都提到 repo 前綴或交棒（各自對應的那一段），`tests/unit/04_docs.bats` 或 `25_docs_policy.bats` 有斷言守著
- [ ] AC16 版號 0.10.0：`VERSION`、`dk-version`、README 安裝段、CHANGELOG 一致，`21_version.bats` 全過
- [ ] AC17 `tests/integration/herdr-real.sh` 加 `workspace create`／`workspace get`／根 pane `agent start` 三個探針；發版前在真 herdr 跑過一次並把 NOTE 行貼進 report.md
- [ ] AC20 `dk-leader --run` 在每個 worktree 切好後跑 `DK_SETUP_CMD`／`DK_SETUP_CMD_<名>`（乾淨環境、失敗只警告並記 process、沒設跳過、單 repo 也適用）；init 會問；README 給 pnpm 寫法與 symlink 的坑
- [ ] AC19 `dk-leader`（含 `--run`）起 claude 領導時 `agent start` 帶 `--name dk/<short>`；kind 為 codex／agy 時不帶；`kind_session_args` 三個 kind 各有測試
- [ ] AC18 `tests/run.sh` 全綠、`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh` 零警告

## 12. 關卡①要問人的（領導的建議在前）

1. **agent 名**（已由人的補充解決）：herdr 註冊名維持 `leader-<short>`；claude 領導以 `--name dk/<short>` 啟動，session 名與終端標題就是 workspace 名（決策④）。codex／agy 領導沒有對應旗標，只有 herdr 的 workspace label。只需確認這樣符合你的意思。
2. **workspace 何時開**（已由人裁定）：`/dkbo-run` 時才建，worktree 與依賴安裝也一起延後——計畫完可能不做，不先付成本。計畫審查的 reviewer 留在人的 workspace 右側（與今天相同）。
3. **單 repo 專案也走 workspace**：建議是（決策⑤與「不做 `--no-workspace`」）。panova 那邊下一次升級後，每個任務都會在側邊欄多一列、`/dkbo-run` 會交棒。
4. **結案不關 workspace**：建議是（決策⑫）。
