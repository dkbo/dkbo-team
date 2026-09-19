# dk-brief-review 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `/dkbo-plan` 裡加一道 AI 審查閘 `dk-brief-review`，派 2–3 個不同 kind 的 reviewer 讀「需求原文 + brief」並出固定格式意見，領導裁定後才准過關卡①。

**Architecture:** 照 `dk-review` 的骨架寫一支平行的腳本，兩者共用抽出來的 `lib/review.sh`（kind 選擇與檔位驗證）。審查材料是新增的 `request.md`（領導逐字落檔的需求原文）加上 `brief.md`。硬閘落在 `dk-task-new --gate1`：沒有裁定行、裁定漏交代別名、reviewer pane 還活著，三者任一就拒絕過關卡①。

**Tech Stack:** bash 3.2+、jq、git、herdr 0.9.0；測試是 bats-core 搭 `tests/stub` 的假 herdr（零 token）。

**Spec:** `.dkbo/tasks/2026-09-19-briefrev/plan.md`

## Global Constraints

- bash 3.2 相容（macOS 內建版本）：不用 `declare -A`、不用 `${var^^}`、不用 `mapfile`。
- 只依賴 bash / jq / git / herdr 本身，不新增外部依賴。
- 每支 `bin/dk-*` 開頭固定是 `set -euo pipefail` 與 `. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"`。
- shellcheck 必須零警告（設定在 `.dkbo/.shellcheckrc`，`tests/run.sh` 會跑）。
- 使用者可見字串一律繁體中文；程式碼註解在解釋「為什麼」時寫中文，語法說明寫英文，照既有檔案的密度。
- 別名固定 `p1 p2 p3`（不可用 `a b c`，會被每一波的 `dk-review` 覆蓋 `state/reviewer-a.*`）。
- 設定沿用既有 `DK_REVIEW_KINDS` / `DK_REVIEW_MIN` / `DK_REVIEW_TIER` / `DK_REVIEW_TIMEOUT_MIN`，**不新增任何 `DK_*` 設定鍵**。
- `process.md` 行格式固定為 `<時間戳> <內文>`，本功能用三種內文：
  `brief-review spawned <agent>(<kind>) …`、`brief-review verdict p1: … / p2: …`、`brief-review skipped: <理由>`。
- 不動版號與 CHANGELOG（發版是另一件事，等整個功能落地後一次做）。

---

### Task 1: 抽出 `lib/review.sh`，`dk-review` 改用它

把 kind 選擇與檔位驗證從 `dk-review` 抽成兩個函式，讓 `dk-brief-review` 共用。**行為必須完全不變** —— 這一步的驗證方式就是既有的 `20_review.bats` 全過，不新增測試。

**Files:**
- Create: `.dkbo/lib/review.sh`
- Modify: `.dkbo/bin/dk-review`（第 13 行 tier 解析、第 30–40 行 kind 過濾）
- Test: `tests/unit/20_review.bats`（既有，不改內容，當回歸網）

**Interfaces:**
- Consumes: `lib/common.sh` 的 `dk_die`；`.task.env` 的 `DK_KIND_DOWN`；`settings.env` 的 `DK_REVIEW_TIER`（由呼叫端先 `dk_settings`）
- Produces:
  - `dk_review_tier TIER_FLAG` → 印出 `M` 或 `L`；`TIER_FLAG` 為空時取 `DK_REVIEW_TIER`；不合法時 `dk_die` 並指名來源
  - `dk_review_kinds WANT CMD LABEL` → 印出實際要用的 kind（空白分隔、最多 3 個、濾掉熔斷者）；一個都不剩時往 stderr 印提示並 `return 1`

- [ ] **Step 1: 先確認回歸網是綠的**

Run: `tests/run.sh tests/unit/20_review.bats`
Expected: 11 項全 `ok`（這是重構前的基準線，之後要一模一樣）

- [ ] **Step 2: 建立 `lib/review.sh`**

```bash
# shellcheck shell=bash
# 審查共用：kind 選擇與檔位驗證。dk-review（差異包）與 dk-brief-review（計畫）共用這一份。
# 需要先 source common.sh（dk_die）、載入 .task.env（DK_KIND_DOWN）與 settings.env（DK_REVIEW_TIER）。

dk_review_tier() { # TIER_FLAG → M|L；空字串表示沒給 --tier，改取 settings.env
  local tier="${1:-}" src="--tier"
  [ -n "$tier" ] || { tier="${DK_REVIEW_TIER:-}"; src="settings.env 的 DK_REVIEW_TIER"; }
  [[ "$tier" =~ ^[ML]$ ]] || dk_die "$src 是 '$tier'：reviewer 檔位只能是 M 或 L"
  printf '%s' "$tier"
}

dk_review_kinds() { # WANT CMD LABEL → 可用的 kind（≤3，濾掉本任務已熔斷的）；全滅回非零
  local want="$1" cmd="$2" label="$3" k use=""
  for k in $want; do
    if [[ " ${DK_KIND_DOWN:-} " == *" $k "* ]]; then
      echo "$cmd: kind $k is down for this task; skipped" >&2; continue
    fi
    use="$use $k"
  done
  # shellcheck disable=SC2086  # split kinds on purpose
  use=$(printf '%s\n' $use | head -3 | tr '\n' ' ')
  if [ -z "${use// /}" ]; then
    echo "$cmd: no reviewer kind available; record: dk-process \"$label skipped: all kinds down\"" >&2
    return 1
  fi
  printf '%s' "$use"
}
```

