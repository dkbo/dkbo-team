load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); }
teardown() { teardown_project; }

@test "spawn splits with env, starts agent with tier flags, sends first prompt" {
  run dk-spawn frontend cart --tier L
  [ "$status" -eq 0 ]
  split=$(grep '^pane split' "$HERDR_STUB_LOG")
  [[ "$split" == *"--pane wB:p1 --direction right --ratio 0.500 --cwd $WORKTREE_PATH --no-focus"* ]]
  [[ "$split" == *"--env DK_TASK_DIR=$d"* ]]; [[ "$split" == *"--env DK_ROLE=frontend"* ]]
  [[ "$split" == *"--env DK_AGENT=login-frontend-cart"* ]]; [[ "$split" == *"--env DK_LEADER=leader-login"* ]]
  [[ "$split" == *"--env DK_ISOLATED=0"* ]]
  grep -q '^agent start login-frontend-cart --kind claude --pane wC:p2 -- --model opus --effort high --permission-mode auto --add-dir '"$PROJECT"' --name login-frontend-cart$' "$HERDR_STUB_LOG"
  p=$(grep '^agent prompt login-frontend-cart' "$HERDR_STUB_LOG")
  [[ "$p" == *"$DK_ROOT/roles/frontend.md"* ]]; [[ "$p" == *"$d/brief.md"* ]]; [[ "$p" == *"$d/state/frontend-cart.report.md"* ]]
  [[ "$p" == *"$d/state/frontend-cart.md"* ]]; [[ "$p" == *"禁止使用 subagent"* ]]; [[ "$p" == *"--wait --until working --timeout 15000" ]]
  grep -Eq '^login-frontend-cart wC:p2 [0-9]{10} dev 1 1$' "$d/.panes"
  grep -q 'spawn login-frontend-cart (claude L)' "$d/process.md"
}
@test "spawn defaults tier M, honours --kind and --isolated and --resume" {
  run dk-spawn qa --kind codex --isolated --resume
  [ "$status" -eq 0 ]
  grep -q -- '--kind codex --pane wC:p2 -- -m gpt-5.5 -c model_reasoning_effort=medium' "$HERDR_STUB_LOG"
  grep -q -- '--env DK_ISOLATED=1' "$HERDR_STUB_LOG"
  grep -q '從 state 檔續作' "$HERDR_STUB_LOG"
  grep -q 'spawn login-qa (codex M) override-kind isolated resume' "$d/process.md"
}
@test "spawn warns on missing mcp but continues" {
  sed -i 's/^mcp: \[\]/mcp: [playwright]/' "$DK_ROOT/roles/qa.md"
  run dk-spawn qa
  [ "$status" -eq 0 ]; [[ "$output" == *"mcp missing"* ]]; grep -q 'mcp-missing login-qa: playwright' "$d/process.md"
}
@test "spawn fails on unknown role or tier without S" {
  run dk-spawn designer; [ "$status" -eq 1 ]
  run dk-spawn reviewer --tier S; [ "$status" -eq 1 ]
}
@test "worktree:false role splits beside the leader in the main tree" {
  run dk-spawn pm; [ "$status" -eq 0 ]
  grep -q -- "^pane split --pane wB:p1 --direction right --cwd $PROJECT --no-focus" "$HERDR_STUB_LOG"
  grep -Eq '^login-pm wC:p2 [0-9]+ dev 0 0$' "$d/.panes"
}
@test "spawn records prompt failure but keeps the pane entry" {
  HERDR_STUB_FAIL="agent prompt" run dk-spawn qa
  [ "$status" -eq 1 ]; [[ "$output" == *"first prompt"* ]]
  grep -q '^login-qa wC:p2 ' "$d/.panes"; grep -q 'spawn login-qa (claude M) prompt-failed' "$d/process.md"
}
@test "spawn validates agent name before touching herdr" {
  run dk-spawn frontend 'Big Cart!'
  [ "$status" -eq 1 ]
  refute_grep -q '^pane split' "$HERDR_STUB_LOG"
}
@test "spawn keeps the pane when agent start fails, so the startup prompt survives" {
  # e2e 實測：codex 卡在「Update available!」升級提示而 agent start 失敗，
  # 舊行為把 pane 關掉連證據一起銷毀，現場查不出原因（RESULTS-2026-09-11 ⑧）
  HERDR_STUB_FAIL="agent start" run dk-spawn qa
  [ "$status" -eq 1 ]
  refute_grep -q '^pane close wC:p2$' "$HERDR_STUB_LOG"
  [[ "$output" == *"wC:p2"* ]] && [[ "$output" == *"pane read"* ]]
  grep -q 'spawn login-qa failed: pane wC:p2 kept' "$d/process.md"
  refute_grep -q '^login-qa ' "$d/.panes"
}
@test "spawn --resume closes and dedupes the old pane entry" {
  echo "login-qa wC:p9" >> "$d/.panes"
  run dk-spawn qa --resume
  [ "$status" -eq 0 ]
  grep -q '^pane close wC:p9$' "$HERDR_STUB_LOG"
  [ "$(grep -c '^login-qa ' "$d/.panes")" -eq 1 ]
  grep -q '^login-qa wC:p2 ' "$d/.panes"
}
@test "first prompt points at the member slice when it exists" {
  mkdir -p "$d/briefs"; echo '# slice' > "$d/briefs/qa.md"
  dk-spawn qa >/dev/null
  p=$(grep '^agent prompt login-qa' "$HERDR_STUB_LOG"); [[ "$p" == *"$d/briefs/qa.md"* ]]; [[ "$p" != *"$d/brief.md"* ]]; [[ "$p" == *"report-employee.md"* ]]
}
@test "second employee hangs below the first; review group recorded" {
  echo "login-backend wC:p2 0 dev 1 1" > "$d/.panes"
  echo '{"result":{"pane":{"pane_id":"wC:p3"}}}' > "$HERDR_STUB_RESPONSES/pane_split.json"
  dk-spawn qa >/dev/null
  grep -q -- '--pane wC:p2 --direction down --ratio 0.500' "$HERDR_STUB_LOG"
  grep -Eq '^login-qa wC:p3 [0-9]+ review 1 2$' "$d/.panes"
}
@test "--split overrides only the direction" {
  echo "login-backend wC:p2 0 dev 1 1" > "$d/.panes"
  dk-spawn qa --split right >/dev/null
  grep -q -- '--pane wC:p2 --direction right --ratio 0.500' "$HERDR_STUB_LOG"; grep -Eq '^login-qa wC:p2 [0-9]+ review 1 2$' "$d/.panes"
}
@test "fifth employee opens tab 2 as its root pane and records DK_TABS" {
  printf 'a wC:p2 0 dev 1 1\nb wC:p3 0 dev 1 2\nc wC:p4 0 dev 1 3\nd wC:p5 0 dev 1 4\n' > "$d/.panes"
  run dk-spawn qa; [ "$status" -eq 0 ]; [ "$output" = "login-qa wB:p10" ]
  tc=$(grep '^tab create' "$HERDR_STUB_LOG")
  [[ "$tc" == "tab create --workspace wB --cwd $WORKTREE_PATH --label login-2 --no-focus --env DK_ROOT=$DK_ROOT --env DK_TASK_DIR=$d --env DK_ROLE=qa --env DK_AGENT=login-qa"* ]]
  refute_grep -q '^pane split' "$HERDR_STUB_LOG"
  grep -q '^agent start login-qa --kind claude --pane wB:p10 ' "$HERDR_STUB_LOG"
  grep -Eq '^login-qa wB:p10 [0-9]+ review 2 1$' "$d/.panes"
  grep -q '^DK_TABS="2=wB:t2"$' "$d/.task.env"; grep -q 'tab 2 wB:t2 opened' "$d/process.md"
}
@test "tab create failure dies before starting an agent" {
  printf 'a wC:p2 0 dev 1 1\nb wC:p3 0 dev 1 2\nc wC:p4 0 dev 1 3\nd wC:p5 0 dev 1 4\n' > "$d/.panes"
  HERDR_STUB_FAIL="tab create" run dk-spawn qa; [ "$status" -eq 1 ]; refute_grep -q '^agent start' "$HERDR_STUB_LOG"; [ "$(wc -l < "$d/.panes")" -eq 4 ]
}
@test "agent start failure on a new tab keeps the tab so the startup prompt survives" {
  printf 'a wC:p2 0 dev 1 1\nb wC:p3 0 dev 1 2\nc wC:p4 0 dev 1 3\nd wC:p5 0 dev 1 4\n' > "$d/.panes"
  HERDR_STUB_FAIL="agent start" run dk-spawn qa; [ "$status" -eq 1 ]
  refute_grep -q '^tab close wB:t2$' "$HERDR_STUB_LOG"; refute_grep -q '^pane close' "$HERDR_STUB_LOG"
  grep -q '^DK_TABS="2=wB:t2"$' "$d/.task.env"; [ "$(wc -l < "$d/.panes")" -eq 4 ]
  grep -q 'spawn login-qa failed: pane .* kept for diagnosis' "$d/process.md"
}
@test "--resume of an overflow tab's only occupant closes the stale tab and keeps one DK_TABS entry" {
  printf 'a wC:p2 0 dev 1 1\nb wC:p3 0 dev 1 2\nc wC:p4 0 dev 1 3\nd wC:p5 0 dev 1 4\nlogin-qa wB:p10 0 review 2 1\n' > "$d/.panes"
  sed -i 's/^DK_TABS=.*/DK_TABS="2=wB:t9"/' "$d/.task.env"
  run dk-spawn qa --resume; [ "$status" -eq 0 ]
  grep -q '^pane close wB:p10$' "$HERDR_STUB_LOG"; grep -q '^tab close wB:t9$' "$HERDR_STUB_LOG"; grep -q '^tab create ' "$HERDR_STUB_LOG"
  grep -q '^DK_TABS="2=wB:t2"$' "$d/.task.env"; [ "$(grep -c '^2=' <<< "$(sed -n 's/^DK_TABS="\(.*\)"$/\1/p' "$d/.task.env" | tr ' ' '\n')")" -eq 1 ]
  grep -q 'tab 2 wB:t9 closed (recreated)' "$d/process.md"; grep -Eq '^login-qa wB:p10 [0-9]+ review 2 1$' "$d/.panes"
}
@test "首輪提示帶 TDD 順序與除錯方法檔" {
  fixture_brief "$d"; dk-wave-open 1 >/dev/null
  run dk-spawn backend; [ "$status" -eq 0 ]
  grep -q '先寫一條會失敗的測試' "$HERDR_STUB_LOG"
  grep -q 'methods/debugging.md' "$HERDR_STUB_LOG"
}
@test "--handoff 落 ruling、隱含 resume、用接手版提示" {
  fixture_brief "$d"; dk-wave-open 1 >/dev/null
  dk-spawn backend >/dev/null
  run dk-spawn backend --handoff "claude 修一次沒好，換 codex" --kind codex
  [ "$status" -eq 0 ]
  grep -qE '^[^ ]+ ruling: 換 codex/M 接手 login-backend 的修復 — claude 修一次沒好，換 codex — ' "$d/process.md"
  grep -q '上一位修過一次沒成功' "$HERDR_STUB_LOG"
  grep -q 'methods/debugging.md' "$HERDR_STUB_LOG"
}
@test "--handoff 不帶原因就死" {
  fixture_brief "$d"; dk-wave-open 1 >/dev/null
  run dk-spawn backend --handoff; [ "$status" -ne 0 ]; [[ "$output" == *"--handoff"* ]]
}
@test "TDD 那一句只發給 group: dev，reviewer 與 qa 不收到" {
  # Minor 6：reviewer 依角色定義不寫任何碼，報告格式另由切片規定成規格合規／Important／
  # Minor，收到「兩次的指令與輸出貼進報告的紅綠」跟自己的切片矛盾。
  fixture_brief "$d"; dk-wave-open 1 >/dev/null
  run dk-spawn backend; [ "$status" -eq 0 ]
  grep -q '先寫一條會失敗的測試' "$HERDR_STUB_LOG"
  : > "$HERDR_STUB_LOG"
  run dk-spawn qa; [ "$status" -eq 0 ]
  refute_grep '先寫一條會失敗的測試' "$HERDR_STUB_LOG"
}
@test "--handoff 的 ruling 只在 pane 與 agent 真的起來後才落盤" {
  # Minor 7：ruling 原本在 pane split／agent start 之前就落盤，agent start 失敗時
  # process.md 會留下一行「換人」的假裁定，而那次換手其實沒發生。
  fixture_brief "$d"; dk-wave-open 1 >/dev/null
  dk-spawn backend >/dev/null
  HERDR_STUB_FAIL="agent start" run dk-spawn backend --handoff "claude 修一次沒好，換 codex" --kind codex
  [ "$status" -eq 1 ]
  refute_grep 'ruling: 換 codex' "$d/process.md"
}

