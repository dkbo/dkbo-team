# dkbo

**繁體中文** · [English](README.en.md)

以 herdr 為底的多模型 AI 開發團隊套件。一位領導（Claude Code）在主 pane 讀需求、寫 brief、拆波、派工、裁定；員工（`claude` / `codex` / `agy`）各佔一個 pane 實作、測試、審查、互相傳訊。所有記憶都是小型 markdown，領導失憶可一鍵恢復。整個套件就是一個可攜目錄 `.dkbo/`，複製進任何 git 專案即可用。

- 目前版本：`.dkbo/VERSION`（0.15.0），變更紀錄見 [CHANGELOG.md](CHANGELOG.md)
- Repo：https://github.com/dkbo/dkbo-team
- 安裝、更新與疑難排解的完整手冊：**[.dkbo/README.md](.dkbo/README.md)**

## 為什麼需要它

單一 agent 做中型以上的功能會撞到三個牆：上下文吃緊就開始忘事、沒有第二意見就會自我確認、改到別人的檔就會互相踩。dkbo 用三個機制回應：

- **記憶外置**：任務的全部狀態（brief、process、每位員工的 state 與 report、訊息紀錄）都是檔案。領導 `/clear` 之後叫 `/dkbo-run` 就能接續（它第一步就是 `dk-resume`），員工掛掉用 `--resume` 重派。
- **多模型審查閘**：每一波實作完成，領導派 1 到 3 位不同 kind 的 reviewer 只讀差異包出意見；wave-close 會檢查裁定、每位 dev 的測試段與專案測試指令，缺一不放行。
- **檔案所有權**：brief 裡每個成員可改的檔案 glob 不得重疊，`dk-brief-check` 事前擋、`dk-wave-close` 事後拿 worktree 的**真實 git diff**（含未 commit 與未追蹤）比對；出現本波沒人擁有的檔就不放行。

## 運作方式

```
你 ──對話──▶ 領導（Claude Code，tab 1 左欄）
                │  dk-task-new / dk-leader --run / dk-spawn / dk-review / dk-wave-close / dk-task-close
                ▼
        員工 pane（herdr 分割，各自在任務 worktree 內）
        backend · frontend · qa · reviewer-a(claude) · reviewer-b(codex) …
                │  dk-msg：[DONE] [BUG] [FIXED] [QUESTION] [ESCALATE] …
                ▼
        .dkbo/tasks/<日期-短名>/  brief.md · process.md · state/ · messages.log · report.md
```

**一個任務的生命週期**

1. 你叫 `/dkbo-plan`，對它說「開任務 login，顯示名『使用者登入』，需求是…」。
2. 領導寫 `brief.md`：目標、驗收標準、檔案所有權、共用契約、波次表（每列一位成員，標 S/M/L 難度）。`dk-brief-check` 過了才進入審查。接著 `dk-brief-review` 派 2 到 3 個不同 kind 讀需求原文與 brief，領導裁定並改完 brief，才把三份（需求原文、brief、裁定摘要）給你確認。這是**關卡①**。
3. 你叫 `/dkbo-run`：`dk-leader <short> --run` 這一刻才把任務「實體化」——依 `DK_REPOS`（多 repo 專案，見 [.dkbo/README.md](.dkbo/README.md)）各切一個 worktree、在任務所屬的 workspace（`.task.env` 的 `DK_WORKSPACE`，計畫時記下；空時退回 `HERDR_WORKSPACE_ID`）開一個 label `dk/<short>` 的新 tab，並在它的根 pane 起執行領導交棒，你的 session 空出來可以開下一個任務。每一波：`dk-wave-open` 切出每位成員的 brief 切片，`dk-spawn` 開 pane 並下第一段提示。員工只能改自己所有權內的檔（多 repo 時所有權與 `touched` 帶 `<名>:` 前綴），做完寫 state 與 report，`dk-msg leader "[DONE] …"`。
4. dev DONE 後領導 `dk-review-pack` 打包差異、`dk-review` 派 reviewer；reviewer 與 qa 並行。有 Important 就轉 BUG 給 dev，同一個 bug 修一次沒好就升報。
5. 員工碰到選擇題、要動別人的檔、上下文吃緊，一律 `[ESCALATE]`。領導能依 brief 判的就下 `[DECISION]` 並記 ruling；brief 判不了的也由領導自己裁定（記成 `ruling: [自主] …`），**`/dkbo-run` 開跑後不停下來問你**，你睡覺時任務照常跑完。修不好的問題照熔斷器 park 或用最小改法繞過，不讓整個任務卡住。
6. qa DONE 且審查裁定完成，`dk-wave-close`：四道閘 —— 裁定行、每位 dev 的 `## 測試`、`DK_TEST_CMD`、真實 diff 的越界比對 —— 缺一不放行，然後關 pane 並在 worktree 內 commit（`-m` 可指定訊息）。
7. 所有波結束，領導先做整分支評議，再寫 `report.md` 給你拍板，裡面的「自主裁定（待你複核）」列出執行中途替你做的每一個決定；有視覺變更就看 qa 附的截圖。這是**關卡③**。`dk-task-close` 合併回主分支、移除 worktree、INDEX 記 done。

