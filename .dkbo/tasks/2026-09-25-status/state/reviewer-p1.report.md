# reviewer-p1 報告 — brief-review（dk-status --json）

## 做了什麼
依序讀 request.md、brief.md，逐條對照需求、AC、所有權、波次表。只讀不改。
為了確認 brief 裡「規則同 X」「經 Y」的前提，唯讀抽查了主樹的 `lib/common.sh`（dk_ts_pick、dk_index_set、dk_minor_count）、
`lib/kinds.sh`（kinds-down 列格式）、`lib/brief.sh`、`lib/repos.sh`（.repos 四欄）、`bin/dk-timeline`、`bin/dk-wave-close`、
`bin/dk-task-close`、`bin/dk-msg`、`bin/dk-spawn`（.panes 六欄）、`tests/helpers.bash`（fixture_task）、`tests/unit/21_version.bats`、
CHANGELOG 0.16.0 節與 git ls-files 的 `@test` 靜態計數。

## 需求覆蓋
request 各段 → brief 對應：
- 第 1–3 則／領導提議「dkbo 倉只放 `dk-status --json`，唯讀，帶 `schema_version`，有自己的測試；dashboard 不直接解析 markdown」→ 目標、AC1、AC2、AC7、AC9 ✅
- 範圍提議「list 摘要」→ AC2 ✅；「`<short>` 詳情：成員、波次、ruling、訊息、閘門事件」→ AC3（members／waves／rulings／messages／events）✅；「用量和逐字稿不做」→ 目標「不做」✅
- 對應表「5 分鐘內有動靜」→ `updated_at` ✅；「進度條」→ `waves_closed`／`waves_planned` ✅（但定義有誤，見可驗證性 ②）；「Repos 欄」→ `repo_names` ✅；「自主裁定要醒目列出」→ `autonomous` 與 `counts.autonomous_rulings` ✅；「messages.log 做成訊息時間軸」→ `messages[]` ✅；「live 用 events.subscribe」→ `panes[].pane` 給 id、ruling 已記 ✅；Ruling／QUESTION／minor 三組 → rulings、messages type=QUESTION、events kind=minor ✅
- 「它沒有、但 dkbo 值得加的」三項：kind 額度 → `kinds_down` ✅；閘門狀態（四道閘）→ 只有 `waves[].tests` 與原文 `events[]`，勉強接住（Minor 建議在 schema 文件點名哪些 events kind 是閘門）

**必改 ①（request「它沒有、但 dkbo 值得加的：所有權（每個成員的 glob 對照實際 diff）」沒被接住）**
brief 給了 `brief.owners`（glob）與 `members[].touched`（自報），但沒有「對照實際 diff」，而目標段的「不做」也沒列它。
dashboard 作者讀 brief／schema 會以為漏做，且 dashboard「只讀這份 JSON」的前提下它自己補不了（要跑 git diff）。
改法二選一，由領導裁定：(a) 目標「不做」加一句「所有權對照實際 diff（需要 git diff 與仍存在的 worktree，結案後 worktree 已刪；dashboard 以 `brief.owners` ＋ `members[].touched` 呈現自報版）」；
(b) 加欄位。我建議 (a)，本任務範圍已經夠大，且 dk-status 唯讀＋不碰 worktree 比較單純。

## 驗收標準可驗證性
- AC1 ✅ 可判定（exit code、stderr 逐字、`jq -c` 單行）。
- AC2 ✅（`dkbo_version` 去不去尾端換行見 Minor）。
- AC3 ✅ 頂層鍵恰為 → 可判定。
- AC4 ⚠️ 見必改 ②③。
- AC5、AC6、AC7 ✅ 可判定（已核對 `setup_project` 會匯出 `HERDR_ENV`／`HERDR_PANE_ID`，測試要自己 unset；`fixture_task` 不呼叫 herdr，stub log 在 dk-status 前後比對可行）。
- AC8 ✅ 可判定（反向防漂移只涵蓋夾具裡真的出現的鍵，見 Minor）。
- AC9 ✅（`fixture_task` 不寫 INDEX 列、日期固定今天，見 Minor）。
- AC10 ⚠️ 見必改 ④。
- AC11 ✅。

