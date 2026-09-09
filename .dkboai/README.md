# dkboai

以 herdr 為底的多模型 AI 團隊：一位領導（Claude Code）在主 pane 審查需求、拆波、派工、決策；員工（claude / codex / agy）各佔一個 pane 實作、測試、互相傳訊；所有記憶是小型 markdown，領導失憶可一鍵恢復。設計文件：`docs/superpowers/specs/2026-09-09-dkboai-ai-team-design.md`。

## 前置需求
- herdr ≥ 0.9.0（`herdr --version`），且你在 herdr 的 pane 裡（`echo $HERDR_ENV` 印 `1`）。
- git、jq、bash 5。
- 至少一個 AI CLI：`claude`（必要，領導用）。可選 `codex`、`agy`（第二、第三意見）。
- 目標專案是 git repo，且工作樹乾淨。

## 給 AI 的一鍵安裝
把下面整段貼給在 herdr 內、目標專案根目錄開啟的 Claude Code（或任何能跑 bash 的 agent）：

> 請在目前專案安裝 dkboai。依序執行以下指令，任何一步失敗就停下回報，不要自行變通：
>
> ```bash
> test "$HERDR_ENV" = 1 || { echo "不在 herdr 內，請先用 herdr 開啟終端"; exit 1; }
> herdr --version && command -v jq git claude >/dev/null || { echo "缺少 herdr/jq/git/claude"; exit 1; }
> git status --porcelain | grep -q . && { echo "工作樹不乾淨，請先 commit 或 stash"; exit 1; }
> REPO=https://github.com/dkbo/dkboai.git   # fork 的話改這裡
> tmp=$(mktemp -d) && git clone -q --depth 1 "$REPO" "$tmp" && cp -r "$tmp/.dkboai" ./.dkboai && rm -rf "$tmp"
> .dkboai/install.sh
> git add -A && git commit -m "chore: add dkboai"
> .dkboai/bin/dk-whoami   # 預期印出 leader
> ```
>
> 全部成功後執行 `/dkboai-init`，依它的提問完成初始化。

預期輸出的最後兩行：
```
dkboai installed into /path/to/project
leader
```

## 手動安裝（同一件事拆開）
1. 複製 `.dkboai/` 到專案根目錄。
2. `.dkboai/install.sh`：在 `.claude/skills/` 與 `.agents/skills/` 建 `dkboai-init`、`dkboai-add-role` 兩個 symlink；在 `AGENTS.md` 尾端追加一行指向 `.dkboai/ENTRY.md`；在 `CLAUDE.md` 尾端追加 `@AGENTS.md`（CLAUDE.md 若是 AGENTS.md 的 symlink 則略過）；`.gitignore` 加 `.dkboai/.sessions/`。既有內容一律不動。
3. `git add -A && git commit`。員工在 worktree 工作，只看得到已 commit 的檔案，這步不能省。
4. 在 herdr 內的 Claude Code 執行 `/dkboai-init`：偵測已裝的 AI CLI、選主模型與第二三意見、改寫角色檔的 model/effort、預填 `.dkboai/PROJECT.md`、掃描既有 CLAUDE.md / AGENTS.md 與 dkboai 規則的衝突、檢查 MCP 需求。

## 驗證
```bash
.dkboai/bin/dk-whoami            # leader
ls -l .claude/skills .agents/skills | grep dkboai   # 四個 symlink
tail -1 AGENTS.md CLAUDE.md     # 分別是入口行與 @AGENTS.md
```

## 日常使用
- 開任務：對領導說「開任務 login，顯示名『使用者登入』，需求是…」。領導會寫 brief 給你確認（關卡①）、分波派工、員工升報時問你（關卡②）、結案時給你 report 拍板（關卡③）。
- 雜務：對領導說「翻譯 README 成英文」「先修登入頁那個 bug」。領導評估後派一位員工，不自己動手。
- 領導失憶：在領導 pane `/clear`，然後說「執行 .dkboai/bin/dk-resume 然後繼續」。
- 第二位領導：在任何 herdr shell 執行 `.dkboai/bin/dk-leader pay "金流"`。
- 新角色：`/dkboai-add-role`。

## 目錄
| 路徑 | 用途 |
|---|---|
| `ENTRY.md` | 唯一入口，決定你是領導或員工 |
| `LEADER.md` / `PROTOCOL.md` | 領導規範 / 通訊協定與升報規則 |
| `roles/` | 角色檔（kind、S/M/L 三檔、職責） |
| `kinds/` | 各 AI CLI 的旗標對應 |
| `bin/` | `dk-*` 腳本，全部封裝 herdr |
| `tasks/<日期-短名>/` | 一個任務的全部記憶：brief、process、report、messages.log、state/ |
| `tasks/INDEX.md`、`tasks/BACKLOG.md`、`decisions.md`、`PROJECT.md` | 跨任務記憶 |

## 更新 dkboai
只更新核心，保留你的 `tasks/`、`PROJECT.md`、`decisions.md` 與自訂角色：
```bash
tmp=$(mktemp -d) && git clone -q --depth 1 https://github.com/dkbo/dkboai.git "$tmp"
rsync -a --exclude=tasks --exclude=PROJECT.md --exclude=decisions.md --exclude='roles/*' --exclude=.sessions "$tmp/.dkboai/" ./.dkboai/
rsync -a --ignore-existing "$tmp/.dkboai/roles/" ./.dkboai/roles/   # 只補新角色，不覆蓋既有
rm -rf "$tmp" && .dkboai/install.sh && git add -A && git commit -m "chore: update dkboai"
```

## 疑難排解
| 症狀 | 原因 / 處理 |
|---|---|
| `dk: not running inside herdr` | 不是從 herdr 的 pane 執行。`herdr` 開啟終端後再試。 |
| 員工 pane 說找不到 `.dkboai/` | 安裝後沒 commit，worktree 看不到。commit 後重新 `dk-spawn`。 |
| 員工卡住不動 | 卡在審批對話框。dk-watch 會通知；切到該 pane 按同意，或檢查 `kinds/<kind>.sh` 的免審批旗標。 |
| codex / agy 不照協定回訊 | 確認 `AGENTS.md` 最後一行是入口行，且該 worktree 分支含這個 commit。 |
| 領導自己開始寫程式 | 提醒它讀 `.dkboai/LEADER.md`；必要時 `/clear` 後 `dk-resume`。 |
