# tests/fixtures

`dk-timeline` 的來源樣本。都是**真實跑過的 process.md**，不是手編的假資料 —— 時間表這種
東西只要 token 的形狀對不上就靜默算錯，用真 log 才擋得住。

| 檔 | 來源 | 人手算出的數字 |
|---|---|---|
| `highfix-process.md` | `.dkbo/tasks/2026-09-19-highfix/process.md` 原樣複製 | 任務 66m、計畫 6m、波 1 27m（dev 19m、審查 7m）、波 2 16m（dev 1m、審查 3m）、結案 6m |
| `flowgap-process.md` | `.dkbo/tasks/2026-09-19-flowgap/process.md` 原樣複製 | 任務 279m、計畫 15m、波 1 148m（dev 22m、審查 125m）、波 2 16m（dev 1m、審查 4m）、波 3 21m（dev 0m、審查 5m）、波 4 23m（dev 0m、審查 6m）、結案 42m |
| `crossday-process.md` | **手改**：highfix 的每個時間戳整批 +3 小時 | 跨日樣本（20:39 → 23:39，結案落在隔天 00:45）。時長與 highfix 逐欄相同，差別只在日期進位 |

`crossday-process.md` 的存在理由：`dk_ts_minutes` 不准用 `date -d`／`date -j`／`mktime`，
曆法是自己算的，而「只在同一天內對」的實作在單日樣本上完全看不出來。波 2–4 的 dev 分鐘偏小
是當時假聚合留下的，dk-timeline 忠實反映 log 即可，不要「修正」樣本。
