load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"
  printf 'login-backend wC:p2 0 dev 1 1\nlogin-qa wC:p3 0 review 1 2\n' > "$d/.panes"
  printf 'status: done\nwave: 1\ntouched:\n  - src/api/login.ts\nreport: state/backend.report.md\n' > "$d/state/backend.md"
  printf 'status: done\nwave: 1\ntouched:\n  - tests/login.test.ts\n' > "$d/state/qa.md"
  printf '# backend 報告\n## 做了什麼\nlogin\n## 測試\n### 紅\n$ npm test -- login\nFAIL login not defined\n### 綠\n$ npm test -- login\n3 passed\n## 自我審查\n## 疑慮\n' > "$d/state/backend.report.md"
  sed -i 's/^DK_WAVE=.*/DK_WAVE="1"/' "$d/.task.env"
  echo "$(date +%Y-%m-%dT%H:%M) wave-open 1 base $(git -C "$WORKTREE_PATH" rev-parse --short=7 HEAD) members backend qa" >> "$d/process.md"
  echo "$(date +%Y-%m-%dT%H:%M) review 1 verdict a: ok" >> "$d/process.md"
  wt() { git -C "$WORKTREE_PATH" -c user.name=t -c user.email=t@t "$@"; }
}
teardown() { teardown_project; }

