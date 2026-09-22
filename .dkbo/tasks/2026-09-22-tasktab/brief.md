# 任務改開 tab
來源：人的口頭需求   需求原文：request.md
分支：dk/tasktab   worktree：交棒時建立

## 目標（≤3 行）
`dk-leader <short> --run` 實體化任務時，不再開一個新的 herdr workspace，改在人所在的同一個 workspace（`.task.env` 的 `DK_WORKSPACE`，退路 `HERDR_WORKSPACE_ID`）開一個 label `dk/<short>` 的新 tab，在它的根 pane 起執行領導交棒。
任務根 tab 的 id 記進 `.task.env` 新鍵 `DK_TASK_TAB`；rollback、幂等檢查、`dk-task-close` 的結尾提示、`dk-resume` 的字樣全部從 workspace 改成 tab。其餘（worktree、依賴鉤子、`.sessions` 改綁、`--name dk/<short>`、溢出 tab）不變。
文件與測試跟著改，出貨版本 0.11.0。

## 全域約束
bash 3.2+；不得使用 bash 4 語法（關聯陣列、${x^^}、declare -A）
依賴只有 herdr 0.9.0、git ≥ 2.17、jq ≥ 1.5；不得新增依賴
shellcheck 零警告（`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh`）
不新增 settings.env 鍵、不新增 skill、不新增 install.sh 的 symlink；`.task.env` 只新增 `DK_TASK_TAB` 一個鍵
不改「員工在波內不 commit、dk-wave-close 統一 commit」的模型；不改 dk-spawn 的溢出 tab 行為（它本來就用 `tab create --workspace "$DK_WORKSPACE"`）
`dk-leader --run` 不再呼叫 `herdr workspace create`、`herdr workspace get`、`herdr tab rename`；任務根 tab 由 `herdr tab create --workspace <ws> --cwd <主樹> --label dk/<short> --no-focus --env DK_ROOT=… --env HERDR_ENV=1` 一次開好
`DK_WORKSPACE` 的語意從「任務專屬 workspace」改為「任務所在的 workspace（＝人叫 /dkbo-run 時所在的那個）」，`dk-leader --run` 不改寫它
否定斷言一律用 tests/helpers.bash 的 refute_grep，不得寫 ! grep -q
0.10.0 的 539 條測試語意不變：不刪、不放寬既有斷言；只允許（a）把 workspace create／workspace get／tab rename／workspace close 的斷言改成對應的 tab create／tab get／tab close 斷言，（b）改 `DK_WORKSPACE`／`DK_ROOT_PANE`／`DK_LEADER_PANE` 在交棒後的期望值與 stdout 最後一行的字樣，（c）新增斷言
所有面向使用者的文案是繁體中文；目標版本 0.11.0
例外：本任務的成員**可以**修改 `.dkbo/` 底下的腳本、模板、規則檔與 skill 文件（PROTOCOL 停止條件「不改 .dkbo/ 規則檔」在本任務不適用；ruling 見 process.md）；但只能改所有權表劃給自己的檔
領導跑的是主樹的腳本：本任務交棒時仍會用 0.10.0 的 `workspace create`，新行為要等結案合併後的下一個任務才生效，report 不得宣稱「本波已用到」

