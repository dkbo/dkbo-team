# 流程缺口補齊 — 需求原文

把人講的原話**逐字**抄在下面。不要摘要、不要改寫、不要先做技術轉換 ——
brief 才是轉換的產物，這一份是用來比對「brief 有沒有漏掉人要的東西」的基準。
外部文件（spec、issue、對話紀錄）請把相關段落整段貼進來，不要只留連結：
連結會死，而這個檔案要活到任務歸檔之後還有人讀得懂。

---

（原文從這裡開始）

## 人的第一句（2026-09-19）

> 目前 dkbo 跟 superpower 的流程對比

（領導做完對比後，列出六個「dkbo 缺、superpowers 有」的缺口：brief 的
Interfaces 區塊、Global Constraints 區塊、TDD 骨架、systematic-debugging
等價物、Minor 匯總去向、修復迴圈的中間層。）

## 人的第二句

> 馬上補上這幾個缺口

## 人的第三句

> 直接 commit 到 master，然後寫 implementation.md

## 人在設計問答裡做的裁定（逐題原文）

**這一輪的出貨範圍要多大？** → 「三組一個任務、三波」

**誰來實作？** → 「dkbo 自己跑（dogfood）」

**TDD 骨架要強制到哪一層？** → 「report 證據制」，並選了這個樣子：

```
## 測試

### 紅
$ pytest tests/test_login.py::test_401 -v
FAILED - NameError: verify_token not defined

### 綠
$ pytest tests/test_login.py -v
5 passed in 0.8s

→ dk-wave-close 驗：兩個小節都在、都有命令列與輸出
```

**除錯方法論要怎麼交到員工手上？** → 「獨立方法檔 + 提示指路」：

```
.dkbo/methods/debugging.md   ← 新檔，~40 行

PROTOCOL.md 的 BUG 列：
  「收到 BUG 先讀 $DK_ROOT/methods/debugging.md，
    照它走完再動手。」

[FIXED] 訊息要求附根因一句。
```

**修復迴圈的中間層該怎麼設？** → 「第二輪換腦袋，第三輪升報」：

```
BUG → FIXED → 再驗失敗
   ↓
領導裁定：換 kind（未熔斷者）或 --tier L
   dk-spawn backend --kind codex --tier L --resume
   新人讀 state + report：上一位試過 X、排除 Y
   ↓
再驗失敗 → ESCALATE（關卡②）
```

**新的 brief 閘對既有專案要多硬？** → 「舊格式 WARN，新任務 FAIL」：

```
既有任務（舊 brief）：
  $ dk-brief-check
  WARN 全域約束: 段落不存在（0.9.0 後的新任務必填）
  WARN 共用契約: 非表格格式
  → exit 0，波照跑

新任務（dk-task-new 產的範本）：
  FAIL 全域約束: 段落為空（無約束請寫「無」）
  → exit 1
```

**這個任務要怎麼開？** → 「指名 SKILL.md 進場」（不跑 install.sh，repo 結構不變）

**員工要改 .dkbo/ 這件事怎麼處理？** → 「brief 寫明例外並記 ruling」：

```
brief 全域約束：
  本任務的產出就是 .dkbo/ 下的規則檔與腳本。
  PROTOCOL 停止條件「不改 .dkbo/ 下的規則檔」
  對本任務不適用 —— 以檔案所有權為準。

process.md:
  ruling: 本任務放行 .dkbo/ 修改 — 任務內容
  就是改 dkbo 自己 — 若錯，員工會改到不該改的
  規則檔，靠 wave-close 的所有權比對兜底
```

## 設計與計畫

人已經看過並核可了設計；設計與實作計畫是這個任務的一部分，見同資料夾的
`plan.md`（設計）與 `implementation.md`（13 個 task 的實作計畫）。
兩份都已經 commit 在 master 上（218e650、88633e8、63e5c2f）。
