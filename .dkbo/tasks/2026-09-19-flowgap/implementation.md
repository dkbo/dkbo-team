# 流程缺口補齊 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 dkbo 相對 superpowers 的六個流程缺口補齊：brief 的全域約束與介面契約、TDD 骨架、除錯方法論、Minor 匯總、修復迴圈的中間層。

**Architecture:** 三組改動照載體切成三波，每一組都遵循 dkbo 既有的兩層結構 —— 規範寫在會被 rsync 升級覆蓋的檔（`templates/`、`lib/`、`PROTOCOL.md`、新增的 `methods/`），閘門寫在 `dk-*` 腳本裡用 exit code 擋。新舊 brief 的相容靠「段落／表頭存不存在」判別，舊的走 WARN、新的走 FAIL。

**Tech Stack:** bash 3.2+、jq、git、herdr 0.9.0；測試是 bats-core 搭 `tests/stub` 的假 herdr（零 token）。

**Spec:** `.dkbo/tasks/_specs/2026-09-19-flowgap.md`

## Global Constraints

- bash 3.2+（macOS 內建的就夠）；不得使用 bash 4 語法（關聯陣列、`${x^^}`）
- 依賴只有 herdr 0.9.0、git ≥ 2.17、jq ≥ 1.5；不得新增任何依賴
- shellcheck 零警告（`shellcheck .dkbo/bin/* .dkbo/lib/*.sh`）
- 不新增 `settings.env` 鍵、不新增 skill、不新增 `install.sh` 的 symlink
- 不改「員工在波內不 commit、`dk-wave-close` 過閘後統一 commit 一次」的模型
- 否定斷言一律用 `tests/helpers.bash` 的 `refute_grep`，不得寫 `! grep -q`
- 所有面向使用者的文案是繁體中文
- 目標版本 0.9.0（目前 `.dkbo/VERSION` 是 0.8.1）
- 測試指令一律 `tests/run.sh <檔案>`；它會自己 bootstrap bats-core

---

### Task 1: `dk_brief_constraints()` 與 `## 全域約束` 段

**Files:**
- Modify: `.dkbo/lib/brief.sh`（接在 `dk_brief_acceptance` 之後）
- Modify: `.dkbo/templates/brief.md`（「目標」段之後、「驗收標準」段之前）
- Modify: `tests/helpers.bash` 的 `fixture_brief`
- Test: `tests/unit/15_brief_lib.bats`

**Interfaces:**
- Consumes: `dk_brief_section BRIEF "## heading"`（既有）
- Produces: `dk_brief_constraints BRIEF` → 段落內文，含指引行；段落不存在時輸出空、exit 0

- [ ] **Step 1: 寫失敗的測試**

在 `tests/unit/15_brief_lib.bats` 末尾加：

```bash
@test "constraints: 段落讀得到，範本帶著它" {
  [ "$(dk_brief_constraints "$b" | grep -v '^[[:space:]]*$' | tr -d '\n')" = "bash 3.2+；不得使用 bash 4 語法" ]
  grep -q '^## 全域約束$' "$DK_ROOT/templates/brief.md"
}
```

- [ ] **Step 2: 跑它確認失敗**

Run: `tests/run.sh tests/unit/15_brief_lib.bats`
Expected: FAIL，訊息含 `dk_brief_constraints: command not found`

- [ ] **Step 3: 加 reader**

在 `.dkbo/lib/brief.sh` 的 `dk_brief_acceptance` 那一行之後加：

```bash
# 橫切所有波的硬要求（版本下限、命名規則、平台要求）。段落不存在＝0.9.0 之前建立的 brief。
dk_brief_constraints() { dk_brief_section "$1" "## 全域約束"; }
```

- [ ] **Step 4: 範本加段落**

在 `.dkbo/templates/brief.md` 的 `## 目標（≤3 行）` 段之後、`## 驗收標準` 之前插入：

```markdown
## 全域約束
（橫切所有波的硬要求，一行一條，值逐字：版本下限、命名與文案規則、平台要求。沒有就寫「無」）
```

指引行用全形括號開頭，是為了讓 Task 2 的「段落是否為空」沿用 `## 共用契約` 既有的 `grep -v '^（'` 過濾法。

- [ ] **Step 5: fixture 加段落**

在 `tests/helpers.bash` 的 `fixture_brief` heredoc 裡，`## 目標（≤3 行）` 那段之後插入：

```
## 全域約束
bash 3.2+；不得使用 bash 4 語法

```

- [ ] **Step 6: 跑測試確認通過**

Run: `tests/run.sh tests/unit/15_brief_lib.bats`
Expected: PASS

- [ ] **Step 7: 跑全套確認沒打壞別人**

Run: `tests/run.sh`
Expected: 全綠。`fixture_brief` 被很多檔共用，這一步是它的回歸測試。

---

### Task 2: `dk-brief-check` 的全域約束閘（舊 WARN、新 FAIL）

**Files:**
- Modify: `.dkbo/bin/dk-brief-check`（「── 驗收與契約」那一段之前）
- Test: `tests/unit/16_brief_check.bats`

**Interfaces:**
- Consumes: `dk_brief_constraints BRIEF`（Task 1）、`fail`／`warn`（本檔既有函式）

- [ ] **Step 1: 寫失敗的測試**

在 `tests/unit/16_brief_check.bats` 的 `@test "acceptance and contract must be present"` 之前插入：

```bash
@test "全域約束: 段落不存在只警告，段落在但沒填要擋" {
  run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]
  sed -i '/^## 全域約束$/,+1d' "$b"        # 舊 brief：整段不存在
  run dk-brief-check; [ "$status" -eq 0 ]; [[ "$output" == *"WARN 全域約束"* ]]; [ "$output" != OK ]
  fixture_brief "$d"                        # 新 brief：段落在，只剩指引行
  sed -i 's/^bash 3.2+；不得使用 bash 4 語法$/（橫切所有波的硬要求）/' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"FAIL 全域約束"* ]]; [[ "$output" == *"1 FAIL"* ]]
}
```

- [ ] **Step 2: 跑它確認失敗**

Run: `tests/run.sh tests/unit/16_brief_check.bats`
Expected: FAIL，第二段斷言拿不到 `WARN 全域約束`

