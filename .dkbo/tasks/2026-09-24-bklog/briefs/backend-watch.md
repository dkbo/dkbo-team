# BACKLOG A–C 清理 — 給 backend-watch 的切片（波 1）
由 dk-wave-open 產生，只讀。完整 brief 在 /home/bal/project/teamflow/.dkbo/tasks/2026-09-24-bklog/brief.md。

## 目標
收掉 BACKLOG A–C 三類共 17 條（request.md 逐字列出）：守望不再誤熔斷工作中的 reviewer、dev／qa 閒置有出口、領導能手動登記額度耗盡、審查能單獨補派、領導的訊息不再五分鐘就放棄、重派已交付的 dev 會重新聚合。
brief 工具：無主測試檔 WARN、切片表格看得懂 `\|`、契約可標波次、`--run` 的 tab 開在人當下所在的 workspace；規範與文件一併補齊，出貨 0.16.0。
不做：BACKLOG D、E 類；testtrust（2026-09-24-testtrust）的範圍；#16 原文提的「`--tier L` 獨立逾時門檻」（AC1 讓 working 的 reviewer 不再熔斷，已涵蓋；且不新增 settings 鍵）。`decisions.md` 由領導追加（計畫階段已加三條），成員不改。

## 全域約束（全文）
**本任務在 testtrust 合併回 master 之後才交棒（`dk-leader bklog --run`）**：兩者都動大量測試檔，base 必須含 testtrust 的否定斷言修正與 `35_test_hygiene.bats`
bash 3.2+；不得使用 bash 4 語法（關聯陣列、${x^^}、declare -A、mapfile）；依賴只有 herdr 0.9.0、git ≥ 2.17、jq ≥ 1.5、flock，不得新增；`date -d`／`date -r` 不得使用（換算時間走 `lib/kinds.sh` 既有的純算術 `dk_ts_minutes`／`dk_epoch_to_local` 手法）
shellcheck 零警告（`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh`）
不新增 settings.env 鍵、不新增 `.task.env` 鍵、不新增 bin（`dk-kind down` 是既有 `dk-kind` 的子指令）、不新增 skill；新測試檔只准 `tests/unit/36_process.bats` 一個
否定斷言一律用 tests/helpers.bash 的 refute_grep（grep 類）或 refute（其他指令），不得寫 `! cmd`；`35_test_hygiene.bats` 會擋
既有測試語意不變：不刪、不放寬；只允許（a）新增斷言，（b）`25_docs_policy.bats` 的「Important4: DK_WORKSPACE 講成任務所屬」那條依 AC11 改成守新語意（人拍板的語意反轉，見 request.md），（c）`04_docs.bats`／`25_docs_policy.bats` 裡斷言被 AC 明文改掉的文件句子的那幾行，改成斷言新句子
`04_docs.bats` 的行數上限不得放寬：`skills/run/SKILL.md` ≤60、`LEADER.md` ≤30、`skills/plan/SKILL.md` ≤25、`PROTOCOL.md` ≤120——補規則要改寫既有段落收進去，不是往下加行
改任何檔之前先 `grep -l <檔名> tests/unit/*.bats`：引用它的測試檔不在你的可改欄、而你的改動會讓它紅，就 `[ESCALATE]`，不要自己改
面向使用者的文案是繁體中文；目標版本 0.16.0
例外：本任務的成員**可以**修改 `.dkbo/` 底下的腳本、模板、規則檔與 skill 文件，以及 `.dkbo/tasks/BACKLOG.md`（PROTOCOL 停止條件「不改 .dkbo/ 規則檔」在本任務不適用；ruling 見 process.md）；但只能改所有權表劃給自己的檔
編輯一律用切片「## 倉庫」段的 worktree 路徑；`$DK_ROOT` 指向主樹，只拿來跑 `dk-msg`，不得當編輯路徑
取紅一律 cp 到獨立目錄或 `git archive <base>` 解到暫存目錄做，不在 worktree 用 `git stash`／`git checkout -- <檔>`（同波四人共用一個 worktree）
領導跑的是主樹的腳本：本任務的新行為（working 不熔斷、閒置逾時、`dk-kind down`、背景送、補派命名、無主測試 WARN）在本任務內一次都不會生效；report 不得宣稱「本波已用到」
已知風險：本任務要改 `dk-watch` 與額度判定、`[TIMEOUT]`／`[LIMIT]` 的字樣，員工畫面必然出現這些字；而且主樹 dk-watch 仍會把工作中的 reviewer 逾時熔斷（#16 本身）。領導收到 `[LIMIT]`／`[TIMEOUT]` 一律先 `herdr agent read` 看畫面與 status 再決定：reviewer `[TIMEOUT]` 而畫面仍在寫 report → `dk-kind up claude` 並記 ruling，不關 pane、繼續等（目前只剩 claude 可用，誤熔斷等於三個 kind 全倒）

