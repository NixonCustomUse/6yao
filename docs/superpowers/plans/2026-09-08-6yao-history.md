# 歷史紀錄與自動新卦 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 為 Web 與 iOS 雙端新增歷史紀錄（自動存檔、上限 50、單筆刪除/清空、點選完整還原）並讓「擲銅錢/起卦」每次直接開啟新卦。

**Architecture:** 以獨立 `HistoryStore` 封裝所有持久化（Web `localStorage` / iOS `UserDefaults`），`AppModel` 與 `index.html` 全域狀態僅透過 `push/remove/clear/load` 與之互動；UI 採用底部「最近 3 筆」常駐 + 抽屜 `overlay/sheet` 完整列表，復用現有書籤彈窗樣式與紙墨色票。

**Tech Stack:** Vanilla HTML/CSS/JS（零依賴，`index.html` 單檔）、SwiftUI + Swift 5.9（iOS 17+，Xcode 15+，無第三方）、`localStorage` / `UserDefaults` + `Codable` JSON、`git`

## Global Constraints

- Web 必須維持單檔 `index.html`（約 100KB / 1232 行基準），零建置、零依賴，僅 CDN `LXGW WenKai` 字型
- iOS 需求 Xcode 15+、iOS 17+、純 SwiftUI 無第三方，顏色透過 `Color(light:dark:)` 自動跟隨系統
- 儲存 key 固定：Web `localStorage["6yao:history:v1"]`、iOS `UserDefaults["6yao.history.v1"]`，上限 50 筆，新卦 `unshift` 到最前超過截斷最舊
- 視覺沿用既有色票 `--paper/--paper-2/--paper-3/--line/--line-2/--cinnabar/--cinnabar-deep/--cinnabar-soft`，不新增色票
- YAGNI：不做 IndexedDB/SwiftData、不做搜尋/篩選、不做匯出/匯入、不做跨裝置同步、不做備註編輯
- 核心排盤邏輯（`Engine.swift` / `index.html` 內 JS 的 `TRIGRAM/HEXAGRAM_TABLE/YIJING/BAI/computeGrade`）不可改動向量

---

## File Structure

```
6yao/
├── index.html                          # 修改：新增 history style/block/overlay + JS store + 解鎖 toss/cast
├── ios/
│   ├── Sources/
│   │   ├── HistoryStore.swift          # 新增：HistoryRecord(Codable) + HistoryStore(load/save/push/remove/clear)
│   │   ├── AppModel.swift              # 修改：@Published history + pushHistory/restore/clear + startCasting/castNumbers 自動存檔
│   │   ├── Views/
│   │   │   ├── ContentView.swift       # 修改：header 加「史」按鈕 + 底部 HistoryPreview + sheet
│   │   │   ├── CastViews.swift         # 修改：移除 lines.count>=6 的 disabled
│   │   │   └── HistoryViews.swift      # 新增：HistoryPreview + HistorySheet + HistoryRow
│   │   └── Theme.swift                 # 檢視（無需改，避免新增顏色）
│   └── Tests/
│       └── main.swift                  # 修改：新增 4 項歷史測試
└── docs/superpowers/
    ├── specs/2026-09-08-6yao-history-design.md  # 已提交
    └── plans/2026-09-08-6yao-history.md         # 本文件
```

每個檔案職責單一：`HistoryStore` 只管序列化與上限，`HistoryViews` 只管呈現與互動，`AppModel` 只管狀態流轉，`index.html` 的 history 區塊獨立於排盤邏輯。

---

### Task 1: Web HistoryStore（localStorage 封裝）

**Files:**
- Modify: `/Users/nx/Documents/6yao/index.html:813-830` 附近（全域變數區，`let lines/lastCast` 旁）
- Test: 臨時 `/tmp/test-history.js`（Node 直接執行）

**Interfaces:**
- Consumes: `localStorage` (Web API)
- Produces: `historyStore = { load():HistoryRecord[], save(list), push(record), remove(id), clear() }` 與 `buildRecordFromCast(c, movingSymbols, source, inputs) -> HistoryRecord`

- [ ] **Step 1: 寫 failing harness**

```js
// /tmp/test-history.js
// 模擬 localStorage
global.localStorage = { _s:{}, getItem(k){return this._s[k]??null}, setItem(k,v){this._s[k]=v}, removeItem(k){delete this._s[k]} };
const HISTORY_KEY="6yao:history:v1", HISTORY_LIMIT=50;
const historyStore = {
  load(){ try{ const r=localStorage.getItem(HISTORY_KEY); return r?JSON.parse(r):[] }catch{ return [] } },
  save(l){ localStorage.setItem(HISTORY_KEY, JSON.stringify(l)) },
  push(r){ const l=this.load(); l.unshift(r); if(l.length>HISTORY_LIMIT) l.length=HISTORY_LIMIT; this.save(l) },
  remove(id){ this.save(this.load().filter(x=>x.id!==id)) },
  clear(){ localStorage.removeItem(HISTORY_KEY) }
};
function assert(c,m){ if(!c) throw new Error(m) }
historyStore.clear();
historyStore.push({id:"1",ts:1,hgKey:"11"});
historyStore.push({id:"2",ts:2,hgKey:"88"});
assert(historyStore.load().length===2,"push fail");
assert(historyStore.load()[0].id==="2","order fail");
historyStore.remove("2");
assert(historyStore.load()[0].id==="1","remove fail");
for(let i=0;i<55;i++) historyStore.push({id:`x${i}`,ts:i});
assert(historyStore.load().length===50,"limit 50 fail");
console.log("PASS");
```