# ── 多 repo（AC8）────────────────────────────────────────────────────────────
multirepo_task() {   # setup 建的是單 repo fixture；多 repo 要從頭再來一次
  teardown_project; setup_project; setup_multirepo
  d=$(fixture_task login 使用者登入); fixture_brief "$d"
  sed -i 's#^| backend | src/api/\*\* | src/web/\*\* |$#| backend | api:src/**, shared:src/** | main:src/web/** |#' "$d/brief.md"
  sed -i 's#^| qa | tests/\*\* | — |$#| qa | main:tests/** | — |#' "$d/brief.md"
  . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/repos.sh"
}

@test "AC8: cwd 是成員第一個可改 glob 的 repo worktree，--add-dir 主樹加每個 worktree" {
  multirepo_task
  run dk-spawn backend; [ "$status" -eq 0 ]
  api_wt=$(dk_repo_field "$d" api wt)
  grep -q -- "--cwd $api_wt --no-focus" "$HERDR_STUB_LOG"
  start=$(grep '^agent start login-backend' "$HERDR_STUB_LOG")
  [[ "$start" == *"--add-dir $PROJECT "* ]] || [[ "$start" == *"--add-dir $PROJECT" ]]
  for r in main api shared; do
    [[ "$start" == *"--add-dir $(dk_repo_field "$d" "$r" wt)"* ]]
  done
  # qa 的第一個 glob 在 main
  : > "$HERDR_STUB_LOG"
  run dk-spawn qa; [ "$status" -eq 0 ]
  grep -q -- "--cwd $(dk_repo_field "$d" main wt) --no-focus" "$HERDR_STUB_LOG"
}

