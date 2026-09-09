# 太極生爻動畫重設計 — 設計文件

日期：2026-09-09
狀態：已與使用者確認（方案 3 太極生爻，風格 B 玄學神秘）

## 目標

將六爻排盤的「擲銅錢」動畫從現有 `coinJump 0.52s + coinSpin + shadowPulse` 全新重設計為「太極生爻」：以太極旋轉為起點，逐爻吐出陰陽，最終定型為卦畫。維持零依賴、60fps、`prefers-reduced-motion` 可用，雙端（Web + iOS）行為一致。

## 現況問題

| 問題 | 說明 |
|---|---|
| 舊動畫單調 | 3 枚銅錢重複翻轉 6 次，無儀式感，與玄學氛圍不符 |
| 與卦理無關 | 銅錢翻轉與陰陽爻無視覺對應，動爻僅靠 `barGrow` |
| 風格不符需求 | 使用者指定 B 玄學神秘（暗底金光、太極/八卦），現有宣紙輕盈風格需局部暗化 |

## 需求（已確認 B-3）

- 風格 B 玄學神秘，選方案 3 太極生爻
- 時長 2.8 秒單次起卦觸發，6 爻自下而上每 0.28s 吐出一爻
- 容器置於原 `coins` 位置，高度 120px 置中，局部暗化不改全站主題
- 太極：外圈 1.5px solid var(--line-2)，內黑 #1A1A1E、白 #F9F5EA，金點 var(--gold) #C99D4F
- 爻線復用 .bar，陽實線 86px、陰斷線 35px+7px+35px，動爻朱砂 + 發光
- 零依賴，Web 用 SVG+CSS，iOS 用 Canvas+TimelineView

## 1. 視覺分鏡

```
0.0-0.8s  太極入場：160px 太極圖置中，rotate 0→180° ease-in-out，黑白魚各含 1 金點（radial-gradient），外發光 drop-shadow 0 0 12px rgba(201,157,79,0.25)
0.8-1.08  初爻吐出：依該爻陰陽，太極邊緣滑出一條爻線（translateY 12→0 + opacity 0→1 + scaleX 0→1），陰斷線兩段同步展開
1.08-1.36 二爻
1.36-1.64 三爻
1.64-1.92 四爻
1.92-2.20 五爻
2.20-2.48 上爻（共 6 爻，間隔 0.28s）
2.48-2.8  定型：6 爻同時發光 drop-shadow 0 0 6px rgba(201,157,79,0.5)，太極 opacity 1→0 淡出，背景暗化 radial-gradient 收回
```

每爻對應一次 `tossThreeCoins()` 的陰陽結果，動爻時爻線為朱砂色並加 `moveGlow 2.2s infinite`。

## 2. 版式與顏色

- 容器 `div.taiji-stage`：`position:relative; height:120px; display:flex; align-items:center; justify-content:center; perspective:600px`，背景 `radial-gradient(ellipse at center, rgba(43,38,32,0.06), transparent 70%)`
- 太極 SVG：`width 96 height 96`，`circle` 外圈 + `path` 陰陽魚 + 兩 `circle` 金點，`will-change: transform`
- 爻線容器 `div.taiji-lines`：`position:absolute; left:50%; top:50%; transform:translate(-50%,-50%); display:flex; flex-direction:column-reverse; gap:4px`
- 顏色僅復用 `--paper/--line-2/--cinnabar/--gold`，不新增色票；太極黑白為固定值 #1A1A1E / #F9F5EA，位於暗化層內不影響亮色主題
- `prefers-reduced-motion`：太極不旋轉，6 爻瞬間顯示（`animation:none; opacity:1; transform:none`）

## 3. 技術方案

### Web（index.html 單檔內增量）

