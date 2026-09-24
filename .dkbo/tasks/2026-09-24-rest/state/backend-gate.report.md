# rest-backend-gate 報告（波 1）
## 做了什麼
- **AC1**（`.dkbo/bin/dk-wave-close` gate c）：`clean` 陣列同一個迴圈改成 `for v in ${!DK_@} ${!HERDR_@}`，單 repo 與多 repo 兩條路徑共用它，所以兩邊都剝掉 `HERDR_*`；`PATH`、`HOME` 等照舊。上方註解補了理由（`HERDR_PANE_ID` 等繼承值會讓專案測試以為自己在領導的 pane 裡，打到真 herdr）。
- **AC1 測試**（`tests/unit/08_wave_close.bats`）加兩條：單 repo 一條、多 repo 一條。呼叫端有 `HERDR_PANE_ID`／`HERDR_ENV`（helpers 已經 export）和測試自己 export 的 `HERDR_SOCKET_PATH`，測試指令 `env > 檔`，斷言檔案裡沒有 `^HERDR_`、沒有 `^DK_`、有 `^PATH=`。
  - 注意：`HERDR_PANE_ID` 不能改成別的值。dk-wave-close 靠 `.sessions/$HERDR_PANE_ID` 找任務，第一版我改了值，結果 dk-wave-close 自己就失敗（紅的原因不對），已修正，也在測試註解裡寫明。
- **AC1 確認 dkbo 自己的測試不靠繼承的 `HERDR_*`**：
  1. `grep -c HERDR tests/run.sh` 結果是 0，run.sh 不讀這些變數。
  2. `tests/unit/*.bats` 全部都呼叫 `setup_project`。`tests/helpers.bash:27-34` 在每條測試的 setup 裡重新設定並 export `HERDR_STUB_LOG`、`HERDR_STUB_RESPONSES`、`HERDR_ENV`、`HERDR_PANE_ID`、`HERDR_WORKSPACE_ID`、`HERDR_TAB_ID`；逐檔掃過，沒有「沒呼叫 setup_project 卻用 `HERDR_`」的檔。
  3. 實證：完整套件用和 gate c 同一套手法剝掉 `DK_*` 和 `HERDR_*`（本 pane 有 `HERDR_BIN_PATH HERDR_ENV HERDR_PANE_ID HERDR_SOCKET_PATH HERDR_TAB_ID HERDR_WORKSPACE_ID`）之後跑 `tests/run.sh`，結果見「## 測試」。
- **AC6**（`.dkbo/lib/ownership.sh` `dk_owned`）：改成 `dk_brief_owners`（只讀 `## 檔案所有權` 段）加 `$DK__BRIEF_SPLIT` 跳脫感知切欄，取第 2 欄之後依逗號切開，再把 `\|` 還原成字面 `|`（切欄時保留跳脫，用到值的那一刻才還原，和 `dk_brief_md_rows` 保留跳脫的慣例一致）。ownership.sh 開頭加了「缺 `dk_brief_owners` 就 source brief.sh」，寫法同既有的 repos.sh 那行。
- **AC6**（`.dkbo/bin/dk-spawn` `first_glob`）：同樣改走 `$DK__BRIEF_SPLIT`，切完再還原 `\|`。
  - **踩到的坑**：`DK__BRIEF_SPLIT` 內部用了 awk 變數 `m`、`c`、`p`、`i`、`j`、`v`、`nf`、`line`，原本的 `-v m="$sname"` 會被它蓋掉，結果 first_glob 是空的、cwd 退回主 repo。已改成 `-v who=`，並在程式碼註解警告這件事。
- **AC6**（`.dkbo/bin/dk-brief-check` 136、143 行）：取波次成員的兩處從 `awk -F'|' … '$1==n{print $3}'` 改成 `awk -v n="$w" "$DK__BRIEF_SPLIT"'c[1]==n{print c[3]}'`，寫法同 153 行的既有寫法。這只是為了一致，不是修 bug。
- **AC6 測試**：
  - 22 加兩條：`\|` 跳脫一條，誘餌表（放在 `## 目標` 底下，第一格是 backend、第二格是 `bait/**`）一條。
  - 07 加一條守護：multi repo、第一個 glob 是 `shared:src/a\|b/**` → cwd 與首輪提示是 shared 的 worktree。
  - 16 加一條回歸守護：三位成員的「做什麼」欄都含 `\|`，獨佔資源衝突和 dev 計數 WARN 照常。

