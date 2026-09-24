load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

# bash 4+ 專屬語法。dk_ver_ge 刻意避開 sort -V 是為了 macOS，而 macOS 內建的是 bash 3.2，
# 所以整個 .dkbo/ 必須跑得動 bash 3.2 —— 把「文件宣稱」變成機械閘。
bash4_hits() {
  grep -rnE 'declare -A|local -A|typeset -A|\bmapfile\b|\breadarray\b|\bcoproc\b|&>>|;;&|\$\{[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?(\^\^|,,)' \
    "$1" --include='*.sh' --include='dk-*' 2>/dev/null || true
}

@test "no bash 4+ syntax anywhere in .dkbo (and the scan has teeth)" {
  printf 'declare -A poison\n' > "$DK_ROOT/lib/poison.sh"
  [ -n "$(bash4_hits "$DK_ROOT")" ] || { echo "scan missed a planted 'declare -A'"; false; }
  rm "$DK_ROOT/lib/poison.sh"
  hits=$(bash4_hits "$DK_ROOT")
  [ -z "$hits" ] || { echo "bash 4+ syntax found:"; echo "$hits"; false; }
}

@test "the three READMEs state the real dependency floors, not bash 5" {
  for f in README.md README.en.md .dkbo/README.md; do
    refute_grep -q 'bash 5' "$REPO_ROOT/$f" || { echo "$f still claims bash 5"; false; }
    grep -q 'bash 3.2' "$REPO_ROOT/$f" || { echo "$f does not state bash 3.2"; false; }
  done
  grep -q 'flock' "$REPO_ROOT/README.md"
  grep -q 'git ≥ 2.17' "$REPO_ROOT/README.md"
}
