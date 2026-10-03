#!/usr/bin/env bats
# 員工留下的 listen 行程（lib/procs.sh）：結波收綁在 worktree 上的、開波收綁在已刪除 worktree 上的孤兒、
# 宣告的 port 被佔就 WARN。listen 清單一律來自 tests/stub/ss（SS_STUB_LISTEN），看不到開發機真的行程。
load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"
  SS_STUB_LISTEN="$PROJECT/.listen"; : > "$SS_STUB_LISTEN"; export SS_STUB_LISTEN
  pids=()
}
teardown() { local p; for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; teardown_project; }
# 起一支假的 listen 行程：ARGV0 當命令列（模仿 vite preview --outDir <路徑>），CWD 當工作目錄
fake_listener() { # PORT CWD ARGV0
  mkdir -p "$2"
  # 輸出與 fd 3 都要關掉：背景行程拿著 bats 的 fd 3，bats 會等它結束才收這條測試
  ( cd "$2" && exec -a "$3" sleep 300 ) </dev/null >/dev/null 2>&1 3>&- & local p=$!
  pids+=("$p"); echo "$1 $p" >> "$SS_STUB_LISTEN"
  for _ in 1 2 3 4 5 6 7 8 9 10; do grep -q sleep "/proc/$p/comm" 2>/dev/null && break; sleep 0.1; done
  echo "$p"
}
alive() { kill -0 "$1" 2>/dev/null; }
wave_close_ready() {
  printf 'login-qa wC:p3 0 review 1 2\n' > "$d/.panes"
  printf 'status: done\nwave: 1\ntouched:\n' > "$d/state/qa.md"
  sed -i 's/^DK_WAVE=.*/DK_WAVE="1"/' "$d/.task.env"
  echo "$(date +%Y-%m-%dT%H:%M) wave-open 1 base $(git -C "$WORKTREE_PATH" rev-parse --short=7 HEAD) members qa" >> "$d/process.md"
  echo "$(date +%Y-%m-%dT%H:%M) review 1 verdict a: ok" >> "$d/process.md"
}