@test "all gates pass: panes closed, DK_WAVE cleared, tests skipped without DK_TEST_CMD" {
  run dk-wave-close; [ "$status" -eq 0 ]; [[ "$output" == *"closed 2"* ]]
  grep -q '^pane close wC:p2$' "$HERDR_STUB_LOG"; grep -q '^pane close wC:p3$' "$HERDR_STUB_LOG"
  [ ! -s "$d/.panes" ]; grep -q '^DK_WAVE=""$' "$d/.task.env"
  grep -q ' wave-close 1 tests skipped (no DK_TEST_CMD) 2 agents closed$' "$d/process.md"
}
@test "gate 0: a state not done refuses unless --force" {
  sed -i 's/^status: done/status: working/' "$d/state/qa.md"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"not done: login-qa"* ]]; refute_grep -q '^pane close' "$HERDR_STUB_LOG"
  run dk-wave-close --force; [ "$status" -eq 0 ]
}
@test "gate a: needs a review verdict or a recorded skip" {
  sed -i '/review 1 verdict/d' "$d/process.md"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"review 1 verdict"* ]]; refute_grep -q '^pane close' "$HERDR_STUB_LOG"
  echo "2026-09-10T10:00 review 1 skipped: 純文件波" >> "$d/process.md"; run dk-wave-close; [ "$status" -eq 0 ]
}
@test "gate b: every dev needs a report with content under ## 測試; review-group members do not" {
  rm "$d/state/backend.report.md"; run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"no report"*"backend.report.md"* ]]
  printf '# r\n## 測試\n（必填）\n\n## 自我審查\nok\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"的 '## 測試' 缺證據"* ]]
  printf '# r\n## 測試\n### 紅\n$ bats\nFAIL 12\n### 綠\n$ bats\n12 ok\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 0 ]
}
@test "gate c: DK_TEST_CMD runs in the worktree; failure keeps panes and shows the tail" {
  echo 'DK_TEST_CMD="cat tests/marker.txt"' >> "$DK_ROOT/settings.env"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"tests failed (cat tests/marker.txt)"* ]]; [[ "$output" == *"No such file"* ]]
  refute_grep -q '^pane close' "$HERDR_STUB_LOG"; grep -q ' wave-close 1 tests failed (cat tests/marker.txt)$' "$d/process.md"; [ -f "$d/waves/1.test.log" ]
  mkdir -p "$WORKTREE_PATH/tests"; echo ok > "$WORKTREE_PATH/tests/marker.txt"   # under qa's ownership, or gate d refuses it
  run dk-wave-close; [ "$status" -eq 0 ]; grep -q ' wave-close 1 tests ok (cat tests/marker.txt) 2 agents closed$' "$d/process.md"
}
@test "gate c: --force closes despite failing tests and says so" {
  echo 'DK_TEST_CMD="echo boom; exit 1"' >> "$DK_ROOT/settings.env"
  run dk-wave-close --force; [ "$status" -eq 0 ]; [[ "$output" == *"boom"* ]]; grep -q 'tests failed (echo boom; exit 1, forced) 2 agents closed' "$d/process.md"
}
@test "no open wave refuses" {
  sed -i 's/^DK_WAVE=.*/DK_WAVE=""/' "$d/.task.env"; run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"no wave open"* ]]
}
@test "legacy: two-column .panes or no DK_WAVE key → old behaviour with a warning" {
  printf 'login-backend wC:p2\nlogin-qa wC:p3\n' > "$d/.panes"; rm "$d/state/backend.report.md"; sed -i '/review 1 verdict/d' "$d/process.md"
  mkdir -p "$WORKTREE_PATH/src/web"; echo x > "$WORKTREE_PATH/src/web/x.ts"   # no diff gate, no commit either
  run dk-wave-close; [ "$status" -eq 0 ]; [[ "$output" == *"legacy"* ]]; grep -q 'wave-close: 2 agents closed' "$d/process.md"
  [[ "$output" != *"unowned"* ]]; [[ "$output" != *"committed"* ]]; [ "$(wt log -1 --pretty=%s)" = init ]
}
@test "long state is still reported" {
  for i in $(seq 1 25); do echo "notes: line $i" >> "$d/state/qa.md"; done
  run dk-wave-close; [ "$status" -eq 0 ]; [[ "$output" == *"state too long"* ]]
}
@test "越界閘: a real change nobody in the wave owns refuses unless --force" {
  mkdir -p "$WORKTREE_PATH/src/web"; echo x > "$WORKTREE_PATH/src/web/x.ts"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"unowned change: src/web/x.ts"* ]]
  refute_grep -q '^pane close' "$HERDR_STUB_LOG"
  run dk-wave-close --force; [ "$status" -eq 0 ]; grep -q 'violation unowned: src/web/x.ts' "$d/process.md"
}
@test "越界閘: an owned change nobody reported warns but still closes" {
  mkdir -p "$WORKTREE_PATH/src/api"; echo x > "$WORKTREE_PATH/src/api/other.ts"
  run dk-wave-close; [ "$status" -eq 0 ]
  [[ "$output" == *"unreported change: src/api/other.ts (owner backend)"* ]]
  grep -q 'unreported src/api/other.ts' "$d/process.md"
}
@test "越界閘: a touched path that never really changed is no longer a violation" {
  printf 'status: done\ntouched:\n  - src/web/x.ts\n' > "$d/state/backend.md"
  run dk-wave-close; [ "$status" -eq 0 ]; [[ "$output" != *"violation"* ]]; refute_grep -q 'violation' "$d/process.md"
}
@test "越界閘: a wave with no recorded base skips the diff gate with a warning" {
  sed -i '/ wave-open 1 base /d' "$d/process.md"
  mkdir -p "$WORKTREE_PATH/src/web"; echo x > "$WORKTREE_PATH/src/web/x.ts"
  run dk-wave-close; [ "$status" -eq 0 ]; [[ "$output" == *"no recorded base"* ]]
}
@test "越界閘: a wave member with no state file still gets the normal refusal" {
  rm "$d/state/qa.md"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"not done: login-qa"* ]]
}
@test "越界閘: an unreadable worktree refuses rather than passing the gate silently" {
  rm -rf "$WORKTREE_PATH"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"cannot read the worktree diff"* ]]
}
@test "commit: the wave is committed in the worktree once the gates pass" {
  mkdir -p "$WORKTREE_PATH/src/api"; echo x > "$WORKTREE_PATH/src/api/login.ts"
  run dk-wave-close; [ "$status" -eq 0 ]; [[ "$output" == *"committed"* ]]
  [ "$(wt log -1 --pretty=%s)" = "wave 1: backend qa" ]
  [ -z "$(wt status --porcelain)" ]
  grep -qE ' commit [0-9a-f]{7} wave 1$' "$d/process.md"
}
@test "commit: -m overrides the message" {
  mkdir -p "$WORKTREE_PATH/src/api"; echo x > "$WORKTREE_PATH/src/api/login.ts"
  run dk-wave-close -m "wave 1: 登入 API 完成"; [ "$status" -eq 0 ]
  [ "$(wt log -1 --pretty=%s)" = "wave 1: 登入 API 完成" ]
}
@test "commit: an unchanged worktree is not committed" {
  run dk-wave-close; [ "$status" -eq 0 ]; [[ "$output" == *"nothing to commit"* ]]
  [ "$(wt log -1 --pretty=%s)" = init ]
}
@test "an emptied overflow tab is closed after the wave" {
  echo 'login-reviewer-a wB:p10 0 review 2 1' >> "$d/.panes"; printf 'status: done\n' > "$d/state/reviewer-a.md"
  sed -i 's/^DK_TABS=.*/DK_TABS="2=wB:t2"/' "$d/.task.env"
  run dk-wave-close; [ "$status" -eq 0 ]; grep -q '^tab close wB:t2$' "$HERDR_STUB_LOG"; grep -q '^DK_TABS=""$' "$d/.task.env"
}
@test "--agent closes one pane, drops its row, re-balances its tab" {
  run dk-wave-close --agent login-qa; [ "$status" -eq 0 ]; [ "$output" = "closed login-qa" ]
  grep -q '^pane close wC:p3$' "$HERDR_STUB_LOG"; refute_grep -q '^login-qa ' "$d/.panes"; grep -q '^login-backend ' "$d/.panes"
  grep -q 'pane-close login-qa' "$d/process.md"; grep -q '^pane layout --pane wB:p1$' "$HERDR_STUB_LOG"
  run dk-wave-close --agent nobody; [ "$status" -eq 1 ]
}
@test "ownership matches member names exactly" {
  . "$DK_ROOT/lib/ownership.sh"
  printf '| qa-a | docs/** | — |\n' | sed -i '/^| qa | tests/r /dev/stdin' "$d/brief.md"
  dk_owned "$d/brief.md" qa tests/x.ts; refute dk_owned "$d/brief.md" qa docs/x.md; dk_owned "$d/brief.md" qa-a docs/x.md
}

