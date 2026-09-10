load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "install creates symlinks, entry files, gitignore; idempotent" {
  run .dkbo/install.sh; [ "$status" -eq 0 ]
  for s in init add-role; do
    [ "$(readlink .claude/skills/dkbo-$s)" = "../../.dkbo/skills/$s" ]
    [ "$(readlink .agents/skills/dkbo-$s)" = "../../.dkbo/skills/$s" ]
    [ -f ".claude/skills/dkbo-$s/SKILL.md" ]
  done
  grep -q '^讀 .dkbo/ENTRY.md' AGENTS.md; grep -q '^@AGENTS.md$' CLAUDE.md; grep -q '.dkbo/.sessions' .gitignore; grep -qx '.worktrees/' .gitignore
  run .dkbo/install.sh; [ "$status" -eq 0 ]
  [ "$(grep -c '^@AGENTS.md$' CLAUDE.md)" -eq 1 ]
}
@test "install appends to an existing CLAUDE.md and AGENTS.md" {
  echo '# my project' > CLAUDE.md; echo '# agents rules' > AGENTS.md; .dkbo/install.sh >/dev/null
  head -1 CLAUDE.md | grep -q '# my project'; grep -q '^@AGENTS.md$' CLAUDE.md
  head -1 AGENTS.md | grep -q '# agents rules'; grep -q '^讀 .dkbo/ENTRY.md' AGENTS.md
}
@test "install skips CLAUDE.md line when it symlinks AGENTS.md" {
  echo '# agents rules' > AGENTS.md; ln -s AGENTS.md CLAUDE.md; .dkbo/install.sh >/dev/null
  ! grep -q '^@AGENTS.md$' AGENTS.md; grep -q '^讀 .dkbo/ENTRY.md' AGENTS.md
}
@test "README carries the one-shot install and update commands" {
  for needle in '.dkbo/install.sh' 'git add -A' '/dkbo-init' 'HERDR_ENV' 'herdr --version' 'dk-whoami' 'rsync' '--exclude=tasks'; do
    grep -qF -- "$needle" .dkbo/README.md || { echo "missing: $needle"; return 1; }
  done
  [ -f "$REPO_ROOT/README.md" ]; grep -q '.dkbo/README.md' "$REPO_ROOT/README.md"
}
@test "skills have agent-skills frontmatter" {
  for s in init add-role; do
    head -1 ".dkbo/skills/$s/SKILL.md" | grep -q '^---$'
    grep -q "^name: dkbo-$s$" ".dkbo/skills/$s/SKILL.md"; grep -q '^description: ' ".dkbo/skills/$s/SKILL.md"
  done
}
@test "install appends cleanly to files without a trailing newline" {
  printf 'node_modules' > .gitignore; printf '# my project' > CLAUDE.md; printf '# rules' > AGENTS.md
  .dkbo/install.sh >/dev/null
  grep -qx 'node_modules' .gitignore; grep -qx '.dkbo/.sessions/\*' .gitignore
  grep -qx '# my project' CLAUDE.md; grep -qx '@AGENTS.md' CLAUDE.md
  grep -qx '# rules' AGENTS.md; grep -q '^讀 .dkbo/ENTRY.md' AGENTS.md
}
@test "install leaves a pre-existing real directory alone" {
  mkdir -p .claude/skills/dkbo-init; touch .claude/skills/dkbo-init/keep
  run .dkbo/install.sh; [ "$status" -eq 0 ]; [[ "$output" == *"not a symlink"* ]]
  [ ! -L .claude/skills/dkbo-init ]; [ -f .claude/skills/dkbo-init/keep ]; [ ! -e .claude/skills/dkbo-init/init ]
  [ "$(readlink .agents/skills/dkbo-init)" = "../../.dkbo/skills/init" ]
}
