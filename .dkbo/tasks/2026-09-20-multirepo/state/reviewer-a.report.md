# reviewer-a 報告（波 5 — 整枝評議第二輪 Important 1、2 修復）

對象：`waves/5.diff`（6 檔、+17/-12，since e8f45e1，工作樹未 commit）。做法：對照我上一輪（整枝評議）報告裡 Important 1、2 與 Minor 的 CHANGELOG 條目，逐條核對這一波是否照我建議的修法 (a) 落地；再自跑 `tests/run.sh` 與 shellcheck 複驗。

## 規格合規

波5 brief 沒有新增 AC，完成條件是「18/04/25 全過；tests/run.sh 全綠；shellcheck 零警告」與波次表列的三項修復：

- **(1) `dk-wave-open` 單 repo 模式「## 倉庫」段只印路徑、不印 `main →`；`PROTOCOL.md:56` 判別器改寫** ✅
  `.dkbo/bin/dk-wave-open:29-30` 改成 `if dk_repos_multi; then ... else repos_list=$(printf '%s\n' "$repo_rows" | awk '{print $3}'); fi`，比照 `dk-resume` 的既有形狀。`dk_settings` 補進第 5 行（`dir=...; dk_task_env; dk_settings`），是必要的：`dk_repos_multi` 讀 `DK_REPOS`，不補這行會一直落在單 repo 分支，測試會抓到但我另外確認過。`PROTOCOL.md:56` 改成「「## 倉庫」段的列帶 `<名> →`，如 `api → /path/to/worktree`」+ 「單 repo 專案的切片也有「## 倉庫」段，但只印一行 worktree 路徑、不帶名字與 `→`，不帶前綴」，判別器落在可觀察的行形狀上，不再與 `dk-wave-open` 的實際行為互指。`tests/unit/18_wave_open.bats:83-88` 同步改（`grep -qxF` 全行比對 + `refute_grep 'main →'`），這正是我上一輪選的修法 (a)。
- **(2) 兩份頂層 README 指令一覽與運作方式圖補 `dk-leader --run`、task-new 列改實話** ✅
  `README.md:23`／`README.en.md:23` 的指令流圖補上 `dk-leader --run`；`:158/221`（task-new 列）改成「只建任務目錄（不切 worktree，`/dkbo-run` 交棒時才實體化）」，不再與同文件第 3 步互相矛盾；`dk-leader` 列補了 `--run` 實體化與交棒的說明。三處都是我上一輪指名的 `file:line`（`README.md:84/96`、`README.en.md:84/96`，行號因後續改動略有位移但段落是同一批）。
- **(3) CHANGELOG 補波 4 的兩條修法與測試數字** ✅
  `CHANGELOG.md` 新增 `fix(repos)`（主 repo 乾淨檢查排除 `.dkbo/`）與 `fix(leader,wave-close)`（`while read` 迴圈內使用者指令加 `</dev/null`）兩條，並把「測試：535 bats（+109）」改成「539 bats（+113）」。跟我上一輪 Minor 指的 `CHANGELOG.md:15` 一致，且描述與 `waves/4.diff` 的實際改動（`dk-leader:run_setup`、`dk-wave-close` gate c 與逐 repo commit、`lib/repos.sh:dk_repos_check`）逐句對得上，沒有誇大或漏項。

**所有權**：本波只改 `.dkbo/PROTOCOL.md`、`.dkbo/bin/dk-wave-open`、`CHANGELOG.md`、`README.en.md`、`README.md`、`tests/unit/18_wave_open.bats`，六個檔全在 backend-docs 的可改清單內，沒有越界。

## Important

無。

## Minor

- `README.md:92` / `README.en.md:92` 的 `dk-task-close` 那列仍沒提「workspace 不自動關」——這是我上一輪報告明確標成「可以留到下一版，不需要卡住 merge」的項目，這一波沒動它是符合預期的，留待下一版或整枝收尾時再補即可，不擋這一波。

## 測試

### 紅
不適用：reviewer 只讀、不改碼、不寫測試，本波沒有紅可跑。

### 綠
自跑於 `.worktrees/multirepo`：

```
$ tests/run.sh tests/unit/18_wave_open.bats tests/unit/04_docs.bats tests/unit/25_docs_policy.bats
1..22
22 ok / 0 not ok

$ tests/run.sh
1..539
539 ok / 0 not ok    （exit 0，含波5的 refute_grep 'main →' 新斷言）

$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh
（無輸出，exit 0）
```

## 自我審查
- 逐條核對波5要修的三項（Important 1、2、CHANGELOG Minor）是不是照我上一輪建議的修法 (a) 落地，而不是只看 diff 有沒有動這些檔。
- 額外確認了 `dk_settings` 補進 `dk-wave-open` 的必要性（`dk_repos_multi` 依賴 `DK_REPOS`），不是無謂改動；也核對了其他七支 `dk-bin-*` 腳本都是同一種 `dk_task_env; dk_settings` 順序，這一行改動跟既有慣例一致，不是新引入的模式。
- 核對六個改動檔全在 backend-docs 的所有權清單內。
- README 兩處改動我逐字比對了圖與表跟同文件其他段落（第 3 步、`.dkbo/README.md` 已有的交棒段）是否一致，不再互相矛盾。

## 疑慮
- 我上一輪報告的 Minor（README 的 `dk-task-close` 列缺「workspace 不自動關」、`dk_repos_multi` 讀當下 `DK_REPOS` 而非 `.repos`、`DK_REPOS="main=. api="` 空路徑的孿生案例等）都還沒進波次表，若整枝結案前要收尾，建議領導在 report.md 的「未完成／遺留」裡點名，避免下一個人以為累積 Minor 已經清空。
