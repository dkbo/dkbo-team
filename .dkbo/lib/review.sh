# shellcheck shell=bash
# 審查共用：kind 選擇與檔位驗證。dk-review（差異包）與 dk-brief-review（計畫）共用這一份。
# 需要先 source common.sh（dk_die）、載入 .task.env（DK_KIND_DOWN）與 settings.env（DK_REVIEW_TIER）。

dk_review_tier() { # TIER_FLAG → M|L；空字串表示沒給 --tier，改取 settings.env
  local tier="${1:-}" src="--tier"
  [ -n "$tier" ] || { tier="${DK_REVIEW_TIER:-}"; src="settings.env 的 DK_REVIEW_TIER"; }
  [[ "$tier" =~ ^[ML]$ ]] || dk_die "$src 是 '$tier'：reviewer 檔位只能是 M 或 L"
  printf '%s' "$tier"
}

dk_review_kinds() { # WANT CMD LABEL → 可用的 kind（≤3，濾掉本任務已熔斷的）；全滅回非零
  local want="$1" cmd="$2" label="$3" k use=""
  for k in $want; do
    if [[ " ${DK_KIND_DOWN:-} " == *" $k "* ]]; then
      echo "$cmd: kind $k is down for this task; skipped" >&2; continue
    fi
    use="$use $k"
  done
  # shellcheck disable=SC2086  # split kinds on purpose
  use=$(printf '%s\n' $use | head -3 | tr '\n' ' ')
  if [ -z "${use// /}" ]; then
    echo "$cmd: no reviewer kind available; record: dk-process \"$label skipped: all kinds down\"" >&2
    return 1
  fi
  printf '%s' "$use"
}
