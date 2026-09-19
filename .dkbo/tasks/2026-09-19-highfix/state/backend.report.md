# backend 報告（波 2 — 修復波，AC13–AC17）

## 做了什麼

修 reviewer-a 整枝評議的 3 條 Important（= brief 的 AC13/AC14/AC15）與 1 條 Minor（AC16）。
每條都先寫紅測試、跑它確認真的紅、再寫最小實作讓它綠。

### AC13：`dev_delivered()` 的 latch 讓「已交付」在同一波內不可逆

根因：`dk-watch:174` 原本是 `[ -f "$latch" ] && return 0`，latch 落下之後不論該成員的
state 變成什麼都算已交付。A 交件（latch 落下）→ qa 依 PROTOCOL 退件、A 改回
`status: working` → B 交齊 → 下一輪 tick 仍判「全員完成」並推聚合 `[DONE]`——跟 BACKLOG
那條「開波空窗誤發」是同一個洞，只是觸發條件換成「退件」而不是「開波空窗」。

修法（reviewer-a 建議、AC13 指定的最小修法）：
`[ -f "$latch" ] && { grep -q '^status: done' "$sf" 2>/dev/null; return $?; }`
—— latch 只豁免「內容與快照相同」那一關，`status: done` 本身仍要每輪重新確認。
`resume_unchanged_stays_done`（AC4）不受影響：那條測試裡 backend 的 state 從頭到尾都是
`status: done`，走的是同一個 `grep -q` 分支。

### AC14：三份 README 的 herdr 版號被誤標成 0.9.1

根因：波 1 出貨 0.9.1 時把 dkbo 自己的版號與 herdr 的版號混在一起改，herdr 是外部依賴、
本任務沒有升級它，`lib/common.sh` 的 `DK_HERDR_MIN` 一直是 `0.9.0`。`.dkbo/README.md:89`
疑難排解那列還把**程式實際印出的錯誤訊息原文**改錯了（`common.sh:44` 印的是
`…the 0.9.0 dkbo needs`）。`21_version.bats` 原本的版本字串測試刻意 `grep -vF herdr`
排除含 herdr 的行，所以漏網。

修法：6 處全部改回 0.9.0（`.dkbo/README.md:6`、`.dkbo/README.md:89`、`README.md:48`、
`README.md:120`、`README.en.md:48`、`README.en.md:120`）。新增
`tests/unit/21_version.bats` 一條測試，直接比對三份 README 裡 `herdr` 後面的版號字串
與 `lib/common.sh` 的 `DK_HERDR_MIN`，兩者不一致就紅。

### AC15：`kinds/claude.sh` 的 `KIND_QUOTA_RE` 有裸 `approaching your`

根因：brief 自己寫的共用契約第三列要求「`KIND_QUOTA_RE` 只描述額度已耗盡，不描述正常
啟動或工作中會出現的字樣」，而 `approaching your`（a）語意是「快到了」不是「已耗盡」，
（b）是極常見的英文片語 —— 跟被同一波修掉的 agy 裸 `quota` 是同一類洞，只是換了個 kind。

修法：`KIND_QUOTA_RE` 收窄成 `usage limit|rate limit`（claude 兩條實測過的耗盡片語）。
既有正例 `Approaching your usage limit` 仍中，因為它同時含 `usage limit` 這個子字串——
不是靠 `approaching your` 才中。`03_kinds.bats` 加一條測試：`approaching your deadline`
不命中、`You've hit your usage limit`／`rate limit` 命中。CHANGELOG 0.9.1 首節
`fix(kinds)` 那行補上這次收窄。

### AC16：`09_watch.bats` 的「agy 真的耗盡時仍標 (quota?)」測試名副其實

