# backend-repos 報告（波 1）

## 做了什麼

### 1. 新檔 `.dkbo/lib/repos.sh`（共用契約：lib/repos.sh API）
plan 第 6 節列的函式全部到齊，簽名與契約一致：

| 函式 | 行為 |
|---|---|
| `dk_repos_parse` | `$DK_REPOS` → 每行 `<名> <絕對路徑>`；空字串回一行 `main <DK_PROJECT_ROOT>`；相對路徑相對 `DK_PROJECT_ROOT` 解析（存在時順便 `pwd -P` 解 symlink）；缺 `=` 的項目路徑欄留空，交給 check 點名 |
| `dk_repos_multi` | 0 ⟺ `DK_REPOS` 非空 |
| `dk_repos_check [--no-clean]` | 名字合法（`[a-z][a-z0-9_]{0,15}`）、唯一、第一個是主 repo、每個路徑是 git 根、工作樹乾淨；任一不過 `dk_die` 並用「`repo「<名>」`」點名。**乾淨只看已追蹤檔**（`git status --porcelain --untracked-files=no`，領導 09:41 ruling） |
| `dk_repos_write TASK_DIR SHORT WT_ROOT` | 寫 `.repos`；多 repo `<WT_ROOT>/<short>/<名>`，單 repo `<WT_ROOT>/<short>`；base sha 取各 repo 當下 HEAD。**不切 worktree、不建分支**（有測試守著） |
| `dk_repos_rows` / `dk_repo_field` / `dk_repos_names` | 讀 `.repos`（跳空行）；`FIELD = root\|wt\|base`；名字一行一個、主 repo 在前。沒有 `.repos` 時 `dk_repos_rows` 回非零 |
| `dk_glob_split GLOB` | `<名>:<glob>` → `<名>\t<glob>`；沒前綴 → `\t<glob>` |
| `dk_glob_check TASK_DIR GLOB` | 多 repo：必須有前綴且名字存在；單 repo：不得有前綴。非零＝違規，stdout 是理由 |
| `dk_repo_setup_cmd NAME` | 主 repo 回 `DK_SETUP_CMD`，其餘 `DK_SETUP_CMD_<名>`（`${!v}` 間接展開），沒設回空 |
| `dk_repos_known TASK_DIR` | 內部用：已實體化看 `.repos`，計畫階段（還沒有 `.repos`）退回 `DK_REPOS` |

`.repos` 檔格式照契約：`<名> <repo 根> <worktree> <base sha>`，主 repo 第一列，單 repo 也寫一列（名字 `main`）。

**`dk_repos_check --no-clean`（領導 09:41 ruling 已納入契約）。** plan 第 7 節要求 `dk-task-new` 開場只做「名字合法、第一個是主 repo、路徑是 git 根」三項（便宜、早失敗），「工作樹乾淨」留到 `dk-leader --run` 真的要從 HEAD 切 worktree 那一刻。不帶旗標時行為就是契約寫的五項全驗，所以對既有消費者是相容的。已 dk-msg 通知 backend-ws。

### 2. `lib/ownership.sh` 的前綴版
- `dk_owned BRIEF WHO PATH`：路徑與 glob 各自 `dk_glob_split`，**前綴相同才比**。兩個 repo 裡的同名路徑是兩個檔；沒前綴的路徑不配帶前綴的 glob，反之亦然。單 repo（兩邊都沒前綴）與 0.9.2 相同。
- `dk_changed_files WT BASE`：**名字與簽名維持 0.9.2 不動**（領導 09:41 ruling：改名而不是換簽名，見「疑慮」②的結果），只多一條「base 為空就回空」的護欄。`dk-wave-close` 與 `dk-review-pack` 在波 2 之前照舊用它。
- `dk_changed_repo_files TASK_DIR N`（新名字，plan 裡叫 `dk_changed_files` 的那一支）：逐 repo 跑 `dk_changed_files`，多 repo 模式每行加 `<名>:` 前綴、單 repo 不加。每個 repo 的 base 依序找：`wave-open N repo <名> base <sha>` → 主 repo 再退回 0.9.2 那行 `wave-open N base <sha>` → 都沒有就退回 `.repos` 的實體化 sha。沒有 `.repos` 的舊任務退回 `DK_WORKTREE` 與單一 base。
- ownership.sh 開頭在 `dk_glob_split` 不存在時自己 source repos.sh —— 呼叫端（dk-wave-close）今天只 source ownership.sh，不想讓它為了這件事被迫改。