**必改 ②（共用契約「任務詳情」的 `waves[]` 與「任務摘要」的 `waves_closed`：規則與 process.md 真實 token 對不上，dev 只能自己猜）**
已讀 `bin/dk-wave-close`：
- 成功行是 `wave-close N tests <tests> K agents closed`，`<tests>` 實際值是 `ok (<cmd>)`、`skipped (no DK_TEST_CMD)`、`failed (<cmd>, forced)`（強關），多 repo 是串起來的 `main ok (…) api skipped (no change)`；
- 未強關的失敗行是 `wave-close N tests failed (<cmd>)`，**不帶 `agents closed`、波沒關**，卻同樣符合 `wave-close N tests`。
後果：
- 契約寫 `"tests":"ok"|"failed"|null`，`skipped` 與多 repo 串沒有對應值；
- `waves_closed` 定義成「有 `wave-close N tests ok` 的不同 N 數」，沒設 `DK_TEST_CMD` 的專案（`tests/helpers.bash` 的夾具就是）永遠 0、強關的波也不算，進度條錯；
- `closed_at` 照 dk-timeline 取「最後一筆 `wave-close N tests`」，未強關的失敗行也會被當成關了；
- `commit` 沒給解析規則：真實行是 `commit <sha> wave N`、多 repo 是 `commit <sha> wave N repo <名>`（一波多行），另有 `commit failed wave N`（第 3 欄是 `failed` 不是 sha）；`str|null` 裝不下多 repo；
- `review_verdict` 沒寫取哪一段（真實行 `review N verdict a: ok（…）`，另有 `review N skipped: …`）。
可驗證改寫（建議）：「波 N 算關閉 ⟺ 存在 `wave-close N tests … agents closed` 行；`closed_at` 取最後一筆這種行；`tests` 取該行 `tests ` 與 ` K agents closed` 之間的原文（str|null），另加 `tests_ok`：bool\|null＝原文不含 `failed`；`waves_closed`＝關閉的不同 N 數；`commits:[{"repo":str\|null,"sha":str}]` 取 `commit <sha> wave N[ repo <名>]`、略過 `commit failed`；`review_verdict` 取最後一筆 `review N verdict` 行 `verdict ` 之後的原文，沒有而有 `review N skipped:` 時給 `"skipped: …"` 原文」。改的是共用契約，所以要領導在開工前定稿。

**必改 ③（共用契約「任務摘要」與 `members[]` 有欄位沒寫來源）**
- `current_wave`：取 `.task.env` 的 `DK_WAVE`（wave-close 會清空）還是「最後一個 wave-open 且未關」？沒寫。
- `counts.undelivered`：`dk-msg` 在領導送不到時**同時**寫 messages 的 `[UNDELIVERED]` 與 process 的 `undelivered <target> [TYPE]`；取哪一邊沒寫，兩邊數字不一定相等（員工送不到只寫 messages）。
- `counts.escalations`：應是 messages 的 type=ESCALATE，沒寫。
- `created_at`：第一筆 `task-new`（dk-timeline 用的是第一筆，不是 dk_ts_pick 的最後一筆）；`gate1_at`：最後一筆 `gate1 approved`？沒寫。
- `closed_at`／`close_result`：`task-close merge-failed …` 與 `task-close local-changes:…` 也是 task-close 行，但任務其實沒結（INDEX 仍 running），要不要算？
- `members[].notes`：PROTOCOL 允許 notes ≤5 行，續行怎麼接（以換行串接？只取第一行？）沒寫；`wave` 非整數時給 null？
可驗證改寫：在「任務摘要」形狀欄每個沒標來源的欄位後補括號來源，照上面每條給一個明確規則（我的建議：`current_wave`＝`DK_WAVE` 空則 null；`undelivered`＝messages type=UNDELIVERED 列數；`escalations`＝messages type=ESCALATE 列數；`created_at`＝第一筆 task-new；`gate1_at`＝最後一筆 `gate1 approved`；`closed_at`／`close_result` 只認 `merged`／`in-tree`／`abandoned:` 三種；`notes` 取同鍵後續縮排行以 `\n` 串接）。

**必改 ④（AC10「增量＝實跑值 − 757」的基準數字與事實不符）**
CHANGELOG 0.16.0 節（HEAD＝ff05db2）寫的是 `756 bats`，`git ls-files tests | xargs grep -c '^@test'` 靜態計數也是 756。
照 757 算，增量會少 1，而 21_version 只檢查格式、擋不住。改法：把 757 改成 756，或改寫成「增量＝實跑值 − base（`git archive <base>` 解到暫存目錄跑 `tests/run.sh`）的實跑值」。

## 檔案所有權
- 兩位成員可改欄不重疊 ✅；AC1–AC9 要動的三個新檔都在 backend-status，AC10 的六個檔都在 backend-docs ✅；新增檔上限三個與所有權一致 ✅。
- 已核對：既有測試裡只有 `37_shellcheck` 會列舉 `bin/*`，新 bin 不會讓其他測試意外紅；三份 README 八處版號（2＋2＋4）與 21 的「總數 8」相符 ✅。
- 獨佔資源留空合理：兩人共用 worktree，但全套測試只由 backend-docs 在 backend-status 完成後跑一次 ✅。
- 沒有必改。

## 波次切法
- 單波、兩人並行、`dk-status` 在三份 README 出現那條由 backend-status 寫測試、可暫紅，已在完成條件標明 ✅；共用契約四列擁有者都是 backend-status ✅。
- backend-docs 的條目「照共用契約逐字」，不必等 backend-status 的實作，只有測試條數要等 → 同波合理 ✅。

