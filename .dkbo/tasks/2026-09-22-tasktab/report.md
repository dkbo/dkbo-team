# 任務改開 tab 結案
結果：merged   分支：dk/tasktab   波數：4

## 完成
`dk-leader <short> --run` 實體化任務時不再開一個新的 herdr workspace，改在任務所屬的 workspace 底下用 `herdr tab create` 開一個 label `dk/<short>` 的新 tab，在它的根 pane 起執行領導交棒。出貨 0.11.0（`feat(tab)!`）。

- **AC1** `dk-leader:148` 一次 `herdr tab create --workspace "$ws" --cwd "$DK_PROJECT_ROOT" --label "dk/$short" --no-focus --env DK_ROOT=… --env HERDR_ENV=1`，讀 `.result.tab.tab_id`／`.result.root_pane.pane_id`，缺任一就 rollback 並 die。`workspace create`／`workspace get`／`tab rename` 全倉零命中。
- **AC2** `.task.env` 新增唯一一個鍵 `DK_TASK_TAB`；`--run` 成功後改寫五欄，process 記 `materialize repos <名…> tab <id>`。
- **AC3** rollback 改用 `herdr tab close`，單 repo 與多 repo 各兩條測試（`tab create` 失敗、交棒前失敗）。
- **AC4** 幂等三態：tab 已不在→拒絕、已交棒→印訊息 exit 0 且不開 tab、尚未交棒→跳過實體化直接交棒。
- **AC5** `dk-task-close` 不關 tab，成功結案最後一行提示 `herdr tab close <DK_TASK_TAB>`；legacy 路徑未動。
- **AC6** `dk-resume` 未交棒訊息改「開 tab」，已實體化多印 `tab: <id>`。
- **AC7** 三份 README、`LEADER.md`、`PROJECT.md`、`run/SKILL.md`、`plan/SKILL.md` 全面改成 tab 說法。
- **AC8** `VERSION` 0.11.0、8 處版本字串、CHANGELOG 首節 `feat(tab)!` 含升級注意。
- **AC9** 整合腳本 AC17 探針換成 `tab create`／`tab get`／`tab close`，在真 herdr 0.9.0（nested `dktest` session）實跑通過，四行 NOTE 已貼進 backend-docs 的 report。
- **AC10** `tests/run.sh` 548/548、`shellcheck` 零警告。

規模：27 檔、+259/−105，四個 commit（`511f173` `6da19b8` `4cfefb3` `256c75f`）。測試 539→548，**零刪除、零放寬**。

## 未完成 / 遺留
- 所有波都經過審查（波 1–4 各一輪預設 kind，另加兩輪整枝評議）。**但四輪審查全程只有 claude 一個 kind** —— codex 與 agy 在計畫階段就各自撞額度熔斷，`DK_REVIEW_MIN=1` 達標但沒有第二個 kind 的視角。
- `dk-leader:112` 在 `DK_WORKSPACE` 原本為空時補寫的那一次落盤，**不在 `rollback()` 的還原範圍**。要「計畫時不在 herdr 內」＋「實體化失敗」＋「換 workspace 重跑」三件事同時成立才會顯現，刻意不回捲，但與 AC3「還原」的直覺相反。
- 0.10.0 開出、尚未結案的任務升級到 0.11.0 後 `DK_TASK_TAB` 是空的，`dk-resume` 會印一行光禿禿的 `tab: `，`dk-leader` 幂等訊息會印成「已交棒（tab  根 pane …」。純觀感，CHANGELOG 的升級注意已交代 0.10.0 的任務要自己收尾。
- `tests/integration/herdr-real.sh:19` 的 AC17 探針傳了 `--env DK_PROBE=1` 卻沒驗它被吃到。不是洞——同檔 §10 探針已用 `pane run` + `pane wait-output` 驗過 `tab create --env` 繼承，交棒需要的 `DK_ROOT`／`HERDR_ENV=1` 有真 herdr 的證據。
- `tests/stub/responses/workspace_create.json`／`workspace_get.json` 已無呼叫端，保留未刪。
- 波 4 的 report 沒給新斷言掃了幾個檔的具體數字（reviewer 複查為 142 檔）。
- 倉裡仍有三處既有 `! grep -q`（`12_task_close.bats:20,45`、`04_docs.bats:62`），非本任務引進，已進 BACKLOG。

