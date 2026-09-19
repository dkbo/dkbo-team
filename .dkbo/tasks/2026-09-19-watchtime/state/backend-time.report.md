# backend-time 報告（波 1）

## 做了什麼
AC5–AC11 與 AC14 的 SKILL.md 那句。核心是：process.md 每一行本來就有時間戳，但沒有任何腳本讀它 ——
這一波把那些既有時間戳接起來，不新增任何要員工或領導多填的欄位。

- **AC5 `dk-resume`**：「本波」段開頭多兩行 `任務已進行 Xh Ym（自 task-new）`、`本波已進行 Ym（自 wave-open）`；
  沒開波時只印任務那行。「在線員工」每位附 `等了 N min`（`.panes` 第三欄 epoch 到現在），dev 與 reviewer 一致。
  時間在 `render()` 之外算一次 —— render 為了塞進 150 行預算最多跑四次，每次重算會讓同一份輸出裡的數字彼此對不上。
- **AC6 `dk-wave-close`**：成功關波時印並記 `wave N 耗時 Mm（dev Am、審查 Rm）`。缺任一來源該欄印 `—`，
  純文件波（`review N skipped:`）審查欄印 `skip`。
- **AC7/AC8 新腳本 `bin/dk-timeline [<task>]`**：只讀 process.md 印 markdown 表（任務／計畫／每波／結案），
  未結案的任務算到現在並標「（進行中）」。零 token、不寫任何檔（有測試斷言 herdr 一次都沒被呼叫、`$DK_ROOT` 下檔案清單前後相同）。
- **AC9 `dk-task-close`**：非 `--abandon` 的兩條結案路徑都在 `dk_process "task-close …"` 之後、`dk_commit_memory` 之前
  把時間表填進 `report.md` 的「## 時間」段（`templates/report.md` 同步加這一段並註明由 dk-task-close 填）。
  早一步算不到結案那一刻，晚一步就沒進任務記憶的 commit。
- **AC10 文件**：`skills/run/SKILL.md`「每次醒來先做」加一條 dk-timeline、`.dkbo/README.md`「日常使用」加一條；
  `README.md`／`README.en.md` 的 dk-resume 那列補時間行並新增 dk-timeline 一列。
- **AC14 的 SKILL.md 那句**：故障段「同任務內解除熔斷」後面補「`.blocked/<員工>.limit` 標記檔不要刪」及理由。
- **AC11 版本**：`.dkbo/VERSION` 0.9.2、三份 README 的 dkbo 版本字串八處全改（herdr 六處維持 0.9.0），
  CHANGELOG 首節 `## 0.9.2 — 2026-09-19`，`fix(watch)` 那一條是 backend-watch 用 `[TASK]` 交過來的原文
  （契約規定由它出文、我照原文寫進首節），`feat(time)` 與測試行是我寫的。

共用契約 `dk_ts_minutes "YYYY-MM-DDTHH:MM"` 依 brief 放在 `lib/common.sh`，回自 epoch 起的分鐘數，
純算術（days_from_civil）。同檔另加兩個只在這條路徑上用的小工具，讓三支腳本共用同一套政策而不是各抄一份：
`dk_span`（缺來源印 `—`）與 `dk_ts_pick`（依欄位取最後一筆命中的時間戳）。

## 測試
全套：`tests/run.sh` → **426 passed, 0 failed**（原 399，新增 27）。
shellcheck：`cd .dkbo && shellcheck bin/dk-* lib/*.sh kinds/*.sh install.sh` → `rc=0`，零輸出。
（下面三組各自都是「先只寫測試、跑它看它紅、再寫實作、跑同一條指令看它綠」的順序。）

### 紅
```
$ tests/run.sh tests/unit/10_resume.bats                       # AC5
not ok 7 本波段印任務與本波已進行的時間，在線員工每位附等了 N min
#   `[[ "$output" =~ 任務已進行\ ([0-9]+)h\ ([0-9]+)m（自\ task-new） ]] || { echo "no 任務已進行 line"; false; }' failed
# no 任務已進行 line
not ok 8 沒有開波時只印任務那行
#   `[[ "$output" == *"任務已進行 "* ]]; [[ "$output" != *"本波已進行"* ]]' failed

