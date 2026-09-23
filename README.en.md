# dkbo

[繁體中文](README.md) · **English**

A multi-model AI development team packaged as one portable directory, `.dkbo/`, built on top of herdr. One leader (Claude Code) sits in the main pane, reads the request, writes the brief, splits the work into waves, dispatches, and rules on escalations. Workers (`claude`, `codex`, `agy`) each get their own pane to implement, test, review, and message each other. Every piece of memory is a small markdown file, so a leader that loses its context recovers with one command. Copy `.dkbo/` into any git project and it works.

- Current version: `.dkbo/VERSION` (0.13.0); history in [CHANGELOG.md](CHANGELOG.md)
- Repo: https://github.com/dkbo/dkbo-team
- Full install, update and troubleshooting manual: **[.dkbo/README.md](.dkbo/README.md)** (Traditional Chinese)

## Why

A single agent working on a medium-sized feature hits three walls: it forgets things once its context fills up, it confirms its own mistakes without a second opinion, and it steps on files that belong to someone else. dkbo answers with three mechanisms:

- **Memory lives on disk.** Everything about a task (brief, process log, each worker's state and report, the message log) is a file. After `/clear`, invoke `/dkbo-run` to carry on (its first step is `dk-resume`). A dead worker is re-spawned with `--resume`.
- **A multi-model review gate on every wave.** When a wave's implementation is done the leader dispatches one to three read-only reviewers, optionally of different kinds. `dk-wave-close` refuses until a verdict is recorded, every dev report has a filled test section, the project's test command passes, and the real diff stays inside the wave's declared ownership.
- **File ownership.** Each member's writable globs are declared in the brief and may not overlap. `dk-brief-check` blocks overlaps up front; afterwards `dk-wave-close` compares the worktree's **real git diff** (uncommitted and untracked work included) against those globs and refuses to close a wave that changed a file no member of it owns.

## How it works

```
you ──chat──▶ leader (Claude Code, left column of tab 1)
                │  dk-task-new / dk-leader --run / dk-spawn / dk-review / dk-wave-close / dk-task-close
                ▼
        worker panes (herdr splits, each inside the task worktree)
        backend · frontend · qa · reviewer-a(claude) · reviewer-b(codex) …
                │  dk-msg: [DONE] [BUG] [FIXED] [QUESTION] [ESCALATE] …
                ▼
        .dkbo/tasks/<date-short>/  brief.md · process.md · state/ · messages.log · report.md
```

**Life of a task**

1. You invoke `/dkbo-plan` and tell it: "open task login, display name 'User login', requirements are…".
2. The leader writes `brief.md`: goal, acceptance criteria, file ownership, shared contracts, and a wave table with one row per member tagged S/M/L. It runs `dk-brief-check` and only then moves on to review. Next `dk-brief-review` dispatches 2 to 3 reviewers of different kinds to read the raw request and the brief; the leader rules on their feedback, revises the brief, and only then hands you all three — the raw request, the brief, and a summary of the ruling — to confirm. This is **gate 1**.
3. You invoke `/dkbo-run`: only then does `dk-leader <short> --run` "materialize" the task — one worktree per repo in `DK_REPOS` (a multi-repo project; see [.dkbo/README.md](.dkbo/README.md), Traditional Chinese), a new tab labeled `dk/<short>` opened in the task's workspace (`.task.env`'s `DK_WORKSPACE`, recorded at plan time; falls back to `HERDR_WORKSPACE_ID` when empty), and a handoff to an execution leader in its root pane, freeing your session for the next task. Each wave: `dk-wave-open` writes a per-member slice of the brief, `dk-spawn` opens a pane and sends the first prompt. Workers may only edit files they own (in a multi-repo project, ownership and `touched` carry a `<name>:` prefix). When done they write their state and report and send `dk-msg leader "[DONE] …"`.
4. After a dev is done the leader runs `dk-review-pack` to build the diff pack and `dk-review` to dispatch reviewers; reviewers and qa run in parallel. Important findings go back to the dev as a BUG. One fix attempt per bug, then it escalates.
5. Any A-or-B choice, any edit outside one's ownership, any tight context: the worker sends `[ESCALATE]`. If the brief settles it the leader replies `[DECISION]` and records a ruling; otherwise it asks you. This is **gate 2**.
6. Once qa is done and the review has a verdict, `dk-wave-close` applies four gates — the verdict line, every dev's `## 測試` section, `DK_TEST_CMD`, and an ownership check against the worktree's real diff — then closes the panes and commits the wave inside the worktree (`-m` sets the message).
7. After the last wave the leader runs a whole-branch review, then writes `report.md` for you to sign off. This is **gate 3**. `dk-task-close` merges into the main branch, removes the worktree, and marks the task done in INDEX.

