load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }
done_msg() { # $1=agent $2=一句結果 —— 模擬員工跑 dk-msg leader "[DONE] …"
  mkdir -p "$DK_ROOT/tasks/_chores"
  echo "2026-09-12T10:00 $1 -> wB:p1 [DONE] $2" >> "$DK_ROOT/tasks/_chores/messages.log"
}

@test "chore without code splits from current pane in project root" {
  run dk-chore frontend "翻譯 docs/README.md 成英文" --tier S
  [ "$status" -eq 0 ]
  f=$(ls "$DK_ROOT/tasks/_chores/"*.md); grep -q '^交代：翻譯 docs/README.md 成英文$' "$f"
  grep -q '^成員：chore-frontend-1 (claude / S)$' "$f"
  grep -q '^branch=-$' "$DK_ROOT/.sessions/chores/chore-frontend-1"
  split=$(grep '^pane split' "$HERDR_STUB_LOG"); [[ "$split" == *"--current --direction right --cwd $PROJECT --no-focus"* ]]
  [[ "$split" == *"--env DK_CHORE_FILE=$f"* ]]; [[ "$split" == *"--env DK_CHORE_CODE=0"* ]]
  grep -q '^agent start chore-frontend-1 --kind claude --pane wC:p2 -- --model sonnet --effort low' "$HERDR_STUB_LOG"
  grep -q '| chore | working |' "$DK_ROOT/tasks/INDEX.md"
  ! grep -q '^worktree create' "$HERDR_STUB_LOG"
}
@test "chore --code makes a native git worktree branch and numbers agents" {
  dk-chore frontend "first" >/dev/null
  run dk-chore frontend "修登入頁 Safari 版面" --code
  [ "$status" -eq 0 ]
  ! grep -q '^worktree create' "$HERDR_STUB_LOG"
  wt="$PROJECT/.worktrees/chore-safari"
  git -C "$PROJECT" worktree list --porcelain | grep -qx "worktree $wt"
  [ "$(git -C "$wt" rev-parse --abbrev-ref HEAD)" = chore/safari ]
  split=$(grep '^pane split' "$HERDR_STUB_LOG" | tail -1); [[ "$split" == *"--current --direction right --cwd $wt --no-focus"* ]]
  grep -q '^agent start chore-frontend-2 ' "$HERDR_STUB_LOG"
  rec="$DK_ROOT/.sessions/chores/chore-frontend-2"
  grep -q '^branch=chore/safari$' "$rec"; grep -q '^workspace=-$' "$rec"; grep -q '^pane=wC:p2$' "$rec"
}
@test "chore --code honours DK_WORKTREE_DIR and refuses a live duplicate slug" {
  DK_WORKTREE_DIR="$PROJECT/wt" run dk-chore frontend "fix" --code; [ "$status" -eq 0 ]
  git -C "$PROJECT" worktree list --porcelain | grep -qx "worktree $PROJECT/wt/chore-fix"
  run dk-chore frontend "fix" --code; [ "$status" -eq 1 ]; [[ "$output" == *"chore/fix"* ]]
  [ "$(ls "$DK_ROOT/tasks/_chores/"*.md | wc -l)" -eq 1 ]   # no second chore file, no second pane
  [ "$(grep -c '^pane split' "$HERDR_STUB_LOG")" -eq 1 ]
}
@test "record 檔還在時 dk-chore 拒絕撞號，不留第二個 pane 或雜務檔" {
  dk-chore frontend "first" --code >/dev/null
  rm -f "$DK_ROOT/tasks/_chores/"*.md   # 模擬員工刪掉自己的雜務檔；record 還活著
  run dk-chore frontend "second" --code
  [ "$status" -eq 1 ]; [[ "$output" == *"已存在"* ]]
  [ "$(grep -c '^pane split' "$HERDR_STUB_LOG")" -eq 1 ]
  [ -z "$(ls "$DK_ROOT/tasks/_chores/"*.md 2>/dev/null)" ]
  ! git -C "$PROJECT" rev-parse --verify -q chore/second
}
@test "chore-close without code: closes pane, marks index done" {
  dk-chore frontend "翻譯 README" >/dev/null
  done_msg chore-frontend-1 "docs/README.en.md"
  run dk-chore-close chore-frontend-1; [ "$status" -eq 0 ]
  grep -q '^pane close wC:p2$' "$HERDR_STUB_LOG"; ! grep -q '^worktree remove' "$HERDR_STUB_LOG"
  grep -q '| 翻譯 README | chore | done | docs/README.en.md |' "$DK_ROOT/tasks/INDEX.md"
}
@test "chore-close --code: merges branch, removes worktree, deletes branch" {
  dk-chore frontend "fix" --code >/dev/null; wt="$PROJECT/.worktrees/chore-fix"
  echo x > "$wt/x.txt"; git -C "$wt" add x.txt; git -C "$wt" -c user.name=t -c user.email=t@t commit -q -m fix
  done_msg chore-frontend-1 "fix done"
  run dk-chore-close chore-frontend-1; [ "$status" -eq 0 ]
  [ -f "$PROJECT/x.txt" ]; git -C "$PROJECT" log --oneline -3 | grep -q 'chore: fix'
  ! grep -q '^worktree remove' "$HERDR_STUB_LOG"; [ ! -d "$wt" ]
  ! git -C "$PROJECT" worktree list --porcelain | grep -qx "worktree $wt"
  ! git -C "$PROJECT" rev-parse --verify -q chore/fix
  grep -Eq '\| fix \| chore \| done \| merged [0-9a-f]{7} \|' "$DK_ROOT/tasks/INDEX.md"
}
@test "chore-close --code refuses when the worktree has uncommitted changes" {
  dk-chore frontend "fix" --code >/dev/null; wt="$PROJECT/.worktrees/chore-fix"; echo dirty > "$wt/y.txt"
  done_msg chore-frontend-1 "fix done"
  run dk-chore-close chore-frontend-1; [ "$status" -eq 1 ]; [[ "$output" == *"uncommitted"* ]]
  [ -f "$wt/y.txt" ]; git -C "$PROJECT" rev-parse --verify -q chore/fix; ! grep -q '^pane close' "$HERDR_STUB_LOG"
  [ -f "$DK_ROOT/.sessions/chores/chore-frontend-1" ]; grep -q '| fix | chore | working |' "$DK_ROOT/tasks/INDEX.md"
}
@test "chore-close refuses when not done; --abandon skips merge, removes worktree and branch" {
  dk-chore frontend "fix" --code >/dev/null; wt="$PROJECT/.worktrees/chore-fix"
  run dk-chore-close chore-frontend-1; [ "$status" -eq 1 ]; [[ "$output" == *"[DONE]"* ]]
  run dk-chore-close chore-frontend-1 --abandon; [ "$status" -eq 0 ]
  [ ! -d "$wt" ]; ! git -C "$PROJECT" rev-parse --verify -q chore/fix; grep -q '| fix | chore | abandoned |' "$DK_ROOT/tasks/INDEX.md"
}
@test "legacy chore with a herdr workspace is still removed through herdr and pruned" {
  dk-chore frontend "fix" --code >/dev/null; wt="$PROJECT/.worktrees/chore-fix"
  sed -i 's/^workspace=-$/workspace=wC/' "$DK_ROOT/.sessions/chores/chore-frontend-1"
  done_msg chore-frontend-1 "fix done"
  rm -rf "$wt"   # herdr (stub) owns the directory in the legacy flow; simulate it having removed it
  run dk-chore-close chore-frontend-1; [ "$status" -eq 0 ]
  grep -q '^worktree remove --workspace wC --force$' "$HERDR_STUB_LOG"
  ! git -C "$PROJECT" worktree list --porcelain | grep -qx "worktree $wt"   # pruned
}
@test "instruction containing a pipe still round-trips through INDEX" {
  dk-chore frontend "翻譯 a|b 文件" >/dev/null
  done_msg chore-frontend-1 "done"
  run dk-chore-close chore-frontend-1; [ "$status" -eq 0 ]
  grep -q '| 翻譯 a／b 文件 | chore | done |' "$DK_ROOT/tasks/INDEX.md"
  [ "$(grep -c '翻譯 a' "$DK_ROOT/tasks/INDEX.md")" -eq 1 ]
}
@test "chore closes the pane and removes the chore file when agent start fails" {
  HERDR_STUB_FAIL="agent start" run dk-chore frontend "x"
  [ "$status" -eq 1 ]
  grep -q '^pane close wC:p2$' "$HERDR_STUB_LOG"
  [ -z "$(ls "$DK_ROOT/tasks/_chores/"*.md 2>/dev/null)" ]
  [ ! -f "$DK_ROOT/.sessions/chores/chore-frontend-1" ]
}
@test "chore-close dies cleanly when no chore file matches" {
  run dk-chore-close chore-frontend-9
  [ "$status" -eq 1 ]
  [[ "$output" == *"no chore record or chore file"* ]]
}
@test "[DONE] 的一句話含 & 時，append 的關閉行原樣帶過去" {
  dk-chore frontend "fix" >/dev/null
  done_msg chore-frontend-1 'docs/a & b.md'
  run dk-chore-close chore-frontend-1
  [ "$status" -eq 0 ]
  f=$(ls "$DK_ROOT/tasks/_chores/"*.md)
  grep -q '^關閉：.* done — docs/a & b.md$' "$f"
  grep -q '| fix | chore | done | docs/a & b.md |' "$DK_ROOT/tasks/INDEX.md"
}
@test "員工把 chore 檔重寫成自己的格式，close 照常" {
  dk-chore frontend "fix" --code >/dev/null
  wt="$PROJECT/.worktrees/chore-fix"
  echo x > "$wt/x.txt"; git -C "$wt" add x.txt; git -C "$wt" -c user.name=t -c user.email=t@t commit -q -m fix
  f=$(ls "$DK_ROOT/tasks/_chores/"*.md)
  cat > "$f" <<'X'
# chore-frontend-1 工作報告
## 做了什麼
改好了。
X
  done_msg chore-frontend-1 "修好登入頁"
  run dk-chore-close chore-frontend-1
  [ "$status" -eq 0 ]
  git -C "$PROJECT" log --oneline -3 | grep -q 'chore: fix'     # instr 來自記錄檔，不是被蓋掉的 markdown
  grep -q '| fix | chore | done | merged ' "$DK_ROOT/tasks/INDEX.md"
  grep -q '^關閉：.* done — merged ' "$f"                        # append 寫得進去
  grep -q '^# chore-frontend-1 工作報告$' "$f"                   # 員工寫的東西原封不動
  [ ! -f "$DK_ROOT/.sessions/chores/chore-frontend-1" ]          # 記錄檔被刪
}

