#!/usr/bin/env bash
# Layer 2: verify herdr JSON shapes and behaviours the stub assumes. Runs in a separate named session.
set -uo pipefail
[ "${HERDR_ENV:-}" = 1 ] || { echo "run inside herdr"; exit 2; }
ok(){ echo "OK   $*"; }; fail(){ echo "FAIL $*"; rc=1; }; rc=0
tmp=$(mktemp -d); git -C "$tmp" init -q; git -C "$tmp" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
H="herdr --session dktest"
ws=$($H workspace create --cwd "$tmp" --no-focus 2>&1) || { echo "$ws"; fail "workspace create"; exit 1; }
ws0=$(echo "$ws" | jq -r '.result.workspace.workspace_id')
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
if echo "$pr" | jq -e '.result.read.text' >/dev/null 2>&1; then ok "pane read returns JSON .result.read.text"; echo "NOTE pane/agent read is JSON; dk-watch uses .result.read.text"
elif [ -n "$pr" ]; then ok "pane read returns plain text"; echo "NOTE pane/agent read is PLAIN TEXT on herdr $(herdr --version | awk '{print $2}'); dk-watch falls back to the raw output — keep tests/stub/responses/agent_read.json as JSON only if dk-watch's jq fallback stays"
else fail "pane read returned nothing"; fi
printf '%s' "$tc" > "$tmp/tab_create.json"; printf '%s' "$lay" > "$tmp/pane_layout.json"; printf '%s' "$pr" > "$tmp/pane_read.json"
$H tab close "$tid" >/dev/null 2>&1 && ok "tab close" || fail "tab close"
$H notification show "dkboai layer2" --body ok >/dev/null 2>&1 && ok "notification show" || fail "notification show"
$H pane close "$p" >/dev/null 2>&1 && ok "pane close" || fail "pane close"
wsid=$(echo "$wt" | jq -r '.result.workspace.workspace_id // empty' 2>/dev/null); [ -n "$wsid" ] && $H worktree remove --workspace "$wsid" --force >/dev/null 2>&1
[ -n "$wsid" ] && [ "$wsid" != "$ws0" ] && $H workspace close "$wsid" >/dev/null 2>&1
$H workspace close "$ws0" >/dev/null 2>&1
echo "raw responses saved to $tmp/*.json for stub updates"; printf '%s' "$sp" > "$tmp/pane_split.json"; printf '%s' "$wt" > "$tmp/worktree_create.json"
exit $rc
