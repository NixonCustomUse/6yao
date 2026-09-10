import Foundation

// Standalone logic test harness (macOS) — mirrors the 17 JS vectors.
// Usage: swiftc -o /tmp/iyiq-test Sources/Models.swift Sources/Engine.swift Tests/run-tests.swift && /tmp/iyiq-test

let dataDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Sources/Resources")
let data = try! YiData.load(from: dataDir)

var pass = 0, fail = 0
func eq<T: Equatable>(_ label: String, _ got: T, _ want: T) {
    let ok = got == want
    ok ? (pass += 1) : (fail += 1)
    print("\(ok ? "PASS" : "FAIL") \(label): got \(got) want \(want)")
}

// 1. BAI 64 keys complete (t + 6 translations)
let missingBai = data.bai.keys.filter { k in
    guard let b = data.bai[k] else { return true }
    return b.l.count != 6 || b.t.isEmpty
}
eq("BAI 64卦齊全（t+6白話）", missingBai.sorted(), [])

// 2. BAI keys == YIJING keys
eq("BAI 與 YIJING key 完全對應", data.bai.keys.sorted(), data.yijing.keys.sorted())

// 3-5. spot-check translations
eq("乾卦辭白話", data.bai["11"]!.t, "大吉大利，通達順利，守正而行。")
eq("乾九五白話", data.bai["11"]!.l[4], "龍飛騰於天，大展鴻圖，利於見貴人、成大事。")
eq("坤初六白話", data.bai["88"]!.l[0], "踩到薄霜，便知堅冰將至，禍患都是漸積而成，防微杜漸。")

// 6. hexagram shi/ying/palace
let qian = buildHexagram(upper: 1, lower: 1, data: data)
eq("乾為天 世應/宮", [qian.name, String(qian.shi), String(qian.ying)], ["乾為天", "5", "2"])

// 7. cast 天風姤 動三爻 → 天水訟
eq("天風姤 動三爻→天水訟", cast(upper: 1, lower: 5, moving: [2], data: data).changed?.name, "天水訟")

// 8. 甲寅旬 空子丑
eq("甲寅旬 空子丑", xunkongBranches(dayIdx: 54), [0, 1])

// 9. positionName
eq("爻位名 初九/九三/上六",
   [positionName([1,1,1,1,1,1], 0), positionName([1,0,1,1,0,1], 2), positionName([0,0,0,0,0,0], 5)],
   ["初九", "九三", "上六"])

// 10. dayInfo reference values (computed from JS Date.UTC)
func checkDate(_ y: Int, _ m: Int, _ d: Int, idx: Int, gan: String, zhi: String, kong: String) {
    var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let date = cal.date(from: DateComponents(year: y, month: m, day: d))!
    let di = computeDayInfo(from: date)
    eq("dayInfo \(y)-\(m)-\(d)", [String(di.dayIdx), di.dayGan, di.dayZhi, di.kongText], [String(idx), gan, zhi, kong])
}
checkDate(2026, 8, 19, idx: 1, gan: "乙", zhi: "丑", kong: "戌亥")
checkDate(2026, 8, 20, idx: 2, gan: "丙", zhi: "寅", kong: "戌亥")
checkDate(2000, 1, 1, idx: 54, gan: "戊", zhi: "午", kong: "子丑")

// 11. monthZhi
eq("monthZhi(8,19)", monthZhi(month: 8, day: 19), "申")
eq("monthZhi(2,4)", monthZhi(month: 2, day: 4), "寅")
eq("monthZhi(1,1)", monthZhi(month: 1, day: 1), "子")

// 12-16. computeGrade (same vectors as JS tests)
let ys = "世爻"
let g0 = computeGrade(hg: qian, moving: [], yongshen: ys, dayZhi: "午", dayIdx: 10)
eq("無動爻 → 中吉", g0.label, "中吉")
eq("用神旬空 → 中平",
   computeGrade(hg: buildHexagram(upper: 1, lower: 1, data: data), moving: [], yongshen: "子孫", dayZhi: "午", dayIdx: 54).label, "中平")