- 新增結構（coinsPanel 內 coinsBox 旁或替代）：
```html
<div class="taiji-stage" id="taijiStage" aria-hidden="true">
  <svg class="taiji" viewBox="0 0 96 96"><circle cx="48" cy="48" r="47" fill="none" stroke="var(--line-2)" stroke-width="1.5"/><path d="M48 1 A47 47 0 0 0 48 95 A23.5 23.5 0 0 0 48 48 A23.5 23.5 0 0 1 48 1" fill="#1A1A1E"/><path d="M48 1 A47 47 0 0 1 48 95 A23.5 23.5 0 0 1 48 48 A23.5 23.5 0 0 0 48 1" fill="#F9F5EA"/><circle cx="48" cy="24.5" r="6" fill="#C99D4F"/><circle cx="48" cy="71.5" r="6" fill="#C99D4F"/></svg>
  <div class="taiji-lines" id="taijiLines"></div>
</div>
```
- CSS（獨立 <style id="taiji-style">）：
```css
.taiji{transition:transform 0.8s cubic-bezier(0.22,1,0.36,1); will-change:transform}
.taiji.spin{transform:rotate(180deg)}
.taiji-lines .bar{transform-origin:left; transform:scaleX(0); transition:transform 0.35s cubic-bezier(0.22,1,0.36,1), opacity 0.3s}
.taiji-lines .bar.in{transform:scaleX(1)}
@media (prefers-reduced-motion: reduce){ .taiji{transition:none} .taiji-lines .bar{transition:none; transform:none} }
```
- JS：`tossBtn` 的 6 次迴圈內，將 `renderCoins` 改為 `renderTaiji(i, tossResult)`，`renderTaiji` 依 `symbol` 決定 `yang ? 86px實線 : 雙35px斷線`，動時加 `moveGlow`；首擲前 `taiji.classList.add('spin')`，末爻後 `setTimeout(()=>taiji.style.opacity=0, 400)`

### iOS（ios/Sources/Views/CastViews.swift）

- 新增 `TaijiView(isAnimating: Bool, currentYao: Int, tosses: [CoinToss])`：`Canvas` 繪太極（`Path` 陰陽魚 + `Circle` 金點），`TimelineView` 驅動 `rotationEffect(.degrees(isAnimating ? 180 : 0))`，6 爻用 `ForEach` + `HexBars` 復用，`opacity` 與 `scaleEffect` 依 `currentYao >= index`
- `AppModel.startCasting` 內每 `480ms` 後更新 `@Published var taijiYao: Int`（0→6），`CastViews` 監聽 `taijiYao` 觸發動畫
- `Theme.swift` 無需新增顏色

## 4. 行為與錯誤處理

| 情境 | 處理 |
|---|---|
| `prefers-reduced-motion: reduce` | Web 直接顯示靜態 6 爻，無旋轉與縮放； iOS `TimelineView` 不開，`withAnimation(nil)` |
| 重入（casting 期間再點） | 仍由 `casting` guard 阻擋，動畫不重疊 |
| 還原歷史（非起卦） | 不觸發太極動畫，直接顯示靜態爻線（`taijiStage` hidden） |
| 舊瀏覽器無 `conic-gradient` | 不使用，僅 `radial-gradient` 與 `rotate`，相容至 Safari 12 |
| 動畫中斷（切 tab/報數起卦） | `visibilitychange` 或 `mode` 切換時 `taijiStage` 立即 hidden，顯示結果 |

## 範圍外（YAGNI）

- 不做八卦光陣/星象粒子（留作後續可選動畫 B-1/B-2）
- 不做 WebGL/Three.js，不引入 canvas 粒子系統
- 不做音效（木魚/銅錢碰撞聲）
- 不改變全站宣紙亮色主題，僅局部暗化
- 不做使用者自選動畫設定頁（首版固定太極，後續再加設定）

## 測試與驗收

- Web：慢速 0.5x 錄影檢查 6 爻自下而上、陰陽對應正確（`—/○` 為陽、`- -/×` 為陰）、動爻朱砂發光、太極 180° 旋轉、reduce-motion 直接出結果
- iOS：`xcodebuild -project ios/六爻.xcodeproj -scheme 六爻` 無掉幀，6 爻依序出現
- 測試：`ios/Tests/main.swift` 增 1 項 `taijiBits`：`trigramFromLines` 轉 `bits` 與 `TaijiView` 顯示一致
- 驗收：點「擲銅錢」3 次皆 2.8s 內完成，卦象與動畫爻一致；報數起卦不觸發太極

## 實作位置

- Web：`/Users/nx/Documents/6yao/index.html`（新增 taiji-stage SVG+style+JS，替換 coins 動畫）
- iOS：`ios/Sources/Views/CastViews.swift`（新增 TaijiView，改 CoinsCastView）、`ios/Sources/AppModel.swift`（新增 taijiYao 狀態）、`ios/Tests/main.swift`（1 項測試）
