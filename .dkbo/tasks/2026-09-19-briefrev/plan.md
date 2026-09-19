# dk-brief-review — 計畫層的第二三意見閘

狀態：設計定案，待實作
日期：2026-09-19
來源：與人的對話（brainstorming）

## 1. 這是什麼

在 `/dkbo-plan` 裡，`dk-brief-check`（機械閘、零 token）旁邊加第二道閘 `dk-brief-review`（AI 閘）：
派 2–3 個不同 kind 的 reviewer 讀「需求原文 + brief」，各自出一份固定格式的意見，領導一輪收齊後裁定、
改 brief，才准過關卡①。

**它不是第四個階段。** 領導仍然只有三個階段（brain / plan / run）。`dk-brief-check` 與
`dk-brief-review` 是同一層的兩道閘 —— 審的是同一個物件 `brief.md`，一個用 shell 驗形狀，一個用模型
看內容。名字跟著物件走，所以叫 `dk-brief-review` 而不是 `dk-plan-review`（`plan.md` 這個一等公民在
目前版本還不存在）。

## 2. 為什麼

執行階段每一波都有多模型審查閘（`dk-review`），但**計畫本身從來沒有被第二個腦袋看過**。
`dk-brief-check` 只驗得了形狀：所有權有沒有重疊、波次表欄位齊不齊、成員名對不對得上。它永遠抓不到
這兩種錯：

- brief 漏了人講過的需求（最貴的錯：整個任務做完才發現少一半）
- 驗收標準寫得不可驗證（qa 到了 `dk-wave-close` 才發現沒辦法判過或不過）

這兩種錯發生在計畫階段，代價卻在執行階段才付 —— 而那時已經燒掉了整個波次的 token 與時間。

## 3. 已定案的決策

① **同層兩支，不是新階段。** 機械閘與 AI 閘並排，先零 token 後燒 token。順序由程式保證（見決策⑤），
不靠領導記得。

② **審查材料是 `request.md` + `brief.md`。** 只給 brief 的話，reviewer 只能在 brief 的自我一致性裡
打轉，看不出少了什麼。

③ **`request.md` 是領導逐字落檔的需求原文。** 不改寫、不摘要。這帶來一個無法由 reviewer 消除的盲點：
領導若從一開始就誤解需求，reviewer 看到的是已經被同一個腦袋過濾過的版本。唯一能擋住這個的是人自己 ——
所以關卡①給人看的是 `request.md` + `brief.md` + 裁定摘要三份，不是只有 brief（見第 9 節）。

④ **一輪，領導直接裁定。** 與 `dk-review` 同一個心智模型，不做 `/dkbo-brain` 評議波那種第二輪反駁 ——
每開一個任務都多燒一輪 token 與等待時間，小任務會顯得很重。爭點大到需要辯論時，領導可以自己改用評議波。

⑤ **硬閘，留痕才能跳。** `dk-task-new --gate1` 沒看到裁定行就拒絕；真的不審（純文件任務、所有 kind
熔斷）要先記 `brief-review skipped: <理由>`。與 `dk-wave-close` 同一套規矩。

⑥ **共用現有 `DK_REVIEW_*` 設定**（`KINDS` / `MIN` / `TIER` / `TIMEOUT_MIN`），不新增旋鈕。
`--kinds` 與 `--tier` 逐次覆寫，與 `dk-review` 的介面一致。

⑦ **別名用 `p1/p2/p3`，不是 `a/b/c`。** `dk-review` 每一波固定用 a/b/c；計畫階段若也用 a/b/c，
第一波的 reviewer 會把 `state/reviewer-a.report.md` 整份覆蓋掉 —— 裁定的依據消失，而且沒有任何東西
會報錯。

⑧ **reviewer 不讀專案程式碼。** 它要回答「這份計畫做出來會不會是人要的東西」，不是「這段碼寫得好不好」。
副作用是它看不出「`src/api/**` 底下其實沒有檔案」這類錯 —— 那要等 `dk-wave-close` 的真實 diff 比對才會炸。
這個取捨是刻意的：讓 reviewer 去翻碼，它們會迅速滑進實作細節。

