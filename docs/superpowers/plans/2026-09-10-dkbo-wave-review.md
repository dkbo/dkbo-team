# dkbo 每波審查閘、事前防線與多人版面 — 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓 dkbo 的每一個實作波內建 reviewer 審查閘（與 qa 並行）、brief 機械預檢、員工個人 brief 切片、報告檔與測試閘、reviewer 逾時熔斷，以及領導佔左欄、員工依格填位的多人 herdr 版面。

**Architecture:** 所有機械判斷仍放在 `.dkbo/bin/dk-*`（bash，source `.dkbo/lib/*.sh`），新增 `lib/brief.sh`（brief 表格解析）、`lib/layout.sh`（格位與均分）、`.dkbo/settings.env`（init 寫、bash source）。需要判斷的規則留在 `LEADER.md`、`PROTOCOL.md`、`roles/*.md`。單元測試以 `tests/stub/herdr` 假 herdr 跑 bats；真 herdr 形狀由 `tests/integration/herdr-real.sh` 驗。

**Tech Stack:** bash 5、jq 1.7、git 2.43、herdr 0.9.0 CLI、bats-core（`tests/lib/bats-core`）。

**Spec:** `docs/superpowers/specs/2026-09-10-dkbo-wave-review-design.md`（前置：`docs/superpowers/specs/2026-09-09-dkboai-ai-team-design.md`）

## Global Constraints

- 套件目錄是 `.dkbo/`（不是 `dkboai/`）。每個 `bin/dk-*` 以 `set -euo pipefail` 開頭再 source lib；`lib/*.sh` 不設 shell 選項（bats 也會 source）。不引入 node/python 依賴。
- `.dkbo/settings.env` 五個鍵、全部加引號、缺檔用預設值並警告一次：`DK_TEST_CMD=""`、`DK_REVIEW_KINDS="claude"`、`DK_REVIEW_MIN="1"`、`DK_REVIEW_TIMEOUT_MIN="20"`、`DK_TAB1_SLOTS="4"`。
- `.task.env` 新增欄：`DK_BASE`（任務建立時的基底 sha）、`DK_WAVE`（目前波號，空＝沒開波）、`DK_KIND_DOWN`（熔斷 kind，空白分隔）、`DK_TABS`。**DK_TABS 格式定為 `"<tab_no>=<tab_id> …"`（例 `2=wB:t2 3=wB:t3`）**，不用規格寫的 `<tab_id>:<root_pane>`：tab id 本身含 `:`，且 root pane 已記在 `.panes`。
- `.panes` 行格式：`<agent> <pane_id> <epoch> <group> <tab_no> <slot>`。`group` 是 `dev|review`。`worktree: false` 的角色（pm）記 `tab_no=0 slot=0`。舊的兩欄行視為 legacy：只關不重排、閘門跳過並警告一次。
- 命名：員工 agent `<short>-<role>[-<alias>]`；state 名 `<role>[-<alias>]`。**切片與報告都用 state 名**：`tasks/<t>/briefs/<state>.md`、`tasks/<t>/state/<state>.report.md`（規格寫 `<agent>` 之處一律指這個）。reviewer 別名固定 a、b、c → state 名 `reviewer-a` 等。
- process.md 事件詞彙（只追加，格式照抄）：`wave-open N base <sha7> members backend(M) qa(S)`、`review N spawned <agent>(<kind>) …`、`review N verdict …`、`review N skipped: <理由>`、`ruling: <決定> — <原因> — <若錯代價>`、`timeout <agent> (quota?) → kind <k> down`、`wave-close N tests ok (<cmd>) K agents closed`、`wave-close N tests skipped (no DK_TEST_CMD) K agents closed`、`tab N <tab_id> opened|closed`、`pane-close <agent>`。
- brief.md 波次表**一列一位成員**：`| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |`；同一波的列相鄰、波號從 1 連續；審查欄值只能是 `預設`、`skip: <理由>`、`kinds: <k1> [k2] [k3]`，同一波至少一列填了審查欄。成員欄以 `（範例）` 開頭的列一律忽略。
- `pane split --ratio` 語意在 `lib/layout.sh` 一處轉換（`DK_RATIO_MEANS`，預設 `new`＝比例是新 pane 的份）；`dk_layout_slot` 回傳的比例一律是「anchor 保留的份」。`pane resize --amount` 以「tab 面積的比例」送出，轉換集中在 `dk__layout_amount`。兩者由 Task 16 的真 herdr 腳本驗證並印 NOTE。
- herdr 回傳形狀（自 `herdr api schema --json` 確認）：`tab create` → `.result.tab.tab_id`、`.result.root_pane.pane_id`；`pane layout` → `.result.layout.area{x,y,width,height}`、`.result.layout.panes[]{pane_id,rect{x,y,width,height}}`（整數格數）；`pane resize` → `.result.resize.layout`（同形狀）；`pane read`/`agent read` → `.result.read.text`。
- 字數限制不變：state ≤20 行（警告）、`LEADER.md` ≤120 行、`PROTOCOL.md` ≤120 行、`dk-resume` ≤150 行。
- 現有 82 個 bats 測試在每個任務結束時都要通過（被本計畫刻意改掉預期者除外，該任務會同步改測試）。
- 每個任務結束 commit，作者 `dkbo <dk880842@gmail.com>`（repo 已設定），訊息尾加 `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`。

---

## File Structure

```
.dkbo/
├── settings.env                 # 新：五個設定鍵（init 改寫、rsync 更新時排除）
├── lib/
│   ├── common.sh                # 改：+dk_settings、dk_env_set、dk_legacy_task
│   ├── brief.sh                 # 新：brief.md 段落/表格解析、成員→角色/群組
│   ├── layout.sh                # 新：dk_layout_slot、dk_layout_even、比例/amount 轉換
│   └── prompt.sh                # 改：首段提示指向 briefs 切片與報告檔
├── bin/
│   ├── dk-brief-check           # 新：關卡①前的機械預檢（只讀）
│   ├── dk-wave-open             # 新：開波：base sha、DK_WAVE、切片
│   ├── dk-review-pack           # 新：產 waves/N.diff（含未 commit 的工作樹）
│   ├── dk-review                # 新：派 1–3 位 reviewer
│   ├── dk-task-new              # 改：git worktree add、DK_BASE、領導 workspace/pane
│   ├── dk-spawn                 # 改：切片提示、六欄 .panes、格位、新 tab、--split
│   ├── dk-wave-close            # 改：三檢查、--agent 單關、tests、均分、關空 tab
│   ├── dk-watch                 # 改：reviewer 逾時、(quota?)、熔斷
│   ├── dk-resume                # 改：本波、裁定、每 tab 一行、降級
│   └── dk-task-close            # 改：git worktree remove、關 DK_TABS、legacy
├── templates/
│   ├── brief.md                 # 改：審查欄、波次範例列
│   ├── brief-member.md          # 新：成員切片
│   ├── brief-reviewer.md        # 新：reviewer 切片（diff 路徑、report 格式）
│   ├── report-employee.md       # 新：員工報告
│   ├── state.md                 # 改：report: 行
│   └── task.env                 # 改：DK_BASE/DK_WAVE/DK_KIND_DOWN/DK_TABS
├── roles/*.md                   # 改：split: → group:；reviewer 職責
├── skills/init/SKILL.md         # 改：步驟 3 寫 settings.env
├── skills/add-role/SKILL.md     # 改：frontmatter 欄位 group
├── install.sh                   # 改：.gitignore 加 .worktrees/
├── LEADER.md  PROTOCOL.md  README.md   # 改
tests/
├── helpers.bash                 # 改：fixture_task 建真 worktree、新欄；+fixture_brief
├── stub/responses/{tab_create,pane_layout,agent_read}.json   # 新
├── unit/15_brief_lib.bats 16_brief_check.bats 17_layout.bats 18_wave_open.bats 19_review_pack.bats 20_review.bats   # 新
├── unit/{01,04,05,07,08,09,10,12,14}_*.bats   # 改
├── integration/herdr-real.sh    # 改：tab/ratio/resize/read 形狀
└── e2e/RUNBOOK.md               # 改：第 11 步
```

責任劃分：`lib/brief.sh` 是唯一解析 brief 表格的地方（brief-check、wave-open、review、wave-close 共用）；`lib/layout.sh` 是唯一知道格位幾何與 herdr 比例語意的地方；每個 `bin/dk-*` 仍只做一個生命週期動作。

---

### Task 1: `settings.env`、`dk_settings`、`dk_env_set`

**Files:**
- Create: `.dkbo/settings.env`
- Modify: `.dkbo/lib/common.sh`（檔尾追加）
- Modify: `.dkbo/templates/task.env`
- Modify: `tests/helpers.bash:28-46`（`fixture_task` 的 `.task.env`）
- Test: `tests/unit/01_common.bats`

**Interfaces:**
- Produces: `dk_settings`（source 後設定並 export 環境變數 `DK_TEST_CMD DK_REVIEW_KINDS DK_REVIEW_MIN DK_REVIEW_TIMEOUT_MIN DK_TAB1_SLOTS` 皆有值並 export）；`dk_env_set KEY VALUE`（改寫或追加綁定任務 `.task.env` 的一行 `KEY="VALUE"`）；`dk_legacy_task`（`.task.env` 無 `DK_BASE` 時回 0）。

- [ ] **Step 1: 寫失敗測試**

在 `tests/unit/01_common.bats` 檔尾追加：

```bash
@test "dk_settings: defaults, one warning when missing, file overrides" {
  rm "$DK_ROOT/settings.env"
  run dk_settings; [ "$status" -eq 0 ]; [[ "$output" == *"settings.env missing"* ]]
  dk_settings 2>/dev/null
  [ "$DK_TEST_CMD" = "" ]; [ "$DK_REVIEW_KINDS" = claude ]; [ "$DK_REVIEW_MIN" = 1 ]; [ "$DK_REVIEW_TIMEOUT_MIN" = 20 ]; [ "$DK_TAB1_SLOTS" = 4 ]
  run dk_settings; [ -z "$output" ]   # warned already in this process tree
  printf 'DK_TEST_CMD="npm test"\nDK_REVIEW_KINDS="claude codex"\nDK_TAB1_SLOTS="6"\n' > "$DK_ROOT/settings.env"
  dk_settings; [ "$DK_TEST_CMD" = "npm test" ]; [ "$DK_REVIEW_KINDS" = "claude codex" ]; [ "$DK_TAB1_SLOTS" = 6 ]; [ "$DK_REVIEW_MIN" = 1 ]
}
@test "shipped settings.env has the five keys, all quoted" {
  for k in DK_TEST_CMD DK_REVIEW_KINDS DK_REVIEW_MIN DK_REVIEW_TIMEOUT_MIN DK_TAB1_SLOTS; do grep -Eq "^$k=\"[^\"]*\"" "$DK_ROOT/settings.env"; done
  dk_settings; [ "$DK_REVIEW_KINDS" = claude ]
}
@test "dk_env_set rewrites or appends a .task.env key" {
  d=$(fixture_task login x)
  dk_env_set DK_WAVE 2; grep -q '^DK_WAVE="2"$' "$d/.task.env"; [ "$(grep -c '^DK_WAVE=' "$d/.task.env")" -eq 1 ]
  dk_env_set DK_NEWKEY "a b"; grep -q '^DK_NEWKEY="a b"$' "$d/.task.env"
  dk_env_set DK_WAVE ""; grep -q '^DK_WAVE=""$' "$d/.task.env"
  dk_task_env; [ -z "$DK_WAVE" ]; [ "$DK_NEWKEY" = "a b" ]
}
@test "dk_legacy_task detects a task folder without DK_BASE" {
  d=$(fixture_task login x); ! dk_legacy_task
  sed -i '/^DK_BASE=/d' "$d/.task.env"; dk_legacy_task
}
@test "task.env template carries the new keys" {
  for k in DK_BASE DK_WAVE DK_KIND_DOWN DK_TABS; do grep -q "^$k=" "$DK_ROOT/templates/task.env"; done
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `tests/run.sh tests/unit/01_common.bats`
Expected: 5 個新測試 FAIL（`dk_settings: command not found`、settings.env 不存在等）。

- [ ] **Step 3: 建 `.dkbo/settings.env`**

```bash
cat > .dkbo/settings.env <<'E'
# dkbo 設定。/dkboai-init 會改寫這裡的值；bash 可直接 source，所有值都要加引號。
DK_TEST_CMD=""                  # dk-wave-close 在 worktree 執行的測試指令；空字串表示不跑
DK_REVIEW_KINDS="claude"        # 預設 reviewer kind，依偏好排序，1 至 3 個，空白分隔
DK_REVIEW_MIN="1"               # 至少幾位 reviewer 意見回來才算審查完成
DK_REVIEW_TIMEOUT_MIN="20"      # reviewer 逾時分鐘（dk-watch 用）
DK_TAB1_SLOTS="4"               # tab 1 右側可放的員工格數（4 = 2×2，6 = 3×2）
E
```

- [ ] **Step 4: 在 `lib/common.sh` 檔尾追加三個函式**

```bash
dk_settings() { # load .dkbo/settings.env over the defaults; warn once per process tree when the file is missing
  DK_TEST_CMD=""; DK_REVIEW_KINDS="claude"; DK_REVIEW_MIN="1"; DK_REVIEW_TIMEOUT_MIN="20"; DK_TAB1_SLOTS="4"
  if [ -f "$DK_ROOT/settings.env" ]; then
    # shellcheck disable=SC1091
    . "$DK_ROOT/settings.env"
  elif [ -z "${DK_SETTINGS_WARNED:-}" ]; then
    echo "dk: $DK_ROOT/settings.env missing; using defaults (run /dkboai-init)" >&2; DK_SETTINGS_WARNED=1
  fi
  export DK_TEST_CMD DK_REVIEW_KINDS DK_REVIEW_MIN DK_REVIEW_TIMEOUT_MIN DK_TAB1_SLOTS DK_SETTINGS_WARNED
}
dk_env_set() { # KEY VALUE — rewrite KEY="VALUE" in the bound task's .task.env (append when the key is missing)
  local d f; d=$(dk_task_dir) || return 1; f="$d/.task.env"
  if grep -q "^$1=" "$f"; then
    awk -v k="$1" -v v="$2" 'index($0, k "=")==1 {print k "=\"" v "\""; next} {print}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  else echo "$1=\"$2\"" >> "$f"; fi
}
dk_legacy_task() { ! grep -q '^DK_BASE=' "$(dk_task_dir)/.task.env"; }   # task folder created before the wave-review scripts
```

- [ ] **Step 5: 改 `templates/task.env` 與 `fixture_task`**

`templates/task.env` 整檔改為：

```
DK_SHORT="{{SHORT}}"
DK_DISPLAY="{{DISPLAY}}"
DK_BRANCH="{{BRANCH}}"
DK_WORKTREE="{{WORKTREE}}"
DK_WORKSPACE="{{WORKSPACE}}"
DK_ROOT_PANE="{{ROOT_PANE}}"
DK_BASE="{{BASE}}"
DK_WATCH_PID=""
DK_WAVE=""
DK_KIND_DOWN=""
DK_TABS=""
```

`tests/helpers.bash` 的 `fixture_task` heredoc（`cat > "$d/.task.env" <<E … E`）在 `DK_WATCH_PID=""` 之前插入一行、之後追加三行：

```bash
DK_BASE="$(git -C "$PROJECT" rev-parse HEAD)"
DK_WATCH_PID=""
DK_WAVE=""
DK_KIND_DOWN=""
DK_TABS=""
```

（`DK_WORKSPACE="wC"`、`DK_ROOT_PANE="wC:p1"` 這兩行本任務先不動，Task 4 才改。）

`dk-task-new` 目前的 `vars=(…)` 尚未提供 `BASE`，渲染後會留下字面 `{{BASE}}`；Task 4 會補。本任務只需 05 測試維持通過（它不檢查 `DK_BASE`）。

- [ ] **Step 6: 跑測試確認通過**

Run: `tests/run.sh`
Expected: 全部通過（82 + 5）。

- [ ] **Step 7: Commit**

```bash
git add .dkbo/settings.env .dkbo/lib/common.sh .dkbo/templates/task.env tests/helpers.bash tests/unit/01_common.bats
git commit -m "feat(settings): settings.env, dk_settings, dk_env_set, new .task.env keys"
```

---

### Task 2: `lib/brief.sh`、範本、角色檔 `group:`

**Files:**
- Create: `.dkbo/lib/brief.sh`
- Create: `.dkbo/templates/brief-member.md`, `.dkbo/templates/report-employee.md`
- Modify: `.dkbo/templates/brief.md`, `.dkbo/templates/state.md`
- Modify: `.dkbo/roles/{pm,frontend,backend,qa,it,reviewer}.md`（`split:` → `group:`）
- Modify: `.dkbo/skills/add-role/SKILL.md:14`
- Modify: `tests/helpers.bash`（+`fixture_brief`）
- Modify: `tests/unit/04_docs.bats`
- Test: `tests/unit/15_brief_lib.bats`

**Interfaces:**
- Produces（`lib/brief.sh`，需先 source `common.sh` 與 `frontmatter.sh`）：
  - `dk_brief_section BRIEF "## 標題前綴"` → 該段正文行（到下一個 `## ` 為止）
  - `dk_brief_owners BRIEF` → 每行 `member|globs|readonly`（去表頭、去分隔列、去 `（範例）` 列、欄位去首尾空白）
  - `dk_brief_waves BRIEF` → 每行 `wave|type|member|what|tier|done|review`
  - `dk_brief_wave_members BRIEF N` → 每行 `member(tier)`
  - `dk_brief_wave_review BRIEF N` → 該波第一個非空的審查欄值
  - `dk_brief_acceptance BRIEF` → `- [ ] …` 行
  - `dk_member_role MEMBER` → `"<role> <alias>"`（alias 可空；找不到角色檔回 1）
  - `dk_member_group MEMBER` → `dev|review`
- Produces：`tests/helpers.bash` 的 `fixture_brief DIR`（寫一份合法 brief 到 `DIR/brief.md`，成員 backend / frontend-cart / qa，波 1 = backend(M)+qa(S) 審查 `預設`，波 2 = frontend-cart(S) 審查 `kinds: claude codex`）。

- [ ] **Step 1: 加 `fixture_brief` 到 `tests/helpers.bash` 檔尾**

```bash
fixture_brief() { # $1=task dir — a brief that passes dk-brief-check
  cat > "$1/brief.md" <<'B'
# 使用者登入
來源：test
分支：dk/login   worktree：/tmp/x

## 目標（≤3 行）
登入 API 與表單。

## 驗收標準
- [ ] POST /login 空密碼回 400
- [ ] renderLogin 產出 user/pass 欄位

## 檔案所有權
| 成員 | 可改 | 只讀 |
|---|---|---|
| （範例）backend | src/api/**, db/** | src/web/** |
| backend | src/api/** | src/web/** |
| frontend-cart | src/web/** | src/api/types.ts |
| qa | tests/** | — |

## 共用契約
無

## 波次表
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
| （範例）1 | 實作 | backend | API | M | 測試過 | 預設 |
| 1 | 實作 | backend | POST /login | M | 測試過 | 預設 |
| 1 | 實作 | qa | 驗 API | S | 全過 | |
| 2 | 實作 | frontend-cart | 表單 | S | 可用 | kinds: claude codex |
B
}
```

- [ ] **Step 2: 寫失敗測試 `tests/unit/15_brief_lib.bats`**

```bash
load ../helpers
setup() { setup_project; . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/frontmatter.sh"; . "$DK_ROOT/lib/brief.sh"; d=$(fixture_task login 使用者登入); fixture_brief "$d"; b="$d/brief.md"; }
teardown() { teardown_project; }

@test "owners: header, separator and （範例） rows dropped, fields trimmed" {
  run dk_brief_owners "$b"; [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [ "${lines[0]}" = "backend|src/api/**|src/web/**" ]; [ "${lines[1]}" = "frontend-cart|src/web/**|src/api/types.ts" ]; [ "${lines[2]}" = "qa|tests/**|—" ]
}
@test "waves: members per wave with tier, review column of the wave" {
  [ "$(dk_brief_wave_members "$b" 1 | tr '\n' ' ')" = "backend(M) qa(S) " ]
  [ "$(dk_brief_wave_members "$b" 2)" = "frontend-cart(S)" ]
  [ -z "$(dk_brief_wave_members "$b" 3)" ]
  [ "$(dk_brief_wave_review "$b" 1)" = "預設" ]; [ "$(dk_brief_wave_review "$b" 2)" = "kinds: claude codex" ]
  [ "$(dk_brief_waves "$b" | wc -l)" -eq 3 ]
}
@test "sections and acceptance" {
  [ "$(dk_brief_section "$b" "## 目標" | tr -d '\n')" = "登入 API 與表單。" ]
  [ "$(dk_brief_section "$b" "## 共用契約" | tr -d '\n')" = "無" ]
  [ "$(dk_brief_acceptance "$b" | wc -l)" -eq 2 ]
}
@test "member → role/alias/group" {
  [ "$(dk_member_role frontend-cart)" = "frontend cart" ]
  [ "$(dk_member_role qa)" = "qa " ]
  run dk_member_role designer; [ "$status" -eq 1 ]
  [ "$(dk_member_group qa)" = review ]; [ "$(dk_member_group reviewer-a)" = review ]; [ "$(dk_member_group backend)" = dev ]
}
@test "templates: brief has 審查 column and example rows; member/report templates carry tokens; state has report line" {
  grep -q '| 審查 |' "$DK_ROOT/templates/brief.md"; grep -q '^| （範例）1 |' "$DK_ROOT/templates/brief.md"
  for t in MEMBER WAVE WAVE_ROWS OWNER_ROWS CONTRACT ACCEPTANCE PEERS BRIEF GOAL; do grep -q "{{$t}}" "$DK_ROOT/templates/brief-member.md"; done
  grep -q '^## 測試' "$DK_ROOT/templates/report-employee.md"; grep -q '{{AGENT}}' "$DK_ROOT/templates/report-employee.md"
  grep -q '^report:' "$DK_ROOT/templates/state.md"
}
```

