status: done
wave: 2
current: AC8–AC12 五支腳本全部落地，533/533 綠、我的五個檔 shellcheck 零警告
touched:
  - .dkbo/bin/dk-spawn
  - .dkbo/lib/prompt.sh
  - .dkbo/bin/dk-wave-open
  - .dkbo/bin/dk-review-pack
  - .dkbo/bin/dk-wave-close
  - .dkbo/templates/brief-member.md
  - tests/unit/07_spawn.bats
  - tests/unit/18_wave_open.bats
  - tests/unit/19_review_pack.bats
  - tests/unit/08_wave_close.bats
report: state/backend-gates.report.md
notes: 27_qa_gate.bats 在我的所有權內但不需改動（新增那句提示只在多 repo 出現）。
  單 repo 的 --add-dir 只放主樹：AC1 不准放寬 07_spawn 既有斷言，與 AC8 字面衝突，見報告〈疑慮〉一。
  gate c 單／多 repo 走兩條分支，單 repo 維持 0.9.2「不管有沒有變更都跑」。
  backend-ws 收工後重跑全套：533/533 綠；它把「已實體化」判別器換成 .repos，與我用 DK_WORKTREE 空值擋開波不衝突（legacy 任務有 worktree 沒 .repos，仍要放行）。
