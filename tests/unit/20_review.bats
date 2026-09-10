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
  : > "$HERDR_STUB_LOG"; run dk-review --kinds "agy" 2; [ "$status" -eq 0 ]; [[ "$output" == "review 2: login-reviewer-a(agy)" ]]; grep -q -- '--kind agy' "$HERDR_STUB_LOG"
  : > "$HERDR_STUB_LOG"; run dk-review --kinds "claude codex agy claude" --tier L; [ "$status" -eq 0 ]
  [ "$(grep -c '^agent start login-reviewer-' "$HERDR_STUB_LOG")" -eq 3 ]; grep -q -- '--model opus --effort high' "$HERDR_STUB_LOG"
}
@test "downed kinds are skipped; all down exits 1 with the skip hint" {
  open_wave 1; sed -i 's/^DK_KIND_DOWN=.*/DK_KIND_DOWN="codex"/' "$d/.task.env"
  run dk-review --kinds "codex claude"; [ "$status" -eq 0 ]; [[ "$output" == *"review 1: login-reviewer-a(claude)" ]]; [[ "$output" == *"codex is down"* ]]
  : > "$HERDR_STUB_LOG"; run dk-review --kinds codex; [ "$status" -eq 1 ]; [[ "$output" == *'review 1 skipped: all kinds down'* ]]; ! grep -q '^agent start' "$HERDR_STUB_LOG"
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
