# 六爻排盤

> 文人書齋 · 宣紙朱砂 — 六爻占卜的網頁版與 iOS 原生實作

以三枚銅錢起卦，排本卦／變卦、世應、六親、六神、旬空與日辰，並依用神旺衰給出吉凶分級與文言／白話解讀。無後端、無依賴，開箱即用。

---

## 功能

| 能力 | 說明 |
|---|---|
| **搖錢起卦** | 擲三枚銅錢六次（○老陽／—少陽／– –少陰／×老陰），自初爻而上 |
| **報數起卦** | 三數起卦：上卦／下卦／動爻（除 8／除 6 取餘） |
| **排盤** | 本卦／變卦、宮位、世應、六親（父母／兄弟／子孫／妻財／官鬼）、六神（青龍～玄武）、旬空標記 |
| **吉凶分級** | `computeGrade` 以用神為主、日辰生剋為輔：上上／上吉／中吉／中平 |
| **解讀** | 卦辭／象曰／爻辭（文言）＋白話籤文；乾／坤六爻全動的用九／用六 |
| **籤文書籤** | 起卦完成自動彈出直式書籤卡（卦名／分級／卦畫／文言／白話），可重開 |
| **註釋** | 地支／六親／六神／世應等皆可 hover（網頁）／tap（iOS）查看說明 |
| **占日** | 依所選日期推干支、旬空、月建；影響六神起點與吉凶判斷 |
| **深色模式** | iOS 版支援系統深色外觀（`Color(light:dark:)`）；網頁版固定亮色宣紙 |

---

## 專案結構

```
6yao/
├── index.html                          # 網頁版 — 單檔（HTML/CSS/JS/資料一體，約 100KB / 1141 行）
├── ios/                                # iOS 版 — SwiftUI
│   ├── 六爻.xcodeproj
│   ├── Sources/
│   │   ├── SixYaoApp.swift             # App 入口
│   │   ├── AppModel.swift              # 狀態與起卦流程（含觸覺回饋）
│   │   ├── Engine.swift                # 排盤引擎（靜態表＋純函式，與網頁版同源）
│   │   ├── Models.swift                # Codable 模型與計算結構
│   │   ├── Theme.swift                 # 亮/暗色定義、共用樣式、HapticManager
│   │   ├── Resources/
│   │   │   ├── hexagram_table.json     # 64 卦對照（宮／世／應）
│   │   │   ├── yijing.json             # 卦辭／象曰／爻辭／卦意
│   │   │   └── bai.json                # 白話籤文
│   │   └── Views/
│   │       ├── ContentView.swift       # 頁面骨架、header、模式切換、書籤入口
│   │       ├── CastViews.swift         # 搖錢／報數起卦、銅錢動畫、爻行
│   │       ├── ResultViews.swift       # 排盤欄、白話解讀
│   │       └── BookmarkSheet.swift     # 書籤卡片（Overlay + 卡面）
│   └── Tests/
│       └── main.swift                  # 17 項邏輯測試（與網頁版向量一致）
└── docs/superpowers/specs/
    ├── 2026-08-20-bookmark-slip-design.md
    └── 2026-09-01-ios-ux-enhancement.md
```

---

## 快速開始

### 網頁版

零建置步驟，直接用瀏覽器開啟即可：

```bash
open index.html
# 或
python3 -m http.server 8000
# 瀏覽器開 http://localhost:8000
```

- 依賴：無（僅 CDN 載入 `LXGW WenKai` 字型）
- 支援現代瀏覽器；排版以 780px 內容寬度為基準

### iOS 版

需求：Xcode 15+、iOS 17+

```bash
open ios/六爻.xcodeproj
# 選擇模擬器或實機 → Run
```

- 純 SwiftUI，無第三方依賴
- 顏色透過 `Color(light:dark:)` 自動跟隨系統深/淺色

---

## 技術說明

### 資料

- `HEXAGRAM_TABLE` — 64 卦的 `upper+lower → { name, palace, shi, ying }`
- `TRIGRAM` — 八宮的五行與內外卦地支
- `YIJING` / `BAI` — 卦辭、象曰、六爻辭與白話對譯（64 × 7 條）
- `JIEQI` — 簡化節氣表，用於推月建

網頁版資料內嵌於 `index.html`；iOS 版為同源 JSON（`Sources/Resources/*.json`）。

### 核心邏輯（`Engine.swift` / `index.html` 內 JS）

```
三枚銅錢 → backs 計數 → 符號（○/—/– –/×）與動靜
        → trigramFromBits → buildHexagram → cast（翻動爻得變卦）
        → 六親（宮五行 vs 爻支五行，生剋比和）
        → 六神（日干起青龍順排）
        → 旬空（日柱旬首推兩支）
        → 吉凶（computeGrade：旬空→中平／用神動→上上／日辰生扶→上吉／受剋→中平／餘→中吉）
```

日柱以 `JDN → (JDN+49)%60` 推干支，與 JS `Date.UTC` 向量對齊；iOS 版等價以 `Calendar(gregorian, UTC)` 計算。

---

## 設計文件

- `docs/superpowers/specs/2026-08-20-bookmark-slip-design.md` — 籤文書籤卡片（版面、互動、分級規則）
- `docs/superpowers/specs/2026-09-01-ios-ux-enhancement.md` — iOS 動畫/轉場、觸覺回饋、深色模式

---

## 測試

iOS 邏輯測試為獨立 harness（無 XCTest 依賴），覆蓋 BAI 完整性、世應、變卦、旬空、爻位名、日期向量、月建、吉凶分級與解讀文本：

```bash
cd ios
swiftc -o /tmp/6yao-test Sources/Models.swift Sources/Engine.swift Tests/main.swift && /tmp/6yao-test
# 預期：17 項全 PASS
```

---

## 授權

未標示授權。若需對外發布，請補上 `LICENSE`。
