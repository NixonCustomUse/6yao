# 歷史紀錄與自動新卦 — 設計文件

日期：2026-09-08
狀態：已與使用者確認設計方向（方案 B）

## 目標

為六爻排盤新增兩個關聯功能：

1. **歷史紀錄**：每次起卦自動存檔，可瀏覽、還原完整排盤、單筆刪除與清空
2. **自動新卦**：已有一卦時，點「擲銅錢」或「起卦」直接開始新的一卦，無需手動「重新起卦」

兩端（Web `index.html` 與 iOS `SwiftUI`）行為一致，維持「文人書齋 · 宣紙朱砂」視覺與零依賴原則。

## 現況問題

| 問題 | 說明 |
|---|---|
| 無歷史 | 起卦後刷新頁面或重起一卦，舊結果即消失，無法回溯對照 |
| 需手動重置 | Web `tossBtn` 在 `lines.length >= 6` 時直接 `return`；iOS `startCasting()` `guard lines.count < 6`；使用者必須先按「重新起卦」才能再擲，與「點了就開新」的直覺不符 |
| 已有書籤彈窗可復用 | 現有 `bmkOverlay` / `BookmarkOverlay` 的 overlay + 卡面樣式可直接復用於歷史抽屜 |

## 需求（已確認）

- **C. 清單精簡 + 完整還原**：列表顯示 `日期 · 卦名→變卦 · 分級 · 用神標籤`，點整列還原完整排盤（含本卦/變卦、六親/六神/旬空/世應/解讀）
- **C. 折衷呈現**：底部常駐「歷史 · 最近 3 筆」+ 右上角「史」印章入口，點「查看全部」彈出可滾動抽屜
- **A. 自動存檔直接重來**：若已有結果，點新卦前先自動 `pushHistory(lastCast)`，再清空並開始；`casting` 期間仍禁用避免重入
- **雙端皆做**：Web 用 `localStorage`，iOS 用 `UserDefaults`，皆本地儲存無後端
- **上限 50 筆**：新卦 `unshift` 到最前，超過截斷最舊
- **用神一起存**：歷史需還原當時的 `yongshen` 選擇與 `dayIdx/dayGan/dayZhi/ganzhiText/dateISO`

## 1. 架構總覽

```
HistoryStore (封裝)
  ├─ load(): HistoryRecord[]
  ├─ save(list)
  ├─ push(record)  // 去重 + 上限 50 + 排序
  ├─ remove(id)
  └─ clear()

Web:  historyStore 物件 + localStorage key "6yao:history:v1"
iOS:  HistoryStore.swift + AppModel.history: [HistoryRecord] + UserDefaults key "6yao.history.v1"
      AppModel 透過 HistoryStore 間接讀寫，不直接碰 UserDefaults
```

自動新卦解鎖：

- Web：`tossBtn` 移除 `if (lines.length >=6) return`，改為 `if (lastCast) pushHistory(); lines=[]; casting=true; ...`
- Web：`castBtn` 同理先 `pushHistory` 再 `renderResult`
- iOS：`AppModel.startCasting()` 移除 `lines.count < 6` guard，改為 `if (result != nil) pushHistory()` 再清空；`castNumbers` 同理

## 2. 資料模型

### HistoryRecord（雙端共用欄位）

| 欄位 | 型別 | 說明 |
|---|---|---|
| `id` | string | `Date.now` + random，唯一鍵 |
| `ts` | number (ms) | 建立時間，用於排序 |
| `dateISO` | string | `YYYY-MM-DD`，還原占日 |
| `ganzhiText` | string | 完整干支顯示文字 |
| `yongshen` | string | `"" / "妻財" / "官鬼" / ... / "世爻"` |
| `hgKey` | string | 本卦 key，如 `"11"` |
| `changedKey` | string\|null | 變卦 key |
| `hgName` | string | 本卦名，如 `"乾為天"` |
| `changedName` | string\|null | 變卦名 |
| `moving` | number[] | 動爻索引 0-5 |
| `movingSymbols` | Record<int,string> | `{"0":"○","3":"×"}` |
| `bits` | number[] | 6 位 0/1 用於精準還原 |
| `dayIdx` | number | 0-59，日柱索引，用於旬空/六神/分級 |
| `dayGan` | string | 日干 |
| `dayZhi` | string | 日支 |
| `lines` | CoinToss[]\|null | 搖錢才有，供還原爻線 |
| `source` | `"coins"` \| `"numbers"` | 來源 |
| `inputs` | `{a,b,c}`\|null | 報數才有 |

Web 以 `JSON.stringify` 存； iOS 以 `Codable` 存。舊格式 `load` 時 `try/catch` 失敗則回 `[]`。

上限 50：`push` 時 `list.unshift(record); if (list.length>50) list= list.slice(0,50)`。

## 3. Web 設計（`index.html` 單檔內增量）

### 新增元素

- `header` 右側加 `button#historyBtn`：樣式復用 `.seal-mini`（印章「史」），`data-note="歷史紀錄"`，固定在標題旁
- `section#historyCard`（位於 `baihuaBox` 之後）：`.card` 內
  - 標題 `seal-tag`「史」+「歷史 · 最近 3 筆」+ 右側「查看全部 →」文字按鈕
  - `div#historyPreviewBox` 列表（最近 3 筆）
  - 空狀態 `div.history-empty`：「歷史尚無記錄。起一卦後會自動存檔。」
- `div#historyOverlay` 抽屜（結構復用 `bmkOverlay`）：
  - `div.history-pop > div.history-sheet`
  - 頂部 `歷史紀錄（N）` + 關閉按鈕
  - `div#historyListBox` 可滾動列表（`max-height: 72vh`）
  - 底部 `清空全部` 按鈕（`mini-btn` 危險樣式）