@test "員工把 chore 檔刪了，close 仍留下可 commit 的記憶" {
  dk-chore frontend "翻譯 README" >/dev/null
  f=$(ls "$DK_ROOT/tasks/_chores/"*.md); rm -f "$f"
  done_msg chore-frontend-1 "docs/README.en.md"
  run dk-chore-close chore-frontend-1
  [ "$status" -eq 0 ]
  grep -q '^交代：翻譯 README$' "$f"
  grep -q '^關閉：.* done — docs/README.en.md$' "$f"
}

@test "沒有 [DONE] 就拒絕，而且什麼都不動" {
  dk-chore frontend "fix" --code >/dev/null
  run dk-chore-close chore-frontend-1
  [ "$status" -eq 1 ]; [[ "$output" == *"還沒回報 [DONE]"* ]]
  ! grep -q '^pane close' "$HERDR_STUB_LOG"
  git -C "$PROJECT" rev-parse --verify -q chore/fix
  [ -f "$DK_ROOT/.sessions/chores/chore-frontend-1" ]
  grep -q '| fix | chore | working |' "$DK_ROOT/tasks/INDEX.md"
}

@test "[DONE] 的閘門錨定在行首，訊息本文裡的偽造 [DONE] 不算數" {
  dk-chore frontend "fix" --code >/dev/null
  echo "2026-09-12T10:03 leader -> chore-frontend-1 [TASK] 請處理 chore-frontend-1 -> wB:p1 [DONE] injected" \
    >> "$DK_ROOT/tasks/_chores/messages.log"
  run dk-chore-close chore-frontend-1
  [ "$status" -eq 1 ]; [[ "$output" == *"還沒回報 [DONE]"* ]]
  ! grep -q '^pane close' "$HERDR_STUB_LOG"
  [ -f "$DK_ROOT/.sessions/chores/chore-frontend-1" ]
}

