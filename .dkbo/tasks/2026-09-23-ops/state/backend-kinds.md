status: done
wave: 4
current: AC18 完成：hit 截斷改按字元、09 補中文樣本、Minor 全補
touched:
  - .dkbo/bin/dk-watch
  - .dkbo/bin/dk-resume
  - .dkbo/lib/kinds.sh
  - tests/stub/herdr
  - tests/unit/09_watch.bats
  - tests/unit/10_resume.bats
  - tests/unit/34_kind_down.bats
todo:
report: state/backend-kinds.report.md
notes: 全套 tests/run.sh 627 條全過；shellcheck 零警告。領導提醒：共用 worktree 補紅不得用 git stash（會讓夥伴讀到舊碼），下次改用 cp 到 /tmp 獨立目錄
