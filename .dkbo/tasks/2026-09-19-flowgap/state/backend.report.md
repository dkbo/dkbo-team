# backend 報告（波 4）
## 做了什麼
修整枝評議的 2 條 Important 與 5 條 Minor（AC18–AC24）：
- AC18/Important1：`skills/run/SKILL.md` 第 4 步裁定句後補「reviewer 的 Minor 逐條 `dk-process "minor N: <一句> <file:line>"`」，格式對齊 `dk-review` 的正規表示式。
- AC19/Important2：`roles/backend.md`、`roles/frontend.md`、`roles/qa.md` 的「交接對象」改成「修復迴圈兩輪（見 PROTOCOL.md，領導會視情況換人）」，不再寫「修一次」，跟 `PROTOCOL.md:29` 與首輪提示第一項讀到的內容一致。
- AC20/Minor3：`dk-task-close` 比對 report.md 是否提到 minor 時，先 `grep -v '^（'` 濾掉範本「未完成 / 遺留」段自己的指引行（那行本身含「Minor」三個字，會讓警告永遠沉默）。
- AC21/Minor4：`dk-wave-close` gate b 的「不適用」豁免同時接受半形 `:` 與全形 `：`。
- AC22/Minor6：`lib/prompt.sh` 的 `dk_first_prompt` 新增第 10 個位置參數 GROUP；TDD 那句抽成 `$tdd`，只在 `group=dev` 時填入。`dk-spawn` 傳自己手上已有的 `$group`。reviewer／qa 不再收到跟自己報告格式矛盾的指示。
- AC23/Minor7：`dk-spawn` 把 `--handoff` 的 ruling 落盤從 pane split 之前，挪到 `herdr agent start` 成功、pane 與 agent 確認起來之後（緊接在 `.panes` 那行 echo 之後）。agent start 失敗時 `dk_die` 會在到達那一行之前中止，不再留下假裁定。
- AC24/Minor5：新增 `lib/common.sh` 的 `DK_MINOR_RE`／`dk_minor_lines()`／`dk_minor_count()`，`dk-review` 與 `dk-task-close` 兩處都改用它，不再各養一份互相看不見的正規表示式。

前八個位置參數與 `{{CONSTRAINTS}}`／`{{MINORS}}` token 都沒動，符合共用契約的變更流程限制（只加第 10 個參數，不改前面）。

## 測試
### 紅
```
$ cd /home/bal/project/teamflow/.worktrees/flowgap && ./tests/run.sh 2>&1 | grep -E '^not ok|^1\.\.'
1..384
not ok 26 dk_minor_lines/dk_minor_count 是 dk-review 與 dk-task-close 共用的同一套 pattern
not ok 46 roles/*.md 的修復迴圈文字跟 PROTOCOL 一致，不再寫修一次
not ok 47 skills/run/SKILL.md 教領導把 reviewer 的 Minor 寫成 minor process 行
not ok 117 TDD 那一句只發給 group: dev，reviewer 與 qa 不收到
not ok 118 --handoff 的 ruling 只在 pane 與 agent 真的起來後才落盤
not ok 143 gate b: 不適用 全形冒號也算豁免
not ok 249 report.md 只留著範本的指引行不算提到 minor，警告不會被消掉
```
（先加 7 條新測試對應 AC18–AC24，跑一次確認紅了，再動實作）
### 綠
```
$ ./tests/run.sh 2>&1 | grep -E '^not ok|^1\.\.'
1..384
$ ./tests/run.sh 2>&1 | grep -c '^ok '
384
$ shellcheck .dkbo/bin/* .dkbo/lib/*.sh; echo "exit=$?"
exit=0
$ git status --short
 M .dkbo/bin/dk-review
 M .dkbo/bin/dk-spawn
 M .dkbo/bin/dk-task-close
 M .dkbo/bin/dk-wave-close
 M .dkbo/lib/common.sh
 M .dkbo/lib/prompt.sh
 M .dkbo/roles/backend.md
 M .dkbo/roles/frontend.md
 M .dkbo/roles/qa.md
 M .dkbo/skills/run/SKILL.md
 M CHANGELOG.md
 M tests/unit/01_common.bats
 M tests/unit/04_docs.bats
 M tests/unit/07_spawn.bats
 M tests/unit/08_wave_close.bats
 M tests/unit/12_task_close.bats
```
（16 個檔全落在 backend 的所有權：`.dkbo/**`、`tests/**`、`CHANGELOG.md`）

## 自我審查
- 每條都對回 reviewer-a.report.md 的 Important/Minor 原文，逐條核對修法與她建議的一致（AC18 的 `skills/run/SKILL.md` 插入點、AC20 的 `^（` 過濾、AC21 的半形／全形冒號、AC24 抽進 `lib/`）。
- AC22 沒有動前八個位置參數，只加第 10 個（第 9 個 HANDOFF 是波 3 加的）；跑過 `07_spawn.bats` 既有測試沒破。
- AC23 的修法刻意驗證了「agent start 失敗時不留假裁定」這條路徑（新測試用 `HERDR_STUB_FAIL="agent start"`），沒有只測正向路徑。
- 過程中一度誤讀主樹（`/home/bal/project/teamflow/.dkbo/`）而非 worktree（`/home/bal/project/teamflow/.worktrees/flowgap/.dkbo/`）的檔案，導致一開始以為波 1–3 的產出不存在；用 `md5sum` 對過 HEAD 內容後確認是路徑問題，之後所有讀寫都改在 worktree 下進行，最終 `git status --short` 只落在正確所有權範圍內，沒有污染主樹。

## 疑慮
- Minor 8（`dk-review --task` 的切片「本波成員」空白）不在本波 AC18–AC24 的範圍內（reviewer 自己標註是 0.8.x 既有狀態、非本波引入），沒有動它；留給下一輪或人裁定要不要順手補。
- CHANGELOG.md 沒有另開新版本號（VERSION 仍是 0.9.0），把這波的修復追加寫進既有的 0.9.0 條目，因為這是出貨前的整枝修復、不是下一版功能。若領導期待獨立版本號，請指示。
