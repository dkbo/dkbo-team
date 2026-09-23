# reviewer-a 報告（波 4 審查）

差異包：waves/4.diff（since 031afa6，工作樹含未 commit，8 檔）。逐檔對照 worktree `/home/bal/project/teamflow/.worktrees/ops` 的現行內容讀，並實跑測試與 shellcheck。

## 規格合規
- AC18 ✅ 全部達成：
  - `dk-watch` 的 hit 截斷不再用 `cut -c`，改呼叫新函式 `dk_utf8_trunc`（.dkbo/lib/kinds.sh:153-169），逐位元組用 `od -An -v -tu1` 判斷是否為 UTF-8 leading byte 來計數字元、遇到第 n+1 個字元的 leading byte 就在**組回跳脫序列之前** break，不會切出半個字元；`${msg:0:200}` 也改成 `dk_utf8_trunc "$msg" 200`（.dkbo/bin/dk-watch:93、116）。
  - `.limit` 的 `hit:` 行、`dk_kinds_down_set` 存進去的第一條 hit、送給領導的 `[LIMIT]` 訊息三處都走同一條已截斷字串，皆為合法 UTF-8；訊息仍 ≤200 字元。
  - `od`／`printf` 的實作不依賴任何 locale 假設，`tests/unit/09_watch.bats` 新增「LC_ALL=C 下啟動」那條實測驗證過（跑過，通過）。
  - `tests/unit/09_watch.bats` 新增兩條中文命中行（>160 bytes）斷言：一條一般環境、一條 `LC_ALL=C`，都驗證 `hit:` 行與訊息 `refute_grep 'not valid UTF-8'`、且字元數在上限內；`tests/stub/herdr` 新增 `dk_stub_utf8_valid`，比照真 herdr 對 `agent prompt` 的第 4 個參數做 UTF-8 合法性檢查（非法則 `exit 2`，訊息 `argument 4 is not valid UTF-8`），與 reviewer 先前用真 herdr 0.9.0 實測的 `rc=2` 行為一致。
  - Minor 併修：`dk-resume` 的專案層熔斷列移出 `if [ -n "${DK_WAVE:-}" ]` 區塊，兩波之間（`DK_WAVE` 空）也印（.dkbo/bin/dk-resume:44-55，`tests/unit/10_resume.bats` 新增一條斷言，通過）；guess 標記統一成 `dk-kind` 的 `(guess)`（半形、前綴一個空白），不再用「（猜）」，全倉搜尋確認只剩註解裡提到這個字（用於解釋改動理由）、沒有功能性殘留；`lib/kinds.sh` 的 `dk_kind_recover_epoch` 在 codex 分支加上 `[ "$diff" -gt 0 ]` 判斷，目標時間已過（≤現在）改走 guess（.dkbo/lib/kinds.sh:144-147，`tests/unit/34_kind_down.bats` 新增一條「Jan 1st, 2020」樣本斷言，通過）。
  - CHANGELOG 0.12.0 的測試條數已改成 `627 bats（+75）`，跟本波實跑 `tests/run.sh` 的 `1..627` 全綠一致（8 檔改動中新增 4 條測試：09×2、10×1、34×1，623+4=627，算術對得上）；`feat(watch)` 段落補了一句解釋 `cut -c` 按位元組截斷的根因與改法，沒有跟既有段落重複。
- 全域約束：✅ 沒有 bash 4 語法（`dk_utf8_trunc` 只用 while/read/printf/算術，沒有關聯陣列）；沒有新增依賴（`od` 屬既有系統工具，非新增套件；brief 沒有列出但也沒有禁止系統內建的 `od`，且它跟 `cut`／`printf` 同層級，不算「新依賴」——若領導認為這條該收緊到只准 `date`/`git`/`jq`/`flock` 之外連 `od` 都要 ESCALATE，請裁定，我判為合規）；沒有 `date -d`；`shellcheck` 零警告，`dk_utf8_trunc` 裡動態展開的 `printf "$esc"` 有 `# shellcheck disable=SC2059` 並附理由；沒有新增 bin／新的執行期檔；`.task.env`／`settings.env` 沒改。
- 所有權：8 個改動檔（.dkbo/bin/dk-resume、.dkbo/bin/dk-watch、.dkbo/lib/kinds.sh、tests/stub/herdr、tests/unit/09_watch.bats、tests/unit/10_resume.bats、tests/unit/34_kind_down.bats 屬 backend-kinds；CHANGELOG.md 屬 backend-docs）逐一核對所有權表，沒有越界。

## Important
無。

## Minor
無新發現。（本切片屬逐波審查，不 triage 累積的 Minor）

## 做了什麼
讀了 reviewer 角色檔、PROTOCOL、PROJECT、本波切片、完整 brief.md（AC1–AC18、全域約束、所有權表）、process.md 追蹤本任務至今的裁定與前三輪 Important。逐檔讀 waves/4.diff 並對照 worktree 現行原始碼；重點驗證 `dk_utf8_trunc` 的逐位元組計數與 break 時機是否真的不切半個字元、`dk-resume` 兩波之間的印出邏輯、`dk_kind_recover_epoch` 的 guess 分支。跑了全套測試與 shellcheck，並單獨重跑 09/10/34 三個測試檔確認新增的 AC18 斷言都過。核對 8 個改動檔與所有權表。沒有改任何檔、沒有跑會寫入的指令。

## 測試
- `tests/run.sh`（worktree，全套）→ 1..627 全部 `ok`，沒有 `not ok`，exit 0
- `shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh` → 沒有輸出，exit 0
- 單獨重跑 `tests/run.sh tests/unit/09_watch.bats tests/unit/10_resume.bats tests/unit/34_kind_down.bats` → 1..110 全部 ok，確認以下三條 AC18 斷言通過：
  - `AC18: 中文命中行（>160 bytes）截斷不切半個字元，hit: 與訊息皆合法 UTF-8`
  - `AC18: dk-watch 在 LC_ALL=C 下啟動時，中文命中行照樣不切半個字元`
  - `AC18/Minor: 兩波之間（DK_WAVE 空）也印專案層熔斷，guess 標記統一成 (guess)`
- `git ls-files -s .dkbo/bin/dk-kind` → `100755`（波 4 沒動這支，沿用先前波次已驗證的權限）

## 自我審查
`dk_utf8_trunc` 的「按字元截斷不切半個字元」不是只讀程式碼推論，而是靠實跑的 09_watch 兩條新測試（含 `LC_ALL=C`）驗證過。CHANGELOG 測試條數用實跑 `tests/run.sh` 的輸出核對，不是憑 diff 裡的數字直接信。guess 標記統一與 dk-resume 兩波之間印出，都各自對照到一條通過的新測試。

## 疑慮
- `dk_utf8_trunc` 用 `od | tr | sed` 逐位元組處理，對長字串效能較差，但 `hit:` 行已先被截到 160 字元、最多 5 行，量體很小，不影響實務；純屬風格，未列 Minor。
- 全域約束「不得新增依賴」原意應該是指 herdr／git／jq／flock 之外的套件，`od` 屬 coreutils 既有工具，我判為不算新依賴；若領導認定不同，請裁定並轉 backend-kinds 改用純 bash 位元運算重寫（會犧牲一點可讀性）。
