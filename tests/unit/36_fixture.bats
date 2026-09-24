load ../helpers
# setup 刻意不 source lib/common.sh：06、09、12、16、20、28、29 都是這樣呼叫 fixture_task 的，
# fixture 不能靠呼叫端先載過 dk_render。
setup() { setup_project; }
teardown() { teardown_project; rm -rf "${FAKE_REPO:-}"; }

env_keys() { sed -n 's/^\(DK_[A-Z_]*\)=.*/\1/p' "$1"; }

# --- AC5：fixture 的 .task.env 由 templates/task.env 套出來，壞了就回非零 -------------

@test "fixture 的 .task.env 鍵集合與順序和模板一致" {
  d=$(fixture_task login 使用者登入)
  [ "$(env_keys "$d/.task.env")" = "$(env_keys "$DK_ROOT/templates/task.env")" ]
  refute_grep -q '{{' "$d/.task.env"
  # .task.env 會被 source：DK_*= 之外多出的雜行（例如 source common.sh 時印到 stdout 的字）也要擋
  refute_grep -vE '^(DK_[A-Z_]*=|[[:space:]]*#|[[:space:]]*$)' "$d/.task.env"
}

@test "fixture 給的值：DK_SHORT 到 DK_BASE，LEADER_PANE 刻意空" {
  d=$(fixture_task login 使用者登入)
  grep -qx 'DK_SHORT="login"' "$d/.task.env"
  grep -qx 'DK_DISPLAY="使用者登入"' "$d/.task.env"
  grep -qx 'DK_BRANCH="dk/login"' "$d/.task.env"
  grep -qx "DK_WORKTREE=\"$WORKTREE_PATH\"" "$d/.task.env"
  grep -qx 'DK_WORKSPACE="wB"' "$d/.task.env"
  grep -qx 'DK_ROOT_PANE="wB:p1"' "$d/.task.env"
  grep -qx "DK_BASE=\"$(git -C "$PROJECT" rev-parse HEAD)\"" "$d/.task.env"
  grep -qx 'DK_TASK_TAB=""' "$d/.task.env"
  grep -qx 'DK_LEADER_PANE=""' "$d/.task.env"
  grep -qx 'DK_NO_WORKTREE=""' "$d/.task.env"
}

@test "模板多一個 fixture 沒給的佔位符：fixture_task 回非零，stderr 點名 PROBE" {
  echo 'DK_PROBE="{{PROBE}}"' >> "$DK_ROOT/templates/task.env"
  local rc=0
  fixture_task login x > /dev/null 2> "$PROJECT/err" || rc=$?
  [ "$rc" -ne 0 ]
  grep -q 'PROBE' "$PROJECT/err"
}

@test "模板裡半截的佔位符 {{PROBE2：fixture_task 回非零，stderr 點名 PROBE2" {
  echo 'DK_PROBE2="{{PROBE2"' >> "$DK_ROOT/templates/task.env"
  local rc=0
  fixture_task login x > /dev/null 2> "$PROJECT/err" || rc=$?
  [ "$rc" -ne 0 ]
  grep -q 'PROBE2' "$PROJECT/err"
}

@test "抽不出名字的 {{：fixture_task 回非零，stderr 印出那一行" {
  echo 'DK_PROBE3="{{}"' >> "$DK_ROOT/templates/task.env"
  local rc=0
  fixture_task login x > /dev/null 2> "$PROJECT/err" || rc=$?
  [ "$rc" -ne 0 ]
  grep -qF 'DK_PROBE3="{{}"' "$PROJECT/err"
}

@test "setup 沒 source common.sh 時，fixture 的 .task.env 照樣非空、有 DK_SHORT=" {
  refute declare -F dk_render
  d=$(fixture_task login x)
  [ -s "$d/.task.env" ]
  grep -q '^DK_SHORT=' "$d/.task.env"
}

@test "fixture_task 不在呼叫端 shell 留下新的變數或函式" {
  local fb="" vb="" fa="" va=""
  fb=$(declare -F); vb=$(compgen -v)
  fixture_task login x > /dev/null
  fa=$(declare -F); va=$(compgen -v)
  [ -z "$(comm -13 <(echo "$fb" | sort) <(echo "$fa" | sort))" ] || { echo "新增函式："; comm -13 <(echo "$fb" | sort) <(echo "$fa" | sort); false; }
  [ -z "$(comm -13 <(echo "$vb" | sort) <(echo "$va" | sort))" ] || { echo "新增變數："; comm -13 <(echo "$vb" | sort) <(echo "$va" | sort); false; }
}

# --- AC9：setup_project 不把主樹的執行期狀態帶進夾具 ---------------------------------

@test "setup_project 之後 .sessions/ 只剩 .gitkeep，不帶主樹的 kinds-down、綁定與 pid" {
  # worktree 的 .sessions/ 本來就乾淨，所以另造一個「髒的主樹」當 REPO_ROOT 來重現
  FAKE_REPO=$(mktemp -d)
  cp -r "$REPO_ROOT/.dkbo" "$FAKE_REPO/.dkbo"
  mkdir -p "$FAKE_REPO/tests" "$FAKE_REPO/.dkbo/.sessions/chores"
  cp -r "$REPO_ROOT/tests/stub" "$FAKE_REPO/tests/stub"
  local s="$FAKE_REPO/.dkbo/.sessions"
  echo "agy 9999999999 exact 2026-09-24T06:55 t p x" > "$s/kinds-down"
  : > "$s/kinds-down.lock"; : > "$s/chores/chore-x-1"; echo 2026-09-24-x > "$s/wB:p9"; echo 1 > "$s/chores.watch.pid"
  teardown_project
  REPO_ROOT="$FAKE_REPO" setup_project
  [ "$(ls -A "$DK_ROOT/.sessions")" = ".gitkeep" ] || { ls -A "$DK_ROOT/.sessions"; false; }
  [ -f "$s/kinds-down" ]   # 來源那一邊（主樹）不動
}

