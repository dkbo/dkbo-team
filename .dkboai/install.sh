#!/usr/bin/env bash
# .dkboai/install.sh [--target DIR]  — wire dkboai into a project (idempotent).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="$(dirname "$here")"; [ "${1:-}" = --target ] && target="$(cd "$2" && pwd)"
cd "$target"
for s in init add-role; do
  for d in .claude/skills .agents/skills; do
    mkdir -p "$d"; ln -sfn "../../.dkboai/skills/$s" "$d/dkboai-$s"
  done
done
grep -qs '^讀 .dkboai/ENTRY.md' AGENTS.md || echo '讀 .dkboai/ENTRY.md 並依其行事。' >> AGENTS.md
if [ -L CLAUDE.md ] && [ "$(readlink CLAUDE.md)" = AGENTS.md ]; then
  echo "CLAUDE.md is a symlink to AGENTS.md; nothing to add"
else
  grep -qs '^@AGENTS.md$' CLAUDE.md || echo '@AGENTS.md' >> CLAUDE.md
fi
grep -qs '.dkboai/.sessions' .gitignore || printf '.dkboai/.sessions/*\n!.dkboai/.sessions/.gitkeep\n' >> .gitignore
chmod +x .dkboai/bin/* .dkboai/install.sh
echo "dkboai installed into $target"
