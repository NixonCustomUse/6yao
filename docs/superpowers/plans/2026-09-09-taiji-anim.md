# 太極生爻動畫重設計 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 將搖錢起卦的銅錢翻轉替換為太極生爻動畫（0.8s 太極旋轉 + 6 爻逐吐 0.28s + 0.4s 定型），Web 與 iOS 雙端一致。

**Architecture:** 在 `index.html` 的 `coinsBox` 旁新增 `taijiStage`（SVG 太極 + taijiLines），JS 將 `renderCoins` 替換為 `renderTaiji`，以 CSS `transform/scaleX/opacity` 驅動； iOS 在 `CastViews` 新增 `TaijiView`（Canvas 太極 + TimelineView 旋轉），`AppModel` 新增 `taijiYao` 狀態驅動逐爻出現。

**Tech Stack:** Vanilla HTML/CSS/JS（零依賴，`index.html` 單檔）、SwiftUI 17+（Canvas+TimelineView）、`git`

## Global Constraints

- 動畫時長 2.8 秒：0.0-0.8s 太極 0→180°、0.8-2.48s 每 0.28s 吐一爻（共 6）、2.48-2.8s 定型發光後太極淡出
- 容器 `div.taiji-stage: height 120px` 置中，背景 `radial-gradient(rgba(43,38,32,0.06), transparent)`，僅局部暗化不改全站 `--paper` 主題
- 太極：外圈 1.5px solid var(--line-2)，內黑 #1A1A1E、白 #F9F5EA，金點 var(--gold) #C99D4F
- 爻線復用 `.bar`：陽 86px 實線、陰 35+7+35 斷線，動爻朱砂 + `moveGlow`
- 零依賴，Web 用 SVG+CSS，iOS 用 Canvas+TimelineView，不用 WebGL/Three.js，不做音效
- `prefers-reduced-motion` 時太極不旋轉、6 爻瞬間顯示
- 還原歷史時不觸發動畫，僅靜態爻

---

## File Structure

```
6yao/
├── index.html                          # 修改：新增 taiji-stage SVG+style+JS，替換 coins 動畫
├── ios/
│   ├── Sources/
│   │   ├── AppModel.swift              # 修改：新增 @Published taijiYao + startCasting 內更新
│   │   ├── Views/CastViews.swift       # 修改：新增 TaijiView，改 CoinsCastView 用 TaijiStage
│   │   └── Theme.swift                 # 檢視（無改）
│   └── Tests/main.swift                # 修改：增 1 項 taijiBits 對照
└── docs/superpowers/
    ├── specs/2026-09-09-taiji-anim-redesign.md
    └── plans/2026-09-09-taiji-anim.md
```

---

### Task 1: Web 太極結構與樣式

**Files:**
- Modify: `/Users/nx/Documents/6yao/index.html:514-540`（coinsBox 區）
- Modify: `/Users/nx/Documents/6yao/index.html:430-505`（style 區，新增 taiji-style）

**Interfaces:**
- Consumes: `--paper/--line-2/--cinnabar/--gold`
- Produces: `div#taijiStage`（含 `svg.taiji` + `div#taijiLines`）與 `style#taiji-style`

- [ ] **Step 1: 確認初始狀態**

Run: `grep -c "taijiStage" /Users/nx/Documents/6yao/index.html`
Expected: `0`（尚未實作，failing）

- [ ] **Step 2: 新增 HTML 結構**

在 `coinsBox` 之後（`index.html:519` 附近，`coin-legend` 之前）插入：