@test "AC8: 首輪提示點名自己的 repo；單 repo 模式不印這一句" {
  multirepo_task
  run dk-spawn backend; [ "$status" -eq 0 ]
  p=$(grep '^agent prompt login-backend' "$HERDR_STUB_LOG")
  [[ "$p" == *"你的 pane 在「api」的 worktree"* ]]
  [[ "$p" == *"$(dk_repo_field "$d" api wt)"* ]]
  [[ "$p" == *"「## 倉庫」"* ]]
  [[ "$p" == *"以「api:」"* ]]
  teardown_project; setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"
  run dk-spawn backend; [ "$status" -eq 0 ]
  refute_grep '你的 pane 在' "$HERDR_STUB_LOG"
}

@test "AC8: 單 repo 模式的 --add-dir 只有主樹（0.9.2 不變）" {
  run dk-spawn backend; [ "$status" -eq 0 ]
  start=$(grep '^agent start login-backend' "$HERDR_STUB_LOG")
  [[ "$start" == *"--add-dir $PROJECT --name login-backend" ]]   # 就這一個，後面只剩 session 名
  [ "$(grep -o -- '--add-dir' <<< "$start" | wc -l)" -eq 1 ]
}

@test "AC8: DK_WORKTREE 為空（計畫階段的 reviewer）時 cwd 退回主樹" {
  # 計畫階段的任務只有資料夾：沒有 worktree，也還沒有 .repos
  sed -i 's/^DK_WORKTREE=.*/DK_WORKTREE=""/' "$d/.task.env"; rm -f "$d/.repos"
  run dk-spawn reviewer p1 --isolated; [ "$status" -eq 0 ]
  grep -q -- "--cwd $PROJECT --no-focus" "$HERDR_STUB_LOG"
  grep -q -- '--add-dir '"$PROJECT"' --name login-reviewer-p1$' "$HERDR_STUB_LOG"
}

