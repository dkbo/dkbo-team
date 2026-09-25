# reviewer-a 報告（波 1）

## 複看（修復輪，即整枝評議）— 2026-09-25T10:22 差異包
- Minor 1 ✅ 已修：`.dkbo/bin/dk-status:143` 改成先對 state 路徑的 basename（含 `.md`）做 `sort_by`，也就是碼點序，和 status-schema.md:95 的「依檔名升冪」一致。新增的 38 第 16 條在預設與 `LC_ALL=C` 兩種 locale 下都驗 `qa-b.md` 排在 `qa.md` 前。
- Minor 2 ✅ 已修：`38_status.bats:72/90/115/118` 的夾具全部換成 `$(touch "$PROJECT/pwned")`。`:297` 改成斷言 `[ ! -e "$PROJECT/pwned" ]`。我查過 `PROJECT` 在 helpers.bash:29 有 export，所以只要有回歸讓內文被 shell 求值，檔案真的會被建出來，這條就會紅；`rm -rf /` 已清掉。
- Minor 3 照原判定留著，只影響人手改壞的 process 行，不擋 merge。
- CHANGELOG 測試行改成 `772 bats（+16）`＝756＋16，AC4 的條數也改成四條，與 38 的 16 條相符。
- 整枝評議：本任務只有一波，這份 diff 就是整枝。修復輪只動了 dk-status 的排序和 38 的夾具、多一條測試，沒碰共用契約。其餘 AC 的判定維持下文，沒有新的 Important。
- 複看測試：`tests/run.sh tests/unit/38_status.bats tests/unit/21_version.bats` → 1..22 全綠；shellcheck 零警告；完整 `tests/run.sh`（worktree）→ 1..772，ok 772、not ok 0、skip 0，rc=0（含 ok 562 CHANGELOG 首節、ok 733 沒有 `!` 否定述句、ok 754 shellcheck 實跑）。
- 修復輪結論：Important 0，Minor 0 條新增（原 Minor 1、2 已修，Minor 3 留著）。


審查對象：`waves/1.diff`（since 6c610ff，全是未 commit 的工作樹，9 個檔）＋ brief.md 全文。worktree `/home/bal/project/teamflow/.worktrees/status`。

## 規格合規
- ✅ AC1 介面：`[ "$1" = --json ] && [ $# -le 2 ]`＋`case "$2" in -*)` 擋掉無 `--json`／未知旗標／多參數／`--json` 不在第一位，exit 2、文案逐字（`.dkbo/bin/dk-status:13-15`）。`is_task` 要求 `^YYYY-MM-DD-[^/]+$` 且是目錄，`_chores`／`.`／`..`／`../tasks` 一律找不到，exit 1 印 `dk: no task '<x>'`（`:18-27`）。短名解析取 glob 排序最後一個＝日期最晚，與 dk-timeline 的 `compgen … | tail -1` 等價，而且逐字比對、不當 glob。stdout 是 `jq -c` 單行。
- ✅ AC2 list：頂層五鍵（`:230`、`:239`），`dkbo_version` 用 `tr -d '[:space:]'`、沒有檔就 null（`:226-227`），`tasks` 按 `sort_by(.dir)` 排序。kinds_down 走 `dk_kinds_down_rows`，本地時間逐列用 `dk_epoch_to_local` 算（`:209-224`），列序對得上（awk 過濾與 jq 的 `select(. != "")` 丟掉的是同一批空列，`to_entries` 在 capture 之前取 index）。
- ✅ AC3 detail：五個頂層鍵；task＝摘要＋九個詳情鍵（`:118-174`）。38 的 AC3 測試逐鍵比對過摘要與 list 那一筆相同。
- ✅ AC4 欄位來源：INDEX 以 `split("|")` 的 `.[2] == " "+name+" "` 比對，`|`→`／` 與 `dk_index_set` 一致（`:80-83`）；`pick` 與 `dk_ts_pick` 同樣是逐欄相等、取最後一筆（`:57`）；關閉只認 `… tests … K agents closed$`（`:58`、`:88`），我對照過 `dk-wave-close:187` 的實際寫法（含 `--force` 的 `failed (…, forced)`）與 `:129` 的未強關失敗行，判定正確；ruling、`[自主]`、members 的來源都對。對主樹 11 個真實任務（唯讀）跑 list 和 detail，status／waves_closed／closed_at／review_verdict 與 INDEX、process.md 都一致。**有一處和字面不符：成員排序**，見 Minor 1。
- ✅ AC5 容錯：每個檔都先檢查 `-f`／`-r`，缺了就給 `[]`／null；壞行計進 `skipped_lines`；檔尾沒換行不會黏行（改用 awk 加檔頭標記，是 dev 自己抓到的 bug，38 第 15 條有守）。
- ✅ AC6 JSON 安全：所有原文都經 `jq -R` 讀入，沒有經過 shell 展開；38 的 AC6 用 `sed` 取原文逐字比對。
- ✅ AC7 唯讀：程式碼（扣掉註解）沒有 herdr／dk-watch／dk_require_herdr／dk_task_dir／HERDR_*，也沒有任何寫入的重導向。38 的 AC7 驗了 find -newer、檔案清單、herdr stub log，並且兩個 HERDR 變數都 unset。
- ✅ AC8 schema 文件：每個鍵都有型別、可否 null、來源與說明；相容規則、三件事、`wave-close`／`violation`／`unreported`／`review` 各代表什麼，都對得上 dk-wave-close:102/105/187 的真實行格式；反向防漂移測試也在。
- ✅ AC9 測試：夾具符合所有要求（done＋running＋開著的波、.panes 兩列、state 兩位、`[自主]` 與一般 ruling、UNDELIVERED、壞 process 行、未過期與已過期的 kinds-down、舊日期同短名、每個陣列都非空、有一位帶 blocked_by）；jq 計數測試按任務數線性、與行數無關；backend-status 的報告附了取紅紀錄。
- ✅ AC10 文件與版本：兩份根 README 的指令表各加一列。`.dkbo/README.md` 沒有指令表，改在「日常使用」加一條，另加專段，合理。版號 8 處全換成 0.17.0，沒有殘留 0.16.0。CHANGELOG 有 feat(status)／docs 條目；`771 bats（+15）`＝756＋15，與我實跑的條數相符。21_version 首節清單已換成 0.17.0。
- ✅ AC11：我在 worktree 實跑完整 `tests/run.sh`，結果見「## 測試」。
- ✅ 全域約束：只新增了三個檔；沒有 bash 4 語法（`local -a`、`${arr[@]+…}` 都是 3.2 安全寫法）；沒有 `date -d/-r`；shellcheck 零警告；JSON 全由 jq 產生（`printf '%s' "$rows" | jq -R -s` 傳的是原文，不是拼 JSON）；list 模式每個任務一次 jq；沒有新增 settings／.task.env 鍵、lib 或 skill；dev 沒改所有權以外的檔。

