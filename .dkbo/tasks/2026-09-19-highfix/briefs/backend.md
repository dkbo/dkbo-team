# BACKLOG 三條高嚴重度缺陷 — 給 backend 的切片（波 2）
由 dk-wave-open 產生，只讀。完整 brief 在 /home/bal/project/teamflow/.dkbo/tasks/2026-09-19-highfix/brief.md。

## 目標
修掉 flowgap 實跑記進 `tasks/BACKLOG.md` 的三條「高」缺陷：dk-watch 的 dev 完成聚合在開波空窗誤發且此後永不再通知、
dk-wave-close 的 gate c 把領導的 `DK_*` 環境整包餵給 `DK_TEST_CMD`、agy 啟動橫幅命中 `KIND_QUOTA_RE` 的裸 `quota`。
每條都要有先紅後綠的 bats 測試守著，出貨 0.9.1。

## 全域約束（全文）
- 本任務的產出就是 `.dkbo/` 下的腳本與規則檔。`PROTOCOL.md` 停止條件「不改 `.dkbo/` 下的規則檔」對本任務不適用，以下方檔案所有權表為準（領導已記 ruling）。
- bash 3.2 相容（macOS 內建版本）：不用 `declare -A`、不用 `${var^^}`、不用 `mapfile`。只依賴 bash / jq / git / herdr，不新增外部依賴。
- 每支 `bin/dk-*` 開頭固定是 `set -euo pipefail` 與 `. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"`。shellcheck 零警告（`tests/run.sh` 會跑，設定在 `.dkbo/.shellcheckrc`）。
- 檔案新舊不靠 mtime（`date -r` 在 GNU 與 BSD 語義不同；`decisions.md` 2026-09-19 已裁定），用 `cksum` 或等價的內容比對。
- dkbo 不代員工改 state 檔（`PROTOCOL.md`「只有本人能寫自己的 state 與 report 檔」）。
- 不新增 `settings.env` 鍵、不新增 skill、不改 herdr 呼叫的 JSON 形狀假設、不改 `tests/stub/herdr` 對 herdr 的模擬語意。
- 測試檔放 `tests/unit/`，檔名兩位數遞增（目前到 31），新測試優先加進既有對應檔（`09_watch.bats`、`08_wave_close.bats`、`03_kinds.bats`）。
- 使用者可見字串一律繁體中文；程式碼註解解釋「為什麼」時寫中文，語法說明寫英文，照既有檔案的密度。
- 版本字串一致：`.dkbo/VERSION`、`CHANGELOG.md` 首節、`README.md`、`README.en.md`、`.dkbo/README.md` 全部 0.9.1（`21_version.bats` 守著）。

## 你的波次
| 波 | 型態 | 成員 | 做什麼 | 難度 | 完成條件 | 審查 |
|---|---|---|---|---|---|---|
| 2 | 修復 | backend | AC13–AC17：整枝評議的 3 條 Important 與 Minor 1。修完先 dk-msg leader 送 [FIXED] 附根因一句（本波是修復波，[DONE] 不會叫醒領導），再照常寫 state 與 report 送 [DONE] | M | tests/run.sh 全綠、report 紅綠齊 | 預設 |

