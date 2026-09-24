# reviewer-p1 報告 — testtrust 計畫審查（dk-brief-review）

## 做了什麼
依序讀了 request.md、brief.md，也讀了 process.md 的兩條 ruling。brief 裡能直接驗的前提，逐條對照 HEAD fb60415 的實檔：否定斷言分佈、`fixture_task()` 的呼叫形狀、`templates/task.env`、`dk-task-new` 傳給模板的變數、`dk_render`、CHANGELOG 0.15.0 節，以及 21/25 對 CHANGELOG、BACKLOG 的斷言。只讀，沒有改任何檔。

## 需求覆蓋
request 裡人選中的是「處理 L29 和 L30」。brief 要接住的有三件事：BACKLOG 兩列，加上領導試跑發現的第三件。

- **L29（否定斷言失效）**：換成 refute_grep 或 run，由 AC1、AC2 接住。建議處理欄寫的是「給 tests/run.sh 加一條掃描式 meta 測試」，AC3 做成 `tests/unit/35_test_hygiene.bats`。`tests/run.sh` 預設跑 `tests/unit`（`tests/run.sh:8`），所以兩者等價。✅
- **L30（fixture 漂移）**：BACKLOG 給了兩個選項，一是套模板，二是「至少補鍵集合一致的測試」。brief 兩個都做（AC4 加上 AC5(a)）。✅
- **試跑第三點**：「06、09、12、16、20、28、29 拿到空 `.task.env` 照樣全綠 —— fixture 壞掉沒有任何測試會紅」。❌ **只接住一半（必須改 #1）**。
  - AC5 自檢有兩個分支：「仍含 `{{`」與「缺模板任一 `DK_*` 鍵」。
  - 試跑那種壞法（`dk_render` 不存在，產出空檔）**不含 `{{`**，只有「缺鍵」分支抓得到。
  - 但 AC5 的三條新測試都沒碰到「缺鍵」分支：(a) 是成功路徑下比鍵集合，(b) 走的是 `{{` 分支，(c) 是成功路徑下檢查非空。AC8 的兩項取紅也沒有這一種。
  - 結果是 dev 就算只實作 `{{` 分支，AC 也全過，而 request 點名的那種壞法仍然全綠。
  - **改寫建議**：AC8 加 (c)。在副本（照全域約束，cp 或 git archive）把 fixture「套模板」那一步換成產出空檔，重現試跑。這時 06（`>/dev/null` 形狀）與任一 `d=$(…)` 形狀的檔（例如 09）setup 都必須紅，stderr 要列出缺的鍵。或者在 AC5 加 (d)：讓渲染步驟產出空內容時 `fixture_task` 回非零，stderr 含 `DK_SHORT`。前者不需要在 fixture 開測試鉤子，比較省。

## 驗收標準可驗證性
- **AC1** ✅ 可機械判定，定義清楚。
  - 我用 AC1 的規則掃 HEAD：74 行、76 次出現，分佈在 15 個檔。`07_spawn.bats:104` 與 `20_review.bats:48` 各一行兩處，所以 request 的「76」是出現次數。
  - `tests/*.bats` 的 git pathspec 會跨 `/`，追蹤中的 .bats 全在 `tests/unit/` 下。
- **AC2** ✅ 大致可判。「原本就有效／原本失效」的分類在邊角有模糊地帶，見 Minor。
- **AC3** ✅ 兩個方向都有具體樣本。不過樣本沒涵蓋 AC1 列的 `&&`、`||`、`do` 三種前綴，而且 35 本身也在掃描集合裡，見 Minor。
- **AC4** ✅ 值的清單明確。
  - 我逐鍵對過模板：16 鍵，其中 10 個 `{{}}`，全有給值。
  - `LEADER_PANE` 給空字串與 `dk-task-new:67`（`LEADER_PANE=$root_pane`）不同。但這樣才能保住「642 條語意不變」：heredoc 版根本沒有這個鍵，而 `setup_project` 洗掉了 `DK_*`，所以現況等同空值。建議在 brief 註明是刻意的，免得 dev「修正」它。
  - 「不在呼叫端留下新變數或函式」沒有對應的驗證方式，見 Minor。