## Important
（無）

## Minor
累積 Minor 判定：brief「本任務累積的 Minor」是空的，不需要 triage。以下是本波新提的：

1. `.dkbo/bin/dk-status:167`：`members` 用 `sort_by(.name)` 排序，排的是去掉 `.md` 的名字，但 AC4 與 status-schema.md:95 寫的是「依檔名升冪」。當一個名字是另一個的前綴、後面接 `-` 時，兩種排法結果不同：實測 `qa.md`＋`qa-b.md` 輸出 `["qa","qa-b"]`，照檔名（C 排序 `-` < `.`）應為 `["qa-b","qa"]`。修法二選一：拿掉 `sort_by(.name)`，直接沿用 glob 的檔名順序；或把文件改成「依 state 名升冪」。不影響正確性。
2. `tests/unit/38_status.bats:90`、`:297`：夾具 messages 內文放了 `$(rm -rf /)`。萬一將來有回歸把內文丟給 shell 求值，這條測試本身就會嘗試刪根目錄（GNU rm 有 --preserve-root 會擋，但這不是該賭的東西）。另外 `:297` 的 `[ ! -e pwned ]` 其實什麼都沒驗到：夾具裡只有 `$(echo pwned)`，只會印字、不會建檔。建議改成 `$(touch "$PROJECT/pwned")` 這類無害又可偵測的內容，再斷言那個絕對路徑不存在。
3. `.dkbo/bin/dk-status:56` 對上 `dk_ts_pick`：第 1 欄不是合法 `YYYY-MM-DDTHH:MM` 的行（例如人手寫了帶秒的時間戳），dk-timeline 仍會拿它，dk-status 則略過並計進 skipped。backend-status 的報告已自己註明；只有人手改壞 process.md 時才會出現，記下供整枝評議參考。

## 測試
- `tests/run.sh tests/unit/38_status.bats` → 1..15，15/15 ok。
- `shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh tests/run.sh` → 零警告。
- 完整 `tests/run.sh`（worktree，含兩位 dev 未 commit 的改動）→ 1..771，ok 771、not ok 0、skip 0，rc=0；含 `ok 562 CHANGELOG 首節列出本版的每一條變更`、`ok 733 tests/ 裡沒有 ! 開頭的否定述句`、`ok 754 全域約束的檔案集合 shellcheck 零警告`（37 實跑、沒有 skip）。CHANGELOG 寫的 771（+15）與實跑相符。
- 真實資料抽查（唯讀，`DK_ROOT` 指主樹 `.dkbo`，HERDR_* unset）：list rc=0，11 個任務；抽 detail `briefrev`（只有計畫檔、沒有 .task.env）、`multirepo`（5 波、6 位 member）、`status`（開著的波 1），全部 rc=0，skipped 都是 0，waves／members 與 process.md 對得上。
- 邊界抽查（scratchpad 自造夾具）：`wave-close 1 tests  2 agents closed`（tests 空字串）→ 算關閉、`tests:""`；`[DONE]` 後面沒有內文 → text `""`；`[Done]` 小寫 → 略過並計數；只有時間戳的 process 行 → 產出 kind `""` 的事件；成員排序見 Minor 1。

## 疑慮
- 本機只有 jq 1.7，沒辦法實測 jq 1.5／1.6。`splits`、`capture` 的具名群組、字串切片、`def f($x)`、`inputs`，照我的了解 1.5 都有；程式對選配群組一律用 `// 預設值` 接住，沒找到具體的不相容點，但全域約束寫的是 jq ≥ 1.5，這一點沒有測試守。
- 本任務的 dk-status 只在 worktree 裡，主樹沒有；我是用 worktree 的腳本去讀主樹的資料，不算本任務流程用到。