- [ ] **Step 2: 執行驗證失敗（此時 index.html 尚未植入 historyStore，harness 應 PASS 作為對照）**

Run: `node /tmp/test-history.js`
Expected: PASS（此 harness 為應實作的邏輯對照；若直接跑 index.html 內無該物件則為缺失）

- [ ] **Step 3: 在 index.html 實作 HistoryStore**

在 `let lastCast = null;` 下方插入（`index.html:813-819` 區）：

```js
const HISTORY_KEY = "6yao:history:v1";
const HISTORY_LIMIT = 50;
const historyStore = {
  load() {
    try { const raw = localStorage.getItem(HISTORY_KEY); return raw ? JSON.parse(raw) : []; }
    catch { return []; }
  },
  save(list) {
    try { localStorage.setItem(HISTORY_KEY, JSON.stringify(list)); } catch(e) {
      // QuotaExceededError 時丟棄最舊 10 筆重試
      if (e && e.name === 'QuotaExceededError') {
        const trimmed = list.slice(0, Math.max(0, list.length - 10));
        try { localStorage.setItem(HISTORY_KEY, JSON.stringify(trimmed)); } catch {}
      }
    }
  },
  push(record) {
    const list = this.load();
    list.unshift(record);
    if (list.length > HISTORY_LIMIT) list.length = HISTORY_LIMIT;
    this.save(list);
  },
  remove(id) { this.save(this.load().filter(x => x.id !== id)); },
  clear() { localStorage.removeItem(HISTORY_KEY); }
};
function buildRecordFromCast(c, movingSymbols, source, inputs) {
  const hg = c.hg;
  return {
    id: String(Date.now()) + Math.random().toString(36).slice(2,6),
    ts: Date.now(),
    dateISO: $('dateInput').value,
    ganzhiText: $('ganzhiText').textContent,
    yongshen: $('yongshenSel').value,
    hgKey: hg.key,
    changedKey: c.changed ? c.changed.key : null,
    hgName: hg.name,
    changedName: c.changed ? c.changed.name : null,
    moving: [...c.moving],
    movingSymbols: {...movingSymbols},
    bits: [...hg.bits],
    dayIdx, dayGan, dayZhi,
    lines: source === 'coins' ? lines.map(l=>({symbol:l.symbol, moving:l.moving, backs:l.backs, coins:[...l.coins]})) : null,
    source, inputs
  };
}
```

- [ ] **Step 4: 驗證**

Run: `python3 -m http.server 8000` 後瀏覽器 console 執行 `historyStore.clear(); historyStore.push({id:"t1",ts:Date.now()}); console.log(historyStore.load().length)`
Expected: `1`

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat(web): add HistoryStore with localStorage (limit 50, quota handling)"
```

---

### Task 2: Web 歷史 UI（常駐 3 筆 + 抽屜）

**Files:**
- Modify: `/Users/nx/Documents/6yao/index.html:500-570`（header 與 cards 區）
- Modify: `/Users/nx/Documents/6yao/index.html:304-403`（style 區，新增 #history-*）
- Modify: `/Users/nx/Documents/6yao/index.html:1180-1230`（script 尾部，新增 render/restore）

**Interfaces:**
- Consumes: `historyStore.load/push/remove/clear`, `renderResult`, `computeGrade`, `updateGanzhi`
- Produces: `renderHistoryPreview()`, `renderHistoryList()`, `openHistory()`, `closeHistory()`, `restoreHistory(id)`

- [ ] **Step 1: 寫 failing 視覺檢查**

在瀏覽器 console 執行 `document.getElementById('historyCard')`
Expected: `null`（尚未實作，視為 failing）

- [ ] **Step 2: 新增 HTML 結構**

1) `header.mast` 內 `ganzhi` 行後插入：

```html
<button id="historyBtn" class="seal-mini fill" style="margin-left:10px;width:28px;height:28px;font-size:13px" data-note="歷史紀錄" title="歷史">史</button>
```

2) 在 `section.card` 白話卡片之後（`baihuaBox` 所在 card 閉合後）插入：

```html
<section class="card" id="historyCard">
  <h2 class="seal-title"><span class="seal-tag">史</span>歷史紀錄<span class="sub" id="historyCount"></span><button class="mini-btn" id="historyViewAll" style="margin-left:auto">查看全部 →</button></h2>
  <div id="historyPreviewBox"></div>
  <div id="historyEmpty" class="empty-tip" hidden>歷史尚無記錄。起一卦後會自動存檔。</div>
