load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "VERSION is semver and dk-version prints it" {
  v=$(cat "$DK_ROOT/VERSION"); [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
  run dk-version; [ "$status" -eq 0 ]; [ "$output" = "dkbo $v" ]
}
@test "every dkbo version string in the READMEs matches .dkbo/VERSION" {
  v=$(tr -d '[:space:]' < "$REPO_ROOT/.dkbo/VERSION"); n=0
  for f in README.md README.en.md .dkbo/README.md; do
    found=$(grep -vF herdr "$REPO_ROOT/$f" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)   # herdr 有自己的版號
    [ -n "$found" ] || { echo "no version string in $f"; false; }
    while IFS= read -r got; do
      [ "$got" = "$v" ] || { echo "$f: '$got' != .dkbo/VERSION '$v'"; false; }
      n=$((n+1))
    done <<< "$found"
  done
  # 版本行、安裝 pin ×2、更新 pin、install.sh 與 dk-version 的範例輸出。加減一處請一起改這個數字。
  [ "$n" -eq 8 ] || { echo "expected 8 version strings across the three READMEs, found $n"; false; }
}
@test "READMEs 引用的 herdr 版號都等於 lib/common.sh 的 DK_HERDR_MIN" {
  min=$(sed -n 's/^DK_HERDR_MIN="\([0-9.]*\)".*/\1/p' "$REPO_ROOT/.dkbo/lib/common.sh"); n=0
  [ -n "$min" ] || { echo "找不到 DK_HERDR_MIN"; false; }
  for f in README.md README.en.md .dkbo/README.md; do
    found=$(grep -oE 'herdr[^0-9]*[0-9]+\.[0-9]+\.[0-9]+' "$REPO_ROOT/$f" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
    [ -n "$found" ] || { echo "no herdr version string in $f"; false; }
    while IFS= read -r got; do
      [ "$got" = "$min" ] || { echo "$f: herdr '$got' != DK_HERDR_MIN '$min'"; false; }
      n=$((n+1))
    done <<< "$found"
  done
  # 0.9.1 的 docs 那條把六處 herdr 版號誤標成 dkbo 的版號。數字寫死在這裡，少一處或多一處都要有人回來看。
  [ "$n" -eq 6 ] || { echo "expected 6 herdr version strings across the three READMEs, found $n"; false; }
}
@test "dk-version tolerates a missing VERSION file" {
  rm "$DK_ROOT/VERSION"; run dk-version; [ "$status" -eq 0 ]; [ "$output" = "dkbo unknown" ]
}
@test "the newest CHANGELOG section matches .dkbo/VERSION" {
  v=$(tr -d '[:space:]' < "$REPO_ROOT/.dkbo/VERSION")
  top=$(grep -m1 -oE '^## [0-9]+\.[0-9]+\.[0-9]+' "$REPO_ROOT/CHANGELOG.md" | awk '{print $2}')
  [ "$top" = "$v" ] || { echo "CHANGELOG top is '$top' but .dkbo/VERSION is '$v'"; false; }
}
@test "CHANGELOG 首節列出本版的每一條變更" {
  sec=$(awk '/^## [0-9]/{n++} n==1' "$REPO_ROOT/CHANGELOG.md")
  for w in 'feat(watch)' '逾時但仍在工作（未熔斷）' '閒置 <N> 分鐘未交' 'feat(kind)' 'dk-kind down' \
           'feat(review)' 'p1`–`p6' 'feat(msg)' '背景送' '[UNDELIVERED]' '（你已交付過' \
           'feat(process)' 'minor 行格式不符' 'feat(brief)' 'WARN 所有權' '<成員>@波<N>' '\|' \
           'feat(leader)!' 'HERDR_WORKSPACE_ID' 'docs(protocol)' '取紅' 'state too long' \
           'docs(readme)' '任務 tab 不自動關' 'fix(repos)' 'SIGPIPE' 'fix(wave)' 'panes.lock' '別名還回來' 'all_globs' '測試：'; do
    [[ "$sec" == *"$w"* ]] || { echo "CHANGELOG 首節缺 $w"; false; }
  done
  # 測試條數是實跑值，不留 N 佔位
  grep -qE '^- 測試：[0-9]+ bats（\+[0-9]+；' <<< "$sec" || { echo "CHANGELOG 首節測試條數仍是佔位"; false; }
}
