# backend-gates 報告（波 2）

## 做了什麼

五支腳本長出 repo 維度，對應 AC8–AC12。單 repo 模式（`DK_REPOS=""`）一律走 0.9.2 的原路，
面向人的輸出不印任何 repo 前綴。

### AC9 `bin/dk-wave-open`、`templates/brief-member.md`
- 計畫階段（`DK_WORKTREE` 為空）拒絕開波，訊息直接點名下一步：
  `任務尚未實體化（.task.env 的 DK_WORKTREE 還是空的）：先 dk-leader <short> --run …`。
  擋在 `n` 解析之後、任何寫檔之前，所以拒絕時 `process.md` 與 `.task.env` 都沒被動過。
- 每個 repo 各記一行 `wave-open N repo <名> base <sha>`（短 sha，與既有那行一致），
  主 repo 的 sha 同時留在原本的 `wave-open N base <sha> members …` 那一行 —— `dk_wave_base DIR N`
  的舊呼叫（dk-review-pack、gate d 的前置檢查）一個字都不用改。
- 逐 repo 的行**先**落盤、總結行最後：`dk-wave-close` 的「本波耗時」是用
  `dk_ts_pick … wave-open N` 取最後一筆相符的行，順序反過來的話那一欄會變成逐 repo 行的時間。
- 切片新段「## 倉庫」（模板加 `{{REPOS}}`），逐列 `<名> → <worktree 路徑>`；單 repo 模式也印，
  就一列 `main → <worktree>`，格式一致。
- 沒有 `.repos` 的是 0.9.2 之前建立的任務：退回單列（名字 `main`、路徑 `DK_WORKTREE`），
  讓三個讀 `.repos` 的呼叫端只有一條路。

### AC8 `bin/dk-spawn`、`lib/prompt.sh`
- pane／tab 的 `--cwd` 改成成員的家：`dk_brief_owners` 取它第一個可改 glob →
  `dk_glob_split` 取前綴 → `dk_repo_field <名> wt`。取不到（單 repo、成員不在所有權表、
  未知 repo 名）就退回 `DK_WORKTREE`；`DK_WORKTREE` 為空（計畫階段的 reviewer）退回
  `DK_PROJECT_ROOT`。`worktree: false` 的角色（pm）照舊在主樹，沒動。
- `DK_ADD_DIRS` 在 `dk_kind_args` 之前組好並 export（契約要求的順序）：主樹加 `.repos`
  每一列的 worktree、去重。
- 首輪提示多一句（只在多 repo 模式）：「你的 pane 在「<名>」的 worktree（<路徑>）；其他 repo 的
  worktree 見切片的「## 倉庫」段，你可以直接在那裡工作；touched 與所有權一律以「<名>:」這樣的
  <名>: 前綴開頭。」`dk_first_prompt` 多收兩個選填參數（REPO、REPO_WT），單 repo 傳空字串就不印。
  句子用「」不用反引號 —— 整段提示在 `printf '%s' "…"` 的雙引號裡，反引號會變成命令替換。

### AC10 `bin/dk-review-pack`
- 一份檔、逐 repo 分段：每個**有變更**的 repo 各出一段 `## repo <名>`（commits / stat / diff -U10），
  reviewer 仍只讀 `waves/N.diff` 一個檔。單 repo 模式不印 `## repo` 那一行。
- 表頭的 `files changed` 是所有 repo 的總和；全部沒變更時照舊寫檔並在 stderr 警告。
- 每個 repo 的 base：波模式先讀 `wave-open N repo <名> base`，主 repo 退回 0.9.2 那一行，
  再退回 `.repos` 記的實體化 sha；`--task` 模式用 `.repos` 的實體化 sha（主 repo 退回 `DK_BASE`）。
- 丟棄式 index 的招法不變（員工真正的 index 不被碰），只是每個 repo 重用同一個暫存檔。

### AC11／AC12 `bin/dk-wave-close`
- gate d 改呼叫 `dk_changed_repo_files TASK_DIR N`，`unowned change:` 與 `unreported change:`
  的路徑自然帶 `<名>:` 前綴，`dk_owned` 那側波 1 已經會拆前綴。
- gate d 另外補一道「worktree 在不在」的檢查：`dk_changed_repo_files` 會**跳過**不存在的目錄
  （它服務的是「這個 repo 這一波沒被實體化」），閘門這一側若照單全收，worktree 被刪掉就變成
  靜默放行 —— 0.9.2 那條「an unreadable worktree refuses」的測試正是守這件事。