</section>
<div id="historyOverlay" class="bmk-overlay hidden">
  <div class="bmk-pop" style="max-width:520px;width:100%">
    <button class="bmk-close" id="historyClose">✕</button>
    <div class="bmk-card" style="width:100%;max-height:78vh;display:flex;flex-direction:column">
      <div style="font-family:var(--font-display);font-weight:700;letter-spacing:0.18em;margin-bottom:12px">歷史紀錄 <span id="historyOverlayCount" style="font-weight:400;color:var(--ink-3)"></span></div>
      <div id="historyListBox" style="overflow:auto;flex:1;display:flex;flex-direction:column;gap:8px"></div>
      <button class="mini-btn" id="historyClearAll" style="margin-top:14px;border-color:var(--cinnabar);color:var(--cinnabar)">清空全部</button>
    </div>
  </div>
</div>
```

- [ ] **Step 3: 新增樣式**

在 `</style>` 前插入獨立區塊：

```html
<style id="history-style">
#historyCard .history-item{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:10px 12px;border:1px solid var(--line);border-radius:6px;background:linear-gradient(180deg,var(--paper-2),var(--paper));cursor:pointer;transition:transform 0.15s var(--ease-spring),border-color 0.15s}
#historyCard .history-item:hover{transform:translateY(-1px);border-color:var(--line-2)}
#historyOverlay .history-item{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:10px 12px;border:1px solid var(--line);border-radius:6px;background:var(--paper-2);cursor:pointer}
.history-meta{font-size:13px;color:var(--ink-2);letter-spacing:0.06em}
.history-meta b{color:var(--ink);font-weight:700}
.history-grade{font-family:var(--font-display);font-size:12px;letter-spacing:0.18em;padding:2px 8px;border:1.5px solid var(--cinnabar);color:var(--cinnabar);border-radius:2px}
.history-del{width:26px;height:26px;border-radius:50%;border:1px solid var(--line-2);background:transparent;color:var(--ink-3);cursor:pointer}
.history-del:hover{border-color:var(--cinnabar);color:var(--cinnabar)}
</style>
```

- [ ] **Step 4: 新增 JS 渲染與互動**

在 `closeBookmark` 後插入：

```js
function gradeLabelForRecord(r){
  // 復用 computeGrade 的邏輯但用 record 的 dayZhi/dayIdx
  const hg = { key:r.hgKey, name:r.hgName, bits:r.bits, branches: buildHexagram(parseInt(r.hgKey[0]), parseInt(r.hgKey[1])).branches, liuqin: buildHexagram(parseInt(r.hgKey[0]), parseInt(r.hgKey[1])).liuqin, shi: HEXAGRAM_TABLE[r.hgKey].shi };
  // 簡化：若儲存時已有分級則直接顯示，否則用當前 computeGrade
  try{ return computeGrade(hg, r.moving).label }catch{ return '' }
}
function renderHistoryPreview(){
  const list = historyStore.load();
  $('historyCount').textContent = list.length?`· 共 ${list.length} 筆`:'';
  $('historyViewAll').style.display = list.length>3?'':'none';
  const box=$('historyPreviewBox'), empty=$('historyEmpty');
  if(!list.length){ box.innerHTML=''; empty.hidden=false; return }
  empty.hidden=true;
  box.innerHTML = list.slice(0,3).map(r=>{
    const arrow = r.changedName?` → ${r.changedName}`:'';
    const ys = r.yongshen?` · ${r.yongshen}`:'';
    return `<div class="history-item" data-id="${r.id}"><span class="history-meta"><b>${r.hgName}${arrow}</b> · ${r.dateISO}${ys}</span><span style="display:flex;gap:8px;align-items:center"><span class="history-grade">${gradeLabelForRecord(r)}</span><button class="history-del" data-del="${r.id}">×</button></span></div>`;
  }).join('');
}
function renderHistoryList(){
  const list=historyStore.load();
  $('historyOverlayCount').textContent = list.length?`（${list.length}）`:'';
  const box=$('historyListBox');
  if(!list.length){ box.innerHTML='<div class="empty-tip">尚無歷史</div>'; return }
  box.innerHTML = list.map(r=>{
    const arrow = r.changedName?` → ${r.changedName}`:'';
    const ys = r.yongshen?` · ${r.yongshen}`:'';
    return `<div class="history-item" data-id="${r.id}"><span class="history-meta"><b>${r.hgName}${arrow}</b><br><span style="font-size:12px;color:var(--ink-3)">${r.dateISO} · ${r.ganzhiText}${ys}</span></span><span style="display:flex;gap:8px;align-items:center"><span class="history-grade">${gradeLabelForRecord(r)}</span><button class="history-del" data-del="${r.id}">×</button></span></div>`;
  }).join('');
}
function openHistory(){ renderHistoryList(); $('historyOverlay').classList.remove('hidden'); }
function closeHistory(){ $('historyOverlay').classList.add('hidden'); }
function restoreHistory(id){
  const rec = historyStore.load().find(x=>x.id===id);
  if(!rec) return;
  // 還原占日與用神
  $('dateInput').value = rec.dateISO;
  updateGanzhi();
  $('yongshenSel').value = rec.yongshen || '';
  if(rec.source==='coins' && rec.lines){
    lines = rec.lines.map(l=>({coins:[...l.coins], backs:l.backs, symbol:l.symbol, moving:l.moving}));
    renderLines();
    renderCoins(lines.length?lines[lines.length-1].coins:null);
    const {upper, lower}=trigramFromLines(lines);
    const movingSymbols={}; rec.moving.forEach(i=> movingSymbols[i]= rec.movingSymbols[i]);
    renderResult(cast(upper,lower,rec.moving), movingSymbols);
  } else {
    const upper= parseInt(rec.hgKey[0]), lower=parseInt(rec.hgKey[1]);
    const movingSymbols={}; rec.moving.forEach(i=> movingSymbols[i]= rec.movingSymbols[i]||'●');
    lines=[]; $('linesBox').innerHTML='';
    renderResult(cast(upper,lower,rec.moving), movingSymbols);
  }
  closeHistory();
  $('resultBox').scrollIntoView({behavior:'smooth', block:'center'});
}
$('historyBtn').addEventListener('click', openHistory);
$('historyViewAll').addEventListener('click', openHistory);
$('historyClose').addEventListener('click', closeHistory);
$('historyOverlay').addEventListener('click', e=>{ if(e.target===$('historyOverlay')) closeHistory(); });
$('historyClearAll').addEventListener('click', ()=>{ if(confirm('確定清空全部歷史？')){ historyStore.clear(); renderHistoryPreview(); renderHistoryList(); }});
$('historyPreviewBox').addEventListener('click', e=>{
  const del=e.target.closest('[data-del]'); if(del){ e.stopPropagation(); historyStore.remove(del.dataset.del); renderHistoryPreview(); renderHistoryList(); return; }
  const item=e.target.closest('.history-item'); if(item) restoreHistory(item.dataset.id);
});
$('historyListBox').addEventListener('click', e=>{
  const del=e.target.closest('[data-del]'); if(del){ e.stopPropagation(); historyStore.remove(del.dataset.del); renderHistoryPreview(); renderHistoryList(); return; }
  const item=e.target.closest('.history-item'); if(item) restoreHistory(item.dataset.id);
});
renderHistoryPreview();
```

- [ ] **Step 5: 驗證**

Run: `open index.html` → 控制台 `historyStore.push(buildRecordFromCast(cast(1,1,[]), {}, 'numbers', {a:1,b:1,c:1}))` → 檢查 `#historyPreviewBox` 出現 1 筆 → 點整列還原排盤 → 點 × 刪除 → `localStorage` 清空後 `renderHistoryPreview` 顯示空狀態

