load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "task-new creates folder, env, worktree, binding, index, rename" {
  run dk-task-new login "使用者登入" --from docs/plan.md
  [ "$status" -eq 0 ]
  d="$DK_ROOT/tasks/$(date +%Y-%m-%d)-login"; [ "$output" = "$d" ]
  [ -f "$d/brief.md" ]; [ -f "$d/process.md" ]; [ -f "$d/messages.log" ]; [ -d "$d/state" ]; [ -f "$d/.panes" ]
  grep -q '^# 使用者登入$' "$d/brief.md"; grep -q 'docs/plan.md' "$d/brief.md"; grep -q 'dk/login' "$d/brief.md"
  grep -q '^DK_SHORT="login"$' "$d/.task.env"; grep -q "^DK_WORKTREE=\"$WORKTREE_PATH\"$" "$d/.task.env"
  grep -q '^DK_WORKSPACE="wB"$' "$d/.task.env"; grep -q '^DK_ROOT_PANE="wB:p1"$' "$d/.task.env"
  grep -q "^DK_BASE=\"$(git -C "$PROJECT" rev-parse HEAD)\"$" "$d/.task.env"; grep -q '^DK_WAVE=""$' "$d/.task.env"; grep -q '^DK_TABS=""$' "$d/.task.env"
  [ "$(cat "$DK_ROOT/.sessions/wB:p1")" = "$(basename "$d")" ]
  grep -q '| 使用者登入 | task | planning |' "$DK_ROOT/tasks/INDEX.md"
  ! grep -q '^worktree create' "$HERDR_STUB_LOG"
  git -C "$PROJECT" worktree list --porcelain | grep -qx "worktree $WORKTREE_PATH"
  [ "$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref HEAD)" = dk/login ]
  grep -q '^agent rename wB:p1 leader-login$' "$HERDR_STUB_LOG"
  grep -q 'task-new login' "$d/process.md"
}
@test "task-new rejects bad short names and duplicates" {
  run dk-task-new Login x; [ "$status" -eq 1 ]
  run dk-task-new averyveryverylongname x; [ "$status" -eq 1 ]
  run dk-task-new login 'bad "quote'; [ "$status" -eq 1 ]
  run dk-task-new login 'abc\'; [ "$status" -eq 1 ]
  run dk-task-new login "with space & hash #1"; [ "$status" -eq 0 ]; grep -q '^DK_DISPLAY="with space & hash #1"$' "$output/.task.env"
  run dk-task-new login x; [ "$status" -eq 1 ]
}
@test "task-new tolerates agent rename failure" {
  HERDR_STUB_FAIL="agent rename" run dk-task-new login x
  [ "$status" -eq 0 ]
  grep -q '| x | task | planning |' "$DK_ROOT/tasks/INDEX.md"
  grep -q 'rename failed' "$DK_ROOT/tasks/$(date +%F)-login/process.md"
}
@test "task-new renames a pane whose agent carries some other name" {
  # e2e 實測：領導 pane 只要曾被命名過，rename 就被跳過，而 dk_leader_name 固定回
  # leader-<short> —— 員工的 dk-msg leader 與 dk-watch 推送全部靜默送不到（RESULTS-2026-09-11 ④）
  echo '{"result":{"agent":{"name":"dke2e"}}}' > "$HERDR_STUB_RESPONSES/agent_get.json"
  run dk-task-new login x; [ "$status" -eq 0 ]
  grep -q '^agent rename wB:p1 leader-login$' "$HERDR_STUB_LOG"
}
@test "task-new skips rename when already named leader-<short>" {
  echo '{"result":{"agent":{"name":"leader-login","agent_status":"idle","pane_id":"wB:p1"}}}' > "$HERDR_STUB_RESPONSES/agent_get.json"
  dk-task-new login x >/dev/null
  ! grep -q '^agent rename' "$HERDR_STUB_LOG"
}
@test "dk-process appends to the bound task" {
  dk-task-new login x >/dev/null; dk-process "decision: 用現有 users 表"
  grep -Eq '^[0-9T:-]+ decision: 用現有 users 表$' "$DK_ROOT/tasks/$(date +%Y-%m-%d)-login/process.md"
}
@test "task-new --gate1 flips index to running" {
  dk-task-new login "使用者登入" >/dev/null
  dk-process "brief-review skipped: 單元測試"
  dk-task-new login --gate1
  grep -q '| 使用者登入 | task | running |' "$DK_ROOT/tasks/INDEX.md"
  grep -q 'gate1 approved' "$DK_ROOT/tasks/$(date +%Y-%m-%d)-login/process.md"
}
@test "task-new --gate1 on unknown short dies cleanly" {
  run dk-task-new nosuch --gate1; [ "$status" -eq 1 ]; [[ "$output" == *"no task nosuch"* ]]
}
@test "hyphenated short names do not collide" {
  dk-task-new brand-new x >/dev/null
  run dk-task-new new y; [ "$status" -eq 0 ]
  dk-process "brief-review skipped: 單元測試"
  run dk-task-new new --gate1; [ "$status" -eq 0 ]
  grep -q 'gate1 approved' "$DK_ROOT/tasks/$(date +%F)-new/process.md"
  ! grep -q 'gate1 approved' "$DK_ROOT/tasks/$(date +%F)-brand-new/process.md"
}
@test "task-new honours DK_WORKTREE_DIR and refuses an existing branch without creating the folder" {
  DK_WORKTREE_DIR="$PROJECT/wt" run dk-task-new login x; [ "$status" -eq 0 ]; grep -q "^DK_WORKTREE=\"$PROJECT/wt/login\"$" "$output/.task.env"
  git -C "$PROJECT" branch dk/pay
  run dk-task-new pay y; [ "$status" -eq 1 ]; [[ "$output" == *"worktree add failed"* ]]; [ ! -d "$DK_ROOT/tasks/$(date +%F)-pay" ]
}
@test "task-new --no-worktree still records DK_BASE" {
  run dk-task-new login x --no-worktree; [ "$status" -eq 0 ]; grep -q "^DK_WORKTREE=\"$PROJECT\"$" "$output/.task.env"; grep -Eq '^DK_BASE="[0-9a-f]{40}"$' "$output/.task.env"
}
@test "task-new removes its worktree and branch when a later step fails" {
  rm "$DK_ROOT/templates/process.md"
  run dk-task-new login x; [ "$status" -ne 0 ]
  [ ! -d "$WORKTREE_PATH" ]
  ! git -C "$PROJECT" worktree list --porcelain | grep -qx "worktree $WORKTREE_PATH"
  ! git -C "$PROJECT" rev-parse --verify -q dk/login
  [ ! -d "$DK_ROOT/tasks/$(date +%F)-login" ]; [ ! -f "$DK_ROOT/.sessions/wB:p1" ]
  cp "$REPO_ROOT/.dkbo/templates/process.md" "$DK_ROOT/templates/process.md"
  run dk-task-new login x; [ "$status" -eq 0 ]   # same short name works again afterwards
}

