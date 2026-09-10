# dkbo：回應外部評論與路線定調

日期：2026-09-10
狀態：已定案
對應版本：0.1.2

## 1. 背景

一位外部評論者讀過 repo 後給了一份長評：肯定 Leader 不寫碼、wave 加審查閘、多模型、記憶外置、repo-native 五點，並提出七項不足與一個「AI Team OS」的重構方向。本文件記錄我們的事實更正與逐點裁定，避免未來的領導或貢獻者重提同樣的問題。

## 2. 定調

dkbo 的定位是：**一位人類、一位領導、同時 3 到 6 位員工、一個 herdr 視窗**。這個規模足以應付九成以上的專案。所有「往幾十個 agent 擴展」的建議一律不採納，不是做不到，而是那是另一個產品。此決定已寫進 `.dkbo/decisions.md`。

## 3. 事實更正

評論有四處與 0.1.2 的實況不符：

| 評論說法 | 實況 |
|---|---|
| 版本 0.1.1 | 0.1.2，見 `.dkbo/VERSION` 與 CHANGELOG |
| 缺 deterministic verification layer，AI review 直接代表品質 | `dk-wave-close` 已有三道機械閘：跑 `DK_TEST_CMD` 且失敗不放行、每位 dev 的 report 必須有 `## 測試` 內容、touched 清單比對檔案所有權。AI 裁定只是其中一道 |
| Wave Close 應與 Merge 分開 | 本來就分開。`dk-wave-close` 只在 worktree 內 commit；合併是關卡③人類拍板 report 後由 `dk-task-close` 執行 |
| Reviewer 是「另一個 AI」，可能自己審自己 | reviewer 預設用與 dev 不同的 kind，`DK_ISOLATED=1` 只讀、不能改碼、只能對領導傳訊；dev 看不到 reviewer 原始意見，由領導轉成 BUG。是刻意的隔離設計 |

## 4. 逐點裁定

| # | 評論建議 | 裁定 | 說明 |
|---|---|---|---|
| ① | herdr 抽象層，加 tmux／Docker／cloud adapter | 部分採納 | 不做多 adapter。只把 bin 下 14 支腳本的 herdr 呼叫收攏進 `lib/herdr.sh`，其他檔不直呼。成本低，日後若真要換底層才有門。已入 BACKLOG |
| ② | 檔案訊息改 event bus | 不做 | 3 到 6 個 pane 下 messages.log 可讀、可 grep、進 git，優於任何 bus。規模不變，瓶頸不存在 |
| ③ | 加 hard gates（test、lint、typecheck、build） | 不改 | 三道閘已存在（見第 3 節）。lint／build 請串進 `DK_TEST_CMD`，例如 `pnpm lint && pnpm test`；不另開變數 |
| ④ | Wave Close 與 Merge 分開 | 不改 | 本來就分開（見第 3 節） |
| ⑤ | Cost／token／時間預算 | 採納時間，不做金額 | 三家 CLI 沒有可 script 的統一計價，金額會是假數字。新增 `DK_WAVE_TIMEOUT_MIN` 整波逾時，由 dk-watch 推 `[TIMEOUT]`。修復迴圈一次、同對 QUESTION 兩則、reviewer 逾時，已是既有的次數與時間預算。已入 BACKLOG |
| ⑥ | Agent capability registry 與評分 | 不做 | 三種 kind、六個角色，領導照 `roles/` 選人比評分準。評分要樣本量，小團隊永遠不夠 |
| ⑦ | 任務 DAG 與 parallel scheduling | 不做 | brief 的波次表就是領導手工壓平的 DAG，同波成員即平行，跨波即依賴 |
| — | Observability dashboard | 不做 web，現有即是 | `dk-resume` 印的本波、裁定、未處理訊息、各員工 state、在線員工就是純文字 dashboard，隨時可跑。`.dkbo/README.md` 已補一句說明 |
| — | 重構成 AI Team OS | 不做 | 與第 2 節定位相反 |

## 5. 結果

- `.dkbo/decisions.md`：新增五則（定位總綱、不做 event bus、不做 registry 評分、不做 DAG、不做金額預算）。
- `.dkbo/tasks/BACKLOG.md`：新增兩項（herdr 收攏、整波逾時）。
- `.dkbo/README.md`：dk-resume 補「隨時可跑當狀態總覽」。
- 不改任何腳本。
