# backend-docs 報告（波 1）
## 做了什麼
- AC7 run SKILL「每次醒來先做」第 1 條（`.dkbo/skills/run/SKILL.md:16`）就地改寫 watcher 句：重啟時機加 `dk-msg`（員工送 `[DONE]` 時）、process 記 `watch died`、死因看 `.sessions/<任務>.watch.log`；不加行，仍 58 行（≤60）。
- AC7 `.dkbo/PROJECT.md`：測試指令那句改成 shellcheck 由 `tests/unit/37_shellcheck.bats` 守（沒裝就 skip），集合同全域約束（含 install.sh、tests/run.sh）；刪掉「不在 run.sh 裡……沒有機械閘」與舊集合；目錄慣例補 helpers 複製 `.dkbo` 的行為。
- AC7 CHANGELOG 0.16.0 節在「測試：」行之前追加 feat(watch)、fix(wave-close)、fix(ownership)、test、docs(run) 五條；測試行改成實跑值 `754 bats（+98；…；守望與測試可信度 +30：…）`，括號內列本任務各檔新增條數。
- AC7 `tests/unit/21_version.bats` 首節清單補 `fix(wave-close)` `HERDR_*` `setsid` `watch.log` `watch died` `fix(ownership)` `first_glob` `test:` `37_shellcheck` `fixture_copy_dkbo` `空 branch` `docs(run)`。
- AC8 `.dkbo/tasks/BACKLOG.md` 用 python 逐字比對 request.md「外部文件」段的 6 列刪除（每列先 assert 恰好出現一次），其餘行一字不動（剩表頭 2 行＋4 列＋說明句）。
## 測試
### 紅
`tests/run.sh tests/unit/21_version.bats`（先補 21 的新條目斷言、CHANGELOG 尚未追加）
`not ok 6 CHANGELOG 首節列出本版的每一條變更` / `# CHANGELOG 首節缺 fix(wave-close)`
### 綠
`tests/run.sh tests/unit/21_version.bats` → `ok 6 CHANGELOG 首節列出本版的每一條變更`
`tests/run.sh tests/unit/21_version.bats tests/unit/04_docs.bats tests/unit/25_docs_policy.bats` → 1..34，34 ok（改完測試條數後重跑）
### 完整實跑（三則 [DONE] 到齊後）
`tests/run.sh`（worktree，rc=0）→ `1..754`，754 ok、0 not ok；`ok 752 全域約束的檔案集合 shellcheck 零警告` 是實跑、非 skip。
條數核對：對 HEAD 逐檔數 `^@test`：06 57→61、07 34→35、08 41→43、09 74→84、11 40→41、16 34→35、22 10→12、26 26→29、36 9→12、37 0→3，合計 +30；724+30=754，與實跑一致；增量 754−656=98。
helpers 回歸把關：全套 0 紅，無需送 [BUG]。
AC8 取紅不適用：純文件刪列；以 python 對 request.md 6 列逐字 assert 各出現一次後刪除。
## 自我審查
- run SKILL 第 1 條同時含 `dk-msg`、`watch.log`、`watch died`（grep 核對），58 行 ≤60；PROJECT.md 8 行 ≤40。
- CHANGELOG 條目對過實作：`dk-watch:22-31`（setsid、HUP）、`:58`/`:76`（lock、watch died）、`dk-wave-close:122`（`${!HERDR_@}`）、`dk-msg:76-80`（--ensure）、`tests/helpers.bash:46`（fixture_copy_dkbo）、37 的三條標題。
- 沒升版，VERSION／README `VER=` 未動；只改所有權內 5 檔。
## 疑慮
- run SKILL 照 AC7 寫「dk-msg（員工送 `[DONE]` 時）」，實作其實是 dk-msg 每個寫 log 的出口都 --ensure；文字比實作窄但不矛盾。
- 若修復波新增測試，CHANGELOG 條數要等領導 `[TASK] 補測試條數` 重填。

## 修復輪（leader [TASK] 補測試條數）
### 做了什麼
- CHANGELOG feat(watch) 補：dk-msg 在 `.panes` 已不在（任務已結案）時不叫回守望；`dk-task-new` 的第一對守望改走 `--ensure`（對照 `dk-msg:78-83`、`dk-task-new:97-103`）。
- 測試行改成 `756 bats（+100；…；守望與測試可信度 +32：…）`，06 改 +5（含結案後不叫回）、補 05_task_new +1。
### 測試
`tests/run.sh`（worktree，rc=0）→ `1..756`，756 ok、0 not ok、無 skip。
條數核對：05 30→31、06 57→62，其餘同上輪；724+32=756，增量 756−656=100。
`tests/run.sh tests/unit/21_version.bats tests/unit/04_docs.bats tests/unit/25_docs_policy.bats` → 34 ok（改完條數後重跑）。
### 紅／綠
不適用: 只改 CHANGELOG 文字與條數，21 的既有斷言已涵蓋格式（測試行必須是數字）。
