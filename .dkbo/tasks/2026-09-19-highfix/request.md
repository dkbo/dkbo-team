# BACKLOG 三條高嚴重度缺陷 — 需求原文

把人講的原話**逐字**抄在下面。不要摘要、不要改寫、不要先做技術轉換 ——
brief 才是轉換的產物，這一份是用來比對「brief 有沒有漏掉人要的東西」的基準。
外部文件（spec、issue、對話紀錄）請把相關段落整段貼進來，不要只留連結：
連結會死，而這個檔案要活到任務歸檔之後還有人讀得懂。

---

（原文從這裡開始）

## 人在同一段對話裡講的話（2026-09-19，依序逐字）

> 目前dkbo 跟 superpower 改成怎樣了???  dkbo 有沒有畫蛇添足的流程

（領導回答了 0.9.0 現況與五處可能畫蛇添足的地方，並在結尾寫：
「如果要動，我的建議順序是：先修 dev DONE 聚合的競態，再把 Minor 匯總改成
dk-review-pack --task 自動從 reviewer report 收集，最後把 gate b 降成警告或只留
『不適用』的存在檢查。」）

> dkbo 會執行到 superpower 嗎?

（領導回答：dkbo 腳本不會呼叫 superpowers，但 claude 員工因使用者層 plugin 被動帶著它。）

> 目前這專案要拿走superpower 了，可以開始用自己框架流進行開發

（領導在專案層停用 superpowers plugin、刪 `.superpowers/`，並在結尾寫：
「目前 BACKLOG 裡最值得先做的是 dk-watch 的 dev 完成聚合競態，那條在 flowgap 實跑中
出過兩次事故且會讓真完成永遠不通知。」）

> ok 繼續

## 領導對範圍的解讀（不是人的原話，關卡①請人確認）

人只點頭了「繼續」，沒有指定範圍。領導把範圍定為 `tasks/BACKLOG.md` 裡 flowgap 實跑
記下的**三條「高」嚴重度缺陷**（dk-watch 的 dev 聚合競態、dk-wave-close gate c 洩漏領導
環境、agy 啟動橫幅命中裸 `quota`），出 0.9.1。「Minor 匯總改自動收集」與「gate b 降級」
是設計變更、人尚未同意，**不在本任務**。

## 三條缺陷在 BACKLOG 的原文（逐字）

| 2026-09-19 | flowgap 實跑 | `kinds/agy.sh` 的 `KIND_QUOTA_RE` 含裸 `quota`，而 agy 啟動橫幅固定印 `bal@… (Antigravity Starter Quota)`、`screen_hits` 用 `grep -qiE` —— 直接用 grep 驗過確實命中，所以**任何 agy 員工只要 watcher 讀到啟動畫面就會被判成撞額度**。（註：flowgap 這一次的熔斷不是誤判，agy 真的耗盡了；這是還沒被觸發過的 latent 缺陷，不是事故報告） | 把 agy 的式子收窄成真正的耗盡訊息（`quota reached`、`quota exceeded`、`resource exhausted`、`rate limit`），不要用裸 `quota`；順手檢查 `dk-watch:193` 那條通用 `(quota?)` 標記式有沒有同樣的問題 |
| 2026-09-19 | flowgap 波 1 事故 | `dk-wave-close` 的 gate c 用 `bash -c "$DK_TEST_CMD"` 跑測試，繼承領導整包 `DK_*` 環境。對 dkbo 自己的 repo，這讓測試裡的 `dk-task-new` 在**真實 repo** 建 worktree（實際發生：7 個 worktree、8 個分支）。任何專案只要測試會讀 `DK_*` 都可能中招 | gate c 改成 `env -u DK_ROOT -u DK_PROJECT_ROOT -u DK_TASK_DIR … bash -c`，或用白名單式的乾淨環境。波 2 Task 6 要動 dk-wave-close，順便一起改 |
| 2026-09-19 | flowgap 波 3 | `dk-watch` 的 dev 完成聚合只看 `^status: done`，但 state 檔跨波共用、`.devdone` 標記逐波 —— **任何成員跨兩波以上，第二波起一開波就收到假的「dev 全員完成」**。實測發生。若領導信了，四道閘會全數放行一個零產出的波（report 跨波留存過 gate b、空 diff 過 gate d、測試照綠過 gate c） | 聚合改成同時要求 state 的 `wave:` 欄等於 `DK_WAVE`（最便宜），或沿用 0.8.0 reviewer 那套 cksum，在 dk-spawn 時存下 state 快照。**實測兩次（波 3、波 4）**：精確機制是「開波到員工寫下第一份 state」之間的競態，誤發後 `.devdone` 標記寫成 delivered，**真正完成時永遠不再通知**，領導從此只能手動追蹤。嚴重度高：既會靜默放行空波，也會讓真完成靜默 |