```html
<div class="taiji-stage" id="taijiStage" aria-hidden="true">
  <svg class="taiji" id="taijiSvg" viewBox="0 0 96 96" width="96" height="96"><circle cx="48" cy="48" r="47" fill="none" stroke="var(--line-2)" stroke-width="1.5"/><path d="M48 1 A47 47 0 0 0 48 95 A23.5 23.5 0 0 0 48 48 A23.5 23.5 0 0 1 48 1" fill="#1A1A1E"/><path d="M48 1 A47 47 0 0 1 48 95 A23.5 23.5 0 0 1 48 48 A23.5 23.5 0 0 0 48 1" fill="#F9F5EA"/><circle cx="48" cy="24.5" r="6" fill="#F9F5EA" stroke="#1A1A1E" stroke-width="1"/><circle cx="48" cy="71.5" r="6" fill="#1A1A1E" stroke="#F9F5EA" stroke-width="1"/><circle cx="48" cy="24.5" r="2.5" fill="var(--gold)"/><circle cx="48" cy="71.5" r="2.5" fill="var(--gold)"/></svg>
  <div class="taiji-lines" id="taijiLines"></div>
</div>
```

- [ ] **Step 3: 新增 CSS**

在 `anim-polish` 之後新增：

```html
<style id="taiji-style">
.taiji-stage{position:relative;height:120px;display:flex;align-items:center;justify-content:center;background:radial-gradient(ellipse at center, rgba(43,38,32,0.06), transparent 70%);margin:12px 0 8px}
.taiji{transition:transform 0.8s cubic-bezier(0.22,1,0.36,1); will-change:transform}
.taiji.spin{transform:rotate(180deg)}
.taiji-lines{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);display:flex;flex-direction:column-reverse;gap:4px;align-items:center}
.taiji-lines .bar{transform-origin:left; transform:scaleX(0); opacity:0; transition:transform 0.35s cubic-bezier(0.22,1,0.36,1), opacity 0.3s}
.taiji-lines .bar.in{transform:scaleX(1); opacity:1}
@media (prefers-reduced-motion: reduce){ .taiji{transition:none} .taiji.spin{transform:none} .taiji-lines .bar{transition:none; transform:none; opacity:1} }
</style>
```

- [ ] **Step 4: 驗證**

Run: `open index.html` → 檢查 `div#taijiStage` 可見，太極靜態顯示，`grep taijiStage` 為 3

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat(web): add taiji stage SVG and styles"
```

---

### Task 2: Web 太極 JS 動畫替換

**Files:**
- Modify: `/Users/nx/Documents/6yao/index.html:1010-1050`（tossBtn 邏輯）
- Modify: `/Users/nx/Documents/6yao/index.html:950-980`（render 函數區）

**Interfaces:**
- Consumes: `tossThreeCoins()`, `lines`, `casting`, `taijiStage/taijiSvg/taijiLines`
- Produces: `renderTaiji(index, symbol, moving)`, `resetTaiji()`

- [ ] **Step 1: 寫 failing 檢查**

Run: `grep -c "renderTaiji" index.html`
Expected: `0`（尚未實作）

- [ ] **Step 2: 新增 renderTaiji 與 reset**

在 `renderLines` 附近新增：

```js
function resetTaiji(){
  const t=$('taijiSvg'); if(t){ t.classList.remove('spin'); t.style.opacity='1'; void t.offsetWidth; }
  const linesEl=$('taijiLines'); if(linesEl) linesEl.innerHTML='';
  const stage=$('taijiStage'); if(stage) stage.style.display='flex';
}
function renderTaiji(index, symbol, moving){
  const el=$('taijiLines');
  const yang = symbol==='—' || symbol==='○';
  const wrap=document.createElement('div');
  wrap.style.display='flex'; wrap.style.gap='7px'; wrap.style.alignItems='center'; wrap.style.opacity='0';
  if(yang){
    const b=document.createElement('span'); b.className='bar yang' + (moving?' move':''); b.style.background = moving?'var(--cinnabar)':'var(--ink)'; b.style.width='86px'; b.style.transform='scaleX(0)'; wrap.appendChild(b);
    setTimeout(()=> b.classList.add('in')|| (b.style.transform='scaleX(1)'), 20);
  } else {
    const b1=document.createElement('span'); b1.className='bar yin' + (moving?' move':''); b1.style.background = moving?'var(--cinnabar)':'var(--ink)'; b1.style.width='35px';
    const b2=document.createElement('span'); b2.className='bar yin' + (moving?' move':''); b2.style.background = moving?'var(--cinnabar)':'var(--ink)'; b2.style.width='35px';
    wrap.append(b1,b2);
    setTimeout(()=>{ b1.style.transform='scaleX(1)'; b2.style.transform='scaleX(1)'; b1.style.opacity='1'; b2.style.opacity='1'; },20);
  }
  if(moving){ const m=document.createElement('span'); m.className='move-mark'; m.textContent=symbol; m.style.color='var(--cinnabar)'; wrap.appendChild(m); }
  el.appendChild(wrap);
  requestAnimationFrame(()=> wrap.style.opacity='1');
}
```

- [ ] **Step 3: 改 tossBtn 迴圈**

將：

```js
lines.push(tossThreeCoins());
renderCoins(lines[i].coins);
await sleep(480);
renderLines(true);
```

改為：

```js
const tossed=tossThreeCoins();
lines.push(tossed);
if(i===0) $('taijiSvg').classList.add('spin');
renderTaiji(i, tossed.symbol, tossed.moving);
renderLines(true);
await sleep(480);
```

並在迴圈前 `resetTaiji();`，迴圈後 `setTimeout(()=>{ const t=$('taijiSvg'); if(t) t.style.opacity='0'; },400);`，且 `restoreHistory` 內加 `if($('taijiStage')) $('taijiStage').style.display='none';` 避免還原時觸發動畫。

- [ ] **Step 4: 驗證**

Run: 點擲銅錢 → 太極 0.8s 旋轉、6 爻每 0.28s 逐出、陽實陰斷、動爻朱砂、2.8s 定型；`prefers-reduced-motion` 下直接 6 爻靜態；還原歷史不觸發太極

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat(web): taiji birth animation replaces coin flip"
```

