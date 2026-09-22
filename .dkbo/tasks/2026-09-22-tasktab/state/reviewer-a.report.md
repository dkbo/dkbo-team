## 規格合規
- ✅ 波 4 任務項1：`tests/integration/README.md:202`「在人所在的 workspace 裡開新 tab」與 `:206`「DK_WORKSPACE 從此固定是人所在的 workspace」皆已改成「任務所屬的 workspace（`.task.env` 的 `DK_WORKSPACE`，計畫時記下；空時退回 `HERDR_WORKSPACE_ID`）」，與波 3 CHANGELOG 修法措辭一致。
- ✅ 波 4 任務項2（根因修法）：`tests/unit/25_docs_policy.bats:39` 的 Important4 斷言由硬編六檔清單改成掃 `git -C "$REPO_ROOT" ls-files` 的全部追蹤檔，排除 `.dkbo/tasks/*` 與自身 `tests/unit/25_docs_policy.bats`；經全倉複查（`git ls-files` 排除同樣兩項）確認目前無 `人所在的 workspace|你所在的 workspace|時所在的那個 workspace|workspace you're` 殘留。
- ✅ 完成條件：21/25/04 三個 bats 檔獨立重跑全過（1..21 ok）；`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh` 零警告；report「## 測試」段有紅綠兩段且交代了排除規則。
- ❌ 缺漏（輕微）：完成條件明寫「並交代新斷言掃了幾個檔」，report 只寫「非固定六檔」，未給實際數字（複查得 142 個追蹤檔，排除 `.dkbo/tasks/**` 與自身後）。不影響斷言正確性，見 Minor。
- 全域約束：否定斷言用 `refute_grep`（非 `! grep -q`），bash 3.2 相容（`case`/`while read < <(...)` 皆非 bash4 專屬語法），只改所有權表劃給 backend-docs 的兩檔，均合規。

## Important
（無）

## Minor
- `tests/unit/25_docs_policy.bats:39` 附近／report.md 的「## 測試」段：完成條件要求「交代新斷言掃了幾個檔」，report 只寫「非固定六檔」沒給具體數字；建議下次寫具體計數（本次複查為 142，`git ls-files` 排除 `.dkbo/tasks/**` 與自身後）。file: `/home/bal/project/teamflow/.dkbo/tasks/2026-09-22-tasktab/state/backend-docs.report.md:20`