### 單筆呈現

每筆 `.history-item`：

```
[左] 2026-09-08 · 乾為天 → 風地觀 · 妻財
[右] 上上 徽章 + × 刪除
```

- 整列 `cursor: pointer`，點擊還原
- 右側 `×` 需 `e.stopPropagation()` 避免觸發還原
- 分級徽章復用 `.bmk-grade` 縮小版

### JS 模組

```js
const HISTORY_KEY = "6yao:history:v1";
const HISTORY_LIMIT = 50;
const historyStore = {
  load(), save(list), push(record), remove(id), clear()
};
function buildRecordFromCast(c, movingSymbols, source, inputs) -> HistoryRecord
function renderHistoryPreview() // 最近 3
function renderHistoryList()    // 全部
function openHistory() / closeHistory()
function restoreHistory(id)     // 寫回 lines/result/lastCast/dayIdx/ganzhi/yongshen 並 render
```

`renderResult` 完成後不立即存歷史；自動新卦觸發時才 `push(lastCast)`，避免重複存同一卦多次。

樣式新增於獨立 `<style id="history-style">` 區塊，沿用 `--paper/--line/--cinnabar`，不新增色票。

## 4. iOS 設計（`ios/Sources/`）

### 新增檔案

- `Sources/HistoryStore.swift`：`HistoryRecord: Codable, Identifiable, Equatable` + `HistoryStore`（load/save/push/remove/clear，UserDefaults key `6yao.history.v1`）
- `Sources/Views/HistoryViews.swift`：`HistoryPreview` + `HistorySheet` + `HistoryRow`

### 修改檔案

- `AppModel.swift`：新增 `@Published var history: [HistoryRecord]`，init 時 `history = HistoryStore.load()`；新增 `pushHistory()`, `removeHistory(id)`, `clearHistory()`, `restore(record)`；`startCasting()` 與 `castNumbers()` 開頭先 `if result != nil { pushHistory() }` 再清空
- `ContentView.swift`：`header` 右側加「史」按鈕；`ScrollView` 底部加 `HistoryPreview`；`.sheet(isPresented: $showHistory)` 呈 `HistorySheet`
- `Views/CastViews.swift`：`Button` 的 `.disabled(model.casting)` 移除 `lines.count >=6` 條件
- `Theme.swift`：無需新增顏色（復用現有）

### 互動

- `HistoryRow` 點整列 `model.restore(record)` 並 `showHistory = false`
- 支援 `swipeActions` 刪除單筆；`HistorySheet` 底部 `清空全部` 帶確認 `alert`
- 空狀態同 Web 文案

## 5. 行為與錯誤處理

| 情境 | 處理 |
|---|---|
| `localStorage` / `UserDefaults` 解析失敗 | `try/catch` 回 `[]`，不中斷主流程 |
| `QuotaExceededError`（Web） | 捕獲後丟棄最舊 10 筆重試一次，仍失敗則靜默忽略本次 push |
| 單筆 `JSON.stringify` 過大 | 預檢 `JSON.stringify(list).length > 4MB` 則先裁至 40 筆 |
| 舊格式還原失敗 | `restore` 時 `guard let hg = data.hexagramTable[record.hgKey]` 否則移除該筆並提示 |
| 空歷史 | 顯示空狀態文案，不顯示「查看全部」/「清空全部」 |
| 連點保護 | `casting == true` 時 `tossBtn` / `startCasting` 禁用，`history` 相關按鈕不受影響 |

## 範圍外（YAGNI）

- 不做 IndexedDB / SwiftData、不做搜尋與篩選
- 不做匯出/匯入 JSON/CSV
- 不做跨裝置同步（無後端）
- 不做歷史搜尋、標籤、備註編輯
- Web 不做深色模式新色（沿用現有）

## 測試與驗收

### Web 手動驗收

1. 起一卦 → 重新整理 → 歷史仍有 1 筆
2. 已滿 6 爻後再點「擲銅錢」→ 直接重擲且舊卦出現在歷史第 1 筆（日期/卦名/分級正確）
3. 報數起卦覆蓋同樣自動存檔
4. 點歷史任意筆 → 排盤/解讀/用神/干支完整還原
5. 單筆刪除與清空全部生效且持久化
6. 連續起 51 卦 → 歷史保持 50 筆，最舊被淘汰

### iOS

- `swiftc -o /tmp/6yao-test Sources/Models.swift Sources/Engine.swift Sources/HistoryStore.swift Tests/main.swift && /tmp/6yao-test`
- 新增 4 項測試：上限裁切 50、序列化往返、還原後分級一致、用神還原
- 手動同 Web 六步

### 驗收標準

- 「點算卦直接開新卦」無需手動重置，舊卦不丟失
- 歷史點回可完整還原且與當時顯示一致

## 實作位置

- Web：`/Users/nx/Documents/6yao/index.html`（新增 history 區塊、overlay、style、JS store；解鎖 toss/cast 邏輯）
- iOS：
  - 新增 `ios/Sources/HistoryStore.swift`
  - 新增 `ios/Sources/Views/HistoryViews.swift`
  - 修改 `ios/Sources/AppModel.swift`
  - 修改 `ios/Sources/Views/ContentView.swift`
  - 修改 `ios/Sources/Views/CastViews.swift`

## 風險

- `index.html` 已 1232 行，單檔持續膨脹；本次嚴守增量在獨立區塊，不重構全檔
- `localStorage` 同步寫入在極端 50 筆時仍 < 50KB，無效能風險
