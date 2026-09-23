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

@test "Important4: DK_WORKSPACE 講成任務所屬，不再講成人所在的那一刻" {
  while IFS= read -r f; do
    case "$f" in
      .dkbo/tasks/*) continue ;;
      tests/unit/25_docs_policy.bats) continue ;;
    esac
    refute_grep -E '人所在的 workspace|你所在的 workspace|時所在的那個 workspace' "$REPO_ROOT/$f"
    refute_grep -E "workspace you're (already )?in" "$REPO_ROOT/$f"
  done < <(git -C "$REPO_ROOT" ls-files)
  grep -q '任務所屬的 workspace' "$REPO_ROOT/README.md"
  grep -q '任務所屬的 workspace' "$DK_ROOT/README.md"
  grep -q '任務所屬的 workspace' "$REPO_ROOT/CHANGELOG.md"
  grep -q '任務所屬的 workspace' "$DK_ROOT/LEADER.md"
  grep -q '任務所屬的 workspace' "$DK_ROOT/PROJECT.md"
  grep -q "task's workspace" "$REPO_ROOT/README.en.md"
}

@test "AC13: skills/run/SKILL.md 帶新規範的五個字串，三份 README 都提到 dk-kind" {
  for w in 'hit:' 'dk-kind up' '未 ack' 'wave-open <N> --refresh' '請人看'; do
    grep -q -- "$w" "$DK_ROOT/skills/run/SKILL.md" || { echo "SKILL.md 缺 $w"; false; }
  done
  for f in README.md README.en.md .dkbo/README.md; do
    grep -q 'dk-kind' "$REPO_ROOT/$f" || { echo "$f 沒提到 dk-kind"; false; }
  done
}

@test "AC17: 波中改 brief 只請原 dev 重做時要回 [FIXED]，不再回 [DONE]" {
  grep -q -- '回 `\[FIXED\]`' "$DK_ROOT/skills/run/SKILL.md"
}
