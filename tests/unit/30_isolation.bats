load ../helpers

# 事故回放（2026-09-19）：領導 session 的 shell source 過 common.sh，所以環境裡帶著
# DK_PROJECT_ROOT；helpers.bash 當時只覆寫 DK_ROOT、沒清掉繼承來的 DK_*，而 common.sh:5
# 是 ${DK_PROJECT_ROOT:-…} —— 繼承值優先。結果同一份測試，誰跑決定它動哪個 repo：
# 員工手動跑全綠（shell 沒 source 過 common.sh），領導跑就在真 repo 建了 7 個 worktree。
# 這一條把「帶著領導的環境變數」做成前提，setup_project 必須把它洗乾淨。
setup() {
  BAIT="$(mktemp -d)"
  git -C "$BAIT" init -q
  git -C "$BAIT" config user.name t; git -C "$BAIT" config user.email t@t
  git -C "$BAIT" commit -q --allow-empty -m init
  BAIT_BEFORE="$(git -C "$BAIT" worktree list | wc -l):$(git -C "$BAIT" branch | wc -l)"
  # 領導環境的三個代表：會寫到別的 repo、會改 worktree 落點、會被 gate c 執行
  export DK_PROJECT_ROOT="$BAIT" DK_WORKTREE_DIR="$BAIT/wt" DK_TEST_CMD="touch $BAIT/pwned"
  setup_project
}
teardown() { teardown_project; rm -rf "$BAIT"; }

@test "setup_project 洗掉繼承來的 DK_*，測試不會碰到別的 repo" {
  [ -z "${DK_PROJECT_ROOT:-}" ]; [ -z "${DK_WORKTREE_DIR:-}" ]; [ -z "${DK_TEST_CMD:-}" ]
  run dk-task-new login 使用者登入; [ "$status" -eq 0 ]
  # 0.10.0 起 worktree 是 dk-leader --run 建的，所以正面斷言要走完交棒那一步才看得到
  dk-process "brief-review skipped: 隔離測試"
  dk-task-new login --gate1 >/dev/null
  run dk-leader login --run; [ "$status" -eq 0 ]
  # 正面：worktree 真的建出來了，而且落在測試專案裡（不是靜默沒做事）
  git -C "$PROJECT" worktree list --porcelain | grep -qx "worktree $WORKTREE_PATH"
  # 反面：誘餌 repo 一個 worktree、一個分支、一個檔案都沒多
  [ "$(git -C "$BAIT" worktree list | wc -l):$(git -C "$BAIT" branch | wc -l)" = "$BAIT_BEFORE" ]
  refute_grep -q . <(git -C "$BAIT" status --porcelain)
  [ ! -e "$BAIT/pwned" ]; [ ! -e "$BAIT/wt" ]; [ ! -e "$BAIT/.worktrees" ]
}

@test "setup_project 之後環境裡只剩 harness 自己設的 DK_*" {
  leaked=""
  for v in $(compgen -v | grep '^DK_' || true); do
    case "$v" in DK_ROOT|DK_NO_WATCH) ;; *) leaked="$leaked $v";; esac
  done
  [ -z "$leaked" ] || { echo "洩漏的變數:$leaked" >&2; false; }
}

@test "setup_project 不讓 fixture 吃源碼倉自己的 DK_TEST_CMD" {
  # 源碼倉的 settings.env 是給 dogfood 任務的 gate c 用的（tests/run.sh）；fixture 整包 cp 進來
  # 之後若原樣保留，每一條「閘全過」的 wave-close 測試都會在假 worktree 裡去跑一個不存在的
  # 測試指令。2026-09-19 把 DK_TEST_CMD 設成 tests/run.sh 那個 commit，就這樣紅了 16 條。
  grep -Eq '^DK_TEST_CMD=""( |$)' "$DK_ROOT/settings.env"
  # 對照：源碼倉那份是什麼都無所謂，fixture 一律是空
  ( . "$DK_ROOT/lib/common.sh"; dk_settings; [ -z "$DK_TEST_CMD" ] )
}
