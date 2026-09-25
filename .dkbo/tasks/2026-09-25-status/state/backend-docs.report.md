# backend-docs 報告（波 1）
## 做了什麼
- `tests/unit/21_version.bats`：「CHANGELOG 首節列出本版的每一條變更」的清單整份換成 0.17.0 條目（`feat(status)`、`dk-status --json`、`dk-status --json <任務>`、`唯讀`、`不呼叫 herdr`、`schema_version`、`只加欄位不升`、`status-schema.md`、`kinds_down`、`skipped_lines`、`docs(readme)`、`給 dashboard 讀的 JSON`、`test:`、`38_status`、`測試：`）；條數實跑值斷言與版號總數 8 不動。
- `.dkbo/VERSION` 0.16.0 → 0.17.0；三份 README 八處版號同步（總數仍 8）。
- `README.md`、`README.en.md` 指令表在 `dk-timeline` 後加 `dk-status --json [<任務>]` 一列；`.dkbo/README.md` 沒有指令表，在「日常使用」段加一條，並在「## 目錄」前新增「## 給 dashboard 讀的 JSON」段（兩種用法、exit 碼、不呼叫 herdr、相容規則一句、連到 status-schema.md）。
- `CHANGELOG.md` 新節 `## 0.17.0 — 2026-09-25`：feat(status)、docs(status)、docs(readme)、test、測試行、升級行。
## 測試
### 紅
先改 `21_version` 首節清單（CHANGELOG 還是 0.16.0 節）：
```
$ tests/run.sh tests/unit/21_version.bats
not ok 6 CHANGELOG 首節列出本版的每一條變更
# CHANGELOG 首節缺 feat(status)
```
再把 `.dkbo/VERSION` 改成 0.17.0（README、CHANGELOG 未動）：
```
$ tests/run.sh tests/unit/21_version.bats
not ok 2 every dkbo version string in the READMEs matches .dkbo/VERSION
# README.md: '0.16.0' != .dkbo/VERSION '0.17.0'
not ok 5 the newest CHANGELOG section matches .dkbo/VERSION
not ok 6 CHANGELOG 首節列出本版的每一條變更
```
同步 README 版號、寫 CHANGELOG 新節（測試行留 `{N}` 佔位）後：
```
$ tests/run.sh tests/unit/21_version.bats
ok 1 … ok 5
not ok 6 CHANGELOG 首節列出本版的每一條變更
# CHANGELOG 首節測試條數仍是佔位
```
### 綠
收到 backend-status 的 `[DONE]` 後，CHANGELOG 測試行填 `771 bats（+15；新增 38_status 15 條…）`（771−756＝15，38 靜態計數 15），在 worktree 跑完整測試：
```
$ tests/run.sh > full.log; echo rc=$?
rc=0
1..771   （ok 771 條、not ok 0、# skip 0）
ok 562 CHANGELOG 首節列出本版的每一條變更
ok 733 tests/ 裡沒有 ! 開頭的否定述句（改用 refute_grep 或 refute）
ok 754 全域約束的檔案集合 shellcheck 零警告（實跑，沒有 skip）
```
文件相關單檔（04_docs、14_install、23_leader_kind、24_portability、25_docs_policy、32_timeline）改完當下各跑一次，全綠。
## 自我審查
- 版號總數仍 8（21 第 2 條綠）；新段落沒有新增任何 x.y.z 字串，也沒有 `rsync -a` 開頭的行（不影響 14_install 的 eval）。
- CHANGELOG feat(status) 的 stderr 文案、exit 碼、頂層鍵與 backend-status 的實作逐一對過（實跑 `dk-status` 無參數得 rc=2 與同一句文案）。
- 21_version 只換首節清單，條數斷言與其他五條不動（ruling 見 process.md 第 5 行）。
- `.dkbo/README.md` 沒有指令表，「加一列」落在「日常使用」段的一條，另加「給 dashboard 讀的 JSON」專段。
## 疑慮
- 在員工 pane 直接跑 worktree 的 `dk-status --json`，`dkbo_version` 印 0.16.0：繼承的 `DK_ROOT` 指主樹（PROJECT.md 已知坑），不是實作錯；測試夾具會洗掉 DK_*，所以不受影響。
- CHANGELOG 節日期寫 2026-09-25（今天）；若結案日不同，領導結案時改日期即可，21 不檢查日期。

## 複跑（backend-status [FIXED] Minor1／Minor2 之後）
38 增為 16 條（新增「AC4 members 依檔名（含 .md）碼點升冪」），CHANGELOG 測試行改成 `772 bats（+16；新增 38_status 16 條…AC4 四條（含 members 依檔名碼點排序）…）`，再跑完整測試：
```
$ tests/run.sh > full2.log; echo rc=$?
rc=0
1..772   （ok 772、not ok 0、# skip 0）
ok 562 CHANGELOG 首節列出本版的每一條變更
ok 754 全域約束的檔案集合 shellcheck 零警告
```
