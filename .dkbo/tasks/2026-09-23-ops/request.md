# 營運回饋修補（panova headermerge） — 需求原文

把人講的原話**逐字**抄在下面。不要摘要、不要改寫、不要先做技術轉換 ——
brief 才是轉換的產物，這一份是用來比對「brief 有沒有漏掉人要的東西」的基準。
外部文件（spec、issue、對話紀錄）請把相關段落整段貼進來，不要只留連結：
連結會死，而這個檔案要活到任務歸檔之後還有人讀得懂。

---

（原文從這裡開始）

## 2026-09-23 對話逐字紀錄

**人：**

> 先幫我分一下昨日 panova2 的任務執行過程，看看有沒有哪些流程是需要改善的

（領導把 `sport-frontend-panova` 的 `2026-09-22-headermerge` 讀完後回報，內容見下一段。）

**人：**

> 寫成 plan 在 review

---

## 領導回報（人要求寫成 plan 的對象）

這一段不是人的原話，是人那句「寫成 plan」所指的內容。為了不讓 reviewer 的畫面冒出 dk-watch 的額度字樣而被誤判熔斷，
凡是 `kinds/*.sh` 的 `KIND_QUOTA_RE` 會命中的英文字樣，這裡一律改用描述（例如「codex 的快到額度選單」），不抄原文。
原文樣本在 panova 那邊的領導 session 與 spike 目錄，實作時再看。

來源：`sport-frontend-panova/.dkbo/tasks/2026-09-22-headermerge/` 的 process.md、messages.log、report.md、state/*，
以及規劃領導 session `11f580b2` 與執行領導 session `7b4db904` 的逐字紀錄。panova 當時跑 0.11.1。
任務 20:08 開、22:59 合併，171m；計畫 19m、波 1 47m（dev 23m／審查 23m）、波 2 68m（dev 2m／審查 33m）。

### 一、dkbo 本身要改的
1. **熔斷不跨任務**：`DK_KIND_DOWN` 只活在該任務 `.task.env`。9/19 gamemore 已查明 codex 要到 Oct 11 才恢復、
   agy 約 9/23 下午恢復，9/22 新任務的 `DK_KIND_DOWN` 又是空的，計畫審查照派 codex 與 agy，當分鐘與三分鐘後各撞一次，
   之後整個任務（計畫審查、兩波、兩次整枝評議）只剩 claude 一份第二意見。建議熔斷記到專案層並帶恢復時間
   （codex 畫面印「try again at <日期>」、agy 印「Resets in <N>h<M>m」），派 reviewer 前先查、沒過恢復時間就跳過。
2. **`[LIMIT]` 的證據隨 pane 消失**：規劃領導收到兩則 `[LIMIT]` 都沒讀畫面就 `dk-wave-close --agent` 關掉，
   事後無從查證。有誤判前例（9/19 agy 首則 prompt stall 被一併記成 limit；codex 的快到額度選單在寬 pane 上標題會先命中額度式子）。
   建議 `handle_limit` 把命中的幾行存進 `.blocked/<agent>.limit`，`[LIMIT]` 訊息也帶命中那一行。
3. **改 brief 正本不會同步切片**：`briefs/<成員>.md` 是 `dk-wave-open` 當下產的；領導波中改了 AC12、AC15、所有權表，
   21:08 frontend 因此卡在所有權（正本有 project-gotchas、切片沒有）。建議重產切片的指令，或 `dk-msg` 在 brief 比切片新時警告。
4. **state 格式不驗證**：translator 的 `touched:` 寫成一行 brace glob，缺 `current`／`todo`／`report`；`dk_touched` 解析不到，
   21:14 wave-close 把四支 i18n 檔判成 `unreported`，只有警告。建議寫完 state 就驗格式。
5. **波中加範圍，逾時不重新起算**：波 2 開波時只有一行 CSS（S），人陸續追加三項並加 designer，22:42 觸發 60 分鐘 `[TIMEOUT]`，是雜訊。
6. **結案後 report.md 是舊的**：已經 `task-close merged 6461612`，report 還寫「結果：待拍板」與「171m（進行中）」。
   （領導規劃時查到根因：`dk-task-close` merged 路徑的 `fill_timeline`（第 108 行）在 `dk_process "task-close merged"`（第 173 行）之前跑，
   與第 12 行註解說的「放在 task-close 之後」相反。）

### 二、領導行為面（改 LEADER.md／skill 措辭）
7. **發訊息前沒先讀收件匣，指示互相打架**：20:56 叫 frontend 先別修 ESC，但它 20:53 已修好；21:02 同分鐘對 qa 三則 TASK，
   其中一則在發出前已被 frontend 的實證推翻；21:07 同分鐘先撤回 ✅ 又宣布達標。ESC 一題繞約 15 分鐘。
   建議規範明寫「送 TASK／DECISION 前先讀 messages.log 裡比你上一則新的訊息」，或 `dk-msg` 提示有未讀。
8. **UI 任務讓人看畫面太晚**：波 1 結波 → 整枝評議 → 人才看 dev server → 追加四項開波 2 → 再整枝評議一次，第一次整枝評議白做。
   建議有視覺變更的任務，結波後先請人看，確認沒有追加再整枝評議。

### 三、專案面（panova 自己的坑，任務內已記，不動流程）
- dev server 被 `quasar dev` 內建 eslint watcher 打掛（BACKLOG 已有）；可考慮 dk-watch 順手 curl。
- qa 探測腳本的暗色切換是空操作、波 2 刪了波 1 的 AC 覆蓋，reviewer 已攔。

領導建議先做 1＋2（都在 dk-watch 與 `lib/review.sh` 一帶），3、4 其次。

### 前一輪已出貨的相關修補（本倉 af36aec，0.11.2，尚未 push／tag）
codex 的 `KIND_BLOCK_RE` 補上 `Press enter to`，讓快到額度的切換模型選單在窄 pane 被判成等審批。
CHANGELOG 0.11.2 記了已知未處理：寬 pane 上該選單標題會先命中 codex 額度式子裡的裸字樣、被判撞額度並熔斷 codex。
