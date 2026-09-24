load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"; }
teardown() { teardown_project; }
open_wave() { dk-wave-open "$1" >/dev/null; mkdir -p "$d/waves"; echo diff > "$d/waves/$1.diff"; }

@test "default kinds come from settings.env; aliases a/b; slice points at the diff" {
  open_wave 1; printf 'DK_REVIEW_KINDS="claude codex"\n' >> "$DK_ROOT/settings.env"
  run dk-review; [ "$status" -eq 0 ]; [[ "$output" == "review 1: login-reviewer-a(claude) login-reviewer-b(codex)" ]]
  grep -q '^agent start login-reviewer-a --kind claude ' "$HERDR_STUB_LOG"; grep -q '^agent start login-reviewer-b --kind codex ' "$HERDR_STUB_LOG"
  grep -q -- '--env DK_ISOLATED=1' "$HERDR_STUB_LOG"
  grep -q ' review 1 spawned login-reviewer-a(claude) login-reviewer-b(codex)$' "$d/process.md"
  grep -q "$d/waves/1.diff" "$d/briefs/reviewer-a.md"; grep -q '## Important' "$d/briefs/reviewer-a.md"; grep -q 'backend(M) qa(S)' "$d/briefs/reviewer-b.md"
  grep -q "$d/briefs/reviewer-a.md" "$HERDR_STUB_LOG"   # first prompt used the slice
}
@test "wave table kinds: beat settings; --kinds beats both; cap is 3" {
  open_wave 2
  run dk-review; [ "$status" -eq 0 ]; [[ "$output" == *"login-reviewer-a(claude) login-reviewer-b(codex)" ]]
  : > "$HERDR_STUB_LOG"; run dk-review --kinds "agy" 2; [ "$status" -eq 0 ]; [[ "$output" == "review 2: login-reviewer-a(claude) login-reviewer-b(codex) login-reviewer-c(agy)" ]]; grep -q -- '--kind agy' "$HERDR_STUB_LOG"
  [ "$(grep ' review 2 spawned ' "$d/process.md" | tail -1 | sed 's/^[^ ]* //')" = "review 2 spawned login-reviewer-a(claude) login-reviewer-b(codex) login-reviewer-c(agy)" ]   # AC4：同波補派拿下一個別名、名單累加
  : > "$HERDR_STUB_LOG"; run dk-review --kinds "claude codex agy claude" --tier L; [ "$status" -eq 0 ]
  [ "$(grep -c '^agent start login-reviewer-' "$HERDR_STUB_LOG")" -eq 3 ]; grep -q -- '--model opus --effort high' "$HERDR_STUB_LOG"
}
@test "downed kinds are skipped; all down exits 1 with the skip hint" {
  open_wave 1; sed -i 's/^DK_KIND_DOWN=.*/DK_KIND_DOWN="codex"/' "$d/.task.env"
  run dk-review --kinds "codex claude"; [ "$status" -eq 0 ]; [[ "$output" == *"review 1: login-reviewer-a(claude)" ]]; [[ "$output" == *"codex is down"* ]]
  : > "$HERDR_STUB_LOG"; run dk-review --kinds codex; [ "$status" -eq 1 ]; [[ "$output" == *'review 1 skipped: all kinds down'* ]]; refute_grep -q '^agent start' "$HERDR_STUB_LOG"
}
@test "--task reviews the whole branch pack" {
  mkdir -p "$d/waves"; echo diff > "$d/waves/task.diff"
  run dk-review --task --tier L; [ "$status" -eq 0 ]; [ "$output" = "review task: login-reviewer-a(claude)" ]
  grep -q ' review task spawned login-reviewer-a(claude)$' "$d/process.md"; grep -q "$d/waves/task.diff" "$d/briefs/reviewer-a.md"; grep -q -- '--model opus --effort high' "$HERDR_STUB_LOG"
  rm "$d/waves/task.diff"; run dk-review --task; [ "$status" -eq 1 ]; [[ "$output" == *"dk-review-pack --task"* ]]
}
@test "refuses without a diff pack, with a skip: column, or a bad tier" {
  dk-wave-open 1 >/dev/null; run dk-review; [ "$status" -eq 1 ]; [[ "$output" == *"dk-review-pack"* ]]
  mkdir -p "$d/waves"; echo x > "$d/waves/1.diff"; sed -i 's#| 測試過 | 預設 |#| 測試過 | skip: 純文件 |#' "$d/brief.md"
  run dk-review; [ "$status" -eq 1 ]; [[ "$output" == *"skip: 純文件"* ]]; [[ "$output" == *"dk-process"* ]]
  run dk-review --tier S; [ "$status" -eq 1 ]
}
@test "a reviewer whose first prompt failed is counted but tagged prompt-failed" {
  open_wave 1
  HERDR_STUB_FAIL="agent prompt" run dk-review; [ "$status" -eq 0 ]
  [[ "$output" == *"review 1: login-reviewer-a(claude,prompt-failed)" ]]; [[ "$output" == *"re-prompt"* ]]
  grep -q ' review 1 spawned login-reviewer-a(claude,prompt-failed)$' "$d/process.md"
}
@test "every spawn failing exits 1 without a spawn-failed process line" {
  open_wave 1
  HERDR_STUB_FAIL="agent start" run dk-review; [ "$status" -eq 1 ]
  [[ "$output" == *"no reviewer spawned (dk-spawn failed for: claude)"* ]]; refute_grep -q 'spawn-failed' "$d/process.md"; refute_grep -q ' review 1 spawned' "$d/process.md"
}
@test "reviewer tier defaults to DK_REVIEW_TIER (ships as L)" {
  open_wave 1; run dk-review; [ "$status" -eq 0 ]
  grep -q '^agent start login-reviewer-a --kind claude --pane wC:p2 -- --model opus --effort high' "$HERDR_STUB_LOG"
}
@test "DK_REVIEW_TIER=M lowers reviewers to the M tier without touching roles/reviewer.md" {
  printf 'DK_REVIEW_TIER="M"\n' >> "$DK_ROOT/settings.env"
  open_wave 1; run dk-review; [ "$status" -eq 0 ]
  grep -q '^agent start login-reviewer-a --kind claude --pane wC:p2 -- --model opus --effort medium' "$HERDR_STUB_LOG"
  grep -q '^  L: opus/high$' "$DK_ROOT/roles/reviewer.md"   # 角色檔的 tier 語義沒被動過
}
@test "--tier still overrides DK_REVIEW_TIER" {
  printf 'DK_REVIEW_TIER="L"\n' >> "$DK_ROOT/settings.env"
  open_wave 1; run dk-review --tier M; [ "$status" -eq 0 ]
  grep -q -- '--model opus --effort medium' "$HERDR_STUB_LOG"
}
@test "a DK_REVIEW_TIER that is not M or L is refused, naming settings.env" {
  printf 'DK_REVIEW_TIER="S"\n' >> "$DK_ROOT/settings.env"
  open_wave 1; run dk-review
  [ "$status" -eq 1 ]; [[ "$output" == *"settings.env"* ]]; refute_grep -q '^agent start' "$HERDR_STUB_LOG"
}
@test "整枝評議帶累積的 Minor，逐波審查不帶" {
  open_wave 1
  echo "2026-09-19T10:00 minor 1: 變數命名不一致 src/a.sh:12" >> "$d/process.md"
  run dk-review 1; [ "$status" -eq 0 ]
  grep -q '逐波審查不 triage' "$d/briefs/reviewer-a.md"
  refute_grep '變數命名不一致' "$d/briefs/reviewer-a.md"
  dk-wave-close --force >/dev/null 2>&1 || true
  mkdir -p "$d/waves"; echo diff > "$d/waves/task.diff"
  run dk-review --task; [ "$status" -eq 0 ]
  grep -q '變數命名不一致' "$d/briefs/reviewer-a.md"
}