## 你的檔案所有權
| 成員 | 可改 | 只讀 |
|---|---|---|
| backend | .dkbo/bin/**, .dkbo/lib/**, .dkbo/kinds/**, .dkbo/VERSION, .dkbo/README.md, tests/**, CHANGELOG.md, README.md, README.en.md | .dkbo/tasks/**, .dkbo/PROTOCOL.md, .dkbo/LEADER.md, .dkbo/skills/**, .dkbo/roles/**, .dkbo/templates/**, .dkbo/decisions.md |

## 共用契約（全文）
（一列一個契約。擁有者填一個成員短名；消費者填一個或多個、逗號分隔；沒有就填 —。完全沒有契約時只留表頭）
| 契約 | 擁有者 | 消費者 | 形狀／簽名 | 變更流程 |
|---|---|---|---|---|
| dev 聚合的 state 快照 | backend | — | `dk-spawn` 寫、`dk-watch` 讀；位置在任務目錄 `.blocked/` 或 `.panes` 欄位內，內容是 state 檔的 `cksum` 輸出；員工不知道也不需要知道它 | 位置或格式要動到 `.panes` 既有欄位順序時先 ESCALATE（`dk-resume`、`dk-msg`、`dk-wave-close` 都在讀 `.panes`） |
| gate c 子行程環境 | backend | — | `DK_TEST_CMD` 在 `DK_WORKTREE` 內以不含任何 `DK_*` 的環境執行；其餘環境變數原樣 | 若要保留任何一個 `DK_*` 給測試指令用，先 ESCALATE |
| `KIND_QUOTA_RE` 的語意 | backend | — | 只描述「額度已耗盡」的畫面字樣，不描述任何會在正常啟動或正常工作中出現的字樣；三個 kind 一致 | 加新字樣時要附該 CLI 的實測原文進註解 |

## 驗收標準（全文）
- [ ] AC1 重現 flowgap 波 3／4 的競態：同一成員 `backend` 在波 N 的 state 已是 `status: done`，領導 `dk-wave-open N+1` 並 `dk-spawn backend` 之後、員工尚未改寫 state 之前，跑一輪 dk-watch 的檢查，**不得**送出聚合 `[DONE]`、不得記 `dev-done wave N+1` 的 process 行、不得建立 `.blocked/wave-N+1.devdone`。bats 測試先紅（現行程式會誤發）後綠。
- [ ] AC2 員工在波 N+1 把 state 改寫（內容有變）並寫 `status: done` 後，同一輪檢查照常送出聚合 `[DONE]` 一次、記 `dev-done` process 行、標記寫成 `delivered`；第二輪不重送（回歸，既有 `09_watch.bats` 的聚合測試仍綠）。
- [ ] AC3 判定「這一輪的 done」的依據**不得**只靠員工是否填對 state 的 `wave:` 欄（漏填會靜默永不通知，比誤報更糟），也不靠 mtime；可用 `dk-spawn` 當下存的 state 內容 `cksum` 快照（同 0.8.0 reviewer 逾時那套）或等價的內容比對。快照存在任務目錄的 `.blocked/` 或 `.panes` 內，不寫進員工的 state。
- [ ] AC4 `dk-spawn … --resume` 或 `--handoff` 重派同一位成員時，快照以重派當下的 state 內容重取。若該成員本波已 `status: done` 且此後 state 內容不再變動，聚合狀態**維持 done 不變**（不因重派回退成未完成）；測試名含 `resume_unchanged_stays_done`。
- [ ] AC5 `dk-wave-close` 的 gate c 執行 `DK_TEST_CMD` 時，子行程環境裡**沒有任何** `DK_*` 變數（`env -u` 逐一或白名單式乾淨環境皆可），但 `PATH`、`HOME` 等非 `DK_*` 變數照舊。測試：把 `DK_TEST_CMD` 設成「`env | grep '^DK_' > <檔>; true`」，斷言該檔為空；先紅後綠。
- [ ] AC6 gate c 仍在 `DK_WORKTREE` 目錄執行、測試指令非零仍拒絕關波並記 `wave-close N tests failed`、`--force` 照舊放行（既有 `08_wave_close.bats` 回歸全綠）。
- [ ] AC7 `kinds/agy.sh` 的 `KIND_QUOTA_RE` 對 agy 啟動橫幅 `bal@host (Antigravity Starter Quota)` **不命中**，對實測耗盡訊息 `Individual quota reached, Resets in 102h11m1s` 命中；另對 `quota exceeded`、`resource exhausted`、`rate limit` 命中。`03_kinds.bats` 正反兩組例子，經由 `dk_kind_re agy quota` 與 `screen_hits` 同一條路徑（`grep -qiE`）驗。
- [ ] AC8 `dk-watch` 對 reviewer `[TIMEOUT]` 訊息附加 `(quota?)` 的那條通用式（目前 `dk-watch:193` 的 `rate limit|quota|429|usage limit`）不再用裸 `quota`：改用該 kind 的 `KIND_QUOTA_RE`，或收窄成與 AC7 同一組耗盡字樣；`Antigravity Starter Quota` 不得被標 `(quota?)`。有測試。
- [ ] AC9 `codex.sh` 與 `claude.sh` 的 `KIND_QUOTA_RE` 對各自 CLI 的啟動畫面不命中（至少對 `claude` 的歡迎畫面字樣與 codex 的版本列各一個反例），既有正例不變。
- [ ] AC10 `tests/run.sh` 全綠、零 `not ok`；`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh` 零警告。
- [ ] AC11 `CHANGELOG.md` 首節 `## 0.9.1 — 2026-09-19` 三條 `fix(...)` 各一行，寫清楚症狀與修法；五處版本字串一致（`21_version.bats` 綠）。
- [ ] AC12 report 的 `### 紅`／`### 綠` 貼的是 AC1、AC5、AC7、AC8 四條測試各自先失敗後通過的實際指令與輸出。
- [ ] AC13 `dk-watch` 的 `dev_delivered()`：latch 只豁免「內容與快照相同」那一關，不豁免 `status: done` 本身（例：`[ -f "$latch" ] && { grep -q '^status: done' "$sf"; return $?; }`）。新測試：dev A 交件（latch 落下）後被退回 `status: working`，同波 dev B 交齊，不推聚合、不記 `dev-done`、不寫 `.devdone`；A 再改回 done 才推。先紅後綠；`resume_unchanged_stays_done` 仍綠。
- [ ] AC14 三份 README 的 herdr 版號六處改回 0.9.0（`.dkbo/README.md:6`、`.dkbo/README.md:89` 含錯誤訊息原文與「實測 0.9.0」、`README.md:48`、`README.md:120`、`README.en.md:48`、`README.en.md:120`），並加測試守住：`.dkbo/README.md` 的「herdr ≥ X」與疑難排解那列引用的錯誤訊息版號，都要等於 `lib/common.sh` 的 `DK_HERDR_MIN`。先紅後綠。
- [ ] AC15 `kinds/claude.sh` 的 `KIND_QUOTA_RE` 移除 `approaching your`（預警不是耗盡，違反共用契約第三列）；`03_kinds.bats` 加反例 `approaching your deadline` 不命中，正例 `You've hit your usage limit`、`rate limit` 命中。CHANGELOG 0.9.1 首節 `fix(kinds)` 那行補上 claude 式子收窄。
- [ ] AC16 `09_watch.bats` 的「agy 真的耗盡時仍標 (quota?)」測試名副其實：二擇一 —— (a) 補一條斷言 `[TIMEOUT] … 逾時 (quota?)` 的正向測試；或 (b) 若 AC8 之後 `assess()` 必先攔下同一畫面、`(quota?)` 標記已不可達，就刪掉那段標記碼與該測試，CHANGELOG 說明。report 寫清選了哪個與為何。
- [ ] AC17 `tests/run.sh` 全綠、shellcheck 零警告、版本字串仍 0.9.1；report 的 `### 紅`／`### 綠` 貼 AC13、AC14、AC15 三組實際指令與輸出。

## 同波成員
backend(M)
