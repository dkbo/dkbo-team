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
2. Spawns an agent of the given kind in role `it` at tier S
3. Waits for the agent's state file to appear
4. Sends an initial prompt via `herdr agent prompt`
5. While the agent is working, sends a second prompt via `dk-msg` with `DK_MSG_WAIT_MS=1000` (times out if agent is still busy)
6. Checks if both prompts completed (both `[DONE]` messages received)
7. Records `QUEUES=yes` (messages queued) or `QUEUES=no` (first message timed out)

**Note on queue checking:** To test raw queuing instead of `dk-msg`'s wait-for-idle behavior, replace the `dk-msg` line with a direct `herdr agent prompt` call. The script currently uses `dk-msg` with a timeout to detect whether the kind supports queuing.