# --- 0.16.0 AC4（#26）：同一個 label 補派 reviewer ---------------------------------
# 原本第二次 dk-review 會從 a 重新取名：dk-spawn 在已有的 login-reviewer-a 身上再開一個，
# 而新的 spawned 行只列這一次的名單，dk-wave-close 只讀最後一行，第一位從此沒人收。
@test "AC4: 同一波補派 → 別名跳過已派的、spawned 行累加、第一位的 pane 不被關" {
  open_wave 1
  run dk-review --kinds claude; [ "$status" -eq 0 ]; [ "$output" = "review 1: login-reviewer-a(claude)" ]
  : > "$HERDR_STUB_LOG"
  run dk-review --kinds agy; [ "$status" -eq 0 ]
  [ "$output" = "review 1: login-reviewer-a(claude) login-reviewer-b(agy)" ]
  grep -q '^agent start login-reviewer-b --kind agy ' "$HERDR_STUB_LOG"
  refute_grep '^agent start login-reviewer-a ' "$HERDR_STUB_LOG"
  refute_grep '^pane close' "$HERDR_STUB_LOG"
  [ "$(grep ' review 1 spawned ' "$d/process.md" | tail -1 | sed 's/^[^ ]* //')" = "review 1 spawned login-reviewer-a(claude) login-reviewer-b(agy)" ]
  [ -f "$d/briefs/reviewer-b.md" ]
}
@test "AC4: 別名池擴到 a–f；不同 label（別的波）各算各的" {
  open_wave 1
  dk-review --kinds "claude codex agy" >/dev/null
  run dk-review --kinds "claude codex agy"; [ "$status" -eq 0 ]
  [[ "$output" == *"login-reviewer-d(claude) login-reviewer-e(codex) login-reviewer-f(agy)" ]]
  run dk-review --kinds "claude codex"; [ "$status" -eq 1 ]; [[ "$output" == *"別名"* ]]
  mkdir -p "$d/waves"; echo diff > "$d/waves/task.diff"
  run dk-review --task --kinds claude; [ "$status" -eq 0 ]; [ "$output" = "review task: login-reviewer-a(claude)" ]
}
@test "bklog Minor①: 別名用完的提示寫明關 pane 不會把別名還回來、只留 skipped 的出路" {
  open_wave 1
  dk-review --kinds "claude codex agy" >/dev/null; dk-review --kinds "claude codex agy" >/dev/null
  run dk-review --kinds claude; [ "$status" -eq 1 ]
  [[ "$output" == *"關 pane 不會把別名還回來"* ]]
  [[ "$output" == *'dk-process "review 1 skipped: <理由>"'* ]]
  refute_grep -q 'dk-wave-close --agent' <<< "$output"
}
