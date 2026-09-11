# Changelog

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
