---
name: dkboai-init
description: 第一次在專案啟用 dkboai 時執行。偵測已安裝的 AI CLI、選主模型與第二三意見工具、改寫角色檔的 kind 與三檔、預填 PROJECT.md、檢查 MCP 需求。
---
# dkboai init

逐步做，每步用 AskUserQuestion 或等人回答，一次問一題。

0. 前置檢查：`git status --porcelain .dkboai AGENTS.md CLAUDE.md .claude .agents`。有輸出就停下，請人先 commit（員工的 worktree 只看得到已 commit 的檔案）。
1. 偵測工具：執行 `bash -c '. .dkboai/lib/common.sh; . .dkboai/lib/kinds.sh; dk_kinds_available'`。對每個結果檢查登入狀態：`claude --version`、`codex login status`、`agy models | head -1`。列出可用者。
2. 問主模型：預設 claude。若人選其他 kind，對 `.dkboai/roles/*.md` 每一檔：把 `kind:` 改成該 kind，並用 `.dkboai/kinds/<kind>.sh` 的 `KIND_DEFAULT_TIERS` 覆寫 `tiers:` 三檔（reviewer 沒有 S）。逐角色列出改後的值讓人確認或修改。同步更新 `.dkboai/roles/README.md` 的表。
3. 問第二、第三意見工具：只列可用且非主模型者。把結果寫進 `.dkboai/LEADER.md` 的「評議波」段落，替換範例中的 `--kind codex` / `--kind agy`。沒裝的不列。
4. 預填 `.dkboai/PROJECT.md`：先讀既有的 `CLAUDE.md`、`AGENTS.md`、`.claude/rules/*.md`（若存在），從中抽技術棧、測試指令、慣例；再看 package.json / pyproject.toml / go.mod / Cargo.toml / Makefile 補齊。保持 ≤40 行，不重複既有指令檔已寫的規則，只寫事實。給人確認後存檔。
4b. 衝突掃描：比對既有指令檔與 `.dkboai/PROTOCOL.md`、`.dkboai/LEADER.md` 會打架的規則，至少查這幾類：要求使用 subagent 或平行 agent、要求直接 commit/push 到 main、禁止建分支或 worktree、要求每次改動都問人。逐條列出「既有規則 vs dkboai 規則」，讓人決定改哪一邊。不自動修改既有檔案。
5. MCP 檢查：對每個已選 kind 執行 `bash -c '. .dkboai/lib/common.sh; . .dkboai/lib/kinds.sh; dk_kind_load <kind>; kind_mcp_list'`，比對所有角色檔 `mcp:` 清單。缺的列出，並印出對應指令範本（`claude mcp add <name> -- <cmd>` / `codex mcp add <name> -- <cmd>` / `agy mcp add <name> <cmd>`）讓人自己執行。不要代寫含認證的設定。
6. 結束時列出：可用工具、主模型、評議成員、PROJECT.md 行數、缺少的 MCP。