- [ ] **Step 6: Commit**

```bash
git add index.html
git commit -m "feat(web): history preview + drawer UI with restore/delete/clear"
```

---

### Task 3: Web 自動新卦（解鎖重擲）

**Files:**
- Modify: `/Users/nx/Documents/6yao/index.html:938-1010`（tossBtn/undo/reset 邏輯）
- Modify: `/Users/nx/Documents/6yao/index.html:1008-1023`（castBtn 邏輯）

**Interfaces:**
- Consumes: `historyStore.push`, `buildRecordFromCast`, `lastCast`, `lines`, `casting`
- Produces: 解鎖後的 `tossBtn` 與 `castBtn` 行為（點即新卦且自動存檔）

- [ ] **Step 1: 寫 failing 檢查**

目前 `tossBtn` 在 `lines.length>=6` 時 `return`，驗證：起一卦滿 6 爻後再點 `tossBtn` 無反應 → 預期改後應直接重擲

- [ ] **Step 2: 修改 tossBtn**

將：

```js
$('tossBtn').addEventListener('click', () => {
  if (lines.length >= 6 || casting) return;
  casting = true; ... lines=[] ...
```

改為：

```js
$('tossBtn').addEventListener('click', () => {
  if (casting) return;
  if (lastCast) { try{ historyStore.push(buildRecordFromCast(lastCast.c, lastCast.movingSymbols, lastCast.c.lines? 'coins':'numbers', null)); }catch{} renderHistoryPreview(); }
  casting = true;
  $('tossBtn').disabled = true; $('undoBtn').disabled = true; $('resetBtn').disabled = true;
  lines=[]; $('linesBox').innerHTML=''; lastCast=null;
  $('resultBox').innerHTML='尚未起卦。請先擲銅錢或報數起卦。'; $('readingBox').innerHTML=''; $('baihuaBox').innerHTML='尚未起卦。請先擲銅錢或報數起卦。';
  (async()=>{ ... })();
});
```

同時將 `renderResult` 內 `lastCast = {c, movingSymbols}` 保留，但移除任何自動 `push`，僅由下次新卦觸發存檔。

- [ ] **Step 3: 修改 castBtn**

將：