## 驗收標準
- [ ] AC1 `dk-leader <short> --run` 用 `herdr tab create --workspace "$DK_WORKSPACE" --cwd "$DK_PROJECT_ROOT" --label "dk/$short" --no-focus --env DK_ROOT=… --env HERDR_ENV=1` 開任務根 tab，讀 `.result.tab.tab_id` 與 `.result.root_pane.pane_id`，缺任一就 rollback 並 die；`DK_WORKSPACE` 空時退回 `HERDR_WORKSPACE_ID`，兩者皆空拒絕並說明要在 herdr 內跑；不再呼叫 `workspace create`／`workspace get`／`tab rename`
- [ ] AC2 `templates/task.env` 新增 `DK_TASK_TAB=""`；`dk-task-new` 寫出的 `.task.env` 含它且為空；`--run` 成功後改寫 `DK_TASK_TAB`／`DK_ROOT_PANE`／`DK_LEADER_PANE`／`DK_WORKTREE`／`DK_BASE` 五個欄位，`DK_WORKSPACE` 維持原值；process 記 `materialize repos <名…> tab <tab id>`
- [ ] AC3 rollback：`agent start` 之前任一步失敗（含 `tab create` 失敗）清掉全部 worktree、分支、`.repos`，已開的 tab 用 `herdr tab close` 關掉，`.task.env` 五欄還原（`DK_TASK_TAB` 還原成空）；不呼叫 `workspace close`；單 repo 與多 repo 各一條測試
- [ ] AC4 幂等：`.repos` 在且 `DK_TASK_TAB` 非空但 `herdr tab get "$DK_TASK_TAB"` 失敗 → 拒絕並提示「tab 已不在，先人工收拾」；根 pane 已是 `leader-<short>` → 印「已交棒（tab <id> 根 pane <pane> 上的 leader-<short>）」exit 0 且不開 tab；`.repos` 在、tab 活著、尚未交棒 → 跳過實體化直接 agent start
- [ ] AC5 `dk-task-close` 不呼叫 `herdr tab close` 也不呼叫 `herdr workspace close`；成功結案的 stdout 最後一行含字樣 `herdr tab close <DK_TASK_TAB 的值>`；沒有 `.repos` 或 `DK_TASK_TAB` 空時不印；legacy 路徑（無 `DK_BASE` 行）的 `worktree remove --workspace` 不變
- [ ] AC6 `dk-resume` 的「尚未交棒」訊息改成「切 worktree、開 tab、把領導搬進去」；已實體化時多印一行 `tab: <DK_TASK_TAB>`
- [ ] AC7 `.dkbo/skills/run/SKILL.md` 第 0 步、`.dkbo/LEADER.md` 的 `DK_REPOS` 段、`.dkbo/PROJECT.md` 多 repo 事實、三份 README（運作方式、生命週期第 3 步、指令一覽 `dk-leader` 列、`.dkbo/README.md` 的交棒段與疑難排解「側邊欄還留著那個 workspace」列）全部改成 tab 的說法，不再說「任務專屬 workspace」；`25_docs_policy.bats` 與 `04_docs.bats` 的斷言跟著改並仍守著這些段落
- [ ] AC8 版號 0.11.0：`VERSION`、README 安裝段的 `VER=v0.11.0`、CHANGELOG 首節 `## 0.11.0 — <日期>` 含 `feat(tab)!` 條目（說明 workspace→tab 的行為變更、`DK_TASK_TAB`、升級注意：0.10.0 開出的任務 workspace 要自己關），`21_version.bats` 的首節斷言改成 `feat(tab)` 且全過
- [ ] AC9 `tests/integration/herdr-real.sh` 的 AC17 探針換成：對一個臨時 workspace 做 `tab create --workspace <id> --cwd --label dk/probe --no-focus --env K=V` 驗 `.result.tab.tab_id` 與 `.result.root_pane.pane_id`、`tab get <id>` 成功、`tab close <id>` 成功；不再呼叫 `workspace get`；發版前在真 herdr（nested dktest session，見 tests/integration/README.md）跑過一次，NOTE 行貼進 report 的「## 測試」段；形狀與 stub 不符先 ESCALATE
- [ ] AC10 `tests/run.sh` 全綠、`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh` 零警告

