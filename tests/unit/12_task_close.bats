load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入)
  git -C "$PROJECT" -c user.name=t -c user.email=t@t commit -q --allow-empty -m base
  echo hi > "$WORKTREE_PATH/f.txt"; git -C "$WORKTREE_PATH" add f.txt; git -C "$WORKTREE_PATH" -c user.name=t -c user.email=t@t commit -q -m wave1
  printf '| 2026-09-10 | 使用者登入 | task | running | — |\n' >> "$DK_ROOT/tasks/INDEX.md"
  : > "$d/.panes"
}
teardown() { teardown_project; }

@test "refuses without report or with live panes" {
  run dk-task-close; [ "$status" -eq 1 ]; [[ "$output" == *"report.md"* ]]
  echo '# r' > "$d/report.md"; echo 'x wC:p9' > "$d/.panes"
  run dk-task-close; [ "$status" -eq 1 ]; [[ "$output" == *"dk-wave-close"* ]]
}
@test "merges, removes worktree, clears binding and index" {
  echo '# r' > "$d/report.md"
  run dk-task-close; [ "$status" -eq 0 ]
  [ -f "$PROJECT/f.txt" ]; git -C "$PROJECT" log --oneline -3 | grep -q 'task login: 使用者登入'
  ! grep -q '^worktree remove' "$HERDR_STUB_LOG"; [ ! -d "$WORKTREE_PATH" ]
  ! git -C "$PROJECT" worktree list --porcelain | grep -qx "worktree $WORKTREE_PATH"
  grep -q '^agent rename wB:p1 --clear$' "$HERDR_STUB_LOG"
  [ ! -f "$DK_ROOT/.sessions/wB:p1" ]
  grep -Eq '\| 使用者登入 \| task \| done \| merged [0-9a-f]{7} \|' "$DK_ROOT/tasks/INDEX.md"
  grep -q 'task-close merged' "$d/process.md"
}
@test "conflict aborts with exit 3 and keeps binding" {
  echo '# r' > "$d/report.md"; echo other > "$PROJECT/f.txt"
  git -C "$PROJECT" add f.txt; git -C "$PROJECT" -c user.name=t -c user.email=t@t commit -q -m clash
  run dk-task-close; [ "$status" -eq 3 ]
  [ -f "$DK_ROOT/.sessions/wB:p1" ]; grep -q 'merge-conflict' "$d/process.md"
  git -C "$PROJECT" diff --quiet   # merge aborted cleanly
}
@test "abandon writes report, deletes branch, marks index" {
  run dk-task-close --abandon "需求改了"; [ "$status" -eq 0 ]
  grep -q '需求改了' "$d/report.md"; grep -q 'abandoned' "$d/report.md"
  [ ! -d "$WORKTREE_PATH" ]
  ! git -C "$PROJECT" rev-parse --verify -q dk/login
  grep -q '| abandoned | 需求改了 |' "$DK_ROOT/tasks/INDEX.md"
}
@test "in-tree task (no worktree) closes without merge" {
  echo '# r' > "$d/report.md"
  sed -i "s|^DK_WORKTREE=.*|DK_WORKTREE=\"$PROJECT\"|; s|^DK_WORKSPACE=.*|DK_WORKSPACE=\"\"|" "$d/.task.env"
  run dk-task-close; [ "$status" -eq 0 ]; [[ "$output" == closed* ]]
  ! grep -q '^worktree remove' "$HERDR_STUB_LOG"
  grep -q '^agent rename wB:p1 --clear$' "$HERDR_STUB_LOG"
  [ ! -f "$DK_ROOT/.sessions/wB:p1" ]
  grep -Eq '\| 使用者登入 \| task \| done \| in-tree [0-9a-f]{7} \|' "$DK_ROOT/tasks/INDEX.md"
  grep -q 'task-close in-tree' "$d/process.md"
  git -C "$PROJECT" rev-parse --verify -q dk/login   # branch untouched
}
@test "task-close closes overflow tabs listed in DK_TABS" {
  echo '# r' > "$d/report.md"; sed -i 's/^DK_TABS=.*/DK_TABS="2=wB:t2 3=wB:t3"/' "$d/.task.env"
  run dk-task-close; [ "$status" -eq 0 ]; grep -q '^tab close wB:t2$' "$HERDR_STUB_LOG"; grep -q '^tab close wB:t3$' "$HERDR_STUB_LOG"
}
@test "legacy task (no DK_BASE) falls back to herdr worktree remove with a warning" {
  echo '# r' > "$d/report.md"; sed -i '/^DK_BASE=/d; s/^DK_WORKSPACE=.*/DK_WORKSPACE="wC"/' "$d/.task.env"
  run dk-task-close; [ "$status" -eq 0 ]; [[ "$output" == *"legacy"* ]]; grep -q '^worktree remove --workspace wC --force$' "$HERDR_STUB_LOG"
}
@test "task-close deletes the merged task branch" {
  echo '# r' > "$d/report.md"
  run dk-task-close; [ "$status" -eq 0 ]
  ! git -C "$PROJECT" rev-parse --verify -q dk/login
}
@test "task-close refuses when the worktree has uncommitted changes" {
  echo '# r' > "$d/report.md"; echo dirty > "$WORKTREE_PATH/g.txt"
  run dk-task-close; [ "$status" -eq 1 ]; [[ "$output" == *"uncommitted"* ]]
  [ -d "$WORKTREE_PATH" ]; [ -f "$WORKTREE_PATH/g.txt" ]   # nothing discarded
  git -C "$PROJECT" rev-parse --verify -q dk/login; [ -f "$DK_ROOT/.sessions/wB:p1" ]
  ! git -C "$PROJECT" log --oneline -1 | grep -q 'task login'
}

