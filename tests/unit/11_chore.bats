load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "chore without code splits from current pane in project root" {
  run dk-chore frontend "翻譯 docs/README.md 成英文" --tier S
  [ "$status" -eq 0 ]
  f=$(ls "$DK_ROOT/tasks/_chores/"*.md); grep -q '^交代：翻譯 docs/README.md 成英文$' "$f"
  grep -q '^成員：chore-frontend-1 (claude / S)$' "$f"; grep -q '^branch: -$' "$f"
  split=$(grep '^pane split' "$HERDR_STUB_LOG"); [[ "$split" == *"--current --direction right --cwd $PROJECT --no-focus"* ]]
  [[ "$split" == *"--env DK_CHORE_FILE=$f"* ]]; [[ "$split" == *"--env DK_CHORE_CODE=0"* ]]
  grep -q '^agent start chore-frontend-1 --kind claude --pane wC:p2 -- --model sonnet --effort low' "$HERDR_STUB_LOG"
  grep -q '| chore | working |' "$DK_ROOT/tasks/INDEX.md"
  ! grep -q '^worktree create' "$HERDR_STUB_LOG"
}
@test "chore --code makes a worktree branch and numbers agents" {
  dk-chore frontend "first" >/dev/null
  run dk-chore frontend "修登入頁 Safari 版面" --code
  [ "$status" -eq 0 ]
  grep -q '^worktree create --branch chore/.* --base main --cwd .* --no-focus$' "$HERDR_STUB_LOG"
  grep -q '^agent start chore-frontend-2 ' "$HERDR_STUB_LOG"
  f=$(grep -l 'chore-frontend-2' "$DK_ROOT/tasks/_chores/"*.md); grep -q '^branch: chore/' "$f"; grep -q '^workspace: wC$' "$f"; grep -q '^pane: wC:p2$' "$f"
}
@test "chore-close without code: closes pane, marks index done" {
  dk-chore frontend "翻譯 README" >/dev/null
  f=$(ls "$DK_ROOT/tasks/_chores/"*.md); sed -i 's/^status: working/status: done/; s#^結果：$#結果：docs/README.en.md#' "$f"
  run dk-chore-close chore-frontend-1; [ "$status" -eq 0 ]
  grep -q '^pane close wC:p2$' "$HERDR_STUB_LOG"; ! grep -q '^worktree remove' "$HERDR_STUB_LOG"
  grep -q '| 翻譯 README | chore | done | docs/README.en.md |' "$DK_ROOT/tasks/INDEX.md"
}
@test "chore-close --code: merges branch, removes worktree" {
  git -C "$PROJECT" branch chore/fix; git -C "$PROJECT" checkout -q chore/fix; echo x > "$PROJECT/x.txt"
  git -C "$PROJECT" add x.txt; git -C "$PROJECT" commit -q -m fix; git -C "$PROJECT" checkout -q main
  dk-chore frontend "fix" --code >/dev/null
  f=$(grep -l 'chore-frontend-1' "$DK_ROOT/tasks/_chores/"*.md); sed -i 's/^status: working/status: done/' "$f"
  run dk-chore-close chore-frontend-1; [ "$status" -eq 0 ]
  [ -f "$PROJECT/x.txt" ]; grep -q '^worktree remove --workspace wC --force$' "$HERDR_STUB_LOG"
  grep -Eq '\| fix \| chore \| done \| merged [0-9a-f]{7} \|' "$DK_ROOT/tasks/INDEX.md"
}
@test "chore-close refuses when not done; --abandon skips merge and deletes branch" {
  dk-chore frontend "fix" --code >/dev/null; git -C "$PROJECT" branch chore/fix
  run dk-chore-close chore-frontend-1; [ "$status" -eq 1 ]
  run dk-chore-close chore-frontend-1 --abandon; [ "$status" -eq 0 ]
  ! git -C "$PROJECT" rev-parse --verify -q chore/fix; grep -q '| fix | chore | abandoned |' "$DK_ROOT/tasks/INDEX.md"
}
@test "instruction containing a pipe still round-trips through INDEX" {
  dk-chore frontend "翻譯 a|b 文件" >/dev/null
  f=$(ls "$DK_ROOT/tasks/_chores/"*.md); sed -i 's/^status: working/status: done/' "$f"
  run dk-chore-close chore-frontend-1; [ "$status" -eq 0 ]
  grep -q '| 翻譯 a／b 文件 | chore | done |' "$DK_ROOT/tasks/INDEX.md"
  [ "$(grep -c '翻譯 a' "$DK_ROOT/tasks/INDEX.md")" -eq 1 ]
}
@test "chore closes the pane and removes the chore file when agent start fails" {
  HERDR_STUB_FAIL="agent start" run dk-chore frontend "x"
  [ "$status" -eq 1 ]
  grep -q '^pane close wC:p2$' "$HERDR_STUB_LOG"
  [ -z "$(ls "$DK_ROOT/tasks/_chores/"*.md 2>/dev/null)" ]
}
@test "chore-close dies cleanly when no chore file matches" {
  run dk-chore-close chore-frontend-9
  [ "$status" -eq 1 ]
  [[ "$output" == *"no chore file"* ]]
}
@test "chore-close leaves a non-code 結果 line containing & untouched" {
  dk-chore frontend "fix" >/dev/null
  f=$(ls "$DK_ROOT/tasks/_chores/"*.md)
  sed -i 's/^status: working/status: done/; s#^結果：$#結果：docs/a \& b.md#' "$f"
  run dk-chore-close chore-frontend-1
  [ "$status" -eq 0 ]
  grep -q '^結果：docs/a & b.md$' "$f"
  grep -q '| fix | chore | done | docs/a & b.md |' "$DK_ROOT/tasks/INDEX.md"
}
@test "chore prompt tells the worker to report through dk-msg, not a raw herdr prompt" {
  dk-chore frontend "翻譯 README" >/dev/null
  p=$(grep '^agent prompt chore-frontend-1 ' "$HERDR_STUB_LOG")
  [[ "$p" == *'dk-msg leader "[DONE] '* ]]
  [[ "$p" != *'herdr agent prompt'* ]]
}
@test "multi-line instruction keeps INDEX one row per chore and chore-close still finds it" {
  dk-chore frontend $'同步四個文件位置\n(1) AGENTS.md 第 23 行\n(2) roles/frontend.md' >/dev/null
  [ "$(grep -c '| chore | working |' "$DK_ROOT/tasks/INDEX.md")" -eq 1 ]
  grep -q '^| .* | 同步四個文件位置 | chore | working |' "$DK_ROOT/tasks/INDEX.md"
  ! grep -q '^(1) AGENTS.md' "$DK_ROOT/tasks/INDEX.md"
  f=$(ls "$DK_ROOT/tasks/_chores/"*.md); grep -q '^(2) roles/frontend.md$' "$f"   # the chore file keeps the full text
  sed -i 's/^status: working/status: done/' "$f"
  run dk-chore-close chore-frontend-1; [ "$status" -eq 0 ]
  grep -q '| 同步四個文件位置 | chore | done |' "$DK_ROOT/tasks/INDEX.md"
  ! grep -q '| chore | working |' "$DK_ROOT/tasks/INDEX.md"
}
