# reviewer-a 報告（波 2）

## 做了什麼
- 讀 `waves/2.diff`（base 6dc7bc7，18 檔，全在未 commit 的工作樹）、完整 `brief.md`、`messages.log` 與三位 dev 的 report。
- 對照 worktree 現況：`git diff --stat` 與差異包同為 18 檔、+117/−26，打包之後沒有新改動。
- 逐項驗波 2 波次表列的三組 Minor 修正（backend-msg ①②③、backend-brief ①②③、backend-docs ①②③④）與全域約束；對可疑的測試在 scratchpad 的副本（`git ls-files` 打包解出、另 git init）做突變測試，沒有動共用 worktree。
- 波 1 的報告備份在我的 scratchpad（`wave1-report.md`）；本檔改寫為波 2。

## 測試
### 紅
- 突變探針（scratchpad 副本）：把 `dk-spawn` append 那段的鎖拿掉 → `bats tests/unit/07_spawn.bats -f 'Minor②'`
  → `not ok 1 整枝評議 Minor②…`（`07_spawn.bats:286` 的 elapsed 斷言），append 那一半確實守得住。
- 突變探針：只把 `dk-spawn --resume` 刪舊列那段（`:77-79`）的鎖拿掉、append 的鎖留著 → 同一條指令
  → `ok 1 整枝評議 Minor②…`：**測試照樣綠**，--resume 那一半守不住它宣稱的東西。見 Minor 1。
### 綠
- `shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh` → rc=0，零警告。
- `tests/run.sh tests/unit/06_msg.bats tests/unit/07_spawn.bats tests/unit/08_wave_close.bats tests/unit/15_brief_lib.bats tests/unit/16_brief_check.bats tests/unit/20_review.bats tests/unit/21_version.bats tests/unit/25_docs_policy.bats tests/unit/04_docs.bats tests/unit/35_test_hygiene.bats` → `1..235`，沒有 `not ok`，rc=0。
- 測試條數：`grep -h '^@test' tests/unit/*.bats | wc -l` → 724；0.15.0 節寫 656 → +68，與 CHANGELOG `724 bats（+68；` 相符。
- 完整 `tests/run.sh` 沒跑（wave-close 會當閘跑；backend-brief 與 backend-docs 都回報 724/724）。

## 規格合規
- ✅ backend-msg ① `dk-msg:170-183`：redispatch 的鎖改成 `.blocked/panes.lock`，`mkdir -p .blocked` 移到 subshell 之前（否則重導向會失敗）；`dk-task-close:81` 的 `rm -rf "$dir/.blocked"` 會把它一起刪，不進記憶。`06_msg.bats` 補「鎖在 .blocked、不在任務目錄根」一條（`DK_MSG_BG=1` 走同步送達，會實際跑到 redispatch）。
- ✅ backend-msg ② `dk-spawn:76-79`（--resume／--handoff 共用這段，`--handoff` 會設 `resume=1`）、`dk-spawn:118-120`（append）、`dk-wave-close:13-15`（`--agent`）都拿同一把鎖；另外 `dk-wave-close:180` 收波清空 `.panes` 也包進去了（超出列舉，方向對）。全倉 grep 會改寫 `.panes` 的只剩 `dk-task-new:65`（任務建立那一刻，沒有並行者），`dk-watch` 只讀。07／08 各補一條等鎖測試；07 的 --resume 那一半有缺口，見 Minor 1。
- ✅ backend-msg ③ `dk-wave-close:55-56`：`case " $vline" in *" $al:"*`，別名前面要是行首或空白；`08_wave_close.bats` 補 `note:`／`if:` 冒充 e／f 的反例與正例。run SKILL 規定的格式 `a: ok / b: important 2`、歷來 process.md 的 verdict 行（全倉掃過，都只有 `a:` 開頭）都照樣通過。
- ✅ backend-brief ① `lib/review.sh:54`：提示寫明「關 pane 不會把別名還回來」、只留 `dk-process "<label> skipped: <理由>"`，不再叫人 `dk-wave-close --agent`；20 補一條（含 refute）。
- ✅ backend-brief ② `lib/brief.sh:39-41`：`dk_brief_ncols [COL]...` 改成印欄數再附指定欄，`dk-brief-check:46`、`:132` 兩處欄數閘都改呼叫它，內聯 awk 沒了、不留死碼；15 補行為斷言、16 補結構斷言。
- ✅ backend-brief ③ `dk-brief-check:48`：`all_globs` 改用 `$DK__BRIEF_SPLIT` 的 `c[1]`／`c[2]`；16 補漏判與誤判兩個方向，backend-brief 用 `git archive` 副本單獨取了誤判那一半的紅。
- ✅ backend-docs ① `25_docs_policy.bats:48`、`:51`：改回嚴格禁「計畫時記下｜recorded at plan time」，排除清單不變；CHANGELOG 0.16.0 節用的是「計畫那一刻記下」，不會踩到。
- ✅ backend-docs ② 三份 README 改成 `--note <文字>`／`<text>`，25 AC16 那條補了三行逐字斷言。
- ✅ backend-docs ③ CHANGELOG 補 `fix(repos)`（我核對過：`repos.sh:111`、`dk-brief-check:172`、`dk-wave-close:103`、`dk-wave-open:23` 都已改成 here-string，敘述屬實）、`fix(wave)`，並把 panes.lock、別名提示、all_globs 各補進 feat(msg)／feat(review)／feat(brief)；21 補關鍵字。
- ✅ backend-docs ④ 測試條數 724（+68），實數核對相符；21 補「不留 N 佔位」的斷言。
- ✅ 交接：backend-msg 15:40、backend-brief 15:42 都有前景送 `[DONE]` 給 backend-docs（messages.log）。
- 全域約束：無 bash 4 語法、無 `date -d/-r`、無新 settings／`.task.env` 鍵、無新 bin／skill／測試檔；測試沒有 `! cmd`（07／08 的 `[ ! -e … ]` 是 test 內建，35 綠）；既有測試只新增斷言，25 Important4 的改動在（b）允許範圍內且是收緊；04 行數上限沒動。18 個改動檔逐一對過所有權表，全在本波三位的可改欄內。報告沒有人宣稱「本波已用到」新行為。

