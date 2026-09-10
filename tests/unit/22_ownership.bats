load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"; dk-wave-open 1 >/dev/null
  wt() { git -C "$WORKTREE_PATH" -c user.name=t -c user.email=t@t "$@"; }
  . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/ownership.sh"
}
teardown() { teardown_project; }

@test "dk_wave_base reads the sha dk-wave-open recorded; empty for an unknown or non-numeric wave" {
  base=$(dk_wave_base "$d" 1); [ -n "$base" ]
  git -C "$WORKTREE_PATH" rev-parse HEAD | grep -q "^$base"
  [ -z "$(dk_wave_base "$d" 7)" ]
  [ -z "$(dk_wave_base "$d" 'x; echo boom')" ]
}

@test "dk_wave_base takes the last line when a wave was recorded twice" {
  echo "2026-09-10T10:00 wave-open 1 base deadbee members backend" >> "$d/process.md"
  [ "$(dk_wave_base "$d" 1)" = deadbee ]
}

@test "dk_changed_files lists committed, dirty and untracked work since the base" {
  mkdir -p "$WORKTREE_PATH/src/api"
  echo hello > "$WORKTREE_PATH/src/api/login.ts"; wt add -A; wt commit -q -m 'api: login'
  echo dirty >> "$WORKTREE_PATH/src/api/login.ts"
  echo new > "$WORKTREE_PATH/untracked.txt"
  run dk_changed_files "$WORKTREE_PATH" "$(dk_wave_base "$d" 1)"
  [ "$status" -eq 0 ]
  [[ "$output" == *"src/api/login.ts"* ]]; [[ "$output" == *"untracked.txt"* ]]
  wt status --porcelain | grep -q '^?? untracked.txt'   # the employee's real index was not touched
}

@test "dk_changed_files skips ignored files and leaves non-ASCII paths unescaped" {
  printf 'ignored.txt\n' > "$WORKTREE_PATH/.gitignore"
  echo junk > "$WORKTREE_PATH/ignored.txt"
  echo z > "$WORKTREE_PATH/文件.ts"
  run dk_changed_files "$WORKTREE_PATH" "$(dk_wave_base "$d" 1)"
  [ "$status" -eq 0 ]
  [[ "$output" == *".gitignore"* ]]; [[ "$output" == *"文件.ts"* ]]; [[ "$output" != *"ignored.txt"* ]]
}

@test "dk_changed_files reports nothing when the worktree is untouched" {
  run dk_changed_files "$WORKTREE_PATH" "$(dk_wave_base "$d" 1)"
  [ "$status" -eq 0 ]; [ -z "$output" ]
}