@test "task-close commits the task's memory in the main tree" {
  # e2e 實測：結案後整個 .dkbo/tasks/<t>/ 仍是 untracked，README 與 decisions.md 都聲稱
  # 記憶「進 git」但沒有任何一步做（RESULTS-2026-09-11 ⑨）
  : > "$d/report.md"
  run dk-task-close; [ "$status" -eq 0 ]
  t="$DK_ROOT/tasks/$(date +%F)-login"
  [ -z "$(git -C "$PROJECT" status --porcelain -- "$t" "$DK_ROOT/tasks/INDEX.md")" ]   # 任務目錄與 INDEX 都已進 git
  git -C "$PROJECT" log -1 --name-only --format=%s | grep -q "memory"
  git -C "$PROJECT" ls-files --error-unmatch "$DK_ROOT/tasks/$(date +%F)-login/brief.md" >/dev/null
  git -C "$PROJECT" ls-files --error-unmatch "$DK_ROOT/tasks/INDEX.md" >/dev/null
}
@test "task-close leaves unrelated working-tree changes alone" {
  : > "$d/report.md"; echo dirty > "$PROJECT/unrelated.txt"
  run dk-task-close; [ "$status" -eq 0 ]
  [ -n "$(git -C "$PROJECT" status --porcelain -- unrelated.txt)" ]
}
@test "有 minor 但 report 沒提到只警告，不擋結案" {
  echo "2026-09-19T10:00 minor 1: 命名不一致" >> "$d/process.md"
  printf '# x 結案\n## 完成\n做完了\n' > "$d/report.md"
  run dk-task-close; [ "$status" -eq 0 ]; [[ "$output" == *"minor"* ]]
}
@test "report.md 只留著範本的指引行不算提到 minor，警告不會被消掉" {
  # Minor 3：templates/report.md 的「未完成 / 遺留」段本身就有一行括號開頭的指引，
  # 那行含 Minor 三個字，會讓 grep -qi minor 永遠命中、警告永遠沉默。
  echo "2026-09-19T10:00 minor 1: 命名不一致" >> "$d/process.md"
  printf '# x 結案\n## 未完成 / 遺留\n（未經審查的波；整枝評議 triage 後決定不修的 Minor，一條一行）\n' > "$d/report.md"
  run dk-task-close; [ "$status" -eq 0 ]; [[ "$output" == *"minor"* ]]
}
@test "AC9: 結案把 dk-timeline 的時間表填進 report.md 的 ## 時間 段" {
  cat > "$d/process.md" <<'P'
2026-09-19T20:39 task-new login
2026-09-19T20:45 gate1 approved
2026-09-19T20:45 wave-open 1 base abc1234 members backend
2026-09-19T21:04 dev-done wave 1 (1: backend)
2026-09-19T21:04 review 1 spawned login-reviewer-a(claude)
2026-09-19T21:11 review 1 verdict a: ok
2026-09-19T21:12 wave-close 1 tests ok (x) 2 agents closed
P
  printf '# r 結案\n## 完成\nx\n## 時間\n（由 dk-task-close 填）\n' > "$d/report.md"
  run dk-task-close; [ "$status" -eq 0 ]
  grep -qx '| 計畫 | 2026-09-19T20:39 | 2026-09-19T20:45 | 6m | — | — |' "$d/report.md"
  grep -qx '| 波 1 | 2026-09-19T20:45 | 2026-09-19T21:12 | 27m | 19m | 7m |' "$d/report.md"
  grep -q '^| 任務 | 2026-09-19T20:39 | ' "$d/report.md"   # 結束欄是這次 task-close 的當下
  refute_grep -F '由 dk-task-close 填' "$d/report.md"      # 範本的指引行被實際內容取代
  grep -qx '## 完成' "$d/report.md"                         # 其他段落不動
  git -C "$PROJECT" show --stat HEAD | grep -q report.md    # 填完才 commit 任務記憶
}
@test "AC9: --abandon 不附時間表" {
  echo '2026-09-19T20:39 task-new login' > "$d/process.md"
  run dk-task-close --abandon "需求改了"; [ "$status" -eq 0 ]
  refute_grep -F '| 階段 |' "$d/report.md"
}
@test "AC9: 範本有 ## 時間 段且註明由 dk-task-close 填" {
  grep -qx '## 時間' "$REPO_ROOT/.dkbo/templates/report.md"
  grep -q 'dk-task-close' "$REPO_ROOT/.dkbo/templates/report.md"
}
