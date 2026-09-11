load ../helpers
setup() { setup_project; . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/frontmatter.sh"; }
teardown() { teardown_project; }

@test "all six roles have complete frontmatter with valid tiers" {
  for r in pm frontend backend qa it reviewer; do
    f="$DK_ROOT/roles/$r.md"; [ -f "$f" ]
    [ "$(dk_fm "$f" name)" = "$r" ]
    [ "$(dk_fm "$f" kind)" = claude ]
    for t in M L; do
      v=$(dk_fm_tier "$f" $t); [[ "$v" =~ ^(opus|sonnet)/(low|medium|high)$ ]]
    done
    [[ "$(dk_fm "$f" worktree)" =~ ^(true|false)$ ]]
    [[ "$(dk_fm "$f" group)" =~ ^(dev|review)$ ]]
  done
  [ -z "$(dk_fm_tier "$DK_ROOT/roles/reviewer.md" S)" ]
  [ "$(dk_fm "$DK_ROOT/roles/qa.md" group)" = review ]; [ "$(dk_fm "$DK_ROOT/roles/reviewer.md" group)" = review ]; [ "$(dk_fm "$DK_ROOT/roles/backend.md" group)" = dev ]
}
@test "docs exist and are short" {
  for f in LEADER.md PROTOCOL.md PROJECT.md ENTRY.md README.md roles/README.md; do [ -f "$DK_ROOT/$f" ]; done
  [ "$(wc -l < "$DK_ROOT/PROJECT.md")" -le 40 ]
  [ "$(wc -l < "$DK_ROOT/LEADER.md")" -le 120 ]
  [ "$(wc -l < "$DK_ROOT/PROTOCOL.md")" -le 120 ]
}
@test "templates carry substitution tokens" {
  grep -q '{{DISPLAY}}' "$DK_ROOT/templates/brief.md"
  grep -q '{{BRANCH}}' "$DK_ROOT/templates/brief.md"
  grep -q 'DK_SHORT="{{SHORT}}"' "$DK_ROOT/templates/task.env"
  grep -q '^status:' "$DK_ROOT/templates/state.md"
}

@test "LEADER.md covers brief-check, wave-open, review, ruling, timeout; PROTOCOL covers report and reviewer rules" {
  for w in dk-brief-check dk-wave-open dk-review-pack dk-review 'ruling:' '\[TIMEOUT\]' 'dk-wave-close --agent' 'review N skipped' 'settings.env' '--task'; do grep -q -- "$w" "$DK_ROOT/LEADER.md"; done
  for w in '## 測試' 'report.md' 'briefs/' '## 規格合規' '## Important' '## Minor' 'file:line' '不 push' 'ESCALATE'; do grep -q -- "$w" "$DK_ROOT/PROTOCOL.md"; done
  grep -q '^group: review' "$DK_ROOT/roles/reviewer.md"; grep -q '結案評議' "$DK_ROOT/roles/reviewer.md"
  grep -q 'settings.env' "$DK_ROOT/skills/init/SKILL.md"; grep -q 'DK_REVIEW_KINDS' "$DK_ROOT/skills/init/SKILL.md"
  grep -q -- '--exclude=settings.env' "$DK_ROOT/README.md"; grep -q '每波自動附審查' "$DK_ROOT/README.md"
  grep -q '^10\. ' "$REPO_ROOT/tests/e2e/RUNBOOK.md"; grep -q 'TIMEOUT' "$REPO_ROOT/tests/e2e/RUNBOOK.md"
}

@test "PROTOCOL's FIXED row covers the leader-relayed BUG that LEADER.md expects" {
  # LEADER.md 教領導把 reviewer 的 Important 轉成 [BUG] 給 dev、等 dev 的 [FIXED]，
  # 但 PROTOCOL 的類型表只寫「員工→員工」，於是 dev 照自己的規範回了 [DONE]
  # （RESULTS-2026-09-11 ⑩）
  grep -qE 'dev .?\[FIXED\]' "$DK_ROOT/LEADER.md"
  grep -qE '^\| FIXED \|[^|]*領導' "$DK_ROOT/PROTOCOL.md"
}