reviewer-a 指出這條測試只斷言 `[LIMIT]`，全檔沒有任何一條斷言 `[TIMEOUT] … 逾時 (quota?)`。
先用 scratchpad 的探針（暫時在同一條測試裡把 `$HERDR_STUB_LOG` 複製出來看，跑完就撤掉，
沒有進最終 diff）確認：`assess()`（判 `[LIMIT]`）與 reviewer 逾時迴圈（判 `[TIMEOUT]`）
是 `tick()` 裡兩個各自獨立掃 `.panes` 的迴圈，`assess()` 送出 `[LIMIT]` 不會讓下一個迴圈
跳過同一位 agent —— 所以 `(quota?)` 這條路徑其實可達，探針跑出來的 log 裡確實同時有
`[LIMIT] … login-reviewer-b 撞額度` 與 `[TIMEOUT] … login-reviewer-b 逾時 (quota?)` 兩行。

選 (a)：不是死碼，補一條正向斷言即可，不動 `dk-watch` 本身。已加
`grep -q '\[TIMEOUT\] from dk-watch: login-reviewer-b 逾時 (quota?)' "$HERDR_STUB_LOG"`。
這條补上去就是綠的（沒有先紅），因為它驗證的是既有行為，不是修 bug——見「### 測試」
AC16 那節寫「不適用」。

## 測試

新增／修改 3 條 bats：`09_watch.bats` +1（AC13）、`03_kinds.bats` +1（AC15）、
`21_version.bats` +1（AC14）；`09_watch.bats` 既有一條測試補一行斷言（AC16，非紅綠）。
全套 399 條、零 `not ok`（原 396 + 3 新增）；`shellcheck .dkbo/bin/* .dkbo/lib/*.sh
.dkbo/kinds/*.sh` rc=0、零輸出。

### 紅

AC13 —— latch 讓已交付在同一波內不可逆：

```
$ tests/run.sh tests/unit/09_watch.bats
not ok 50 latch 落下後被退回 working，不再算已交付；同波夥伴交齊也不推聚合
# (from function `refute_grep' in file tests/unit/../helpers.bash, line 125,
#  in test file tests/unit/09_watch.bats, line 444)
#   `refute_grep '全員完成' "$HERDR_STUB_LOG"' failed
# refute_grep: 不該命中卻命中了: 全員完成 /tmp/tmp.HxOPBViAr0/.herdr-calls.log
```

AC14 —— README 的 herdr 版號與 `DK_HERDR_MIN` 不一致：

```
$ tests/run.sh tests/unit/21_version.bats
not ok 3 READMEs 引用的 herdr 版號都等於 lib/common.sh 的 DK_HERDR_MIN
# (in test file tests/unit/21_version.bats, line 29)
#   `[ "$got" = "$min" ] || { echo "$f: herdr '$got' != DK_HERDR_MIN '$min'"; false; }' failed
# README.md: herdr '0.9.1' != DK_HERDR_MIN '0.9.0'
```

AC15 —— claude 的 `approaching your` 誤中正常字樣：

```
$ tests/run.sh tests/unit/03_kinds.bats
not ok 13 claude 的額度式子不再吃裸 approaching your，只認耗盡片語
# (from function `refute_quota' in file tests/unit/03_kinds.bats, line 65,
#  in test file tests/unit/03_kinds.bats, line 89)
#   `refute_quota claude 'approaching your deadline'' failed
# claude 的額度式子誤中: approaching your deadline
```

AC16：不適用: 補的是既有可達路徑的正向斷言，不是修 bug，沒有先紅（探針已在上面「做了
什麼」段落記錄怎麼確認可達）。

### 綠

AC13：

```
$ tests/run.sh tests/unit/09_watch.bats
ok 50 latch 落下後被退回 working，不再算已交付；同波夥伴交齊也不推聚合
```

AC14：

```
$ tests/run.sh tests/unit/21_version.bats
ok 3 READMEs 引用的 herdr 版號都等於 lib/common.sh 的 DK_HERDR_MIN
```

AC15：

```
$ tests/run.sh tests/unit/03_kinds.bats
ok 13 claude 的額度式子不再吃裸 approaching your，只認耗盡片語
```

AC16：

```
$ tests/run.sh tests/unit/09_watch.bats
ok 52 逾時標記：agy 真的耗盡時仍標 (quota?)
```

全套與 shellcheck（AC17）：

```
$ tests/run.sh
1..399
（ok 399 條、not ok 0 條）

