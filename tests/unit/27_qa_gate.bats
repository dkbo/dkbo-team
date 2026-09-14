load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入); export DK_TASK_DIR="$d"
  fixture_brief "$d"                       # 波 1 = backend（group dev）＋ qa（group review）
  sed -i 's/^DK_WAVE=.*/DK_WAVE="1"/' "$d/.task.env"
}
teardown() { teardown_project; }
prompt_of() { grep "^agent prompt $1 " "$HERDR_STUB_LOG" | tail -1; }

@test "dk_brief_wave_upstream 只挑出同波裡 group=dev 的成員" {
  run bash -c '. "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/frontmatter.sh"; . "$DK_ROOT/lib/brief.sh"
               dk_brief_wave_upstream "'"$d"'/brief.md" 1 | tr "\n" " "'
  [ "$status" -eq 0 ]
  [[ "$output" == *backend* ]]          # dev
  [[ "$output" != *qa* ]]               # 自己不算自己的上游
}
@test "第 2 波的上游是那一波的 dev，不是第 1 波的" {
  run bash -c '. "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/frontmatter.sh"; . "$DK_ROOT/lib/brief.sh"
               dk_brief_wave_upstream "'"$d"'/brief.md" 2 | tr "\n" " "'
  [ "$status" -eq 0 ]; [[ "$output" == *frontend-cart* ]]; [[ "$output" != *backend* ]]
}

@test "qa 的首輪提示指名本波的 dev，並擋住對半成品下判定" {
  run dk-spawn qa; [ "$status" -eq 0 ]
  p=$(prompt_of login-qa)
  [[ "$p" == *backend* ]]
  [[ "$p" == *"status: done"* ]]
  [[ "$p" == *"半成品"* ]]
}
@test "dev 自己的提示不帶這段：它不等任何人" {
  run dk-spawn backend; [ "$status" -eq 0 ]
  p=$(prompt_of login-backend)
  [[ "$p" != *"半成品"* ]]
}
@test "reviewer 不在波次表裡，不該被塞上游" {
  run dk-spawn reviewer a --isolated; [ "$status" -eq 0 ]
  p=$(prompt_of login-reviewer-a)
  [[ "$p" != *"半成品"* ]]
}
@test "沒綁波次時 qa 照常起得來，只是沒有上游那段" {
  sed -i 's/^DK_WAVE=.*/DK_WAVE=""/' "$d/.task.env"
  run dk-spawn qa; [ "$status" -eq 0 ]
  [[ "$(prompt_of login-qa)" != *"半成品"* ]]
}
@test "波次表裡沒有 dev 的一波（純 qa）不會生出空的上游句" {
  sed -i 's/^| 1 | 實作 | backend | POST \/login | M | 測試過 | 預設 |$//' "$d/brief.md"
  run dk-spawn qa; [ "$status" -eq 0 ]
  [[ "$(prompt_of login-qa)" != *"半成品"* ]]
}

@test "roles/qa.md 把「等 dev 交差再判定」寫成硬性做法" {
  grep -q 'status: done' "$DK_ROOT/roles/qa.md"
  grep -qE '前置|不下判定|不要下' "$DK_ROOT/roles/qa.md"
}
