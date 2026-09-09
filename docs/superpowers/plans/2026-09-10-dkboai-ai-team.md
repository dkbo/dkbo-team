# dkboai AI Team Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the portable `dkboai/` package: markdown rules plus thin bash scripts that let a Claude Code leader in a herdr pane dispatch, coordinate and close out waves of claude / codex / agy employees, with all memory persisted as small markdown files.

**Architecture:** Everything deterministic lives in `dkboai/bin/*` (bash, sourcing `dkboai/lib/*.sh`), which wrap the `herdr` CLI and read/write the task folder. Everything judgemental lives in markdown (`LEADER.md`, `PROTOCOL.md`, `roles/*.md`) that the agents read. Tests run the scripts against a fake `herdr` stub on `PATH`; real-herdr and real-agent checks are separate scripted layers.

**Tech Stack:** bash 5, jq 1.7, git 2.43, herdr 0.9.0 CLI, bats-core (vendored under `tests/lib/bats-core`), Claude Code / Codex CLI / Antigravity CLI (`agy`).

**Spec:** `docs/superpowers/specs/2026-09-09-dkboai-ai-team-design.md`

## Global Constraints

- All scripts are bash with `set -euo pipefail`; no node/python runtime dependency in `dkboai/`.
- herdr agent names must match `[a-z][a-z0-9_-]{0,31}` and be unique among live agents.
- Employee agent name: `<short>-<role>[-<alias>]`; state file name: `<role>[-<alias>].md`; leader: `leader-<short>`; chore agent: `chore-<role>-<n>`.
- Task short name: ascii lowercase, ≤12 chars. Task folder: `dkboai/tasks/<yyyy-mm-dd>-<short>/`. Branch: `dk/<short>`. Chore branch: `chore/<name>`.
- Task memory lives in the main working tree under `dkboai/tasks/`, never inside the worktree. Employees receive `DK_TASK_DIR` as an absolute path.
- Message body ≤200 characters or `dk-msg` refuses. Messages to the leader are one header line.
- `dk-msg` waits for the target to be `idle`/`done` (timeout 300000 ms) before sending; on failure it logs `[UNDELIVERED]` and exits non-zero.
- Fix loop cap: one `FIXED` per bug, then `ESCALATE`. `QUESTION` cap: two per pair per wave. These are protocol rules in markdown, not enforced by scripts.
- `state/<agent>.md` ≤20 lines (warn only). `PROJECT.md` ≤40 lines. `dk-resume` output ≤150 lines.
- claude tiers use only `opus`/`sonnet` and effort `low|medium|high`.
- Leader never writes code or produces content; scripts never write `process.md` on behalf of employees.
- Employees are forbidden from using subagents (stated in the first prompt and in `PROTOCOL.md`).
- Spec addendum locked here: each task folder also holds `.task.env` (machine-readable: `DK_SHORT`, `DK_DISPLAY`, `DK_BRANCH`, `DK_WORKTREE`, `DK_WORKSPACE`, `DK_ROOT_PANE`, `DK_WATCH_PID`). It is committed with the task folder; `dkboai/.sessions/` is gitignored.
- Commit after every task with the trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

---

## File Structure

```
dkboai/
├── ENTRY.md  LEADER.md  PROTOCOL.md  PROJECT.md  README.md  decisions.md
├── install.sh                 # symlinks + AGENTS.md/CLAUDE.md lines into a target project
├── lib/
│   ├── common.sh              # DK_ROOT, die/now/slug, task binding, process append, herdr JSON helpers
│   ├── frontmatter.sh         # dk_fm / dk_fm_tier: YAML-ish frontmatter readers for roles
│   └── kinds.sh               # dk_kind_load / dk_kind_args: tier "model/effort" → CLI flags
├── kinds/ claude.sh codex.sh agy.sh
├── roles/ README.md pm.md frontend.md backend.md qa.md it.md reviewer.md
├── templates/ brief.md process.md state.md report.md chore.md task.env
├── skills/ init/SKILL.md  add-role/SKILL.md
├── bin/ dk-whoami dk-task-new dk-leader dk-spawn dk-msg dk-wave-close dk-watch dk-resume dk-chore dk-task-close
├── tasks/ INDEX.md BACKLOG.md _chores/.gitkeep
└── .sessions/.gitkeep
tests/
├── run.sh                     # bootstraps bats-core if missing, runs tests/unit
├── helpers.bash               # temp project fixture, PATH with stub, env
├── stub/herdr                 # fake herdr: logs calls, returns canned JSON, overridable per test
├── unit/*.bats
├── integration/herdr-real.sh  # layer 2: real herdr in named session `dktest`
├── smoke/kind-smoke.sh        # layer 3: one real agent per kind
└── e2e/RUNBOOK.md             # layer 4: manual run against example/
example/                       # tiny node app used by layer 4
```

Responsibilities: `lib/common.sh` owns paths and herdr plumbing; each `bin/dk-*` owns exactly one lifecycle action; markdown files own all judgement rules.

---

### Task 0: Repo scaffold and test harness

**Files:**
- Create: `dkboai/.sessions/.gitkeep`, `dkboai/tasks/_chores/.gitkeep`, `dkboai/tasks/INDEX.md`, `dkboai/tasks/BACKLOG.md`, `dkboai/decisions.md`
- Create: `tests/run.sh`, `tests/helpers.bash`, `tests/stub/herdr`, `tests/stub/responses/*.json`, `tests/unit/00_harness.bats`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `tests/helpers.bash` exporting `setup_project` (creates `$PROJECT` temp dir with a copy of `dkboai/`, a git repo with one commit and a local user identity, stub `herdr` first on `PATH`, `DK_NO_WATCH=1`, `HERDR_ENV=1`, `HERDR_PANE_ID=wB:p1`, `HERDR_WORKSPACE_ID=wB`, `HERDR_TAB_ID=wB:t1`) and `stub_calls` (prints the stub call log). Stub reads `$HERDR_STUB_RESPONSES/<cmd>_<sub>.json` (e.g. `pane_split.json`); tests override by writing a file there. Stub honours `HERDR_STUB_FAIL="<cmd> <sub>"` to return exit 1 with `{"error":{"code":"stubbed_failure"}}` on stderr.

- [ ] **Step 1: Write `.gitignore` and empty memory files**

```bash
cat > .gitignore <<'G'
dkboai/.sessions/*
!dkboai/.sessions/.gitkeep
tests/lib/
example/node_modules/
G
mkdir -p dkboai/.sessions dkboai/tasks/_chores
touch dkboai/.sessions/.gitkeep dkboai/tasks/_chores/.gitkeep
printf '| 日期 | 名稱 | 型態 | 狀態 | 一句結論 |\n|---|---|---|---|---|\n' > dkboai/tasks/INDEX.md
printf '| 日期 | 來源 | 一句描述 | 建議處理 |\n|---|---|---|---|\n' > dkboai/tasks/BACKLOG.md
printf '# 決策紀錄（跨任務，一行一則，只寫會影響未來的）\n' > dkboai/decisions.md
```

- [ ] **Step 2: Write the herdr stub**

`tests/stub/herdr`:

```bash
#!/usr/bin/env bash
# Fake herdr. Logs every call; answers from canned JSON files.
set -uo pipefail
log="${HERDR_STUB_LOG:?}"
printf '%s\n' "$*" >> "$log"
cmd="${1:-}"; sub="${2:-}"
key="${cmd}_${sub}"
if [ "${HERDR_STUB_FAIL:-}" = "$cmd $sub" ]; then
  echo '{"error":{"code":"stubbed_failure"}}' >&2; exit 1
fi
f="${HERDR_STUB_RESPONSES:?}/${key}.json"
if [ -f "$f" ]; then cat "$f"; else echo "{\"id\":\"cli:$cmd:$sub\",\"result\":{}}"; fi
```

`tests/stub/responses/pane_split.json`:
```json
{"id":"cli:pane:split","result":{"pane":{"pane_id":"wC:p2","tab_id":"wC:t1","workspace_id":"wC"}}}
```
`tests/stub/responses/worktree_create.json`:
```json
{"id":"cli:worktree:create","result":{"workspace":{"workspace_id":"wC"},"tab":{"tab_id":"wC:t1"},"root_pane":{"pane_id":"wC:p1"},"path":"__WORKTREE__"}}
```
`tests/stub/responses/agent_list.json`:
```json
{"id":"cli:agent:list","result":{"agents":[{"agent":"claude","name":"leader-login","agent_status":"idle","pane_id":"wB:p1"},{"agent":"claude","name":"login-frontend","agent_status":"working","pane_id":"wC:p2"},{"agent":"claude","name":"login-qa","agent_status":"blocked","pane_id":"wC:p3"}]}}
```
`tests/stub/responses/agent_get.json`:
```json
{"id":"cli:agent:get","result":{"agent":{"agent":"claude","name":"login-frontend","agent_status":"idle","pane_id":"wC:p2"}}}
```
`tests/stub/responses/agent_start.json`:
```json
{"id":"cli:agent:start","result":{"agent":{"name":"login-frontend","agent_status":"idle","pane_id":"wC:p2"}}}
```
`tests/stub/responses/agent_wait.json`:
```json
{"id":"cli:agent:wait","result":{"agent_status":"idle"}}
```
`tests/stub/responses/pane_current.json`:
```json
{"id":"cli:pane:current","result":{"pane":{"pane_id":"wB:p1","workspace_id":"wB","tab_id":"wB:t1","cwd":"__PROJECT__"}}}
```

Note: `__WORKTREE__` and `__PROJECT__` are literal placeholders the helper replaces per fixture (Step 3).

- [ ] **Step 3: Write `tests/helpers.bash`**

```bash
# shellcheck shell=bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

setup_project() {
  PROJECT="$(mktemp -d)"
  cp -r "$REPO_ROOT/dkboai" "$PROJECT/dkboai"
  chmod +x "$PROJECT"/dkboai/bin/* 2>/dev/null || true
  git -C "$PROJECT" init -q
  git -C "$PROJECT" config user.name t; git -C "$PROJECT" config user.email t@t
  git -C "$PROJECT" commit -q --allow-empty -m init
  git -C "$PROJECT" branch -M main
  HERDR_STUB_LOG="$PROJECT/.herdr-calls.log"; : > "$HERDR_STUB_LOG"
  HERDR_STUB_RESPONSES="$PROJECT/.herdr-responses"
  cp -r "$REPO_ROOT/tests/stub/responses" "$HERDR_STUB_RESPONSES"
  WORKTREE_PATH="$PROJECT/.worktrees/login"
  sed -i "s#__WORKTREE__#$WORKTREE_PATH#; s#__PROJECT__#$PROJECT#" "$HERDR_STUB_RESPONSES"/*.json
  export HERDR_STUB_LOG HERDR_STUB_RESPONSES PROJECT WORKTREE_PATH
  export PATH="$REPO_ROOT/tests/stub:$PROJECT/dkboai/bin:$PATH"
  export HERDR_ENV=1 HERDR_PANE_ID=wB:p1 HERDR_WORKSPACE_ID=wB HERDR_TAB_ID=wB:t1
  export DK_ROOT="$PROJECT/dkboai"
  export DK_NO_WATCH=1   # unit tests do not launch the background watcher (Task 9 has one test that unsets this)
  unset DK_TASK_DIR DK_ROLE DK_AGENT DK_LEADER DK_ISOLATED
  cd "$PROJECT"
}
teardown_project() { rm -rf "$PROJECT"; }
stub_calls() { cat "$HERDR_STUB_LOG"; }
# Make a bound task quickly without dk-task-new (for tests of later scripts).
fixture_task() { # $1=short $2=display
  local d="$DK_ROOT/tasks/$(date +%Y-%m-%d)-$1"
  mkdir -p "$d/state"
  sed -e "s#{{DISPLAY}}#$2#g; s#{{SHORT}}#$1#g; s#{{BRANCH}}#dk/$1#g; s#{{WORKTREE}}#$WORKTREE_PATH#g; s#{{SOURCE}}#test#g" \
    "$DK_ROOT/templates/brief.md" > "$d/brief.md"
  : > "$d/process.md"; : > "$d/messages.log"; : > "$d/.panes"
  cat > "$d/.task.env" <<E
DK_SHORT=$1
DK_DISPLAY=$2
DK_BRANCH=dk/$1
DK_WORKTREE=$WORKTREE_PATH
DK_WORKSPACE=wC
DK_ROOT_PANE=wC:p1
DK_WATCH_PID=
E
  mkdir -p "$WORKTREE_PATH"
  echo "$(basename "$d")" > "$DK_ROOT/.sessions/$HERDR_PANE_ID"
  echo "$d"
}
```

- [ ] **Step 4: Write `tests/run.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -x tests/lib/bats-core/bin/bats ]; then
  git clone -q --depth 1 https://github.com/bats-core/bats-core tests/lib/bats-core
fi
chmod +x tests/stub/herdr dkboai/bin/* 2>/dev/null || true
exec tests/lib/bats-core/bin/bats "${@:-tests/unit}"
```

- [ ] **Step 5: Write the harness self-test `tests/unit/00_harness.bats`**

```bash
load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "stub herdr logs calls and returns canned json" {
  run herdr pane split --current --direction right
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.result.pane.pane_id == "wC:p2"'
  grep -q '^pane split --current --direction right$' "$HERDR_STUB_LOG"
}

@test "stub herdr can be told to fail" {
  HERDR_STUB_FAIL="agent start" run herdr agent start x --kind claude --pane wC:p2
  [ "$status" -eq 1 ]
}
```

- [ ] **Step 6: Run the harness**

Run: `chmod +x tests/run.sh tests/stub/herdr && tests/run.sh`
Expected: `2 tests, 0 failures`

- [ ] **Step 7: Commit**

```bash
git add .gitignore dkboai tests
git commit -m "test: bats harness with fake herdr stub

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 1: `lib/common.sh` and `lib/frontmatter.sh`

**Files:**
- Create: `dkboai/lib/common.sh`, `dkboai/lib/frontmatter.sh`
- Test: `tests/unit/01_common.bats`

**Interfaces:**
- Produces (`common.sh`): `DK_ROOT`, `DK_PROJECT_ROOT`; `dk_die MSG` (stderr, exit 1); `dk_now` (`YYYY-MM-DDTHH:MM`); `dk_today`; `dk_slug STR` (herdr-safe ≤32); `dk_require_herdr`; `dk_task_dir` (echo absolute task dir from `DK_TASK_DIR` or `.sessions/$HERDR_PANE_ID`, die if none); `dk_task_env` (source `.task.env`, exports `DK_SHORT DK_DISPLAY DK_BRANCH DK_WORKTREE DK_WORKSPACE DK_ROOT_PANE DK_WATCH_PID`); `dk_process LINE` (append `now LINE` to process.md); `dk_leader_name` (`leader-$DK_SHORT`); `dk_agent_name ROLE [ALIAS]` (`$DK_SHORT-role[-alias]`); `dk_state_name ROLE [ALIAS]` (`role[-alias]`); `dk_json` (`jq -r "$1"` on stdin); `dk_index_add DATE NAME TYPE STATUS NOTE`; `dk_index_set NAME STATUS NOTE`.
- Produces (`frontmatter.sh`): `dk_fm FILE KEY` (top-level scalar), `dk_fm_tier FILE S|M|L` (value under `tiers:`), `dk_fm_list FILE KEY` (inline `[a, b]` → lines).

- [ ] **Step 1: Write failing tests**

`tests/unit/01_common.bats`:
```bash
load ../helpers
setup() { setup_project; . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/frontmatter.sh"; }
teardown() { teardown_project; }

@test "dk_slug makes herdr-safe names" {
  [ "$(dk_slug 'Login/Page Cart')" = "login-page-cart" ]
  [ "$(dk_slug '123abc')" = "abc" ]
  [ "$(dk_slug "$(printf 'a%.0s' {1..40})")" = "$(printf 'a%.0s' {1..32})" ]
}

@test "dk_task_dir dies when unbound" {
  run dk_task_dir
  [ "$status" -eq 1 ]; [[ "$output" == *"no task bound"* ]]
}

@test "dk_task_dir resolves .sessions binding and env" {
  d=$(fixture_task login 使用者登入)
  [ "$(dk_task_dir)" = "$d" ]
  dk_task_env
  [ "$DK_SHORT" = login ]; [ "$(dk_leader_name)" = leader-login ]
  [ "$(dk_agent_name frontend cart)" = login-frontend-cart ]
  [ "$(dk_state_name frontend cart)" = frontend-cart ]
  [ "$(dk_agent_name qa)" = login-qa ]
}

@test "dk_process appends timestamped line" {
  d=$(fixture_task login x); dk_process "wave1 start"
  grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2} wave1 start$' "$d/process.md"
}

