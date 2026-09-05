import Foundation

// MARK: - Static tables (ported from index.html)

let TRIGRAM: [Int: TrigramInfo] = [
    1: .init(name: "乾", five: "金", inner: ["子","寅","辰"], outer: ["午","申","戌"]),
    2: .init(name: "兌", five: "金", inner: ["巳","卯","丑"], outer: ["亥","酉","未"]),
    3: .init(name: "離", five: "火", inner: ["卯","丑","亥"], outer: ["酉","未","巳"]),
    4: .init(name: "震", five: "木", inner: ["子","寅","辰"], outer: ["午","申","戌"]),
    5: .init(name: "巽", five: "木", inner: ["丑","亥","酉"], outer: ["未","巳","卯"]),
    6: .init(name: "坎", five: "水", inner: ["寅","辰","午"], outer: ["申","戌","子"]),
    7: .init(name: "艮", five: "土", inner: ["辰","午","申"], outer: ["戌","子","寅"]),
    8: .init(name: "坤", five: "土", inner: ["未","巳","卯"], outer: ["丑","亥","酉"])
]

let TRIGRAM_BITS: [Int: [Int]] = [
    1: [1,1,1], 2: [1,1,0], 3: [1,0,1], 4: [1,0,0],
    5: [0,1,1], 6: [0,1,0], 7: [0,0,1], 8: [0,0,0]
]

let BITS_TO_TRIGRAM = [8, 7, 6, 5, 4, 3, 2, 1]

let LIUSHEN = ["青龍","朱雀","勾陳","螣蛇","白虎","玄武"]

let LIUSHEN_START: [String: Int] = ["甲":0,"乙":0,"丙":1,"丁":1,"戊":2,"己":3,"庚":4,"辛":4,"壬":5,"癸":5]

let WUXING_OF_BRANCH: [String: String] = ["子":"水","丑":"土","寅":"木","卯":"木","辰":"土","巳":"火","午":"火","未":"土","申":"金","酉":"金","戌":"土","亥":"水"]

let SHENG: [String: String] = ["金":"水","水":"木","木":"火","火":"土","土":"金"]
let KE: [String: String] = ["金":"木","木":"土","土":"水","水":"火","火":"金"]

let JIEQI: [(m: Int, d: Int, zhi: String)] = [
    (1,6,"丑"), (2,4,"寅"), (3,6,"卯"), (4,5,"辰"), (5,6,"巳"), (6,6,"午"),
    (7,7,"未"), (8,8,"申"), (9,8,"酉"), (10,8,"戌"), (11,7,"亥"), (12,7,"子")
]

let BRANCH_IDX: [String: Int] = ["子":0,"丑":1,"寅":2,"卯":3,"辰":4,"巳":5,"午":6,"未":7,"申":8,"酉":9,"戌":10,"亥":11]
let POS_NAME = ["初","二","三","四","五","上"]
let STEMS = Array("甲乙丙丁戊己庚辛壬癸")
let BRANCHES = Array("子丑寅卯辰巳午未申酉戌亥")

// MARK: - Notes (hover / tap annotations)

let SIXSHEN_NOTE: [String: String] = [
    "青龍":"主吉慶喜事、酒色財帛", "朱雀":"主口舌文書、言談爭訟", "勾陳":"主田土牢獄、遲滯牽連",
    "螣蛇":"主虛驚怪異、驚恐纏擾", "白虎":"主凶喪血光、刑傷急速", "玄武":"主暗昧盜賊、曖昧隱私"
]
let LIUQIN_NOTE: [String: String] = [
    "父母":"生我者，主長輩文書、保護庇蔭", "兄弟":"同我者，主同輩合夥、競爭破財",
    "子孫":"我生者，主子女晚輩、財源解厄", "妻財":"我剋者，主財帛俸祿、妻妾",
    "官鬼":"剋我者，主官非事業、壓力疾病"
]
let BRANCH_ZODIAC: [String: String] = ["子":"鼠","丑":"牛","寅":"虎","卯":"兔","辰":"龍","巳":"蛇","午":"馬","未":"羊","申":"猴","酉":"雞","戌":"狗","亥":"豬"]
let GRADE_NOTE: [String: String] = ["上上":"大吉，諸事順遂", "上吉":"吉利，可積極行動", "中吉":"平穩，謹慎可成", "中平":"事未定，宜守宜觀"]

func branchNote(_ b: String) -> String {
    "\(b)：\(BRANCH_ZODIAC[b] ?? "")，五行屬\(WUXING_OF_BRANCH[b] ?? "")"
}

// MARK: - Pure logic

