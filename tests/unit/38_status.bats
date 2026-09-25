load ../helpers
# dk-status --json：唯讀把任務記憶轉成 JSON 給 dashboard。夾具三個任務資料夾：
#   <今天>-alpha  已結案（INDEX done、一波、task-close merged）
#   <今天>-beta   進行中（INDEX running、波 2 開著、.panes 兩列、state 兩位、ruling [自主]＋一般、
#                 一則 [UNDELIVERED]、一行壞 process 行、三行壞 messages 行）
#   2026-01-01-beta  舊日期的同短名空資料夾（短名解析取日期最晚；缺檔容錯）
setup() {
  setup_project
  TODAY=$(date +%Y-%m-%d)
  a=$(fixture_task alpha 已完成任務)
  b=$(fixture_task beta '進行中|任務')
  old="$DK_ROOT/tasks/2026-01-01-beta"; mkdir -p "$old"
  status_fixture
}
teardown() { teardown_project; }

status_fixture() {
  printf '| %s | 已完成任務 | task | done | merged abc1234 |\n' "$TODAY" >> "$DK_ROOT/tasks/INDEX.md"
  printf '| %s | 進行中／任務 | task | running | — |\n' "$TODAY" >> "$DK_ROOT/tasks/INDEX.md"
  cat > "$a/process.md" <<'P'
2026-09-25T08:00 task-new alpha
2026-09-25T08:05 gate1 approved
2026-09-25T08:06 wave-open 1 base abc1234 members backend(M)
2026-09-25T08:20 dev-done wave 1 (1: backend)
2026-09-25T08:21 review 1 spawned alpha-reviewer-a(claude)
2026-09-25T08:30 review 1 verdict a: ok
2026-09-25T08:31 wave-close 1 tests ok (tests/run.sh) 2 agents closed
2026-09-25T08:31 commit failed wave 1
2026-09-25T08:32 commit abc1234 wave 1
2026-09-25T08:32 commit 5678def wave 1 repo api
2026-09-25T08:40 task-close merge-failed merged: failed: main not-attempted:
2026-09-25T08:50 task-close merged abc1234
P
  sed -i 's/^DK_TASK_TAB=.*/DK_TASK_TAB="wB:t9"/; s/^DK_WAVE=.*/DK_WAVE="2"/' "$b/.task.env"
  cat > "$b/brief.md" <<'B'
# 進行中|任務
來源：test

## 目標（≤3 行）
讓 dashboard 讀 JSON。
第二行目標。

## 全域約束
bash 3.2+

## 驗收標準
- [x] AC1 已完成的一條
- [ ] AC2 還沒做 "引號" a\|b

## 檔案所有權
| 成員 | 可改 | 只讀 | 獨佔資源 |
|---|---|---|---|
| （範例）backend | src/api/**, db/** | src/web/** | db, port:3000 |
| backend | src/api/**, db/** | src/web/** | db, port:3000 |
| frontend-cart | src/web/** | — | |

## 共用契約
| 契約 | 擁有者 | 消費者 | 形狀／簽名 | 變更流程 |
|---|---|---|---|---|
| login API | backend | frontend-cart | POST /login | 動它要先 ESCALATE |

## 波次表
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
| （範例）1 | 實作 | backend | API | M | 測試過 | 預設 |
| 1 | 實作 | backend | 解析 a\|b | M | 測試過 | 預設 |
| 1 | 實作 | qa | 驗 API | S | 全過 | |
| 2 | 實作 | frontend-cart | 表單 | S | 可用 | kinds: claude codex |
B
  printf '%s\n' \
    '2026-09-25T09:00 task-new beta' \
    '2026-09-25T09:05 ruling: [自主] 引號 "q" 反斜線 \n\ 分頁	tab $(touch "$PROJECT/pwned") 中文 🚀 — 若錯代價：無' \
    '2026-09-25T09:06 ruling: 一般裁定 — 若錯代價：無' \
    '2026-09-25T09:07 gate1 approved' \
    '2026-09-25T09:08 wave-open 1 base abc1234 members backend(M) qa(S)' \
    '2026-09-25T09:20 dev-done wave 1 (2: backend, qa)' \
    '2026-09-25T09:21 review 1 spawned beta-reviewer-a(claude)' \
    '2026-09-25T09:25 violation unowned: src/x.ts' \
    '2026-09-25T09:26 wave-close 1 tests failed (tests/run.sh)' \
    '2026-09-25T09:30 review 1 verdict a: important 1' \
    '2026-09-25T09:31 minor 1: 某個 minor src/api/a.ts:3' \
    '2026-09-25T09:40 review 1 verdict a: ok' \
    '2026-09-25T09:45 wave-close 1 tests ok (tests/run.sh) 2 agents closed' \
    '2026-09-25T09:45 commit 1234abc wave 1' \
    '2026-09-25T09:46 wave-open 2 base 1234abc members frontend-cart(S)' \
    '這一行沒有時間戳' \
    '2026-09-25T09:47 review 2 skipped: 單人小波' \
    '2026-09-25T09:50 unreported src/web/a.ts (owner frontend-cart)' > "$b/process.md"
  printf '%s\n' \
    '2026-09-25T09:20 beta-backend -> leader-beta [DONE] 完成 "引號" \反斜線	tab $(touch "$PROJECT/pwned") 🚀' \
    '2026-09-25T09:21 leader-beta [ACK]' \
    '2026-09-25T09:22 beta-backend -> qa [UNDELIVERED] [DONE] 沒送到' \
    'garbage line without ts' \
    '2026-09-25T09:23 beta-qa -> leader-beta [ESCALATE] 需要決策' \
    '2026-09-25T09:24 malformed-no-type' \
    '內文的續行沒有時間戳' > "$b/messages.log"
  printf 'beta-frontend-cart wB:p7 1790000000 dev 1 2\nbeta-qa wB:p8\n' > "$b/.panes"
  cat > "$b/state/backend.md" <<'S'
status: done
wave: 1
current: 完成
touched:
  - src/api/login.ts
  - db/schema.sql
todo: []
report: state/backend.report.md
notes: 第一行
  縮排續行
notes: 第二則 notes
S
  echo '# 報告' > "$b/state/backend.report.md"
  printf '%s\n' \
    'status: working' \
    'wave: 二' \
    'current: 做 "表單" \x	tab $(touch "$PROJECT/pwned") 中文 🚀' \
    'touched: []' \
    'blocked_by: 等 backend 的 API' \
    'notes: 引號 "n" \反斜線	tab $(touch "$PROJECT/pwned") 🚀' > "$b/state/frontend-cart.md"
  now=$(date +%s)
  printf '%s\n' \
    "codex $((now + 7200)) exact 2026-09-25T09:00 $TODAY-beta beta-backend usage limit reached" \
    "agy $((now - 60)) guess 2026-09-25T08:00 $TODAY-beta beta-qa quota exceeded" \
    "claude $((now + 3600)) guess 2026-09-25T09:10 $TODAY-alpha alpha-backend rate limit" > "$DK_ROOT/.sessions/kinds-down"
  CODEX_EPOCH=$((now + 7200))
}
detail() { dk-status --json "$1" | jq -c "${2:-.}"; }
SUMMARY_KEYS='["branch","close_result","closed_at","counts","created_at","current_wave","date","dir","display","gate1_at","index_note","panes_open","repo_names","short","status","task_tab","updated_at","waves_closed","waves_planned","worktree"]'

@test "AC1 介面：list／detail 單行 JSON＋換行 exit 0；資料夾名或短名（短名取日期最晚）" {
  run dk-status --json; [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l)" -eq 1 ]
  [ "$output" = "$(jq -c . <<< "$output")" ]
  dk-status --json > "$PROJECT/.out"; [ "$(tail -c 1 "$PROJECT/.out" | od -An -c | tr -d ' ')" = '\n' ]
  run dk-status --json beta; [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l)" -eq 1 ]
  [ "$(jq -r .task.dir <<< "$output")" = "$TODAY-beta" ]
  run dk-status --json 2026-01-01-beta; [ "$status" -eq 0 ]; [ "$(jq -r .task.dir <<< "$output")" = 2026-01-01-beta ]
  run dk-status --json "$TODAY-alpha"; [ "$status" -eq 0 ]; [ "$(jq -r .task.short <<< "$output")" = alpha ]
}

@test "AC1 用法錯 exit 2、找不到任務 exit 1，訊息逐字" {
  msg='dk-status: 目前只支援 --json（用法：dk-status --json [<任務>]）'
  for args in "" "--text" "beta" "beta --json" "--json beta extra" "--json --foo" "-j"; do
    # shellcheck disable=SC2086
    run dk-status $args; [ "$status" -eq 2 ]; [ "$output" = "$msg" ]
  done
  for x in nosuch _chores . .. BACKLOG.md INDEX.md 2026-09-25 "$TODAY-" 2026-01-01-nosuch ../tasks; do
    run dk-status --json "$x"; [ "$status" -eq 1 ]; [ "$output" = "dk: no task '$x'" ]
  done
  mkdir -p "$DK_ROOT/tasks/_chores/2026-09-25"
  run dk-status --json _chores; [ "$status" -eq 1 ]
}

@test "AC2 list：頂層鍵恰為五個、版本去空白、任務依資料夾名升冪且不含 _chores／BACKLOG" {
  mkdir -p "$DK_ROOT/tasks/_chores/2026-09-25"; mkdir -p "$DK_ROOT/tasks/notatask"
  out=$(dk-status --json)
  [ "$(jq -c 'keys' <<< "$out")" = '["dkbo_version","generated_at","kinds_down","schema_version","tasks"]' ]
  [ "$(jq -c '.schema_version' <<< "$out")" = 1 ]
  [ "$(jq -r '.dkbo_version' <<< "$out")" = "$(tr -d '[:space:]' < "$DK_ROOT/VERSION")" ]
  [[ "$(jq -r '.generated_at' <<< "$out")" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}$ ]]
  # 夾具帶著主樹已追蹤的歷史任務資料夾，所以期望值從檔案系統算；notatask、_chores、BACKLOG.md 不在裡面
  want=$(cd "$DK_ROOT/tasks" && ls -d [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-* | LC_ALL=C sort | jq -R -s -c 'split("\n") | map(select(. != ""))')
  [ "$(jq -c '[.tasks[].dir]' <<< "$out")" = "$want" ]
  [ "$(jq -c '[.tasks[].dir | select(. == "2026-01-01-beta" or . == "'"$TODAY"'-alpha" or . == "'"$TODAY"'-beta")]' <<< "$out")" = "[\"2026-01-01-beta\",\"$TODAY-alpha\",\"$TODAY-beta\"]" ]
  [ "$(jq -c '[.tasks[] | keys] | unique' <<< "$out")" = "[$SUMMARY_KEYS]" ]
  printf ' 9.9.9 \n\n' > "$DK_ROOT/VERSION"
  [ "$(dk-status --json | jq -r .dkbo_version)" = 9.9.9 ]
  rm "$DK_ROOT/VERSION"
  [ "$(dk-status --json | jq -c .dkbo_version)" = null ]
  [ "$(dk-status --json beta | jq -c .dkbo_version)" = null ]
}

@test "AC2 kinds_down：只列未過期、依 kind 升冪、形狀與本地時間經 dk_epoch_to_local" {
  out=$(dk-status --json)
  [ "$(jq -c '[.kinds_down[].kind]' <<< "$out")" = '["claude","codex"]' ]
  [ "$(jq -c '.kinds_down[1] | keys' <<< "$out")" = '["agent","exact","from_task","kind","reason","recorded_at","until","until_epoch"]' ]
  [ "$(jq -c '.kinds_down[1] | [.until_epoch, .exact, .recorded_at, .from_task, .agent, .reason]' <<< "$out")" = "[$CODEX_EPOCH,true,\"2026-09-25T09:00\",\"$TODAY-beta\",\"beta-backend\",\"usage limit reached\"]" ]
  [ "$(jq -c '.kinds_down[0].exact' <<< "$out")" = false ]
  want=$( . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/kinds.sh"; dk_epoch_to_local "$CODEX_EPOCH")
  [ "$(jq -r '.kinds_down[1].until' <<< "$out")" = "$want" ]
  [ "$(dk-status --json beta | jq -c '[.kinds_down[].kind]')" = '["claude","codex"]' ]
  rm "$DK_ROOT/.sessions/kinds-down"
  [ "$(dk-status --json | jq -c .kinds_down)" = '[]' ]
}

@test "AC3 detail：頂層鍵恰為五個；task＝摘要全部欄位＋九個詳情欄位，摘要值與 list 那一筆相同" {
  out=$(dk-status --json beta)
  [ "$(jq -c 'keys' <<< "$out")" = '["dkbo_version","generated_at","kinds_down","schema_version","task"]' ]
  [ "$(jq -c '.schema_version' <<< "$out")" = 1 ]
  want=$(jq -c --argjson s "$SUMMARY_KEYS" -n '$s + ["brief","events","members","messages","panes","repos","rulings","skipped_lines","waves"] | sort')
  [ "$(jq -c '.task | keys' <<< "$out")" = "$want" ]
  sum=$(dk-status --json | jq -c --arg d "$TODAY-beta" '.tasks[] | select(.dir == $d)')
  [ "$(jq -c --argjson s "$SUMMARY_KEYS" '.task as $t | reduce $s[] as $k ({}; .[$k] = $t[$k])' <<< "$out")" = "$(jq -c --argjson s "$SUMMARY_KEYS" '. as $t | reduce $s[] as $k ({}; .[$k] = $t[$k])' <<< "$sum")" ]
}

@test "AC4 摘要欄位：INDEX 狀態（| 存成 ／）、.task.env、波數、時間戳、counts" {
  s=$(detail beta '.task')
  [ "$(jq -c '[.dir, .short, .display, .date, .status, .index_note, .branch, .task_tab, .current_wave]' <<< "$s")" = "[\"$TODAY-beta\",\"beta\",\"進行中|任務\",\"$TODAY\",\"running\",\"—\",\"dk/beta\",\"wB:t9\",2]" ]
  [ "$(jq -r .worktree <<< "$s")" = "$WORKTREE_PATH" ]
  [ "$(jq -c .repo_names <<< "$s")" = '["main"]' ]
  [ "$(jq -c '[.waves_planned, .waves_closed, .panes_open]' <<< "$s")" = '[2,1,2]' ]
  [ "$(jq -c '[.created_at, .gate1_at, .closed_at, .close_result, .updated_at]' <<< "$s")" = '["2026-09-25T09:00","2026-09-25T09:07",null,null,"2026-09-25T09:50"]' ]
  [ "$(jq -c .counts <<< "$s")" = '{"rulings":2,"autonomous_rulings":1,"minors":1,"undelivered":1,"escalations":1}' ]
  s=$(detail alpha '.task')
  [ "$(jq -c '[.status, .index_note, .closed_at, .close_result, .waves_closed, .current_wave]' <<< "$s")" = '["done","merged abc1234","2026-09-25T08:50","merged abc1234",1,null]' ]
  # INDEX 沒有那一列就是 unknown
  sed -i '/已完成任務/d' "$DK_ROOT/tasks/INDEX.md"
  [ "$(detail alpha '.task | [.status, .index_note]')" = '["unknown",null]' ]
  # 結案只認 merged／in-tree／abandoned:；merge-failed 與 local-changes: 不算
  printf '2026-09-25T09:00 task-close local-changes: main\n' >> "$a/process.md"
  [ "$(detail alpha '.task.closed_at')" = '"2026-09-25T08:50"' ]
  printf '2026-09-25T09:10 task-close abandoned: 不做了\n' >> "$a/process.md"
  [ "$(detail alpha '.task | [.closed_at, .close_result]')" = '["2026-09-25T09:10","abandoned: 不做了"]' ]
}

@test "AC4 waves[]：時間戳與 dk_ts_pick／dk-timeline 一致（flowgap 真 log），關閉 ⟺ agents closed" {
  mkdir -p "$DK_ROOT/tasks/2026-09-19-flowgap"
  cp "$REPO_ROOT/tests/fixtures/flowgap-process.md" "$DK_ROOT/tasks/2026-09-19-flowgap/process.md"
  p="$DK_ROOT/tasks/2026-09-19-flowgap/process.md"
  out=$(detail flowgap '.task.waves')
  . "$DK_ROOT/lib/common.sh"
  for n in $(jq -r '.[].wave' <<< "$out"); do
    w=$(jq -c --argjson n "$n" '.[] | select(.wave == $n)' <<< "$out")
    [ "$(jq -r '.opened_at // ""' <<< "$w")" = "$(dk_ts_pick "$p" wave-open "$n")" ]
    [ "$(jq -r '.dev_done_at // ""' <<< "$w")" = "$(dk_ts_pick "$p" dev-done wave "$n")" ]
    [ "$(jq -r '.review_spawned_at // ""' <<< "$w")" = "$(dk_ts_pick "$p" review "$n" spawned)" ]
    [ "$(jq -r '.review_verdict_at // ""' <<< "$w")" = "$(dk_ts_pick "$p" review "$n" verdict)" ]
  done
  [ "$(jq -c '[.[].wave]' <<< "$out")" = '[1,2,3,4]' ]
  # 波 1 在 15:37 失敗過一次（沒有 agents closed），真正關掉的是 17:15 那次，與 dk-timeline 的波 1 列一致
  [ "$(jq -c '.[0] | [.closed_at, .tests, .tests_ok, .commits]' <<< "$out")" = '["2026-09-19T17:15","ok (tests/run.sh)",true,[{"repo":null,"sha":"ae24f02"}]]' ]
  dk-timeline flowgap | grep -qF '| 波 1 | 2026-09-19T14:47 | 2026-09-19T17:15 |'
  w=$(detail beta '.task.waves')
  [ "$(jq -c '[.[].wave]' <<< "$w")" = '[1,2]' ]
  [ "$(jq -c '.[0] | [.opened_at, .dev_done_at, .review_spawned_at, .review_verdict_at, .review_verdict, .closed_at, .tests, .tests_ok]' <<< "$w")" = '["2026-09-25T09:08","2026-09-25T09:20","2026-09-25T09:21","2026-09-25T09:40","a: ok","2026-09-25T09:45","ok (tests/run.sh)",true]' ]
  [ "$(jq -c '.[1] | [.opened_at, .review_verdict, .closed_at, .tests, .tests_ok, .commits]' <<< "$w")" = '["2026-09-25T09:46","skipped: 單人小波",null,null,null,[]]' ]
  # 只有失敗行（未強關）的波不算關閉；強關的失敗行算關閉但 tests_ok=false
  printf '2026-09-25T10:00 wave-close 2 tests failed (tests/run.sh)\n' >> "$b/process.md"
  [ "$(detail beta '.task | [.waves[1].closed_at, .waves_closed]')" = '[null,1]' ]
  printf '2026-09-25T10:05 wave-close 2 tests failed (tests/run.sh) 1 agents closed\n' >> "$b/process.md"
  [ "$(detail beta '.task | [.waves[1].closed_at, .waves[1].tests, .waves[1].tests_ok, .waves_closed]')" = '["2026-09-25T10:05","failed (tests/run.sh)",false,2]' ]
  # commits：略過 commit failed、帶 repo 的列給 repo 名
  [ "$(detail alpha '.task.waves[0].commits')" = '[{"repo":null,"sha":"abc1234"},{"repo":"api","sha":"5678def"}]' ]
  # 波號取 brief 與 process 的聯集：只在 process 出現的波 3 也要列
  printf '2026-09-25T10:10 wave-open 3 base 1 members x(S)\n' >> "$b/process.md"
  [ "$(detail beta '[.task.waves[].wave]')" = '[1,2,3]' ]
}

@test "AC4 members／panes／rulings／events／messages／repos／brief 的內容" {
  t=$(detail beta '.task')
  [ "$(jq -c '[.members[].name]' <<< "$t")" = '["backend","frontend-cart"]' ]
  [ "$(jq -c '.members[0] | [.status, .wave, .current, .touched, .todo, .blocked_by, .notes, .has_report]' <<< "$t")" = '["done",1,"完成",["src/api/login.ts","db/schema.sql"],[],null,"第一行\n縮排續行\n第二則 notes",true]' ]
  [ "$(jq -c '.members[1] | [.status, .wave, .touched, .todo, .blocked_by, .has_report]' <<< "$t")" = '["working",null,[],[],"等 backend 的 API",false]' ]
  [ "$(jq -c '.panes' <<< "$t")" = '[{"agent":"beta-frontend-cart","pane":"wB:p7","since_epoch":1790000000,"group":"dev","tab":"1","slot":"2"},{"agent":"beta-qa","pane":"wB:p8","since_epoch":null,"group":null,"tab":null,"slot":null}]' ]
  [ "$(jq -c '[.rulings[] | [.ts, .autonomous]]' <<< "$t")" = '[["2026-09-25T09:05",true],["2026-09-25T09:06",false]]' ]
  [ "$(jq -r '.rulings[1].text' <<< "$t")" = '一般裁定 — 若錯代價：無' ]
  [ "$(jq -c '.events | length' <<< "$t")" = 17 ]
  [ "$(jq -c '.events[7]' <<< "$t")" = '{"ts":"2026-09-25T09:25","kind":"violation","text":"violation unowned: src/x.ts"}' ]
  [ "$(jq -c '[.events[] | select(.kind == "unreported" or .kind == "ruling") | .kind]' <<< "$t")" = '["ruling","ruling","unreported"]' ]
  [ "$(jq -c '.messages[1:4]' <<< "$t")" = '[{"ts":"2026-09-25T09:21","from":"leader-beta","to":null,"type":"ACK","text":""},{"ts":"2026-09-25T09:22","from":"beta-backend","to":"qa","type":"UNDELIVERED","text":"[DONE] 沒送到"},{"ts":"2026-09-25T09:23","from":"beta-qa","to":"leader-beta","type":"ESCALATE","text":"需要決策"}]' ]
  [ "$(jq -c '.repos' <<< "$t")" = "[{\"name\":\"main\",\"path\":\"$PROJECT\",\"worktree\":\"$WORKTREE_PATH\",\"base\":\"$(git -C "$PROJECT" rev-parse HEAD)\"}]" ]
  [ "$(jq -c '.brief.goal' <<< "$t")" = '"讓 dashboard 讀 JSON。\n第二行目標。"' ]
  [ "$(jq -c '.brief.acceptance' <<< "$t")" = '[{"text":"AC1 已完成的一條","checked":true},{"text":"AC2 還沒做 \"引號\" a\\|b","checked":false}]' ]
  [ "$(jq -c '.brief.owners' <<< "$t")" = '[{"member":"backend","writable":["src/api/**","db/**"],"readonly":["src/web/**"],"exclusive":["db","port:3000"]},{"member":"frontend-cart","writable":["src/web/**"],"readonly":[],"exclusive":[]}]' ]
  [ "$(jq -c '.brief.waves[0]' <<< "$t")" = '{"wave":1,"type":"實作","member":"backend","what":"解析 a|b","tier":"M","done":"測試過","review":"預設"}' ]
  [ "$(jq -c '.brief.waves[1:] | map(.review)' <<< "$t")" = '[null,"kinds: claude codex"]' ]
  [ "$(jq -c '.skipped_lines' <<< "$t")" = '{"process":1,"messages":3}' ]
}

@test "AC5 容錯：缺檔給 null／[]、壞行計進 skipped_lines、state 缺鍵給 null" {
  t=$(detail 2026-01-01-beta '.task')
  [ "$(jq -c '[.short, .display, .date, .status, .index_note, .branch, .worktree, .task_tab, .current_wave, .created_at, .gate1_at, .closed_at, .close_result, .updated_at]' <<< "$t")" = '["beta",null,"2026-01-01","unknown",null,null,null,null,null,null,null,null,null,null]' ]
  [ "$(jq -c '[.repo_names, .waves_planned, .waves_closed, .panes_open, .repos, .waves, .members, .panes, .rulings, .events, .messages]' <<< "$t")" = '[[],0,0,0,[],[],[],[],[],[],[]]' ]
  [ "$(jq -c '.brief' <<< "$t")" = '{"goal":null,"acceptance":[],"owners":[],"waves":[]}' ]
  [ "$(jq -c '.counts' <<< "$t")" = '{"rulings":0,"autonomous_rulings":0,"minors":0,"undelivered":0,"escalations":0}' ]
  [ "$(jq -c '.skipped_lines' <<< "$t")" = '{"process":0,"messages":0}' ]
  mkdir "$old/state"; : > "$old/state/empty.md"; : > "$old/.task.env"
  [ "$(detail 2026-01-01-beta '.task.members')" = '[{"name":"empty","status":null,"wave":null,"current":null,"touched":[],"todo":[],"blocked_by":null,"notes":null,"has_report":false}]' ]
  # 每一個檔各拿掉一次，兩種模式都不報錯
  for f in brief.md process.md messages.log state .panes .repos .task.env; do
    rm -r "$b/$f"
    run dk-status --json beta; [ "$status" -eq 0 ]; jq -e .task <<< "$output" >/dev/null
    run dk-status --json; [ "$status" -eq 0 ]; jq -e .tasks <<< "$output" >/dev/null
  done
  [ "$(detail beta '.task | [.display, .status, .skipped_lines]')" = '[null,"unknown",{"process":0,"messages":0}]' ]
}

@test "AC6 JSON 安全：引號、反斜線、tab、\$(...)、中文與 emoji 逐字取回" {
  out=$(dk-status --json beta)
  jq -e . <<< "$out" >/dev/null
  [ "$(jq -r '.task.rulings[0].text' <<< "$out")" = "$(sed -n 2p "$b/process.md" | sed 's/^[^ ]* ruling: //')" ]
  [ "$(jq -r '.task.events[1].text' <<< "$out")" = "$(sed -n 2p "$b/process.md" | cut -d' ' -f2-)" ]
  [ "$(jq -r '.task.messages[0].text' <<< "$out")" = "$(sed -n 1p "$b/messages.log" | sed 's/^.*\[DONE\] //')" ]
  [ "$(jq -r '.task.members[1].current' <<< "$out")" = "$(sed -n 's/^current: //p' "$b/state/frontend-cart.md")" ]
  [ "$(jq -r '.task.members[1].notes' <<< "$out")" = "$(sed -n 's/^notes: //p' "$b/state/frontend-cart.md")" ]
  [ "$(jq -r '.task.display' <<< "$out")" = '進行中|任務' ]
  [ ! -e "$PROJECT/pwned" ]   # 夾具裡的 $(touch …) 若被 shell 求值就會建出這個檔
  jq -e . <<< "$(dk-status --json)" >/dev/null
}

@test "AC7 唯讀：不寫任何檔、不叫 herdr；herdr 外（HERDR_ENV／HERDR_PANE_ID unset）照樣成功" {
  unset HERDR_ENV HERDR_PANE_ID
  before=$(cd "$DK_ROOT" && find . | sort)
  touch "$PROJECT/.marker"; sleep 1
  : > "$HERDR_STUB_LOG"
  run dk-status --json; [ "$status" -eq 0 ]; jq -e .tasks <<< "$output" >/dev/null
  run dk-status --json beta; [ "$status" -eq 0 ]; jq -e .task <<< "$output" >/dev/null
  run dk-status --json nosuch; [ "$status" -eq 1 ]
  [ -z "$(find "$DK_ROOT" -newer "$PROJECT/.marker")" ]
  [ "$(cd "$DK_ROOT" && find . | sort)" = "$before" ]
  [ ! -s "$HERDR_STUB_LOG" ]
  # 註解可以提到這些名字，程式碼不行：不叫 herdr／dk-watch、不綁 session、不看 HERDR_*
  refute_grep -E 'herdr|dk-watch|dk_require_herdr|dk_task_dir|dk_task_env|\.sessions/\$|HERDR_' <(grep -v '^[[:space:]]*#' "$REPO_ROOT/.dkbo/bin/dk-status")
}

@test "AC8 status-schema.md：相容規則、三件事，且輸出的每一個鍵名都寫在文件裡（反向防漂移）" {
  s="$REPO_ROOT/.dkbo/status-schema.md"
  [ -f "$s" ]
  grep -q 'schema_version' "$s"
  grep -q '只加欄位不升' "$s"
  grep -q '忽略' "$s"
  grep -q 'until_epoch' "$s"; grep -q '本地時間' "$s"
  grep -q '續行' "$s"; grep -q 'skipped_lines.messages' "$s"
  for k in wave-close violation unreported review; do grep -qF "\`$k\`" "$s"; done
  keys=$( { dk-status --json; dk-status --json beta; dk-status --json alpha; } | jq -r '[paths | .[] | strings] | unique | .[]' | sort -u)
  [ -n "$keys" ]
  miss=""
  while IFS= read -r k; do grep -qF "\`$k\`" "$s" || miss="$miss $k"; done <<< "$keys"
  [ -z "$miss" ] || { echo "status-schema.md 缺鍵:$miss" >&2; false; }
}

@test "AC9 list 不逐行叫 jq：呼叫次數對任務數線性（≤ 常數×N）且與 process 行數無關" {
  real=$(command -v jq)
  mkdir -p "$PROJECT/.jqwrap"
  printf '#!/usr/bin/env bash\necho x >> "%s/.jqcount"\nexec "%s" "$@"\n' "$PROJECT" "$real" > "$PROJECT/.jqwrap/jq"
  chmod +x "$PROJECT/.jqwrap/jq"
  count() { : > "$PROJECT/.jqcount"; PATH="$PROJECT/.jqwrap:$PATH" dk-status --json >/dev/null || return 1; wc -l < "$PROJECT/.jqcount"; }
  mk() { # N 起始序號 行數
    local i j d
    for ((i = $2; i < $2 + $1; i++)); do
      d="$DK_ROOT/tasks/2026-02-01-t$i"; mkdir -p "$d/state"
      for ((j = 0; j < $3 + i; j++)); do echo "2026-02-01T00:00 ruling: r$j"; done > "$d/process.md"
      printf '2026-02-01T00:00 a -> b [DONE] x\n' > "$d/messages.log"
      printf 'status: done\n' > "$d/state/m.md"
    done
  }
  c0=$(count); [ "$c0" -gt 0 ]
  mk 3 0 5;  c1=$(count)
  mk 3 3 50; c2=$(count)
  for f in "$DK_ROOT"/tasks/2026-02-01-t*/process.md; do for ((j = 0; j < 200; j++)); do echo "2026-02-01T00:01 minor: m$j"; done >> "$f"; done
  c3=$(count)
  echo "c0=$c0 c1=$c1 c2=$c2 c3=$c3" >&2
  [ $((c1 - c0)) -le $((3 * 3)) ]
  [ $((c2 - c1)) -le $((3 * 3)) ]
  [ $((c2 - c1)) -eq $((c1 - c0)) ]
  [ "$c3" -eq "$c2" ]
}

