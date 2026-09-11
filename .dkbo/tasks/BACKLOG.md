| 日期 | 來源 | 一句描述 | 建議處理 |
|---|---|---|---|
| 2026-09-10 | 外部評論 ① | bin 下 14 支腳本直呼 herdr，收攏進 `lib/herdr.sh` 一層，其他檔只呼叫該層 | 雜務，--code，一位 it |
| 2026-09-10 | 外部評論（同上 ⑤） | 新增 `DK_WAVE_TIMEOUT_MIN` 整波逾時；dk-watch 超過即推 `[TIMEOUT] wave` 給領導 | 小任務，一位 backend + reviewer |
| 2026-09-10 | 外部 skill 鏈比較 | brief 所有權表加「獨佔資源」欄（如 `db`、`port:3000`、`docker`）；`dk-brief-check` 檢查同一波內兩位成員不得宣告同一獨佔資源，違反即 FAIL | 小任務，一位 it |
| 2026-09-11 | e2e 實跑 ⑨ | `dk-task-close` 不 commit 任務記憶：結案後整個 `.dkbo/tasks/<t>/` 仍是 untracked、`INDEX.md` 只是 modified。README 與 decisions.md 都聲稱記憶「進 git」，實際沒有任何一步做。結案時應一併 add + commit 任務目錄、INDEX、decisions | 小任務，一位 backend |
| 2026-09-11 | e2e 實跑 ④ | `dk-task-new` 只在 agent 完全沒名字時才 rename 成 `leader-<short>`；領導 pane 若已有名字就靜默跳過，員工的 `dk-msg leader` 與 dk-watch 推送全部送不到且無警告。條件應改成「不等於 `leader-<short>` 就 rename」 | 雜務，--code，一位 backend |
| 2026-09-11 | e2e 實跑 ⑩ | `PROTOCOL.md` 的 `[FIXED]` 只定義員工→員工，領導轉來的 BUG 修好後 dev 只能回 `[DONE]`，於是 RUNBOOK 的「messages.log 有 FIXED」驗收條件結構上永遠不成立。補規範或改驗收條件 | 雜務，一位 pm |
