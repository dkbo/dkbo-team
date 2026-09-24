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
  run dk-leader pay x --effort ultra; [ "$status" -eq 1 ]; [[ "$output" == *"unknown effort"* ]]
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
# 單 repo 與多 repo（DK_REPOS）兩種模式。

mk() { # 一個過了關卡①、還沒實體化的任務
  dk-task-new login "使用者登入" >/dev/null
  dk-process "brief-review skipped: 單元測試"
  dk-task-new login --gate1 >/dev/null
  d="$DK_ROOT/tasks/$(date +%F)-login"
}

@test "--run 實體化 worktree 與任務根 tab、改寫 .task.env、交棒給根 pane" {
  mk
  base=$(git -C "$PROJECT" rev-parse HEAD)
  run dk-leader login --run; [ "$status" -eq 0 ]
  # worktree 與分支（原本在 05_task_new，0.10.0 起是 --run 的事）
  git -C "$PROJECT" worktree list --porcelain | grep -qx "worktree $WORKTREE_PATH"
  [ "$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref HEAD)" = dk/login ]
  # 任務根 tab：開在人當下所在的 workspace（HERDR_WORKSPACE_ID，這裡與 DK_WORKSPACE 同為 wB），label 是分支名
  grep -q "^tab create --workspace wB --cwd $PROJECT --label dk/login --no-focus --env DK_ROOT=$DK_ROOT --env HERDR_ENV=1\$" "$HERDR_STUB_LOG"
  refute_grep '^workspace create' "$HERDR_STUB_LOG"
  refute_grep '^workspace get' "$HERDR_STUB_LOG"
  refute_grep '^tab rename' "$HERDR_STUB_LOG"
  # .task.env：DK_TASK_TAB／DK_ROOT_PANE／DK_LEADER_PANE／DK_WORKTREE／DK_BASE 五欄，DK_WORKSPACE 維持原值
  grep -q '^DK_WORKSPACE="wB"$' "$d/.task.env"
  grep -q '^DK_TASK_TAB="wB:t2"$' "$d/.task.env"
  grep -q '^DK_ROOT_PANE="wB:p10"$' "$d/.task.env"
  grep -q '^DK_LEADER_PANE="wB:p10"$' "$d/.task.env"
  grep -q "^DK_WORKTREE=\"$WORKTREE_PATH\"$" "$d/.task.env"
  grep -q "^DK_BASE=\"$base\"$" "$d/.task.env"
  # 交棒
  grep -q '^agent rename wB:p1 --clear$' "$HERDR_STUB_LOG"
  grep -q "^agent start leader-login --kind claude --pane wB:p10 -- --model opus --effort high --permission-mode auto --add-dir $PROJECT --name dk/login\$" "$HERDR_STUB_LOG"
  grep -q '^agent prompt leader-login .*--wait --until working' "$HERDR_STUB_LOG"
  [ "$(cat "$DK_ROOT/.sessions/wB:p10")" = "$(basename "$d")" ]
  [ ! -f "$DK_ROOT/.sessions/wB:p1" ]
  grep -q 'materialize repos main tab wB:t2' "$d/process.md"
  grep -q 'handoff run-leader pane wB:p10' "$d/process.md"
}

@test "--run: DK_WORKSPACE 原本是空的就用 HERDR_WORKSPACE_ID 補上並落盤（Important 1 正面）" {
  HERDR_WORKSPACE_ID="" dk-task-new login "使用者登入" >/dev/null
  dk-process "brief-review skipped: 單元測試"
  dk-task-new login --gate1 >/dev/null
  d="$DK_ROOT/tasks/$(date +%F)-login"
  grep -q '^DK_WORKSPACE=""$' "$d/.task.env"
  HERDR_WORKSPACE_ID="wX" run dk-leader login --run; [ "$status" -eq 0 ]
  grep -q '^DK_WORKSPACE="wX"$' "$d/.task.env"
  grep -q -- "--workspace wX " "$HERDR_STUB_LOG"
}

@test "--run: DK_WORKSPACE 原本非空時以當下的 HERDR_WORKSPACE_ID 為準並回寫（Important 1 反面；bklog AC11 語意反轉）" {
  # 0.16.0 起 tab 開在人叫 /dkbo-run 當下所在的 workspace（人拍板的語意反轉，ruling 2026-09-24T14:52）：
  # 原本這條守的是「非空就不被改寫」，現在守的是它的反面
  mk   # HERDR_WORKSPACE_ID=wB 建立時已落盤 DK_WORKSPACE="wB"
  HERDR_WORKSPACE_ID="wZ" run dk-leader login --run; [ "$status" -eq 0 ]
  grep -q '^DK_WORKSPACE="wZ"$' "$d/.task.env"
  grep -q -- "--workspace wZ " "$HERDR_STUB_LOG"
  refute_grep -- "--workspace wB " "$HERDR_STUB_LOG"
}