- [ ] **Step 3: 跑測試確認失敗**

Run: `tests/run.sh tests/unit/15_brief_lib.bats`
Expected: 全部 FAIL（`brief.sh` 不存在）。

- [ ] **Step 4: 寫 `.dkbo/lib/brief.sh`**

```bash
# shellcheck shell=bash
# Readers for brief.md. Needs common.sh and frontmatter.sh sourced first.
# Tables: rows start with '|'; the header row, '|---' separator rows and rows whose first cell starts with （範例） are dropped.
dk_brief_section() { # BRIEF "## heading prefix" → body lines until the next '## '
  awk -v h="$2" 'index($0, h)==1 {s=1; next} s && /^## / {exit} s {print}' "$1"
}
dk__brief_rows() { # BRIEF HEADING → data rows as trimmed "|"-joined cells (outer pipes removed)
  dk_brief_section "$1" "$2" | awk -F'|' '/^\|/ && !/^\|[- |]*$/ {
    out=""; for (i=2; i<NF; i++) { f=$i; gsub(/^ +| +$/, "", f); out = out (i>2 ? "|" : "") f } print out }' \
    | tail -n +2 | grep -v '^（範例）' || true
}
dk_brief_owners() { dk__brief_rows "$1" "## 檔案所有權"; }   # member|globs|readonly
dk_brief_waves()  { dk__brief_rows "$1" "## 波次表"; }       # wave|type|member|what|tier|done|review
dk_brief_wave_members() { dk_brief_waves "$1" | awk -F'|' -v n="$2" '$1==n {print $3 "(" $5 ")"}'; }
dk_brief_wave_review()  { dk_brief_waves "$1" | awk -F'|' -v n="$2" '$1==n && $7!="" {print $7; exit}'; }
dk_brief_acceptance()   { dk_brief_section "$1" "## 驗收標準" | grep -E '^- \[.\] ' || true; }
dk_member_role() { # MEMBER → "role alias" (alias may be empty). role = longest dash-prefix that has a role file.
  local role="$1" alias
  while [ ! -f "$DK_ROOT/roles/$role.md" ] && [[ "$role" == *-* ]]; do role="${role%-*}"; done
  [ -f "$DK_ROOT/roles/$role.md" ] || return 1
  alias="${1#"$role"}"; alias="${alias#-}"; echo "$role $alias"
}
dk_member_group() { local r; r=$(dk_member_role "$1") || return 1; dk_fm "$DK_ROOT/roles/${r%% *}.md" group; }
```

- [ ] **Step 5: 改範本**

`templates/brief.md` 的波次表段改為：

```
## 波次表
一列一位成員；同一波的列相鄰、波號從 1 連續。審查欄只填在該波第一列：`預設`（用 settings.env 的 kind）、`skip: <理由>`（純文件波）、`kinds: <k1> [k2] [k3]`。
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
| （範例）1 | 實作 | backend | POST /login | M | 測試過 | 預設 |
```

`templates/state.md` 整檔改為：

```
status: working
wave: 
current: 
touched:
todo:
report: state/<你的 state 名>.report.md
notes: 
```

新檔 `templates/brief-member.md`：

```
# {{DISPLAY}} — 給 {{MEMBER}} 的切片（波 {{WAVE}}）
由 dk-wave-open 產生，只讀。完整 brief 在 {{BRIEF}}。

## 目標
{{GOAL}}

## 你的波次
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
{{WAVE_ROWS}}

## 你的檔案所有權
| 成員 | 可改 | 只讀 |
|---|---|---|
{{OWNER_ROWS}}

## 共用契約（全文）
{{CONTRACT}}

## 驗收標準（全文）
{{ACCEPTANCE}}

## 同波成員
{{PEERS}}
```

新檔 `templates/report-employee.md`：

```
# {{AGENT}} 報告（波 {{WAVE}}）
## 做了什麼
## 測試
（必填：跑了什麼指令、結果摘要；沒有這段 dk-wave-close 不放行）
## 自我審查
## 疑慮
```

- [ ] **Step 6: 角色檔 `split:` → `group:`**

```bash
for r in pm frontend backend it; do sed -i 's/^split: .*/group: dev/' .dkbo/roles/$r.md; done
for r in qa reviewer; do sed -i 's/^split: .*/group: review/' .dkbo/roles/$r.md; done
grep -n '^group:' .dkbo/roles/*.md   # 六檔各一行
```

`skills/add-role/SKILL.md` 第 14 行的 `` `name kind tiers(S M L) worktree split mcp` `` 改為 `` `name kind tiers(S M L) worktree group mcp` ``，句尾 `` `split` 預設 right。`` 改為 `` `group` 填 `dev`（會改碼、要交報告）或 `review`（qa、reviewer 類，只驗不改）。``

- [ ] **Step 7: 更新 `tests/unit/04_docs.bats`**

第一個測試的 for 迴圈內、`worktree` 檢查之後加一行：

```bash
    [[ "$(dk_fm "$f" group)" =~ ^(dev|review)$ ]]
```

迴圈後加：

```bash
  [ "$(dk_fm "$DK_ROOT/roles/qa.md" group)" = review ]; [ "$(dk_fm "$DK_ROOT/roles/reviewer.md" group)" = review ]; [ "$(dk_fm "$DK_ROOT/roles/backend.md" group)" = dev ]
```

- [ ] **Step 8: 跑全部測試**

Run: `tests/run.sh`
Expected: 全部通過。`07_spawn` 仍通過（`dk-spawn` 讀不到 `split` 就用預設 `right`，測試只檢查 frontend 與 pm 的 right）。

- [ ] **Step 9: Commit**

```bash
git add .dkbo/lib/brief.sh .dkbo/templates .dkbo/roles .dkbo/skills/add-role/SKILL.md tests/helpers.bash tests/unit/04_docs.bats tests/unit/15_brief_lib.bats
git commit -m "feat(brief): brief.sh parsers, member/report templates, roles group: field"
```

---
### Task 3: `dk-brief-check`

**Files:**
- Create: `.dkbo/bin/dk-brief-check`
- Test: `tests/unit/16_brief_check.bats`

**Interfaces:**
- Consumes: `lib/brief.sh` 全部函式、`dk_settings`（`DK_TAB1_SLOTS`）。
- Produces: `dk-brief-check [<brief.md>]`。無參數時用綁定任務的 brief。輸出 `OK`、若干 `WARN <位置>: <原因>`（exit 0）或逐條 `FAIL <位置>: <原因>` 加結尾 `N FAIL`（exit 1）。不改任何檔。

- [ ] **Step 1: 寫失敗測試 `tests/unit/16_brief_check.bats`**

```bash
load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"; b="$d/brief.md"; }
teardown() { teardown_project; }

@test "a good brief prints OK, exit 0, touches nothing" {
  before=$(md5sum "$b"); run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]; [ "$(md5sum "$b")" = "$before" ]
  run dk-brief-check "$b"; [ "$status" -eq 0 ]   # explicit path works too
}
@test "overlapping 可改 globs fail (** prefix vs literal, ** vs **)" {
  sed -i 's#| frontend-cart | src/web/\*\* |#| frontend-cart | src/** |#' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 所有權 backend/frontend-cart"* ]]; [[ "$output" == *"重疊"* ]]; [[ "$output" == *"1 FAIL"* ]]
  fixture_brief "$d"; printf '| it | src/api/types.ts | — |\n' | sed -i '/^| qa | tests/r /dev/stdin' "$b"   # literal path inside backend's src/api/** tree
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 所有權 backend/it"* ]]
}
@test "unknown role, duplicate member, empty 可改" {
  sed -i 's#^| qa | tests/\*\* | — |#| designer | ui/** | — |#' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 所有權 designer: 找不到角色檔"* ]]; [[ "$output" == *"FAIL 波次表 1 qa: 成員不在所有權表"* ]]
  fixture_brief "$d"; printf '| backend | db/** | — |\n' | sed -i '/^| qa | tests/r /dev/stdin' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"成員重複"* ]]
  fixture_brief "$d"; sed -i 's#^| qa | tests/\*\* | — |#| qa |  | — |#' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"可改欄為空"* ]]
}
@test "wave table: tier, contiguity, review column, unknown kind, missing review" {
  sed -i 's#| S | 全過 | |#| X | 全過 | |#' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"難度只能 S/M/L"* ]]
  fixture_brief "$d"; sed -i 's#^| 2 | 實作 | frontend-cart#| 3 | 實作 | frontend-cart#' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"波號不連續"* ]]
  fixture_brief "$d"; sed -i 's#| 測試過 | 預設 |#| 測試過 | always |#' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"審查欄須為"* ]]
  fixture_brief "$d"; sed -i 's#kinds: claude codex#kinds: claude nope#' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"未知 kind nope"* ]]
  fixture_brief "$d"; sed -i 's#kinds: claude codex#kinds: claude codex agy claude#' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"kinds 須 1 至 3 個"* ]]
  fixture_brief "$d"; sed -i 's#| 測試過 | 預設 |#| 測試過 | |#' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 波次表 1: 審查欄未填"* ]]
}
@test "acceptance and contract must be present" {
  sed -i '/^- \[ \] /d' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 驗收標準"* ]]
  fixture_brief "$d"; sed -i 's/^無$/（誰定稿、放哪、變更流程）/' "$b"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 共用契約"* ]]
}
@test "more dev members than DK_TAB1_SLOTS in one wave is a WARN, exit 0" {
  for m in a b c d; do printf '| backend-%s | db/%s/** | — |\n' "$m" "$m" | sed -i '/^| qa | tests/r /dev/stdin' "$b"; done
  for m in a b c d; do printf '| 1 | 實作 | backend-%s | 表 | S | 過 | |\n' "$m" | sed -i '/^| 1 | 實作 | qa/r /dev/stdin' "$b"; done   # keep wave 1 rows contiguous
  run dk-brief-check; [ "$status" -eq 0 ]; [[ "$output" == *"WARN 波次表 1: dev 成員 5 位超過 tab 1 的 4 格"* ]]; [[ "$output" != OK ]]
  echo 'DK_TAB1_SLOTS="6"' >> "$DK_ROOT/settings.env"; run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]
}
@test "dies cleanly without a bound task or brief" {
  rm "$DK_ROOT/.sessions/wB:p1"; run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"no task bound"* ]]
  run dk-brief-check /nonexistent.md; [ "$status" -eq 1 ]; [[ "$output" == *"no brief"* ]]
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `tests/run.sh tests/unit/16_brief_check.bats`
Expected: 全部 FAIL（`dk-brief-check: command not found`）。

- [ ] **Step 3: 寫 `.dkbo/bin/dk-brief-check`**

```bash
#!/usr/bin/env bash
# dk-brief-check [<brief.md>] — mechanical pre-flight before gate ①. Read-only; exit 1 on any FAIL.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"; . "$DK_ROOT/lib/frontmatter.sh"; . "$DK_ROOT/lib/brief.sh"
dk_settings
brief="${1:-}"; [ -n "$brief" ] || brief="$(dk_task_dir)/brief.md"
[ -f "$brief" ] || dk_die "no brief at $brief"
fails=0; warns=0
fail() { echo "FAIL $1: $2"; fails=$((fails+1)); }
warn() { echo "WARN $1: $2"; warns=$((warns+1)); }

# ── 檔案所有權
owners=$(dk_brief_owners "$brief"); [ -n "$owners" ] || fail 所有權 "沒有任何成員列"
members=" "
while IFS='|' read -r m globs _ro; do
  [ -n "$m" ] || continue
  [[ "$m" =~ ^[a-z][a-z0-9_-]*$ ]] || fail "所有權 $m" "成員欄須為 <角色>[-<別名>]（ascii 小寫）"
  dk_member_role "$m" >/dev/null 2>&1 || fail "所有權 $m" "找不到角色檔（用 add-role skill 建立）"
  [[ "$members" == *" $m "* ]] && fail "所有權 $m" "成員重複"
  members="$members$m "
  [ -n "$globs" ] && [ "$globs" != "—" ] || fail "所有權 $m" "可改欄為空"
