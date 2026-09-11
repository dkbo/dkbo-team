| 日期 | 來源 | 一句描述 | 建議處理 |
|---|---|---|---|
| 2026-09-10 | 外部評論 ① | bin 下 14 支腳本直呼 herdr，收攏進 `lib/herdr.sh` 一層，其他檔只呼叫該層 | 雜務，--code，一位 it |
| 2026-09-10 | 外部評論（同上 ⑤） | 新增 `DK_WAVE_TIMEOUT_MIN` 整波逾時；dk-watch 超過即推 `[TIMEOUT] wave` 給領導 | 小任務，一位 backend + reviewer |
| 2026-09-10 | 外部 skill 鏈比較 | brief 所有權表加「獨佔資源」欄（如 `db`、`port:3000`、`docker`）；`dk-brief-check` 檢查同一波內兩位成員不得宣告同一獨佔資源，違反即 FAIL | 小任務，一位 it |
| 2026-09-11 | 0.2.0 查證 | `dk-watch` 三處推送（`:59`、`:81` 的 BLOCKED 與 `:97` 的 TIMEOUT）直接 `herdr agent prompt` 領導，沒等 `--until idle`；而守望觸發的前提正是領導忙著。若「提示送給 working 的 agent」是丟掉而非排隊（`KIND_PROMPT_QUEUES` 三個 kind 仍是 unknown），通知會恰好在最需要時無聲消失 —— 與 d7630a6 修掉的是同一元件的另一條無聲失效路徑。改成等 idle 再送，但背景迴圈不得被長等待卡住（`dk-msg` 預設等 300 秒）。領導回雜務員工那條（LEADER.md 第 13 行）同一個問題 | 小任務，一位 backend + reviewer |