- gate c 多 repo 逐 repo 跑：只跑**本波有變更**的 repo（變更清單取自 gate d；gate d 被跳過時
  退回全部都跑），主 repo 用 `DK_TEST_CMD`、其餘 `DK_TEST_CMD_<名>`（bash 3.2 的 `${!v}` 間接展開），
  缺指令記 `<名> skipped (no DK_TEST_CMD_<名>)` 並在 stderr 警告、不擋；log 檔 `N.<名>.test.log`。
  失敗訊息與 process 行都點名是哪個 repo。乾淨環境 `env -u DK_*` 的組法一字未動。
- 逐 repo commit：每個有變更的 repo 各 commit 一次，訊息相同（`wave N: <成員>` 或 `-m`）；
  多 repo 的輸出與 process 行帶 ` repo <名>` 後綴，單 repo 一字不變。commit 失敗點名 repo 後 exit 1。
- 單 repo 模式的 gate c 走獨立分支，保持 0.9.2「有沒有變更都跑」的語意（見〈疑慮〉一）。

## 測試

### 紅
四個子步驟各先寫測試、各跑一次確認真的紅。

AC9（`tests/run.sh tests/unit/18_wave_open.bats`）：
```
not ok 6 AC9: DK_WORKTREE 為空（還沒交棒）時拒絕並指向 dk-leader --run
#   `[ "$status" -eq 1 ]; [[ "$output" == *"dk-leader login --run"* ]]' failed
not ok 7 AC9: 每 repo 記一行 wave-open N repo <名> base <sha>，dk_wave_base 讀得到
#   `grep -q " wave-open 1 repo $r base $sha$" "$d/process.md"' failed
not ok 8 AC9: 切片有「## 倉庫」段，逐列 <名> → <worktree 路徑>
not ok 9 AC9: 單 repo 模式的切片也有「## 倉庫」段，就一列 main
```

AC8（`tests/run.sh tests/unit/07_spawn.bats`）：
```
not ok 22 AC8: cwd 是成員第一個可改 glob 的 repo worktree，--add-dir 主樹加每個 worktree
#   `grep -q -- "--cwd $api_wt --no-focus" "$HERDR_STUB_LOG"' failed
not ok 23 AC8: 首輪提示點名自己的 repo；單 repo 模式不印這一句
not ok 24 AC8: DK_WORKTREE 為空（計畫階段的 reviewer）時 cwd 退回主樹
```

AC10（`tests/run.sh tests/unit/19_review_pack.bats`）：
```
not ok 5 AC10: 每個有變更的 repo 各一段 ## repo <名>，files changed 是總和
#   `grep -q '^# files changed: 3 (working tree included)$' "$f"' failed
not ok 8 AC10: --task 也逐 repo 分段，base 取 .repos 記的實體化 sha
```

AC11／AC12（`tests/run.sh tests/unit/08_wave_close.bats`）：
```
not ok 32 AC11: gate c 逐 repo 跑各自的指令，log 檔名帶 repo，缺指令記 skipped 不擋
not ok 33 AC11: 本波沒變更的 repo 不跑它的測試
not ok 34 AC11: 某個 repo 的測試紅了要點名它，pane 不關
not ok 35 AC12: gate d 的 unowned／unreported 訊息帶 <名>: 前綴
not ok 36 AC12: 每個有變更的 repo 各 commit 一次，沒變更的不 commit
```

另有一條**既有**測試在實作 AC8 的過程中變紅（不是新寫的）：
```
$ tests/run.sh
not ok 117 spawn splits with env, starts agent with tier flags, sends first prompt
#   `grep -q '^agent start login-frontend-cart --kind claude --pane wC:p2 -- --model opus --effort high --permission-mode auto --add-dir '"$PROJECT"'$' …' failed
```
處置見〈自我審查〉二。

### 綠
實作之後，同樣四條指令逐一轉綠：

```
$ tests/run.sh tests/unit/18_wave_open.bats
1..9
ok 6 AC9: DK_WORKTREE 為空（還沒交棒）時拒絕並指向 dk-leader --run
ok 7 AC9: 每 repo 記一行 wave-open N repo <名> base <sha>，dk_wave_base 讀得到
ok 8 AC9: 切片有「## 倉庫」段，逐列 <名> → <worktree 路徑>
ok 9 AC9: 單 repo 模式的切片也有「## 倉庫」段，就一列 main

