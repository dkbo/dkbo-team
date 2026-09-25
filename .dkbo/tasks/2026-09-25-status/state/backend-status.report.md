# backend-status 報告（波 1）
## 做了什麼
- 新 bin `.dkbo/bin/dk-status`（AC1–AC7）：
  - 參數：只收 `--json [<任務>]`；其餘（沒帶 `--json`、未知旗標、`--json` 不在第一位、多於一個位置參數）exit 2 並印規定的那句；找不到任務走 `dk_die`（exit 1、`dk: no task '<x>'`）。`<任務>` 先比資料夾名（必須符合 `^[0-9]{4}-[0-9]{2}-[0-9]{2}-[^/]+$` 且是目錄，所以 `_chores`、`.`、`..`、`BACKLOG.md`、`../tasks` 都是找不到），再逐字比短名、取日期最晚的那個（不經 glob，`*` 之類不會展開）。
  - 讀法：每個任務一支 awk 把 process／messages／.task.env／.panes／INDEX／state/*.md 串成一條流（每檔前一行 `\x1edk-status:<路徑>` 檔頭），一次 `jq -n -R` 讀完並組出整個任務物件；所有解析（時間戳、欄位、訊息格式、state 鍵）都在 jq 裡，原文不經 shell，所以 AC6 的引號／反斜線／tab／`$(...)`／emoji 原樣進 JSON。list 模式每任務固定 1 支 awk＋1 次 jq，外加 kinds_down 1 次、組裝 1 次。
  - 重用 lib：brief 的切欄走 `dk_brief_owners`／`dk_brief_waves`／`dk_brief_acceptance`／`dk_brief_section`（jq 只做同一套 `\|` 跳脫感知切法，切完還原成字面 `|`）；`dk_minor_count`；`dk_repos_rows`；`dk_kinds_down_rows`＋`dk_epoch_to_local`；`dk_now`。
  - 時間戳取法照 `dk_ts_pick`（第 2／3／4 欄逐欄相等的最後一筆）；波 N 關閉 ⟺ `wave-close N tests … K agents closed`；commit 行只收 `commit <hex> wave N[ repo <名>]`。
  - 不叫 herdr、不 source session 綁定、不寫任何檔。
- 新檔 `.dkbo/status-schema.md`（AC8）：list／detail 每一個鍵的表（鍵名、型別、可否 null、來源、說明），相容規則，三件事（until 是本地時間用 until_epoch、續行計進 skipped_lines.messages、`wave-close`／`violation`／`unreported`／`review` 各代表什麼）。
- 新檔 `tests/unit/38_status.bats`（AC9）：15 條，AC1–AC10 每條至少一條；夾具照 AC9 要求（alpha done、beta running 且波 2 開著、`.panes` 兩列含 legacy 兩欄、state 兩位含 blocked_by、[自主]＋一般 ruling、[UNDELIVERED]、ACK、壞 process 行、三行壞 messages 行、舊日期同短名空資料夾、未過期兩列＋過期一列 kinds-down）；另用 tests/fixtures 的 flowgap 真 log 對 `dk_ts_pick` 與 `dk-timeline` 逐波比對。

## 測試
### 紅
先寫 38（14 條）、dk-status 與 status-schema.md 都還沒有時跑：
```
$ tests/run.sh tests/unit/38_status.bats
1..14
not ok 1 AC1 介面：list／detail 單行 JSON＋換行 exit 0；資料夾名或短名（短名取日期最晚）
#   `run dk-status --json; [ "$status" -eq 0 ]' failed
not ok 2 AC1 用法錯 exit 2、找不到任務 exit 1，訊息逐字
…（3–12 同樣 not ok：dk-status: command not found；12 是 [ -f status-schema.md ] failed）
not ok 13 AC9 list 不逐行叫 jq：呼叫次數對任務數線性（≤ 常數×N）且與 process 行數無關
ok 14 AC10 文件：dk-status 在三份 README 都出現
```
（AC10 那條一開始就綠：backend-docs 已先把 dk-status 加進三份 README。AC9 第一次寫的版本在指令不存在時會空過，補了「dk-status 必須成功且計數 > 0」後才紅，上面是補強後的紀錄。）

實作中自我審查發現的 bug 另取一次紅（`jq -R` 多檔時前一檔沒結尾換行會黏到下一檔第一行，實測 `{"fa":["a1"],"fb":["a2b1","b2"]}`）：
```
$ tests/run.sh tests/unit/38_status.bats
not ok 15 AC5 檔尾沒有換行：最後一行不會黏到下一個檔的第一行
#   `[ "$(jq -c '[.updated_at, .gate1_at, .status, .display]' <<< "$t")" = '["2026-09-25T11:00","2026-09-25T11:00","running","進行中|任務"]' ]' failed
```
### 綠
```
$ tests/run.sh tests/unit/38_status.bats
1..15
ok 1 AC1 介面：list／detail 單行 JSON＋換行 exit 0；資料夾名或短名（短名取日期最晚）
…
ok 15 AC5 檔尾沒有換行：最後一行不會黏到下一個檔的第一行
（15/15 ok）
$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh tests/run.sh && echo SC-OK
SC-OK
```
相關既有測試：`tests/run.sh tests/unit/{25_docs_policy,35_test_hygiene,24_portability,29_constraints,37_shellcheck,04_docs,14_install}.bats` → 54/54 ok。

完整套件（送 DONE 前一次，worktree 含 backend-docs 未 commit 的 README／VERSION／CHANGELOG／21 改動）：
```
$ tests/run.sh
1..771
770 ok、1 not ok、0 skip（37_shellcheck 實跑：ok 754 全域約束的檔案集合 shellcheck 零警告）
not ok 562 CHANGELOG 首節列出本版的每一條變更  ← 21_version：「CHANGELOG 首節測試條數仍是佔位」
```
那一條紅是 backend-docs 的 CHANGELOG 條數佔位，照 brief 由它在收到我的 [DONE] 後跑完整測試填實跑值；不是我的檔。

真資料抽查（唯讀，DK_ROOT 指主樹）：list 11 個任務 0.32 秒、detail 0.05 秒；kinds_down 讀到 agy／codex 兩列，各任務 status／waves_closed／closed_at 與 INDEX、process.md 對得上。

## 自我審查
- 全域約束：沒用 bash 4 語法（無關聯陣列／mapfile／`${x^^}`），空陣列展開用 `${files[@]+"${files[@]}"}` 顧 bash 3.2 的 `set -u`；沒用 `date -d`／`-r`；沒新增 lib、settings 鍵、.task.env 鍵；JSON 全由 jq 產生；否定斷言都用 refute_grep／refute（35 過）。
- jq ≥ 1.5：刻意只用 1.5 就有的東西（`inputs`、`capture`／`test`／`sub`／`splits`、`first`／`last`、`any`、`to_entries`、字串切片），沒用 `--rawfile`、`--args`、`$ENV`、`IN` 這類 1.6 之後才有的東西；gsub 一律不用（1.5 對可空匹配有無窮迴圈的 bug）。**但本機只有 jq 1.7，沒在 1.5 上實跑過。**
- 唯讀：AC7 測試驗 `find -newer` 為空、檔案清單不變、herdr stub 記錄為空、HERDR_* unset 仍成功；另對非註解行 refute_grep `herdr|dk-watch|dk_task_dir|HERDR_…`。
- 空行計進 skipped_lines（字面照「第 1 欄不是時間戳的行」），schema 文件寫明了。
- state 的同鍵重複：`notes` 全部串接（契約），其他鍵取第一次出現；鍵值空字串給 null。schema 文件寫明。
- INDEX 狀態不在四種（planning／running／done／abandoned）之內時給 `unknown`（契約列舉只有五值）。

## 疑慮
- `waves[]` 的時間戳只看合法時間戳行；`dk_ts_pick` 不驗第 1 欄，所以若有一行第 1 欄壞掉但第 2–4 欄剛好是 `wave-open N`，dk-timeline 會取它、dk-status 不會。正常 process.md 不會出現（dk_process 一律寫 dk_now），只在人手改壞時才有差。
- INDEX 以名稱比對，任務與雜務若同名會對到同一列（與 dk_index_set 同一個限制，沒另外過濾型態欄）。
- 本任務的 dk-status 只存在於 worktree，本任務內主樹沒有這支，沒有被本任務流程用到。

## 修復輪（leader 轉 reviewer-a Minor 1、2）
### 做了什麼
- Minor 1：`members` 原本是 `sort_by(.name)`，排的是去掉 `.md` 的名字，跟 AC4／status-schema.md 寫的「依檔名升冪」不一致（`qa.md`＋`qa-b.md` 會排成 `qa, qa-b`）。改成排序前先對 state 路徑的 basename（含 `.md`）用 jq `sort_by` 排，也就是碼點序，跟 glob 的 locale 無關（`.dkbo/bin/dk-status` members 那段）。根因：排序鍵用的是 state 名，不是檔名。
- Minor 2：夾具裡四處 `$(echo pwned)`／`$(rm -rf /)`／`$(date)`／`$(id)` 全部換成無害又抓得到的 `$(touch "$PROJECT/pwned")`；斷言從 `[ ! -e pwned ]`（原本什麼都驗不到）改成 `[ ! -e "$PROJECT/pwned" ]`。
### 紅
```
$ tests/run.sh tests/unit/38_status.bats
not ok 16 AC4 members 依檔名（含 .md）碼點升冪，不靠 glob 的 locale：qa-b.md 排在 qa.md 前
#   `[ "$(detail beta '[.task.members[].name]')" = '["backend","frontend-cart","qa-b","qa"]' ]' failed
```
Minor 2 只改測試，沒辦法在正確的實作上取紅；改用 scratchpad 證明新斷言有效：把夾具第 90 行交給 `bash -c 'eval "echo \"$1\""'`、`PROJECT=<scratchpad>` → `<scratchpad>/pwned` 真的被建出來（之後已刪），所以只要有回歸讓內文被 shell 求值，`[ ! -e "$PROJECT/pwned" ]` 就會紅。
### 綠
```
$ tests/run.sh tests/unit/38_status.bats
1..16   （16/16 ok）
$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh tests/run.sh && echo SC-OK
SC-OK
$ tests/run.sh
1..772  772 ok、0 not ok、0 skip，rc=0（ok 754 全域約束的檔案集合 shellcheck 零警告）
```
測試總數 771 → 772（+1：38 第 16 條），CHANGELOG 條數要 backend-docs 重填。status-schema.md 原本就寫「依檔名升冪」，實作改成跟它一致，文件不用動。Minor 3（dk_ts_pick 不驗時間戳）照原報告的疑慮留著，沒改。
