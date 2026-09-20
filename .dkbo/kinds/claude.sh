# shellcheck shell=bash
# shellcheck disable=SC2034  # KIND_* are read by lib/kinds.sh after sourcing
# 每個 model 各自宣告它真的支援的 effort（不是 models × efforts 的笛卡兒積）。
KIND_MODEL_EFFORTS="opus:low,medium,high sonnet:low,medium,high"
KIND_DEFAULT_TIERS="S=sonnet/low M=sonnet/medium L=opus/high"
KIND_PROMPT_QUEUES=unknown   # layer-3 smoke updates this: does a prompt sent while working queue?
# auto 而非 acceptEdits：員工的 cwd 是 worktree，但切片、state、report 都在主樹的 .dkbo/ 下，
# acceptEdits 不放行工作區外的讀寫，也不放行任何 shell —— 實跑時每位員工都卡在第一個動作。
# --add-dir 明示主樹，讓「讀自己的切片、寫自己的 state」本來就在授權範圍內。

# claude 的審批 herdr 認得（會回 blocked），這兩行是第二道訊號，不是唯一依據。
KIND_BLOCK_RE='Do you want|Allow this|❯ 1\. Yes'
KIND_QUOTA_RE='usage limit|rate limit'
kind_args() { echo "--model $1 --effort $2 --permission-mode auto$(dk_add_dirs)"; }
# CLI 那側的 session 顯示名（session picker 與終端標題）。herdr 的註冊名是另一回事：
# 它只吃 [a-z][a-z0-9_-]{0,31}，放不進 workspace 名字裡的斜線。
kind_session_args() { [ -n "${1:-}" ] && echo "--name $1"; return 0; }
kind_mcp_list() { claude mcp list 2>/dev/null | awk -F: 'NF>1{print $1}'; }
