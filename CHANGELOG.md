# Changelog

## 0.16.0 — 2026-09-24

- feat(watch): reviewer 逾時時若 `agent_status` 仍是 `working`，不再熔斷它的 kind（不寫 `DK_KIND_DOWN`、不寫專案層 kinds-down），改推一次 `[TIMEOUT] from dk-watch: <agent> 逾時但仍在工作（未熔斷）`、process 記 `timeout <agent> working (no kind down)`，同一輪只推一次；它不再 working 且仍未交，才走既有的逾時熔斷；`agent_status` 拿不到照舊熔斷。依據：tasktab 整枝評議時 claude L 檔 reviewer 正在寫 report 就被判逾時，codex 與 agy 已先熔斷，一下子三個 kind 全倒。
- feat(watch): dev 與 qa 新增閒置逾時：`agent_status` 為 idle／done、這一輪還沒交、距計時起點超過 `DK_REVIEW_TIMEOUT_MIN` 分鐘，推 `[TIMEOUT] from dk-watch: <agent> 閒置 <N> 分鐘未交（state 不是這一輪的 done）`、process 記 `idle <agent> <N>min`，**永不熔斷 kind**。計時起點 dev 是最後一次送達指派的 epoch（`.panes` 第 3 欄），qa 是它與本波 dev 聚合時間（`.blocked/wave-N.devdone` 新增的 `at=<epoch>` 行）的較晚者，聚合前不計時。`.blocked/<agent>.idle` 記當時的 epoch，同一次指派只推一次，重新指派自動重新武裝。working、blocked 與 reviewer 不走這條。
- feat(kind): `dk-kind down <kind> [--until YYYY-MM-DDTHH:MM] [--note <文字>]`——領導從畫面、CLI 狀態列、前一個任務的 ruling 或人告知確認額度耗盡時手動登記專案層熔斷。`--until` 以本地時間純算術解析（標 exact），沒給就現在＋5 小時（標 guess）；經 `dk_kinds_down_set` 寫一列（agent 寫 `leader`），綁著任務時同時加進 `DK_KIND_DOWN`；process 記 `kind <k> down (leader) until <本地時間>[ (guess)]`，stdout 印 `kind <k> down until <本地時間>[ (guess)]`。未知 kind、格式錯或已過去的時間 exit 2。依據：ops 的 ruling 已寫明 codex 要到 Oct 11 才恢復，但沒有寫入路徑，testtrust 的計畫審查照樣派了 codex 與 agy、各白燒一個 pane。
- feat(review): `dk-review` 與 `dk-brief-review` 可以只補派一位：同一個 label 已有 `<label> spawned` 行時，新 reviewer 的別名跳過最新那一行已列的（別名池擴成 `a`–`f` 與 `p1`–`p6`），新的 spawned 行＝上一行的名單＋這次新派的，`dk-wave-close` 與 `--gate1` 看得到完整名單；不關、不重派已在的 reviewer。別名池用完時的錯誤提示改叫人記 `dk-process "<label> skipped: <理由>"` 收掉這一輪，不再叫人 `dk-wave-close --agent`——關 pane 不會把別名還回來。先前 `--kinds codex` 重跑會命名成 p1，`dk-spawn` 先關同名 pane，等於殺掉正在跑的 claude p1。
- feat(msg): 領導送給員工的 `[TASK]`／`[BUG]`／`[DECISION]`／`[STOP]` 一律背景送：當場返回並印 `dk-msg: 改在背景等 <target> 閒下來再送（結果記在 messages.log），你直接往下做`，背景最多等 30 分鐘（`DK_MSG_TRIES`／`DK_MSG_WAIT_MS` 可覆寫），送達才做 `redispatch`；同一收件者的多則背景訊息以 flock 照送出順序逐則送；最終送不到照舊記 `[UNDELIVERED]`，並另記 process `undelivered <target> [<type>]`（`dk-resume` 印得出）。先前對 working 員工只等 5 分鐘就放棄，multirepo 三則 `[DECISION]`／`[TASK]` 都這樣送不到。
- feat(msg): 重派已交付的 dev 會重新聚合：`redispatch` 的對象是 group=dev 且波次開著時，刪掉他本波的交付 latch（`.blocked/wave-N.<state 名>.done`）與聚合標記 `wave-N.devdone`，並把 `.blocked/<agent>.spawn` 改寫成此刻 state 的 cksum——他改寫 state 為 done 才會再推聚合，不會被上一輪的 done 誤推。送達時對方 state 已是 `status: done` 的 dev，訊息尾端附 `（你已交付過：做完先改寫 state 再回 [FIXED]）`。背景送達時改寫 `.panes` 第 3 欄，與 `dk-spawn`（刪舊列、append）和 `dk-wave-close`（`--agent`、收波清空）共用同一把 `.blocked/panes.lock`（隨 `.blocked/` 在結案時刪掉，不進任務記憶），不會互相蓋掉對方剛寫的列。
- feat(process): `dk-process` 拒收以 `minor ` 或 `minor:` 開頭但不合 `DK_MINOR_RE` 本文的行（如 `minor task: …`），exit 2，stderr 印 `dk-process: minor 行格式不符（要 "minor: …" 或 "minor <波號>: …"），整枝評議讀不到這種行`；其他行照收。先前這種行照收不警告，整枝評議的累積 Minor 表靜默漏掉它。
- feat(brief): `dk-brief-check` 新增無主測試檔 WARN：可改欄裡不含萬用字元、不是 `.md` 的路徑，取檔名在 `git ls-files` 的測試檔裡找，命中的測試檔不在任何人的可改欄就印 `WARN 所有權: <測試檔> 引用了 <檔名>…，但沒人擁有它（改行為時斷言舊行為的測試會紅）`；只 WARN 不 FAIL。multirepo 因此升報過三次。
- feat(brief): `dk-wave-open` 切片的波次表列與所有權列改用看得懂 `\|` 跳脫的共用切法（`lib/brief.sh`），「做什麼」欄寫 `a\|b` 不再少一欄；`dk-brief-check` 加欄數閘：所有權表每列 3 或 4 欄、波次表每列 7 欄（跳脫的 `\|` 不算分隔），否則 FAIL 並指出哪一列。所有權重疊檢查（`all_globs`）也改用同一套切法，可改欄含 `\|` 時不再切斷 glob 而漏判或誤判重疊。
- feat(brief): 共用契約的擁有者、消費者欄可寫 `<成員>@波<N>`（單一成員跨多波時「波 1 產出、波 3 消費」）；`dk-brief-check` 驗成員存在、波號存在、該成員在第 N 波有列。不帶 `@` 與 `—` 行為不變，`templates/brief.md` 的說明句同步。
- feat(brief): 員工切片的「## 倉庫」段多一句：編輯一律用上面的 worktree 路徑，`$DK_ROOT` 指向主樹的 `.dkbo/`、只拿來跑 bin。ops 波 1 的 S 檔員工拿 `$DK_ROOT/…` 當編輯路徑，把 10 個檔寫進主樹。
- feat(leader)!: `dk-leader <short> --run` 的任務 tab 改開在**你叫 `/dkbo-run` 當下所在的 workspace**：`HERDR_WORKSPACE_ID` 非空就用它，空才退回 `.task.env` 的 `DK_WORKSPACE`；兩者不同時回寫 `DK_WORKSPACE` 為當下值、process 記 `workspace <舊> → <新>（--run 開在當下所在的 workspace）` 並印一行提示。語意反轉（0.11.0 起是計畫那一刻記下的 workspace）：人在 A 計畫、幾天後從 B 叫 run，tab 先前會開在 A，眼前的 B 什麼都沒有。人拍板選「開在你當下所在的」。
- feat(wave): state 行數上限改成 `touched:` 清單項以外 ≤20 行——`dk-wave-close` 的 `state too long` 警告不再計入 `touched:` 之後以 `  - ` 開頭的連續行，員工首段提示同步。一波動 24 個檔的成員先前寫不進 20 行。
- fix(repos): 多 repo 模式下 `dk_glob_check` 驗 `<名>:` 前綴時用 `printf … | grep -qx`，grep 命中就退出、printf 偶爾還沒寫完就吃 SIGPIPE，呼叫端開著 pipefail 時整條管線非零——合法的 repo 名被 `dk-brief-check` 判成「未知的 repo 名字」（直呼 3000 次約 20 次）。改成 here-string；`dk-brief-check`、`dk-wave-close`、`dk-wave-open` 裡同類寫法一併改掉。
- fix(wave): `dk-wave-close` 檢查裁定行有沒有交代每位 reviewer 時改成詞界比對（別名前面要是行首或空白），`note:`、`if:` 不再冒充 `e:`、`f:` 的交代而讓閘靜默放行。
- docs(protocol): `PROTOCOL.md` 測試規則補取紅做法：一律 cp 到獨立目錄或 `git archive <base>` 解到暫存目錄，不在共用 worktree 用 `git stash`／`git checkout -- <檔>`（ops 波 4 夥伴並跑的測試讀到舊碼假紅兩次，stash 堆疊也跨 worktree 共用），`templates/report-employee.md` 的「### 紅」同義一句；雜務段重複的 `dk-msg leader "[DONE] <一句結果>"` 收成一次；state 段改寫成新的行數規則。
- docs(leader): `LEADER.md` 新增「額度」段：派 reviewer 或員工前先 `dk-kind`；任何來源確認某 kind 額度耗盡，當下 `dk-kind down <k> [--until …]`，不能只寫在 ruling 裡。run SKILL 的故障段改寫 reviewer `[TIMEOUT]` 那條（仍在工作的不關 pane、照常等；熔斷版才關並補派）、新增 dev／qa 閒置逾時的處理（先看 messages.log 有沒有它在等的 `[DECISION]`／`[UNDELIVERED]`，再補送或 `--resume`；交接波等夥伴 `[DONE]` 時觸發是預期內），補派 reviewer 直接再跑 `dk-review --kinds <k>`、失敗那位寫 `<別名>: skipped (<理由>)`，領導訊息已是背景送；plan SKILL 的計畫審查補派同理（`dk-brief-review --kinds <k>`）。
- docs(readme): 三份 README 的 `dk-kind` 補 `down`、`dk-task-close` 補「任務 tab 不自動關（最後一行印 `herdr tab close <id>`）」，`dk-watch` 與疑難排解的 `[TIMEOUT]` 說明補兩種新訊息；三份 README、`LEADER.md`、`PROJECT.md`、run SKILL 與 `tests/integration/README.md` 的 tab 位置說法改成「你叫 `/dkbo-run` 當下所在的 workspace」。`tasks/BACKLOG.md` 刪掉本版收掉的 17 列（A–C 類）。
- 測試：724 bats（+68；`09_watch` 逾時不熔斷與閒置逾時、`34_kind_down` 的 `dk-kind down`、`20_review`／`28_brief_review` 補派命名、`06_msg` 背景送與重派、新增 `36_process` 的 minor 行格式、`16`／`15`／`18` 的 brief 工具、`13_leader` 的 workspace、`08_wave_close` 的 state 行數、等 `.panes` 鎖與裁定行詞界、`07_spawn` 等鎖、`25_docs_policy` 的 Important4 改守新語意並補 AC14–AC16 三條、`21_version` 首節斷言）；shellcheck 零警告。
- 升級：`roles/` 不受影響；沒有新 settings 鍵、新 `.task.env` 鍵、新依賴、新 skill、新 bin（`dk-kind down` 是既有 `dk-kind` 的子指令）。`--run` 的 tab 位置語意反轉：要開在計畫時的 workspace，就回那個 workspace 叫 `/dkbo-run`。

## 0.15.0 — 2026-09-23

- feat(run)!: `/dkbo-run` 開跑後不停下來等人（取消關卡②）。`skills/run/SKILL.md` 新增「不停車」段：選擇題、規格缺口、reviewer 意見矛盾、修法取捨、要超過某個上限，一律由領導自己裁定——選若錯代價最小、最容易回退的那個，記 `ruling: [自主] <決定> — <原因> — <若錯代價>`，不用 AskUserQuestion。只剩四種會停：關卡③（合併）、不可逆或破壞性的操作、影響 worktree 以外的動作、brief 壞到每一條路都只能猜（最後一種寫進遺留段、停在關卡③）。依據：panova autofold 在執行中途問人的 4 題，人 4 題都選推薦項，每題等 1–13 分；人在睡覺時一題就停一整晚。規則參考 superpowers 6.4.1 `subagent-driven-development` 的「Rulings, not stalls」。人自己打字插話仍然照做。
- feat(run): 新增「熔斷器」段取代三處升關卡②（同一 bug 換過腦袋仍沒好、wave-close 測試連兩次失敗、整枝評議的修復輪用完）：停止派人，逐條判——reviewer 判錯或有爭議就 park、真的但後面沒有工作依賴它就 park 並把驗收項標未達成、真的且後面依賴它就選最小改法寫進下一波。整枝評議挑出的 Important 一次全部寫進同一個修復波，修完還有就走熔斷器，不開第二個修復波。
- feat(run): 員工 `[BLOCKED]`（卡在權限審批）不再「告知人去按」：reviewer 交給既有的 `[TIMEOUT]`；dev／qa 由領導看畫面、記 ruling、`dk-spawn --resume` 重派並叫它改用不需要審批的做法，卡第二次換 kind，再卡就 park。
- feat(run): 視覺變更不再等人看畫面才跑整枝評議；qa 每波在 report 附截圖（必要時錄影）並逐條對應 AC，人在關卡③一起看。人剛好在場時，dev 全員完成那一刻告訴他 dev server 網址，追加需求用 `--refresh` 併進本波（headermerge、autofold 的波 2 都是結波後人才看畫面開出來的）。
- feat(report): `templates/report.md` 新增「自主裁定（待你複核）」段，列出 `grep -F ' ruling: [自主]' process.md` 的每一條，照順序、一條不漏、附若錯代價；`LEADER.md` 的裁定段、三份 README 的流程說明同步。
- fix(msg): dev 送給 qa（`.panes` 的 review 組）的 `[DONE]` 改在背景送——`dk-msg` 當場返回，背景那一份照舊等對方閒下來、重試、記 log。前景等忙碌中的 qa 會把 dev 的 pane 卡住：panova 實測 autofold 22／13 分、gamemore 30 分、headermerge 12 分，而 qa 本來就看 dev 的 state 開工。dev 送 dev 的 `[DONE]` 照常前景送。`roles/qa.md` 補「已在測就不必因晚到的 `[DONE]` 重跑」。
- feat(spawn): 員工與雜務員工啟動時帶 CLI session 名（claude 的 `--name <任務>-<角色>`，同領導的 `dk/<short>`），pane 上看得出是哪位角色；codex、agy 沒有對應旗標，不帶。
- test: 否定斷言改成在 bats 下有效的寫法——`tests/` 的 76 處（74 行）`! cmd` 全數換成 `refute_grep`（grep 類，含 `cmd | refute_grep` 管線）或新增的 `refute <cmd>`（`tests/helpers.bash`），其中 48 處原本失效：bats 在 `set -e` 下跑，而 `!` 開頭的述句豁免 `set -e`，不是測試最後一條時命中了也照樣綠。轉換後全數照舊通過，沒有被遮住的真失敗。新增 `35_test_hygiene.bats` 守門：掃 `git ls-files` 列出的全部 `tests/*.bats` 與 `helpers.bash`，出現 `!` 開頭的述句就紅並列出 `檔:行`，掃描器對植入樣本兩向自我驗證。`fixture_task()` 的 `.task.env` 改由 `templates/task.env` 經 `dk_render` 套出（在子 shell source `common.sh`，跟 `dk-task-new` 走同一條路），補回漂移掉的 `DK_TASK_TAB`、`DK_LEADER_PANE`、`DK_NO_WORKTREE`；套完殘留 `{{…}}` 或缺模板鍵就把名字印到 stderr 並回非零讓 setup 紅（先前七個 setup 沒 source `common.sh` 的檔拿到空 `.task.env` 照樣全綠）。`setup_project()` 不再把主樹 gitignore 的 `.sessions/`（`kinds-down`、pane 綁定、`*.watch.pid`）帶進夾具——開發機上一筆未過期的 `kinds-down` 曾讓 `10_resume` 兩條紅。波 1 審查的收尾：掃描器的分隔符與 `!` 之間允許沒有空白（`true;! foo`、`a &&! b`），分隔符補 `|`、`{`、`(`、`else`；自檢只要 `.task.env` 仍含 `{{` 就回非零（`{{FOO}`、`{{FOO` 這種半截的也算，抽不出名字就印整行）；鍵集合測試另擋 `DK_*=` 以外的雜行。只動 `tests/`，安裝包不含它，升級拿不到差異，所以不升版。
- 測試：656 bats（+18；`06_msg` 背景送與 dev→dev 前景送、`07_spawn` session 名、`25_docs_policy` 不停車與背景送兩條；測試可信度 +14：`35_test_hygiene` 5 條（掃描、掃描集合、兩向自我驗證、列出檔:行）、`36_fixture` 9 條（鍵集合與順序且無雜行、各鍵的值、殘留佔位符回非零、半截佔位符 `{{PROBE2` 回非零、抽不出名字的 `{{` 印整行、不靠呼叫端 source、不留變數與函式、`.sessions/` 只剩 `.gitkeep` 兩條））；`04_docs` 的 run SKILL.md 行數上限 50 → 60（多了兩段）；shellcheck 零警告。
- 升級：`roles/` 不會跟著升（rsync `--ignore-existing`），`qa.md` 的截圖要求與 frontend／backend 的說明要手動對照本版改；不改也能用——背景送在 `dk-msg` 那一側生效。沒有新鍵、新依賴、新 skill。