- [ ] **Step 3: `dk-review` 改用它**

第 5 行的 source 清單加上 `lib/review.sh`：

```bash
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"; . "$DK_ROOT/lib/frontmatter.sh"; . "$DK_ROOT/lib/brief.sh"; . "$DK_ROOT/lib/review.sh"
```

把這兩行（原本的 tier 解析）：

```bash
src="--tier"; [ -n "$tier" ] || { tier="$DK_REVIEW_TIER"; src="settings.env 的 DK_REVIEW_TIER"; }
[[ "$tier" =~ ^[ML]$ ]] || dk_die "$src 是 '$tier'：reviewer 檔位只能是 M 或 L"
```

換成：

```bash
tier=$(dk_review_tier "$tier")
```

把這一段（原本的 kind 過濾）：

```bash
use=""
for k in $kinds; do
  if [[ " ${DK_KIND_DOWN:-} " == *" $k "* ]]; then echo "dk-review: kind $k is down for this task; skipped" >&2; continue; fi
  use="$use $k"
done
# shellcheck disable=SC2086  # split kinds on purpose
use=$(printf '%s\n' $use | head -3 | tr '\n' ' ')
[ -n "${use// /}" ] || { echo "dk-review: no reviewer kind available; record: dk-process \"review $n skipped: all kinds down\"" >&2; exit 1; }
```

換成：

```bash
use=$(dk_review_kinds "$kinds" dk-review "review $n") || exit 1
```

注意 `dk_review_tier` 的呼叫要放在 `dk_settings` 之後、且仍在旗標解析之後，位置與原本那兩行相同。

- [ ] **Step 4: 跑回歸，確認行為一個字都沒變**

Run: `tests/run.sh tests/unit/20_review.bats`
Expected: 仍是 11 項全 `ok`。特別注意這兩項必須綠，它們斷言的是**字面訊息**：
`downed kinds are skipped; all down exits 1 with the skip hint`（`codex is down`、`review 1 skipped: all kinds down`）與
`a DK_REVIEW_TIER that is not M or L is refused, naming settings.env`

- [ ] **Step 5: shellcheck**

Run: `tests/run.sh` 並確認 shellcheck 段零警告（`lib/review.sh` 開頭的 `# shellcheck shell=bash` 是必要的，缺了它 shellcheck 會把這個沒有 shebang 的檔案當成 sh）

- [ ] **Step 6: Commit**

```bash
git add .dkbo/lib/review.sh .dkbo/bin/dk-review
git commit -m "refactor(review): 抽出 lib/review.sh 供計畫審查共用"
```

---

### Task 2: `request.md` —— 需求原文落檔

`dk-task-new` 建任務時產出 `request.md`：`--from <檔>` 指向可讀檔案時**逐字複製內容**（不是塞路徑字串），否則寫一份空殼。`brief.md` 標頭加一行指路。

**Files:**
- Create: `.dkbo/templates/request.md`
- Modify: `.dkbo/bin/dk-task-new`（`dk_render` 那三行之後）、`.dkbo/templates/brief.md`（標頭）
- Test: `tests/unit/05_task_new.bats`

**Interfaces:**
- Consumes: `dk-task-new` 既有的 `$from`（`--from` 的值，預設字串 `人的口頭需求`）、`$dir`、`$display`
- Produces: `tasks/<日期-短名>/request.md`，供 Task 4 的 `dk-brief-review` 讀取；Task 4 只驗它存在且非空

- [ ] **Step 1: 寫失敗的測試**

加到 `tests/unit/05_task_new.bats` 尾端：

```bash
@test "task-new 產出 request.md 空殼" {
  d=$(dk-task-new login "使用者登入")
  [ -s "$d/request.md" ]
  grep -q '使用者登入' "$d/request.md"
  grep -q '逐字' "$d/request.md"
}
@test "--from 指向檔案時把需求原文逐字複製進 request.md" {
  printf '第一行需求\n第二行需求\n' > "$PROJECT/req.txt"
  d=$(dk-task-new login "使用者登入" --from "$PROJECT/req.txt")
  [ "$(cat "$d/request.md")" = "$(cat "$PROJECT/req.txt")" ]
  grep -q '來源：.*req.txt' "$d/brief.md"
}
@test "--from 指向不存在的檔時退回空殼，來源欄照舊" {
  d=$(dk-task-new login "使用者登入" --from "人在會議上口述")
  [ -s "$d/request.md" ]
  grep -q '來源：人在會議上口述' "$d/brief.md"
}
@test "brief 標頭指得到 request.md" {
  d=$(dk-task-new login "使用者登入")
  grep -q 'request.md' "$d/brief.md"
}
```

- [ ] **Step 2: 跑測試確認它失敗**

Run: `tests/run.sh tests/unit/05_task_new.bats`
Expected: 四項新測試 `not ok`（`request.md` 不存在）

- [ ] **Step 3: 建立 `templates/request.md`**

