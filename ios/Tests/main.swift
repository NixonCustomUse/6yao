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

print("\n\(pass) passed, \(fail) failed")
exit(fail == 0 ? 0 : 1)