@test "--run: DK_WORKSPACE 與 HERDR_WORKSPACE_ID 都是空的就拒絕並說明要在 herdr 內跑（AC1）" {
  HERDR_WORKSPACE_ID="" dk-task-new login "使用者登入" >/dev/null
  dk-process "brief-review skipped: 單元測試"
  dk-task-new login --gate1 >/dev/null
  d="$DK_ROOT/tasks/$(date +%F)-login"
  grep -q '^DK_WORKSPACE=""$' "$d/.task.env"
  HERDR_WORKSPACE_ID="" run dk-leader login --run
  [ "$status" -ne 0 ]
  [[ "$output" == *"都是空的"* ]]
  refute_grep '^tab create' "$HERDR_STUB_LOG"
  git -C "$PROJECT" worktree list --porcelain > "$PROJECT/.worktree-list"
  refute_grep -x "worktree $WORKTREE_PATH" "$PROJECT/.worktree-list"
  git -C "$PROJECT" branch --list > "$PROJECT/.branch-list"
  refute_grep 'dk/login' "$PROJECT/.branch-list"
  [ ! -f "$d/.repos" ]
}

@test "--run 起 codex 領導時不帶 --name（AC19 反面）" {
  mk
  run dk-leader login --run --kind codex; [ "$status" -eq 0 ]
  grep -q '^agent start leader-login --kind codex --pane wB:p10 -- ' "$HERDR_STUB_LOG"
  refute_grep -- '--name dk/login' "$HERDR_STUB_LOG"
}

@test "--run 主 repo的 .dkbo/tasks/INDEX.md 已追蹤且已修改時仍要過（Important 1 回歸：本倉這種 .dkbo/ 進版控的專案）" {
  mk
  git -C "$PROJECT" add .dkbo
  git -C "$PROJECT" -c user.name=t -c user.email=t@t commit -q -m "track .dkbo"
  echo more >> "$DK_ROOT/tasks/INDEX.md"   # .dkbo/tasks/INDEX.md 已追蹤且已修改
  run dk-leader login --run; [ "$status" -eq 0 ]
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
  grep -q '^tab create ' "$HERDR_STUB_LOG"
}

@test "--run 在分支已存在時拒絕，.task.env 原封不動" {
  mk
  git -C "$PROJECT" branch dk/login
  run dk-leader login --run; [ "$status" -eq 1 ]; [[ "$output" == *"git worktree add 失敗"* ]]
  grep -q '^DK_WORKTREE=""$' "$d/.task.env"; grep -q '^DK_WORKSPACE="wB"$' "$d/.task.env"
  grep -q '^DK_TASK_TAB=""$' "$d/.task.env"
  refute_grep '^tab create' "$HERDR_STUB_LOG"
}

@test "--run: tab create 失敗就清掉 worktree、分支並還原 .task.env" {
  mk
  HERDR_STUB_FAIL="tab create" run dk-leader login --run; [ "$status" -ne 0 ]
  [ ! -e "$WORKTREE_PATH" ]
  refute_grep -qx 'dk/login' <(git -C "$PROJECT" branch --format='%(refname:short)')
  grep -q '^DK_WORKTREE=""$' "$d/.task.env"; grep -q '^DK_BASE=""$' "$d/.task.env"
  grep -q '^DK_TASK_TAB=""$' "$d/.task.env"
  grep -q '^DK_WORKSPACE="wB"$' "$d/.task.env"; grep -q '^DK_ROOT_PANE="wB:p1"$' "$d/.task.env"
  grep -q '^DK_LEADER_PANE="wB:p1"$' "$d/.task.env"
  refute_grep '^agent start' "$HERDR_STUB_LOG"
}

@test "--run: 交棒前失敗時 rollback 連 tab 一起關掉" {
  mk
  HERDR_STUB_FAIL="agent rename" run dk-leader login --run; [ "$status" -ne 0 ]
  grep -q '^tab close wB:t2$' "$HERDR_STUB_LOG"
  [ ! -e "$WORKTREE_PATH" ]
  refute_grep -qx 'dk/login' <(git -C "$PROJECT" branch --format='%(refname:short)')
  grep -q '^DK_WORKTREE=""$' "$d/.task.env"; grep -q '^DK_WORKSPACE="wB"$' "$d/.task.env"
  grep -q '^DK_TASK_TAB=""$' "$d/.task.env"
  refute_grep '^agent start' "$HERDR_STUB_LOG"
}

