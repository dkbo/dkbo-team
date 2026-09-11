# shellcheck shell=bash
# shellcheck disable=SC2034  # KIND_* are read by lib/kinds.sh after sourcing
# 每個 model 各自宣告它真的支援的 effort（不是 models × efforts 的笛卡兒積）。
KIND_MODEL_EFFORTS="opus:low,medium,high sonnet:low,medium,high"
KIND_DEFAULT_TIERS="S=sonnet/low M=sonnet/medium L=opus/high"
KIND_PROMPT_QUEUES=unknown   # layer-3 smoke updates this: does a prompt sent while working queue?
kind_args() { echo "--model $1 --effort $2 --permission-mode acceptEdits"; }
kind_mcp_list() { claude mcp list 2>/dev/null | awk -F: 'NF>1{print $1}'; }
