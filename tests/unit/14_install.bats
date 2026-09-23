load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "install creates symlinks, entry files, gitignore; idempotent" {
  run .dkbo/install.sh; [ "$status" -eq 0 ]
  for s in init add-role; do
    [ "$(readlink .claude/skills/dkbo-$s)" = "../../.dkbo/skills/$s" ]
    [ "$(readlink .agents/skills/dkbo-$s)" = "../../.dkbo/skills/$s" ]
    [ -f ".claude/skills/dkbo-$s/SKILL.md" ]
  done
  grep -q '^讀 .dkbo/ENTRY.md' AGENTS.md; grep -q '^@AGENTS.md$' CLAUDE.md; grep -q '.dkbo/.sessions' .gitignore; grep -qx '.worktrees/' .gitignore
  run .dkbo/install.sh; [ "$status" -eq 0 ]
  [ "$(grep -c '^@AGENTS.md$' CLAUDE.md)" -eq 1 ]
}
@test "install.sh links all five skills into both skill dirs" {
  run .dkbo/install.sh
  [ "$status" -eq 0 ]
  for d in .claude/skills .agents/skills; do
    for s in init add-role brain plan run; do
      [ -L "$d/dkbo-$s" ] || { echo "missing symlink $d/dkbo-$s"; false; }
      [ -f "$d/dkbo-$s/SKILL.md" ] || { echo "$d/dkbo-$s does not resolve to a SKILL.md"; false; }
    done
  done
}
@test "install refuses an herdr below the floor and does not require a herdr pane" {
  HERDR_STUB_VERSION=0.8.0 run .dkbo/install.sh
  [ "$status" -ne 0 ]; [[ "$output" == *"older than"* ]]; [ ! -e .claude/skills/dkbo-init ]
  HERDR_ENV=0 run .dkbo/install.sh; [ "$status" -eq 0 ]   # installing from a plain shell stays allowed
}
@test "install appends to an existing CLAUDE.md and AGENTS.md" {
  echo '# my project' > CLAUDE.md; echo '# agents rules' > AGENTS.md; .dkbo/install.sh >/dev/null
  head -1 CLAUDE.md | grep -q '# my project'; grep -q '^@AGENTS.md$' CLAUDE.md
  head -1 AGENTS.md | grep -q '# agents rules'; grep -q '^讀 .dkbo/ENTRY.md' AGENTS.md
}
@test "install skips CLAUDE.md line when it symlinks AGENTS.md" {
  echo '# agents rules' > AGENTS.md; ln -s AGENTS.md CLAUDE.md; .dkbo/install.sh >/dev/null
  ! grep -q '^@AGENTS.md$' AGENTS.md; grep -q '^讀 .dkbo/ENTRY.md' AGENTS.md
}
@test "README carries the one-shot install and update commands" {
  for needle in '.dkbo/install.sh' 'git add -A' '/dkbo-init' 'HERDR_ENV' 'herdr --version' 'dk-whoami' 'rsync' '--exclude=tasks' '--branch' 'dk-version'; do
    grep -qF -- "$needle" .dkbo/README.md || { echo "missing: $needle"; return 1; }
  done
  [ -f "$REPO_ROOT/README.md" ]; grep -q '.dkbo/README.md' "$REPO_ROOT/README.md"
}
@test "skills have agent-skills frontmatter" {
  for s in init add-role brain plan run; do
    head -1 ".dkbo/skills/$s/SKILL.md" | grep -q '^---$'
    grep -q "^name: dkbo-$s$" ".dkbo/skills/$s/SKILL.md"; grep -q '^description: ' ".dkbo/skills/$s/SKILL.md"
  done
}
@test "install appends cleanly to files without a trailing newline" {
  printf 'node_modules' > .gitignore; printf '# my project' > CLAUDE.md; printf '# rules' > AGENTS.md
  .dkbo/install.sh >/dev/null
  grep -qx 'node_modules' .gitignore; grep -qx '.dkbo/.sessions/\*' .gitignore
  grep -qx '# my project' CLAUDE.md; grep -qx '@AGENTS.md' CLAUDE.md
  grep -qx '# rules' AGENTS.md; grep -q '^讀 .dkbo/ENTRY.md' AGENTS.md
}
@test "install leaves a pre-existing real directory alone" {
  mkdir -p .claude/skills/dkbo-init; touch .claude/skills/dkbo-init/keep
  run .dkbo/install.sh; [ "$status" -eq 0 ]; [[ "$output" == *"not a symlink"* ]]
  [ ! -L .claude/skills/dkbo-init ]; [ -f .claude/skills/dkbo-init/keep ]; [ ! -e .claude/skills/dkbo-init/init ]
  [ "$(readlink .agents/skills/dkbo-init)" = "../../.dkbo/skills/init" ]
}
@test "全新安裝：README 的一鍵指令先拿掉源碼倉的開發紀錄，install.sh 補空白起始檔" {
  strip=$(grep -o '(cd "$tmp/.dkbo" && rm -rf [^)]*)' "$REPO_ROOT/README.md" | head -1)
  [ -n "$strip" ]
  tmp=$(mktemp -d); cp -r "$REPO_ROOT/.dkbo" "$tmp/.dkbo"
  eval "$strip"
  rm -rf .dkbo; cp -r "$tmp/.dkbo" ./.dkbo; rm -rf "$tmp"
  run bash .dkbo/install.sh; [ "$status" -eq 0 ]
  [[ "$output" == *"seeded .dkbo/decisions.md"* ]]
  [ -z "$(find .dkbo/tasks -mindepth 1 -maxdepth 1 -name '20*')" ]
  for f in tasks/INDEX.md:INDEX.md tasks/BACKLOG.md:BACKLOG.md decisions.md:decisions.md PROJECT.md:PROJECT.md settings.env:settings.env; do
    cmp ".dkbo/${f%%:*}" ".dkbo/templates/seed/${f#*:}" || { echo "not seeded: ${f%%:*}"; false; }
  done
  grep -q '^DK_TEST_CMD=""' .dkbo/settings.env
  [ -f .dkbo/tasks/_chores/.gitkeep ]; [ -f .dkbo/.sessions/.gitkeep ]
}
@test "install.sh 不覆蓋既有的專案記憶與設定" {
  echo '- 2026-01-01 我的決策' >> .dkbo/decisions.md
  for f in decisions.md settings.env PROJECT.md tasks/INDEX.md tasks/BACKLOG.md; do cp ".dkbo/$f" "$BATS_TEST_TMPDIR/$(basename "$f").bak"; done
  run .dkbo/install.sh; [ "$status" -eq 0 ]; [[ "$output" != *seeded* ]]
  for f in decisions.md settings.env PROJECT.md tasks/INDEX.md tasks/BACKLOG.md; do cmp ".dkbo/$f" "$BATS_TEST_TMPDIR/$(basename "$f").bak"; done
}
@test "三份 README 的全新安裝都先拿掉專案檔，且涵蓋升級 rsync 排除的每一項（roles 除外）" {
  for f in README.md README.en.md .dkbo/README.md; do
    cp_n=$(grep -c 'cp -r "$tmp/.dkbo" ./.dkbo' "$REPO_ROOT/$f"); rm_n=$(grep -c '(cd "$tmp/.dkbo" && rm -rf ' "$REPO_ROOT/$f")
    [ "$cp_n" -ge 1 ] && [ "$cp_n" -eq "$rm_n" ] || { echo "$f: cp -r $cp_n 次、先拿掉 $rm_n 次"; false; }
  done
  strip=$(grep -o '(cd "$tmp/.dkbo" && rm -rf [^)]*)' "$REPO_ROOT/.dkbo/README.md" | head -1)
  for x in $(grep -o -- "--exclude=[^ ]*" "$REPO_ROOT/.dkbo/README.md" | sed 's/^--exclude=//; s/^'\''//; s/'\''$//' | sort -u); do
    [ "$x" = 'roles/*' ] && continue
    [[ " ${strip%)} " == *" $x "* ]] || { echo "全新安裝沒拿掉 $x"; false; }
  done
}