## Important
（無）

## Minor
累積 Minor 判定：切片的「本任務累積的 Minor」段是空的（逐波審查不 triage），沒有要判的條目。本波新提的三條都**可以留著**，不擋 merge；第 1 條改起來便宜，建議順手修。

1. `tests/unit/07_spawn.bats:288-290` 測試名稱宣稱「--resume 刪舊列拿 .blocked/panes.lock」，但這一半證不了這件事：`--resume` 除了刪舊列還會走到 `:120` 的 append，而 append 也拿同一把鎖，所以只拿掉刪列那段（`dk-spawn:77-79`）的鎖，elapsed ≥1 照樣成立。突變探針已經證實（見「## 測試／紅」第二條）。修法建議：持鎖期間在背景跑 `dk-spawn backend --resume`，大約 1 秒後斷言 `.panes` 裡舊的 `login-backend` 列**還在**；刪列那段沒拿鎖的話，舊列會在持鎖期間就被刪掉。
2. `.dkbo/bin/dk-wave-close:56` 詞界只接受「空白」：如果裁定行用全形標點或括號接別名（`a: ok；b: important 1`、`（b: ok）`、`a: ok,b: ok`），b 會被判成沒交代，閘會 FAIL（fail-closed，訊息會教人補，不會靜默放行）。run SKILL 規定的 `a: ok / b: …` 與歷來的 verdict 行都不受影響，所以可以留著；想更寬容的話，可以把前導字元放寬成空白加 `（(，,；;/`。
3. 同一類的裸 `awk -F'|'` 切可改欄還有兩處：`.dkbo/lib/ownership.sh:12`（`dk_owned`，wave-close 的 gate d 和 brief-check 的無主測試 WARN 都靠它）與 `.dkbo/bin/dk-spawn:57`（`first_glob`）。可改欄含 `\|` 時一樣會錯位。這不在本波範圍，`lib/ownership.sh` 也不在任何人的所有權內，加上路徑裡出現字面管線的情況很少見，建議記進 BACKLOG，不在本任務修。
4. （可有可無）`hold_panes_lock` 在 `07_spawn.bats:278` 與 `08_wave_close.bats:323` 一字不差地各定義一份；`tests/helpers.bash` 沒劃給任何人，所以留著是合理的。

## 自我審查
- 只讀：沒有改 worktree、沒有 git add/commit。突變探針都在 scratchpad 的副本裡做，改完用副本自己的 git 還原。
- Minor 1 的結論是實測出來的，不是推論；Minor 2 的歷史格式是全倉 process.md 掃出來的。

## 疑慮
- 無。