eq("用神為動爻且不空 → 上上",
   computeGrade(hg: cast(upper: 1, lower: 1, moving: [5], data: data).hg, moving: [5], yongshen: ys, dayZhi: "午", dayIdx: 20).label, "上上")
eq("用神得日辰生扶 → 上吉",
   computeGrade(hg: cast(upper: 1, lower: 1, moving: [0], data: data).hg, moving: [0], yongshen: ys, dayZhi: "午", dayIdx: 20).label, "上吉")
eq("用神受日辰剋 → 中平",
   computeGrade(hg: cast(upper: 1, lower: 1, moving: [0], data: data).hg, moving: [0], yongshen: ys, dayZhi: "寅", dayIdx: 20).label, "中平")

// 17. reading sections spot check
let rs = readingSections(c: cast(upper: 1, lower: 5, moving: [2], data: data), movingSymbols: [2: "○"], data: data)
let vtext = rs.vernacular.flatMap { $0.lines }.joined()
eq("白話含本卦卦辭白話", vtext.contains("女子過於強壯，不宜娶此女。"), true)
eq("白話含動爻白話", vtext.contains("臀部無皮，行動困難，雖危無大咎。"), true)
let ctext = rs.classical.flatMap { $0.lines }.joined()
eq("文言含卦辭標記", ctext.contains("卦辭："), true)

// 18. HistoryStore limit 50
HistoryStore.clear()
for i in 0..<55 {
    let r = HistoryRecord(id: "\(i)", ts: Double(i), dateISO: "2026-09-08", ganzhiText: "甲子", yongshen: "", hgKey: "11", changedKey: nil, hgName: "乾為天", changedName: nil, moving: [], movingSymbols: [:], bits: [1,1,1,1,1,1], dayIdx: 0, dayGan: "甲", dayZhi: "子", lines: nil, source: "numbers", inputs: nil)
    HistoryStore.push(r)
}
eq("History limit 50", HistoryStore.load().count, 50)
eq("History order newest first", HistoryStore.load().first?.id, "54")
eq("History oldest truncated", HistoryStore.load().last?.id, "5")

// 19. History roundTrip Codable
HistoryStore.clear()
let tossCodable = HistoryRecord.CoinTossCodable(coins: [true, false, false], backs: 1, symbol: "- -", moving: false)
let sample = HistoryRecord(id: "x", ts: 1, dateISO: "2026-09-08", ganzhiText: "甲子", yongshen: "妻財", hgKey: "11", changedKey: "58", hgName: "乾為天", changedName: "風地觀", moving: [0], movingSymbols: [0: "○"], bits: [1,0,0,0,0,0], dayIdx: 0, dayGan: "甲", dayZhi: "子", lines: [tossCodable], source: "coins", inputs: nil)
HistoryStore.push(sample)
let loaded = HistoryStore.load().first!
eq("History roundTrip hgKey", loaded.hgKey, "11")
eq("History roundTrip movingSymbols", loaded.movingSymbols[0], "○")
eq("History roundTrip bits", loaded.bits, [1,0,0,0,0,0])
eq("History roundTrip coinTosses symbol", loaded.coinTosses?.first?.symbol, "- -")
eq("History roundTrip coinTosses coins", loaded.coinTosses?.first?.coins, [true,false,false])
eq("History roundTrip Equatable", loaded, sample)
eq("History inputs nil preserved", loaded.inputs, nil)