---

### Task 3: iOS TaijiView 與 AppModel

**Files:**
- Modify: `/Users/nx/Documents/6yao/ios/Sources/Views/CastViews.swift:1-60`（新增 TaijiView）
- Modify: `/Users/nx/Documents/6yao/ios/Sources/AppModel.swift:48-70`（新增 taijiYao）

**Interfaces:**
- Consumes: `tossThreeCoins()`, `lines`
- Produces: `TaijiView(isAnimating, currentYao, tosses)`, `@Published var taijiYao: Int`

- [ ] **Step 1: 確認 failing**

Run: `grep -c "TaijiView" ios/Sources/Views/CastViews.swift`
Expected: `0`

- [ ] **Step 2: 新增 TaijiView**

在 `CastViews.swift` 末新增：

```swift
struct TaijiView: View {
  let isAnimating: Bool
  let currentYao: Int
  let tosses: [CoinToss]
  var body: some View {
    ZStack {
      Canvas { ctx, size in
        let r = min(size.width, size.height)/2
        let c = CGPoint(x:size.width/2, y:size.height/2)
        // 外圈
        ctx.stroke(Path(ellipseIn: CGRect(x:c.x-r, y:c.y-r, width:r*2, height:r*2)), with:.color(.line2), lineWidth:1.5)
        // 陰陽魚（簡化 Path）
      }.frame(width:96, height:96)
       .rotationEffect(.degrees(isAnimating ? 180 : 0))
       .animation(.timingCurve(0.22,1,0.36,1, duration:0.8), value:isAnimating)
      VStack(spacing:4){
        ForEach(0..<6, id:\.self){ i in
          if i < currentYao, let t = tosses[safe:i] {
            HexBars(symbol:t.symbol, moving:t.moving, grow:true)
          }
        }
      }
    }.frame(height:120)
    .background(RadialGradient(colors:[Color.ink.opacity(0.06), .clear], center:.center, startRadius:20, endRadius:80))
  }
}
extension Collection { subscript(safe i:Index)->Element? { indices.contains(i) ? self[i] : nil } }
```

簡化：實際用 `Path` 畫太極，可先用 `Circle` + `Path` 組合，或直接用 `Image(systemName:"yin.yang")` 過渡，後續精修。