@test "dk_proc_tied: cwd 在 worktree 裡、命令列寫著 worktree 或它的 scratchpad 編碼都算；同名前綴的別的 worktree 不算" {
  . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/procs.sh"
  a=$(fake_listener 5201 "$WORKTREE_PATH/sub" "sleep")
  enc=$(dk_path_enc "$WORKTREE_PATH")
  b=$(fake_listener 5202 "$PROJECT" "node vite preview --outDir /tmp/claude-1000/$enc/uuid/scratchpad/dist")
  c=$(fake_listener 5203 "$PROJECT" "node vite preview --outDir $WORKTREE_PATH/dist")
  e=$(fake_listener 5204 "$PROJECT" "node vite preview --outDir ${WORKTREE_PATH}2/dist")
  dk_proc_tied "$a" "$WORKTREE_PATH"; dk_proc_tied "$b" "$WORKTREE_PATH"; dk_proc_tied "$c" "$WORKTREE_PATH"
  run dk_proc_tied "$e" "$WORKTREE_PATH"; [ "$status" -eq 1 ]
  [ "$enc" = "$(printf '%s' "$WORKTREE_PATH" | sed 's#[/.]#-#g')" ]
}
@test "dk-wave-close 收掉綁在本任務 worktree 上的 listen 行程並記 reap；主樹的不動" {
  wave_close_ready
  enc=$(. "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/procs.sh"; dk_path_enc "$WORKTREE_PATH")
  q=$(fake_listener 5205 "$PROJECT" "node vite preview --outDir /tmp/claude-1000/$enc/uuid/scratchpad/dist --port 5205")
  l=$(fake_listener 4317 "$PROJECT" "node leader-dev-server")
  run dk-wave-close; [ "$status" -eq 0 ]
  [[ "$output" == *"收掉 worktree 裡的背景行程 pid $q（port 5205）"* ]]
  sleep 0.2; refute alive "$q"; alive "$l"
  grep -q " reap $q port 5205$" "$d/process.md"; refute_grep -q "reap $l" "$d/process.md"
}
@test "--no-worktree 的任務（worktree 就是主樹）結波不收任何行程" {
  wave_close_ready
  sed -i "s#^main .*#main $PROJECT $PROJECT -#" "$d/.repos"
  l=$(fake_listener 5206 "$PROJECT/sub" "node vite")
  run dk-wave-close --force; [ "$status" -eq 0 ]   # 夾具不是真的就地任務，gate d 會把整個主樹當成本波變更
  alive "$l"; refute_grep -q ' reap ' "$d/process.md"
}
@test "dk-wave-open 收掉綁在本專案已刪除 worktree 上的孤兒（明文路徑與 scratchpad 編碼兩種），現存 worktree 的不動" {
  enc=$(. "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/procs.sh"; dk_path_enc "$PROJECT/.worktrees/bomberart")
  o1=$(fake_listener 5174 "$PROJECT" "node vite preview --outDir /tmp/claude-1000/$enc/uuid/scratchpad/dist --port 5174")
  o2=$(fake_listener 5177 "$PROJECT" "node vite preview --outDir $PROJECT/.worktrees/kitchenart/dist")
  live=$(fake_listener 5178 "$PROJECT" "node vite preview --outDir $WORKTREE_PATH/dist")
  run dk-wave-open 1; [ "$status" -eq 0 ]
  [[ "$output" == *"收掉孤兒行程 pid $o1（port 5174，綁著已刪除的 $PROJECT/.worktrees/bomberart）"* ]]
  [[ "$output" == *"收掉孤兒行程 pid $o2（port 5177"* ]]
  sleep 0.2; refute alive "$o1"; refute alive "$o2"; alive "$live"
  grep -q " reap orphan $o1 port 5174 ($PROJECT/.worktrees/bomberart)$" "$d/process.md"
}
@test "dk-wave-open：本波成員宣告的 port 被佔就 WARN 並記 port-busy，照樣開波；沒被佔或不是本波的不吵" {
  sed -i 's#^| qa | tests/\*\* | — |$#| qa | tests/** | — | port:5207 |#; s#^| backend | src/api/\*\* | src/web/\*\* |$#| backend | src/api/** | src/web/** | port:5208, db |#' "$d/brief.md"
  sed -i 's#^| frontend-cart | src/web/\*\* | src/api/types.ts |$#| frontend-cart | src/web/** | src/api/types.ts | port:5209 |#' "$d/brief.md"
  grep -q 'port:5207' "$d/brief.md"; grep -q 'port:5209' "$d/brief.md"
  h=$(fake_listener 5207 /tmp "python3 -m http.server 5207")
  f=$(fake_listener 5209 /tmp "someone else")
  run dk-wave-open 1; [ "$status" -eq 0 ]
  [[ "$output" == *"WARN qa 的 port:5207 已被 pid $h 佔用"* ]]; [[ "$output" == *"dk-wave-open 1 --refresh"* ]]
  [[ "$output" != *"5208"* ]]; [[ "$output" != *"5209"* ]]   # 5208 沒人佔；5209 是第 2 波 frontend-cart 的
  grep -q " port-busy 5207 (qa) pid $h$" "$d/process.md"; alive "$h"; alive "$f"
}
@test "dk-task-close 刪 worktree 前收掉綁在它上面的 listen 行程" {
  q=$(fake_listener 5210 "$WORKTREE_PATH" "node vite preview")
  echo '# 使用者登入 結案' > "$d/report.md"
  run dk-task-close --abandon "測試"; [ "$status" -eq 0 ]
  sleep 0.2; refute alive "$q"
  grep -q " reap $q ($WORKTREE_PATH)$" "$d/process.md" || grep -rq " reap $q ($WORKTREE_PATH)$" "$DK_ROOT/tasks/"*/process.md
}