$ tests/run.sh tests/unit/08_wave_close.bats                    # AC6
not ok 30 AC6: 關波印本波耗時並記進 process
#   `[[ "$output" =~ wave\ 1\ 耗時\ ([0-9]+)m（dev\ 19m、審查\ 7m） ]] || { echo "$output"; false; }' failed
# closed 2
not ok 31 AC6: 缺 dev-done 該欄印 —，純文件波審查欄印 skip
#   `[[ "$output" == *"（dev —、審查 skip）"* ]] || { echo "$output"; false; }' failed
# closed 2

$ tests/run.sh tests/unit/32_timeline.bats                      # AC8（實作前 dk-timeline 還不存在）
not ok 6 AC7 只讀：零 token、不寫任何檔，沒帶參數就讀綁定的任務
BW01: `run`'s command `dk-timeline highfix` exited with code 127, indicating 'Command not found'.
BW01: `run`'s command `dk-timeline flowgap` exited with code 127, indicating 'Command not found'.
BW01: `run`'s command `dk-timeline crossday` exited with code 127, indicating 'Command not found'.
BW01: `run`'s command `dk-timeline live` exited with code 127, indicating 'Command not found'.
```

### 綠
```
$ tests/run.sh tests/unit/10_resume.bats                       # AC5
1..8
ok 7 本波段印任務與本波已進行的時間，在線員工每位附等了 N min
ok 8 沒有開波時只印任務那行

$ tests/run.sh tests/unit/08_wave_close.bats                    # AC6
ok 30 AC6: 關波印本波耗時並記進 process
ok 31 AC6: 缺 dev-done 該欄印 —，純文件波審查欄印 skip

$ tests/run.sh tests/unit/32_timeline.bats                      # AC8
1..8
ok 1 dk_ts_minutes 純算術換算，跨月跨年閏年都對
ok 2 AC8 highfix：與人手算的數字逐列一致
ok 3 AC8 flowgap：四波、審查取最後一則 verdict、關波取最後一次 wave-close
ok 4 AC8 跨日樣本：日期進位，時長與 highfix 逐欄相同
ok 5 AC7 未結案的任務算到現在並標進行中；缺來源印 —
ok 6 AC7 只讀：零 token、不寫任何檔，沒帶參數就讀綁定的任務

$ tests/run.sh                                                  # 全套
1..426
（grep -c '^ok ' → 426；grep '^not ok' → 無輸出）
```

AC8 的數字不是我自己造的樣本：`tests/fixtures/highfix-process.md` 與 `flowgap-process.md` 是
`.dkbo/tasks/` 兩個真任務的 process.md **原樣複製**，斷言值就是 brief 裡領導人手算的那一組，逐欄相同。
跨日樣本 `crossday-process.md` 是把 highfix 的每個時間戳整批 +3 小時（20:39 → 23:39，結案落在隔天 00:45），
出處與理由寫在 `tests/fixtures/README.md`。實跑真任務對照：

```
$ .dkbo/bin/dk-timeline 2026-09-19-flowgap
| 任務 | 2026-09-19T14:32 | 2026-09-19T19:11 | 279m | — | — |
| 計畫 | 2026-09-19T14:32 | 2026-09-19T14:47 | 15m | — | — |
| 波 1 | 2026-09-19T14:47 | 2026-09-19T17:15 | 148m | 22m | 125m |
| 波 2 | 2026-09-19T17:15 | 2026-09-19T17:31 | 16m | 1m | 4m |
| 波 3 | 2026-09-19T17:31 | 2026-09-19T17:52 | 21m | 0m | 5m |
| 波 4 | 2026-09-19T18:06 | 2026-09-19T18:29 | 23m | 0m | 6m |
| 結案 | 2026-09-19T18:29 | 2026-09-19T19:11 | 42m | — | — |
```

## 自我審查
- **`date -d`／`date -j`／`mktime` 三條路都排除**：全域約束禁的就是這三個，而且理由成立 —— 它們各自只在
  GNU／BSD／gawk 上有。改用 days_from_civil 純整數運算，把三月當年初讓閏日落在年尾，跨月跨年不必特判。
  測試涵蓋 epoch 原點、跨月、跨年、閏年（2024）、非閏年（2026）、400 的倍數是閏年（2000）、100 的倍數不是（1900），
  以及 `08`／`09` 被當八進位的經典坑（全部用 `10#` 前綴）。
