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
  for f in LEADER.md PROTOCOL.md PROJECT.md ENTRY.md README.md roles/README.md \
           skills/brain/SKILL.md skills/plan/SKILL.md skills/run/SKILL.md; do
    [ -f "$DK_ROOT/$f" ]
  done
  [ "$(wc -l < "$DK_ROOT/PROJECT.md")" -le 40 ]
  [ "$(wc -l < "$DK_ROOT/PROTOCOL.md")" -le 120 ]
  # LEADER.md 瘦身成三階段共用規範；長回去代表階段內容又被塞進共用段
  [ "$(wc -l < "$DK_ROOT/LEADER.md")" -le 30 ]
  [ "$(wc -l < "$DK_ROOT/skills/brain/SKILL.md")" -le 40 ]
  [ "$(wc -l < "$DK_ROOT/skills/plan/SKILL.md")" -le 25 ]
  # 0.15.0 多了「不停車」與「熔斷器」兩段（run 開跑後不問人），50 → 60
  [ "$(wc -l < "$DK_ROOT/skills/run/SKILL.md")" -le 60 ]
}
@test "templates carry substitution tokens" {
  grep -q '{{DISPLAY}}' "$DK_ROOT/templates/brief.md"
  grep -q '{{BRANCH}}' "$DK_ROOT/templates/brief.md"
  grep -q 'DK_SHORT="{{SHORT}}"' "$DK_ROOT/templates/task.env"
  grep -q '^status:' "$DK_ROOT/templates/state.md"
}

@test "each stage doc covers its own commands; LEADER.md keeps only the shared ones; PROTOCOL covers report and reviewer rules" {
  for w in dk-brief-check 'dk-task-new' '--gate1'; do grep -q -- "$w" "$DK_ROOT/skills/plan/SKILL.md"; done
  for w in dk-wave-open dk-review-pack dk-review '\[TIMEOUT\]' 'dk-wave-close --agent' 'review N skipped' '--task' 'dk-task-close'; do grep -q -- "$w" "$DK_ROOT/skills/run/SKILL.md"; done
  for w in dk-chore 'dk-chore-close' 'dk-chore-tidy' '評議波'; do grep -q -- "$w" "$DK_ROOT/skills/brain/SKILL.md"; done
  for w in 'ruling:' 'settings.env' 'dk-msg --ack'; do grep -q -- "$w" "$DK_ROOT/LEADER.md"; done
  for w in '## 測試' 'report.md' 'briefs/' '## 規格合規' '## Important' '## Minor' 'file:line' '不 push' 'ESCALATE'; do grep -q -- "$w" "$DK_ROOT/PROTOCOL.md"; done
  grep -q '^group: review' "$DK_ROOT/roles/reviewer.md"; grep -q '結案評議' "$DK_ROOT/roles/reviewer.md"
  grep -q 'settings.env' "$DK_ROOT/skills/init/SKILL.md"; grep -q 'DK_REVIEW_KINDS' "$DK_ROOT/skills/init/SKILL.md"
  grep -q -- '--exclude=settings.env' "$DK_ROOT/README.md"; grep -q '每波自動附審查' "$DK_ROOT/README.md"
  grep -q '^10\. ' "$REPO_ROOT/tests/e2e/RUNBOOK.md"; grep -q 'TIMEOUT' "$REPO_ROOT/tests/e2e/RUNBOOK.md"
}

@test "PROTOCOL's FIXED row covers the leader-relayed BUG that run 篇 expects" {
  # run 篇教領導把 reviewer 的 Important 轉成 [BUG] 給 dev、等 dev 的 [FIXED]，
  # 但 PROTOCOL 的類型表只寫「員工→員工」，於是 dev 照自己的規範回了 [DONE]
  # （RESULTS-2026-09-11 ⑩）
  grep -qE 'dev .?\[FIXED\]' "$DK_ROOT/skills/run/SKILL.md"
  grep -qE '^\| FIXED \|[^|]*領導' "$DK_ROOT/PROTOCOL.md"
}

@test "ENTRY.md tells a plain session it is NOT the leader" {
  # 這次改版的核心：入口只認身分、不再把人帶進領導規範。
  # 最可能的回歸是有人為了方便又把 leader 分支接回 LEADER.md。
  ! grep -q 'LEADER\.md' "$DK_ROOT/ENTRY.md"
  for w in dkbo-brain dkbo-plan dkbo-run dk-whoami dk-resume; do
    grep -q -- "$w" "$DK_ROOT/ENTRY.md"
  done
  grep -q '你不是領導' "$DK_ROOT/ENTRY.md"
  grep -q '不要自己去讀規範檔' "$DK_ROOT/ENTRY.md"
  # employee 分支不准動
  grep -q 'roles/<角色>.md' "$DK_ROOT/ENTRY.md"
  grep -q 'PROTOCOL.md' "$DK_ROOT/ENTRY.md"
}

@test "修復迴圈是兩輪，PROTOCOL 與 run SKILL 一致" {
  grep -q 'handoff' "$DK_ROOT/PROTOCOL.md"
  grep -q 'handoff' "$DK_ROOT/skills/run/SKILL.md"
  refute_grep '修復迴圈上限一次' "$DK_ROOT/PROTOCOL.md"
}

@test "roles/*.md 的修復迴圈文字跟 PROTOCOL 一致，不再寫修一次" {
  # 整枝評議 Important 2：員工首輪提示第一項讀的是角色檔，角色檔還停在一輪的話
  # PROTOCOL 的兩輪換腦袋在實務上永遠不會觸發。
  refute_grep '修一次' "$DK_ROOT/roles/backend.md"
  refute_grep '修一次' "$DK_ROOT/roles/frontend.md"
  refute_grep '修一次' "$DK_ROOT/roles/qa.md"
  for r in backend.md frontend.md qa.md; do grep -q '兩輪' "$DK_ROOT/roles/$r"; done
}

@test "skills/run/SKILL.md 教領導把 reviewer 的 Minor 寫成 minor process 行" {
  # 整枝評議 Important 1：dk-review --task 與 dk-task-close 都讀 process.md 的
  # minor 行，但沒有任何一處告訴領導要寫它 —— {{MINORS}} 對其他任務永遠是空的。
  grep -q 'dk-process "minor N: ' "$DK_ROOT/skills/run/SKILL.md"
}

@test "AC15: PROJECT.md 補了多 repo 事實" {
  grep -q 'DK_REPOS' "$DK_ROOT/PROJECT.md"
}