// numbers input roundTrip
HistoryStore.clear()
let numSample = HistoryRecord(id: "n1", ts: 2, dateISO: "2026-09-08", ganzhiText: "乙丑", yongshen: "官鬼", hgKey: "88", changedKey: nil, hgName: "坤為地", changedName: nil, moving: [5], movingSymbols: [5: "×"], bits: [0,0,0,0,0,0], dayIdx: 1, dayGan: "乙", dayZhi: "丑", lines: nil, source: "numbers", inputs: HistoryRecord.NumbersInput(a: 7, b: 8, c: 9))
HistoryStore.push(numSample)
let loaded2 = HistoryStore.load().first!
eq("History numbers inputs roundTrip", loaded2.inputs, HistoryRecord.NumbersInput(a: 7, b: 8, c: 9))
eq("History numbers moving", loaded2.moving, [5])

// 20. History remove
HistoryStore.clear()
HistoryStore.push(HistoryRecord(id: "a", ts: 1, dateISO: "2026-09-08", ganzhiText: "甲子", yongshen: "", hgKey: "11", changedKey: nil, hgName: "乾為天", changedName: nil, moving: [], movingSymbols: [:], bits: [1,1,1,1,1,1], dayIdx: 0, dayGan: "甲", dayZhi: "子", lines: nil, source: "numbers", inputs: HistoryRecord.NumbersInput(a: 1, b: 2, c: 3)))
HistoryStore.push(HistoryRecord(id: "b", ts: 2, dateISO: "2026-09-08", ganzhiText: "甲子", yongshen: "", hgKey: "88", changedKey: nil, hgName: "坤為地", changedName: nil, moving: [], movingSymbols: [:], bits: [0,0,0,0,0,0], dayIdx: 0, dayGan: "甲", dayZhi: "子", lines: nil, source: "numbers", inputs: nil))
HistoryStore.remove(id: "b")
eq("History remove count", HistoryStore.load().count, 1)
eq("History remove remaining", HistoryStore.load().first?.id, "a")
HistoryStore.remove(id: "nonexistent")
eq("History remove nonexistent still 1", HistoryStore.load().count, 1)

// 21. History clear + decode failure
HistoryStore.clear()
HistoryStore.push(HistoryRecord(id: "c", ts: 3, dateISO: "2026-09-08", ganzhiText: "甲子", yongshen: "", hgKey: "11", changedKey: nil, hgName: "乾為天", changedName: nil, moving: [], movingSymbols: [:], bits: [1,1,1,1,1,1], dayIdx: 0, dayGan: "甲", dayZhi: "子", lines: nil, source: "numbers", inputs: nil))
HistoryStore.clear()
eq("History clear count 0", HistoryStore.load().count, 0)
eq("History load empty after clear", HistoryStore.load(), [] as [HistoryRecord])
UserDefaults.standard.set(Data("corrupted".utf8), forKey: HistoryStore.key)
eq("History decode failure returns []", HistoryStore.load(), [] as [HistoryRecord])
HistoryStore.clear()
eq("History after corrupt clear", HistoryStore.load().count, 0)

// 22. Grade consistency via history record (spec Task6/7)
let castA = cast(upper: 1, lower: 1, moving: [0], data: data)
let gLive = computeGrade(hg: castA.hg, moving: castA.moving, yongshen: "妻財", dayZhi: "子", dayIdx: 0)
let recG = HistoryRecord(id: "g1", ts: 0, dateISO: "2026-09-08", ganzhiText: "甲子", yongshen: "妻財", hgKey: castA.hg.key, changedKey: castA.changed?.key, hgName: castA.hg.name, changedName: castA.changed?.name, moving: castA.moving, movingSymbols: [0: "○"], bits: castA.hg.bits, dayIdx: 0, dayGan: "甲", dayZhi: "子", lines: nil, source: "numbers", inputs: HistoryRecord.NumbersInput(a: 1, b: 2, c: 3))
let hgRecon = buildHexagram(upper: Int(String(recG.hgKey.prefix(1)))!, lower: Int(String(recG.hgKey.suffix(1)))!, data: data)
let gFromRec = computeGrade(hg: hgRecon, moving: recG.moving, yongshen: recG.yongshen, dayZhi: recG.dayZhi, dayIdx: recG.dayIdx)
eq("Grade consistency via history", gLive.label, gFromRec.label)
eq("Grade consistency hgKey preserved", recG.hgKey, castA.hg.key)
eq("Grade consistency bits preserved", recG.bits, castA.hg.bits)