@test "--run 需要關卡①、也不准有開著的波" {
  dk-task-new login "使用者登入" >/dev/null
  d="$DK_ROOT/tasks/$(date +%F)-login"
  run dk-leader login --run; [ "$status" -eq 1 ]; [[ "$output" == *"gate1"* ]]
  dk-process "brief-review skipped: 單元測試"; dk-task-new login --gate1 >/dev/null
  sed -i 's/^DK_WAVE=.*/DK_WAVE="1"/' "$d/.task.env"
  run dk-leader login --run; [ "$status" -eq 1 ]; [[ "$output" == *"波"* ]]
  refute_grep '^tab create' "$HERDR_STUB_LOG"
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
  refute_grep '^tab create' "$HERDR_STUB_LOG"
  refute_grep '^agent start' "$HERDR_STUB_LOG"
}

@test "--run 已實體化但根 pane 沒有領導：跳過實體化，只重做交棒" {
  mk
  dk-leader login --run >/dev/null
  rm -f "$HERDR_STUB_RESPONSES/agent_get.wB:p10.json"   # 執行領導掛了
  : > "$HERDR_STUB_LOG"
  run dk-leader login --run; [ "$status" -eq 0 ]
  refute_grep '^tab create' "$HERDR_STUB_LOG"
  grep -q '^agent start leader-login --kind claude --pane wB:p10 -- ' "$HERDR_STUB_LOG"
  git -C "$PROJECT" worktree list --porcelain | grep -qx "worktree $WORKTREE_PATH"
}

@test "--run: 已實體化但任務 tab 已不在時拒絕並提示人工收拾" {
  mk
  dk-leader login --run >/dev/null
  : > "$HERDR_STUB_LOG"
  HERDR_STUB_FAIL="tab get" run dk-leader login --run
  [ "$status" -eq 1 ]; [[ "$output" == *"已不在；先人工收拾"* ]]
  refute_grep '^agent start' "$HERDR_STUB_LOG"
}

# --- 多 repo（DK_REPOS 非空）：AC3 AC4 AC20 ------------------------------------

@test "--run 多 repo：每個 repo 一個 worktree、.repos 三列、DK_WORKTREE 是主 repo 的" {
  setup_multirepo; mk
  run dk-leader login --run; [ "$status" -eq 0 ]
  for n in main api shared; do
    [ -d "$PROJECT/.worktrees/login/$n" ]
    [ "$(git -C "$PROJECT/.worktrees/login/$n" rev-parse --abbrev-ref HEAD)" = dk/login ]
  done
  [ "$(grep -c . "$d/.repos")" -eq 3 ]
  grep -q "^main $PROJECT $PROJECT/.worktrees/login/main [0-9a-f]\{40\}$" "$d/.repos"
  grep -q "^api $REPO_API $PROJECT/.worktrees/login/api [0-9a-f]\{40\}$" "$d/.repos"
  grep -q "^shared $REPO_SHARED $PROJECT/.worktrees/login/shared [0-9a-f]\{40\}$" "$d/.repos"
  [ "$(head -1 "$d/.repos" | awk '{print $1}')" = main ]   # 主 repo 永遠第一列
  grep -q "^DK_WORKTREE=\"$PROJECT/.worktrees/login/main\"\$" "$d/.task.env"
  grep -q "^DK_BASE=\"$(git -C "$PROJECT" rev-parse HEAD)\"\$" "$d/.task.env"
  grep -q 'materialize repos main api shared tab wB:t2' "$d/process.md"
}

@test "--run 單 repo 也寫 .repos：一列，名字 main" {
  mk
  run dk-leader login --run; [ "$status" -eq 0 ]
  [ "$(grep -c . "$d/.repos")" -eq 1 ]
  grep -q "^main $PROJECT $WORKTREE_PATH [0-9a-f]\{40\}\$" "$d/.repos"
}