@test "index add and set" {
  dk_index_add 2026-09-10 使用者登入 task planning —
  grep -q '| 2026-09-10 | 使用者登入 | task | planning | — |' "$DK_ROOT/tasks/INDEX.md"
  dk_index_set 使用者登入 done "merged abc123"
  grep -q '| 使用者登入 | task | done | merged abc123 |' "$DK_ROOT/tasks/INDEX.md"
}

@test "frontmatter readers" {
  cat > "$PROJECT/r.md" <<'R'
---
name: frontend
kind: claude
tiers:
  S: sonnet/low
  M: sonnet/medium
  L: opus/high
worktree: true
mcp: [playwright, github]
---
body
R
  [ "$(dk_fm "$PROJECT/r.md" kind)" = claude ]
  [ "$(dk_fm_tier "$PROJECT/r.md" L)" = opus/high ]
  [ "$(dk_fm_list "$PROJECT/r.md" mcp | tr '\n' ' ')" = "playwright github " ]
  [ -z "$(dk_fm "$PROJECT/r.md" missing)" ]
}
```

- [ ] **Step 2: Run to verify failure**

Run: `tests/run.sh tests/unit/01_common.bats`
Expected: FAIL (`No such file` for lib/common.sh)

- [ ] **Step 3: Implement `dkboai/lib/common.sh`**

```bash
# shellcheck shell=bash
# Shared helpers for dkboai bin scripts. Source, do not execute.
set -euo pipefail
DK_ROOT="${DK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DK_PROJECT_ROOT="${DK_PROJECT_ROOT:-$(dirname "$DK_ROOT")}"
export DK_ROOT DK_PROJECT_ROOT

dk_die() { echo "dk: $*" >&2; exit 1; }
dk_now() { date +%Y-%m-%dT%H:%M; }
dk_today() { date +%Y-%m-%d; }
dk_slug() {
  local s
  s=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_-]+/-/g; s/^[^a-z]+//; s/-{2,}/-/g; s/-$//')
  printf '%s' "${s:0:32}"
}
dk_require_herdr() { [ "${HERDR_ENV:-}" = 1 ] || dk_die "not running inside herdr (HERDR_ENV!=1)"; }
dk_json() { jq -r "$1"; }

dk_task_dir() {
  if [ -n "${DK_TASK_DIR:-}" ]; then echo "$DK_TASK_DIR"; return; fi
  local f="$DK_ROOT/.sessions/${HERDR_PANE_ID:-none}"
  [ -f "$f" ] || dk_die "no task bound to this pane; run dk-task-new or dk-resume <task>"
  echo "$DK_ROOT/tasks/$(cat "$f")"
}
dk_task_env() {
  local d; d=$(dk_task_dir)
  # shellcheck disable=SC1091
  set -a; . "$d/.task.env"; set +a
}
dk_process() { echo "$(dk_now) $*" >> "$(dk_task_dir)/process.md"; }
dk_leader_name() { echo "leader-${DK_SHORT:?}"; }
dk_agent_name() { local n="${DK_SHORT:?}-$1"; [ -n "${2:-}" ] && n="$n-$2"; echo "$n"; }
dk_state_name() { local n="$1"; [ -n "${2:-}" ] && n="$n-$2"; echo "$n"; }

dk_index_add() { printf '| %s | %s | %s | %s | %s |\n' "$1" "$2" "$3" "$4" "$5" >> "$DK_ROOT/tasks/INDEX.md"; }
dk_index_set() { # NAME STATUS NOTE  — rewrite the row whose name column matches
  local name="$1" status="$2" note="$3" f="$DK_ROOT/tasks/INDEX.md"
  awk -F'|' -v n="$name" -v s="$status" -v o="$note" 'BEGIN{OFS="|"}
    { if ($3 == " " n " ") { $5=" " s " "; $6=" " o " " } print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}
```

- [ ] **Step 4: Implement `dkboai/lib/frontmatter.sh`**

```bash
# shellcheck shell=bash
# Minimal frontmatter readers for roles/*.md. Only the shapes dkboai writes.
dk__fm_block() { awk 'NR==1 && $0!="---"{exit} /^---$/{c++; next} c==1{print} c>=2{exit}' "$1"; }
dk_fm() { dk__fm_block "$1" | awk -v k="$2" -F': *' '$1==k {sub(/^[^:]*: */,""); print; exit}'; }
dk_fm_tier() { dk__fm_block "$1" | awk -v k="$2" '/^tiers:/{t=1;next} t && /^[^ ]/{t=0} t && $1==k":" {print $2; exit}'; }
dk_fm_list() { dk_fm "$1" "$2" | tr -d '[]' | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$' || true; }
```

- [ ] **Step 5: Run tests**

Run: `tests/run.sh tests/unit/01_common.bats`
Expected: `6 tests, 0 failures`

- [ ] **Step 6: Commit**

```bash
git add dkboai/lib tests/unit/01_common.bats
git commit -m "feat(lib): common helpers and frontmatter readers

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: `dk-whoami` and `ENTRY.md`

**Files:**
- Create: `dkboai/bin/dk-whoami`, `dkboai/ENTRY.md`
- Test: `tests/unit/02_whoami.bats`

**Interfaces:**
- Produces: `dk-whoami` prints exactly one line: `leader` or `employee <role> <agent> <task_dir>`; exit 0 either way. Later `dk-spawn` sets `DK_ROLE`, `DK_AGENT`, `DK_TASK_DIR` so this works.

- [ ] **Step 1: Failing test**

```bash
load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "whoami: leader when DK_ROLE unset" {
  run dk-whoami; [ "$status" -eq 0 ]; [ "$output" = "leader" ]
}
@test "whoami: employee with role/agent/task" {
  DK_ROLE=frontend DK_AGENT=login-frontend DK_TASK_DIR=/t run dk-whoami
  [ "$output" = "employee frontend login-frontend /t" ]
}
```

- [ ] **Step 2: Run** → FAIL (`dk-whoami: command not found`)

- [ ] **Step 3: Implement `dkboai/bin/dk-whoami`**

```bash
#!/usr/bin/env bash
# Prints who this pane is: "leader" or "employee <role> <agent> <task_dir>".
set -euo pipefail
if [ -n "${DK_ROLE:-}" ]; then
  echo "employee ${DK_ROLE} ${DK_AGENT:-?} ${DK_TASK_DIR:-?}"
else
  echo "leader"
fi
```

- [ ] **Step 4: Write `dkboai/ENTRY.md`**

```markdown
# dkboai 入口

執行 `dkboai/bin/dk-whoami`。

- 輸出 `leader` → 讀 `dkboai/LEADER.md`，照它行事。
- 輸出 `employee <角色> <名字> <任務目錄>` → 讀 `$DK_ROOT/roles/<角色>.md` 與 `$DK_ROOT/PROTOCOL.md`（`DK_ROOT` 是你 pane 的環境變數，指向主工作樹的 dkboai/），照它們行事。你不是領導。

不要同時讀兩者。
```

- [ ] **Step 5: Run** → `2 tests, 0 failures`

- [ ] **Step 6: Commit**

```bash
git add dkboai/bin/dk-whoami dkboai/ENTRY.md tests/unit/02_whoami.bats
git commit -m "feat: dk-whoami and ENTRY.md

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: `kinds/*.sh` and `lib/kinds.sh`

**Files:**
- Create: `dkboai/kinds/claude.sh`, `dkboai/kinds/codex.sh`, `dkboai/kinds/agy.sh`, `dkboai/lib/kinds.sh`
- Test: `tests/unit/03_kinds.bats`

**Interfaces:**
- Each `kinds/<kind>.sh` defines: `KIND_MODELS` (space list), `KIND_EFFORTS` (space list), `KIND_DEFAULT_TIERS` (`S=model/effort M=... L=...`), `kind_args MODEL EFFORT` (prints flags for after `agent start ... --`), `kind_mcp_list` (prints configured MCP server names, one per line, or nothing), `KIND_PROMPT_QUEUES` (`yes|no|unknown`, updated by layer 3).
- `lib/kinds.sh` provides: `dk_kind_load KIND` (source the file, die if missing); `dk_kind_args KIND "model/effort"` (validates against lists, prints flags); `dk_kinds_available` (prints kinds that are in `herdr agent start --help`, on `PATH`, and have a kinds file).

- [ ] **Step 1: Failing test**

```bash
load ../helpers
setup() { setup_project; . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/kinds.sh"; }
teardown() { teardown_project; }

@test "claude tier to args" {
  [ "$(dk_kind_args claude sonnet/low)" = "--model sonnet --effort low --permission-mode acceptEdits" ]
}
@test "codex tier to args" {
  [ "$(dk_kind_args codex gpt-5.5/medium)" = "-m gpt-5.5 -c model_reasoning_effort=medium -a never -s workspace-write" ]
}
@test "agy tier to args" {
  [ "$(dk_kind_args agy gemini-3.1-pro/high)" = "--model gemini-3.1-pro-high --mode accept-edits" ]
}
@test "rejects unknown model or effort" {
  run dk_kind_args claude haiku/low; [ "$status" -eq 1 ]
  run dk_kind_args claude opus/max;  [ "$status" -eq 1 ]
}
@test "available kinds intersects help, PATH and kinds dir" {
  mkdir -p "$PROJECT/fakebin"; printf '#!/bin/sh\n' > "$PROJECT/fakebin/claude"; chmod +x "$PROJECT/fakebin/claude"
  echo '[possible values: pi, claude, codex, agy]' > "$HERDR_STUB_RESPONSES/agent_start.json"
  PATH="$PROJECT/fakebin:$REPO_ROOT/tests/stub:/usr/bin:/bin" run dk_kinds_available
  [ "$output" = "claude" ]
}
```

- [ ] **Step 2: Run** → FAIL

- [ ] **Step 3: Implement kinds files**

`dkboai/kinds/claude.sh`:
```bash
# shellcheck shell=bash
KIND_MODELS="opus sonnet"
KIND_EFFORTS="low medium high"
KIND_DEFAULT_TIERS="S=sonnet/low M=sonnet/medium L=opus/high"
KIND_PROMPT_QUEUES=unknown   # layer-3 smoke updates this: does a prompt sent while working queue?
kind_args() { echo "--model $1 --effort $2 --permission-mode acceptEdits"; }
kind_mcp_list() { claude mcp list 2>/dev/null | awk -F: 'NF>1{print $1}'; }
```
`dkboai/kinds/codex.sh`:
```bash
# shellcheck shell=bash
KIND_MODELS="gpt-5.5"
KIND_EFFORTS="low medium high"
KIND_DEFAULT_TIERS="S=gpt-5.5/low M=gpt-5.5/medium L=gpt-5.5/high"
KIND_PROMPT_QUEUES=unknown
kind_args() { echo "-m $1 -c model_reasoning_effort=$2 -a never -s workspace-write"; }
kind_mcp_list() { codex mcp list 2>/dev/null | awk 'NR>1{print $1}'; }
```
`dkboai/kinds/agy.sh`:
```bash
# shellcheck shell=bash
# agy model ids embed the effort suffix: gemini-3.1-pro-high
KIND_MODELS="gemini-3.1-pro gemini-3.8-flash"
KIND_EFFORTS="low medium high"
KIND_DEFAULT_TIERS="S=gemini-3.8-flash/low M=gemini-3.8-flash/medium L=gemini-3.1-pro/high"
KIND_PROMPT_QUEUES=unknown
kind_args() { echo "--model $1-$2 --mode accept-edits"; }
kind_mcp_list() { agy mcp list 2>/dev/null | awk 'NR>1{print $1}'; }
```

- [ ] **Step 4: Implement `dkboai/lib/kinds.sh`**

```bash
# shellcheck shell=bash
dk_kind_load() {
  local f="$DK_ROOT/kinds/$1.sh"; [ -f "$f" ] || dk_die "unknown kind: $1 (no $f)"
  # shellcheck disable=SC1090
  . "$f"
}
dk_kind_args() { # KIND model/effort
  local kind="$1" model="${2%%/*}" effort="${2##*/}"
  dk_kind_load "$kind"
  [[ " $KIND_MODELS " == *" $model "* ]]  || dk_die "kind $kind: unknown model '$model' (allowed: $KIND_MODELS)"
  [[ " $KIND_EFFORTS " == *" $effort "* ]] || dk_die "kind $kind: unknown effort '$effort' (allowed: $KIND_EFFORTS)"
  kind_args "$model" "$effort"
}
dk_kinds_available() {
  local supported k
  supported=$(herdr agent start --help 2>&1 | sed -n 's/.*possible values: \(.*\)\].*/\1/p' | tr -d ',')
  for k in $supported; do
    [ -f "$DK_ROOT/kinds/$k.sh" ] || continue
    command -v "$k" >/dev/null 2>&1 || continue
    echo "$k"
  done
}
```

- [ ] **Step 5: Run** → `5 tests, 0 failures`

- [ ] **Step 6: Commit**

```bash
git add dkboai/kinds dkboai/lib/kinds.sh tests/unit/03_kinds.bats
git commit -m "feat(kinds): claude/codex/agy flag mapping

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Rule documents, roles and templates

**Files:**
- Create: `dkboai/LEADER.md`, `dkboai/PROTOCOL.md`, `dkboai/PROJECT.md`, `dkboai/README.md`
- Create: `dkboai/roles/README.md`, `dkboai/roles/{pm,frontend,backend,qa,it,reviewer}.md`
- Create: `dkboai/templates/{brief.md,process.md,state.md,report.md,chore.md,task.env}`
- Test: `tests/unit/04_docs.bats`

**Interfaces:**
- Produces: every role file has frontmatter keys `name kind tiers.S tiers.M tiers.L worktree split mcp`, readable by `dk_fm`/`dk_fm_tier`. Templates contain tokens `{{DISPLAY}} {{SHORT}} {{BRANCH}} {{WORKTREE}} {{SOURCE}} {{DATE}}` that `dk-task-new` substitutes with `sed`.

- [ ] **Step 1: Failing test**

```bash
load ../helpers
setup() { setup_project; . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/frontmatter.sh"; }
teardown() { teardown_project; }

@test "all six roles have complete frontmatter with valid tiers" {
  for r in pm frontend backend qa it reviewer; do
    f="$DK_ROOT/roles/$r.md"; [ -f "$f" ]
    [ "$(dk_fm "$f" name)" = "$r" ]
    [ "$(dk_fm "$f" kind)" = claude ]
    for t in M L; do
      v=$(dk_fm_tier "$f" $t); [[ "$v" =~ ^(opus|sonnet)/(low|medium|high)$ ]]
    done
    [[ "$(dk_fm "$f" worktree)" =~ ^(true|false)$ ]]
  done
  [ -z "$(dk_fm_tier "$DK_ROOT/roles/reviewer.md" S)" ]
}
@test "docs exist and are short" {
  for f in LEADER.md PROTOCOL.md PROJECT.md ENTRY.md README.md roles/README.md; do [ -f "$DK_ROOT/$f" ]; done
  [ "$(wc -l < "$DK_ROOT/PROJECT.md")" -le 40 ]
  [ "$(wc -l < "$DK_ROOT/LEADER.md")" -le 120 ]
  [ "$(wc -l < "$DK_ROOT/PROTOCOL.md")" -le 120 ]
}
@test "templates carry substitution tokens" {
  grep -q '{{DISPLAY}}' "$DK_ROOT/templates/brief.md"
  grep -q '{{BRANCH}}' "$DK_ROOT/templates/brief.md"
  grep -q 'DK_SHORT={{SHORT}}' "$DK_ROOT/templates/task.env"
  grep -q '^status:' "$DK_ROOT/templates/state.md"
}
```

- [ ] **Step 2: Run** → FAIL

- [ ] **Step 3: Write `dkboai/LEADER.md`**

