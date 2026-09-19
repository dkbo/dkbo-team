# reviewer-a 報告（波 2 — 修復波，AC13–AC17）

## 規格合規
- [x] AC13 `dev_delivered()` 的 latch 修法：`dk-watch:176`
  `[ -f "$latch" ] && { grep -q '^status: done' "$sf" 2>/dev/null; return $?; }`。
  逐行手追蹤 `09_watch.bats` 新測試三段流程（A 交件落 latch → qa 退回 working、B 交齊仍不推
  → A 再改回 done 才推），確認 `dev_delivered()` 在每一步的回傳值與測試斷言一致；
  `resume_unchanged_stays_done`（既有 `09_watch.bats:411`，AC4）沒被這波觸動，回歸安全。✅
- [x] AC14 三份 README 六處 herdr 版號改回 0.9.0：`.dkbo/README.md:6`、`.dkbo/README.md:89`、
  `README.md:48`（快速開始前置）、`README.md:120`（tests/integration 那行）、
  `README.en.md:48`、`README.en.md:120`，與 `lib/common.sh:25` 的 `DK_HERDR_MIN="0.9.0"` 一致
  （已跑 `grep -n DK_HERDR_MIN`確認）。新測試直接比對三檔字串與 `DK_HERDR_MIN`，不是計數法。✅
- [x] AC15 `kinds/claude.sh:13` 的 `KIND_QUOTA_RE` 收窄為 `'usage limit|rate limit'`，移除裸
  `approaching your`；`03_kinds.bats` 新測試反例 `approaching your deadline` 不中、正例
  `You've hit your usage limit`／`rate limit` 中；CHANGELOG `fix(kinds)` 行已補上這次收窄的說明。✅
- [x] AC16 `09_watch.bats` 既有「agy 真的耗盡時仍標 (quota?)」測試補上
  `[TIMEOUT] … 逾時 (quota?)` 正向斷言。核對 `dk-watch` 原始碼確認 dev report 的判斷屬實：
  `tick()` 裡 `assess()`（第一個 `while read` 迴圈，推 `[LIMIT]`）與 reviewer 逾時檢查
  （第二個獨立 `while read` 迴圈，推 `[TIMEOUT] (quota?)`）各自獨立掃 `.panes`，同一位
  agent 的畫面文字會被兩個迴圈各自讀一次、各自判斷，彼此不互斥 —— 選 (a) 補斷言而非死碼判定正確。✅
- [x] AC17 檔案所有權核對：本波 9 個變動檔（`.dkbo/README.md`、`.dkbo/bin/dk-watch`、
  `.dkbo/kinds/claude.sh`、`CHANGELOG.md`、`README.en.md`、`README.md`、
  `tests/unit/{03_kinds,09_watch,21_version}.bats`）全在 backend 的「可改」清單內，
  state 的 `touched` 與 diff stat 的檔案清單一致，無越界改檔。CHANGELOG 首節 0.9.1
  五處版本字串（VERSION 不變、README 三份 + CHANGELOG 首節）仍一致；report 的
  `### 紅`／`### 綠` 貼了 AC13、AC14、AC15 三組實際指令與輸出，符合模板要求。✅

## Important
（無）

## Minor
本波累積 Minor 4 條的 triage 判定已在領導 verdict（`process.md:27-33`）與 backend report
一併記錄：Minor 1 本波用 AC16 修掉（已驗證，見上）；Minor 2／3／4 領導與 dev 都已判「留著」
（別名與 .panes 名不一致、`.blocked/` 語意混雜、`${!DK_@}` 未在 macOS 實機驗），本波 brief
未把它們排進驗收範圍，同意留到下次動這塊時一併處理，不在本波追加。

## 自我審查
- 對 AC13 的判定沒有只信 dev report 的「紅／綠」貼文，而是照 `dk-watch:171-180` 原始碼手動
  推演三段測試的每一步回傳值，確認邏輯自洽而非巧合過關。
- 對 AC16 特別去讀 `tick()` 全函式（第 182-263 行），確認「兩個迴圈各自獨立掃 `.panes`」
  這個關鍵前提為真，而不是照抄 dev report 的說法。
- 檔案所有權、版本字串一致性都用 `grep`／`diff` 交叉核對過實際檔案內容，不是只看 report 自述。

## 疑慮
無新增疑慮；Minor 2／3／4 的「留著」判定沿用領導既有 ruling，本報告不重新開議。

## 測試
不適用：reviewer 只讀不跑會寫入的指令，未自行執行 `tests/run.sh`；AC13/14/15 的紅綠佐證
已由 backend report（`state/backend.report.md` 的 `### 紅`／`### 綠`）提供，本報告改以逐行
核對原始碼與 diff 的方式驗證其正確性（見上「規格合規」與「自我審查」）。
