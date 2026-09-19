# 流程缺口補齊 結案
結果：待拍板   分支：dk/flowgap   波數：4

## 完成
把 dkbo 相對 superpowers 的六個流程缺口補齊，出貨 0.9.0。24 條驗收標準全數達成。

| 波 | commit | 內容 |
|---|---|---|
| 1 | `ae24f02` | brief 契約擴充：`## 全域約束` 段與 `dk_brief_constraints()`、共用契約表格化與 `dk_brief_interfaces()`、兩道新閘（舊 WARN／新 FAIL）、三份切片帶上新欄位 |
| 2 | `c51d889` | 品質方法論：`## 測試` 拆成 `### 紅`／`### 綠` 與 `dk-wave-close` 的 gate b、`methods/debugging.md`、首輪提示帶 TDD 順序與除錯指路 |
| 3 | `245cff2` | 審查迴圈：`dk-spawn --handoff`、Minor 匯總進整枝評議切片、修復迴圈兩輪、0.9.0 收尾 |
| 4 | `4ff776d` | 整枝評議的 2 條 Important 與 4 條 Minor |

六個缺口對應：全域約束（AC1、AC2）、介面契約（AC3、AC4、AC15）、TDD 骨架（AC5–AC7）、
systematic-debugging（AC8、AC16）、Minor 匯總（AC9、AC10、AC18、AC20、AC24）、
修復迴圈中間層（AC11–AC13、AC19、AC23）。另加 AC14（全套綠）、AC17（測試隔離）、AC21、AC22。

## 未完成 / 遺留

**三條 Minor 判定不修**（整枝 reviewer triage，領導記 ruling）：
1. 共用契約的新舊格式判別器用「表頭存不存在」而非「段落存不存在」，與 AC4 字面有詮釋差異。
   表頭是唯一能區分「舊 brief 的自由文字」與「新 brief 寫壞了」的訊號，而「只有表頭、沒有資料列」
   是合法的無契約狀態。CHANGELOG 已寫明判別方式。
2. `implementation.md` 的 Task 7 寫 `tests/unit/30_methods.bats`，實際落成 `31_methods.bats`
   （30 被波 1 的 AC17 回歸測試佔用）。計畫文件是開工前的產物，事後回改就不再是當時的計畫。
3. `dk-review --task` 的 reviewer 切片「本波成員」欄必然空白（`n=task` 查不到波次成員）。
   0.8.x 既有狀態、非本波引入，純屬顯示。

**未經整枝視角審查的範圍**：波 4 是整枝評議的修復波，它自己經過 reviewer 以 `waves/4.diff`
逐條核過 AC18–AC24，但沒有再跑一次整分支評議。波 4 引入新問題的殘留風險由關卡③承擔。

**本任務實跑查到、記進 `tasks/BACKLOG.md` 的 dkbo 缺陷七條**（都不在本任務範圍內，未修）：
`dk-watch` 的 dev 聚合誤判跨波成員（高）、`dk-wave-close` gate c 洩漏領導環境（高，已造成實際損害）、
agy 啟動橫幅命中裸 `quota`（高）、`dk-msg` 等閒置才送導致補派工必然遲到（中）、
`dk-wave-open` 等下游仍用裸 `awk -F'|'` 切欄（中）、契約表 schema 容不下跨波契約（低）、
角色檔「交接對象」寫死 qa（低）。

## 驗證
- `tests/run.sh`：354 → **384 ok**（+30），零 `not ok`。四波的 `dk-wave-close` gate c 都在 worktree 實跑過。
- `shellcheck .dkbo/bin/* .dkbo/lib/*.sh`：零警告。
- 版本一致性：`.dkbo/VERSION`、`CHANGELOG.md` 首節、三份 README 的版本字串全部 0.9.0（`21_version.bats` 守著）。
- 審查覆蓋：計畫審查 1 位有效（claude；codex 與 agy 撞額度）。波 1 三輪（原審 + 兩次複看）、
  波 2／3／4 各一輪、整分支評議一輪（L 檔）。全部 claude —— **這個任務全程只有單一模型審查**，
  codex 到 10/11、agy 約四天後才恢復。
- 相容性：兩道新 brief 閘對 0.9.0 之前建立的 brief 只給 WARN，升級後進行中的任務不會被卡死。

## 重要決策
1. 本任務放行員工修改 `.dkbo/` —— `PROTOCOL.md` 的停止條件「不改 `.dkbo/` 下的規則檔」與本任務直接衝突，以檔案所有權為準。
2. AC5 從「小節存在」改成「各小節至少兩行內容（指令列＋輸出）」，`不適用: <理由>` 單行豁免 —— 只驗標題存在的話，一行「跑過了」就能過關。
3. 執行階段的審查欄從 `kinds: claude codex` 改成 `kinds: claude` —— 另兩個 kind 耗盡額度，寫著拿不到的 kind 只會讓每一波卡在補位。
4. 欄內 `|` 的切欄缺陷在波 1 修掉不延後 —— 既有函式，但這一波第一次把它接進會擋 exit code 的驗證。
5. 關卡①後修改 brief（補全域約束段、契約表擁有者／消費者改成成員短名）—— 原表違反本任務自己定的 AC3。
6. 接受 dev 在修復裡順手加的「欄數超過五欄 FAIL」，雖超出 BUG 原範圍 —— 切欄修好後少一欄會靜默通過，那正是要根除的形狀。
7. 測試隔離缺陷（`helpers.bash` 未 unset 繼承的 `DK_*`）在波 1 修掉 —— 不修就過不了 gate c。
8. `dk-wave-close` 用乾淨環境跑 `DK_TEST_CMD`（更通用的那一半）不在本任務做 —— 那支檔是波 2 要改的，兩波改同一支會打架。
9. 整枝評議的 2 條 Important 與 4 條 Minor 開波 4 修掉，不帶病合併 —— 兩條都是「功能做出來了但在別的專案上靜默失效」。
10. 累積的 minor 1、minor 2 與整枝 minor 8 判不修，理由見「未完成 / 遺留」。
11. 不再跑第二輪整分支評議 —— 波 4 已被 reviewer 以 `waves/4.diff` 逐條核過。

## 給下次的話（≤3 行）
讓 dkbo 跑自己是這次最大的收穫：七條缺陷沒有一條是假 fixture 測得出來的，兩條「高」還是 dkbo 自己的閘門親手擋下來的。
領導跑的是主樹腳本，所以這一版做出來的新閘在本任務內一次都沒真的生效 —— 要驗新閘，得等合併後的下一個任務。
補充派工要在 `dk-spawn` 之前寫進切片：`dk-msg` 等閒置才送，工作期間排入的訊息必然在員工剛交差的那一刻才到。