@test "task-new records a rename that reported success but never took effect" {
  # panova2/sportswitch：領導 pane 是人手開的 claude，21:29 的 rename 回了 rc=0 卻沒生效，
  # process.md 因此一片乾淨 —— 而整場 12 筆訊息全部投不到 leader-sportswitch。
  # 只看 exit code 的守衛看不見這種靜默失敗，要把名字讀回來比對。
  HERDR_STUB_RENAME_NOOP=1 run dk-task-new login x
  [ "$status" -eq 0 ]
  grep -q 'rename 沒生效' "$DK_ROOT/tasks/$(date +%F)-login/process.md"
}
@test "task-new stays quiet when the rename did take" {
  run dk-task-new login x
  [ "$status" -eq 0 ]
  ! grep -q 'rename' "$DK_ROOT/tasks/$(date +%F)-login/process.md"
}

@test "task-new 產出 request.md 空殼" {
  d=$(dk-task-new login "使用者登入")
  [ -s "$d/request.md" ]
  grep -q '使用者登入' "$d/request.md"
  grep -q '逐字' "$d/request.md"
}
@test "--from 指向檔案時把需求原文逐字複製進 request.md" {
  printf '第一行需求\n第二行需求\n' > "$PROJECT/req.txt"
  d=$(dk-task-new login "使用者登入" --from "$PROJECT/req.txt")
  [ "$(cat "$d/request.md")" = "$(cat "$PROJECT/req.txt")" ]
  grep -q '來源：.*req.txt' "$d/brief.md"
}
@test "--from 指向不存在的檔時退回空殼，來源欄照舊" {
  d=$(dk-task-new login "使用者登入" --from "人在會議上口述")
  [ -s "$d/request.md" ]
  grep -q '來源：人在會議上口述' "$d/brief.md"
}
@test "brief 標頭指得到 request.md" {
  d=$(dk-task-new login "使用者登入")
  grep -q 'request.md' "$d/brief.md"
}