**必改 ⑤（波次表第 1 波 backend-docs 列＋全域約束最後一條：只在 `[DONE]` 時交棒，審查修復後條數會過期）**
reviewer 的 Important 轉成 `[BUG]` 給 backend-status 後，修復多半會在 38 補測試 → 全套條數變了，但 backend-docs 已經填完送 `[DONE]`，
brief 沒寫誰負責重跑、重填 CHANGELOG；21_version 只驗格式，這個錯會安靜地過 wave-close。
改法：全域約束那條補「backend-status 的 `[FIXED]` 也要前景送一則給 backend-docs；backend-docs 收到就重跑完整 `tests/run.sh`、更新 CHANGELOG 條數，再回 `[FIXED]` 給 leader」。

## Minor
1. AC1「資料夾名解析規則同 dk-timeline」：dk-timeline 用 `[ -d "$DK_ROOT/tasks/$t" ]`，`_chores`、`.`、`..` 都會被當成任務資料夾而 exit 0；與 AC2 排除 `_chores`、目標「不做雜務」不一致。建議 AC1 補「資料夾名必須符合 `YYYY-MM-DD-<短名>`，否則視為找不到（exit 1）」。
2. AC1 沒寫多餘位置參數（`--json a b`）與 `--json` 放在任務後面的行為；建議併入 exit 2。
3. AC2 `dkbo_version`：VERSION 檔內容是 `0.16.0\n`，建議寫明「去掉空白與換行」（同 21_version 的 `tr -d '[:space:]'`）。
4. AC9：`fixture_task` 不寫 INDEX 列、資料夾日期固定是今天。要驗 `status` 為 done／running 需手動 append INDEX 列；要驗「短名取日期最晚」需手工再建一個舊日期的同短名資料夾。建議在 AC9 點明，免得 dev 以為 fixture 會處理。
5. AC8 反向防漂移只看夾具輸出**實際出現**的鍵，空陣列裡的物件鍵（如夾具沒有 ACK 訊息、沒有 blocked_by）不會被檢查。建議 AC9 的夾具要求每個陣列至少一個元素（repos、brief.owners、waves、members、panes、rulings、events、messages、kinds_down）。
6. `.panes` 有 legacy 兩欄格式（dk-wave-close 有處理），契約的 `group`／`tab`／`slot` 沒寫可否 null；建議都標 `str|null`／`int|null`。
7. 全域約束「不看 session 綁定（`.sessions/<pane>`）」與 AC2「經 `dk_kinds_down_rows`」（讀 `.sessions/kinds-down`）字面上可能讓 dev 猶豫；建議補半句「讀 `.sessions/kinds-down` 是允許的」。
8. `kinds_down[].until` 經 `dk_epoch_to_local` 是**跑 dk-status 那台機器**的本地時間；dashboard 後端若在不同時區應改用 `until_epoch`，schema 文件值得寫一句。
9. messages 內文若含換行，續行沒有時間戳會被算進 `skipped_lines.messages`；是可接受的行為，schema 文件寫一句即可。
10. 閘門：`dk-wave-close` 的 `violation unowned: …`、`unreported … (owner …)`、`wave-close N tests failed …` 都會進 `events[]`；建議 status-schema.md 點名這幾個 `kind`，dashboard 才知道去哪找四道閘的結果（對應 request「閘門狀態」）。
11. backend-docs 完成條件只列 04／21／25／32，但 09、11、12、14、23、24 也 grep README／CHANGELOG；全套本來就會跑，只是完成條件可寫「全套綠」即可，不必列號。
12. 「list 模式不得逐行呼叫 jq」沒有對應測試；若要守，可在 38 用 PATH 前置一個計數 jq 包裝，驗 N 個任務的呼叫次數 ≤ 固定常數 × N。

## 結論
要改 5 處

## 測試
本切片是計畫審查，不跑專案測試。唯讀核對前提用到的指令：
- `grep -n "^dk_..." .dkbo/lib/*.sh`：確認 dk_ts_pick、dk_index_set、dk_minor_count、dk_kinds_down_rows、dk_epoch_to_local、lib/brief.sh 讀取函式都存在。
- 讀 `dk-wave-close` 第 111–215 行：tests 值有 ok／skipped／failed(forced)／多 repo 串，commit 行帶 ` repo <名>` 後綴（必改 ②的依據）。
- `git ls-files tests | grep '\.bats$' | xargs grep -c '^@test'` → 756；CHANGELOG 0.16.0 節 `756 bats`（必改 ④的依據）。
- `grep -c 0.16.0` 三份 README → 2＋2＋4＝8（與 21 相符）。

## 自我審查
每條必改都指名了 brief 的段落或波次表列，並附可驗證的改寫；前提都讀過程式確認，不是憑印象。

## 疑慮
必改 ①我建議選「列入不做」，但那是範圍決策，由領導裁定；若選加欄位，要多一條 AC 與夾具。