## 0.14.0 — 2026-09-23

- feat(review)!: `DK_REVIEW_TIER` 出廠值由 `M` 改成 `L`（`settings.env`、`templates/seed/settings.seed.env`、`dk_settings` 缺鍵時的預設三處一致）。依據是 18 個已合併任務的 process.md：teamflow 的波審查用 M，6 個任務的整枝評議（L）**全數**再挑出 Important；panova 的波審查用 L，12 個任務只有 2 個。最直接的是同一份 diff 的對照——tasktab 與 ops 第一次整枝評議時分支上只有波 1，`task.diff` 就是波 1 的 diff：tasktab 的 M 判「Important 0、Minor 0」，20 分鐘後 L 挑出 4 條；ops 的 M 判 1 條，L 再多 2 條。波審查漏掉的問題拖到整枝評議，就要多開一整個修復波（ops、tasktab 的修復循環各約 2 小時，佔任務總時長五成以上）。0.4.0 預設 M 的理由是「密度先於天花板」，但第二個 kind 實跑幾乎全程熔斷，密度實際為 0。兩個專案的程式類型不同（bash 對 Vue），檔位不是唯一變因。`/dkbo-init` 的問法改成預設 L、人要省額度才降 M。
- docs(run): `skills/run/SKILL.md` 結案段補兩條，讓同一份 diff 不被審兩次——單波任務的 L 檔波審查即整枝評議，不再跑 `dk-review --task`（記 `review task skipped: 單波…`）；整枝評議挑出 Important 開的修復波，審查用 `--tier L`，這一輪就算下一輪整枝評議，Important 0 即進關卡③，只有修復動到先前各波沒碰過的檔或跨成員共用契約時才重跑整枝評議。
- docs(plan): 計畫審查達 `DK_REVIEW_MIN` 且意見已採納就送關卡①，不等晚到的 reviewer——它與人讀 brief 並行，人拍板前回來就併入並告訴人改了什麼，沒回來就關掉、補一行 `skipped (關卡①時未回)` 的 verdict 再 `--gate1`（`--gate1` 的兩道閘看最後一行 verdict 與 pane 是否關淨，不用改程式）。tasktab 為一位最後逾時的 agy 多等了 18 分鐘；逾時不寫專案層熔斷，所以下個任務還會再派、再等。
- docs(protocol): 員工做的過程只跑相關測試檔，完整測試只在送 `[DONE]`／`[FIXED]` 前跑一次——wave-close 本來就再跑一次當閘；員工 report 記的全套次數一波最多 4 次，teamflow 一次 2 分 10 秒，且同波共用 worktree 會互相拖慢。
- 測試：638 bats（+4）；`20_review.bats` 出廠檔位改驗 `opus/high`、降 M 改驗 `opus/medium`；`23_leader_kind.bats` 缺鍵預設改驗 L；`25_docs_policy.bats` +4（兩條結案規則、三處出廠值一致、關卡①不等晚到的 reviewer、完整測試只跑一次）；shellcheck 零警告。
- 升級：**既有專案的 `settings.env` 不會跟著改**（升級的 rsync 排除它）。要採用就手改 `DK_REVIEW_TIER="L"`；已經是 L 的不用動。沒有新鍵、新依賴、新 skill。

## 0.13.0 — 2026-09-23

- feat(kinds)!: claude kind 三檔全換 Opus 5.5，只用 effort 分檔——`KIND_DEFAULT_TIERS` 由 `S=sonnet/low M=sonnet/medium L=opus/high` 改成 `S=opus/low M=opus/medium L=opus/high`；六份角色檔照同一條規則改：sonnet 一律換成同 effort 的 opus（qa 的 L 由 `sonnet/high` 改 `opus/high`，it 由 `sonnet/low`／`sonnet/low`／`sonnet/medium` 改 `opus/low`／`opus/low`／`opus/medium`）。依據（2026-09-23，Opus 5.5 發布隔天）：Artificial Analysis Intelligence Index 的 opus/low 42、opus/medium 51、opus/high 54，sonnet/low 24、sonnet/medium 28、sonnet/max 38，fable 5.1 最高 53、價格是 opus 的 2.5 倍；每題成本 opus/low $0.55 與 sonnet/low $0.51 相當（opus 單價兩倍但用的 token 少）。Vals 的 Terminal-Bench 2.1 opus 87.6% 對 sonnet 74.5%，與 AA 方向一致。S 檔另有 Anthropic〈What a task costs on Opus 5.5〉的建議：機械式改動留在 Opus 5.5 low，Sonnet/Haiku 只給查找、不給寫碼——dkbo 的 S 定義正是純機械改動。尚未驗證的是 opus/low 對 sonnet 的實跑比較（第三方只有 AA 分 effort 測過，Vals Index（max）上兩者只差 1 分），第一次實跑 S 檔時留意品質與額度。reviewer 的 M/L 仍解析到不同旗標（`opus/medium` 對 `opus/high`），0.4.0 記下的「M 與 L 不得同義」照舊成立。領導走 L 檔，仍是 `opus/high`，不受影響。sonnet 留在 `KIND_MODEL_EFFORTS`，`--model sonnet` 手動指定仍可用。
- feat(kinds): `KIND_MODEL_EFFORTS` 的 opus 與 sonnet 補上 `xhigh`、`max`（claude CLI 2.1.280 的 `--effort` 已收這兩個值），可用 `--model`/`--effort` 或角色檔手動指定；出廠檔位不用它們。
- 已知風險：Opus 5.5 的安全分類比前代寬（新增 bio、reasoning_extraction），Vals 註記它在多個 benchmark 需要 server-side fallback 補分；員工 pane 被拒答時畫面長什麼樣還沒實測，`KIND_BLOCK_RE` 沒有收——第一次實跑撞到時把原文補進來。
- 測試：634 bats（+1，`03_kinds.bats` 驗 xhigh/max 可用；`20_review.bats` 的 reviewer M 檔改驗 `opus/medium`、`11_chore.bats` 的預設 S 檔改驗 `opus/low`；`03`/`13` 拿來驗「不認得的 effort」的值由 `max` 改成 `ultra`）；shellcheck 零警告。
- 升級：**角色檔不會跟著升**——更新 dkbo 的 rsync 對 `roles/` 是 `--ignore-existing`，既有專案只拿到 `kinds/claude.sh` 的新出廠檔位與 effort 清單，派人時實際用的角色檔 `tiers:` 仍是舊值。要採用就照上面那條規則手動改 `roles/*.md` 的 `S:`/`M:`/`L:` 行（或對照本版 `roles/README.md` 的團隊表）。沒有新鍵、新依賴、新 skill。

## 0.12.1 — 2026-09-23

- fix(install): `templates/seed/` 的起始檔改名為 `*.seed.md`／`settings.seed.env`——0.12.0 用的是 `PROJECT.md`、`decisions.md`、`settings.env` 原名，而「更新 dkbo」那條 rsync 的 `--exclude=PROJECT.md` 等是比對檔名、不分目錄，升級時連 seed 裡的同名檔一起排除，升過級的專案日後缺檔再跑 `install.sh` 會因 seed 不存在而中斷。改名後兩條 rsync 照 README 原樣跑，seed 一個不少。
- 測試：633 bats（+1，`14_install.bats` 照 README 的兩條 rsync 實跑升級並驗 seed 齊全）；shellcheck 零警告。
- 升級：用 0.12.0 升過級的專案照「更新 dkbo」重跑一次即可補齊 seed；沒有新鍵、新依賴、新 skill。

## 0.12.0 — 2026-09-23

- feat(kinds)!: 跨任務的專案層熔斷檔 `.dkbo/.sessions/kinds-down`——`dk-watch` 判定撞額度時除了照舊寫本任務 `DK_KIND_DOWN`，另在這個檔追加或更新一列（同 kind 取較晚的恢復時間，不重複），寫檔走 flock；reviewer `[TIMEOUT]` 造成的熔斷不寫這個檔，因為逾時不代表額度用完。派人前 `dk_review_kinds` 把未恢復的 kind 視同已熔斷：`--kind` 明寫且命中就拒絕（`dk-spawn` exit 1），角色檔預設命中則照派但印警告，避免一次誤判把下一個任務每個角色都擋死。新增 `dk-kind [status]` 看清單、`dk-kind up <k>` 解除（同時清 kinds-down 與綁著任務的 `DK_KIND_DOWN`）；`dk-resume` 的 `kinds down:` 行附印專案層未恢復的 kind。
- feat(kinds): 恢復時間解析全部走可攜純算術，不依賴 `date -d`；agy 認「Resets in <N>h<M>m[<S>s]」與沒有小時的「Resets in <M>m[<S>s]」標 `exact`，codex 認「try again at <月份縮寫> <日><序數>, <年> <時>:<分> <AM|PM>」換算後標 `exact`，兩者都解析不到才用「現在 + 5 小時」標 `guess`。
- fix(codex): `kinds/codex.sh` 的 `KIND_QUOTA_RE` 移除第 3 個分支——它跟 `kinds/claude.sh` 額度式子的第 2 個分支同字串，同時命中「快到額度、切模型」選單的標題與說明文字，把暫時性限流誤判成撞額度並熔斷；第 1、2、4 個分支保留，claude 與 agy 的額度式子不動。此後 codex 只印那個片語不再熔斷——這是想要的，不是回歸；0.11.2「已知仍未處理」的這一項本版已處理。
- feat(watch): `[LIMIT]` 留畫面證據——`handle_limit` 在 `.blocked/<agent>.limit` 追加最多 5 行 `hit: <命中的畫面行>`，送給領導的 `[LIMIT]` 訊息尾端附第一條命中行，process.md 的 `limit …` 行不附（避免領導讀 process 時畫面冒出額度字樣）。`hit:` 行的截斷改按字元數（不是位元組）：原本用 `cut -c` 在 GNU 環境是按位元組截，中文命中行會切出半個 UTF-8 字元，讓真 herdr 拒收這個非法參數、`[LIMIT]` 永遠送不到；改法保證 `.limit` 的 `hit:` 行、kinds-down 的第一條 hit 與送出的 `[LIMIT]` 訊息都是合法 UTF-8。
- feat(flow): `dk-wave-open <N> --refresh` 讓波中改 brief 可重產第 N 波所有成員的切片、重設整波逾時起算點，不改 base、不重派、不刪 `.blocked/wave-N.devdone`（改由 `dk-spawn` 在波開著時加入 dev 成員的同一步刪，避免新成員 spawn 前的空窗重推假聚合）；`dk-msg` 在切片比 brief 舊、或領導有未 ack 的訊息時各印一行提示但照送；dev 送 `[DONE]` 前驗 state 的 `status`／`touched`／`report` 三個頂格鍵與 `touched` 文法，不過拒絕並指出哪裡錯；`dk-task-close` 結案後把時間表「任務」列的結束時間與 report.md 的 `結果：` 行改寫成最終值，不再帶「（進行中）」。
- docs: `skills/run/SKILL.md` 的 `[LIMIT]` 故障段改寫成先驗 `hit:` 再判真假、補送 TASK/DECISION 前讀未 ack、視覺變更任務先給人看畫面、波中改 brief 走 `--refresh` 的流程；三份 README 補 `dk-kind`／`--refresh`；`.dkbo/README.md` 疑難排解補專案層熔斷；`PROTOCOL.md`／`templates/state.md` 寫明 `touched` 的清單文法。整枝評議把問題判成不修、記 BACKLOG 時，ruling 要標明前提是實測還是推測，推測不能當不修的理由（ops 任務把 UTF-8 截斷誤判成「只影響顯示」，多開了一波）。檔位選擇收緊：`skills/plan/SKILL.md` 寫明 S 只給純機械的工作，碰邏輯、閘或規則文件至少 M；`skills/run/SKILL.md` 寫明審查後的修復波成員至少 M；`skills/add-role/SKILL.md` 的 S 定義同步改成「純機械照做、不碰邏輯」。
- fix(install): 全新安裝不再把源碼倉的開發紀錄一起裝進去——三份 README 的一鍵安裝原本 `cp -r` 整個 `.dkbo/`，v0.10.0 起的 tag 都帶著 dkbo 自己的 `tasks/`（任務紀錄、BACKLOG、INDEX）、`decisions.md`（領導會當成你專案的跨任務決策來讀）、`PROJECT.md` 與 `settings.env`（`DK_TEST_CMD=tests/run.sh`）。改成複製前先在暫存 clone 拿掉這五項（與升級的 rsync 排除同一組）；`install.sh` 對缺的 `tasks/INDEX.md`、`tasks/BACKLOG.md`、`decisions.md`、`PROJECT.md`、`settings.env` 從新增的 `templates/seed/` 補空白版，已存在的不動。已用舊指令安裝的專案：`decisions.md` 與 `tasks/` 裡不是自己的條目要手動刪。
- 測試：632 bats（+80）；21/25/04/14 補斷言；shellcheck 零警告。
- 升級：`.dkbo/.sessions/kinds-down` 與其鎖檔 `kinds-down.lock` 是新增的執行期檔（已被 `.gitignore` 排除，不進版控）；新增 bin `dk-kind`；沒有新 `settings.env` 鍵、沒有新 skill、`install.sh` 沒有新 symlink，`.task.env` 沒有新鍵。

