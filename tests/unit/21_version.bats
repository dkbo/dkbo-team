load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "VERSION is semver and dk-version prints it" {
  v=$(cat "$DK_ROOT/VERSION"); [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
  run dk-version; [ "$status" -eq 0 ]; [ "$output" = "dkbo $v" ]
}
@test "dk-version tolerates a missing VERSION file" {
  rm "$DK_ROOT/VERSION"; run dk-version; [ "$status" -eq 0 ]; [ "$output" = "dkbo unknown" ]
}