@test "--run 多 repo 下拒絕 DK_NO_WORKTREE" {
  setup_multirepo
  dk-task-new login "使用者登入" --no-worktree >/dev/null
  dk-process "brief-review skipped: 單元測試"; dk-task-new login --gate1 >/dev/null
  d="$DK_ROOT/tasks/$(date +%F)-login"
  run dk-leader login --run; [ "$status" -eq 1 ]; [[ "$output" == *"DK_NO_WORKTREE"* ]]
  refute_grep '^tab create' "$HERDR_STUB_LOG"
  [ ! -e "$d/.repos" ]; [ ! -e "$PROJECT/.worktrees/login" ]
}

@test "--run 任一 repo 工作樹不乾淨就拒絕並點名該 repo" {
  setup_multirepo; mk
  repo_dirty_tracked "$REPO_API"
  run dk-leader login --run; [ "$status" -eq 1 ]; [[ "$output" == *"api"* ]]
  [ ! -e "$PROJECT/.worktrees/login" ]; [ ! -e "$d/.repos" ]
  refute_grep '^tab create' "$HERDR_STUB_LOG"
}

@test "--run 多 repo：tab create 失敗就清掉全部 worktree、分支與 .repos" {
  setup_multirepo; mk
  HERDR_STUB_FAIL="tab create" run dk-leader login --run; [ "$status" -ne 0 ]
  [ ! -e "$PROJECT/.worktrees/login/main" ]
  [ ! -e "$PROJECT/.worktrees/login/api" ]
  [ ! -e "$PROJECT/.worktrees/login/shared" ]
  refute_grep -qx 'dk/login' <(git -C "$PROJECT" branch --format='%(refname:short)')
  refute_grep -qx 'dk/login' <(git -C "$REPO_API" branch --format='%(refname:short)')
  refute_grep -qx 'dk/login' <(git -C "$REPO_SHARED" branch --format='%(refname:short)')
  [ ! -e "$d/.repos" ]
  grep -q '^DK_WORKTREE=""$' "$d/.task.env"; grep -q '^DK_WORKSPACE="wB"$' "$d/.task.env"
  grep -q '^DK_TASK_TAB=""$' "$d/.task.env"
}

@test "--run 多 repo：交棒前失敗時 rollback 連 tab 一起關掉" {
  setup_multirepo; mk
  HERDR_STUB_FAIL="agent rename" run dk-leader login --run; [ "$status" -ne 0 ]
  grep -q '^tab close wB:t2$' "$HERDR_STUB_LOG"
  [ ! -e "$PROJECT/.worktrees/login/main" ]
  [ ! -e "$PROJECT/.worktrees/login/api" ]
  [ ! -e "$PROJECT/.worktrees/login/shared" ]
  [ ! -e "$d/.repos" ]
  grep -q '^DK_WORKTREE=""$' "$d/.task.env"; grep -q '^DK_TASK_TAB=""$' "$d/.task.env"
  refute_grep '^agent start' "$HERDR_STUB_LOG"
}

@test "--run 某個 repo 的 dk/<short> 分支已存在時點名它並清掉先切好的" {
  setup_multirepo; mk
  git -C "$REPO_SHARED" branch dk/login
  run dk-leader login --run; [ "$status" -eq 1 ]; [[ "$output" == *"shared"* ]]
  [ ! -e "$PROJECT/.worktrees/login/main" ]; [ ! -e "$PROJECT/.worktrees/login/api" ]
  refute_grep -qx 'dk/login' <(git -C "$REPO_API" branch --format='%(refname:short)')
  [ ! -e "$d/.repos" ]
  refute_grep '^tab create' "$HERDR_STUB_LOG"
}

@test "AC20: 每個 worktree 切好後在該 worktree 內、乾淨環境跑 DK_SETUP_CMD_<名>" {
  setup_multirepo
  cat > "$PROJECT/setup.sh" <<'S'
#!/usr/bin/env bash
pwd > setup-ran.txt
env | grep -c '^DK_' >> setup-ran.txt || true
S
  chmod +x "$PROJECT/setup.sh"
  printf 'DK_SETUP_CMD_api="%s"\n' "$PROJECT/setup.sh" >> "$DK_ROOT/settings.env"
  mk
  run dk-leader login --run; [ "$status" -eq 0 ]
  f="$PROJECT/.worktrees/login/api/setup-ran.txt"
  [ -f "$f" ]
  [ "$(sed -n 1p "$f")" = "$PROJECT/.worktrees/login/api" ]   # cwd 是那個 repo 的 worktree
  [ "$(sed -n 2p "$f")" = 0 ]                                  # 一個 DK_* 都沒漏進去
  [ ! -e "$PROJECT/.worktrees/login/main/setup-ran.txt" ]      # 沒設 DK_SETUP_CMD 就不跑
  [ ! -e "$PROJECT/.worktrees/login/shared/setup-ran.txt" ]
}