**雜務**：「翻譯 README 成英文」「先修登入頁那個 bug」這類不屬於任務的小事，領導用 `dk-chore` 派一位員工，`--code` 的會在獨立 worktree 分支工作並於 `dk-chore-close` 時合併回來。雜務員工用 `dk-msg leader` 回報，腳本會等領導閒置再送，不會漏訊。

**版面**：領導佔 tab 1 左欄，員工填右側 2×2 或 3×2；第 5 位起自動開新 tab，關 pane 後自動均分。

## 快速開始

前置：herdr ≥ 0.9.0 且在它的 pane 內（`echo $HERDR_ENV` 印 `1`；版本由每支 dk-* 與 `install.sh` 實際驗，低於就拒跑，高於已驗證的 0.9.x 會提醒你跑一次整合測試）、git ≥ 2.17、jq ≥ 1.5、bash 3.2+（macOS 內建的版本就夠；`flock` 是軟依賴，缺了退化成無鎖寫入）、三種 AI CLI 至少一種（`claude` / `codex` / `agy`）。領導這一側用哪個由 `DK_LEADER_KIND` 決定（預設 `claude`），其餘當員工與第二三意見。目標專案要是乾淨的 git repo。

把下面整段貼給在 herdr 內、目標專案根目錄開啟的 Claude Code：

```bash
test "$HERDR_ENV" = 1 || { echo "不在 herdr 內"; exit 1; }
git status --porcelain | grep -q . && { echo "工作樹不乾淨，先 commit"; exit 1; }
VER=v0.15.0; tmp=$(mktemp -d) && git clone -q --depth 1 --branch "$VER" https://github.com/dkbo/dkbo-team.git "$tmp" \
  && (cd "$tmp/.dkbo" && rm -rf tasks decisions.md PROJECT.md settings.env .sessions) \
  && cp -r "$tmp/.dkbo" ./.dkbo && rm -rf "$tmp"
.dkbo/install.sh && git add -A && git commit -m "chore: add dkbo"
.dkbo/bin/dk-whoami   # 預期印出 leader
```

然後執行 `/dkbo-init`：它偵測已裝的 AI CLI、選領導 kind（`DK_LEADER_KIND`）與員工主模型、選第二三意見、寫 `settings.env`、佈線入口檔、預填 `PROJECT.md`、掃描既有 CLAUDE.md / AGENTS.md 與 dkbo 規則的衝突。細節、手動安裝與更新方式見 [.dkbo/README.md](.dkbo/README.md)。

## 角色與 kind

角色檔在 `.dkbo/roles/<角色>.md`，frontmatter 定義 kind 與 S/M/L 三檔（模型／effort），正文是職責與完成定義。`/dkbo-add-role` 可加新角色。

| 角色 | 一句職責 |
|---|---|
| pm | 需求釐成可驗證的驗收標準，不寫碼 |
| frontend / backend | 介面 / API 與資料層實作，只改自己所有權內的檔 |
| qa | 依驗收標準驗證、送 BUG，自己不修 |
| it | 環境、依賴、CI、合併衝突修復 |
| reviewer | 只讀差異包出意見（規格合規 / Important / Minor），不改碼 |

kind 是 AI CLI 的旗標對應，在 `.dkbo/kinds/`：`claude`（opus / sonnet）、`codex`（gpt-5.5）、`agy`（gemini）。reviewer 可指定不同 kind 取得真正的第二意見。

## 指令一覽

全部在 `.dkbo/bin/`，全部封裝 herdr，只有領導會用到；員工只用 `dk-msg`。

