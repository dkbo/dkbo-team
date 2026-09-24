# backend-test 報告（波 1）
## 做了什麼
- AC3：`tests/helpers.bash` 新增 `fixture_copy_dkbo SRC_REPO DEST_DKBO`，`setup_project` 改呼叫它。照舊 `cp -r` 整份 `.dkbo`、清 `.sessions/`；SRC 是 git 倉時（`rev-parse --is-inside-work-tree`）用 `git --no-optional-locks` 加 plumbing：`ls-files -z --others --exclude-standard --directory -- .dkbo/tasks` 刪未追蹤項目，`diff-index -z --name-only --relative HEAD -- .dkbo/tasks` 列出的檔用 `git show HEAD:./<p>` 還原（HEAD 沒有的、只加進 index 的檔就刪掉）。`.dkbo/tasks/` 以外不動。非 git 來源只做前兩步、不報錯；沒有 HEAD 的倉，diff-index 的 stderr 靜音。註解寫了例外（tasks/ 底下含 BACKLOG.md 的未 commit 改動不會進夾具）。
- AC3 測試（36）：+3 條——髒主樹經 `REPO_ROOT=… setup_project`（未追蹤任務資料夾含 `.panes`/`.task.env`/state、改過的 INDEX.md 與 decisions.md、被刪的 BACKLOG.md、未追蹤 `bin/newtool`、tasks/ 以外改過的 PROTOCOL.md；也驗來源不動）；不刷新來源 index（比 `.git/index` 的 inode＋奈秒 mtime）；非 git 來源。
- AC4（11）：+1 條 legacy 新版模板（沒有 `branch:` 行）→ exit 0、INDEX done、分支名稱清單不變、main 沒有 merge commit、沒印 `merge conflict`。
- AC2：新檔 `tests/unit/37_shellcheck.bats`（3 條）：setup 沒裝就 skip（訊息照 AC）；`sc_targets` 是唯一一處檔案集合（同全域約束那一行）；`sc_run` 是②③共用的呼叫、失敗時印 shellcheck 原文；另一條確認集合涵蓋五類檔；③ 用含 `echo $x` 的暫存腳本驗 `sc_run` 回非零且輸出含 SC2086。`tests/run.sh` 沒改。
## 測試
### 紅
- AC3（先寫測試、還沒實作 helpers）：`tests/run.sh tests/unit/36_fixture.bats` → `not ok 10 髒主樹跑 setup_project…`（`[ ! -e "$DK_ROOT/tasks/2026-09-24-live" ]` 失敗，列出 .panes .task.env state）；`not ok 11`、`not ok 12`：`fixture_copy_dkbo: command not found`（status 127）。
- AC3 index 鎖探針（cp 到 scratchpad/probe36，在 fixture_copy_dkbo 裡插一行 `git -C "$src" status`）：`tests/run.sh tests/unit/36_fixture.bats` → `not ok 11 fixture_copy_dkbo：不刷新來源的 index` `[ "$before" = "$after" ]' failed`，證明那條會抓到刷新 index 的指令。
- AC4 突變探針（cp 到 scratchpad/probe11，刪掉 dk-chore-close 的 `[ -n "$branch" ] || branch="-"` 那行，`grep -c 'branch="-"'` 得 0）：`tests/run.sh tests/unit/11_chore.bats` → `not ok 20 legacy：沒有記錄檔、雜務檔是新版模板…`，輸出 `dk-chore-close: merge conflict on ; ask the human`。
- AC2 探針（cp 到 scratchpad/probe37，在 `.dkbo/lib/common.sh` 尾端加 `echo $y`）：`tests/run.sh tests/unit/37_shellcheck.bats` → `not ok 1 全域約束的檔案集合 shellcheck 零警告`，輸出含 `In .dkbo/lib/common.sh line 182: echo $y … SC2086`。沒裝 shellcheck（probe37 用拿掉 shellcheck 的 PATH 跑 bats）→ 三條都是 `# skip shellcheck 未安裝，跳過（CI 與開發機請裝）`。
- 中途紅（已修，見自我審查）：11 新測試第一版比對 `refname objectname` → `not ok 20` 分支比對失敗。
### 綠
- `tests/run.sh tests/unit/36_fixture.bats` → `1..12`，12 條全 ok。
- `tests/run.sh tests/unit/11_chore.bats` → `1..41`，全 ok（含 `ok 20 legacy：…新版模板…`）。
- `tests/run.sh tests/unit/37_shellcheck.bats` → `1..3`，3 條全 ok（本機 shellcheck 0.9.0，是實跑不是 skip）。
- 完整套件 `tests/run.sh`（在共用 worktree、夥伴改動未完成時跑一次）→ `1..752`，749 ok、3 not ok，rc=1：
  - `not ok 153 AC5: 守望已死時 dev 對 leader 的 [DONE]（只落盤、不送達）把它叫回來`（tests/unit/06_msg.bats:569）
  - `not ok 154 AC5: 一般 [QUESTION] 送達路徑也把守望叫回來`（06_msg.bats:580）
  - `not ok 155 AC5: [UNDELIVERED] 出口也把守望叫回來`（06_msg.bats:588）
  三條都在 backend-watch 的檔（06_msg.bats／dk-msg），當時 `.dkbo/bin/dk-msg` 還沒改，是夥伴進行中的紅測試，不是 helpers 的回歸。我的 36/11/37 在全套裡都是 ok（743–745、352、750）。
## 自我審查
- 11 第一版斷言「分支清單不變」比了 objectname → 紅。重現：scratchpad/dbg.bats 印出 close 前後的 refs 與 log → `dk-chore` 沒動分支，`dk-chore-close` 在 main 上 commit 一筆 `dkbo memory: chore fix`。根因：close 本來就會把 main 往前推一筆記憶 commit，所以比 sha 必紅；改成只比分支名稱，並加 `rev-list --merges main` 為空，確認沒有 merge。排除「dk-chore 建了分支」這個假設（前後 refs 相同）。
- fixture_copy_dkbo 第一版把 `g` 從字串改成陣列時漏刪一行舊的 `g="…"` 賦值，36 在探針裡紅；刪掉後重跑 12/12。
- 只用 plumbing（rev-parse、ls-files、diff-index、cat-file、show），都加 `--no-optional-locks`；`diff-index` 不刷新 stat，stat 髒的檔可能被誤列，但還原成 HEAD 版等於同內容，無害。
- `--relative` 加 `HEAD:./<p>`：SRC 就算不是倉頂也能對上路徑。
- helpers 不在 shellcheck 集合裡；`shellcheck -s bash tests/helpers.bash` 的提示全是既有行（34、72、76、115、128、144、152），新函式沒有新增。
- 37 沒有 setup_project：shellcheck 不 source common.sh、不碰 herdr，沒有 DK_* 外洩的風險。35 hygiene 在全套裡是綠的（沒有 `! cmd`）。
## 疑慮
- 36 的 index 測試用 `stat -c`、`touch -d`（GNU）。既有測試本來就用 GNU `sed -i`，套件只在 Linux 跑，所以沿用；macOS 上跑套件會是另一件事。
- 夾具現在不再帶 tasks/ 底下未 commit 的改動：以後若有測試要讀夾具裡的 BACKLOG.md 或 INDEX.md 的新內容，得先 commit，或改 fixture_copy_dkbo（註解已寫）。
- 全套的最終條數由 backend-docs 在三則 [DONE] 到齊後實跑為準。