done <<< "$owners"
all_globs=$(printf '%s\n' "$owners" | awk -F'|' '{n=split($2,g,","); for(i=1;i<=n;i++){x=g[i]; gsub(/^ +| +$/,"",x); if(x!="" && x!="—") print $1 "\t" x}}')
overlap() { # G1 G2 → 0 when the two 可改 globs can match the same path (literal equality, or a dir/** tree containing the other)
  local a="$1" b="$2"; [ "$a" = "$b" ] && return 0
  [[ "$a" == *'/**' ]] && { [[ "$b" == "${a%/**}"/* ]] || [ "$b" = "${a%/**}" ]; } && return 0
  [[ "$b" == *'/**' ]] && { [[ "$a" == "${b%/**}"/* ]] || [ "$a" = "${b%/**}" ]; } && return 0
  return 1
}
while IFS=$'\t' read -r m1 g1; do
  [ -n "$m1" ] || continue
  while IFS=$'\t' read -r m2 g2; do
    [ -n "$m2" ] && [ "$m1" \< "$m2" ] || continue
    if overlap "$g1" "$g2"; then fail "所有權 $m1/$m2" "可改範圍重疊：$g1 與 $g2"; fi
  done <<< "$all_globs"
done <<< "$all_globs"

# ── 波次表
waves=$(dk_brief_waves "$brief"); [ -n "$waves" ] || fail 波次表 "沒有任何列"
prev=0
while IFS='|' read -r w _type m _what tier _done review; do
  [ -n "$w" ] || continue
  [[ "$w" =~ ^[0-9]+$ ]] || { fail "波次表 $w" "波號須為數字"; continue; }
  if [ "$w" -ne "$prev" ]; then [ "$w" -eq $((prev+1)) ] || fail "波次表 $w" "波號不連續（上一列是 $prev）"; prev="$w"; fi
  [[ "$members" == *" $m "* ]] || fail "波次表 $w $m" "成員不在所有權表"
  [[ "$tier" =~ ^[SML]$ ]] || fail "波次表 $w $m" "難度只能 S/M/L，得到 '$tier'"
  case "$review" in
    ""|預設|skip:\ ?*) ;;
    kinds:\ ?*)
      read -ra ks <<< "${review#kinds:}"
      [ "${#ks[@]}" -ge 1 ] && [ "${#ks[@]}" -le 3 ] || fail "波次表 $w" "kinds 須 1 至 3 個"
      for k in "${ks[@]}"; do [ -f "$DK_ROOT/kinds/$k.sh" ] || fail "波次表 $w" "未知 kind $k"; done;;
    *) fail "波次表 $w" "審查欄須為 預設、skip: <理由> 或 kinds: <k1> [k2] [k3]，得到 '$review'";;
  esac
done <<< "$waves"
for w in $(printf '%s\n' "$waves" | cut -d'|' -f1 | grep -E '^[0-9]+$' | sort -un); do
  [ -n "$(dk_brief_wave_review "$brief" "$w")" ] || fail "波次表 $w" "審查欄未填（預設 / skip: <理由> / kinds: …）"
  devs=0
  for m in $(printf '%s\n' "$waves" | awk -F'|' -v n="$w" '$1==n{print $3}'); do
    [ "$(dk_member_group "$m" 2>/dev/null || true)" = dev ] && devs=$((devs+1))
  done
  [ "$devs" -le "$DK_TAB1_SLOTS" ] || warn "波次表 $w" "dev 成員 $devs 位超過 tab 1 的 $DK_TAB1_SLOTS 格，建議拆波"
done

# ── 驗收與契約
[ -n "$(dk_brief_acceptance "$brief")" ] || fail 驗收標準 "至少一條 '- [ ] …'"
[ -n "$(dk_brief_section "$brief" "## 共用契約" | grep -v '^（' | grep -v '^[[:space:]]*$' || true)" ] || fail 共用契約 "段落為空（無契約請寫「無」）"

if [ "$fails" -gt 0 ]; then echo "$fails FAIL"; exit 1; fi
[ "$warns" -gt 0 ] || echo OK
```

`chmod +x .dkbo/bin/dk-brief-check`

- [ ] **Step 4: 跑測試確認通過**

Run: `tests/run.sh tests/unit/16_brief_check.bats`
Expected: 7 PASS。若「成員重複」測試因 `sed r /dev/stdin` 在你的 sed 版本不支援而失敗，改成 `awk -v row='| backend | db/** | — |' '{print} /^\| qa \| tests/{print row}' "$b" > "$b.tmp" && mv "$b.tmp" "$b"`（測試檔兩處）。

- [ ] **Step 5: 全套測試與 Commit**

Run: `tests/run.sh` → 全部通過。

```bash
git add .dkbo/bin/dk-brief-check tests/unit/16_brief_check.bats
git commit -m "feat(brief-check): mechanical pre-flight for the brief before gate 1"
```

---

### Task 4: `dk-task-new` 改用 `git worktree add`、`DK_BASE`；`dk-task-close` 對應清理

**Files:**
- Modify: `.dkbo/bin/dk-task-new:25-41`
- Modify: `.dkbo/bin/dk-task-close:12-17`
- Modify: `.dkbo/install.sh:27-30`
- Modify: `tests/helpers.bash`（`fixture_task` 建真 worktree、`DK_WORKSPACE`/`DK_ROOT_PANE` 改為領導的）
- Modify: `tests/unit/05_task_new.bats`, `tests/unit/12_task_close.bats`, `tests/unit/14_install.bats`, `tests/unit/07_spawn.bats:9`, `tests/unit/09_watch.bats:23`

**Interfaces:**
- Produces：`.task.env` 的 `DK_WORKSPACE`/`DK_ROOT_PANE` 從此是**領導所在** workspace 與 pane（`HERDR_WORKSPACE_ID`/`HERDR_PANE_ID`）；`DK_WORKTREE` 是 `${DK_WORKTREE_DIR:-<project>/.worktrees}/<short>`；`DK_BASE` 是建立時 `git rev-parse HEAD`。`dk-task-close` 用 `git worktree remove --force` 並關 `DK_TABS` 列的 tab；legacy 任務（無 `DK_BASE`）退回 `herdr worktree remove` 並警告。
- 後續 Task 6 的 `dk-spawn` 依賴 `DK_ROOT_PANE` 是領導 pane。

- [ ] **Step 1: 改測試**

`tests/helpers.bash` 的 `fixture_task`：把 `DK_WORKSPACE="wC"` 改 `DK_WORKSPACE="wB"`、`DK_ROOT_PANE="wC:p1"` 改 `DK_ROOT_PANE="wB:p1"`；把 `mkdir -p "$WORKTREE_PATH"` 那行改為：

```bash
  rm -rf "$WORKTREE_PATH"; mkdir -p "$(dirname "$WORKTREE_PATH")"
  git -C "$PROJECT" worktree add -q -b "dk/$1" "$WORKTREE_PATH" main >/dev/null 2>&1
```

`tests/unit/07_spawn.bats:9` 的 `--pane wC:p1` 改為 `--pane wB:p1`。

`tests/unit/05_task_new.bats` 第一個測試：把第 11 行改為

```bash
  grep -q '^DK_SHORT="login"$' "$d/.task.env"; grep -q "^DK_WORKTREE=\"$WORKTREE_PATH\"$" "$d/.task.env"
  grep -q '^DK_WORKSPACE="wB"$' "$d/.task.env"; grep -q '^DK_ROOT_PANE="wB:p1"$' "$d/.task.env"
  grep -q "^DK_BASE=\"$(git -C "$PROJECT" rev-parse HEAD)\"$" "$d/.task.env"; grep -q '^DK_WAVE=""$' "$d/.task.env"; grep -q '^DK_TABS=""$' "$d/.task.env"
```

把第 14 行（`worktree create` 的 grep）改為

```bash
  ! grep -q '^worktree create' "$HERDR_STUB_LOG"
  git -C "$PROJECT" worktree list --porcelain | grep -qx "worktree $WORKTREE_PATH"
  [ "$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref HEAD)" = dk/login ]
```

檔尾追加：

```bash
@test "task-new honours DK_WORKTREE_DIR and refuses an existing branch without creating the folder" {
  DK_WORKTREE_DIR="$PROJECT/wt" run dk-task-new login x; [ "$status" -eq 0 ]; grep -q "^DK_WORKTREE=\"$PROJECT/wt/login\"$" "$output/.task.env"
  git -C "$PROJECT" branch dk/pay
  run dk-task-new pay y; [ "$status" -eq 1 ]; [[ "$output" == *"worktree add failed"* ]]; [ ! -d "$DK_ROOT/tasks/$(date +%F)-pay" ]
}
@test "task-new --no-worktree still records DK_BASE" {
  run dk-task-new login x --no-worktree; [ "$status" -eq 0 ]; grep -q "^DK_WORKTREE=\"$PROJECT\"$" "$output/.task.env"; grep -Eq '^DK_BASE="[0-9a-f]{40}"$' "$output/.task.env"
}
```

`tests/unit/12_task_close.bats` 的 `setup()` 改為：

```bash
setup() {
  setup_project; d=$(fixture_task login 使用者登入)
  git -C "$PROJECT" -c user.name=t -c user.email=t@t commit -q --allow-empty -m base
  echo hi > "$WORKTREE_PATH/f.txt"; git -C "$WORKTREE_PATH" add f.txt; git -C "$WORKTREE_PATH" -c user.name=t -c user.email=t@t commit -q -m wave1
  printf '| 2026-09-10 | 使用者登入 | task | running | — |\n' >> "$DK_ROOT/tasks/INDEX.md"
  : > "$d/.panes"
}
```

「merges, removes worktree…」測試：把 `grep -q '^worktree remove --workspace wC --force$' "$HERDR_STUB_LOG"` 改為

```bash
  ! grep -q '^worktree remove' "$HERDR_STUB_LOG"; [ ! -d "$WORKTREE_PATH" ]
  ! git -C "$PROJECT" worktree list --porcelain | grep -qx "worktree $WORKTREE_PATH"
```

「abandon…」測試在 `! git … rev-parse --verify -q dk/login` 前加 `[ ! -d "$WORKTREE_PATH" ]`。檔尾追加：

```bash
@test "task-close closes overflow tabs listed in DK_TABS" {
  echo '# r' > "$d/report.md"; sed -i 's/^DK_TABS=.*/DK_TABS="2=wB:t2 3=wB:t3"/' "$d/.task.env"
  run dk-task-close; [ "$status" -eq 0 ]; grep -q '^tab close wB:t2$' "$HERDR_STUB_LOG"; grep -q '^tab close wB:t3$' "$HERDR_STUB_LOG"
}
@test "legacy task (no DK_BASE) falls back to herdr worktree remove with a warning" {
  echo '# r' > "$d/report.md"; sed -i '/^DK_BASE=/d; s/^DK_WORKSPACE=.*/DK_WORKSPACE="wC"/' "$d/.task.env"
  run dk-task-close; [ "$status" -eq 0 ]; [[ "$output" == *"legacy"* ]]; grep -q '^worktree remove --workspace wC --force$' "$HERDR_STUB_LOG"
}
```

`tests/unit/14_install.bats` 第 12 行末尾追加 `; grep -qx '.worktrees/' .gitignore`。

`tests/unit/09_watch.bats` 「dk-task-new launches dk-watch」測試第 23 行改為（fixture 已建的 worktree 與分支要先清掉，否則 `git worktree add` 會拒絕）：

```bash
  rm -rf "$DK_ROOT/tasks/"*-login "$DK_ROOT/.sessions/wB:p1"; unset DK_TASK_DIR
  git -C "$PROJECT" worktree remove --force "$WORKTREE_PATH"; git -C "$PROJECT" branch -D dk/login >/dev/null
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `tests/run.sh tests/unit/05_task_new.bats tests/unit/12_task_close.bats tests/unit/14_install.bats`
Expected: 05 的第 1、新 2 個、12 的 merge/abandon/新 2 個、14 的第 1 個 FAIL。

- [ ] **Step 3: 改 `dk-task-new`**

把第 25–35 行（`branch=… if [ "$worktree" = 1 ] … fi`）換成：

```bash
branch="dk/$short"; base_sha=$(git -C "$DK_PROJECT_ROOT" rev-parse HEAD)
ws="${HERDR_WORKSPACE_ID:-}"; root_pane="${HERDR_PANE_ID:-}"   # the leader's own workspace/pane; employees split from here (spec §6)
if [ "$worktree" = 1 ]; then
  wt_path="${DK_WORKTREE_DIR:-$DK_PROJECT_ROOT/.worktrees}/$short"
  [ ! -e "$wt_path" ] || dk_die "worktree path exists: $wt_path"
  mkdir -p "$(dirname "$wt_path")"
  git -C "$DK_PROJECT_ROOT" worktree add -q -b "$branch" "$wt_path" "$base_sha" >/dev/null 2>&1 || dk_die "git worktree add failed (branch $branch exists? run: git branch -D $branch)"
else
  wt_path="$DK_PROJECT_ROOT"
fi
```

第 38 行 `vars=(…)` 末尾加 `"BASE=$base_sha"`。

- [ ] **Step 4: 改 `dk-task-close` 的 `cleanup`**

把第 12–17 行換成：

```bash
legacy=0; if dk_legacy_task; then legacy=1; echo "dk-task-close: legacy task (no DK_BASE); removing the worktree via herdr" >&2; fi
cleanup() {
  [ -n "${DK_WATCH_PID:-}" ] && kill "$DK_WATCH_PID" 2>/dev/null || true
  if [ "$DK_WORKTREE" != "$DK_PROJECT_ROOT" ]; then
    if [ "$legacy" = 1 ]; then [ -n "${DK_WORKSPACE:-}" ] && herdr worktree remove --workspace "$DK_WORKSPACE" --force >/dev/null 2>&1 || true
    else git -C "$DK_PROJECT_ROOT" worktree remove --force "$DK_WORKTREE" >/dev/null 2>&1 || true; fi
  fi
  for t in ${DK_TABS:-}; do herdr tab close "${t#*=}" >/dev/null 2>&1 </dev/null || true; done
  rm -rf "$dir/.panes" "$dir/.blocked" "$DK_ROOT/.sessions/${HERDR_PANE_ID:?}"
  herdr agent rename "$HERDR_PANE_ID" --clear >/dev/null 2>&1 || true
}
```

- [ ] **Step 5: `install.sh` 加 `.worktrees/`**

第 27–30 行的 if 區塊之後加：

```bash
grep -qsx '.worktrees/' .gitignore || append_line .gitignore '.worktrees/'
```

- [ ] **Step 6: 跑全部測試**

Run: `tests/run.sh`
Expected: 全部通過。若 12 的 abandon 測試失敗於 `branch -D`（分支仍被 worktree 佔用），確認 `cleanup` 在 `git branch -D` 之前被呼叫（原碼順序 `cleanup; git … branch -D` 已正確）。

- [ ] **Step 7: Commit**

```bash
git add .dkbo/bin/dk-task-new .dkbo/bin/dk-task-close .dkbo/install.sh tests/helpers.bash tests/unit/05_task_new.bats tests/unit/07_spawn.bats tests/unit/09_watch.bats tests/unit/12_task_close.bats tests/unit/14_install.bats
git commit -m "feat(task): git worktree add/remove, DK_BASE, leader workspace as the pane root"
```

---

### Task 5: `lib/layout.sh` — `dk_layout_slot` 與比例轉換

**Files:**
- Create: `.dkbo/lib/layout.sh`
- Test: `tests/unit/17_layout.bats`

**Interfaces:**
- Consumes: `.panes` 六欄格式、`DK_TAB1_SLOTS`（`dk_settings`）、`DK_ROOT_PANE`（領導 pane）。
- Produces:
  - `dk_layout_slot GROUP [PANES_FILE]` → 一行 `"<tab_no> <slot> <anchor_pane> <right|down> <anchor_share>"`，或 `"NEWTAB <tab_no> 1"`（要開新 tab，新 pane 就是 tab 的 root pane）。`GROUP` 目前只是紀錄用（填位順序由 LEADER.md 規定先派 dev），保留參數以免日後改簽名。
  - `dk_layout_ratio_arg ANCHOR_SHARE` → 給 `herdr pane split --ratio` 的數字（依 `DK_RATIO_MEANS` 轉換，三位小數）。
  - 內部：`dk__layout_cap TAB_NO`、`dk__layout_pane_at TAB SLOT PANES_FILE`。
- 幾何規則（規格 §6.3；比例＝anchor 保留的份）：
  - tab 1：slot1 anchor=領導 pane right 0.5；slot2 anchor=slot1 down 0.5；slot3 anchor=slot1 right（cap 4→0.5，cap 6→0.333）；slot4 anchor=slot2 right（同上）；slot5 anchor=slot3 right 0.5；slot6 anchor=slot4 right 0.5。
  - tab n≥2（cap 6）：slot1=NEWTAB；slot2..6 同上表。
  - 下一格＝最後一個 tab 內最大 slot+1；超過 cap 就開新 tab。anchor 格已被關掉時，改掛在該 tab 最高 slot 的活 pane 下方（down 0.5）。

- [ ] **Step 1: 寫失敗測試 `tests/unit/17_layout.bats`**

```bash
load ../helpers
setup() { setup_project; . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/layout.sh"; p="$PROJECT/panes"; : > "$p"; export DK_ROOT_PANE=wB:p1 DK_TAB1_SLOTS=4; }
teardown() { teardown_project; }
expect() { [ "$(dk_layout_slot dev "$p")" = "$1" ] || { echo "got: $(dk_layout_slot dev "$p") want: $1"; return 1; }; }

@test "slot table: tab 1 has 4 cells, tabs 2+ have 6, anchors and shares per spec §6.3" {
  expect "1 1 wB:p1 right 0.5";      echo "a wB:p2 0 dev 1 1" >> "$p"
  expect "1 2 wB:p2 down 0.5";       echo "b wB:p3 0 dev 1 2" >> "$p"
  expect "1 3 wB:p2 right 0.5";      echo "c wB:p4 0 dev 1 3" >> "$p"
  expect "1 4 wB:p3 right 0.5";      echo "d wB:p5 0 dev 1 4" >> "$p"
  expect "NEWTAB 2 1";               echo "e wB:p10 0 dev 2 1" >> "$p"
  expect "2 2 wB:p10 down 0.5";      echo "f wB:p11 0 review 2 2" >> "$p"
  expect "2 3 wB:p10 right 0.333";   echo "g wB:p12 0 review 2 3" >> "$p"
  expect "2 4 wB:p11 right 0.333";   echo "h wB:p13 0 review 2 4" >> "$p"
  expect "2 5 wB:p12 right 0.5";     echo "i wB:p14 0 review 2 5" >> "$p"
  expect "2 6 wB:p13 right 0.5";     echo "j wB:p15 0 review 2 6" >> "$p"
  expect "NEWTAB 3 1"
}
@test "DK_TAB1_SLOTS=6 splits tab 1 columns in thirds; tab-0 rows (pm) are ignored" {
  export DK_TAB1_SLOTS=6
  printf 'pm wB:p9 0 dev 0 0\na wB:p2 0 dev 1 1\nb wB:p3 0 dev 1 2\n' > "$p"
  expect "1 3 wB:p2 right 0.333"; echo "c wB:p4 0 dev 1 3" >> "$p"
  expect "1 4 wB:p3 right 0.333"; echo "d wB:p5 0 dev 1 4" >> "$p"
  expect "1 5 wB:p4 right 0.5"
}
@test "a closed anchor cell falls back to hanging below the highest live cell" {
  printf 'a wB:p2 0 dev 1 1\nc wB:p4 0 dev 1 3\n' > "$p"   # slot 2 gone; next is slot 4 whose anchor is slot 2
  expect "1 4 wB:p4 down 0.5"
}
@test "legacy two-column .panes counts as no occupied cells" {
  printf 'a wB:p2\n' > "$p"; expect "1 1 wB:p1 right 0.5"
}
@test "dk_layout_ratio_arg converts the anchor share to herdr's --ratio per DK_RATIO_MEANS" {
  [ "$(DK_RATIO_MEANS=new dk_layout_ratio_arg 0.333)" = "0.667" ]
  [ "$(DK_RATIO_MEANS=new dk_layout_ratio_arg 0.5)" = "0.500" ]
  [ "$(DK_RATIO_MEANS=anchor dk_layout_ratio_arg 0.333)" = "0.333" ]
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `tests/run.sh tests/unit/17_layout.bats`
Expected: 全部 FAIL（`layout.sh` 不存在）。

- [ ] **Step 3: 寫 `.dkbo/lib/layout.sh`**

```bash
# shellcheck shell=bash
# Employee pane grid (spec §6). `.panes` rows: <agent> <pane_id> <epoch> <group> <tab_no> <slot>.
# Tab 1 is the leader's tab: the leader keeps a full-height left column; DK_TAB1_SLOTS cells fill the right half.
# Tabs 2+ hold 6 cells (3 columns × 2 rows). Shares below are what the ANCHOR keeps after the split.
# DK_RATIO_MEANS: what herdr's `pane split --ratio` denotes — "new" (the new pane's share; default) or "anchor".
# tests/integration/herdr-real.sh prints a NOTE telling which one real herdr uses.
DK_RATIO_MEANS="${DK_RATIO_MEANS:-new}"
dk_layout_ratio_arg() { # ANCHOR_SHARE → value for --ratio
  if [ "$DK_RATIO_MEANS" = anchor ]; then awk -v r="$1" 'BEGIN{printf "%.3f", r}'; else awk -v r="$1" 'BEGIN{printf "%.3f", 1-r}'; fi
}
dk__layout_cap() { if [ "$1" -eq 1 ]; then echo "${DK_TAB1_SLOTS:-4}"; else echo 6; fi; }
dk__layout_pane_at() { awk -v t="$1" -v s="$2" 'NF>=6 && $5==t && $6==s {print $2; exit}' "$3"; }
dk_layout_slot() { # GROUP [PANES_FILE] → "<tab_no> <slot> <anchor> <direction> <anchor_share>" | "NEWTAB <tab_no> 1"
  local panes="${2:-$(dk_task_dir)/.panes}" tab max cap slot anchor_slot dir share anchor
  tab=$(awk 'NF>=6 && $5>0 {if ($5>t) t=$5} END{print t+0}' "$panes"); [ "$tab" -ge 1 ] || tab=1
  max=$(awk -v t="$tab" 'NF>=6 && $5==t {if ($6>m) m=$6} END{print m+0}' "$panes")
  cap=$(dk__layout_cap "$tab"); slot=$((max+1))
  if [ "$slot" -gt "$cap" ]; then tab=$((tab+1)); slot=1; cap=$(dk__layout_cap "$tab"); fi
  if [ "$slot" -eq 1 ]; then
    if [ "$tab" -eq 1 ]; then echo "1 1 ${DK_ROOT_PANE:?} right 0.5"; else echo "NEWTAB $tab 1"; fi; return 0
  fi
  case "$slot" in
    2) anchor_slot=1; dir=down;  share=0.5;;
    3) anchor_slot=1; dir=right; share=0.5; [ "$cap" -eq 6 ] && share=0.333;;
    4) anchor_slot=2; dir=right; share=0.5; [ "$cap" -eq 6 ] && share=0.333;;
    5) anchor_slot=3; dir=right; share=0.5;;
    *) anchor_slot=4; dir=right; share=0.5;;
  esac
  anchor=$(dk__layout_pane_at "$tab" "$anchor_slot" "$panes")
  if [ -z "$anchor" ]; then   # anchor cell was closed mid-wave: hang below the highest live cell of this tab
    anchor=$(awk -v t="$tab" 'NF>=6 && $5==t {if ($6+0>=m) {m=$6+0; p=$2}} END{print p}' "$panes"); dir=down; share=0.5
  fi
  echo "$tab $slot $anchor $dir $share"
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `tests/run.sh tests/unit/17_layout.bats`
Expected: 5 PASS。

- [ ] **Step 5: Commit**

```bash
git add .dkbo/lib/layout.sh tests/unit/17_layout.bats
git commit -m "feat(layout): dk_layout_slot cell table and --ratio conversion"
```

---
### Task 6: `dk-spawn` — 切片提示、六欄 `.panes`、格位、新 tab、`--split`

**Files:**
- Modify: `.dkbo/bin/dk-spawn`
- Modify: `.dkbo/lib/prompt.sh`
- Create: `tests/stub/responses/tab_create.json`
- Modify: `tests/unit/07_spawn.bats`

**Interfaces:**
- Consumes: `dk_layout_slot`、`dk_layout_ratio_arg`（Task 5）、`dk_env_set`、`dk_settings`（Task 1）、角色檔 `group:`（Task 2）。
- Produces:
  - `dk-spawn <role> [alias] [--tier S|M|L] [--kind K] [--isolated] [--resume] [--split right|down]`。
  - `.panes` 行 `<agent> <pane_id> <epoch> <group> <tab_no> <slot>`；pm 類 `worktree: false` 記 `0 0`。
  - 需要新 tab 時 `herdr tab create --workspace $DK_WORKSPACE --cwd $DK_WORKTREE --label <short>-<n> --no-focus --env …`，`DK_TABS` 追加 `<n>=<tab_id>`，process 記 `tab <n> <tab_id> opened`。
  - `dk_first_prompt AGENT ROLE TASK_DIR STATE_FILE RESUME BRIEF_FILE REPORT_FILE`（新簽名，7 個參數）。首段提示指向 `briefs/<state>.md`（不存在則 `brief.md`）與 `state/<state>.report.md`。
  - `--split` 只覆寫方向，不改 tab 與 slot，也不改比例。

- [ ] **Step 1: 加 stub 回應 `tests/stub/responses/tab_create.json`**

```json
{"id":"cli:tab:create","result":{"type":"tab_created","tab":{"tab_id":"wB:t2","workspace_id":"wB","number":2,"label":"login-2","focused":false,"pane_count":1,"agent_status":"none"},"root_pane":{"pane_id":"wB:p10","tab_id":"wB:t2","workspace_id":"wB"}}}
```

- [ ] **Step 2: 改測試 `tests/unit/07_spawn.bats`**

第一個測試第 9 行改為：

```bash
  [[ "$split" == *"--pane wB:p1 --direction right --ratio 0.500 --cwd $WORKTREE_PATH --no-focus"* ]]
```

第 15 行改為（切片不存在 → 指向 brief.md，並提到報告檔）：

```bash
  [[ "$p" == *"$DK_ROOT/roles/frontend.md"* ]]; [[ "$p" == *"$d/brief.md"* ]]; [[ "$p" == *"$d/state/frontend-cart.report.md"* ]]
```

第 17 行改為：

```bash
  grep -Eq '^login-frontend-cart wC:p2 [0-9]{10} dev 1 1$' "$d/.panes"
```

「spawn records prompt failure…」第 44 行 `grep -q '^login-qa wC:p2$'` 改 `grep -q '^login-qa wC:p2 '`；「--resume closes and dedupes」第 63 行同樣改為 `grep -q '^login-qa wC:p2 '`。「worktree:false」測試第 39 行改為：

```bash
  grep -q -- "^pane split --pane wB:p1 --direction right --cwd $PROJECT --no-focus" "$HERDR_STUB_LOG"
  grep -Eq '^login-pm wC:p2 [0-9]+ dev 0 0$' "$d/.panes"
```

檔尾追加：

