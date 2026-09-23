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

# --- codex 的「Approaching rate limits / Switch model」選單停住等人按 Enter -------------
# 樣本是 gamemore 實跑 herdr agent read 的原文。窄 pane 會把最後一行截斷，所以整句
# `Press enter to confirm` 認不得 24、64 兩份；式子只收 `Press enter to` 這段前綴。
block_hits() { printf '%s' "$2" | grep -qiE "$(dk_kind_re "$1" block)"; }
# `! cmd` 在 bats 的 @test 函式裡不是可靠的否定斷言：POSIX 規定以 `!` 開頭的管線豁免
# set -e，就算 cmd 真的成功（命中），`! cmd` 那一行也不會讓整個測試變紅——跟 helpers.bash
# 的 refute_grep 是同一個坑，這裡用一個普通函式回非零讓 bats 抓得到。
refute_block() { if block_hits "$@"; then echo "$1 的審批式子誤中: $2"; false; fi; }
@test "codex 的審批式子認得 Switch model 選單，含窄 pane 截斷的尾巴" {
  block_hits codex $'› 1. Switch to gpt-5.6-luna\n  2. Keep current model\n\n  Press enter to confirm or esc to go back'
  block_hits codex $'  3. Keep cu… Hide\n              models.\n\n  Press enter to confir'   # 樣本 24
  block_hits codex $'  2. Keep current\n     model\n\n  Press enter to con'                   # 樣本 64
  refute_block codex 'OpenAI Codex (v0.31.0)  model: gpt-5.5  approval: never'
}
@test "Switch model 選單的窄 pane 截斷版在 dk-watch 判成 BLOCKED 而不是 LIMIT" {
  # 窄 pane 把 `rate limit` 拆成兩行，額度式子不會先搶走。
  txt=$'  2. Keep current\n     model\n  3. Keep … Hide\n            future\n            rate\n            limit\n\n  Press enter to con'
  refute_quota codex "$txt"
  block_hits codex "$txt"
}

# --- AC4（0.12.0）：codex 的快到額度選單不再誤判成撞額度 -----------------------
# KIND_QUOTA_RE 拿掉了第 3 個分支 `rate limit`——它同時命中選單標題 `Approaching rate
# limits` 與選單第 3 項的說明文字 `Hide future rate limit reminders`，跟 claude.sh 的
# KIND_QUOTA_RE 第 2 個分支是同一個字串。三份樣本取自 panova headermerge 規劃領導 session
# 630f5371 的 spike/segs_preview.txt（樣本 2.2＝寬 pane 完整選單，樣本 24/64＝窄 pane 截斷
# 選單，已用在上面兩個測試）；第三份「上方另有耗盡訊息」的選單目前沒有實測過的合併原始截圖，
# 用已各自實測過的耗盡片語（03_kinds.bats 既有斷言）疊在同一份選單原文之上構造。
@test "AC4: 寬 pane 完整選單（實測樣本 2.2）不中額度，中審批" {
  txt=$'Approaching rate limits\n  Switch to gpt-5.6-luna for lower credit usage?\n\n\xe2\x80\xba 1. Switch to gpt-5.6-luna                 Fast and affordable agentic coding model.\n  2. Keep current model\n  3. Keep current model (never show again)  Hide future rate limit reminders about\n                                            switching models.\n\n  Press enter to confirm or esc to go back'
  refute_quota codex "$txt"
  block_hits codex "$txt"
}
@test "AC4: 上方另有耗盡訊息的選單仍中額度" {
  txt=$'You\x27ve hit your usage limit. Upgrade to Plus to continue using Codex\nApproaching rate limits\n  Switch to gpt-5.6-luna for lower credit usage?\n\n\xe2\x80\xba 1. Switch to gpt-5.6-luna                 Fast and affordable agentic coding model.\n  2. Keep current model\n\n  Press enter to confirm or esc to go back'
  assert_quota codex "$txt"
}

# --- DK_ADD_DIRS：多 repo 時每個 worktree 各一個 --add-dir（共用契約）-------------
@test "kind_args 沒設 DK_ADD_DIRS 時就是主樹一項（與 0.9.2 相同）" {
  for k in claude codex agy; do
    a=$(dk_kind_args "$k" "$(sed -n 's/.*M=\([^ ]*\).*/\1/p' <<< "$(grep '^KIND_DEFAULT_TIERS=' "$DK_ROOT/kinds/$k.sh")")")
    [ "$(grep -o -- '--add-dir' <<< "$a" | wc -l)" -eq 1 ] || { echo "$k: $a"; false; }
    [[ "$a" == *"--add-dir $DK_PROJECT_ROOT"* ]] || { echo "$k: $a"; false; }
  done
}
@test "kind_args 逐項展開 DK_ADD_DIRS，三個 kind 都一樣" {
  export DK_ADD_DIRS="/m /wt/api /wt/shared"
  for k in claude codex agy; do
    a=$(dk_kind_args "$k" "$(sed -n 's/.*L=\([^ "]*\).*/\1/p' <<< "$(grep '^KIND_DEFAULT_TIERS=' "$DK_ROOT/kinds/$k.sh")")")
    [ "$(grep -o -- '--add-dir' <<< "$a" | wc -l)" -eq 3 ] || { echo "$k: $a"; false; }
    for p in /m /wt/api /wt/shared; do
      [[ "$a" == *"--add-dir $p"* ]] || { echo "$k 少了 $p: $a"; false; }
    done
    refute_grep -q -- "--add-dir $DK_PROJECT_ROOT" <<< "$a"   # DK_ADD_DIRS 是完整清單，不是附加
  done
}

# --- kind_session_args：CLI 那側的 session 顯示名（AC19）--------------------------
@test "kind_session_args: claude 帶 --name，codex 與 agy 不帶" {
  dk_kind_load claude; [ "$(kind_session_args 'dk/login')" = "--name dk/login" ]
  dk_kind_load codex;  [ -z "$(kind_session_args 'dk/login')" ]
  dk_kind_load agy;    [ -z "$(kind_session_args 'dk/login')" ]
}
@test "kind_session_args: 三個 kind 都宣告了它，名字空的時候不吐半截旗標" {
  for k in claude codex agy; do
    grep -q '^kind_session_args()' "$DK_ROOT/kinds/$k.sh" || { echo "$k 沒有 kind_session_args"; false; }
    dk_kind_load "$k"; [ -z "$(kind_session_args '')" ] || { echo "$k 對空名字吐了東西"; false; }
  done
}
