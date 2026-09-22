# backend-ws 報告（波 3）
## 做了什麼
- `tests/unit/13_leader.bats:51` 的註解「任務根 tab：開在**人所在的** workspace（DK_WORKSPACE）」改成「任務所屬的 workspace」，對齊波 2 從文件清掉的講法。
- 在既有的 Important 1 正/反面測試旁補了一則 AC1 明寫但零覆蓋的分支：`DK_WORKSPACE` 與 `HERDR_WORKSPACE_ID` 都是空字串時，`dk-leader <short> --run` 要非零離開、訊息含「都是空的」、不呼叫 `tab create`、worktree／分支／`.repos` 都不建。

## 測試
### 紅
- 先把 `.dkbo/bin/dk-leader` 第 111 行（`[ -n "$ws" ] || dk_die "...都是空的..."` 的守門）暫時換成 `:`（no-op），跑 `tests/run.sh tests/unit/13_leader.bats`。
- 輸出：`not ok 10 --run: DK_WORKSPACE 與 HERDR_WORKSPACE_ID 都是空的就拒絕並說明要在 herdr 內跑（AC1）` / `` `[ "$status" -ne 0 ]' failed ``（因為守門被拿掉，`--run` 帶著空 workspace 繼續往下跑而不是死）。

### 綠
- 還原 `.dkbo/bin/dk-leader`，跑 `tests/run.sh tests/unit/13_leader.bats`。
- 輸出：`ok 10 --run: DK_WORKSPACE 與 HERDR_WORKSPACE_ID 都是空的就拒絕並說明要在 herdr 內跑（AC1）`，34 條全過。

### 全量
- `tests/run.sh`：全過，exit code 0（548 條，含新增這條）。
- `shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh`：零警告。

## 自我審查
- 排除了「守門邏輯本來就沒實作」的假設：讀 `.dkbo/bin/dk-leader:107-112` 發現實作（含中文訊息「都是空的」）本來就在，只是缺測試覆蓋；所以本波是純補測試 + 改註解，沒動實作。
- 否定斷言全改用 `refute_grep`（不寫 `! grep -q`），worktree 清單與分支清單先落檔再 `refute_grep`，因為 `refute_grep` 簽名是對檔案而非 stdin。
- 確認 `git status` 裡的 `CHANGELOG.md` 修改不是我這波動的（不在我的所有權表），沒有覆蓋或還原它。

## 疑慮
無。
