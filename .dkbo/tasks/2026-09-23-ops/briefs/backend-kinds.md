# 營運回饋修補（panova headermerge） — 給 backend-kinds 的切片（波 4）
由 dk-wave-open 產生，只讀。完整 brief 在 /home/bal/project/teamflow/.dkbo/tasks/2026-09-23-ops/brief.md。

## 目標
把 panova headermerge 暴露的六個 dkbo 缺口補起來：熔斷跨任務並記恢復時間、`[LIMIT]` 留下畫面證據、codex 的快到額度選單不再誤判成撞額度、波中改 brief 能重產切片並重新起算逾時、dev 送 `[DONE]` 前驗 state 格式、結案後 report 的結果行與時間表是最終值。
領導規範補兩條：送 TASK／DECISION 前先讀未 ack 的訊息；有視覺變更的任務，結波後先請人看畫面再做整枝評議。
文件與測試跟著改，出貨版本 0.12.0。不做：request 第三段的 panova 專案面（dev server 監看等）。

## 全域約束（全文）
bash 3.2+；不得使用 bash 4 語法（關聯陣列、${x^^}、declare -A、mapfile）
依賴只有 herdr 0.9.0、git ≥ 2.17、jq ≥ 1.5、flock；不得新增依賴。`date -d` 是 GNU 專屬，用到時必須先試、失敗有退路
shellcheck 零警告（`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh`）
不新增 settings.env 鍵、不新增 skill、install.sh 不新增 symlink；`.task.env` 不新增鍵
新增的 bin 只有 `dk-kind` 一支；新增的執行期檔只有 `.dkbo/.sessions/kinds-down` 與它的鎖 `.dkbo/.sessions/kinds-down.lock` 兩個（`.sessions/` 已被 .gitignore，不進版控）
不改「員工在波內不 commit、dk-wave-close 統一 commit」的模型；不改 `DK_KIND_DOWN` 在 `.task.env` 的既有語意（本任務內熔斷）——專案層熔斷是**另加**一層，不是取代
reviewer 逾時（`[TIMEOUT]`）造成的熔斷只記本任務，不寫進專案層：逾時不代表額度用完
否定斷言一律用 tests/helpers.bash 的 refute_grep，不得寫 ! grep -q
0.11.2 的 552 條測試語意不變：不刪、不放寬既有斷言；只允許（a）新增斷言，（b）`03_kinds.bats` 裡 codex 額度式子那幾條依 AC4 改期望值，（c）`12_task_close.bats` 裡斷言時間表「進行中」的地方依 AC11 改期望值
面向使用者的文案是繁體中文；目標版本 0.12.0
例外：本任務的成員**可以**修改 `.dkbo/` 底下的腳本、模板、規則檔與 skill 文件（PROTOCOL 停止條件「不改 .dkbo/ 規則檔」在本任務不適用；ruling 見 process.md）；但只能改所有權表劃給自己的檔
領導跑的是主樹的腳本：本任務的新閘（專案層熔斷、`--refresh`、state 驗證）在本任務內一次都不會生效，要等結案合併後的下一個任務；report 不得宣稱「本波已用到」
已知風險：本任務要改 `kinds/*.sh` 的額度式子與它的測試夾具，員工畫面必然出現這些字樣；員工剛轉 idle、state 還沒寫 done 的空檔可能被 dk-watch 判成 `[LIMIT]`。領導收到 `[LIMIT]` 一律先 `herdr agent read` 看畫面再決定要不要關 pane

## 你的波次
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
| 4 | 修復 | backend-kinds | AC18：dk-watch 的 hit 截斷改按字元（含 `LC_ALL=C` 下）、09 補中文樣本斷言（stub herdr 可比照真 herdr 拒收非 UTF-8）；Minor：dk-resume 兩波之間也印專案層熔斷、（猜）→ `(guess)`、codex 目標時間已過走 guess，各補斷言。重現見 state/reviewer-a.report.md Important 1。做完先送 `dk-msg backend-docs "[DONE] …"` 讓他更新條數，再送領導 | S | 09/10/34 全過；shellcheck 零警告；report 的「## 測試」有紅綠 | 預設 |