## 測試
### 紅
AC1（08）：
```
$ tests/run.sh tests/unit/08_wave_close.bats -f 'HERDR'
not ok 1 gate c: 測試指令拿到的環境裡也沒有任何 HERDR_*（單 repo）
# refute_grep: 不該命中卻命中了: ^HERDR_ /tmp/tmp.dfuPLfRG92/gatec-herdr.txt
not ok 2 gate c: 多 repo 的測試指令也拿不到 HERDR_* 與 DK_*
# refute_grep: 不該命中卻命中了: ^HERDR_ /tmp/tmp.zLLLoCPOk2/gatec-herdr-multi.txt
```
AC6 dk_owned（22）：
```
$ tests/run.sh tests/unit/22_ownership.bats -f 'rest AC6'
not ok 1 rest AC6: 可改欄含 \| 時兩個 glob 都認得，\| 還原成字面 |
#   `run dk_owned "$b" backend 'src/c/x'; [ "$status" -eq 0 ]' failed
not ok 2 rest AC6: 所有權段之前的表格第一格等於成員名也不算（誘餌）
#   `run dk_owned "$b" backend 'bait/x'; [ "$status" -eq 1 ]' failed
```
AC6 first_glob（07）：舊碼本來就綠。first_glob 只用來取 repo 前綴，前綴一定在 `\|` 之前，舊碼截成 `shared:src/a\` 仍判得出 shared，外部觀察不到差異。
- 改用突變探針證明這條會紅：在獨立目錄（`cp -r .dkbo tests` 到 scratchpad）把 dk-spawn 改回 `-v m=`（會被 `DK__BRIEF_SPLIT` 蓋掉的那個 bug）：
```
$ (cd <scratch>/mut07 && tests/run.sh tests/unit/07_spawn.bats -f 'rest AC6')
not ok 1 rest AC6: 第一個 glob 含 \| 時 first_glob 取到完整的第一個 glob（repo 判對）
#   `grep -q -- "--cwd $(dk_repo_field "$d" shared wt) --no-focus" "$HERDR_STUB_LOG"' failed
```
- 直接比對取值（同一份 brief 列 `| backend | shared:src/a\|b/**, api:src/** | x |`）：舊碼得到 `shared:src/a\`，新碼得到 `shared:src/a|b/**`。

AC6 dk-brief-check（16）：不要求取紅（AC 明定）。舊碼跑新測試：`ok 1 rest AC6: 「做什麼」欄含 \| 時取波次成員照常（dev 計數與獨佔資源）`。
### 綠
```
$ tests/run.sh tests/unit/08_wave_close.bats -f 'HERDR'
ok 1 gate c: 測試指令拿到的環境裡也沒有任何 HERDR_*（單 repo）
ok 2 gate c: 多 repo 的測試指令也拿不到 HERDR_* 與 DK_*
$ tests/run.sh tests/unit/22_ownership.bats
ok 11 rest AC6: 可改欄含 \| 時兩個 glob 都認得，\| 還原成字面 |
ok 12 rest AC6: 所有權段之前的表格第一格等於成員名也不算（誘餌）   （全檔 12/12 ok）
$ tests/run.sh tests/unit/07_spawn.bats      → 35/35 ok
$ tests/run.sh tests/unit/16_brief_check.bats → 35/35 ok
$ tests/run.sh tests/unit/08_wave_close.bats  → 43/43 ok
$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh tests/run.sh → rc=0，零警告
```
完整套件（剝掉 `DK_*` 與 `HERDR_*`，手法同 gate c）：
- 指令：`clean=(env); for v in ${!DK_@} ${!HERDR_@}; do clean+=(-u "$v"); done; "${clean[@]}" tests/run.sh`
- 結果：`1..752`，749 ok，3 not ok：
  - 153 `AC5: 守望已死時 dev 對 leader 的 [DONE]（只落盤、不送達）把它叫回來`
  - 154 `AC5: 一般 [QUESTION] 送達路徑也把守望叫回來`
  - 155 `AC5: [UNDELIVERED] 出口也把守望叫回來`
- 這三條都在 06_msg.bats，是 backend-watch 的 AC5 紅測試（當下 `.dkbo/bin/dk-msg` 還沒有 `dk-watch --ensure`），與本人改動無關。
- 除了這三條，其餘全綠，表示 dkbo 自己的測試在沒有繼承 `HERDR_*` 的情況下照常通過。

## 自我審查
- 沒有 bash 4 語法；`${!HERDR_@}` 是 bash 3.2 就有的前綴展開（同既有的 `${!DK_@}`）。
- 既有測試一條都沒有刪、也沒有放寬；否定斷言用 `refute_grep`，沒有寫 `! cmd`。
- 只改了所有權內的 8 個檔。
- 我改的 awk 呼叫，變數名都已避開 `DK__BRIEF_SPLIT` 內部用的名字：dk_owned 用 `w`、dk-spawn 用 `who`、brief-check 用 `n`。
- `dk_owned` 對不存在的 brief 仍回 1。舊碼會印 awk 的錯誤，新碼把 `dk_brief_owners` 的 stderr 壓掉；呼叫端 gate d 只看回傳值。
- 本任務內領導跑的是主樹腳本，gate c 剝 `HERDR_*` 這一波不會生效。

## 疑慮
- `DK__BRIEF_SPLIT` 會蓋掉同名 awk 變數，這是 lib/brief.sh 既有的地雷（不在我的所有權，我只在 dk-spawn 加了註解）。以後還有人沿用這個手法時，建議在 brief.sh 的 SPLIT 定義旁註明它佔用的變數名，或把內部變數改成 `_` 開頭，交給領導決定。
- brief-check 48 行的 `n=split(...)` 也寫在 SPLIT 後面，但那裡沒有用 `-v n`，不受影響。