## 驗證
- `tests/run.sh`：548/548，exit 0。領導在 worktree 內獨立跑過（乾淨環境 `env -u DK_*`），不只採信員工與 reviewer 自報。
- `shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh`：零警告。
- 真 herdr 0.9.0 實跑 `tests/integration/herdr-real.sh`：AC17 三個探針全 `OK`，四行 NOTE 皆為既知的 0.9.0 形狀（`worktree create` 無 `.result.path`、`--ratio` 是 anchor 佔比、`--amount` 是面積分數、`pane/agent read` 是純文字），**沒有一條與 `tab create` 有關**，無 `FAIL`。
- 結案前領導自查：全倉 `git ls-files`（排除 `.dkbo/tasks/**` 與斷言檔）掃舊講法零命中；27 個改動檔逐一對回所有權表無越界；工作樹乾淨。

## 重要決策
- p2 由 codex 換 agy 補位 — codex 額度耗盡至 10/11，DK_REVIEW_MIN=1 但計畫審查要兩個 kind 才有真正第二意見 — 若錯只是多花一位 agy 的 token
- 計畫審查只採一個 kind（claude）的意見就進關卡① — codex 額度到 10/11、agy 23 小時後才重置，等不划算且本任務範圍小、需求只有一句 — 若錯代價是漏掉第二個 kind 才看得到的盲點，由關卡①的人工確認與波 1 的程式審查補
- AC9 的真 herdr 實跑採信 — backend-docs report 與 tests/integration/README.md 都貼了同一組 OK 行，且 herdr session list 只剩 default，證明 dktest 已收乾淨 — 若錯代價是 tab create 的真實形狀與 stub 不符，要等下一個任務交棒時才會炸
- AC9 探針沿用腳本開頭的臨時 ws0、不另開 workspace — brief 只要求「對一個臨時 workspace 做 tab create」，ws0 正是臨時的，另開一個只是多一組要收的資源 — 若錯代價是漏掉「全新 workspace 的第一個 tab」這個邊界，實務上 dk-leader 開的也不是全新 workspace
- tests/stub/responses/workspace_create.json 與 workspace_get.json 雖已無呼叫端但保留不刪 — 本任務 AC 沒要求清理，刪檔會讓 0.10.0 的 waves/*.diff 讀者少一個對照 — 若錯代價只是兩個死檔，記進 BACKLOG 下次動 stub 時一起收
- tasktab-reviewer-a 的 [TIMEOUT] 判為誤判，不關 pane、解除 claude 熔斷 — herdr agent_status 是 working、cost $2.78、ctx 15%、usage 5h:40% 無額度問題，state 寫著 status: working / current: 寫 report、notes 已列 Important 4 條，就是 L 檔整枝評議讀 task.diff 本來就超過 DK_REVIEW_TIMEOUT_MIN=20 — 若錯代價是它其實卡死而我多等，但 .timeout 標記已寫 notified 不會再熔斷第二次
- Important 1 採納，退路生效時要把 ws 落盤（DK_WORKSPACE 空才寫） — AC2 的「DK_WORKSPACE 維持原值」意思是不要像 0.10.0 那樣拿新開的 workspace 蓋掉人的值，填一個本來就空的欄不在禁止之列；不落盤的話 dk-spawn:86 的溢出 tab 會拿空 workspace id 直接 dk_die，這是 0.10.0 沒有的迴歸 — 若錯代價是 .task.env 多一個本來就該有的值
- Important 2 採納 — plan/SKILL.md:10 實際寫著「不開 herdr workspace」，backend-docs 的 report 說它沒提到 workspace 與事實不符；該檔在它可改欄內，波 2 直接改
- Important 3 採納，授權 backend-ws 把 .dkbo/bin/dk-wave-open 與 .dkbo/bin/dk-msg 加進可改欄 — brief 的目標段已經寫明「字樣全部從 workspace 改成 tab」，只是 AC 列表漏點名這兩支；dk-wave-open:9 是領導最常撞到的錯誤訊息，出貨時叫人去「開 workspace」等於文件騙人 — 若錯代價是本波多動兩個檔，兩處都只是使用者可見字串與註解，18_wave_open.bats／06_msg.bats 本來就在同一人可改欄裡守著
- Important 4 只改文案不改程式 — AC1 逐字指定 --workspace "$DK_WORKSPACE"，而 DK_WORKSPACE 是 dk-task-new（計畫那一刻）寫死的，所以正確講法是「任務所屬的 workspace（計畫時記下）」而不是「你叫 /dkbo-run 時所在的」；改程式去追 HERDR_WORKSPACE_ID 會違反 AC1 且屬行為變更 — 若錯代價是計畫與執行不在同一個 workspace 的人要自己找 tab，這個語意問題另記 BACKLOG 並在關卡③向人點名
- Minor triage — merge 前修：tests/integration/README.md:223 的假陳述、plan/SKILL.md（同 Important 2）；順手一起收：dk-leader:26/:71、dk-task-new:55、dk-task-close:81、dk-msg:51 五處過時註解、dk-leader 的 ws 空值檢查提早到切 worktree 前、12_task_close.bats:167 改用 sed。不修：04_docs.bats 再疊一層 AC7 斷言（25_docs_policy.bats:30 已覆蓋，價值不高）、倉裡既有三處 ! grep -q（非本波引進，另記 BACKLOG）
- Important 4 的殘留擴大到四處，回派 backend-docs 本波修掉 — README.md:96「在人所在的 workspace 開任務專屬 tab」、README.en.md:96「a task-specific tab in the workspace you're in」、.dkbo/PROJECT.md:7、.dkbo/LEADER.md:7 全是同一個錯誤講法，四個檔都在 backend-docs 可改欄內；25_docs_policy.bats 新增的斷言只擋三種措辭×四個檔，漏掉「人所在的」「你所在的」與 LEADER.md／PROJECT.md 兩個檔，正是波 1 它自己警告過的弱斷言 — 若錯代價是出貨文件對「tab 開在哪」自相矛盾，而這正是 feat(tab)! 使用者唯一要知道的事
- 撤回「12_task_close.bats:167 改用 sed」那條 Minor，改回波 1 的 echo >> 寫法，不動 tests/helpers.bash — 該 Minor 的前提是假的：fixture_task() 自己手寫 .task.env 的 heredoc，裡面根本沒有 DK_TASK_TAB 這一行，所以從來沒有重複鍵，sed -i 's/^DK_TASK_TAB=.*/…/' 是空操作、鍵永遠沒被設；reviewer 引為先例的 10_resume.bats:124 是另一種寫法（錨在既有的 DK_ROOT_PANE 上插一行），不是取代既有的 DK_TASK_TAB 行 — 若錯代價是 fixture 與 templates/task.env 繼續有漂移，但那要動所有 547 條測試共用的檔，不該在收尾的修復波做，已記 BACKLOG
- 波 2 放行結案 — Important 1-4 與指名 Minor 逐條驗過，547/547 綠、shellcheck 零警告、17 個變更檔無越界；12_task_close.bats 的撤回沒有 diff 是正確的（恢復原狀）不是漏做 — 若錯代價由整枝評議第二輪兜底
- 整枝評議 Important 1 採納 — CHANGELOG.md:5 寫「--run 不再改寫它」與出貨行為不符，波 2 的修法就是讓 dk-leader:112 在 DK_WORKSPACE 原本是空字串時落盤；這是 feat(tab)! 的 release note，讀者照它推論會以為空值會一直空著，而 dk-spawn:86 的溢出 tab 正好靠這個值 — 若錯代價是使用者照 release note 推論錯誤
- 整枝評議 Important 2 採納 — AC9 與 backend-docs 的完成條件都明寫 NOTE 行要進 report 的「## 測試」段，現在整份 report 沒有 NOTE／herdr-real 字樣；NOTE 是那支腳本唯一會講「herdr 版本落在已驗證系列之外」的管道，只摘四行 OK 等於把示警丟掉 — 若錯代價是真 herdr 有示警而我們不知道
- 波 3 順手收 13_leader.bats:51 的註解與 AC1「兩者皆空就拒絕」的缺測 — 前者正是波 2 剛從文件清掉的講法，只因 25_docs_policy 的掃描清單不含 .bats 才漏網；後者是 AC1 明寫的分支卻零覆蓋，兩輪評議都點名，補一則三行的測試就補上 — 若錯代價只是波 3 多一個成員
- 其餘 5 條 Minor 不修 — dk-leader:112 的補寫不回捲（要三件事同時成立，記 report 遺留段與 BACKLOG）、0.10.0 升級後 dk-resume 印光禿禿 tab:（CHANGELOG 升級注意已交代）、herdr-real.sh:19 多餘的 --env DK_PROBE=1（§10 探針已驗過 env 繼承）、fixture_task 漂移（已在 BACKLOG，且 helpers.bash 無人可改）、既有 ! grep -q（已在 BACKLOG） — 若錯代價是這些小債留到下一版
- 波 3 之後不跑第三輪整枝評議，以波 3 的預設審查覆蓋 — 波 3 只動 CHANGELOG 一句、一行 bats 註解、一則新測試與兩處 report 文字，波 3 的 reviewer 讀的就是這份 diff；再跑一輪 L 檔重讀 27 個檔去覆蓋十行改動不划算 — 若錯代價是漏掉波 3 引進的整枝層級問題，由我自己比對 task.diff 與全套測試兜底
- 波 3 放行 — 差異包只動 CHANGELOG.md 與 13_leader.bats 兩檔、548/548 綠、shellcheck 零警告、無越界；AC9 的四行 NOTE 皆為既知的 herdr 0.9.0 形狀且與 tab create 無關，沒有需要 ESCALATE 的不符 — 若錯代價由結案前我自己比對 task.diff 兜底
- 結案前領導自查發現 tests/integration/README.md:202,206 仍寫「在人所在的 workspace 裡開新 tab」與「DK_WORKSPACE 從此固定是人所在的 workspace」，開波 4 修 — 後者正是波 3 Important 1 在 CHANGELOG 修掉的同一句假陳述，而 25_docs_policy.bats:39 的 Important4 斷言掃的是六個檔的硬編清單，不含 tests/integration/**，所以機械閘抓不到；這已是同一個弱斷言模式第三次漏接（波 1 漏 LEADER/PROJECT、波 2 漏措辭、波 3 漏檔案清單） — 若錯代價是出貨文件在「tab 開在哪」這件事上自相矛盾，而那正是 feat(tab)! 唯一要講清楚的事
- 波 4 的唯一 Minor 不另開波 — 完成條件要求交代新斷言掃了幾個檔，report 只寫「非固定六檔」沒給數字；reviewer 複查得 142 檔（git ls-files 排除 .dkbo/tasks/** 與斷言檔本身），數字記在這裡與 report.md 即可 — 若錯代價為零，斷言正確性不受影響

## 給下次的話（≤3 行）
硬編檔案清單的文件斷言連三波漏接同一類殘留（波 1 漏兩個檔、波 2 漏一個措辭、波 3 漏一個目錄），每輪都在補上一輪的洞而沒人質疑做法本身——文件類斷言一律掃 `git ls-files` 全倉加排除清單，不要列舉檔名。
reviewer 的 Minor 也要驗證前提：波 2 那條「改用 sed 避免重複鍵」的前提（fixture 已有該鍵）是假的，害 dev 把原本正確的寫法改壞、繞掉一整輪 BUG/FIXED。
L 檔整枝評議必跑兩輪且必超過 `DK_REVIEW_TIMEOUT_MIN=20`——第二輪多抓到 2 條第一輪沒有的 Important，而 dk-watch 會把正在工作的它誤判逾時並熔斷該 kind。
## 時間
任務 2026-09-22-tasktab
| 階段 | 開始 | 結束 | 時長 | dev | 審查 |
|---|---|---|---|---|---|
| 任務 | 2026-09-22T21:14 | 2026-09-23T00:38 | 204m（進行中） | — | — |
| 計畫 | 2026-09-22T21:14 | 2026-09-22T21:42 | 28m | — | — |
| 波 1 | 2026-09-22T21:55 | 2026-09-22T22:29 | 34m | 22m | 10m |
| 波 2 | 2026-09-22T22:58 | 2026-09-22T23:37 | 39m | 8m | 6m |
| 波 3 | 2026-09-22T23:55 | 2026-09-23T00:17 | 22m | 9m | 7m |
| 波 4 | 2026-09-23T00:18 | 2026-09-23T00:31 | 13m | 4m | 2m |
| 結案 | 2026-09-23T00:31 | — | — | — | — |
