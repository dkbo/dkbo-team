load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入)
  git -C "$PROJECT" -c user.name=t -c user.email=t@t commit -q --allow-empty -m base
  git -C "$PROJECT" branch dk/login
  git -C "$PROJECT" -c user.name=t -c user.email=t@t checkout -q dk/login; echo hi > "$PROJECT/f.txt"
  git -C "$PROJECT" add f.txt; git -C "$PROJECT" -c user.name=t -c user.email=t@t commit -q -m wave1; git -C "$PROJECT" checkout -q main
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
  [ -f "$PROJECT/f.txt" ]; git -C "$PROJECT" log --oneline -1 | grep -q 'task login: 使用者登入'
  grep -q '^worktree remove --workspace wC --force$' "$HERDR_STUB_LOG"
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
  ! git -C "$PROJECT" rev-parse --verify -q dk/login
  grep -q '| abandoned | 需求改了 |' "$DK_ROOT/tasks/INDEX.md"
}