```markdown
# 領導規範

你是這個任務的領導。你不寫程式、不改業務檔案、不親自翻譯或畫圖。所有產出都派員工。你只做：讀需求、寫 brief、拆波、派工、處理 ESCALATE、決策、寫記憶檔、每波 commit、結案合併。

## 每次醒來先做
1. 若不確定狀態：執行 `dkboai/bin/dk-resume`，讀完再行動。
2. 讀 `dkboai/PROTOCOL.md`（訊息格式與升報規則）。

## 收到人的請求時分流
- 是進行中任務的一部分 → 調波次表（記 process.md），不改 brief 的需求與驗收。
- 獨立、不改程式（翻譯、畫圖、整理） → `dk-chore <角色> "<交代>"`。
- 獨立、改程式、範圍小 → 先評估：涉及檔案、是否落在在線成員所有權內、嚴重度。給三選一附建議：立刻修（`dk-chore <角色> --code`）/ 併入當前任務 / 延後進 `tasks/BACKLOG.md`。人選後執行；人說「照建議」就直接做。
- 範圍大 → 建議開新任務，問人。
- 角色檔不存在 → 先用 add-role skill 建立，再派工。不用通用員工矇混。

## 開任務
1. `dk-task-new <short> "<顯示名>" [--from <plan.md>]`。
2. 寫 `brief.md`：目標 ≤3 行、驗收標準、檔案所有權（成員範圍不得重疊）、共用契約擁有者、波次表（每列標難度 S/M/L）。有 plan 檔時不重寫內容，只對應驗收、劃所有權、把 task 分組成波。
3. 關卡①：把 brief 給人確認。人點頭後 `dk-process "gate1 approved"`（`dk-task-new --gate1` 會改 INDEX 為 running）。

## 跑一波
1. 對波次表每位成員 `dk-spawn <角色> [別名] [--tier S|M|L] [--kind K] [--isolated]`。
2. 結束這個 turn，閒置。員工訊息與人的輸入會自己推進來。不輪詢、不主動讀員工終端。
3. 收到 `[DONE]`：確認 state 檔 `status: done`。收到 `[ESCALATE]`：能依 brief 判定就 `dk-msg <員工> "[DECISION] ..."` 並 `dk-process`；不能就問人（關卡②），得到答案後回 DECISION 並在 `decisions.md` 加一行。收到 `[BLOCKED]`：告知人去按審批。
4. 全員 DONE → `dk-wave-close`。看它的越界與超限警告。然後在 worktree 內 `git add -A && git commit -m "wave N: ..."`。
5. 處理完一批訊息後 `dk-msg --ack`。
6. 依結果增刪下一波，記 process。

## 評議波
第一輪 `dk-spawn reviewer a --isolated --kind claude`、`... b --kind codex`、`... c --kind agy`，各自寫意見到 state。全部 DONE 後第二輪對每人 `dk-msg` 其他兩人的 state 路徑，每人只准一則反駁。你決策，寫進 process.md 與 decisions.md。

## 結案
1. 寫 `report.md`（照範本）。關卡③：給人拍板。
2. `dk-task-close`。合併衝突時它會停：不要自己解，問人或開 `it` 的修復波。放棄用 `dk-task-close --abandon "<原因>"`。

## 故障
- 員工 `[ESCALATE] context` 或 pane 掛掉：`dk-spawn` 同角色同別名 `--resume`，提示會叫他從 state 續作。
- 自己上下文吃緊：`/clear` 後執行 `dk-resume`。
```

- [ ] **Step 4: Write `dkboai/PROTOCOL.md`**

```markdown
# 通訊協定

所有訊息一律用 `dkboai/bin/dk-msg <對象> "[類型] 內文"`。腳本補寄件人、時間，寫進 messages.log，並等對方閒置才送。內文一到三句、≤200 字元，細節寫在你的 state 檔並指路，不貼程式碼。對象可寫 `leader`，腳本會解析成本任務的領導。

## 類型
| 類型 | 方向 | 何時 |
|---|---|---|
| TASK | 領導→員工 | 補充派工 |
| DONE | 員工→領導 | 完成，且 state 已寫 `status: done` |
| BUG | 員工→員工 | 附重現方式，指向 state |
| FIXED | 員工→員工 | 修好了，請重驗 |
| QUESTION / ANSWER | 任意 | 釐清介面、契約 |
| ESCALATE | 員工→領導 | 需要決策、想動不屬於自己的檔、修一次未好、上下文吃緊（寫 `[ESCALATE] context`） |
| DECISION | 領導→員工 | 決策結果 |
| STOP | 領導→員工 | 停手，寫 state 收尾 |

## 規則
- 同一波員工可以互相傳訊。`DK_ISOLATED=1` 的員工只能對 leader 傳訊。
- 修復迴圈上限一次，以同一個 bug 計：BUG → FIXED → 再驗仍失敗 → qa 直接 ESCALATE，不再回 dev。
- QUESTION 若 brief 沒有答案，被問的人不得自己決定；提問者 ESCALATE。同一波同一對員工 QUESTION 最多兩則。
- 任何「選 A 或 B」、任何共用契約的變更，一律 ESCALATE。
- 只能修改 brief 檔案所有權劃給你的檔案。要動別人的檔 → 用 QUESTION 請擁有者改，或 ESCALATE。
- 禁止使用 subagent、禁止自行開 pane 或啟動其他 agent。
- 只有本人能寫自己的 state 檔；員工不寫 process.md、brief.md、report.md。
- dk-msg 回傳非零（對方卡住、送不進）：把這件事寫進 state 的 `blocked_by`，繼續做別的事。

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
notes: 給接手者的必要事實，≤5 行
```
DONE 前 `touched` 必須完整，領導會拿它比對所有權。
```

- [ ] **Step 5: Write `dkboai/PROJECT.md`, `dkboai/README.md`, `dkboai/roles/README.md`**

`PROJECT.md`:
```markdown
# 專案事實（≤40 行；由 init skill 預填，領導或 it 維護）
- 技術棧：
- 安裝 / 啟動：
- 測試指令：
- 目錄慣例：
- 已知坑：
```

`README.md`: one line for now — `# dkboai\n\n安裝與使用說明見 Task 14 完成後的版本。` (Task 14 replaces it with the full AI-installable README).

`roles/README.md`:
```markdown
# 團隊表
| 角色 | kind | S | M | L | 一句職責 |
|---|---|---|---|---|---|
| pm | claude | sonnet/low | sonnet/medium | opus/high | 需求釐成驗收標準，不寫碼 |
| frontend | claude | sonnet/low | sonnet/medium | opus/high | 介面實作 |
| backend | claude | sonnet/low | sonnet/medium | opus/high | API、資料層 |
| qa | claude | sonnet/low | sonnet/medium | sonnet/high | 依驗收標準驗證、送 BUG，自己不修 |
| it | claude | sonnet/low | sonnet/low | sonnet/medium | 環境、依賴、CI、合併衝突修復 |
| reviewer | claude | — | sonnet/medium | opus/high | 評議波用，只出意見不改碼 |
```

- [ ] **Step 6: Write the six role files**

`roles/frontend.md` (pattern for pm/backend with the tiers from the table):
```markdown
---
name: frontend
kind: claude
tiers:
  S: sonnet/low
  M: sonnet/medium
  L: opus/high
worktree: true
split: right
mcp: []
---
## 職責
實作 brief 劃給你的介面檔案。介面契約（API 型別、路徑）以 brief 的「共用契約」為準；契約不清楚就 QUESTION 擁有者，不自行假設。
## 完成定義
所有分給你的驗收項在本機可操作、相關測試通過、state 的 touched 完整、`status: done`。然後 `dk-msg <qa> "[DONE] ..."` 與 `dk-msg leader "[DONE] ..."`。
## 交接對象
qa 驗證；qa 的 BUG 修一次，再不過就由 qa 升報。
```

`roles/backend.md`: same frontmatter with `name: backend`, `split: down`; 職責「實作 API 與資料層；共用契約若由你擁有，先定稿再實作並通知 frontend」。

`roles/pm.md`: `name: pm`, `worktree: false`, `split: right`; 職責「把需求釐成可驗證的驗收標準與檔案所有權建議，寫到 state 的 notes 給領導；不寫碼」。完成定義「驗收標準每條可被 qa 直接驗證」。交接「領導」。

`roles/qa.md`:
```markdown
---
name: qa
kind: claude
tiers:
  S: sonnet/low
  M: sonnet/medium
  L: sonnet/high
worktree: true
split: down
mcp: []
---
## 職責
依 brief 驗收標準逐條驗證。發現問題 `dk-msg <dev> "[BUG] ..."`，重現步驟寫在 state。自己不修程式。
## 完成定義
所有驗收項通過，state 記錄每條的驗證方式，`status: done`，`dk-msg leader "[DONE] ..."`。
## 交接對象
dev 修；同一 bug FIXED 後再驗仍失敗 → `dk-msg leader "[ESCALATE] ..."`。
```

`roles/it.md`: tiers `S: sonnet/low M: sonnet/low L: sonnet/medium`, `worktree: true`, `split: down`; 職責「環境、依賴、CI、合併衝突修復；維護 PROJECT.md 的安裝與測試指令」。

`roles/reviewer.md`:
```markdown
---
name: reviewer
kind: claude
tiers:
  M: sonnet/medium
  L: opus/high
worktree: true
split: right
mcp: []
---
## 職責
針對 brief 指定的題目給出意見與理由，寫在 state 的 notes（≤15 行）。不改任何程式。第二輪收到其他 reviewer 的 state 路徑時，只准發一則反駁給對方。
## 完成定義
意見寫完，`status: done`，`dk-msg leader "[DONE] ..."`。
## 交接對象
領導決策。
```

- [ ] **Step 7: Write templates**

`templates/brief.md`:
```markdown
# {{DISPLAY}}
來源：{{SOURCE}}
分支：{{BRANCH}}   worktree：{{WORKTREE}}

## 目標（≤3 行）

## 驗收標準
- [ ] AC1

## 檔案所有權
| 成員 | 可改 | 只讀 |
|---|---|---|

## 共用契約
（誰定稿、放哪、變更流程）

## 波次表
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 |
|---|---|---|---|---|---|
```
`templates/process.md`: `{{DATE}} task-new {{SHORT}}` (single line).
`templates/state.md`:
```markdown
status: working
wave: 
current: 
touched:
todo:
notes: 
```
`templates/report.md`:
```markdown
# {{DISPLAY}} 結案
結果：merged | abandoned   分支：{{BRANCH}}   波數：
## 完成
## 未完成 / 遺留
## 驗證
## 重要決策
## 給下次的話（≤3 行）
```
`templates/chore.md`:
```markdown
交代：{{SOURCE}}
成員：{{AGENT}} ({{KIND}} / {{TIER}})
branch: {{BRANCH}}
status: working
touched:
結果：
```
`templates/task.env`:
```
DK_SHORT={{SHORT}}
DK_DISPLAY={{DISPLAY}}
DK_BRANCH={{BRANCH}}
DK_WORKTREE={{WORKTREE}}
DK_WORKSPACE={{WORKSPACE}}
DK_ROOT_PANE={{ROOT_PANE}}
DK_WATCH_PID=
```

- [ ] **Step 8: Run** → `3 tests, 0 failures`

- [ ] **Step 9: Commit**

```bash
git add dkboai
git commit -m "docs: leader/protocol rules, roles, templates

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: `dk-task-new`

**Files:**
- Create: `dkboai/bin/dk-task-new`
- Test: `tests/unit/05_task_new.bats`

**Interfaces:**
- Consumes: `lib/common.sh`, templates, stub responses `worktree_create`, `agent_get`, `agent_rename`.
- Produces: `dk-task-new <short> "<display>" [--from <plan>] [--no-worktree] [--gate1]`. Creates `tasks/<date>-<short>/{brief.md,process.md,messages.log,.task.env,state/}`, worktree via `herdr worktree create --branch dk/<short> --base <current branch> --cwd $DK_PROJECT_ROOT --no-focus` (unless `--no-worktree`), binds `.sessions/$HERDR_PANE_ID`, renames current agent to `leader-<short>` if unnamed, adds INDEX row `planning`, starts `dk-watch` in background (Task 9; here it only records the pid if the binary exists). `--gate1` on an existing task sets INDEX status `running` and appends `gate1 approved` to process. Prints the task dir.

- [ ] **Step 1: Failing test**

```bash
load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "task-new creates folder, env, worktree, binding, index, rename" {
  run dk-task-new login "使用者登入" --from docs/plan.md
  [ "$status" -eq 0 ]
  d="$DK_ROOT/tasks/$(date +%Y-%m-%d)-login"; [ "$output" = "$d" ]
  [ -f "$d/brief.md" ]; [ -f "$d/process.md" ]; [ -f "$d/messages.log" ]; [ -d "$d/state" ]; [ -f "$d/.panes" ]
  grep -q '^# 使用者登入$' "$d/brief.md"; grep -q 'docs/plan.md' "$d/brief.md"; grep -q 'dk/login' "$d/brief.md"
  grep -q '^DK_SHORT=login$' "$d/.task.env"; grep -q "^DK_WORKTREE=$WORKTREE_PATH$" "$d/.task.env"; grep -q '^DK_WORKSPACE=wC$' "$d/.task.env"
  [ "$(cat "$DK_ROOT/.sessions/wB:p1")" = "$(basename "$d")" ]
  grep -q '| 使用者登入 | task | planning |' "$DK_ROOT/tasks/INDEX.md"
  grep -q '^worktree create --branch dk/login --base main --cwd .* --no-focus$' "$HERDR_STUB_LOG"
  grep -q '^agent rename wB:p1 leader-login$' "$HERDR_STUB_LOG"
  grep -q 'task-new login' "$d/process.md"
}
@test "task-new rejects bad short names and duplicates" {
  run dk-task-new Login x; [ "$status" -eq 1 ]
  run dk-task-new averyveryverylongname x; [ "$status" -eq 1 ]
  dk-task-new login x >/dev/null
  run dk-task-new login x; [ "$status" -eq 1 ]
}
@test "task-new skips rename when agent already named" {
  echo '{"result":{"agent":{"name":"leader-login","agent_status":"idle","pane_id":"wB:p1"}}}' > "$HERDR_STUB_RESPONSES/agent_get.json"
  dk-task-new login x >/dev/null
  ! grep -q '^agent rename' "$HERDR_STUB_LOG"
}
@test "task-new --gate1 flips index to running" {
  dk-task-new login "使用者登入" >/dev/null
  dk-task-new login --gate1
  grep -q '| 使用者登入 | task | running |' "$DK_ROOT/tasks/INDEX.md"
  grep -q 'gate1 approved' "$DK_ROOT/tasks/$(date +%Y-%m-%d)-login/process.md"
}
```

- [ ] **Step 2: Run** → FAIL

- [ ] **Step 3: Implement `dkboai/bin/dk-task-new`**

```bash
#!/usr/bin/env bash
# dk-task-new <short> "<display>" [--from <plan>] [--no-worktree]
# dk-task-new <short> --gate1
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
dk_require_herdr
short="${1:-}"; shift || true
[[ "$short" =~ ^[a-z][a-z0-9-]{0,11}$ ]] || dk_die "short name must be ascii lowercase, ≤12 chars: '$short'"
display=""; from="人的口頭需求"; worktree=1; gate1=0
while [ $# -gt 0 ]; do case "$1" in
  --from) from="$2"; shift 2;; --no-worktree) worktree=0; shift;; --gate1) gate1=1; shift;;
  --*) dk_die "unknown flag $1";; *) display="$1"; shift;; esac; done

if [ "$gate1" = 1 ]; then
  existing=$(ls -d "$DK_ROOT/tasks/"*"-$short" 2>/dev/null | tail -1); [ -n "$existing" ] || dk_die "no task $short"
  DK_TASK_DIR="$existing"; export DK_TASK_DIR; dk_task_env
  dk_process "gate1 approved"; dk_index_set "$DK_DISPLAY" running "—"; exit 0
fi
[ -n "$display" ] || dk_die "display name required"
date=$(dk_today); name="$date-$short"; dir="$DK_ROOT/tasks/$name"
[ ! -e "$dir" ] || dk_die "task exists: $dir"
ls -d "$DK_ROOT/tasks/"*"-$short" >/dev/null 2>&1 && dk_die "short name '$short' already used"

branch="dk/$short"; wt_path=""; ws=""; root_pane=""
if [ "$worktree" = 1 ]; then
  base=$(git -C "$DK_PROJECT_ROOT" rev-parse --abbrev-ref HEAD)
  out=$(herdr worktree create --branch "$branch" --base "$base" --cwd "$DK_PROJECT_ROOT" --no-focus)
  wt_path=$(echo "$out" | dk_json '.result.path // empty')
  ws=$(echo "$out" | dk_json '.result.workspace.workspace_id')
  root_pane=$(echo "$out" | dk_json '.result.root_pane.pane_id')
  [ -n "$wt_path" ] || wt_path=$(git -C "$DK_PROJECT_ROOT" worktree list --porcelain | awk -v b="refs/heads/$branch" '$1=="worktree"{p=$2} $1=="branch"&&$2==b{print p}')
else
  wt_path="$DK_PROJECT_ROOT"; ws="${HERDR_WORKSPACE_ID:-}"; root_pane="${HERDR_PANE_ID:-}"
fi