- [ ] **Step 3: 加閘**

在 `.dkbo/bin/dk-brief-check` 的 `# ── 驗收與契約` 註解之前插入：

```bash
# ── 全域約束（0.9.0 新增）
# 判別器是「段落存不存在」：不存在＝0.9.0 之前建立的 brief，升級後不該把進行中的任務卡死；
# 存在但沒填＝新範本產出來的，那是真的漏填。同一招 0.8.0 在 request.md 的空殼 sentinel 用過。
if ! grep -q '^## 全域約束' "$brief"; then
  warn 全域約束 "段落不存在（0.9.0 之後建立的任務必填；沒有約束就寫「無」）"
elif [ -z "$(dk_brief_constraints "$brief" | grep -v '^（' | grep -v '^[[:space:]]*$' || true)" ]; then
  fail 全域約束 "段落為空（沒有約束請寫「無」）"
fi
```

- [ ] **Step 4: 跑測試確認通過**

Run: `tests/run.sh tests/unit/16_brief_check.bats`
Expected: PASS

- [ ] **Step 5: shellcheck**

Run: `shellcheck .dkbo/bin/dk-brief-check .dkbo/lib/brief.sh`
Expected: 無輸出

---

### Task 3: 共用契約表格化與 `dk_brief_interfaces()`

**Files:**
- Modify: `.dkbo/lib/brief.sh`（接在 `dk_brief_constraints` 之後）
- Modify: `.dkbo/templates/brief.md`（`## 共用契約` 段）
- Modify: `tests/helpers.bash` 的 `fixture_brief`
- Modify: `tests/unit/15_brief_lib.bats`（既有斷言 `共用契約 = 無` 會壞）
- Test: `tests/unit/15_brief_lib.bats`

**Interfaces:**
- Consumes: `dk__brief_rows BRIEF "## heading"`（既有；它會丟掉表頭列、分隔列與 `（範例）` 開頭的列）
- Produces: `dk_brief_interfaces BRIEF` → 每列 `契約|擁有者|消費者|形狀／簽名|變更流程`，欄位已去空白

- [ ] **Step 1: 寫失敗的測試**

在 `tests/unit/15_brief_lib.bats` 加：

```bash
@test "interfaces: 共用契約表格的資料列讀得到" {
  run dk_brief_interfaces "$b"; [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = "login API|backend|frontend-cart, qa|POST /login {user,pw} → {token}|動它要先 ESCALATE" ]
}
```

同時把既有那條會壞的斷言改掉。原本是：

```bash
  [ "$(dk_brief_section "$b" "## 共用契約" | tr -d '\n')" = "無" ]
```

改成：

```bash
  [ "$(dk_brief_section "$b" "## 共用契約" | grep -c '^|')" = 3 ]
```

- [ ] **Step 2: 跑它確認失敗**

Run: `tests/run.sh tests/unit/15_brief_lib.bats`
Expected: FAIL，`dk_brief_interfaces: command not found`

- [ ] **Step 3: 加 reader**

在 `.dkbo/lib/brief.sh` 的 `dk_brief_constraints` 之後加：

```bash
# 契約|擁有者|消費者|形狀／簽名|變更流程。0.9.0 之前的 brief 這一段是自由文字，回空。
dk_brief_interfaces() { dk__brief_rows "$1" "## 共用契約"; }
```

- [ ] **Step 4: 範本改成表格**

把 `.dkbo/templates/brief.md` 的

```markdown
## 共用契約
（誰定稿、放哪、變更流程）
```

換成

```markdown
## 共用契約
（一列一個契約。擁有者填一個成員短名；消費者填一個或多個、逗號分隔；沒有就填 —。完全沒有契約時只留表頭）
| 契約 | 擁有者 | 消費者 | 形狀／簽名 | 變更流程 |
|---|---|---|---|---|
| （範例）login API | backend | frontend, qa | `POST /login {user,pw} → {token,exp}` | 動它要先 ESCALATE |
```

- [ ] **Step 5: fixture 改成表格**

把 `tests/helpers.bash` 的 `fixture_brief` heredoc 裡的

```
## 共用契約
無
```

換成

```
## 共用契約
| 契約 | 擁有者 | 消費者 | 形狀／簽名 | 變更流程 |
|---|---|---|---|---|
| login API | backend | frontend-cart, qa | POST /login {user,pw} → {token} | 動它要先 ESCALATE |
```

- [ ] **Step 6: 跑測試確認通過**

Run: `tests/run.sh tests/unit/15_brief_lib.bats`
Expected: PASS

- [ ] **Step 7: 跑全套**

Run: `tests/run.sh`
Expected: 全綠。`dk-brief-check` 既有的「共用契約段落為空」檢查對表格照樣成立（表格列不是空行、不以 `（` 開頭）。

---

### Task 4: `dk-brief-check` 驗契約表格的擁有者與消費者

**Files:**
- Modify: `.dkbo/bin/dk-brief-check`（`# ── 驗收與契約` 段裡的共用契約那一行）
- Test: `tests/unit/16_brief_check.bats`

**Interfaces:**
- Consumes: `dk_brief_interfaces BRIEF`（Task 3）、`$members`（本檔在所有權迴圈裡組出來的字串，格式是前後帶空白的 `" backend frontend-cart qa "`）

- [ ] **Step 1: 寫失敗的測試**

```bash
@test "共用契約: 表格的擁有者與消費者都要在所有權表" {
  sed -i 's/^| login API | backend |/| login API | nobody |/' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL 共用契約 login API: 擁有者 nobody 不在檔案所有權表"* ]]
  fixture_brief "$d"; sed -i 's/frontend-cart, qa/frontend-cart, ghost/' "$b"
  run dk-brief-check; [ "$status" -eq 1 ]; [[ "$output" == *"消費者 ghost 不在檔案所有權表"* ]]
}
@test "共用契約: 只有表頭是合法的「無契約」，自由文字只警告" {
  sed -i '/^| login API |/d' "$b"            # 只留表頭
  run dk-brief-check; [ "$status" -eq 0 ]; [ "$output" = OK ]
  fixture_brief "$d"
  sed -i '/^| 契約 | 擁有者 |/d; /^|---|---|---|---|---|$/d; /^| login API |/d' "$b"
  sed -i 's/^## 共用契約$/## 共用契約\n無/' "$b"
  run dk-brief-check; [ "$status" -eq 0 ]; [[ "$output" == *"WARN 共用契約"* ]]
}
```

