# backend-flow 報告（波 3）
## 做了什麼
AC17 的 dk-msg 半邊：
- `dk_state_format_error` 讀 `report:` 路徑後改用 while 迴圈去掉行尾空白再判斷是否存在、非空。
- 缺 `status`／`touched`／`report` 三個頂格鍵時，錯誤訊息各附上正確寫法範例（`status: working`、`touched: 或 touched: []`、`report: state/<你的 state 名>.report.md`）。
- `06_msg.bats` 補三條斷言：裸 `touched:`（沒有任何子項）合法、`report:` 路徑行尾空白仍放行、缺 `touched`／`report` 鍵的錯誤各附正確寫法。裸 `touched:` 本身的判定邏輯波 2 已經做對，只是先前沒有測試守住。

## 測試
### 紅
- 指令：`tests/run.sh tests/unit/06_msg.bats`
- 輸出：`not ok 43 AC17: report: 路徑後有行尾空白，去掉再判仍放行` 與 `not ok 44 AC17: 缺 status／touched／report 鍵的錯誤各附正確寫法`（其餘 42 條既有測試皆過）

### 綠
- 指令：`tests/run.sh tests/unit/06_msg.bats`
- 輸出：`1..45` 全部 `ok`（含新增的 43、44、AC17 裸 touched 42 三條）
- 指令：`tests/run.sh`
- 輸出：`621` 條全過，`[exited with code 0]`
- 指令：`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh`
- 輸出：無警告，exit 0

## 自我審查
- 一開始想連「缺 status 鍵」也一起補測試，但發現 dev 的 `[DONE]` 在進到 `dk_state_format_error` 之前已經先卡在既有的 `grep -q '^status: done'` 檢查（訊息是「先把 … 寫成 'status: done'」），所以 `dk_state_format_error` 裡的「缺 status 鍵」分支目前不可達；改寫測試只涵蓋 `touched`／`report` 兩個實際可達的分支，不動這條既有邏輯（不屬於本波所有權，也超出 AC17 範圍）。
- `report:` 去空白只處理行尾（`${rp% }` 迴圈），冒號後的行首空白原本 `sed -n 's/^report: *//p'` 已經吃掉，不需要重複處理。
- 只改了所有權表列出的 `.dkbo/bin/dk-msg` 與 `tests/unit/06_msg.bats`；`dk-wave-open`、`dk-task-close` 本波沒有東西要動。

## 疑慮
- 「缺 status 鍵，正確寫法：status: working」這個分支目前無法被觸發（見上）。若之後有人想讓它可達（例如把既有 `status: done` 檢查併進 `dk_state_format_error`），需要另外走 ESCALATE，因為那會動到既有測試斷言的訊息文字，不在本波範圍內。