@test "AC8: 所有權表沒有這位成員時 cwd 退回 DK_WORKTREE（主 repo）" {
  multirepo_task
  run dk-spawn reviewer a --isolated; [ "$status" -eq 0 ]
  grep -q -- "--cwd $(dk_repo_field "$d" main wt) --no-focus" "$HERDR_STUB_LOG"
}

# --- AC3: 派人前查專案層熔斷 -------------------------------------------------
down_claude() { # 讓 claude 在專案層熔斷到未來（epoch 現在+3600）
  mkdir -p "$DK_ROOT/.sessions"
  printf 'claude %s exact 2026-09-10T10:00 other-task some-agent 撞額度樣本\n' "$(( $(date +%s) + 3600 ))" \
    > "$DK_ROOT/.sessions/kinds-down"
}

@test "AC3: --kind 明寫且該 kind 專案層未恢復 → 拒絕" {
  down_claude
  run dk-spawn frontend cart --kind claude; [ "$status" -eq 1 ]
  [[ "$output" == *"kind claude 在專案層熔斷到"* ]]; [[ "$output" == *"dk-kind up claude"* ]]
  refute_grep '^pane split' "$HERDR_STUB_LOG"
}
@test "AC3: 沒給 --kind、角色預設命中專案層熔斷 → 只警告，照派" {
  down_claude
  run dk-spawn frontend cart; [ "$status" -eq 0 ]
  [[ "$output" == *"kind claude 在專案層熔斷到"* ]]; [[ "$output" == *"dk-kind up claude"* ]]
  grep -q '^pane split' "$HERDR_STUB_LOG"
  grep -q '^agent start login-frontend-cart --kind claude ' "$HERDR_STUB_LOG"
}

