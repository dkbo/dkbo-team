# Layer 2: real-herdr verification

`herdr-real.sh` checks the JSON shapes and behaviours that `tests/stub/responses/*.json`
(the fake `herdr` used by the unit suite, `tests/run.sh`) assumes, against a real herdr
0.9.0 install. It runs entirely inside one throwaway named session, `dktest`, so it never
touches your own herdr session, workspaces, or panes.

Run it (from inside a live herdr session, `HERDR_ENV=1`):

```bash
chmod +x tests/integration/herdr-real.sh && tests/integration/herdr-real.sh
```

It creates a scratch git repo under `mktemp -d`, opens a `dktest` session workspace in it,
splits a pane, checks `--env` propagation, checks `agent rename` on a pane with no agent,
runs `worktree create`, `notification show`, and `pane close` — then removes the worktree
and closes the workspace it made. Nothing under session `dktest` should remain afterward
(`herdr --session dktest workspace list` should come back empty, aside from anything you
had open there yourself).

Needs: a real `herdr` 0.9.0+ binary on `PATH`, run from inside an existing herdr-managed
pane (`HERDR_ENV=1`). If your terminal is itself inside a herdr session, starting the
`dktest` session's server requires nested herdr to be allowed (see `[experimental]
allow_nested` in `herdr --default-config`); this script only talks to the `dktest`
socket over the CLI, it does not itself start or attach that session.

Set `DK_REAL_AGENT=1` to also exercise starting a real `claude` agent in the test pane
(off by default — the default run spends zero agent tokens).

## Last run

2026-09-10, real herdr 0.9.0: all checks `OK`, one `NOTE` (real herdr's `worktree create`
has no `.result.path`; `dk-task-new`/`dk-chore` already fall back to
`git worktree list --porcelain`, confirmed working). No `FAIL`s against the stub shapes
themselves; one bug found and fixed in this script (real herdr rejects `--workspace` +
`--cwd` together on `worktree create` — production code only ever passes `--cwd`, so it
was unaffected). Unit suite (`tests/run.sh`) re-checked at 73/73 passing since no stub or
`.dkboai/` script changes were needed.