```markdown
# {{DISPLAY}} — 需求原文

把人講的原話**逐字**抄在下面。不要摘要、不要改寫、不要先做技術轉換 ——
brief 才是轉換的產物，這一份是用來比對「brief 有沒有漏掉人要的東西」的基準。
外部文件（spec、issue、對話紀錄）請把相關段落整段貼進來，不要只留連結：
連結會死，而這個檔案要活到任務歸檔之後還有人讀得懂。

---

（原文從這裡開始）
```

- [ ] **Step 4: `dk-task-new` 產出它**

在既有的三行 `dk_render`（`brief.md` / `process.md` / `.task.env`）之後加：

```bash
if [ -f "$from" ]; then cp "$from" "$dir/request.md"      # --from 指向真的檔案：逐字複製，不是塞路徑
else dk_render "$DK_ROOT/templates/request.md" "${vars[@]}" > "$dir/request.md"; fi
```

- [ ] **Step 5: `templates/brief.md` 標頭加一行指路**

把標頭第二行：

```
來源：{{SOURCE}}
```

改成兩行：

```
來源：{{SOURCE}}   需求原文：request.md
```

- [ ] **Step 6: 跑測試確認它通過**

Run: `tests/run.sh tests/unit/05_task_new.bats`
Expected: 全部 `ok`

- [ ] **Step 7: Commit**

```bash
git add .dkbo/templates/request.md .dkbo/templates/brief.md .dkbo/bin/dk-task-new tests/unit/05_task_new.bats
git commit -m "feat(task-new): 需求原文落檔成 request.md"
```

---

### Task 3: 計畫審查切片範本與角色檔

**Files:**
- Create: `.dkbo/templates/brief-reviewer-plan.md`
- Modify: `.dkbo/roles/reviewer.md`（「職責」段）
- Test: `tests/unit/28_brief_review.bats`（本任務只加一項角色檔的測試，其餘在 Task 4）

**Interfaces:**
- Consumes: `dk_render` 的變數替換（`{{KEY}}` → 值）
- Produces: 範本檔，變數為 `DISPLAY` `REQUEST` `BRIEF` `REPORT`，由 Task 4 的 `dk-brief-review` 渲染

- [ ] **Step 1: 寫失敗的測試**

新檔 `tests/unit/28_brief_review.bats`：

```bash
load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"; }
teardown() { teardown_project; }

@test "roles/reviewer.md 認得計畫審查，且格式以切片為準" {
  grep -q '計畫審查' "$DK_ROOT/roles/reviewer.md"
  grep -q '以切片為準' "$DK_ROOT/roles/reviewer.md"
}
@test "計畫審查範本問的是計畫，不是程式碼" {
  t="$DK_ROOT/templates/brief-reviewer-plan.md"
  for s in '## 需求覆蓋' '## 驗收標準可驗證性' '## 檔案所有權' '## 波次切法' '## Minor' '## 結論'; do
    grep -qF "$s" "$t" || { echo "缺少段落：$s"; false; }
  done
  grep -q '{{REQUEST}}' "$t"; grep -q '{{BRIEF}}' "$t"; grep -q '{{REPORT}}' "$t"; grep -q '{{DISPLAY}}' "$t"
  grep -q '不需要讀專案程式碼' "$t"
  # 需求覆蓋必須排在其餘四段之前：那是唯一只有看了 request 才答得出來的一段
  [ "$(grep -n '## 需求覆蓋' "$t" | cut -d: -f1)" -lt "$(grep -n '## 檔案所有權' "$t" | cut -d: -f1)" ]
}
```

- [ ] **Step 2: 跑測試確認它失敗**

Run: `tests/run.sh tests/unit/28_brief_review.bats`
Expected: 兩項都 `not ok`（範本不存在、角色檔沒有那兩個詞）

- [ ] **Step 3: 建立 `templates/brief-reviewer-plan.md`**

```markdown
# {{DISPLAY}} — 計畫審查（reviewer 切片）
你審的是**還沒開工的計畫**，不是程式碼，也不是差異包。只讀、不改任何檔（包含 brief）、
不派工、不寫程式。意見只給領導（dk-msg leader），不要直接對任何人說。

## 要讀的（就這兩份，依序）
1. 需求原文 {{REQUEST}} —— 人講的原話，領導逐字抄下來的
2. brief {{BRIEF}} —— 領導的轉換產物

你不需要讀專案程式碼。你要回答的是「這份計畫做出來會不會是人要的東西」，
不是「這段碼寫得好不好」。每條意見都要指名 brief 的哪一段或波次表的哪一列。

## 報告寫到 {{REPORT}}，格式固定
## 需求覆蓋
（逐條對照 request：人要的每一件事，brief 有沒有對應的驗收標準？
  漏的列出來，指明 request 的哪一段沒有被接住）
## 驗收標準可驗證性
（逐條 AC：能不能明確判定過或不過？不能的指出來，並給一個可驗證的改寫）
## 檔案所有權
（成員之間有無重疊或遺漏？有沒有哪條 AC 要動的檔沒有任何人擁有？獨佔資源欄有無漏）
## 波次切法
（順序合理嗎？同一波裡有沒有人其實要等另一個人的產出？共用契約有沒有指定擁有者）
## Minor
（其餘建議）
## 結論
一行，只能是 `可以開工` 或 `要改 N 處`（N = 前四段裡你認為**必須**改的條數）

## 完成
state 檔 `status: done`，然後
dk-msg leader "[DONE] brief-review: <可以開工|要改 N 處>，見 report"
```