⑨ **改 `roles/reviewer.md` 一行，不新增角色檔。** 新增 `plan-reviewer` 會把 kind 與 tier 定義複製
一份，以後 `DK_REVIEW_TIER` 調整時兩邊會漂移。

⑩ **守望完全不用改。** `dk-watch` 認 reviewer 的條件是 `group = review` 且 agent 名含 `-reviewer-`，
`<short>-reviewer-p1` 天然命中；逾時推 `[TIMEOUT]`、熔斷寫 `DK_KIND_DOWN` 都照舊生效。
`dk-task-new` 本來就在建任務時起守望，所以計畫階段的 reviewer 一樣有安全網。

## 4. 資料流

```
人口述需求 ──▶ 領導寫 request.md（逐字）
                    │
                    ▼
              領導寫 brief.md（轉換：劃 AC、切所有權、分波）
                    │
                    ▼
              dk-brief-check              機械閘，零 token
                    │ 全 OK
                    ▼
              dk-brief-review             2–3 個 kind，各讀 request.md + brief.md
                    │                     各自寫 state/reviewer-p<n>.report.md
                    ▼
              領導讀齊 → dk-process "brief-review verdict p1: ok / p2: important 2"
                       → dk-process "ruling: <決定> — <原因> — <若錯代價>"
                       → 改 brief → 重跑 dk-brief-check
                       → dk-wave-close --agent <short>-reviewer-p<n>（逐個關 pane）
                    │
                    ▼
              dk-task-new <short> --gate1  硬閘：三道（見第 8 節）
                    │
                    ▼
              關卡①：人拍板 → /dkbo-run
```

## 5. 檔案佈局

```
.dkbo/tasks/<日期-短名>/
  request.md                    新。需求原文，領導逐字落檔
  brief.md                      領導的轉換產物
  briefs/reviewer-p1.md         新。計畫審查切片（三個 kind 同一張考卷）
  briefs/reviewer-p2.md
  state/reviewer-p1.md          reviewer 的 state
  state/reviewer-p1.report.md   意見報告
  process.md                    brief-review spawned / verdict / skipped
```

## 6. `dk-brief-review` 規格

```
dk-brief-review [--kinds "k1 k2 k3"] [--tier M|L]
```

**行為，依序：**

1. 取任務目錄、`dk_task_env`、`dk_settings`。
2. 前置：`request.md` 存在且非空，否則 `dk_die`（理由見決策②）。
3. 跑 `dk-brief-check`，非零就 `dk_die`，不派任何人。**零 token 的閘沒過就燒三個 kind 的 token，是這個
   設計裡最蠢的失敗模式，值得用一行 code 擋掉。**
4. tier：`--tier` > `DK_REVIEW_TIER`，只接受 `M` 或 `L`（與 `dk-review` 相同的驗證與錯誤訊息）。
5. kinds：`--kinds` > `DK_REVIEW_KINDS`；濾掉 `.task.env` 的 `DK_KIND_DOWN`；取前 3 個。
   一個都不剩 → 印出提示要領導記 `brief-review skipped: all kinds down`，`exit 1`。
6. 逐個 kind 產切片 `briefs/reviewer-p<n>.md`（範本見第 7 節），然後
   `dk-spawn reviewer p<n> --isolated --kind <k> --tier <t>`。
7. 記 `dk_process "brief-review spawned p1(claude) p2(codex)"`，同一行印到 stdout。
   spawn 全滅 → `dk_die`；部分失敗照 `dk-review` 的做法標 `(kind,prompt-failed)` 並繼續。

**退出碼**：0 = 至少派出一位；1 = 沒派出任何人（含全數熔斷）。

## 7. 新範本 `templates/brief-reviewer-plan.md`

變數：`DISPLAY` `REQUEST` `BRIEF` `REPORT`。

