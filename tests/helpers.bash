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
  chmod +x "$PROJECT"/.dkbo/bin/* 2>/dev/null || true
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
  rm -rf "$PROJECT"
}
stub_calls() { cat "$HERDR_STUB_LOG"; }
# 雜務檔住在 _chores/<日期>/ 底下；0.5.0 之前開的 legacy 檔還在根層。兩層都算。
# || true：兩個 glob 通常只有一個命中，ls 對另一個回非零，而 bats 在 set -e 下跑。
chore_files() { ls "$DK_ROOT/tasks/_chores/"*/*.md "$DK_ROOT/tasks/_chores/"*.md 2>/dev/null || true; }
# Make a bound task quickly without dk-task-new (for tests of later scripts).
fixture_task() { # $1=short $2=display
  local d="$DK_ROOT/tasks/$(date +%Y-%m-%d)-$1"
  mkdir -p "$d/state"
  sed -e "s#{{DISPLAY}}#$2#g; s#{{SHORT}}#$1#g; s#{{BRANCH}}#dk/$1#g; s#{{WORKTREE}}#$WORKTREE_PATH#g; s#{{SOURCE}}#test#g" \
    "$DK_ROOT/templates/brief.md" > "$d/brief.md"
  : > "$d/process.md"; : > "$d/messages.log"; : > "$d/.panes"
  cat > "$d/.task.env" <<E
DK_SHORT="$1"
DK_DISPLAY="$2"
DK_BRANCH="dk/$1"
DK_WORKTREE="$WORKTREE_PATH"
DK_WORKSPACE="wB"
DK_ROOT_PANE="wB:p1"
DK_BASE="$(git -C "$PROJECT" rev-parse HEAD)"
DK_WATCH_PID=""
DK_EVENTS_PID=""
DK_WAVE=""
DK_WAVE_STARTED=""
DK_KIND_DOWN=""
DK_TABS=""
E
  rm -rf "$WORKTREE_PATH"; mkdir -p "$(dirname "$WORKTREE_PATH")"
  git -C "$PROJECT" worktree add -q -b "dk/$1" "$WORKTREE_PATH" main >/dev/null 2>&1
  echo "$(basename "$d")" > "$DK_ROOT/.sessions/$HERDR_PANE_ID"
  echo "$d"
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