- [ ] **Step 4: 改 `roles/reviewer.md` 的「職責」段**

把現有的：

```markdown
## 職責
實作波審查與結案評議：讀 `waves/N.diff` 與 brief，逐條驗收標準判合規，找出會出錯、違反契約、越界改檔的地方。不改任何程式、不跑會寫入的指令。評議波（設計題）時把意見寫在 state 的 notes（≤15 行），第二輪只准發一則反駁。
```

改成：

```markdown
## 職責
三種工作，**報告格式一律以你收到的切片為準**（下面的完成定義是實作波審查那一種）：
- 實作波審查與結案評議：讀 `waves/N.diff` 與 brief，逐條驗收標準判合規，找出會出錯、違反契約、越界改檔的地方。
- 計畫審查（`dk-brief-review`，開工前）：讀需求原文與 brief，回答「這份計畫做出來會不會是人要的東西」。沒有 diff、沒有 `file:line`，改為指名 brief 的段落或波次表的列。
- 評議波（設計題）：把意見寫在 state 的 notes（≤15 行），第二輪只准發一則反駁。

不改任何程式、不跑會寫入的指令。
```

- [ ] **Step 5: 跑測試確認它通過**

Run: `tests/run.sh tests/unit/28_brief_review.bats`
Expected: 兩項 `ok`

- [ ] **Step 6: Commit**

```bash
git add .dkbo/templates/brief-reviewer-plan.md .dkbo/roles/reviewer.md tests/unit/28_brief_review.bats
git commit -m "feat(review): 計畫審查的切片範本與角色職責"
```

---

### Task 4: `dk-brief-review` 腳本

**Files:**
- Create: `.dkbo/bin/dk-brief-review`
- Test: `tests/unit/28_brief_review.bats`（接續 Task 3 的檔案）

**Interfaces:**
- Consumes: Task 1 的 `dk_review_tier` / `dk_review_kinds`；Task 2 的 `tasks/<t>/request.md`；Task 3 的 `templates/brief-reviewer-plan.md`；既有的 `dk-spawn`、`dk-brief-check`、`dk_process`、`dk_render`
- Produces:
  - `briefs/reviewer-p<n>.md`（切片）
  - `process.md` 的 `brief-review spawned <agent>(<kind>) …` 行 —— Task 5 的閘會解析它
  - stdout 一行 `brief-review: <agent>(<kind>) …`

- [ ] **Step 1: 寫失敗的測試**

加到 `tests/unit/28_brief_review.bats`。注意 `fixture_task` 不會產出 `request.md`（它是 Task 2 才加進 `dk-task-new` 的，而 fixture 是自己拼的），所以每個要走正常路徑的測試都要自己寫一份：