## 檔案所有權
獨佔資源欄填同一波內不能共用的執行環境（`db`、`port:3000`、`docker`…），逗號分隔，沒有就留空或 `—`。worktree 隔離檔案，不隔離執行環境。
只讀欄只是提示「你會需要讀哪裡」，不是機械閘的輸入；只讀欄的萬用字元**不包含**同一列可改欄列出的檔（可改優先於只讀）。
| 成員 | 可改 | 只讀 | 獨佔資源 |
|---|---|---|---|
| backend-ws | .dkbo/bin/dk-leader, .dkbo/bin/dk-wave-open, .dkbo/bin/dk-msg, .dkbo/bin/dk-task-close, .dkbo/bin/dk-resume, .dkbo/bin/dk-task-new, .dkbo/templates/task.env, .dkbo/skills/run/**, tests/stub/**, tests/unit/13_leader.bats, tests/unit/12_task_close.bats, tests/unit/10_resume.bats, tests/unit/23_leader_kind.bats, tests/unit/05_task_new.bats, tests/unit/06_msg.bats, tests/unit/09_watch.bats, tests/unit/26_watch_events.bats, tests/unit/30_isolation.bats, tests/unit/07_spawn.bats, tests/unit/01_common.bats, tests/unit/18_wave_open.bats | .dkbo/lib/**, tests/helpers.bash, .dkbo/bin/dk-spawn | — |
| backend-docs | README.md, README.en.md, .dkbo/README.md, CHANGELOG.md, .dkbo/VERSION, .dkbo/bin/dk-version, .dkbo/LEADER.md, .dkbo/PROJECT.md, .dkbo/skills/plan/**, tests/unit/21_version.bats, tests/unit/25_docs_policy.bats, tests/unit/04_docs.bats, tests/integration/** | .dkbo/bin/**, .dkbo/skills/run/**, tests/stub/**, tests/helpers.bash | — |

## 共用契約
（一列一個契約。擁有者填一個成員短名；消費者填一個或多個、逗號分隔；沒有就填 —。完全沒有契約時只留表頭）
| 契約 | 擁有者 | 消費者 | 形狀／簽名 | 變更流程 |
|---|---|---|---|---|
| .task.env 的 DK_TASK_TAB | backend-ws | backend-docs | `DK_TASK_TAB="<tab id>"`，計畫階段為空，`dk-leader --run` 成功後填任務根 tab 的 id；`DK_WORKSPACE` 從此固定是**任務所屬的 workspace**（`dk-task-new` 在計畫那一刻記下的 `HERDR_WORKSPACE_ID`，`--run` 不刷新它）；只有它原本是空字串時 `--run` 才用 `HERDR_WORKSPACE_ID` 補上並落盤，好讓 `dk-spawn` 的溢出 tab 讀得到。文件裡提到 `.task.env` 欄位時用這個名字，且不得寫成「你叫 /dkbo-run 時所在的 workspace」 | 動它要先 ESCALATE |
| 結案提示字樣 | backend-ws | backend-docs | `dk-task-close` 成功結案的最後一行：`任務 tab 沒有自動關（你就住在它的根 pane 上）。看完 report 再自己關：herdr tab close <DK_TASK_TAB>`；README 疑難排解列引用同一句 | 動它要先 ESCALATE |
| stub tab_create.json | backend-ws | backend-docs | `.result.tab.tab_id` 與 `.result.root_pane.pane_id`（既有檔，dk-spawn 的溢出 tab 已在用）；`tab get`／`tab close` 的 stub 回應由 backend-ws 補；整合腳本 AC9 驗的就是這個形狀 | 動它要先 ESCALATE |
| 交棒後的實體化判別 | backend-ws | backend-docs | 「實體化了沒」仍看 `.repos` 在不在；「tab 還在不在」看 `herdr tab get "$DK_TASK_TAB"`；「交棒了沒」看根 pane 的 agent 名是不是 `leader-<short>`。run/SKILL.md 第 0 步的判別條件（`DK_WORKTREE` 空或 `HERDR_PANE_ID` ≠ `DK_ROOT_PANE`）不變 | 動它要先 ESCALATE |

## 波次表
一列一位成員；同一波的列相鄰、波號從 1 連續。審查欄只填在該波第一列：`預設`（用 settings.env 的 kind）、`skip: <理由>`（純文件波）、`kinds: <k1> [k2] [k3]`。
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
| 1 | 實作 | backend-ws | dk-leader --run：workspace create／get／tab rename 換成一次 tab create（AC1）、DK_WORKSPACE 退路 HERDR_WORKSPACE_ID、.task.env 新鍵 DK_TASK_TAB 與五欄改寫（AC2）、rollback 改 tab close（AC3）、幂等改看 tab get（AC4）；dk-task-close finish_note 改 tab 版（AC5）；dk-resume 字樣與 tab 行（AC6）；templates/task.env；run/SKILL.md 第 0 步改寫；stub 補 tab get／tab close 回應；13/12/10/23/05 等既有測試對應改寫並補 AC1–AC6 正反測試 | M | 13/12/10/23/05/06/09/26/30/07/01/18 全過；AC3 單 repo 與多 repo 各有 rollback 測試；shellcheck 零警告；報告的「## 測試」有紅綠 | 預設 |
| 1 | 文件 | backend-docs | 三份 README、LEADER.md、PROJECT.md、plan/SKILL.md 若有提到 workspace 的段落改成 tab 說法（AC7）；CHANGELOG 0.11.0 首節 feat(tab)! 與升級注意、VERSION、README 安裝段版號（AC8）；21/25/04 的斷言跟著改；整合腳本 AC17 探針換成 tab create／tab get／tab close 並在真 herdr 跑一次、NOTE 行貼進 report（AC9） | M | 21/25/04 全過（自己擁有的檔；全套件 tests/run.sh 全綠是 AC10、由 dk-wave-close gate c 判，不是單一成員的完成條件）；shellcheck 零警告；AC9 的 NOTE 行在 report 的「## 測試」段 | |
| 2 | 修復 | backend-ws | Important 1：`dk-leader` 的 `ws="${DK_WORKSPACE:-${HERDR_WORKSPACE_ID:-}}"` 退路生效時（＝`.task.env` 的 `DK_WORKSPACE` 原本是空的）要 `dk_env_set DK_WORKSPACE "$ws"` 落盤，否則 `dk-spawn:86` 的溢出 tab 拿到空 workspace id 直接 `dk_die`；`DK_WORKSPACE` 原本非空時一律不動。Important 3：`dk-wave-open:9` 的「開 workspace」改成「開 tab」。Important 4：`run/SKILL.md` 第 0 步與 `dk-leader:137` 註解裡「人所在的 workspace」改成「任務所屬的 workspace（計畫時記下，`.task.env` 的 `DK_WORKSPACE`）」。Minor：`dk-leader` 的 `ws` 空值檢查提早到切 worktree／跑 `DK_SETUP_CMD` 之前（純前置條件，早失敗省一次白付的依賴安裝）；`dk-leader:26`／`:71`、`dk-task-new:55`、`dk-task-close:81`、`dk-msg:51` 五處過時註解改 tab 說法；`12_task_close.bats:167` 的 `echo >>` 改成 `sed -i`（避免 `.task.env` 出現重複鍵）。補測試：退路落盤的正面測試（`DK_WORKSPACE` 空 + `HERDR_WORKSPACE_ID` 有值 → `.task.env` 寫入該值且 `tab create --workspace` 用它）與反面測試（`DK_WORKSPACE` 非空 → 不被改寫）；`18_wave_open.bats` 守住新字樣 | S | 13/12/10/18/06 全過、`tests/run.sh` 全綠、shellcheck 零警告；report 的「## 測試」有紅綠 | 預設 |
| 2 | 文件 | backend-docs | Important 2：`.dkbo/skills/plan/SKILL.md:10` 的「不切 worktree、不開 herdr workspace」改成 tab 說法（同一行後半「reviewer 填在你的 workspace 右側」指人當下所在的 workspace，語意正確、不要動）。Important 4：`CHANGELOG.md:5`、`.dkbo/README.md:62`、`README.md:36`、`README.en.md:36` 四處「人叫 /dkbo-run 時所在的／你所在的 workspace」改成「任務所屬的 workspace（`.task.env` 的 `DK_WORKSPACE`，計畫時記下；空時退回 `HERDR_WORKSPACE_ID`）」。Minor：`tests/integration/README.md:223` 的「這次只改了整合腳本與這篇文件，沒有動 `.dkbo/` 或 stub」是假陳述（0.11.0 動了六支腳本、新增兩個 stub），改掉。`25_docs_policy.bats` 補一條斷言擋住「你所在的 workspace」這類講法回流 | S | 21/25/04 全過、shellcheck 零警告；report 的「## 測試」段交代跑了哪些 | |
| 3 | 修復 | backend-docs | Important 1：`CHANGELOG.md:5` 的「`DK_WORKSPACE` 的語意從此固定是「任務所在的 workspace」，`--run` 不再改寫它」與出貨行為不符（`dk-leader:112` 在它原本是空字串時會 `dk_env_set` 落盤）。改成「`--run` 只在它原本是空字串時用 `HERDR_WORKSPACE_ID` 補上並落盤，非空時一律不動」。Important 2：把那一次真 herdr `tests/integration/herdr-real.sh` 執行輸出裡的 `NOTE` 行**原樣**貼進 `state/backend-docs.report.md` 的「## 測試」段（AC9 與你的完成條件都明寫要有；`tests/integration/README.md` 那一節留著不動）。Minor：同一份 report 的「## 測試」段還寫著「547 條中 1 條 `not ok`：12_task_close.bats:171」，那條在 backend-ws 撤回 `sed -i` 之後已修好，現在是 547/547；不更新的話 `dk-task-close` 會把這句假陳述帶進結案 report.md | S | 21/25/04 全過、`tests/run.sh` 全綠、shellcheck 零警告；report 的「## 測試」段有 NOTE 行且沒有過時的紅 | 預設 |
| 3 | 修復 | backend-ws | Minor：`tests/unit/13_leader.bats:51` 的註解「任務根 tab：開在**人所在的** workspace（DK_WORKSPACE）」改成「任務所屬的 workspace」——正是波 2 從文件清掉的講法，只因 `25_docs_policy.bats` 的掃描清單不含 `.bats` 才漏網。補測試：AC1 明寫的「`DK_WORKSPACE` 與 `HERDR_WORKSPACE_ID` 都是空的就拒絕並說明要在 herdr 內跑」這條分支目前零覆蓋，在 `13_leader.bats` 既有的退路測試旁補一則（`DK_WORKSPACE` 空 + `HERDR_WORKSPACE_ID` 空 → 非零離開、訊息含「都是空的」、`refute_grep '^tab create'`、worktree／分支／`.repos` 都沒建） | S | 13 全過、`tests/run.sh` 全綠、shellcheck 零警告；report 的「## 測試」有紅綠 | |
| 4 | 修復 | backend-docs | 領導結案自查發現的第四處 Important 4 殘留：`tests/integration/README.md:202` 的「（在人所在的 workspace 裡開新 tab）」與 `:206` 的「`DK_WORKSPACE` 從此固定是人所在的 workspace」。後者跟波 3 Important 1 在 CHANGELOG 修掉的是同一句假陳述。兩處都改成「任務所屬的 workspace（`.task.env` 的 `DK_WORKSPACE`，計畫時記下；空時退回 `HERDR_WORKSPACE_ID`）」。**根因修法**：`tests/unit/25_docs_policy.bats:39` 的 Important4 斷言掃的是六個檔的硬編清單，所以第三次漏接（波 1 漏 LEADER/PROJECT、波 2 漏「人所在的」這個措辭、波 3 漏 tests/integration/）。改成掃整個倉的追蹤檔（`git ls-files`），排除 `.dkbo/tasks/**`（歷史任務記憶與 waves/*.diff 是當時的原文紀錄，不該改也不該擋）與 `tests/unit/25_docs_policy.bats` 自己（斷言字串本身會自我命中）。跑一次紅（暫時把某個檔改回舊講法、確認掃得到）再綠 | S | 21/25/04 全過、`tests/run.sh` 全綠、shellcheck 零警告；report 的「## 測試」有紅綠，並交代新斷言掃了幾個檔 | 預設 |