```bash
@test "first prompt points at the member slice when it exists" {
  mkdir -p "$d/briefs"; echo '# slice' > "$d/briefs/qa.md"
  dk-spawn qa >/dev/null
  p=$(grep '^agent prompt login-qa' "$HERDR_STUB_LOG"); [[ "$p" == *"$d/briefs/qa.md"* ]]; [[ "$p" != *"$d/brief.md"* ]]; [[ "$p" == *"report-employee.md"* ]]
}
@test "second employee hangs below the first; review group recorded" {
  echo "login-backend wC:p2 0 dev 1 1" > "$d/.panes"
  echo '{"result":{"pane":{"pane_id":"wC:p3"}}}' > "$HERDR_STUB_RESPONSES/pane_split.json"
  dk-spawn qa >/dev/null
  grep -q -- '--pane wC:p2 --direction down --ratio 0.500' "$HERDR_STUB_LOG"
  grep -Eq '^login-qa wC:p3 [0-9]+ review 1 2$' "$d/.panes"
}
@test "--split overrides only the direction" {
  echo "login-backend wC:p2 0 dev 1 1" > "$d/.panes"
  dk-spawn qa --split right >/dev/null
  grep -q -- '--pane wC:p2 --direction right --ratio 0.500' "$HERDR_STUB_LOG"; grep -Eq '^login-qa wC:p2 [0-9]+ review 1 2$' "$d/.panes"
}
@test "fifth employee opens tab 2 as its root pane and records DK_TABS" {
  printf 'a wC:p2 0 dev 1 1\nb wC:p3 0 dev 1 2\nc wC:p4 0 dev 1 3\nd wC:p5 0 dev 1 4\n' > "$d/.panes"
  run dk-spawn qa; [ "$status" -eq 0 ]; [ "$output" = "login-qa wB:p10" ]
  tc=$(grep '^tab create' "$HERDR_STUB_LOG")
  [[ "$tc" == "tab create --workspace wB --cwd $WORKTREE_PATH --label login-2 --no-focus --env DK_ROOT=$DK_ROOT --env DK_TASK_DIR=$d --env DK_ROLE=qa --env DK_AGENT=login-qa"* ]]
  ! grep -q '^pane split' "$HERDR_STUB_LOG"
  grep -q '^agent start login-qa --kind claude --pane wB:p10 ' "$HERDR_STUB_LOG"
  grep -Eq '^login-qa wB:p10 [0-9]+ review 2 1$' "$d/.panes"
  grep -q '^DK_TABS="2=wB:t2"$' "$d/.task.env"; grep -q 'tab 2 wB:t2 opened' "$d/process.md"
}
@test "tab create failure dies before starting an agent" {
  printf 'a wC:p2 0 dev 1 1\nb wC:p3 0 dev 1 2\nc wC:p4 0 dev 1 3\nd wC:p5 0 dev 1 4\n' > "$d/.panes"
  HERDR_STUB_FAIL="tab create" run dk-spawn qa; [ "$status" -eq 1 ]; ! grep -q '^agent start' "$HERDR_STUB_LOG"; [ "$(wc -l < "$d/.panes")" -eq 4 ]
}
```

- [ ] **Step 3: 跑測試確認失敗**

Run: `tests/run.sh tests/unit/07_spawn.bats`
Expected: 第 1、5、6 個與 5 個新測試 FAIL。

- [ ] **Step 4: 改 `lib/prompt.sh`**

```bash
# shellcheck shell=bash
dk_first_prompt() { # AGENT ROLE TASK_DIR STATE_FILE RESUME BRIEF_FILE REPORT_FILE
  local resume=""; [ "${5:-0}" = 1 ] && resume="你是重新啟動的員工：先讀 $4，從 state 檔續作，不要重做已完成的項目。"
  printf '%s' "你是 $1，角色 $2。先讀：$DK_ROOT/roles/$2.md、$DK_ROOT/PROTOCOL.md、$DK_ROOT/PROJECT.md、$6。你的 state 檔是 $4（≤20 行，每完成一個子步驟就覆寫）；報告檔是 $7（不限行數，照 $DK_ROOT/templates/report-employee.md，「## 測試」必填）。只能修改 brief 檔案所有權劃給你的檔案。禁止使用 subagent、禁止自行開 pane。所有訊息用 $DK_ROOT/bin/dk-msg。讀完後建立 state 檔並開始做分給你的項目；送 [DONE] 前 state 與報告都要寫好，然後 dk-msg 交接對象與 leader。$resume"
}
```

- [ ] **Step 5: 改 `dk-spawn`**

整檔改為：

```bash
#!/usr/bin/env bash
# dk-spawn <role> [alias] [--tier S|M|L] [--kind K] [--isolated] [--resume] [--split right|down]
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
. "$DK_ROOT/lib/frontmatter.sh"; . "$DK_ROOT/lib/kinds.sh"; . "$DK_ROOT/lib/prompt.sh"; . "$DK_ROOT/lib/layout.sh"
dk_require_herdr
dir=$(dk_task_dir); DK_TASK_DIR="$dir"; export DK_TASK_DIR; dk_task_env; dk_settings
role="${1:-}"; shift || true; [ -n "$role" ] || dk_die "usage: dk-spawn <role> [alias] [--tier T] [--kind K] [--isolated] [--resume] [--split right|down]"
alias=""; tier=M; kind=""; isolated=0; resume=0; notes=""; split_override=""
while [ $# -gt 0 ]; do case "$1" in
  --tier) tier="$2"; shift 2;; --kind) kind="$2"; notes="$notes override-kind"; shift 2;;
  --isolated) isolated=1; notes="$notes isolated"; shift;; --resume) resume=1; notes="$notes resume"; shift;;
  --split) split_override="$2"; [[ "$split_override" =~ ^(right|down)$ ]] || dk_die "--split must be right or down"; shift 2;;
  --*) dk_die "unknown flag $1";; *) alias="$1"; shift;; esac; done
rf="$DK_ROOT/roles/$role.md"; [ -f "$rf" ] || dk_die "no role file $rf (use add-role skill first)"
[ -n "$kind" ] || kind=$(dk_fm "$rf" kind)
spec=$(dk_fm_tier "$rf" "$tier"); [ -n "$spec" ] || dk_die "role $role has no tier $tier"
if [ "$kind" != "$(dk_fm "$rf" kind)" ]; then dk_kind_load "$kind"; spec=$(echo "$KIND_DEFAULT_TIERS" | tr ' ' '\n' | awk -F= -v t="$tier" '$1==t{print $2}'); fi
args=$(dk_kind_args "$kind" "$spec")
group=$(dk_fm "$rf" group); group="${group:-dev}"
agent=$(dk_agent_name "$role" "$alias"); sname=$(dk_state_name "$role" "$alias"); state="$dir/state/$sname.md"
[[ "$agent" =~ ^[a-z][a-z0-9_-]{0,31}$ ]] || dk_die "agent name '$agent' must match [a-z][a-z0-9_-]{0,31} (shorten the alias)"
brief_for="$dir/brief.md"; [ -f "$dir/briefs/$sname.md" ] && brief_for="$dir/briefs/$sname.md"
report="$dir/state/$sname.report.md"

if [ "$resume" = 1 ]; then
  old=$(awk -v a="$agent" '$1==a{print $2}' "$dir/.panes" | tail -1 || true)
  if [ -n "$old" ]; then
    herdr pane close "$old" >/dev/null 2>&1 </dev/null || true
    grep -v "^$agent " "$dir/.panes" > "$dir/.panes.tmp" || true
    mv "$dir/.panes.tmp" "$dir/.panes"
    dk_process "resume $agent: closed old pane $old"
  fi
fi

env_args=(--env "DK_ROOT=$DK_ROOT" --env "DK_TASK_DIR=$dir" --env "DK_ROLE=$role" --env "DK_AGENT=$agent"
  --env "DK_LEADER=$(dk_leader_name)" --env "DK_ISOLATED=$isolated" --env "HERDR_ENV=1")
tab_no=0; slot=0
if [ "$(dk_fm "$rf" worktree)" = false ]; then   # e.g. pm: beside the leader in the main tree, outside the employee grid
  pane=$(herdr pane split --pane "${HERDR_PANE_ID:?}" --direction "${split_override:-right}" --cwd "$DK_PROJECT_ROOT" --no-focus "${env_args[@]}" | dk_json '.result.pane.pane_id')
else
  read -r tab_no slot anchor direction share <<< "$(dk_layout_slot "$group")"
  if [ "$tab_no" = NEWTAB ]; then
    tab_no="$slot"; slot=1
    out=$(herdr tab create --workspace "$DK_WORKSPACE" --cwd "$DK_WORKTREE" --label "$DK_SHORT-$tab_no" --no-focus "${env_args[@]}") || dk_die "tab create failed"
    tab_id=$(echo "$out" | dk_json '.result.tab.tab_id // empty'); pane=$(echo "$out" | dk_json '.result.root_pane.pane_id // empty')
    [ -n "$tab_id" ] && [ -n "$pane" ] || dk_die "tab create returned no tab_id/root pane"
    dk_env_set DK_TABS "${DK_TABS:+$DK_TABS }$tab_no=$tab_id"; dk_process "tab $tab_no $tab_id opened"
  else
    pane=$(herdr pane split --pane "$anchor" --direction "${split_override:-$direction}" --ratio "$(dk_layout_ratio_arg "$share")" \
      --cwd "$DK_WORKTREE" --no-focus "${env_args[@]}" | dk_json '.result.pane.pane_id')
  fi
fi
[ -n "$pane" ] || dk_die "pane split returned no pane_id"
# shellcheck disable=SC2086
if ! herdr agent start "$agent" --kind "$kind" --pane "$pane" -- $args >/dev/null; then
  herdr pane close "$pane" >/dev/null 2>&1 </dev/null || true
  dk_die "agent start failed for $agent (pane $pane closed)"
fi
echo "$agent $pane $(date +%s) $group $tab_no $slot" >> "$dir/.panes"

dk_kind_load "$kind"; have=$(kind_mcp_list || true); missing=""
for m in $(dk_fm_list "$rf" mcp); do echo "$have" | grep -qx "$m" || missing="$missing $m"; done
if [ -n "$missing" ]; then echo "dk-spawn: mcp missing for $kind:$missing" >&2; dk_process "mcp-missing $agent:$missing"; fi

if herdr agent prompt "$agent" "$(dk_first_prompt "$agent" "$role" "$dir" "$state" "$resume" "$brief_for" "$report")" --wait --timeout 60000 >/dev/null; then
  dk_process "spawn $agent ($kind $tier)$notes"
  echo "$agent $pane"
else
  dk_process "spawn $agent ($kind $tier)$notes prompt-failed"
  echo "dk-spawn: first prompt to $agent failed or timed out; pane $pane is live — herdr agent read $agent, then re-prompt or dk-wave-close --force" >&2
  echo "$agent $pane"; exit 1
fi
```

- [ ] **Step 6: 跑全部測試**

Run: `tests/run.sh`
Expected: 全部通過。`20_review`（尚未存在）之外沒有其他腳本讀 `.panes` 第 2 欄以外的欄位，`08/09` 用 `read -r agent pane` 讀兩欄仍相容。

- [ ] **Step 7: Commit**

```bash
git add .dkbo/bin/dk-spawn .dkbo/lib/prompt.sh tests/stub/responses/tab_create.json tests/unit/07_spawn.bats
git commit -m "feat(spawn): grid placement, overflow tabs, six-column .panes, brief slice prompt"
```

---

### Task 7: `dk-wave-open`

**Files:**
- Create: `.dkbo/bin/dk-wave-open`
- Test: `tests/unit/18_wave_open.bats`

**Interfaces:**
- Consumes: `dk_brief_*`（Task 2）、`dk_env_set`（Task 1）、`templates/brief-member.md`。
- Produces: `dk-wave-open <N>`：要求 `.panes` 空、`DK_WAVE` 空、process 無 `wave-open N`；寫 `DK_WAVE=N`；`base=$(git -C "$DK_WORKTREE" rev-parse HEAD)`；每位成員渲染 `briefs/<member>.md`；process 記 `wave-open N base <sha7> members backend(M) qa(S)`。

- [ ] **Step 1: 寫失敗測試 `tests/unit/18_wave_open.bats`**

```bash
load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"; }
teardown() { teardown_project; }

@test "wave-open sets DK_WAVE, records base, renders one slice per member" {
  run dk-wave-open 1; [ "$status" -eq 0 ]
  grep -q '^DK_WAVE="1"$' "$d/.task.env"
  sha=$(git -C "$WORKTREE_PATH" rev-parse --short=7 HEAD)
  grep -q " wave-open 1 base $sha members backend(M) qa(S)$" "$d/process.md"
  [ -f "$d/briefs/backend.md" ]; [ -f "$d/briefs/qa.md" ]; [ ! -f "$d/briefs/frontend-cart.md" ]
  grep -q '^| 1 | 實作 | backend | POST /login | M | 測試過 | 預設 |$' "$d/briefs/backend.md"
  ! grep -q 'frontend-cart |' "$d/briefs/backend.md"
  grep -q '^| backend | src/api/\*\* | src/web/\*\* |$' "$d/briefs/backend.md"; ! grep -q '^| qa |' "$d/briefs/backend.md"
  grep -q 'POST /login 空密碼回 400' "$d/briefs/backend.md"; grep -q '^無$' "$d/briefs/backend.md"; grep -q 'backend(M) qa(S)' "$d/briefs/backend.md"
  grep -q "$d/brief.md" "$d/briefs/backend.md"; grep -q '登入 API 與表單' "$d/briefs/qa.md"
}
@test "refuses a second open, an open with live panes, and a wave without members" {
  dk-wave-open 1 >/dev/null
  run dk-wave-open 2; [ "$status" -eq 1 ]; [[ "$output" == *"wave 1 is open"* ]]
  sed -i 's/^DK_WAVE=.*/DK_WAVE=""/' "$d/.task.env"
  run dk-wave-open 1; [ "$status" -eq 1 ]; [[ "$output" == *"already opened"* ]]
  echo "login-qa wC:p3 0 review 1 1" > "$d/.panes"
  run dk-wave-open 2; [ "$status" -eq 1 ]; [[ "$output" == *"live panes"* ]]
  : > "$d/.panes"; run dk-wave-open 9; [ "$status" -eq 1 ]; [[ "$output" == *"no members"* ]]
  run dk-wave-open x; [ "$status" -eq 1 ]
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `tests/run.sh tests/unit/18_wave_open.bats` → FAIL（command not found）。

- [ ] **Step 3: 寫 `.dkbo/bin/dk-wave-open`**

```bash
#!/usr/bin/env bash
# dk-wave-open <N> — open wave N: record the base sha, set DK_WAVE, render one brief slice per member.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"; . "$DK_ROOT/lib/frontmatter.sh"; . "$DK_ROOT/lib/brief.sh"
dir=$(dk_task_dir); DK_TASK_DIR="$dir"; export DK_TASK_DIR; dk_task_env
n="${1:-}"; [[ "$n" =~ ^[0-9]+$ ]] || dk_die "usage: dk-wave-open <N>"
[ ! -s "$dir/.panes" ] || dk_die "live panes remain; run dk-wave-close first"
[ -z "${DK_WAVE:-}" ] || dk_die "wave $DK_WAVE is open; run dk-wave-close first"
! grep -q " wave-open $n " "$dir/process.md" || dk_die "wave $n was already opened (see process.md)"
brief="$dir/brief.md"
members=$(dk_brief_wave_members "$brief" "$n"); [ -n "$members" ] || dk_die "wave $n has no members in the 波次表 of $brief"
base=$(git -C "$DK_WORKTREE" rev-parse HEAD)
goal=$(dk_brief_section "$brief" "## 目標"); contract=$(dk_brief_section "$brief" "## 共用契約"); acc=$(dk_brief_section "$brief" "## 驗收標準")
peers=$(echo "$members" | tr '\n' ' ' | sed 's/ $//')
mkdir -p "$dir/briefs"
for m in $(echo "$members" | sed 's/(.*//'); do
  rows=$(dk_brief_waves "$brief" | awk -F'|' -v m="$m" -v n="$n" '$1==n && $3==m {printf "| %s | %s | %s | %s | %s | %s | %s |\n", $1,$2,$3,$4,$5,$6,$7}')
  own=$(dk_brief_owners "$brief" | awk -F'|' -v m="$m" '$1==m {printf "| %s | %s | %s |\n", $1,$2,$3}')
  dk_render "$DK_ROOT/templates/brief-member.md" "DISPLAY=$DK_DISPLAY" "MEMBER=$m" "WAVE=$n" "BRIEF=$brief" "GOAL=$goal" \
    "WAVE_ROWS=$rows" "OWNER_ROWS=$own" "CONTRACT=$contract" "ACCEPTANCE=$acc" "PEERS=$peers" > "$dir/briefs/$m.md"
done
dk_env_set DK_WAVE "$n"
dk_process "wave-open $n base ${base:0:7} members $peers"
echo "wave $n open (base ${base:0:7}); slices in $dir/briefs/"
```

`chmod +x .dkbo/bin/dk-wave-open`

- [ ] **Step 4: 跑測試確認通過** — `tests/run.sh tests/unit/18_wave_open.bats` → 2 PASS。

- [ ] **Step 5: Commit**

```bash
git add .dkbo/bin/dk-wave-open tests/unit/18_wave_open.bats
git commit -m "feat(wave-open): base sha, DK_WAVE, per-member brief slices"
```

---

### Task 8: `dk-review-pack`

**Files:**
- Create: `.dkbo/bin/dk-review-pack`
- Test: `tests/unit/19_review_pack.bats`

**Interfaces:**
- Consumes: process.md 的 `wave-open N base <sha>` 行、`DK_BASE`、`DK_WORKTREE`。
- Produces: `dk-review-pack [N]` 寫 `tasks/<t>/waves/N.diff` 並印路徑；`--task` 寫 `waves/task.diff`（base = `DK_BASE`）。差異包含 **worktree 未 commit 的變更與未追蹤檔**（用臨時 index，不動員工的真 index）：`## commits`（`git log --oneline base..HEAD`）、`## stat`、`## diff (-U10)`。沒有任何變更時仍產檔但 stderr 警告。

- [ ] **Step 1: 寫失敗測試 `tests/unit/19_review_pack.bats`**

```bash
load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"; dk-wave-open 1 >/dev/null
  wt() { git -C "$WORKTREE_PATH" -c user.name=t -c user.email=t@t "$@"; }
}
teardown() { teardown_project; }

@test "pack holds commits, stat and -U10 diff, including uncommitted and untracked work" {
  mkdir -p "$WORKTREE_PATH/src/api"; echo 'hello' > "$WORKTREE_PATH/src/api/login.ts"; wt add -A; wt commit -q -m 'api: login'
  echo 'dirty' >> "$WORKTREE_PATH/src/api/login.ts"; echo 'new' > "$WORKTREE_PATH/untracked.txt"
  run dk-review-pack; [ "$status" -eq 0 ]; [ "$output" = "$d/waves/1.diff" ]
  f="$d/waves/1.diff"; grep -q '^## commits' "$f"; grep -q 'api: login' "$f"; grep -q '^## stat' "$f"; grep -q '^## diff (-U10)' "$f"
  grep -q '^+hello' "$f"; grep -q '^+dirty' "$f"; grep -q '^+new' "$f"; grep -q 'untracked.txt' "$f"
  wt status --porcelain | grep -q '^?? untracked.txt'   # the employee's real index was not touched
  run dk-review-pack 1; [ "$status" -eq 0 ]   # explicit wave number
}
@test "no changes: file still written, warning on stderr" {
  run dk-review-pack; [ "$status" -eq 0 ]; [ -f "$d/waves/1.diff" ]; [[ "$output" == *"no changes"* ]]
}
@test "unknown wave or no open wave dies" {
  run dk-review-pack 7; [ "$status" -eq 1 ]; [[ "$output" == *"wave-open 7"* ]]
  sed -i 's/^DK_WAVE=.*/DK_WAVE=""/' "$d/.task.env"; run dk-review-pack; [ "$status" -eq 1 ]; [[ "$output" == *"usage"* ]]
}
@test "--task diffs the whole branch from DK_BASE; legacy task dies" {
  echo 'x' > "$WORKTREE_PATH/a.txt"; wt add -A; wt commit -q -m 'wave 0'
  run dk-review-pack --task; [ "$status" -eq 0 ]; [ "$output" = "$d/waves/task.diff" ]; grep -q 'wave 0' "$d/waves/task.diff"; grep -q '^+x' "$d/waves/task.diff"
  sed -i '/^DK_BASE=/d' "$d/.task.env"; run dk-review-pack --task; [ "$status" -eq 1 ]; [[ "$output" == *"DK_BASE"* ]]
}
```

- [ ] **Step 2: 跑測試確認失敗** — `tests/run.sh tests/unit/19_review_pack.bats` → FAIL。

- [ ] **Step 3: 寫 `.dkbo/bin/dk-review-pack`**

