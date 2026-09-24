# bklog-reviewer-p1 報告（計畫審查）

審查對象：request.md、brief.md（2026-09-24 08:08 版）。另以唯讀 grep 驗證了所有權與測試引用的前提（指令列在文末「## 測試」）。

## 需求覆蓋
request 列的 17 條（A 7、B 6、C 4）與四題回答都有對應 AC，沒有整條漏掉的：
#16→AC1、#25→AC3+AC15、#10→AC2、#14→AC5、#23/#3→AC6、#26→AC4、#20→AC13、#21→AC14、#24→AC7、#9→AC12+AC14、#2→AC14、#12→AC16、#15→AC8、#5→AC9、#4→AC10、#17→AC11+AC16；「testtrust 合併後才交棒」→全域約束第一句；「四位成員並行」→波次表。

**必須改（1 處）**
1. **#9 只修了一半：員工第一眼讀的 spawn 提示仍寫「≤20 行」，而且沒人擁有它。** `.dkbo/lib/prompt.sh:15` 印出「你的 state 檔是 …（≤20 行，每完成一個子步驟就覆寫）」——本 pane 收到的首段提示就是這一句。AC12 只改 PROTOCOL 與 dk-wave-close，那一波動 24 個檔的成員照樣會被提示擋住，而 #9 要解的正是這個衝突。`lib/prompt.sh` 在所有權表只列為只讀（backend-watch/msg/brief 的 `.dkbo/lib/**`）。改法：把 `.dkbo/lib/prompt.sh` 劃給 backend-brief，AC12 補一句「spawn 提示同步改成 `touched` 清單以外 ≤20 行」。（已查：`grep -l prompt.sh tests/unit/*.bats` 沒有命中，不會連帶讓測試變紅。）

其他（非必改）：
- #16 原文另外提到「L 檔整枝評議讀 task.diff 本來就會超過 20 分鐘，`--tier L` 應該有獨立（較長）的門檻」，brief 沒接，全域約束「不新增 settings.env 鍵」也等於排除了它。AC1 做完之後 working 不熔斷，這條多半變得不需要；但建議在「目標／不做」寫明「L 檔獨立門檻不做（AC1 已涵蓋）」，免得有人以為漏了。
- #10 原文建議「門檻可比 reviewer 長」，AC2 直接沿用 `DK_REVIEW_TIMEOUT_MIN`（20）。只算 idle／done 狀態的話這樣說得通，但要當成刻意的選擇寫進 AC2。

## 驗收標準可驗證性
**必須改（3 處）**
2. **AC2 的 qa 閒置逾時在正常流程裡每一波都會誤報。** run SKILL 第 22 行是「先派 dev 再派 qa」，qa 與 dev 同時 spawn，qa 開工後就閒置等 dev 的 `[DONE]`（PROTOCOL：「qa 本來就會看你的 state 開工，這一則是給停下來等的 qa 的叫醒訊號」）；而 dev→qa 的 `[DONE]` 不觸發 redispatch（`dk-msg:183` 只有 TASK／BUG 才會），所以 `.panes` 的 epoch 不會更新。結果是：dev 寫超過 20 分鐘，qa 就會被推 `[TIMEOUT] … 閒置 N 分鐘未交`，領導照 AC15 去翻 messages.log，而這其實是 qa 在正常等人。dev 在 dev→dev 交接波等夥伴時也一樣。可驗證的改寫：qa 的計時起點改成 `max(.panes epoch, .blocked/wave-$DK_WAVE.devdone 的時間)`，devdone 還不存在就不計時；dev 維持原樣。測試補一條「dev 未全員完成時，qa 閒置 >門檻也不推」。
3. **AC8 的「測試檔」定義與「basename 比對」在本倉會產生數百條 WARN，這條 WARN 等於沒用。** `git ls-files` 裡符合 AC8 定義的檔包括 `.dkbo/tasks/*/waves/*.test.log`（歸檔任務的測試紀錄，21 個）、`tests/fixtures/*`、`tests/e2e/RESULTS-*.md`、`tests/integration/README.md` 等。basename 又含 `brief.md`、`README.md`、`VERSION` 這類幾乎每個 fixture 都有的名字。我把本 brief 的可改欄拿去照 AC8 模擬：**約 348 條 WARN**（光 `brief.md` 就命中 11_chore、12_task_close、22_ownership、27_qa_gate……這些都是 fixture 自己的 brief.md，不是 `templates/brief.md`）。可驗證的改寫：(a) 測試檔排除 `.dkbo/tasks/**` 與非程式檔（`*.log`、`*.md`），或直接限定成 `*.bats` 加上 `*_test.*`／`*.test.*`／`*.spec.*` 中的程式副檔名；(b) 被比對的來源照 BACKLOG 原案，限可改欄裡的程式檔（`bin/`、`lib/` 底下，或有執行權限的檔），不含 `.md`；(c) 加一條吃自己狗糧的斷言：「拿本任務的 brief.md 跑 dk-brief-check，WARN 恰好是 {03_kinds, 05_task_new, 07_spawn, …} 這幾個」或「≤ N 條」，當成 AC8 過不過的判準。
4. **AC9 的欄數閘會打壞共用 fixture，而那個 fixture 沒人擁有。** `tests/helpers.bash:147` 的 `fixture_brief`（註解寫明是「a brief that passes dk-brief-check」）所有權表只有 **3 欄**（`| 成員 | 可改 | 只讀 |`），`.dkbo/templates/brief-member.md:19` 的表頭也是 3 欄。「每列必須 4 欄，否則 FAIL」會讓所有靠這個 fixture 通過 dk-brief-check 的測試（16、18、28……）全紅，而 `tests/helpers.bash` 在四位成員的欄裡都只是只讀。可驗證的改寫：所有權表接受 **3 或 4 欄**（獨佔資源選填，相容 0.9.x 格式），波次表固定 7 欄；或者把 `tests/helpers.bash` 劃給 backend-brief，並准許在全域約束 (c) 裡改 fixture。前者成本低、也不會讓舊 brief 失效，建議選前者。

