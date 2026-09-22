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
`.dkbo/` script changes were needed.

### 2026-09-10, layer 2 §10 follow-up: tab create / `--ratio` / resize / read shapes

Second block added to `herdr-real.sh` (before `notification show`) per
spec 2026-09-10 §10. Bootstrapped a throwaway `dktest` session server (see "Running from
inside a herdr pane" above) since this run was itself inside a herdr pane; torn down
afterward (`herdr session stop/delete dktest`, `herdr session list` back to only
`default`).

Result: 8 `OK`, 0 `FAIL`, three `NOTE` lines:

```
NOTE --ratio 0.3 made the ANCHOR narrower → --ratio is the anchor's share: set DK_RATIO_MEANS=anchor in .dkbo/lib/layout.sh
NOTE resize --amount 0.1 changed width by 12 cells of area 120 (a fraction would give ≈12); if the unit is cells, change dk__layout_amount to print whole cells
NOTE pane/agent read is PLAIN TEXT on herdr 0.9.0; dk-watch falls back to the raw output — keep tests/stub/responses/agent_read.json as JSON only if dk-watch's jq fallback stays
```

(Ruling from review: a layer-2 check that FAILs by design on a real, permanently-true
shape is noise — `dk-watch` already tolerates both the JSON and plain-text shapes, so the
script's `pane read` check was changed from a hard `jq -e '.result.read.text'` assertion
to a branch that accepts either shape as `OK`, emitting a `NOTE` naming which one the
running herdr actually returned. Re-ran against a freshly re-bootstrapped `dktest`
session — see below.)

What changed, and why:

- **`--ratio` semantics — anchor.** `pane split --pane <troot> --direction right --ratio 0.3`
  left the anchor (`troot`) at width 36 of a 120-wide area (36/120 = 0.3) and gave the new
  pane the remaining 84 (0.7). So `--ratio` is the **anchor's** retained share, not the new
  pane's. Changed `.dkbo/lib/layout.sh`: `DK_RATIO_MEANS="${DK_RATIO_MEANS:-new}"` →
  `${DK_RATIO_MEANS:-anchor}`. Left `tests/unit/07_spawn.bats`'s three `--ratio 0.500`
  assertions unchanged, as the brief allows — all of them come from a 0.5 share, and
  `dk_layout_ratio_arg` gives 0.500 under either `DK_RATIO_MEANS` value; `tests/unit/17_layout.bats`'s
  `dk_layout_ratio_arg` test sets `DK_RATIO_MEANS` explicitly in every assertion, so the
  default change doesn't affect it either. `tests/run.sh` confirmed 145/145 still passing.
- **`--amount` unit — fraction, unchanged.** `pane resize --pane <troot> --direction right
  --amount 0.1` changed width by exactly 12 cells on a 120-cell-wide area — precisely
  `120 * 0.1`, i.e. a fraction of the tab area, not a literal cell count (which would have
  changed width by ~0, not 12). This already matches `dk__layout_amount`'s existing
  `awk -v d="$1" -v t="$2" 'BEGIN{printf "%.3f", d/t}'` (cells → fraction). No change made
  to `dk__layout_amount`, `tests/unit/17_layout.bats`'s `--amount -0.050`/`0.050`
  assertions, or `tests/stub/responses/pane_layout.json`.
- **`pane read` / `agent read` shape — plain text on success, not `.result.read.text`
  JSON; check softened to accept either shape.** `herdr api schema --json`'s
  socket-level `PaneReadResult` documents `.result.read.text`, but the CLI (`herdr pane
  read <id> --lines N`, with or without `--raw`/`--format`) prints the bare terminal text
  directly on success — no JSON envelope at all (confirmed on a live pane: valid `jq`
  parse fails, `echo $?` = 5). `herdr agent read` behaves identically on success (only its
  *error* responses — e.g. `agent_not_found` — go through the JSON envelope, confirmed by
  reading a pane with no reported agent). This is a real, permanent discrepancy from the
  schema/stub shape (not a stub field-name/extra-field issue), and `.dkbo/bin/dk-watch`
  (the only production consumer of `agent read` output) already parses defensively —
  `txt=$(printf '%s' "$raw" | jq -r '.result.read.text // .result.text // empty' 2>/dev/null || true); txt="${txt:-$raw}"`
  — falling back to the raw text when `jq` fails. Per review ruling, a layer-2 check that
  `FAIL`s on this permanently-true real shape is noise, so
  `tests/integration/herdr-real.sh`'s `pane read` check was changed from a hard
  `jq -e '.result.read.text'` assertion to a three-way branch: JSON shape → `ok` + a NOTE
  naming it; non-empty plain text → `ok` + a NOTE naming the herdr version and the
  plain-text shape; empty → `fail`. Re-run against a freshly re-bootstrapped `dktest`
  confirmed the plain-text branch: `OK pane read returns plain text` +
  `NOTE pane/agent read is PLAIN TEXT on herdr 0.9.0; ...`. No changes made to
  `.dkbo/bin/dk-watch` or `tests/stub/responses/agent_read.json` — the stub's JSON shape
  stays valid for the unit suite (which fakes herdr and doesn't care what the real CLI
  does), and `dk-watch`'s existing fallback already covers the real plain-text case.
- `tab_create.json` and `pane_layout.json` real captures (`$tmp/tab_create.json`,
  `$tmp/pane_layout.json`) matched the stub's field names exactly (the real payloads carry
  extra fields — `cwd`, `revision`, `scroll`, `terminal_id`, etc. on `root_pane` — that the
  stub omits); per the brief, extra-field-only differences don't warrant a stub change, so
  `tests/stub/responses/tab_create.json` and `pane_layout.json` are unchanged.