### 3. `dk-brief-check` 的前綴與同 repo 重疊（AC5）
- 所有權表的**可改與只讀兩欄**每個 glob 都過 `dk_glob_check`：多 repo 缺前綴或未知名字 FAIL，單 repo 帶前綴 FAIL。只讀欄也驗，因為寫錯 repo 名字會把員工帶到不存在的樹。
- `overlap()` 先按 repo 分組：跨 repo 的同一條 glob 不算重疊，同 repo 內照舊（字面相等、或 `dir/**` 的樹包住另一條）。
- repo 名字的來源：brief 隔壁有 `.repos` 就以它為準（已實體化的任務的 repo 集合是定死的），沒有就查 `DK_REPOS`（dk-brief-check 跑在關卡①之前，那時任務還沒實體化）。

### 4. `DK_ADD_DIRS` 與 `kind_session_args`（共用契約）
- `lib/kinds.sh` 新增 `dk_add_dirs`：`DK_ADD_DIRS`（空白分隔，預設 `$DK_PROJECT_ROOT`）每一項展開成一個 `--add-dir`。三個 kind 的 `kind_args` 改成呼叫它，其餘旗標一字不動。沒設 `DK_ADD_DIRS` 時輸出與 0.9.2 逐字相同。
- 三個 kind 新增 `kind_session_args NAME`：claude 印 `--name NAME`，codex 與 agy 印空字串；名字為空時 claude 也不吐半截旗標。`dk_kind_args` 已經 `dk_kind_load` 過，所以 `dk-leader` 在它之後直接叫 `kind_session_args` 即可。

### 5. `dk_settings` 與 `dk_wave_base`
- `dk_settings` 多讀 `DK_REPOS` 與 `DK_SETUP_CMD`（預設都是空字串）並 export；`DK_TEST_CMD_<名>` 與 `DK_SETUP_CMD_<名>` 是每 repo 一條的動態鍵，沒辦法在預設區列舉，改成 source 完之後用 `${!DK_TEST_CMD_@}`／`${!DK_SETUP_CMD_@}` 一起 export（bash 3.2 有這個展開，不是 bash 4 語法）。
- `dk_wave_base DIR N [REPO]`：有 REPO 讀 `wave-open N repo <名> base <sha>`，沒有時一字不改。REPO 先過名字的形狀才拼進 sed。

### 6. 文件與範本
- `templates/brief.md` 的檔案所有權段多一句：多 repo 每個 glob 帶 `<名>:` 前綴、名字取自 `DK_REPOS`、重疊只在同 repo 內判、單 repo 一律不帶、`touched` 同一套。
- `settings.env` 新增 `DK_REPOS` 與 `DK_SETUP_CMD` 兩把鑰匙（都有註解與範例），並用註解說明 `DK_TEST_CMD_<名>`／`DK_SETUP_CMD_<名>` 的形狀。沒有新增其他鍵。
- `skills/init/SKILL.md` 新增第 2c、2d 步：問 `DK_REPOS`（先列同層目錄裡是 git 根的候選）、逐 repo 問 `DK_TEST_CMD_<名>`、問依賴鉤子（偵測到 `pnpm-lock.yaml` 就預填 `pnpm install --frozen-lockfile --prefer-offline`，並說明 `node_modules` 不會被 worktree 複製、symlink 主樹 `node_modules` 的兩個坑）。第 3 步的「八鍵」改十鍵，第 6 步的結尾清單跟著補。

