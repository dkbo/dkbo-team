# 多 repo workspace 結案
結果：merged   分支：dk/multirepo   波數：5（3 波實作 + 2 波修復）＋ 整枝評議 2 輪
## 完成
- **一個任務一個 herdr workspace，在 `/dkbo-run` 才建**（AC2、AC3、AC6、AC7、AC19）：`dk-task-new` 瘦身成只建任務資料夾；`dk-leader <short> --run` 實體化（切 worktree、跑依賴鉤子、`herdr workspace create --cwd 主樹`、tab 改名 `dk/<short>`、改寫 `.task.env` 五欄）並交棒（清人的 pane 名、根 pane 起 `leader-<short>`、claude 帶 `--name dk/<short>`、改綁 `.sessions`）；agent start 前失敗整組 rollback，重跑幂等。`DK_ROOT_PANE`（版面錨點）與新欄 `DK_LEADER_PANE`（領導在哪）拆開，`dk-msg`／`dk-watch` 退路改讀後者。
- **一個任務 N 個 repo**（AC4、AC5、AC8 到 AC12）：`settings.env` 新鍵 `DK_REPOS`，`.dkbo/lib/repos.sh` 九個函式，`.repos` 表；所有權與 `touched` 用 `<名>:<glob>` 前綴（多 repo 必帶、單 repo 禁帶，`dk-brief-check` 守）；`dk-spawn` cwd 落在成員第一個 glob 的 repo、`DK_ADD_DIRS` 逐列 `--add-dir`；`dk-wave-open` 逐 repo 記 base 並在切片印「## 倉庫」；`dk-review-pack` 逐 repo 分段；`dk-wave-close` gate c 只跑有變更的 repo 各自的 `DK_TEST_CMD_<名>`、gate d 逐 repo 比對、逐 repo commit。
- **依賴鉤子**（AC20）：`DK_SETUP_CMD`／`DK_SETUP_CMD_<名>` 每個 worktree 各跑一次、失敗只警告；pnpm 為建議寫法。
- **`dk-task-close` 兩階段合併**（AC13、AC14）：記憶先 commit（收掉 BACKLOG「暫存改名擋住 merge」那條）、全部預檢再全部合併、exit 3／4／5 三種訊息、不自動關 workspace。
- **文件與版號**（AC15、AC16）：三份 README、CHANGELOG 0.10.0、PROTOCOL、LEADER、reviewer.md、PROJECT.md、init skill；版號 0.10.0。
- **實機驗證**（AC17，縮成兩個探針）：`workspace create` 回 `.result.workspace.workspace_id` 與 `.result.root_pane.pane_id`，`workspace get` 有 `active_tab_id`，與 stub 一致。
- **AC1、AC18**：單 repo 既有測試語意不變；整包 bats 全綠、shellcheck 零警告（最終數字見「驗證」）。
- 修復波（波 5）收掉整枝評議第二輪的兩條 Important：單 repo 切片的「## 倉庫」段只印路徑，PROTOCOL 的多 repo 判別器改成「列帶 `<名> →`」；兩份頂層 README 的指令一覽與運作方式圖改成 0.10.0 時序並補 `dk-leader --run`；CHANGELOG 補波 4 的修法與最終測試數字。
- 修復波（波 4）收掉整枝評議第一輪的兩條 Important：主 repo 乾淨檢查排除 `.dkbo/`（否則交棒被自己的 INDEX.md 擋死）；`while read` 迴圈內跑使用者指令加 `</dev/null`（否則靜默漏 repo）。兩條累積 Minor（英文開頭訊息）一併改成繁中。

## 未完成 / 遺留
- AC17 依 11:20 裁定縮成兩個探針（`workspace create`、`workspace get`）；「新 workspace 根 pane 上 `agent start --name`」在 layer 2 沒有機械驗證，留給 layer 3 或第一次真跑 `dk-leader --run`。brief 的 AC17 條文已同步改寫。
- Minor 不修：`README.md:92`／`README.en.md:92` 指令一覽的 `dk-task-close` 列沒提「workspace 不自動關」（`.dkbo/README.md` 與 CHANGELOG 已寫），下一版順手補。
- 未經第三輪整枝評議：波 5 的三處改動（單 repo 切片不印名字、兩份 README 指令表、CHANGELOG 補述）只有波 5 自己的審查與全套測試守（ruling 12:37）。
- 跨 repo 整合測試沒有機械閘（plan 決策⑨刻意不開）；agy 的資料夾信任每個 worktree 一次（既有 BACKLOG，範圍隨 N 個 repo 變大）；`DK_REPOS` 與 `.repos` 不支援含空白的路徑；`setup.<名>.log` 進任務記憶，體積待觀察（記 BACKLOG）。
- 多 repo 的合併不是真原子：預檢過、真合併炸時 exit 4 只列名單、不回捲已合併的 repo。一人一機可忽略。
- 本任務跑在 0.9.2 的主樹腳本上，新的「交棒時才實體化」與多 repo 閘門要到合併後的下一個任務才第一次真跑；`dk-leader --run` 在真 herdr 上的完整交棒（含 `--name` 是否原樣傳給 claude）尚未實跑過。

