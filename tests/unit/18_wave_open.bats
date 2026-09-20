#!/usr/bin/env bats
load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"; }
teardown() { teardown_project; }

@test "wave-open sets DK_WAVE, records base, renders one slice per member" {
  run dk-wave-open 1; [ "$status" -eq 0 ]
  grep -q '^DK_WAVE="1"$' "$d/.task.env"
  sha=$(git -C "$WORKTREE_PATH" rev-parse --short=7 HEAD)
  grep -q " wave-open 1 base $sha members backend(M) qa(S)$" "$d/process.md"
  [ -f "$d/briefs/backend.md" ]; [ -f "$d/briefs/qa.md" ]; [ ! -f "$d/briefs/frontend-cart.md" ]
  grep -q '^| 1 | 實作 | backend | POST /login | M | 測試過 | 預設 |$' "$d/briefs/backend.md"
  ! grep -q 'frontend-cart |' "$d/briefs/backend.md"
  grep -q '^| backend | src/api/\*\* | src/web/\*\* |$' "$d/briefs/backend.md"; ! grep -q '^| qa |' "$d/briefs/backend.md"
  grep -q 'POST /login 空密碼回 400' "$d/briefs/backend.md"; grep -q '^| login API | backend | frontend-cart, qa |' "$d/briefs/backend.md"; grep -q 'backend(M) qa(S)' "$d/briefs/backend.md"
  grep -q "$d/brief.md" "$d/briefs/backend.md"; grep -q '登入 API 與表單' "$d/briefs/qa.md"
}
@test "refuses a second open, an open with live panes, and a wave without members" {
  dk-wave-open 1 >/dev/null
  run dk-wave-open 2; [ "$status" -eq 1 ]; [[ "$output" == *"wave 1 is open"* ]]
  sed -i 's/^DK_WAVE=.*/DK_WAVE=""/' "$d/.task.env"
  run dk-wave-open 1; [ "$status" -eq 1 ]; [[ "$output" == *"already opened"* ]]
  echo "login-qa wC:p3 0 review 1 1" > "$d/.panes"
  run dk-wave-open 2; [ "$status" -eq 1 ]; [[ "$output" == *"live panes"* ]]
  : > "$d/.panes"; run dk-wave-open 9; [ "$status" -eq 1 ]; [[ "$output" == *"no members"* ]]
  run dk-wave-open x; [ "$status" -eq 1 ]
}
@test "只剩計畫審查 pane 時指得出路：dk-wave-close --agent" {
  echo "login-reviewer-p1 wC:p9 0 review 1 1" > "$d/.panes"
  run dk-wave-open 1
  [ "$status" -eq 1 ]; [[ "$output" == *"dk-wave-close --agent"* ]]; [[ "$output" == *"login-reviewer-p1"* ]]
}
@test "a tab-0 advisor pane (pm) does not block wave-open; a grid pane does" {
  echo "login-pm wC:p9 0 dev 0 0" > "$d/.panes"
  run dk-wave-open 1; [ "$status" -eq 0 ]
  sed -i 's/^DK_WAVE=.*/DK_WAVE=""/' "$d/.task.env"; sed -i '/ wave-open 1 /d' "$d/process.md"
  echo "login-qa wC:p3 0 review 1 1" >> "$d/.panes"
  run dk-wave-open 1; [ "$status" -eq 1 ]; [[ "$output" == *"live panes remain (1)"* ]]
}

@test "wave-open 記下這一波的開始時間" {
  run dk-wave-open 1; [ "$status" -eq 0 ]
  v=$(sed -n 's/^DK_WAVE_STARTED="\([0-9]*\)"$/\1/p' "$d/.task.env"); [[ "$v" =~ ^[0-9]+$ ]]
  [ "$v" -ge "$(( $(date +%s) - 60 ))" ]
}

# ── 多 repo（AC9）────────────────────────────────────────────────────────────
# setup 已經建好單 repo 的 fixture；多 repo 要從頭再來一次（setup_multirepo 得在
# fixture_task 之前跑，fixture_task 才會照 DK_REPOS 逐 repo 切 worktree、寫 .repos）。
multirepo_task() {
  teardown_project; setup_project; setup_multirepo
  d=$(fixture_task login 使用者登入); fixture_brief "$d"
  . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/repos.sh"
}

@test "AC9: DK_WORKTREE 為空（還沒交棒）時拒絕並指向 dk-leader --run" {
  sed -i 's/^DK_WORKTREE=.*/DK_WORKTREE=""/' "$d/.task.env"
  run dk-wave-open 1
  [ "$status" -eq 1 ]; [[ "$output" == *"dk-leader login --run"* ]]
  refute_grep '^DK_WAVE="1"$' "$d/.task.env"
  refute_grep ' wave-open 1 ' "$d/process.md"
}

@test "AC9: 每 repo 記一行 wave-open N repo <名> base <sha>，dk_wave_base 讀得到" {
  multirepo_task
  run dk-wave-open 1; [ "$status" -eq 0 ]
  for r in main api shared; do
    sha=$(git -C "$(dk_repo_field "$d" "$r" wt)" rev-parse --short=7 HEAD)
    grep -q " wave-open 1 repo $r base $sha$" "$d/process.md"
    [ "$(dk_wave_base "$d" 1 "$r")" = "$sha" ]
  done
  # 主 repo 的 sha 同時留在既有那一行（dk_wave_base 舊呼叫不變）
  msha=$(git -C "$(dk_repo_field "$d" main wt)" rev-parse --short=7 HEAD)
  grep -q " wave-open 1 base $msha members backend(M) qa(S)$" "$d/process.md"
  [ "$(dk_wave_base "$d" 1)" = "$msha" ]
}

@test "AC9: 切片有「## 倉庫」段，逐列 <名> → <worktree 路徑>" {
  multirepo_task
  run dk-wave-open 1; [ "$status" -eq 0 ]
  grep -q '^## 倉庫$' "$d/briefs/backend.md"
  for r in main api shared; do
    grep -qF "$r → $(dk_repo_field "$d" "$r" wt)" "$d/briefs/backend.md"
  done
}

@test "AC9: 單 repo 模式的切片也有「## 倉庫」段，就一列 main" {
  run dk-wave-open 1; [ "$status" -eq 0 ]
  grep -q '^## 倉庫$' "$d/briefs/backend.md"
  grep -qF "main → $WORKTREE_PATH" "$d/briefs/backend.md"
}
