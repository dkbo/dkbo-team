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
  for w in 'hit:' 'dk-kind up' '未 ack' 'wave-open <N> --refresh' '不等人看畫面'; do
    grep -q -- "$w" "$DK_ROOT/skills/run/SKILL.md" || { echo "SKILL.md 缺 $w"; false; }
  done
  for f in README.md README.en.md .dkbo/README.md; do
    grep -q 'dk-kind' "$REPO_ROOT/$f" || { echo "$f 沒提到 dk-kind"; false; }
  done
}

@test "AC17: 波中改 brief 只請原 dev 重做時要回 [FIXED]，不再回 [DONE]" {
  grep -q -- '回 `\[FIXED\]`' "$DK_ROOT/skills/run/SKILL.md"
}
@test "檔位：S 只給純機械工作，審查後的修復波至少 M" {
  grep -q -- 'S 只給純機械的工作' "$DK_ROOT/skills/plan/SKILL.md"
  grep -q -- '審查後的修復波成員至少 M' "$DK_ROOT/skills/run/SKILL.md"
  grep -q -- 'S 純機械照做' "$DK_ROOT/skills/add-role/SKILL.md"
}
@test "整枝評議判不修時 ruling 要標明前提是實測還是推測" {
  grep -q -- '前提是\*\*實測\*\*還是\*\*推測\*\*' "$DK_ROOT/skills/run/SKILL.md"
}
@test "單波任務與整枝評議後的修復波，同一份 diff 不審兩次" {
  grep -q -- '只有一波的任務' "$DK_ROOT/skills/run/SKILL.md"
  grep -q -- 'review task skipped: 單波' "$DK_ROOT/skills/run/SKILL.md"
  grep -q -- '這一輪就算下一輪整枝評議' "$DK_ROOT/skills/run/SKILL.md"
}
@test "reviewer 出廠檔位是 L（settings、seed、dk_settings 預設一致）" {
  grep -q '^DK_REVIEW_TIER="L"' "$REPO_ROOT/.dkbo/settings.env"
  grep -q '^DK_REVIEW_TIER="L"' "$REPO_ROOT/.dkbo/templates/seed/settings.seed.env"
  grep -q 'DK_REVIEW_TIER="L"$' "$REPO_ROOT/.dkbo/lib/common.sh"
}
@test "計畫審查達法定人數就送關卡①，不等晚到的 reviewer" {
  grep -q -- '不等晚到的 reviewer' "$DK_ROOT/skills/plan/SKILL.md"
  grep -q -- 'skipped (關卡①時未回)' "$DK_ROOT/skills/plan/SKILL.md"
}
@test "員工的完整測試只在送 DONE／FIXED 前跑一次" {
  grep -q -- '完整測試只在送 `\[DONE\]`／`\[FIXED\]` 前跑一次' "$DK_ROOT/PROTOCOL.md"
}
@test "run 開跑後不停車：自己裁定記 [自主]、熔斷器取代關卡②、審批卡住自己重派" {
  f="$DK_ROOT/skills/run/SKILL.md"
  grep -q -- '## 不停車' "$f"
  grep -q -- 'ruling: \[自主\]' "$f"
  grep -q -- '不用 AskUserQuestion' "$f"
  grep -q -- '## 熔斷器' "$f"
  grep -q -- '不開第二個修復波' "$f"
  grep -q -- '員工 `\[BLOCKED\]`' "$f"
  grep -q -- '不等人看畫面' "$f"
  refute_grep '關卡②' "$f"
  refute_grep '告知人去按審批' "$f"
  refute_grep '不能依 brief 判者升關卡②' "$DK_ROOT/LEADER.md"
  grep -q -- 'ruling: \[自主\]' "$DK_ROOT/LEADER.md"
  grep -q -- '## 自主裁定（待你複核）' "$DK_ROOT/templates/report.md"
  refute_grep '不能判的問你' "$REPO_ROOT/README.md"
  refute_grep 'otherwise it asks you' "$REPO_ROOT/README.en.md"
  refute_grep '員工升報時問你' "$DK_ROOT/README.md"
  grep -q -- '附截圖' "$DK_ROOT/roles/qa.md"
}
@test "dev→qa 的 [DONE] 背景送：PROTOCOL 不再說照常即時送達" {
  refute_grep '（dev→qa）照常即時送達' "$DK_ROOT/PROTOCOL.md"
  grep -q -- 'dev 送給 qa 的 `\[DONE\]` 在背景送' "$DK_ROOT/PROTOCOL.md"
}