- [ ] **Step 2: 跑它確認失敗**

Run: `tests/run.sh tests/unit/16_brief_check.bats`
Expected: FAIL，第一條的 exit code 是 0（目前沒有這道閘）

- [ ] **Step 3: 換掉共用契約的檢查**

把 `.dkbo/bin/dk-brief-check` 裡這一行：

```bash
[ -n "$(dk_brief_section "$brief" "## 共用契約" | grep -v '^（' | grep -v '^[[:space:]]*$' || true)" ] || fail 共用契約 "段落為空（無契約請寫「無」）"
```

換成：

```bash
ct=$(dk_brief_section "$brief" "## 共用契約")
if [ -z "$(printf '%s\n' "$ct" | grep -v '^（' | grep -v '^[[:space:]]*$' || true)" ]; then
  fail 共用契約 "段落為空（無契約請保留表頭；舊格式請寫「無」）"
elif ! printf '%s\n' "$ct" | grep -qE '^\| *契約 *\|'; then
  # 判別器是表頭而不是資料列：新格式底下「沒有任何契約」就是只有表頭、沒有資料列，
  # 那是合法的。拿資料列當判別器會把這個合法狀態誤判成舊 brief，它從此拿不到欄位檢查。
  warn 共用契約 "非表格格式（0.9.0 之後建立的任務請用 契約｜擁有者｜消費者｜形狀／簽名｜變更流程 五欄）"
else
  while IFS='|' read -r c owner consumers _shape _flow; do
    [ -n "$c" ] || continue
    [ "$owner" = "—" ] || [[ "$members" == *" $owner "* ]] || fail "共用契約 $c" "擁有者 $owner 不在檔案所有權表"
    for cs in $(printf '%s' "$consumers" | tr ',' ' '); do
      [ "$cs" = "—" ] || [[ "$members" == *" $cs "* ]] || fail "共用契約 $c" "消費者 $cs 不在檔案所有權表"
    done
  done <<< "$(dk_brief_interfaces "$brief")"
fi
```

- [ ] **Step 4: 跑測試確認通過**

Run: `tests/run.sh tests/unit/16_brief_check.bats`
Expected: PASS

- [ ] **Step 5: shellcheck 與全套**

Run: `shellcheck .dkbo/bin/dk-brief-check && tests/run.sh`
Expected: shellcheck 無輸出、bats 全綠

---

### Task 5: 全域約束流進三份切片

**Files:**
- Modify: `.dkbo/bin/dk-wave-open`（`goal=`／`contract=`／`acc=` 那一行與 `dk_render` 呼叫）
- Modify: `.dkbo/bin/dk-review`（`dk_render` 呼叫前後）
- Modify: `.dkbo/bin/dk-brief-review`（`dk_render` 呼叫前後）
- Modify: `.dkbo/templates/brief-member.md`
- Modify: `.dkbo/templates/brief-reviewer.md`
- Modify: `.dkbo/templates/brief-reviewer-plan.md`
- Test: `tests/unit/29_constraints.bats`（新檔）

**Interfaces:**
- Consumes: `dk_brief_constraints BRIEF`（Task 1）、`dk_render TEMPLATE K=V…`（既有）
- Produces: 三份切片模板新增 `{{CONSTRAINTS}}` token

- [ ] **Step 1: 寫失敗的測試**

新檔 `tests/unit/29_constraints.bats`：

```bash
load ../helpers
setup() { setup_project; d=$(fixture_task login 使用者登入); fixture_brief "$d"; }
teardown() { teardown_project; }

@test "全域約束進成員切片" {
  run dk-wave-open 1; [ "$status" -eq 0 ]
  grep -q '^## 全域約束（全文）$' "$d/briefs/backend.md"
  grep -q 'bash 3.2+' "$d/briefs/backend.md"
  grep -q 'bash 3.2+' "$d/briefs/qa.md"
}
@test "全域約束進波審查切片" {
  dk-wave-open 1 >/dev/null; mkdir -p "$d/waves"; echo diff > "$d/waves/1.diff"
  run dk-review 1; [ "$status" -eq 0 ]
  grep -q 'bash 3.2+' "$d/briefs/reviewer-a.md"
}
@test "全域約束進計畫審查切片" {
  printf '把登入做出來\n（原文從這裡開始）\n人的原話在這裡\n' > "$d/request.md"
  run dk-brief-review; [ "$status" -eq 0 ]
  grep -q 'bash 3.2+' "$d/briefs/reviewer-p1.md"
}
```

- [ ] **Step 2: 跑它確認失敗**

Run: `tests/run.sh tests/unit/29_constraints.bats`
Expected: 三條全 FAIL，切片裡找不到 `bash 3.2+`

- [ ] **Step 3: 成員切片**

`.dkbo/bin/dk-wave-open`，把

```bash
goal=$(dk_brief_section "$brief" "## 目標"); contract=$(dk_brief_section "$brief" "## 共用契約"); acc=$(dk_brief_section "$brief" "## 驗收標準")
```

改成

```bash
goal=$(dk_brief_section "$brief" "## 目標"); contract=$(dk_brief_section "$brief" "## 共用契約"); acc=$(dk_brief_section "$brief" "## 驗收標準")
constraints=$(dk_brief_constraints "$brief")
```

並在同檔的 `dk_render` 呼叫裡，`"GOAL=$goal"` 之後加一個參數：

```bash
    "CONSTRAINTS=$constraints" \
```

`.dkbo/templates/brief-member.md`，在 `## 目標` 段之後插入：

```markdown
## 全域約束（全文）
{{CONSTRAINTS}}
```

- [ ] **Step 4: 波審查切片**

`.dkbo/bin/dk-review`，在 `members=$(...)` 那一行之後加：

```bash
constraints=$(dk_brief_constraints "$dir/brief.md")
```

並在 `dk_render` 呼叫的 `"MEMBERS=$members"` 之後加 `"CONSTRAINTS=$constraints"`。