```bash
#!/usr/bin/env bash
# dk-review-pack [N] | dk-review-pack --task — write tasks/<t>/waves/N.diff (or task.diff) for reviewers; prints the path.
# Includes uncommitted and untracked work in the worktree via a throwaway index (the employees' real index is untouched).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
dir=$(dk_task_dir); DK_TASK_DIR="$dir"; export DK_TASK_DIR; dk_task_env
if [ "${1:-}" = --task ]; then
  [ -n "${DK_BASE:-}" ] || dk_die "no DK_BASE in .task.env (legacy task); pass a wave number instead"
  base="$DK_BASE"; out="$dir/waves/task.diff"; label="task $DK_SHORT, whole branch since ${base:0:7}"
else
  n="${1:-${DK_WAVE:-}}"; [[ "$n" =~ ^[0-9]+$ ]] || dk_die "usage: dk-review-pack [N] | --task  (no wave is open)"
  base=$(sed -n "s/^[^ ]* wave-open $n base \([0-9a-f]*\) .*/\1/p" "$dir/process.md" | tail -1)
  [ -n "$base" ] || dk_die "no 'wave-open $n base <sha>' line in process.md"
  out="$dir/waves/$n.diff"; label="wave $n since ${base:0:7}"
fi
mkdir -p "$dir/waves"
idx=$(mktemp); trap 'rm -f "$idx"' EXIT
g()  { git -C "$DK_WORKTREE" "$@"; }
gi() { GIT_INDEX_FILE="$idx" git -C "$DK_WORKTREE" "$@"; }
gi read-tree HEAD; gi add -A
changed=$(gi diff --cached --name-only "$base" | wc -l)
{
  echo "# $DK_DISPLAY — $label — $(dk_now)"; echo "# files changed: $changed (working tree included)"; echo
  echo "## commits"; g log --oneline "$base..HEAD"; echo
  echo "## stat"; gi diff --cached --stat "$base"; echo
  echo "## diff (-U10)"; gi diff --cached -U10 "$base"
} > "$out"
[ "$changed" -gt 0 ] || echo "dk-review-pack: no changes since ${base:0:7}; $out holds only the header" >&2
echo "$out"
```

`chmod +x .dkbo/bin/dk-review-pack`

- [ ] **Step 4: 跑測試確認通過** — 4 PASS。若 `gi read-tree HEAD` 在空 repo 失敗，fixture 的 worktree 至少有 init commit，不會發生；真實任務同理（dk-task-new 要求 repo 已有 commit）。

- [ ] **Step 5: Commit**

```bash
git add .dkbo/bin/dk-review-pack tests/unit/19_review_pack.bats
git commit -m "feat(review-pack): wave/task diff pack including uncommitted worktree changes"
```

---

### Task 9: `dk-review` 與 reviewer 切片範本

**Files:**
- Create: `.dkbo/bin/dk-review`, `.dkbo/templates/brief-reviewer.md`
- Test: `tests/unit/20_review.bats`

**Interfaces:**
- Consumes: `dk-spawn`（Task 6，會自動採用 `briefs/reviewer-<alias>.md`）、`dk_brief_wave_review`、`DK_REVIEW_KINDS`、`DK_KIND_DOWN`、`waves/N.diff`（Task 8）。
- Produces: `dk-review [--kinds "a b"] [--tier M|L] [N | --task]`。`--task` 讀 `waves/task.diff`（`dk-review-pack --task` 的產物），process 與輸出用 `task` 代替波號，kind 只看 `--kinds` 與 `DK_REVIEW_KINDS`。kind 來源：`--kinds` > 波次表 `kinds:` > `DK_REVIEW_KINDS`；扣 `DK_KIND_DOWN`；上限 3；別名依序 a b c；每位 `dk-spawn reviewer <alias> --isolated --kind <k> --tier <T>`。process 記 `review N spawned <agent>(<kind>) …`。派不出任何人 → exit 1 並提示 `dk-process "review N skipped: all kinds down"`。審查欄是 `skip:` 時拒絕並提示改用 dk-process。

- [ ] **Step 1: 寫失敗測試 `tests/unit/20_review.bats`**

```bash
load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"; }
teardown() { teardown_project; }
open_wave() { dk-wave-open "$1" >/dev/null; mkdir -p "$d/waves"; echo diff > "$d/waves/$1.diff"; }

@test "default kinds come from settings.env; aliases a/b; slice points at the diff" {
  open_wave 1; printf 'DK_REVIEW_KINDS="claude codex"\n' >> "$DK_ROOT/settings.env"
  run dk-review; [ "$status" -eq 0 ]; [[ "$output" == "review 1: login-reviewer-a(claude) login-reviewer-b(codex)" ]]
  grep -q '^agent start login-reviewer-a --kind claude ' "$HERDR_STUB_LOG"; grep -q '^agent start login-reviewer-b --kind codex ' "$HERDR_STUB_LOG"
  grep -q -- '--env DK_ISOLATED=1' "$HERDR_STUB_LOG"
  grep -q ' review 1 spawned login-reviewer-a(claude) login-reviewer-b(codex)$' "$d/process.md"
  grep -q "$d/waves/1.diff" "$d/briefs/reviewer-a.md"; grep -q '## Important' "$d/briefs/reviewer-a.md"; grep -q 'backend(M) qa(S)' "$d/briefs/reviewer-b.md"
  grep -q "$d/briefs/reviewer-a.md" "$HERDR_STUB_LOG"   # first prompt used the slice
}
@test "wave table kinds: beat settings; --kinds beats both; cap is 3" {
  open_wave 2
  run dk-review; [ "$status" -eq 0 ]; [[ "$output" == *"login-reviewer-a(claude) login-reviewer-b(codex)" ]]
  : > "$HERDR_STUB_LOG"; run dk-review --kinds "agy" 2; [ "$status" -eq 0 ]; [[ "$output" == "review 2: login-reviewer-a(agy)" ]]; grep -q -- '--kind agy' "$HERDR_STUB_LOG"
  : > "$HERDR_STUB_LOG"; run dk-review --kinds "claude codex agy claude" --tier L; [ "$status" -eq 0 ]
  [ "$(grep -c '^agent start login-reviewer-' "$HERDR_STUB_LOG")" -eq 3 ]; grep -q -- '--model opus --effort high' "$HERDR_STUB_LOG"
}
@test "downed kinds are skipped; all down exits 1 with the skip hint" {
  open_wave 1; sed -i 's/^DK_KIND_DOWN=.*/DK_KIND_DOWN="codex"/' "$d/.task.env"
  run dk-review --kinds "codex claude"; [ "$status" -eq 0 ]; [[ "$output" == *"review 1: login-reviewer-a(claude)" ]]; [[ "$output" == *"codex is down"* ]]
  : > "$HERDR_STUB_LOG"; run dk-review --kinds codex; [ "$status" -eq 1 ]; [[ "$output" == *'review 1 skipped: all kinds down'* ]]; ! grep -q '^agent start' "$HERDR_STUB_LOG"
}
@test "--task reviews the whole branch pack" {
  mkdir -p "$d/waves"; echo diff > "$d/waves/task.diff"
  run dk-review --task --tier L; [ "$status" -eq 0 ]; [ "$output" = "review task: login-reviewer-a(claude)" ]
  grep -q ' review task spawned login-reviewer-a(claude)$' "$d/process.md"; grep -q "$d/waves/task.diff" "$d/briefs/reviewer-a.md"; grep -q -- '--model opus --effort high' "$HERDR_STUB_LOG"
  rm "$d/waves/task.diff"; run dk-review --task; [ "$status" -eq 1 ]; [[ "$output" == *"dk-review-pack --task"* ]]
}
@test "refuses without a diff pack, with a skip: column, or a bad tier" {
  dk-wave-open 1 >/dev/null; run dk-review; [ "$status" -eq 1 ]; [[ "$output" == *"dk-review-pack"* ]]
  mkdir -p "$d/waves"; echo x > "$d/waves/1.diff"; sed -i 's#| 測試過 | 預設 |#| 測試過 | skip: 純文件 |#' "$d/brief.md"
  run dk-review; [ "$status" -eq 1 ]; [[ "$output" == *"skip: 純文件"* ]]; [[ "$output" == *"dk-process"* ]]
  run dk-review --tier S; [ "$status" -eq 1 ]
}
```

- [ ] **Step 2: 跑測試確認失敗** — `tests/run.sh tests/unit/20_review.bats` → FAIL。

- [ ] **Step 3: 寫 `templates/brief-reviewer.md`**

```
# {{DISPLAY}} — 波 {{WAVE}} 審查（reviewer 切片）
你是本波的 reviewer：只讀、不改碼、不跑會寫入的指令。意見只給領導（`dk-msg leader`），不直接對 dev 說。

## 要讀的
1. 差異包 {{DIFF}}（commit 清單、stat、-U10 diff；含未 commit 的工作樹）
2. 完整 brief {{BRIEF}}（驗收標準、共用契約、所有權）
3. 本波成員：{{MEMBERS}}

## 報告寫到 {{REPORT}}，格式固定
## 規格合規
（逐條驗收標準 ✅/❌，缺漏寫明）
## Important
（會出錯、違反 brief 或契約、越界改檔；每條附 file:line）
## Minor
（風格、可讀性；每條附 file:line）

## 完成
state 檔 `status: done`，然後 `dk-msg leader "[DONE] review 波 {{WAVE}}: Important N 條，見 report"`。
```

- [ ] **Step 4: 寫 `.dkbo/bin/dk-review`**

```bash
#!/usr/bin/env bash
# dk-review [--kinds "k1 k2"] [--tier M|L] [N | --task] — spawn 1–3 isolated reviewers for wave N's (or the whole task's) diff pack.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"; . "$DK_ROOT/lib/frontmatter.sh"; . "$DK_ROOT/lib/brief.sh"
dir=$(dk_task_dir); DK_TASK_DIR="$dir"; export DK_TASK_DIR; dk_task_env; dk_settings
kinds=""; tier=M; n=""; task=0
while [ $# -gt 0 ]; do case "$1" in
  --kinds) kinds="$2"; shift 2;; --tier) tier="$2"; shift 2;; --task) task=1; shift;; --*) dk_die "unknown flag $1";; *) n="$1"; shift;; esac; done
[[ "$tier" =~ ^[ML]$ ]] || dk_die "reviewer tier must be M or L"
if [ "$task" = 1 ]; then
  n=task; diff="$dir/waves/task.diff"; [ -f "$diff" ] || dk_die "no $diff; run dk-review-pack --task first"
else
  n="${n:-${DK_WAVE:-}}"; [[ "$n" =~ ^[0-9]+$ ]] || dk_die "usage: dk-review [--kinds \"a b\"] [--tier M|L] [N | --task]  (no wave is open)"
  diff="$dir/waves/$n.diff"; [ -f "$diff" ] || dk_die "no $diff; run dk-review-pack $n first"
fi
if [ -z "$kinds" ] && [ "$task" = 1 ]; then kinds="$DK_REVIEW_KINDS"; fi
if [ -z "$kinds" ]; then
  col=$(dk_brief_wave_review "$dir/brief.md" "$n")
  case "$col" in
    kinds:*) kinds="${col#kinds:}";;
    skip:*)  dk_die "wave $n review column is '$col'; record it with: dk-process \"review $n skipped: ${col#skip: }\"";;
    *)       kinds="$DK_REVIEW_KINDS";;
  esac
fi
use=""
for k in $kinds; do
  if [[ " ${DK_KIND_DOWN:-} " == *" $k "* ]]; then echo "dk-review: kind $k is down for this task; skipped" >&2; continue; fi
  use="$use $k"
done
use=$(printf '%s\n' $use | head -3 | tr '\n' ' ')
[ -n "${use// /}" ] || { echo "dk-review: no reviewer kind available; record: dk-process \"review $n skipped: all kinds down\"" >&2; exit 1; }
members=$(dk_brief_wave_members "$dir/brief.md" "$n" | tr '\n' ' ' | sed 's/ $//')
aliases=(a b c); i=0; spawned=""
mkdir -p "$dir/briefs"
for k in $use; do
  alias="${aliases[$i]}"; i=$((i+1)); sname="reviewer-$alias"
  dk_render "$DK_ROOT/templates/brief-reviewer.md" "DISPLAY=$DK_DISPLAY" "WAVE=$n" "DIFF=$diff" "BRIEF=$dir/brief.md" \
    "MEMBERS=$members" "REPORT=$dir/state/$sname.report.md" > "$dir/briefs/$sname.md"
  out=$("$DK_ROOT/bin/dk-spawn" reviewer "$alias" --isolated --kind "$k" --tier "$tier") || true   # prompt failure still leaves a live pane; dk-spawn logged it
  if [ -n "$out" ]; then spawned="$spawned ${out%% *}($k)"; else echo "dk-review: could not spawn reviewer $alias ($k)" >&2; fi
done
[ -n "$spawned" ] || { dk_process "review $n spawn-failed"; dk_die "no reviewer spawned; record: dk-process \"review $n skipped: all kinds down\""; }
dk_process "review $n spawned$spawned"
echo "review $n:$spawned"
```

`chmod +x .dkbo/bin/dk-review`

- [ ] **Step 5: 跑全部測試** — `tests/run.sh` → 全部通過。

- [ ] **Step 6: Commit**

```bash
git add .dkbo/bin/dk-review .dkbo/templates/brief-reviewer.md tests/unit/20_review.bats
git commit -m "feat(review): spawn 1-3 isolated reviewers with kind priority and circuit breaker"
```

---
### Task 10: `dk_layout_even` 與 `dk-wave-close --agent`（單關一格）

**Files:**
- Modify: `.dkbo/lib/layout.sh`（檔尾追加）
- Modify: `.dkbo/bin/dk-wave-close`（在 `--force` 解析之前插入 `--agent` 分支；完整改寫在 Task 11）
- Create: `tests/stub/responses/pane_layout.json`
- Modify: `tests/unit/17_layout.bats`, `tests/unit/08_wave_close.bats`

**Interfaces:**
- Produces:
  - `dk_layout_even TAB_NO [PANES_FILE]`：讀 `herdr pane layout --pane <探針>`（tab 1 用 `DK_ROOT_PANE`，其他 tab 用該 tab 第一個活 pane），對該 tab 仍在 `.panes` 的員工 pane 各算一個目標寬高：**目標寬 = 員工區寬 ÷（與我同列（y 區間重疊）的 pane 中不同 x 的個數）**，**目標高 = 員工區高 ÷（與我同欄（x 區間重疊）的 pane 中不同 y 的個數）**；差超過 1 格就 `herdr pane resize --pane <id> --direction <right|left|down|up> --amount <差÷面積寬或高，三位小數>`（右/下邊未貼齊區域邊界時往 right/down，否則往 left/up）。tab 1 的員工區從領導 pane 右邊開始。tab ≥2 已無員工 → `herdr tab close <tab_id>`、自 `DK_TABS` 移除、process 記 `tab N <tab_id> closed`。任何 herdr 失敗都吞掉（版面是可有可無的）。
  - `dk__layout_amount CELLS TOTAL` → 三位小數的比例（`--amount` 單位的唯一轉換點）。
  - `dk-wave-close --agent <agent>`：關那一位的 pane、刪 `.panes` 行、process 記 `pane-close <agent>`、對其 tab 跑 `dk_layout_even`。給 reviewer 逾時後用。

- [ ] **Step 1: 加 stub `tests/stub/responses/pane_layout.json`**

```json
{"id":"cli:pane:layout","result":{"type":"pane_layout","layout":{"workspace_id":"wB","tab_id":"wB:t1","zoomed":false,"focused_pane_id":"wB:p1","area":{"x":0,"y":0,"width":200,"height":50},"panes":[{"pane_id":"wB:p1","focused":true,"rect":{"x":0,"y":0,"width":100,"height":50}},{"pane_id":"wB:p2","focused":false,"rect":{"x":100,"y":0,"width":60,"height":25}},{"pane_id":"wB:p4","focused":false,"rect":{"x":160,"y":0,"width":40,"height":25}},{"pane_id":"wB:p3","focused":false,"rect":{"x":100,"y":25,"width":100,"height":25}}],"splits":[]}}}
```

（情境：tab 1 領導佔左半；右半原本 2×2，右下格已關，左下格 p3 橫跨整列；p2/p4 寬度 60/40 不均。）

- [ ] **Step 2: 寫失敗測試**

`tests/unit/17_layout.bats` 檔尾追加（`setup` 已 source layout.sh；這幾個測試自己綁任務）：

```bash
@test "dk_layout_even: equalises widths in a row, leaves spanning panes and heights alone" {
  d=$(fixture_task login x); export DK_TASK_DIR="$d"; dk_task_env
  printf 'a wB:p2 0 dev 1 1\nb wB:p3 0 dev 1 2\nc wB:p4 0 dev 1 3\n' > "$d/.panes"
  dk_layout_even 1
  grep -q '^pane layout --pane wB:p1$' "$HERDR_STUB_LOG"
  grep -q '^pane resize --pane wB:p2 --direction right --amount -0.050$' "$HERDR_STUB_LOG"
  grep -q '^pane resize --pane wB:p4 --direction left --amount 0.050$' "$HERDR_STUB_LOG"
  [ "$(grep -c '^pane resize' "$HERDR_STUB_LOG")" -eq 2 ]
}
@test "dk_layout_even: an emptied tab ≥2 is closed and dropped from DK_TABS" {
  d=$(fixture_task login x); export DK_TASK_DIR="$d"; sed -i 's/^DK_TABS=.*/DK_TABS="2=wB:t2 3=wB:t3"/' "$d/.task.env"; dk_task_env
  printf 'a wB:p2 0 dev 1 1\nz wB:p20 0 review 3 1\n' > "$d/.panes"
  dk_layout_even 2
  grep -q '^tab close wB:t2$' "$HERDR_STUB_LOG"; grep -q '^DK_TABS="3=wB:t3"$' "$d/.task.env"; grep -q 'tab 2 wB:t2 closed' "$d/process.md"
  ! grep -q '^pane layout' "$HERDR_STUB_LOG"
}
@test "dk_layout_even: herdr failure is swallowed; legacy rows are ignored" {
  d=$(fixture_task login x); export DK_TASK_DIR="$d"; dk_task_env
  printf 'a wB:p2\nb wB:p3 0 dev 1 2\n' > "$d/.panes"
  HERDR_STUB_FAIL="pane layout" dk_layout_even 1; ! grep -q '^pane resize' "$HERDR_STUB_LOG"
}
```

`tests/unit/08_wave_close.bats` 檔尾追加（此時 setup 仍是舊的兩欄 fixture；Task 11 會改寫整檔，這個測試要保留）：

```bash
@test "--agent closes one pane, drops its row, re-balances its tab" {
  printf 'login-frontend wC:p2 0 dev 1 1\nlogin-qa wC:p3 0 review 1 2\n' > "$d/.panes"
  run dk-wave-close --agent login-qa; [ "$status" -eq 0 ]; [ "$output" = "closed login-qa" ]
  grep -q '^pane close wC:p3$' "$HERDR_STUB_LOG"; ! grep -q '^login-qa ' "$d/.panes"; grep -q '^login-frontend ' "$d/.panes"
  grep -q 'pane-close login-qa' "$d/process.md"; grep -q '^pane layout --pane wB:p1$' "$HERDR_STUB_LOG"
  run dk-wave-close --agent nobody; [ "$status" -eq 1 ]
}
```

- [ ] **Step 3: 跑測試確認失敗** — `tests/run.sh tests/unit/17_layout.bats tests/unit/08_wave_close.bats` → 新測試 FAIL。

- [ ] **Step 4: 在 `lib/layout.sh` 檔尾追加**

```bash
dk__layout_amount() { awk -v d="$1" -v t="$2" 'BEGIN{printf "%.3f", d/t}'; }   # cells → fraction of the tab area (herdr --amount unit; see herdr-real.sh NOTE)
dk_layout_even() { # TAB_NO [PANES_FILE] — equalise the tab's live employee cells; close an emptied tab ≥2. Never fails.
  local tab="$1" panes="${2:-$(dk_task_dir)/.panes}" ids probe snap tid
  ids=$(awk -v t="$tab" 'NF>=6 && $5==t {print $2}' "$panes")
  if [ -z "$ids" ]; then
    if [ "$tab" -ge 2 ]; then
      tid=$(printf '%s\n' ${DK_TABS:-} | awk -F= -v t="$tab" '$1==t{print $2}')
      if [ -n "$tid" ]; then
        herdr tab close "$tid" >/dev/null 2>&1 </dev/null || true
        dk_env_set DK_TABS "$(printf '%s\n' ${DK_TABS:-} | grep -v "^$tab=" | tr '\n' ' ' | sed 's/ $//')"
        dk_process "tab $tab $tid closed"
      fi
    fi
    return 0
  fi
  if [ "$tab" -eq 1 ]; then probe="${DK_ROOT_PANE:?}"; else probe=$(echo "$ids" | head -1); fi
  snap=$(herdr pane layout --pane "$probe" 2>/dev/null </dev/null) || return 0
  printf '%s\n' "$snap" | jq -r '.result.layout as $l | ($l.area | "AREA \(.x) \(.y) \(.width) \(.height)"), ($l.panes[] | "PANE \(.pane_id) \(.rect.x) \(.rect.y) \(.rect.width) \(.rect.height)")' 2>/dev/null \
  | awk -v ids=" $(echo "$ids" | tr '\n' ' ')" -v leader="${DK_ROOT_PANE:-}" -v tab="$tab" '
    $1=="AREA" {ax=$2; ay=$3; aw=$4; ah=$5; next}
    $1=="PANE" && tab==1 && $2==leader {rx=$3+$5; next}                    # employee region starts right of the leader column
    $1=="PANE" && index(ids, " " $2 " ") {n++; id[n]=$2; x[n]=$3; y[n]=$4; w[n]=$5; h[n]=$6}
    END {
      if (n==0 || aw==0 || ah==0) exit
      if (tab==1 && rx>0) rw=ax+aw-rx; else {rx=ax; rw=aw}
      ry=ay; rh=ah
      for (i=1;i<=n;i++) {
        split("", cx); split("", cy); nc=0; nr=0
        for (j=1;j<=n;j++) {
          if (y[j] < y[i]+h[i] && y[i] < y[j]+h[j] && !(x[j] in cx)) {cx[x[j]]=1; nc++}   # same row: distinct columns
          if (x[j] < x[i]+w[i] && x[i] < x[j]+w[j] && !(y[j] in cy)) {cy[y[j]]=1; nr++}   # same column: distinct rows
        }
        dw=int(rw/nc)-w[i]; dh=int(rh/nr)-h[i]
        if (dw>1 || dw<-1) printf "%s %s %d %d\n", id[i], (x[i]+w[i] < rx+rw ? "right" : "left"), dw, aw
        if (dh>1 || dh<-1) printf "%s %s %d %d\n", id[i], (y[i]+h[i] < ry+rh ? "down" : "up"), dh, ah
      }
    }' | while read -r pid direction delta total; do
      herdr pane resize --pane "$pid" --direction "$direction" --amount "$(dk__layout_amount "$delta" "$total")" >/dev/null 2>&1 </dev/null || true
    done
  return 0
}
```