$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh
（零輸出，rc=0）
```

## 自我審查

逐條驗收標準：

- AC13 ✅ `dk-watch:174` 改成 `[ -f "$latch" ] && { grep -q '^status: done' "$sf" 2>/dev/null; return $?; }`；
  `09_watch.bats:427-445` 新測試涵蓋「交件→退回 working→夥伴交齊仍不推→再改回 done 才推」
  全流程，`resume_unchanged_stays_done`（既有 :411）仍綠。
- AC14 ✅ 6 處全改回 0.9.0；`21_version.bats` 新測試直接比對 `DK_HERDR_MIN`，不是靠計數。
- AC15 ✅ `claude.sh` 的 `KIND_QUOTA_RE` 移除 `approaching your`；`03_kinds.bats:85-90`
  反例 `approaching your deadline` 不中、正例 `You've hit your usage limit`／`rate limit`
  中；CHANGELOG 補上這次收窄。
- AC16 ✅ 選 (a)：`09_watch.bats:472` 補上 `[TIMEOUT] … (quota?)` 的正向斷言；report 已
  寫清楚為何選 (a)（路徑可達，不是死碼）。
- AC17 ✅ `tests/run.sh` 399 條全綠、shellcheck 零警告、`.dkbo/VERSION` 仍 0.9.1（這波
  沒有升版號，只是修復同一個 0.9.1）；`### 紅`／`### 綠` 貼了 AC13、AC14、AC15 三組實際
  指令與輸出。

排除過的假設（依 `methods/debugging.md` 第五條）：

- 「AC13 用『latch 存的 cksum 是否等於現在的 state cksum』取代 `status: done` 判準」——
  排除。這樣會讓「交件後改成別的 working 內容又改回原本 done 內容」被誤判成沒交（波 1
  report 疑慮 2 已記過這個邊界），brief 指定的修法更小、更直接對應 Important 1 的根因。
- 「AC16 選 (b)，刪掉 `(quota?)` 標記碼」—— 排除。探針證實路徑可達且行為正確（真耗盡時
  確實標），刪掉是把可用行為當死碼砍掉，補斷言成本更低。
- 「AC15 順便把 agy／codex 的式子也重新掃一遍找同類字樣」—— 排除。brief 只指名
  `claude.sh:13`，agy／codex 已經是波 1 修過、有測試守著的實測片語，不在本波驗收範圍。

檢查過沒有副作用的地方：AC13 的修法沒有新增檔案或欄位，只改一行判斷邏輯；AC14／AC15
都是純字串替換，沒有動任何邏輯；AC16 只加斷言。改到的檔全部在切片的「可改」欄內
（`.dkbo/bin/dk-watch`、`.dkbo/kinds/claude.sh`、`.dkbo/README.md`、`README.md`、
`README.en.md`、`CHANGELOG.md`、`tests/unit/{09_watch,03_kinds,21_version}.bats`）。
沒有新增 `settings.env` 鍵、沒有新增 skill、沒有改 `tests/stub/herdr`、`.panes` 欄位順序
沒動。

## 疑慮

1. **latch 的清理仍只在 `dk-wave-close` 這一條路上**（波 1 report 疑慮 1 已記，AC13 沒有
   改動這件事）：領導若跳過 `dk-wave-close` 直接 `dk-task-close`，`.blocked/` 整個被刪掉，
   沒問題；`dk-wave-open` 擋住同波號重開，現況擋得住。
2. **reviewer-a Minor 2、Minor 3**（latch 的 key 來源不一致、`.blocked/` 目錄混了兩種語意
   不同的檔案）**不在 brief 的驗收範圍內**（brief 只點名 AC13/14/15/16 對應 Important
   1/2/3 與 Minor 1），這波沒有動；若要修建議另開任務或波次，領導視情況決定要不要記
   BACKLOG。