mkdir -p "$dir/state"; : > "$dir/.panes"   # dk-watch exits when this file disappears (dk-task-close removes it)
subst() { sed -e "s#{{DISPLAY}}#$display#g; s#{{SHORT}}#$short#g; s#{{BRANCH}}#$branch#g; s#{{WORKTREE}}#$wt_path#g; s#{{SOURCE}}#$from#g; s#{{DATE}}#$(dk_now)#g; s#{{WORKSPACE}}#$ws#g; s#{{ROOT_PANE}}#$root_pane#g"; }
subst < "$DK_ROOT/templates/brief.md"   > "$dir/brief.md"
subst < "$DK_ROOT/templates/process.md" > "$dir/process.md"
subst < "$DK_ROOT/templates/task.env"   > "$dir/.task.env"
: > "$dir/messages.log"
mkdir -p "$DK_ROOT/.sessions"; echo "$name" > "$DK_ROOT/.sessions/${HERDR_PANE_ID:?}"

current=$(herdr agent get "$HERDR_PANE_ID" 2>/dev/null | dk_json '.result.agent.name // empty' || true)
[ -n "$current" ] || herdr agent rename "$HERDR_PANE_ID" "leader-$short" >/dev/null
dk_index_add "$date" "$display" task planning "—"

if [ -x "$DK_ROOT/bin/dk-watch" ] && [ -z "${DK_NO_WATCH:-}" ]; then
  # close fd 3 and stdin so bats/herdr never wait on the detached watcher
  DK_TASK_DIR="$dir" nohup "$DK_ROOT/bin/dk-watch" </dev/null >/dev/null 2>&1 3>&- &
  sed -i "s/^DK_WATCH_PID=.*/DK_WATCH_PID=$!/" "$dir/.task.env"
fi
echo "$dir"
```

- [ ] **Step 4: Run** → `4 tests, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add dkboai/bin/dk-task-new tests/unit/05_task_new.bats
git commit -m "feat: dk-task-new creates task folder, worktree and leader binding

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: `dk-msg`

**Files:**
- Create: `dkboai/bin/dk-msg`
- Test: `tests/unit/06_msg.bats`

**Interfaces:**
- Consumes: `dk_task_dir`, `dk_task_env`, `dk_leader_name`; env `DK_AGENT` (sender name; leader falls back to `leader-<short>`), `DK_ISOLATED`.
- Produces: `dk-msg <target> "[TYPE] body"`; `dk-msg --ack`. Log line: `<now> <sender> -> <target> [TYPE] body`; ack line: `<now> <sender> [ACK]`. Exit 0 sent; exit 2 refused (length/type/isolation); exit 1 undelivered (logged `[UNDELIVERED]`). Target `leader` resolves to `leader-<short>`. Waits `herdr agent wait <target> --until idle --until done --timeout ${DK_MSG_WAIT_MS:-300000}` first, then `herdr agent prompt <target> "<line>"` where line is `[TYPE] from <sender>: body`.

- [ ] **Step 1: Failing test**

```bash
load ../helpers
setup() { setup_project; fixture_task login 使用者登入 >/dev/null; }
teardown() { teardown_project; }

@test "msg from employee to employee: waits, prompts, logs" {
  DK_AGENT=login-qa run dk-msg login-frontend "[BUG] 空密碼未擋，見 state/qa.md"
  [ "$status" -eq 0 ]
  grep -q '^agent wait login-frontend --until idle --until done --timeout 300000$' "$HERDR_STUB_LOG"
  grep -q '^agent prompt login-frontend \[BUG\] from login-qa: 空密碼未擋，見 state/qa.md$' "$HERDR_STUB_LOG"
  grep -Eq '^[0-9T:-]+ login-qa -> login-frontend \[BUG\] 空密碼未擋，見 state/qa.md$' "$DK_ROOT/tasks/$(date +%F)-login/messages.log"
}
@test "leader alias resolves and leader sender defaults" {
  DK_AGENT=login-qa run dk-msg leader "[DONE] 驗收全過"
  grep -q '^agent prompt leader-login ' "$HERDR_STUB_LOG"
  run dk-msg login-qa "[DECISION] 用現有 users 表"
  grep -q 'leader-login -> login-qa \[DECISION\]' "$DK_ROOT/tasks/$(date +%F)-login/messages.log"
}
@test "refuses >200 chars, unknown type, isolated peer" {
  long=$(printf 'x%.0s' {1..201})
  DK_AGENT=login-qa run dk-msg login-frontend "[BUG] $long"; [ "$status" -eq 2 ]
  DK_AGENT=login-qa run dk-msg login-frontend "[HELLO] hi"; [ "$status" -eq 2 ]
  DK_AGENT=login-qa DK_ISOLATED=1 run dk-msg login-frontend "[BUG] x"; [ "$status" -eq 2 ]
  DK_AGENT=login-qa DK_ISOLATED=1 run dk-msg leader "[DONE] x"; [ "$status" -eq 0 ]
  ! grep -q '^agent prompt login-frontend' "$HERDR_STUB_LOG"
}
@test "undelivered when wait fails" {
  HERDR_STUB_FAIL="agent wait" DK_AGENT=login-qa run dk-msg login-frontend "[BUG] x"
  [ "$status" -eq 1 ]
  grep -q 'login-qa -> login-frontend \[UNDELIVERED\] \[BUG\] x' "$DK_ROOT/tasks/$(date +%F)-login/messages.log"
}
@test "ack writes marker" {
  dk-msg --ack
  grep -Eq '^[0-9T:-]+ leader-login \[ACK\]$' "$DK_ROOT/tasks/$(date +%F)-login/messages.log"
}
```

- [ ] **Step 2: Run** → FAIL

- [ ] **Step 3: Implement `dkboai/bin/dk-msg`**

```bash
#!/usr/bin/env bash
# dk-msg <target|leader> "[TYPE] body"   |   dk-msg --ack
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
dk_require_herdr
dir=$(dk_task_dir); DK_TASK_DIR="$dir"; export DK_TASK_DIR; dk_task_env
log="$dir/messages.log"
sender="${DK_AGENT:-$(dk_leader_name)}"

if [ "${1:-}" = "--ack" ]; then echo "$(dk_now) $sender [ACK]" >> "$log"; exit 0; fi
target="${1:-}"; text="${2:-}"
[ -n "$target" ] && [ -n "$text" ] || dk_die "usage: dk-msg <target> \"[TYPE] body\""
[ "$target" = leader ] && target=$(dk_leader_name)

if [[ ! "$text" =~ ^\[(TASK|DONE|BUG|FIXED|QUESTION|ANSWER|ESCALATE|DECISION|STOP|BLOCKED)\]\ (.+)$ ]]; then
  echo "dk-msg: text must be '[TYPE] body' with a known type" >&2; exit 2; fi
type="${BASH_REMATCH[1]}"; body="${BASH_REMATCH[2]}"
if [ "${#body}" -gt 200 ]; then echo "dk-msg: body >200 chars; put details in your state file" >&2; exit 2; fi
if [ "${DK_ISOLATED:-0}" = 1 ] && [ "$target" != "$(dk_leader_name)" ]; then
  echo "dk-msg: you are isolated; only leader may be messaged" >&2; exit 2; fi

line="[$type] from $sender: $body"
if herdr agent wait "$target" --until idle --until done --timeout "${DK_MSG_WAIT_MS:-300000}" >/dev/null 2>&1 \
   && herdr agent prompt "$target" "$line" >/dev/null 2>&1; then
  echo "$(dk_now) $sender -> $target [$type] $body" >> "$log"; exit 0
fi
echo "$(dk_now) $sender -> $target [UNDELIVERED] [$type] $body" >> "$log"
echo "dk-msg: undelivered to $target (logged); note it in your state blocked_by and continue" >&2
exit 1
```

- [ ] **Step 4: Run** → `5 tests, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add dkboai/bin/dk-msg tests/unit/06_msg.bats
git commit -m "feat: dk-msg protocol-checked messaging with log

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: `dk-spawn`

**Files:**
- Create: `dkboai/bin/dk-spawn`, `dkboai/lib/prompt.sh`
- Test: `tests/unit/07_spawn.bats`

**Interfaces:**
- Consumes: role frontmatter (`dk_fm`, `dk_fm_tier`, `dk_fm_list`), `dk_kind_args`, `dk_kind_load` (`kind_mcp_list`), `dk_agent_name`, `dk_state_name`, `dk_process`, stub `pane_split`, `agent_start`, `agent_prompt`.
- Produces: `dk-spawn <role> [alias] [--tier S|M|L] [--kind K] [--isolated] [--resume]`. Steps: read role; tier default `M`; `herdr pane split --pane $DK_ROOT_PANE --direction <split> --cwd $DK_WORKTREE --no-focus --env DK_ROOT=… --env DK_TASK_DIR=… --env DK_ROLE=… --env DK_AGENT=… --env DK_LEADER=… --env DK_ISOLATED=0|1 --env HERDR_ENV=1`; `herdr agent start <agent> --kind <kind> --pane <new> -- <kind_args>`; `herdr agent prompt <agent> "<first prompt>" --wait --timeout 60000`; append `pane_id` to `$dir/.panes` as `<agent> <pane_id>`; `dk_process "wave? spawn <agent> (<kind> <tier>)"`. MCP check: names in role `mcp:` missing from `kind_mcp_list` → warn on stderr and process line `mcp-missing <agent>: <names>`. `lib/prompt.sh` provides `dk_first_prompt AGENT ROLE TASK_DIR STATE_FILE RESUME(0|1)` printing the fixed bootstrap text.

- [ ] **Step 1: Failing test**

```bash
load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); }
teardown() { teardown_project; }

@test "spawn splits with env, starts agent with tier flags, sends first prompt" {
  run dk-spawn frontend cart --tier L
  [ "$status" -eq 0 ]
  split=$(grep '^pane split' "$HERDR_STUB_LOG")
  [[ "$split" == *"--pane wC:p1 --direction right --cwd $WORKTREE_PATH --no-focus"* ]]
  [[ "$split" == *"--env DK_TASK_DIR=$d"* ]]; [[ "$split" == *"--env DK_ROLE=frontend"* ]]
  [[ "$split" == *"--env DK_AGENT=login-frontend-cart"* ]]; [[ "$split" == *"--env DK_LEADER=leader-login"* ]]
  [[ "$split" == *"--env DK_ISOLATED=0"* ]]
  grep -q '^agent start login-frontend-cart --kind claude --pane wC:p2 -- --model opus --effort high --permission-mode acceptEdits$' "$HERDR_STUB_LOG"
  p=$(grep '^agent prompt login-frontend-cart' "$HERDR_STUB_LOG")
  [[ "$p" == *"$DK_ROOT/roles/frontend.md"* ]]; [[ "$p" == *"$d/brief.md"* ]]
  [[ "$p" == *"$d/state/frontend-cart.md"* ]]; [[ "$p" == *"禁止使用 subagent"* ]]; [[ "$p" == *"--wait --timeout 60000" ]]
  grep -q '^login-frontend-cart wC:p2$' "$d/.panes"
  grep -q 'spawn login-frontend-cart (claude L)' "$d/process.md"
}
@test "spawn defaults tier M, honours --kind and --isolated and --resume" {
  run dk-spawn qa --kind codex --isolated --resume
  [ "$status" -eq 0 ]
  grep -q -- '--kind codex --pane wC:p2 -- -m gpt-5.5 -c model_reasoning_effort=medium' "$HERDR_STUB_LOG"
  grep -q -- '--env DK_ISOLATED=1' "$HERDR_STUB_LOG"
  grep -q '從 state 檔續作' "$HERDR_STUB_LOG"
  grep -q 'spawn login-qa (codex M) override-kind isolated resume' "$d/process.md"
}
@test "spawn warns on missing mcp but continues" {
  sed -i 's/^mcp: \[\]/mcp: [playwright]/' "$DK_ROOT/roles/qa.md"
  run dk-spawn qa
  [ "$status" -eq 0 ]; [[ "$output" == *"mcp missing"* ]]; grep -q 'mcp-missing login-qa: playwright' "$d/process.md"
}
@test "spawn fails on unknown role or tier without S" {
  run dk-spawn designer; [ "$status" -eq 1 ]
  run dk-spawn reviewer --tier S; [ "$status" -eq 1 ]
}
```

- [ ] **Step 2: Run** → FAIL

- [ ] **Step 3: Implement `dkboai/lib/prompt.sh`**

```bash
# shellcheck shell=bash
dk_first_prompt() { # AGENT ROLE TASK_DIR STATE_FILE RESUME
  local resume=""; [ "${5:-0}" = 1 ] && resume="你是重新啟動的員工：先讀 $4，從 state 檔續作，不要重做已完成的項目。"
  printf '%s' "你是 $1，角色 $2。先讀：$DK_ROOT/roles/$2.md、$DK_ROOT/PROTOCOL.md、$DK_ROOT/PROJECT.md、$3/brief.md。你的 state 檔是 $4（≤20 行，每完成一個子步驟就覆寫）。只能修改 brief 檔案所有權劃給你的檔案。禁止使用 subagent、禁止自行開 pane。所有訊息用 $DK_ROOT/bin/dk-msg。讀完後建立 state 檔並開始做波次表分給你的項目；完成後 dk-msg 交接對象與 leader 送 [DONE]。$resume"
}
```

- [ ] **Step 4: Implement `dkboai/bin/dk-spawn`**

```bash
#!/usr/bin/env bash
# dk-spawn <role> [alias] [--tier S|M|L] [--kind K] [--isolated] [--resume]
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
. "$DK_ROOT/lib/frontmatter.sh"; . "$DK_ROOT/lib/kinds.sh"; . "$DK_ROOT/lib/prompt.sh"
dk_require_herdr
dir=$(dk_task_dir); DK_TASK_DIR="$dir"; export DK_TASK_DIR; dk_task_env
role="${1:-}"; shift || true; [ -n "$role" ] || dk_die "usage: dk-spawn <role> [alias] [--tier T] [--kind K] [--isolated] [--resume]"
alias=""; tier=M; kind=""; isolated=0; resume=0; notes=""
while [ $# -gt 0 ]; do case "$1" in
  --tier) tier="$2"; shift 2;; --kind) kind="$2"; notes="$notes override-kind"; shift 2;;
  --isolated) isolated=1; notes="$notes isolated"; shift;; --resume) resume=1; notes="$notes resume"; shift;;
  --*) dk_die "unknown flag $1";; *) alias="$1"; shift;; esac; done
rf="$DK_ROOT/roles/$role.md"; [ -f "$rf" ] || dk_die "no role file $rf (use add-role skill first)"
[ -n "$kind" ] || kind=$(dk_fm "$rf" kind)
spec=$(dk_fm_tier "$rf" "$tier"); [ -n "$spec" ] || dk_die "role $role has no tier $tier"
if [ "$kind" != "$(dk_fm "$rf" kind)" ]; then dk_kind_load "$kind"; spec=$(echo "$KIND_DEFAULT_TIERS" | tr ' ' '\n' | awk -F= -v t="$tier" '$1==t{print $2}'); fi
args=$(dk_kind_args "$kind" "$spec")
direction=$(dk_fm "$rf" split); direction="${direction:-right}"
agent=$(dk_agent_name "$role" "$alias"); state="$dir/state/$(dk_state_name "$role" "$alias").md"

pane=$(herdr pane split --pane "$DK_ROOT_PANE" --direction "$direction" --cwd "$DK_WORKTREE" --no-focus \
  --env "DK_ROOT=$DK_ROOT" --env "DK_TASK_DIR=$dir" --env "DK_ROLE=$role" --env "DK_AGENT=$agent" \
  --env "DK_LEADER=$(dk_leader_name)" --env "DK_ISOLATED=$isolated" --env "HERDR_ENV=1" | dk_json '.result.pane.pane_id')
[ -n "$pane" ] || dk_die "pane split returned no pane_id"
# shellcheck disable=SC2086
herdr agent start "$agent" --kind "$kind" --pane "$pane" -- $args >/dev/null
echo "$agent $pane" >> "$dir/.panes"

dk_kind_load "$kind"; have=$(kind_mcp_list || true); missing=""
for m in $(dk_fm_list "$rf" mcp); do echo "$have" | grep -qx "$m" || missing="$missing $m"; done
if [ -n "$missing" ]; then echo "dk-spawn: mcp missing for $kind:$missing" >&2; dk_process "mcp-missing $agent:$missing"; fi

herdr agent prompt "$agent" "$(dk_first_prompt "$agent" "$role" "$dir" "$state" "$resume")" --wait --timeout 60000 >/dev/null
dk_process "spawn $agent ($kind $tier)$notes"
echo "$agent $pane"
```

- [ ] **Step 5: Run** → `4 tests, 0 failures`

- [ ] **Step 6: Commit**

```bash
git add dkboai/bin/dk-spawn dkboai/lib/prompt.sh tests/unit/07_spawn.bats
git commit -m "feat: dk-spawn starts an employee pane with env, tier flags and bootstrap prompt

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: `dk-wave-close`

