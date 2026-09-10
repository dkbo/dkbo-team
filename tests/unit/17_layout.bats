load ../helpers
setup() { setup_project; . "$DK_ROOT/lib/common.sh"; . "$DK_ROOT/lib/layout.sh"; p="$PROJECT/panes"; : > "$p"; export DK_ROOT_PANE=wB:p1 DK_TAB1_SLOTS=4; }
teardown() { teardown_project; }
expect() { [ "$(dk_layout_slot dev "$p")" = "$1" ] || { echo "got: $(dk_layout_slot dev "$p") want: $1"; return 1; }; }

@test "slot table: tab 1 has 4 cells, tabs 2+ have 6, anchors and shares per spec §6.3" {
  expect "1 1 wB:p1 right 0.5";      echo "a wB:p2 0 dev 1 1" >> "$p"
  expect "1 2 wB:p2 down 0.5";       echo "b wB:p3 0 dev 1 2" >> "$p"
  expect "1 3 wB:p2 right 0.5";      echo "c wB:p4 0 dev 1 3" >> "$p"
  expect "1 4 wB:p3 right 0.5";      echo "d wB:p5 0 dev 1 4" >> "$p"
  expect "NEWTAB 2 1";               echo "e wB:p10 0 dev 2 1" >> "$p"
  expect "2 2 wB:p10 down 0.5";      echo "f wB:p11 0 review 2 2" >> "$p"
  expect "2 3 wB:p10 right 0.333";   echo "g wB:p12 0 review 2 3" >> "$p"
  expect "2 4 wB:p11 right 0.333";   echo "h wB:p13 0 review 2 4" >> "$p"
  expect "2 5 wB:p12 right 0.5";     echo "i wB:p14 0 review 2 5" >> "$p"
  expect "2 6 wB:p13 right 0.5";     echo "j wB:p15 0 review 2 6" >> "$p"
  expect "NEWTAB 3 1"
}
@test "DK_TAB1_SLOTS=6 splits tab 1 columns in thirds; tab-0 rows (pm) are ignored" {
  export DK_TAB1_SLOTS=6
  printf 'pm wB:p9 0 dev 0 0\na wB:p2 0 dev 1 1\nb wB:p3 0 dev 1 2\n' > "$p"
  expect "1 3 wB:p2 right 0.333"; echo "c wB:p4 0 dev 1 3" >> "$p"
  expect "1 4 wB:p3 right 0.333"; echo "d wB:p5 0 dev 1 4" >> "$p"
  expect "1 5 wB:p4 right 0.5"
}
@test "a closed anchor cell falls back to hanging below the highest live cell" {
  printf 'a wB:p2 0 dev 1 1\nc wB:p4 0 dev 1 3\n' > "$p"   # slot 2 gone; next is slot 4 whose anchor is slot 2
  expect "1 4 wB:p4 down 0.5"
}
@test "legacy two-column .panes counts as no occupied cells" {
  printf 'a wB:p2\n' > "$p"; expect "1 1 wB:p1 right 0.5"
}
@test "dk_layout_ratio_arg converts the anchor share to herdr's --ratio per DK_RATIO_MEANS" {
  [ "$(DK_RATIO_MEANS=new dk_layout_ratio_arg 0.333)" = "0.667" ]
  [ "$(DK_RATIO_MEANS=new dk_layout_ratio_arg 0.5)" = "0.500" ]
  [ "$(DK_RATIO_MEANS=anchor dk_layout_ratio_arg 0.333)" = "0.333" ]
}