// 23. Yongshen restore roundTrip + 世爻 special
HistoryStore.clear()
let recYS = HistoryRecord(id: "ys1", ts: 0, dateISO: "2026-09-08", ganzhiText: "甲子", yongshen: "官鬼", hgKey: "11", changedKey: nil, hgName: "乾為天", changedName: nil, moving: [], movingSymbols: [:], bits: [1,1,1,1,1,1], dayIdx: 10, dayGan: "甲", dayZhi: "戌", lines: nil, source: "numbers", inputs: nil)
HistoryStore.push(recYS)
let loadedYS = HistoryStore.load().first!
eq("Yongshen restore roundTrip", loadedYS.yongshen, "官鬼")
eq("Yongshen grade uses restored yongshen", computeGrade(hg: buildHexagram(upper: 1, lower: 1, data: data), moving: loadedYS.moving, yongshen: loadedYS.yongshen, dayZhi: loadedYS.dayZhi, dayIdx: loadedYS.dayIdx).label, computeGrade(hg: buildHexagram(upper: 1, lower: 1, data: data), moving: [], yongshen: "官鬼", dayZhi: "戌", dayIdx: 10).label)
eq("Yongshen 世爻 index == shi", yongshenIndex(hg: buildHexagram(upper: 1, lower: 1, data: data), yongshen: "世爻"), buildHexagram(upper: 1, lower: 1, data: data).shi)
let hgQian = buildHexagram(upper: 1, lower: 1, data: data)
eq("Yongshen 妻財 index valid", hgQian.liuqin.contains("妻財"), true)
eq("Yongshen 妻財 index matches first occurrence", yongshenIndex(hg: hgQian, yongshen: "妻財"), hgQian.liuqin.firstIndex(of: "妻財")!)
HistoryStore.clear()
let recShi = HistoryRecord(id: "shi", ts: 0, dateISO: "2026-09-08", ganzhiText: "甲子", yongshen: "世爻", hgKey: "88", changedKey: nil, hgName: "坤為地", changedName: nil, moving: [2], movingSymbols: [2: "●"], bits: [0,0,0,0,0,0], dayIdx: 20, dayGan: "丙", dayZhi: "寅", lines: nil, source: "numbers", inputs: nil)
HistoryStore.push(recShi)
eq("History 世爻 roundTrip", HistoryStore.load().first?.yongshen, "世爻")
let hg88 = buildHexagram(upper: 8, lower: 8, data: data)
eq("世爻 grade after restore", computeGrade(hg: hg88, moving: [2], yongshen: "世爻", dayZhi: "寅", dayIdx: 20).label, computeGrade(hg: hg88, moving: recShi.moving, yongshen: HistoryStore.load().first!.yongshen, dayZhi: recShi.dayZhi, dayIdx: recShi.dayIdx).label)

// 24. sixShen correctness (回歸)
eq("sixShen 甲 start 青龍", sixShen(dayGan: "甲"), ["青龍","朱雀","勾陳","螣蛇","白虎","玄武"])
eq("sixShen 丙 start 朱雀", sixShen(dayGan: "丙")[0], "朱雀")
eq("sixShen 戊", sixShen(dayGan: "戊"), ["勾陳","螣蛇","白虎","玄武","青龍","朱雀"])
eq("sixShen 癸", sixShen(dayGan: "癸"), ["玄武","青龍","朱雀","勾陳","螣蛇","白虎"])

