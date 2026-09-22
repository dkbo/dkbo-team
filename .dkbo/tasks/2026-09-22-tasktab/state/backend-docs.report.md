# backend-docs 報告（波 4）

## 做了什麼
- `tests/integration/README.md:202,206` 兩處「在人所在的 workspace 裡開新 tab」「DK_WORKSPACE 從此固定是人所在的 workspace」改成「任務所屬的 workspace（`.task.env` 的 `DK_WORKSPACE`，計畫時記下，空時退回 `HERDR_WORKSPACE_ID`）」，跟波 3 CHANGELOG 修的措辭一致。
- `tests/unit/25_docs_policy.bats:39` 的 Important4 斷言根因修法：把硬編的六檔清單 `for f in README.md README.en.md .dkbo/README.md CHANGELOG.md .dkbo/LEADER.md .dkbo/PROJECT.md` 改成 `while IFS= read -r f; do ... done < <(git -C "$REPO_ROOT" ls-files)`，逐一 `refute_grep` 舊講法；排除 `.dkbo/tasks/*`（歷史任務記憶與 waves diff 是原文紀錄，不該改也不該擋）與 `tests/unit/25_docs_policy.bats` 自己（斷言字串會自我命中）。原本檢查那六個具名檔存在「任務所屬的 workspace」字樣的斷言（`grep -q '任務所屬的 workspace' ...`）不變。

## 測試
### 紅
- 指令：`sed -i` 把 `tests/integration/README.md:202` 暫時改回舊講法「人所在的 workspace 裡開新 tab」，跑 `./tests/run.sh tests/unit/25_docs_policy.bats`
- 輸出：`not ok 5 Important4: DK_WORKSPACE 講成任務所屬，不再講成人所在的那一刻` / `refute_grep: 不該命中卻命中了: ... /home/bal/project/teamflow/.worktrees/tasktab/tests/integration/README.md`（掃 `git ls-files` 的新斷言抓到了原本六檔清單漏掉的 `tests/integration/README.md`）

### 綠
- 指令：把 `tests/integration/README.md:202` 改回正確措辭後，跑 `./tests/run.sh tests/unit/25_docs_policy.bats`
- 輸出：`1..5` 全部 `ok`（含 `ok 5 Important4: ...`）
- 指令：`./tests/run.sh tests/unit/21_version.bats tests/unit/25_docs_policy.bats tests/unit/04_docs.bats`
- 輸出：`1..21` 全部 `ok`
- 指令：`./tests/run.sh`
- 輸出：`ok 548 init skill 問 DK_REPOS 與每個 repo 的 DK_SETUP_CMD，pnpm 給預填寫法` / `[exited with code 0]`，548 條全過
- 指令：`shellcheck .dkbo/bin/* .dkbo/lib/*.sh .dkbo/kinds/*.sh`
- 輸出：無輸出（零警告）
- 新斷言掃了幾個檔：`git -C "$REPO_ROOT" ls-files` 在本倉回傳的追蹤檔總數（排除 `.dkbo/tasks/**` 與自己後逐一檢查），非固定六檔。

## 自我審查
- 只改了所有權表劃給 backend-docs 的兩個檔（`tests/integration/README.md`、`tests/unit/25_docs_policy.bats`），`git status --porcelain` 確認無越界改動。
- 兩處文件字樣與 `.task.env` 共用契約（`DK_TASK_TAB` 那列，`backend-ws` 擁有）描述的 `DK_WORKSPACE` 語意一致，未動共用契約本身。
- 沒有新增依賴、沒有動 `.dkbo/bin/**`（唯讀）。

## 疑慮
- 無。
