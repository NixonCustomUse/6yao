# 水墨成爻擲爻動畫 — 設計文件（網頁版先行）

日期：2026-09-17
狀態：已與使用者確認（方案 B 水墨成爻，範圍：僅 Web `index.html`，iOS 不動）
前情：方案 A 硯台落錢已上線（e297c8f）；本次迭代為 B 版，主角從銅錢換成筆墨爻線。

## 目標

每擲一次以毛筆一劃成爻：陽實線一筆、陰斷線兩筆分先後（差 90ms），動爻蓋朱砂印（○/× 用 stampIn 蓋印動畫），新爻行襯一筆淡墨（inkWash 0.6s）。銅錢退為配角：輕點 -12px + 0.38s 短翻轉。節奏沿用 A 版（每爻 650ms、共約 3.9s），零依賴、transform/opacity 為主（外加短暫小 blur 收斂）、`prefers-reduced-motion` 沿用全域降級。

## 變更點（僅 index.html）

- CSS：`coinJump` 改 -12px/0.38s；`barGrow` 加 `blur(3px)→0` 筆墨收斂（含書籤 `.bmk-bar` 同沾光）；陰第二筆 `.line-draw .bar.yin.grow:nth-of-type(2)` 延 90ms；`.move-mark` 加 `stampIn 0.4s` 蓋印；新增 `.line-box.fresh` + `inkWash` 淡墨襯底
- JS：`renderLines` 僅對 `animateLast` 的末爻行加 `fresh` 類；其餘（toss 迴圈 350+300ms、delay 清理、托盤）沿用 A 版不變
- 不動：起卦邏輯、排盤、書籤、歷史、報數、iOS

## 驗收（Web）

- 連擲 3 次：爻線如筆劃長出、陰兩段先後、動爻蓋印、淡墨只閃最新一爻、無殘留 delay
- reduced-motion：直接出結果；報數/歷史還原：靜態
