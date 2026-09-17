# 竹筒搖出銅錢動畫 — 設計文件（網頁版先行）

日期：2026-09-17
狀態：已與使用者確認（銅錢改為 C 竹筒搖出；爻線水墨成爻保留；範圍：僅 Web `index.html`，iOS 不動）

## 目標

銅錢區新增竹筒（純 CSS 竹節筒 + 筒口，閒置即為裝飾）：每擲筒身搖三下（rotate ±10°→0，0.36s），三錢以 0/70/140ms 先後彈起 -16px + 單周翻轉落定（0.4s），如應聲而出。節奏維持每爻 650ms、共約 3.9s；零依賴、transform/opacity only；全域 `prefers-reduced-motion` 照舊降級。

## 變更點（僅 index.html）

- HTML：`#coinsBox` 內加 `#tube`（竹筒）置頂，三 `.coin` 包入 `.coin-row`
- CSS（`#anim-polish`）：`.coins` 改直列置中；新增 `.tube` 竹紋/筒口/竹節 + `.shake`/`tubeShake`；`.coin.toss` 改 `coinPop`（-16px/0.4s，取代 `coinJump`）；`coinSpin`/`shadowPulse`/托盤/水墨爻線沿用；mobile 加 `.coin-row{gap:16px}`、筒縮小
- JS：`renderCoins` 每擲重觸 `.shake`（remove→reflow→add），錢 stagger 改 70ms，delay 清理沿用；undo/reset 照舊觸發（筒跟著輕搖，視為回饋）
- 不動：起卦邏輯、爻線水墨（brush/inkWash/蓋印）、排盤、書籤、歷史、報數、iOS

## 驗收（Web）

- 連擲 3 次：筒搖三下可見、三錢先後彈出、定面背/字可讀、爻線水墨照舊、無殘留 delay
- reduced-motion：靜態；報數/歷史還原：靜態（筒僅裝飾不搖）
