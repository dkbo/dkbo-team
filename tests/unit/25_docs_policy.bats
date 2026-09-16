load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "docs/ is out of version control and nothing tracked links into it" {
  grep -qE '^docs/$' "$REPO_ROOT/.gitignore" || { echo ".gitignore does not ignore docs/"; false; }
  [ -z "$(git -C "$REPO_ROOT" ls-files docs)" ] || { echo "docs/ is still tracked"; false; }
  # CHANGELOG 的歷史條目是當時的事實，不改。
  for f in README.md README.en.md .dkbo/README.md .dkbo/decisions.md .dkbo/tasks/BACKLOG.md; do
    ! grep -q 'docs/design' "$REPO_ROOT/$f" || { echo "$f still points into docs/design"; false; }
  done
}

@test "stage docs reach skills by SKILL.md path, not only by slash command" {
  grep -q '.dkbo/skills/add-role/SKILL.md' "$DK_ROOT/skills/brain/SKILL.md"
  grep -q '.dkbo/skills/init/SKILL.md' "$DK_ROOT/LEADER.md"
}
