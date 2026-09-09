# shellcheck shell=bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

setup_project() {
  PROJECT="$(mktemp -d)"
  cp -r "$REPO_ROOT/.dkboai" "$PROJECT/.dkboai"
  chmod +x "$PROJECT"/.dkboai/bin/* 2>/dev/null || true
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
  export PATH="$REPO_ROOT/tests/stub:$REPO_ROOT/tests/stub/cli:$PROJECT/.dkboai/bin:$PATH"
  export HERDR_ENV=1 HERDR_PANE_ID=wB:p1 HERDR_WORKSPACE_ID=wB HERDR_TAB_ID=wB:t1
  export DK_ROOT="$PROJECT/.dkboai"
  export DK_NO_WATCH=1   # unit tests do not launch the background watcher (Task 9 has one test that unsets this)
  unset DK_TASK_DIR DK_ROLE DK_AGENT DK_LEADER DK_ISOLATED
  cd "$PROJECT"
}
teardown_project() { rm -rf "$PROJECT"; }
stub_calls() { cat "$HERDR_STUB_LOG"; }
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
DK_WORKSPACE="wC"
DK_ROOT_PANE="wC:p1"
DK_WATCH_PID=""
E
  mkdir -p "$WORKTREE_PATH"
  echo "$(basename "$d")" > "$DK_ROOT/.sessions/$HERDR_PANE_ID"
  echo "$d"
}
