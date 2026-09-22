# 任務改開 tab — 需求原文

把人講的原話**逐字**抄在下面。不要摘要、不要改寫、不要先做技術轉換 ——
brief 才是轉換的產物，這一份是用來比對「brief 有沒有漏掉人要的東西」的基準。
外部文件（spec、issue、對話紀錄）請把相關段落整段貼進來，不要只留連結：
連結會死，而這個檔案要活到任務歸檔之後還有人讀得懂。

---

（原文從這裡開始）

2026-09-22，人在本 repo 的 Claude Code session 裡問「目前 dkbo 的流程是怎樣」、再問「dkbo-run 會開啟甚麼 ?」。
領導回覆「交棒時（`dk-leader --run`，一個任務只做一次）」會開的東西，其中第 2 點原文如下（人接下來的話就是指這一點）：

> 2. **一個 herdr workspace**：label 與 tab 名都叫 `dk/<short>`，cwd 指向主樹（因為 `.dkbo/` 和腳本都在主樹）。它不搶焦點，你原本的 workspace 不動。

人說：

> 2 可能要調整， 要在同一個 herdr workspace 開一個新的 tab 才對

領導評估可行並列出要動的地方後，人說：

> dkbo-plan

（以上為全部原話。「同一個 herdr workspace」指人叫 `/dkbo-run` 時所在的那個 workspace，也就是 `dk-task-new` 記進 `.task.env` 的 `DK_WORKSPACE`／pane 環境的 `HERDR_WORKSPACE_ID`。）
