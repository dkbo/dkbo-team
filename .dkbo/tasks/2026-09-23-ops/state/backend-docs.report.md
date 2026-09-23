# backend-docs 報告（波 3）
## 做了什麼
- `.dkbo/skills/run/SKILL.md`（AC17 的 SKILL.md 半邊）：
  - 「每次醒來先做」新增第 3 條：送 `[TASK]`／`[DECISION]` 前先讀未 ack 訊息（原本掛在故障段尾巴，現拆出並移入本段）。
  - 「跑一波」新增第 9 條：波中改 brief 的做法（改 brief.md → `dk-wave-open <N> --refresh` → dk-msg 員工重讀切片 → 新成員接著 dk-spawn），並補上「只請原 dev 重做時，`[TASK]` 裡叫他完成後回 `[FIXED]`（聚合不會重推）」。
  - 「結案」新增第 1 條：有視覺變更的任務，最後一波結波後、`dk-review-pack --task` 之前先請人看畫面；原有兩條順移為第 2、3 條。
  - 故障段移除原本浮在段尾、沒有小標的「未 ack」與「請人看」兩句合併句（已拆條移到上面兩處）。
  - 全文仍維持 50 行（`04_docs.bats` 的上限），移動內容時淨行數抵銷（新增 3 行、刪除 3 行）。
- `tests/unit/25_docs_policy.bats`：新增一條斷言 `AC17: 波中改 brief 只請原 dev 重做時要回 [FIXED]，不再回 [DONE]`，grep `回 \`[FIXED]\`` 守住這句用語。

## 測試
### 紅
- 指令：把 `.dkbo/skills/run/SKILL.md` 暫時還原成 HEAD 版本（尚未加 `[FIXED]` 一句），跑 `tests/run.sh tests/unit/25_docs_policy.bats`
- 輸出：`not ok 7 AC17: 波中改 brief 只請原 dev 重做時要回 [FIXED]，不再回 [DONE]` — `grep -q -- '回 \`\[FIXED\]\`' "$DK_ROOT/skills/run/SKILL.md"' failed`

### 綠
- 指令：還原成本波修改後的 `.dkbo/skills/run/SKILL.md`，再跑 `tests/run.sh tests/unit/25_docs_policy.bats`
- 輸出：`1..7` 全部 `ok`，含 `ok 7 AC17: 波中改 brief 只請原 dev 重做時要回 [FIXED]，不再回 [DONE]`

另外跑過：
- `tests/run.sh tests/unit/21_version.bats tests/unit/04_docs.bats` → `1..16` 全 `ok`（含 `wc -l` ≤50 的行數上限與各字串斷言）
- `shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh` → 無輸出，exit 0（零警告；本波未改任何 shell 檔）

## 自我審查
- 移位後 25/04 既有 grep（`hit:`、`dk-kind up`、`未 ack`、`wave-open <N> --refresh`、`請人看`、`\[TIMEOUT\]`、`dk-wave-close --agent`、`review N skipped`、`--task`、`dk-task-close` 等）仍全部命中，未因搬動或改寫措辭而失效。
- 只改了切片所有權內的檔案（`.dkbo/skills/run/SKILL.md`、`tests/unit/25_docs_policy.bats`），未動 `.dkbo/bin/**`、`.dkbo/lib/**`、`tests/helpers.bash`。
- 全文仍是繁體中文，用語與既有段落風格一致（動詞＋冒號的條列）。

## 疑慮
無。

## 追加（領導 [TASK]）
- 做了什麼：`CHANGELOG.md:11` 的「614 bats（+62）」改成「623 bats（+71）」，對齊波 3 後 `tests/run.sh` 的實跑筆數。
- 測試：不適用: 純數字改動非行為，無對應紅/綠；改完跑 `tests/run.sh` 全量驗證，尾端印 `ok 623 dk-kind 以 100755 的權限存在（git ls-files -s 在結案 commit 後會看到這個 mode）`、`[exited with code 0]`，實際總數 623 與新文案一致，且沒有任何測試斷言硬編這個數字（`grep -rn '614\|623\|bats（+' tests/unit/*.bats` 無結果）。
- 已回 `[FIXED]` 給 leader（根因：CHANGELOG 沿用了波 1/2 當下的舊統計，未在波 3 新增測試後更新）。

# backend-docs 報告（波 4）
## 做了什麼
等 backend-kinds 完成 AC18（state 轉 done，touched 含 `.dkbo/bin/dk-watch`、`.dkbo/bin/dk-resume`、`.dkbo/lib/kinds.sh`、`tests/stub/herdr`、`tests/unit/09_watch.bats`、`tests/unit/10_resume.bats`、`tests/unit/34_kind_down.bats`）後，在 worktree（`/home/bal/project/teamflow/.worktrees/ops`）跑全量 `tests/run.sh` 取得實跑條數 627（552 + AC1-18 累積 75 條），據此改 `CHANGELOG.md`：
- 0.12.0 節的「測試」行條數從舊文案改成「627 bats（+75）」。
- `feat(watch)` 那條 `[LIMIT]` 證據段落補一句：`hit:` 行的截斷改按字元數（不是位元組），說明原本 `cut -c` 在 GNU 環境按位元組截、中文命中行會切出半個 UTF-8 字元讓真 herdr 拒收參數（對應 reviewer-a 波 task 複看提的 Important 1、backend-kinds AC18 的修復），並點出 `.limit` 的 `hit:` 行、kinds-down 第一條 hit、送出的 `[LIMIT]` 訊息三處都保證合法 UTF-8。

## 測試
### 紅
不適用: 本波只改 CHANGELOG.md 的說明文字（測試條數與敘述），不是行為改動，沒有對應可失敗的測試。

### 綠
不適用: 同上；改完後用全量測試結果驗證數字正確，見下。

另外跑過：
- `tests/run.sh`（全量，worktree `.worktrees/ops`）→ `1..627` 全 `ok`，`EXIT:0`，尾端 `ok 627 dk-kind 以 100755 的權限存在（git ls-files -s 在結案 commit 後會看到這個 mode）`。
- `grep -rn '623\|627\|bats（+' tests/unit/*.bats CHANGELOG.md` → 只有 CHANGELOG.md 各版本行含這個模式，`tests/unit/*.bats` 無命中，確認沒有測試硬編這個數字（沿用波 3 教訓）。
- `grep -n "feat(kinds)\|CHANGELOG" tests/unit/21_version.bats` → 首節斷言只檢查含 `feat(kinds)` 字串，不比對條數，改動不影響它。

## 自我審查
- 只改了切片所有權內的 `CHANGELOG.md`，未動 `.dkbo/bin/**`、`.dkbo/lib/**`、`tests/helpers.bash` 或其他人本波的檔案。
- 條數 627 與本次 worktree 實跑一致（非估算），且與 backend-kinds state notes 記的「627 條全過」互相印證。
- 補的 `[LIMIT]` 說明文字用語對齊 backend-kinds AC18 的實作方向（按字元截、UTF-8 合法），未捏造未實作的行為。

## 疑慮
無。