`.dkbo/templates/brief-reviewer.md`，在 `## 要讀的` 那一段之後插入：

```markdown
## 全域約束（全文，逐條當硬要求檢查）
{{CONSTRAINTS}}
```

- [ ] **Step 5: 計畫審查切片**

`.dkbo/bin/dk-brief-review`，在 `aliases=$(...)` 那一行之後加：

```bash
constraints=$(dk_brief_constraints "$dir/brief.md")
```

並在 `dk_render` 呼叫的 `"BRIEF=$dir/brief.md"` 之後加 `"CONSTRAINTS=$constraints"`。

`.dkbo/templates/brief-reviewer-plan.md`，在 `## 要讀的（就這兩份，依序）` 那一段之後插入：

```markdown
## 全域約束（全文）
{{CONSTRAINTS}}
```

- [ ] **Step 6: 跑測試確認通過**

Run: `tests/run.sh tests/unit/29_constraints.bats`
Expected: PASS

- [ ] **Step 7: 全套與 shellcheck**

Run: `shellcheck .dkbo/bin/dk-wave-open .dkbo/bin/dk-review .dkbo/bin/dk-brief-review && tests/run.sh`
Expected: shellcheck 無輸出、bats 全綠。`15_brief_lib.bats` 有一條在檢查 `brief-member.md` 的 token 清單，`CONSTRAINTS` 要一併加進那個 `for t in …` 列表。

---

### Task 6: report 的 `### 紅`／`### 綠` 與 `dk-wave-close` 的 gate b

**Files:**
- Modify: `.dkbo/templates/report-employee.md`
- Modify: `.dkbo/bin/dk-wave-close`（gate b 的 awk）
- Modify: `tests/unit/08_wave_close.bats`（setup 的 fixture report 會壞）
- Test: `tests/unit/08_wave_close.bats`

**Interfaces:**
- Consumes: `.panes` 的欄位順序 `agent pane epoch group tab slot`（既有）
- Produces: 無新函式；gate b 的判定條件改變

- [ ] **Step 1: 寫失敗的測試**

`tests/unit/08_wave_close.bats` 的 setup 裡，把 fixture report 那一行

```bash
  printf '# backend 報告\n## 做了什麼\nlogin\n## 測試\nnpm test → 3 passed\n## 自我審查\n## 疑慮\n' > "$d/state/backend.report.md"
```

改成

```bash
  printf '# backend 報告\n## 做了什麼\nlogin\n## 測試\n### 紅\n$ npm test -- login\nFAIL login not defined\n### 綠\n$ npm test -- login\n3 passed\n## 自我審查\n## 疑慮\n' > "$d/state/backend.report.md"
```

並加測試：

```bash
@test "gate b: 缺 ### 紅 或 ### 綠 都不放行，不適用可以過" {
  # 錯誤訊息同時提到兩個小節名，所以不能拿訊息裡有沒有「### 紅」來分辨是哪一邊缺 ——
  # 斷言改成「這份 report 被擋下來了」，並用 refute_grep 確認沒有其他 gate 一起叫。
  printf '# backend 報告\n## 測試\n### 綠\n3 passed\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 1 ]
  [[ "$output" == *"state/backend.report.md 的 '## 測試' 缺"* ]]
  refute_grep 'unowned change' <<< "$output"
  printf '# backend 報告\n## 測試\n### 紅\nFAIL\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 1 ]
  [[ "$output" == *"state/backend.report.md 的 '## 測試' 缺"* ]]
  # 兩節都在、但各只有一行（沒有輸出）：這正是 AC5 要擋的
  printf '# backend 報告\n## 測試\n### 紅\n跑過了會失敗\n### 綠\n跑過了會過\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 1 ]
  [[ "$output" == *"兩行以上"* ]]
  # 指令列＋輸出：放行
  printf '# backend 報告\n## 測試\n### 紅\n$ npm test -- login\nFAIL not defined\n### 綠\n$ npm test -- login\n3 passed\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 0 ]
}
@test "gate b: 不適用 是單行豁免" {
  printf '# backend 報告\n## 測試\n### 紅\n不適用: 純文件波\n### 綠\n不適用: 純文件波\n' > "$d/state/backend.report.md"
  run dk-wave-close; [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: 跑它確認失敗**

Run: `tests/run.sh tests/unit/08_wave_close.bats`
Expected: FAIL，缺小節的兩條拿到 exit 0（目前只驗 `## 測試` 非空）

- [ ] **Step 3: 升級 gate b**

把 `.dkbo/bin/dk-wave-close` 的

```bash
    elif ! awk '/^## 測試/{t=1; next} t && /^## /{exit} t && /^[^[:space:]（]/{ok=1} END{exit !ok}' "$rf"; then
      problems="$problems\n  report $rf lacks content under '## 測試'"
```

換成

```bash
    elif ! awk '
      /^## 測試/{t=1; next}
      t && /^## /{exit}
      t && /^### 紅/{s="r"; next}
      t && /^### 綠/{s="g"; next}
      t && s!="" && /^[^[:space:]（]/{
        n[s]++
        if (n[s]==1 && $0 ~ /^不適用:/) ok[s]=1   # 沒有測試的波：首行就是豁免宣告
        if (n[s]>=2) ok[s]=1                      # 指令列＋輸出，至少兩行
      }
      END{exit !(ok["r"] && ok["g"])}' "$rf"; then
      problems="$problems\n  report $rf 的 '## 測試' 缺證據：'### 紅' 與 '### 綠' 各要指令列與輸出兩行以上（沒有測試的波首行寫「不適用: <理由>」）"
```

為什麼是「兩行」而不是比對 `$` 開頭的指令列：人的裁定要的是「命令列與輸出」，而要求字面上的
`$` 前綴等於規定員工怎麼貼終端機內容，換個 shell 或換個貼法就誤擋。「至少兩行」抓得到同一件事
（一行指令、一行輸出），又不綁死格式。`不適用: <理由>` 只有一行，所以要一條明確的豁免分支 ——
它不能像「非空即算數」那樣被順便接住。

- [ ] **Step 4: 改範本**

把 `.dkbo/templates/report-employee.md` 的

```markdown
## 測試
（必填：跑了什麼指令、結果摘要；沒有這段 dk-wave-close 不放行）
```