## 0.11.2 — 2026-09-23

- fix(codex): codex 的「Approaching rate limits / Switch model」選單會停住等人按 Enter，但 `kinds/codex.sh` 的 `KIND_BLOCK_RE` 沒有這個選單的字樣，`dk-watch` 認不出這種卡住（gamemore 實跑樣本 24、64 都漏掉）。式子補上 `Press enter to`——收前綴不收整句：窄 pane 會截掉最後一行的尾巴，實測原文是 `Press enter to confir` 與 `Press enter to con`，整句 `Press enter to confirm` 兩份都認不得。已知仍未處理：寬 pane 上這個選單的標題 `Approaching rate limits` 會先命中額度式子的裸 `rate limit`（`dk-watch` 額度優先），被判成撞額度並熔斷 codex，但這個畫面是「快到了」不是「已耗盡」；實測樣本 2.2 上方另有真的額度用完訊息，所以結果剛好是對的，留待確認 codex 真的耗盡時印什麼再收窄。
- 測試：552 bats（+2，`03_kinds.bats`，用實測原文）；shellcheck 零警告。
- 升級：純修補，沒有新鍵、新依賴、新 skill。

## 0.11.1 — 2026-09-23

- fix(resume): `dk-resume` 的「## BACKLOG」段原本整份 `cat tasks/BACKLOG.md`，而 BACKLOG 是只會長的跨任務記憶——0.11.0 結案後補了四條，恢復包在最後一級降級（process 10 行、state 3 行、裁定 5 行）之後仍超過 150 行，`10_resume.bats` 在 CI 紅掉（v0.11.0 的 tag CI 是紅的；領導在結案前跑的 548 綠是在那四條進來之前）。改成只印表頭與最後 8 條，超出的留一行「另有 N 條較早的，見 tasks/BACKLOG.md」；預算從此不再被 BACKLOG 的長度左右。補兩條測試。
- 測試：550 bats（+2）；shellcheck 零警告。
- 升級：純修補，沒有新鍵、新依賴、新 skill。

## 0.11.0 — 2026-09-22

- feat(tab)!: `dk-leader <short> --run` 實體化任務時，不再開一個新的 herdr workspace，改在任務所屬的 workspace（`.task.env` 的 `DK_WORKSPACE`，計畫時記下；空時退回 `HERDR_WORKSPACE_ID`）用 `herdr tab create --workspace <ws> --cwd <主樹> --label dk/<short> --no-focus --env DK_ROOT=… --env HERDR_ENV=1` 開一個 label `dk/<short>` 的新 tab，在它的根 pane 起執行領導交棒；不再呼叫 `herdr workspace create`／`herdr workspace get`／`herdr tab rename`。任務根 tab 的 id 記進 `.task.env` 新鍵 `DK_TASK_TAB`（計畫階段為空）；`DK_WORKSPACE` 的語意從此固定是「任務所在的 workspace」，`--run` 只在它原本是空字串時用 `HERDR_WORKSPACE_ID` 補上並落盤，非空時一律不動。rollback、幂等檢查（`.repos` 在、`DK_TASK_TAB` 非空但 `herdr tab get` 失敗即拒絕）、`dk-task-close` 結尾提示（`herdr tab close <DK_TASK_TAB 的值>`）、`dk-resume` 的字樣全部從 workspace 改成 tab；`dk-spawn` 的溢出 tab 行為不變（它本來就是 `tab create --workspace "$DK_WORKSPACE"`）。**升級注意**：0.10.0 開出的任務 workspace 這一版不會自動關，看完 report 自己手動關掉。
- 測試：21/25/04 的斷言跟著改；`tests/integration/herdr-real.sh` 的 AC17 探針換成 `tab create`／`tab get`／`tab close`，發版前在真 herdr（nested dktest session）跑過一次。
- 升級：`.task.env` 只新增 `DK_TASK_TAB` 一個鍵，沒有新 `settings.env` 鍵、沒有新 skill、`install.sh` 沒有新 symlink。

## 0.10.0 — 2026-09-20

- feat(workspace)!: 一個任務從此有自己的 herdr workspace，在 `/dkbo-run` 那一刻才建。`dk-task-new` 只建任務資料夾——不切 worktree、不開 workspace，`.task.env` 的 `DK_WORKTREE`／`DK_BASE` 是空的，計畫完可能不做就不先付成本。`dk-leader <short> --run` 把任務「實體化」：切 worktree、跑依賴鉤子、用 `herdr workspace create --cwd <主樹>` 開 label 與 tab 名皆為 `dk/<short>` 的 workspace、在根 pane 起執行領導（`agent start --name dk/<short>`，claude 才帶這個旗標）並改綁 `.sessions`、`DK_LEADER_PANE`。`agent start` 之前任一步失敗，rollback 還原全部 worktree、分支、workspace 與 `.task.env`；重跑是幂等的。單 repo 專案（`DK_REPOS` 空字串）行為相同，只是只切一個 worktree。
- feat(repos)!: 一個任務可以跨 N 個獨立 git repo。新的 `settings.env` 鍵 `DK_REPOS="<名>=<路徑> …"`（第一個是主 repo）；設了它，檔案所有權、`touched`、差異包、`dk-wave-close` 的越界比對、合併全部長出 repo 這個維度，所有面向人的輸出（切片、報告、越界訊息、`file:line`）在多 repo 模式下一律印 `<名>:` 前綴，單 repo 模式一律不印。新函式庫 `.dkbo/lib/repos.sh`：`dk_repos_parse`／`dk_repos_check`／`dk_repos_write`／`dk_glob_split`／`dk_glob_check`／`dk_repo_setup_cmd` 等。`DK_REPOS` 空字串時 0.9.2 的既有測試語意不變。
- feat(setup): 新增 `DK_SETUP_CMD`／`DK_SETUP_CMD_<名>` 依賴鉤子，每個 worktree 切好之後在乾淨環境（`env -u DK_*`，同 gate c 那一套）各跑一次；失敗只警告不 rollback，log 落 `tasks/<t>/setup.<名>.log`。前端 repo 建議 `pnpm install --frozen-lockfile --prefer-offline`——不 symlink 主樹的 `node_modules`（見 `.dkbo/README.md` 的「多 repo 專案」段兩個坑）。
- feat(task-close)!: `dk-task-close` 重寫合併流程為兩階段：先逐 repo 預檢（`merge --no-commit --no-ff` 後 abort），任一衝突就整批不合併並 exit 3、全部列名；主樹本地變更會被覆蓋則 exit 5；預檢全過才真的逐 repo 合併，中途失敗 exit 4 並印 merged／failed／not attempted 三份清單（已合併的不會自動回捲）。任務記憶固定在合併之前先 commit 一次（修掉「暫存中的改名擋住 merge」那個舊債）。**不再自動 `herdr workspace close`**——執行領導自己住在那個 workspace 的根 pane 上，成功結案的最後一行改印 `herdr workspace close <id>` 提醒人手動關。
- feat(gates): `dk-wave-open`／`dk-review-pack`／`dk-wave-close`／`dk-spawn` 全部學會多 repo：`dk-wave-open` 逐 repo 記 base 並在切片印「## 倉庫」段；`dk-review-pack` 逐 repo 分段 `## repo <名>`；`dk-wave-close` 的 gate c 只對本波有變更的 repo 跑各自的 `DK_TEST_CMD`／`DK_TEST_CMD_<名>`、gate d 逐 repo 比對所有權並逐 repo commit；`dk-spawn` 的 pane cwd 落在成員第一個可改 glob 所在 repo 的 worktree，`DK_ADD_DIRS` 對 `.repos` 每一列各出一個 `--add-dir`（單 repo 模式維持只有主樹，不放寬既有斷言）。
- fix(dk-task-new): 開場多驗「主 repo 是 git 根」（`dk_repos_check --no-clean` 的便宜三項），比 0.9.2 早——0.9.2 是靠 `git worktree add` 隱含這個要求，`dk-task-new` 瘦身後不再切 worktree，失敗點從 `/dkbo-run` 提前到 `/dkbo-plan`。
- fix(repos): `dk_repos_check` 的乾淨檢查只看已追蹤檔（`git status --porcelain --untracked-files=no`）——`.dkbo/` 不進版控的專案，未追蹤檔不算髒。
- fix(common): `dk_task_dir` 在 `DK_TASK_DIR` 分支結尾的裸 `return` 改成 `return 0`；裸 `return` 在 EXIT trap 裡回的是觸發 trap 的狀態，會讓掛了 rollback trap 的失敗路徑上 `dk_env_set` 第一行靜默退出。
- fix(brief-check): 所有權與獨佔資源欄用了未加引號的 `for … in $(…)`，被 cwd 的真實檔名做 pathname expansion 展開，多 repo 模式的前綴檢查形同虛設；改成 `while IFS= read -r … <<< "$(…)"`。
- fix(repos): 主 repo 的乾淨檢查排除 `.dkbo/` 底下的路徑（`git status … -- . ':!.dkbo'`）——dkbo 自己的任務記帳（`INDEX.md`／`process.md`…）從 `dk-task-new` 到 `dk-task-close` 之間永遠是已追蹤且已修改，那不是工作樹不乾淨；把 `.dkbo/` 進版控的專案（含本倉）不排除的話，`--run` 會被自己的任務記帳擋死。`.dkbo/` 只存在於主 repo，其餘 repo 這條 pathspec 排除不到東西，行為不變。
- fix(leader,wave-close): `dk-leader --run` 的 `DK_SETUP_CMD` 鉤子與 `dk-wave-close` gate c 的測試指令都跑在 `while read <<< "$repo_rows"` 的迴圈裡；鉤子或測試指令若讀一次 stdin（互動提示、docker compose…），會吃掉迴圈的 herestring，後面的 repo 靜默不跑。兩處都加 `< /dev/null`；`dk-wave-close` 逐 repo commit 那一句雖然 `-m` 下 `git commit` 不讀 stdin，同一個迴圈、同一類曝險，一併加固。
- docs: 三份 README 加交棒（`/dkbo-run` 才建 workspace）、多 repo 前綴、`dk-task-close` exit 3/4/5 與 workspace 不自動關、`DK_SETUP_CMD` 的 pnpm 寫法與 `node_modules` 兩個坑；`PROTOCOL.md` 加 `<名>:` 前綴與共用 worktree 段；`LEADER.md` 補 `DK_REPOS`／`DK_SETUP_CMD`；`roles/reviewer.md` 補 `file:line` 前綴；`PROJECT.md` 補多 repo 事實。
- 測試：539 bats（+113）；shellcheck 零警告。
- 升級：新增三把 `settings.env` 鍵（`DK_REPOS`、`DK_SETUP_CMD`，加上多 repo 專案逐 repo 的 `DK_TEST_CMD_<名>`／`DK_SETUP_CMD_<名>`），沒有新依賴、沒有新 skill、`install.sh` 沒有新 symlink。既有單 repo 專案不設 `DK_REPOS` 就是 0.9.2 的行為，唯一可見差異是 `dk-task-new` 早驗主 repo 是 git 根、`dk-task-close` 不再自動關 workspace（0.9.2 本來就沒有任務專屬 workspace 可關）。

## 0.9.2 — 2026-09-19

- fix(watch): assess()/reviewer 逾時判定加 agent_status=working 與 state done 前提，跳過畫面判定不再誤判額度／審批
- feat(time): 領導看不到時間 —— process.md 每一行都有時間戳，卻沒有任何一支腳本讀它，於是「這一波跑多久了」「該不該催」全憑感覺，結案 report 也說不出時間花在哪。這一版把那些既有時間戳接起來：`lib/common.sh` 新增 `dk_ts_minutes "YYYY-MM-DDTHH:MM"`（純算術的 days_from_civil；`date -d` 是 GNU 限定、`date -j` 是 BSD 限定、`mktime` 是 gawk 限定，三條路各自會在另外兩種機器上斷掉），三支腳本共用同一份換算與同一套「缺來源印 `—`」的政策。`dk-resume` 的「本波」段多兩行（`任務已進行 Xh Ym`、`本波已進行 Ym`），「在線員工」每位附 `等了 N min`（dev 與 reviewer 一致）。`dk-wave-close` 成功關波時印並記一行 `wave N 耗時 Mm（dev Am、審查 Rm）`。新腳本 `dk-timeline [<任務>]` 只讀 process.md 印一張 markdown 表（任務、計畫、每波的開關與 dev／審查、結案），零 token、不寫任何檔；`dk-task-close` 結案時把它填進 `report.md` 的「## 時間」段（`templates/report.md` 同步加這一段）。只認 process.md 既有的行首 token，不新增任何要員工或領導多填的欄位。回歸樣本用真跑過的 log（`tests/fixtures/` 的 highfix 與 flowgap 原樣複製，數字與領導人手算的逐欄一致），外加一份手改成跨午夜的 `crossday-process.md` —— 曆法是自己算的，只在同一天內對的實作在單日樣本上完全看不出來。
- 測試：426 bats（+27）；shellcheck 零警告。

## 0.9.1 — 2026-09-19