@test "verdict must account for every reviewer that was spawned" {
  # e2e 實測：兩位 reviewer 派出去，領導只對 a 裁定就放行，codex 那位的意見整筆蒸發
  # 而流程看起來完全正常（RESULTS-2026-09-11 ⑧）
  echo "2026-09-11T10:00 review 1 spawned login-reviewer-a(claude) login-reviewer-b(codex)" >> "$d/process.md"
  run dk-wave-close                      # setup 已寫了 "review 1 verdict a: ok"，缺 b
  [ "$status" -eq 1 ]; [[ "$output" == *"reviewer b"* ]]; refute_grep -q '^pane close' "$HERDR_STUB_LOG"
  echo "2026-09-11T10:02 review 1 verdict a: ok b: skipped (spawn-failed)" >> "$d/process.md"
  run dk-wave-close; [ "$status" -eq 0 ]
}

@test "gate b: 缺 ### 紅 或 ### 綠 都不放行，不適用可以過" {
  # 錯誤訊息同時提到兩個小節名，所以不能拿訊息裡有沒有「### 紅」來分辨是哪一邊缺 ——
  # 斷言改成「這份 report 被擋下來了」，並用 refute_grep 確認沒有其他 gate 一起叫。
  printf '# backend 報告\n## 測試\n### 綠\n3 passed\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 1 ]
  [[ "$output" == *"state/backend.report.md 的 '## 測試' 缺"* ]]
  refute_grep 'unowned change' <<< "$output"
  printf '# backend 報告\n## 測試\n### 紅\nFAIL\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 1 ]
  [[ "$output" == *"state/backend.report.md 的 '## 測試' 缺"* ]]
  # 兩節都在、但各只有一行（沒有輸出）：這正是 AC5 要擋的
  printf '# backend 報告\n## 測試\n### 紅\n跑過了會失敗\n### 綠\n跑過了會過\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 1 ]
  [[ "$output" == *"兩行以上"* ]]
  # 指令列＋輸出：放行
  printf '# backend 報告\n## 測試\n### 紅\n$ npm test -- login\nFAIL not defined\n### 綠\n$ npm test -- login\n3 passed\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 0 ]
}
@test "gate b: 不適用 是單行豁免" {
  printf '# backend 報告\n## 測試\n### 紅\n不適用: 純文件波\n### 綠\n不適用: 純文件波\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 0 ]
}
@test "gate b: 不適用 全形冒號也算豁免" {
  # Minor 4：文案是繁體中文，員工打成全形冒號是很自然的事，錯誤訊息看不出真正原因。
  printf '# backend 報告\n## 測試\n### 紅\n不適用：純文件波\n### 綠\n不適用：純文件波\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 0 ]
}