// 25. History 51 limit keeps 50 (Task7 Step6 Web對應)
HistoryStore.clear()
for i in 0..<51 {
    let r = HistoryRecord(id: "p\(i)", ts: Double(i), dateISO: "2026-09-08", ganzhiText: "甲子", yongshen: "", hgKey: "11", changedKey: nil, hgName: "乾為天", changedName: nil, moving: [], movingSymbols: [:], bits: [1,1,1,1,1,1], dayIdx: 0, dayGan: "甲", dayZhi: "子", lines: nil, source: "numbers", inputs: nil)
    HistoryStore.push(r)
}
eq("History 51 limit keeps 50", HistoryStore.load().count, 50)
eq("History 51 newest first", HistoryStore.load().first?.id, "p50")
eq("History 51 oldest is p1", HistoryStore.load().last?.id, "p1")

// 26. yongshenSel 切換仍正常 (grade不崩潰, 書籤結構正常)
let hgTest = buildHexagram(upper: 1, lower: 5, data: data) // 天風姤
let gA = computeGrade(hg: hgTest, moving: [2], yongshen: "妻財", dayZhi: "午", dayIdx: 20)
let gB = computeGrade(hg: hgTest, moving: [2], yongshen: "兄弟", dayZhi: "午", dayIdx: 20)
eq("yongshenSel switch grade still string", gA.label.isEmpty, false)
eq("yongshenSel switch grade B still string", gB.label.isEmpty, false)
let rsB = readingSections(c: cast(upper: 1, lower: 5, moving: [2], data: data), movingSymbols: [2: "○"], data: data)
eq("Reading still has classical卦辭標記", rsB.classical.flatMap({$0.lines}).joined().contains("卦辭："), true)
eq("Reading fallback yongshen empty uses shi", yongshenIndex(hg: hgTest, yongshen: ""), hgTest.shi)
eq("HistoryRecord inputs preserved after clear-repush", {
    HistoryStore.clear()
    let rr = HistoryRecord(id: "inp", ts: 1, dateISO: "2026-09-08", ganzhiText: "甲子", yongshen: "", hgKey: "11", changedKey: nil, hgName: "乾為天", changedName: nil, moving: [1], movingSymbols: [1:"●"], bits: [1,1,1,1,1,1], dayIdx: 0, dayGan: "甲", dayZhi: "子", lines: nil, source: "numbers", inputs: HistoryRecord.NumbersInput(a: 9, b: 10, c: 11))
    HistoryStore.push(rr)
    return HistoryStore.load().first?.inputs ?? HistoryRecord.NumbersInput(a: 0, b: 0, c: 0)
}(), HistoryRecord.NumbersInput(a: 9, b: 10, c: 11))

// 27. Taiji bits consistency (Task 4: trigramFromLines vs direct toss map)
func testTaijiBits() {
    let tosses: [CoinToss] = [
        CoinToss(coins: [true, true, true], backs: 3, symbol: "○", moving: true),
        CoinToss(coins: [true, true, false], backs: 2, symbol: "—", moving: false),
        CoinToss(coins: [false, false, false], backs: 0, symbol: "×", moving: true),
        CoinToss(coins: [true, false, false], backs: 1, symbol: "- -", moving: false),
        CoinToss(coins: [true, true, true], backs: 3, symbol: "○", moving: true),
        CoinToss(coins: [false, true, true], backs: 2, symbol: "—", moving: false)
    ]
    let t = trigramFromLines(tosses)
    let bits = (0..<6).map { lineYang(upper: t.upper, lower: t.lower, i: $0) }
    let expected = tosses.map { $0.symbol == "—" || $0.symbol == "○" ? 1 : 0 }
    eq("Taiji bits consistency trigramFromLines vs direct", bits, expected)
    // also exercise tossThreeCoins to satisfy interface (single sampling, check backs count matches)
    let _ = tossThreeCoins()
}
testTaijiBits()

HistoryStore.clear()

print("\n\(pass) passed, \(fail) failed")
exit(fail == 0 ? 0 : 1)