- [ ] **Step 5: `dk-wave-close` 插入 `--agent` 分支**

在 `dk_task_env` 那行之後（第 6 行後）加 `. "$DK_ROOT/lib/layout.sh"` 到 source 列，並插入：

```bash
if [ "${1:-}" = --agent ]; then   # close one employee (e.g. a timed-out reviewer) and re-balance its tab
  a="${2:-}"; [ -n "$a" ] || dk_die "usage: dk-wave-close --agent <agent>"
  line=$(awk -v a="$a" '$1==a' "$dir/.panes" | tail -1); [ -n "$line" ] || dk_die "no live pane for $a"
  read -r _ pane _ _ tab _ <<< "$line"
  herdr pane close "$pane" >/dev/null 2>&1 </dev/null || true
  grep -v "^$a " "$dir/.panes" > "$dir/.panes.tmp" || true; mv "$dir/.panes.tmp" "$dir/.panes"
  dk_process "pane-close $a"
  [ -n "${tab:-}" ] && dk_layout_even "$tab"
  echo "closed $a"; exit 0
fi
```

- [ ] **Step 6: 跑全部測試** — `tests/run.sh` → 全部通過。

- [ ] **Step 7: Commit**

```bash
git add .dkbo/lib/layout.sh .dkbo/bin/dk-wave-close tests/stub/responses/pane_layout.json tests/unit/17_layout.bats tests/unit/08_wave_close.bats
git commit -m "feat(layout): dk_layout_even re-balance, dk-wave-close --agent single close"
```

---

### Task 11: `dk-wave-close` 三檢查、測試閘、均分、關空 tab

**Files:**
- Modify: `.dkbo/bin/dk-wave-close`（整檔改寫，保留 Task 10 的 `--agent` 分支）
- Modify: `tests/unit/08_wave_close.bats`（整檔改寫）

**Interfaces:**
- Consumes: `dk_settings`（`DK_TEST_CMD`）、`dk_env_set`、`dk_legacy_task`、`dk_layout_even`、`.panes` 六欄、`state/<state>.report.md`。
- Produces: `dk-wave-close [--force]`。順序：(0) 全員 `status: done`；(a) process 有 `review N verdict` 或 `review N skipped:`；(b) 每位 group=dev 的 report 存在且 `## 測試` 下有非空、非 `（` 開頭的內容行；任一失敗且無 `--force` → 印全部問題、exit 1、不關 pane。(c) `DK_TEST_CMD` 非空 → `(cd $DK_WORKTREE && bash -c "$DK_TEST_CMD")` 輸出到 `waves/N.test.log`；失敗印最後 20 行、process 記 `wave-close N tests failed (<cmd>)`、exit 1（`--force` 則續行並記 `failed (…, forced)`）。通過後關 pane、越界/超長警告照舊、清 `DK_WAVE`、process 記 `wave-close N tests ok|skipped … K agents closed`、對每個涉及的 tab 跑 `dk_layout_even`。legacy（無 `DK_WAVE` 欄或兩欄 `.panes`）→ 只做 (0) 與關 pane，記 `wave-close: K agents closed`，警告一次。

- [ ] **Step 1: 改寫 `tests/unit/08_wave_close.bats`**

```bash
load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"
  printf 'login-backend wC:p2 0 dev 1 1\nlogin-qa wC:p3 0 review 1 2\n' > "$d/.panes"
  printf 'status: done\nwave: 1\ntouched:\n  - src/api/login.ts\nreport: state/backend.report.md\n' > "$d/state/backend.md"
  printf 'status: done\nwave: 1\ntouched:\n  - tests/login.test.ts\n' > "$d/state/qa.md"
  printf '# backend 報告\n## 做了什麼\nlogin\n## 測試\nnpm test → 3 passed\n## 自我審查\n## 疑慮\n' > "$d/state/backend.report.md"
  sed -i 's/^DK_WAVE=.*/DK_WAVE="1"/' "$d/.task.env"
  echo "$(date +%Y-%m-%dT%H:%M) review 1 verdict a: ok" >> "$d/process.md"
}
teardown() { teardown_project; }

@test "all gates pass: panes closed, DK_WAVE cleared, tests skipped without DK_TEST_CMD" {
  run dk-wave-close; [ "$status" -eq 0 ]; [ "$output" = "closed 2" ]
  grep -q '^pane close wC:p2$' "$HERDR_STUB_LOG"; grep -q '^pane close wC:p3$' "$HERDR_STUB_LOG"
  [ ! -s "$d/.panes" ]; grep -q '^DK_WAVE=""$' "$d/.task.env"
  grep -q ' wave-close 1 tests skipped (no DK_TEST_CMD) 2 agents closed$' "$d/process.md"
}
@test "gate 0: a state not done refuses unless --force" {
  sed -i 's/^status: done/status: working/' "$d/state/qa.md"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"not done: login-qa"* ]]; ! grep -q '^pane close' "$HERDR_STUB_LOG"
  run dk-wave-close --force; [ "$status" -eq 0 ]
}
@test "gate a: needs a review verdict or a recorded skip" {
  sed -i '/review 1 verdict/d' "$d/process.md"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"review 1 verdict"* ]]; ! grep -q '^pane close' "$HERDR_STUB_LOG"
  echo "2026-09-10T10:00 review 1 skipped: 純文件波" >> "$d/process.md"; run dk-wave-close; [ "$status" -eq 0 ]
}
@test "gate b: every dev needs a report with content under ## 測試; review-group members do not" {
  rm "$d/state/backend.report.md"; run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"no report"*"backend.report.md"* ]]
  printf '# r\n## 測試\n（必填）\n\n## 自我審查\nok\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"lacks content under '## 測試'"* ]]
  printf '# r\n## 測試\nbats 12 ok\n' > "$d/state/backend.report.md"; run dk-wave-close; [ "$status" -eq 0 ]
}
@test "gate c: DK_TEST_CMD runs in the worktree; failure keeps panes and shows the tail" {
  echo 'DK_TEST_CMD="cat marker.txt"' >> "$DK_ROOT/settings.env"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"tests failed (cat marker.txt)"* ]]; [[ "$output" == *"No such file"* ]]
  ! grep -q '^pane close' "$HERDR_STUB_LOG"; grep -q ' wave-close 1 tests failed (cat marker.txt)$' "$d/process.md"; [ -f "$d/waves/1.test.log" ]
  echo ok > "$WORKTREE_PATH/marker.txt"; run dk-wave-close; [ "$status" -eq 0 ]; grep -q ' wave-close 1 tests ok (cat marker.txt) 2 agents closed$' "$d/process.md"
}
@test "gate c: --force closes despite failing tests and says so" {
  echo 'DK_TEST_CMD="echo boom; exit 1"' >> "$DK_ROOT/settings.env"
  run dk-wave-close --force; [ "$status" -eq 0 ]; [[ "$output" == *"boom"* ]]; grep -q 'tests failed (echo boom; exit 1, forced) 2 agents closed' "$d/process.md"
}
@test "no open wave refuses" {
  sed -i 's/^DK_WAVE=.*/DK_WAVE=""/' "$d/.task.env"; run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"no wave open"* ]]
}
@test "legacy: two-column .panes or no DK_WAVE key → old behaviour with a warning" {
  printf 'login-backend wC:p2\nlogin-qa wC:p3\n' > "$d/.panes"; rm "$d/state/backend.report.md"; sed -i '/review 1 verdict/d' "$d/process.md"
  run dk-wave-close; [ "$status" -eq 0 ]; [[ "$output" == *"legacy"* ]]; grep -q 'wave-close: 2 agents closed' "$d/process.md"
}
@test "ownership violations and long state are still reported" {
  printf 'status: done\ntouched:\n  - src/web/x.ts\n' > "$d/state/backend.md"
  for i in $(seq 1 25); do echo "notes: line $i" >> "$d/state/qa.md"; done
  run dk-wave-close; [ "$status" -eq 0 ]; grep -q 'violation login-backend: src/web/x.ts' "$d/process.md"; [[ "$output" == *"state too long"* ]]
}
@test "an emptied overflow tab is closed after the wave" {
  echo 'login-reviewer-a wB:p10 0 review 2 1' >> "$d/.panes"; printf 'status: done\n' > "$d/state/reviewer-a.md"
  sed -i 's/^DK_TABS=.*/DK_TABS="2=wB:t2"/' "$d/.task.env"
  run dk-wave-close; [ "$status" -eq 0 ]; grep -q '^tab close wB:t2$' "$HERDR_STUB_LOG"; grep -q '^DK_TABS=""$' "$d/.task.env"
}
@test "--agent closes one pane, drops its row, re-balances its tab" {
  run dk-wave-close --agent login-qa; [ "$status" -eq 0 ]; [ "$output" = "closed login-qa" ]
  grep -q '^pane close wC:p3$' "$HERDR_STUB_LOG"; ! grep -q '^login-qa ' "$d/.panes"; grep -q '^login-backend ' "$d/.panes"
  grep -q 'pane-close login-qa' "$d/process.md"; grep -q '^pane layout --pane wB:p1$' "$HERDR_STUB_LOG"
  run dk-wave-close --agent nobody; [ "$status" -eq 1 ]
}
@test "ownership matches member names exactly" {
  . "$DK_ROOT/lib/ownership.sh"
  printf '| qa-a | docs/** | — |\n' | sed -i '/^| qa | tests/r /dev/stdin' "$d/brief.md"
  dk_owned "$d/brief.md" qa tests/x.ts; ! dk_owned "$d/brief.md" qa docs/x.md; dk_owned "$d/brief.md" qa-a docs/x.md
}
```

- [ ] **Step 2: 跑測試確認失敗** — `tests/run.sh tests/unit/08_wave_close.bats` → 大部分 FAIL。

- [ ] **Step 3: 改寫 `.dkbo/bin/dk-wave-close`**

```bash
#!/usr/bin/env bash
# dk-wave-close [--force] | dk-wave-close --agent <agent>
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"; . "$DK_ROOT/lib/ownership.sh"; . "$DK_ROOT/lib/layout.sh"
dk_require_herdr
dir=$(dk_task_dir); DK_TASK_DIR="$dir"; export DK_TASK_DIR; dk_task_env; dk_settings
if [ "${1:-}" = --agent ]; then   # close one employee (e.g. a timed-out reviewer) and re-balance its tab
  a="${2:-}"; [ -n "$a" ] || dk_die "usage: dk-wave-close --agent <agent>"
  line=$(awk -v a="$a" '$1==a' "$dir/.panes" | tail -1); [ -n "$line" ] || dk_die "no live pane for $a"
  read -r _ pane _ _ tab _ <<< "$line"
  herdr pane close "$pane" >/dev/null 2>&1 </dev/null || true
  grep -v "^$a " "$dir/.panes" > "$dir/.panes.tmp" || true; mv "$dir/.panes.tmp" "$dir/.panes"
  dk_process "pane-close $a"
  [ -n "${tab:-}" ] && dk_layout_even "$tab"
  echo "closed $a"; exit 0
fi
force=0; [ "${1:-}" = --force ] && force=1
[ -s "$dir/.panes" ] || dk_die "no live panes recorded in $dir/.panes"
legacy=0
if ! grep -q '^DK_WAVE=' "$dir/.task.env" || awk 'NF<6{bad=1} END{exit !bad}' "$dir/.panes"; then
  legacy=1; echo "dk-wave-close: legacy task or two-column .panes; review/report/test gates skipped" >&2
fi
n="${DK_WAVE:-}"; problems=""
while read -r agent _pane _; do   # gate 0: everyone done
  sname="${agent#"$DK_SHORT"-}"; sf="$dir/state/$sname.md"
  if [ ! -f "$sf" ] || ! grep -q '^status: done' "$sf"; then problems="$problems\n  not done: $agent"; fi
done < "$dir/.panes"
if [ "$legacy" = 0 ]; then
  if [ -z "$n" ]; then problems="$problems\n  no wave open (DK_WAVE empty); dk-wave-open N first"
  elif ! grep -Eq "^[^ ]+ review $n (verdict|skipped:)" "$dir/process.md"; then   # gate a
    problems="$problems\n  no 'review $n verdict …' or 'review $n skipped: <理由>' line in process.md (dk-review, then dk-process)"
  fi
  while read -r agent _pane _epoch group _; do   # gate b: dev reports carry a filled ## 測試
    [ "$group" = dev ] || continue
    sname="${agent#"$DK_SHORT"-}"; rf="$dir/state/$sname.report.md"
    if [ ! -f "$rf" ]; then problems="$problems\n  no report $rf (dk-msg $agent \"[TASK] 補 report 測試段\")"
    elif ! awk '/^## 測試/{t=1; next} t && /^## /{exit} t && /^[^[:space:]（]/{ok=1} END{exit !ok}' "$rf"; then
      problems="$problems\n  report $rf lacks content under '## 測試'"
    fi
  done < "$dir/.panes"
fi
if [ -n "$problems" ] && [ "$force" = 0 ]; then printf 'dk-wave-close: refused (use --force to close anyway):%b\n' "$problems"; exit 1; fi
tests="skipped (no DK_TEST_CMD)"
if [ "$legacy" = 0 ] && [ -n "${DK_TEST_CMD:-}" ]; then   # gate c
  mkdir -p "$dir/waves"; log="$dir/waves/${n:-0}.test.log"
  if (cd "$DK_WORKTREE" && bash -c "$DK_TEST_CMD") > "$log" 2>&1; then tests="ok ($DK_TEST_CMD)"
  else
    echo "dk-wave-close: tests failed ($DK_TEST_CMD); last 20 lines of $log:"; tail -n 20 "$log"
    if [ "$force" = 0 ]; then dk_process "wave-close $n tests failed ($DK_TEST_CMD)"; exit 1; fi
    tests="failed ($DK_TEST_CMD, forced)"
  fi
fi
closed=0; tabs=""
while read -r agent pane _epoch _group tab _; do
  sname="${agent#"$DK_SHORT"-}"; sf="$dir/state/$sname.md"
  if [ -f "$sf" ]; then
    [ "$(wc -l < "$sf")" -le 20 ] || echo "dk-wave-close: state too long: $sf"
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      dk_owned "$dir/brief.md" "$sname" "$p" || { echo "dk-wave-close: violation $agent touched $p"; dk_process "violation $agent: $p"; }
    done < <(dk_touched "$sf")
  fi
  herdr pane close "$pane" >/dev/null </dev/null && closed=$((closed+1))
  if [ -n "${tab:-}" ] && [[ " $tabs " != *" $tab "* ]]; then tabs="$tabs $tab"; fi
done < "$dir/.panes"
: > "$dir/.panes"
if [ "$legacy" = 1 ]; then dk_process "wave-close: $closed agents closed"
else
  dk_env_set DK_WAVE ""; dk_process "wave-close $n tests $tests $closed agents closed"
  for t in $tabs; do [ "$t" -ge 1 ] && dk_layout_even "$t"; done
fi
echo "closed $closed"
```

- [ ] **Step 4: 跑全部測試** — `tests/run.sh` → 全部通過。「gate c」測試若因 `cat: marker.txt: No such file or directory` 的訊息語系不同而失敗，改成只驗 `tests failed (cat marker.txt)` 與 `.test.log` 存在。

- [ ] **Step 5: Commit**

```bash
git add .dkbo/bin/dk-wave-close tests/unit/08_wave_close.bats
git commit -m "feat(wave-close): review/report/test gates, DK_WAVE reset, tab re-balance and cleanup"
```

---

### Task 12: `dk-watch` — reviewer 逾時、`(quota?)`、kind 熔斷

**Files:**
- Modify: `.dkbo/bin/dk-watch`
- Create: `tests/stub/responses/agent_read.json`
- Modify: `tests/unit/09_watch.bats`

**Interfaces:**
- Consumes: `.panes` 六欄（epoch、group）、`DK_REVIEW_TIMEOUT_MIN`（`dk_settings`）、process 的 `spawn <agent> (<kind> …)` 行（取 kind）、`dk_env_set`。
- Produces: 每 tick 對 group=review 且名稱含 `-reviewer-`、state 非 done、`now-epoch > TIMEOUT*60` 的員工：`herdr agent read <agent> --lines 30` 命中 `rate limit|quota|429|usage limit`（不分大小寫）→ `(quota?)`；`herdr notification show`、`herdr agent prompt <leader> "[TIMEOUT] from dk-watch: <agent> 逾時 (quota?)"`、process `timeout <agent> (quota?) → kind <k> down`、`DK_KIND_DOWN` 追加該 kind；marker `.blocked/<agent>.timeout`，每位只通知一次。

- [ ] **Step 1: stub `tests/stub/responses/agent_read.json`**

```json
{"id":"cli:agent:read","result":{"type":"pane_read","read":{"pane_id":"wC:p4","workspace_id":"wC","tab_id":"wC:t1","source":"recent","format":"text","text":"Error: You have hit your usage limit. Rate limit reached, try again later.","revision":1,"truncated":false}}}
```

- [ ] **Step 2: 加測試到 `tests/unit/09_watch.bats` 檔尾**

```bash
old=$(( $(date +%s) - 1500 ))   # 25 minutes ago
reviewer_row() { printf 'login-reviewer-b wC:p4 %s review 1 3\n' "$1" >> "$d/.panes"; echo "2026-09-10T10:00 spawn login-reviewer-b (codex M) override-kind isolated" >> "$d/process.md"; }

@test "reviewer past DK_REVIEW_TIMEOUT_MIN is reported once with (quota?) and its kind goes down" {
  reviewer_row "$old"
  dk-watch --once; dk-watch --once
  [ "$(grep -c '^agent prompt leader-login \[TIMEOUT\] from dk-watch: login-reviewer-b 逾時 (quota?)$' "$HERDR_STUB_LOG")" -eq 1 ]
  [ "$(grep -c '^notification show dkboai: login-reviewer-b timeout' "$HERDR_STUB_LOG")" -eq 1 ]
  grep -q '^agent read login-reviewer-b --lines 30$' "$HERDR_STUB_LOG"
  grep -q ' timeout login-reviewer-b (quota?) → kind codex down$' "$d/process.md"; grep -q '^DK_KIND_DOWN="codex"$' "$d/.task.env"
  [ -f "$d/.blocked/login-reviewer-b.timeout" ]
}
@test "no quota words → no (quota?) tag; kinds accumulate without duplicates" {
  echo '{"result":{"read":{"text":"thinking..."}}}' > "$HERDR_STUB_RESPONSES/agent_read.json"
  sed -i 's/^DK_KIND_DOWN=.*/DK_KIND_DOWN="agy"/' "$d/.task.env"; reviewer_row "$old"
  dk-watch --once
  grep -q '^agent prompt leader-login \[TIMEOUT\] from dk-watch: login-reviewer-b 逾時$' "$HERDR_STUB_LOG"; grep -q '^DK_KIND_DOWN="agy codex"$' "$d/.task.env"
}
@test "fresh reviewers, done reviewers, qa and legacy rows never time out" {
  reviewer_row "$(date +%s)"; dk-watch --once; ! grep -q 'TIMEOUT' "$HERDR_STUB_LOG"
  sed -i "s/^login-reviewer-b wC:p4 [0-9]*/login-reviewer-b wC:p4 $old/" "$d/.panes"; printf 'status: done\n' > "$d/state/reviewer-b.md"
  dk-watch --once; ! grep -q 'TIMEOUT' "$HERDR_STUB_LOG"
  printf 'login-qa wC:p3 %s review 1 2\nlogin-frontend wC:p2\n' "$old" > "$d/.panes"; dk-watch --once; ! grep -q 'TIMEOUT' "$HERDR_STUB_LOG"
}
@test "a shorter DK_REVIEW_TIMEOUT_MIN is honoured" {
  echo 'DK_REVIEW_TIMEOUT_MIN="1"' >> "$DK_ROOT/settings.env"; reviewer_row "$(( $(date +%s) - 120 ))"
  dk-watch --once; grep -q 'TIMEOUT' "$HERDR_STUB_LOG"
}
```