$ tests/run.sh tests/unit/07_spawn.bats
ok 22 AC8: cwd 是成員第一個可改 glob 的 repo worktree，--add-dir 主樹加每個 worktree
ok 23 AC8: 首輪提示點名自己的 repo；單 repo 模式不印這一句
ok 24 AC8: 單 repo 模式的 --add-dir 只有主樹（0.9.2 不變）
ok 25 AC8: DK_WORKTREE 為空（計畫階段的 reviewer）時 cwd 退回主樹
ok 26 AC8: 所有權表沒有這位成員時 cwd 退回 DK_WORKTREE（主 repo）

$ tests/run.sh tests/unit/19_review_pack.bats
1..8
ok 5 AC10: 每個有變更的 repo 各一段 ## repo <名>，files changed 是總和
ok 6 AC10: 多 repo 全都沒變更時仍寫檔並警告
ok 7 AC10: 單 repo 模式不印 repo 段（面向人的輸出不帶前綴）
ok 8 AC10: --task 也逐 repo 分段，base 取 .repos 記的實體化 sha

$ tests/run.sh tests/unit/08_wave_close.bats
ok 32 AC11: gate c 逐 repo 跑各自的指令，log 檔名帶 repo，缺指令記 skipped 不擋
ok 33 AC11: 本波沒變更的 repo 不跑它的測試
ok 34 AC11: 某個 repo 的測試紅了要點名它，pane 不關
ok 35 AC12: gate d 的 unowned／unreported 訊息帶 <名>: 前綴
ok 36 AC12: 每個有變更的 repo 各 commit 一次，沒變更的不 commit
```

全套（含同波 backend-ws 當下在樹上的改動）：
```
$ tests/run.sh
（exit 0；533 條 ok，0 條 not ok）
ok 533 init skill 問 DK_REPOS 與每個 repo 的 DK_SETUP_CMD，pnpm 給預填寫法
```
基準是波 1 收尾時的 488 條，本波共新增 14 條（07 五條、18 四條、19 四條扣掉一條落在既有檔名下、
08 五條；其餘為同波 backend-ws 的新增）。

shellcheck：
```
$ shellcheck .dkbo/bin/dk-spawn .dkbo/bin/dk-wave-open .dkbo/bin/dk-review-pack .dkbo/bin/dk-wave-close .dkbo/lib/prompt.sh
（無輸出，exit 0）
$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh
（無輸出，exit 0）
```

`tests/unit/27_qa_gate.bats`（完成條件列的第五個檔）沒有改動就全過：首輪提示新增的那一句
只在多 repo 模式出現，27 跑的是單 repo fixture，上游／TDD／qa 三段的斷言不受影響。

## 自我審查

一、**排除過的假設：gate c 可以不分模式、一律「只跑有變更的 repo」。**
試過把「本波有變更才跑」這條規則同時套在單 repo 上，`08_wave_close` 的
「gate c: DK_TEST_CMD runs in the worktree; failure keeps panes and shows the tail」立刻紅：
那條測試的 worktree 第一次跑時是乾淨的，卻期望測試**照跑**並失敗。0.9.2 的語意就是「不管有沒有
變更都跑」，AC1 不准放寬既有斷言，所以「只跑有變更的」只在 `dk_repos_multi` 為真時生效，單 repo
走獨立分支。排除。

二、**`--add-dir` 在單 repo 模式下不放 worktree。**
第一版照 plan 第 123 行「主樹加 `.repos` 每一列的 worktree」無條件組清單，結果把 0.9.2 的
既有斷言（`… --permission-mode auto --add-dir $PROJECT$`，`$` 是行尾）打掉了 —— 單 repo 的
那一列 worktree 就是 pane 的 cwd。AC1 明文「不刪、不放寬既有斷言」，所以改成只有
`dk_repos_multi` 為真時才展開 `.repos`；單 repo 維持只有主樹，並**新增**一條斷言把這件事釘住
（`AC8: 單 repo 模式的 --add-dir 只有主樹`）。AC8 的「對 `.repos` 每一列各出一個 `--add-dir`」
在多 repo 模式下逐字成立。這是 AC1 與 AC8 字面上的衝突，我按約束層級較高的 AC1 處理，列在
〈疑慮〉請領導確認。

三、**排除過的假設：gate d 可以直接把 `dk_changed_repo_files` 的結果當全部真相。**
換過去之後「an unreadable worktree refuses rather than passing the gate silently」變綠得太容易 ——
查下去發現 `dk_changed_repo_files` 對不存在的 worktree 是 `continue`（那是它該有的行為：某個 repo
這一波沒被實體化不該讓整支炸掉），於是 worktree 被 `rm -rf` 之後它回空、gate d 一條變更都比不到、
整個閘靜默放行。所以在呼叫之前另外掃一次 `.repos` 的目錄存在性，不存在就進 `problems`。

四、**`set -e` 下的 `A || { B && C; }`。**
`dk-review-pack` 第一版寫成 `[ -n "$b" ] || { [ "$rname" = "$mainrepo" ] && b="$base"; }`，
`rname` 不是主 repo 時整個 OR 列回非零，`set -e` 會當場把腳本收掉（`lib/repos.sh` 的註解正好
記著同一個坑）。改成 `if [ -z "$b" ] && [ … ]; then … fi`。同一輪順手確認 `multi=0; dk_repos_multi && multi=1`
是安全的：失敗的是 AND 列的**非最後一個**元素，`set -e` 對它豁免。

五、**`awk` 不吃 `→`。** 「## 倉庫」的箭頭一開始寫成 awk 程式裡的 `→`，POSIX awk 不解析
這個逸出；改成字面的 `→`。

六、**`process.md` 行序。** 逐 repo 的 `wave-open N repo …` 若排在總結行之後，
`dk_ts_pick … wave-open N`（取最後一筆）拿到的會是逐 repo 行的時間戳，「本波耗時」那一欄
就從「開波到現在」變成別的東西。所以逐 repo 行先寫、總結行最後。`08_wave_close` 的兩條 AC6
計時測試是手寫 `process.md`、沒有逐 repo 行的，抓不到這件事 —— 靠順序保證，不靠測試。

七、**所有權自查。** `git status --short` 比對切片的可改清單：本人只動了
`.dkbo/bin/dk-spawn`、`.dkbo/lib/prompt.sh`、`.dkbo/bin/dk-wave-open`、`.dkbo/bin/dk-review-pack`、
`.dkbo/bin/dk-wave-close`、`.dkbo/templates/brief-member.md`、`tests/unit/{07,08,18,19}_*.bats`，
全在清單內。`27_qa_gate.bats` 在清單內但不需要改動。樹上其餘的 `M`（dk-leader、dk-resume、
dk-task-new、dk-task-close 與 05/10/12/13 的測試）是同波 backend-ws 的進行中工作，沒有碰。

八、**沒做的事。** 本波的成果要等結案合併後的下一個任務才生效（全域約束最後一條），
所以本報告裡的任何行為都**沒有**在本任務的實跑中用到，只有 bats 假 herdr 的驗證。

## 疑慮

一、**AC1 與 AC8 在單 repo 模式的 `--add-dir` 上字面衝突。**
AC8 說「三個 kind 對 `.repos` 每一列各出一個 `--add-dir`」，`.repos` 在單 repo 模式也有一列；
AC1 與全域約束說 0.9.2 的既有斷言不得放寬，而 `07_spawn` 第一條測試把
`--add-dir $PROJECT` 釘在行尾。兩者不能同時成立。我的判斷是 AC1 層級較高（它是全域約束，
且 AC8 的 repo 維度本來就只在多 repo 才存在），所以單 repo 只放主樹。
若領導認為應該反過來（單 repo 也加 worktree），要改的是 `07_spawn` 那一條既有斷言，
屬於 AC1 明文禁止的範圍 —— 需要一則 ruling 才能動，請領導裁示。

二、**gate c 在多 repo 模式下，`dk_wave_base` 記不到本波 base 時退回「全部 repo 都跑」。**
`dgate=0`（gate d 被跳過）只會發生在 `process.md` 少了 `wave-open N base` 那一行的異常情況。
我選擇多跑而不是少跑，但這會讓一次異常的關波跑滿 N 套測試、比較慢。如果領導偏好「比不到就
一個都不跑、只印警告」，是一行的差別。

三、**跨 repo 整合測試沒有鉤子**（plan 決策⑨刻意不開）。gate c 每個 repo 都在
`env -u DK_*` 的乾淨環境裡跑，拿不到其他 worktree 的路徑。多 repo 專案若想在關波時驗跨 repo
的接線，目前只能靠自己的 CI。這是既定決策，記在這裡讓 reviewer 不用再查一次。

四、**`.repos` 的第四欄（實體化 sha）被 `--task` 當成 base。** 若某個 repo 是在任務中途才被加進
`DK_REPOS`（本版沒有這條路徑，但 `dk-leader --run` 的幂等重跑理論上碰得到），它的 `--task`
差異包會從它自己被寫進 `.repos` 的那一刻算起，而不是任務開始的那一刻。目前沒有情境會走到，
先記著。