**Chores.** Small jobs outside any task ("translate the README", "fix that login page bug first") go through `dk-chore`, which dispatches one worker. With `--code` the worker gets its own worktree branch that `dk-chore-close` merges back. Chore workers report with `dk-msg leader`, which waits for the leader to be idle before delivering, so nothing is lost while the leader is mid-turn.

**Layout.** The leader owns the left column of tab 1; workers fill a 2×2 or 3×2 grid on the right. From the fifth worker a new tab is opened automatically, and closed panes trigger a re-balance.

## Quick start

Prerequisites: herdr ≥ 0.9.0 and a shell inside one of its panes (`echo $HERDR_ENV` prints `1`; the version is enforced by every dk-* command and by `install.sh` — older refuses to run, newer than the verified 0.9.x prints a one-off nudge to run the integration test), git >= 2.17, jq >= 1.5, bash 3.2+ (the version macOS ships is enough; `flock` is a soft dependency and its absence degrades to unlocked writes), and at least one of the three AI CLIs (`claude`, `codex`, `agy`). Which one drives the leader is set by `DK_LEADER_KIND` (default `claude`); the rest serve as workers and second/third opinions. The target project must be a clean git repo.

Paste this into a Claude Code session running inside herdr at the project root:

```bash
test "$HERDR_ENV" = 1 || { echo "not inside herdr"; exit 1; }
git status --porcelain | grep -q . && { echo "working tree dirty, commit first"; exit 1; }
VER=v0.13.0; tmp=$(mktemp -d) && git clone -q --depth 1 --branch "$VER" https://github.com/dkbo/dkbo-team.git "$tmp" \
  && (cd "$tmp/.dkbo" && rm -rf tasks decisions.md PROJECT.md settings.env .sessions) \
  && cp -r "$tmp/.dkbo" ./.dkbo && rm -rf "$tmp"
.dkbo/install.sh && git add -A && git commit -m "chore: add dkbo"
.dkbo/bin/dk-whoami   # expected: leader
```

Then run `/dkbo-init`. It detects installed AI CLIs, lets you pick the leader kind (`DK_LEADER_KIND`) and the workers' primary model plus second/third-opinion kinds, writes `settings.env`, wires the entry files, pre-fills `PROJECT.md`, and scans your existing CLAUDE.md / AGENTS.md for rules that conflict with dkbo's. Manual install and upgrade steps are in [.dkbo/README.md](.dkbo/README.md).

## Roles and kinds

Role files live in `.dkbo/roles/<role>.md`. The frontmatter declares the kind and the S/M/L tiers (model and effort); the body is the job description and the definition of done. `/dkbo-add-role` adds a new one.

| Role | In one line |
|---|---|
| pm | Turns requirements into verifiable acceptance criteria; writes no code |
| frontend / backend | UI / API and data layer; edits only owned files |
| qa | Verifies against the acceptance criteria and files BUGs; never fixes |
| it | Environment, dependencies, CI, merge-conflict repair |
| reviewer | Read-only review of the diff pack (spec compliance / Important / Minor); never edits |

A kind maps an AI CLI to its flags, in `.dkbo/kinds/`: `claude` (opus / sonnet), `codex` (gpt-5.5), `agy` (gemini). Reviewers can be given a different kind from the implementers to get a genuine second opinion.

## Commands

All live in `.dkbo/bin/` and wrap herdr. Only the leader uses them; workers use `dk-msg` and nothing else.