@test "真的 REPO_ROOT 跑 setup_project：.sessions/ 同樣只剩 .gitkeep" {
  [ "$(ls -A "$DK_ROOT/.sessions")" = ".gitkeep" ]
}

# --- AC3：夾具不帶進主樹的進行中任務（fixture_copy_dkbo） ------------------------------
# 造一個「主樹」：.dkbo 整份 commit 進 git，之後才在 tasks/ 底下弄髒（領導正在跑的任務長這樣）
fake_git_repo() {
  FAKE_REPO=$(mktemp -d)
  cp -r "$REPO_ROOT/.dkbo" "$FAKE_REPO/.dkbo"
  mkdir -p "$FAKE_REPO/tests"; cp -r "$REPO_ROOT/tests/stub" "$FAKE_REPO/tests/stub"
  echo "# 決策" > "$FAKE_REPO/.dkbo/tasks/decisions.md"
  git -C "$FAKE_REPO" init -q
  git -C "$FAKE_REPO" add -A
  git -C "$FAKE_REPO" -c user.name=t -c user.email=t@t commit -q -m base
  local live="$FAKE_REPO/.dkbo/tasks/2026-09-24-live"
  mkdir -p "$live/state"
  echo 'wB:p9 backend' > "$live/.panes"; echo 'DK_SHORT="live"' > "$live/.task.env"; echo x > "$live/state/backend.md"
  echo '| live | working |' >> "$FAKE_REPO/.dkbo/tasks/INDEX.md"
  echo '主樹上領導剛寫的決策' >> "$FAKE_REPO/.dkbo/tasks/decisions.md"
  rm "$FAKE_REPO/.dkbo/tasks/BACKLOG.md"                                  # 追蹤中但被刪
  printf '#!/usr/bin/env bash\necho new\n' > "$FAKE_REPO/.dkbo/bin/newtool"   # tasks/ 以外的未追蹤檔
  echo '未 commit 的規則改動' >> "$FAKE_REPO/.dkbo/PROTOCOL.md"                # tasks/ 以外的追蹤檔改動
}

@test "髒主樹跑 setup_project：未追蹤任務資料夾不進夾具、tasks/ 追蹤檔還原成 HEAD 版、tasks/ 以外照舊帶" {
  fake_git_repo
  teardown_project
  REPO_ROOT="$FAKE_REPO" setup_project
  [ ! -e "$DK_ROOT/tasks/2026-09-24-live" ] || { ls -A "$DK_ROOT/tasks/2026-09-24-live"; false; }
  [ "$(cat "$DK_ROOT/tasks/INDEX.md")" = "$(git -C "$FAKE_REPO" show HEAD:.dkbo/tasks/INDEX.md)" ]
  [ "$(cat "$DK_ROOT/tasks/decisions.md")" = "# 決策" ]
  [ "$(cat "$DK_ROOT/tasks/BACKLOG.md")" = "$(git -C "$FAKE_REPO" show HEAD:.dkbo/tasks/BACKLOG.md)" ]
  [ -x "$DK_ROOT/bin/newtool" ]
  grep -qx '未 commit 的規則改動' "$DK_ROOT/PROTOCOL.md"
  # 來源那一邊（主樹）一律不動
  [ -f "$FAKE_REPO/.dkbo/tasks/2026-09-24-live/.panes" ]
  grep -q '主樹上領導剛寫的決策' "$FAKE_REPO/.dkbo/tasks/decisions.md"
  [ ! -e "$FAKE_REPO/.dkbo/tasks/BACKLOG.md" ]
}

@test "fixture_copy_dkbo：不刷新來源的 index（不搶 .git/index.lock）" {
  fake_git_repo
  local before after dest
  touch -d '2020-01-01' "$FAKE_REPO/.dkbo/tasks/INDEX.md"   # stat 髒掉：會刷新 index 的指令就會改寫它
  before=$(stat -c "%i %y" "$FAKE_REPO/.git/index")
  dest=$(mktemp -d)
  fixture_copy_dkbo "$FAKE_REPO" "$dest/.dkbo"
  after=$(stat -c "%i %y" "$FAKE_REPO/.git/index")
  rm -rf "$dest"
  [ "$before" = "$after" ]
}

@test "fixture_copy_dkbo：來源不是 git 倉時照樣複製、清 .sessions/、不報錯" {
  FAKE_REPO=$(mktemp -d)
  cp -r "$REPO_ROOT/.dkbo" "$FAKE_REPO/.dkbo"
  mkdir -p "$FAKE_REPO/.dkbo/tasks/2026-09-24-live"; : > "$FAKE_REPO/.dkbo/tasks/2026-09-24-live/.panes"
  echo 1 > "$FAKE_REPO/.dkbo/.sessions/chores.watch.pid"
  local dest; dest=$(mktemp -d)
  run fixture_copy_dkbo "$FAKE_REPO" "$dest/.dkbo"
  [ "$status" -eq 0 ]; [ -z "$output" ] || { echo "$output"; false; }
  [ -f "$dest/.dkbo/PROTOCOL.md" ]
  [ -f "$dest/.dkbo/tasks/2026-09-24-live/.panes" ]   # 不是 git 倉就分不出哪些是追蹤的，整份照帶
  [ "$(ls -A "$dest/.dkbo/.sessions")" = ".gitkeep" ]
  rm -rf "$dest"
}