## 倉庫
/home/bal/project/teamflow/.worktrees/ops

## 你的檔案所有權
| 成員 | 可改 | 只讀 |
|---|---|---|
| backend-kinds | .dkbo/bin/dk-watch, .dkbo/bin/dk-spawn, .dkbo/bin/dk-resume, .dkbo/bin/dk-kind, .dkbo/lib/kinds.sh, .dkbo/lib/review.sh, .dkbo/kinds/codex.sh, tests/stub/**, tests/unit/03_kinds.bats, tests/unit/09_watch.bats, tests/unit/26_watch_events.bats, tests/unit/20_review.bats, tests/unit/28_brief_review.bats, tests/unit/07_spawn.bats, tests/unit/10_resume.bats, tests/unit/34_kind_down.bats | .dkbo/lib/common.sh, .dkbo/kinds/claude.sh, .dkbo/kinds/agy.sh, tests/helpers.bash |

## 共用契約（全文）
（一列一個契約。擁有者填一個成員短名；消費者填一個或多個、逗號分隔；沒有就填 —。完全沒有契約時只留表頭）
| 契約 | 擁有者 | 消費者 | 形狀／簽名 | 變更流程 |
|---|---|---|---|---|
| kinds-down 檔 | backend-kinds | backend-docs | `.dkbo/.sessions/kinds-down`，一列一筆、空白分隔：`<kind> <恢復 epoch> <exact\|guess> <記錄時間 YYYY-MM-DDTHH:MM> <來源任務目錄名> <agent> <第一條 hit，行尾剩餘全部>`；讀的人略過恢復 epoch ≤ 現在的列；檔不存在＝沒有專案層熔斷 | 動它要先 ESCALATE |
| dk-kind 指令 | backend-kinds | backend-docs | `dk-kind [status]`：每列 `<kind>  down until <本地時間>[ (guess)]  from <任務> — <第一條 hit>`，全部恢復時印 `沒有專案層熔斷`；`dk-kind up <k>`：印 `kind <k> up`；usage 錯誤 exit 2 | 動它要先 ESCALATE |
| [LIMIT] 訊息與證據 | backend-kinds | backend-docs | `.blocked/<agent>.limit` 追加 `hit: <行>`（≤5 行）；訊息 `[LIMIT] from dk-watch: <agent> 撞額度 — <第一條 hit>`，整則 ≤200 字 | 動它要先 ESCALATE |
| wave-open --refresh | backend-flow | backend-kinds, backend-docs | `dk-wave-open <N> --refresh`；成功印 `wave <N> refreshed; slices in <dir>/briefs/`；process 行 `wave-refresh N members <成員…>`；刪 `.blocked/wave-N.timeout`，不刪 `.blocked/wave-N.devdone`；`dk-spawn` 在波開著時加入 group=dev 成員的同一步刪 `.blocked/wave-$DK_WAVE.devdone`（兩個標記的語意屬 dk-watch：不存在＝還沒通知過，不得改；波 2 經關卡② 改） | 動它要先 ESCALATE |
| state 的 touched 文法 | backend-flow | backend-docs | `touched:` 那一行冒號後只能是空白或 `[]`；從下一行到下一個頂格行之間，每個非空行都必須以 `  - `（兩個空白）開頭，路徑不含 `{`、`}`、`*`、`?`；零項合法（裸 `touched:` 與 `touched: []` 都是零項）。`templates/state.md` 與 PROTOCOL 的範例照這個寫 | 動它要先 ESCALATE |
| dk-msg 的兩行提示與 DONE 驗證訊息 | backend-flow | backend-docs | AC8、AC9 的 stderr 原句；AC10 的拒絕訊息以 `dk-msg: state 格式錯：` 開頭 | 動它要先 ESCALATE |

## 驗收標準（全文）
- [ ] AC1 專案層熔斷檔 `.dkbo/.sessions/kinds-down`：dk-watch 判定撞額度（`handle_limit`）時，除了照舊寫本任務 `DK_KIND_DOWN`，另在這個檔追加或更新一列（形狀見共用契約）；同一 kind 已有未過期的列就更新成較晚的恢復時間，不重複。寫檔走 flock，鎖檔是 `.dkbo/.sessions/kinds-down.lock`（同 `dk_env_set` 的手法：鎖另一個檔，資料檔可以 tmp＋mv 改寫）。reviewer 逾時的熔斷**不**寫這個檔
- [ ] AC2 恢復時間：從撞額度當下讀到的畫面解析，全部走可攜的純算術，不依賴 `date -d`。agy 認「Resets in <N>h<M>m[<S>s]」與沒有小時的「Resets in <M>m[<S>s]」（後者沒有實測樣本，用構造樣本測），換成秒數加到 `date +%s`，標 `exact`；codex 認「try again at <英文月份縮寫> <日><st|nd|rd|th>, <年> <時>:<分> <AM|PM>」，用月份表與 12→24 小時制轉成 `YYYY-MM-DDTHH:MM`，以 `lib/common.sh` 的 `dk_ts_minutes(目標) − dk_ts_minutes(dk_now)` 乘 60 加到 `date +%s`，標 `exact`；兩種都解析不到才用「現在 + 5 小時」並標 `guess`。解析函式放 `lib/kinds.sh`，單元測試：agy 有小時、agy 無小時、codex 實測原文（`11th`）、codex 非 `th` 序數（例 `22nd`、`1st`）、12 AM／12 PM 邊界、解析不到走 guess；另一條在 PATH 上放一支拒絕 `-d` 的假 `date`，同一段 codex 樣本算出的 epoch 與正常環境相差 ≤ 60 秒
- [ ] AC3 派人前查專案層：`dk_review_kinds`（`lib/review.sh`）把 kinds-down 裡恢復時間未到的 kind 視同已熔斷，stderr 印 `kind <k> 在專案層熔斷到 <本地時間>（<來源任務>），跳過`。`dk-spawn`：`--kind <k>` **明寫**且 `<k>` 專案層未恢復 → 拒絕（exit 1），印同一句的前半加上解除方法 `dk-kind up <k>`；沒給 `--kind`、用角色檔預設的 kind 而命中 → 只在 stderr 印同一句與 `dk-kind up <k>`，照派（誤判的 claude 不能把下一個任務的每個角色都擋死；ruling 見 process.md）。恢復時間已過的列視同不存在（讀的時候略過，不必當場刪）。07_spawn 各一條「拒絕」與「只警告照派」的斷言
- [ ] AC4 codex 的快到額度切換模型選單不再被判成撞額度：`kinds/codex.sh` 的 `KIND_QUOTA_RE` 目前有四個分支，移除**第 3 個分支**（`kinds/claude.sh` 的 `KIND_QUOTA_RE` 第 2 個分支就是同一個字串；它同時命中選單標題與選單第 3 項的說明文字），第 1、2、4 個分支保留。這也代表 codex 只印那個片語的暫時性限流不再熔斷——這是想要的，CHANGELOG 要明寫，免得被當成回歸。樣本（取自 panova spike：寬 pane 完整選單、窄 pane 截斷選單、上方另有耗盡訊息的選單）在 `03_kinds.bats` 各一條：只有選單的兩條 → 不中額度、中審批；上方有耗盡訊息的那條 → 中額度。claude 與 agy 的額度式子不動
- [ ] AC5 `[LIMIT]` 留證據：`handle_limit` 在 `.blocked/<agent>.limit` 既有的 `notified`／`delivered` 行之外，追加最多 5 行 `hit: <命中的畫面行>`（同一組 grep 選出的行，去頭尾空白，每行截 160 字）；送給領導的 `[LIMIT]` 訊息尾端附第一條命中行（整則仍 ≤200 字，超過就截）。process.md 的 `limit …` 行**不**附命中行（避免領導讀 process 時畫面冒出額度字樣）。既有「`delivered` 在就不重送」的判斷不變。輪詢路徑（09_watch）與事件路徑（26_watch_events）各一條斷言寫出 `hit:` 行
- [ ] AC6 `dk-kind`：`dk-kind` 或 `dk-kind status` 列出 kinds-down 裡恢復時間未到的列（kind、恢復時間本地字串、`guess` 標記、來源任務、第一條證據）；`dk-kind up <k>` 從兩張清單拿掉 `<k>`——kinds-down 的所有該 kind 列，以及綁著任務時 `.task.env` 的 `DK_KIND_DOWN`（reviewer 逾時的熔斷只在後者，這正是最常要解的情況）；有真的拿掉東西才記 process `kind <k> up`；兩張都沒有就印一句說明、exit 0；`<k>` 不是 `kinds/*.sh` 裡的 kind 就 exit 2。`dk-kind` 要以 100755 進版控（`git ls-files -s .dkbo/bin/dk-kind`），34_kind_down 直接執行它而不是 `bash dk-kind`。`dk-resume` 的 `kinds down:` 那一行後面多印專案層未恢復的 kind 與恢復時間
- [ ] AC7 `dk-wave-open <N> --refresh`：只能用在第 N 波正開著時（`DK_WAVE == N`），否則拒絕並說明；依當下的 brief.md 重產第 N 波**所有**成員的切片（含 brief 裡新加進第 N 波的成員），不改 base、不動 `.panes`、不 spawn；把 `DK_WAVE_STARTED` 重設成現在，並刪掉 `.blocked/wave-N.timeout`（整波逾時從這一刻重新起算）；**不刪** `.blocked/wave-N.devdone`（波 2 改：refresh 當下刪會在新成員 spawn 前的空窗重推假聚合，整枝評議 I2；ruling 見 process.md）。改由 `dk-spawn` 在第 `DK_WAVE` 波開著時、把一位 group=dev 的成員寫進 `.panes` 的同一步刪掉 `.blocked/wave-$DK_WAVE.devdone`，新 dev 交 `[DONE]` 時 dk-watch 才會再推聚合；只請原有 dev 重做、沒有新成員時聚合不重推（與 0.11.x 重派行為相同），領導叫 dev 做完回 `[FIXED]`；process 記 `wave-refresh N members <成員…>`。既有「wave N was already opened」的拒絕只對不帶 `--refresh` 的呼叫成立。`dk-timeline` 的波起訖仍以 `wave-open N` 為準，不受 refresh 影響。18_wave_open 補一條：devdone 已 delivered → refresh → 標記**仍在**、timeout 標記被刪；07_spawn 補一條：波開著時 spawn 一位 dev → devdone 被刪，spawn qa／reviewer → 不刪
- [ ] AC8 切片過期提示：寄件者是領導（`dk_leader_name`；員工之間互傳不提示）且 `dk-msg <員工> "[TASK|DECISION|BUG] …"` 時，若 `brief.md` 的 mtime 晚於該員工的 `briefs/<state 名>.md`，stderr 印一行 `dk-msg: brief.md 比 <切片> 新，員工讀的是舊切片；改了會影響他的段落就先 dk-wave-open <N> --refresh`，訊息照送（不擋）
- [ ] AC9 未讀提示：領導送 `[TASK]`／`[DECISION]` 時，若 messages.log 裡在領導最後一筆 `[ACK]` 之後有寄給領導的訊息，stderr 印一行 `dk-msg: 你有 <n> 則未 ack 的訊息（最新一則 <時間> 來自 <寄件者>），先讀再送`，訊息照送（不擋）。沒有任何 `[ACK]` 時從 log 開頭算；dev 只落盤、不叫醒領導的 `[DONE]` 也算未 ack
- [ ] AC10 dev 送 `[DONE]` 前驗 state 格式：在 dk-msg 既有的「dev 的 [DONE] 必須 status: done」同一處加驗，不過就 exit 2，訊息以 `dk-msg: state 格式錯：` 開頭並指出哪一行錯、正確寫法長什麼樣：（a）`status`、`touched`、`report` 三個頂格鍵都必須在（`current`／`todo` 不驗：沒有任何閘讀它們；ruling 見 process.md）；（b）`touched` 照共用契約「state 的 touched 文法」；（c）`report:` 的路徑（相對任務目錄）必須已存在且非空。只驗 dev，不驗 reviewer、qa 與雜務
- [ ] AC11 結案後 report 是最終值：`dk-task-close` 在 merged 與 in-tree 兩條成功路徑上，於 `dk_process "task-close …"` **之後**、第二次 `commit_memory` 之前再跑一次 `fill_timeline`，時間表的「任務」列結束時間是 task-close 那一刻、不再帶「（進行中）」；同一時間把 report.md 第一個以 `結果：` 開頭的行的值（`結果：` 之後到三個連續空白或行尾之前）改寫成 `merged <sha>`／`in-tree <sha>`，行內其他欄位（分支、波數）不動，沒有這一行就不動。abandon 路徑不變
- [ ] AC12 領導規範：`.dkbo/skills/run/SKILL.md` 的故障段 `[LIMIT]` 那條改寫——先讀 `.blocked/<agent>.limit` 的 `hit:` 行（或 `herdr agent read`）判斷真假，誤判用 `dk-kind up <k>` 解熔斷並記 ruling；真的就照舊處理，並提一句專案層熔斷會讓下一個任務自動跳過該 kind。同篇補兩條：送 TASK／DECISION 前先讀 messages.log 裡未 ack 的訊息（對應 AC9 的提示）；有視覺變更的任務，計畫中的最後一波結波後、跑 `dk-review-pack --task` 之前，先請人看畫面（dev server 或截圖），人確認沒有追加才跑整枝評議。另提一句「不要叫員工跑 `dk-kind`」（它會把命中行印在員工畫面上，員工 pane 會把自己熔斷）。改寫 `[LIMIT]` 那條時保住 `04_docs.bats` 已斷言的 `dk-wave-close --agent`。波中改 brief 的做法寫成「改 brief.md → `dk-wave-open <N> --refresh` → 再 dk-msg 員工重讀切片」
- [ ] AC13 文件：三份 README 的指令一覽加 `dk-kind`、`dk-wave-open` 列補 `--refresh`；`.dkbo/README.md` 疑難排解加一列「新任務一派 reviewer 就跳過某個 kind」→ `dk-kind` 看、`dk-kind up <k>` 解；`PROTOCOL.md`（或 `templates/state.md` 的註解）寫明 `touched` 必須是清單。`04_docs.bats`／`25_docs_policy.bats` 補斷言守住 run/SKILL.md 的新規範（至少 grep 這五個字串：`hit:`、`dk-kind up`、`未 ack`、`wave-open <N> --refresh`、`請人看`）與三份 README 的 `dk-kind`
- [ ] AC14 版號 0.12.0：`VERSION`、README 安裝段 `VER=v0.12.0`、CHANGELOG 首節 `## 0.12.0 — <日期>` 含 `feat(kinds)` 條目（專案層熔斷、`dk-kind`、`[LIMIT]` 證據、codex 額度式子收窄——並把 0.11.2 的「已知仍未處理」那句標成本版已處理）與其餘每一條變更；`21_version.bats` 首節斷言改成 `feat(kinds)` 且全過
- [ ] AC15 `tests/run.sh` 全綠、`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh` 零警告
- [ ] AC16 （波 2，整枝評議）`dk-kind up <k>` 在 `DK_KIND_DOWN` 只有 `<k>` 時要成功：`DK_KIND_DOWN` 變成空字串、exit 0、process 記 `kind <k> up`（I1：`grep -vx` 無輸出在 pipefail 下讓腳本 exit 1）；34_kind_down 補這一條。併修 Minor：`dk-msg` 驗 touched 時去掉冒號後全部空白再比對空字串或 `[]`（06 補一條 `touched:  []` 合法）；`lib/kinds.sh` 不用 `cmp`；run/SKILL.md 的 `[TIMEOUT]` 條解熔斷改指 `dk-kind up <k>`、波中改 brief 那句補「新加的成員接著 dk-spawn」；CHANGELOG 補正測試條數、agy 無小時格式、refresh 不刪 devdone 的行為；`.dkbo/README.md` 疑難排解那列開頭改「dk-watch 判定撞額度」
- [ ] AC17 （波 3，整枝評議第二輪）`dk-spawn` 刪 `.blocked/wave-$DK_WAVE.devdone` 只在該成員**還沒有** latch `.blocked/wave-$DK_WAVE.<state 名>.done` 時做：新成員、經 `dk-wave-close --agent` 關掉再派的人照刪；`--handoff`／`--resume` 重派已交付的 dev 不刪（I1：否則下一個 tick 推假聚合，0.11.2 基準只推一次）；07 或 09 補一條「已交付的 dev `--handoff` 之後 `dk-watch --once` 不再推聚合」。run/SKILL.md 波中改 brief 那句補「只請原 dev 重做時，`[TASK]` 裡叫他完成後回 `[FIXED]`（聚合不會重推）」並以 25 grep `回 \`[FIXED]\`` 守住（I2）；「送 TASK 前讀未 ack」與「視覺變更先請人看畫面」移出故障段（前者放「每次醒來先做」或「跑一波」、後者放「結案」第 1 步前），與波中改 brief 拆成各自一條。併修 Minor：06 補裸 `touched:` 合法；34 的 codex `Nov 11th … 3:15 PM` 樣本標題改「構造樣本」；10_resume 補專案層熔斷列的斷言；09 補 AC5 三個上限（`hit:` ≤5 行、每行 ≤160 字、`[LIMIT]` 訊息 ≤200 字）；dk-msg 的 `report:` 去掉行尾空白再判，缺 `status`／`touched`／`report` 鍵的錯誤也附正確寫法（AC10「正確寫法長什麼樣」）
- [ ] AC18 （波 4，整枝評議第三輪）`[LIMIT]` 的 `hit:` 行按**字元**截 160（不是位元組）：`dk-watch` 的 hit 截斷不得用 `cut -c`（GNU cut 按位元組，切出半個 UTF-8 字元，真 herdr 拒收非 UTF-8 參數 → `[LIMIT]` 永遠送不到）；`.limit` 的 `hit:` 行、kinds-down 的第一條 hit 與送出的 `[LIMIT]` 訊息都必須是合法 UTF-8，訊息 ≤200 字元；dk-watch 在 `LC_ALL=C` 下被啟動也不得切出半個字元。09 補一條中文命中行（>160 bytes）的斷言：`hit:` 行與訊息皆為合法 UTF-8、字元數在上限內（`tests/stub/herdr` 可比照真 herdr 拒收非 UTF-8 參數）。併修 Minor：dk-resume 在兩波之間（`DK_WAVE` 空）也印專案層熔斷；dk-resume 的「（猜）」統一成 dk-kind 的 `(guess)`；`lib/kinds.sh` 的 codex 解析在目標時間 ≤ 現在時改走 guess。CHANGELOG 0.12.0 的測試條數以本波 wave-close 時實跑為準

## 同波成員
backend-kinds(S) backend-docs(S)