換成

```markdown
## 測試
### 紅
（先寫的那條測試：跑它的指令一行、失敗輸出一行，至少兩行。沒有測試的波首行寫「不適用: <理由>」）
### 綠
（實作之後同一條指令一行、通過輸出一行，至少兩行。沒有測試的波首行寫「不適用: <理由>」）
```

- [ ] **Step 5: 跑測試確認通過**

Run: `tests/run.sh tests/unit/08_wave_close.bats`
Expected: PASS

- [ ] **Step 6: 全套與 shellcheck**

Run: `shellcheck .dkbo/bin/dk-wave-close && tests/run.sh`
Expected: shellcheck 無輸出、bats 全綠。gate b 只掃 `group: dev` 的成員，qa 與 reviewer 的 report 格式不受影響 —— 若有 qa 的 report fixture 紅了，表示改錯了迴圈條件。

---

### Task 7: `methods/debugging.md` 與 PROTOCOL 的指路

**Files:**
- Create: `.dkbo/methods/debugging.md`
- Modify: `.dkbo/PROTOCOL.md`（`## 類型` 表的 BUG 列、FIXED 列）
- Modify: `.dkbo/roles/backend.md`、`.dkbo/roles/frontend.md`、`.dkbo/roles/it.md`、`.dkbo/roles/qa.md`（各加一行，給新專案）
- Test: `tests/unit/30_methods.bats`（新檔）

**Interfaces:**
- Consumes: `$DK_ROOT` 環境變數（員工 pane 上指向主工作樹的 `.dkbo/`）
- Produces: `$DK_ROOT/methods/debugging.md` 這個路徑，Task 8 的首輪提示會指向它

- [ ] **Step 1: 寫失敗的測試**

新檔 `tests/unit/30_methods.bats`：

```bash
load ../helpers
setup() { setup_project; }
teardown() { teardown_project; }

@test "除錯方法檔存在，PROTOCOL 指得到它" {
  [ -f "$DK_ROOT/methods/debugging.md" ]
  grep -q 'methods/debugging.md' "$DK_ROOT/PROTOCOL.md"
}
@test "PROTOCOL 的 FIXED 列要求附根因（AC16）" {
  grep -qE '^\| FIXED \|.*根因' "$DK_ROOT/PROTOCOL.md"
}
@test "方法檔講方法不講次數上限" {
  grep -q '重現' "$DK_ROOT/methods/debugging.md"
  grep -q '根因' "$DK_ROOT/methods/debugging.md"
  refute_grep '上限一次' "$DK_ROOT/methods/debugging.md"
}
```

- [ ] **Step 2: 跑它確認失敗**

Run: `tests/run.sh tests/unit/30_methods.bats`
Expected: FAIL，`methods/debugging.md` 不存在

- [ ] **Step 3: 寫方法檔**

新檔 `.dkbo/methods/debugging.md`：

```markdown
# 除錯方法

收到 `[BUG]`、或自己的測試紅了，先讀這一篇再動手。這裡講的是方法；一次修不好要怎麼辦寫在
`PROTOCOL.md` 的「規則」段。

## 一、先重現，再修
沒有一個能穩定重現的最小指令之前，不要改任何一行程式。重現指令寫進你的 report 的
`## 測試` 的 `### 紅`。改完之後要跑的就是它 —— 「改了所以應該好了」不是證據。

## 二、沿著錯誤往回找第一個說謊的地方
從症狀出現的那一行往上游走，在每一層問：這一層拿到的輸入對不對？第一個「輸入是對的、
輸出是錯的」的地方就是根因。在那之前的每一層都只是把錯誤搬運下去，改它們只會把症狀挪位置。

## 三、一次只改一件事
同時改兩個地方而症狀消失，你不知道是哪一個修好的，也不知道另一個是不是新的洞。改一件、
跑一次、記一行。

## 四、二分法縮範圍
範圍大到看不出來時，把它切一半：註解掉一半的輸入、退回一半的 commit、拿掉一半的設定。
兩三次就能把範圍縮到可以直接讀懂的大小。

## 五、寫下你排除了什麼
每排除一個假設就記一行到自己的 report 的 `## 自我審查`：試過什麼、看到什麼、所以排除了什麼。
這份清單有兩個用途 —— 你自己不會繞回去重試，接手的人也不用從頭來過。

## 六、修好的定義
原本那條重現指令現在通過，而且你能用一句話說出根因。兩者缺一就還沒修好，
`[FIXED]` 的內文要帶著那一句根因。說不出根因就表示你只是讓症狀消失了。
```

- [ ] **Step 4: PROTOCOL 指路**

把 `.dkbo/PROTOCOL.md` 的 BUG 那一列

```
| BUG | 員工→員工、領導→dev（reviewer 的 Important 由領導轉） | 附重現方式，指向 state 或 report |
```

換成

```
| BUG | 員工→員工、領導→dev（reviewer 的 Important 由領導轉） | 附重現方式，指向 state 或 report。收到 BUG 先讀 `$DK_ROOT/methods/debugging.md` 再動手 |
```

並把 FIXED 那一列

```
| FIXED | 員工→員工、dev→領導 | 修好了，請重驗。領導轉來的 `[BUG]`（reviewer 的 Important）修好後也回這個，不要回 `[DONE]` —— 領導要靠它決定何時重打差異包請 reviewer 複看 |
```

換成

```
| FIXED | 員工→員工、dev→領導 | 修好了，請重驗，**內文帶一句根因**。領導轉來的 `[BUG]`（reviewer 的 Important）修好後也回這個，不要回 `[DONE]` —— 領導要靠它決定何時重打差異包請 reviewer 複看 |
```

- [ ] **Step 5: 角色檔骨架**

在 `.dkbo/roles/backend.md`、`frontend.md`、`it.md`、`qa.md` 的 `## 職責` 段各加一行：

```markdown
碰到 bug 先讀 `$DK_ROOT/methods/debugging.md`，照它走完再動手。
```

這一行只對新專案生效 —— 升級對 `roles/` 是 `--ignore-existing`。真正會生效的載體是 Task 8 的首輪提示。

- [ ] **Step 6: 跑測試確認通過**

Run: `tests/run.sh tests/unit/30_methods.bats && tests/run.sh`
Expected: 全綠