- fix(watch): dev 完成聚合只看 state 的 `^status: done`，而 state 檔跨波共用、`.devdone` 標記逐波 —— 成員跨兩波時，**開波到員工寫下第一份 state 之間的空窗會被判成「dev 全員完成」**（flowgap 實測兩次），誤發後標記寫成 `delivered`，真正完成時永遠不再通知，領導從此只能手動追蹤。改法：`dk-spawn` 在每次 spawn（含 `--resume`／`--handoff` 重派）當下把 state 內容的 `cksum` 存成 `.blocked/<agent>.spawn`，聚合要求「`status: done` 且內容與快照不同」才算這一輪的交付；認定過就落一個 `.blocked/wave-N.<成員>.done` latch，重派不會把已認定的完成打回未完成。不看 state 的 `wave:` 欄（員工漏填會靜默永不通知，比誤報更糟），也不看 mtime（`date -r` 在 GNU 與 BSD 語義不同）。沒有快照檔的 legacy 任務照舊只看 status。`dk-wave-close` 收波與 `--agent` 關單人時一併清 latch。
- fix(wave-close): gate c 用 `bash -c "$DK_TEST_CMD"` 跑測試，把領導整包 `DK_*` 環境餵給子行程；專案的測試只要 source 到會寫 `${DK_X:-預設}` 的東西就會照繼承值打到真 repo（2026-09-19 領導在自己 session 跑 gate c，在源碼倉建了 7 個 worktree 與 8 個分支）。改成以 `env -u` 逐一剝掉所有 `DK_*` 再執行，`PATH`、`HOME` 等非 `DK_*` 照舊；仍在 `DK_WORKTREE` 內跑，測試非零仍拒絕關波，`--force` 照舊放行。
- fix(kinds): `kinds/agy.sh` 的 `KIND_QUOTA_RE` 收了裸 `quota`，而 agy 的啟動橫幅就叫 `bal@host (Antigravity Starter Quota)` —— 每個 agy 員工一 spawn 就被判撞額度、該 kind 當場熔斷。改成只收耗盡的說法（`quota reached|quota exceeded|rate limit|usage limit|resource exhausted`；實測原文 `Individual quota reached, Resets in 102h11m1s`），`lib/kinds.sh` 的通用回退式 `DK_RE_QUOTA_ANY` 同步收窄。`dk-watch` 對 reviewer `[TIMEOUT]` 附加 `(quota?)` 的那條另寫的寬鬆式子（`rate limit|quota|429|usage limit`）廢除，改走該 kind 的 `KIND_QUOTA_RE` 同一條路徑。`kinds/claude.sh` 的 `KIND_QUOTA_RE` 同一波再收窄一次：移除裸 `approaching your`（「快到了」不是「已耗盡」，且是極常見英文片語，員工畫面上出現這兩個字就會被誤判熔斥），只留實測過的耗盡片語 `usage limit|rate limit`。
- fix(watch): `dev_delivered()` 的 latch 原本一旦落下就無條件視為「已交付」，qa 把某位 dev 退回 `status: working` 之後，只要同波其他人交齊，仍會被判成全員完成並推出聚合 `[DONE]`——跟開波空窗那條誤發是同一個洞，只是觸發條件換成「退件」。改成 latch 只豁免「內容與快照相同」那一關，`status: done` 本身仍要每輪重新確認。
- docs: 三份 README 的 herdr 版號誤標成 0.9.1（含疑難排解那列的錯誤訊息原文），與 `lib/common.sh` 的 `DK_HERDR_MIN="0.9.0"` 不符；改回 0.9.0，六處。新增 `21_version.bats` 測試守住兩者一致。
- 測試：399 bats（+14）；shellcheck 零警告。

## 0.9.0 — 2026-09-19

- feat(brief)!: brief 新增 `## 全域約束` 段（橫切所有波的硬要求，一行一條），流進三份切片模板（成員、波審查、計畫審查）的 `{{CONSTRAINTS}}` token。`dk_brief_constraints()` 有 reader 與測試。
- feat(brief): 共用契約段改成表格（契約｜擁有者｜消費者｜形狀／簽名｜變更流程），`dk_brief_interfaces()` 有 reader 與測試；`dk-brief-check` 驗表格的擁有者與消費者都在檔案所有權表內。**`dk-brief-check` 對 0.9.0 之後建立的 brief 多兩道 FAIL（全域約束為空、共用契約表格的擁有者／消費者不在所有權表）；進行中的舊任務只拿到 WARN**，判別器是段落與表頭存不存在，不看內容。
- feat(report)!: report 的 `## 測試` 分成 `### 紅`／`### 綠` 兩節，`dk-wave-close` 的 gate b 要求每節至少兩行非空內容（指令列與輸出）；首行 `不適用: <理由>` 是單行豁免。**沒有測試的波兩節都寫「不適用: <理由>」**。
- feat(methods): 新增 `.dkbo/methods/debugging.md`（六段除錯方法：先重現、往回找第一個說謊的地方、一次改一件事、二分法縮範圍、寫下排除了什麼、修好的定義）。`PROTOCOL.md` 的 BUG 列指向它；首輪提示帶 TDD 順序（先寫失敗測試、跑它確認失敗、再寫最小實作）與除錯指路。
- feat(review): 整枝評議（`dk-review --task`）的 reviewer 切片帶本任務累積的 Minor（來自 `process.md` 的 `minor` 列），逐條 triage；逐波審查不帶，避免同一條風格意見在每一波都被重讀一次。`dk-task-close` 對「有 minor 但 report 沒提」只警告不阻擋結案。
- feat(spawn): 新增 `dk-spawn --handoff "<原因>"`——修復迴圈換腦袋的正式入口，隱含 `--resume`，自己落 `ruling:` 一行進 `process.md`，首輪提示改用接手版文案（讀上一位的 state／report、不要照它的路再走一次）。不帶原因 exit 非零。修復迴圈上限從一次改成兩輪：BUG → FIXED → 再驗仍失敗 → 換腦袋（`--handoff`）→ 再驗仍失敗才 ESCALATE。`PROTOCOL.md` 與 `skills/run/SKILL.md` 同步。
- fix(protocol): `[FIXED]` 列要求內文附一句根因，有測試守著。
- fix(minor)!: `minor` process 行原本沒有生產者，換一個任務就靜默失效；`skills/run/SKILL.md` 第 4 步補教領導逐條 `dk-process "minor N: <一句> <file:line>"`。`dk-review` 與 `dk-task-close` 對 minor process 行共用同一個 pattern（`lib/common.sh` 的 `dk_minor_lines`/`dk_minor_count`），不再各養一份互相看不見的正規表示式；`dk-task-close` 比對 report.md 是否提到 minor 時也忽略範本自己的指引行（`^（` 開頭），否則那行的「Minor」三個字會把警告永遠消掉。
- fix(roles): `roles/backend.md`、`roles/frontend.md`、`roles/qa.md` 的修復迴圈文字改成兩輪，跟 `PROTOCOL.md` 一致（原本仍寫「修一次」，員工首輪提示第一項讀到的正是角色檔）。
- fix(prompt): 首輪提示的 TDD 那一句只發給 `group: dev` 的成員；`dk-spawn --handoff` 的 ruling 改到 pane 與 agent 真的起來之後才落盤，spawn 失敗不再留下假裁定。
- fix(wave-close): `不適用` 豁免同時接受半形 `:` 與全形 `：`。
- fix(tests): 測試的 `setup_project` 整包 `cp -r .dkbo` 進 fixture，連源碼倉自己的 `settings.env` 一起帶走。源碼倉為了 dogfood 任務的 gate c 把 `DK_TEST_CMD` 設成 `tests/run.sh` 之後，每一條「閘全過」的 wave-close 測試都在假 worktree 裡去跑一個不存在的指令，16 條紅。現在 fixture 的 `DK_TEST_CMD` 一律清空，要測 gate c 的測試自己 append 一行蓋掉；`30_isolation.bats` 多一條守著。
- **已知問題**（flowgap 實跑打出來的八條全記在 `.dkbo/tasks/BACKLOG.md`，這一版沒有修，兩條要先知道）：
  - `dk-watch` 的 dev 完成聚合只看 state 的 `status: done`，但 state 檔跨波共用。**任何成員跨兩波以上，第二波一開波就可能收到假的「dev 全員完成」**（開波到員工寫下第一份 state 之間的競態，實測兩次），而且誤發後 `.devdone` 標記寫成 delivered，**真正完成時不再通知**。領導收到聚合先看 `dk-resume` 的 state 對不對得上本波，別直接打差異包；四道閘擋不住零產出的波（report 跨波留存、空 diff、測試照綠）。0.8.0 起就存在，不是這一版造成的。
  - `dk-wave-close` 的 gate c 用 `bash -c "$DK_TEST_CMD"` 跑測試，繼承領導整包 `DK_*` 環境。專案的測試若會讀 `DK_*`（目前只有 dkbo 自己），會在真實 repo 上動手。測試端已在這一版修掉，腳本端的 `env -u` 留到下一版。
- 測試：385 bats（+8）；shellcheck 零警告。
- 升級：照 README 的 rsync 流程走即可。這一版沒有新依賴、沒有新 `settings.env` 鍵、沒有新 skill、`install.sh` 沒有新 symlink。`roles/` 是 `--ignore-existing`，既有專案不會拿到「碰到 bug 先讀 methods/debugging.md」那一行——真正對既有專案生效的載體是首輪提示，升級後立刻生效。

## 0.8.1 — 2026-09-19

- refactor(review): 審查的 spawn 迴圈收進 `lib/review.sh`，`dk-review` 與 `dk-brief-review` 不再各養一份。兩支原本有 14 行逐字重複 —— 別名指派、`dk-spawn` 呼叫與 rc 捕捉、prompt-failed 三分支、`spawned` 累積、結尾的 `dk_die`／`dk_process`／`echo` —— 真正不同的只有 `dk_render` 那一句與訊息裡的名字。0.8.0 已評估過抽法可行但選擇先出貨，這一版收掉。
- 切法是兩段：呼叫端自己跑 render 迴圈把切片產齊，`dk_review_spawn` 只管派 —— 它假設 `briefs/reviewer-<別名>.md` 已經在那裡。沒有回呼、沒有 eval，bash 3.2 相容（用位置參數走訪別名，不用陣列索引）。順手也抽了 `dk_review_aliases`：只抽 spawn 迴圈的話，render 迴圈會變成 `for k in $use` 卻不用 `k`（shellcheck SC2034），而用 `disable` 蓋掉一個**真的沒用到**的變數是在掩蓋味道；抽出來之後兩邊的 `i` 計數一起消失，「別名清單與 kind 清單一一對應」也有了明確的出處。
- **行為一個字都沒變**，而且是量過的：`tests/unit/20_review.bats` 與 `28_brief_review.bats` 共 24 筆的 TAP 輸出，重構前後逐字相同。這兩支對那 14 行的三個分支（正常、prompt-failed、全數 spawn 失敗）都有測試蓋著，所以那份綠是真的擋得住事的綠。`dk-review` 48→37 行，`dk-brief-review` 45→34 行。
- 測試：354 bats（±0 —— 純重構不該需要新測試，需要的話就表示它不是純重構）；shellcheck 零警告。
- 升級：照 README 的 rsync 流程走即可。只動 `lib/` 與 `bin/` 兩支腳本，沒有新檔案、沒有新 symlink、`settings.env` 沒有新鍵。從 0.8.0 升上來的人不會看到任何行為差異。

## 0.8.0 — 2026-09-19

- feat(plan)!: **計畫本身現在也會被第二個腦袋看過。** 執行階段每一波都有多模型審查閘（`dk-review`），但 `brief.md` 從來沒有 —— 領導寫完、跑過 `dk-brief-check`（機械閘、零 token）就直接到關卡①請人拍板，而那時所有人都還沒開工，改起來最便宜。新增 `dk-brief-review`：派 2–3 個不同 kind 的 reviewer 讀「需求原文 + brief」，各自出一份固定格式的意見，領導一輪收齊後裁定、改 brief，才准過關卡①。
- 它**不是第四個階段**。領導仍然只有 brain / plan / run 三個階段：`dk-brief-check` 與 `dk-brief-review` 是同一層的兩道閘，審的是同一個物件，一個用 shell 驗形狀，一個用模型看內容。名字跟著物件走，所以叫 `dk-brief-review` 而不是 `dk-plan-review` —— `plan.md` 這個一等公民在目前版本還不存在。別名固定 `p1 p2 p3` 而不是 `a b c`：後者會被每一波的 `dk-review` 覆蓋掉 `state/reviewer-a.*`。
- feat(task-new): 需求原文逐字落檔成 `request.md`，成為任務資料夾的一等公民。`--from` 指向可讀檔案時逐字複製，否則產一份指導抄錄的空殼。計畫審查要回答的是「這份計畫做出來會不會是人要的東西」—— 沒有原文，reviewer 只能拿 brief 審 brief。
- feat(gate1): 沒有計畫審查的結果就不放行關卡①。`process.md` 缺 `brief-review` 的 verdict／skipped 行、verdict 沒交代每一位**真的派出去**的 reviewer、計畫審查的 pane 還沒關乾淨，三者任一都拒絕。
- fix(gate1): 三筆實作與審查當場打出來的缺陷。**空殼判斷**：`dk-task-new` 沒給 `--from` 時一定會 render 出約 300 bytes 的空殼，`[ -s ]` 在這條最常見的路徑上恆真 —— reviewer 因此拿著一段「叫人去抄原話」的說明文字當需求原文在審計畫；改用空殼最後一行的 sentinel 判斷是否真的填過。**閘 2 的時序**：`process.md` 是 append-only，verdict 之後可能又補一行 skipped（派完才熔斷），這時最新的決定是「跳過」；原本只挑最後一行 verdict 去逐別名檢查，會拿陳舊的 verdict 挑錯、跟已經放行的閘 1 互相矛盾，把領導卡死在補一份已經不需要的裁定上。**錨定**：改好時序後用 `case *" brief-review verdict"*` 認那一行，但那是子字串比對 —— skipped 的自由文字只要提到「brief-review verdict」幾個字就被誤判成裁定，等於用另一種觸發條件把同一個死結裝回去；改成對該行重新錨定的 `^[^ ]+ brief-review verdict`。
- feat(msg): **dev 的 `[DONE]` 只落盤，不逐筆吵領導。** 每一則訊息送達都是把對方整個 context 重跑一輪 user turn —— 本文兩百字不是成本，對方累積的 context 才是。四人波就是四次全量喚醒，而領導在收齊之前做不了下一步（`dk-review-pack` 要的是整波的差異）。改由 `dk-watch` 在本波 dev 全員 `status: done` 時推一則聚合。刻意**不**降的三種：`[DECISION]`（員工 ESCALATE 後在等的答案，員工不讀 log，降了就永遠卡著）、`[FIXED]`（領導靠它決定何時重打差異包請 reviewer 複看）、dev→qa 的 `[DONE]`（qa 等它才開工）。真相來源是 state 檔不是訊息，與 `dk-wave-close` 的 gate 0 同一個。換傳輸層省不到任何 token，要省的是喚醒次數。
- 配套兩個閘：`dk-msg` 對「state 還沒 done 就送 `[DONE]`」當場 exit 2（少了它，那則 DONE 沉進 log，而 `dk-watch` 也因為 state 沒 done 不推聚合，整波會靜悄悄卡到整波逾時才有人吭聲）；`dk-wave-close --agent` 重置 `.devdone` 標記（被單獨關掉的多半是撞額度、等著換 kind 重派的，標記若停在 delivered，補上的那位做完也不會再有人通知領導）。
- fix(kinds): agy 不再停在工具審批。實跑症狀是 agy 員工經常卡在 `Requesting permission for: rg …`，而 `dk-watch` 只能推 `[BLOCKED]` 叫人去按。agy 1.2.6 沒有 claude `auto` 的等價檔位 —— `--mode` 只吃 `accept-edits` 與 `plan`，而 `accept-edits` 只放行編輯，每一個 shell 指令都要人按。claude 在 0.2.2 撞過同一面牆並改成 `auto`，codex 走 `-a never`，只有 agy 一直留在等價於 `acceptEdits` 的設定上。逐條往 `permissions.allow` 補追不完（按指令字串前綴比對，`git diff <sha> -- <path>` 各記一條，`dk-msg` 那條還綁死絕對路徑、換專案即失效）。三個 kind 至此對齊同一句話：**員工是無人看管的 pane，邊界由 worktree 隔離、`dk-wave-close` 的真實 diff 所有權比對與 git 來撐，不是靠 CLI 的審批 UI**。`--sandbox` 不能拿來補這個邊界 —— 實測它把檔案系統視角搬到 `~/.gemini/antigravity-cli/scratch/`，員工看不到自己的 worktree；新增的測試同時擋住未來有人想用它。另一個根因（agy 的 `trustedWorkspaces` 逐路徑精確比對、不繼承上層）是互動模式才有的對話框，headless 測不到，記進 `decisions.md` 等下次實跑確認。
- fix(watch): **複看的 reviewer 不再永久靜默，逾時量的是這一輪。** panova2 實跑查到、0.6.2 刻意排進 BACKLOG 的兩筆，其實是同一個語意缺陷的兩個出口：`.panes` 的 epoch 被當成「spawn 時間」寫入，卻被 `dk-watch` 與 `dk-resume` 當成「這一輪等了多久」在讀。reviewer 交完首輪後被派複看，它的 state 還停在上一輪的 `status: done`，而逾時分支對 done 無條件 `continue` —— 熔斷、桌面通知、送領導的 `[TIMEOUT]` 三個出口全程空轉。而**只修這一條會更糟**：第二輪的 epoch 不重置，複看一派出去就已經超過 `DK_REVIEW_TIMEOUT_MIN`，當場誤判逾時並熔斷一個活得好好的 kind。兩者必須一起修。
- 現在 `dk-msg` 送達 `[TASK]` 後重設該列的 epoch，epoch 就此正名為「最後一次指派」。只在**送達後**重設：送不到的指派沒有開始任何一輪，先重設只會把卡住的人藏起來。同時清掉上一輪的 `.timeout`（留著的 `delivered` 會讓這一輪永遠不再報），並存下 state 此刻的 `cksum` —— `dk-watch` 靠「內容有沒有變過」分辨這一輪交的 done 與上一輪留下的 done；沒有那個標記就表示它從沒被重新指派過，首輪的 done 照樣算數。為什麼**不**用 mtime：`date -r` 在 GNU 與 BSD 語義不同，`dk-chore-tidy:24` 已經為同一個理由裁定過一次。為什麼**不**由 `dk-msg` 把 state 的 `status` 改回 `working`（最短的那條路）：`PROTOCOL.md:34` 寫死「只有本人能寫自己的 state 與 report 檔」。重設對所有 `[TASK]` 收件者生效而不只 reviewer —— 壞掉的是 epoch 的語意本身，`dk-resume` 的 `TIMEOUT?` 讀的是同一欄。
- refactor(review): 抽出 `lib/review.sh`（`dk_review_tier`、`dk_review_kinds`）供兩支審查腳本共用。兩者的 spawn 迴圈仍有 14 行逐字重複，已評估兩段式抽法可行，這一輪選擇先出貨 —— 記在 BACKLOG，下次動這兩支任一支時一起收。
- 測試：354 bats（+50）；shellcheck 零警告。新增 `tests/helpers.bash` 的 `refute_grep`：bats 跑在 `set -e` 下，而 POSIX 規定 `! cmd` 這種形式豁免 `set -e`，所以 `! grep -q x file` 這樣寫的否定斷言只要不在測試最後一行，**命中了也照樣 ok** —— 這個 repo 裡好幾條斷言一直是假的。用一個普通函式回非零，`set -e` 才抓得到。
- 升級：照 README 的 rsync 流程走即可。這一版沒有新 skill，`.dkbo/install.sh` 沒有新 symlink 要建（照跑無害）；`settings.env` 也沒有新鍵。**一個要自己看的地方**：更新指令對 `roles/` 是 `--ignore-existing`（只補新角色、不覆蓋既有），所以既有專案的 `roles/reviewer.md` 仍是舊的單行職責，不會拿到「計畫審查」那一段。這不影響計畫審查跑得起來 —— 格式的載體是 `templates/brief-reviewer-plan.md`（在覆蓋範圍內），角色檔那段是給新專案的；想同步的人自己 diff 一次即可。