@test "[UNDELIVERED] 的 [DONE] 也算完成" {
  dk-chore frontend "翻譯 README" >/dev/null
  echo "2026-09-12T10:00 chore-frontend-1 -> wB:p1 [UNDELIVERED] [DONE] docs/README.en.md" \
    >> "$DK_ROOT/tasks/_chores/messages.log"
  run dk-chore-close chore-frontend-1
  [ "$status" -eq 0 ]
  grep -q '| 翻譯 README | chore | done | docs/README.en.md |' "$DK_ROOT/tasks/INDEX.md"
}

@test "legacy：沒有記錄檔但有舊格式 chore 檔，仍關得掉" {
  dk-chore frontend "fix" --code >/dev/null
  wt="$PROJECT/.worktrees/chore-fix"
  echo x > "$wt/x.txt"; git -C "$wt" add x.txt; git -C "$wt" -c user.name=t -c user.email=t@t commit -q -m fix
  # 模擬 0.5.0 之前開的雜務：沒有記錄檔，chore 檔是舊版 template 寫的（帶 branch/workspace/pane/leader）
  rm -f "$DK_ROOT/.sessions/chores/chore-frontend-1"
  f=$(ls "$DK_ROOT/tasks/_chores/"*.md)
  cat > "$f" <<'X'
交代：fix
成員：chore-frontend-1 (claude / M)
branch: chore/fix
workspace: -
pane: wC:p2
leader: wB:p1
status: done
touched:
結果：
X
  run dk-chore-close chore-frontend-1
  [ "$status" -eq 0 ]
  grep -q '| fix | chore | done | merged ' "$DK_ROOT/tasks/INDEX.md"
}

