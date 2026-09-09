#!/usr/bin/env bash
# Layer 3: one real agent of <kind>: spawn → state → DONE, plus prompt-while-working queue check.
set -euo pipefail
kind="${1:?kind}"; write=0; [ "${2:-}" = --write ] && write=1
[ "${HERDR_ENV:-}" = 1 ] || { echo "run inside herdr"; exit 2; }
repo="$(cd "$(dirname "$0")/../.." && pwd)"
tmp=$(mktemp -d); cp -r "$repo/.dkboai" "$tmp/"; cd "$tmp"
git init -q; git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init; git branch -M main
.dkboai/install.sh >/dev/null; export DK_ROOT="$tmp/.dkboai"; PATH="$tmp/.dkboai/bin:$PATH"
mkdir -p notes; touch notes/.gitkeep
git add -A; git -c user.name=t -c user.email=t@t commit -q -m "add dkboai"
dir=$(dk-task-new smoke "smoke")
cat >> "$dir/brief.md" <<'B'
| it | notes/** | — |
B
printf '| 1 | 實作 | it | 在 notes/ 建檔 | S | leader 收到 DONE |\n' >> "$dir/brief.md"
dk-spawn it --tier S --kind "$kind"
. .dkboai/lib/common.sh; DK_TASK_DIR="$dir"; export DK_TASK_DIR; dk_task_env; agent=$(dk_agent_name it)
for _ in $(seq 1 60); do [ -f "$dir/state/it.md" ] && break; sleep 2; done
[ -f "$dir/state/it.md" ] && echo "OK state file created" || { echo "FAIL no state file"; herdr agent read "$agent" --lines 60; exit 1; }
herdr agent prompt "$agent" "請把 notes/a.txt 寫入 100 行遞增數字，完成後執行 .dkboai/bin/dk-msg leader \"[DONE] a\"" >/dev/null
sleep 2
DK_MSG_WAIT_MS=1000 dk-msg "$agent" "[TASK] 完成後再把 notes/b.txt 寫入 hello，並執行 .dkboai/bin/dk-msg leader \"[DONE] b\"" || true
q=no; for _ in $(seq 1 90); do grep -q '\[DONE\] a' "$dir/messages.log" && grep -q '\[DONE\] b' "$dir/messages.log" && { q=yes; break; }; sleep 2; done
echo "QUEUES=$q"
if [ "$write" = 1 ]; then sed -i "s/^KIND_PROMPT_QUEUES=.*/KIND_PROMPT_QUEUES=$q/" "$repo/.dkboai/kinds/$kind.sh"; fi
dk-wave-close --force || true; dk-task-close --abandon smoke >/dev/null || true
echo "done: $tmp"
