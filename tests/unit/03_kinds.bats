load ../helpers
setup() { setup_project; . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/kinds.sh"; }
teardown() { teardown_project; }

@test "claude tier to args uses auto mode and grants the main tree" {
  # e2e 實測：acceptEdits 下員工連讀自己的切片、寫自己的 state 都要人按審批（RESULTS-2026-09-11 ①）
  [ "$(dk_kind_args claude sonnet/low)" = "--model sonnet --effort low --permission-mode auto --add-dir $DK_PROJECT_ROOT" ]
}
@test "codex tier to args" {
  [ "$(dk_kind_args codex gpt-5.5/medium)" = "-m gpt-5.5 -c model_reasoning_effort=medium -a never -s workspace-write" ]
}
@test "agy tier to args passes model and effort as separate flags" {
  [ "$(dk_kind_args agy gemini-3.1-pro/high)" = "--model gemini-3.1-pro --effort high --mode accept-edits" ]
}
@test "every kind declares its efforts per model" {
  for k in claude codex agy; do grep -q '^KIND_MODEL_EFFORTS=' "$DK_ROOT/kinds/$k.sh"; done
}
@test "rejects an effort the model does not offer" {
  run dk_kind_args agy gemini-3.1-pro/medium   # agy models: pro has high and low only
  [ "$status" -eq 1 ]; [[ "$output" == *"unknown effort"* ]]
  [ "$(dk_kind_args agy gemini-3.8-flash/medium)" = "--model gemini-3.8-flash --effort medium --mode accept-edits" ]
}
@test "rejects unknown model or effort" {
  run dk_kind_args claude haiku/low; [ "$status" -eq 1 ]
  run dk_kind_args claude opus/max;  [ "$status" -eq 1 ]
}
@test "available kinds intersects help, PATH and kinds dir" {
  mkdir -p "$PROJECT/fakebin"; printf '#!/bin/sh\n' > "$PROJECT/fakebin/claude"; chmod +x "$PROJECT/fakebin/claude"
  echo '[possible values: pi, claude, codex, agy]' > "$HERDR_STUB_RESPONSES/agent_start.json"
  PATH="$PROJECT/fakebin:$REPO_ROOT/tests/stub:/usr/bin:/bin" run dk_kinds_available
  [ "$output" = "claude" ]
}