### 7. `tests/helpers.bash`
- `setup_multirepo`：在 `$PROJECT` 之外另建 `api` 與 `shared` 兩個 git repo，往 `settings.env` 追加 `DK_REPOS="main=. api=… shared=…"` 與 `DK_TEST_CMD_api`。旗標用 `MULTIREPO`（不是 `DK_MULTIREPO`）—— `setup_project` 會整片洗掉 `DK_*`。
- `fixture_task` 學會多 repo：照 `MULTIREPO` 逐 repo 切 worktree（多 repo 落在 `.worktrees/<short>/<名>`）並寫 `.repos`；**單 repo 也寫 `.repos`（一列 main）**，讓每個讀它的呼叫端只有一條路。
- `repo_commit_all [REPO]`：fixture 的 `$PROJECT` 一建好就是髒的（`.dkbo/` 是 cp 進去、沒 commit 過），要驗 `dk_repos_check` 的其他項目得先把它弄乾淨。
- `teardown_project` 連帶刪掉 `$PROJECT-api`／`$PROJECT-shared`。

### 9. 未加引號的 `for … in $(…)` 會拿 cwd 的檔名展開 brief 欄位（reviewer-a Important 1）
`dk-brief-check` 不 `cd`，執行時的 cwd 就是專案根。未加引號的命令替換先做 word splitting、再對每個字做 **pathname expansion** —— 而所有權欄的內容裡本來就有 `**`。所以 `.dkbo/kinds/**` 會被換成三個實際檔名，真正該驗的那條 glob 字串根本沒進到 `dk_glob_check`：多 repo 的前綴檢查（AC5）形同虛設。改成 `while IFS= read -r … <<< "$(…)"`（同檔其餘迴圈的既有寫法），不用 `set -f`：那會動到整支腳本的全域狀態。

同一個洞在**獨佔資源那一層迴圈**（line 85）也有一份，reviewer 沒點到，但它是同一檔、同一類、同一個修法：獨佔資源是自由文字（`db`、`port:3000`、`docker`…），可以含 `*` 與 `?`。一併修掉並補了測試。另外三個 `for … in $(…)`（line 74 波號、77／84 成員名、127 消費者名）跑的是純數字與已驗過 `[a-z][a-z0-9_-]*` 的名字，沒有這個曝險，所以沒有動它們。

### 8. `dk_task_dir` 的裸 return（backend-ws 回報）
`lib/common.sh` 的 `dk_task_dir` 在 `DK_TASK_DIR` 那條分支結尾是裸 `return`。bash 規定 trap handler 裡執行的裸 `return` 回的是**觸發 trap 的那個狀態**，不是函式最後一個指令的狀態 —— 而 `dk_env_set` 的第一行是 `d=$(dk_task_dir) || return 1`，所以掛了 rollback 型 `trap EXIT` 的失敗路徑上，每一次 `dk_env_set` 都在第一行靜默退出、一個欄位都沒寫。改成 `return 0`，並在 `01_common.bats` 留一條同時驗兩條分支的回歸測試。

## 測試

### 紅

`lib/repos.sh` 那一條（先寫測試檔、跑它、確認 19 條全紅）：