| Command | What it does |
|---|---|
| `dk-whoami` | Is this pane the leader or a worker |
| `dk-task-new` / `dk-brief-check` | Create the task directory only (no worktree — `/dkbo-run` materializes it at handoff); mechanical brief check |
| `dk-brief-review` | Before work starts, dispatch 1 to 3 reviewers to review the brief and the raw request (an AI gate, the second one before gate 1) |
| `dk-wave-open N` / `dk-spawn <role>` | Open a wave and write member slices (`--refresh` re-derives every member's slice for wave N from the current brief and resets the wave timeout); open a worker pane and prompt it |
| `dk-kind [status]` / `dk-kind up <k>` | List kinds tripped at the project level and their recovery time; clear the breaker for one kind |
| `dk-msg <target> "[TYPE] body"` | Wait until the target is idle, deliver, log to messages.log |
| `dk-review-pack N` / `dk-review` | Build the diff pack; dispatch one to three reviewers |
| `dk-wave-close` | Four gates, then close panes and commit the wave inside the worktree |
| `dk-process` / `dk-resume` | Append an event; print the recovery pack (brief, current wave, rulings, unread messages, plus how long the task and the current wave have been running and how long each worker has been waiting) |
| `dk-timeline` | Read-only: compute the whole timeline from process.md (task, planning, each wave's dev and review, close-out); `dk-task-close` appends it to report.md |
| `dk-task-close` | Merge into the main branch, remove the worktree, mark INDEX done |
| `dk-chore` / `dk-chore-close` | Dispatch and finish a chore |
| `dk-chore-tidy` | File chore notes under their date folder, archive `messages.log` (only when no chore is running) |
| `dk-watch` | Background watcher: pushes `[BLOCKED]` when a worker is stuck on an approval, `[TIMEOUT]` when a reviewer overruns, and trips the breaker for that kind. `--ensure` restarts it idempotently (dk-spawn, dk-wave-open and dk-resume all call it); `--chores` watches the chore side |
| `dk-leader` / `dk-version` | Start a second leader (kind from `DK_LEADER_KIND`, tier L of that kind); `--run` materializes the task (worktrees per `DK_REPOS`, a task tab in the task's workspace (`.task.env`'s `DK_WORKSPACE`, recorded at plan time)) and hands off to the execution leader in that tab's root pane; print the version |

## Layout of the repo

```
.dkbo/
  ENTRY.md            the only entry point: dk-whoami identifies you; the leader must invoke a skill to start
  LEADER.md           shared leader rules (hard boundaries, settings.env, ruling format)
  skills/             init, add-role, plus the brain / plan / run stage rules (install.sh symlinks them into .claude/skills and .agents/skills)
  PROTOCOL.md         messaging protocol: types, escalation rules, stop conditions, state / report formats
  PROJECT.md          project facts, ≤40 lines, pre-filled by init
  settings.env        DK_LEADER_KIND, DK_TEST_CMD, DK_REVIEW_KINDS, DK_REVIEW_MIN, DK_REVIEW_TIER, DK_REVIEW_TIMEOUT_MIN, DK_TAB1_SLOTS, DK_WAVE_TIMEOUT_MIN
  roles/  kinds/      role files; flag mappings per AI CLI
  bin/  lib/          dk-* scripts and shared functions
  templates/          brief, slice, state, report and chore templates
  tasks/<date-short>/ all memory for one task
  tasks/INDEX.md  tasks/BACKLOG.md  decisions.md   cross-task memory
tests/                unit (bats, fake herdr), integration (real herdr), smoke (real agents), e2e RUNBOOK
example/              minimal Node project used by the e2e RUNBOOK
```

## Development and testing

```bash
tests/run.sh                          # unit tests; clones bats-core into tests/lib on first run; uses the fake herdr in tests/stub
tests/integration/herdr-real.sh       # verifies the JSON shapes the stub assumes against a real herdr 0.9.0; zero tokens
tests/smoke/kind-smoke.sh             # verifies each kind's flags and prompt behaviour against real AI CLIs
shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh   # target: zero warnings
```

`tests/e2e/RUNBOOK.md` walks a full task by hand with `example/` as the target project. Every script change starts with a failing bats test.

The unit tests and shellcheck run on every push and pull request via [`.github/workflows/ci.yml`](.github/workflows/ci.yml) (version-string consistency is one of the bats tests). Pushing a `v*` tag additionally checks that the tag matches `.dkbo/VERSION` and that CHANGELOG.md has an entry for it.

## Documents

- [.dkbo/README.md](.dkbo/README.md): install, verify, daily use, upgrade, troubleshooting (Traditional Chinese)
- [.dkbo/LEADER.md](.dkbo/LEADER.md) and [.dkbo/skills/{brain,plan,run}/SKILL.md](.dkbo/skills), [.dkbo/PROTOCOL.md](.dkbo/PROTOCOL.md): the rules the leader and workers actually follow
- Design documents are not version-controlled (`docs/` is gitignored): settled conclusions go into `.dkbo/decisions.md`, and work still to be done becomes a task's `plan.md`.
