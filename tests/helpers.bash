# shellcheck shell=bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

setup_project() {
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
  unset DK_TASK_DIR DK_ROLE DK_AGENT DK_LEADER DK_ISOLATED
  cd "$PROJECT"
}
teardown_project() { rm -rf "$PROJECT"; }
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
無

## 波次表
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
| （範例）1 | 實作 | backend | API | M | 測試過 | 預設 |
| 1 | 實作 | backend | POST /login | M | 測試過 | 預設 |
| 1 | 實作 | qa | 驗 API | S | 全過 | |
| 2 | 實作 | frontend-cart | 表單 | S | 可用 | kinds: claude codex |
B
}
