# dkbo：對照專案內嵌 skill 鏈的比較與裁定

日期：2026-09-10
狀態：已定案
對應版本：0.1.3

## 1. 背景

另一個專案的團隊把自家「brainstorming → spec → plan → readiness-review」skill 鏈與 dkbo 並排比較。兩者都跑在 herdr 上、都是 lead + 工單 + 波次 + 外部記憶；差別是 dkbo 是通用可攜 kit（shell 腳本硬驗），對方是專案內嵌 skill 鏈（prompt 自律 + 領域知識）。對方結論是借 dkbo 的多模型 reviewer、機械閘、blocked/timeout 守護三樣，不整套換過來。本文件記錄我們反向對照後的裁定。

## 2. 對方描述與 0.1.3 實況

對方對 dkbo 的描述經逐項對照腳本，屬實：
- 隔離鎖只有檔案所有權 glob（`dk-brief-check` 事前驗重疊、`dk-wave-close` 事後比對 touched）。
- 驗收是統一 `DK_TEST_CMD` 跑全套，加 dev report 必有 `## 測試` 段；波次表「完成條件」欄是自由文字，不被機器執行。
- 上游只有 `dk-task-new --from plan.md` 選配，brief 由領導現寫。

## 3. 裁定

| # | 對方作法 | 裁定 | 說明 |
|---|---|---|---|
| ① | `resources` 獨佔鎖（stack／db 獨佔） | 採納 | worktree 隔離檔案，不隔離執行環境。同波兩位 dev 仍會對同一 dev DB 跑 migration、搶 port、重啟同一組 docker。所有權表加「獨佔資源」欄，`dk-brief-check` 檢查同波不得重複宣告。已入 BACKLOG |
| ② | 上游 brainstorming → spec → plan 鏈，plan 才是真相 | 不做 | dkbo 的定位是領導把口頭需求寫成 brief 並過關卡①。有 plan 時 LEADER.md 已規定「不重寫內容，只對應驗收、劃所有權、分波」，即等價做法 |
| ③ | 每 task 自帶 Verify 指令與預期輸出 | 不做 | 單 task 指令快，但抓不到跨 task 互相破壞；dev 的 `## 測試` 段已是各自的驗證紀錄。若日後加，只能是 `DK_TEST_CMD` 之外的加分項。已入 decisions |
| ④ | 共用主工作樹，只有無資源衝突的 task 開 worktree | 不做 | 員工只看得到已 commit 的檔案是刻意隔離；共用樹會讓 touched 比對失去意義。已入 decisions |
| ⑤ | 領域知識 skill（migration-review、go-pg）與 guard.py hook | 不做 | 專案內嵌物；通用 kit 的對應位置是 `PROJECT.md` 與 `roles/` 客製，不進核心 |

## 4. 交叉印證

對方要借的三樣（多模型 reviewer、機械閘、blocked/timeout 守護）與上一份外部評論（`2026-09-10-external-review-response.md`）肯定的重點一致。兩份獨立來源印證 0.1.x 的投入方向。

## 5. 結果

- `.dkbo/tasks/BACKLOG.md`：新增一項（同波獨佔資源鎖）。
- `.dkbo/decisions.md`：新增兩則（不做 per-task Verify 取代全套測試、不做共用主工作樹）。
- 不改任何腳本。
