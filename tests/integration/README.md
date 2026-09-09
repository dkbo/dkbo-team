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

This script is zero-token: it never starts a real coding agent. Exercising a real agent
(e.g. `claude`) against herdr is layer 3's job (`tests/smoke/`), not this script.

## Running from inside a herdr pane (nested)

If you run this from a terminal that is *itself* already inside a herdr-managed pane
(`HERDR_ENV=1`), the `dktest` session's server won't exist yet, and real herdr refuses to
launch a second, nested TUI attach by default ("nested herdr is disabled by default").
You only need to bootstrap the `dktest` session's server once — the verification script
itself never attaches or launches a TUI, it only talks to the `dktest` socket once that
session is up. To bootstrap it:

```bash
mkdir -p /tmp/dktest-herdr-config
cat > /tmp/dktest-herdr-config/config.toml <<'EOF'
[experimental]
allow_nested = true
EOF
setsid nohup env HERDR_CONFIG_PATH=/tmp/dktest-herdr-config/config.toml \
  herdr session attach dktest </dev/null >/tmp/dktest-attach.log 2>&1 &
disown
sleep 4
cat /tmp/dktest-attach.log   # expect: "herdr: Not a tty (os error 25)"
herdr session list           # expect: dktest now shows status "running"
```

The attach process itself still fails with `herdr: Not a tty (os error 25)` (it can't
draw a TUI without a real terminal), but by the time it fails the session's headless
server has already started and stays running, so `herdr --session dktest ...` API calls
work from then on. This uses a throwaway config file via `HERDR_CONFIG_PATH` — it does
not modify your real `~/.config/herdr/config.toml`.

After the run, tear the whole `dktest` session down so nothing persists:

```bash
herdr session stop dktest
herdr session delete dktest
rm -rf /tmp/dktest-herdr-config /tmp/dktest-attach.log
herdr session list   # expect: only "default" remains
```

If your terminal is *not* inside a herdr pane already, none of the above is needed —
`herdr --session dktest ...` will create and start the session on first use like any
other named session, per `herdr session --help`.

## Last run

2026-09-10, real herdr 0.9.0: all checks `OK`, one `NOTE` (real herdr's `worktree create`
has no `.result.path`; `dk-task-new`/`dk-chore` already fall back to
`git worktree list --porcelain`, confirmed working). No `FAIL`s against the stub shapes
themselves; one bug found and fixed in this script (real herdr rejects `--workspace` +
`--cwd` together on `worktree create` — production code only ever passes `--cwd`, so it
was unaffected). Unit suite (`tests/run.sh`) re-checked at 73/73 passing since no stub or
`.dkboai/` script changes were needed.
