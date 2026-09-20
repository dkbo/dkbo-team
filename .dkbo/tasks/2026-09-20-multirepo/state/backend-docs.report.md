# backend-docs 報告（波 5）

## 做了什麼

整枝評議第二輪 reviewer-a 的 Important 1、2，三個子項全做完。

### Important 1：單 repo 模式的「## 倉庫」段不該印 `main →`
- `.dkbo/bin/dk-wave-open:30`：改成用 `dk_repos_multi` 判斷——多 repo 印 `<名> → <path>`，單 repo 只印 `<path>` 一行（比照 `dk-resume:30-31` 的既有寫法）。
- 順手修一個連帶的洞：`dk-wave-open` 原本沒呼叫 `dk_settings`，`DK_REPOS` 這個環境變數從沒被載入過，`dk_repos_multi` 永遠判定成單 repo（`AC9: 切片有「## 倉庫」段，逐列 <名> → <worktree 路徑>` 那條多 repo 測試改完後當場紅）。在 `dk_task_env` 之後補一句 `dk_settings`（跟 `dk-resume:10` 同一個順序）。
- `tests/unit/18_wave_open.bats:87-91`：斷言改成「一列、只印 `$WORKTREE_PATH`、`refute_grep 'main →'`」。
- `.dkbo/PROTOCOL.md:56`：判別器改寫成「「## 倉庫」段的列帶 `<名> →` 才是多 repo」，並補一句單 repo 也有這一段、只印路徑不帶前綴。

### Important 2：兩份頂層 README 的指令一覽與運作方式圖仍是 0.9.2 時序
- `README.md` / `README.en.md` 的指令一覽：`dk-task-new` 那列改成「只建任務目錄（不切 worktree，`/dkbo-run` 交棒時才實體化）」；`dk-leader` 那列補上 `--run` 實體化與交棒的說明。
- 兩份的運作方式圖／How it works 指令流：`dk-task-new / dk-spawn / …` 中間插入 `dk-leader --run`。
- 「運作方式」正文第 3 步在波 3 已經寫好交棒說明，這次沒有再動，只補指令一覽與圖，避免重複。

### CHANGELOG 0.10.0
- 補兩條波 4 的修法：（a）主 repo 乾淨檢查排除 `.dkbo/`（`git status … -- . ':!.dkbo'`），理由是 dkbo 自己的任務記帳在任務進行中永遠是已追蹤且已修改，不是工作樹不乾淨；（b）`dk-leader --run` 的 `DK_SETUP_CMD` 鉤子與 `dk-wave-close` gate c 的測試指令都在 `while read <<< …` 迴圈裡，鉤子/測試指令讀一次 stdin 會吃掉迴圈的 herestring，兩處補 `< /dev/null`，逐 repo commit 那句一併加固。
- 測試數字從「535 bats（+109）」改成「539 bats（+113）」，跟 `tests/run.sh` 實測一致。

## 測試

### 紅
先改 `tests/unit/18_wave_open.bats:87-91` 的斷言到新期望值，再跑確認紅（實作還沒改）：
```
$ tests/run.sh tests/unit/18_wave_open.bats
not ok 9 AC9: 單 repo 模式的切片也有「## 倉庫」段，只印 worktree 路徑、不印 main →
#   `grep -qxF "$WORKTREE_PATH" "$d/briefs/backend.md"' failed
```

### 綠
改完 `dk-wave-open` 之後單 repo 那條先過，但多 repo 那條（AC9 逐列）反而紅了——`dk_repos_multi` 讀不到 `DK_REPOS`（`dk-wave-open` 沒呼叫 `dk_settings`）；補上 `dk_settings` 之後兩條一起過：
```
$ tests/run.sh tests/unit/18_wave_open.bats
1..9
ok 8 AC9: 切片有「## 倉庫」段，逐列 <名> → <worktree 路徑>
ok 9 AC9: 單 repo 模式的切片也有「## 倉庫」段，只印 worktree 路徑、不印 main →

$ tests/run.sh
1..539
539 ok / 0 not ok（exit 0）

$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh
（無輸出，exit 0）
```

Important 2 與 CHANGELOG 兩項是文件修正，沒有機械測試守著（README／CHANGELOG 的字面不在任何 bats 斷言的比對範圍內，`04_docs.bats`／`25_docs_policy.bats` 只查特定關鍵字如 `<名>:`、`feat(workspace)`，本波沒有新增或改動這些關鍵字的存在與否）：
### 紅
不適用: README／CHANGELOG 文字修正沒有對應的機械斷言，只能人工核對前後文字與 `dk-leader`/`dk-task-new` 的實際行為一致
### 綠
不適用: 同上；改完後人工核對 README.md/README.en.md 兩處表格與運作方式圖、CHANGELOG.md 的新增段落，確認用詞與程式碼行為（`dk-task-new:55-76` 不切 worktree、`dk-leader --run` 才實體化）一致

## 自我審查
- 只改了切片所有權表劃給我的六個檔：`.dkbo/bin/dk-wave-open`、`tests/unit/18_wave_open.bats`、`.dkbo/PROTOCOL.md`、`README.md`、`README.en.md`、`CHANGELOG.md`；`git status --short` 逐行核對過。
- Important 1 選了 brief 指定的做法（(a)：改 `dk-wave-open` 而不是只改 PROTOCOL 文字），沒有另外裁決。
- 修 `dk_settings` 遺漏那個連帶洞時，回頭確認過其他呼叫 `dk_repos_multi` 的腳本（`dk-resume`、`dk-brief-check`、`dk-spawn`）都有各自呼叫 `dk_settings` 或等價載入，不是同一個洞的其他分身。
- 全域約束逐條自查：bash 3.2（無 `declare -A`／`${x^^}`／`mapfile`）、新增測試無 `! grep -q`（用 `refute_grep`）、面向使用者文案繁體中文、沒有新依賴、沒有動 `install.sh` 或新增 skill。
- PROTOCOL.md 改完後仍是 75 行，在 `04_docs.bats` 的 ≤120 行機械上限內；`<名>:` 字樣仍在（`25_docs_policy.bats:21`）。

## 疑慮
- CHANGELOG 的兩條新 fix 說明文字沒有機械閘守著（prose，不是斷言），如果整枝評議還有下一輪，麻煩順手核對用詞是否與 backend-repos／backend-ws 想強調的重點一致（我是照 `git show e8f45e1` 的實際 diff 與註解寫的，沒有另外問過他們）。
- README 的「疑難排解」表與 Minor 提到的「`dk-task-close` 那列沒提 workspace 不自動關」不在本波 brief 的完成條件內，這次沒有動，留給之後有需要的人。
