status: done
wave: 1
current: 修復輪（reviewer-a Minor 1、2）完成：38（16 條）全綠、shellcheck 零警告；完整套件 772/772 ok
touched:
  - .dkbo/bin/dk-status
  - .dkbo/status-schema.md
  - tests/unit/38_status.bats
todo: []
report: state/backend-status.report.md
notes: 每任務 1 awk（加檔頭串流，防 jq -R 多檔時檔尾無換行黏行）＋1 jq；jq 1.5 相容只靠寫法、未在 1.5 實跑
notes: 修復輪 +1 測試（38 第 16 條），測試總數 771 → 772，CHANGELOG 條數要 backend-docs 重填
