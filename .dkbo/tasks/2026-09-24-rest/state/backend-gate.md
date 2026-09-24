status: done
wave: 1
current: 完成 AC1、AC6，已送 DONE
touched:
  - .dkbo/bin/dk-wave-close
  - .dkbo/lib/ownership.sh
  - .dkbo/bin/dk-spawn
  - .dkbo/bin/dk-brief-check
  - tests/unit/08_wave_close.bats
  - tests/unit/22_ownership.bats
  - tests/unit/07_spawn.bats
  - tests/unit/16_brief_check.bats
todo: []
report: state/backend-gate.report.md
notes: 全套 749/752，3 紅是 06 的 AC5（backend-watch 進行中）；DK__BRIEF_SPLIT 會蓋掉 awk 的 m/c/p/i/j/v 變數，見 report 疑慮
