load ../helpers
# shellcheck 零警告是全域約束，但過去只靠人記得另外跑。這一檔把它收進 tests/run.sh 的完整套件。
# 不必 setup_project：shellcheck 只讀檔，不碰 herdr、不 source common.sh。
setup() {
  command -v shellcheck >/dev/null 2>&1 || skip "shellcheck 未安裝，跳過（CI 與開發機請裝）"
}

# 檔案集合只寫這一處（同全域約束那一行）。相對 REPO_ROOT 展開；沒命中的 glob 會原樣留下，
# 由 sc_run 交給 shellcheck 報「不存在」—— 不會靜悄悄少掃一類檔。
sc_targets() {
  ( cd "$REPO_ROOT" && printf '%s\n' .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh tests/run.sh )
}
# ②③ 共用的呼叫：零警告回 0，否則回非零並把 shellcheck 原文印出來（bats 失敗時會顯示）。
sc_run() { # FILE…（相對 REPO_ROOT 或絕對路徑）
  ( cd "$REPO_ROOT" && shellcheck "$@" )
}

@test "全域約束的檔案集合 shellcheck 零警告" {
  local files=() f
  while IFS= read -r f; do files+=("$f"); done < <(sc_targets)
  [ "${#files[@]}" -gt 5 ]
  run sc_run "${files[@]}"
  [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "檔案集合涵蓋 bin、lib、install.sh、kinds 與 tests/run.sh" {
  local t; t=$(sc_targets)
  echo "$t" | grep -qx '.dkbo/bin/dk-msg'
  echo "$t" | grep -qx '.dkbo/lib/common.sh'
  echo "$t" | grep -qx '.dkbo/install.sh'
  echo "$t" | grep -q '^\.dkbo/kinds/.*\.sh$'
  echo "$t" | grep -qx 'tests/run.sh'
}

@test "自我驗證：同一個 sc_run 對含 SC2086（未加引號的 \$x）的腳本回非零、印出原文" {
  local t; t=$(mktemp)
  printf '#!/usr/bin/env bash\nx="a b"\necho $x\n' > "$t"
  run sc_run "$t"
  rm -f "$t"
  [ "$status" -ne 0 ]
  [[ "$output" == *SC2086* ]]
}