@test "AC10 文件：dk-status 在三份 README 都出現" {
  for f in .dkbo/README.md README.md README.en.md; do grep -q 'dk-status' "$REPO_ROOT/$f"; done
}

@test "AC5 檔尾沒有換行：最後一行不會黏到下一個檔的第一行" {
  printf '2026-09-25T11:00 gate1 approved' >> "$b/process.md"   # process.md 原本有結尾換行，這一行沒有
  printf 'status: done\nwave: 1' > "$b/state/backend.md"
  printf 'DK_SHORT="beta"\nDK_DISPLAY="進行中|任務"' > "$b/.task.env"
  t=$(detail beta '.task')
  [ "$(jq -c '[.updated_at, .gate1_at, .status, .display]' <<< "$t")" = '["2026-09-25T11:00","2026-09-25T11:00","running","進行中|任務"]' ]
  [ "$(jq -c '.members[0] | [.name, .status, .wave]' <<< "$t")" = '["backend","done",1]' ]
  [ "$(jq -c '.members[1] | [.name, .status]' <<< "$t")" = '["frontend-cart","working"]' ]
  [ "$(jq -c '.skipped_lines' <<< "$t")" = '{"process":1,"messages":3}' ]
}

@test "AC4 members 依檔名（含 .md）碼點升冪，不靠 glob 的 locale：qa-b.md 排在 qa.md 前" {
  printf 'status: done\n' > "$b/state/qa.md"
  printf 'status: done\n' > "$b/state/qa-b.md"
  [ "$(detail beta '[.task.members[].name]')" = '["backend","frontend-cart","qa-b","qa"]' ]
  [ "$(LC_ALL=C dk-status --json beta | jq -c '[.task.members[].name]')" = '["backend","frontend-cart","qa-b","qa"]' ]
}
