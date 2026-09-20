load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "dk-leader opens a named leader pane" {
  run dk-leader pay "金流"; [ "$status" -eq 0 ]; [ "$output" = "leader-pay wC:p2" ]
  grep -q -- "--current --direction right --cwd $PROJECT --no-focus --env DK_ROOT=$DK_ROOT --env HERDR_ENV=1" "$HERDR_STUB_LOG"
  grep -q '^agent start leader-pay --kind claude --pane wC:p2 -- --model opus --effort high --permission-mode auto --add-dir '"$PROJECT"' --name dk/pay$' "$HERDR_STUB_LOG"
  grep -q 'dk-task-new pay "金流"' "$HERDR_STUB_LOG"
}
@test "dk-leader validates short name" { run dk-leader Pay x; [ "$status" -eq 1 ]; }
@test "dk-leader rejects a display name with backslash/quote/dollar/backtick" {
  run dk-leader pay 'abc\'; [ "$status" -eq 1 ]
}
@test "dk-leader rejects unknown model/effort and unknown kind" {
  run dk-leader pay x --model gpt-5; [ "$status" -eq 1 ]; [[ "$output" == *"unknown model"* ]]
  run dk-leader pay x --effort max; [ "$status" -eq 1 ]; [[ "$output" == *"unknown effort"* ]]
  run dk-leader pay x --kind nope;  [ "$status" -eq 1 ]
  refute_grep '^agent start' "$HERDR_STUB_LOG"
}
@test "dk-leader dies cleanly when pane split fails" {
  HERDR_STUB_FAIL="pane split" run dk-leader pay x; [ "$status" -eq 1 ]; [[ "$output" == *"no pane_id"* ]]
}
@test "dk-leader's first prompt waits for the leader to start, and a failure keeps the pane" {
  dk-leader pay "金流" >/dev/null
  p=$(grep '^agent prompt leader-pay ' "$HERDR_STUB_LOG")
  [[ "$p" == *"--wait --until working"* ]]
  : > "$HERDR_STUB_LOG"
  HERDR_STUB_FAIL="agent prompt" run dk-leader pay "金流"
  [ "$status" -eq 1 ]; [[ "$output" == *"first prompt"* ]]
  refute_grep '^pane close' "$HERDR_STUB_LOG"
}

# --- dk-leader <short> --run：實體化 + 交棒（0.10.0） ---------------------------
# 單 repo 模式。多 repo（DK_REPOS）在波 2。

mk() { # 一個過了關卡①、還沒實體化的任務
  dk-task-new login "使用者登入" >/dev/null
  dk-process "brief-review skipped: 單元測試"
  dk-task-new login --gate1 >/dev/null
  d="$DK_ROOT/tasks/$(date +%F)-login"
}

@test "--run 實體化 worktree 與 workspace、改寫 .task.env、交棒給根 pane" {
  mk
  base=$(git -C "$PROJECT" rev-parse HEAD)
  run dk-leader login --run; [ "$status" -eq 0 ]
  # worktree 與分支（原本在 05_task_new，0.10.0 起是 --run 的事）
  git -C "$PROJECT" worktree list --porcelain | grep -qx "worktree $WORKTREE_PATH"
  [ "$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref HEAD)" = dk/login ]
  # workspace 與 tab：label 與 tab 名都是分支名
  grep -q "^workspace create --cwd $PROJECT --label dk/login --no-focus --env DK_ROOT=$DK_ROOT --env HERDR_ENV=1\$" "$HERDR_STUB_LOG"
  grep -q '^tab rename wC:t1 dk/login$' "$HERDR_STUB_LOG"
  # .task.env 的五個欄位
  grep -q '^DK_WORKSPACE="wC"$' "$d/.task.env"
  grep -q '^DK_ROOT_PANE="wC:p1"$' "$d/.task.env"
  grep -q '^DK_LEADER_PANE="wC:p1"$' "$d/.task.env"
  grep -q "^DK_WORKTREE=\"$WORKTREE_PATH\"$" "$d/.task.env"
  grep -q "^DK_BASE=\"$base\"$" "$d/.task.env"
  # 交棒
  grep -q '^agent rename wB:p1 --clear$' "$HERDR_STUB_LOG"
  grep -q "^agent start leader-login --kind claude --pane wC:p1 -- --model opus --effort high --permission-mode auto --add-dir $PROJECT --name dk/login\$" "$HERDR_STUB_LOG"
  grep -q '^agent prompt leader-login .*--wait --until working' "$HERDR_STUB_LOG"
  [ "$(cat "$DK_ROOT/.sessions/wC:p1")" = "$(basename "$d")" ]
  [ ! -f "$DK_ROOT/.sessions/wB:p1" ]
  grep -q 'materialize repos main workspace wC' "$d/process.md"
  grep -q 'handoff run-leader pane wC:p1' "$d/process.md"
}

@test "--run 起 codex 領導時不帶 --name（AC19 反面）" {
  mk
  run dk-leader login --run --kind codex; [ "$status" -eq 0 ]
  grep -q '^agent start leader-login --kind codex --pane wC:p1 -- ' "$HERDR_STUB_LOG"
  refute_grep -- '--name dk/login' "$HERDR_STUB_LOG"
}

