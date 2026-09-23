# backend-kinds 報告（波 4）

## 做了什麼
AC18：`[LIMIT]` 的 `hit:` 行按位元組截斷（`cut -c1-160`）會切出半個 UTF-8 字元，讓 herdr 拒收整則
`[LIMIT]`（reviewer-a Important 1，本輪重現並修）。改法：
- `.dkbo/lib/kinds.sh` 新增 `dk_utf8_trunc TEXT N`：用 `od -An -v -tu1` 逐位元組讀（純數字運算，
  不靠 `grep -o .`／`read` 對文字的 locale 假設——除錯過程中發現那條路子在某些環境下會把含半個
  UTF-8 字元的整行直接吞掉，比 `cut -c` 更難察覺），只在字元邊界（非延續位元組）累計字元數，
  超過 N 就停；再用 `printf` 的八進位跳脫把位元組組回字串。locale 中立，`LC_ALL=C` 下行為相同。
- `.dkbo/bin/dk-watch` 的 `handle_limit`：`hit:` 每行、送給領導的 `[LIMIT]` 訊息都改用
  `dk_utf8_trunc` 截斷，不再用 `cut -c1-160` 或 `${msg:0:200}`。
- `tests/stub/herdr`：加 `agent prompt` 的 UTF-8 驗證（比照真 herdr 拒收非 UTF-8 參數，rc=2），
  09_watch 才抓得到截斷是不是按位元組切的；驗證函式同樣走 `od` 逐位元組讀，不用 `grep -o .`。
- `tests/unit/09_watch.bats` 補中文命中行（>160 bytes）斷言兩條：一條在 ambient locale、一條在
  `LC_ALL=C` 下啟動 dk-watch，各驗 `.limit` 的 `hit:` 行有寫出、與送出的訊息都是合法 UTF-8、
  長度在上限內。

Minor（reviewer-a 本輪）：
- `.dkbo/bin/dk-resume`：專案層熔斷（`dk_kinds_down_rows`）的印法移出 `DK_WAVE` 判斷，兩波之間
  （`DK_WAVE` 空）也印；`guess` 標記統一成 `dk-kind` 的 `(guess)`，不再用「（猜）」。
- `.dkbo/lib/kinds.sh` 的 `dk_kind_recover_epoch`：codex 分支算出的 `diff` ≤ 0（目標時間已過，
  例如時區不一致）時不再誤標 `exact`，改走現在＋5 小時的 `guess` 退路。