# --- AC16（整枝評議 I2 spawn 半邊）：dev 進 .panes 的同一步刪 wave-N.devdone -------
@test "AC16 I2: 波開著時 spawn 一位 group=dev 成員 → wave-N.devdone 被刪" {
  fixture_brief "$d"; dk-wave-open 1 >/dev/null
  mkdir -p "$d/.blocked"; printf 'notified\ndelivered\n' > "$d/.blocked/wave-1.devdone"
  run dk-spawn backend; [ "$status" -eq 0 ]
  [ ! -f "$d/.blocked/wave-1.devdone" ]
}
@test "AC16 I2: 波開著時 spawn qa 或 reviewer（group=review）→ wave-N.devdone 不刪" {
  fixture_brief "$d"; dk-wave-open 1 >/dev/null
  mkdir -p "$d/.blocked"; printf 'notified\ndelivered\n' > "$d/.blocked/wave-1.devdone"
  run dk-spawn qa; [ "$status" -eq 0 ]
  [ -f "$d/.blocked/wave-1.devdone" ]
  run dk-spawn reviewer a --isolated; [ "$status" -eq 0 ]
  [ -f "$d/.blocked/wave-1.devdone" ]
}
@test "AC17 I1: 已交付的 dev --handoff 重派不刪 wave-N.devdone（有 latch）" {
  fixture_brief "$d"; dk-wave-open 1 >/dev/null
  dk-spawn backend >/dev/null
  mkdir -p "$d/.blocked"
  : > "$d/.blocked/wave-1.backend.done"   # 已交付的 latch
  printf 'notified\ndelivered\n' > "$d/.blocked/wave-1.devdone"
  run dk-spawn backend --handoff "claude 修一次沒好，換 codex" --kind codex
  [ "$status" -eq 0 ]
  [ -f "$d/.blocked/wave-1.devdone" ]
}
@test "AC17 I1: 沒有 latch 的 dev 重派仍照刪 wave-N.devdone（新成員／已被 --agent 關過）" {
  fixture_brief "$d"; dk-wave-open 1 >/dev/null
  mkdir -p "$d/.blocked"
  printf 'notified\ndelivered\n' > "$d/.blocked/wave-1.devdone"
  run dk-spawn backend --handoff "claude 修一次沒好，換 codex" --kind codex
  [ "$status" -eq 0 ]
  [ ! -f "$d/.blocked/wave-1.devdone" ]
}

