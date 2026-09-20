status: done
wave: 1
current: review 1 Important 1 已修（含同類的獨佔資源那一層）；488/488 綠、shellcheck 零警告
touched:
  - .dkbo/lib/repos.sh
  - .dkbo/lib/ownership.sh
  - .dkbo/lib/common.sh
  - .dkbo/lib/kinds.sh
  - .dkbo/kinds/claude.sh
  - .dkbo/kinds/codex.sh
  - .dkbo/kinds/agy.sh
  - .dkbo/bin/dk-brief-check
  - .dkbo/templates/brief.md
  - .dkbo/settings.env
  - .dkbo/skills/init/SKILL.md
  - tests/helpers.bash
  - tests/unit/33_repos.bats
  - tests/unit/16_brief_check.bats
  - tests/unit/22_ownership.bats
  - tests/unit/03_kinds.bats
  - tests/unit/01_common.bats
  - tests/unit/15_brief_lib.bats
report: state/backend-repos.report.md
notes: 契約表要補 dk_changed_repo_files TASK_DIR N（舊的 dk_changed_files WT BASE 原樣留著）。Important 1 的同類洞在獨佔資源那一層也修了。Important 2（契約表 DK_SETUP_CMD 執行點寫 dk-task-new，與 AC20 矛盾）是 brief 的問題，不是我的檔。
