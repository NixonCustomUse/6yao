# 硯台落錢擲爻動畫（網頁版） Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `index.html` 實作硯台落錢擲爻動畫（Web-only），修掉連擲卡頓並把總時長壓到約 3.9s。

**Architecture:** 只改 `index.html` 單檔：`#anim-polish` 內 coins CSS 置換為托盤 + 0.45s 跳動，`renderCoins` 加 delay 清理，toss 迴圈 sleep 改 350+300ms。無新檔案、無新依賴、不碰 iOS。

**Tech Stack:** 純 HTML/CSS/JS（零依賴），CSS transform/opacity only，`var(--ease-spring)`。

## Global Constraints

- 僅改網頁版 `index.html`，不碰 `ios/` 任何檔案。
- 不新增色票，僅復用 `--paper-3/--line/--cinnabar/--ease-spring`。
- 只用 transform/opacity 做動畫，維持 60fps。
- 保留 `prefers-reduced-motion` 靜態降級。
- 報數起卦 / 歷史還原 / undo-reset 不觸發 toss 動畫（維持現狀）。

---

## Files

- Modify: `/Users/nx/Documents/6yao/index.html` — `#anim-polish` coins 段（約第 437-470 行）：托盤 `::after` + `coinJump 0.45s/-22px` + `shadowPulse 0.45s` + `coinSpin 0.45s`。
- Modify: `/Users/nx/Documents/6yao/index.html` — `renderCoins`（約第 988-997 行）：加 delay 清理 `setTimeout 600ms`。
- Modify: `/Users/nx/Documents/6yao/index.html` — toss 迴圈（約第 1024-1031 行）：`sleep(480)→sleep(350)`、`sleep(420)→sleep(300)`。
- Modify: `/Users/nx/Documents/6yao/index.html` — `@media (prefers-reduced-motion: reduce)`（約第 399-401 行）：確認托盤/跳動全關（若既有全域關閉已涵蓋則免改）。

---

### Task 1: Coins CSS 置換（托盤 + 0.45s 跳動）

**Files:**
- Modify: `/Users/nx/Documents/6yao/index.html:437-470`

**Interfaces:**
- Consumes: 現有 `.coins`、`.coin`、`.coin .face`、`::before` 陰影結構。
- Produces: 新 `.coins::after` 托盤、`coinJump(-22px/0.45s)`、`shadowPulse(0.45s)`，供 Task 2 的 `renderCoins` 觸發。

- [ ] **Step 1: 置換 CSS 區塊**

將 `#anim-polish` 內以下舊段：

```css
.coins { gap: 24px; perspective: 800px; }
.coin { position: relative; }
```

置換/擴充為：

```css
.coins { gap: 24px; perspective: 800px; position: relative; padding-bottom: 14px; }
.coins::after {
  content: "";
  position: absolute;
  left: 50%;
  bottom: 0;
  width: 220px;
  height: 18px;
  transform: translateX(-50%);
  background: radial-gradient(ellipse at center, rgba(43, 38, 32, 0.14), transparent 70%);
  border-radius: 50%;
  pointer-events: none;
}
.coin { position: relative; }
```

並將：

```css
.coin.toss { animation: coinJump 0.52s cubic-bezier(0.25, 0.46, 0.45, 0.94); }
.coin.toss::before { animation: shadowPulse 0.52s ease-out; }
.coin.toss .face { animation: coinSpin 0.52s linear; }
@keyframes coinJump {
  0% { transform: translateY(0); }
  38% { transform: translateY(-18px); }
  100% { transform: translateY(0); }
}
```

改為：

```css
.coin.toss { animation: coinJump 0.45s cubic-bezier(0.25, 0.46, 0.45, 0.94); }
.coin.toss::before { animation: shadowPulse 0.45s ease-out; }
.coin.toss .face { animation: coinSpin 0.45s linear; }
@keyframes coinJump {
  0% { transform: translateY(0); }
  38% { transform: translateY(-22px); }
  100% { transform: translateY(0); }
}
```

`coinSpin` / `shadowPulse` keyframes 本體不動（時長由呼叫處 0.45s 決定）。

- [ ] **Step 2: 靜態驗證 CSS 生效**

