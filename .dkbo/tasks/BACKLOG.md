| 日期 | 來源 | 一句描述 | 建議處理 |
|---|---|---|---|
| 2026-09-19 | highfix 波 1 疑慮 | `kinds/agy.sh` 的 `KIND_BLOCK_RE` 沒有資料夾信任詢問的畫面字樣（agy 的 `trustedWorkspaces` 逐路徑精確比對、不繼承上層，新 worktree 第一次跑必問），守望認不出這種卡住 | 下次實跑 agy 員工時把信任詢問的原文抄進 `KIND_BLOCK_RE`，順便決定要不要由 dkbo 代寫全域信任設定（decisions.md 2026-09-19 那條尾巴）；多 repo 任務是 N 個 worktree 各問一次（原 multirepo 結案那條併進來） |
| 2026-09-20 | multirepo 結案（2026-09-24 改寫） | 單 repo 的 `dk-leader --run` 交棒已在真 herdr 實跑三次：2026-09-22 tasktab（主樹仍是 0.10.0，走 `workspace create`）、2026-09-23 ops（0.11.0 起開 tab，`materialize … tab wB:tJ`）與 2026-09-24 testtrust（`materialize … tab wB:tK`）；**多 repo** 的交棒路徑（逐 repo 切 worktree、逐 repo 跑 `DK_SETUP_CMD_<名>`）仍沒在真 herdr 上走過 | 第一個設了 `DK_REPOS` 的專案就是第一次實跑；跑之前先 `dk-resume` 看 `.repos`，交棒失敗時 pane 會留著，`herdr pane read` 看它 |
| 2026-09-20 | multirepo 結案 | `setup.<名>.log`（`DK_SETUP_CMD` 的輸出）落在 `tasks/<t>/` 進任務記憶，一次 `pnpm install` 的輸出就進版控 | 觀察體積；太大就改寫到 `.sessions/` 並加 gitignore，一行的事 |
| 2026-09-23 | ops 整枝評議第三輪 Minor | codex 在重置時間是同一天時可能只印 `try again at 3:15 PM`（不帶日期），目前會落 guess＝現在＋5h；未實測 | 下次 codex 撞額度時收一份真樣本；若屬實，`dk_kind_parse_codex_reset` 補「只有時分」的分支（今天，已過則明天） |

已修好的條目在修掉它的同一個 commit 裡整列刪掉，不留「已修」標記；表頭固定佔前兩行（`dk-resume` 讀 `head -n 2`），說明只能寫在表格之後。