@test "wave-close 清掉本波的 dev 聚合標記" {
  mkdir -p "$d/.blocked"; printf 'notified\ndelivered\n' > "$d/.blocked/wave-1.devdone"
  run dk-wave-close; [ "$status" -eq 0 ]
  [ ! -f "$d/.blocked/wave-1.devdone" ]
}

@test "--agent 關掉一位員工後重置聚合標記：換 kind 重派才不會啞掉" {
  # dev 撞額度 → dk-wave-close --agent 關它 → 用未熔斷的 kind 重派。
  # 標記還停在 delivered 的話，補上的那位做完也不會再有人通知領導。
  mkdir -p "$d/.blocked"; printf 'notified\ndelivered\n' > "$d/.blocked/wave-1.devdone"
  run dk-wave-close --agent login-backend; [ "$status" -eq 0 ]
  [ ! -f "$d/.blocked/wave-1.devdone" ]
}

@test "gate c: 測試指令拿到的環境裡沒有任何 DK_*" {
  # 領導整包 DK_* 傳下去，測試裡任何 source lib/common.sh 的東西都會打到真 repo：
  # 2026-09-19 實跑就這樣在源碼倉建了 7 個 worktree 與 8 個分支（BACKLOG）。
  out="$PROJECT/gatec-dk.txt"
  echo "DK_TEST_CMD=\"env | grep '^DK_' > $out; true\"" >> "$DK_ROOT/settings.env"
  run dk-wave-close; [ "$status" -eq 0 ]
  [ -f "$out" ]; [ ! -s "$out" ] || { echo "洩漏："; cat "$out"; false; }
}

