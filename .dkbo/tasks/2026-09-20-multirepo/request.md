# 多 repo workspace — 需求原文

把人講的原話**逐字**抄在下面。不要摘要、不要改寫、不要先做技術轉換 ——
brief 才是轉換的產物，這一份是用來比對「brief 有沒有漏掉人要的東西」的基準。

---

（原文從這裡開始）

## 2026-09-20 本次對話

人在看完「dkbo 目前流程」簡報後，貼上簡報裡「設計待寫 · 多 repo workspace」那張卡片的截圖，說：

> 需要開始規畫這個

卡片原文（簡報第 14 張，領導從記憶整理出來的，不是人的原話）：

> 設計待寫
> 多 repo workspace
> 一個任務等於一個 herdr workspace，N 個 repo 各切同名分支的 worktree。herdr workspace 只吃一個 cwd，其餘靠 pane --cwd。spec 還沒寫。

## 2026-09-19 對話（領導記憶檔 `dkbo-multirepo-workspace-plan` 的整理，**非逐字**；當時的原始對話已不在手上）

人要的形狀，四條：

1. 一個 brief（任務）= 一個 herdr workspace，不再寄生在領導的 workspace 佔 tab 1 左欄。
2. workspace 裡有多個獨立 git repo（前端／後端／shared 各一個 repo），每個都自動切出同一個分支名 `dk/<short>` 的 worktree。
3. `/dkbo-run` 開新 tab，tab 名 = 分支名／workspace 名。
4. 該 tab 的初始 session 就是該任務的 leader，並把它在 AI CLI 那側的 agent 名改成 workspace 名。

同一份記憶還記了當時查證過的地基與地雷（herdr `workspace create --cwd` 只吃一個 cwd；所有權要長出 repo 維度；`dk-task-close` 合 N 個 repo 失去原子性；`DK_TEST_CMD` 從一條變每 repo 一條；`.dkbo/` 要指定主 repo）。那些是領導的分析，不是人的需求，所以不列在這裡；見 plan.md。

同一天的定序：先做 `dk-brief-review`（已在 0.8.x／0.9.0 出貨），接著寫這份 spec。

## 2026-09-20 追加（看完關卡①預告的四個問題後）

> claude 有支援 rename 功能

（領導查證：`claude --help` 有 `-n, --name <name>`「Set a display name for this session（session picker 與 terminal title）」；互動中對應 `/rename`。）

## 2026-09-20 追加（關卡①討論）

> 還有 workspace 下的 repo 如果有前端會有 node_modules 要怎避免複製大量資料?? 能用甚麼方式

領導給了四個選項（pnpm store、symlink 主樹 node_modules、cp -al、回主樹跑測試）並建議做成 `DK_SETUP_CMD` 鉤子；人回：

> 加進 brief，用 pnpm 那個方式

## 2026-09-20 追加（關卡①第二輪）

領導列出三件要確認的事，第一件是「workspace 在計畫階段就開，不是 /dkbo-run 時才開」。人回：

> - workspace 在計畫階段就開，不是 /dkbo-run 時才開 前面都還在計畫階段?? 有可能計畫完不做
