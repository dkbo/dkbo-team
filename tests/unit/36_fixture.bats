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