```bash
have_request() { printf '人要一個登入功能，空密碼要擋掉。\n' > "$d/request.md"; }

@test "沒有 request.md 就拒跑，一個 pane 都不開" {
  run dk-brief-review
  [ "$status" -eq 1 ]; [[ "$output" == *"需求原文"* ]]
  ! grep -q '^agent start' "$HERDR_STUB_LOG"
}
@test "request.md 是空的也拒跑" {
  : > "$d/request.md"
  run dk-brief-review; [ "$status" -eq 1 ]; [[ "$output" == *"需求原文"* ]]
  ! grep -q '^agent start' "$HERDR_STUB_LOG"
}
@test "dk-brief-check 沒過就不燒 token" {
  have_request
  sed -i '/^- \[ \] /d' "$d/brief.md"          # 拿掉全部驗收標準 → dk-brief-check 必 FAIL
  run dk-brief-review; [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL 驗收標準"* ]]; [[ "$output" == *"dk-brief-check"* ]]
  ! grep -q '^agent start' "$HERDR_STUB_LOG"
}
@test "正常路徑：別名 p1/p2、切片指向 request 與 brief、process 記一行" {
  have_request; printf 'DK_REVIEW_KINDS="claude codex"\n' >> "$DK_ROOT/settings.env"
  run dk-brief-review; [ "$status" -eq 0 ]
  [ "$output" = "brief-review: login-reviewer-p1(claude) login-reviewer-p2(codex)" ]
  grep -q '^agent start login-reviewer-p1 --kind claude ' "$HERDR_STUB_LOG"
  grep -q '^agent start login-reviewer-p2 --kind codex ' "$HERDR_STUB_LOG"
  grep -q -- '--env DK_ISOLATED=1' "$HERDR_STUB_LOG"
  grep -q ' brief-review spawned login-reviewer-p1(claude) login-reviewer-p2(codex)$' "$d/process.md"
  grep -qF "$d/request.md" "$d/briefs/reviewer-p1.md"
  grep -qF "$d/brief.md" "$d/briefs/reviewer-p1.md"
  grep -qF "$d/state/reviewer-p1.report.md" "$d/briefs/reviewer-p1.md"
  grep -q '## 需求覆蓋' "$d/briefs/reviewer-p2.md"
  grep -qF "$d/briefs/reviewer-p1.md" "$HERDR_STUB_LOG"   # 首輪提示用的是切片
}
@test "--kinds 與 --tier 覆寫；最多三位" {
  have_request
  run dk-brief-review --kinds "agy"; [ "$status" -eq 0 ]; [ "$output" = "brief-review: login-reviewer-p1(agy)" ]
  : > "$HERDR_STUB_LOG"
  run dk-brief-review --kinds "claude codex agy claude" --tier L; [ "$status" -eq 0 ]
  [ "$(grep -c '^agent start login-reviewer-p' "$HERDR_STUB_LOG")" -eq 3 ]
  grep -q -- '--model opus --effort high' "$HERDR_STUB_LOG"
  run dk-brief-review --tier S; [ "$status" -eq 1 ]
}
@test "熔斷的 kind 被跳過；全滅回非零並給出該記的 process 行" {
  have_request; sed -i 's/^DK_KIND_DOWN=.*/DK_KIND_DOWN="codex"/' "$d/.task.env"
  run dk-brief-review --kinds "codex claude"; [ "$status" -eq 0 ]
  [[ "$output" == *"login-reviewer-p1(claude)"* ]]; [[ "$output" == *"codex is down"* ]]
  : > "$HERDR_STUB_LOG"
  run dk-brief-review --kinds codex; [ "$status" -eq 1 ]
  [[ "$output" == *'brief-review skipped: all kinds down'* ]]
  ! grep -q '^agent start' "$HERDR_STUB_LOG"
}
@test "全數 spawn 失敗時退非零，且不留下 spawned 行" {
  have_request
  HERDR_STUB_FAIL="agent start" run dk-brief-review; [ "$status" -eq 1 ]
  [[ "$output" == *"no reviewer spawned"* ]]
  ! grep -q ' brief-review spawned' "$d/process.md"
}
@test "首輪提示失敗的 reviewer 仍算派出，但標 prompt-failed" {
  have_request
  HERDR_STUB_FAIL="agent prompt" run dk-brief-review; [ "$status" -eq 0 ]
  [[ "$output" == *"login-reviewer-p1(claude,prompt-failed)"* ]]
  grep -q ' brief-review spawned login-reviewer-p1(claude,prompt-failed)$' "$d/process.md"
}
@test "不吃位置參數（波號是執行階段的概念）" {
  have_request; run dk-brief-review 1
  [ "$status" -eq 1 ]; [[ "$output" == *"unexpected argument"* ]]
}
```

- [ ] **Step 2: 跑測試確認它失敗**

Run: `tests/run.sh tests/unit/28_brief_review.bats`
Expected: 九項新測試全 `not ok`（`dk-brief-review: command not found`）

- [ ] **Step 3: 寫 `bin/dk-brief-review`**

```bash
#!/usr/bin/env bash
# dk-brief-review [--kinds "k1 k2 k3"] [--tier M|L] — 開工前的計畫審查：派 1–3 位隔離 reviewer
# 讀 request.md + brief.md 出意見。與 dk-brief-check 同一層：那一支驗形狀，這一支看內容。
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"; . "$DK_ROOT/lib/review.sh"
dir=$(dk_task_dir); DK_TASK_DIR="$dir"; export DK_TASK_DIR; dk_task_env; dk_settings
kinds=""; tier=""
while [ $# -gt 0 ]; do case "$1" in
  --kinds) kinds="$2"; shift 2;; --tier) tier="$2"; shift 2;;
  --*) dk_die "unknown flag $1";; *) dk_die "unexpected argument $1（計畫審查不分波；波號是執行階段的概念）";; esac; done

req="$dir/request.md"
[ -s "$req" ] || dk_die "缺需求原文 $req —— 先把人的原話逐字抄進去。reviewer 少了它只能在 brief 的自我一致性裡打轉，看不出 brief 漏掉了什麼。"
# 零 token 的機械閘沒過就燒三個 kind 的 token，是這個設計裡最蠢的失敗模式。順序由程式保證，不靠領導記得。
"$DK_ROOT/bin/dk-brief-check" || dk_die "dk-brief-check 沒過（上面那幾條 FAIL），先修 brief 再回來"

tier=$(dk_review_tier "$tier")
[ -n "$kinds" ] || kinds="$DK_REVIEW_KINDS"
use=$(dk_review_kinds "$kinds" dk-brief-review "brief-review") || exit 1

aliases=(p1 p2 p3); i=0; spawned=""; failed=""
mkdir -p "$dir/briefs" "$dir/state"
for k in $use; do
  alias="${aliases[$i]}"; i=$((i+1)); sname="reviewer-$alias"
  dk_render "$DK_ROOT/templates/brief-reviewer-plan.md" "DISPLAY=$DK_DISPLAY" "REQUEST=$req" \
    "BRIEF=$dir/brief.md" "REPORT=$dir/state/$sname.report.md" > "$dir/briefs/$sname.md"
  if out=$("$DK_ROOT/bin/dk-spawn" reviewer "$alias" --isolated --kind "$k" --tier "$tier"); then rc=0; else rc=$?; fi
  if [ -n "$out" ] && [ "$rc" = 0 ]; then
    spawned="$spawned ${out%% *}($k)"
  elif [ -n "$out" ]; then
    spawned="$spawned ${out%% *}($k,prompt-failed)"
    echo "dk-brief-review: first prompt to ${out%% *} failed; herdr agent read it, then re-prompt" >&2
  else
    echo "dk-brief-review: could not spawn reviewer $alias ($k)" >&2; failed="$failed $k"
  fi
done
[ -n "$spawned" ] || dk_die "no reviewer spawned (dk-spawn failed for:$failed); check herdr, then retry dk-brief-review or record: dk-process \"brief-review skipped: <理由>\""
dk_process "brief-review spawned$spawned"
echo "brief-review:$spawned"
```