@test "gate1 拒絕沒有計畫審查裁定的任務" {
  dk-task-new login "使用者登入" >/dev/null
  run dk-task-new login --gate1
  [ "$status" -eq 1 ]; [[ "$output" == *"brief-review"* ]]
  refute_grep 'gate1 approved' "$DK_ROOT/tasks/$(date +%F)-login/process.md"
  refute_grep '| 使用者登入 | task | running |' "$DK_ROOT/tasks/INDEX.md"
}
@test "gate1 接受 skipped，也接受 verdict" {
  dk-task-new login "使用者登入" >/dev/null
  dk-process "brief-review skipped: 純文件任務"
  run dk-task-new login --gate1; [ "$status" -eq 0 ]
  grep -q 'gate1 approved' "$DK_ROOT/tasks/$(date +%F)-login/process.md"
}
@test "gate1 要求裁定交代每一位真的派出去的 reviewer" {
  d=$(dk-task-new login "使用者登入")
  dk-process "brief-review spawned login-reviewer-p1(claude) login-reviewer-p2(codex)"
  dk-process "brief-review verdict p1: ok"
  run dk-task-new login --gate1
  [ "$status" -eq 1 ]; [[ "$output" == *"p2"* ]]
  dk-process "brief-review verdict p1: ok / p2: skipped (逾時)"
  run dk-task-new login --gate1; [ "$status" -eq 0 ]
}
@test "gate1 看最後一行決定：verdict 之後補的 skipped 蓋過陳舊 verdict" {
  dk-task-new login "使用者登入" >/dev/null
  dk-process "brief-review spawned login-reviewer-p1(claude) login-reviewer-p2(codex)"
  dk-process "brief-review verdict p1: ok"
  run dk-task-new login --gate1; [ "$status" -eq 1 ]
  dk-process "brief-review skipped: 兩個 kind 都熔斷"
  run dk-task-new login --gate1; [ "$status" -eq 0 ]
  grep -q 'gate1 approved' "$DK_ROOT/tasks/$(date +%F)-login/process.md"
}
@test "gate1 不被 skipped 理由裡剛好提到 verdict 這幾個字誤判成裁定" {
  dk-task-new login "使用者登入" >/dev/null
  dk-process "brief-review spawned login-reviewer-p1(claude) login-reviewer-p2(codex)"
  dk-process "brief-review verdict p1: ok"
  dk-process "brief-review skipped: 忘記寫 brief-review verdict，直接跳過"
  run dk-task-new login --gate1; [ "$status" -eq 0 ]
  grep -q 'gate1 approved' "$DK_ROOT/tasks/$(date +%F)-login/process.md"
}
@test "gate1 看最後一行決定：skipped 之後補的 verdict 讓逐別名檢查重新生效" {
  dk-task-new login "使用者登入" >/dev/null
  dk-process "brief-review spawned login-reviewer-p1(claude) login-reviewer-p2(codex)"
  dk-process "brief-review skipped: 先跳過"
  dk-process "brief-review verdict p1: ok"
  run dk-task-new login --gate1
  [ "$status" -eq 1 ]; [[ "$output" == *"p2"* ]]
}
@test "gate1 拒絕還開著的計畫審查 pane" {
  d=$(dk-task-new login "使用者登入")
  dk-process "brief-review skipped: 測試"
  echo "login-reviewer-p1 wC:p9 $(date +%s) review 1 2" >> "$d/.panes"
  run dk-task-new login --gate1
  [ "$status" -eq 1 ]; [[ "$output" == *"login-reviewer-p1"* ]]; [[ "$output" == *"dk-wave-close --agent"* ]]
  : > "$d/.panes"
  run dk-task-new login --gate1; [ "$status" -eq 0 ]
}
