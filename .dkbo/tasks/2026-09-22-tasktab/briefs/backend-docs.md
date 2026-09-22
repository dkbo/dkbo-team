# 任務改開 tab — 給 backend-docs 的切片（波 4）
由 dk-wave-open 產生，只讀。完整 brief 在 /home/bal/project/teamflow/.dkbo/tasks/2026-09-22-tasktab/brief.md。

## 目標
`dk-leader <short> --run` 實體化任務時，不再開一個新的 herdr workspace，改在人所在的同一個 workspace（`.task.env` 的 `DK_WORKSPACE`，退路 `HERDR_WORKSPACE_ID`）開一個 label `dk/<short>` 的新 tab，在它的根 pane 起執行領導交棒。
任務根 tab 的 id 記進 `.task.env` 新鍵 `DK_TASK_TAB`；rollback、幂等檢查、`dk-task-close` 的結尾提示、`dk-resume` 的字樣全部從 workspace 改成 tab。其餘（worktree、依賴鉤子、`.sessions` 改綁、`--name dk/<short>`、溢出 tab）不變。
文件與測試跟著改，出貨版本 0.11.0。

## 全域約束（全文）
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

## 你的波次
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
| 4 | 修復 | backend-docs | 領導結案自查發現的第四處 Important 4 殘留：`tests/integration/README.md:202` 的「（在人所在的 workspace 裡開新 tab）」與 `:206` 的「`DK_WORKSPACE` 從此固定是人所在的 workspace」。後者跟波 3 Important 1 在 CHANGELOG 修掉的是同一句假陳述。兩處都改成「任務所屬的 workspace（`.task.env` 的 `DK_WORKSPACE`，計畫時記下；空時退回 `HERDR_WORKSPACE_ID`）」。**根因修法**：`tests/unit/25_docs_policy.bats:39` 的 Important4 斷言掃的是六個檔的硬編清單，所以第三次漏接（波 1 漏 LEADER/PROJECT、波 2 漏「人所在的」這個措辭、波 3 漏 tests/integration/）。改成掃整個倉的追蹤檔（`git ls-files`），排除 `.dkbo/tasks/**`（歷史任務記憶與 waves/*.diff 是當時的原文紀錄，不該改也不該擋）與 `tests/unit/25_docs_policy.bats` 自己（斷言字串本身會自我命中）。跑一次紅（暫時把某個檔改回舊講法、確認掃得到）再綠 | S | 21/25/04 全過、`tests/run.sh` 全綠、shellcheck 零警告；report 的「## 測試」有紅綠，並交代新斷言掃了幾個檔 | 預設 |

## 倉庫
/home/bal/project/teamflow/.worktrees/tasktab

## 你的檔案所有權
| 成員 | 可改 | 只讀 |
|---|---|---|
| backend-docs | README.md, README.en.md, .dkbo/README.md, CHANGELOG.md, .dkbo/VERSION, .dkbo/bin/dk-version, .dkbo/LEADER.md, .dkbo/PROJECT.md, .dkbo/skills/plan/**, tests/unit/21_version.bats, tests/unit/25_docs_policy.bats, tests/unit/04_docs.bats, tests/integration/** | .dkbo/bin/**, .dkbo/skills/run/**, tests/stub/**, tests/helpers.bash |

## 共用契約（全文）
（一列一個契約。擁有者填一個成員短名；消費者填一個或多個、逗號分隔；沒有就填 —。完全沒有契約時只留表頭）
| 契約 | 擁有者 | 消費者 | 形狀／簽名 | 變更流程 |
|---|---|---|---|---|
| .task.env 的 DK_TASK_TAB | backend-ws | backend-docs | `DK_TASK_TAB="<tab id>"`，計畫階段為空，`dk-leader --run` 成功後填任務根 tab 的 id；`DK_WORKSPACE` 從此固定是**任務所屬的 workspace**（`dk-task-new` 在計畫那一刻記下的 `HERDR_WORKSPACE_ID`，`--run` 不刷新它）；只有它原本是空字串時 `--run` 才用 `HERDR_WORKSPACE_ID` 補上並落盤，好讓 `dk-spawn` 的溢出 tab 讀得到。文件裡提到 `.task.env` 欄位時用這個名字，且不得寫成「你叫 /dkbo-run 時所在的 workspace」 | 動它要先 ESCALATE |
| 結案提示字樣 | backend-ws | backend-docs | `dk-task-close` 成功結案的最後一行：`任務 tab 沒有自動關（你就住在它的根 pane 上）。看完 report 再自己關：herdr tab close <DK_TASK_TAB>`；README 疑難排解列引用同一句 | 動它要先 ESCALATE |
| stub tab_create.json | backend-ws | backend-docs | `.result.tab.tab_id` 與 `.result.root_pane.pane_id`（既有檔，dk-spawn 的溢出 tab 已在用）；`tab get`／`tab close` 的 stub 回應由 backend-ws 補；整合腳本 AC9 驗的就是這個形狀 | 動它要先 ESCALATE |
| 交棒後的實體化判別 | backend-ws | backend-docs | 「實體化了沒」仍看 `.repos` 在不在；「tab 還在不在」看 `herdr tab get "$DK_TASK_TAB"`；「交棒了沒」看根 pane 的 agent 名是不是 `leader-<short>`。run/SKILL.md 第 0 步的判別條件（`DK_WORKTREE` 空或 `HERDR_PANE_ID` ≠ `DK_ROOT_PANE`）不變 | 動它要先 ESCALATE |

## 驗收標準（全文）
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

## 同波成員
backend-docs(S)