- **AC5** ✅ 可判。
  - 兩種呼叫形狀的說法經查屬實：45 處 `d=$(fixture_task …)`，1 處 `06_msg.bats:2` 的 `>/dev/null`，沒有 `local x=$(…)` 這種會吞掉狀態的形狀。
  - 缺鍵分支沒測到，已列在「需求覆蓋」#1。
  - (b) 與首句的措辭不一致，見 Minor。
- **AC6** ✅ 可判：兩列文字唯一，BACKLOG 內沒有其他列引用它們。`25_docs_policy.bats:10` 只掃 `docs/design`，不受影響。
- **AC7** ✅ 可判。`21_version.bats:39-49` 只查首節的版號與四個關鍵字，加 `test:` 條目不會碰到。「+4」的處理見 Minor。
- **AC8** ✅ 可判。(a) 的計數單位（行或出現次數）見 Minor。
- **全域約束第 15 行（`brief.md:15`）的「二選一後全倉一致」**：❌ **必須改 #2**。
  - 這是把「選 A 或 B」直接交給 dev，而 PROTOCOL 規則寫明「任何『選 A 或 B』一律 ESCALATE」。照規則，dev 一開工就得先升報一輪。
  - 兩條路也不對等。`run <cmd>; [ "$status" -ne 0 ]` 會覆寫 `$status`／`$output`，brief 自己在第 16 行也提醒了。所以 `run` 未必能套到每一處，「全倉一致」可能根本做不到。新增 `refute` 則每一處都能用。
  - 目前需要轉非 grep 的處數很少，例如 `01_common.bats:156` 的 `! dk_legacy_task`、`08_wave_close.bats:121` 的 `! dk_owned`、`11_chore.bats:82` 的 `! git … rev-parse`。
  - **改寫建議**：領導現在就定案，並寫進全域約束與 AC1。我推薦 `refute <cmd> [args…]`，放在 `tests/helpers.bash`、緊接 `refute_grep` 之後。AC1 相應補一句：「非 grep 的否定一律 `refute …`，diff 裡不出現用來取代 `!` 的 `run …; [ "$status" -ne 0 ]`」，這樣才能機械判定。

## 檔案所有權
✅ 沒有重疊，也沒有遺漏。
- 只有 backend 一位成員，可改欄涵蓋所有 AC 會動的檔：AC1、AC3 的 `tests/unit/**`，AC4、AC5 的 `tests/helpers.bash`，AC7 的 `CHANGELOG.md`，AC6 的 `.dkbo/tasks/BACKLOG.md`。
- BACKLOG 的例外在 `process.md` 06:51 有 ruling。
- 追蹤中的 `*.bats` 全在 `tests/unit/`，沒有 unit 以外、沒人擁有的 bats 檔。35 這個號碼沒被佔用（現有到 34）。
- 35 不需要改 `tests/run.sh`，它只讀是對的。
- 獨佔資源填 `—` 正確：fixture 全在 `mktemp -d`、stub 化 herdr，沒有 port、db 或服務。

## 波次切法
✅ 合理。
- 一波一人是對的切法。轉換否定斷言（會新增 `refute` 到 helpers.bash）與改 `fixture_task()` 都動 `tests/helpers.bash`，拆給兩人就重疊。
- 「做什麼」的順序先寫 35 掃描器、對 base 取紅，再轉換到變綠，是先紅後綠的正確順序。
- 單人不需要共用契約，契約表留空合理。
- 審查欄填 `預設`，也就是 0.14.0 的 L reviewer，對一次碰全套測試的改動是合適的。