## 驗證
- 波 1：reviewer-a Important 2（`dk-brief-check` 未加引號 `for` 被檔名展開、brief 契約表執行點寫錯）→ 修並複看確認；486→488 綠。
- 波 2：Important 0，Minor 2（英文訊息）；533 綠。
- 波 3：Important 0；535 綠。AC17 探針在 nested `dktest` session 實機跑過，NOTE 行在 `tests/integration/README.md`。
- 整枝評議第一輪（L）：Important 2（AC3 在本倉跑不起來、stdin 被吃）→ 波 4 修。
- 波 4：Important 0。
- 整枝評議第二輪（L）：Important 2（單 repo 切片讓 PROTOCOL 判別器反向、頂層 README 指令表過時）→ 波 5 修。
- 波 5：Important 0；gate c 全套 539 條綠，shellcheck 零警告。
- 每波 `dk-wave-close` 四道閘全過：裁定行、dev 的紅綠測試段、`tests/run.sh`、真實 diff 所有權比對（全程零 `unowned change`）。

## 重要決策
（全部 ruling 見 process.md `grep ' ruling: '`，共 18 條；關鍵的九條）
1. `herdr workspace create --cwd 主樹` 開 workspace，worktree 仍 `git worktree add`，不用 `herdr worktree create`。
2. 作廢「workspace 在 dk-task-new 開」：計畫完可能不做，worktree、鉤子、workspace 全延到 `dk-leader --run`。
3. herdr 註冊名維持 `leader-<short>`，CLI 那側 session 名靠 `claude --name dk/<short>`（`kind_session_args`）。
4. 前端依賴走 `DK_SETUP_CMD` 鉤子＋pnpm store，不 symlink 主樹 `node_modules`。
5. 乾淨檢查只看已追蹤檔，且主 repo 排除 `.dkbo/`（記帳從 task-new 到 task-close 必然已修改）。
6. `dk_changed_files` 舊簽名保留到波 2，逐 repo 版本改名 `dk_changed_repo_files`，不做相容雙形狀。
7. 單 repo 的 `--add-dir` 只放主樹（AC1 高於 AC8 字面）。
8. AC17 探針縮成兩個：零 token 的整合腳本不得起真 agent；classifier 擋「Create Unsafe Agents」是對的。
9. 波 4 由 backend-ws 一人修，三位成員的檔暫轉給它。

## 給下次的話（≤3 行）
無主測試檔在本任務升報了三次：改既有腳本的行為時，先 grep tests/ 裡誰斷言了那個行為，把那些檔一起劃進所有權。
訊息與 DONE 會錯身：員工照 ruling 自己動手比等 [DECISION] 快，領導的裁定先寫 process.md 再送訊息，員工讀得到。
dk-msg 對 working 的員工等不到閒置就放棄（預設 5 分鐘）；背景送、拉長 DK_MSG_WAIT_MS 比反覆重送好。

## 時間
任務 2026-09-20-multirepo
| 階段 | 開始 | 結束 | 時長 | dev | 審查 |
|---|---|---|---|---|---|
| 任務 | 2026-09-20T08:36 | 2026-09-20T14:11 | 335m | — | — |
| 計畫 | 2026-09-20T08:36 | 2026-09-20T08:57 | 21m | — | — |
| 波 1 | 2026-09-20T08:59 | 2026-09-20T10:32 | 93m | 40m | 21m |
| 波 2 | 2026-09-20T10:32 | 2026-09-20T11:08 | 36m | 26m | 7m |
| 波 3 | 2026-09-20T11:08 | 2026-09-20T11:50 | 42m | 27m | 9m |
| 波 4 | 2026-09-20T12:00 | 2026-09-20T12:25 | 25m | 14m | 10m |
| 波 5 | 2026-09-20T12:37 | 2026-09-20T12:57 | 20m | 11m | 6m |
| 結案 | 2026-09-20T12:57 | 2026-09-20T14:11 | 74m | — | — |