@test "--run 尊重 DK_WORKTREE_DIR" {
  mk
  DK_WORKTREE_DIR="$PROJECT/wt" run dk-leader login --run; [ "$status" -eq 0 ]
  grep -q "^DK_WORKTREE=\"$PROJECT/wt/login\"$" "$d/.task.env"
  [ -d "$PROJECT/wt/login" ]
}

@test "--run 對 DK_NO_WORKTREE 的任務不切 worktree，DK_WORKTREE 指主樹" {
  dk-task-new login "使用者登入" --no-worktree >/dev/null
  dk-process "brief-review skipped: 單元測試"; dk-task-new login --gate1 >/dev/null
  d="$DK_ROOT/tasks/$(date +%F)-login"
  run dk-leader login --run; [ "$status" -eq 0 ]
  grep -q "^DK_WORKTREE=\"$PROJECT\"$" "$d/.task.env"
  grep -Eq '^DK_BASE="[0-9a-f]{40}"$' "$d/.task.env"
  [ ! -e "$WORKTREE_PATH" ]
  grep -q '^workspace create ' "$HERDR_STUB_LOG"
}

@test "--run 在分支已存在時拒絕，.task.env 原封不動" {
  mk
  git -C "$PROJECT" branch dk/login
  run dk-leader login --run; [ "$status" -eq 1 ]; [[ "$output" == *"worktree add failed"* ]]
  grep -q '^DK_WORKTREE=""$' "$d/.task.env"; grep -q '^DK_WORKSPACE="wB"$' "$d/.task.env"
  refute_grep '^workspace create' "$HERDR_STUB_LOG"
}

@test "--run: workspace create 失敗就清掉 worktree、分支並還原 .task.env" {
  mk
  HERDR_STUB_FAIL="workspace create" run dk-leader login --run; [ "$status" -ne 0 ]
  [ ! -e "$WORKTREE_PATH" ]
  refute_grep -qx 'dk/login' <(git -C "$PROJECT" branch --format='%(refname:short)')
  grep -q '^DK_WORKTREE=""$' "$d/.task.env"; grep -q '^DK_BASE=""$' "$d/.task.env"
  grep -q '^DK_WORKSPACE="wB"$' "$d/.task.env"; grep -q '^DK_ROOT_PANE="wB:p1"$' "$d/.task.env"
  grep -q '^DK_LEADER_PANE="wB:p1"$' "$d/.task.env"
  refute_grep '^agent start' "$HERDR_STUB_LOG"
}

@test "--run: 交棒前失敗時 rollback 連 workspace 一起關掉" {
  mk
  HERDR_STUB_FAIL="agent rename" run dk-leader login --run; [ "$status" -ne 0 ]
  grep -q '^workspace close wC$' "$HERDR_STUB_LOG"
  [ ! -e "$WORKTREE_PATH" ]
  refute_grep -qx 'dk/login' <(git -C "$PROJECT" branch --format='%(refname:short)')
  grep -q '^DK_WORKTREE=""$' "$d/.task.env"; grep -q '^DK_WORKSPACE="wB"$' "$d/.task.env"
  refute_grep '^agent start' "$HERDR_STUB_LOG"
}

@test "--run 需要關卡①、也不准有開著的波" {
  dk-task-new login "使用者登入" >/dev/null
  d="$DK_ROOT/tasks/$(date +%F)-login"
  run dk-leader login --run; [ "$status" -eq 1 ]; [[ "$output" == *"gate1"* ]]
  dk-process "brief-review skipped: 單元測試"; dk-task-new login --gate1 >/dev/null
  sed -i 's/^DK_WAVE=.*/DK_WAVE="1"/' "$d/.task.env"
  run dk-leader login --run; [ "$status" -eq 1 ]; [[ "$output" == *"波"* ]]
  refute_grep '^workspace create' "$HERDR_STUB_LOG"
  [ ! -e "$WORKTREE_PATH" ]
}

@test "--run 對不存在的任務乾淨地死" {
  run dk-leader nosuch --run; [ "$status" -eq 1 ]; [[ "$output" == *"nosuch"* ]]
}

@test "--run 重跑是幂等的：已交棒就只印一行" {
  mk
  dk-leader login --run >/dev/null
  : > "$HERDR_STUB_LOG"
  run dk-leader login --run; [ "$status" -eq 0 ]; [[ "$output" == *"已交棒"* ]]
  refute_grep '^workspace create' "$HERDR_STUB_LOG"
  refute_grep '^agent start' "$HERDR_STUB_LOG"
}

@test "--run 已實體化但根 pane 沒有領導：跳過實體化，只重做交棒" {
  mk
  dk-leader login --run >/dev/null
  rm -f "$HERDR_STUB_RESPONSES/agent_get.wC:p1.json"   # 執行領導掛了
  : > "$HERDR_STUB_LOG"
  run dk-leader login --run; [ "$status" -eq 0 ]
  refute_grep '^workspace create' "$HERDR_STUB_LOG"
  grep -q '^agent start leader-login --kind claude --pane wC:p1 -- ' "$HERDR_STUB_LOG"
  git -C "$PROJECT" worktree list --porcelain | grep -qx "worktree $WORKTREE_PATH"
}
