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
  # 0.10.0：任務記憶在合併之前先 commit 一次（AC13），所以 report.md 落在那一筆裡而不是
  # HEAD（HEAD 是合併後撿 INDEX 與 process 尾巴的第二筆）。錨點跟著換，強度不變。
  m=$(git -C "$PROJECT" log --format='%H %s' | grep 'dkbo memory: task login' | tail -1 | cut -d' ' -f1)
  git -C "$PROJECT" show --stat "$m" | grep -q report.md    # 填完才 commit 任務記憶
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

# --- 0.10.0：記憶先 commit、兩階段合併、exit 3/4/5、不關 workspace（AC13 AC14）------

# setup() 已經用單 repo 建過一次任務（worktree 在 .worktrees/login），多 repo 的佈局是
# .worktrees/login/<名>，兩者在同一個路徑上打架 —— 先把單 repo 那份收掉再重建。
remk_multirepo() {
  git -C "$PROJECT" worktree remove --force "$WORKTREE_PATH" >/dev/null 2>&1 || true
  git -C "$PROJECT" branch -D dk/login >/dev/null 2>&1 || true
  rm -rf "$DK_ROOT/tasks/$(date +%F)-login"
  setup_multirepo
  d=$(fixture_task login 使用者登入)
  : > "$d/.panes"
}
# 三個 repo 的分支上各改一次 f.txt（內容＝repo 名），讓每個 repo 都真的有東西要合。
seed_branch_commits() {
  local n wt
  for n in main api shared; do
    wt="$PROJECT/.worktrees/login/$n"
    echo "${1:-$n}" > "$wt/f.txt"; git -C "$wt" add f.txt
    git -C "$wt" -c user.name=t -c user.email=t@t commit -q -m wave1
  done
}

@test "AC13: 任務記憶在合併之前就先 commit 一次" {
  # BACKLOG 2026-09-19「暫存中的改名擋住 merge」：任務目錄還在未追蹤狀態時 merge 會被擋。
  echo '# r' > "$d/report.md"
  run dk-task-close; [ "$status" -eq 0 ]
  m=$(git -C "$PROJECT" log --format='%H %s' | grep 'dkbo memory: task login' | tail -1 | cut -d' ' -f1)
  mg=$(git -C "$PROJECT" log --format='%H %s' | grep -m1 'task login: 使用者登入' | cut -d' ' -f1)
  [ -n "$m" ]; [ -n "$mg" ]
  git -C "$PROJECT" merge-base --is-ancestor "$m" "$mg"   # 記憶那一筆在合併那一筆之前
  git -C "$PROJECT" show --stat "$m" | grep -q report.md
}

@test "AC14: 結案不呼叫 herdr workspace close，最後一行叫人自己關" {
  echo '# r' > "$d/report.md"
  run dk-task-close; [ "$status" -eq 0 ]
  refute_grep '^workspace close' "$HERDR_STUB_LOG"
  [[ "${lines[$((${#lines[@]}-1))]}" == *"herdr workspace close wB"* ]]
}

@test "AC13: 主樹有會被覆蓋的本地變更 → exit 5，一個 repo 都沒合" {
  echo '# r' > "$d/report.md"
  echo local > "$PROJECT/f.txt"     # 分支上也有 f.txt，合併會覆蓋它
  run dk-task-close; [ "$status" -eq 5 ]
  [[ "$output" == *"本地變更"* ]]
  refute_grep 'task-close merged' "$d/process.md"
  [ -f "$DK_ROOT/.sessions/wB:p1" ]; [ -d "$WORKTREE_PATH" ]
  [ "$(cat "$PROJECT/f.txt")" = local ]
}

@test "AC13: 多 repo 任一個衝突 → exit 3、列出全部衝突 repo、誰都不合" {
  remk_multirepo
  echo '# r' > "$d/report.md"
  # 三個 repo 都在分支上改了 f.txt；api 與 shared 的主樹也各自改了同一個檔 → 衝突
  seed_branch_commits branch
  for r in "$REPO_API" "$REPO_SHARED"; do
    echo trunk > "$r/f.txt"; git -C "$r" add f.txt
    git -C "$r" -c user.name=t -c user.email=t@t commit -q -m clash
  done
  run dk-task-close; [ "$status" -eq 3 ]
  [[ "$output" == *"api"* ]]; [[ "$output" == *"shared"* ]]
  grep -q 'merge-conflict' "$d/process.md"
  [ ! -e "$PROJECT/f.txt" ]                          # 主 repo 也沒被合進去
  git -C "$PROJECT" diff --quiet                     # 預檢的 merge 都 abort 乾淨了
  git -C "$REPO_API" diff --quiet
  [ -d "$PROJECT/.worktrees/login/api" ]             # worktree 與分支一律保留
}