Run: `python3 -m http.server 8000`（workdir `/Users/nx/Documents/6yao`），瀏覽器開 `http://localhost:8000`，檢查 `.coins` 下方有托盤橢圓、無主控台錯誤。
Expected: 有托盤、無報錯（尚未驗動畫）。

- [ ] **Step 3: Commit**

```bash
git add index.html && git commit -m "feat(web): 硯台托盤 + 0.45s 落錢跳動 CSS"
```

---

### Task 2: JS 節奏 + delay 清理（修不順核心）

**Files:**
- Modify: `/Users/nx/Documents/6yao/index.html:988-997`（`renderCoins`）
- Modify: `/Users/nx/Documents/6yao/index.html:1024-1031`（toss 迴圈）

**Interfaces:**
- Consumes: Task 1 的 `.toss` CSS。
- Produces: 每爻 650ms 節奏 + 無殘留 delay，供 Task 3 驗收。

- [ ] **Step 1: 改 `renderCoins` 加清理**

舊碼：

```js
function renderCoins(coins) {
  const faces = $('coinsBox').querySelectorAll('.coin');
  faces.forEach((c, i) => {
    c.querySelector('.face').textContent = coins && coins[i] ? '背' : '字';
    c.classList.remove('toss');
    void c.offsetWidth;
    c.style.animationDelay = `${i * 80}ms`;
    c.classList.add('toss');
  });
}
```

新碼：

```js
function renderCoins(coins) {
  const faces = $('coinsBox').querySelectorAll('.coin');
  faces.forEach((c, i) => {
    c.querySelector('.face').textContent = coins && coins[i] ? '背' : '字';
    c.classList.remove('toss');
    void c.offsetWidth;
    c.style.animationDelay = `${i * 80}ms`;
    c.classList.add('toss');
    setTimeout(() => { c.style.animationDelay = ''; }, 600);
  });
}
```

- [ ] **Step 2: 改 toss 迴圈節奏**

舊碼：

```js
      lines.push(tossThreeCoins());
      renderCoins(lines[i].coins);
      await sleep(480);
      renderLines(true);
      await sleep(420);
```

新碼：

```js
      lines.push(tossThreeCoins());
      renderCoins(lines[i].coins);
      await sleep(350);
      renderLines(true);
      await sleep(300);
```

- [ ] **Step 3: 功能驗收（手動，即本 plan 的 test）**

Run: 瀏覽器開 `http://localhost:8000`，連點「擲銅錢」3 次。
Expected: 每次約 3.9s 完成；三錢 stagger 可見；定面背/字可讀；爻線自下而上；`—/○` 為陽、`- -/×` 為陰；動爻朱砂發光；無越跳越亂；主控台無錯誤。

- [ ] **Step 4: Commit**

```bash
git add index.html && git commit -m "feat(web): 落錢節奏 650ms/爻 + 清 animationDelay"
```

---

### Task 3: 降級與迴歸驗收 + 收尾

**Files:**
- Modify: `/Users/nx/Documents/6yao/index.html:399-401`（僅當托盤/跳動未被既有 `reduce` 全域關閉涵蓋時才改；既有 `*{animation-duration:0.01ms}` 已涵蓋則免改，只驗證）

**Interfaces:**
- Consumes: Task 1+2 成果。
- Produces: 可合併的最終狀態。

- [ ] **Step 1: reduced-motion 驗證**

Run: 瀏覽器（或 DevTools rendering 模擬）開啟 `prefers-reduced-motion: reduce`，點「擲銅錢」。
Expected: 無跳動/翻轉，直接出 6 爻結果 + 書籤。

- [ ] **Step 2: 迴歸驗證**

Run: 報數起卦 1 次（隨意三數如 8/8/6）；undo/reset 各 1 次；若有歷史則還原 1 筆。
Expected: 報數不觸發銅錢動畫；undo/reset 靜態；歷史還原靜態顯示；無報錯。

- [ ] **Step 3: 最終 Commit（如有改動）**

```bash
git status --short && git log --oneline -5
```

有改動才 commit：

```bash
git add index.html && git commit -m "fix(web): reduced-motion 托盤降級"
```

無改動則不 commit。