@test "AC20: 鉤子失敗只警告並記 process，不 rollback" {
  setup_multirepo
  printf 'DK_SETUP_CMD_api="exit 7"\n' >> "$DK_ROOT/settings.env"
  mk
  run dk-leader login --run; [ "$status" -eq 0 ]
  [[ "$output" == *"setup"* ]]
  grep -q 'setup api failed' "$d/process.md"
  [ -d "$PROJECT/.worktrees/login/api" ]        # worktree 本身是好的，不因鉤子而收掉
  grep -q '^agent start leader-login ' "$HERDR_STUB_LOG"
}

@test "AC20: 單 repo 模式也跑 DK_SETUP_CMD" {
  printf 'DK_SETUP_CMD="pwd > setup-ran.txt"\n' >> "$DK_ROOT/settings.env"
  mk
  run dk-leader login --run; [ "$status" -eq 0 ]
  [ "$(cat "$WORKTREE_PATH/setup-ran.txt")" = "$WORKTREE_PATH" ]
}

@test "AC20 回歸: 鉤子讀一次 stdin 仍能跑完 N 個 repo（Important 2）" {
  setup_multirepo
  printf 'DK_SETUP_CMD_api="cat >/dev/null; pwd > setup-ran.txt"\n' >> "$DK_ROOT/settings.env"
  printf 'DK_SETUP_CMD_shared="pwd > setup-ran.txt"\n' >> "$DK_ROOT/settings.env"
  mk
  run dk-leader login --run; [ "$status" -eq 0 ]
  [ -f "$PROJECT/.worktrees/login/api/setup-ran.txt" ]
  [ -f "$PROJECT/.worktrees/login/shared/setup-ran.txt" ]
}

@test "--run 的已實體化判別器是 .repos，不是 DK_WORKTREE" {
  mk
  dk-leader login --run >/dev/null
  rm -f "$HERDR_STUB_RESPONSES/agent_get.wB:p10.json"   # 執行領導掛了，要重交棒
  sed -i 's#^DK_WORKTREE=.*#DK_WORKTREE=""#' "$d/.task.env"
  : > "$HERDR_STUB_LOG"
  run dk-leader login --run; [ "$status" -eq 0 ]
  refute_grep '^tab create' "$HERDR_STUB_LOG"
  git -C "$PROJECT" worktree list --porcelain | grep -qx "worktree $WORKTREE_PATH"
}

# ── bklog AC11：--run 的 tab 開在人當下所在的 workspace ───────────────────────
@test "bklog AC11: HERDR_WORKSPACE_ID 與 DK_WORKSPACE 不同 → tab 開在當下的、回寫 DK_WORKSPACE 並記 process" {
  mk   # 建立時落盤 DK_WORKSPACE="wB"；人後來換到 wZ 叫 /dkbo-run
  HERDR_WORKSPACE_ID="wZ" run dk-leader login --run; [ "$status" -eq 0 ]
  grep -q -- "^tab create --workspace wZ " "$HERDR_STUB_LOG"
  refute_grep -- "--workspace wB " "$HERDR_STUB_LOG"
  grep -q '^DK_WORKSPACE="wZ"$' "$d/.task.env"
  grep -qF ' workspace wB → wZ（--run 開在當下所在的 workspace）' "$d/process.md"
  [[ "$output" == *"workspace wB → wZ"* ]]
}
@test "bklog AC11: HERDR_WORKSPACE_ID 空時退回 DK_WORKSPACE，不記 workspace 行" {
  mk
  HERDR_WORKSPACE_ID="" run dk-leader login --run; [ "$status" -eq 0 ]
  grep -q -- "^tab create --workspace wB " "$HERDR_STUB_LOG"
  grep -q '^DK_WORKSPACE="wB"$' "$d/.task.env"
  refute_grep -F ' workspace wB → ' "$d/process.md"
}
@test "bklog AC11: 兩者相同時不回寫也不記 process" {
  mk
  run dk-leader login --run; [ "$status" -eq 0 ]   # setup 的 HERDR_WORKSPACE_ID=wB
  grep -q -- "^tab create --workspace wB " "$HERDR_STUB_LOG"
  refute_grep -F '（--run 開在當下所在的 workspace）' "$d/process.md"
  refute_grep -qF '→' <<< "$output"
}