## 0.7.0 — 2026-09-16

- feat(entry)!: **升級後開新 session 不再自動變成領導。** 舊行為是 `AGENTS.md` 的入口行 → `ENTRY.md` → `LEADER.md`，於是任何在專案根目錄開的 session 一啟動就被 61 行領導規範接管，想在同一個專案做別的事得先跟它拔河。現在 `ENTRY.md` 的 `leader` 分支只告訴你「這個專案裝了 dkbo」並列出三個 skill，不再指向規範檔。要開團隊流程得自己叫：`/dkbo-brain`（諮詢、分流、雜務、評議波）、`/dkbo-plan`（開任務到關卡①）、`/dkbo-run`（派工、跑波、審查、結案）。
- refactor(leader)!: `LEADER.md` 從 61 行瘦身成三階段共用的部分（領導硬邊界、`dk-*` 位置、`settings.env` 八鍵、裁定格式、階段導航、上下文吃緊怎麼辦），階段規範搬進 `skills/{brain,plan,run}/SKILL.md`，每篇第一行都是「先讀 `.dkbo/LEADER.md`」。共用段落只有一份，改一次改一處 —— 0.6.1／0.6.2／0.6.3 動的都是這類段落，抄三份必定不同步。
- fix(resume): `dk-resume` 的指路從命令句改成條件句（「若你要接手推進，先讀…」）。`ENTRY.md` 聲明它是唯讀看板，它自己就不能反過來命令一個只想看狀態的 session 接管。
- fix(leader-cmd): `dk-leader` 開第二位領導的第一則提示改成「讀 `.dkbo/LEADER.md` 與 `.dkbo/skills/plan/SKILL.md`」。走 SKILL.md 路徑不走斜線指令 —— 那個 pane 可能是 codex 或 agy。
- fix(docs): 更新用的 rsync 拿掉 `--exclude=LEADER.md`。該排除的理由是「`/dkbo-init` 已客製過它」，但 init 自 0.2.0 起就不再改寫 `LEADER.md` 的 prose，這條排除會讓升級漏掉新版規範。
- 測試：304 bats（+2）；shellcheck 零警告。新增兩筆：`ENTRY.md` 的 leader 分支要講明「你不是領導」、`install.sh` 要把五個 skill 都接進兩個 skill 目錄；原本斷言 `LEADER.md` 內容的那幾筆，改成斷言三篇階段規範各自涵蓋自己的命令。
- 升級：照 README 的 rsync 流程走即可，**最後一步的 `.dkbo/install.sh` 不能省** —— 三個新 symlink 靠它建。`AGENTS.md` 的入口行不用改。跳過這步不會報錯，是安靜失效：新版 `ENTRY.md` 不再自動把人接管成領導，而三個 skill 的 symlink 還沒建，於是 dkbo 什麼都不做、也不告訴你哪裡錯了。

## 0.6.3 — 2026-09-14
- fix(spawn): qa 不再對半成品下驗收判定。同一場 `panova2` 實跑：波 1 的 frontend 與 qa 在 07:20 同一秒 spawn，qa 07:27 讀到 helper 收斂只做了一半的 worktree，判定 AC5 沒過、發 `[QUESTION]` 問「現在能開始驗還是等你收斂完」，然後停在那裡——07:39 才收到 frontend 的「你看到的是收斂前快照」。**12 分鐘空轉，外加一份假的驗收失敗**。
- 根因是三層都沒有人告訴 qa 要等：`templates/brief.md` 的波次表只說「同一波的列相鄰」，沒說 dev 與 qa 不能同波（panova 的 brief 完全照著寫）；`dk-wave-open:17` 的 `for m in $members` 一次把全波 spawn 完，沒有順序概念；`dk_first_prompt` 說的是「讀完後**開始做**分給你的項目」，`roles/qa.md` 說的是「依 brief 驗收標準**逐條驗證**」。qa 對半成品下判定，是完全照著 dkbo 的指示做的。
- 為什麼**不**照 BACKLOG 原本寫的「延後 spawn `group: review` 的成員」：qa 有一大段不依賴 dev 產出的前置，而且是 role 檔明文要求的——起環境、測試帳號、mobile/桌面兩種 UA、探測腳本骨架。延後 spawn 會把這段時間整個丟掉，而那正是並行的價值。真正錯的只有一件事：**qa 不知道自己的驗收依賴誰、那個人交差了沒**。所以閘門是「知情」不是「延後」：新增 `dk_brief_wave_upstream`（同一波裡 `group: dev` 的成員），`dk-spawn` 把它算出來餵進首輪提示——不擋前置，只擋判定。
- 為什麼主要載體是**首輪提示**而不是 `roles/qa.md`：更新 dkbo 的指令是 `rsync -a --exclude='roles/*'` 加 `rsync -a --ignore-existing roles/`——**角色檔只補新的、不覆蓋既有**。任何像 panova 那樣把 `roles/qa.md` 擴充成自己版本的專案，升級後永遠拿不到寫在角色檔裡的修正，這個洞會一直留著。`lib/prompt.sh` 在覆蓋範圍內，升級就生效。角色檔骨架同步加了一條，那是給新專案的。
- reviewer 不受影響：它不在波次表裡（由 `dk-review` 派、`--isolated` 讀收齊後的 diff pack），`dk-spawn` 的條件明確要求該成員真的被排進這一波才帶上游。
- fix(brief): `dk_brief_wave_upstream` 的迴圈最後一位不是 dev 時，`[ … ] && echo` 會讓函式回非零，呼叫端在 `set -e` 下整支退出——寫測試時當場踩到，結尾補 `return 0`。同型的 `&&` 結尾在這個 repo 裡不只一處，值得下次順手掃。
- 測試：302 bats（+8）；shellcheck 零警告。

## 0.6.2 — 2026-09-14
- feat(watch): 守望改看畫面，不再只信 herdr 的 `agent_status`。實跑事故：`panova2` 的 paramleak 任務，reviewer-c（agy）停在權限審批 UI —— 畫面上白紙黑字寫著 `Requesting permission for: rg …` 與 `Run this command?` —— 而 `herdr agent get` 回的是 **`idle`**；reviewer-b（codex）撞到 `You've hit your usage limit`，回的也是 **`idle`**。dk-watch 的 blocked 偵測唯一的訊號就是 `agent_status == blocked`，於是 `DK_BLOCK_SEC=60` 的安全網、桌面通知、送領導的 `[BLOCKED]` 三個出口對這兩個 kind **全程空轉**，`.blocked/` 底下一個標記檔都沒生出來。領導等了 20 分鐘，等到的是逾時兜底，不是安全網 —— 而它一直以為那兩位還在工作。
- 根因不在 herdr 壞掉，而在 dkbo 把「卡住」押在一個只認得部分情況的訊號上。herdr 自己的文件寫得很清楚：`blocked` 是「Herdr recognized an approval or question UI」—— 認不認得出來，取決於它有沒有為那個 CLI 寫過 detector。agy 的審批 UI 它沒認出來，codex 的額度畫面根本不是審批 UI。唯一不會騙人的是**畫面上印出來的字**。現在每個 kind 在自己的 `kinds/<k>.sh` 宣告 `KIND_BLOCK_RE` 與 `KIND_QUOTA_RE`（`dk_kind_re` 讀，未知 kind 退回通用式、絕不回空 —— 空式子會讓 `grep -E ''` 命中每一行，把守望變成「所有人都卡住了」），`agent_status` 退成第二訊號：claude 的審批它認得，留著沒壞處。
- feat(watch): 新增 `dk-watch --events`，走 herdr 的事件訂閱而不是輪詢。`herdr pane wait-output --regex` 底層就是 socket API 的 `pane.output_matched` 訂閱，畫面一冒出審批或額度字樣就回來，不必等下一個 tick。`dk-task-new` 與 `--ensure` 現在起兩條獨立的命脈 —— 30 秒輪詢（`DK_WATCH_PID`）與事件訂閱（`DK_EVENTS_PID`）—— 一條死了另一條還在；`dk-task-close` 兩條都收。
- 為什麼**不**直接對 herdr 的 unix socket 講 `events.subscribe`：那要新增一個 socket client（python 或 socat），而 dkbo 到今天為止只依賴 bash 3.2／jq／git／herdr 本身。`pane wait-output` 是同一個訂閱的 CLI 包裝，而且測試能用現成的 herdr stub 演。為什麼**輪詢不拿掉**：訂閱是長連線，herdr 一升級重啟它就沒了 —— 事故當下領導 pane 上正掛著 `Update installed · Restart to apply`。推送是快路徑，輪詢是慢但不會消失的底，跟 0.5.2「訊息投遞不再押在一個會掉的名字上」是同一種教訓。
- fix(watch): 撞額度不必再等 `DK_REVIEW_TIMEOUT_MIN`。額度偵測本來埋在 reviewer 逾時分支裡，要先耗滿 20 分鐘才會去讀畫面 —— 而那行字在撞到的當下就在畫面上了。現在它是獨立的一條，任何員工（不只 reviewer）撞到就當場熔斷該 kind 並推 `[LIMIT]` 給領導。新的訊息型別寫進 `PROTOCOL.md` 與 `LEADER.md`：`[BLOCKED]` 是等人按一下，`[LIMIT]` 是按審批也救不回來，處置不同，不要當成同一件事。
- fix(watch): reviewer 逾時不再把「在等人按審批」誤判成「這個 kind 掛了」。事故裡活得好好的 agy 被寫進 `DK_KIND_DOWN`，之後的整分支評議只剩 claude 一家 —— 少掉的那兩份意見不是因為沒額度，是因為守望把它斬了。逾時觸發時先讀畫面：命中審批特徵就只報 `[BLOCKED]`，不熔斷。
- 排進 BACKLOG 三筆（同一場實跑查到、這一版刻意沒做）：dev 與 qa 同波並行導致 qa 對半成品驗收、逾時分支對 `status: done` 的無條件 skip、`.panes` 的 epoch 不隨第二輪派工重置。
- 測試：294 bats（+17）；shellcheck 零警告。stub 的 `agent_read.json` 預設畫面從「撞額度」改成中性 —— 新的 tick 會讀每一個員工的畫面，預設帶著額度字樣的話，每個測試裡的每個人都會被判成撞額度。三個真的要測額度的測試改成自己講明白（`quota_screen`），不再隱性依賴 stub 的預設值。`teardown_project` 收拾 `--ensure` 起的背景行程，否則它們會在後面的測試裡繼續消耗 pid —— 兩個認 pid 的 `--ensure` 測試就是這樣間歇性紅的。

