status: done
wave: 4
current: 完成 Important 1/2 修復與兩條 Minor，全套測試與 shellcheck 過
touched:
  - .dkbo/lib/repos.sh
  - .dkbo/bin/dk-leader
  - .dkbo/bin/dk-wave-close
  - .dkbo/bin/dk-task-close
  - tests/unit/33_repos.bats
  - tests/unit/13_leader.bats
  - tests/unit/08_wave_close.bats
blocked_by: dk-msg qa 送不到（本波沒有 qa 成員，只落 log；leader 已收到）
report: state/backend-ws.report.md
notes: Important 1 只排除主 repo 的 .dkbo/；Important 2 兩處 </dev/null 加 git commit 一併加固；
  dk-leader:121,124 兩行都改了繁中（Minor 同一項）。全套 539 ok/0 not ok，shellcheck 零警告。
