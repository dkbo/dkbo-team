load ../helpers
setup() { SAMPLE="$(mktemp)"; }
teardown() { rm -f "$SAMPLE"; }

# bats 在 set -e 下跑，而 `! cmd` 豁免 set -e —— 否定斷言不是測試最後一條時，命中了也照樣綠
# （helpers.bash 的 refute_grep 那段註解）。這一檔掃出所有 `!` 開頭的述句，擋住新增。
# 算數：行首（去掉縮排），或接在 `;`、`&&`、`||`、`|`、`{`、`(` 之後（中間可以沒有空白），
# 或接在 `then`、`do`、`else` 之後（關鍵字後面 bash 本來就要空白）的 `! `。
# 不算：註解行、`[ ! … ]`／`[[ ! … ]]`（`!` 前面是 `[`）、字串裡的 `!`（前面不是上述分隔符）。
# 本檔的違規樣本一律在執行期用 printf 組出來：字面寫進原始碼的話，(a) 會掃到自己。
bang_scan() { # FILE... → 每一個違規行印一列 `檔:行: 內容`；沒有違規時什麼都不印
  grep -nE '^[[:space:]]*!([[:space:]]|$)|(;|&&|\||\{|\()[[:space:]]*!([[:space:]]|$)|(^|[^[:alnum:]_])(then|do|else)[[:space:]]+!([[:space:]]|$)' "$@" /dev/null \
    | grep -vE '^[^:]*:[0-9]+:[[:space:]]*#' || true
}

@test "tests/ 裡沒有 ! 開頭的否定述句（改用 refute_grep 或 refute）" {
  local files hits
  files=$(git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard 'tests/*.bats' tests/helpers.bash)
  [ -n "$files" ]
  hits=$(cd "$REPO_ROOT" && bang_scan $files)
  [ -z "$hits" ] || { echo "無效的否定斷言（bats 的 set -e 抓不到）："; echo "$hits"; false; }
}

@test "掃描集合包含 35 自己與 helpers.bash（不是硬編的清單）" {
  local files
  files=$(git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard 'tests/*.bats' tests/helpers.bash)
  echo "$files" | grep -qx 'tests/unit/35_test_hygiene.bats'
  echo "$files" | grep -qx 'tests/helpers.bash'
}

@test "掃描器判出每一種 ! 述句形狀" {
  local b='!' line
  for line in "  $b grep -q x f; true" "true; $b foo" "true && $b foo" "false || $b foo" \
              "if true; then $b foo; fi" "for i in 1; do $b foo; done" \
              "true;$b foo" "a &&$b b" "a ||$b b" "{ $b foo; }" "($b foo)" "x | $b foo" \
              "if a; then b; else $b foo; fi"; do
    printf '%s\n' "$line" > "$SAMPLE"
    [ -n "$(bang_scan "$SAMPLE")" ] || { echo "漏判：$line"; false; }
  done
}

@test "掃描器不誤判 [ ! ]、[[ ! ]]、refute_grep、註解與字串裡的 !" {
  local b='!' line
  for line in "[ $b -f x ]" "[[ $b -d y ]]" "refute_grep x f" "  # $b 註解" "echo \"a $b b\""; do
    printf '%s\n' "$line" > "$SAMPLE"
    [ -z "$(bang_scan "$SAMPLE")" ] || { echo "誤判：$line"; false; }
  done
}

@test "掃描器列出檔:行" {
  local b='!'
  printf 'ok\n  %s grep -q x f; true\nok\n' "$b" > "$SAMPLE"
  [ "$(bang_scan "$SAMPLE" | cut -d: -f1-2)" = "$SAMPLE:2" ]
}