## 0.6.1 — 2026-09-13
- fix(chore): 雜務員工現在知道執行環境是全隊共用的。實跑事故：`chore-qa-21`，一件交代明寫「探測切換球種的 API 與 WebSocket 幀序，**不改 src/**」的唯讀 QA 雜務，跑去 `kill` 主樹的 dev server 進程並 `nohup pnpm dev` 重啟，接著去探別的 worktree 的 9001 埠。兩次都被 auto mode classifier 判 `[Interfere With Workloads]` 擋下 —— **它判對了**。主樹上有領導，其他 worktree 裡有同事，而那台 dev server 是所有人共用的。
- 洞在於：任務那側 `brief.md` 有「獨佔資源」欄（`db`、`port:3000`、`docker`…，模板原話：「worktree 隔離檔案，不隔離執行環境」），而**雜務沒有 brief** —— `dk-chore` 的提示叫員工讀 `roles/<role>.md`、`PROTOCOL.md`、`PROJECT.md`，三份沒有一份提過這件事。員工發現 dev server 卡住就去重啟它，是完全合理的推論；沒有人告訴過它那是共用的，也沒有人給過它一條合法路徑。現在提示與 `PROTOCOL.md` 的雜務段各補一條，並指向 `dk-msg leader "[ESCALATE] …"`。
- fix(kinds): `codex` 與 `agy` 補上 `--add-dir $DK_PROJECT_ROOT`。員工的 cwd 是 worktree，但切片、state、report、diff pack 全在主樹的 `.dkbo/` 下 —— `claude.sh` 早就寫明這一點並補了旗標，另外兩個漏掉：codex 的 `-s workspace-write` 與 agy 的 `--mode accept-edits`，primary workspace 同樣只有 worktree。三個 CLI 的 `--help` 都有 `--add-dir`。這個缺口一直沒被觸發，是因為 agy 只當過 reviewer（唯讀），而 codex reviewer 在 0.5.2 修掉那個投遞洞之前**一次都沒真的收到過任務**。
- 為什麼**不**照原始需求「在 init 就把三個 CLI 的權限放寬」：查下去發現被擋的動作本來就該擋。放寬只會讓下一個員工成功 kill 掉領導腳下的 dev server —— 0.3.1 已經因為同類事故丟過一次未 commit 的改動。截圖上那個看似無辜的 `curl localhost:9000` 是同一串的第三次，「3 consecutive actions were blocked」是累積計數要人去看 transcript，不是那條 curl 危險。
- 查證紀錄進 `decisions.md` 三則：classifier 這次判對了、Claude Code 權限的三個硬事實（`permissions.allow` 擋不住 classifier；專案層 permissions 需要 workspace 被信任過，信任按路徑前綴繼承所以 `DK_WORKTREE_DIR` 設到專案外會靜默失效；`settings.local.json` 常被 gitignore 擋著、worktree 裡不存在）、三個 kind 都要 `--add-dir`。
- chore(backlog): 清掉 5 筆 —— 自主巡檢那筆移除，4 筆「已裁定不做」的把裁定理由搬進它們該在的位置後刪除（`&` 測試是 tripwire、`$(cat)` 比對今天不可達 → 寫進 `01_common.bats`；六個呼叫點措辭要一起改 → 寫進 `common.sh`；那一行冗餘斷言 → 直接刪掉，比留個註解說它冗餘乾淨）。BACKLOG 從 9 筆降到 3 筆，剩下的每一筆都真的還有事要做。
- 測試：277 bats（+3）；shellcheck 零警告。

## 0.6.0 — 2026-09-13
- feat(chore): 雜務檔改成一天一夾。實跑三天累積 33 個 `.md` 平躺在 `_chores/` 底下，展開就是一面牆；日期本來就寫在每個檔名前面，把它提到資料夾上，檔名就只剩內容（`_chores/2026-09-10/commi.md`）。`dk-chore-close` 的 legacy 反查改掃兩層，0.5.0 之前留在根層的舊檔照樣關得掉。
- feat(chore): 新增 `dk-chore-tidy`。根層舊檔歸位到日期資料夾、`messages.log` 整份 append 進 `archive/YYYY-MM.log` 後清空。兩件事合成一支指令，是因為它們的前提是同一個：`.sessions/chores/` 非空就拒絕。搬走在途雜務的檔會讓記錄檔的 `file=` 失效，截斷 log 會讓它的 `logline=` 指錯行 —— 一道閘門同時擋住兩種壞法，而閘門成立時「整份歸檔」才是安全的（沒有任何 `logline=` 指著它）。收掉 BACKLOG 那筆「`_chores/` 只增不減、沒有歸檔機制」。
- feat(chore): agent 編號改成回收最小可用號。舊的 `count(_chores/*.md) + 1` 只增不減，跑到第 33 件就是 `chore-qa-33`；而編號真正要保證的只有「同時在跑的不撞」，那件事的真相是 `.sessions/chores/<agent>`（存在 ⟺ 它還在跑），不是雜務檔的數量。改成從 1 找第一個沒被佔的號之後，號碼永遠停在同時在跑的件數（實務上個位數），而且**編號與檔案佈局徹底脫鉤** —— 0.5.1 修的那個撞號情境（人整理過 `_chores/`，編號重算回同一個數字，新雜務撿到上一輪的 `[DONE]`）從根本上不再可能發生。`logline=` 留著，它現在守的是更窄也更明確的一件事：陳舊 `[DONE]` 不算數。`dk-chore:40` 的「執行記錄已存在」守衛從主要防線退成 race 保險，刻意不刪。
- fix(chore): 雜務檔的防撞後綴從 `-$n` 改成在該日資料夾內遞增找空位。這是上一條引進的洞：`$n` 現在會回收，同一天同 slug 的第三件會算出跟第二件一樣的 `-1` 檔名，而舊寫法 `[ ! -e "$cf" ] || cf="${cf%.md}-$n.md"` 只試一次就放棄 —— 第三件會靜靜覆蓋掉第二件的雜務檔。
- 為什麼 `messages.log` **不**跟著切日期：一件 23:50 開、00:10 回報的雜務，`[DONE]` 會落在隔天的檔裡，而 `dk-chore-close` 的閘門在今天的檔裡找不到它 —— 關不掉。活躍的 log 只有一份，跨午夜就不是問題；增長由 `dk-chore-tidy` 處理，那是有閘門保護的明確動作。
- 為什麼舊檔**不**自動搬：`dk-chore` 每次都偷偷搬一次檔案，等於讓一個派工指令兼差做檔案系統手術，而且它跑的時候正好有雜務在跑（自己那件），閘門條件天生不成立。tidy 是人明確跑的。
- 其他目錄**不動**：`tasks/<日期>-<short>/` 早就一任務一夾，任務內的 `state/`／`briefs/`／`waves/` 隨任務有界（實跑最多 10 個檔）、跑完整夾歸檔；`.sessions/chores/` 是短命執行記錄，關掉就刪。扁平累積的從頭到尾只有 `_chores/` 這一處。
- 測試：274 bats（+9）；shellcheck 零警告。

## 0.5.2 — 2026-09-12
- fix(msg): 收件者名字對不上 herdr 時，訊息不再靜默全滅。`sport-frontend-panova` 的 sportswitch 任務實跑，`messages.log` 13 筆有 **12 筆 `[UNDELIVERED]`** —— 唯一送到的那筆是領導放棄 `dk-msg`、改用 `herdr agent prompt` 直送的。兩個方向各壞一邊，而且是兩個獨立的洞：(1) 員工的 `dk-msg leader` 被 `dk_leader_name` 解析成 `leader-<short>`，但領導 pane 在 herdr 裡的 `name` 是 `null`，`herdr agent get leader-sportswitch` 回 `agent_not_found`；(2) 領導照 `LEADER.md` 的 `dk-msg <reviewer>` 佔位符打了短名 `reviewer-a`／`frontend`，而 `dk-spawn` 註冊的是 `sportswitch-reviewer-a`／`sportswitch-frontend` —— `dk-msg` 只對字面 `leader` 做解析，其他對象原樣丟給 herdr。
- 這個故障穿的是「對方忙到送不進」的衣服：`agent_not_found` 讓 `wait` 與 `prompt` **雙雙**回非零，跟 0.2.3 修的那個「一次就判死」長得一模一樣，所以 0.2.3 加的三次重試在這裡只是把同一個必敗的動作做三遍。`dk-msg` 現在先解析對象（短名補上任務前綴、對 `.panes` 查真名），送不到再退回 **pane id**：那是 herdr 唯一不靠 rename 的把手。對照組就在隔壁 —— `dk-chore` 記的 `leader=w9:p1` 是 pane id，雜務那側的 `messages.log` 幾乎全通。
- fix(watch): 守望的三個出口（`[BLOCKED]`、reviewer `[TIMEOUT]`、整波 `[TIMEOUT]`）同樣走 `dk_leader_name`，同樣全滅。`.blocked/sportswitch-reviewer-b.timeout` 躺在磁碟上、沒有 `delivered`，而領導是自己發現 reviewer-b 沒動的。`notify_leader` 補上 `DK_ROOT_PANE` 退路（雜務那側本來就是 pane id，維持不變）。
- fix(task-new): rename 回 `rc=0` 不等於生效。`dk-task-new` 那行本來就是為「領導 pane 不是 `dk-leader` 開的」準備的補救，21:29 它跑過了、`process.md` 卻一片乾淨 —— 守衛只看 exit code。現在 rename 後把名字讀回來比對，不符就記 `process.md` 並提示訊息改走 pane id。**0.2.3 已經為同一個症狀修過一次**（RESULTS-2026-09-11 ④：「pane 只要曾被命名過就跳過 rename」），那次修的是**要不要做**，這次修的是**做了有沒有成**。
- 下游災情兩筆，都不是它們看起來的那件事：`sportswitch-reviewer-b` 整場沒收到 `[TASK]`、閒置到逾時，被記成 `kind codex down` —— codex 沒壞；`sportswitch-frontend` 三次 `[ESCALATE]` 求授權全部投不到，又被 Stop hook 擋著不能收工，只好自行改了不在它所有權清單裡的 `src/api/sport.spec.ts`（事後由 ruling 追認）。**兩筆都是靜默投遞失敗長出來的假象**，而領導對著錯的原因做了裁定。
- 為什麼**不**只補 `herdr agent rename`（領導在事故現場的救火）：那治的是這一次。pane 是誰開的、herdr 有沒有重連、rename 有沒有生效，都不在 dkbo 控制之內，而失敗是靜默的；名字是**衍生**的把手，pane id 是**原生**的。為什麼**不**讓 `dk-msg` 一律改用 pane id：`messages.log` 那一欄是人與 `dk-wave-close` 在讀的，`w9:pT` 讀不出是誰。名字負責可讀，pane id 負責送達。
- 測試：265 bats（+9）；stub 補上兩件真 herdr 的行為，否則這個故障在測試裡無從被看見：`HERDR_STUB_MISSING` 讓指定對象回 `agent_not_found`，`agent rename` 會真的改變之後 `agent get` 讀到的名字（`HERDR_STUB_RENAME_NOOP=1` 演靜默失敗）。shellcheck 零警告。

## 0.5.1 — 2026-09-12
- fix(chore): 完成訊號綁上這件雜務的生命期。記錄檔多一欄 `logline=`（建立當下 `_chores/messages.log` 的行數），`dk-chore-close` 只看那之後的行。0.5.0 的撞號守衛擋的是「記錄檔還在就拒絕同名」，但有一條路徑繞過它：一件雜務正常跑完關閉後記錄檔就刪了，而它的 `[DONE]` 永遠留在 append-only 的 `messages.log` 裡；等有人整理逐漸變大的 `_chores/*.md`（agent 編號正是 `count(_chores/*.md) + 1` 算出來的），編號重算回同一個數字，新雜務的記錄檔是乾淨的、守衛不會觸發，而閘門會撿到上一輪的 `[DONE]` 立刻放行 —— `--code` 的話等於合併一個員工從沒回報過的分支。`messages.log` 只增不減、`_chores/*.md` 是人會去清的那一個，所以這不是「會不會」而是「什麼時候」。順帶讓閘門對任何陳舊 `[DONE]` 免疫，不只這個情境。
- fix(chore): `dk-chore-close` 在讀取端也驗 agent 名。`dk-chore` 早就有 `[[ "$agent" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]`，但那是**寫入端**；操作者打的字是從 `dk-chore-close <agent>` 進系統的，而 `$agent` 會組成 `rm -f` 的路徑、也會被內插進 `sed` program。同一條規則在讀取端再擋一次。
- fix(chore): `rollback()` 補上雜務檔與記錄檔。它的契約是「還沒有人進去過就清乾淨」，但先前只清 worktree 與分支；`--code` 雜務在 trap 掛上之後、`herdr agent start` 之前若被 Ctrl+C 或磁碟出事，`$cf` 與 `$crec` 會留下來 —— 而 0.5.0 之後「記錄檔存在 ⟺ 雜務在跑」，一個孤兒記錄檔會讓 `dk-watch --chores` 永遠不退出，且那時 `dk_index_add` 還沒跑，INDEX 裡看不到它。
- 這三條都是 0.5.0 最終審查延後、實跑前重新評估後決定收掉的；其餘延後項維持延後。
- 測試：256 bats（+3）；shellcheck 零警告。

## 0.5.0 — 2026-09-12
- fix(chore): 雜務檔不再一檔兩主。實跑收尾發現兩件事——`dk-chore-close chore-it-19` 回 `no chore file for chore-it-19`（員工把雜務檔整份重寫成自己的報告格式，`成員：`／`branch:`／`pane:` 全沒了）；人工補回欄位關掉之後，`tasks/INDEX.md` 那列仍停在 `working`，而 `dk-chore-close` 回了 0。查下來是**同一個結構缺陷的兩個出口**：雜務檔同時裝著系統的識別碼（`成員：` `branch:` `workspace:` `pane:` `leader:`）與員工的進度（`status:` `touched:` `結果：`），而 `dk-chore` 的第一段提示與 `PROTOCOL.md:60` 正是叫員工去寫那個檔案的。員工要「更新」一個檔案，最自然的動作就是重寫整份。對照組是任務那側：`dk-spawn` 把 agent→pane 寫進 `.panes`，員工從不碰它——**雜務沒有 `.panes` 的對應物**。
- 另外三個出口當時沒被觸發：(1) `dk-watch --chores` 同樣從雜務檔 `sed` 出 `成員：` 與 `leader:`，員工重寫後那件雜務靜默地從 blocked 名單消失；(2) 更糟的是 `[ "$working" = 1 ] || exit 0` 的 `working` 來自掃描所有雜務檔的 `^status: working`，**一個員工重寫自己的檔案會讓整個守望行程退出，連帶放掉同時在跑的其他雜務的 blocked 偵測**；(3) 若 `成員：` 僥倖留著而 `branch:` 掉了，`git merge --no-ff ""` 失敗會吐出 `merge conflict on ; ask the human`——訊息是錯的，而 `herdr pane close ""` 靜默 no-op、pane 留著不關。五個出口裡只有 `no chore file` 那個會誠實報錯。
- feat(chore): 執行狀態搬到 `.dkbo/.sessions/chores/<agent>`（gitignored，`key=value` 純文字，用 `sed` 讀**不 source**——`instr` 來自領導打的字，可能含引號與 `$`）。完成訊號改讀 `tasks/_chores/messages.log` 的 `[DONE]` 行（`dk-msg` 寫的，員工的 markdown 碰不到；`[UNDELIVERED]` 也算完成，因為員工確實交差了只是投遞失敗）。雜務檔從此**整份是員工的，機器完全不讀**。收尾從 `sed -i` 改成 append 一行 `關閉：<時間> done|abandoned — <結果>`：append 不管員工把檔案改成什麼樣都會成功。
- fix(index): `dk_index_set` 沒命中時回非零，六個呼叫點全部接上警告。名稱是 INDEX 的主鍵，而主鍵對不上是靜默的——這是上面第二件事能活到事後才被發現的原因，而六個呼叫點裡有四個在任務那側（人手動整理過 `INDEX.md` 就會踩到同一顆雷）。
- 為什麼**不**把提示語寫得更嚴厲叫員工別重寫整份檔案：那是把正確性押在一個 LLM 對格式的自制力上，對不同 kind、不同檔位、不同上下文長度的員工效果不同，而失敗是靜默的。為什麼**不**多加幾條 fallback 反查（用 branch 或 pane 倒推 agent）：那是在同一個壞結構上疊防線，真相仍住在員工的寫入面，每加一條「真相在哪」就更模糊一分。為什麼**不**給 INDEX 加 id 主鍵：名稱現在由記錄檔供應、開檔時寫一次就不再變，主鍵已經穩定，要補的是失敗的音量不是主鍵。
- `dk-chore-close` 保留 legacy 分支（0.5.0 之前開的雜務沒有記錄檔，走舊的 grep 反查 + `status: done` 閘門），但 **`dk-watch` 刻意不做**：做了就等於「誰在跑」又有兩個真相來源，正是這次要消滅的病。在途舊雜務升級後失去 blocked 守望直到被關掉為止，關閉不受影響。
- 已知代價：雜務檔的 `status:` 從此可能永遠停在 `working`（那是員工的欄位，機器不再改它，真相在 `關閉：` 那行與 INDEX）；員工做完卻忘記跑 `dk-msg` 就關不掉（`--abandon` 會跳過 merge），不加 `--done` 人工覆寫是刻意的——那等於在新界線上開一個後門。
- fix(chore): 最終審查收掉這次改動自己新開的兩個出口（同一個結構缺陷的殘餘）。`[DONE]` 的判定從此錨定在行首的 timestamp（`^[^ ]*`），不再是不設防的 `^.*`——員工可寫的訊息本文含一句偽造的 `-> … [DONE] …` 就能騙過閘門，正是這次要消滅的病換了個地方。`dk-chore` 撞號時（員工刪了自己的雜務檔，agent 編號重算撞上正在跑的那個）現在會先拒絕，不會覆蓋或牽連活著的執行記錄。記錄檔寫入改成 `.tmp` + `mv` 的原子寫，`dk-chore-close` 對 legacy 分支的空 `branch` 也加了防呆，不再把「記錄檔遺失」誤判成「merge 衝突」。
- 測試：253 bats（+13，其中三條是事故本體：員工重寫雜務檔後仍關得掉、員工刪掉雜務檔後仍留下可 commit 的記憶、員工重寫雜務檔不影響守望名單；另兩條是最終審查加的：偽造的 `[DONE]` 不算數、撞號時拒絕且不留第二個 pane）；shellcheck 零警告。

## 0.4.0 — 2026-09-12
- feat(review): 新增第八個設定鍵 `DK_REVIEW_TIER`（`M` 或 `L`，預設 `M` 維持相容）。`dk-review` 的檔位改從它來，`--tier` 仍逐次覆寫。審查是全隊最吃推理的位置，卻跟 dev 同樣預設 M；而 reviewer 是 `--isolated` 唯讀、只讀一個 diff pack + brief、單輪，升到 L 的邊際成本遠低於一個要跑 20–60 分鐘的 dev pane。現在這是一個設定，不是一次改角色檔的手術。
- 為什麼**不**把 `roles/reviewer.md` 的 `M: sonnet/medium` 直接改成 `opus/high`（這是收到的原始提案）：`dk-review` 收 `--tier M|L`，兩個值會解析到同一組旗標，旗標變成**靜默的 no-op**；結案評議的 `dk-review --task --tier L` 從此與例行波審查無異，失去加碼的意義；而 tier 在別處一律是「切片難度」（`dk-spawn`、`dk-chore` 都預設 M），讓某一個角色的 M 改指頂配，同一個字在不同角色就不同義。審查政策本來就住在 `settings.env`（`DK_REVIEW_KINDS` / `DK_REVIEW_MIN` / `DK_REVIEW_TIMEOUT_MIN`），第四把鑰匙也該放在那裡。
- `/dkbo-init` 第 3 步改問八鍵，並在問 `DK_REVIEW_TIER` 時要求先確認 `DK_REVIEW_KINDS` 已有第二個 kind：**密度先於天花板**。0.2.2 加 `dk-wave-close` 第五道閘，正是因為實跑兩波都派了 claude + codex、兩波都只有 claude 進裁定，`DK_REVIEW_MIN=1` 讓領導每次都合法地靜默放行，多模型審查的實際生效率是 0。換一個不同模型抓到的錯誤類別，跟同一個模型想得更久抓到的，不是同一批。
- 測試：240 bats（+6，其中一條釘住出廠預設仍是 M、一條釘住 `roles/reviewer.md` 的 tier 語義沒被動過）；shellcheck 零警告。

## 0.3.1 — 2026-09-12
- fix(chore): `dk-chore` 不再把正在工作的員工腳下的 worktree 與分支刪掉。兩個缺陷疊在一起造成一次實際的資料遺失（`sport-frontend-panova` 的 `chore/chore18`，員工改完 `GameModule.vue` 尚未 commit，整個 worktree 與分支消失，`git branch -a` 也查無此分支）：(1) 第一段提示用的是 `--wait --timeout 60000`，而 `herdr agent prompt --wait` 的預設語意是等**這一輪跑完**（`--help`：matches idle, done, or blocked），任何真的要動手的雜務第一輪都超過 60 秒，於是必然回 timeout；(2) 那個非零在 `set -e` 下觸發了還掛著的 `trap rollback EXIT`，rollback 執行 `worktree remove --force` 與 `branch -D`。**0.2.2 已經針對 `dk-spawn` 修過同一條**（「等這一輪結束 ≠ 提示送到了沒」），但 `dk-chore` 與 `dk-leader` 兩處漏掉了；在 `dk-chore` 這一處它不只是誤判，而是會毀掉工作。
- fix(chore): rollback 的契約收斂成「還沒有人進去過就清乾淨」——`herdr agent start` 一成功就 `trap - EXIT`，而不是拖到腳本最後一行。此後任何一步失敗（`dk_index_add`、`dk-watch`、Ctrl+C）都只報錯不動 worktree：那裡有一個活著的 agent 和它還沒 commit 的改動。提示失敗時 pane 與 worktree 都留著，INDEX 也已寫入（在提示之前），領導可以讀 pane 診斷後重送提示，或 `dk-chore-close <agent> --abandon` 收乾淨。
- fix(leader): `dk-leader` 的第一段提示同樣改成 `--wait --until working --timeout 15000`。領導第一輪要讀 `LEADER.md`、跑 `dk-task-new`、開始寫 brief，一定超過任何合理逾時；舊行為讓一個開得好好的領導 pane 被回報成失敗。這一處沒有破壞性 trap，只是誤報。
- 前例：`_chores/messages.log` 顯示 09-10 23:45 `chore-translator-12` 出過形狀相同的 ESCALATE（`chore-hi-in-144-key` 環境消失）。同一個坑吃掉兩次雜務。
- 測試：234 bats（+3）；shellcheck 零警告。

## 0.3.0 — 2026-09-11
- feat(brief-check): 檔案所有權表新增「獨佔資源」欄（`db`、`port:3000`、`docker`…，逗號分隔），同一波內兩位成員宣告同一個資源即 FAIL。worktree 隔離檔案，**不隔離執行環境** —— 同波兩位 dev 仍會對同一個 dev DB 跑 migration、搶同一個 port、重啟同一組 docker。舊的三欄 brief 照常通過（欄位缺就是沒宣告）。
- feat(watch): 新增 `DK_WAVE_TIMEOUT_MIN`（第七個設定鍵，預設 60 分鐘，0 表示關閉）。`dk-wave-open` 記下 `DK_WAVE_STARTED`，`dk-watch` 超過門檻就推一次 `[TIMEOUT] wave N` 給領導、發一次桌面通知、記一行 process，`dk-wave-close` 收尾時清掉。補的是「員工沒 blocked、reviewer 也沒逾時，但這一波就是卡著不動」這個先前沒有任何守望覆蓋的狀態。訊息走 0.2.1 的 `notify_leader`，送不到會重試。
- feat(herdr): 新增 `lib/herdr.sh` —— `dk_h_soft` 與 `dk_h_note`。dkbo 對 herdr 的呼叫有一種特別危險：吞掉失敗之後還裝作正常。`herdr agent list` 一壞，`dk-watch` 的 `|| return 0` 會讓它每 30 秒安靜地什麼都不做，blocked 與 timeout 永遠偵測不到，而 `process.md` 乾乾淨淨 —— 0.1.5 的 CHANGELOG 已經點名過這件事但沒有動作。現在這類呼叫走 `dk_h_soft`：照樣不崩，但在 `process.md` 留一行 `herdr-degraded: <呼叫>`（每個行程樹只記一次，不洗版），`LEADER.md` 故障段也補了對應處理。
- 範圍裁定（見 `decisions.md`）：**不做**全面收攏 51 個 herdr 呼叫點。失敗就該死的那些非零會自然往上傳，收尾與桌面通知吞掉是對的，硬包一層只是拿 51 處改寫的回歸風險換一個假的抽象；外部評論原本的理由（單一適配點）已由 herdr 版本硬閘與 layer-2 形狀測試涵蓋。
- BACKLOG 清空。
- 測試：231 bats（+8）；shellcheck 零警告。

## 0.2.3 — 2026-09-11
- feat(task-close, chore-close): 結案時把記憶 commit 進主樹。新增 `dk_commit_memory`（`lib/common.sh`）：只 `git add` 並 commit 指定的那幾條路徑（任務目錄、`tasks/INDEX.md`、`decisions.md`；雜務則是雜務檔、`_chores/messages.log`、INDEX），**不碰工作樹上的其他改動**（有測試守住這一點）。先前 `dk-wave-close` 在 worktree 內 commit 程式碼，但任務記憶住在主樹的 `.dkbo/tasks/`，沒有任何腳本碰過它 —— 實跑結案後整個 `tasks/<t>/`（brief、process.md 的 7 條 ruling、每位員工的 state 與 report、report.md）仍是 untracked，一個 `git clean -fd` 就會抹掉，而 README 與 `decisions.md` 都聲稱記憶「進 git」。commit 失敗只警告不擋結案。
- fix(task-new): 領導 pane 的 rename 條件從「完全沒有 agent 名字」改成「還不叫 `leader-<short>`」。pane 只要曾被命名過（例如用 `herdr agent rename` 取過名、或用 `agent start <name>` 起的），rename 就被靜默跳過，而 `dk_leader_name` 固定回 `leader-<short>` —— 員工的 `dk-msg leader` 與 `dk-watch` 的 `[BLOCKED]`／`[TIMEOUT]` 會全部送不到，**且沒有任何警告**，`process.md` 照樣寫得像一切正常。實跑時是手動改名才把訊息接回來的。
- fix(protocol): `[FIXED]` 的方向從「員工→員工」補成「員工→員工、dev→領導」。`LEADER.md` 早就規定領導把 reviewer 的 Important 轉成 `[BUG]` 給 dev、等 dev 的 `[FIXED]` 再重打差異包請 reviewer 複看，但 `PROTOCOL.md` 的類型表沒有這個方向 —— 員工照自己的規範回了 `[DONE]`，於是實跑中 `[FIXED]` 一次都沒出現，RUNBOOK 的驗收條件結構上不可能成立。兩份文件現在對齊，並加了一條測試釘住。
- 測試：223 bats（+4）；shellcheck 零警告。

## 0.2.2 — 2026-09-11
- fix(kinds): claude 員工的權限模式從 `acceptEdits` 改成 `auto`，並加 `--add-dir $DK_PROJECT_ROOT`。實跑（`tests/e2e/RESULTS-2026-09-11.md` ①）顯示 `acceptEdits` 下員工的**每一個協定動作**都在授權之外：讀自己的切片、讀 `PROJECT.md`、寫自己的 state、跑任何 shell —— 因為員工的 cwd 是 worktree 而任務記憶在主樹的 `.dkbo/`。批准一個路徑只會跳出下一個，實跑共人工介入 7 次才走得完一個任務，「領導閒置、員工自己做」根本不成立。對照組是 codex（`-a never -s workspace-write`），整趟零審批。**這是刻意放寬權限**：員工跑在隔離的 worktree 內，`PROTOCOL.md` 的停止條件仍禁止 push／改寫歷史／刪分支／裝依賴／動 `.dkbo/`；要改回嚴格模式就改 `kinds/claude.sh` 一行。
- fix(spawn): `agent start` 失敗時**不再關掉 pane**。實跑中 codex 連續四次 spawn 失敗，原因是 codex CLI 的 `✨ Update available!` 升級提示擋在啟動 —— 但舊行為把 pane（連同那個畫面）關掉，領導只看得到「失敗」兩個字，現場完全無從診斷。現在 pane 保留、`process.md` 記 `spawn <agent> failed: pane <id> kept for diagnosis`，錯誤訊息直接告訴領導怎麼讀它、怎麼收掉。`LEADER.md` 故障段補一條。
- fix(spawn): 第一段提示的等待從 `--wait --timeout 60000` 改成 `--wait --until working --timeout 15000`。`herdr agent prompt --wait` 的預設語意是等**這一輪跑完**（`--help`：matches idle, done, or blocked），不是「提示送到了沒」—— 所以第一輪超過 60 秒的員工會被誤判成 `prompt-failed`，而 `LEADER.md` 會教領導去「重新提示」一個正在工作的 agent，claude 又會把提示排隊，於是它做完後再收到一次同樣的任務。
- fix(msg): `dk-msg` 送不到改成重試（`DK_MSG_TRIES` 預設 3 次、`DK_MSG_RETRY_SEC` 預設 5 秒）才認輸。實跑中 codex reviewer 的 `[DONE]` 在一分鐘內就被判失敗、整筆遺失，而它的報告好端端躺在磁碟上 —— 領導從不知道它交過，於是 `review 1 verdict` 只有一位。
- feat(wave-close): 新增第五道閘：裁定行必須交代每一位真的派出去的 reviewer（`review N spawned` 列出誰就要有誰，沒回來的寫 `<別名>: skipped (<理由>)`）。實跑中兩波都派了 claude + codex，兩波都只有 claude 進入裁定，而 `DK_REVIEW_MIN=1` 讓領導每次都合法地靜默放行 —— 多模型審查的實際生效率是 0，且整個系統看起來一切正常。這道閘讓退化必須被寫下來。
- 測試：219 bats（+2 淨增，另改寫 6 條以對齊新行為）；shellcheck 零警告。

## 0.2.1 — 2026-09-11
- fix(watch): 送給領導的 `[BLOCKED]` 與 `[TIMEOUT]` 不再可能被靜靜吃掉。`dk-watch` 的三處推送（blocked ×2、reviewer timeout）原本直接 `herdr agent prompt` 領導、結果丟棄、標記照寫 —— 而守望觸發的前提正是領導忙著，且「提示送給 working 的 agent 會排隊還是被丟掉」在三個 kind 上都還是 `KIND_PROMPT_QUEUES=unknown`。現在一律走 `notify_leader`：先 `agent wait --until idle --until done`（**有界**，`DK_WATCH_WAIT_MS` 預設 5000 毫秒，背景迴圈不會被卡住），送到才寫 `delivered`；沒送到就留著，下一 tick 重試到送達為止。
- fix(watch): 標記檔從「兩行就算通知過」改成分開的 `notified`（桌面通知已發）與 `delivered`（領導已收到）。桌面通知、`dk_process` 的事件行、以及 reviewer 逾時的 kind 熔斷都只做一次，**且不等領導** —— 熔斷是任務狀態的改變，領導收不收得到訊息都一樣成立。逾時訊息的 `(quota?)` 標記存進標記檔，重試時訊息與第一次逐字相同。
- fix(watch): 雜務那一側同理；`messages.log` 改成送達才記，沒送到不留半筆。0.1.4 之前沒有 `leader:` 行的舊雜務檔沿用原行為（記一行「（無 leader 紀錄）」就收工，不無限重試）。
- docs(leader): 領導回雜務員工那條（`LEADER.md`）是同一個問題的第二處，改成先 `herdr agent wait --until idle` 再 prompt。
- 為什麼不先跑 layer-3 smoke 問出答案：兩條路的終點都是「讓 dk-watch 不要在乎這件事」。直接走那一步是零 token，而且未知數從此不在關鍵路徑上。`KIND_PROMPT_QUEUES` 仍是 unknown，但已不再是安全網的單點。
- 測試：217 bats（+4，含「等 idle 才送」「沒送到就重試且不重複桌面通知」「熔斷不受送達與否影響」「雜務側重試」）；shellcheck 零警告。

## 0.2.0 — 2026-09-11
- feat(leader): 領導這一側的 AI CLI 可選。`settings.env` 新增第六鍵 `DK_LEADER_KIND`（預設 `claude`，`dk_settings` 補預設與 export），`dk-leader` 不再寫死 `claude/opus/high`：kind 取 `DK_LEADER_KIND`，model/effort 取該 kind `KIND_DEFAULT_TIERS` 的 **L 檔**（領導用最高檔），`--kind` / `--model` / `--effort` 仍可逐次覆寫。它也不再自己拼 `--model/--effort`，改走 `dk_kind_args` —— 原本那樣對 codex 會送出它不認的旗標，而且漏掉 `kind_args` 該帶的權限模式。`dk-leader` 先前完全沒呼叫 `dk_settings`，順帶補上。
- feat(init): `/dkbo-init` 第 2 步拆成兩問（領導 kind，預設偵測目前 pane 的 CLI；員工主模型），第 3 步從五鍵變六鍵，並新增入口檔佈線一步。佈線放在 init 而不是 `install.sh`：install 跑在 init 之前，那時還不知道領導是誰，讓它無條件生出 `GEMINI.md` 會在 claude-only 的專案裡塞垃圾。
- refactor(docs): `LEADER.md` 去 claude 化。`/dkbo-init`、「用 add-role skill」這類 Claude Code 專屬呼叫改成指路 `.dkbo/skills/<name>/SKILL.md`（括號註明 Claude Code 的斜線指令），`/clear` 改成「清掉自己的上下文」。一份規範三種 kind 共用，不做 if/else 分歧。
- fix(kinds): `KIND_MODELS` × `KIND_EFFORTS` 的笛卡兒積驗證換成逐 model 宣告的 `KIND_MODEL_EFFORTS`。`agy models` 實測：`gemini-3.1-pro` 只有 `high` 與 `low`，**沒有 medium**，但笛卡兒積會放行 `gemini-3.1-pro/medium`，錯誤要等到 `herdr agent start` 才爆 —— 而那時 pane 已經切出去、`.panes` 也寫了。出廠檔位剛好都避開，所以這個洞一直沒被觸發。`agy` 的 `kind_args` 同時從 `--model <id>-<effort>` 改成 `--model <id> --effort <e>`（實測兩種都可用，但後綴與 `--effort` 同時給會衝突；分開傳較乾淨）。兩件都做才有意義：改傳法不會讓本地擋下不存在的組合。
- fix(docs): README 的 `bash 5` 比實際需求嚴格三個大版本，改成 `bash 3.2+`。`dk_ver_ge` 刻意避開 `sort -V` 就是為了 macOS，而 macOS 內建的正是 bash 3.2 —— 程式碼跑得動，是文件把門檻寫高了。新增 bats 掃 `.dkbo/` 不得出現 bash 4+ 語法（`declare -A`、`mapfile`、`${x,,}` 等），把文件宣稱變成機械閘，跟 0.1.5 對 herdr 做的事同一個路數；該測試會先種一個違規再掃，確認掃描真的有牙齒。
- fix(docs): 補查證出來、README 沒列的真實依賴：`git ≥ 2.17`、`jq ≥ 1.5`、`flock`（軟依賴，缺了 `dk_env_set` 退化成無鎖寫入不會崩）。早先以為需要的 `column`、coreutils `timeout`、python、node 經逐字查證並未被任何程式碼使用（grep 命中的全是註解與 herdr 自己的 `--timeout` 旗標），不列入。
- chore(docs): `docs/` 移出版控（`git rm -r --cached docs/design` + `.gitignore`）。已定案的結論寫進 `.dkbo/decisions.md`，待實作的寫成任務的 `plan.md`；README 與 BACKLOG 的九處引用改成不帶路徑的描述，CHANGELOG 的歷史條目不動（那是當時的事實）。新增 bats 擋住任何進版控的文件再指向 `docs/design`。
- test: 新增 `CHANGELOG` 最上面的版本段必須等於 `.dkbo/VERSION`。先前 `VERSION` 是 0.1.4 而 CHANGELOG 頂端已是未發布的 0.1.5，版本一致性測試只比對 VERSION 與三份 README，抓不到這個落差 —— 那個狀態下推 `v0.1.5` tag 會被 CI 擋。
- 測試：+13 bats；shellcheck 零警告。

### 0.1.5 的內容（未單獨發版，併入 0.2.0）
- feat(herdr): herdr 版本從「文件上的期望」變成實際的閘。`lib/common.sh` 新增 `DK_HERDR_MIN="0.9.0"`（低於即拒跑）與 `DK_HERDR_VERIFIED="0.9"`（`tests/integration/herdr-real.sh` 實測過 JSON 形狀的系列）；`dk_herdr_check` 解析 `herdr --version`，讀不到版本或低於下界就 `dk_die`，高於已驗證系列則每個行程樹提醒一次去跑整合測試。`dk_require_herdr`（每支 dk-* 都會過）與 `install.sh` 都呼叫它 —— install 不要求 `HERDR_ENV`，從普通 shell 安裝仍可。版本比較用自帶的 `dk_ver_ge`（純 bash，逐段十進位比較）而不是 `sort -V` —— `sort -V` 是 GNU 擴充、macOS 的 sort 不保證有，缺了會讓 `dk_herdr_check` 把每一支 dk-* 都判成「herdr 太舊」而全面停擺；字串比較則會把 0.10.0 判成小於 0.9.0。兩個陷阱測試都有覆蓋，另加前導零不被當八進位、`-rc1` 這類後綴忽略、`0.9` 等於 `0.9.0`（刻意與 `sort -V` 不同：對下界檢查而言短版本不是舊版本）。實測 `herdr --version` 20 次共 17ms，擋在每支指令上的成本可以忽略。
- 為什麼需要這道閘：dkbo 對 herdr 的假設（`pane split --ratio` 是 anchor 保留的份、`--amount` 是面積比例、`pane read` 回純文字）是實測 0.9.0 得到的，而 herdr 呼叫的失敗是刻意吞掉的（`dk_layout_even || true`、`agent list || return 0`，見測試「herdr failure is swallowed」）。換版時的表現不是報錯，而是版面悄悄歪掉、`agent list` 取不到 agents 之後 **dk-watch 永遠偵測不到 blocked** —— 整套安全網變成 no-op 而看起來一切正常。
- test(integration): `herdr-real.sh` 開頭印出實際 herdr 版本是否落在 `DK_HERDR_VERIFIED`，超出時提示驗完就把常數往上調。stub 支援 `HERDR_STUB_VERSION` 假裝任何版本。
- 測試：200 個 bats（+7）；shellcheck 零警告。

## 0.1.4 — 2026-09-11
- fix(wave-close): 越界比對從「員工自報的 `touched:` 清單 + 只印警告」改成真正的機械閘。新增 `dk_changed_files`（`lib/ownership.sh`）用丟棄式 index 取 worktree 自本波 base 起的真實變更檔，含未 commit 與未追蹤、`.gitignore` 照舊生效、不碰員工的 index；本波沒有任何成員擁有的檔案一律 `exit 1`（`--force` 例外，並在 process 記 `violation unowned:`）。改到不屬於自己的檔、在 worktree 裡動 `.dkbo/` 規則檔，現在都關不掉這一波。
- feat(wave-close): 自己擁有但沒寫進 `touched` 的檔列為 `unreported change`（警告、不阻擋，記 process）。
- feat(wave-close): 波的 commit 收進腳本。四道閘全過、pane 關完後在 worktree 內 `git add -A && git commit`，訊息預設 `wave N: <成員>`，`-m "<訊息>"` 可覆寫；無變更不空 commit；commit 失敗回非零並記 process。領導不再手動 commit，波的邊界等於 commit 邊界。
- refactor: `wave-open N base <sha>` 的解析收攏成 `dk_wave_base`（`lib/common.sh`），`dk-review-pack`、`dk-resume`、`dk-wave-close` 共用。
- docs: LEADER.md 第 5 步與三則新故障處理、PROTOCOL.md 的 `touched` 說明、兩份 README、`.dkbo/README.md`；`docs/design/2026-09-10-external-review-response.md` 加第 6 節，更正該文第 3 節「三道機械閘」的說法。
- 無主但預期會變的檔（lockfile 之類）不另開設定鍵：要動就在 brief 的檔案所有權表列給某位成員。
- ci: 新增 `.github/workflows/ci.yml` —— 每次 push 與 PR 跑 `tests/run.sh` 與 shellcheck（含 `install.sh`、`kinds/*.sh`，與 README 記載的範圍對齊）；推 `v*` tag 時另驗 tag 等於 `.dkbo/VERSION` 且 CHANGELOG 有該版條目。版本字串一致性做成 bats 測試（`.dkbo/VERSION` 與兩份 README 的版本行、三處 `VER=v…` pin、`install.sh` 與 `dk-version` 的範例輸出共八處必須一致），本機 `tests/run.sh` 就會抓。
- fix(watch): 守望不再會無聲消失。`dk-watch --ensure` 幂等重啟：用 `ps -p <pid> -o args=` 比對完整命令列（不是 `kill -0` —— PID 會被回收，`kill -0` 會把一個無關行程當成 watcher 還活著），死了就重啟並記 `watch restarted`。`dk-spawn`、`dk-wave-open`、`dk-resume` 都會呼叫；`dk-resume` 另外在「本波」段印一行 `watch:` 狀態。原本 watcher 只由 `dk-task-new` 啟動一次，機器睡眠或行程被殺之後 `[BLOCKED]`／`[TIMEOUT]`／kind 熔斷整層就靜靜不見了，而領導的判斷依賴它存在。
- feat(watch): 雜務也有守望了。`dk-watch --chores` 掃 `tasks/_chores/*.md` 裡 `status: working` 的雜務做 blocked 偵測（沒有 reviewer 逾時那套），推 `[BLOCKED]` 給該件雜務自己的領導並記進 `_chores/messages.log`；由 `dk-chore` 幂等啟動，最後一件雜務關掉後自己退出。pid 與 marker 放 `.sessions/`（已被 gitignore）。`templates/chore.md` 新增 `leader:` 欄（`dk-chore` 本來就算出這個值，只是沒寫下來）；0.1.4 之前的雜務檔沒這欄，退化成只發桌面通知。
- 測試：193 個 bats（+29）；shellcheck 零警告。

## 0.1.3 — 2026-09-10
- docs(decisions): 定調路線：一位人類、一位領導、同時 3 到 6 位員工、一個 herdr 視窗；不做 event bus、agent registry 評分、任務 DAG、金額預算。
- docs(design): 新增 `docs/design/2026-09-10-external-review-response.md`，記錄對外部評論的四處事實更正（wave-close 三道機械閘已存在、wave close 與 merge 本來分開、reviewer 為隔離的不同 kind、版本）與逐點裁定。
- docs(backlog): 排入 herdr 呼叫收攏進 `lib/herdr.sh`、整波逾時 `DK_WAVE_TIMEOUT_MIN` 兩項。
- docs(readme): `dk-resume` 隨時可跑當狀態總覽，不必等失憶才用。
- 不改任何腳本。

## 0.1.2 — 2026-09-10
- docs(protocol): 停止條件加「不跑會跳權限確認的指令」（`rm -rf`、`git push`、`git reset --hard`、`git clean`、部署類）。員工跑在 acceptEdits，專案的 `ask` 規則會讓指令停在確認提示等人按，pane 沒人看就永遠卡住；改用不加 `-f` 的單一路徑刪除或工具自帶清理，否則 ESCALATE。
- fix(close): `dk-task-close`、`dk-chore-close` 在 worktree 有未 commit 變更時拒絕結案（exit 1），不再被 `worktree remove --force` 無聲丟掉；要丟才用 `--abandon`。
- fix(close): 合併成功後刪掉 `dk/<short>`、`chore/<slug>` 分支（`branch -d`，只刪已合併的），分支不再隨任務數累積。
- fix(task-new): `worktree add` 之後任何一步失敗都會回收 worktree、分支與半寫的任務資料夾，同名任務可以直接重開。
- refactor(chore): `--code` 雜務改用原生 `git worktree add`（`.worktrees/chore-<slug>`，同樣吃 `DK_WORKTREE_DIR`），不再經 `herdr worktree create` 另開 workspace；員工 pane 從領導 pane 切出。同 slug 的雜務尚未關閉時拒絕重開。舊的 herdr workspace 雜務仍由 `dk-chore-close` 用 herdr 移除並 `git worktree prune`。

## 0.1.1 — 2026-09-10
- fix(chore): 雜務員工改用 `dk-msg leader` 回報。舊做法直接 `herdr agent prompt` 領導，領導忙碌或剛 `/clear` 時訊息會被吃掉，領導永遠不知道要 `dk-chore-close`；dk-msg 會等領導閒置再送，並記到 `tasks/_chores/messages.log`。
- fix(chore): 多行交代不再撐壞 `tasks/INDEX.md`（名稱只取第一行、`dk_index_add` 壓平換行），也不再讓 chore 檔名帶換行（`dk_slug`）。之前多行交代會讓 `dk-chore-close` 找不到檔、INDEX 狀態永遠停在 working。

## 0.1.0 — 2026-09-10
第一個標版本。

- 領導／員工基本流程：`dk-task-new`、`dk-spawn`、`dk-msg`、`dk-wave-close`、`dk-watch`、`dk-resume`、`dk-chore`、`dk-task-close`、`dk-leader`。
- 每波審查閘：`dk-wave-open`、`dk-review-pack`、`dk-review`（1–3 位 reviewer、kind 熔斷）、`dk-wave-close` 三檢查（裁定、dev 報告 `## 測試`、`DK_TEST_CMD`）。
- 事前防線：`dk-brief-check`、成員 brief 切片、員工報告檔、`.dkbo/settings.env`。
- 多人版面：領導佔 tab 1 左欄，員工依格填位，第 5 位起自動開新 tab，關 pane 後動態均分。
- 任務 worktree 改用 `git worktree add`（`.worktrees/<short>`）。
- 真 herdr 0.9.0 驗證：`pane split --ratio` 是 anchor 保留的份、`pane resize --amount` 是面積比例、`pane read` 回純文字。
- 套件名統一為 dkbo，repo `dkbo/dkbo-team`；shellcheck 零警告。
