load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "install creates symlinks, entry files, gitignore; idempotent" {
  run .dkboai/install.sh; [ "$status" -eq 0 ]
  for s in init add-role; do
    [ "$(readlink .claude/skills/dkboai-$s)" = "../../.dkboai/skills/$s" ]
    [ "$(readlink .agents/skills/dkboai-$s)" = "../../.dkboai/skills/$s" ]
    [ -f ".claude/skills/dkboai-$s/SKILL.md" ]
  done
  grep -q '^讀 .dkboai/ENTRY.md' AGENTS.md; grep -q '^@AGENTS.md$' CLAUDE.md; grep -q '.dkboai/.sessions' .gitignore
  run .dkboai/install.sh; [ "$status" -eq 0 ]
  [ "$(grep -c '^@AGENTS.md$' CLAUDE.md)" -eq 1 ]
}
@test "install appends to an existing CLAUDE.md and AGENTS.md" {
  echo '# my project' > CLAUDE.md; echo '# agents rules' > AGENTS.md; .dkboai/install.sh >/dev/null
  head -1 CLAUDE.md | grep -q '# my project'; grep -q '^@AGENTS.md$' CLAUDE.md
  head -1 AGENTS.md | grep -q '# agents rules'; grep -q '^讀 .dkboai/ENTRY.md' AGENTS.md
}
@test "install skips CLAUDE.md line when it symlinks AGENTS.md" {
  echo '# agents rules' > AGENTS.md; ln -s AGENTS.md CLAUDE.md; .dkboai/install.sh >/dev/null
  ! grep -q '^@AGENTS.md$' AGENTS.md; grep -q '^讀 .dkboai/ENTRY.md' AGENTS.md
}
@test "README carries the one-shot install and update commands" {
  for needle in '.dkboai/install.sh' 'git add -A' '/dkboai-init' 'HERDR_ENV' 'herdr --version' 'dk-whoami' 'rsync' '--exclude=tasks'; do
    grep -qF -- "$needle" .dkboai/README.md || { echo "missing: $needle"; return 1; }
  done
  [ -f "$REPO_ROOT/README.md" ]; grep -q '.dkboai/README.md' "$REPO_ROOT/README.md"
}
@test "skills have agent-skills frontmatter" {
  for s in init add-role; do
    head -1 ".dkboai/skills/$s/SKILL.md" | grep -q '^---$'
    grep -q "^name: dkboai-$s$" ".dkboai/skills/$s/SKILL.md"; grep -q '^description: ' ".dkboai/skills/$s/SKILL.md"
  done
}
