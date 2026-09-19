load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "除錯方法檔存在，PROTOCOL 指得到它" {
  [ -f "$DK_ROOT/methods/debugging.md" ]
  grep -q 'methods/debugging.md' "$DK_ROOT/PROTOCOL.md"
}
@test "PROTOCOL 的 FIXED 列要求附根因（AC16）" {
  grep -qE '^\| FIXED \|.*根因' "$DK_ROOT/PROTOCOL.md"
}
@test "方法檔講方法不講次數上限" {
  grep -q '重現' "$DK_ROOT/methods/debugging.md"
  grep -q '根因' "$DK_ROOT/methods/debugging.md"
  refute_grep '上限一次' "$DK_ROOT/methods/debugging.md"
}
