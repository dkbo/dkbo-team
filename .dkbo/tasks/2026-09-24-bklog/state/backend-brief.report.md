# backend-brief 報告（波 2）
## 做了什麼
整枝評議三條 Minor：
- **①** `.dkbo/lib/review.sh:54`：`dk_review_aliases` 別名用完的提示拿掉「先 dk-wave-close --agent 收掉不用的」（關 pane 不會把別名還回來，照那句做還是會再撞同一個錯），改成 `—— 關 pane 不會把別名還回來（已派名單只增不減），只能記 dk-process "<label> skipped: <理由>" 收掉這一輪`。
- **②** `.dkbo/lib/brief.sh`：`dk_brief_ncols [COL]...` 擴充成每個非空列印「欄數＼t指定欄值…」（無參數時只印欄數，原本語意保留）；`dk-brief-check` 的兩個欄數閘（所有權 `dk_brief_ncols 1`、波次表 `dk_brief_ncols 1 3`）改呼叫它，取代原本兩段內聯 awk，不再是死碼。
- **③** `.dkbo/bin/dk-brief-check:47`：`all_globs` 從裸 `awk -F'|'` 改用 `$DK__BRIEF_SPLIT` 切欄（取 `c[1]`、`c[2]`）。原本可改欄含 `\|` 時會在那裡被切斷：後面的 glob 整段遺失（漏判重疊），或兩條不同 glob 因共同前綴 `src/a\` 誤判重疊。

## 測試
### 紅
取紅方式：先把三條新測試寫進 worktree 跑（實作前）；③ 後半段（誤判）被前半段遮住，另外 `git archive HEAD` 解到 scratchpad、把前半段斷言改成只印輸出，單獨取紅。沒有在共用 worktree 用 stash／checkout。
```
$ tests/run.sh tests/unit/15_brief_lib.bats tests/unit/16_brief_check.bats tests/unit/20_review.bats
not ok 48 bklog Minor③: 可改欄含 \| 時重疊判斷不錯位（不漏判、不誤判）
#   `run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 所有權 backend/it: 可改範圍重疊"* ]]' failed
not ok 49 bklog Minor②: 欄數閘走 dk_brief_ncols，不再內聯一份切欄 awk
#   `grep -q 'dk_brief_ncols' "$DK_ROOT/bin/dk-brief-check"' failed
not ok 64 bklog Minor①: 別名用完的提示寫明關 pane 不會把別名還回來、只留 skipped 的出路
#   `[[ "$output" == *"關 pane 不會把別名還回來"* ]]' failed
$ tests/run.sh tests/unit/15_brief_lib.bats
not ok 15 bklog Minor②: dk_brief_ncols 印欄數（\| 不算分隔），再附上指定欄的值
#   `[ "$(printf '%s\n' 'a|b\|c|d' 'x|y' | dk_brief_ncols 1 2)" = "$(printf '3\ta\tb\\|c\n2\tx\ty')" ]' failed
$ (scratchpad/red，git archive HEAD＋新 16) tests/run.sh tests/unit/16_brief_check.bats
not ok 33 bklog Minor③: 可改欄含 \| 時重疊判斷不錯位（不漏判、不誤判）
#   `run dk-brief-check; refute_grep -q '重疊' <<< "$output"' failed      ← 誤判那一半；前半段輸出是 OK（漏判）
```
### 綠
```
$ tests/run.sh tests/unit/15_brief_lib.bats tests/unit/16_brief_check.bats tests/unit/20_review.bats
ok 15 bklog Minor②: dk_brief_ncols 印欄數（\| 不算分隔），再附上指定欄的值
ok 48 bklog Minor③: 可改欄含 \| 時重疊判斷不錯位（不漏判、不誤判）
ok 49 bklog Minor②: 欄數閘走 dk_brief_ncols，不再內聯一份切欄 awk
ok 64 bklog Minor①: 別名用完的提示寫明關 pane 不會把別名還回來、只留 skipped 的出路
（1..64，not ok 0 條）
$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh   → 零警告
$ tests/run.sh   → 1..724，724 ok、0 not ok（含同波夥伴當下未 commit 的改動）
```

## 自我審查
- Minor② 的測試第一版寫成 `refute_grep DK__BRIEF_SPLIT dk-brief-check`，跟 ③ 要求用 `$DK__BRIEF_SPLIT` 互相矛盾；改成擋內聯欄數 awk 的特徵 `print nf`（舊碼 2 處、新碼 0 處，仍是紅→綠）。這是我這波新寫的測試，不是既有測試。
- `dk_brief_ncols` 原本沒有任何呼叫端，擴充參數不影響別人；無參數行為（每列印欄數）保留，但現在跳過空列（`NF`），與閘原本的內聯 awk 一致。
- `all_globs` 輸出的 glob 保留 `\|`（與 dk_brief_owners 一致），`overlap` 比的是同一形式，FAIL 訊息裡印的也是 `\|` 形式——和 brief 原文一致。
- 新測試的否定斷言都用 `refute_grep`，沒寫 `! cmd`。

## 疑慮
- 無。改動只在 review.sh、brief.sh、dk-brief-check 與 15／16／20 三個測試檔；引用它們的其他測試（01、04、09、19、25、27、28、29、34）全套跑過都綠。

---
# （以下保留）backend-brief 報告（波 1）
#### 波1 做了什麼
- **AC8**（dk-brief-check）：新增「無主測試檔」WARN。來源＝各成員可改欄裡不含萬用字元（`* ? [`）且不是 `.md` 的路徑，取 basename；在各 repo 自己的 `git ls-files` 測試檔（`*.bats`、`*_test.*`、`*.test.*`、`*.spec.*`；排除 `.dkbo/tasks/**`、`*.log`、`*.md`、`*.txt`）裡 `grep -lF`；命中檔用既有的 `dk_owned`（lib/ownership.sh）比對，無人擁有就一個測試檔一條 `WARN 所有權: <測試檔> 引用了 <檔名>, …（<成員>, … 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）`。多 repo 時路徑帶 `<名>:`。只 WARN 不 FAIL。
- **AC9**：`lib/brief.sh` 新增共用的跳脫感知切法 `DK__BRIEF_SPLIT`（awk 片段）與 `dk_brief_md_rows NCOLS [COL VALUE]…`、`dk_brief_ncols`；`dk_brief_wave_members`／`dk_brief_wave_review` 改用它（原本裸 `awk -F'|'`，「做什麼」欄有 `\|` 時難度／審查欄錯位）。`dk-wave-open` 的波次列、所有權列改用 `dk_brief_md_rows`。`dk-brief-check` 的所有權、波次表迴圈改成先換哨兵再切；加欄數閘：所有權每列 3 或 4 欄、波次表每列 7 欄，不符 `FAIL 所有權 <成員>: 每列須 3 或 4 欄…得到 N 欄`／`FAIL 波次表 <波> <成員>: 每列須 7 欄，得到 N 欄`。獨佔資源欄（第 4 欄）也改跳脫感知。
- **AC10**：契約擁有者／消費者欄可寫 `<成員>@波<N>`：驗成員在所有權表、波號存在、成員在該波有列，分別 FAIL `… 不在檔案所有權表`／`… 的波 N 不在波次表`／`… 不在第 N 波`；`@` 後不是 `波<數字>` 也 FAIL。不帶 `@` 與 `—` 行為不變。`templates/brief.md` 共用契約段說明句補上寫法。
- **AC11**（dk-leader）：`ws="${HERDR_WORKSPACE_ID:-${DK_WORKSPACE:-}}"`；兩者皆非空且不同 → 回寫 `DK_WORKSPACE`、process 記 `workspace <舊> → <新>（--run 開在當下所在的 workspace）`、stdout 印 `dk-leader: workspace <舊> → <新>（…）`；都空照舊 die。改掉描述舊語意的兩段註解（dk-leader 兩處、13_leader.bats 一處）。
- **AC12**：dk-wave-close 的 `state too long` 改成不計 `touched:` 之後連續的 `  - ` 行；`lib/prompt.sh` 首段提示改「touched 清單以外 ≤20 行」。
- **AC13**：`templates/brief-member.md` 的「## 倉庫」段在 `{{REPOS}}` 之後加指定句。
- **額外（ruling 2026-09-24T14:52 劃入）**：`lib/repos.sh` 的 `dk_glob_check` 把 `printf … | grep -qx` 改 here-string（pipefail 下偶發 SIGPIPE → 合法 repo 名被判未知）。我自己檔裡的同類寫法一併改：dk-brief-check 兩處、dk-wave-close 一處（unreported 判定）、dk-wave-open 一處（計審 pane 判定），行為等價。

#### 波1 測試
### 紅
```
$ tests/run.sh tests/unit/18_wave_open.bats
not ok 15 bklog AC9: 做什麼欄寫 a\|b，切片的波次列仍是 7 欄並保留 a\|b
# (in test file tests/unit/18_wave_open.bats, line 153)
#   `grep -qxF '| 1 | 實作 | backend | 拆 a\|b 兩段 | M | 測試過 | 預設 |' "$d/briefs/backend.md"' failed
not ok 16 bklog AC9: 所有權欄寫 \|，切片的所有權列仍是 3 欄並保留 \|
# (in test file tests/unit/18_wave_open.bats, line 159)
#   `grep -qxF '| backend | src/api/** | src/web/** 與 a\|b |' "$d/briefs/backend.md"' failed
not ok 17 bklog AC13: 切片的「## 倉庫」段告訴員工編輯一律用 worktree 路徑
# (in test file tests/unit/18_wave_open.bats, line 163)
#   `grep -qxF '編輯一律用上面的 worktree 路徑；$DK_ROOT 指向主樹的 .dkbo/，只拿來跑 dk-msg 等 bin，不得當編輯路徑' "$d/briefs/backend.md"' failed
$ tests/run.sh tests/unit/15_brief_lib.bats
not ok 12 bklog AC9: dk_brief_md_rows 跳脫感知地挑列、拼回 markdown 列
# (in test file tests/unit/15_brief_lib.bats, line 79)
#   `[ "$(printf '%s\n' "$rows" | dk_brief_md_rows 7 1 1 3 backend)" = '| 1 | 實作 | backend | a \| b | M | 過 | 預設 |' ]' failed
# /home/bal/project/teamflow/.worktrees/bklog/tests/unit/15_brief_lib.bats: line 79: dk_brief_md_rows: command not found
not ok 13 bklog AC9: 做什麼欄的 \| 不讓 wave_members 的難度錯位
# (in test file tests/unit/15_brief_lib.bats, line 87)
#   `[ "$(dk_brief_wave_members "$b" 1 | tr '\n' ' ')" = "backend(M) qa(S) " ]' failed
$ tests/run.sh tests/unit/16_brief_check.bats
1..31
not ok 22 bklog AC9: 所有權表每列 3 或 4 欄，其他欄數 FAIL 並指出哪一列
# (in test file tests/unit/16_brief_check.bats, line 179)
#   `run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 所有權 backend: 每列須 3 或 4 欄"* ]]; [[ "$output" == *"得到 5 欄"* ]]' failed
not ok 23 bklog AC9: 波次表每列固定 7 欄，\| 不算分隔
# (in test file tests/unit/16_brief_check.bats, line 185)
#   `run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]                       # 跳脫的管線：仍 7 欄，難度沒錯位' failed
not ok 24 bklog AC10: 擁有者／消費者寫 <成員>@波<N> 合法時照過
# (in test file tests/unit/16_brief_check.bats, line 195)
#   `run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]' failed
ok 25 bklog AC10: @波N 的成員不存在要 FAIL
not ok 26 bklog AC10: @波N 的波號不存在要 FAIL
# (in test file tests/unit/16_brief_check.bats, line 203)
#   `run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 共用契約 login API: 消費者 frontend-cart@波9 的波 9 不在波次表"* ]]' failed
not ok 27 bklog AC10: @波N 的成員不在那一波要 FAIL
# (in test file tests/unit/16_brief_check.bats, line 207)
#   `run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 共用契約 login API: 擁有者 backend@波2 不在第 2 波"* ]]' failed
not ok 28 bklog AC8: 無人擁有的測試檔引用了成員的可改檔 → WARN，exit 0
# (in test file tests/unit/16_brief_check.bats, line 226)
#   `[[ "$output" == *"WARN 所有權: spec/auth.spec.js 引用了 auth.sh（backend 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）"* ]]' failed
ok 29 bklog AC8: 測試檔有人擁有就不 WARN
not ok 31 bklog AC8: 多 repo 各在自己的 ls-files 裡找，路徑帶 <名>:
# (in test file tests/unit/16_brief_check.bats, line 248)
#   `[[ "$output" == *"WARN 所有權: api:spec/client.spec.js 引用了 client.sh（backend 的可改檔）"* ]]' failed
$ tests/run.sh -f "bklog AC11" tests/unit/13_leader.bats
1..3
not ok 1 bklog AC11: HERDR_WORKSPACE_ID 與 DK_WORKSPACE 不同 → tab 開在當下的、回寫 DK_WORKSPACE 並記 process
# (in test file tests/unit/13_leader.bats, line 360)
#   `grep -q -- "^tab create --workspace wZ " "$HERDR_STUB_LOG"' failed
ok 2 bklog AC11: HERDR_WORKSPACE_ID 空時退回 DK_WORKSPACE，不記 workspace 行
ok 3 bklog AC11: 兩者相同時不回寫也不記 process
$ tests/run.sh tests/unit/08_wave_close.bats   （AC12，實作前）
not ok 38 AC12: state 行數不計 touched 清單項——24 項＋其他 10 行不警告
#   `refute_grep -q 'state too long' <<< "$output"' failed
# refute_grep: 不該命中卻命中了: -q state too long
$ tests/run.sh tests/unit/15_brief_lib.bats   （AC12 prompt，實作前）
not ok 11 AC12: 員工首段提示的 state 行數規則是「touched 清單以外 ≤20 行」
$ tests/run.sh -f 'AC10: templates' tests/unit/15_brief_lib.bats   （模板說明句，實作前）
not ok 1 bklog AC10: templates/brief.md 的共用契約說明句講得出 <成員>@波<N>
$ for i in 1..5; tests/run.sh -f SIGPIPE tests/unit/16_brief_check.bats   （repos.sh 修正前）
not ok 1 bklog: dk_glob_check 在 pipefail 下不會偶發誤判「未知的 repo 名字」（SIGPIPE 回歸）
not ok 1 bklog: dk_glob_check 在 pipefail 下不會偶發誤判「未知的 repo 名字」（SIGPIPE 回歸）
not ok 1 bklog: dk_glob_check 在 pipefail 下不會偶發誤判「未知的 repo 名字」（SIGPIPE 回歸）
not ok 1 bklog: dk_glob_check 在 pipefail 下不會偶發誤判「未知的 repo 名字」（SIGPIPE 回歸）
not ok 1 bklog: dk_glob_check 在 pipefail 下不會偶發誤判「未知的 repo 名字」（SIGPIPE 回歸）
$ tests/run.sh tests/unit/13_leader.bats   （AC11 實作後、改寫舊反面測試前：預期中的紅，已 ESCALATE 並獲准）
not ok 9 --run: DK_WORKSPACE 原本非空就不被 HERDR_WORKSPACE_ID 改寫（Important 1 反面）
#   `grep -q '^DK_WORKSPACE="wB"$' "$d/.task.env"' failed
```
取紅方式：新測試寫進 worktree 後、實作之前直接跑（未用 git stash／checkout）；repos.sh 的「base 就有」是 `git archive HEAD` 解到 scratchpad 跑出來的（多 repo 四條 25 輪紅 1 次）。
### 綠
```
$ tests/run.sh tests/unit/18_wave_open.bats
1..17
ok 15 bklog AC9: 做什麼欄寫 a\|b，切片的波次列仍是 7 欄並保留 a\|b
ok 16 bklog AC9: 所有權欄寫 \|，切片的所有權列仍是 3 欄並保留 \|
ok 17 bklog AC13: 切片的「## 倉庫」段告訴員工編輯一律用 worktree 路徑
$ tests/run.sh tests/unit/15_brief_lib.bats
1..13
ok 11 AC12: 員工首段提示的 state 行數規則是「touched 清單以外 ≤20 行」
ok 12 bklog AC9: dk_brief_md_rows 跳脫感知地挑列、拼回 markdown 列
ok 13 bklog AC9: 做什麼欄的 \| 不讓 wave_members 的難度錯位
$ tests/run.sh tests/unit/16_brief_check.bats
1..31
ok 22 bklog AC9: 所有權表每列 3 或 4 欄，其他欄數 FAIL 並指出哪一列
ok 23 bklog AC9: 波次表每列固定 7 欄，\| 不算分隔
ok 24 bklog AC10: 擁有者／消費者寫 <成員>@波<N> 合法時照過
ok 25 bklog AC10: @波N 的成員不存在要 FAIL
ok 26 bklog AC10: @波N 的波號不存在要 FAIL
ok 27 bklog AC10: @波N 的成員不在那一波要 FAIL
ok 28 bklog AC8: 無人擁有的測試檔引用了成員的可改檔 → WARN，exit 0
ok 29 bklog AC8: 測試檔有人擁有就不 WARN
ok 30 bklog AC8: glob 路徑與 .md 來源不觸發
not ok 31 bklog AC8: 多 repo 各在自己的 ls-files 裡找，路徑帶 <名>:   ← 這一輪如實是紅：失敗訊息為 FAIL 所有權 qa: 未知的 repo 名字 main（dk_glob_check 的 SIGPIPE 既有 bug，見自我審查）；repos.sh 修正後由下方 364 條與完整套件 714 條確認綠
$ for i in 1..5; tests/run.sh -f SIGPIPE tests/unit/16_brief_check.bats   （repos.sh 修正後）
ok 1 bklog: dk_glob_check 在 pipefail 下不會偶發誤判「未知的 repo 名字」（SIGPIPE 回歸）
ok 1 bklog: dk_glob_check 在 pipefail 下不會偶發誤判「未知的 repo 名字」（SIGPIPE 回歸）
ok 1 bklog: dk_glob_check 在 pipefail 下不會偶發誤判「未知的 repo 名字」（SIGPIPE 回歸）
ok 1 bklog: dk_glob_check 在 pipefail 下不會偶發誤判「未知的 repo 名字」（SIGPIPE 回歸）
ok 1 bklog: dk_glob_check 在 pipefail 下不會偶發誤判「未知的 repo 名字」（SIGPIPE 回歸）
$ tests/run.sh tests/unit/{08,13,15,16,18}_*.bats + 01 03 05 07 10 12 19 22 23 27 29 30 33
1..364，全 ok
$ tests/run.sh   （完整套件，送 DONE 前一次）
1..714，714 ok，rc=0
$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh
（無輸出）rc=0
```
### AC8：拿本任務 brief.md（定案版）跑的 WARN 清單
```
WARN 所有權: tests/unit/03_kinds.bats 引用了 dk-watch, kinds.sh, dk-wave-close（backend-watch, backend-brief 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）
WARN 所有權: tests/unit/05_task_new.bats 引用了 dk-watch, dk-msg, dk-process, dk-leader, dk-wave-close（backend-watch, backend-msg, backend-brief 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）
WARN 所有權: tests/unit/07_spawn.bats 引用了 dk-kind, repos.sh, dk-wave-open（backend-watch, backend-brief 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）
WARN 所有權: tests/unit/10_resume.bats 引用了 kinds.sh, dk-leader（backend-watch, backend-brief 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）
WARN 所有權: tests/unit/01_common.bats 引用了 dk-review, dk-leader, VERSION（backend-watch, backend-brief, backend-docs 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）
WARN 所有權: tests/unit/19_review_pack.bats 引用了 dk-review, repos.sh, dk-wave-open（backend-watch, backend-brief 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）
WARN 所有權: tests/unit/29_constraints.bats 引用了 dk-review, dk-brief-review, dk-wave-open（backend-watch, backend-brief 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）
WARN 所有權: tests/unit/11_chore.bats 引用了 dk-msg（backend-msg 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）
WARN 所有權: tests/unit/30_isolation.bats 引用了 dk-process, dk-leader（backend-msg, backend-brief 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）
WARN 所有權: tests/unit/27_qa_gate.bats 引用了 brief.sh（backend-brief 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）
WARN 所有權: tests/unit/22_ownership.bats 引用了 repos.sh, dk-wave-open, dk-wave-close（backend-brief 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）
WARN 所有權: tests/unit/33_repos.bats 引用了 repos.sh（backend-brief 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）
WARN 所有權: tests/unit/23_leader_kind.bats 引用了 dk-leader（backend-brief 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）
WARN 所有權: tests/unit/12_task_close.bats 引用了 dk-wave-close（backend-brief 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）
WARN 所有權: tests/unit/14_install.bats 引用了 VERSION（backend-docs 的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）
```
與 process.md `note: AC8 模擬` 比：模擬 14 個（01 03 05 07 10 11 12 14 19 22 23 27 29 30）全部出現，多一個 **33_repos.bats**。原因：14:52 的 ruling 把 `.dkbo/lib/repos.sh` 劃進 backend-brief 可改欄，33 引用 repos.sh 而無人擁有；模擬是在那之前做的。其餘一致。

#### 波1 自我審查
- 每條 AC 的測試：08（AC12 兩條）、15（AC12 prompt、AC9 共用函式、AC9 wave_members、AC10 模板）、16（AC9 欄數兩條、AC10 四條、AC8 四條、SIGPIPE 回歸一條）、18（AC9 兩條、AC13 一條）、13（AC11 三條＋改寫一條）。
- 既有測試語意：只新增斷言；唯一改寫的是 13_leader.bats「DK_WORKSPACE 原本非空…」那條（ruling 14:52 准，改成守反面新語意），以及 13 一行註解。沒有刪任何測試。
- 否定斷言全用 refute_grep，沒有 `! cmd`。沒有 bash 4 語法；新 awk 只用 POSIX（split、SUBSEP、gsub）。
- 排除過的假設（AC8 單 repo 紅）：輸出是 OK 而不是 WARN → 追到 `IFS=$'\t' read` 吃掉開頭的空欄（單 repo 的 repo 欄是空字串），改用 `-` 佔位。與 ownership.sh 註解講的是同一個坑。
- 排除過的假設（16:31 間歇紅）：不是我的 AC8 碼 —— 失敗訊息是 `FAIL 所有權 qa: 未知的 repo 名字 main`，來自 dk_glob_check；base 的 git archive 副本同樣會紅；直呼 3000 次 20 次；`printf|grep -qx` 在 pipefail vs 不開 pipefail 的對照確認是 SIGPIPE。
- dk-spawn:57 也對 dk_brief_owners 用裸 `awk -F'|'`，但只取第 2 欄（前面只有成員名，不會有 `\|`），不受影響，且不是我的檔，沒動。
- `dk_brief_md_rows` 的條件值以 \034 分隔，值可含空白；awk 的 split 會先清空陣列，列與列之間不會殘留舊欄。

#### 波1 疑慮
- AC8 的 WARN 是 basename 字面比對，會有誤報（例如 `VERSION` 這種常見字、或只在註解提到檔名）；AC 就是這樣定義的，只 WARN 不擋。
- SIGPIPE 回歸測試是機率性的：舊寫法 1500 次實測 5/5 紅（400 次約四成），修正後穩定綠；每次約 1.3 秒。
- 領導跑的是主樹腳本：本任務內這些新行為（無主測試 WARN、欄數閘、@波N、workspace 語意）一次都不會生效，本報告不宣稱已用到。

#### 波1 追記（DONE 之後）
- 應 backend-docs QUESTION：dk-leader:108 我新寫的註解含「計畫時記下」四字，會讓 25 的 Important4 新版全倉掃描紅；改成「空才退回 .task.env 的 DK_WORKSPACE」。`git ls-files` 全倉（排除 tasks/decisions/CHANGELOG）再掃，只剩 25 自己。重跑 `tests/run.sh tests/unit/13_leader.bats tests/unit/25_docs_policy.bats` → 1..55 全 ok；shellcheck dk-leader rc=0。
- 領導 DECISION（13:84 改寫、repos.sh 劃入）送到時兩件都已依 14:52 ruling 做完；切片重讀確認含 .dkbo/lib/repos.sh。誤報率與修後重跑見上文自我審查與疑慮段。