## 檔案所有權
**必須改（1 處）**
5. **AC16 的「git ls-files 全倉掃」會掃到不該改或沒人擁有的檔。** 以下是 `git grep` 舊說法（「任務所屬的 workspace」「計畫時記下」「task's workspace」）的命中結果，排除 `.dkbo/tasks/**` 之後：
   - `CHANGELOG.md:64`：0.11.0 的歷史條目，不該改寫歷史；但「不再出現計畫時記下的 tab 位置說法」這條全倉斷言一定會打到它。
   - `.dkbo/decisions.md:24`：2026-09-22 的決策紀錄。沒人擁有，而且它是歷史，應該用追加新決策的方式處理，不是改寫。
   - `tests/integration/README.md:202,206`：現行說明，應該改，但**沒人擁有**。
   - `.dkbo/bin/dk-leader:146` 的註解與 `tests/unit/13_leader.bats:51` 的註解：屬 backend-brief，AC11 沒提到要改，建議明寫。

   改法：AC16 寫明掃描範圍，排除 `.dkbo/tasks/**`、`CHANGELOG.md` 0.16.0 以前的節、`.dkbo/decisions.md`；25 的新斷言用同一份排除清單。`tests/integration/README.md` 劃給 backend-docs。decisions.md 的新決策由領導在結案時追加。

非必改的觀察：
- 已照全域約束「改任何檔之前先 grep -l」替每位成員先跑過一次，被引用、但不在任何人可改欄的測試檔如下：`03_kinds`（dk-watch、kinds.sh）、`05_task_new`（dk-watch、dk-msg、dk-process、dk-leader、dk-wave-close）、`07_spawn`（dk-kind、dk-wave-open、report-employee.md）、`10_resume`（kinds.sh、dk-leader、BACKLOG.md）、`11_chore`（dk-msg、PROTOCOL.md）、`12_task_close`、`22_ownership`（dk-wave-close、dk-wave-open）、`19_review_pack`、`29_constraints`（dk-review、dk-brief-review、dk-wave-open）、`23_leader_kind`、`30_isolation`（dk-leader、dk-process）、`27_qa_gate`（brief.sh）、`01_common`、`14_install`、`24_portability`、`31_methods`、`32_timeline`。我抽查了風險最高的幾個：`30_isolation` 跑 `dk-leader login --run`，但 helpers 設的 `HERDR_WORKSPACE_ID=wB` 與 fixture 的 `DK_WORKSPACE="wB"` 相同，AC11 不會改變它的行為；`11_chore:390` 只斷言雜務段含「共用」與「ESCALATE」，AC14 去重不會打到；`03_kinds`／`05_task_new` 沒有跑 `dk-watch --once`。看起來都不需要重劃，但 `22_ownership`（dk-wave-close 的 state 行數算法）與 `29_constraints`（dk-review／dk-brief-review 的輸出）我沒有逐條看，建議領導在開工前各花一分鐘確認。
- 獨佔資源欄全部填「—」，合理：四人共用一個 worktree，但測試都跑在各自的暫存目錄。
- `tests/stub/**` 只歸 backend-watch。AC5 的「背景等 30 分鐘、最終失敗」測試如果要 stub 支援新形狀（例如前 N 次 `agent wait` 失敗、之後成功），backend-msg 得跨人請求。06:62 已經在數 `agent wait` 的次數，現有 stub 可能夠用，只是提醒一下。