- [ ] **Step 4: 給它執行權限**

```bash
chmod +x .dkbo/bin/dk-brief-review
```

（`tests/helpers.bash` 的 `setup_project` 會 `chmod +x` 複製過去的 `bin/*`，但版控裡的模式位要自己設對，否則真實安裝會拿到一個不能執行的檔。）

- [ ] **Step 5: 跑測試確認它通過**

Run: `tests/run.sh tests/unit/28_brief_review.bats`
Expected: 11 項全 `ok`

- [ ] **Step 6: Commit**

```bash
git add .dkbo/bin/dk-brief-review tests/unit/28_brief_review.bats
git commit -m "feat(plan): dk-brief-review 派計畫的第二三意見"
```

---

### Task 5: `--gate1` 的三道硬閘

**Files:**
- Modify: `.dkbo/bin/dk-task-new`（`if [ "$gate1" = 1 ]` 區塊）
- Test: `tests/unit/05_task_new.bats`（新增四項；**修掉既有四項**）

**Interfaces:**
- Consumes: Task 4 寫進 `process.md` 的 `brief-review spawned …` 行；`.panes` 的 agent 欄；`.task.env` 的 `DK_SHORT`
- Produces: 無新介面；`--gate1` 的成功路徑（`gate1 approved` + INDEX 轉 running）不變

- [ ] **Step 1: 先修既有測試（它們會因為新閘而變紅）**

`05_task_new.bats` 裡有四處直接呼叫 `--gate1`，都要先記一行跳過理由。把：

```bash
@test "task-new --gate1 flips index to running" {
  dk-task-new login "使用者登入" >/dev/null
  dk-task-new login --gate1
```

改成：

```bash
@test "task-new --gate1 flips index to running" {
  dk-task-new login "使用者登入" >/dev/null
  dk-process "brief-review skipped: 單元測試"
  dk-task-new login --gate1
```

同樣的 `dk-process "brief-review skipped: 單元測試"` 要加在 `hyphenated short names do not collide` 那一項的 `dk-task-new new --gate1` 之前（該測試先 `dk-task-new brand-new x` 再 `dk-task-new new y`，`dk-process` 綁的是最後寫進 `.sessions` 的那個任務，也就是 `new`，正是要放行的那一個）。

`task-new --gate1 on unknown short dies cleanly` 不用改（它在找任務那一步就死了，還沒走到閘）。

- [ ] **Step 2: 寫新閘的失敗測試**

加到 `tests/unit/05_task_new.bats` 尾端：

```bash
@test "gate1 拒絕沒有計畫審查裁定的任務" {
  dk-task-new login "使用者登入" >/dev/null
  run dk-task-new login --gate1
  [ "$status" -eq 1 ]; [[ "$output" == *"brief-review"* ]]
  ! grep -q 'gate1 approved' "$DK_ROOT/tasks/$(date +%F)-login/process.md"
  ! grep -q '| 使用者登入 | task | running |' "$DK_ROOT/tasks/INDEX.md"
}
@test "gate1 接受 skipped，也接受 verdict" {
  dk-task-new login "使用者登入" >/dev/null
  dk-process "brief-review skipped: 純文件任務"
  run dk-task-new login --gate1; [ "$status" -eq 0 ]
  grep -q 'gate1 approved' "$DK_ROOT/tasks/$(date +%F)-login/process.md"
}
@test "gate1 要求裁定交代每一位真的派出去的 reviewer" {
  d=$(dk-task-new login "使用者登入")
  dk-process "brief-review spawned login-reviewer-p1(claude) login-reviewer-p2(codex)"
  dk-process "brief-review verdict p1: ok"
  run dk-task-new login --gate1
  [ "$status" -eq 1 ]; [[ "$output" == *"p2"* ]]
  dk-process "brief-review verdict p1: ok / p2: skipped (逾時)"
  run dk-task-new login --gate1; [ "$status" -eq 0 ]
}
@test "gate1 拒絕還開著的計畫審查 pane" {
  d=$(dk-task-new login "使用者登入")
  dk-process "brief-review skipped: 測試"
  echo "login-reviewer-p1 wC:p9 $(date +%s) review 1 2" >> "$d/.panes"
  run dk-task-new login --gate1
  [ "$status" -eq 1 ]; [[ "$output" == *"login-reviewer-p1"* ]]; [[ "$output" == *"dk-wave-close --agent"* ]]
  : > "$d/.panes"
  run dk-task-new login --gate1; [ "$status" -eq 0 ]
}
```

- [ ] **Step 3: 跑測試確認新的四項失敗**

Run: `tests/run.sh tests/unit/05_task_new.bats`
Expected: 新增四項 `not ok`（現在的 `--gate1` 什麼都不檢查，所以第一項會成功過關），既有的都 `ok`

