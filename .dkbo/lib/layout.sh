# shellcheck shell=bash
# Employee pane grid (spec §6). `.panes` rows: <agent> <pane_id> <epoch> <group> <tab_no> <slot>.
# Tab 1 is the leader's tab: the leader keeps a full-height left column; DK_TAB1_SLOTS cells fill the right half.
# Tabs 2+ hold 6 cells (3 columns × 2 rows). Shares below are what the ANCHOR keeps after the split.
# DK_RATIO_MEANS: what herdr's `pane split --ratio` denotes — "new" (the new pane's share; default) or "anchor".
# tests/integration/herdr-real.sh prints a NOTE telling which one real herdr uses.
DK_RATIO_MEANS="${DK_RATIO_MEANS:-new}"
dk_layout_ratio_arg() { # ANCHOR_SHARE → value for --ratio
  if [ "$DK_RATIO_MEANS" = anchor ]; then awk -v r="$1" 'BEGIN{printf "%.3f", r}'; else awk -v r="$1" 'BEGIN{printf "%.3f", 1-r}'; fi
}
dk__layout_cap() { if [ "$1" -eq 1 ]; then echo "${DK_TAB1_SLOTS:-4}"; else echo 6; fi; }
dk__layout_pane_at() { awk -v t="$1" -v s="$2" 'NF>=6 && $5==t && $6==s {print $2; exit}' "$3"; }
dk_layout_slot() { # GROUP [PANES_FILE] → "<tab_no> <slot> <anchor> <direction> <anchor_share>" | "NEWTAB <tab_no> 1"
  local panes="${2:-$(dk_task_dir)/.panes}" tab max cap slot anchor_slot dir share anchor
  tab=$(awk 'NF>=6 && $5>0 {if ($5>t) t=$5} END{print t+0}' "$panes"); [ "$tab" -ge 1 ] || tab=1
  max=$(awk -v t="$tab" 'NF>=6 && $5==t {if ($6>m) m=$6} END{print m+0}' "$panes")
  cap=$(dk__layout_cap "$tab"); slot=$((max+1))
  if [ "$slot" -gt "$cap" ]; then tab=$((tab+1)); slot=1; cap=$(dk__layout_cap "$tab"); fi
  if [ "$slot" -eq 1 ]; then
    if [ "$tab" -eq 1 ]; then echo "1 1 ${DK_ROOT_PANE:?} right 0.5"; else echo "NEWTAB $tab 1"; fi; return 0
  fi
  case "$slot" in
    2) anchor_slot=1; dir=down;  share=0.5;;
    3) anchor_slot=1; dir=right; share=0.5; [ "$cap" -eq 6 ] && share=0.333;;
    4) anchor_slot=2; dir=right; share=0.5; [ "$cap" -eq 6 ] && share=0.333;;
    5) anchor_slot=3; dir=right; share=0.5;;
    *) anchor_slot=4; dir=right; share=0.5;;
  esac
  anchor=$(dk__layout_pane_at "$tab" "$anchor_slot" "$panes")
  if [ -z "$anchor" ]; then   # anchor cell was closed mid-wave: hang below the highest live cell of this tab
    anchor=$(awk -v t="$tab" 'NF>=6 && $5==t {if ($6+0>=m) {m=$6+0; p=$2}} END{print p}' "$panes"); dir=down; share=0.5
  fi
  echo "$tab $slot $anchor $dir $share"
}
