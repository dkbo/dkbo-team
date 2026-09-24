# testtrust-backend 報告（波 2）
base：`b169571`（波 1 commit）。改動 5 檔：`tests/unit/35_test_hygiene.bats`、`tests/unit/36_fixture.bats`、`tests/helpers.bash`（只動 `fixture_env_check` 與它上面的註解）、`.dkbo/tasks/BACKLOG.md`、`CHANGELOG.md`。全部未 commit，留給 wave-close。

## 做了什麼
- **AC10(a)** `35_test_hygiene.bats:10` 的 `bang_scan` 正規式拆成三支：行首 `!`；`;`、`&&`、`||`、`|`、`{`、`(` 之後**零個以上**空白再接 `! `；`then`、`do`、`else`（前面是非字元）之後**一個以上**空白再接 `! `。關鍵字維持要空白：bash 的保留字後面本來就要空白（`then!` 是一個字），放寬成零空白只會多誤判 `echo "do! it"` 這種字串。頂端註解同步改寫。
  自我驗證（b）的必判樣本補 7 個：`true;! foo`、`a &&! b`、`a ||! b`、`{ ! foo; }`、`(! foo)`、`x | ! foo`、`if a; then b; else ! foo; fi`，照舊以 `b='!'` 在執行期 `printf` 寫臨時檔，35 原始碼沒有字面違規行。不判樣本 5 個照舊全過。
  新規則對 `git ls-files` 集合（38 檔）仍是 0 處 —— 沒有既有述句要照 AC1 轉換（先用寬鬆 grep 預掃 `{ ! `、`( ! `、`| ! `、`else ! `、`(( !` 也是 0）。
  **`echo "a;! b"` 會誤判**（grep 分不出引號）：取捨是不加入不判樣本、接受誤判。理由：掃描器是逐行 grep，要認引號就得寫 shell 詞法分析，成本遠大於收益；誤判方向是「多報」，碰到時把字串改寫（例如 `a; ! b` 以外的寫法或拆變數）就好，不會漏放無效斷言。波 1 版本對 `echo "a; ! b"`（有空白）本來就會誤判，這不是新類別。另外 `$(! foo)` 會判出（`(` 分隔符），這是對的：命令替換裡的 `!` 同樣豁免 set -e。`${!x}` 不判（`!` 後面不是空白）。
- **AC10(b)** `helpers.bash` 的 `fixture_env_check`：殘留判定從「成對 `{{…}}`」改成「任何一行含 `{{`」。逐行處理：抽得出 `{{` 後接識別字的印名字（`{{FOO}`、`{{FOO` 都印 `FOO`），抽不出的（如 `{{}`）印整行。仍只用 `local` 變數，36 的「不留變數與函式」照過。新增 36 兩條：模板追加 `DK_PROBE2="{{PROBE2"` → 回非零且 stderr 含 `PROBE2`；追加 `DK_PROBE3="{{}"` → 回非零且 stderr 含該行。
- **AC10(c)** `36_fixture.bats` 第一條（鍵集合與順序）加一行 `refute_grep -vE '^(DK_[A-Z_]*=|[[:space:]]*#|[[:space:]]*$)' "$d/.task.env"`：`DK_*=` 以外的非空、非註解行一出現就紅。
- **AC10(d)** `BACKLOG.md` 表格最後一列之後插一列（reviewer-a Minor 4，`tests/helpers.bash:14`），寫明「只複製追蹤檔會讓 worktree 未 commit 的 `.dkbo/` 改動進不了夾具」的取捨與折衷做法。其餘行一字不動（diff 只有 1 行 `+`）。
- **AC10(e)** `CHANGELOG.md` 0.15.0：「測試：」654 → **656**（+16 → +18；測試可信度 +12 → +14；`36_fixture` 7 → 9 條並列出兩條新的、鍵集合那條註明「且無雜行」）；`test:` 條目在「只動 `tests/`…」前補一句波 1 審查收尾內容。`.dkbo/VERSION`、README 未動。

