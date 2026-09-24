# shellcheck shell=bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

setup_project() {
  # 繼承來的 DK_* 一律洗掉，再設 harness 自己要的那兩個。
  # common.sh 幾乎每個變數都寫成 ${DK_X:-<預設>}，繼承值優先 —— 只覆寫 DK_ROOT 不夠：
  # DK_PROJECT_ROOT 會留著指向呼叫者的 repo，而 dk-task-new 是 git -C "$DK_PROJECT_ROOT"
  # worktree add。2026-09-19 領導在自己 session 跑 gate c，就這樣在真 repo 建了 7 個
  # worktree 與 8 個分支；員工手動跑全綠，因為員工的 shell 沒 source 過 common.sh。
  # 逐一列舉會隨新變數再度過時，所以整片清 —— 回歸測試在 tests/unit/30_isolation.bats。
  local v
  for v in ${!DK_@}; do unset "$v"; done
  PROJECT="$(mktemp -d)"
  cp -r "$REPO_ROOT/.dkbo" "$PROJECT/.dkbo"
  # .sessions/ 是主樹的執行期狀態（gitignore，只追蹤 .gitkeep）。原樣帶進來的話，開發機上一筆
  # 未過期的 kinds-down 就讓 10_resume 兩條紅 —— 測試結果不能取決於誰的機器、哪一天跑。
  find "$PROJECT/.dkbo/.sessions" -mindepth 1 -maxdepth 1 -not -name .gitkeep -exec rm -rf {} +
  chmod +x "$PROJECT"/.dkbo/bin/* 2>/dev/null || true
  # 源碼倉自己的 settings.env 是 dogfood 任務在用的（DK_TEST_CMD=tests/run.sh 給 gate c），
  # fixture 不能原樣繼承：gate c 會在假 worktree 裡跑一個不存在的指令，每條「閘全過」的
  # wave-close 測試都紅。要測 gate c 的測試自己往 settings.env append 一行蓋掉即可。
  sed -i 's/^DK_TEST_CMD=.*/DK_TEST_CMD=""/' "$PROJECT/.dkbo/settings.env"
  git -C "$PROJECT" init -q
  git -C "$PROJECT" config user.name t; git -C "$PROJECT" config user.email t@t
  git -C "$PROJECT" commit -q --allow-empty -m init
  git -C "$PROJECT" branch -M main
  HERDR_STUB_LOG="$PROJECT/.herdr-calls.log"; : > "$HERDR_STUB_LOG"
  HERDR_STUB_RESPONSES="$PROJECT/.herdr-responses"
  cp -r "$REPO_ROOT/tests/stub/responses" "$HERDR_STUB_RESPONSES"
  WORKTREE_PATH="$PROJECT/.worktrees/login"
  sed -i "s#__WORKTREE__#$WORKTREE_PATH#; s#__PROJECT__#$PROJECT#" "$HERDR_STUB_RESPONSES"/*.json
  export HERDR_STUB_LOG HERDR_STUB_RESPONSES PROJECT WORKTREE_PATH
  export PATH="$REPO_ROOT/tests/stub:$REPO_ROOT/tests/stub/cli:$PROJECT/.dkbo/bin:$PATH"
  export HERDR_ENV=1 HERDR_PANE_ID=wB:p1 HERDR_WORKSPACE_ID=wB HERDR_TAB_ID=wB:t1
  export DK_ROOT="$PROJECT/.dkbo"
  export DK_NO_WATCH=1   # unit tests do not launch the background watcher (Task 9 has one test that unsets this)
  cd "$PROJECT"
}
teardown_project() {
  # --ensure 起的是背景常駐行程（輪詢一條、訂閱一條）。留著的話它們會在後面的測試裡
  # 繼續消耗 pid 並寫檔 —— 兩個認 pid 的 --ensure 測試就是這樣間歇性紅的。
  local f p v
  for f in "$DK_ROOT"/tasks/*/.task.env; do
    [ -f "$f" ] || continue
    for v in DK_WATCH_PID DK_EVENTS_PID; do
      p=$(sed -n "s/^$v=\"\([0-9]*\)\"$/\1/p" "$f")
      [ -n "$p" ] && kill "$p" 2>/dev/null || true
    done
  done
  p=$(cat "$DK_ROOT/.sessions/chores.watch.pid" 2>/dev/null || true)
  [ -n "$p" ] && kill "$p" 2>/dev/null || true
  # setup_multirepo 的兩個 repo 是 $PROJECT 的兄弟目錄（多 repo 的路徑必須在主樹之外，
  # 否則 git 會把它們當成主 repo 的子目錄）—— 沒呼叫過 setup_multirepo 時這兩行是 no-op。
  rm -rf "$PROJECT" "$PROJECT-api" "$PROJECT-shared"
}
# 多 repo fixture：在 $PROJECT 之外另建 api 與 shared 兩個 git repo，並把 DK_REPOS 追加進
# settings.env。旗標用 MULTIREPO 而不是 DK_MULTIREPO：setup_project 會整片洗掉 DK_*，
# 而這個旗標要活過 setup_project 之後的每一個 helper 呼叫。
setup_multirepo() {
  REPO_API="$PROJECT-api"; REPO_SHARED="$PROJECT-shared"
  local r
  for r in "$REPO_API" "$REPO_SHARED"; do
    mkdir -p "$r"
    git -C "$r" init -q
    git -C "$r" config user.name t; git -C "$r" config user.email t@t
    git -C "$r" commit -q --allow-empty -m init
    git -C "$r" branch -M main
  done
  printf 'DK_REPOS="main=. api=%s shared=%s"\n' "$REPO_API" "$REPO_SHARED" >> "$DK_ROOT/settings.env"
  printf 'DK_TEST_CMD_api="true"\n' >> "$DK_ROOT/settings.env"
  MULTIREPO=1
  export REPO_API REPO_SHARED MULTIREPO
}
stub_calls() { cat "$HERDR_STUB_LOG"; }
# 把一個 repo 弄成「已追蹤檔有未 commit 的改動」。dk_repos_check 的乾淨檢查只看已追蹤檔
# （領導 2026-09-20T09:41 ruling：.dkbo/ 不進版控的專案不該每次 --run 都被自己擋下），
# 所以要測「不乾淨」就不能只丟一個未追蹤檔進去。
repo_dirty_tracked() { # [REPO]（預設 $PROJECT）
  local r="${1:-$PROJECT}"
  echo v1 > "$r/tracked.txt"
  git -C "$r" add tracked.txt
  git -C "$r" -c user.name=t -c user.email=t@t commit -q -m tracked
  echo v2 > "$r/tracked.txt"        # 已追蹤、已修改、未 commit
}
# 雜務檔住在 _chores/<日期>/ 底下；0.5.0 之前開的 legacy 檔還在根層。兩層都算。
# || true：兩個 glob 通常只有一個命中，ls 對另一個回非零，而 bats 在 set -e 下跑。
chore_files() { ls "$DK_ROOT/tasks/_chores/"*/*.md "$DK_ROOT/tasks/_chores/"*.md 2>/dev/null || true; }
# Make a bound task quickly without dk-task-new (for tests of later scripts).
fixture_task() { # $1=short $2=display —— setup_multirepo 跑過的話，照 DK_REPOS 逐 repo 切 worktree
  local d="$DK_ROOT/tasks/$(date +%Y-%m-%d)-$1"
  mkdir -p "$d/state"
  # 多 repo 的主 repo worktree 在 .worktrees/<short>/main（決策⑥）。fixture_task 跑在
  # 命令替換的子 shell 裡，所以這個覆寫只影響它自己寫出去的 .task.env 與 .repos —— 呼叫端的
  # $WORKTREE_PATH 不會跟著變，要拿多 repo 的 worktree 路徑請用 dk_repo_field "$d" <名> wt。
  [ -n "${MULTIREPO:-}" ] && WORKTREE_PATH="$PROJECT/.worktrees/$1/main"
  sed -e "s#{{DISPLAY}}#$2#g; s#{{SHORT}}#$1#g; s#{{BRANCH}}#dk/$1#g; s#{{WORKTREE}}#$WORKTREE_PATH#g; s#{{SOURCE}}#test#g" \
    "$DK_ROOT/templates/brief.md" > "$d/brief.md"
  : > "$d/process.md"; : > "$d/messages.log"; : > "$d/.panes"
  # .task.env 跟 dk-task-new 走同一條路：套 templates/task.env、用 common.sh 的 dk_render。
  # 手寫 heredoc 的舊版跟模板漂移過（缺 DK_TASK_TAB 與 DK_LEADER_PANE，改那一行的 sed 靜默
  # 變成空操作）。子 shell 裡 source：呼叫端多半沒載 common.sh，也不能被它塞進函式與變數。
  # LEADER_PANE 刻意給空字串 —— 舊版根本沒有這個鍵，照 dk-task-new 填根 pane 會改掉既有測試的語意。
  ( . "$DK_ROOT/lib/common.sh"
    dk_render "$DK_ROOT/templates/task.env" "SHORT=$1" "DISPLAY=$2" "BRANCH=dk/$1" \
      "WORKTREE=$WORKTREE_PATH" "WORKSPACE=wB" "TASK_TAB=" "ROOT_PANE=wB:p1" "LEADER_PANE=" \
      "BASE=$(git -C "$PROJECT" rev-parse HEAD)" "NO_WORKTREE=" ) > "$d/.task.env" || return 1
  fixture_env_check "$DK_ROOT/templates/task.env" "$d/.task.env" || return 1
  # .repos 在真實流程裡是 dk-leader --run 寫的；fixture 直接落一份，單 repo 模式也有（一列，
  # 名字固定 main），這樣每個讀 .repos 的呼叫端只有一條路。
  local e n p wt
  : > "$d/.repos"
  for e in $(fixture_repos); do
    n=${e%%=*}; p=${e#*=}
    wt="$WORKTREE_PATH"; [ -n "${MULTIREPO:-}" ] && wt="$PROJECT/.worktrees/$1/$n"
    rm -rf "$wt"; mkdir -p "$(dirname "$wt")"
    git -C "$p" worktree add -q -b "dk/$1" "$wt" main >/dev/null 2>&1
    printf '%s %s %s %s\n' "$n" "$p" "$wt" "$(git -C "$p" rev-parse HEAD)" >> "$d/.repos"
  done
  echo "$(basename "$d")" > "$DK_ROOT/.sessions/$HERDR_PANE_ID"
  echo "$d"
}
# fixture_task 的自檢：套完仍含 {{（{{FOO}、{{FOO 這種半截的也算），或少了模板裡的任一 DK_* 鍵，
# 就印到 stderr 並回 1：能抽出佔位符名字的印名字，抽不出的印整行。
# fixture 多半跑在 d=$(…) 裡，那裡沒有 set -e —— 不自己回非零，壞掉的 .task.env 會一路綠下去。
fixture_env_check() { # TEMPLATE ENV_FILE
  local k miss="" left="" line names
  for k in $(sed -n 's/^\(DK_[A-Z_]*\)=.*/\1/p' "$1"); do
    grep -q "^$k=" "$2" || miss="$miss $k"
  done
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    names=$(printf '%s\n' "$line" | grep -oE '[{][{][A-Za-z_][A-Za-z0-9_]*' | sed 's/^{{//' | tr '\n' ' ' || true)
    left="$left${names:-$line }"
  done <<< "$(grep '{{' "$2" || true)"
  [ -z "$miss" ] || echo "fixture_task: $2 缺鍵:$miss" >&2
  [ -z "$left" ] || echo "fixture_task: $2 殘留佔位符: $left" >&2
  [ -z "$miss$left" ]
}
# fixture 用的 <名>=<repo 根> 清單（單 repo 一項）。路徑不含空白，所以可以用空白分隔的字串傳。
fixture_repos() {
  if [ -n "${MULTIREPO:-}" ]; then echo "main=$PROJECT api=$REPO_API shared=$REPO_SHARED"
  else echo "main=$PROJECT"; fi
}
fixture_brief() { # $1=task dir — a brief that passes dk-brief-check
  cat > "$1/brief.md" <<'B'
# 使用者登入
來源：test
分支：dk/login   worktree：/tmp/x

## 目標（≤3 行）
登入 API 與表單。

## 全域約束
bash 3.2+；不得使用 bash 4 語法

## 驗收標準
- [ ] POST /login 空密碼回 400
- [ ] renderLogin 產出 user/pass 欄位

## 檔案所有權
| 成員 | 可改 | 只讀 |
|---|---|---|
| （範例）backend | src/api/**, db/** | src/web/** |
| backend | src/api/** | src/web/** |
| frontend-cart | src/web/** | src/api/types.ts |
| qa | tests/** | — |

## 共用契約
| 契約 | 擁有者 | 消費者 | 形狀／簽名 | 變更流程 |
|---|---|---|---|---|
| login API | backend | frontend-cart, qa | POST /login {user,pw} → {token} | 動它要先 ESCALATE |

## 波次表
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
| （範例）1 | 實作 | backend | API | M | 測試過 | 預設 |
| 1 | 實作 | backend | POST /login | M | 測試過 | 預設 |
| 1 | 實作 | qa | 驗 API | S | 全過 | |
| 2 | 實作 | frontend-cart | 表單 | S | 可用 | kinds: claude codex |
B
}

# bats 跑在 set -e 下，而 POSIX 規定 `! cmd` 這種形式要豁免 set -e —— 所以
# `! grep -q x file` 這樣寫的否定斷言永遠不會讓測試變紅，命中了也照樣 ok。
# 用一個普通函式回非零，set -e 才抓得到。
refute_grep() { # 用法同 grep；命中即失敗
  if grep -q "$@"; then echo "refute_grep: 不該命中卻命中了: $*" >&2; return 1; fi
}
# 非 grep 的否定斷言用這個：`! cmd` 同樣豁免 set -e。指令成功就把指令印到 stderr 並回 1。
# 不改用 run 再查 $status：run 會覆寫呼叫端的 $status 與 $output。
refute() { # CMD [ARGS…]；指令成功即失敗
  if "$@"; then echo "refute: 不該成功卻成功了: $*" >&2; return 1; fi
}
