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
@test "dk-version tolerates a missing VERSION file" {
  rm "$DK_ROOT/VERSION"; run dk-version; [ "$status" -eq 0 ]; [ "$output" = "dkbo unknown" ]
}