func xunkongBranches(dayIdx: Int) -> [Int] {
    let start = (dayIdx / 10) * 10
    return [(start + 10) % 12, (start + 11) % 12]
}

func positionName(_ bits: [Int], _ i: Int) -> String {
    if i == 0 { return bits[i] == 1 ? "初九" : "初六" }
    if i == 5 { return bits[i] == 1 ? "上九" : "上六" }
    return (bits[i] == 1 ? "九" : "六") + POS_NAME[i]
}

func liuqin(palaceFive: String, lineFive: String) -> String {
    if lineFive == palaceFive { return "兄弟" }
    if SHENG[palaceFive] == lineFive { return "子孫" }
    if SHENG[lineFive] == palaceFive { return "父母" }
    if KE[palaceFive] == lineFive { return "妻財" }
    return "官鬼"
}

func sixShen(dayGan: String) -> [String] {
    let start = LIUSHEN_START[dayGan] ?? 0
    return (0..<6).map { LIUSHEN[(start + $0) % 6] }
}

func lineYang(upper: Int, lower: Int, i: Int) -> Int {
    let t = i < 3 ? lower : upper
    return (TRIGRAM_BITS[t] ?? [])[i % 3]
}

func trigramFromBits(_ b0: Int, _ b1: Int, _ b2: Int) -> Int {
    BITS_TO_TRIGRAM[b0 * 4 + b1 * 2 + b2]
}

func buildHexagram(upper: Int, lower: Int, data: YiData) -> Hexagram {
    let key = "\(upper)\(lower)"
    let entry = data.hexagramTable[key]!
    let u = TRIGRAM[upper]!
    let l = TRIGRAM[lower]!
    let palace = TRIGRAM[entry.palace]!
    let branches = l.inner + u.outer
    let bits = (0..<6).map { lineYang(upper: upper, lower: lower, i: $0) }
    let lq = branches.map { liuqin(palaceFive: palace.five, lineFive: WUXING_OF_BRANCH[$0] ?? "") }
    return Hexagram(key: key, name: entry.name, palace: palace.name, branches: branches, bits: bits, liuqin: lq, shi: entry.shi, ying: entry.ying)
}

func cast(upper: Int, lower: Int, moving: [Int], data: YiData) -> CastResult {
    let hg = buildHexagram(upper: upper, lower: lower, data: data)
    var changed: Hexagram? = nil
    if !moving.isEmpty {
        let bits = (0..<6).map { i in
            moving.contains(i) ? 1 - lineYang(upper: upper, lower: lower, i: i) : lineYang(upper: upper, lower: lower, i: i)
        }
        changed = buildHexagram(upper: trigramFromBits(bits[3], bits[4], bits[5]),
                                lower: trigramFromBits(bits[0], bits[1], bits[2]),
                                data: data)
    }
    return CastResult(hg: hg, changed: changed, moving: moving)
}

func trigramFromLines(_ tosses: [CoinToss]) -> (upper: Int, lower: Int) {
    let yang: (CoinToss) -> Int = { $0.symbol == "—" || $0.symbol == "○" ? 1 : 0 }
    let lower = trigramFromBits(yang(tosses[0]), yang(tosses[1]), yang(tosses[2]))
    let upper = trigramFromBits(yang(tosses[3]), yang(tosses[4]), yang(tosses[5]))
    return (upper, lower)
}

func tossThreeCoins() -> CoinToss {
    var coins: [Bool] = []
    for _ in 0..<3 { coins.append(Bool.random()) }
    let backs = coins.filter { $0 }.count
    let moving = backs == 3 || backs == 0
    let symbol = backs == 3 ? "○" : backs == 2 ? "—" : backs == 1 ? "- -" : "×"
    return CoinToss(coins: coins, backs: backs, symbol: symbol, moving: moving)
}

func yongshenIndex(hg: Hexagram, yongshen: String) -> Int {
    if yongshen == "世爻" { return hg.shi }
    if let m = hg.liuqin.firstIndex(of: yongshen) { return m }
    return hg.shi
}

func computeGrade(hg: Hexagram, moving: [Int], yongshen: String, dayZhi: String, dayIdx: Int) -> Grade {
    let yi = yongshenIndex(hg: hg, yongshen: yongshen)
    let el = WUXING_OF_BRANCH[hg.branches[yi]] ?? ""
    let dayEl = WUXING_OF_BRANCH[dayZhi] ?? ""
    if xunkongBranches(dayIdx: dayIdx).contains(BRANCH_IDX[hg.branches[yi]] ?? -1) { return Grade(grade: "中平", label: "中平") }
    if moving.contains(yi) { return Grade(grade: "上上", label: "上上") }
    if moving.isEmpty { return Grade(grade: "中吉", label: "中吉") }
    if SHENG[dayEl] == el || dayEl == el { return Grade(grade: "上吉", label: "上吉") }
    if KE[dayEl] == el { return Grade(grade: "中平", label: "中平") }
    return Grade(grade: "中吉", label: "中吉")
}

