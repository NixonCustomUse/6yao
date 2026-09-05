# iOS 版 UI/UX 優化 — 設計文件

日期：2026-09-01
狀態：已與使用者確認設計方向

## 目標

對 iOS 六爻排盤 App 進行三項 UI/UX 優化：動畫與轉場、觸覺回饋、深色模式。獨立升級，不對齊網頁版，以原生 iOS 手感為依歸，維持「文人書齋·宣紙朱砂」風格。

## 1. 動畫與轉場

### 現狀問題

- `spin += 360` 累計無限增長，精度會飄
- 所有轉場用 `easeOut`，無彈性物理感
- 書籤走 `.sheet` 預設轉場，無自訂
- 無交錯（stagger）動畫，缺少鬆弛感

### 設計

| 項目 | 作法 |
|---|---|
| 擲銅錢 | 改用 `withAnimation(.spring)` 搭配 `rotation3DEffect`，每次擲完歸零 spin 避免溢位；每次擲出時 coin 有輕微彈跳 scale 效果 |
| 爻行出現 | `.transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity), removal: .opacity))` + spring；每爻依序延遲 `delay * i`（delay 0.08s）交錯入場 |
| 模式切換 | 朱色 active 指示器使用 `matchedGeometryEffect` 平滑滑動 |
| 書籤彈窗 | 移除 `.sheet`，改為自訂 overlay：`transition(.move(edge: .bottom).combined(with: .opacity))` + spring；內容卡片加入 fadeUp + stampIn 效果（`scale 0.92 → 1.0` + `opacity 0 → 1`） |
| 註釋卡片 | 保留 bottom slide，改用 spring |
| 預設曲線 | `.spring(response: 0.42, dampingFraction: 0.78)` 作為全 App 預設彈性曲線，營造鬆弛感 |

### 鬆弛感關鍵

- damping 偏中高（0.78）讓彈性不突兀
- response 略長（0.42）讓動作不急躁
- 所有 transition 統一使用同一曲線，保持一致性

## 2. 觸覺回饋

### 現狀問題

- 只有 `UIImpactFeedbackGenerator(.light)` 一種
- 僅在 `startCasting()` 和 `castNumbers()` 使用

### 設計

`HapticManager` 類別統一管理三種反饋類型：

- `impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat)` — 按壓感
- `notification(_ type: UINotificationFeedbackGenerator.FeedbackType)` — 事件完成
- `selection()` — 選項更動

### 場景配置

| 事件 | 反饋類型 | 備註 |
|---|---|---|
| 每擲一爻 | impact light | 強度 random 0.4-0.7 模擬銅錢著地差異 |
| 六爻擲畢 | notification success | 輕柔 |
| 報數起卦按鈕 | impact light | 強度 0.5 |
| 退一爻 / 重新起卦 | impact light | 強度 0.4 |
| 用神選單切換 | selection | — |
| 書籤彈出 | impact medium | 強度 0.6 |
| 書籤關閉 | impact light | 強度 0.3 |

### 可開關

- 使用 `@AppStorage("hapticEnabled")` 預設 true
- HapticManager 內部檢查 flag，關閉時跳過所有反饋
- 在 App 內加入設定入口（簡易 toggle）

### 預熱

- `HapticManager.prepare()` 在 ContentView appear 時呼叫，避免首次延遲

## 3. 深色模式

### 現狀問題

- `.preferredColorScheme(.light)` 鎖死亮色
- 16 組顏色皆無暗色變體

### 設計

- 移除 `.preferredColorScheme(.light)`，使用系統自動切換
- 每組顏色定義暗色變體，維持文人書齋溫暖感

### 色彩對應表

| 角色 | 亮色 hex | 暗色 hex | 說明 |
|---|---|---|---|
| paper | `#F2ECE0` | `#1C1A17` | 底紙，暗色微暖不刺眼 |
| paper2 | `#F9F5EA` | `#24221E` | 卡片紙 |
| paper3 | `#E9E1CF` | `#2E2B26` | 按壓/背景 |
| ink | `#2B2620` | `#E0D8CC` | 主文字 |
| ink2 | `#5B5346` | `#B0A79A` | 次要文字 |
| ink3 | `#948B7B` | `#7A7266` | 輔助文字 |
| line | `#D8CDB6` | `#3D3830` | 分隔線 |
| line2 | `#C2B495` | `#4C463D` | 邊框 |
| cinnabar | `#A63B2A` | `#D4634F` | 朱砂，暗底略亮 |
| cinnabarDeep | `#7D2A1C` | `#B84A37` | 朱砂深色 |
| cinnabarSoft | `#F4E3DB` | `#3A2825` | 朱砂淺底 |
| gold | `#C99D4F` | `#D4B06A` | 穗帶，暗底略亮 |

### 實作方式

- `Color` extension 新增 `init(light:dark:)`，內部使用 `UIColor` 的 `init(dynamicProvider:)`
- 所有現有 `Color` static 屬性改為計算屬性，依賴 `Color(light:dark:)`

### 額外細節

- 暗色模式下 paper 層加 0.5pt 極細邊框模擬紙張邊緣，維持層次感

## 範圍外（YAGNI）

- 不支援動態字型大小（Dynamic Type）變更動畫
- 不做深色模式手動切換開關（僅跟隨系統）
- 不做減少了動畫（reduce motion）偵測

## 實作位置

全部在 `/Users/nx/Documents/6yao/ios/Sources/` 內：

- `Theme.swift` — 暗色 Color 定義、HapticManager
- `Views/CastViews.swift` — 銅錢動畫、爻行交錯、模式切換 matchedGeometry
- `Views/ResultViews.swift` — 無變動（動畫在 ContentView 層級）
- `Views/BookmarkSheet.swift` — 書籤自訂轉場動畫
- `Views/ContentView.swift` — overlay 書籤、預設 spring 動畫、觸覺預熱
- `AppModel.swift` — 觸覺回饋呼叫點
- `SixYaoApp.swift` — 移除 light mode 鎖