```
$ tests/run.sh tests/unit/33_repos.bats
1..19
not ok 1 dk_repos_parse: 空字串是單 repo 模式，回一列 main
# (from function `setup' in test file tests/unit/33_repos.bats, line 2)
#   `setup() { setup_project; . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/repos.sh"; }' failed
# /home/bal/project/teamflow/.worktrees/multirepo/tests/unit/33_repos.bats: line 2: /tmp/tmp.xbSAyLtGbZ/.dkbo/lib/repos.sh: No such file or directory
…（19 條全部 not ok，原因同上）
```

`kind_args` / `kind_session_args` 那一條：

```
$ tests/run.sh tests/unit/03_kinds.bats
1..17
ok 14 kind_args 沒設 DK_ADD_DIRS 時就是主樹一項（與 0.9.2 相同）
not ok 15 kind_args 逐項展開 DK_ADD_DIRS，三個 kind 都一樣
not ok 16 kind_session_args: claude 帶 --name，codex 與 agy 不帶
not ok 17 kind_session_args: 三個 kind 都宣告了它，名字空的時候不吐半截旗標
```

`dk_changed_files` 的 repo 維度那一條：

```
$ tests/run.sh tests/unit/22_ownership.bats
1..10
not ok 3 dk_changed_since lists committed, dirty and untracked work since the base
not ok 4 dk_changed_since skips ignored files and leaves non-ASCII paths unescaped
not ok 5 dk_changed_since reports nothing when the worktree is untouched
not ok 6 dk_changed_files 單 repo 模式不加前綴，路徑與 0.9.2 相同
not ok 7 dk_changed_files 空的波回空、不回非零
not ok 8 dk_changed_files 多 repo 逐 repo 用各自的 base，輸出帶 <名>: 前綴
```

`dk-brief-check` 的前綴那一條：

```
$ tests/run.sh tests/unit/16_brief_check.bats
1..18
not ok 15 多 repo：缺前綴的 glob 要 FAIL，補上前綴就過
not ok 16 多 repo：未知的 repo 名字要 FAIL（可改與只讀兩欄都驗）
not ok 17 單 repo：帶前綴的 glob 要 FAIL
```

範本、設定與 init skill 那一條：

```
$ tests/run.sh tests/unit/01_common.bats tests/unit/15_brief_lib.bats
1..38
not ok 28 shipped settings.env 有 DK_REPOS 與 DK_SETUP_CMD 兩把新鑰匙，都加了引號
not ok 38 templates/brief.md 說明 repo 前綴的兩條規則

$ tests/run.sh tests/unit/33_repos.bats
1..21
not ok 21 init skill 問 DK_REPOS 與每個 repo 的 DK_SETUP_CMD，pnpm 給預填寫法
```

review 1 Important 1 的紅（先在專案根重現，不是在 bats 裡）：

```
$ cd .worktrees/multirepo
$ globs=".dkbo/lib/repos.sh, .dkbo/kinds/**"; ro=".dkbo/bin/**"
$ for g in $(printf '%s\n%s\n' "$globs" "$ro" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
            | grep -vE '^(|—)$' || true); do echo "[$g]"; done
[.dkbo/lib/repos.sh]
[.dkbo/kinds/agy.sh]
[.dkbo/kinds/claude.sh]
[.dkbo/kinds/codex.sh]
[.dkbo/bin/dk-brief-check]
[.dkbo/bin/dk-brief-review]
...共 24 個字，brief 裡其實只有 3 條 glob

$ tests/run.sh tests/unit/16_brief_check.bats
not ok 20 所有權的 glob 不被 cwd 的真實檔名展開（reviewer-a Important 1）
# (in test file tests/unit/16_brief_check.bats, line 156)
#   `[[ "$output" == *".dkbo/kinds/**"* ]]                    # 訊息指的是 brief 裡那條 glob' failed

not ok 21 獨佔資源欄同樣不被 cwd 的真實檔名展開（Important 1 的同類洞）
# (in test file tests/unit/16_brief_check.bats, line 169)
#   `[[ "$output" == *"獨佔資源 build-* 同時被"* ]]      # 訊息指的是宣告的那個字串' failed
```

重工三項的紅（領導 09:41 兩則 ruling ＋ backend-ws 回報的 bug）：

```
# ① dk_task_dir 的裸 return（第一版重現寫錯了分支，改成打 DK_TASK_DIR 那條才紅）
$ tests/run.sh tests/unit/01_common.bats
not ok 29 dk_task_dir 在 EXIT trap 裡也回 0（裸 return 會回觸發 trap 的狀態）
# (in test file tests/unit/01_common.bats, line 218)
#   `[ "${lines[0]}" = "explicit rc=0" ]; [ "${lines[1]}" = "bound rc=0" ]' failed