```markdown
# {{DISPLAY}} — 計畫審查（reviewer 切片）
你審的是**還沒開工的計畫**，不是程式碼，也不是差異包。只讀、不改任何檔（包含 brief）、
不派工、不寫程式。意見只給領導（dk-msg leader），不要直接對任何人說。

## 要讀的（就這兩份，依序）
1. 需求原文 {{REQUEST}} —— 人講的原話，領導逐字抄下來的
2. brief {{BRIEF}} —— 領導的轉換產物

你不需要讀專案程式碼。你要回答的是「這份計畫做出來會不會是人要的東西」，
不是「這段碼寫得好不好」。每條意見都要指名 brief 的哪一段或波次表的哪一列。

## 報告寫到 {{REPORT}}，格式固定
## 需求覆蓋
（逐條對照 request：人要的每一件事，brief 有沒有對應的驗收標準？
  漏的列出來，指明 request 的哪一段沒有被接住）
## 驗收標準可驗證性
（逐條 AC：能不能明確判定過或不過？不能的指出來，並給一個可驗證的改寫）
## 檔案所有權
（成員之間有無重疊或遺漏？有沒有哪條 AC 要動的檔沒有任何人擁有？獨佔資源欄有無漏）
## 波次切法
（順序合理嗎？同一波裡有沒有人其實要等另一個人的產出？共用契約有沒有指定擁有者）
## Minor
（其餘建議）
## 結論
一行，只能是 `可以開工` 或 `要改 N 處`（N = 前四段裡你認為**必須**改的條數）

## 完成
state 檔 `status: done`，然後
dk-msg leader "[DONE] brief-review: <可以開工|要改 N 處>，見 report"
```

**前四段的順序是刻意的。** 需求覆蓋排第一，因為那是唯一「只有看了 request 才答得出來」的一段。排在
後面的話，模型容易在所有權、波次這些具體的東西上耗完注意力，最後對需求覆蓋草草帶過。最貴的錯要放在
它最清醒的時候問。

**`## 結論` 逼一個離散答案**，讓領導能一眼比較三份報告，也讓 `[DONE]` 訊息本身就帶資訊。代價是模型
可能為了給數字而湊數 —— 湊出來的條目在領導讀 report 時會露餡，可接受。

## 8. 對既有檔案的改動

### `lib/review.sh`（新）
把 `dk-review` 與 `dk-brief-review` 共用的 kind 選擇邏輯抽出來（覆寫 > 設定、濾熔斷、取前 3、全滅時的
訊息）。`dk-review` 改為呼叫它。**這是為了這件工作必要的整理，不是順便重構** —— 不抽的話同一段 20 行
邏輯會有兩份，熔斷規則改一邊忘一邊。

### `bin/dk-task-new`
- 建任務時產出 `request.md`：`--from <檔>` 且該檔可讀 → **逐字複製內容**（不是塞路徑字串）；
  否則寫一份空殼（標題 + 一行提示「領導把人的原話抄在這裡，不要摘要」）。
  `--from` 對 brief「來源」欄的既有行為不變。
- `--gate1` 新增三道閘，任一不過就拒絕並印出該跑什麼：
  1. `process.md` 有 `brief-review verdict …` 或 `brief-review skipped: <理由>`。
  2. verdict 要交代**每一位真的派出去的別名**（從最後一行 `brief-review spawned` 抓 `p1 p2`），
     少一位就拒絕。照抄 `dk-wave-close` gate a2 的理由：派了三個 kind 卻只讀一個的意見，第二意見白花。
  3. `.panes` 裡沒有 agent 名符合 `<短名>-reviewer-p<數字>` 的列還活著。留著的話它們會佔版面格子、被守望當活人算逾時，而且
     `dk-wave-close` 的 gate 0（每個人都 done）會把它們算進第一波，導致第一波永遠關不掉。

### `templates/brief.md`
標頭加一行指向 `request.md`，讓讀 brief 的人知道原文在哪。

### `roles/reviewer.md`
「職責」加計畫審查為第三種工作（已有實作波審查、結案評議），並寫明**報告格式以切片為準** ——
現行的完成定義寫死了 `## 規格合規 / Important / Minor` 與 `file:line`，計畫審查沒有 `file:line` 可附。

### `skills/plan/SKILL.md`
步驟改為：
1. `dk-task-new <short> "<顯示名>" [--from <檔>]`
2. **寫 `request.md`**（逐字，不摘要）
3. 寫 `brief.md`
4. `dk-brief-check`
5. `dk-brief-review`，等 reviewer `[DONE]`
6. 達 `DK_REVIEW_MIN` 位回覆、或所有人都回覆了，即可裁定（與 `/dkbo-run` 收 `dk-review` 的規則相同）：
   `dk-process "brief-review verdict …"` → 有爭議記 `ruling:` → 改 brief →
   **重跑 `dk-brief-check`** → `dk-wave-close --agent` 逐個關掉 reviewer pane