---

### Task 8: 首輪提示帶 TDD 順序與除錯指路

**Files:**
- Modify: `.dkbo/lib/prompt.sh`（`dk_first_prompt` 的 `printf` 字串）
- Test: `tests/unit/07_spawn.bats`

**Interfaces:**
- Consumes: `$DK_ROOT/methods/debugging.md`（Task 7）、`report-employee.md` 的 `### 紅`／`### 綠`（Task 6）
- Produces: 首輪提示字串多兩句；`dk_first_prompt` 的參數順序不變

- [ ] **Step 1: 寫失敗的測試**

在 `tests/unit/07_spawn.bats` 加：

```bash
@test "首輪提示帶 TDD 順序與除錯方法檔" {
  dk-wave-open 1 >/dev/null
  run dk-spawn backend; [ "$status" -eq 0 ]
  grep -q '先寫一條會失敗的測試' "$HERDR_STUB_LOG"
  grep -q 'methods/debugging.md' "$HERDR_STUB_LOG"
}
```

- [ ] **Step 2: 跑它確認失敗**

Run: `tests/run.sh tests/unit/07_spawn.bats`
Expected: FAIL，stub log 裡沒有那兩段字

- [ ] **Step 3: 改提示**

在 `.dkbo/lib/prompt.sh` 的 `printf` 字串裡，把

```
讀完後建立 state 檔並開始做分給你的項目；
```

換成

```
讀完後建立 state 檔並開始做分給你的項目。寫程式的順序是：先寫一條會失敗的測試、跑它確認真的失敗、再寫最小實作讓它過；兩次的指令與輸出分別貼進報告的「### 紅」與「### 綠」（沒有測試的波兩節都寫「不適用: <理由>」）。碰到 bug 或測試紅了，先讀 $DK_ROOT/methods/debugging.md 再動手。
```

- [ ] **Step 4: 跑測試確認通過**

Run: `tests/run.sh tests/unit/07_spawn.bats`
Expected: PASS

- [ ] **Step 5: 全套與 shellcheck**

Run: `shellcheck .dkbo/lib/prompt.sh && tests/run.sh`
Expected: shellcheck 無輸出、bats 全綠

---

### Task 9: `dk-spawn --handoff "<原因>"`

**Files:**
- Modify: `.dkbo/bin/dk-spawn`（旗標解析、resume 區塊之後）
- Modify: `.dkbo/lib/prompt.sh`（`dk_first_prompt` 新增第 9 個參數 `HANDOFF`）
- Test: `tests/unit/07_spawn.bats`

**Interfaces:**
- Consumes: `dk_process "…"`（既有，寫一行進 process.md）
- Produces: `dk_first_prompt AGENT ROLE TASK_DIR STATE_FILE RESUME BRIEF_FILE REPORT_FILE UPSTREAM HANDOFF` —— 第 9 個位置參數是接手原因，空字串表示不是接手

- [ ] **Step 1: 寫失敗的測試**

```bash
@test "--handoff 落 ruling、隱含 resume、用接手版提示" {
  dk-wave-open 1 >/dev/null
  dk-spawn backend >/dev/null
  run dk-spawn backend --handoff "claude 修一次沒好，換 codex" --kind codex
  [ "$status" -eq 0 ]
  grep -qE '^[^ ]+ ruling: 換 codex/M 接手 login-backend 的修復 — claude 修一次沒好，換 codex — ' "$d/process.md"
  grep -q '上一位修過一次沒成功' "$HERDR_STUB_LOG"
  grep -q 'methods/debugging.md' "$HERDR_STUB_LOG"
}
@test "--handoff 不帶原因就死" {
  dk-wave-open 1 >/dev/null
  run dk-spawn backend --handoff; [ "$status" -ne 0 ]; [[ "$output" == *"--handoff"* ]]
}
```

- [ ] **Step 2: 跑它確認失敗**

Run: `tests/run.sh tests/unit/07_spawn.bats`
Expected: FAIL，`unknown flag --handoff`

- [ ] **Step 3: 加旗標**

`.dkbo/bin/dk-spawn` 的變數初始化那一行，把

```bash
alias=""; tier=M; kind=""; isolated=0; resume=0; notes=""; split_override=""
```

換成

```bash
alias=""; tier=M; kind=""; isolated=0; resume=0; notes=""; split_override=""; handoff=""
```

在旗標 `case` 裡，`--resume` 那一支之後加：

```bash
  --handoff) handoff="${2:-}"; [ -n "$handoff" ] || dk_die "--handoff 要帶原因：dk-spawn <role> [alias] --handoff \"<為什麼換人>\""
             resume=1; notes="$notes handoff"; shift 2;;
```

- [ ] **Step 4: 落 ruling**

在 `.dkbo/bin/dk-spawn` 的 `if [ "$resume" = 1 ]; then … fi` 區塊**之後**、`env_args=(` 之前插入：

```bash
# 換腦袋這一步一定有 ruling，是結構保證不是事後驗：理由由呼叫端給，格式由腳本補完。
# 事後驗要認「同一個 bug 的第二輪」這種事件序列，是既有閘門沒做過的形狀，容易誤判。
[ -z "$handoff" ] || dk_process "ruling: 換 $kind/$tier 接手 $agent 的修復 — $handoff — 若換人也修不好，下一輪就是 ESCALATE，代價是多一輪 pane"
```

- [ ] **Step 5: 接手版提示**

`.dkbo/lib/prompt.sh` 的 `dk_first_prompt`，把第一行的 resume 判斷

```bash
  local resume=""; [ "${5:-0}" = 1 ] && resume="你是重新啟動的員工：先讀 $4，從 state 檔續作，不要重做已完成的項目。"
```

換成

```bash
  local resume=""; [ "${5:-0}" = 1 ] && resume="你是重新啟動的員工：先讀 $4，從 state 檔續作，不要重做已完成的項目。"
  # 接手與續作是兩件事：續作的人要接著往下做，接手的人要重做，只是不能重走死路。
  [ -z "${9:-}" ] || resume="你是接手的員工（換人原因：${9}）。上一位修過一次沒成功 —— 先讀 $4 與 $7，看它試過什麼、排除了什麼，再讀 \$DK_ROOT/methods/debugging.md，然後自己重新判斷根因。不要照著它的路再走一次。"
```

