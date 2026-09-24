# bklog-backend-docs 報告（波 2）
## 做了什麼
整枝評議 Minor 三項＋測試條數：
- ① `tests/unit/25_docs_policy.bats` Important4：全倉掃的正規式從收窄版 `workspace（[^）]*計畫時記下|recorded at plan time` 改回嚴格的 `計畫時記下|recorded at plan time`，排除清單不變（`.dkbo/tasks/*`、`.dkbo/decisions.md`、`CHANGELOG.md`、本檔）；CHANGELOG 首節也用同一個嚴格式查。收窄的理由（dk-leader 註解「退回計畫時記下的 DK_WORKSPACE」）在波 1 已被 backend-brief 改掉，全倉現在零命中。
- ② `README.md`、`.dkbo/README.md` 的 `--note <證據>` → `--note <文字>`；`README.en.md` 的 `--note <evidence>` → `--note <text>`。25 的 AC16 條補三條斷言守住契約原句。
- ③ `CHANGELOG.md` 0.16.0：
  - 新增 `fix(repos)`：`dk_glob_check` 的 `printf | grep -qx` 在 pipefail 下吃 SIGPIPE、合法 repo 名誤判未知 → here-string（backend-brief 波 1 的修正，同類寫法一併改）。
  - 新增 `fix(wave)`（backend-msg 波 2）：`dk-wave-close` 裁定行改詞界比對，`note:`／`if:` 不再冒充 `e:`／`f:`（gate a2 是 0.16.0 以前就有的碼，所以是 fix）。
  - `feat(msg)` 重派那條補一句（backend-msg 波 2）：`.panes` 由 dk-msg／dk-spawn／dk-wave-close 共用 `.blocked/panes.lock`、不進任務記憶。
  - `feat(review)` 補一句（backend-brief 波 2 ①）：別名用完的提示改叫人記 `dk-process "<label> skipped: <理由>"`。
  - `feat(brief)` 欄數閘那條補一句（backend-brief 波 2 ③）：`all_globs` 也改用跳脫感知的切法。②（`dk_brief_ncols` 接進欄數閘）是內部重構、沒有行為差異，不另寫。
  - 我自己這波的修正（Important4 改回嚴格、README 簽名）已包含在既有的 `docs(readme)`／測試行敘述內，屬本版新增內容的修飾，不另開條目。
- ④ 兩位 `[DONE]` 都到後在 worktree 跑完整 `tests/run.sh`：724 條全 ok → 測試行填 `724 bats（+68；…`（0.15.0 為 656），並補列 07／08 本波新增的測試。21 的首節斷言補 `fix(repos)`、`SIGPIPE`、`fix(wave)`、`panes.lock`、`別名還回來`、`all_globs` 與「測試條數不是佔位」（加在既有 @test 內，條數不變）。

## 測試
### 紅
① 在暫存副本（`git archive HEAD` 解到 scratchpad、git init，放入新版 25，並在 `.dkbo/bin/dk-leader` 注入舊的退路句「空才退回計畫時記下的 DK_WORKSPACE」——收窄版會放行的句型）：
`tests/run.sh tests/unit/25_docs_policy.bats`
→ `not ok 5 Important4（0.16.0 反轉）…` / `refute_grep: 不該命中卻命中了: -E 計畫時記下|recorded at plan time …/red1/.dkbo/bin/dk-leader`
② worktree 裡先加斷言、README 未改：`tests/run.sh tests/unit/25_docs_policy.bats`
→ `not ok 8 AC16: 三份 README 的 dk-kind 補 down…` / `` `grep -qF -- '`dk-kind down <k> [--until YYYY-MM-DDTHH:MM] [--note <文字>]`' "$REPO_ROOT/README.md"' failed ``
③ 先加 `fix(repos)` 關鍵字、CHANGELOG 未改：`tests/run.sh tests/unit/21_version.bats`
→ `not ok 6 CHANGELOG 首節列出本版的每一條變更` / `CHANGELOG 首節缺 fix(repos)`
④ 先加佔位斷言、仍是 `N`：`tests/run.sh tests/unit/21_version.bats`
→ `not ok 6 …` / `CHANGELOG 首節測試條數仍是佔位`
（`fix(wave)`／`panes.lock`／`別名還回來`／`all_globs` 四個關鍵字是和 CHANGELOG 句子同一步加的，沒有單獨取紅。取紅都沒用 stash／checkout：①在暫存副本，②–④是我自己檔案的斷言先於文件。）
### 綠
`tests/run.sh tests/unit/21_version.bats tests/unit/25_docs_policy.bats tests/unit/04_docs.bats`
→ `1..34`，34 條全 ok。
送 DONE 前完整測試（兩位 [DONE] 之後）：`tests/run.sh` → `1..724`，724 條全 ok、rc=0；`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh` rc=0。
（完整測試跑完之後只改了 CHANGELOG 測試行的說明文字和 21 的斷言，沒有新增 @test，所以條數不變；改完後重跑 21/25/04 全綠。）

## 自我審查
- 04 行數上限沒碰到（本波沒動 PROTOCOL／LEADER／SKILL）。
- 嚴格版 Important4 對現在全倉零命中；排除清單跟 AC16 一樣。
- 條數 724 是本波 dev 全員完成當下的實跑值；如果 wave-close 之後又有修復波加測試，條數要再更新。

## 疑慮
- 若本波審查再開修復、改動測試數，CHANGELOG 的 724／+68 需要再補一次（process 的 ruling 已預見）。

## 追加：[TASK] BACKLOG 補一列（波 2 審查 Minor 3）
- `.dkbo/tasks/BACKLOG.md` 表格末列（第 12 行，說明段之前）加一列：2026-09-24／bklog 波 2 審查 Minor 3／`dk_owned`（`lib/ownership.sh:12`）與 `first_glob`（`dk-spawn:57`）仍裸 `awk -F` 以管線切可改欄，含跳脫管線時錯位／建議改用 `DK__BRIEF_SPLIT`。兩處行號已對照現碼確認。
- 描述裡刻意不寫字面的 `'|'`：表格儲存格裡的 `|` 會多切一欄（初版就犯了，已改），改寫後該列與上一列同為 6 個欄位分隔（`awk -F'|'` NF=6）。
- `diff` 對照原檔只有這一行新增，其餘行一字不動。
- 測試：不適用新測試（純紀錄列）；引用 BACKLOG 的測試檔（`grep -l BACKLOG tests/unit/*.bats`）重跑 272 條全 ok。
