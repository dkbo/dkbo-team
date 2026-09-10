| 日期 | 來源 | 一句描述 | 建議處理 |
|---|---|---|---|
| 2026-09-10 | 外部評論（見 docs/design/2026-09-10-external-review-response.md ①） | bin 下 14 支腳本直呼 herdr，收攏進 `lib/herdr.sh` 一層，其他檔只呼叫該層 | 雜務，--code，一位 it |
| 2026-09-10 | 外部評論（同上 ⑤） | 新增 `DK_WAVE_TIMEOUT_MIN` 整波逾時；dk-watch 超過即推 `[TIMEOUT] wave` 給領導 | 小任務，一位 backend + reviewer |
| 2026-09-10 | 外部比較（見 docs/design/2026-09-10-skill-chain-comparison.md） | brief 所有權表加「獨佔資源」欄（如 `db`、`port:3000`、`docker`）；`dk-brief-check` 檢查同一波內兩位成員不得宣告同一獨佔資源，違反即 FAIL | 小任務，一位 it |
