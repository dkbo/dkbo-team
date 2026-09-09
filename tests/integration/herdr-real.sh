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
# NOTE: real herdr 0.9.0 rejects `--workspace` and `--cwd` together on `worktree create`
# ("usage: ... [--workspace ID | --cwd PATH] ..."). Production code (dk-task-new, dk-chore)
# only ever passes --cwd, so mirror that here instead of the brief's original --workspace+--cwd combo.
wt=$($H worktree create --branch dk/test --base "$(git -C "$tmp" rev-parse --abbrev-ref HEAD)" --cwd "$tmp" --no-focus 2>&1)
echo "$wt" | jq -e '.result.workspace.workspace_id and .result.root_pane.pane_id' >/dev/null 2>&1 && ok "worktree create shape" || fail "worktree create shape: $wt"
echo "$wt" | jq -e '.result.path' >/dev/null 2>&1 && ok "worktree create has .result.path" || echo "NOTE worktree create has no .result.path; dk-task-new falls back to git worktree list"
$H notification show "dkboai layer2" --body ok >/dev/null 2>&1 && ok "notification show" || fail "notification show"
$H pane close "$p" >/dev/null 2>&1 && ok "pane close" || fail "pane close"
wsid=$(echo "$wt" | jq -r '.result.workspace.workspace_id // empty'); [ -n "$wsid" ] && $H worktree remove --workspace "$wsid" --force >/dev/null 2>&1
$H workspace close "$(echo "$ws" | jq -r '.result.workspace.workspace_id')" >/dev/null 2>&1
echo "raw responses saved to $tmp/*.json for stub updates"; printf '%s' "$sp" > "$tmp/pane_split.json"; printf '%s' "$wt" > "$tmp/worktree_create.json"
exit $rc