- [ ] **Step 3: 跑測試確認失敗** — `tests/run.sh tests/unit/09_watch.bats` → 4 個新測試 FAIL。

- [ ] **Step 4: 改 `dk-watch`**

第 5 行之後加 `dk_settings`。在 `tick()` 內、`done < "$dir/.panes"` 之後（`}` 之前）插入：

```bash
  dk_task_env   # pick up DK_KIND_DOWN / DK_REVIEW_TIMEOUT_MIN changes made since the watcher started
  while read -r agent _pane epoch group _; do   # reviewer timeout (spec §3.2)
    [ "${group:-}" = review ] && [[ "$agent" == *-reviewer-* ]] && [[ "${epoch:-}" =~ ^[0-9]+$ ]] || continue
    m="$dir/.blocked/$agent.timeout"; [ ! -f "$m" ] || continue
    sf="$dir/state/${agent#"$DK_SHORT"-}.md"; if [ -f "$sf" ] && grep -q '^status: done' "$sf"; then continue; fi
    [ $((now - epoch)) -gt $((DK_REVIEW_TIMEOUT_MIN * 60)) ] || continue
    raw=$(herdr agent read "$agent" --lines 30 2>/dev/null </dev/null || true)
    txt=$(printf '%s' "$raw" | jq -r '.result.read.text // .result.text // empty' 2>/dev/null || true); txt="${txt:-$raw}"
    tag=""; printf '%s' "$txt" | grep -qiE 'rate limit|quota|429|usage limit' && tag=" (quota?)"
    kind=$(sed -n "s/^[^ ]* spawn $agent (\([a-z0-9_-]*\) .*/\1/p" "$dir/process.md" | tail -1)
    herdr notification show "dkboai: $agent timeout" --body "reviewer 逾時${tag}，該 kind 已熔斷" --sound request >/dev/null 2>&1 </dev/null || true
    herdr agent prompt "$(dk_leader_name)" "[TIMEOUT] from dk-watch: $agent 逾時${tag}" >/dev/null 2>&1 </dev/null || true
    if [ -n "$kind" ] && [[ " ${DK_KIND_DOWN:-} " != *" $kind "* ]]; then
      DK_KIND_DOWN="${DK_KIND_DOWN:+$DK_KIND_DOWN }$kind"; dk_env_set DK_KIND_DOWN "$DK_KIND_DOWN"
    fi
    dk_process "timeout $agent$tag → kind ${kind:-?} down"; echo notified > "$m"
  done < "$dir/.panes"
```

注意 `dk_settings` 也要在 `tick` 外呼叫一次（`thr=` 那行之前），讓 `--once` 路徑拿到 `DK_REVIEW_TIMEOUT_MIN`。

- [ ] **Step 5: 跑全部測試** — `tests/run.sh` → 全部通過。

- [ ] **Step 6: Commit**

```bash
git add .dkbo/bin/dk-watch tests/stub/responses/agent_read.json tests/unit/09_watch.bats
git commit -m "feat(watch): reviewer timeout detection, quota tagging, kind circuit breaker"
```

---

### Task 13: `dk-resume` — 本波、裁定、每 tab 一行、降級

**Files:**
- Modify: `.dkbo/bin/dk-resume`
- Modify: `tests/unit/10_resume.bats`

**Interfaces:**
- Consumes: `DK_WAVE`、`DK_KIND_DOWN`、process 的 `wave-open`/`ruling:` 行、`.panes` 六欄、`DK_REVIEW_TIMEOUT_MIN`。
- Produces: 新段 `## 本波`（`wave: N  base: <sha7>  kinds down: …` 與每位 reviewer 一行 `<agent> <status> <分鐘> min[ TIMEOUT?]`）、`## 裁定（最後一次 wave-open 之後）`、`## 在線員工（每 tab 一行）`（`tab 1: login-backend(working) login-qa(blocked)`；`.panes` 空時退回 agent list 過濾）。降級順序：`render 20 5 0` → `20 3 0` → `10 3 0` → `10 3 5`（第 3 參數 = 裁定行數上限，0 = 全部）。總行數 ≤150。

- [ ] **Step 1: 改測試**

`tests/unit/10_resume.bats` 的 `setup()` 尾端追加：

```bash
  cat >> "$d/process.md" <<'P'
2026-09-10T11:00 ruling: old — before the wave — n/a
2026-09-10T11:01 wave-open 1 base abc1234 members frontend(M) qa(S)
2026-09-10T11:02 ruling: 用 JWT — brief 指定 — 低
2026-09-10T11:03 ruling: 錯誤碼 422 — 契約 — 中
P
  sed -i 's/^DK_WAVE=.*/DK_WAVE="1"/; s/^DK_KIND_DOWN=.*/DK_KIND_DOWN="codex"/' "$d/.task.env"
  printf 'login-frontend wC:p2 0 dev 1 1\nlogin-qa wC:p3 0 review 1 2\nlogin-reviewer-a wB:p10 %s review 2 1\n' "$(( $(date +%s) - 1800 ))" > "$d/.panes"
  printf 'status: working\n' > "$d/state/reviewer-a.md"
```

第一個測試把 `[[ "$output" == *"login-frontend working"* ]]` 改為：

```bash
  [[ "$output" == *"wave: 1  base: abc1234  kinds down: codex"* ]]
  [[ "$output" == *"login-reviewer-a working 30 min TIMEOUT?"* ]]
  [[ "$output" == *"ruling: 用 JWT"* ]]; [[ "$output" == *"ruling: 錯誤碼 422"* ]]; [[ "$output" != *"ruling: old"* ]]
  [[ "$output" == *"tab 1: login-frontend(working) login-qa(blocked)"* ]]; [[ "$output" == *"tab 2: login-reviewer-a(?)"* ]]
```

檔尾追加：

```bash
@test "no open wave and empty .panes fall back to plain text and the agent list" {
  sed -i 's/^DK_WAVE=.*/DK_WAVE=""/' "$d/.task.env"; : > "$d/.panes"
  run dk-resume; [ "$status" -eq 0 ]; [[ "$output" == *"沒有開著的波"* ]]; [[ "$output" == *"login-frontend working"* ]]
}
@test "rulings are trimmed to the last 5 only as the final degradation step" {
  for i in $(seq 1 60); do echo "2026-09-10T12:00 ruling: r$i — x — y" >> "$d/process.md"; done
  for a in a b c d e f g h i j k l m n o p q r s t; do for i in $(seq 1 8); do echo "line $i" >> "$d/state/dev-$a.md"; done; done
  run dk-resume; [ "$status" -eq 0 ]; [ "${#lines[@]}" -le 150 ]
  [[ "$output" == *"ruling: r60 —"* ]]; [[ "$output" != *"ruling: r30 —"* ]]   # 裁定段只剩最後 5 行；process 尾 10 行也不含 r30
}
```

- [ ] **Step 2: 跑測試確認失敗** — `tests/run.sh tests/unit/10_resume.bats` → 第 1 個與 2 個新測試 FAIL。

- [ ] **Step 3: 改寫 `dk-resume` 的 `render` 與降級**

第 10 行 `dk_task_env` 後加 `; dk_settings`。把 `render()` 到檔尾換成：

```bash
render() { # $1=process lines $2=state lines $3=ruling lines (0 = all)
  echo "## 你是 $(dk_leader_name)（任務 $(basename "$dir")）"
  echo "規範在 .dkbo/LEADER.md 與 .dkbo/PROTOCOL.md，先讀再行動。任務目錄 $dir"
  echo "## brief"; cat "$dir/brief.md"
  echo "## 本波"
  if [ -n "${DK_WAVE:-}" ]; then
    echo "wave: $DK_WAVE  base: $(sed -n "s/^[^ ]* wave-open $DK_WAVE base \([0-9a-f]*\).*/\1/p" "$dir/process.md" | tail -1)  kinds down: ${DK_KIND_DOWN:-無}"
    awk -v t="$DK_REVIEW_TIMEOUT_MIN" -v now="$(date +%s)" -v pfx="$DK_SHORT-" -v dir="$dir" '
      NF>=6 && $4=="review" && index($1, "-reviewer-") {
        sf=dir "/state/" substr($1, length(pfx)+1) ".md"; st="no-state"
        while ((getline l < sf) > 0) if (l ~ /^status: /) st=substr(l, 9); close(sf)
        printf "%s %s %d min%s\n", $1, st, (now-$3)/60, ((now-$3) > t*60 && st!="done") ? " TIMEOUT?" : "" }' "$dir/.panes"
  else echo "沒有開著的波（dk-wave-open N 開下一波）"; fi
  echo "## 裁定（最後一次 wave-open 之後）"
  rul=$(awk '/ wave-open /{buf=""} / ruling: /{buf=buf $0 "\n"} END{printf "%s", buf}' "$dir/process.md")
  if [ "$3" -gt 0 ]; then printf '%s' "$rul" | tail -n "$3"; else printf '%s' "$rul"; fi
  echo "## process（最後 $1 行）"; tail -n "$1" "$dir/process.md"
  echo "## 未處理訊息（最後一則 ACK 之後，寄給 leader）"
  awk -v me="$(dk_leader_name)" '$2==me && $3=="[ACK]" {buf=""; next} index($0, "-> " me " ")>0 {buf=buf $0 "\n"} END{printf "%s", buf}' "$dir/messages.log"
  echo "## state 摘要（每檔前 $2 行）"
  for f in "$dir"/state/*.md; do [ -f "$f" ] || continue; case "$f" in *.report.md) continue;; esac; n=$(basename "$f" .md); head -n "$2" "$f" | sed "s/^/$n: /"; done
  echo "## 在線員工（每 tab 一行）"
  list=$(herdr agent list 2>/dev/null | jq -r '(.result.agents // [])[] | select(.name != null) | "\(.name) \(.agent_status)"' 2>/dev/null || true)
  if [ -s "$dir/.panes" ]; then
    awk -v L="$list" 'BEGIN{n=split(L, a, "\n"); for(i=1;i<=n;i++){split(a[i], kv, " "); st[kv[1]]=kv[2]}}
      {t=(NF>=6)?$5:"?"; row[t]=row[t] " " $1 "(" (($1 in st)?st[$1]:"?") ")"; if(!(t in seen)){seen[t]=1; order[++k]=t}}
      END{for(i=1;i<=k;i++) printf "tab %s:%s\n", order[i], row[order[i]]}' "$dir/.panes"
  else printf '%s\n' "$list" | grep "^$DK_SHORT-" || echo "（無）"; fi
  echo "## BACKLOG"; cat "$DK_ROOT/tasks/BACKLOG.md"
}
out=$(render 20 5 0)
[ "$(echo "$out" | wc -l)" -le 150 ] || out=$(render 20 3 0)
[ "$(echo "$out" | wc -l)" -le 150 ] || out=$(render 10 3 0)
[ "$(echo "$out" | wc -l)" -le 150 ] || out=$(render 10 3 5)
printf '%s\n' "$out"
```

- [ ] **Step 4: 跑全部測試** — `tests/run.sh` → 全部通過。

- [ ] **Step 5: Commit**

```bash
git add .dkbo/bin/dk-resume tests/unit/10_resume.bats
git commit -m "feat(resume): current wave, rulings, per-tab roster, extra degradation step"
```

---
### Task 14: 文件與 skill — LEADER.md、PROTOCOL.md、reviewer 角色、README、init、RUNBOOK

**Files:**
- Modify: `.dkbo/LEADER.md`（整檔改寫，≤120 行）、`.dkbo/PROTOCOL.md`（整檔改寫，≤120 行）
- Modify: `.dkbo/roles/reviewer.md`, `.dkbo/roles/README.md:9`
- Modify: `.dkbo/README.md`, `.dkbo/skills/init/SKILL.md`, `tests/e2e/RUNBOOK.md`
- Modify: `tests/unit/04_docs.bats`

**Interfaces:**
- Consumes: 前 13 個任務的所有指令名與 process 詞彙（文件必須照 Global Constraints 的字面）。
- Produces: 人與 AI 讀的規則；`04_docs` 守住行數與關鍵詞。

- [ ] **Step 1: 加測試到 `tests/unit/04_docs.bats` 檔尾**

```bash
@test "LEADER.md covers brief-check, wave-open, review, ruling, timeout; PROTOCOL covers report and reviewer rules" {
  for w in dk-brief-check dk-wave-open dk-review-pack dk-review 'ruling:' '\[TIMEOUT\]' 'dk-wave-close --agent' 'review N skipped' 'settings.env' '--task'; do grep -q -- "$w" "$DK_ROOT/LEADER.md"; done
  for w in '## 測試' 'report.md' 'briefs/' '## 規格合規' '## Important' '## Minor' 'file:line' '不 push' 'ESCALATE'; do grep -q -- "$w" "$DK_ROOT/PROTOCOL.md"; done
  grep -q '^group: review' "$DK_ROOT/roles/reviewer.md"; grep -q '結案評議' "$DK_ROOT/roles/reviewer.md"
  grep -q 'settings.env' "$DK_ROOT/skills/init/SKILL.md"; grep -q 'DK_REVIEW_KINDS' "$DK_ROOT/skills/init/SKILL.md"
  grep -q -- '--exclude=settings.env' "$DK_ROOT/README.md"; grep -q '每波自動附審查' "$DK_ROOT/README.md"
  grep -q '^11\. ' "$REPO_ROOT/tests/e2e/RUNBOOK.md"; grep -q 'TIMEOUT' "$REPO_ROOT/tests/e2e/RUNBOOK.md"
}
```

- [ ] **Step 2: 跑測試確認失敗** — `tests/run.sh tests/unit/04_docs.bats` → 新測試 FAIL。

- [ ] **Step 3: 改寫 `.dkbo/LEADER.md`**