## 波次切法
**必須改（2 處）**
6. **backend-docs 要等另外三位的產出，卻沒有收到通知的管道。** 波次表 docs 列寫「測試條數等其他三位 `[DONE]` 後在 worktree 跑 `tests/run.sh` 取實跑值」，但三位 dev 的切片只叫他們 `dk-msg leader`，而 dev 給領導的 `[DONE]` 只落盤、不送達任何人。docs 只能輪詢別人的 state，或乾等（結案後的新版 AC2 在這種情況也會誤報）。另外，實作波審查的 Important 修掉之後測試條數還會再變，docs 在第一輪取的值必然過時，而 AC17 又要求「以 wave-close 時實跑值為準」。可驗證的改寫擇一：(a) 另外三列的「做什麼」補「完成後也 `dk-msg backend-docs "[DONE] …"`」（dev→dev 本來就前景送）；(b) 把 CHANGELOG 的測試條數從 docs 第一輪的完成條件拿掉，改成領導在審查修復收斂後對 docs 下 `[TASK] 補測試條數`，AC17 寫成「等於最後一次 wave-close 的 `tests/run.sh` 實跑值」。建議 (b)，因為 (a) 解決不了修復後條數會變的問題。
7. **「`.blocked/` 的交付旗標與 `.panes` epoch」是兩位成員之間的共用介面，契約表卻沒有這一列。** AC6 由 backend-msg 在 dk-msg 裡刪 `.blocked/wave-N.<s>.done`、`.blocked/wave-N.devdone`，並改寫 `.blocked/<agent>.spawn`；讀這些檔的 `dev_delivered`（`dk-watch:210`）歸 backend-watch。backend-watch 同一波還要新增 `.blocked/<agent>.idle`，並以 `.panes` 第 3 欄 epoch 判斷是否重新武裝，而 epoch 是 dk-msg 的 `redispatch` 在更新的；AC5 還把這次更新延到背景送達的那一刻。兩人同時改 dk-watch 與 dk-msg，任何一方調整這些檔的語意，另一方都會默默壞掉。改法：契約表加一列「dev 交付旗標與指派 epoch」，擁有者 backend-watch，消費者 backend-msg，形狀寫明 `.spawn`＝指派當下 state 的 cksum、latch／devdone 的路徑、`.panes` 第 3 欄＝最後一次送達指派的 epoch、`.idle` 存 epoch。

非必改的觀察：
- 四人一波、一次審查，順序本身沒問題：四位的檔完全不重疊，文件只依賴契約表的原句。
- 已查 dk-wave-open 會把「## 共用契約」整段抄進切片、不做過濾，所以 AC10 的 `@波N` 不需要改 dk-wave-open。

