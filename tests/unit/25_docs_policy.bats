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

@test "AC15: 多 repo 的 repo 前綴或交棒在各自對應的文件段落都提到" {
  grep -q 'DK_REPOS' "$DK_ROOT/LEADER.md"
  grep -q '<名>:' "$DK_ROOT/PROTOCOL.md"
  grep -q '<名>:' "$DK_ROOT/roles/reviewer.md"
  for f in README.md README.en.md .dkbo/README.md; do
    grep -qE '交棒|handoff' "$REPO_ROOT/$f" || { echo "$f 沒提到交棒"; false; }
  done
  grep -q 'feat(workspace)' "$REPO_ROOT/CHANGELOG.md"
  grep -q 'feat(repos)' "$REPO_ROOT/CHANGELOG.md"
}

@test "AC7: 交棒改開 tab，三份 README 與 .dkbo/README.md 不再說任務專屬 workspace" {
  for f in README.md README.en.md .dkbo/README.md; do
    grep -q 'tab' "$REPO_ROOT/$f" || { echo "$f 沒提到 tab"; false; }
    refute_grep '任務專屬的 herdr workspace' "$REPO_ROOT/$f"
    refute_grep 'a task-specific herdr workspace' "$REPO_ROOT/$f"
  done
  grep -q 'DK_TASK_TAB' "$DK_ROOT/README.md"
}
