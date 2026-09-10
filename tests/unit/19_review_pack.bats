load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"; dk-wave-open 1 >/dev/null
  wt() { git -C "$WORKTREE_PATH" -c user.name=t -c user.email=t@t "$@"; }
}
teardown() { teardown_project; }

@test "pack holds commits, stat and -U10 diff, including uncommitted and untracked work" {
  mkdir -p "$WORKTREE_PATH/src/api"; echo 'hello' > "$WORKTREE_PATH/src/api/login.ts"; wt add -A; wt commit -q -m 'api: login'
  echo 'dirty' >> "$WORKTREE_PATH/src/api/login.ts"; echo 'new' > "$WORKTREE_PATH/untracked.txt"
  run dk-review-pack; [ "$status" -eq 0 ]; [ "$output" = "$d/waves/1.diff" ]
  f="$d/waves/1.diff"; grep -q '^## commits' "$f"; grep -q 'api: login' "$f"; grep -q '^## stat' "$f"; grep -q '^## diff (-U10)' "$f"
  grep -q '^+hello' "$f"; grep -q '^+dirty' "$f"; grep -q '^+new' "$f"; grep -q 'untracked.txt' "$f"
  wt status --porcelain | grep -q '^?? untracked.txt'   # the employee's real index was not touched
  run dk-review-pack 1; [ "$status" -eq 0 ]   # explicit wave number
}
@test "no changes: file still written, warning on stderr" {
  run dk-review-pack; [ "$status" -eq 0 ]; [ -f "$d/waves/1.diff" ]; [[ "$output" == *"no changes"* ]]
}
@test "unknown wave or no open wave dies" {
  run dk-review-pack 7; [ "$status" -eq 1 ]; [[ "$output" == *"wave-open 7"* ]]
  sed -i 's/^DK_WAVE=.*/DK_WAVE=""/' "$d/.task.env"; run dk-review-pack; [ "$status" -eq 1 ]; [[ "$output" == *"usage"* ]]
}
@test "--task diffs the whole branch from DK_BASE; legacy task dies" {
  echo 'x' > "$WORKTREE_PATH/a.txt"; wt add -A; wt commit -q -m 'wave 0'
  run dk-review-pack --task; [ "$status" -eq 0 ]; [ "$output" = "$d/waves/task.diff" ]; grep -q 'wave 0' "$d/waves/task.diff"; grep -q '^+x' "$d/waves/task.diff"
  sed -i '/^DK_BASE=/d' "$d/.task.env"; run dk-review-pack --task; [ "$status" -eq 1 ]; [[ "$output" == *"DK_BASE"* ]]
}