## Minor
- **審查波的熔斷風險建議寫成具體步驟。** 計畫審查只派 claude（codex、agy 已熔斷），實作波審查也只剩 claude。一位 claude L 讀 17 條的差異包，幾乎必定超過 20 分鐘，而主樹的 dk-watch 會照 #16 把 claude 熔斷，等於三個 kind 全倒。全域約束「已知風險」寫了「先 herdr agent read 再決定」，建議再具體一句：「reviewer `[TIMEOUT]` 若畫面仍在寫 report：`dk-kind up claude` 並記 ruling，不關 pane、繼續等」。
- **AC5**：同一個收件者同時排著多則背景訊息（例如先 `[BUG]` 再 `[DECISION]`）時，送達順序與「幾則同時醒來一起送」的行為沒有規定。建議用 flock（既有依賴）依收件者序列化成 FIFO，並補一條測試。另外「dk-resume 讀得到」請改成可以判定的寫法：「`dk-resume` 的 process 尾段印得出 `undelivered <target> [<type>]`」（dk-resume 只印 process 的最後 N 行）。
- **AC6**：尾註「（你已交付過…）」只給 dev 還是給所有收件者？AC6 那句接在「group=dev」後面，契約表卻寫成泛指「已交付者」。請擇一寫明。
- **AC7**：`lib/common.sh:46` 已經有 `DK_MINOR_RE='^[^ ]+ minor(: | [0-9]+: )'`，建議明寫「沿用 `DK_MINOR_RE` 的本文部分，不另寫一份」，免得兩份正規式各自漂移。另外，第一句「以 `minor` 開頭」會包含 `minority`，和後面的測試描述矛盾；觸發條件請直接寫成「以 `minor ` 或 `minor:` 開頭」。
- **AC14**：「`[DONE]` 句只出現一次」請寫出逐字字串 `dk-msg leader "[DONE] <一句結果>"`。PROTOCOL 的 reviewer 專節還有 `dk-msg leader "[DONE] review 波 N…"`，斷言寫太鬆會誤擋。
- **AC4／AC15**：補派之後，失敗的那位仍留在累加的 spawned 名單裡，裁定行要寫 `<別名>: skipped (<理由>)`。dk-wave-close 的 gate a2（`dk-wave-close:52`）與 gate1（`dk-task-new:32`）都已經支援這種寫法，但 run／plan SKILL 的補派句應該順帶講清楚，不然領導會以為補派之後就不用交代那位失敗的。別名池 a–f 仍能被 gate a2 的 `reviewer-[a-z]` 抓到，p1–p6 也能被 gate1 的 `reviewer-p[0-9]+` 抓到，所以讀取端不必改。
- **AC2 對既有 fixture 的影響**：06（歸 backend-msg）、09、26 的 `.panes` fixture 多半把 epoch 寫成 0，而 stub 的 `agent_status` 預設是 idle。只要測試跑了 `dk-watch --once`，AC2 就會立刻多推一則 `[TIMEOUT]`。backend-watch 改的 dk-watch 可能讓 backend-msg 擁有的 06 變紅，建議在 backend-watch 那一列提醒一句「先 grep 有沒有測試在跑 `dk-watch --once`，有影響就對 backend-msg 發 QUESTION」。
- **AC15**：run SKILL 目前 57/60 行，要塞進四個新重點只剩 3 行的餘裕。第 42 行「reviewer `[TIMEOUT]`（該 kind 已寫進 `DK_KIND_DOWN`）」在 AC1 之後對 working 的情況已經不成立，必須改寫這一行，不能只往下加。建議在 docs 列點名第 42 行。
- **AC11**：語意反轉之後，`.dkbo/decisions.md` 應該追加一條新決策，取代 2026-09-22 那條的 workspace 部分。decisions.md 不在成員所有權內，建議在結案步驟寫明由領導追加。
- **AC17**：`dk-version（若有寫死）`請在計畫階段先確認，把「若有」改成確定的句子（可驗證性）。

## 結論
要改 7 處

## 測試
不適用: 計畫審查，沒有程式碼也沒有差異包。只跑了唯讀指令驗證前提：
- `for f in dk-watch … BACKLOG.md; do grep -lF "$f" tests/unit/*.bats; done` → 列出每個被改檔被哪些 bats 引用（整理在「## 檔案所有權」）
- 照 AC8 的定義與本 brief 的可改欄模擬 `git ls-files | grep -E '(test|tests|spec|__tests__)/|\.bats$|_test\.|\.test\.|\.spec\.'` 再 `grep -lF <basename>` → 無人擁有的命中約 348 條
- `grep -rn '^| *成員 *|' tests/ .dkbo/templates` → `tests/helpers.bash:147`、`templates/brief-member.md:19` 是 3 欄
- `git grep -n -e '計畫時記下' -e '任務所屬的 workspace' -e "task's workspace" -- ':!.dkbo/tasks/**'` → 命中清單見第 5 條
- `git grep -n '≤20 行'` → `.dkbo/lib/prompt.sh:15`；`grep -l prompt.sh tests/unit/*.bats` → 無命中
- 讀 `dk-wave-close:40-70`、`dk-task-new:14-40`、`lib/review.sh:1-70`、`dk-msg:146-183`、`dk-watch:153-280`（grep）、`skills/run/SKILL.md`（qa 派法）
