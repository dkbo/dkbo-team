status: done
wave: 2
current: 三條 Minor 完成，紅綠已貼報告，全套 724 綠、shellcheck 零警告
touched:
  - .dkbo/lib/review.sh
  - .dkbo/lib/brief.sh
  - .dkbo/bin/dk-brief-check
  - tests/unit/15_brief_lib.bats
  - tests/unit/16_brief_check.bats
  - tests/unit/20_review.bats
todo:
report: state/backend-brief.report.md
notes: dk_brief_ncols [COL]... 現在印「欄數\t指定欄」，由 dk-brief-check 兩個欄數閘呼叫；別名用完提示不再叫人 dk-wave-close --agent，只留 dk-process "<label> skipped: <理由>"