## 測試
### 紅
AC10(a)：先在 35 補 7 個必判樣本、還沒改正規式就跑（worktree）：
```
$ tests/run.sh tests/unit/35_test_hygiene.bats
not ok 3 掃描器判出每一種 ! 述句形狀
# 漏判：true;! foo
```
同一批樣本對 `b169571` 版掃描器（`git archive b169571 | tar -x` 到 scratchpad，`eval` 抽出其 `bang_scan`）逐一檢查：7 個全部「漏判」（`true;! foo`、`a &&! b`、`a ||! b`、`{ ! foo; }`、`(! foo)`、`x | ! foo`、`if a; then b; else ! foo; fi`）。

AC10(b)：先寫 36 兩條新測試再跑（worktree，未改 `fixture_env_check`）：
```
$ tests/run.sh tests/unit/36_fixture.bats
not ok 4 模板裡半截的佔位符 {{PROBE2：fixture_task 回非零，stderr 點名 PROBE2   # [ "$rc" -ne 0 ] failed
not ok 5 抽不出名字的 {{：fixture_task 回非零，stderr 印出那一行              # [ "$rc" -ne 0 ] failed
```
把新 36 放進 `b169571` 副本跑：同樣 `not ok 4`、`not ok 5`，其餘 7 條 ok —— 舊自檢對半截 `{{` 回 0。