**Files:**
- Create: `dkboai/bin/dk-wave-close`, `dkboai/lib/ownership.sh`
- Test: `tests/unit/08_wave_close.bats`

**Interfaces:**
- Consumes: `$dir/.panes` (`<agent> <pane_id>` lines from Task 7), `state/*.md`, `brief.md` ownership table, stub `pane_close`.
- Produces: `dk-wave-close [--force]`. For each line in `.panes`: state file must exist with `status: done` (else list and exit 1 unless `--force`); warn if state >20 lines; compare `touched:` entries against ownership globs via `dk_owned STATE_NAME PATH` (from `lib/ownership.sh`, reads brief table rows `| 成員 | 可改 | 只讀 |` where 可改 is comma-separated globs); violations → stderr + process `violation <agent>: <path>`; `herdr pane close <pane>`; truncate `.panes`; process `wave-close: <n> agents closed`. Never commits.

- [ ] **Step 1: Failing test**

```bash
load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入)
  printf 'login-frontend wC:p2\nlogin-qa wC:p3\n' > "$d/.panes"
  cat >> "$d/brief.md" <<'B'
| frontend | src/web/** | src/api/types.ts |
| qa | tests/** | — |
B
  printf 'status: done\nwave: 1\ntouched:\n  - src/web/login.tsx\n' > "$d/state/frontend.md"
  printf 'status: done\nwave: 1\ntouched:\n  - tests/login.test.ts\n' > "$d/state/qa.md"
}
teardown() { teardown_project; }

@test "closes all panes when every state is done" {
  run dk-wave-close; [ "$status" -eq 0 ]
  grep -q '^pane close wC:p2$' "$HERDR_STUB_LOG"; grep -q '^pane close wC:p3$' "$HERDR_STUB_LOG"
  [ ! -s "$d/.panes" ]; grep -q 'wave-close: 2 agents closed' "$d/process.md"
}
@test "refuses when a state is not done, unless --force" {
  sed -i 's/^status: done/status: working/' "$d/state/qa.md"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"login-qa"* ]]
  ! grep -q '^pane close' "$HERDR_STUB_LOG"
  run dk-wave-close --force; [ "$status" -eq 0 ]
}
@test "reports ownership violations and long state" {
  printf 'status: done\ntouched:\n  - src/api/login.ts\n' > "$d/state/frontend.md"
  for i in $(seq 1 25); do echo "notes: line $i" >> "$d/state/qa.md"; done
  run dk-wave-close; [ "$status" -eq 0 ]
  grep -q 'violation login-frontend: src/api/login.ts' "$d/process.md"
  [[ "$output" == *"state too long"* ]]
}
```

- [ ] **Step 2: Run** → FAIL

- [ ] **Step 3: Implement `dkboai/lib/ownership.sh`**

```bash
# shellcheck shell=bash
# dk_owned BRIEF STATE_NAME PATH → exit 0 if PATH matches one of the member's 可改 globs.
dk_owned() {
  local brief="$1" who="$2" path="$3" globs g
  globs=$(awk -F'|' -v w="$who" '$2 ~ "^ *"w" *$" {print $3; exit}' "$brief" | tr ',' '\n' | sed 's/^ *//; s/ *$//')
  [ -n "$globs" ] || return 1
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    case "$path" in
      $g) return 0;;
    esac
    # ** → match any depth: strip to prefix
    if [[ "$g" == *'/**' ]] && [[ "$path" == "${g%/**}"/* ]]; then return 0; fi
  done <<< "$globs"
  return 1
}
dk_touched() { awk '/^touched:/{t=1;next} t && /^  - /{sub(/^  - /,""); print; next} t && /^[^ ]/{t=0}' "$1"; }
```

- [ ] **Step 4: Implement `dkboai/bin/dk-wave-close`**

```bash
#!/usr/bin/env bash
# dk-wave-close [--force]
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"; . "$DK_ROOT/lib/ownership.sh"
dk_require_herdr
dir=$(dk_task_dir); DK_TASK_DIR="$dir"; export DK_TASK_DIR; dk_task_env
force=0; [ "${1:-}" = --force ] && force=1
[ -s "$dir/.panes" ] || dk_die "no live panes recorded in $dir/.panes"
notdone=""
while read -r agent pane; do
  sname="${agent#"$DK_SHORT"-}"; sf="$dir/state/$sname.md"
  if [ ! -f "$sf" ] || ! grep -q '^status: done' "$sf"; then notdone="$notdone $agent"; fi
done < "$dir/.panes"
if [ -n "$notdone" ] && [ "$force" = 0 ]; then echo "dk-wave-close: not done:$notdone (use --force to close anyway)"; exit 1; fi
n=0
while read -r agent pane; do
  sname="${agent#"$DK_SHORT"-}"; sf="$dir/state/$sname.md"
  if [ -f "$sf" ]; then
    [ "$(wc -l < "$sf")" -le 20 ] || echo "dk-wave-close: state too long: $sf"
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      dk_owned "$dir/brief.md" "$sname" "$p" || { echo "dk-wave-close: violation $agent touched $p"; dk_process "violation $agent: $p"; }
    done < <(dk_touched "$sf")
  fi
  herdr pane close "$pane" >/dev/null && n=$((n+1))
done < "$dir/.panes"
: > "$dir/.panes"
dk_process "wave-close: $n agents closed"
echo "closed $n"
```

Note: `sname` strips the task short prefix, so alias names like `login-frontend-cart` map to `state/frontend-cart.md` and ownership row `frontend-cart`; the brief's ownership column must use the state name (role or role-alias).

- [ ] **Step 5: Run** → `3 tests, 0 failures`

- [ ] **Step 6: Commit**

```bash
git add dkboai/bin/dk-wave-close dkboai/lib/ownership.sh tests/unit/08_wave_close.bats
git commit -m "feat: dk-wave-close verifies state, ownership and closes panes

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: `dk-watch`

**Files:**
- Create: `dkboai/bin/dk-watch`
- Test: `tests/unit/09_watch.bats`

**Interfaces:**
- Consumes: `DK_TASK_DIR` (set by `dk-task-new`), `$dir/.panes`, stub `agent_list`, `notification_show`, `agent_prompt`.
- Produces: `dk-watch [--once] [--interval SEC]`. Loop: `herdr agent list` → for agents listed in `.panes` with `agent_status == "blocked"`, track first-seen time in `$dir/.blocked/<agent>`; if blocked ≥ `${DK_BLOCK_SEC:-60}` and not yet notified this episode: `herdr notification show "dkboai: <agent> blocked" --body "需要人按審批" --sound request`, `herdr agent prompt <leader> "[BLOCKED] from dk-watch: <agent> 卡在審批"` and process `blocked <agent>`. Clears the marker when the agent is no longer blocked. `--once` runs a single iteration (for tests). Exits when `$dir/.panes` disappears (`dk-task-close` removes it).

- [ ] **Step 1: Failing test**

```bash
load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); printf 'login-frontend wC:p2\nlogin-qa wC:p3\n' > "$d/.panes"; export DK_TASK_DIR="$d"; }
teardown() { teardown_project; }