7. 關卡①：把 `request.md` + `brief.md` + 裁定摘要給人 → `dk-task-new <short> --gate1`

「改完 brief 要重跑 `dk-brief-check`」只寫進 SKILL，不做機械強制 —— `--gate1` 那時已經無法分辨
「改過但重跑過」與「改過沒重跑」。

### `.dkbo/README.md`、`README.md`、`CHANGELOG.md`
指令一覽加一列；生命週期那段補上這道閘；版號與變更紀錄。

## 9. 關卡①給人看什麼

`request.md` + `brief.md` + 裁定摘要（三份）。只給 brief 的話，人看不出領導有沒有從一開始就聽錯 ——
而那正是 reviewer 結構上抓不到的那一類錯（決策③）。

## 10. 測試計畫（bats，假 herdr）

新增 `tests/unit/28_brief_review.bats`：

1. `request.md` 缺席或空 → 拒跑，不 spawn 任何人
2. `dk-brief-check` FAIL → 拒跑，不 spawn 任何人（證明順序由程式保證）
3. 正常路徑 → 依 `DK_REVIEW_KINDS` 派出對應數量、別名為 p1/p2/p3、切片檔存在且變數都被替換
4. `--kinds` 與 `--tier` 覆寫生效；`--tier` 非 M/L 被拒
5. `DK_KIND_DOWN` 裡的 kind 被跳過；全數熔斷 → `exit 1` 且訊息含 `brief-review skipped: all kinds down`
6. 超過 3 個 kind 只取前 3
7. `process.md` 寫出 `brief-review spawned …` 且格式可被 gate 解析

`tests/unit/05_task_new.bats` 補：

8. `--from <檔>` 把內容**逐字**複製進 `request.md`（不是路徑字串）
9. 沒有 `--from` 時 `request.md` 是空殼且存在
10. `--gate1` 三道閘各自的拒絕情境與通過情境（含「verdict 少交代一位別名」與「reviewer pane 還活著」）

## 11. 已知限制

- **領導誤解需求時 reviewer 也跟著誤解**（決策③）。緩解手段是關卡①給人看 `request.md`，不是機器能解的。
- **`dk_first_prompt` 會叫 reviewer 讀 `templates/report-employee.md` 並說「## 測試」必填**，對計畫
  reviewer 不適用。現行 `dk-review` 已有同樣的摩擦（靠切片覆蓋），這次沿用同樣的做法，不在這一輪動
  首輪提示的結構。
- **glob 對不上真實檔案這類錯抓不到**（決策⑧），要等 `dk-wave-close` 的真實 diff 比對。

## 12. 不做什麼

- 不做第二輪反駁（決策④）
- 不新增 `DK_BRIEF_REVIEW_*` 設定（決策⑥）
- 不新增 `plan-reviewer` 角色（決策⑨）
- 不改 `dk-watch`（決策⑩）
- 不寫 markdown parser 去機械驗 `request.md` 的內容 —— 它是人話，機器只驗存在與非空

## 13. 驗收標準

- [ ] AC1 `dk-brief-review` 在 `request.md` 缺席或 `dk-brief-check` 未過時拒跑，且不 spawn 任何 pane
- [ ] AC2 正常路徑派出 1–3 位 reviewer，別名 p1/p2/p3，各自拿到內容相同的切片
- [ ] AC3 `--kinds` / `--tier` 覆寫生效，熔斷的 kind 被跳過，全滅時以非零退出並給出該記的 process 行
- [ ] AC4 `dk-task-new --gate1` 在缺裁定行、裁定漏交代別名、reviewer pane 未關這三種情況下各自拒絕
- [ ] AC5 `--from <檔>` 把需求原文逐字寫進 `request.md`
- [ ] AC6 `dk-review` 改用 `lib/review.sh` 之後行為不變（既有 `20_review.bats` 全過）
- [ ] AC7 全套 `tests/run.sh` 綠燈
