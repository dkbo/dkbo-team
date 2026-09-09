# shellcheck shell=bash
# Shared helpers for dkboai bin scripts. Source, do not execute. No `set` here: bats sources this too.
export LC_ALL="${LC_ALL:-C.UTF-8}"
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

dk_render() { # TEMPLATE_FILE KEY=VALUE... → stdout with every {{KEY}} replaced; values may contain any character
  local c kv; c=$(<"$1"); shift
  for kv in "$@"; do c=${c//"{{${kv%%=*}}}"/"${kv#*=}"}; done
  printf '%s\n' "$c"
}
dk_index_add() { printf '| %s | %s | %s | %s | %s |\n' "$1" "$2" "$3" "$4" "$5" >> "$DK_ROOT/tasks/INDEX.md"; }
dk_index_set() { # NAME STATUS NOTE  — rewrite the row whose name column matches
  local name="$1" status="$2" note="$3" f="$DK_ROOT/tasks/INDEX.md"
  awk -F'|' -v n="$name" -v s="$status" -v o="$note" 'BEGIN{OFS="|"}
    { if ($3 == " " n " ") { $5=" " s " "; $6=" " o " " } print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}
