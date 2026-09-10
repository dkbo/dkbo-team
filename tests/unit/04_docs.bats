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