# ② 乾淨檢查只看已追蹤檔
$ tests/run.sh tests/unit/33_repos.bats
1..22
not ok 11 乾淨檢查只看已追蹤檔：未追蹤檔不算髒（.dkbo/ 不進版控的專案）
# (in test file tests/unit/33_repos.bats, line 82)
#   `run dk_repos_check; [ "$status" -eq 0 ]' failed
（另有 6 條因為 fixture 不再需要先 commit 而連帶轉紅，同一次修好）

# ③ 改名（dk_changed_files 回舊簽名、新的叫 dk_changed_repo_files）的紅就是改名前的
#    08_wave_close 三條越界閘，逐字同下面「整包」那一段改名前的輸出。
```

### 綠

分給我的六個測試檔，105 條全過：

```
$ tests/run.sh tests/unit/33_repos.bats tests/unit/16_brief_check.bats tests/unit/22_ownership.bats \
              tests/unit/03_kinds.bats tests/unit/01_common.bats tests/unit/15_brief_lib.bats
1..105
ok 1 dk_repos_parse: 空字串是單 repo 模式，回一列 main
…
ok 105 templates/brief.md 說明 repo 前綴的兩條規則
（not ok 0 條）
```

shellcheck 零警告：

```
$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh
（無輸出，exit 0）
```

重工三項各自的綠：

```
$ tests/run.sh tests/unit/01_common.bats
1..29
ok 29 dk_task_dir 在 EXIT trap 裡也回 0（裸 return 會回觸發 trap 的狀態）

$ tests/run.sh tests/unit/33_repos.bats
1..22
ok 11 乾淨檢查只看已追蹤檔：未追蹤檔不算髒（.dkbo/ 不進版控的專案）
（not ok 0 條）

