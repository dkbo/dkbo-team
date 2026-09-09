# 通訊協定

所有訊息一律用 `$DK_ROOT/bin/dk-msg <對象> "[類型] 內文"`（下文簡寫 dk-msg；`DK_ROOT` 是你 pane 的環境變數）。腳本補寄件人、時間，寫進 messages.log，並等對方閒置才送。內文一到三句、≤200 字元，細節寫在你的 state 檔並指路，不貼程式碼。對象可寫 `leader`，腳本會解析成本任務的領導。

## 類型
| 類型 | 方向 | 何時 |
|---|---|---|
| TASK | 領導→員工 | 補充派工 |
| DONE | 員工→領導（也可同時通知同波夥伴，如 dev→qa） | 完成，且 state 已寫 `status: done` |
| BUG | 員工→員工 | 附重現方式，指向 state |
| FIXED | 員工→員工 | 修好了，請重驗 |
| QUESTION / ANSWER | 任意 | 釐清介面、契約 |
| ESCALATE | 員工→領導 | 需要決策、想動不屬於自己的檔、修一次未好、上下文吃緊（寫 `[ESCALATE] context`） |
| DECISION | 領導→員工 | 決策結果 |
| STOP | 領導→員工 | 停手，寫 state 收尾 |

## 規則
- 同一波員工可以互相傳訊。`DK_ISOLATED=1` 的員工只能對 leader 傳訊。
- 修復迴圈上限一次，以同一個 bug 計：BUG → FIXED → 再驗仍失敗 → qa 直接 ESCALATE，不再回 dev。
- QUESTION 若 brief 沒有答案，被問的人不得自己決定；提問者 ESCALATE。同一波同一對員工 QUESTION 最多兩則。
- 任何「選 A 或 B」、任何共用契約的變更，一律 ESCALATE。
- 只能修改 brief 檔案所有權劃給你的檔案。要動別人的檔 → 用 QUESTION 請擁有者改，或 ESCALATE。
- 禁止使用 subagent、禁止自行開 pane 或啟動其他 agent。
- 只有本人能寫自己的 state 檔；員工不寫 process.md、brief.md、report.md。
- dk-msg 回傳非零（對方卡住、送不進）：把這件事寫進 state 的 `blocked_by`，繼續做別的事。

## state 檔（≤20 行，每完成一個子步驟就覆寫）
```
status: working | blocked | done
wave: 1
current: 正在做什麼（一句）
touched:
  - src/api/login.ts
todo:
  - 錯誤碼對齊前端
blocked_by: （無則省略）
notes: 給接手者的必要事實，≤5 行
```
DONE 前 `touched` 必須完整，領導會拿它比對所有權。

雜務員工（`chore-*`）沒有任務綁定，不適用上面的 state 檔／dk-msg 流程；他們以 `herdr agent prompt "$DK_LEADER" "[DONE] from <agent>: ..."` 作為回報第一句。