```markdown
# 領導規範

你是這個任務的領導。你不寫程式、不改業務檔案、不親自翻譯或畫圖。所有產出都派員工。你只做：讀需求、寫 brief、拆波、派工、派審查、裁定、處理 ESCALATE、寫記憶檔、每波 commit、結案合併。

以下所有 `dk-*` 指令都在 `.dkbo/bin/`，例如 `.dkbo/bin/dk-task-new`。團隊設定在 `.dkbo/settings.env`（測試指令 `DK_TEST_CMD`、reviewer kind 清單 `DK_REVIEW_KINDS`、法定人數 `DK_REVIEW_MIN`、逾時 `DK_REVIEW_TIMEOUT_MIN`、tab 1 格數 `DK_TAB1_SLOTS`），由 /dkboai-init 寫。

## 每次醒來先做
1. 若不確定狀態：執行 `dk-resume`，讀完再行動。它印 brief、本波（base、reviewer 狀態、熔斷）、裁定、未處理訊息、每 tab 的員工。
2. 讀 `.dkbo/PROTOCOL.md`（訊息格式與升報規則）。

## 收到人的請求時分流
- 是進行中任務的一部分 → 調波次表（記 process.md），不改 brief 的需求與驗收。
- 獨立、不改程式（翻譯、畫圖、整理） → `dk-chore <角色> "<交代>"`。雜務不屬於任務，對雜務員工回話用 `herdr agent prompt <agent> "..."`（不是 dk-msg）；收到它的 `[DONE]` 後看結果，再 `dk-chore-close <agent>`（`--code` 的會合併回 main）。
- 獨立、改程式、範圍小 → 先評估：涉及檔案、是否落在在線成員所有權內、嚴重度。給三選一附建議：立刻修（`dk-chore <角色> --code`）/ 併入當前任務 / 延後進 `tasks/BACKLOG.md`。人選後執行；人說「照建議」就直接做。
- 範圍大 → 建議開新任務，問人。
- 角色檔不存在 → 先用 add-role skill 建立，再派工。不用通用員工矇混。

## 開任務
1. `dk-task-new <short> "<顯示名>" [--from <plan.md>]`。
2. 寫 `brief.md`：目標 ≤3 行、驗收標準、檔案所有權（成員範圍不得重疊）、共用契約擁有者、波次表。波次表一列一位成員（標難度 S/M/L），審查欄只填在該波第一列，三種寫法：`預設`（用 settings.env 的 kind）、`skip: <理由>`（純文件波）、`kinds: <k1> [k2] [k3]`（指定 1–3 個 kind 當第二、三意見）。成員欄填 `<角色>[-<別名>]`（即 state 檔名，不含任務短名），可改欄以逗號分隔 glob，`dir/**` 代表整棵子樹。有 plan 檔時不重寫內容，只對應驗收、劃所有權、把 task 分組成波。
3. `dk-brief-check`。FAIL 就修 brief 重跑；WARN（一波 dev 超過 tab 1 格數）建議拆波。全 OK 才給人。
4. 關卡①：把 brief 給人確認。人點頭後執行 `dk-task-new <short> --gate1`（記 process、INDEX 改 running）。

## 跑一波
1. `dk-wave-open N`：記 base sha、寫每位成員的切片 `briefs/<成員>.md`（員工只讀切片）。
2. 對該波每位成員 `dk-spawn <角色> [別名] [--tier S|M|L] [--kind K] [--isolated]`。先派 dev 再派 qa，版面才會照 tab 填。結束這個 turn，閒置。員工訊息與人的輸入會自己推進來。不輪詢、不主動讀員工終端。
3. 收到 dev `[DONE]`（state `status: done`、`state/<成員>.report.md` 有 `## 測試`）：`dk-review-pack N` 再 `dk-review`。reviewer 與 qa 並行，不必等 qa。
4. 收到 reviewer `[DONE]`：讀 `state/reviewer-<x>.report.md`。達 `DK_REVIEW_MIN` 且無 Important，或所有 reviewer 皆回覆，即裁定：`dk-process "review N verdict a: ok / b: important 2"`，再記 `ruling:`（見下）。有 Important → `dk-msg <dev> "[BUG] review: …"` 指向 reviewer 的 report；dev `[FIXED]` 後重跑 `dk-review-pack N`，`dk-msg <reviewer> "[TASK] 複看 waves/N.diff"`。同一 bug 一次修復上限照 PROTOCOL。
5. qa `[DONE]` 且審查已裁定 → `dk-wave-close`。它檢查裁定行、每位 dev 的 report、在 worktree 跑 `DK_TEST_CMD`；看測試結果與越界、超長警告。然後在 worktree 內 `git add -A && git commit -m "wave N: ..."`。
6. 純文件波：審查欄寫 `skip: <理由>`，領導 `dk-process "review N skipped: <理由>"`，wave-close 就放行。
7. 收到 `[ESCALATE]`：能依 brief 判定就 `dk-msg <員工> "[DECISION] ..."` 並記 `ruling:`；不能就問人（關卡②），得到答案後回 DECISION 並在 `decisions.md` 加一行。收到 `[BLOCKED]`：告知人去按審批。處理完一批訊息後 `dk-msg --ack`。
8. 依結果增刪下一波，記 process。

## 裁定（ruling）
唯一格式：`dk-process "ruling: <決定> — <原因> — <若錯代價>"`。只影響本任務者只記 process；會影響其他任務者另複製一行進 `decisions.md`。結案 report.md 的「重要決策」列出本任務所有 ruling（`grep ' ruling: ' process.md`）。reviewer 意見矛盾：以 brief 為準裁定並記 ruling；不能依 brief 判者升關卡②。

## 評議波（不綁定 diff 的設計題）
第一輪對 `settings.env` 的 `DK_REVIEW_KINDS` 每個 kind 各派一位：`dk-spawn reviewer a --isolated --kind <k1>`、`dk-spawn reviewer b --isolated --kind <k2>`…，題目寫在 brief，各自寫意見到 state。全部 DONE 後第二輪對每人 `dk-msg` 其他人的 state 路徑，每人只准一則反駁。你裁定，記 ruling 與 decisions.md。

## 結案
1. 關卡③前先整分支評議：`dk-review-pack --task`，再 `dk-review --task --tier L`（L 檔 reviewer 讀 `waves/task.diff`）。Important 修掉或記 ruling，才寫 `report.md`（照範本；遺留段列出未經審查的波）。關卡③：給人拍板。
2. `dk-task-close`。合併衝突時它會停：不要自己解，問人或開 `it` 的修復波。放棄用 `dk-task-close --abandon "<原因>"`。

## 故障
- reviewer `[TIMEOUT]`（dk-watch 推來；該 kind 已寫進 `.task.env` 的 `DK_KIND_DOWN`）：`dk-wave-close --agent <reviewer>` 關它。達 `DK_REVIEW_MIN` 照常裁定；不夠就 `dk-review --kinds "<未熔斷者>"` 補一位；全部熔斷 → `dk-process "review N skipped: all kinds down"`，report.md 遺留段標「本波未經審查」。同任務內解除熔斷：編輯 `.task.env` 的 `DK_KIND_DOWN` 並 `dk-process "kind <k> up"`；`dk-task-close` 會清掉。
- wave-close 測試失敗：它不關 pane；`dk-msg <擁有者> "[BUG] wave-close tests: <最後幾行>"`；連續兩次失敗升關卡②。
- dev report 缺 `## 測試`：wave-close 拒絕；`dk-msg <dev> "[TASK] 補 report 測試段"`。
- 員工 `[ESCALATE] context` 或 pane 掛掉：`dk-spawn` 同角色同別名 `--resume`，提示會叫他從 state 續作；它會先關掉同名舊 pane。
- 自己上下文吃緊：`/clear` 後執行 `dk-resume`，依「本波」段從「跑一波」第 3 或 4 步接續。
```

- [ ] **Step 4: 改寫 `.dkbo/PROTOCOL.md`**

```markdown
# 通訊協定

所有訊息一律用 `$DK_ROOT/bin/dk-msg <對象> "[類型] 內文"`（下文簡寫 dk-msg；`DK_ROOT` 是你 pane 的環境變數）。腳本補寄件人、時間，寫進 messages.log，並等對方閒置才送。內文一到三句、≤200 字元，細節寫在你的 state 或 report 檔並指路，不貼程式碼。對象可寫 `leader`，腳本會解析成本任務的領導。

## 你要讀的
首段提示指向你的切片 `tasks/<t>/briefs/<你的 state 名>.md`（你的波次列、所有權、共用契約與驗收標準全文、同波成員）。完整 `brief.md` 仍可讀，但以切片為準；切片沒寫的所有權就不是你的。

## 類型
| 類型 | 方向 | 何時 |
|---|---|---|
| TASK | 領導→員工 | 補充派工、要求補 report、請 reviewer 複看 |
| DONE | 員工→領導（也可同時通知同波夥伴，如 dev→qa） | 完成，且 state 已寫 `status: done`、report 已寫好 |
| BUG | 員工→員工、領導→dev（reviewer 的 Important 由領導轉） | 附重現方式，指向 state 或 report |
| FIXED | 員工→員工 | 修好了，請重驗 |
| QUESTION / ANSWER | 任意 | 釐清介面、契約 |
| ESCALATE | 員工→領導 | 需要決策、想動不屬於自己的檔、修一次未好、上下文吃緊（寫 `[ESCALATE] context`）、碰到停止條件 |
| DECISION | 領導→員工 | 決策結果 |
| STOP | 領導→員工 | 停手，寫 state 收尾 |

`[BLOCKED]` 與 `[TIMEOUT]` 由 dk-watch 直接推給領導，員工不用送。

## 規則
- 同一波員工可以互相傳訊。`DK_ISOLATED=1` 的員工（reviewer）只能對 leader 傳訊。
- 修復迴圈上限一次，以同一個 bug 計：BUG → FIXED → 再驗仍失敗 → qa（或領導）直接 ESCALATE，不再回 dev。
- QUESTION 若 brief 沒有答案，被問的人不得自己決定；提問者 ESCALATE。同一波同一對員工 QUESTION 最多兩則。
- 任何「選 A 或 B」、任何共用契約的變更，一律 ESCALATE。
- 只能修改切片所有權劃給你的檔案。要動別人的檔 → 用 QUESTION 請擁有者改，或 ESCALATE。
- 禁止使用 subagent、禁止自行開 pane 或啟動其他 agent。
- 只有本人能寫自己的 state 與 report 檔；員工不寫 process.md、brief.md、report.md（任務結案報告）。
- dk-msg 回傳非零（對方卡住、送不進）：把這件事寫進 state 的 `blocked_by`，繼續做別的事。

## 停止條件（碰到就停手並 ESCALATE，不要自行變通）
不 push、不改寫歷史（rebase/amend 已推送的 commit、force）、不刪分支、不動所有權外的檔、不裝依賴（it 角色除外）、不改 `.dkbo/` 下的規則檔。

## state 檔（≤20 行，每完成一個子步驟就覆寫）
```
status: working | blocked | done
wave: 1
current: 正在做什麼（一句）
touched:
  - src/api/login.ts
todo:
  - 錯誤碼對齊前端
blocked_by: （無則省略）
report: state/<你的 state 名>.report.md
notes: 給接手者的必要事實，≤5 行
```
DONE 前 `touched` 必須完整，領導會拿它比對所有權。

## report 檔（`tasks/<t>/state/<你的 state 名>.report.md`，不限行數）
照 `$DK_ROOT/templates/report-employee.md`：`## 做了什麼`、`## 測試`（**必填**：跑了什麼指令、結果摘要；空的話 dk-wave-close 不放行）、`## 自我審查`、`## 疑慮`。DONE 前 state 與 report 都要寫好。

## reviewer 專節
- 只讀、不改碼、不跑會寫入的指令（不 `git add/commit`、不改檔、不裝東西）。讀切片指的差異包 `waves/N.diff` 與 brief。
- report 格式固定：`## 規格合規`（逐條驗收標準 ✅/❌ 與缺漏）、`## Important`（會出錯、違反 brief 或契約、越界改檔）、`## Minor`（風格、可讀性）；每條附 `file:line`。
- 意見只給領導（`dk-msg leader "[DONE] review 波 N: Important K 條，見 report"`），不直接對 dev 說；領導轉成 BUG 給 dev。收到領導 `[TASK] 複看` 時重讀差異包、更新 report、再 DONE。
- 評議波（設計題）沿用：意見寫 state notes，第二輪只准一則反駁。

雜務員工（`chore-*`）沒有任務綁定，不適用上面的 state 檔／dk-msg 流程；他們以 `herdr agent prompt "$DK_LEADER" "[DONE] from <agent>: ..."` 作為回報第一句。
```

- [ ] **Step 5: `roles/reviewer.md`、`roles/README.md`**

`roles/reviewer.md` 正文改為（frontmatter 已在 Task 2 改成 `group: review`）：

```markdown
## 職責
實作波審查與結案評議：讀 `waves/N.diff` 與 brief，逐條驗收標準判合規，找出會出錯、違反契約、越界改檔的地方。不改任何程式、不跑會寫入的指令。評議波（設計題）時把意見寫在 state 的 notes（≤15 行），第二輪只准發一則反駁。
## 完成定義
report 寫好（`## 規格合規` ✅/❌、`## Important`、`## Minor`，每條附 `file:line`），state `status: done`，`dk-msg leader "[DONE] review 波 N: Important K 條，見 report"`。
## 交接對象
領導裁定並轉 BUG；收到 `[TASK] 複看` 就重讀差異包更新 report。
```

`roles/README.md` 第 9 行末欄改為 `實作波審查與結案評議，只出意見不改碼`。

- [ ] **Step 6: `.dkbo/README.md`**

「日常使用」加兩點：

```markdown
- 每波自動附審查：dev DONE 後領導派 1–3 位 reviewer（kind 依 `.dkbo/settings.env`）與 qa 並行；wave-close 會檢查裁定、每位 dev 的 report 與 `DK_TEST_CMD`。純文件波在 brief 審查欄寫 `skip: <理由>`。
- 人多時的版面：領導在 tab 1 左欄，員工填右側 2×2（或 3×2）；第 5 位起自動開 `<short>-2` 等 tab，每 tab 6 位。
```

「更新 dkboai」的第一條 rsync 加 `--exclude=settings.env`（放在 `--exclude=LEADER.md` 之前）。「疑難排解」表加：

```markdown
| 領導收到 `[TIMEOUT]` | reviewer 超過 `DK_REVIEW_TIMEOUT_MIN` 沒 DONE，多半是該 CLI 用量到頂（訊息含 rate limit / quota / 429 / usage limit 會標 `(quota?)`）。該 kind 本任務內熔斷；領導 `dk-wave-close --agent <reviewer>` 後照 LEADER.md 補位。 |
| `dk-wave-close` 拒絕 | 印出的每一條都是缺的東西：裁定行、dev 的 `## 測試`、測試失敗。補齊再跑；真要跳過用 `--force` 並在 process 記理由。 |
```

- [ ] **Step 7: `skills/init/SKILL.md`**

第 3 步改為：

```markdown
3. 寫 `.dkbo/settings.env`（所有值加引號）：`DK_TEST_CMD`（從 PROJECT.md / package.json 等找測試指令，讓人確認；沒有就留空）、`DK_REVIEW_KINDS`（第二、第三意見工具：只列可用且已登入者，主模型放第一個，1 至 3 個，空白分隔）、`DK_REVIEW_MIN`（預設 1）、`DK_REVIEW_TIMEOUT_MIN`（預設 20）、`DK_TAB1_SLOTS`（4 或 6，看螢幕寬）。逐鍵讓人確認。不再改寫 LEADER.md 的 prose。
```

第 6 步改為：`6. 結束時列出：可用工具、主模型、settings.env 的五個值、PROJECT.md 行數、缺少的 MCP。`

- [ ] **Step 8: `tests/e2e/RUNBOOK.md`**

第 3 步結尾加「切到 tab 1 觀察：領導佔左欄、backend 與 qa 在右側上下兩格」。第 6 步改為「兩人 DONE 後：領導 `dk-review-pack 1`、`dk-review`；reviewer DONE 後領導記 verdict 與 ruling，才 `dk-wave-close` 並 commit `wave 1: ...`。檢查 process.md 有 `review 1 spawned`、`review 1 verdict`、`ruling:`、`wave-close 1 tests`。」。第 10 步之前插入：

```markdown
11. 逾時與熔斷：在 wave2 用一個未登入（或已到用量上限）的 kind 當 reviewer（`settings.env` 的 `DK_REVIEW_KINDS` 加上它，或 brief 審查欄 `kinds: claude <那個 kind>`），`DK_REVIEW_TIMEOUT_MIN` 先調成 2。預期：約 2 分鐘後領導 pane 收到 `[TIMEOUT] from dk-watch: … 逾時 (quota?)`、桌面通知一次、`.task.env` 的 `DK_KIND_DOWN` 出現該 kind、process 有 `timeout … → kind <k> down`；領導 `dk-wave-close --agent <reviewer>` 後 tab 版面重新均分。把該 CLI 實際印出的用量訊息字樣抄一行進 `.dkbo/README.md` 疑難排解表。
12. 記錄：把每步實際發生與預期的差異寫到 `tests/e2e/RESULTS-<日期>.md`。
```

（原第 10 步「記錄」改成第 12 步。）驗收行補：`process.md 另有 wave-open / review … spawned / review … verdict / ruling: / wave-close … tests / timeout 各一行以上；每位 dev 有 state/<成員>.report.md`。

- [ ] **Step 9: 跑全部測試** — `tests/run.sh` → 全部通過（含行數 ≤120）。若 LEADER.md 或 PROTOCOL.md 超過 120 行，先刪空行再合併「分流」段的長句，不刪規則。

- [ ] **Step 10: Commit**

```bash
git add .dkbo/LEADER.md .dkbo/PROTOCOL.md .dkbo/roles/reviewer.md .dkbo/roles/README.md .dkbo/README.md .dkbo/skills/init/SKILL.md tests/e2e/RUNBOOK.md tests/unit/04_docs.bats
git commit -m "docs(dkbo): wave review flow, ruling format, reviewer protocol, settings in init and README"
```

---

### Task 15: 層 2 — 真 herdr 驗證 tab / ratio / resize / read 形狀

**Files:**
- Modify: `tests/integration/herdr-real.sh:22-27`（在 `notification show` 之前插入）
- Modify: `tests/integration/README.md`（「Last run」段）
- 可能 Modify: `.dkbo/lib/layout.sh` 的 `DK_RATIO_MEANS` 預設、`dk__layout_amount`；`tests/stub/responses/{tab_create,pane_layout,agent_read}.json`

**Interfaces:**
- Produces: 腳本印 `OK/FAIL` 與三行 `NOTE`：`--ratio` 語意（new / anchor）、`--amount 0.1` 實際改了幾格、`pane read` 形狀。實作者依 NOTE 決定是否改 `DK_RATIO_MEANS` 預設與 `dk__layout_amount`。

- [ ] **Step 1: 在 `herdr-real.sh` 第 22 行（`notification show`）之前插入**

```bash
# ── spec 2026-09-10 §10: tab create shape, --ratio semantics, resize unit, read shape
tc=$($H tab create --workspace "$ws0" --cwd "$tmp" --label dktest-2 --no-focus --env DK_T=7 2>&1)
tid=$(echo "$tc" | jq -r '.result.tab.tab_id // empty'); troot=$(echo "$tc" | jq -r '.result.root_pane.pane_id // empty')
[ -n "$tid" ] && [ -n "$troot" ] && ok "tab create shape tab=$tid root=$troot" || fail "tab create shape: $(echo "$tc" | head -c 300)"
$H pane run "$troot" 'echo DKT=$DK_T' >/dev/null 2>&1
$H pane wait-output "$troot" --match 'DKT=7' --timeout 10000 >/dev/null 2>&1 && ok "tab create --env inherited" || fail "tab create --env not visible"
s2=$($H pane split --pane "$troot" --direction right --ratio 0.3 --cwd "$tmp" --no-focus 2>&1); p2=$(echo "$s2" | jq -r '.result.pane.pane_id // empty')
lay=$($H pane layout --pane "$troot" 2>&1)
w_root=$(echo "$lay" | jq -r --arg p "$troot" '.result.layout.panes[] | select(.pane_id==$p) | .rect.width' 2>/dev/null)
w_new=$(echo "$lay"  | jq -r --arg p "$p2"    '.result.layout.panes[] | select(.pane_id==$p) | .rect.width' 2>/dev/null)
aw=$(echo "$lay" | jq -r '.result.layout.area.width // empty' 2>/dev/null)
[ -n "$w_root" ] && [ -n "$w_new" ] && [ -n "$aw" ] && ok "pane layout has area + panes[].rect (root=$w_root new=$w_new area=$aw)" || fail "pane layout shape: $(echo "$lay" | head -c 300)"
if [ "${w_new:-0}" -lt "${w_root:-0}" ]; then echo "NOTE --ratio 0.3 made the NEW pane narrower → --ratio is the new pane's share: keep DK_RATIO_MEANS=new in .dkbo/lib/layout.sh"
else echo "NOTE --ratio 0.3 made the ANCHOR narrower → --ratio is the anchor's share: set DK_RATIO_MEANS=anchor in .dkbo/lib/layout.sh"; fi
rz=$($H pane resize --pane "$troot" --direction right --amount 0.1 2>&1)
w_after=$(echo "$rz" | jq -r --arg p "$troot" '.result.resize.layout.panes[] | select(.pane_id==$p) | .rect.width' 2>/dev/null)
[ -n "$w_after" ] && ok "pane resize returns .result.resize.layout" || fail "pane resize shape: $(echo "$rz" | head -c 300)"
[ -n "$w_after" ] && echo "NOTE resize --amount 0.1 changed width by $((w_after - w_root)) cells of area $aw (a fraction would give ≈$((aw/10))); if the unit is cells, change dk__layout_amount to print whole cells"
# 4 cells, close 1, layout still parseable (dk_layout_even reads exactly these fields)
s3=$($H pane split --pane "$troot" --direction down --ratio 0.5 --cwd "$tmp" --no-focus 2>&1); p3=$(echo "$s3" | jq -r '.result.pane.pane_id // empty')
s4=$($H pane split --pane "$p2" --direction down --ratio 0.5 --cwd "$tmp" --no-focus 2>&1); p4=$(echo "$s4" | jq -r '.result.pane.pane_id // empty')
$H pane close "$p4" >/dev/null 2>&1
lay2=$($H pane layout --pane "$troot" 2>&1); n=$(echo "$lay2" | jq -r '.result.layout.panes | length' 2>/dev/null)
[ "${n:-0}" -eq 3 ] && ok "after closing one of four cells layout lists 3 panes" || fail "layout after close: $(echo "$lay2" | head -c 300)"
pr=$($H pane read "$troot" --lines 5 2>&1)
echo "$pr" | jq -e '.result.read.text' >/dev/null 2>&1 && ok "pane read shape .result.read.text (agent read shares it)" || fail "pane read shape: $(echo "$pr" | head -c 200)"
printf '%s' "$tc" > "$tmp/tab_create.json"; printf '%s' "$lay" > "$tmp/pane_layout.json"; printf '%s' "$pr" > "$tmp/pane_read.json"
$H tab close "$tid" >/dev/null 2>&1 && ok "tab close" || fail "tab close"
```

- [ ] **Step 2: 執行（需在 herdr 內；不在 herdr 內就跳到 Step 4 並在 README 記「pending」）**

Run: `chmod +x tests/integration/herdr-real.sh && tests/integration/herdr-real.sh`
Expected: 全部 `OK`，三行 `NOTE`。

- [ ] **Step 3: 依 NOTE 調整**

- 若 NOTE 說 anchor：把 `.dkbo/lib/layout.sh` 的 `DK_RATIO_MEANS="${DK_RATIO_MEANS:-new}"` 改為 `anchor`，並把 `tests/unit/07_spawn.bats` 中三處 `--ratio 0.500` 保持不變（0.5 兩種語意相同）。
- 若 `--amount` 單位是格：`dk__layout_amount() { awk -v d="$1" 'BEGIN{printf "%d", d}'; }`，並把 `tests/unit/17_layout.bats` 的期望改為 `--amount -10` 與 `--amount 10`。
- 若真實 JSON 與 stub 差異只在多餘欄位，不改 stub；若欄位名不同，用 `$tmp/*.json` 更新 `tests/stub/responses/` 對應檔並跑 `tests/run.sh`。

- [ ] **Step 4: 更新 `tests/integration/README.md` 的「Last run」段**

追加一段：日期、herdr 版本、幾個 OK/FAIL、三行 NOTE 原文、因此改了什麼（或「pending：本次不在 herdr 內，尚未執行」）。

- [ ] **Step 5: 跑全部測試與 Commit**

Run: `tests/run.sh` → 全部通過。

```bash
git add tests/integration/herdr-real.sh tests/integration/README.md .dkbo/lib/layout.sh tests/stub/responses tests/unit/17_layout.bats tests/unit/07_spawn.bats
git commit -m "test(integration): verify tab create, --ratio semantics, resize unit and read shape on real herdr"
```

---

## 執行順序與相依

Task 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 → 13 → 14 → 15。硬相依：2 需要 1（`dk_settings` 不是，但 `fixture_task` 的新欄要先在）；3 需要 2；6 需要 4（`DK_ROOT_PANE` 是領導 pane）與 5；7–9 需要 2 與 6；10–11 需要 6；12 需要 6（六欄）；13 需要 6；14 最後；15 任何時候可跑但建議最後。Task 3 與 5 彼此獨立，可平行。

## 規格對照（自我檢查）

| 規格章節 | 任務 |
|---|---|
| §2.1 settings.env、dk_settings | 1、14（init） |
| §2.2 .task.env 欄位 | 1（DK_WAVE/KIND_DOWN/TABS）、4（DK_BASE） |
| §2.3 .panes 六欄 | 6 |
| §2.4 process 詞彙 | 7、9、11、12、10（tab/pane-close）、14（ruling） |
| §2.5 成員切片 | 2（範本）、7 |
| §2.6 報告檔、state report: 行 | 2、6（提示）、11（檢查） |
| §2.7 brief 範本審查欄 | 2 |
| §2.8 角色 group: | 2 |
| §3.1 dk-brief-check / wave-open / review-pack / review / layout.sh | 3 / 7 / 8 / 9 / 5+10 |
| §3.2 task-new / spawn / wave-close / watch / resume / task-close | 4 / 6 / 10+11 / 12 / 13 / 4 |
| §4 一波流程與錯誤處理 | 14（LEADER.md） |
| §5 文件與 skill | 14 |
| §6 多人版面 | 5、6、10 |
| §7 測試策略層 1 | 每任務；層 2 | 15；層 4 | 14（RUNBOOK） |
| §9 相容性 | 1（缺檔預設）、4（legacy task-close）、11（legacy wave-close）、5（兩欄 .panes） |
| §10 待驗證假設 | 15（NOTE）、Global Constraints（schema 已確認的形狀） |

與規格的三處刻意偏差（都寫在 Global Constraints）：`DK_TABS` 用 `<tab_no>=<tab_id>`；切片與報告檔名用 state 名而非 agent 名；wave-close 的 (a) 接受任何 `review N skipped:` 行（不只審查欄為 skip 時），因為「全部熔斷」也走這條。另：規格未指定誰關逾時 reviewer 的 pane，本計畫給 `dk-wave-close --agent`。
