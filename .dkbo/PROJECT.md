# 專案事實（≤40 行；由 init skill 預填，領導或 it 維護）
- 技術棧：純 bash 3.2+ 腳本（`.dkbo/bin/dk-*` 與 `.dkbo/lib/*.sh`），依賴 jq、git、herdr 0.9.0；沒有任何套件管理器。
- 安裝 / 啟動：這裡是 dkbo 的原始碼倉，`.dkbo/` 是產品本身，**不要在本倉跑 `install.sh`**；領導以指名 `.dkbo/skills/*/SKILL.md` 進場。
- 測試指令：`tests/run.sh`（bats-core，第一次跑會 clone 進 `tests/lib/`）。shellcheck **不在** run.sh 裡，要另外跑 `shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh`，目前沒有機械閘守它。單檔：`tests/run.sh tests/unit/09_watch.bats`。
- 目錄慣例：`tests/unit/NN_name.bats` 兩位數遞增；`tests/stub/herdr` 是假 herdr（零 token），`tests/stub/cli/*` 是假的 claude/codex/agy；`tests/helpers.bash` 建臨時專案並洗掉繼承的 `DK_*`。`docs/` 被 gitignore（設計文件不進版控）。
- 已知坑：`lib/common.sh` 幾乎每個變數都是 `${DK_X:-預設}`，繼承值優先 —— 任何會 source 它的測試或子行程都要先 unset `DK_*`，否則會打到真 repo。領導跑的是主樹的腳本，員工在 worktree 改 `.dkbo/` 的成果要等合併後的下一個任務才生效。
- 多 repo（0.10.0）：`settings.env` 的 `DK_REPOS` 空字串＝本倉是單 repo 專案，行為與 0.9.2 相同；`dk-leader <short> --run` 才會依 `DK_REPOS` 切 worktree、開任務專屬 herdr workspace 並交棒，`dk-task-new` 只建任務資料夾。多 repo 的檔案所有權、`touched`、`file:line` 一律 `<名>:` 前綴。