Unit suite (`tests/run.sh`) re-checked at 145/145 passing after the `DK_RATIO_MEANS`
default change.

### 2026-09-20, 0.10.0 AC17: workspace create --label / workspace get probes

Two probes added ahead of the multirepo/workspace release (`dk-leader --run` is the first
production caller of both): `workspace create --cwd <主樹> --label dk/<short>` and
`workspace get <id>` (reads `.result.workspace.active_tab_id`, used to rename the tab).

A third probe — `agent start <name> --kind claude --pane <root_pane> -- … --name
dk/<short>` on that workspace's root pane, to cover AC17's "root-pane agent start" leg —
was drafted, run once, and then **removed on leader ruling 2026-09-20**: this script's
documented contract at the top of this file is "zero-token: it never starts a real coding
agent", and starting one (even just to reach the interactive-ready banner, no prompt sent)
crosses that line regardless of whether it burns tokens. Exercising a real `agent start`
against herdr belongs to layer 3 (`tests/smoke/`), not here. AC17 stands satisfied by the
two probes below; the leader's ruling narrowed AC17's "根 pane agent start" requirement to
"covered by the layer-3 smoke suite, not layer 2."

For the record, the removed probe's one finding before it was pulled: `agent start` on a
pane whose cwd it had never seen returned `{"error":{"code":"agent_not_ready","message":
"agent <name> is blocked during startup and is not ready for prompts"}}` — herdr detected
the process but claude itself was sitting at its one-time folder-trust confirmation, not
its normal prompt. Not a herdr-shape mismatch, and not new: `skills/run/SKILL.md` already
documents this exact failure mode for `dk-spawn` in production ("CLI 在啟動時跳了資料夾
信任詢問"). Also tried `--dangerously-skip-permissions` to get a clean "ready" reading
instead — the sandbox's own auto-mode classifier denied that call outright ("Create Unsafe
Agents") and left the `dktest` session's `workspace`-scoped calls denied for the rest of
that shell until `herdr session stop/delete dktest` tore the session down and it was
rebuilt. Both are moot now that the probe is gone, but left here so nobody re-adds it and
re-discovers the same dead end.

Bootstrapped a throwaway `dktest` session server (see "Running from inside a herdr pane"
above, this run was itself inside a herdr pane) and ran `tests/integration/herdr-real.sh`
once against real herdr 0.9.0 with the two-probe version. Result: all checks `OK`, exit 0:

```
OK   workspace create root_pane=w2:p1
OK   workspace create --label shape ws=w3 root=w3:p1
OK   workspace get has .result.workspace.active_tab_id=w3:t1
```

(plus the pre-existing `--ratio`/`--amount`/`pane read` `NOTE` lines further down, unaffected
by this change).

Unit suite (`tests/run.sh`) unaffected — no stub or `.dkbo/` script changes were needed for
this addition, only the integration script and this doc.

### 2026-09-22, 0.11.0 AC17: workspace create --label 換成 tab create（改開 tab）

0.11.0 把 `dk-leader --run` 開任務根的動作從 `herdr workspace create --label` 改成
`herdr tab create --workspace <ws>`（在任務所屬的 workspace 裡開新 tab；`.task.env` 的 `DK_WORKSPACE`，計畫時記下，空時退回 `HERDR_WORKSPACE_ID`），AC17 的兩個探針
（`workspace create --label`／`workspace get`）跟著換成三個：`tab create --workspace <id>
--cwd --label dk/probe --no-focus --env K=V` 驗 `.result.tab.tab_id` 與
`.result.root_pane.pane_id`、`tab get <id>` 成功、`tab close <id>` 成功；不再呼叫
`workspace get`（`DK_WORKSPACE` 從此固定是任務所屬的 workspace（`.task.env` 的 `DK_WORKSPACE`，計畫時記下，空時退回 `HERDR_WORKSPACE_ID`），不需要靠 `active_tab_id`
去 rename）。

在一個重新 bootstrap 的 `dktest` session（見上方「Running from inside a herdr pane」）對
真 herdr 0.9.0 跑了一次 `tests/integration/herdr-real.sh`，全部 `OK`、exit 0：

```
OK   workspace create root_pane=w2:p1
OK   tab create --label shape tab=w2:t2 root=w2:p2
OK   tab get succeeds tab=w2:t2
OK   tab close (probe) tab=w2:t2
```

（第一行 `workspace create` 是腳本開頭建立臨時 workspace 給 tab create 掛，不是 AC17 探針
本身；plus 既有的 `--ratio`/`--amount`/`pane read` `NOTE` 行，跟這次改動無關。）跑完照 README
的步驟 `herdr session stop/delete dktest` 收乾淨，`herdr session list` 確認只剩 `default`。

Unit suite（`tests/run.sh`）不受影響 —— 這一節記錄的 AC17 探針改動只動了整合腳本與這篇文件；
0.11.0 的其他 AC 另外動了 `.dkbo/bin/dk-leader`／`dk-resume`／`dk-task-close`／`dk-task-new`／
`.dkbo/skills/run/SKILL.md` 五支腳本，並新增 `tab_close.json`／`tab_get.json` 兩個 stub，不在
這一節範圍內。