@test "AC13: 真合併中途失敗 → exit 4，印 merged／failed／not attempted" {
  remk_multirepo
  echo '# r' > "$d/report.md"
  seed_branch_commits branch
  # 預檢用 --no-commit，不跑 commit-msg 鉤子；真合併要建 commit 才跑。這是「預檢過、
  # 真合併炸」唯一能在測試裡穩定造出來的縫。
  printf '#!/bin/sh\nexit 1\n' > "$REPO_API/.git/hooks/commit-msg"
  chmod +x "$REPO_API/.git/hooks/commit-msg"
  run dk-task-close; [ "$status" -eq 4 ]
  [[ "$output" == *"merged"* ]]; [[ "$output" == *"main"* ]]
  [[ "$output" == *"failed"* ]]; [[ "$output" == *"api"* ]]
  [[ "$output" == *"not attempted"* ]]; [[ "$output" == *"shared"* ]]
  [ -d "$PROJECT/.worktrees/login/shared" ]          # worktree 與分支一律不刪
  git -C "$REPO_SHARED" rev-parse --verify -q dk/login
  [ -f "$DK_ROOT/.sessions/wB:p1" ]
}

@test "AC13: 多 repo 全過 → 逐 repo 合併、逐 repo 刪 worktree 與分支" {
  remk_multirepo
  echo '# r' > "$d/report.md"
  seed_branch_commits
  run dk-task-close; [ "$status" -eq 0 ]
  [ "$(cat "$PROJECT/f.txt")" = main ]
  [ "$(cat "$REPO_API/f.txt")" = api ]
  [ "$(cat "$REPO_SHARED/f.txt")" = shared ]
  for n in main api shared; do [ ! -d "$PROJECT/.worktrees/login/$n" ]; done
  refute_grep -qx 'dk/login' <(git -C "$REPO_API" branch --format='%(refname:short)')
  refute_grep -qx 'dk/login' <(git -C "$REPO_SHARED" branch --format='%(refname:short)')
  refute_grep '^workspace close' "$HERDR_STUB_LOG"
}

@test "AC13: 某個 repo 的 worktree 髒了就擋下，訊息帶 repo 前綴" {
  remk_multirepo
  echo '# r' > "$d/report.md"
  echo dirty > "$PROJECT/.worktrees/login/shared/g.txt"
  run dk-task-close; [ "$status" -eq 1 ]
  [[ "$output" == *"uncommitted"* ]]; [[ "$output" == *"shared:"* ]]
  [ -f "$DK_ROOT/.sessions/wB:p1" ]
}

@test "AC2/AC13: 計畫階段（沒有 .repos）--abandon 也收得乾淨" {
  rm -f "$d/.repos"
  sed -i 's#^DK_WORKTREE=.*#DK_WORKTREE=""#; s#^DK_BASE=.*#DK_BASE=""#' "$d/.task.env"
  run dk-task-close --abandon "計畫完不做了"; [ "$status" -eq 0 ]
  grep -q '計畫完不做了' "$d/report.md"
  grep -q '| abandoned | 計畫完不做了 |' "$DK_ROOT/tasks/INDEX.md"
  [ ! -f "$DK_ROOT/.sessions/wB:p1" ]
  grep -q '^agent rename wB:p1 --clear$' "$HERDR_STUB_LOG"
  [ -z "$(git -C "$PROJECT" status --porcelain -- "$d")" ]   # 記憶進了 git
}

@test "AC13: --abandon 逐 repo 刪 worktree 與分支" {
  remk_multirepo
  run dk-task-close --abandon "需求改了"; [ "$status" -eq 0 ]
  for n in main api shared; do [ ! -d "$PROJECT/.worktrees/login/$n" ]; done
  refute_grep -qx 'dk/login' <(git -C "$REPO_API" branch --format='%(refname:short)')
  refute_grep -qx 'dk/login' <(git -C "$REPO_SHARED" branch --format='%(refname:short)')
}

@test "AC13 反面: 沒有 .repos 又不是 --abandon → exit 1，不去合一個不存在的分支" {
  rm -f "$d/.repos"
  sed -i 's#^DK_WORKTREE=.*#DK_WORKTREE=""#; s#^DK_BASE=.*#DK_BASE=""#' "$d/.task.env"
  echo '# r' > "$d/report.md"
  run dk-task-close; [ "$status" -eq 1 ]
  [[ "$output" == *"尚未實體化"* ]]; [[ "$output" == *"--abandon"* ]]
  [ -f "$DK_ROOT/.sessions/wB:p1" ]
  refute_grep 'task-close' "$d/process.md"
}