並在 `.dkbo/bin/dk-spawn` 的 `herdr agent prompt` 呼叫裡，把

```bash
"$(dk_first_prompt "$agent" "$role" "$dir" "$state" "$resume" "$brief_for" "$report" "$upstream")"
```

換成

```bash
"$(dk_first_prompt "$agent" "$role" "$dir" "$state" "$resume" "$brief_for" "$report" "$upstream" "$handoff")"
```

- [ ] **Step 6: 跑測試確認通過**

Run: `tests/run.sh tests/unit/07_spawn.bats`
Expected: PASS

- [ ] **Step 7: 全套與 shellcheck**

Run: `shellcheck .dkbo/bin/dk-spawn .dkbo/lib/prompt.sh && tests/run.sh`
Expected: shellcheck 無輸出、bats 全綠

---

### Task 10: Minor 匯總進整枝評議切片

**Files:**
- Modify: `.dkbo/bin/dk-review`（`--task` 分支）
- Modify: `.dkbo/templates/brief-reviewer.md`
- Test: `tests/unit/20_review.bats`

**Interfaces:**
- Consumes: `process.md` 裡格式為 `<時間> minor N: <一行>` 的列（由領導用 `dk-process` 寫）
- Produces: `brief-reviewer.md` 新增 `{{MINORS}}` token

- [ ] **Step 1: 寫失敗的測試**

```bash
@test "整枝評議帶累積的 Minor，逐波審查不帶" {
  open_wave 1
  echo "2026-09-19T10:00 minor 1: 變數命名不一致 src/a.sh:12" >> "$d/process.md"
  run dk-review 1; [ "$status" -eq 0 ]
  grep -q '逐波審查不 triage' "$d/briefs/reviewer-a.md"
  refute_grep '變數命名不一致' "$d/briefs/reviewer-a.md"
  dk-wave-close --force >/dev/null 2>&1 || true
  mkdir -p "$d/waves"; echo diff > "$d/waves/task.diff"
  run dk-review --task; [ "$status" -eq 0 ]
  grep -q '變數命名不一致' "$d/briefs/reviewer-a.md"
}
```

- [ ] **Step 2: 跑它確認失敗**

Run: `tests/run.sh tests/unit/20_review.bats`
Expected: FAIL，切片裡沒有那兩段字

- [ ] **Step 3: 算 Minor 清單**

`.dkbo/bin/dk-review`，在 `constraints=$(dk_brief_constraints "$dir/brief.md")` 那一行（Task 5 加的）之後插入：

```bash
if [ "$task" = 1 ]; then   # 整枝評議才 triage：一條風格意見不該在每一波都被重讀一次
  minors=$(grep -E '^[^ ]+ minor: |^[^ ]+ minor [0-9]+: ' "$dir/process.md" 2>/dev/null | sed 's/^[^ ]* /- /' || true)
  [ -n "$minors" ] || minors="（本任務沒有累積的 Minor）"
else
  minors="（逐波審查不 triage 累積的 Minor；整枝評議才做）"
fi
```

並在 `dk_render` 呼叫裡加 `"MINORS=$minors"`。

- [ ] **Step 4: 模板加段落**

`.dkbo/templates/brief-reviewer.md`，在 `## 報告寫到 {{REPORT}}，格式固定` 之前插入：

```markdown
## 本任務累積的 Minor
{{MINORS}}

上面每一條是先前各波放掉的風格／可讀性意見。逐條判：哪些**必須**在 merge 前修掉、
哪些可以留著。判定寫進報告的 `## Minor` 段開頭，一條一行。
```

- [ ] **Step 5: 跑測試確認通過**

Run: `tests/run.sh tests/unit/20_review.bats`
Expected: PASS

- [ ] **Step 6: 全套與 shellcheck**

Run: `shellcheck .dkbo/bin/dk-review && tests/run.sh`
Expected: shellcheck 無輸出、bats 全綠

---

### Task 11: `dk-task-close` 的 Minor 軟警告與結案範本

**Files:**
- Modify: `.dkbo/bin/dk-task-close`（gate 3 檢查之後）
- Modify: `.dkbo/templates/report.md`
- Test: `tests/unit/12_task_close.bats`

**Interfaces:**
- Consumes: `process.md` 的 `minor` 列（Task 10 同一個格式）、`$dir/report.md`
- Produces: 只有 stderr 上的一行警告；**不改 exit code**

- [ ] **Step 1: 寫失敗的測試**

```bash
@test "有 minor 但 report 沒提到只警告，不擋結案" {
  echo "2026-09-19T10:00 minor 1: 命名不一致" >> "$d/process.md"
  printf '# x 結案\n## 完成\n做完了\n' > "$d/report.md"
  run dk-task-close; [ "$status" -eq 0 ]; [[ "$output" == *"minor"* ]]
}
```

- [ ] **Step 2: 跑它確認失敗**

Run: `tests/run.sh tests/unit/12_task_close.bats`
Expected: FAIL，輸出裡沒有 `minor`

- [ ] **Step 3: 加軟警告**

`.dkbo/bin/dk-task-close`，在

```bash
if [ "$abandon" = 0 ]; then [ -f "$dir/report.md" ] || { echo "dk-task-close: write $dir/report.md first (gate 3)"; exit 1; }; fi
```

之後插入：

```bash
# 軟警告，不擋：一條風格意見不該卡住結案（同 dk-wave-close 的 unreported change）。
if [ "$abandon" = 0 ] && grep -qE '^[^ ]+ minor' "$dir/process.md" 2>/dev/null; then
  mn=$(grep -cE '^[^ ]+ minor' "$dir/process.md")
  grep -qi 'minor' "$dir/report.md" \
    || echo "dk-task-close: process.md 有 $mn 條 minor，但 report.md 沒提到 —— 整枝評議 triage 過的話，把沒修的寫進「未完成 / 遺留」段" >&2