@test "first sighting records marker, no notify" {
  run dk-watch --once; [ "$status" -eq 0 ]
  [ -f "$d/.blocked/login-qa" ]; [ ! -f "$d/.blocked/login-frontend" ]
  ! grep -q '^notification show' "$HERDR_STUB_LOG"
}
@test "blocked past threshold notifies once" {
  mkdir -p "$d/.blocked"; echo 0 > "$d/.blocked/login-qa"
  dk-watch --once; dk-watch --once
  [ "$(grep -c '^notification show dkboai: login-qa blocked' "$HERDR_STUB_LOG")" -eq 1 ]
  grep -q '^agent prompt leader-login \[BLOCKED\] from dk-watch: login-qa' "$HERDR_STUB_LOG"
  grep -q 'blocked login-qa' "$d/process.md"
}
@test "marker clears when unblocked" {
  mkdir -p "$d/.blocked"; echo 0 > "$d/.blocked/login-qa"
  sed -i 's/"blocked"/"idle"/' "$HERDR_STUB_RESPONSES/agent_list.json"
  dk-watch --once; [ ! -f "$d/.blocked/login-qa" ]
}
```

- [ ] **Step 2: Run** → FAIL

- [ ] **Step 3: Implement `dkboai/bin/dk-watch`**

```bash
#!/usr/bin/env bash
# dk-watch [--once] [--interval SEC]  — background blocked-agent detector for one task.
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
dir=$(dk_task_dir); DK_TASK_DIR="$dir"; export DK_TASK_DIR; dk_task_env
once=0; interval=30
while [ $# -gt 0 ]; do case "$1" in --once) once=1; shift;; --interval) interval="$2"; shift 2;; *) dk_die "unknown flag $1";; esac; done
thr="${DK_BLOCK_SEC:-60}"; mkdir -p "$dir/.blocked"
tick() {
  [ -f "$dir/.panes" ] || exit 0
  local now list; now=$(date +%s); list=$(herdr agent list 2>/dev/null) || return 0
  while read -r agent _pane; do
    [ -n "$agent" ] || continue
    st=$(echo "$list" | jq -r --arg a "$agent" '.result.agents[] | select(.name==$a) | .agent_status' | head -1)
    m="$dir/.blocked/$agent"
    if [ "$st" = blocked ]; then
      if [ ! -f "$m" ]; then echo "$now" > "$m"; continue; fi
      since=$(head -1 "$m"); [ "$(wc -l < "$m")" -ge 2 ] && continue   # already notified
      if [ $((now - since)) -ge "$thr" ]; then
        herdr notification show "dkboai: $agent blocked" --body "需要人按審批" --sound request >/dev/null 2>&1 || true
        herdr agent prompt "$(dk_leader_name)" "[BLOCKED] from dk-watch: $agent 卡在審批" >/dev/null 2>&1 || true
        dk_process "blocked $agent"; echo notified >> "$m"
      fi
    else rm -f "$m"; fi
  done < "$dir/.panes"
}
if [ "$once" = 1 ]; then tick; exit 0; fi
while :; do tick; sleep "$interval"; done
```

- [ ] **Step 4: Add the launch test to `tests/unit/09_watch.bats` and run**

```bash
@test "dk-task-new launches dk-watch and records its pid" {
  rm -rf "$DK_ROOT/tasks/"*-login "$DK_ROOT/.sessions/wB:p1"; unset DK_TASK_DIR
  DK_NO_WATCH= run dk-task-new login 使用者登入; [ "$status" -eq 0 ]
  pid=$(sed -n 's/^DK_WATCH_PID=//p' "$output/.task.env"); [[ "$pid" =~ ^[0-9]+$ ]]
  kill "$pid" 2>/dev/null || true
}
```

Run: `tests/run.sh tests/unit/09_watch.bats` → `4 tests, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add dkboai/bin/dk-watch tests/unit/09_watch.bats
git commit -m "feat: dk-watch notifies leader and human about blocked employees

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 10: `dk-resume`

**Files:**
- Create: `dkboai/bin/dk-resume`
- Test: `tests/unit/10_resume.bats`

**Interfaces:**
- Consumes: `.sessions` binding or explicit `<task>` arg (folder name or short); task files; stub `agent_list`.
- Produces: `dk-resume [<task>]` prints, in order, sections `## 你是 leader-<short>`, `## brief`, `## process（最後 20 行）`, `## 未處理訊息`, `## state 摘要`, `## 在線員工`, `## BACKLOG`; total ≤150 lines (brief printed whole; if the total exceeds 150, state summaries drop to 3 lines each, then process to 10). With an explicit `<task>` it also rewrites `.sessions/$HERDR_PANE_ID` (manual takeover).

- [ ] **Step 1: Failing test**

```bash
load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入)
  for i in $(seq 1 30); do echo "2026-09-10T10:$i ev$i" >> "$d/process.md"; done
  cat > "$d/messages.log" <<'L'
2026-09-10T10:00 login-qa -> leader-login [DONE] old
2026-09-10T10:01 leader-login [ACK]
2026-09-10T10:02 login-qa -> login-frontend [BUG] x
2026-09-10T10:03 login-qa -> leader-login [ESCALATE] 修一次未好
L
  printf 'status: working\nwave: 1\ncurrent: 修 bug\ntouched:\n  - a\ntodo:\n  - b\nnotes: n\n' > "$d/state/frontend.md"
}
teardown() { teardown_project; }

@test "resume prints the recovery pack under 150 lines" {
  run dk-resume; [ "$status" -eq 0 ]
  [ "${#lines[@]}" -le 150 ]
  [[ "$output" == *"## 你是 leader-login"* ]]; [[ "$output" == *"dkboai/LEADER.md"* ]]
  [[ "$output" == *"# 使用者登入"* ]]
  [[ "$output" == *" ev30"* ]]; [[ "$output" != *" ev5"* ]]
  [[ "$output" == *"[ESCALATE] 修一次未好"* ]]; [[ "$output" != *"[DONE] old"* ]]; [[ "$output" != *"[BUG] x"* ]]
  [[ "$output" == *"frontend: status: working"* ]]
  [[ "$output" == *"login-frontend working"* ]]
}
@test "resume <task> rebinds the pane" {
  rm "$DK_ROOT/.sessions/wB:p1"
  run dk-resume; [ "$status" -eq 1 ]
  run dk-resume login; [ "$status" -eq 0 ]
  [ "$(cat "$DK_ROOT/.sessions/wB:p1")" = "$(basename "$d")" ]
}
```

- [ ] **Step 2: Run** → FAIL

- [ ] **Step 3: Implement `dkboai/bin/dk-resume`**

```bash
#!/usr/bin/env bash
# dk-resume [<task-folder|short>] — print a ≤150-line recovery pack for the leader.
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
if [ -n "${1:-}" ]; then
  t="$1"; [ -d "$DK_ROOT/tasks/$t" ] || t=$(ls -d "$DK_ROOT/tasks/"*"-$1" 2>/dev/null | xargs -n1 basename | tail -1)
  [ -n "$t" ] && [ -d "$DK_ROOT/tasks/$t" ] || dk_die "no task '$1'"
  mkdir -p "$DK_ROOT/.sessions"; echo "$t" > "$DK_ROOT/.sessions/${HERDR_PANE_ID:?}"
fi
dir=$(dk_task_dir); DK_TASK_DIR="$dir"; export DK_TASK_DIR; dk_task_env
render() { # $1=process lines $2=state lines
  echo "## 你是 $(dk_leader_name)（任務 $(basename "$dir")）"
  echo "規範在 dkboai/LEADER.md 與 dkboai/PROTOCOL.md，先讀再行動。任務目錄 $dir"
  echo "## brief"; cat "$dir/brief.md"
  echo "## process（最後 $1 行）"; tail -n "$1" "$dir/process.md"
  echo "## 未處理訊息（最後一則 ACK 之後，寄給 leader）"
  awk -v me="$(dk_leader_name)" '/\[ACK\]$/{buf=""; next} index($0, "-> " me " ")>0 {buf=buf $0 "\n"} END{printf "%s", buf}' "$dir/messages.log"
  echo "## state 摘要（每檔前 $2 行）"
  for f in "$dir"/state/*.md; do [ -f "$f" ] || continue; n=$(basename "$f" .md); head -n "$2" "$f" | sed "s/^/$n: /"; done
  echo "## 在線員工"
  herdr agent list 2>/dev/null | jq -r --arg p "$DK_SHORT-" '.result.agents[] | select(.name != null and (.name|startswith($p))) | "\(.name) \(.agent_status)"' || true
  echo "## BACKLOG"; cat "$DK_ROOT/tasks/BACKLOG.md"
}
out=$(render 20 5); [ "$(echo "$out" | wc -l)" -le 150 ] || out=$(render 20 3)
[ "$(echo "$out" | wc -l)" -le 150 ] || out=$(render 10 3)
printf '%s\n' "$out"
```

- [ ] **Step 4: Run** → `2 tests, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add dkboai/bin/dk-resume tests/unit/10_resume.bats
git commit -m "feat: dk-resume recovery pack for a cleared leader

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 11: `dk-chore`

**Files:**
- Create: `dkboai/bin/dk-chore`
- Test: `tests/unit/11_chore.bats`

**Interfaces:**
- Consumes: role file, `dk_kind_args`, `dk_first_prompt`-like bootstrap (own text), stub `pane_split`, `agent_start`, `agent_prompt`, `worktree_create`.
- Produces: `dk-chore <role> "<instruction>" [--kind K] [--tier S|M|L] [--code] [--cwd PATH]`. Agent name `chore-<role>-<n>` where n = count of existing `tasks/_chores/*` + 1. Chore file `tasks/_chores/<date>-<slug>.md` from `templates/chore.md` (slug = `dk_slug` of first 24 chars of instruction). Without `--code`: split from current pane (`--current`), cwd = `--cwd` or `$DK_PROJECT_ROOT`, `DK_CHORE_CODE=0`. With `--code`: `herdr worktree create --branch chore/<slug> --base <head> --cwd $DK_PROJECT_ROOT --no-focus`, split from its root pane, cwd = worktree path, branch recorded in chore file. Env injected: `DK_ROOT`, `DK_ROLE`, `DK_AGENT`, `DK_CHORE_FILE`, `DK_LEADER` (current agent name, or `leader` unresolved → uses `herdr agent get $HERDR_PANE_ID` name, else `HERDR_PANE_ID`), `DK_CHORE_CODE`. First prompt: read role, PROJECT.md, PROTOCOL.md; instruction; write status/touched/結果 to chore file; `dk-msg` not usable without a task, so chores report with `herdr agent prompt "$DK_LEADER" "[DONE] from <agent>: ..."` (prompt says so). INDEX row `chore working`; leader flips it manually via `dk_index_set` when done (documented in LEADER.md).

- [ ] **Step 1: Failing test**

```bash
load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "chore without code splits from current pane in project root" {
  run dk-chore frontend "翻譯 docs/README.md 成英文" --tier S
  [ "$status" -eq 0 ]
  f=$(ls "$DK_ROOT/tasks/_chores/"*.md); grep -q '^交代：翻譯 docs/README.md 成英文$' "$f"
  grep -q '^成員：chore-frontend-1 (claude / S)$' "$f"; grep -q '^branch: -$' "$f"
  split=$(grep '^pane split' "$HERDR_STUB_LOG"); [[ "$split" == *"--current --direction right --cwd $PROJECT --no-focus"* ]]
  [[ "$split" == *"--env DK_CHORE_FILE=$f"* ]]; [[ "$split" == *"--env DK_CHORE_CODE=0"* ]]
  grep -q '^agent start chore-frontend-1 --kind claude --pane wC:p2 -- --model sonnet --effort low' "$HERDR_STUB_LOG"
  grep -q '| chore | working |' "$DK_ROOT/tasks/INDEX.md"
  ! grep -q '^worktree create' "$HERDR_STUB_LOG"
}
@test "chore --code makes a worktree branch and numbers agents" {
  dk-chore frontend "first" >/dev/null
  run dk-chore frontend "修登入頁 Safari 版面" --code
  [ "$status" -eq 0 ]
  grep -q '^worktree create --branch chore/.* --base main --cwd .* --no-focus$' "$HERDR_STUB_LOG"
  grep -q '^agent start chore-frontend-2 ' "$HERDR_STUB_LOG"
  f=$(ls -t "$DK_ROOT/tasks/_chores/"*.md | head -1); grep -q '^branch: chore/' "$f"
}
```

- [ ] **Step 2: Run** → FAIL

- [ ] **Step 3: Implement `dkboai/bin/dk-chore`**

```bash
#!/usr/bin/env bash
# dk-chore <role> "<instruction>" [--kind K] [--tier S|M|L] [--code] [--cwd PATH]
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
. "$DK_ROOT/lib/frontmatter.sh"; . "$DK_ROOT/lib/kinds.sh"
dk_require_herdr
role="${1:-}"; instr="${2:-}"; shift 2 || true
[ -n "$role" ] && [ -n "$instr" ] || dk_die "usage: dk-chore <role> \"<instruction>\" [--kind K] [--tier T] [--code] [--cwd PATH]"
kind=""; tier=M; code=0; cwd="$DK_PROJECT_ROOT"
while [ $# -gt 0 ]; do case "$1" in
  --kind) kind="$2"; shift 2;; --tier) tier="$2"; shift 2;; --code) code=1; shift;; --cwd) cwd="$2"; shift 2;;
  *) dk_die "unknown flag $1";; esac; done
rf="$DK_ROOT/roles/$role.md"; [ -f "$rf" ] || dk_die "no role file $rf (use add-role skill first)"
[ -n "$kind" ] || kind=$(dk_fm "$rf" kind)
spec=$(dk_fm_tier "$rf" "$tier"); [ -n "$spec" ] || dk_die "role $role has no tier $tier"
if [ "$kind" != "$(dk_fm "$rf" kind)" ]; then dk_kind_load "$kind"; spec=$(echo "$KIND_DEFAULT_TIERS" | tr ' ' '\n' | awk -F= -v t="$tier" '$1==t{print $2}'); fi
args=$(dk_kind_args "$kind" "$spec")
n=$(( $(ls "$DK_ROOT/tasks/_chores/"*.md 2>/dev/null | wc -l) + 1 ))
agent="chore-$role-$n"; slug=$(dk_slug "${instr:0:24}"); slug="${slug:-chore$n}"
cf="$DK_ROOT/tasks/_chores/$(dk_today)-$slug.md"; [ ! -e "$cf" ] || cf="${cf%.md}-$n.md"
branch="-"; split_from=(--current)
if [ "$code" = 1 ]; then
  branch="chore/$slug"; base=$(git -C "$DK_PROJECT_ROOT" rev-parse --abbrev-ref HEAD)
  out=$(herdr worktree create --branch "$branch" --base "$base" --cwd "$DK_PROJECT_ROOT" --no-focus)
  cwd=$(echo "$out" | dk_json '.result.path // empty'); root=$(echo "$out" | dk_json '.result.root_pane.pane_id')
  [ -n "$cwd" ] || cwd=$(git -C "$DK_PROJECT_ROOT" worktree list --porcelain | awk -v b="refs/heads/$branch" '$1=="worktree"{p=$2} $1=="branch"&&$2==b{print p}')
  split_from=(--pane "$root")
fi
sed -e "s#{{SOURCE}}#$instr#; s#{{AGENT}}#$agent#; s#{{KIND}}#$kind#; s#{{TIER}}#$tier#; s#{{BRANCH}}#$branch#" "$DK_ROOT/templates/chore.md" > "$cf"
leader=$(herdr agent get "${HERDR_PANE_ID:?}" 2>/dev/null | dk_json '.result.agent.name // empty' || true); leader="${leader:-$HERDR_PANE_ID}"
pane=$(herdr pane split "${split_from[@]}" --direction "$(dk_fm "$rf" split)" --cwd "$cwd" --no-focus \
  --env "DK_ROOT=$DK_ROOT" --env "DK_ROLE=$role" --env "DK_AGENT=$agent" --env "DK_CHORE_FILE=$cf" \
  --env "DK_LEADER=$leader" --env "DK_CHORE_CODE=$code" --env "HERDR_ENV=1" | dk_json '.result.pane.pane_id')
# shellcheck disable=SC2086
herdr agent start "$agent" --kind "$kind" --pane "$pane" -- $args >/dev/null
prompt="你是 $agent，角色 $role，這是一件雜務。先讀 $DK_ROOT/roles/$role.md、$DK_ROOT/PROTOCOL.md、$DK_ROOT/PROJECT.md。交代：$instr。進度與結果寫在 $cf（status、touched、結果）。禁止使用 subagent。"
[ "$code" = 1 ] && prompt="$prompt 你在分支 $branch 的 worktree 中，完成後自己跑測試並 commit。範圍比想的大就停下回報。" || prompt="$prompt 不得修改程式碼。"
prompt="$prompt 完成後執行：herdr agent prompt $leader \"[DONE] from $agent: <一句結果>\"。"
herdr agent prompt "$agent" "$prompt" --wait --timeout 60000 >/dev/null
dk_index_add "$(dk_today)" "$instr" chore working "$cf"
echo "$agent $pane $cf"
```

- [ ] **Step 4: Run** → `2 tests, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add dkboai/bin/dk-chore tests/unit/11_chore.bats
git commit -m "feat: dk-chore lightweight one-agent errands, optional code worktree

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 12: `dk-task-close`

**Files:**
- Create: `dkboai/bin/dk-task-close`
- Test: `tests/unit/12_task_close.bats`

**Interfaces:**
- Consumes: `.task.env`, `report.md`, `.panes`, `DK_WATCH_PID`, stub `worktree_remove`, `agent_rename`.
- Produces: `dk-task-close [--abandon "<reason>"]`. Requires `report.md` to exist (else exit 1) unless `--abandon`, which writes a minimal report with the reason. Requires `.panes` empty (else exit 1, "run dk-wave-close"). Merge: `git -C $DK_PROJECT_ROOT merge --no-ff dk/<short> -m "task <short>: <display>"`; on conflict: `git merge --abort`, process `merge-conflict`, exit 3, leave everything else untouched. On success (or abandon): `herdr worktree remove --workspace $DK_WORKSPACE --force`, `git branch -D` only when abandoning, kill `DK_WATCH_PID`, remove `.panes`, `.blocked/`, `.sessions/$HERDR_PANE_ID`, `herdr agent rename $HERDR_PANE_ID --clear`, INDEX → `done <merge sha>` or `abandoned <reason>`, process `task-close merged <sha>` / `task-close abandoned`.

- [ ] **Step 1: Failing test**

```bash
load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入)
  git -C "$PROJECT" -c user.name=t -c user.email=t@t commit -q --allow-empty -m base
  git -C "$PROJECT" branch dk/login
  git -C "$PROJECT" -c user.name=t -c user.email=t@t checkout -q dk/login; echo hi > "$PROJECT/f.txt"
  git -C "$PROJECT" add f.txt; git -C "$PROJECT" -c user.name=t -c user.email=t@t commit -q -m wave1; git -C "$PROJECT" checkout -q main
  printf '| 2026-09-10 | 使用者登入 | task | running | — |\n' >> "$DK_ROOT/tasks/INDEX.md"
  : > "$d/.panes"
}
teardown() { teardown_project; }

@test "refuses without report or with live panes" {
  run dk-task-close; [ "$status" -eq 1 ]; [[ "$output" == *"report.md"* ]]
  echo '# r' > "$d/report.md"; echo 'x wC:p9' > "$d/.panes"
  run dk-task-close; [ "$status" -eq 1 ]; [[ "$output" == *"dk-wave-close"* ]]
}
@test "merges, removes worktree, clears binding and index" {
  echo '# r' > "$d/report.md"
  run dk-task-close; [ "$status" -eq 0 ]
  [ -f "$PROJECT/f.txt" ]; git -C "$PROJECT" log --oneline -1 | grep -q 'task login: 使用者登入'
  grep -q '^worktree remove --workspace wC --force$' "$HERDR_STUB_LOG"
  grep -q '^agent rename wB:p1 --clear$' "$HERDR_STUB_LOG"
  [ ! -f "$DK_ROOT/.sessions/wB:p1" ]
  grep -Eq '\| 使用者登入 \| task \| done \| merged [0-9a-f]{7} \|' "$DK_ROOT/tasks/INDEX.md"
  grep -q 'task-close merged' "$d/process.md"
}
@test "conflict aborts with exit 3 and keeps binding" {
  echo '# r' > "$d/report.md"; echo other > "$PROJECT/f.txt"
  git -C "$PROJECT" add f.txt; git -C "$PROJECT" -c user.name=t -c user.email=t@t commit -q -m clash
  run dk-task-close; [ "$status" -eq 3 ]
  [ -f "$DK_ROOT/.sessions/wB:p1" ]; grep -q 'merge-conflict' "$d/process.md"
  git -C "$PROJECT" diff --quiet   # merge aborted cleanly
}
@test "abandon writes report, deletes branch, marks index" {
  run dk-task-close --abandon "需求改了"; [ "$status" -eq 0 ]
  grep -q '需求改了' "$d/report.md"; grep -q 'abandoned' "$d/report.md"
  ! git -C "$PROJECT" rev-parse --verify -q dk/login
  grep -q '| abandoned | 需求改了 |' "$DK_ROOT/tasks/INDEX.md"
}
```

- [ ] **Step 2: Run** → FAIL

- [ ] **Step 3: Implement `dkboai/bin/dk-task-close`**

```bash
#!/usr/bin/env bash
# dk-task-close [--abandon "<reason>"]
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
dk_require_herdr
dir=$(dk_task_dir); DK_TASK_DIR="$dir"; export DK_TASK_DIR; dk_task_env
abandon=0; reason=""
[ "${1:-}" = --abandon ] && { abandon=1; reason="${2:-（未填原因）}"; }
if [ "$abandon" = 0 ]; then [ -f "$dir/report.md" ] || { echo "dk-task-close: write $dir/report.md first (gate 3)"; exit 1; }; fi
[ ! -s "$dir/.panes" ] || { echo "dk-task-close: live panes remain; run dk-wave-close first"; exit 1; }

cleanup() {
  [ -n "${DK_WATCH_PID:-}" ] && kill "$DK_WATCH_PID" 2>/dev/null || true
  [ -n "${DK_WORKSPACE:-}" ] && [ "$DK_WORKTREE" != "$DK_PROJECT_ROOT" ] && herdr worktree remove --workspace "$DK_WORKSPACE" --force >/dev/null 2>&1 || true
  rm -rf "$dir/.panes" "$dir/.blocked" "$DK_ROOT/.sessions/${HERDR_PANE_ID:?}"
  herdr agent rename "$HERDR_PANE_ID" --clear >/dev/null 2>&1 || true
}
if [ "$abandon" = 1 ]; then
  printf '# %s 結案\n結果：abandoned   分支：%s\n## 原因\n%s\n' "$DK_DISPLAY" "$DK_BRANCH" "$reason" > "$dir/report.md"
  cleanup; git -C "$DK_PROJECT_ROOT" branch -D "$DK_BRANCH" >/dev/null 2>&1 || true
  dk_index_set "$DK_DISPLAY" abandoned "$reason"; dk_process "task-close abandoned: $reason"; echo abandoned; exit 0
fi
if ! git -C "$DK_PROJECT_ROOT" merge --no-ff "$DK_BRANCH" -m "task $DK_SHORT: $DK_DISPLAY" >/dev/null 2>&1; then
  git -C "$DK_PROJECT_ROOT" merge --abort 2>/dev/null || true
  dk_process "merge-conflict $DK_BRANCH"; echo "dk-task-close: merge conflict on $DK_BRANCH; ask the human or run an it repair wave"; exit 3
fi
sha=$(git -C "$DK_PROJECT_ROOT" rev-parse --short HEAD)
cleanup
dk_index_set "$DK_DISPLAY" done "merged $sha"; dk_process "task-close merged $sha"; echo "merged $sha"
```

- [ ] **Step 4: Run** → `4 tests, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add dkboai/bin/dk-task-close tests/unit/12_task_close.bats
git commit -m "feat: dk-task-close merges, cleans worktree and binding, handles abandon

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 13: `dk-leader`

**Files:**
- Create: `dkboai/bin/dk-leader`
- Test: `tests/unit/13_leader.bats`

**Interfaces:**
- Consumes: stub `pane_split`, `agent_start`, `agent_prompt`; `kinds/claude.sh`.
- Produces: `dk-leader <short> "<display>" [--kind claude] [--model opus|sonnet] [--effort high]`. Run by a human from any herdr shell pane. Splits from `--current` (direction `right`, cwd `$DK_PROJECT_ROOT`, env `DK_ROOT`, `HERDR_ENV=1`), starts `leader-<short>` with `--model ${model:-opus} --effort ${effort:-high}` (no acceptEdits: the leader pane is where the human sits, so keep normal permissions), then prompts: 「讀 dkboai/LEADER.md，然後執行 dkboai/bin/dk-task-new <short> "<display>" 並開始寫 brief。」 Prints `leader-<short> <pane>`.

- [ ] **Step 1: Failing test**

```bash
load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "dk-leader opens a named leader pane" {
  run dk-leader pay "金流"; [ "$status" -eq 0 ]; [ "$output" = "leader-pay wC:p2" ]
  grep -q -- "--current --direction right --cwd $PROJECT --no-focus --env DK_ROOT=$DK_ROOT --env HERDR_ENV=1" "$HERDR_STUB_LOG"
  grep -q '^agent start leader-pay --kind claude --pane wC:p2 -- --model opus --effort high$' "$HERDR_STUB_LOG"
  grep -q 'dk-task-new pay "金流"' "$HERDR_STUB_LOG"
}
@test "dk-leader validates short name" { run dk-leader Pay x; [ "$status" -eq 1 ]; }
```

- [ ] **Step 2: Run** → FAIL

- [ ] **Step 3: Implement `dkboai/bin/dk-leader`**

```bash
#!/usr/bin/env bash
# dk-leader <short> "<display>" [--kind claude] [--model M] [--effort E]  — open a second leader pane.
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
dk_require_herdr
short="${1:-}"; display="${2:-}"; shift 2 || true
[[ "$short" =~ ^[a-z][a-z0-9-]{0,11}$ ]] || dk_die "short name must be ascii lowercase, ≤12 chars"
[ -n "$display" ] || dk_die "display name required"
kind=claude; model=opus; effort=high
while [ $# -gt 0 ]; do case "$1" in --kind) kind="$2";; --model) model="$2";; --effort) effort="$2";; *) dk_die "unknown flag $1";; esac; shift 2; done
pane=$(herdr pane split --current --direction right --cwd "$DK_PROJECT_ROOT" --no-focus --env "DK_ROOT=$DK_ROOT" --env "HERDR_ENV=1" | dk_json '.result.pane.pane_id')
herdr agent start "leader-$short" --kind "$kind" --pane "$pane" -- --model "$model" --effort "$effort" >/dev/null
herdr agent prompt "leader-$short" "讀 dkboai/LEADER.md，然後執行 dkboai/bin/dk-task-new $short \"$display\" 並開始寫 brief。" --wait --timeout 60000 >/dev/null
echo "leader-$short $pane"
```

- [ ] **Step 4: Run** → `2 tests, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add dkboai/bin/dk-leader tests/unit/13_leader.bats
git commit -m "feat: dk-leader opens an additional named leader pane

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 14: `install.sh`, the two skills, and the AI-installable README

**Files:**
- Create: `dkboai/install.sh`, `dkboai/skills/init/SKILL.md`, `dkboai/skills/add-role/SKILL.md`
- Create: `README.md` (repo root, points to `dkboai/README.md`)
- Modify: `dkboai/README.md` (full version replacing the Task 4 stub)
- Test: `tests/unit/14_install.bats`

**Interfaces:**
- Produces: `dkboai/install.sh` (run from target project root or with `--target DIR`): never overwrites existing files, only appends; skips the CLAUDE.md line when CLAUDE.md is a symlink to AGENTS.md; creates `.claude/skills/dkboai-init`, `.claude/skills/dkboai-add-role`, `.agents/skills/dkboai-init`, `.agents/skills/dkboai-add-role` relative symlinks into `dkboai/skills/*`; writes `AGENTS.md` line `讀 dkboai/ENTRY.md 並依其行事。` if absent; writes `CLAUDE.md` line `@AGENTS.md` if absent (appends if file exists without it); `chmod +x dkboai/bin/*`; appends `dkboai/.sessions/*` to `.gitignore` if missing. Idempotent.
- Skills are markdown only; their frontmatter `name` and `description` follow the Agent Skills format so all three CLIs list them.
- `dkboai/README.md` is written for an AI reader as much as a human: a copy-pasteable block that installs everything without further questions, exact expected outputs, and an update procedure that never overwrites `tasks/`, `PROJECT.md`, `decisions.md` or customised `roles/`.

- [ ] **Step 1: Failing test**

```bash
load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "install creates symlinks, entry files, gitignore; idempotent" {
  run dkboai/install.sh; [ "$status" -eq 0 ]
  for s in init add-role; do
    [ "$(readlink .claude/skills/dkboai-$s)" = "../../dkboai/skills/$s" ]
    [ "$(readlink .agents/skills/dkboai-$s)" = "../../dkboai/skills/$s" ]
    [ -f ".claude/skills/dkboai-$s/SKILL.md" ]
  done
  grep -q '^讀 dkboai/ENTRY.md' AGENTS.md; grep -q '^@AGENTS.md$' CLAUDE.md; grep -q 'dkboai/.sessions' .gitignore
  run dkboai/install.sh; [ "$status" -eq 0 ]
  [ "$(grep -c '^@AGENTS.md$' CLAUDE.md)" -eq 1 ]
}
@test "install appends to an existing CLAUDE.md and AGENTS.md" {
  echo '# my project' > CLAUDE.md; echo '# agents rules' > AGENTS.md; dkboai/install.sh >/dev/null
  head -1 CLAUDE.md | grep -q '# my project'; grep -q '^@AGENTS.md$' CLAUDE.md
  head -1 AGENTS.md | grep -q '# agents rules'; grep -q '^讀 dkboai/ENTRY.md' AGENTS.md
}
@test "install skips CLAUDE.md line when it symlinks AGENTS.md" {
  echo '# agents rules' > AGENTS.md; ln -s AGENTS.md CLAUDE.md; dkboai/install.sh >/dev/null
  ! grep -q '^@AGENTS.md$' AGENTS.md; grep -q '^讀 dkboai/ENTRY.md' AGENTS.md
}
@test "README carries the one-shot install and update commands" {
  for needle in 'dkboai/install.sh' 'git add -A' '/dkboai-init' 'HERDR_ENV' 'herdr --version' 'dk-whoami' 'rsync' '--exclude=tasks'; do
    grep -qF -- "$needle" dkboai/README.md || { echo "missing: $needle"; return 1; }
  done
  [ -f README.md ]; grep -q 'dkboai/README.md' README.md
}
@test "skills have agent-skills frontmatter" {
  for s in init add-role; do
    head -1 "dkboai/skills/$s/SKILL.md" | grep -q '^---$'
    grep -q "^name: dkboai-$s$" "dkboai/skills/$s/SKILL.md"; grep -q '^description: ' "dkboai/skills/$s/SKILL.md"
  done
}
```

- [ ] **Step 2: Run** → FAIL

- [ ] **Step 3: Implement `dkboai/install.sh`**

```bash
#!/usr/bin/env bash
# dkboai/install.sh [--target DIR]  — wire dkboai into a project (idempotent).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="$(dirname "$here")"; [ "${1:-}" = --target ] && target="$(cd "$2" && pwd)"
cd "$target"
for s in init add-role; do
  for d in .claude/skills .agents/skills; do
    mkdir -p "$d"; ln -sfn "../../dkboai/skills/$s" "$d/dkboai-$s"
  done
done
grep -qs '^讀 dkboai/ENTRY.md' AGENTS.md || echo '讀 dkboai/ENTRY.md 並依其行事。' >> AGENTS.md
if [ -L CLAUDE.md ] && [ "$(readlink CLAUDE.md)" = AGENTS.md ]; then
  echo "CLAUDE.md is a symlink to AGENTS.md; nothing to add"
else
  grep -qs '^@AGENTS.md$' CLAUDE.md || echo '@AGENTS.md' >> CLAUDE.md
fi
grep -qs 'dkboai/.sessions' .gitignore || printf 'dkboai/.sessions/*\n!dkboai/.sessions/.gitkeep\n' >> .gitignore
chmod +x dkboai/bin/* dkboai/install.sh
echo "dkboai installed into $target"
```

Then: `chmod +x dkboai/install.sh` (git keeps the mode).

- [ ] **Step 4: Write `dkboai/skills/init/SKILL.md`**

```markdown
---
name: dkboai-init
description: 第一次在專案啟用 dkboai 時執行。偵測已安裝的 AI CLI、選主模型與第二三意見工具、改寫角色檔的 kind 與三檔、預填 PROJECT.md、檢查 MCP 需求。
---
# dkboai init

逐步做，每步用 AskUserQuestion 或等人回答，一次問一題。

0. 前置檢查：`git status --porcelain dkboai AGENTS.md CLAUDE.md .claude .agents`。有輸出就停下，請人先 commit（員工的 worktree 只看得到已 commit 的檔案）。
1. 偵測工具：執行 `bash -c '. dkboai/lib/common.sh; . dkboai/lib/kinds.sh; dk_kinds_available'`。對每個結果檢查登入狀態：`claude --version`、`codex login status`、`agy models | head -1`。列出可用者。
2. 問主模型：預設 claude。若人選其他 kind，對 `dkboai/roles/*.md` 每一檔：把 `kind:` 改成該 kind，並用 `dkboai/kinds/<kind>.sh` 的 `KIND_DEFAULT_TIERS` 覆寫 `tiers:` 三檔（reviewer 沒有 S）。逐角色列出改後的值讓人確認或修改。同步更新 `dkboai/roles/README.md` 的表。
3. 問第二、第三意見工具：只列可用且非主模型者。把結果寫進 `dkboai/LEADER.md` 的「評議波」段落，替換範例中的 `--kind codex` / `--kind agy`。沒裝的不列。
4. 預填 `dkboai/PROJECT.md`：先讀既有的 `CLAUDE.md`、`AGENTS.md`、`.claude/rules/*.md`（若存在），從中抽技術棧、測試指令、慣例；再看 package.json / pyproject.toml / go.mod / Cargo.toml / Makefile 補齊。保持 ≤40 行，不重複既有指令檔已寫的規則，只寫事實。給人確認後存檔。
4b. 衝突掃描：比對既有指令檔與 `dkboai/PROTOCOL.md`、`dkboai/LEADER.md` 會打架的規則，至少查這幾類：要求使用 subagent 或平行 agent、要求直接 commit/push 到 main、禁止建分支或 worktree、要求每次改動都問人。逐條列出「既有規則 vs dkboai 規則」，讓人決定改哪一邊。不自動修改既有檔案。
5. MCP 檢查：對每個已選 kind 執行 `bash -c '. dkboai/lib/common.sh; . dkboai/lib/kinds.sh; dk_kind_load <kind>; kind_mcp_list'`，比對所有角色檔 `mcp:` 清單。缺的列出，並印出對應指令範本（`claude mcp add <name> -- <cmd>` / `codex mcp add <name> -- <cmd>` / `agy mcp add <name> <cmd>`）讓人自己執行。不要代寫含認證的設定。
6. 結束時列出：可用工具、主模型、評議成員、PROJECT.md 行數、缺少的 MCP。
```

- [ ] **Step 5: Write `dkboai/skills/add-role/SKILL.md`**

```markdown
---
name: dkboai-add-role
description: 為 dkboai 團隊新增一個角色（例如 translator、designer）。問職責與交接，偵測可用 AI 工具讓人選，依難度建議 S/M/L 三檔的 model/effort 讓人確認，產出 roles/<name>.md 並登錄團隊表。
---
# dkboai add-role

一次問一題。

1. 問角色名（ascii 小寫，符合 `[a-z][a-z0-9_-]*`）、一句職責、交接對象（做完給誰驗、被誰用）。
2. 偵測可用工具：`bash -c '. dkboai/lib/common.sh; . dkboai/lib/kinds.sh; dk_kinds_available'`。
3. 讓人選 kind，預設推薦 claude。
4. 讀 `dkboai/kinds/<kind>.sh` 的 `KIND_MODELS`、`KIND_EFFORTS`。依職責難度建議三檔（S 小改照做、M 一般、L 需設計判斷），每檔一個 `model/effort`，說明理由。純產出型角色（翻譯、整理）L 檔也不必用最高 model。
5. 逐檔讓人確認或改。
6. 寫 `dkboai/roles/<name>.md`，frontmatter 依序：`name kind tiers(S M L) worktree split mcp`，正文三段：`## 職責`（3–5 行）、`## 完成定義`、`## 交接對象`。`worktree` 對不碰程式碼的角色設 false。`split` 預設 right。
7. 在 `dkboai/roles/README.md` 表尾加一行。
8. 用 `bash -c '. dkboai/lib/common.sh; . dkboai/lib/frontmatter.sh; . dkboai/lib/kinds.sh; for t in S M L; do v=$(dk_fm_tier dkboai/roles/<name>.md $t); [ -n "$v" ] && dk_kind_args <kind> "$v"; done'` 驗證三檔都能轉成旗標。
```

- [ ] **Step 6: Write `dkboai/README.md`**

```markdown
# dkboai

以 herdr 為底的多模型 AI 團隊：一位領導（Claude Code）在主 pane 審查需求、拆波、派工、決策；員工（claude / codex / agy）各佔一個 pane 實作、測試、互相傳訊；所有記憶是小型 markdown，領導失憶可一鍵恢復。設計文件：`docs/superpowers/specs/2026-09-09-dkboai-ai-team-design.md`。

## 前置需求
- herdr ≥ 0.9.0（`herdr --version`），且你在 herdr 的 pane 裡（`echo $HERDR_ENV` 印 `1`）。
- git、jq、bash 5。
- 至少一個 AI CLI：`claude`（必要，領導用）。可選 `codex`、`agy`（第二、第三意見）。
- 目標專案是 git repo，且工作樹乾淨。

## 給 AI 的一鍵安裝
把下面整段貼給在 herdr 內、目標專案根目錄開啟的 Claude Code（或任何能跑 bash 的 agent）：

> 請在目前專案安裝 dkboai。依序執行以下指令，任何一步失敗就停下回報，不要自行變通：
>
> ```bash
> test "$HERDR_ENV" = 1 || { echo "不在 herdr 內，請先用 herdr 開啟終端"; exit 1; }
> herdr --version && command -v jq git claude >/dev/null || { echo "缺少 herdr/jq/git/claude"; exit 1; }
> git status --porcelain | grep -q . && { echo "工作樹不乾淨，請先 commit 或 stash"; exit 1; }
> REPO=https://github.com/dkbo/dkboai.git   # fork 的話改這裡
> tmp=$(mktemp -d) && git clone -q --depth 1 "$REPO" "$tmp" && cp -r "$tmp/dkboai" ./dkboai && rm -rf "$tmp"
> dkboai/install.sh
> git add -A && git commit -m "chore: add dkboai"
> dkboai/bin/dk-whoami   # 預期印出 leader
> ```
>
> 全部成功後執行 `/dkboai-init`，依它的提問完成初始化。

預期輸出的最後兩行：
```
dkboai installed into /path/to/project
leader
```

## 手動安裝（同一件事拆開）
1. 複製 `dkboai/` 到專案根目錄。
2. `dkboai/install.sh`：在 `.claude/skills/` 與 `.agents/skills/` 建 `dkboai-init`、`dkboai-add-role` 兩個 symlink；在 `AGENTS.md` 尾端追加一行指向 `dkboai/ENTRY.md`；在 `CLAUDE.md` 尾端追加 `@AGENTS.md`（CLAUDE.md 若是 AGENTS.md 的 symlink 則略過）；`.gitignore` 加 `dkboai/.sessions/`。既有內容一律不動。
3. `git add -A && git commit`。員工在 worktree 工作，只看得到已 commit 的檔案，這步不能省。
4. 在 herdr 內的 Claude Code 執行 `/dkboai-init`：偵測已裝的 AI CLI、選主模型與第二三意見、改寫角色檔的 model/effort、預填 `dkboai/PROJECT.md`、掃描既有 CLAUDE.md / AGENTS.md 與 dkboai 規則的衝突、檢查 MCP 需求。

## 驗證
```bash
dkboai/bin/dk-whoami            # leader
ls -l .claude/skills .agents/skills | grep dkboai   # 四個 symlink
tail -1 AGENTS.md CLAUDE.md     # 分別是入口行與 @AGENTS.md
```

## 日常使用
- 開任務：對領導說「開任務 login，顯示名『使用者登入』，需求是…」。領導會寫 brief 給你確認（關卡①）、分波派工、員工升報時問你（關卡②）、結案時給你 report 拍板（關卡③）。
- 雜務：對領導說「翻譯 README 成英文」「先修登入頁那個 bug」。領導評估後派一位員工，不自己動手。
- 領導失憶：在領導 pane `/clear`，然後說「執行 dkboai/bin/dk-resume 然後繼續」。
- 第二位領導：在任何 herdr shell 執行 `dkboai/bin/dk-leader pay "金流"`。
- 新角色：`/dkboai-add-role`。

## 目錄
| 路徑 | 用途 |
|---|---|
| `ENTRY.md` | 唯一入口，決定你是領導或員工 |
| `LEADER.md` / `PROTOCOL.md` | 領導規範 / 通訊協定與升報規則 |
| `roles/` | 角色檔（kind、S/M/L 三檔、職責） |
| `kinds/` | 各 AI CLI 的旗標對應 |
| `bin/` | `dk-*` 腳本，全部封裝 herdr |
| `tasks/<日期-短名>/` | 一個任務的全部記憶：brief、process、report、messages.log、state/ |
| `tasks/INDEX.md`、`tasks/BACKLOG.md`、`decisions.md`、`PROJECT.md` | 跨任務記憶 |

## 更新 dkboai
只更新核心，保留你的 `tasks/`、`PROJECT.md`、`decisions.md` 與自訂角色：
```bash
tmp=$(mktemp -d) && git clone -q --depth 1 https://github.com/dkbo/dkboai.git "$tmp"
rsync -a --exclude=tasks --exclude=PROJECT.md --exclude=decisions.md --exclude='roles/*' --exclude=.sessions "$tmp/dkboai/" ./dkboai/
rsync -a --ignore-existing "$tmp/dkboai/roles/" ./dkboai/roles/   # 只補新角色，不覆蓋既有
rm -rf "$tmp" && dkboai/install.sh && git add -A && git commit -m "chore: update dkboai"
```

## 疑難排解
| 症狀 | 原因 / 處理 |
|---|---|
| `dk: not running inside herdr` | 不是從 herdr 的 pane 執行。`herdr` 開啟終端後再試。 |
| 員工 pane 說找不到 `dkboai/` | 安裝後沒 commit，worktree 看不到。commit 後重新 `dk-spawn`。 |
| 員工卡住不動 | 卡在審批對話框。dk-watch 會通知；切到該 pane 按同意，或檢查 `kinds/<kind>.sh` 的免審批旗標。 |
| codex / agy 不照協定回訊 | 確認 `AGENTS.md` 最後一行是入口行，且該 worktree 分支含這個 commit。 |
| 領導自己開始寫程式 | 提醒它讀 `dkboai/LEADER.md`；必要時 `/clear` 後 `dk-resume`。 |
```

Also write the repo-root `README.md`:
```markdown
# dkboai

多模型 AI 開發團隊套件，可攜目錄在 `dkboai/`。安裝、使用、更新與疑難排解全部在 **[dkboai/README.md](dkboai/README.md)**；把那份 README 的「給 AI 的一鍵安裝」段落貼給 Claude Code 即可安裝。

- 設計規格：`docs/superpowers/specs/2026-09-09-dkboai-ai-team-design.md`
- 實作計畫：`docs/superpowers/plans/2026-09-10-dkboai-ai-team.md`
- 測試：`tests/run.sh`（單元）、`tests/integration/`（真 herdr）、`tests/smoke/`（真 agent）、`tests/e2e/RUNBOOK.md`
```

- [ ] **Step 7: Run** → `5 tests, 0 failures`

- [ ] **Step 8: Commit**

```bash
git add README.md dkboai/README.md dkboai/install.sh dkboai/skills tests/unit/14_install.bats
git commit -m "feat: install.sh, init/add-role skills, AI-installable README

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 15: Layer 2 — real herdr verification script

**Files:**
- Create: `tests/integration/herdr-real.sh`, `tests/integration/README.md`

**Interfaces:**
- Consumes: a running herdr (`HERDR_ENV=1`). Uses a named session `dktest` so nothing touches the user's session.
- Produces: a script that exits 0 when every assumption the stub encodes holds on real herdr 0.9.0, printing `OK <check>` / `FAIL <check>`. Checks: (a) `pane split ... --env K=V` JSON has `.result.pane.pane_id`; (b) the env var is visible inside the new pane (`pane run <id> 'echo DKENV=$DK_TEST'` then `pane wait-output --match DKENV=42`); (c) `agent rename <pane> name` works on a pane without an agent → record actual behaviour (expected: error; then the script starts `claude` in the pane only if `DK_REAL_AGENT=1`); (d) `worktree create` JSON keys (`.result.workspace.workspace_id`, `.result.root_pane.pane_id`, whether `.result.path` exists); (e) `notification show` returns 0; (f) `pane close` returns 0. Any key mismatch is printed as `FAIL` with the actual JSON so the stub files in `tests/stub/responses/` can be corrected.

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Layer 2: verify herdr JSON shapes and behaviours the stub assumes. Runs in a separate named session.
set -uo pipefail
[ "${HERDR_ENV:-}" = 1 ] || { echo "run inside herdr"; exit 2; }
ok(){ echo "OK   $*"; }; fail(){ echo "FAIL $*"; rc=1; }; rc=0
tmp=$(mktemp -d); git -C "$tmp" init -q; git -C "$tmp" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
H="herdr --session dktest"
ws=$($H workspace create --cwd "$tmp" --no-focus 2>&1) || { echo "$ws"; fail "workspace create"; exit 1; }
root=$(echo "$ws" | jq -r '.result.root_pane.pane_id'); [ -n "$root" ] && ok "workspace create root_pane=$root" || fail "workspace create shape: $ws"
sp=$($H pane split --pane "$root" --direction right --cwd "$tmp" --no-focus --env DK_TEST=42 2>&1)
p=$(echo "$sp" | jq -r '.result.pane.pane_id // empty'); [ -n "$p" ] && ok "pane split pane_id=$p" || fail "pane split shape: $sp"
$H pane run "$p" 'echo DKENV=$DK_TEST' >/dev/null 2>&1
$H pane wait-output "$p" --match 'DKENV=42' --timeout 10000 >/dev/null 2>&1 && ok "--env inherited by pane shell" || fail "--env not visible: $($H pane read "$p" --lines 20)"
rn=$($H agent rename "$p" dktest-x 2>&1) && ok "agent rename on empty pane accepted" || ok "agent rename on empty pane rejected (expected): $(echo "$rn" | head -c 200)"
wt=$($H worktree create --workspace "$(echo "$ws" | jq -r '.result.workspace.workspace_id')" --branch dk/test --base "$(git -C "$tmp" rev-parse --abbrev-ref HEAD)" --cwd "$tmp" --no-focus 2>&1)
echo "$wt" | jq -e '.result.workspace.workspace_id and .result.root_pane.pane_id' >/dev/null 2>&1 && ok "worktree create shape" || fail "worktree create shape: $wt"
echo "$wt" | jq -e '.result.path' >/dev/null 2>&1 && ok "worktree create has .result.path" || echo "NOTE worktree create has no .result.path; dk-task-new falls back to git worktree list"
$H notification show "dkboai layer2" --body ok >/dev/null 2>&1 && ok "notification show" || fail "notification show"
$H pane close "$p" >/dev/null 2>&1 && ok "pane close" || fail "pane close"
wsid=$(echo "$wt" | jq -r '.result.workspace.workspace_id // empty'); [ -n "$wsid" ] && $H worktree remove --workspace "$wsid" --force >/dev/null 2>&1
$H workspace close "$(echo "$ws" | jq -r '.result.workspace.workspace_id')" >/dev/null 2>&1
echo "raw responses saved to $tmp/*.json for stub updates"; printf '%s' "$sp" > "$tmp/pane_split.json"; printf '%s' "$wt" > "$tmp/worktree_create.json"
exit $rc
```

- [ ] **Step 2: Run it once**

Run: `chmod +x tests/integration/herdr-real.sh && tests/integration/herdr-real.sh`
Expected: all `OK`. For each `FAIL`, fix the corresponding `tests/stub/responses/*.json` and the `jq` path in the script that reads it, re-run the unit suite, and record the finding in the spec's section 12 list (mark verified).

- [ ] **Step 3: Write `tests/integration/README.md`** with the two commands above and the note that it needs a live herdr and creates session `dktest` only.

- [ ] **Step 4: Commit**

```bash
git add tests/integration docs/superpowers/specs
git commit -m "test: layer-2 real herdr verification script

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 16: Layer 3 — one real agent per kind

**Files:**
- Create: `tests/smoke/kind-smoke.sh`
- Modify: `dkboai/kinds/{claude,codex,agy}.sh` (`KIND_PROMPT_QUEUES` value)

**Interfaces:**
- Consumes: a live herdr session, a real installed CLI for the kind under test, the full `dkboai/` package installed into a temp project.
- Produces: `tests/smoke/kind-smoke.sh <kind>`: creates a temp git project, runs `dkboai/install.sh`, `dk-task-new smoke "smoke"` with a brief that owns `notes/**` for role `it`, `dk-spawn it --tier S --kind <kind>`, waits for `state/it.md` to appear (≤120 s), then tests queuing: `herdr agent prompt <agent> "請把 notes/a.txt 寫入 100 行遞增數字，然後 dk-msg leader \"[DONE] a\""` immediately followed (while working) by `dk-msg <agent> "[TASK] 完成後再把 notes/b.txt 寫入 hello 並 dk-msg leader \"[DONE] b\""`; waits up to 180 s for `messages.log` to contain both `[DONE] a` and `[DONE] b`. Prints `QUEUES=yes|no` and, with `--write`, updates `KIND_PROMPT_QUEUES` in `dkboai/kinds/<kind>.sh`. Finishes with `dk-wave-close --force` and `dk-task-close --abandon smoke`.

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Layer 3: one real agent of <kind>: spawn → state → DONE, plus prompt-while-working queue check.
set -euo pipefail
kind="${1:?kind}"; write=0; [ "${2:-}" = --write ] && write=1
[ "${HERDR_ENV:-}" = 1 ] || { echo "run inside herdr"; exit 2; }
repo="$(cd "$(dirname "$0")/../.." && pwd)"
tmp=$(mktemp -d); cp -r "$repo/dkboai" "$tmp/"; cd "$tmp"
git init -q; git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init; git branch -M main
dkboai/install.sh >/dev/null; export DK_ROOT="$tmp/dkboai"; PATH="$tmp/dkboai/bin:$PATH"
dir=$(dk-task-new smoke "smoke")
cat >> "$dir/brief.md" <<'B'
| it | notes/** | — |
B
printf '| 1 | 實作 | it | 在 notes/ 建檔 | S | leader 收到 DONE |\n' >> "$dir/brief.md"
mkdir -p notes
dk-spawn it --tier S --kind "$kind"
. dkboai/lib/common.sh; DK_TASK_DIR="$dir"; export DK_TASK_DIR; dk_task_env; agent=$(dk_agent_name it)
for _ in $(seq 1 60); do [ -f "$dir/state/it.md" ] && break; sleep 2; done
[ -f "$dir/state/it.md" ] && echo "OK state file created" || { echo "FAIL no state file"; herdr agent read "$agent" --lines 60; exit 1; }
herdr agent prompt "$agent" "請把 notes/a.txt 寫入 100 行遞增數字，完成後執行 dkboai/bin/dk-msg leader \"[DONE] a\"" >/dev/null
sleep 2
DK_MSG_WAIT_MS=1000 dk-msg "$agent" "[TASK] 完成後再把 notes/b.txt 寫入 hello，並執行 dkboai/bin/dk-msg leader \"[DONE] b\"" || true
q=no; for _ in $(seq 1 90); do grep -q '\[DONE\] a' "$dir/messages.log" && grep -q '\[DONE\] b' "$dir/messages.log" && { q=yes; break; }; sleep 2; done
echo "QUEUES=$q"
if [ "$write" = 1 ]; then sed -i "s/^KIND_PROMPT_QUEUES=.*/KIND_PROMPT_QUEUES=$q/" "$repo/dkboai/kinds/$kind.sh"; fi
dk-wave-close --force || true; dk-task-close --abandon smoke >/dev/null || true
echo "done: $tmp"
```

Note on the queue check: `dk-msg` first waits for idle, so with `DK_MSG_WAIT_MS=1000` it will time out and log `[UNDELIVERED]` if the agent is still working. To test raw queuing, replace that `dk-msg` line with a direct `herdr agent prompt "$agent" "[TASK] from leader-smoke: ..."`. Run both variants; `QUEUES=yes` from the direct prompt means messages survive being pushed mid-turn and `dk-msg` could skip the wait for that kind later (leave the wait on; record only).

- [ ] **Step 2: Run for each kind**

Run: `tests/smoke/kind-smoke.sh claude --write`, then `codex --write`, then `agy --write`.
Expected: `OK state file created` and a `QUEUES=` line for each. If `agy` never creates the state file, read its pane (`herdr agent read`) and check whether it loaded `AGENTS.md`; if not, add the extra instruction file it does read to `install.sh` (spec section 12 item 1) and re-run.

- [ ] **Step 3: Commit**

```bash
git add tests/smoke dkboai/kinds dkboai/install.sh
git commit -m "test: layer-3 per-kind smoke; record prompt queue behaviour

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 17: Example project and end-to-end runbook

**Files:**
- Create: `example/package.json`, `example/src/api.js`, `example/src/web.js`, `example/test/api.test.js`, `example/README.md`
- Create: `tests/e2e/RUNBOOK.md`

**Interfaces:**
- Produces: a runnable node app (no dependencies; `node --test`) with an obvious two-part feature to build: `POST /login` in `src/api.js` (backend) and a form renderer in `src/web.js` (frontend), plus tests owned by qa. The runbook is the manual layer-4 script a human follows once.

- [ ] **Step 1: Write the example app**

`example/package.json`:
```json
{ "name": "dkboai-example", "private": true, "type": "module", "scripts": { "test": "node --test test/" } }
```
`example/src/api.js`:
```js
import http from 'node:http';
export function createServer() {
  return http.createServer((req, res) => { res.statusCode = 404; res.end('not found'); });
}
```
`example/src/web.js`:
```js
export function renderLogin() { return '<form></form>'; }
```
`example/test/api.test.js`:
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from '../src/api.js';
test('server exists', () => { assert.ok(createServer()); });
```
`example/README.md`: one paragraph: this app exists for `tests/e2e/RUNBOOK.md`; run `npm test`.

- [ ] **Step 2: Verify it runs**

Run: `cd example && npm test`
Expected: `# pass 1`

- [ ] **Step 3: Write `tests/e2e/RUNBOOK.md`**

```markdown
# 端對端示範（層 4，人工一次）

前置：在 herdr 內、`example/` 已 `git init` 並 commit、`cp -r ../dkboai example/dkboai && cd example && dkboai/install.sh`。開 Claude Code（S 檔即可：`claude --model sonnet --effort low`）。

1. 對領導說：「開任務 login，顯示名『使用者登入』。需求：POST /login 接 JSON {user,pass}，空密碼回 400，正確回 200；web.js 的 renderLogin 產出含 user/pass 欄位的表單；qa 寫測試驗證兩者。」
2. 預期：領導執行 dk-task-new，寫 brief（所有權：backend=src/api.js，frontend=src/web.js，qa=test/**；波次表 wave1 backend(M)+qa(S)，wave2 frontend(S)+qa(S)），問你確認（關卡①）。回「OK」。
3. 預期：領導 `dk-task-new login --gate1`，`dk-spawn backend`、`dk-spawn qa`，然後閒置。切到 worktree workspace 觀察兩個 pane。
4. 故意製造一次 BUG 迴圈：在 qa 的 state 出現前對 qa pane 說「空密碼要回 400，請嚴格驗」。看 messages.log 出現 `[BUG]` → `[FIXED]`。
5. 若 qa 第二次仍失敗會 `[ESCALATE]` 給領導；領導應在 pane 裡問你（關卡②）。回一個決策，看 `[DECISION]` 進 log、decisions.md 多一行。
6. 兩人 DONE 後領導 `dk-wave-close` 並 commit `wave 1: ...`。檢查 process.md。
7. 在領導 pane 執行 `/clear`，再說「執行 dkboai/bin/dk-resume 然後繼續」。預期：領導讀回恢復包，正確開 wave2（frontend + qa）。
8. wave2 DONE、wave-close 後，領導寫 report.md 給你看（關卡③）。回「合併」。預期 `dk-task-close` 合併回 main、worktree 移除、INDEX 為 done。
9. 雜務：對領導說「請翻譯 README.md 成英文」。預期領導發現沒有 translator 角色 → 跑 add-role → `dk-chore translator "..."`；完成後 INDEX 多一行 chore。
10. 記錄：把每步實際發生與預期的差異寫到 `tests/e2e/RESULTS-<日期>.md`。

驗收：process.md 有 task-new / gate1 / wave1 / escalate / wave-close / wave2 / task-close 各一行以上；messages.log 有 BUG、FIXED、ESCALATE、DECISION、DONE；report.md 存在；`git log` 有兩個 wave commit 與一個 merge commit；dk-resume 輸出 ≤150 行。
```

- [ ] **Step 4: Commit**

```bash
git add example tests/e2e
git commit -m "docs: example app and e2e runbook for layer-4 demo

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Spec coverage check

| Spec section | Tasks |
|---|---|
| 2 目錄結構、目標專案側 | 0, 4, 14 |
| 3 角色、tiers、LEADER.md、命名 | 1, 4, 7 |
| 4 通訊協定、dk-msg、dk-spawn 首段提示、dk-watch | 4, 6, 7, 9 |
| 5 生命週期：task-new、gate1、wave-close、resume、task-close、dk-leader、故障 | 5, 8, 10, 12, 13 |
| 6 雜務 dk-chore（含 --code） | 11 |
| 7 記憶格式（templates、INDEX、BACKLOG、decisions、.sessions） | 0, 4, 5 |
| 8 kinds 對應表 | 3, 16 |
| 9 skills init / add-role | 14 |
| 10 MCP 立場（聲明、init 檢查、spawn 警告） | 3, 7, 14 |
| 11 測試四層 | 0（層1）, 15（層2）, 16（層3）, 17（層4） |
| 12 待驗證假設 | 15, 16 |
