load ../helpers
setup() {
  setup_project; d=$(fixture_task login 使用者登入)
  printf 'login-frontend wC:p2\nlogin-qa wC:p3\n' > "$d/.panes"
  cat >> "$d/brief.md" <<'B'
| frontend | src/web/** | src/api/types.ts |
| qa | tests/** | — |
B
  printf 'status: done\nwave: 1\ntouched:\n  - src/web/login.tsx\n' > "$d/state/frontend.md"
  printf 'status: done\nwave: 1\ntouched:\n  - tests/login.test.ts\n' > "$d/state/qa.md"
}
teardown() { teardown_project; }

@test "closes all panes when every state is done" {
  run dk-wave-close; [ "$status" -eq 0 ]
  grep -q '^pane close wC:p2$' "$HERDR_STUB_LOG"; grep -q '^pane close wC:p3$' "$HERDR_STUB_LOG"
  [ ! -s "$d/.panes" ]; grep -q 'wave-close: 2 agents closed' "$d/process.md"
}
@test "refuses when a state is not done, unless --force" {
  sed -i 's/^status: done/status: working/' "$d/state/qa.md"
  run dk-wave-close; [ "$status" -eq 1 ]; [[ "$output" == *"login-qa"* ]]
  ! grep -q '^pane close' "$HERDR_STUB_LOG"
  run dk-wave-close --force; [ "$status" -eq 0 ]
}
@test "reports ownership violations and long state" {
  printf 'status: done\ntouched:\n  - src/api/login.ts\n' > "$d/state/frontend.md"
  for i in $(seq 1 25); do echo "notes: line $i" >> "$d/state/qa.md"; done
  run dk-wave-close; [ "$status" -eq 0 ]
  grep -q 'violation login-frontend: src/api/login.ts' "$d/process.md"
  [[ "$output" == *"state too long"* ]]
}
@test "ownership matches member names exactly" {
  . "$DK_ROOT/lib/ownership.sh"
  printf '| qa-a | docs/** | — |\n' >> "$d/brief.md"
  dk_owned "$d/brief.md" qa tests/x.ts
  ! dk_owned "$d/brief.md" qa docs/x.md
  dk_owned "$d/brief.md" qa-a docs/x.md
}
@test "--agent closes one pane, drops its row, re-balances its tab" {
  printf 'login-frontend wC:p2 0 dev 1 1\nlogin-qa wC:p3 0 review 1 2\n' > "$d/.panes"
  run dk-wave-close --agent login-qa; [ "$status" -eq 0 ]; [ "$output" = "closed login-qa" ]
  grep -q '^pane close wC:p3$' "$HERDR_STUB_LOG"; ! grep -q '^login-qa ' "$d/.panes"; grep -q '^login-frontend ' "$d/.panes"
  grep -q 'pane-close login-qa' "$d/process.md"; grep -q '^pane layout --pane wB:p1$' "$HERDR_STUB_LOG"
  run dk-wave-close --agent nobody; [ "$status" -eq 1 ]
}
