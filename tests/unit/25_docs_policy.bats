load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "docs/ is out of version control and nothing tracked links into it" {
  grep -qE '^docs/$' "$REPO_ROOT/.gitignore" || { echo ".gitignore does not ignore docs/"; false; }
  [ -z "$(git -C "$REPO_ROOT" ls-files docs)" ] || { echo "docs/ is still tracked"; false; }
  # CHANGELOG 的歷史條目是當時的事實，不改。
  for f in README.md README.en.md .dkbo/README.md .dkbo/decisions.md .dkbo/tasks/BACKLOG.md; do
    refute_grep -q 'docs/design' "$REPO_ROOT/$f" || { echo "$f still points into docs/design"; false; }
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

@test "Important4（0.16.0 反轉）: --run 的 tab 開在你叫 /dkbo-run 當下所在的 workspace，不再講計畫時記下" {
  # 0.11.0 的語意是「任務所屬的 workspace（計畫時記下）」；人拍板改成當下所在的（bklog AC11）。
  # 歷史紀錄不改寫：任務目錄、decisions.md、CHANGELOG 0.16.0 以前的節。
  while IFS= read -r f; do
    case "$f" in
      .dkbo/tasks/*|.dkbo/decisions.md|CHANGELOG.md) continue ;;
      tests/unit/25_docs_policy.bats) continue ;;
    esac
    # 只禁舊的 tab 位置句型「workspace（…計畫時記下」；「退回計畫時記下的 DK_WORKSPACE」講的是退路來源，照留
    refute_grep -E 'workspace（[^）]*計畫時記下|recorded at plan time' "$REPO_ROOT/$f"
  done < <(git -C "$REPO_ROOT" ls-files)
  sec=$(awk '/^## [0-9]/{n++} n==1' "$REPO_ROOT/CHANGELOG.md")
  refute_grep -E 'workspace（[^）]*計畫時記下' <<< "$sec"
  for f in README.md .dkbo/README.md .dkbo/LEADER.md .dkbo/PROJECT.md .dkbo/skills/run/SKILL.md; do
    grep -qF '你叫 `/dkbo-run` 當下所在的 workspace' "$REPO_ROOT/$f" || { echo "$f 缺新說法"; false; }
    refute_grep -F '任務所屬的 workspace' "$REPO_ROOT/$f"
  done
  grep -qF 'the workspace you invoke `/dkbo-run` from' "$REPO_ROOT/README.en.md"
  refute_grep -F "task's workspace" "$REPO_ROOT/README.en.md"
}

@test "AC14: PROTOCOL 取紅不動共用 worktree、雜務的 [DONE] 句只出現一次、state 行數不算 touched 清單" {
  f="$DK_ROOT/PROTOCOL.md"
  grep -qF '取紅（證明新測試會紅）一律 cp 到獨立目錄或 `git archive <base>` 解到暫存目錄做，不在共用 worktree 用 `git stash`／`git checkout -- <檔>`' "$f"
  grep -qF '夥伴並跑的測試會讀到舊碼而假紅' "$f"
  [ "$(grep -cF 'dk-msg leader "[DONE] <一句結果>"' "$f")" -eq 1 ] || { echo "雜務 [DONE] 句不是恰好一次"; false; }
  grep -qF 'dk-msg leader "[DONE] review 波 N' "$f"
  grep -qF '`touched:` 底下的清單項以外 ≤20 行' "$f"
  grep -qF 'git archive <base>' "$DK_ROOT/templates/report-employee.md"
  grep -qF '不在共用 worktree 用 `git stash`' "$DK_ROOT/templates/report-employee.md"
}

@test "AC15: 額度耗盡當下 dk-kind down、兩種 [TIMEOUT]、補派 reviewer、領導訊息背景送" {
  grep -qF '任何來源確認某 kind 額度耗盡（畫面、CLI 狀態列、前一個任務的 ruling、人告知），當下 `dk-kind down <k> [--until …]`，不能只寫在 ruling 裡' "$DK_ROOT/LEADER.md"
  grep -qF '派 reviewer 或員工前先 `dk-kind`' "$DK_ROOT/LEADER.md"
  f="$DK_ROOT/skills/run/SKILL.md"
  grep -qF '仍在工作（未熔斷）' "$f"; grep -qF '不關 pane' "$f"
  grep -qF '閒置 N 分鐘未交' "$f"; grep -qF '[UNDELIVERED]' "$f"
  grep -qF 'dk-review --kinds <k>' "$f"; grep -qF '<別名>: skipped (<理由>)' "$f"
  grep -qF '背景送' "$f"
  refute_grep -F '該 kind 已寫進 `.task.env` 的 `DK_KIND_DOWN`' "$f"
  grep -qF 'dk-brief-review --kinds <k>' "$DK_ROOT/skills/plan/SKILL.md"
}

@test "AC16: 三份 README 的 dk-kind 補 down、dk-task-close 補任務 tab 不自動關" {
  for f in README.md README.en.md .dkbo/README.md; do
    grep -qF 'dk-kind down' "$REPO_ROOT/$f" || { echo "$f 缺 dk-kind down"; false; }
    grep -qF 'herdr tab close <id>' "$REPO_ROOT/$f" || { echo "$f 缺 tab close"; false; }
  done
  grep -E '^\| `dk-task-close`' "$REPO_ROOT/README.md" | grep -qF '任務 tab 不自動關'
  grep -E '^\| `dk-task-close`' "$REPO_ROOT/README.en.md" | grep -qF 'herdr tab close <id>'
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