fi
```

- [ ] **Step 4: 結案範本提示**

把 `.dkbo/templates/report.md` 的

```markdown
## 未完成 / 遺留
```

換成

```markdown
## 未完成 / 遺留
（未經審查的波；整枝評議 triage 後決定不修的 Minor，一條一行）
```

- [ ] **Step 5: 跑測試確認通過**

Run: `tests/run.sh tests/unit/12_task_close.bats`
Expected: PASS

- [ ] **Step 6: 全套與 shellcheck**

Run: `shellcheck .dkbo/bin/dk-task-close && tests/run.sh`
Expected: shellcheck 無輸出、bats 全綠

---

### Task 12: 修復迴圈改成兩輪（PROTOCOL 與 run SKILL）

**Files:**
- Modify: `.dkbo/PROTOCOL.md`（`## 規則` 段的修復迴圈那一條）
- Modify: `.dkbo/skills/run/SKILL.md`（第 4 步與「故障」段）
- Test: `tests/unit/04_docs.bats`

**Interfaces:**
- Consumes: `dk-spawn --handoff`（Task 9）
- Produces: 無程式介面；這是規範層

- [ ] **Step 1: 寫失敗的測試**

在 `tests/unit/04_docs.bats` 加：

```bash
@test "修復迴圈是兩輪，PROTOCOL 與 run SKILL 一致" {
  grep -q 'handoff' "$DK_ROOT/PROTOCOL.md"
  grep -q 'handoff' "$DK_ROOT/skills/run/SKILL.md"
  refute_grep '修復迴圈上限一次' "$DK_ROOT/PROTOCOL.md"
}
```

- [ ] **Step 2: 跑它確認失敗**

Run: `tests/run.sh tests/unit/04_docs.bats`
Expected: FAIL，兩份文件都沒有 `handoff`

- [ ] **Step 3: 改 PROTOCOL**

把 `.dkbo/PROTOCOL.md` 的

```
- 修復迴圈上限一次，以同一個 bug 計：BUG → FIXED → 再驗仍失敗 → qa（或領導）直接 ESCALATE，不再回 dev。
```

換成

```
- 修復迴圈上限兩輪，以同一個 bug 計：BUG → FIXED → 再驗仍失敗 → **領導換一個腦袋**（`dk-spawn <角色> <別名> --handoff "<原因>"`，換 kind 或升檔位；腳本自己落 ruling）→ 再驗仍失敗 → qa（或領導）ESCALATE，不再回 dev。同一個人再試一次跟換一個腦袋試一次不是同一件事，第二輪要換人。
```

- [ ] **Step 4: 改 run SKILL**

在 `.dkbo/skills/run/SKILL.md` 的第 4 步，把

```
同一 bug 一次修復上限照 PROTOCOL。
```

換成

```
同一 bug 兩輪上限照 PROTOCOL：第一輪回原 dev，再驗仍失敗就 `dk-spawn <角色> <別名> --handoff "<原因>"` 換 kind（挑沒進 `DK_KIND_DOWN` 的）或升 `--tier L`，第三次才升關卡②。`--handoff` 會自己把 ruling 寫進 process.md，你不用另外記。
```

並在「故障」段加一條：

```
- 同一個 bug 修兩次都沒好：不要再派第三個人。`dk-msg <qa> "[TASK] 暫停重驗"`，然後把兩位的 report 與 reviewer 的原始意見一起交給人（關卡②）。第三次還是同一個洞，多半表示 brief 的驗收標準本身有歧義，那是人要裁定的事。
```

- [ ] **Step 5: 跑測試確認通過**

Run: `tests/run.sh tests/unit/04_docs.bats && tests/run.sh`
Expected: 全綠

---

### Task 13: 0.9.0 收尾（VERSION、CHANGELOG、README）

**Files:**
- Modify: `.dkbo/VERSION`
- Modify: `CHANGELOG.md`
- Modify: `README.md`、`README.en.md`、`.dkbo/README.md`（版本字串共 8 處）
- Test: `tests/unit/21_version.bats`

**Interfaces:**
- Consumes: 前 12 個 task 的全部成果
- Produces: 可發布的 0.9.0

- [ ] **Step 1: 跑版本測試確認它現在是綠的**

Run: `tests/run.sh tests/unit/21_version.bats`
Expected: PASS（動手前的基準線；0.8.1 目前是一致的）

- [ ] **Step 2: 改 VERSION**

```bash
echo 0.9.0 > .dkbo/VERSION
```

- [ ] **Step 3: 跑版本測試確認它紅了**

Run: `tests/run.sh tests/unit/21_version.bats`
Expected: FAIL，`CHANGELOG top is '0.8.1' but .dkbo/VERSION is '0.9.0'`，以及三份 README 的版本字串不符

- [ ] **Step 4: 改三份 README 的版本字串**

```bash
sed -i 's/0\.8\.1/0.9.0/g' README.md README.en.md .dkbo/README.md
```

改完確認剛好 8 處：

```bash
grep -c '0\.9\.0' README.md README.en.md .dkbo/README.md
```

- [ ] **Step 5: 寫 CHANGELOG**

在 `CHANGELOG.md` 的 `# Changelog` 之後插入一節 `## 0.9.0 — <今天日期>`，內容涵蓋六個缺口各一條，並寫明這兩件事：

- `dk-brief-check` 對 0.9.0 之後建立的 brief 多兩道 FAIL（全域約束為空、共用契約表格的擁有者／消費者不在所有權表）；**進行中的舊任務只拿到 WARN**，判別器是段落與表頭存不存在。
- `## 測試` 分成 `### 紅`／`### 綠`，`dk-wave-close` 的 gate b 跟著升級；沒有測試的波兩節都寫「不適用: <理由>」。

- [ ] **Step 6: 跑全套**

Run: `tests/run.sh && shellcheck .dkbo/bin/* .dkbo/lib/*.sh`
Expected: bats 全綠、shellcheck 無輸出

---

## 波次對應

| 波 | Task | 對應驗收標準 |
|---|---|---|
| 1 | 1–5 | AC1–AC4、AC15 |
| 2 | 6–8 | AC5–AC8、AC16 |
| 3 | 9–13 | AC9–AC14 |

`dk-wave-close` 會在每一波結束時於 worktree 內自己 commit，所以計畫裡沒有逐 task 的 commit 步驟 ——
這是 dkbo 與 superpowers 的模型差異，不是漏寫。員工在波內不要自己 `git commit`。
