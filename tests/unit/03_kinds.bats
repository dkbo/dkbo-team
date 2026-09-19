load ../helpers
setup() { setup_project; . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/kinds.sh"; }
teardown() { teardown_project; }

@test "claude tier to args uses auto mode and grants the main tree" {
  # e2e 實測：acceptEdits 下員工連讀自己的切片、寫自己的 state 都要人按審批（RESULTS-2026-09-11 ①）
  [ "$(dk_kind_args claude sonnet/low)" = "--model sonnet --effort low --permission-mode auto --add-dir $DK_PROJECT_ROOT" ]
}
@test "codex tier to args" {
  [ "$(dk_kind_args codex gpt-5.5/medium)" = "-m gpt-5.5 -c model_reasoning_effort=medium -a never -s workspace-write --add-dir $DK_PROJECT_ROOT" ]
}
@test "agy tier to args passes model and effort as separate flags" {
  # agy 沒有 claude `auto` 的等價檔位：`--mode` 只吃 accept-edits 與 plan，而 accept-edits 只放行
  # 編輯，每個 shell 指令都要人按（1.2.6 實測原文：a tool required the "command" permission）。
  [ "$(dk_kind_args agy gemini-3.1-pro/high)" = "--model gemini-3.1-pro --effort high --dangerously-skip-permissions --add-dir $DK_PROJECT_ROOT" ]
}
@test "every kind declares its efforts per model" {
  for k in claude codex agy; do grep -q '^KIND_MODEL_EFFORTS=' "$DK_ROOT/kinds/$k.sh"; done
}
@test "rejects an effort the model does not offer" {
  run dk_kind_args agy gemini-3.1-pro/medium   # agy models: pro has high and low only
  [ "$status" -eq 1 ]; [[ "$output" == *"unknown effort"* ]]
  [ "$(dk_kind_args agy gemini-3.8-flash/medium)" = "--model gemini-3.8-flash --effort medium --dangerously-skip-permissions --add-dir $DK_PROJECT_ROOT" ]
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

@test "三個 kind 都把主樹加進可寫範圍" {
  # 員工的 cwd 是 worktree，但切片、state、report、diff pack 全在主樹的 .dkbo/ 下。
  # claude.sh 早就寫明了這一點並補上 --add-dir，codex 與 agy 漏掉 —— 它們的 primary
  # workspace 同樣只有 worktree（codex 是 -s workspace-write）。
  for k in claude codex agy; do
    a=$(dk_kind_args "$k" "$(sed -n 's/.*M=\([^ ]*\).*/\1/p' <<< "$(grep '^KIND_DEFAULT_TIERS=' "$DK_ROOT/kinds/$k.sh")")")
    [[ "$a" == *"--add-dir $DK_PROJECT_ROOT"* ]] || { echo "$k: $a"; false; }
  done
}

@test "沒有任何 kind 把員工留在互動審批上" {
  # 員工是無人看管的 pane：任何要人按的審批都等於整條流水線停住。dkbo 的邊界從來不是靠 CLI 的
  # 審批 UI —— 是 worktree 隔離、dk-wave-close 拿真實 git diff 比對檔案所有權，與 git 本身。
  [[ "$(dk_kind_args agy gemini-3.8-flash/low)" != *"--mode accept-edits"* ]]
  # --sandbox 不是替代品：1.2.6 實測它把檔案系統視角整個搬到 ~/.gemini/antigravity-cli/scratch/
  # （cat worktree 裡的檔回 No such file，寫入落到 scratch），員工會看不到自己的 worktree。
  for k in claude codex agy; do
    a=$(dk_kind_args "$k" "$(sed -n 's/.*S=\([^ ]*\).*/\1/p' <<< "$(grep '^KIND_DEFAULT_TIERS=' "$DK_ROOT/kinds/$k.sh")")")
    [[ "$a" != *"--sandbox"* ]] || { echo "$k: $a"; false; }
  done
}

# --- 額度式子只描述「額度已耗盡」，不描述正常啟動就有的字樣 ---------------------
# agy 的啟動橫幅是 `bal@host (Antigravity Starter Quota)`：裸 `quota` 命中它，等於每個 agy 員工
# 一 spawn 就被判撞額度、該 kind 當場熔斷，整條守望反過來害人（BACKLOG 2026-09-19 實測）。
quota_hits() { # KIND TEXT — 走 dk-watch screen_hits 的同一條路徑
  printf '%s' "$2" | grep -qiE "$(dk_kind_re "$1" quota)"
}
assert_quota() { quota_hits "$@" || { echo "$1 的額度式子漏掉了: $2"; false; }; }
refute_quota() { if quota_hits "$@"; then echo "$1 的額度式子誤中: $2"; false; fi; }

@test "agy 的額度式子放過啟動橫幅，仍認得實測的耗盡訊息" {
  refute_quota agy 'bal@host (Antigravity Starter Quota)'
  assert_quota agy 'Individual quota reached, Resets in 102h11m1s'   # 1.2.6 實測原文
  assert_quota agy 'quota exceeded'
  assert_quota agy 'resource exhausted'
  assert_quota agy 'rate limit'
}
@test "未知 kind 的通用額度式子也放過啟動橫幅" {
  refute_quota '' 'bal@host (Antigravity Starter Quota)'
  assert_quota '' 'Individual quota reached, Resets in 102h11m1s'
  assert_quota '' 'usage limit'
}
@test "claude 與 codex 的額度式子放過各自的啟動畫面" {
  refute_quota claude '✻ Welcome to Claude Code!  /help for help, /status for your current setup'
  refute_quota codex 'OpenAI Codex (v0.31.0)  model: gpt-5.5  approval: never'
  assert_quota claude 'Approaching your usage limit'
  assert_quota codex "You've hit your usage limit. Upgrade to Plus to continue using Codex"
}
# --- claude 的裸 approaching your 是「快到了」不是「已耗盡」，違反共用契約第三列 ---
# （reviewer-a Important 3）：正常畫面只要出現這兩個很常見的英文字就會被判額度已耗盡，
# 跟被修掉的 agy 裸 quota 是同一類洞。收窄成實測過的耗盡片語。
@test "claude 的額度式子不再吃裸 approaching your，只認耗盡片語" {
  refute_quota claude 'approaching your deadline'
  assert_quota claude "You've hit your usage limit"
  assert_quota claude 'rate limit'
}
