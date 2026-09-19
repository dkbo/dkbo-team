load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); . "$DK_ROOT/lib/common.sh"; }
teardown() { teardown_project; }

use_fixture() { # $1=fixture 短名 $2=任務短名 — 把真 log 放進一個任務資料夾，再用 dk-timeline <task> 讀
  mkdir -p "$DK_ROOT/tasks/2026-09-19-$2"
  cp "$REPO_ROOT/tests/fixtures/$1-process.md" "$DK_ROOT/tasks/2026-09-19-$2/process.md"
}

@test "dk_ts_minutes 純算術換算，跨月跨年閏年都對" {
  [ "$(dk_ts_minutes 1970-01-01T00:00)" = 0 ]
  [ "$(( $(dk_ts_minutes 2026-09-20T00:00) - $(dk_ts_minutes 2026-09-19T00:00) ))" = 1440 ]
  [ "$(( $(dk_ts_minutes 2026-02-01T01:00) - $(dk_ts_minutes 2026-01-31T23:00) ))" = 120 ]      # 跨月
  [ "$(( $(dk_ts_minutes 2026-01-01T00:00) - $(dk_ts_minutes 2025-12-31T23:59) ))" = 1 ]        # 跨年
  [ "$(( $(dk_ts_minutes 2024-03-01T00:00) - $(dk_ts_minutes 2024-02-28T00:00) ))" = 2880 ]     # 閏年多一天
  [ "$(( $(dk_ts_minutes 2026-03-01T00:00) - $(dk_ts_minutes 2026-02-28T00:00) ))" = 1440 ]
  [ "$(( $(dk_ts_minutes 2000-03-01T00:00) - $(dk_ts_minutes 2000-02-28T00:00) ))" = 2880 ]     # 400 的倍數是閏年
  [ "$(( $(dk_ts_minutes 1900-03-01T00:00) - $(dk_ts_minutes 1900-02-28T00:00) ))" = 1440 ]     # 100 的倍數不是
  [ "$(dk_ts_minutes 2026-09-08T08:09)" = "$(( $(dk_ts_minutes 2026-09-08T00:00) + 489 ))" ]    # 08/09 不可當八進位
  run dk_ts_minutes 2026-09-19; [ "$status" -ne 0 ]; [ -z "$output" ]
  run dk_ts_minutes "2026-13-01T00:00"; [ "$status" -ne 0 ]
}

@test "AC8 highfix：與人手算的數字逐列一致" {
  use_fixture highfix highfix
  run dk-timeline highfix; [ "$status" -eq 0 ]
  [[ "$output" == *"| 任務 | 2026-09-19T20:39 | 2026-09-19T21:45 | 66m | — | — |"* ]]
  [[ "$output" == *"| 計畫 | 2026-09-19T20:39 | 2026-09-19T20:45 | 6m | — | — |"* ]]
  [[ "$output" == *"| 波 1 | 2026-09-19T20:45 | 2026-09-19T21:12 | 27m | 19m | 7m |"* ]]
  [[ "$output" == *"| 波 2 | 2026-09-19T21:23 | 2026-09-19T21:39 | 16m | 1m | 3m |"* ]]
  [[ "$output" == *"| 結案 | 2026-09-19T21:39 | 2026-09-19T21:45 | 6m | — | — |"* ]]
}

@test "AC8 flowgap：四波、審查取最後一則 verdict、關波取最後一次 wave-close" {
  use_fixture flowgap flowgap
  run dk-timeline flowgap; [ "$status" -eq 0 ]
  [[ "$output" == *"| 任務 | 2026-09-19T14:32 | 2026-09-19T19:11 | 279m | — | — |"* ]]
  [[ "$output" == *"| 計畫 | 2026-09-19T14:32 | 2026-09-19T14:47 | 15m | — | — |"* ]]
  [[ "$output" == *"| 波 1 | 2026-09-19T14:47 | 2026-09-19T17:15 | 148m | 22m | 125m |"* ]]   # 15:37 那次 wave-close 是失敗的，取最後一次
  [[ "$output" == *"| 波 2 | 2026-09-19T17:15 | 2026-09-19T17:31 | 16m | 1m | 4m |"* ]]
  [[ "$output" == *"| 波 3 | 2026-09-19T17:31 | 2026-09-19T17:52 | 21m | 0m | 5m |"* ]]
  [[ "$output" == *"| 波 4 | 2026-09-19T18:06 | 2026-09-19T18:29 | 23m | 0m | 6m |"* ]]
  [[ "$output" == *"| 結案 | 2026-09-19T18:29 | 2026-09-19T19:11 | 42m | — | — |"* ]]
}

@test "AC8 跨日樣本：日期進位，時長與 highfix 逐欄相同" {
  use_fixture crossday crossday
  run dk-timeline crossday; [ "$status" -eq 0 ]
  [[ "$output" == *"| 任務 | 2026-09-19T23:39 | 2026-09-20T00:45 | 66m | — | — |"* ]]
  [[ "$output" == *"| 波 1 | 2026-09-19T23:45 | 2026-09-20T00:12 | 27m | 19m | 7m |"* ]]
  [[ "$output" == *"| 波 2 | 2026-09-20T00:23 | 2026-09-20T00:39 | 16m | 1m | 3m |"* ]]
}

@test "AC7 未結案的任務算到現在並標進行中；缺來源印 —" {
  use_fixture highfix live
  sed -i '/ task-close /d' "$DK_ROOT/tasks/2026-09-19-live/process.md"
  sed -i '/ dev-done wave 2 /d; / review 2 spawned /d; / review 2 verdict /d' "$DK_ROOT/tasks/2026-09-19-live/process.md"
  run dk-timeline live; [ "$status" -eq 0 ]
  [[ "$output" == *"（進行中）"* ]]
  [[ "$output" == *"| 波 2 | 2026-09-19T21:23 | 2026-09-19T21:39 | 16m | — | — |"* ]]
  [[ "$output" == *"| 結案 | 2026-09-19T21:39 | — | — | — | — |"* ]]
}

@test "AC7 只讀：零 token、不寫任何檔，沒帶參數就讀綁定的任務" {
  use_fixture highfix highfix
  before=$(find "$DK_ROOT" -type f | sort); : > "$HERDR_STUB_LOG"
  run dk-timeline highfix; [ "$status" -eq 0 ]
  [ ! -s "$HERDR_STUB_LOG" ]                       # 一次 herdr 都沒呼叫
  [ "$(find "$DK_ROOT" -type f | sort)" = "$before" ]
  echo "2026-09-19T10:00 task-new login" > "$d/process.md"
  run dk-timeline; [ "$status" -eq 0 ]; [[ "$output" == *"| 任務 | 2026-09-19T10:00 |"* ]]
  run dk-timeline nosuchtask; [ "$status" -eq 1 ]
}

@test "AC10 文件：dk-timeline 在 SKILL 與三份 README 都有一句" {
  grep -q 'dk-timeline' "$REPO_ROOT/.dkbo/skills/run/SKILL.md"
  for f in .dkbo/README.md README.md README.en.md; do grep -q 'dk-timeline' "$REPO_ROOT/$f"; done
}
@test "AC14 文件：解除熔斷那條寫明標記檔不要刪" {
  grep -q '同任務內解除熔斷' "$REPO_ROOT/.dkbo/skills/run/SKILL.md"
  grep -q '標記檔不要刪' "$REPO_ROOT/.dkbo/skills/run/SKILL.md"
}
