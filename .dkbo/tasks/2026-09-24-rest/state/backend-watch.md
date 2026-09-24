status: done
wave: 1
current: 修復輪完成（⑦ dk-task-new 走 --ensure、⑧ 結案後不叫回）；完整 tests/run.sh 756 全 ok
touched:
  - .dkbo/bin/dk-watch
  - .dkbo/bin/dk-msg
  - .dkbo/bin/dk-task-new
  - tests/unit/09_watch.bats
  - tests/unit/26_watch_events.bats
  - tests/unit/06_msg.bats
  - tests/unit/05_task_new.bats
todo: []
report: state/backend-watch.report.md
notes: watch.log／watch died 契約形狀未變更；額外用選用的 env --default-signal（有才用）讓 INT trap 生效；修復輪 +2 測試（05、06 各 1），見 report 末段