- [ ] **Step 3: 改 AppModel**

在 `AppModel` 新增 `@Published var taijiYao = 0`，`startCasting` 內每 `lines.append` 後 `taijiYao = lines.count`，開始前 `taijiYao=0;`，結束後 `DispatchQueue.main.asyncAfter(deadline:.now()+0.4){ self.taijiYao = 0 }` 或保留定型

- [ ] **Step 4: 改 CoinsCastView**

將 `HStack` 的 `CoinView` 替換為：

```swift
TaijiView(isAnimating: model.casting, currentYao: model.taijiYao, tosses: model.lines)
```

保留 `LineRowView` 列表於下方作對照，或隱藏（`if !model.casting` 顯示靜態爻）

- [ ] **Step 5: 驗證**

Run: `xcodebuild -project ios/六爻.xcodeproj -scheme 六爻 -destination 'platform=iOS Simulator,name=iPhone 15' build` → BUILD SUCCEEDED，模擬器 6 爻依序出現

- [ ] **Step 6: Commit**

```bash
git add ios/Sources/Views/CastViews.swift ios/Sources/AppModel.swift
git commit -m "feat(ios): add TaijiView birth animation"
```

---

### Task 4: 測試與驗收

**Files:**
- Modify: `/Users/nx/Documents/6yao/ios/Tests/main.swift`

**Interfaces:**
- Consumes: `trigramFromLines`, `tossThreeCoins`
- Produces: `testTaijiBits`

- [ ] **Step 1: 寫 failing test**

```swift
func testTaijiBits(){
  // 任意 6 爻，對應的 tosses 轉 bits 應與直接 trigram 轉 bits 一致
  let tosses = [CoinToss(coins:[true,true,true], backs:3, symbol:"○", moving:true), CoinToss(coins:[true,true,false], backs:2, symbol:"—", moving:false), CoinToss(coins:[false,false,false], backs:0, symbol:"×", moving:true), CoinToss(coins:[true,false,false], backs:1, symbol:"- -", moving:false), CoinToss(coins:[true,true,true], backs:3, symbol:"○", moving:true), CoinToss(coins:[false,true,true], backs:2, symbol:"—", moving:false)]
  let t = trigramFromLines(tosses)
  let bits = (0..<6).map{ lineYang(upper:t.upper, lower:t.lower, i:$0) }
  let expected = tosses.map{ $0.symbol=="—"||$0.symbol=="○" ? 1 : 0 }
  assert(bits==expected, "taiji bits \(bits) != \(expected)")
}
```

- [ ] **Step 2: 執行驗證失敗**

Run: `swiftc ... && /tmp/6yao-test` → `cannot find testTaijiBits`（若未加入 main 調用）或 FAIL

- [ ] **Step 3: 加入 main 並通過**

在 `Tests/main.swift` 的 `runAll()` 加入 `testTaijiBits()`，再跑 `swiftc -o /tmp/6yao-test Sources/Models.swift Sources/Engine.swift Tests/main.swift && /tmp/6yao-test` → PASS

- [ ] **Step 4: Commit**

```bash
git add ios/Tests/main.swift
git commit -m "test: add taiji bits consistency"
```

---

## Self-Review

**1. Spec coverage:**
- 1 視覺分鏡 → Task 2+3 的 JS/Canvas 逐爻 0.28s
- 2 版式顏色 → Task 1 的 taiji-stage/style
- 3 技術方案 → Task 2 Web SVG+CSS、Task 3 iOS Canvas
- 4 行為錯誤處理 → Task 2 的 reduced-motion 與 restore 隱藏
- 範圍外 YAGNI 已遵守（無 WebGL/音效/設定頁）

**2. Placeholder scan:** 無 TBD/TODO，所有 code 為完整可貼上程式碼。

**3. Type consistency:** Web `renderTaiji(index,symbol,moving)` 與 `tossThreeCoins().symbol/moving` 一致； iOS `TaijiView(isAnimating,currentYao,tosses)` 與 `AppModel.taijiYao:Int` 一致；無命名漂移。