@test "gate c: 非 DK_* 的環境照舊（PATH、HOME 都還在）" {
  out="$PROJECT/gatec-env.txt"
  echo "DK_TEST_CMD=\"env > $out\"" >> "$DK_ROOT/settings.env"
  run dk-wave-close; [ "$status" -eq 0 ]
  grep -q '^PATH=' "$out"; grep -q '^HOME=' "$out"
}
@test "gate c: 測試指令拿到的環境裡也沒有任何 HERDR_*（單 repo）" {
  # 繼承的 HERDR_PANE_ID 等會讓專案測試以為自己在領導的 pane 裡，打到真 herdr。
  # HERDR_ENV、HERDR_PANE_ID 由 helpers export（後者是 dk-wave-close 找任務用的，不能改值）
  export HERDR_SOCKET_PATH=/tmp/leader.sock; [ -n "$HERDR_PANE_ID" ]; [ -n "$HERDR_ENV" ]
  out="$PROJECT/gatec-herdr.txt"
  echo "DK_TEST_CMD=\"env > $out\"" >> "$DK_ROOT/settings.env"
  run dk-wave-close; [ "$status" -eq 0 ]
  refute_grep '^HERDR_' "$out"; refute_grep '^DK_' "$out"; grep -q '^PATH=' "$out"
}
@test "AC6: 關波印本波耗時並記進 process" {
  H=$(date +%H); MM=$(date +%M); T=$(date +%Y-%m-%d)
  base=$(git -C "$WORKTREE_PATH" rev-parse --short=7 HEAD)
  cat > "$d/process.md" <<P
${T}T00:00 wave-open 1 base $base members backend qa
${T}T00:19 dev-done wave 1 (2: backend qa)
${T}T00:20 review 1 spawned login-reviewer-a(claude)
${T}T00:24 review 1 verdict a: 待修
${T}T00:27 review 1 verdict a: ok
P
  run dk-wave-close; [ "$status" -eq 0 ]
  [[ "$output" =~ wave\ 1\ 耗時\ ([0-9]+)m（dev\ 19m、審查\ 7m） ]] || { echo "$output"; false; }
  m=$(( 10#${BASH_REMATCH[1]} )); exp=$(( 10#$H * 60 + 10#$MM ))
  [ "$m" -ge "$exp" ] && [ "$m" -le "$((exp+1))" ]   # 跨分鐘時容一分
  grep -q ' wave 1 耗時 .*m（dev 19m、審查 7m）$' "$d/process.md"
}
@test "AC6: 缺 dev-done 該欄印 —，純文件波審查欄印 skip" {
  T=$(date +%Y-%m-%d); base=$(git -C "$WORKTREE_PATH" rev-parse --short=7 HEAD)
  cat > "$d/process.md" <<P
${T}T00:00 wave-open 1 base $base members backend qa
${T}T00:05 review 1 skipped: 純文件波
P
  run dk-wave-close; [ "$status" -eq 0 ]
  [[ "$output" == *"（dev —、審查 skip）"* ]] || { echo "$output"; false; }
}

# ── 多 repo（AC11／AC12）─────────────────────────────────────────────────────
# setup 建的是單 repo fixture；多 repo 要從頭再來一次，並用真的 dk-wave-open 把逐 repo 的
# base 行寫進 process.md（gate c 與 gate d 都靠它分辨「本波有沒有變更」）。
multirepo_close() {
  teardown_project; setup_project; setup_multirepo
  d=$(fixture_task login 使用者登入); fixture_brief "$d"
  sed -i 's#^| backend | src/api/\*\* | src/web/\*\* |$#| backend | api:src/**, main:src/api/**, shared:src/** | main:src/web/** |#' "$d/brief.md"
  sed -i 's#^| qa | tests/\*\* | — |$#| qa | main:tests/** | — |#' "$d/brief.md"
  . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/repos.sh"
  dk-wave-open 1 >/dev/null
  printf 'login-backend wC:p2 0 dev 1 1\nlogin-qa wC:p3 0 review 1 2\n' > "$d/.panes"
  printf 'status: done\nwave: 1\ntouched:\n  - api:src/a.ts\n  - main:src/api/login.ts\n  - shared:src/s.ts\n' > "$d/state/backend.md"
  printf 'status: done\nwave: 1\ntouched:\n' > "$d/state/qa.md"
  printf '# r\n## 測試\n### 紅\n$ bats\nFAIL 1\n### 綠\n$ bats\n1 ok\n' > "$d/state/backend.report.md"
  echo "$(date +%Y-%m-%dT%H:%M) review 1 verdict a: ok" >> "$d/process.md"
  main_wt=$(dk_repo_field "$d" main wt); api_wt=$(dk_repo_field "$d" api wt); shared_wt=$(dk_repo_field "$d" shared wt)
}

@test "AC11: gate c 逐 repo 跑各自的指令，log 檔名帶 repo，缺指令記 skipped 不擋" {
  multirepo_close
  mkdir -p "$main_wt/src/api" "$api_wt/src" "$shared_wt/src"
  echo m > "$main_wt/src/api/login.ts"; echo a > "$api_wt/src/a.ts"; echo s > "$shared_wt/src/s.ts"
  echo 'DK_TEST_CMD="echo main-ran"' >> "$DK_ROOT/settings.env"   # helpers 已給 DK_TEST_CMD_api="true"
  run dk-wave-close; [ "$status" -eq 0 ]
  [ -f "$d/waves/1.main.test.log" ]; [ -f "$d/waves/1.api.test.log" ]
  [ ! -f "$d/waves/1.test.log" ]
  grep -q 'main-ran' "$d/waves/1.main.test.log"
  grep -q 'main ok (echo main-ran)' "$d/process.md"
  grep -q 'api ok (true)' "$d/process.md"
  grep -q 'shared skipped (no DK_TEST_CMD_shared)' "$d/process.md"
  [ ! -f "$d/waves/1.shared.test.log" ]
}

@test "AC11 回歸: 測試指令讀一次 stdin 不會吃掉後續 repo（Important 2）" {
  multirepo_close
  mkdir -p "$main_wt/src/api" "$api_wt/src" "$shared_wt/src"
  echo m > "$main_wt/src/api/login.ts"; echo a > "$api_wt/src/a.ts"; echo s > "$shared_wt/src/s.ts"
  echo 'DK_TEST_CMD="cat >/dev/null; echo main-ran"' >> "$DK_ROOT/settings.env"   # helpers 已給 DK_TEST_CMD_api="true"
  run dk-wave-close; [ "$status" -eq 0 ]
  grep -q 'main ok' "$d/process.md"
  grep -q 'api ok (true)' "$d/process.md"
  grep -q 'shared skipped (no DK_TEST_CMD_shared)' "$d/process.md"
}

@test "gate c: 多 repo 的測試指令也拿不到 HERDR_* 與 DK_*" {
  multirepo_close
  # HERDR_ENV、HERDR_PANE_ID 由 helpers export（後者是 dk-wave-close 找任務用的，不能改值）
  export HERDR_SOCKET_PATH=/tmp/leader.sock; [ -n "$HERDR_PANE_ID" ]; [ -n "$HERDR_ENV" ]
  mkdir -p "$main_wt/src/api"; echo m > "$main_wt/src/api/login.ts"
  out="$PROJECT/gatec-herdr-multi.txt"
  echo "DK_TEST_CMD=\"env > $out\"" >> "$DK_ROOT/settings.env"
  run dk-wave-close; [ "$status" -eq 0 ]
  grep -q 'main ok' "$d/process.md"
  refute_grep '^HERDR_' "$out"; refute_grep '^DK_' "$out"; grep -q '^PATH=' "$out"
}

@test "AC11: 本波沒變更的 repo 不跑它的測試" {
  multirepo_close
  mkdir -p "$api_wt/src"; echo a > "$api_wt/src/a.ts"
  echo 'DK_TEST_CMD="echo main-ran"' >> "$DK_ROOT/settings.env"
  run dk-wave-close; [ "$status" -eq 0 ]
  [ -f "$d/waves/1.api.test.log" ]; [ ! -f "$d/waves/1.main.test.log" ]
  grep -q 'main skipped (no change)' "$d/process.md"
}

@test "AC11: 某個 repo 的測試紅了要點名它，pane 不關" {
  multirepo_close
  mkdir -p "$api_wt/src"; echo a > "$api_wt/src/a.ts"
  echo 'DK_TEST_CMD_api="echo boom; exit 1"' >> "$DK_ROOT/settings.env"
  run dk-wave-close; [ "$status" -eq 1 ]
  [[ "$output" == *"api"* ]]; [[ "$output" == *"boom"* ]]
  refute_grep '^pane close' "$HERDR_STUB_LOG"
  grep -q 'wave-close 1 tests failed' "$d/process.md"
}

@test "AC12: gate d 的 unowned／unreported 訊息帶 <名>: 前綴" {
  multirepo_close
  mkdir -p "$shared_wt/docs"; echo x > "$shared_wt/docs/x.md"      # 沒人擁有 shared:docs/**
  run dk-wave-close; [ "$status" -eq 1 ]
  [[ "$output" == *"unowned change: shared:docs/x.md"* ]]
  refute_grep '^pane close' "$HERDR_STUB_LOG"
  rm -r "$shared_wt/docs"
  mkdir -p "$api_wt/src"; echo o > "$api_wt/src/other.ts"          # backend 擁有但沒寫進 touched
  run dk-wave-close; [ "$status" -eq 0 ]
  [[ "$output" == *"unreported change: api:src/other.ts (owner backend)"* ]]
}

@test "AC12: 每個有變更的 repo 各 commit 一次，沒變更的不 commit" {
  multirepo_close
  mkdir -p "$api_wt/src" "$shared_wt/src"
  echo a > "$api_wt/src/a.ts"; echo s > "$shared_wt/src/s.ts"
  run dk-wave-close; [ "$status" -eq 0 ]
  [ "$(git -C "$api_wt" log -1 --pretty=%s)" = "wave 1: backend qa" ]
  [ "$(git -C "$shared_wt" log -1 --pretty=%s)" = "wave 1: backend qa" ]
  [ "$(git -C "$main_wt" log -1 --pretty=%s)" = init ]
  [ -z "$(git -C "$api_wt" status --porcelain)" ]
  [[ "$output" == *"api"* ]]
  grep -qE ' commit [0-9a-f]{7} wave 1 repo api$' "$d/process.md"
  refute_grep ' repo main$' "$d/process.md"
}

@test "AC12: state 行數不計 touched 清單項——24 項＋其他 10 行不警告" {
  { printf 'status: done\nwave: 1\ncurrent: x\ntouched:\n'
    for i in $(seq 1 24); do printf '  - src/api/f%s.ts\n' "$i"; done
    for i in $(seq 1 6); do printf 'notes: line %s\n' "$i"; done; } > "$d/state/backend.md"
  [ "$(grep -vc '^  - ' "$d/state/backend.md")" -eq 10 ]   # 前提：清單以外剛好 10 行
  run dk-wave-close --force; [ "$status" -eq 0 ]
  refute_grep -q 'state too long' <<< "$output"
}
@test "AC12: touched 以外 21 行照樣警告（清單以外的 '  - ' 行照算）" {
  { printf 'status: done\nwave: 1\ntouched:\n  - src/api/login.ts\ntodo:\n'
    for i in $(seq 1 3); do printf '  - todo %s\n' "$i"; done
    for i in $(seq 1 14); do printf 'notes: line %s\n' "$i"; done; } > "$d/state/backend.md"
  [ "$(grep -vc '^  - src/' "$d/state/backend.md")" -eq 21 ]   # 前提：touched 清單以外 21 行
  run dk-wave-close --force; [ "$status" -eq 0 ]
  [[ "$output" == *"dk-wave-close: state too long: $d/state/backend.md"* ]]
}

hold_panes_lock() {
  mkdir -p "$1/.blocked"
  ( flock 9; : > "$1/.blocked/held"; sleep 2 ) 9>"$1/.blocked/panes.lock" >/dev/null 2>&1 3>&- &
  for _ in $(seq 1 50); do [ -e "$1/.blocked/held" ] && break; sleep 0.1; done
}
@test "整枝評議 Minor②：--agent 改寫 .panes 前拿 .blocked/panes.lock" {
  hold_panes_lock "$d"
  t0=$(date +%s); run dk-wave-close --agent login-qa; t1=$(date +%s)
  [ "$status" -eq 0 ]; [ "$((t1 - t0))" -ge 1 ]
  refute_grep -q '^login-qa ' "$d/.panes"; [ ! -e "$d/.panes.lock" ]
}
@test "整枝評議 Minor③：裁定行的別名要詞界比對，note:／if: 不算交代了 e／f" {
  echo "$(date +%Y-%m-%dT%H:%M) review 1 spawned login-reviewer-a(claude) login-reviewer-e(codex) login-reviewer-f(agy)" >> "$d/process.md"
  echo "$(date +%Y-%m-%dT%H:%M) review 1 verdict a: ok note: 見 report if: 無" >> "$d/process.md"
  run dk-wave-close; [ "$status" -eq 1 ]
  [[ "$output" == *"reviewer e"* ]]; [[ "$output" == *"reviewer f"* ]]
  refute_grep -q '^pane close' "$HERDR_STUB_LOG"
  echo "$(date +%Y-%m-%dT%H:%M) review 1 verdict a: ok e: ok f: skipped (limit) note: 見 report" >> "$d/process.md"
  run dk-wave-close; [ "$status" -eq 0 ]
}