- [ ] **Step 4: 在 `dk-task-new` 加三道閘**

把現有的：

```bash
if [ "$gate1" = 1 ]; then
  existing=$(compgen -G "$DK_ROOT/tasks/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-$short" | tail -1 || true); [ -n "$existing" ] || dk_die "no task $short"
  DK_TASK_DIR="$existing"; export DK_TASK_DIR; dk_task_env
  dk_process "gate1 approved"
```

改成：

```bash
if [ "$gate1" = 1 ]; then
  existing=$(compgen -G "$DK_ROOT/tasks/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-$short" | tail -1 || true); [ -n "$existing" ] || dk_die "no task $short"
  DK_TASK_DIR="$existing"; export DK_TASK_DIR; dk_task_env
  # 關卡①的三道閘。計畫審查與 dk-brief-check 同一層，但只有這一道是機械擋得住的 ——
  # 「改完 brief 有沒有重跑 dk-brief-check」到了這裡已經分辨不出來，那條只寫在 SKILL 裡。
  p="$existing/process.md"
  grep -Eq '^[^ ]+ brief-review (verdict|skipped:)' "$p" \
    || dk_die "關卡①：process.md 沒有計畫審查的結果。跑 dk-brief-review 並在收齊後記 dk-process \"brief-review verdict p1: … / p2: …\"；真的不審就記 dk-process \"brief-review skipped: <理由>\""
  vline=$(grep -E '^[^ ]+ brief-review verdict' "$p" | tail -1 || true)
  if [ -n "$vline" ]; then   # 派了三個 kind 卻只讀一個的意見，等於第二意見白花（同 dk-wave-close 的 gate a2）
    for al in $(grep -E '^[^ ]+ brief-review spawned ' "$p" | tail -1 | grep -oE 'reviewer-p[0-9]+' | sed 's/reviewer-//' | sort -u); do
      case "$vline" in *"$al:"*) ;;
        *) dk_die "brief-review verdict 沒有交代 reviewer $al（寫它的結果，或 '$al: skipped (<理由>)'）";; esac
    done
  fi
  live=$(grep -oE "^$DK_SHORT-reviewer-p[0-9]+" "$existing/.panes" 2>/dev/null | sort -u | tr '\n' ' ' || true)
  [ -z "${live// /}" ] || dk_die "計畫審查的 pane 還開著：${live% } —— 先 dk-wave-close --agent <agent> 逐個關掉。留著它們會佔版面格子、被守望當活人算逾時，而且第一波的 dk-wave-close 會因為它們沒 done 而永遠關不掉。"
  dk_process "gate1 approved"
```

- [ ] **Step 5: 跑測試確認全過**

Run: `tests/run.sh tests/unit/05_task_new.bats`
Expected: 全部 `ok`（含改過的四項既有測試）

- [ ] **Step 6: Commit**

```bash
git add .dkbo/bin/dk-task-new tests/unit/05_task_new.bats
git commit -m "feat(gate1): 沒有計畫審查的結果就不放行關卡①"
```

---

### Task 6: 規範與文件

**Files:**
- Modify: `.dkbo/skills/plan/SKILL.md`、`.dkbo/README.md`（指令一覽）、`README.md`（指令一覽與生命週期）、`README.en.md`（同上）
- Test: `tests/unit/28_brief_review.bats`（加一項規範測試）

**Interfaces:**
- Consumes: 前面五個 Task 的指令與檔名
- Produces: 無程式介面

- [ ] **Step 1: 寫失敗的測試**

加到 `tests/unit/28_brief_review.bats`：

```bash
@test "plan SKILL 把兩道閘與 pane 收尾都寫清楚" {
  s="$DK_ROOT/skills/plan/SKILL.md"
  grep -q 'request.md' "$s"; grep -q 'dk-brief-check' "$s"; grep -q 'dk-brief-review' "$s"
  grep -q 'dk-wave-close --agent' "$s"          # 裁定後要關掉 reviewer pane
  grep -q '重跑' "$s"                            # 改完 brief 要重跑 dk-brief-check
  # 兩道閘的順序：機械閘在 AI 閘之前
  [ "$(grep -n 'dk-brief-check' "$s" | head -1 | cut -d: -f1)" -lt "$(grep -n 'dk-brief-review' "$s" | head -1 | cut -d: -f1)" ]
}
```

- [ ] **Step 2: 跑測試確認它失敗**

Run: `tests/run.sh tests/unit/28_brief_review.bats`
Expected: 該項 `not ok`

- [ ] **Step 3: 改寫 `skills/plan/SKILL.md` 的「開任務」段**

把現有的四步換成：