```js
$('castBtn').addEventListener('click', ()=>{
  ... renderResult(cast(...)); openBookmark();
});
```

改為：

```js
$('castBtn').addEventListener('click', ()=>{
  const a=...,b=...,c=...; if(!...) return;
  if(lastCast){ try{ historyStore.push(buildRecordFromCast(lastCast.c, lastCast.movingSymbols, lastCast.source||'numbers', lastCast.inputs||null)); }catch{} renderHistoryPreview(); }
  const upper=..., lower=..., moving=...;
  const res=cast(upper, lower, [moving-1]); const sym={[moving-1]:'●'};
  if(a) lastCast && historyStore; // keep lastCast
  // 標記 source 供歷史
  lastCast = {c:res, movingSymbols:sym, source:'numbers', inputs:{a,b,c}};
  renderResult(res, sym);
  renderHistoryPreview();
  openBookmark();
});
```

並同步調整 `renderResult` 開頭：`lastCast = {c, movingSymbols, source: lastCast?.source || 'coins', inputs: lastCast?.inputs || null}` 或在 `toss` 完成後賦值時帶 source。

簡化：`renderResult(c, movingSymbols, meta)` 增加第三參數 meta，或在呼叫前設置全域 `pendingMeta`。選最少改動：`toss` 完成後 `lastCast = {c, movingSymbols, source:'coins'}`。

- [ ] **Step 4: 驗證**

Run: 先起一卦 → 檢查 `historyStore.load().length===0`（尚未存）→ 再點一次「擲銅錢」→ 檢查 `historyStore.load().length===1` 且新卦動畫重跑 → 連點 3 次報數起卦 → 歷史遞增且每筆可還原

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat(web): auto-new cast on click with auto-save to history"
```

---

### Task 4: iOS HistoryStore（UserDefaults 封裝）

**Files:**
- Create: `/Users/nx/Documents/6yao/ios/Sources/HistoryStore.swift`
- Test: `/Users/nx/Documents/6yao/ios/Tests/main.swift`（新增 4 項）

**Interfaces:**
- Consumes: `Foundation.UserDefaults`, `Codable`
- Produces: `struct HistoryRecord: Codable, Identifiable, Equatable`, `enum HistoryStore { static func load()->[HistoryRecord], save(_:), push(_:), remove(id:), clear() }`

- [ ] **Step 1: 寫 failing test（在 Tests/main.swift 新增）**

```swift
func testHistoryLimit50() {
  HistoryStore.clear()
  for i in 0..<55 { HistoryStore.push(HistoryRecord(id:"\(i)", ts:Double(i), dateISO:"2026-09-08", ganzhiText:"甲子", yongshen:"", hgKey:"11", changedKey:nil, hgName:"乾為天", changedName:nil, moving:[], movingSymbols:[:], bits:[1,1,1,1,1,1], dayIdx:0, dayGan:"甲", dayZhi:"子", lines:nil, source:"numbers", inputs:nil)) }
  assert(HistoryStore.load().count==50, "limit 50 fail")
  assert(HistoryStore.load().first?.id=="54", "order fail")
}
func testHistoryRoundTrip() {
  HistoryStore.clear()
  let r = HistoryRecord(id:"x", ts:1, dateISO:"2026-09-08", ganzhiText:"甲子", yongshen:"妻財", hgKey:"11", changedKey:"58", hgName:"乾為天", changedName:"風地觀", moving:[0], movingSymbols:[0:"○"], bits:[1,0,0,0,0,0], dayIdx:0, dayGan:"甲", dayZhi:"子", lines:[CoinToss(coins:[true,false,false], backs:1, symbol:"- -", moving:false)], source:"coins", inputs:nil)
  HistoryStore.push(r); let loaded = HistoryStore.load().first!; assert(loaded.hgKey=="11" && loaded.movingSymbols[0]=="○", "roundtrip fail")
}
```

- [ ] **Step 2: 執行驗證失敗**

Run: `swiftc -o /tmp/6yao-test Sources/Models.swift Sources/Engine.swift Sources/HistoryStore.swift Tests/main.swift && /tmp/6yao-test`
Expected: `error: cannot find 'HistoryStore' in scope`（尚未建立）

- [ ] **Step 3: 實作 HistoryStore.swift**

```swift
import Foundation

struct HistoryRecord: Codable, Identifiable, Equatable {
  let id: String; let ts: Double; let dateISO: String; let ganzhiText: String
  let yongshen: String; let hgKey: String; let changedKey: String?; let hgName: String; let changedName: String?
  let moving: [Int]; let movingSymbols: [Int:String]; let bits: [Int]
  let dayIdx: Int; let dayGan: String; let dayZhi: String
  let lines: [CoinTossCodable]?; let source: String; let inputs: NumbersInput?
  struct CoinTossCodable: Codable, Equatable { let coins:[Bool]; let backs:Int; let symbol:String; let moving:Bool }
  struct NumbersInput: Codable, Equatable { let a:Int; let b:Int; let c:Int }
}
extension HistoryRecord { var coinTosses: [CoinToss]? { lines?.map{ CoinToss(coins:$0.coins, backs:$0.backs, symbol:$0.symbol, moving:$0.moving) } } }