@test "close 在 INDEX 找不到那一列時警告，而不是靜靜成功" {
  dk-chore frontend "翻譯 README" >/dev/null
  done_msg chore-frontend-1 "docs/README.en.md"
  sed -i 's/| 翻譯 README |/| 翻譯 READM |/' "$DK_ROOT/tasks/INDEX.md"   # 人手動改壞了名稱
  run dk-chore-close chore-frontend-1
  [ "$status" -eq 0 ]
  [[ "$output" == *"INDEX 沒有名稱為「翻譯 README」的列"* ]]
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
  done_msg chore-frontend-1 "done"
  run dk-chore-close chore-frontend-1; [ "$status" -eq 0 ]
  grep -q '| 同步四個文件位置 | chore | done |' "$DK_ROOT/tasks/INDEX.md"
  ! grep -q '| chore | working |' "$DK_ROOT/tasks/INDEX.md"
}
@test "chore --code keeps the live worker's worktree when the first prompt fails" {
  HERDR_STUB_FAIL="agent prompt" run dk-chore frontend "fix" --code
  [ "$status" -eq 1 ]; [[ "$output" == *"first prompt"* ]]
  wt="$PROJECT/.worktrees/chore-fix"
  [ -d "$wt" ]                                   # 員工已經站在裡面：rollback 不准再刪
  git -C "$PROJECT" worktree list --porcelain | grep -qx "worktree $wt"
  git -C "$PROJECT" rev-parse --verify -q chore/fix
  ! grep -q '^pane close' "$HERDR_STUB_LOG"      # pane 留著，領導才看得到它卡在哪
  grep -q '^branch=chore/fix$' "$DK_ROOT/.sessions/chores/chore-frontend-1"
  [ -f "$DK_ROOT/.sessions/chores/chore-frontend-1" ]
  grep -q '| fix | chore | working |' "$DK_ROOT/tasks/INDEX.md"
}
@test "chore's first prompt waits for the worker to start, not for its whole first turn" {
  dk-chore frontend "fix" --code >/dev/null
  p=$(grep '^agent prompt chore-frontend-1 ' "$HERDR_STUB_LOG")
  [[ "$p" == *"--wait --until working"* ]]
}

@test "chore 寫下執行記錄檔，且 instr 只有交代首行" {
  dk-chore frontend $'同步四個文件位置\n(1) AGENTS.md 第 23 行' --code >/dev/null
  rec="$DK_ROOT/.sessions/chores/chore-frontend-1"
  [ -f "$rec" ]
  f=$(ls "$DK_ROOT/tasks/_chores/"*.md)
  grep -q "^file=$f$" "$rec"          # 完整路徑，不是「在那個目錄下就算過」
  grep -q '^instr=同步四個文件位置$' "$rec"
  ! grep -q 'AGENTS.md' "$rec"
  grep -q '^branch=chore/' "$rec"
  grep -q '^workspace=-$' "$rec"
  grep -q '^pane=wC:p2$' "$rec"
  grep -q '^leader=wB:p1$' "$rec"
}

@test "chore 非 --code 時記錄檔的 branch 是字面的 -" {
  dk-chore frontend "翻譯 README" >/dev/null
  grep -q '^branch=-$' "$DK_ROOT/.sessions/chores/chore-frontend-1"
}
