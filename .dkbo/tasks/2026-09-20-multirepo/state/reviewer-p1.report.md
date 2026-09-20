## 需求覆蓋
- request 四條（workspace-per-task / N repo 各切 worktree / `/dkbo-run` 開新 tab、tab 名=分支名／workspace 名 / 該 tab 初始 session 是 leader 且 AI CLI 側 agent 名改成 workspace 名）與卡片原文，逐條對照：
  - 第 1 條（一個任務一個 workspace）：brief 目標段 + AC3 有接住。✅
  - 第 2 條（N repo 各切同名分支 worktree）：AC2 有接住。✅
  - 第 3 條（`/dkbo-run` 開新 tab，tab 名=分支名／workspace 名）：**有缺口**。brief 波次表 wave1 backend-ws 那列把「開 workspace、tab rename」放進 `dk-task-new`，AC3 也是講 `dk-task-new` 用 `herdr workspace create` 開 workspace、改 tab 名。但 request 原文明講是 **`/dkbo-run`** 開新 tab，不是「建立任務時」開。brief 全文沒有一句話講清楚 `dk-task-new` 跟 `/dkbo-run` 的呼叫關係（`/dkbo-run` 是不是就是呼叫 `dk-task-new` 的入口？還是 `dk-task-new` 在規畫階段就先開了 workspace，`/dkbo-run` 只是後續交棒）。如果 workspace／tab 是在建任務時就開好，那「`/dkbo-run` 開新 tab」這件事就對不上，需要在目標段或 AC3 補一句釐清時序。（brief.md 目標段、波次表 wave1 backend-ws 列）
  - 第 4 條（該 tab 初始 session 是 leader，AI CLI 側 agent 名改成 workspace 名）：AC6「起同名領導」有接住「初始 session 是 leader」，但「agent 名改成 workspace 名」這件事對應不明確，詳見下面驗收標準段的第 2 點。
  - 卡片「herdr workspace 只吃一個 cwd，其餘靠 pane --cwd」：AC2/AC8/共用契約 `DK_ADD_DIRS` 有接住（workspace 只 `--cwd` 主樹，其餘 repo 靠 `dk-spawn` 組 `--add-dir`）。✅

## 驗收標準可驗證性
- AC1–AC5、AC7–AC16、AC18：文字明確，逐條可判過或不過。
- **AC6「在 DK_ROOT_PANE 起同名領導」的「同名」指涉不清。** request 明講「把它在 AI CLI 那側的 agent 名改成 workspace 名」（即 `dk/<short>`），但 AC6 前一句是「清掉呼叫者 pane 的 `leader-<short>`」，讀起來「同名」比較像是延用 `leader-<short>` 這個舊命名，而不是改成 workspace 的 tab 名 `dk/<short>`。這兩個名字不一樣，AC6 沒有明講要對齊哪一個，會導致 dev 跟 reviewer（波審查）各自解讀。改寫建議：「起一個名字為 `dk/<short>` 的領導」，把比對目標寫死。（brief.md AC6）
- **AC17 對應的完成條件有閘卡缺口。** AC17 要求「發版前在真 herdr 跑過一次並把 NOTE 行貼進 report.md」，但波次表 wave3（backend-docs）完成條件只寫「整合腳本語法可跑」，沒有要求真的對真 herdr 跑過、也沒有要求把 NOTE 貼進 report。照現在的完成條件，backend-docs 只要腳本語法過關就能算完成，AC17 這條實質內容可能被漏掉，直到 `dk-task-close` 前才被發現（甚至可能不會被機械擋下，因為這是人工步驟不是自動閘）。建議在 wave3 完成條件加一句「AC17：已對真 herdr 跑過並把 NOTE 貼進 report」。（brief.md AC17、波次表 wave3）

## 檔案所有權
- **三列（backend-repos、backend-gates、backend-docs）的「只讀」欄用了跟自己「可改」清單重疊的萬用字元，自相矛盾：**
  - backend-repos：可改列了 `.dkbo/bin/dk-brief-check`，只讀又列 `.dkbo/bin/**`（涵蓋 dk-brief-check 自己）。
  - backend-gates：可改列了 `.dkbo/lib/prompt.sh`，只讀又列 `.dkbo/lib/**`（涵蓋 prompt.sh 自己）。
  - backend-docs：可改列了 `.dkbo/bin/dk-version`，只讀又列 `.dkbo/bin/**`（涵蓋 dk-version 自己）。
  - 對照組：backend-ws 那列沒有這個問題（只讀是 `.dkbo/lib/**, tests/helpers.bash`，跟自己可改的 `.dkbo/bin/*`、`.dkbo/skills/{run,plan}/**` 不重疊），可見這是前三列個別的疏漏，不是刻意設計。這份表本身就是本任務要建的 `dk-brief-check` 重疊判定的輸入基準，來源表自相矛盾會讓「誰能改什麼」在字面上有兩種讀法。建議修法：只讀欄位的萬用字元一律排除自己可改清單裡列的具體檔案（或在表格加一句慣例說明「可改的具體檔案優先於只讀的萬用字元」）。（brief.md 檔案所有權表，backend-repos／backend-gates／backend-docs 三列）
- 除上述矛盾外，四個成員之間的「可改」集合彼此不重疊，未見遺漏（AC1–AC18 逐條都能對到至少一個成員的可改清單，含 AC15 這種跨三個成員各改各段文件的情況，wave1 兩個成員的敘述有分別點名 init skill／run+plan skill，對得上各自的所有權）。獨佔資源欄四列皆為 `—`，本任務性質（純檔案讀寫）沒有明顯共用執行環境要佔，合理。

## 波次切法
- 波 1（backend-repos ∥ backend-ws）：backend-ws 該波明講「本波 worktree 仍只切主 repo」，刻意不碰 `lib/repos.sh` 的多 repo 能力，兩人在波 1 內互不依賴，順序合理。
- 波 2（backend-ws ∥ backend-gates）：兩人都消費波 1 backend-repos 產出的 `lib/repos.sh` 契約（`.repos` 格式、glob 前綴、`DK_ADD_DIRS`），依賴都指向前一波已完成的擁有者，波內兩人彼此不互相等待，合理。
- 波 3（backend-docs 單人）放最後，等程式行為都定案才寫文件與版號，合理。
- 共用契約表六條都指定了單一擁有者，變更流程統一寫「動它要先 ESCALATE」，跟 PROTOCOL 規則一致。
- 未發現「同一波裡有人其實要等另一個人的產出」的情況。

## Minor
- AC14「結尾印出要人自己關的指令」沒有給出確切文字，dev 跟波審查可能各自認定不同的輸出格式算不算過；可以補一句最低要求（例如「輸出裡含 `herdr workspace close` 字樣與 workspace id」）。
- 波次表只有波 1 backend-repos 那列在完成條件寫「shellcheck 零警告」，其餘幾列沒重複寫；雖然 AC18 是最終兜底閘，但個別波若跳過 shellcheck 檢查，錯誤要留到最後才浮現，拉長除錯距離。可以考慮每波完成條件都補一句 shellcheck。
- 本次切片只指定讀 request.md 與 brief.md，plan.md（14 條決策）不在審查範圍內。若「AI CLI 側 agent 名」這個問題的答案其實已經寫在 plan.md 的決策裡，建議領導確認 brief（尤其 AC6）已經把該決策的結論具體寫出來，不要只靠 plan.md 交叉參照。

## 結論
要改 4 處
