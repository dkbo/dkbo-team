# Smoke Tests

The `kind-smoke.sh` script spawns **one real agent** of a given kind in the current `herdr` session and verifies prompt queuing behavior.

**Warning:** This runs a real AI agent and costs tokens. Must be run inside an active `herdr` session (`HERDR_ENV=1`).

## Usage

```bash
tests/smoke/kind-smoke.sh claude --write
tests/smoke/kind-smoke.sh codex --write
tests/smoke/kind-smoke.sh agy --write
```

The `--write` flag updates `KIND_PROMPT_QUEUES` in `.dkboai/kinds/<kind>.sh` with the test result (`yes` or `no`).

## How it Works

1. Creates a temp git project with `.dkboai` installed
2. Spawns an agent of the given kind in role `it` at tier S. `dk-task-new` renames the current pane's agent to `leader-smoke` (the leader in this scenario), and `dk-task-close --abandon` at the end clears that binding.
3. Waits for the agent's state file to appear, then prints `herdr agent list` once (compare its real `agent_status` vocabulary against `dk-watch`'s literal `blocked`)
4. Sends an initial prompt via `herdr agent prompt`
5. While the agent is working, sends a second prompt via a bare `herdr agent prompt` call (the raw queue test — no `dk-msg` wait-for-idle involved)
6. Checks if both prompts completed (both `[DONE]` messages received, ignoring any `[UNDELIVERED]` lines)
7. Records `QUEUES=yes` (messages queued) or `QUEUES=no` (first message timed out)

**Note on queue checking:** The script sends the second prompt with a raw `herdr agent prompt` call while the agent is still busy, to test whether the underlying CLI kind itself queues prompts (independent of `dk-msg`'s own wait-for-idle behavior). Run both variants (this raw check, and a `dk-msg`-based check) if you need to distinguish "the kind queues" from "dk-msg's wait masks a kind that doesn't."