| 指令 | 做什麼 |
|---|---|
| `dk-whoami` | 這個 pane 是領導還是員工 |
| `dk-task-new` / `dk-brief-check` | 只建任務目錄（不切 worktree，`/dkbo-run` 交棒時才實體化）；brief 的機械檢查 |
| `dk-brief-review` | 開工前派 1 到 3 位 reviewer 審 brief 與需求原文（AI 閘，關卡①前的第二道） |
| `dk-wave-open N` / `dk-spawn <角色>` | 開一波、切成員切片（`--refresh` 依當下 brief 重產第 N 波所有成員的切片、重算逾時）；開員工 pane 並下提示 |
| `dk-kind [status]` / `dk-kind up <k>` | 列出專案層熔斷的 kind 與恢復時間；解除一個 kind 的熔斷 |
| `dk-msg <對象> "[類型] 內文"` | 等對方閒置再送訊息，記進 messages.log |
| `dk-review-pack N` / `dk-review` | 打包差異；派 1 到 3 位 reviewer |
| `dk-wave-close` | 四道閘後關 pane，並在 worktree 內 commit 這一波 |
| `dk-process` / `dk-resume` | 記事件；印恢復包（brief、本波、裁定、未處理訊息，含任務／本波已進行時長與每位員工等了幾分鐘） |
| `dk-timeline` | 只讀 process.md 算整張時間表（任務、計畫、每波的 dev 與審查、結案），結案時由 `dk-task-close` 附進 report.md |
| `dk-task-close` | 合併回主分支、清 worktree、INDEX 記 done |
| `dk-chore` / `dk-chore-close` | 派與收一件雜務 |
| `dk-chore-tidy` | 雜務檔歸位到日期資料夾、`messages.log` 歸檔（沒有雜務在跑時） |
| `dk-watch` | 背景守望：員工卡審批推 `[BLOCKED]`，reviewer 逾時推 `[TIMEOUT]` 並熔斷該 kind。`--ensure` 幂等重啟（spawn／wave-open／resume 都會呼叫），`--chores` 是雜務那一側的守望 |
| `dk-leader` / `dk-version` | 開第二位領導（kind 取 `DK_LEADER_KIND`，檔位取該 kind 的 L）；`--run` 實體化任務（依 `DK_REPOS` 切 worktree、在任務所屬的 workspace（`.task.env` 的 `DK_WORKSPACE`，計畫時記下）開任務 tab）並交棒給該 tab 根 pane 的執行領導；印版本 |

## 目錄

```
.dkbo/
  ENTRY.md            唯一入口：dk-whoami 認身分；領導要自己叫 skill 才啟動
  LEADER.md           領導共同規範（硬邊界、settings.env、裁定格式）
  skills/             init、add-role，與大腦／計畫／執行三篇階段規範（install.sh 會 symlink 進 .claude/skills 與 .agents/skills）
  PROTOCOL.md         通訊協定：訊息類型、升報規則、停止條件、state / report 格式
  PROJECT.md          專案事實，≤40 行，init 預填
  settings.env        DK_LEADER_KIND、DK_TEST_CMD、DK_REVIEW_KINDS、DK_REVIEW_MIN、DK_REVIEW_TIER、DK_REVIEW_TIMEOUT_MIN、DK_TAB1_SLOTS、DK_WAVE_TIMEOUT_MIN
  roles/  kinds/      角色檔；各 AI CLI 的旗標對應
  bin/  lib/          dk-* 腳本與共用函式
  templates/          brief、切片、state、report、chore 範本
  tasks/<日期-短名>/  一個任務的全部記憶
  tasks/INDEX.md  tasks/BACKLOG.md  decisions.md   跨任務記憶
tests/                單元（bats，假 herdr）、整合（真 herdr）、smoke（真 agent）、e2e RUNBOOK
example/              給 e2e RUNBOOK 用的最小 Node 專案
```

## 開發與測試

```bash
tests/run.sh                          # 單元測試，bats-core 會自動 clone 進 tests/lib；用 tests/stub 的假 herdr
tests/integration/herdr-real.sh       # 對真 herdr 0.9.0 驗證 stub 假設的 JSON 形狀，零 token
tests/smoke/kind-smoke.sh             # 對真 AI CLI 驗證各 kind 的旗標與提示行為
shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/install.sh .dkbo/kinds/*.sh   # 目標零警告
```

`tests/e2e/RUNBOOK.md` 是人工走一次完整任務的腳本，用 `example/` 當目標專案。所有腳本改動都先寫失敗的 bats 測試再實作。

單元測試與 shellcheck 由 [`.github/workflows/ci.yml`](.github/workflows/ci.yml) 在每次 push 與 PR 上跑（版本字串一致性是其中一個 bats 測試）；推 `v*` tag 時另驗 tag 等於 `.dkbo/VERSION` 且 CHANGELOG 有該版條目。

## 文件

- [.dkbo/README.md](.dkbo/README.md)：安裝、驗證、日常使用、更新、疑難排解
- [.dkbo/LEADER.md](.dkbo/LEADER.md) 與 [.dkbo/skills/{brain,plan,run}/SKILL.md](.dkbo/skills)、[.dkbo/PROTOCOL.md](.dkbo/PROTOCOL.md)：領導與員工實際照著做的規範
- 設計文件不進版控（`docs/` 已 gitignore）：定案的結論寫進 `.dkbo/decisions.md`，待實作的寫成任務的 `plan.md`。