AC10(c)：現行 fixture 是對的，紅要靠破壞：worktree 的 `.dkbo`、`tests` 複製到 scratchpad，把 `fixture_task` 的 `( . "$DK_ROOT/lib/common.sh"` 改成 `( . "$DK_ROOT/lib/common.sh"; echo "stray output"`（模擬 source 時印到 stdout，雜行會被導進 `.task.env`）：
```
$ tests/run.sh tests/unit/36_fixture.bats
not ok 1 fixture 的 .task.env 鍵集合與順序和模板一致
#   `refute_grep -vE '^(DK_[A-Z_]*=|[[:space:]]*#|[[:space:]]*$)' "$d/.task.env"' failed
```
同一個破壞副本改跑 `b169571` 的 36：`ok 1 fixture 的 .task.env 鍵集合與順序和模板一致` —— 舊測試放過雜行。
### 綠
```
$ tests/run.sh tests/unit/35_test_hygiene.bats
1..5  全 ok（含 ok 1 tests/ 裡沒有 ! 開頭的否定述句 —— 新規則下 git ls-files 集合 0 處）
$ tests/run.sh tests/unit/36_fixture.bats
1..9  全 ok
$ tests/run.sh          # 送 DONE 前完整跑一次
1..656，656 ok，0 not ok，rc=0
```
`grep -c '^@test' tests/unit/*.bats` 合計 656，與 CHANGELOG 寫的一致（最終以 wave-close 實跑為準）。shellcheck 範圍（`.dkbo/bin`、`lib`、`kinds`）本波沒碰，未跑。

## 自我審查
- 全域約束：只動所有權內 5 檔；`.dkbo/bin|lib|kinds|templates` 零改動；沒有 bash 4 語法（`<<<` here-string、`${x:-y}` 在 3.2 可用）；沒有新增 `!` 述句也沒有 `run …; [ "$status" -ne 0 ]`。
- 既有斷言：35 只在樣本清單尾端加項、改正規式與註解；36 只在第一條尾端加一行斷言、另插兩條新測試；沒有改任何期望值或刪斷言。
- 排除過的假設：新規則的 `|` 會不會把 grep 樣式字串裡的 `a|! b` 誤判？預掃 38 檔 0 處，不影響現況；將來出現屬於「多報」方向，同上取捨。`(( ! x ))` 算術否定會被 `(` 判出（其實 set -e 對 `((…))` 有效）—— 現況 0 處，記在這裡。
- `fixture_env_check` 的 here-string 在 `.task.env` 沒有 `{{` 時餵進一個空行，已用 `[ -n "$line" ] || continue` 跳過（否則會把空字串當殘留、每個 fixture 都紅 —— 綠燈 656 條證明沒有）。

## 疑慮
- `echo "a;! b"`、`(( ! x ))` 兩種會誤判，已說明取捨；若領導要零誤判，需要換成真正的 shell 詞法掃描，建議不做。
- BACKLOG 新列的「折衷做法」是建議，沒實作（AC10(d) 只要求記錄）。

---
# 波 1 報告（原文保留）
## 做了什麼
- **AC3** 新增 `tests/unit/35_test_hygiene.bats`（5 條）：`bang_scan FILE…` 是可對任意檔呼叫的函式，一次 `grep -nE` 判出行首或 `;`／`&&`／`||`／`then`／`do` 之後的 `! `，再濾掉註解行，每個違規行印一列 `檔:行: 內容`。(a) 掃 `git ls-files --cached --others --exclude-standard 'tests/*.bats' tests/helpers.bash`（多帶 `--others` 是因為 35／36 在 wave-close commit 前還沒追蹤，不帶的話 35 掃不到自己）；(b) 植入的 6 個必須判出、5 個必須不判的樣本都在執行期用 `printf` 組出來（`b='!'` 再內插），35 的原始碼沒有字面違規行，(a) 掃到 35 自己是乾淨的；另有「掃描集合包含 35 與 helpers.bash」、「列出檔:行」兩條。
- **AC1/AC2** 76 處（74 行，15 檔）照三條規則機械轉換，只改那 74 行：`! git … | grep` → `git … | refute_grep`（4 處）；`! grep` → `refute_grep`；其餘 `! cmd` → `refute cmd`（`dk_ver_ge`、`dk_legacy_task`、`dk_owned`、`git rev-parse`、`kill -0`）。`24_portability:22`、`25_docs_policy:10` 只把 `! grep` 換掉，後面的 `|| { echo …; false; }` 保留。`refute` 放在 `helpers.bash` 緊接 `refute_grep` 之後。沒有任何一處用 `run` 取代。
  - 轉換總數 76：**原本有效 28**（整個 `@test` 最後執行的述句 26 處：06:24、06:54、11:19、11:91、11:227、01:103、01:152、07:50、07:60、12:63、12:70、26:63、26:249、17:52、17:57、08:76、20:25、20:48 第二處、20:68、09:8、09:166、09:181、09:233、09:334、09:424、09:430；已帶 `|| …false` 的 2 處：24:22、25:10），**原本失效 48**。
  - 與 request.md 的 50 差 2：BACKLOG 的 50 是「不是測試最後一條」的處數，把 24:22、25:10 也算進去（它們在 `for` 裡、不是最後一條，但帶 `|| false` 所以有效）。48＋2＝50，兩邊一致；AC2 的分類規則把這兩處歸「原本有效」。
- **AC4** `fixture_task()` 的 heredoc 換成 `( . "$DK_ROOT/lib/common.sh"; dk_render "$DK_ROOT/templates/task.env" … ) > .task.env || return 1`，值照 AC4：`SHORT`、`DISPLAY`、`BRANCH=dk/<short>`、`WORKTREE`、`WORKSPACE=wB`、`ROOT_PANE=wB:p1`、`BASE=<HEAD>`，`TASK_TAB`／`LEADER_PANE`／`NO_WORKTREE` 空字串。順手把迴圈變數 `e` 改成 `local`——它原本就外洩到呼叫端，AC5(d) 的新測試抓到了（見紅）。
- **AC5** 新增 `fixture_env_check TEMPLATE ENV`（helpers.bash，緊接 `fixture_task` 之後）：缺模板的任一 `DK_*` 鍵或殘留 `{{…}}`，把鍵名／佔位符名印 stderr 並回 1；`fixture_task` 以 `|| return 1` 接住。新增 `tests/unit/36_fixture.bats`（setup 只有 `setup_project`，不 source common.sh），(a) 鍵集合與順序一致、(a') 各鍵的值、(b) `DK_PROBE="{{PROBE}}"` 回非零且 stderr 含 PROBE、(c) 沒載 `dk_render` 時 `.task.env` 非空有 `DK_SHORT=`、(d) `declare -F`／`compgen -v` 前後沒有新增項。
- **AC9** `setup_project()` 在 `cp -r` 後 `find "$PROJECT/.dkbo/.sessions" -mindepth 1 -maxdepth 1 -not -name .gitkeep -exec rm -rf {} +`（只清副本，不碰主樹）。36 補兩條：用一個植入 `kinds-down`、`kinds-down.lock`、`chores/`、pane 綁定、`chores.watch.pid` 的假 REPO_ROOT 跑 `setup_project`，之後 `.sessions/` 只剩 `.gitkeep`、來源的 `kinds-down` 還在；真 REPO_ROOT 同樣只剩 `.gitkeep`。setup 自己不往 `.sessions/` 寫東西（`fixture_task` 才寫 `.sessions/wB:p1`，36 的這兩條沒呼叫它）。
- **AC6** 刪 BACKLOG 第 20、21 行兩列，diff 只有 2 行刪除。
- **AC7** CHANGELOG `## 0.15.0`：新增一條 `test:`（76 處／48 原本失效、35 守門、fixture 套模板與自檢、`.sessions/` 隔離），「測試：」行改成 654 bats（+16 相對 0.14.0，列出本任務新增的 12 條）。VERSION、README 未動。

## 測試
### 紅
- 35 對 base（未轉換）：`tests/run.sh tests/unit/35_test_hygiene.bats` → `not ok 1 tests/ 裡沒有 ! 開頭的否定述句（改用 refute_grep 或 refute）`，列出 **74 行、76 處**（15 檔；以行為單位輸出，一行兩處的是 `07_spawn:104`、`20_review:48`），首列 `tests/unit/01_common.bats:13:  ! dk_ver_ge 0.9.0 0.10.0`；自我驗證的 4 條同一次就綠。
- 36 對舊 heredoc fixture 與舊 setup_project：`tests/run.sh tests/unit/36_fixture.bats` → 7 條裡 5 條紅：
  - `not ok 1 …鍵集合與順序和模板一致`、`not ok 2 …LEADER_PANE 刻意空`（heredoc 缺 DK_TASK_TAB／DK_LEADER_PANE／DK_NO_WORKTREE）
  - `not ok 3 模板多一個 fixture 沒給的佔位符…` 失敗在 `[ "$rc" -ne 0 ]` —— **AC8(b)：在舊版會紅**，因為 heredoc 根本不讀模板，模板多了 `{{PROBE}}` 它照樣回 0
  - `not ok 5 fixture_task 不在呼叫端 shell 留下新的變數或函式` → `# 新增變數： # e`（舊版既有的外洩）
  - `not ok 6 setup_project 之後 .sessions/ 只剩 .gitkeep…` → 列出 `.gitkeep chores chores.watch.pid kinds-down kinds-down.lock wB:p9`
  - (c) 與真 REPO_ROOT 那條在 base 就綠（worktree 的 .sessions 本來就乾淨；heredoc 不需要 common.sh）
- AC8(c)（scratchpad 的 worktree rsync 副本，把 helpers.bash 的 `dk_render "$DK_ROOT/templates/task.env"` 換成 `true …`＝產出空檔）：`tests/run.sh tests/unit/06_msg.bats tests/unit/09_watch.bats` → `1..111`、ok 0、not ok 111。06（`fixture_task … >/dev/null` 形狀）：`setup() { setup_project; fixture_task login 使用者登入 >/dev/null; }' failed`；09（`d=$(…)` 形狀）：`setup() { setup_project; d=$(fixture_task login 使用者登入); … }' failed`；兩者 stderr 都是 `fixture_task: …/.task.env 缺鍵: DK_SHORT DK_DISPLAY DK_BRANCH DK_WORKTREE DK_WORKSPACE DK_TASK_TAB DK_ROOT_PANE DK_LEADER_PANE DK_BASE DK_NO_WORKTREE DK_WATCH_PID DK_EVENTS_PID DK_WAVE DK_WAVE_STARTED DK_KIND_DOWN DK_TABS`（111 則都有）。缺鍵分支活著。
- AC9 取紅（主樹 rsync 副本，排除 `.worktrees`；副本的 `.dkbo/.sessions/kinds-down` 有 `agy 1790772549`（2026-09-30）、`codex 1791718349`（2026-10-11），跑的當下 `date +%s`=1790211095，兩列都未過期）：修前 `tests/run.sh tests/unit/10_resume.bats` → `1..16`、ok 14、`not ok 2 AC6/Minor: 本波段多印專案層未恢復的 kind 與恢復時間`、`not ok 3 AC18/Minor: 兩波之間（DK_WAVE 空）也印專案層熔斷，guess 標記統一成 (guess)`，rc=1。主樹本身沒動。
### 綠
- 轉換後：`tests/run.sh <15 個受影響檔> tests/unit/35_test_hygiene.bats` → `1..386`、386 ok，沒有任何一條因轉換變紅（無需 ESCALATE）。
- `tests/run.sh tests/unit/36_fixture.bats tests/unit/35_test_hygiene.bats` → `1..12`，12 ok。
- AC9 修後（同一個主樹副本，只把 helpers.bash 換成本波版本，副本的 `.sessions/` 仍有 11 個檔）：`tests/run.sh tests/unit/10_resume.bats` → `1..16`、16 ok，rc=0。
- 全套（送 DONE 前一次）：`tests/run.sh` → `1..654`，654 ok、0 not ok，rc=0。CHANGELOG 的 654 與實跑一致。

## 自我審查
- 分類：逐處看下一個非空非註解行是否為 `@test` 的收尾 `}`，並確認所屬的是 `@test` 而不是 helper 函式、縮排兩格（不在 `for`／`if` 內）、且 `!` 是該行最後一個述句（20:48 第一處、07:99、11:82、14:38 都因後面還有述句歸失效）。
- 掃描器的已知盲區（AC 沒要求）：`(! cmd)`、`| ! cmd`、`$( ! cmd )` 不判；字串裡出現 `; ! ` 會誤判（目前 tests/ 沒有這種字串，35 的樣本全用變數內插避開）。
- 管線改法 `git … | refute_grep -qx …`：refute_grep 在管線的最後一段，回 1 就是整條管線的狀態，set -e 抓得到；bats 沒開 pipefail，前段的 git 失敗不影響，與原本 `! a | grep` 語意相同。
- `refute kill -0 "$epid" 2>/dev/null`、`refute_grep … 2>/dev/null`：原本的重導向保留，失敗時 refute 的提示訊息也會被吞，但仍回 1、測試照樣紅。
- `fixture_env_check` 是 helpers.bash 載入時就定義的函式，不是呼叫 fixture_task 才出現，所以 AC5(d) 前後比對不受影響；子 shell 裡 source common.sh 的 `DK_PROJECT_ROOT`、`LC_ALL` export 都留在子 shell。
- 排除過的假設：一度用 `git ls-files` 不帶 `--others`，35 未追蹤時「掃描集合包含 35」會紅——改成含未追蹤檔（仍排除 gitignore），不硬編清單。
- helpers.bash 的 `refute` 註解原本寫了 run 取代的字面寫法，會讓 AC1「diff 裡不出現」的 grep 誤中，改成文字敘述。

## 疑慮
- state 檔超過 20 行：touched 有 19 個檔、格式規定一檔一行且不得用 glob，加上必填欄位無法壓到 20 行內。
- `fixture_task` 寫 `brief.md` 那段 `sed` 替換仍是另一份與 `dk_render` 不同的替換邏輯（不在本任務 AC 內，沒動）。
