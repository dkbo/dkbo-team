load ../helpers
setup() { setup_project; fixture_task login 使用者登入 >/dev/null; }
teardown() { teardown_project; }

proc() { echo "$DK_ROOT/tasks/$(date +%F)-login/process.md"; }
lines() { if [ -f "$(proc)" ]; then wc -l < "$(proc)"; else echo 0; fi; }

# --- AC7（#24）：整枝評議只讀合 DK_MINOR_RE 的 minor 行，格式錯的當場擋回去 ---

@test "AC7: minor task: x 拒收，process.md 沒多一行" {
  before=$(lines)
  run dk-process "minor task: 命名不一致"
  [ "$status" -eq 2 ]
  [[ "$output" == "dk-process: minor 行格式不符"* ]]
  [[ "$output" == *'要 "minor: …" 或 "minor <波號>: …"'* ]]
  [ "$(lines)" -eq "$before" ]
  refute_grep -q 'minor task' "$(proc)"
}

@test "AC7: minor:x（冒號後沒空白）也拒收" {
  run dk-process "minor:x"
  [ "$status" -eq 2 ]
  [[ "$output" == "dk-process: minor 行格式不符"* ]]
}

@test "AC7: minor: x 與 minor 2: x 照收，且整枝評議讀得到" {
  run dk-process "minor: 變數名"; [ "$status" -eq 0 ]
  run dk-process "minor 2: 註解錯字"; [ "$status" -eq 0 ]
  grep -Eq '^[0-9T:-]+ minor: 變數名$' "$(proc)"
  grep -Eq '^[0-9T:-]+ minor 2: 註解錯字$' "$(proc)"
  . "$DK_ROOT/lib/common.sh"
  [ "$(dk_minor_count "$(proc)")" -eq 2 ]
}

@test "AC7: 一般行與 minority report 照收（不以 minor 空白或 minor: 開頭）" {
  run dk-process "brief-review skipped: 單元測試"; [ "$status" -eq 0 ]
  run dk-process "minority report"; [ "$status" -eq 0 ]
  grep -Eq '^[0-9T:-]+ brief-review skipped: 單元測試$' "$(proc)"
  grep -Eq '^[0-9T:-]+ minority report$' "$(proc)"
}
