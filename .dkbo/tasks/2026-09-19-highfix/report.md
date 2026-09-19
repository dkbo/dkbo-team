# BACKLOG 三條高嚴重度缺陷 結案
結果：merged   分支：dk/highfix   波數：2

## 完成
修掉 flowgap 實跑記進 BACKLOG 的三條「高」缺陷，出 0.9.1。17 條驗收標準全數達成。

| 波 | commit | 內容 |
|---|---|---|
| 1 | `db9c2c2` | 三條缺陷各自先紅後綠：dk-spawn 存 state 的 cksum 快照、dk-watch 聚合改看「done 且內容變過」加逐波 latch；dk-wave-close gate c 用 `env -u` 剝掉所有 `DK_*`；agy 額度式收窄、通用回退式同步收窄、dk-watch 的 `(quota?)` 標記改走同一份 `KIND_QUOTA_RE`。0.9.1 版本字串與 CHANGELOG |
| 2 | `92002f5` | 整枝評議的 3 條 Important 與 1 條 Minor：latch 不再蓋過現況的 status（退件後不再假聚合）；三份 README 六處 herdr 版號改回 0.9.0 並新增測試比對 `DK_HERDR_MIN`；claude 額度式移除 `approaching your`；`(quota?)` 正向路徑補斷言 |

三條缺陷對應：dev 聚合競態（AC1–AC4、AC13）、gate c 環境洩漏（AC5、AC6）、額度式誤判（AC7–AC9、AC15、AC16）。另加 AC10／AC17（全套綠）、AC11／AC14（版本一致）、AC12（紅綠佐證）。

## 未完成 / 遺留
**整枝評議 triage 後判不修的 Minor 三條**（領導記 ruling）：
1. `dk-wave-close` 清 latch 的 key 來自波次表成員名，`dk-watch` 寫 latch 用 `.panes` 名，帶別名時可能不同名；現靠 `dk-wave-open` 擋同波號重開才安全。下次動這塊時把 key 來源統一成 `.panes`。
2. `.blocked/` 目錄混了六種語意的標記檔（blocked、limit、timeout、devdone、spawn 快照、done latch）；只有 `dk-task-close` 整個刪，沒有正確性問題。下次動這塊改名 `.marks/`。
3. gate c 的 `${!DK_@}` 在 bash 3.2 只有文件依據、未實機驗；加 macOS CI 時第一個驗。

**未經整枝視角審查的範圔**：波 2 是整枝評議的修復波，經 reviewer 以 `waves/2.diff` 逐條核過 AC13–AC17，未再跑第二輪整分支評議。

**本任務實跑撞出、記進 `tasks/BACKLOG.md` 的 dkbo 缺陷三條**（不在本任務範圍，未修）：
- 畫面式額度偵測會命中員工正在編輯或引用的字樣（高）：同一任務內兩次熔斷 claude，一次是 backend 寫額度式的測試字串，一次是 reviewer 在報告裡引用式子。AC7–AC9／AC15 收窄字樣治不了這個洞。
- agy 資料夾信任詢問的畫面字樣仍未實測，`KIND_BLOCK_RE` 沒有它，新 worktree 第一次跑 agy 若停在信任詢問守望認不出來。
- gate c 的 `env -u` 只剝 `DK_*`，`HERDR_*` 照樣傳給測試指令。

## 驗證
- `tests/run.sh`：384 → 396（波 1）→ **399 ok**（波 2），零 `not ok`。兩波的 `dk-wave-close` gate c 都在 worktree 實跑過。
- `shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh`：零警告。
- 版本一致性：dkbo 八處 0.9.1（`21_version.bats`），herdr 六處 0.9.0 且與 `DK_HERDR_MIN` 一致（新測試）。
- 審查覆蓋：計畫審查 1 位（claude M，抓到 AC4 行為未定與 AC12 佐證不足）、波 1 一輪（M）、整枝評議一輪（L，抓到 3 條 Important）、波 2 一輪（M）。**全程單一模型審查**，codex 到 10/11、agy 約 9/23 才恢復額度。
- 本任務修的競態在主樹舊版 dk-watch 上第三次實測重現（波 2 開波即收到假聚合，process 21:24 事故行），修法本身的測試在 worktree 內綠；合併後的下一個任務才是它第一次真的生效。

## 重要決策
1. 本任務放行員工修改 `.dkbo/`，以所有權表為準（與 flowgap 同一例外）。
2. `--resume`／`--handoff` 重派已 done 且內容不變的成員，聚合維持 done —— 重派多半是 pane 掛掉，工作沒有被撤銷。
3. 三條缺陷不拆三波 —— 單人、三支檔不重疊，拆波只多開關 pane 與 review 的成本。
4. 整枝評議的 3 條 Important 與 Minor 1 開波 2 修掉，不帶病合併。
5. `claude.sh` 移除 `approaching your` —— 預警不是耗盡，熔斷代價是整個任務失去該 kind，且它是常見英文片語。
6. 不再跑第二輪整枝評議 —— 波 2 已被 reviewer 以差異包逐條核過。
7. 兩次 `[LIMIT]` 皆判誤判並手動解除熔斷，`.limit` 標記留著防止同一畫面再熔斷。

## 給下次的話（≤3 行）
凡是任務內容碰到 `KIND_QUOTA_RE` 的字樣，寫它的人（dev、reviewer）必然被畫面式偵測熔斷；收到 `[LIMIT]` 先看狀態列的用量百分比再決定。
單人任務裡 dev 的 `[DONE]` 只落盤、聚合又會被舊 dk-watch 誤發，讓 dev 在波次表裡被要求送 `[FIXED]` 是唯一能叫醒領導的路。
版本字串測試刻意排除含 herdr 的行，所以「順手」改版號時 herdr 那幾處是盲區 —— 現在有測試守了。