## 測試
### 紅
指令：`git stash push -u -- .dkbo/bin/dk-watch .dkbo/lib/kinds.sh .dkbo/bin/dk-resume`（暫時退回修法前的版本，只留新斷言）
再跑：`tests/run.sh tests/unit/09_watch.bats`，原始輸出：
```
not ok 63 AC18: 中文命中行（>160 bytes）截斷不切半個字元，hit: 與訊息皆合法 UTF-8
# (in test file tests/unit/09_watch.bats, line 563)
#   `[ -n "$hl" ]   # 用 read 逐行取出 hits 時，含半個 UTF-8 字元的行會被 bash 的 read 整行吞掉' failed
not ok 64 AC18: dk-watch 在 LC_ALL=C 下啟動時，中文命中行照樣不切半個字元
# (in test file tests/unit/09_watch.bats, line 577)
#   `[ -n "$hl" ]' failed
```
根因：`.limit` 只剩 `notified`，因為原本 `cut -c1-160` 切出半個 UTF-8 字元後，後續
`while read -r hl <<< "$hits"` 把含半個字元的整行直接吞掉，比 reviewer 描述的「送出無效 UTF-8」
更隱蔽（連 hit: 行都不見了，訊息也少了 hit 後綴）。

### 綠
指令：`git stash pop`（復原修法）後再跑 `tests/run.sh tests/unit/09_watch.bats`，原始輸出：
```
ok 62 AC5: 輪詢路徑撞額度時 .limit 檔留下 hit: 行，訊息尾端附第一條
ok 63 AC18: 中文命中行（>160 bytes）截斷不切半個字元，hit: 與訊息皆合法 UTF-8
ok 64 AC18: dk-watch 在 LC_ALL=C 下啟動時，中文命中行照樣不切半個字元
ok 65 AC5: 三個上限——hit: 最多 5 行、每行截 160 字、[LIMIT] 訊息 ≤200 字
```
全套指令：`tests/run.sh`，原始輸出（尾三行）：
```
ok 625 dk-kind up：不是 kinds/*.sh 裡的 kind 就 exit 2
ok 626 dk-kind：usage 錯誤 exit 2
ok 627 dk-kind 以 100755 的權限存在（git ls-files -s 在結案 commit 後會看到這個 mode）
```
統計：`grep -c '^not ok' /tmp/full_run.txt` → `0`；`grep -c '^ok ' /tmp/full_run.txt` → `627`。
shellcheck：`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh` → 無輸出，`echo $?` → `0`。

## 自我審查
- 排除過的假設：一開始以為 bug 只是「切出無效 UTF-8」，用 `cut -c1-160` 加中文樣本測，發現在本機
  glibc（C.UTF-8）下 `cut -c` 其實按位元組算（brief 與 reviewer 的判斷成立），但 bug 真正在測試
  裡浮現的路徑不是「送出無效 UTF-8」，而是後續 `while read -r <<< "$hits"` 直接把含半個字元的
  整行吞掉，導致 `.limit` 檔連 `hit:` 都沒有——如果只斷言「訊息不含 not valid UTF-8」會誤判成過，
  改斷言「`hit:` 行確實存在」才抓到。
- 第一版 `dk_utf8_trunc`／stub 的 UTF-8 驗證都用 `LC_ALL=C grep -o .` 逐字元讀，結果在這台機器的
  互動 shell 裡 `grep` 被 Claude Code 自帶的函式覆寫、行為跟真正的 GNU grep 不同，一度誤判修好了；
  改用純 `bash -c`／`tests/run.sh` 實跑才發現 `dk_stub_utf8_valid` 對中文字串一律回傳失敗，
  波及既有 07/09/10 的多條 `dk-spawn` 測試。改成 `od -An -v -tu1` 純數字管線後不再依賴 shell
  對文字的假設，全套測試（627 條）跑過確認沒有回歸。
- 全域約束：沒有新增依賴（`od` 與 `printf` 都是既有 shell 內建／coreutils，其他測試檔也已經在用
  同類工具）；`dk_utf8_trunc`／`dk_stub_utf8_valid` 都不呼叫 `date -d`；bash 3.2+ 語法（沒有
  關聯陣列、`${x^^}`、`declare -A`、`mapfile`）。
- 只改了切片所有權表劃給我的檔案：`.dkbo/bin/dk-watch`、`.dkbo/bin/dk-resume`、
  `.dkbo/lib/kinds.sh`、`tests/stub/herdr`、`tests/unit/09_watch.bats`、`tests/unit/10_resume.bats`、
  `tests/unit/34_kind_down.bats`。
- 領導跑的是主樹的腳本：本波這些修法在本任務內不會生效，要等結案合併後的下一個任務才起作用，
  這份 report 沒有宣稱「本波已用到」。

## 疑慮
- `dk_utf8_trunc` 假設輸入本身是合法 UTF-8（正常情況下畫面文字都是）；若輸入含真正非法的位元組
  （不是延續位元組該有的樣子），函式只保證「輸出不含被截斷的半個字元」，不保證把非法位元組修正
  成合法——這超出 AC18 的範圍（AC18 只要求截斷不切壞，沒有要求清洗上游本就非法的輸入）。
- `tests/stub/herdr` 新增的 `dk_stub_utf8_valid` 只驗 `agent prompt` 的第 4 個參數；其他子命令
  （如 `notification show`）目前沒有中文內容會踩到位元組截斷，故未加驗證，維持切片範圍內。
