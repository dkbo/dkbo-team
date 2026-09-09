#!/usr/bin/env bash
# .dkbo/install.sh [--target DIR]  — wire dkboai into a project (idempotent).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="$(dirname "$here")"; [ "${1:-}" = --target ] && target="$(cd "$2" && pwd)"
cd "$target"
append_line() { # FILE LINE — append LINE, first making sure FILE ends with a newline
  [ ! -s "$1" ] || [ -z "$(tail -c1 "$1")" ] || echo >> "$1"
  echo "$2" >> "$1"
}
for s in init add-role; do
  for d in .claude/skills .agents/skills; do
    mkdir -p "$d"
    if [ -e "$d/dkboai-$s" ] && [ ! -L "$d/dkboai-$s" ]; then
      echo "install.sh: $d/dkboai-$s exists and is not a symlink; left untouched" >&2
    else
      ln -sfn "../../.dkbo/skills/$s" "$d/dkboai-$s"
    fi
  done
done
grep -qs '^讀 .dkbo/ENTRY.md' AGENTS.md || append_line AGENTS.md '讀 .dkbo/ENTRY.md 並依其行事。'
if [ -L CLAUDE.md ] && [ "$(readlink CLAUDE.md)" = AGENTS.md ]; then
  echo "CLAUDE.md is a symlink to AGENTS.md; nothing to add"
else
  grep -qs '^@AGENTS.md$' CLAUDE.md || append_line CLAUDE.md '@AGENTS.md'
fi
if ! grep -qs '.dkbo/.sessions' .gitignore; then
  append_line .gitignore '.dkbo/.sessions/*'
  append_line .gitignore '!.dkbo/.sessions/.gitkeep'
fi
chmod +x .dkbo/bin/* .dkbo/install.sh
echo "dkboai installed into $target"
