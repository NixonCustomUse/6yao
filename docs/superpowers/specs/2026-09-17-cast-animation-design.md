# 硯台落錢擲爻動畫 — 設計文件（網頁版先行）

日期：2026-09-17
狀態：已與使用者確認（方案 A 硯台落錢，範圍：僅 Web `index.html`，iOS 不動）
前情：2026-09-09 太極生爻版因「有 bug / 不順」於 09-11 revert，本次只改網頁版動畫 CSS+JS 節奏，不碰 iOS。

## 目標

把網頁版「擲銅錢」從現有 `coinJump 0.52s + coinSpin + shadowPulse`（每爻 480+420=900ms，共約 5.4s）重調為「硯台落錢」：三錢分先後小跳落入靜態硯台托盤，定面可讀後爻線彈簧長出。只用 transform/opacity、修掉卡頓，總時長壓到約 3.9s，維持零依賴、60fps、`prefers-reduced-motion` 可用、宣紙文人風不變。

## 現況問題（對應 revert 原因）

| 問題 | 說明 |
|---|---|
| 體感不順 | 父層跳 + 子層翻轉不同 easing，視覺脫節；`animationDelay` 殘留未清，多次連擲越跳越亂 |
| 太慢 | 每爻 900ms × 6 = 5.4s，等待感重 |
| 落點飄 | 銅錢懸空無托盤，陰影 `translateX(-50%) scale` 與跳動不同步 |
| 風險 | 上次太極版新增容器 + opacity 流程，與卡片 `fadeUp` 衝突；本次不新增容器 |

## 需求（已確認）

- 方案 A，僅網頁版；iOS `CastViews.swift` / `AppModel.swift` 完全不動
- 每爻約 650ms，6 爻約 3.9s 自下而上
- 三錢 stagger 0/80/160ms，小跳 -22px + 單周翻轉 + 陰影收縮
- 定面停留可讀（背/字），爻線彈簧長出；陰兩段差 90ms；動爻朱砂 + `moveGlow`
- 托盤為靜態 CSS 橢圓（`--paper-3` + `--line`），無動畫，不新增 DOM 容器（用 `.coins::after`）
- 色票不新增，僅復用現有變數

## 1. 視覺分鏡（每爻 650ms）

```
0ms     三錢依 0/80/160ms 先後起跳：translateY 0→-22px→0（0.45s ease-out），face 360° linear，陰影 scale 1→0.68→1
0-450ms 跳動進行，`renderCoins` 已先寫好背/字，翻轉結束即為結果面
350ms   定面停留約 120ms（可讀性，不加動畫）
470ms   爻線生長：scaleX 0→1（0.4s spring var(--ease-spring)），陰第二段延 90ms；動爻朱砂 + moveGlow
650ms   下一爻
6爻後   照舊 renderResult + openBookmark + scrollIntoView，不變
```

## 2. 版式與顏色

- `.coins` 加 `position:relative; padding-bottom:14px`，`::after` 畫托盤橢圓：`ellipse radial-gradient(paper-3→transparent)`，靜態
- 銅錢本體樣式不變（金色 radial + 邊框），只換 keyframes 參數：跳高 18px→22px 實為 -22px，時長 0.52s→0.45s
- 爻線復用 `.bar`（陽 86px、陰 35+7+35），`transform-origin:left`，動爻色 `var(--cinnabar)` 不變
- `prefers-reduced-motion`：跳/轉/生長全關，直接顯示結果（沿用現有 media query 擴充）

## 3. 技術方案（僅 index.html 單檔增量）

- CSS（改 `#anim-polish` 內 coins 段，不動其他）：
```css
.coins{position:relative; padding-bottom:14px}
.coins::after{content:""; position:absolute; left:50%; bottom:0; width:220px; height:18px; transform:translateX(-50%); background:radial-gradient(ellipse at center, rgba(43,38,32,0.14), transparent 70%); border-radius:50%; pointer-events:none}
.coin.toss{animation:coinJump 0.45s cubic-bezier(0.25,0.46,0.45,0.94)}
.coin.toss::before{animation:shadowPulse 0.45s ease-out}
.coin.toss .face{animation:coinSpin 0.45s linear}
@keyframes coinJump{0%{transform:translateY(0)}38%{transform:translateY(-22px)}100%{transform:translateY(0)}}
```
- JS（改 `renderCoins` + toss 迴圈）：
  - `renderCoins`：每次加 `.toss` 前先清 `animationDelay`；加完後用 `setTimeout 600ms` 清 `animationDelay`（不清 `class`，靠下次 `remove→reflow→add` 重觸發），避免殘留疊加
  - 迴圈 `sleep(480)→sleep(350)`、`sleep(420)→sleep(300)`，每爻 650ms，總約 3.9s
  - `renderLines(true)` 時機不變（跳完後長爻）
  - 報數起卦、undo/reset、history 還原：不觸發 toss 動畫，直接靜態顯示
- 不動：`tossThreeCoins`、`barHTML`、`trigramFromLines`、`cast`、`renderResult`、`openBookmark`、書籤、歷史邏輯

## 4. 行為與錯誤處理

| 情境 | 處理 |
|---|---|
| `prefers-reduced-motion` | 跳/轉無動畫，爻線直接顯示 |
| 重入（casting 中再點） | 沿用 `casting` guard + 按鈕 disabled，不重疊 |
| 還原歷史 / 報數起卦 | 不加 `.toss`，靜態渲染 |
| 切 tab / 切 mode 中斷 | `casting` 流程照跑完（現狀），動畫缺幀不影響結果正確性 |
| 舊瀏覽器 | 只用 `transform/opacity/radial-gradient`，Safari 12 可用 |

## 範圍外（YAGNI）

- 不做 iOS（`CastViews`/`AppModel` 不動，留待後續對齊）
- 不做竹筒/太極/八卦光陣/粒子/WebGL
- 不做音效
- 不改全站主題、不做動畫設定頁
- 不新增測試 harness（沿用手動驗收；iOS 17 項測試不受影響）

## 測試與驗收（Web）

- 連點「擲銅錢」3 次：每次約 3.9s 完成，卦象與動畫爻一致，無越跳越亂
- 慢速檢查：三錢 stagger 可見、定面背/字可讀、陰陽對應（`—/○` 陽、`- -/×` 陰）、動爻朱砂發光
- `prefers-reduced-motion` 開啟：直接出結果無動畫
- 報數起卦：不觸發銅錢動畫
- 還原歷史：靜態顯示，不觸發動畫
- 無主控台錯誤，60fps（只跑 transform/opacity）