## Minor
1. `brief.md:6` 的目標寫死「76 處」，AC2 要的是「轉換總數」。建議註明「76 是出現次數，74 行」，免得 dev 對著 35 的逐行清單找不到另外兩處。request 說「另 4 處已帶 `|| {…}`」，我在 HEAD 只找到 2 處（`24_portability.bats:22`、`25_docs_policy.bats:10`），差距在 AC2 裡說明即可。
2. AC8(a)：「列出多少處」請指定單位，行數或出現次數擇一，並與 35 的輸出單位一致。
3. AC3 自我驗證的判出樣本，建議補 `true && ! foo`、`false || ! foo`、`for i in 1; do ! foo; done`，AC1 列了這三種前綴卻沒有樣本守著。另外 35 自己也在 (a) 的掃描集合裡：樣本如果以字面行寫在 35 裡（例如 heredoc），35 會把自己判紅。建議 AC3 註明樣本要用 `printf` 等方式寫進臨時檔，35 自身的 `檔:行` 也要掃得乾淨。
4. AC5 首句說「把缺的鍵名印到 stderr」，(b) 卻要求 `{{` 殘留時 stderr 含 `PROBE`，而那時 `DK_PROBE` 鍵其實在，並沒有缺。建議首句改成「缺的鍵名或殘留的佔位符名」。
5. AC4「不得在呼叫端 shell 留下新的變數或函式」沒有驗法。有兩個做法：
   - 建議實作用子 shell 呼叫真的 dk_render：`( . "$DK_ROOT/lib/common.sh"; dk_render … )`。`common.sh` 頂層會 export `DK_ROOT`、`DK_PROJECT_ROOT`、`LC_ALL`，放在子 shell 裡不外洩。這樣就是 L30 原話的「跟 dk-task-new 走同一條路」，不會多出第三份替換邏輯再度漂移。
   - 或者補一條測試：在同一個 shell 比較呼叫前後的 `declare -F`／`compgen -v`。
6. AC2 的分類有邊角要先定規則：`!` 若在某測試最後一行、但位於 `for` 或 `if` 內，只有最後一次迭代或該分支有效，要歸哪一類？建議規則是「只有它是整個 @test 最後執行的述句才算原本有效」。
7. AC7：0.15.0 的「測試：642 bats（+4；…）」括號裡是相對 0.14.0 的差量與明細（`CHANGELOG.md:10`）。只改條數的話，「+4」會跟新條數對不上。建議 AC 寫明括號一併更新，例如 `+4+k` 並列出本任務新增的測試。

## 測試
計畫審查，沒有程式碼可跑，也沒有跑 `tests/run.sh`。我跑的都是唯讀查核，用來驗 brief 的前提：
- `git ls-files 'tests/*.bats' tests/helpers.bash | xargs grep -nE '(^[[:space:]]*|;…|&&…|\|\|…|then…|do…)! '`，去掉註解後得 74 行。改用 `-o` 數出現次數得 76。帶 `|| {` 的有 2 行。
- 另外放寬 pattern，再掃 AC1 定義以外的 `! `：只剩 `03_kinds.bats:84`，是字串內容。`tests/` 其餘追蹤檔中只有 `tests/stub/herdr:30` 與 `tests/e2e/*.md`，不在 AC1 範圍。
- 列 `fixture_task` 的呼叫形狀：45 處 `d=$(…)`，1 處 `>/dev/null`，沒有 `local`／`export` 包住的形狀。
- 讀了 `templates/task.env`、`lib/common.sh:108-112`（dk_render）、`bin/dk-task-new:66-72`、`tests/helpers.bash`（setup_project 用 `cp -r` 複製 `.dkbo`，所以 AC5(b) 改的是副本的模板，不會汙染真倉）、`21_version.bats:39-49`、`25_docs_policy.bats:1-30`。

## 自我審查
- 每條意見都有指名 brief 的段落（AC 編號、`brief.md:行`）或波次表的列。
- 「必須改」只列了兩條，而且都會實際擋到結果：
  - #1 讓 request 點名的壞法仍然測不出來。
  - #2 照 PROTOCOL 必然多一輪升報，而其中一個選項未必可行。
- 其餘列為 Minor。

## 疑慮
- request 的「另 4 處已帶 `|| {…}`」我只找到 2 處，差距來源沒查出來。不影響開工，AC2 本來就要求說明差異。

## 結論
要改 2 處