```markdown
## 開任務
1. `dk-task-new <short> "<顯示名>" [--from <檔>]`。
2. 寫 `request.md`：把人講的原話**逐字**抄進去，不摘要、不改寫。有外部文件就把相關段落整段貼進來（連結會死）。`--from` 指到真的檔案時它已經幫你複製好了。
3. 寫 `brief.md`：目標 ≤3 行、驗收標準、檔案所有權（成員範圍不得重疊）、共用契約擁有者、波次表。波次表一列一位成員（標難度 S/M/L），審查欄只填在該波第一列，三種寫法：`預設`（用 settings.env 的 kind）、`skip: <理由>`（純文件波）、`kinds: <k1> [k2] [k3]`（指定 1–3 個 kind 當第二、三意見）。成員欄填 `<角色>[-<別名>]`（即 state 檔名，不含任務短名），可改欄以逗號分隔 glob，`dir/**` 代表整棵子樹。有 plan 檔時不重寫內容，只對應驗收、劃所有權、把 task 分組成波。
4. `dk-brief-check`（機械閘，零 token）。FAIL 就修 brief 重跑；WARN（一波 dev 超過 tab 1 格數）建議拆波。
5. `dk-brief-review`（AI 閘）：派 2–3 個 kind 讀 request 與 brief。它自己會先跑一次 `dk-brief-check`，沒過就不派人。派完結束這個 turn，等 reviewer 的 `[DONE]`。
6. 收齊（達 `DK_REVIEW_MIN` 位、或所有人都回覆了）後裁定：`dk-process "brief-review verdict p1: 可以開工 / p2: 要改 2 處"`。採納的意見改進 brief，有爭議或意見矛盾時以需求原文為準並記 `ruling:`（格式見 `.dkbo/LEADER.md`）。**改完 brief 要重跑 `dk-brief-check`** —— 改所有權很容易改出重疊。然後逐個關掉 reviewer：`dk-wave-close --agent <任務短名>-reviewer-p1`。
7. 關卡①：把 `request.md`、`brief.md` 與裁定摘要三份給人確認。只給 brief 的話，人看不出你有沒有從一開始就聽錯 —— 而那正是 reviewer 結構上抓不到的那一類錯。人點頭後執行 `dk-task-new <short> --gate1`（它會檢查計畫審查的結果、裁定有沒有交代每一位 reviewer、reviewer pane 有沒有關乾淨，然後記 process、INDEX 改 running）。
```

- [ ] **Step 4: 三個 README 的指令一覽各加一列**

`README.md` 與 `.dkbo/README.md` 的指令表，在 `dk-task-new` / `dk-brief-check` 那一列之後插入：

```markdown
| `dk-brief-review` | 開工前派 1 到 3 位 reviewer 審 brief 與需求原文（AI 閘，關卡①前的第二道） |
```

`README.md` 的「一個任務的生命週期」第 2 點結尾補一句：

```markdown
接著 `dk-brief-review` 派 2 到 3 個不同 kind 讀需求原文與 brief，領導裁定並改完 brief，才把三份（需求原文、brief、裁定摘要）給你確認。這是**關卡①**。
```

`README.en.md` 對應處同步（指令表一列、生命週期一句）。

- [ ] **Step 5: 跑全套測試**

Run: `tests/run.sh`
Expected: 全綠。特別注意 `25_docs_policy.bats` 與 `21_version.bats` —— 前者管文件規則，後者數三個 README 裡的版號字串（**這次不動版號，數字應該還是 8**）。

- [ ] **Step 6: Commit**

```bash
git add .dkbo/skills/plan/SKILL.md .dkbo/README.md README.md README.en.md tests/unit/28_brief_review.bats
git commit -m "docs(plan): 計畫階段的兩道閘寫進規範與 README"
```

---

### Task 7: 端到端自驗與收尾

**Files:**
- Modify: `.dkbo/tasks/2026-09-19-briefrev/plan.md`（勾掉驗收標準）
- Test: 全套

**Interfaces:**
- Consumes: Task 1–6 的全部產出
- Produces: 一份可以發版的工作樹（版號與 CHANGELOG 由人決定何時做）

- [ ] **Step 1: 全套測試 + shellcheck**

Run: `tests/run.sh`
Expected: 全綠，零 shellcheck 警告。測試數應為 305 + 新增項（Task 2 四項、Task 3 兩項、Task 4 九項、Task 5 四項、Task 6 一項 = 325）

- [ ] **Step 2: 逐條對照 spec 的驗收標準**

打開 `.dkbo/tasks/2026-09-19-briefrev/plan.md` 第 13 節，七條 AC 逐條確認有對應的綠燈測試，把 `- [ ]` 改成 `- [x]`。有任何一條找不到對應測試就回去補測試，不要只勾。

- [ ] **Step 3: 人工煙霧測試（需要真的在 herdr 內，會花 token）**

這一步不能由測試代勞 —— 假 herdr 證明不了真的 AI CLI 會不會照切片做事。

```bash
# 在 herdr pane 內，於一個乾淨的測試專案：
dk-task-new smoke "煙霧測試"
# 把兩三行需求寫進 tasks/<日期>-smoke/request.md
# 照範本寫一份最小 brief.md
dk-brief-review --kinds "claude codex"
# 等兩位 reviewer 的 [DONE]，讀 state/reviewer-p1.report.md 與 p2
```

確認三件事：報告真的照切片的六段格式寫；`## 結論` 那一行真的只有 `可以開工` 或 `要改 N 處`；reviewer 沒有去翻專案程式碼（report 裡不應該出現 brief 與 request 以外的檔案路徑）。

- [ ] **Step 4: Commit**

```bash
git add .dkbo/tasks/2026-09-19-briefrev/plan.md
git commit -m "docs(plan): dk-brief-review 驗收標準逐條勾稽"
```