func monthZhi(month: Int, day: Int) -> String {
    var z = "子"
    for j in JIEQI {
        if j.m < month || (j.m == month && day >= j.d) { z = j.zhi }
    }
    return z
}

func computeDayInfo(from date: Date) -> DayInfo {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let comps = cal.dateComponents([.year, .month, .day], from: date)
    let y = comps.year!, m = comps.month!, d = comps.day!
    let utcMidnight = cal.date(from: comps)!
    let jdn = Int(floor(utcMidnight.timeIntervalSince1970 / 86400)) + 2440588
    let dayIdx = (jdn + 49) % 60
    let dayGan = String(STEMS[dayIdx % 10])
    let dayZhi = String(BRANCHES[dayIdx % 12])
    let yearGan = String(STEMS[(y - 4) % 10])
    let yearZhi = String(BRANCHES[(y - 4) % 12])
    let mz = monthZhi(month: m, day: d)
    let head = (dayIdx / 10) * 10
    let xunStart = String(STEMS[head % 10]) + String(BRANCHES[head % 12])
    let kongText = xunkongBranches(dayIdx: dayIdx).map { String(BRANCHES[$0]) }.joined()
    return DayInfo(dayIdx: dayIdx, dayGan: dayGan, dayZhi: dayZhi, yearGan: yearGan, yearZhi: yearZhi, monthZhi: mz, xunStart: xunStart, kongText: kongText)
}

// MARK: - Reading / bookmark text builders (SwiftUI-ready data)

struct ReadingSections {
    let classical: [(title: String, lines: [String])]
    let vernacular: [(title: String, lines: [String])]
    let bookmarkQuote: [String]
    let bookmarkBai: [String]
}

func readingSections(c: CastResult, movingSymbols: [Int: String], data: YiData) -> ReadingSections {
    let hg = c.hg
    let ben = data.yijing[hg.key]!
    let benBai = data.bai[hg.key]!
    var classical: [(String, [String])] = []
    var vernacular: [(String, [String])] = []
    var bq: [String] = [ben.t]
    var bb: [String] = [benBai.t]

    var cls: [String] = []
    cls.append(ben.j)
    cls.append("卦辭：\(ben.t)")
    cls.append("象曰：\(ben.d)")
    classical.append(("本卦 \(hg.name)", cls))

    var ver: [String] = []
    ver.append(benBai.t)
    vernacular.append(("本卦 \(hg.name) · 卦辭", ver))

    if !c.moving.isEmpty {
        var cl: [String] = []
        var ve: [String] = []
        for i in c.moving {
            let sym = movingSymbols[i] ?? ""
            cl.append("\(positionName(hg.bits, i))\(sym)：\(ben.l[i])")
            ve.append("\(positionName(hg.bits, i))\(sym)：\(benBai.l[i])")
            bq.append("\(positionName(hg.bits, i))：\(ben.l[i])")
            bb.append(benBai.l[i])
        }
        classical.append(("動爻爻辭（占斷重點）", cl))
        vernacular.append(("動爻爻辭", ve))
        if hg.key == "11" && c.moving.count == 6 {
            classical.append(("用九", [ben.y ?? "用九：見群龍无首，吉。"]))
            vernacular.append(("用九", ["群龍無首，各盡其能而不爭先，吉。"]))
        }
        if hg.key == "88" && c.moving.count == 6 {
            classical.append(("用六", [ben.y ?? "用六：利永貞。"]))
            vernacular.append(("用六", ["宜長久守正，柔順至終。"]))
        }
    }

    if let changed = c.changed {
        let bg = data.yijing[changed.key]!
        let bgBai = data.bai[changed.key]!
        classical.append(("變卦 \(changed.name)", [bg.j, "卦辭：\(bg.t)", "象曰：\(bg.d)"]))
        vernacular.append(("變卦 \(changed.name) · 卦辭", [bgBai.t]))
    } else {
        classical.append(("無動爻", ["無動爻，此卦以本卦卦辭與象辭為占斷依據。"]))
        vernacular.append(("無動爻", ["無動爻，此卦以本卦卦辭為占斷依據。"]))
    }

    return ReadingSections(classical: classical, vernacular: vernacular, bookmarkQuote: bq, bookmarkBai: bb)
}