## 你的波次
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
| 1 | 實作 | backend-watch | AC1–AC4：dk-watch 的 working 不熔斷與 dev／qa 閒置逾時；`dk-kind down`；`lib/review.sh` 的補派別名與 spawned 名單累加（dk-review、dk-brief-review 共用）。先寫紅測試再實作；編輯一律用 worktree 路徑，不要用 `$DK_ROOT` | M | 09/26/34/20/28 全過；shellcheck 零警告；report 的「## 測試」有紅綠 | 預設 |

## 倉庫
/home/bal/project/teamflow/.worktrees/bklog

## 你的檔案所有權
| 成員 | 可改 | 只讀 |
|---|---|---|
| backend-watch | .dkbo/bin/dk-watch, .dkbo/bin/dk-kind, .dkbo/lib/kinds.sh, .dkbo/lib/review.sh, .dkbo/bin/dk-review, .dkbo/bin/dk-brief-review, tests/stub/**, tests/unit/09_watch.bats, tests/unit/26_watch_events.bats, tests/unit/34_kind_down.bats, tests/unit/20_review.bats, tests/unit/28_brief_review.bats | .dkbo/lib/**, .dkbo/bin/**, tests/helpers.bash |

## 共用契約（全文）
（一列一個契約。擁有者填一個成員短名；消費者填一個或多個、逗號分隔；沒有就填 —。完全沒有契約時只留表頭）
| 契約 | 擁有者 | 消費者 | 形狀／簽名 | 變更流程 |
|---|---|---|---|---|
| dk-kind down 指令 | backend-watch | backend-docs | `dk-kind down <kind> [--until YYYY-MM-DDTHH:MM] [--note <文字>]`；成功印 `kind <k> down until <本地時間>[ (guess)]`；process 行 `kind <k> down (leader) until <本地時間>[ (guess)]`；usage 錯誤 exit 2 | 動它要先 ESCALATE |
| 兩種新的 [TIMEOUT] | backend-watch | backend-docs | `[TIMEOUT] from dk-watch: <agent> 逾時但仍在工作（未熔斷）`（process `timeout <agent> working (no kind down)`）；`[TIMEOUT] from dk-watch: <agent> 閒置 <N> 分鐘未交（state 不是這一輪的 done）`（process `idle <agent> <N>min`） | 動它要先 ESCALATE |
| 審查補派命名 | backend-watch | backend-docs | 同 label 再派：別名跳過最新 `<label> spawned` 行已列的；新 spawned 行＝舊名單＋新派；別名池 `a`–`f`、`p1`–`p6` | 動它要先 ESCALATE |
| 領導訊息背景送 | backend-msg | backend-docs | 領導→員工的 TASK／BUG／DECISION／STOP 當場返回並印 `dk-msg: 改在背景等 <target> 閒下來再送（結果記在 messages.log），你直接往下做`；最終送不到記 `[UNDELIVERED]` 與 process `undelivered <target> [<type>]`；已交付的 dev（只對 group=dev）收到的尾註 `（你已交付過：做完先改寫 state 再回 [FIXED]）` | 動它要先 ESCALATE |
| dev 交付旗標與指派 epoch | backend-watch | backend-msg | `.panes` 第 3 欄＝最後一次**送達**的 TASK／BUG 指派 epoch（dk-msg `redispatch` 寫；背景送時在送達那一刻寫）；`.blocked/<agent>.spawn`＝指派當下 state 的 cksum（dk-spawn 寫，dk-msg 對已交付 dev 重派時改寫）；`.blocked/wave-N.<state 名>.done`＝dev 本波已交付的 latch；`.blocked/wave-N.devdone`＝本波聚合標記（`notified`／`delivered`／`at=<epoch>` 行）；`.blocked/<agent>.idle`＝閒置逾時已推，存當時的 `.panes` 第 3 欄 | 動它要先 ESCALATE |
| minor 行格式 | backend-msg | backend-docs | `dk-process` 拒收以 `minor ` 或 `minor:` 開頭但不合 `DK_MINOR_RE` 本文部分的行，exit 2，stderr 以 `dk-process: minor 行格式不符` 開頭 | 動它要先 ESCALATE |
| --run 的 workspace | backend-brief | backend-docs | tab 開在 `HERDR_WORKSPACE_ID`（空才用 `DK_WORKSPACE`）；不同時回寫 `DK_WORKSPACE`、process `workspace <舊> → <新>（--run 開在當下所在的 workspace）` | 動它要先 ESCALATE |
| 契約欄的波次寫法 | backend-brief | backend-docs | 擁有者／消費者欄 `<成員>` 或 `<成員>@波<N>` 或 `—` | 動它要先 ESCALATE |
| state 行數規則 | backend-brief | backend-docs | `touched:` 底下以 `  - ` 開頭的連續行不計，其餘 ≤20 行；超過時 wave-close 印 `dk-wave-close: state too long: <檔>`（只警告） | 動它要先 ESCALATE |

## 驗收標準（全文）
- [ ] AC1 （#16）reviewer 逾時時若 `agent_status` 是 `working`：不寫 `DK_KIND_DOWN`、不寫專案層 kinds-down、不記 `timeout … kind … down`；改推一次 `[TIMEOUT] from dk-watch: <agent> 逾時但仍在工作（未熔斷）`、process 記 `timeout <agent> working (no kind down)`，同一輪只推一次。之後它不再 working 且這一輪仍未交，才走既有的逾時熔斷路徑。`agent_status` 拿不到（不在名單、herdr 失敗）照既有行為。09 或 26 補三條：working 不熔斷且只推一次、轉 idle 後照常熔斷、status 未知照常熔斷
- [ ] AC2 （#10）dev 與 qa 的閒置逾時：`.panes` 裡 group=dev 的成員與 group=review 但名字不是 reviewer 的成員（qa），距計時起點超過 `DK_REVIEW_TIMEOUT_MIN` 分鐘（刻意沿用 reviewer 的門檻：只算 idle／done 的閒置，不算工作中，所以不需要比 reviewer 長）、`agent_status` 為 `idle` 或 `done`、且這一輪還沒交（dev 用 `dev_delivered` 同一個判準；qa 用 reviewer 逾時路徑同一個 state＋`.redispatch` 判準）→ 推 `[TIMEOUT] from dk-watch: <agent> 閒置 <N> 分鐘未交（state 不是這一輪的 done）`，process 記 `idle <agent> <N>min`；**永不熔斷 kind**。標記 `.blocked/<agent>.idle` 存當時的 `.panes` epoch，同一個 epoch 只推一次；epoch 變了（被重新指派）自動重新武裝，不需要 dk-msg 配合。working、blocked、reviewer 都不走這條。計時起點：dev＝`.panes` 第 3 欄（最後一次送達指派的 epoch）；qa＝`max(.panes 第 3 欄, 本波聚合的時間)`，本波還沒推過聚合就不計時——qa 與 dev 同時 spawn、開工後正常閒置等 dev 的 `[DONE]`，不能算閒置未交。為此 `.blocked/wave-N.devdone` 在建立時多寫一行 `at=<epoch>`（不用 mtime）。dev 在交接波等夥伴 `[DONE]` 時也可能觸發，這是預期內的提醒（run SKILL 寫明）。測試補：dev 未全員完成時 qa 閒置超過門檻不推、聚合後超過門檻才推、同一 epoch 只推一次、重新指派後重新武裝。改 dk-watch 前先 `grep -ln 'dk-watch --once' tests/unit/*.bats`：06（backend-msg 的檔）的 fixture 若因這條多推 `[TIMEOUT]` 而紅，對 backend-msg 送 QUESTION，不要自己改 06
- [ ] AC3 （#25）`dk-kind down <kind> [--until YYYY-MM-DDTHH:MM] [--note <文字>]`：未知 kind exit 2；`--until` 以本地時間解析成 epoch（純算術，不用 `date -d`），格式錯或已過去 exit 2；給 `--until` 標 `exact`，沒給用現在＋5 小時標 `guess`；經 `dk_kinds_down_set` 寫一列（來源任務＝綁著的任務目錄名、沒綁寫 `-`；agent 寫 `leader`；hit 寫 `--note` 的值，沒給寫 `leader 人工登記`），同 kind 已有未過期列時照既有「取較晚」語意；綁著任務時同時把 kind 加進 `DK_KIND_DOWN`（與 `up` 對稱，已在就不重複）；process 記 `kind <k> down (leader) until <本地時間>[ (guess)]`，stdout 印 `kind <k> down until <本地時間>[ (guess)]`。usage 列出三個子指令。34 補：exact／guess、過去時間拒絕、未知 kind、寫入後 `dk-kind status` 與 `dk_review_kinds` 都跳過它、綁任務時 `DK_KIND_DOWN` 有它
- [ ] AC4 （#26）審查補派：`dk-review` 與 `dk-brief-review` 在同一個 label（`review <N>`／`review task`／`brief-review`）已有 `<label> spawned` 行時，新派的 reviewer 別名跳過最新那一行已列出的別名（別名池擴成 `a`–`f` 與 `p1`–`p6`），新的 spawned 行＝上一行的名單＋這次新派的，讓 `dk-wave-close` 與 `dk-task-new --gate1`（都只讀最後一行）看到完整名單。不得關掉或重派已在的 reviewer。20／28 各補：第一次 `--kinds claude` 之後再 `--kinds agy` → 新的是 b／p2、spawned 行兩位都在、第一位的 pane 沒被 close
- [ ] AC5 （#14）領導送給員工的 `[TASK]`／`[BUG]`／`[DECISION]`／`[STOP]` 一律改背景送（同 0.15.0 dev→qa 那條的機制）：dk-msg 當場返回並印 `dk-msg: 改在背景等 <target> 閒下來再送（結果記在 messages.log），你直接往下做`；背景那一份最多等 30 分鐘（重試次數×單次等待合計 ≥ 30 分鐘，可被既有 `DK_MSG_TRIES`／`DK_MSG_WAIT_MS` 覆寫），送達才做 `redispatch`；最終送不到照舊記 `[UNDELIVERED]`，並另記 process `undelivered <target> [<type>]`（`dk-resume` 的 process 尾段印得出這一行）。同一個收件者同時排著多則背景訊息時，依收件者用 flock 序列化、照送出順序（FIFO）逐則送。領導送給領導、雜務、員工之間互傳的行為不變。06 補：前景立即返回、送達後才 redispatch、最終失敗記 process、同一收件者兩則背景訊息照順序送達
- [ ] AC6 （#23、#3）`redispatch` 的對象是 `.panes` 裡 group=dev 且 `DK_WAVE` 開著時：刪 `.blocked/wave-$DK_WAVE.<state 名>.done` 與 `.blocked/wave-$DK_WAVE.devdone`，並把 `.blocked/<agent>.spawn` 改寫成此刻 state 的 cksum——聚合從此要等他改寫 state 為 done 才會再推，不會因為上一輪留下的 done 當場誤推。送達當下對方是 group=dev 且 state 已是 `status: done` 時（只對 dev；qa、reviewer 不附），送出的訊息尾端附 `（你已交付過：做完先改寫 state 再回 [FIXED]）`（整則仍 ≤200 字元的限制照舊只套在領導打的本文）。06 補：已交付 dev 被 `[TASK]` 後 `dk-watch --once` 不推聚合、改寫 state 為 done 後推一次；尾註出現與不出現各一條
- [ ] AC7 （#24）`dk-process` 收到以 `minor ` 或 `minor:` 開頭、但不合 `lib/common.sh` 的 `DK_MINOR_RE` 本文部分（`minor(: \| [0-9]+: )`，沿用同一個變數，不另寫一份正規式）的行：不寫入，stderr 印 `dk-process: minor 行格式不符（要 "minor: …" 或 "minor <波號>: …"），整枝評議讀不到這種行`，exit 2。其餘行為不變。`36_process.bats`：`minor task: x` 拒收且 process.md 沒多一行；`minor: x`、`minor 2: x` 與一般行照收；`minority report` 不是 minor 行（不以 `minor ` 或 `minor:` 開頭），照收
- [ ] AC8 （#15）`dk-brief-check` 加 WARN：每位成員可改欄裡**不含萬用字元**、且不是 `.md` 的路徑，取檔名（basename）在 `git ls-files` 的測試檔（檔名符合 `*.bats`、`*_test.*`、`*.test.*`、`*.spec.*`；排除 `.dkbo/tasks/**` 與 `*.log`、`*.md`、`*.txt`）裡 `grep -lF`；命中的測試檔不在任何成員可改欄（用既有的所有權比對函式）→ 每個無主測試檔一條 `WARN 所有權: <測試檔> 引用了 <檔名>[, <檔名>…]（<成員>…的可改檔），但沒人擁有它（改行為時斷言舊行為的測試會紅）`。多 repo 時各 repo 在自己的 ls-files 裡找、路徑帶 `<名>:`。只 WARN 不 FAIL。16 補：命中且無人擁有→WARN、有人擁有→無 WARN、glob 路徑不觸發、`.md` 來源不觸發。report 附：拿本任務 brief.md（定案版）跑的 WARN 清單，應與領導關卡①前的模擬一致（見 process.md 的 `note: AC8 模擬`），不同就說明差在哪
- [ ] AC9 （#5）`dk-wave-open` 產切片的波次表列與所有權列不再對 `dk_brief_*` 的輸出用裸 `awk -F'|'`：改成看得懂 `\|` 跳脫的切法（`lib/brief.sh` 提供一個共用函式），「做什麼」欄寫 `a\|b` 時切片那一列仍是 7 欄且保留 `a\|b`。`dk-brief-check` 同時加欄數閘：所有權表每列 3 或 4 欄（獨佔資源選填，相容 0.9.x 格式與 `tests/helpers.bash` 的 `fixture_brief`、`templates/brief-member.md` 的 3 欄表頭）、波次表每列固定 7 欄（跳脫的 `\|` 不算分隔），否則 FAIL 並指出哪一列。18、16、15 各補對應斷言
- [ ] AC10 （#4）共用契約的擁有者、消費者欄可寫 `<成員>@波<N>`：`dk-brief-check` 驗成員在所有權表、`<N>` 是波次表裡存在的波號、且該成員在第 N 波有列，任一不符 FAIL 並指出；不帶 `@` 的寫法與 `—` 行為不變。`templates/brief.md` 共用契約段的說明句補上這個寫法。16 補：合法、成員不存在、波號不存在、成員不在該波各一條
- [ ] AC11 （#17）`dk-leader <short> --run` 的 tab 開在**人當下所在的 workspace**：`HERDR_WORKSPACE_ID` 非空就用它，空才退回 `.task.env` 的 `DK_WORKSPACE`；兩者皆非空且不同時回寫 `DK_WORKSPACE` 為當下值、process 記 `workspace <舊> → <新>（--run 開在當下所在的 workspace）`、stdout 印一行同義提示；兩者皆空照舊 die。`dk-leader` 裡描述舊語意的註解（「開在任務所屬的 workspace（DK_WORKSPACE，計畫時記下…）」那段）與 `13_leader.bats` 的對應註解一併改。13 補：不同時回寫並記 process、`HERDR_WORKSPACE_ID` 空時退回、相同時不記
- [ ] AC12 （#9）state 行數：PROTOCOL 的 state 檔規則改成「`touched:` 底下的清單項以外 ≤20 行」；`dk-wave-close` 的 `state too long` 警告照同一規則算（`touched:` 之後以 `  - ` 開頭的連續行不計）；員工首段提示（`lib/prompt.sh` 的「你的 state 檔是 …（≤20 行…）」）同步改成「`touched` 清單以外 ≤20 行」。08 補：`touched` 24 項＋其他 10 行不警告、其他 21 行警告
- [ ] AC13 （#20）`templates/brief-member.md` 的「## 倉庫」段在 `/home/bal/project/teamflow/.worktrees/bklog` 之後加一行：`編輯一律用上面的 worktree 路徑；$DK_ROOT 指向主樹的 .dkbo/，只拿來跑 dk-msg 等 bin，不得當編輯路徑`；15 或 18 斷言切片含這一句
- [ ] AC14 （#21、#2）`PROTOCOL.md`：測試那條（或 report 段）補「取紅（證明新測試會紅）一律 cp 到獨立目錄或 `git archive <base>` 解到暫存目錄做，不在共用 worktree 用 `git stash`／`git checkout -- <檔>`：夥伴並跑的測試會讀到舊碼而假紅，stash 堆疊也跨 worktree 共用」；`templates/report-employee.md` 的 `## 測試` 說明同義一句；雜務段的逐字字串 `dk-msg leader "[DONE] <一句結果>"` 在 PROTOCOL.md 只出現一次（刪重複，語意不減；reviewer 專節的 `dk-msg leader "[DONE] review 波 N…"` 不算、不動）；AC12 的 state 行數規則同步。25 補斷言守住取紅那句與 `[DONE]` 句只出現一次
- [ ] AC15 （#25、#26、#10、#16、#14）領導規範：`LEADER.md` 或 plan／run 的 SKILL.md 寫明「派 reviewer 或員工前先 `dk-kind`；任何來源確認某 kind 額度耗盡（畫面、CLI 狀態列、前一個任務的 ruling、人告知），當下 `dk-kind down <k> [--until …]`，不能只寫在 ruling 裡」；run SKILL 故障段：`[TIMEOUT] … 仍在工作（未熔斷）` 不關 pane、照常等；`[TIMEOUT] … 閒置 N 分鐘未交` 先看 messages.log 是否有它在等的 `[DECISION]`／`[UNDELIVERED]`，再補送或 `--resume`；補派 reviewer 直接再跑 `dk-review --kinds <k>`（會拿下一個別名、名單累加；失敗的那位仍在名單裡，裁定行要寫 `<別名>: skipped (<理由>)`）；領導的 `[TASK]`／`[DECISION]` 已是背景送、送不到會進 process。plan SKILL 的計畫審查補派同理（`dk-brief-review --kinds <k>`）。`[TIMEOUT]` 那條（現在寫「該 kind 已寫進 `DK_KIND_DOWN`」）在 AC1 之後對 working 不成立，必須改寫那一條而不是往下加。25 補斷言守住 `dk-kind down` 那一句
- [ ] AC16 （#12、#17）文件：`README.md`、`README.en.md`、`.dkbo/README.md` 的指令一覽 `dk-kind` 列補 `down`、`dk-task-close` 列補「任務 tab 不自動關（最後一行印 `herdr tab close <id>`）」；三份 README、`LEADER.md`、`.dkbo/PROJECT.md`、run SKILL 裡講 tab 開在「任務所屬的 workspace（計畫時記下）」的句子全部改成「你叫 `/dkbo-run` 當下所在的 workspace」（`git ls-files` 全倉掃、不硬編檔名清單；排除 `.dkbo/tasks/**`、`.dkbo/decisions.md`、`CHANGELOG.md` 裡 0.16.0 以前的節——那些是歷史紀錄，不改寫；`tests/integration/README.md` 的現行說明要改）；`25_docs_policy.bats` 的 Important4 那條改成守新說法，用同一份排除清單（不再出現「計畫時記下」的 tab 位置說法、README 與 `.dkbo/README.md` 含新說法）
- [ ] AC17 版號 0.16.0：`.dkbo/VERSION`、兩份 README 安裝段 `VER=v0.16.0`（`dk-version` 讀 VERSION 檔、沒有寫死版號，不用改）；CHANGELOG 首節 `## 0.16.0 — <日期>` 逐條列出 AC1–AC16 的變更（`feat(watch)`、`feat(kind)`、`feat(review)`、`feat(msg)`、`feat(brief)`、`feat(leader)!`（tab 位置語意反轉）、`docs(protocol)` 等）與測試條數——條數等於**最後一次** wave-close 的 `tests/run.sh` 實跑值：docs 第一輪先寫 `N` 佔位，審查修復收斂後領導對 backend-docs 下 `[TASK] 補測試條數` 再填；`21_version.bats` 首節斷言照改並全過
- [ ] AC18 BACKLOG：刪掉 `.dkbo/tasks/BACKLOG.md` 裡 request.md 列出的 17 列（A–C），其餘每一行一字不動
- [ ] AC19 `tests/run.sh` 全綠（含 testtrust 的 `35_test_hygiene.bats`）、shellcheck 零警告；每位 dev 的 report「## 測試」附自己 AC 的取紅紀錄

## 同波成員
backend-watch(M) backend-msg(M) backend-brief(M) backend-docs(M)
