load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "dk_settings provides and exports DK_LEADER_KIND, defaulting to claude" {
  rm -f "$DK_ROOT/settings.env"
  run bash -c '. "$DK_ROOT/lib/common.sh"; dk_settings 2>/dev/null; env | grep "^DK_LEADER_KIND="'
  [ "$status" -eq 0 ]; [ "$output" = "DK_LEADER_KIND=claude" ]
}

@test "settings.env ships DK_LEADER_KIND as the sixth key" {
  grep -q '^DK_LEADER_KIND=' "$DK_ROOT/settings.env"
}

@test "dk-leader takes its kind from DK_LEADER_KIND and that kind's L tier" {
  sed -i 's/^DK_LEADER_KIND=.*/DK_LEADER_KIND="codex"/' "$DK_ROOT/settings.env" || true
  grep -q '^DK_LEADER_KIND=' "$DK_ROOT/settings.env" || echo 'DK_LEADER_KIND="codex"' >> "$DK_ROOT/settings.env"
  run dk-leader pay 金流; [ "$status" -eq 0 ]
  # --add-dir 對領導是冗餘的（它的 cwd 就是主樹），但 kind_args 是領導與員工共用的一支，
  # 而 claude 那側一直就帶著它 —— 三個 kind 保持一致，不為領導開特例。
  grep -q "^agent start leader-pay --kind codex --pane wC:p2 -- -m gpt-5.5 -c model_reasoning_effort=high -a never -s workspace-write --add-dir $PROJECT\$" "$HERDR_STUB_LOG"
}

@test "dk-leader --kind overrides DK_LEADER_KIND and takes the new kind's L tier" {
  echo 'DK_LEADER_KIND="codex"' >> "$DK_ROOT/settings.env"
  run dk-leader pay 金流 --kind claude; [ "$status" -eq 0 ]
  # --name dk/pay：AC19，CLI 那側的 session 顯示名＝workspace 名（kinds/claude.sh 的 kind_session_args）
  grep -q '^agent start leader-pay --kind claude --pane wC:p2 -- --model opus --effort high --permission-mode auto --add-dir '"$PROJECT"' --name dk/pay$' "$HERDR_STUB_LOG"
}

@test "init skill asks for the leader kind" {
  grep -q 'DK_LEADER_KIND' "$DK_ROOT/skills/init/SKILL.md"
}

@test "the three READMEs state the leader CLI is selectable" {
  for f in README.md README.en.md .dkbo/README.md; do grep -q 'DK_LEADER_KIND' "$REPO_ROOT/$f"; done
}

@test "settings.env 有整波逾時這個鍵" {
  grep -q '^DK_WAVE_TIMEOUT_MIN=' "$DK_ROOT/settings.env"
  [ "$(grep -c '^DK_' "$DK_ROOT/settings.env")" -eq 10 ]   # 0.10.0 多了 DK_REPOS 與 DK_SETUP_CMD
}
@test "dk_settings provides and exports DK_REVIEW_TIER, defaulting to L" {
  rm -f "$DK_ROOT/settings.env"
  run bash -c '. "$DK_ROOT/lib/common.sh"; dk_settings 2>/dev/null; env | grep "^DK_REVIEW_TIER="'
  [ "$status" -eq 0 ]; [ "$output" = "DK_REVIEW_TIER=L" ]
}
@test "settings.env ships DK_REVIEW_TIER as the eighth key" {
  grep -q '^DK_REVIEW_TIER=' "$DK_ROOT/settings.env"
}
