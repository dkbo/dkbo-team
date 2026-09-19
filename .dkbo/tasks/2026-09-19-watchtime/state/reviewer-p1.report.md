# reviewer-p1 brief-review 報告

## 需求覆蓋
- 誤判修復（request 第1件事）：brief 目標(1) 與 AC1–AC4 對應 BACKLOG 條目的「方案 A（agent_status 前提）」，覆蓋到位。用 `.dkbo/tasks/2026-09-19-highfix/process.md` 的真實事故紀錄核對：兩次誤判發生當下員工狀態列都顯示仍在工作／收尾（20:58、21:21 兩則 note），與 AC1「working 就不做畫面判定」的前提相符，這條修法確實會擋住這兩次已發生的事故。
- 缺口①：BACKLOG 原文「順帶：領導解除熔斷後 `.limit` 標記要留著，否則同一畫面下一輪立刻再熔斷」——這句是需求原文的一部分，但 brief 全域約束與 AC1–AC4 都沒有對應處理，也沒有說明「現狀已經滿足、不需改動」。highfix 的 process.md 顯示這件事目前是**領導手動**留著標記檔（21:58 note：「`.blocked/highfix-backend.limit` 保留，避免同一畫面再熔斷一次」），看不出是不是 dk-watch 本來就會保留、還是純靠人記得別去刪。這件事没有被任何 AC 接住，人可能會覺得沒做完。
- 缺口②：request.md 明白標記「關卡①請人確認」——領導對「看到任務時間」的解讀（落在 dk-resume/dk-wave-close/dk-timeline/dk-task-close 四處）尚未見到人確認的紀錄，但 brief 目標(2)、AC5–AC9 已經整批照這個解讀寫死。這不是 brief 內容本身的缺陷，是流程缺口：開工前（gate1）這個確認動作要真的做，不然一旦解讀有出入，AC5–AC9 全部要重來。

## 驗收標準可驗證性
- AC1–AC4、AC5–AC7、AC9–AC11：條件、輸入輸出、通過/失敗判準都寫得夠具體，可驗證。
- AC8（Important，需改）：highfix 的四組數字（任務 66 分、計畫 6 分、波1 27 分/審查 7 分、波2 16 分/審查 3 分）我用真實 `process.md` 的時間戳逐筆手算全部核對相符，這部分寫得很扎實。但 flowgap 那組寫的是「由 dev 自己人手算後寫進測試斷言與 report」——驗收標準的判準來源和驗收人是同一個人，這是自證迴圈：dev 算錯，測試照樣綠，不會被抓到。可驗證的改寫：比照 highfix，brief 直接把 flowgap 的期望分鐘數算好列進這條 AC；或者維持現狀但明確加一句「reviewer 複看波 1 時要重新人手核算 flowgap 的數字，兜底 dev 的自算」。
- AC3「有測試明文這個選擇」：判準偏軟（"明文"沒定義到什麼程度算過），但影響小，列 Minor 不列 Important。

## 檔案所有權
- 兩位成員可改清單互不重疊，AC 提到要動的每個檔都能在某一方的可改清單裡找到（dk-watch/lib/kinds.sh/kinds/** → backend-watch；dk-resume/dk-wave-close/dk-task-close/dk-timeline/common.sh/templates/report.md/skills/run/SKILL.md/VERSION/README*/CHANGELOG.md/tests/fixtures/** → backend-time），沒有遺漏。
- 共用契約表的「CHANGELOG 0.9.2 條目」與「process.md 時間行的 token」把跨檔案協作寫清楚了，backend-watch 只讀 CHANGELOG、backend-time 只讀 dk-watch 寫的 process 行語意，方向一致沒有矛盾。
- 獨佔資源都填 `—`：這個任務是純腳本／測試，沒有共用 dev server 或 port，合理。

## 波次切法
- 只有一波、兩位成員平行做不相交的檔案，沒有「同波裡有人要等另一人產出」的阻塞式依賴。
- 唯一的跨人依賴是共用契約裡的 CHANGELOG 交接（backend-watch 做完 dk-msg 一行給 backend-time），這是訊息交接不是檔案依賴，靠 dk-msg 就能解，不需要拆波。Minor：波次表「做什麼」欄可以補一句提醒 backend-time「AC11 的 CHANGELOG 收尾要等 backend-watch 那則 TASK 訊息」，避免 backend-time 誤以為自己先做完就能關波。
- 審查欄只填在第一列（預設），符合格式規則，沒有缺漏。

## Minor
- AC1/AC2 的「working 時不看畫面」修法目前用兩次真實事故驗證都成立，但兩次事故發生當下狀態列都還在動（working/收尾）。理論上還有一個沒被兩次真實事故覆蓋到的邊界：員工剛從 working 轉 idle、畫面殘留舊文字（例如剛寫完引用 usage limit 的 report、還沒送出）的那個瞬間，這個修法擋不住。建議波 1 測試裡加一條這個邊界的用例，不強制列進 AC（現有 AC1 的判準已經足夠明確可驗收）。
- AC3 判準「有測試明文這個選擇」偏軟，建議改寫成「有測試斷言 agent_status 取不到時走畫面判定路徑，測試名稱含 unknown-status 或等義字樣」。

## 結論
要改 2 處
