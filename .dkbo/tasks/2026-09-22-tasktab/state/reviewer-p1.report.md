# tasktab 計畫審查（reviewer-p1）

## 需求覆蓋
request 的唯一明確要求：`dk-leader --run` 第 2 點「開 workspace」改成「在人所在的同一個 workspace 開一個新 tab」，且沿用原本的 label/tab 名 `dk/<short>`、不搶焦點、原 workspace 不動。

逐項對照：
- 「同一個 workspace 開新 tab」→ brief 目標段第 1 行、AC1 完整接住。
- 「同一個 workspace＝人叫 /dkbo-run 時所在的那個」→ request.md 括號說明的 `DK_WORKSPACE`／`HERDR_WORKSPACE_ID` 退路，AC1、共用契約「.task.env 的 DK_TASK_TAB」列都有對應。
- 「不搶焦點、原 workspace 不動」→ AC1 的 `--no-focus`、「不再呼叫 workspace create/get/close」隱式保證。
- 「領導評估可行並列出要動的地方」後人才說 `dkbo-plan`（等同同意擴大範圍）→ brief 把連帶要動的 rollback、幂等、`dk-task-close`、`dk-resume`、文件、版號都納入，屬於人已默許的延伸，不是 reviewer 該擋的越界。

未見漏接的 request 段落。

## 驗收標準可驗證性
AC1–AC10 均附具體指令形狀、欄位名、exit code 或 bats 檔號，可機械判定。逐條檢查未見無法判定的敘述；AC7「全部改成 tab 的說法」看似主觀，但落地成 `25_docs_policy.bats`／`04_docs.bats` 的斷言即可驗證，不算缺口。

## 檔案所有權
兩位成員（backend-ws／backend-docs）的可改清單彼此不重疊；backend-docs 對 `skills/run/**`、`.dkbo/bin/**`、`tests/stub/**` 只有唯讀，符合「可改優先於只讀」規則，未見重疊或衝突。AC1–AC9 提到的每個檔案都能在所有權表中找到擁有者，未見遺漏。獨佔資源欄兩列皆空，本任務不涉及 db/port 等執行環境競用，合理。

## 波次切法
### Important
**wave1「文件」（backend-docs）完成條件寫「tests/run.sh 全綠」，等於隱性依賴 wave1「實作」（backend-ws）先完工**（brief.md 波次表第 58 行）。
backend-ws 那列（第 57 行）的完成條件只列自己擁有的 12 個 bats 檔＋自身 shellcheck，並未要求 `tests/run.sh` 全綠；但 backend-docs 那列卻要求全綠，而全綠的判定包含 backend-ws 正在改的 13/12/10/23/05/06/09/26/30/07/01/18 全部檔案。兩人共用同一個 worktree，若 backend-docs 先做完想收工，會被 backend-ws 尚未完成、尚未通過的測試卡住 —— 這違反「同一波是平行工作」的設計初衷，實質把兩人序列化。
建議改寫：backend-docs 完成條件把「tests/run.sh 全綠」改成「21/25/04 全過（自己擁有的檔）」，全套件 `tests/run.sh 全綠` 只留在 AC10／任務結案（`dk-task-close`／`dk-wave-close`）層級判定，不放進單一成員的完成條件。

## Minor
- backend-docs 的難度標「S」，但 AC9 要求在真實 herdr（nested dktest session）跑一次探針並把 NOTE 行貼進 report，屬於手動、非 CI 內步驟，實際耗時可能不只是 S；建議領導評估是否升到 M，或在 process.md 註記「AC9 手動步驟不計入 S 的估時」。

## 結論
要改 1 處