$ tests/run.sh tests/unit/22_ownership.bats tests/unit/08_wave_close.bats
1..41
（not ok 0 條 —— 改名之後 08_wave_close 的三條越界閘自己就好了，dk-wave-close 一行都沒動）
```

review 1 Important 1 的綠（同一條重現指令，改成 while read 之後）：

```
$ n=0; while IFS= read -r g; do [ -n "$g" ] || continue; n=$((n+1)); echo "[$g]"; done \
    <<< "$(printf '%s\n%s\n' ".dkbo/lib/repos.sh, .dkbo/kinds/**" ".dkbo/bin/**" | tr ',' '\n' \
           | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -vE '^(|—)$' || true)"; echo "共 $n 個"
[.dkbo/lib/repos.sh]
[.dkbo/kinds/**]
[.dkbo/bin/**]
共 3 個

$ tests/run.sh tests/unit/16_brief_check.bats
1..21
（not ok 0 條）
```

整包 `tests/run.sh` 現在全綠：

```
$ tests/run.sh
ok=488  not ok=0

$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh
（無輸出，exit 0）
```

（波 1 三輪的數字：首次交付 478 ok / 6 not ok → ruling 重工 486 / 0 → review 1 修完 488 / 0。）

重工之前那一輪是 478 ok / 6 not ok，六條的去向：3 條 `08_wave_close` 越界閘由改名 ruling 解掉（我這邊改名即可，`dk-wave-close` 不用動）、1 條 `23_leader_kind` 與 2 條 `13_leader`／`30_isolation` 由 backend-ws 在它自己的檔裡修掉。

（起點：本波開工前 `tests/run.sh` 是 429 ok / 0 not ok、shellcheck 零警告；本波兩人合計新增 57 條。）

## 自我審查

排除掉的假設與踩過的坑，一條一行：

1. **`[[ … ]] && dk_die` 在 `set -e` 下會把整支拖下水。** `dk_repos_check` 的重複名字檢查一開始寫成這個形狀，條件為假時整個 `&&` 回非零，呼叫端（bats、`set -euo pipefail` 的 bin 腳本）當場退出 —— 症狀是「乾淨的多 repo 也被拒絕、而且沒有任何訊息」。改成 `if`。這個 repo 裡既有的同形狀寫法後面都接了 `|| true`，我漏看了那半截。
2. **`IFS=$'\t' read -r a b` 讀不到開頭的空欄。** tab 是 IFS 的空白字元，`read` 會把開頭的分隔符整段吃掉，所以 `dk_glob_split` 對沒有前綴的 glob 印出的 `\tsrc/api/**` 被讀成 `repo=src/api/**`、`glob=""`，單 repo 模式的 `dk_owned` 整個失效。改用參數展開 `${s%%$'\t'*}` / `${s#*$'\t'}`。`dk-brief-check` 的 `overlap()` 同一招同一個坑，一起改掉。
3. **`fixture_task` 跑在命令替換的子 shell 裡**，它對 `WORKTREE_PATH` 的覆寫不會回到呼叫端。多 repo 的 worktree 路徑要用 `dk_repo_field "$d" <名> wt` 拿，已經寫進 helpers 的註解。
4. **fixture 的 `$PROJECT` 天生是髒的**（`.dkbo/` 是 cp 進去的、沒 commit），所以 `dk_repos_check` 的「工作樹乾淨」會先於其他四項觸發，害我一度以為名字檢查沒生效。加了 `repo_commit_all`，並在每個 check 測試裡明寫它。
5. **`dk_owned` 的前綴其實不加 split 也會對**：前綴在 glob 與路徑裡都是字面字串，`case` 比對本來就會把 `api:src/**` 與 `main:src/x` 分開。我還是照 plan 拆了前綴，因為「只比同 repo」這條規則要在程式裡寫明才讀得出來，而且路徑含冒號（`src/a:b.ts`）時 `dk_glob_split` 的名字形狀判別比裸 `case` 精確。對應的測試因此是回歸護欄、不是新行為的紅燈，這裡如實記一筆。
6. **`dk_repos_write` 不切 worktree** 有專門一條測試守著（跑完之後 `.worktrees/<short>` 不存在、`dk/<short>` 分支不存在）—— 計畫階段不得有 git 副作用是全域約束，光靠 code review 看不住。
7. **bash 3.2**：沒有用關聯陣列、`${x^^}`、`declare -A`。`${!DK_TEST_CMD_@}` 與 `${!v}` 都是 bash 2.04 起就有的間接展開（`tests/helpers.bash` 既有的 `${!DK_@}` 是同一個東西），`24_portability.bats` 的 bash 4 掃描全過。
8. **否定斷言**一律用 `refute_grep`，沒有寫 `! grep -q`。
9. **只改所有權表劃給我的檔**：`git status` 裡屬於我的是 lib/repos.sh（新）、lib/{ownership,common,kinds}.sh、kinds/×3、bin/dk-brief-check、templates/brief.md、settings.env、skills/init/SKILL.md、tests/helpers.bash、tests/unit/{33,16,22,03,01,15}。其餘變更是 backend-ws 的。
10. **重現寫錯分支的一次**：`dk_task_dir` 那條紅，我第一版的重現腳本沒設 `DK_TASK_DIR`，走的是 `.sessions` 綁定那條（結尾是 `echo`，本來就回 0），所以「紅」是綠的。照 debugging.md 第二條往回走一層才發現裸 `return` 只在另一條分支上。改成兩條分支各驗一次才真的紅。教訓：測試通過不等於重現成功，要先確認它打在被修的那一行上。
11. **backend-ws 的回報我先驗過才動手**：寫了一支 12 行的 `trapcheck.sh`，在 bash 5.2.21 上量到裸 `return` 在 EXIT trap 裡回 7（觸發 trap 的狀態）、經過 `$()` 命令替換也一樣、`return 0` 回 0。回報屬實，不是猜的。
12. **差點誤報一條 bug**：重現 Important 1 時我這個 shell 的 `grep` 報了 `error at position 6 (?m)^(|—)$`，看起來像 `grep -vE '^(|—)$'` 不可攜（ugrep 不收空的 alternation）。查下去發現 `grep` 在我的互動 shell 裡是 Claude Code 注入的**函式**（包 ugrep），真正的 `/usr/bin/grep` 是 GNU grep 3.11，bats 與 `dk-brief-check` 用的都是後者。是我的環境假象，不是專案缺陷，所以沒有回報 —— 記在這裡以免下一個人重踩。
13. **沒有用 `set -f`**：reviewer 給了兩個選項，我選 `while read`。`set -f` 會關掉整支腳本的檔名展開，是全域狀態，之後任何人在這支腳本裡寫需要展開的程式碼都會被它默默影響；`while read` 只影響這一個迴圈，而且與同檔其餘四個迴圈的寫法一致。
14. **`lib/brief.sh` 我沒動** —— `dk_brief_owners` 原樣回傳帶前綴的 glob，前綴的解讀全在消費端（dk-brief-check、dk_owned），不需要改讀取層。

## 疑慮

上一版的五條疑慮，領導 2026-09-20T09:41 全部裁定了，處置與結果：

1. ~~`23_leader_kind.bats` 的 8 鍵斷言~~ → **已裁定**：該檔劃給 backend-ws，由擁有者改成 10。我沒有碰它，現在整包全綠。
2. ~~`dk_changed_files` 換簽名害 `08_wave_close` 三條紅~~ → **已裁定且已照辦**：舊簽名 `dk_changed_files WT BASE` 原樣留到波 2，逐 repo 的新版改名 `dk_changed_repo_files TASK_DIR N`。領導這個處置比我原本的做法好：我只想到「相容雙形狀」與「直接換簽名」兩條，前者會讓 gate d 在參數寫錯時靜默放行（我因此反對），後者要等波 2 才收得回來 —— 改名兩邊的缺點都沒有，而且 `dk-wave-close` 一行都不用動就自己綠了。契約表請把這個名字補上。
3. ~~乾淨檢查會擋下 `.dkbo/` 不進版控的專案~~ → **已裁定且已照辦**：改成 `--untracked-files=no`，只看已追蹤檔，並新增一條測試守著「未追蹤檔不算髒、已追蹤檔改了就是髒」。
4. ~~`DK_REPOS` 與 `.repos` 不支援含空白的路徑~~ → **已裁定**：波 3 寫進文件的已知限制。`lib/repos.sh` 的檔頭註解已經寫著。
5. ~~`--no-clean` 算不算契約變更~~ → **已裁定**：納入契約，`dk-task-new` 用它做便宜三項。

還開著的一條：

6. **`herdr workspace create` 的實機回傳形狀仍未在真機驗過**（plan 第 9 節、AC17）。我這一波沒碰到它，但 `DK_ADD_DIRS` 的消費端 `dk-spawn`（波 2）會依賴 `.repos` 每一列的 worktree 真的存在 —— 那要等 `dk-leader --run` 在真 herdr 上跑過才算數。整合腳本是 backend-docs 的檔。

另外記一筆給波 2 的 backend-gates（不是疑慮，是交接）：gate d 要改用 `dk_changed_repo_files "$d" "$N"`，`unowned change`／`unreported change` 的訊息前綴就是它輸出的 `<名>:`；需要單一 worktree 的真實 diff（`dk-review-pack`）時繼續用 `dk_changed_files WT BASE`。波 2 換完呼叫之後，`dk_changed_files` 這個名字要不要收掉由領導決定（ruling 說「波 2 換完呼叫後把舊的刪掉」，但 `dk-review-pack` 也在用它，刪之前請確認）。