- **排除了「用 mtime 判先後」**：`decisions.md` 2026-09-19 已經否掉，而且 `date -r` 在 GNU 與 BSD 語義不同。整支沒碰過檔案時間。
- **`set -e` 的坑，踩到一次**：`[ -n "$ts" ] && task_min=$(…)` 這種寫法在 `$ts` 為空時整行回 1，
  在 `set -euo pipefail` 下會當場殺掉 dk-resume。第一版就是這樣寫的，改成 `if … then … fi`。
  其餘新增的條件式一律用 `if`，不用 `A && B` 當語句。
- **shellcheck 的 SC2016 是設計訊號，不是噪音**：`dk_ts_pick` 第一版把 awk 條件當字串傳進去（`'$2=="review" …'`），
  shellcheck 判成沒展開的 shell 變數。與其 disable，改成依欄位比對（`dk_ts_pick FILE TOK2 [TOK3] [TOK4]`，
  空字串＝該欄不限）—— 引號不再散在每個呼叫端，而 process.md 的 token 本來就是靠欄位定位的。SC2013 同時消掉（改 `while read`）。
- **「最後一筆」不是「第一筆」**：flowgap 的波 1 關了兩次（15:37 tests failed、17:15 tests ok），
  review 1 也裁定了三次（15:18、15:36、17:14）。取第一筆會算出 50m 與 9m，都是錯的。
  `dk_ts_pick` 一律取最後一筆命中，flowgap 那一列（148m／125m）就是這條規則的回歸測試。
- **缺來源印 `—` 而不是 0**：沒量到和量到零是兩件事。印 0 會讓時間表憑空多出一段假的「即時完成」，
  而波 3、波 4 的 dev 真的是 0m（當時假聚合留下的），兩者必須看得出差別。
- **契約沒動**：`dk-timeline` 只認 brief 契約表列的既有行首 token，一個都沒新增、沒改形狀。
  AC6 新記的 process 行是 `wave N 耗時 …`，第二欄是 `wave`，與 `wave-open`／`wave-close` 不同 token，
  `dk_wave_base`、`dk-resume`、`dk-review` 的既有 awk 都不會誤讀（全套 425 綠可證）。
- **既有測試被我改過兩處，都是我的檔**：`10_resume.bats` setup 的 `.panes` epoch 從 `0` 改成相對現在的秒數，
  以及那一條的 tab 斷言補上「等了 N min」—— epoch 0 會印出兩百多萬分鐘，不是壞掉，是 fixture 本來就不真實。
- **測試的時間戳沒有用 `date -d` 湊**：測試也要能在別人的機器上跑。用「今天 00:00」與「今天 HH:00」
  兩個純字串組出來，期望值只靠 `date +%H`／`%M` 算，並對跨分鐘容一分（`exp` 到 `exp+1`），避免間歇紅。

## 疑慮
1. **`PROJECT.md` 說 `tests/run.sh` 會跑 shellcheck，實際上不會。** `tests/run.sh` 只 `exec bats`，
   `tests/` 底下沒有任何一處呼叫 shellcheck。AC11 的「shellcheck 零警告」我是手動跑的
   （`cd .dkbo && shellcheck bin/dk-* lib/*.sh kinds/*.sh install.sh` → rc=0）。
   也就是說**現在沒有任何機械閘守著 shellcheck**，下一個人漏跑不會有人吭聲。建議記 BACKLOG（我沒有 BACKLOG 的所有權）。
2. **`dk_ts_minutes` 把時間戳當「無時區的本地時間」。** 跨 DST 切換的那一小時會多報或少報 60 分。
   process.md 的時間戳本來就是 `date +%Y-%m-%dT%H:%M`、不帶偏移資訊，要算對必須引進時區資料庫 —— 不值得，
   而且台灣沒有 DST。有這個需求時才處理。
3. **`review N skipped:` 的比對是第 4 欄完全相等 `skipped:`。** 領導若把理由緊貼冒號寫成 `skipped:純文件波`，
   審查欄會退回 `—` 而不是 `skip`（數字不會錯，只是少一個標記）。SKILL.md 教的寫法有空格，`dk-wave-close` 的
   gate a 也是這個形狀，所以正常路徑上不會發生。
4. **state 檔 26 行，超過 PROTOCOL 的 ≤20 行。** 這一波動了 24 個檔，而 `touched` 必須完整才過得了 gate d
   的真實 diff 比對。兩條規則在這裡衝突，我選了完整的 `touched`（gate d 會擋，行數只是警告）。