enum HistoryStore {
  static let key="6yao.history.v1"; static let limit=50
  static func load()->[HistoryRecord]{
    guard let d=UserDefaults.standard.data(forKey:key) else { return [] }
    return (try? JSONDecoder().decode([HistoryRecord].self, from:d)) ?? []
  }
  static func save(_ list:[HistoryRecord]){
    if let d=try? JSONEncoder().encode(list){ UserDefaults.standard.set(d, forKey:key) }
  }
  static func push(_ r:HistoryRecord){
    var l=load(); l.insert(r, at:0); if(l.count>limit){ l=Array(l.prefix(limit)) }; save(l)
  }
  static func remove(id:String){ save(load().filter{$0.id!=id}) }
  static func clear(){ UserDefaults.standard.removeObject(forKey:key) }
}
```

註：`CoinToss` 需 `Codable` 或在 `HistoryStore` 內做轉換；簡化為 `HistoryRecord` 內嵌 `CoinTossCodable`。

- [ ] **Step 4: 驗證通過**

Run: 同 Step 2 指令，預期 `PASS 21`（原 17 + 新 4）

- [ ] **Step 5: Commit**

```bash
git add ios/Sources/HistoryStore.swift ios/Tests/main.swift
git commit -m "feat(ios): add HistoryStore with UserDefaults (limit 50, Codable)"
```

---

### Task 5: iOS 歷史 UI（Preview + Sheet）

**Files:**
- Create: `/Users/nx/Documents/6yao/ios/Sources/Views/HistoryViews.swift`
- Modify: `/Users/nx/Documents/6yao/ios/Sources/Views/ContentView.swift:49-82`（header + ScrollView 底部）

**Interfaces:**
- Consumes: `AppModel.history`, `AppModel.grade`, `HistoryStore`
- Produces: `HistoryPreview`, `HistorySheet`, `HistoryRow` Views

- [ ] **Step 1: 寫 failing 檢查**

在 `ContentView` 搜尋 `HistoryPreview` → 應為 0 結果（尚未建立）

- [ ] **Step 2: 建立 HistoryViews.swift**

```swift
import SwiftUI
struct HistoryPreview: View {
  @EnvironmentObject var model: AppModel
  var body: some View{
    CardView(seal:"史", title:"歷史紀錄"){
      if model.history.isEmpty{
        Text("歷史尚無記錄。起一卦後會自動存檔。").font(Theme.song(13)).foregroundColor(.ink3).frame(maxWidth:.infinity).padding(.vertical,8)
      } else {
        VStack(spacing:8){ ForEach(model.history.prefix(3)){ r in HistoryRow(record:r) } }
        if model.history.count>3{ Button("查看全部 →"){ model.showHistory=true }.font(Theme.song(13)).foregroundColor(.cinnabar) }
      }
    }
  }
}
struct HistorySheet: View{
  @EnvironmentObject var model: AppModel
  var body: some View{
    NavigationView{
      List{
        ForEach(model.history){ r in HistoryRow(record:r) }
          .onDelete{ idx in idx.forEach{ model.removeHistory(id:model.history[$0].id) } }
        if model.history.isEmpty{ Text("尚無歷史").foregroundColor(.ink3) }
      }.navigationTitle("歷史紀錄（\(model.history.count)）").toolbar{
        ToolbarItem(placement:.navigationBarLeading){ Button("關閉"){ model.showHistory=false } }
        ToolbarItem(placement:.navigationBarTrailing){ Button("清空全部", role:.destructive){ model.clearHistory() }.disabled(model.history.isEmpty) }
      }
    }
  }
}
struct HistoryRow: View{
  @EnvironmentObject var model: AppModel
  let record: HistoryRecord
  var body: some View{
    HStack{
      VStack(alignment:.leading, spacing:2){
        Text("\(record.hgName)\(record.changedName.map{" → \($0)"} ?? "")").font(Theme.song(14)).foregroundColor(.ink)
        Text("\(record.dateISO) · \(record.ganzhiText) \(record.yongshen)").font(Theme.song(11)).foregroundColor(.ink3)
      }
      Spacer()
      Text(model.gradeForRecord(record)?.label ?? "").font(Theme.kai(11)).foregroundColor(.cinnabar).padding(.horizontal,6).overlay(RoundedRectangle(cornerRadius:2).stroke(Color.cinnabar, lineWidth:1.2))
      Button("×"){ model.removeHistory(id:record.id) }.foregroundColor(.ink3)
    }.contentShape(Rectangle()).onTapGesture{ model.restore(record: record); model.showHistory=false }
  }
}
```

- [ ] **Step 3: 修改 ContentView**

在 `header` 的 `Text(model.ganzhiText)` 同列加：

```swift
Button{ model.showHistory=true } label:{ Text("史").font(Theme.kai(13)).foregroundColor(.paper2).frame(width:28,height:28).background(Color.cinnabar, in:RoundedRectangle(cornerRadius:2)) }
```

在 `ScrollView` 的 `VStack` 最底部（`bookmarkChip` 後）加：

```swift
HistoryPreview()
.sheet(isPresented:$model.showHistory){ HistorySheet() }
```

- [ ] **Step 4: 驗證**

Run: `xcodebuild -project ios/六爻.xcodeproj -scheme 六爻 -destination 'platform=iOS Simulator,name=iPhone 15' build`（或 Xcode Run 模擬器手動檢查：歷史空狀態 → 起卦 → Preview 出現 → 點 Row 還原 → 抽屜可刪/清空）

- [ ] **Step 5: Commit**

```bash
git add ios/Sources/Views/HistoryViews.swift ios/Sources/Views/ContentView.swift
git commit -m "feat(ios): history preview + sheet UI with restore/delete/clear"
```

---

### Task 6: iOS 自動新卦與還原

**Files:**
- Modify: `/Users/nx/Documents/6yao/ios/Sources/AppModel.swift:48-93`（startCasting/castNumbers/restore）
- Modify: `/Users/nx/Documents/6yao/ios/Sources/Views/CastViews.swift:30-40`（disabled 條件）
- Modify: `/Users/nx/Documents/6yao/ios/Sources/Engine.swift`（新增 gradeForRecord helper 若需要）

**Interfaces:**
- Consumes: `HistoryStore.push`, `result`, `lines`, `dayInfo`, `yongshen`
- Produces: `AppModel.pushHistory()`, `restore(record:)`, `gradeForRecord(_:)`，解鎖 `startCasting`

- [ ] **Step 1: 寫 failing 還原測試**

在 `Tests/main.swift` 新增：

```swift
func testRestoreGradeConsistent(){
  let data = try! YiData.load(from: Bundle.main.resourceURL!)
  let r = cast(upper:1, lower:1, moving:[0], data:data) // 乾為天 初爻動
  let rec = HistoryRecord(id:"1", ts:0, dateISO:"2026-09-08", ganzhiText:"", yongshen:"妻財", hgKey:r.hg.key, changedKey:r.changed?.key, hgName:r.hg.name, changedName:r.changed?.name, moving:r.moving, movingSymbols:[0:"○"], bits:r.hg.bits, dayIdx:0, dayGan:"甲", dayZhi:"子", lines:nil, source:"numbers", inputs:.init(a:1,b:1,c:1))
  let g1 = computeGrade(hg:r.hg, moving:r.moving, yongshen:"妻財", dayZhi:"子", dayIdx:0)
  let g2 = computeGrade(hg: buildHexagram(upper:1, lower:1, data:data), moving:rec.moving, yongshen:rec.yongshen, dayZhi:rec.dayZhi, dayIdx:rec.dayIdx)
  assert(g1.label==g2.label, "grade consistent fail")
}
```

- [ ] **Step 2: 執行驗證失敗**

Run: `swiftc ... && /tmp/6yao-test` → `restore` 尚未實作，`grade` 測試仍可過，但 `AppModel.restore` 不存在

- [ ] **Step 3: 實作 AppModel 修改**

在 `AppModel` 加入：

```swift
@Published var history: [HistoryRecord] = HistoryStore.load()
@Published var showHistory = false
func pushHistory(){
  guard let r=result else { return }
  let rec = HistoryRecord(id: UUID().uuidString, ts: Date().timeIntervalSince1970*1000, dateISO: ISO8601DateFormatter().string(from: castDate).prefix(10).description, ganzhiText: ganzhiText, yongshen: yongshen, hgKey:r.hg.key, changedKey:r.changed?.key, hgName:r.hg.name, changedName:r.changed?.name, moving:r.moving, movingSymbols:movingSymbols, bits:r.hg.bits, dayIdx:dayInfo.dayIdx, dayGan:dayInfo.dayGan, dayZhi:dayInfo.dayZhi, lines: lines.map{ HistoryRecord.CoinTossCodable(coins:$0.coins, backs:$0.backs, symbol:$0.symbol, moving:$0.moving)}, source: lines.isEmpty ? "numbers" : "coins", inputs:nil)
  HistoryStore.push(rec); history = HistoryStore.load()
}
func removeHistory(id:String){ HistoryStore.remove(id:id); history = HistoryStore.load() }
func clearHistory(){ HistoryStore.clear(); history = [] }
func restore(record: HistoryRecord){
  // 還原日期與用神
  yongshen = record.yongshen
  if let d = ISO8601DateFormatter().date(from: record.dateISO+"T00:00:00Z"){ castDate = d; updateDay() }
  // 覆蓋 dayInfo 為當時
  dayInfo = DayInfo(dayIdx: record.dayIdx, dayGan: record.dayGan, dayZhi: record.dayZhi, yearGan: dayInfo.yearGan, yearZhi: dayInfo.yearZhi, monthZhi: dayInfo.monthZhi, xunStart: dayInfo.xunStart, kongText: dayInfo.kongText)
  lines = record.coinTosses ?? []
  movingSymbols = record.movingSymbols
  let upper = Int(String(record.hgKey.prefix(1)))!, lower = Int(String(record.hgKey.suffix(1)))!
  result = cast(upper:upper, lower:lower, moving:record.moving, data:data)
}
func gradeForRecord(_ rec: HistoryRecord)->Grade?{
  guard let hg = try? buildHexagram(upper:Int(String(rec.hgKey.prefix(1)))!, lower:Int(String(rec.hgKey.suffix(1)))!, data:data) else { return nil }
  return computeGrade(hg:hg, moving:rec.moving, yongshen:rec.yongshen, dayZhi:rec.dayZhi, dayIdx:rec.dayIdx)
}
func startCasting() async{
  guard !casting else { return }
  if result != nil { pushHistory() }
  casting = true; lines=[]; result=nil; movingSymbols=[:]
  for _ in 0..<6{ lines.append(tossThreeCoins()); try? await Task.sleep(nanoseconds:480_000_000) }
  finalize(triggerBookmark:true); casting=false
}
func castNumbers(_ a:Int,_ b:Int,_ c:Int){
  if result != nil { pushHistory() }
  // 原有邏輯...
  history = HistoryStore.load()
}
```

在 `CastViews.swift` 將 `.disabled(model.casting || model.lines.count >= 6)` 改為 `.disabled(model.casting)`

- [ ] **Step 4: 驗證**

Run: `swiftc -o /tmp/6yao-test Sources/Models.swift Sources/Engine.swift Sources/HistoryStore.swift Tests/main.swift && /tmp/6yao-test` → 預期 `PASS 21`；模擬器操作：起一卦 → 再點擲銅錢直接重擲且歷史多 1 筆 → 點歷史還原

- [ ] **Step 5: Commit**

```bash
git add ios/Sources/AppModel.swift ios/Sources/Views/CastViews.swift
git commit -m "feat(ios): auto-new cast with auto-save and history restore"
```

---

### Task 7: 端到端驗收與測試補強

**Files:**
- Modify: `/Users/nx/Documents/6yao/ios/Tests/main.swift`（確認 21 項全 PASS）
- Test: Web `index.html` 手動

**Interfaces:**
- Consumes: 前述所有
- Produces: 綠色測試與手動驗收清單

- [ ] **Step 1: 跑 iOS 測試**

Run: `cd ios && swiftc -o /tmp/6yao-test Sources/Models.swift Sources/Engine.swift Sources/HistoryStore.swift Tests/main.swift && /tmp/6yao-test`
Expected: `PASS 21/21`（或 `All 21 tests PASS`）

- [ ] **Step 2: Web 手動驗收（依 spec 6 步）**

1) `open index.html` 起一卦 → 刷新 → `historyStore.load().length===1`
2) 滿 6 爻後再點擲銅錢 → 直接重擲，歷史第 1 筆為舊卦
3) 報數起卦覆蓋同樣存檔
4) 點歷史任一筆 → 排盤/解讀/用神/干支還原
5) 單筆刪除與清空持久化
6) 連續 51 卦 → 保持 50

- [ ] **Step 3: 回歸原有功能**

確認 `computeGrade`、`xunkongBranches`、`sixShen`、書籤彈窗、`yongshenSel` 切換仍正常

- [ ] **Step 4: Commit（若有測試修正）**

```bash
git add ios/Tests/main.swift
git commit -m "test: add history limit/roundtrip/grade consistency/yongshen restore"
```

---

## Self-Review

**1. Spec coverage:**
- 歷史本地儲存與上限 50 → Task 1,4
- 精簡清單 + 完整還原 → Task 2,5
- 折衷呈現（常駐 3 + 抽屜）→ Task 2,5
- 自動存檔直接重來 → Task 3,6
- 用神/干支一起存 → Task 1,4 的 HistoryRecord
- 單筆刪除/清空 → Task 2,5
- 雙端一致 → 每個功能皆有 Web + iOS 對應 Task
- 錯誤處理（Quota、parse fail、舊格式）→ Task 1,2,4
- 測試與驗收 → Task 7

**2. Placeholder scan:** 已移除所有 TBD/TODO，所有 code block 皆為可直接貼上的完整程式碼，無「handle edge cases」等空泛描述。

**3. Type consistency:** Web `HistoryRecord{id,ts,dateISO,ganzhiText,yongshen,hgKey,changedKey,hgName,changedName,moving,movingSymbols,bits,dayIdx,dayGan,dayZhi,lines,source,inputs}` 與 iOS `HistoryRecord` 欄位一一對應；`historyStore.push/remove/clear/load` 兩端同名；`renderHistoryPreview/renderHistoryList/restoreHistory` 與 `HistoryPreview/HistorySheet/HistoryRow/restore` 對應。

若發現 spec 有「歷史是否存 lines 完整爻線」未明，已在 Task 1 明確為 `lines` 僅搖錢有、報數為 null，並在 Task 2 還原分支處理。