@test "員工的 CLI session 名＝agent 名，pane 上看得出是哪位角色；codex 沒有對應旗標就不帶" {
  run dk-spawn qa; [ "$status" -eq 0 ]
  grep -q '^agent start login-qa --kind claude .* --name login-qa$' "$HERDR_STUB_LOG"
  run dk-spawn backend --kind codex; [ "$status" -eq 0 ]
  start=$(grep '^agent start login-backend' "$HERDR_STUB_LOG")
  [[ "$start" != *"--name"* ]]
}

# 另一個行程拿著 .blocked/panes.lock（預設兩秒）；dk-spawn 若也拿同一把鎖就得等它放掉
hold_panes_lock() {
  mkdir -p "$1/.blocked"
  ( flock 9; : > "$1/.blocked/held"; sleep "${2:-2}" ) 9>"$1/.blocked/panes.lock" >/dev/null 2>&1 3>&- &
  for _ in $(seq 1 50); do [ -e "$1/.blocked/held" ] && break; sleep 0.1; done
}
@test "整枝評議 Minor②：spawn 的 append 與 --resume 刪舊列都拿 .blocked/panes.lock" {
  hold_panes_lock "$d"
  t0=$(date +%s); run dk-spawn backend; t1=$(date +%s)
  [ "$status" -eq 0 ]; [ "$((t1 - t0))" -ge 1 ]
  grep -q '^login-backend ' "$d/.panes"; [ ! -e "$d/.panes.lock" ]
  # --resume 光量耗時分不出來：最後的 append 本身就會等鎖。改看持鎖期間舊列還在不在 ——
  # 刪舊列若沒拿鎖，pane close 之後就立刻被 grep -v 掉了（reviewer 波 2 Minor 1）
  sed -i 's/^login-backend [^ ]* /login-backend wC:p9 /' "$d/.panes"; old=wC:p9   # stub 會再發 wC:p2，舊列要分得出來
  rm "$d/.blocked/held"; hold_panes_lock "$d" 3
  dk-spawn backend --resume >/dev/null 2>&1 3>&- & pid=$!
  sleep 1
  grep -q "^login-backend $old " "$d/.panes"
  wait "$pid"
  [ "$(grep -c '^login-backend ' "$d/.panes")" -eq 1 ]
  refute_grep -q "^login-backend $old " "$d/.panes"; grep -q "^pane close $old$" "$HERDR_STUB_LOG"
}
