import SwiftUI
import UIKit

enum Mode { case coins, numbers }

@MainActor
final class AppModel: ObservableObject {
    @Published var mode: Mode = .coins
    @Published var lines: [CoinToss] = []
    @Published var casting = false
    @Published var result: CastResult? = nil
    @Published var movingSymbols: [Int: String] = [:]
    @Published var yongshen = ""
    @Published var castDate = Date()
    @Published var dayInfo: DayInfo
    @Published var showBookmark = false
    @Published var numError = ""
    @Published var history: [HistoryRecord] = HistoryStore.load()
    @Published var showHistory = false

    let data: YiData

    init() {
        guard let url = Bundle.main.resourceURL else { fatalError("no resources") }
        data = try! YiData.load(from: url)
        dayInfo = computeDayInfo(from: Date())
    }

    var ganzhiText: String {
        let d = dayInfo
        return "\(d.yearGan)\(d.yearZhi) 年 · \(d.monthZhi)月 · \(d.dayGan)\(d.dayZhi) 日 · \(d.xunStart)旬 空\(d.kongText)"
    }

    var grade: Grade? {
        guard let r = result else { return nil }
        return computeGrade(hg: r.hg, moving: r.moving, yongshen: yongshen, dayZhi: dayInfo.dayZhi, dayIdx: dayInfo.dayIdx)
    }

    func updateDay() {
        dayInfo = computeDayInfo(from: castDate)
    }

    func clearResult() {
        result = nil
        movingSymbols = [:]
        lines = []
        numError = ""
    }

    func startCasting() async {
        guard !casting else { return }
        if result != nil { pushHistory() }
        casting = true
        lines = []
        result = nil
        movingSymbols = [:]
        for _ in 0..<6 {
            let intensity = Double.random(in: 0.4...0.7)
            HapticManager.shared.impact(.light, intensity: intensity)
            lines.append(tossThreeCoins())
            try? await Task.sleep(nanoseconds: 480_000_000)
        }
        finalize(triggerBookmark: true)
        HapticManager.shared.success()
        casting = false
    }

    func undo() {
        guard !casting, !lines.isEmpty else { return }
        lines.removeLast()
        result = nil
        movingSymbols = [:]
        HapticManager.shared.impact(.light, intensity: 0.4)
    }

    func reset() {
        guard !casting else { return }
        clearResult()
        HapticManager.shared.impact(.light, intensity: 0.4)
    }

    func castNumbers(_ a: Int, _ b: Int, _ c: Int) {
        guard a > 0, b > 0, c > 0 else {
            numError = "請輸入三個正整數"
            return
        }
        if result != nil { pushHistory() }
        numError = ""
        let upper = a % 8 == 0 ? 8 : a % 8
        let lower = b % 8 == 0 ? 8 : b % 8
        let moving = c % 6 == 0 ? 6 : c % 6
        lines = []
        result = cast(upper: upper, lower: lower, moving: [moving - 1], data: data)
        movingSymbols = [moving - 1: "●"]
        HapticManager.shared.impact(.light, intensity: 0.5)
        HapticManager.shared.impact(.medium, intensity: 0.6)
        showBookmark = true
        history = HistoryStore.load()
    }

    private func finalize(triggerBookmark: Bool) {
        guard lines.count == 6 else { return }
        let t = trigramFromLines(lines)
        var moving: [Int] = []
        var symbols: [Int: String] = [:]
        for (i, l) in lines.enumerated() where l.moving {
            moving.append(i)
            symbols[i] = l.symbol
        }
        result = cast(upper: t.upper, lower: t.lower, moving: moving, data: data)
        movingSymbols = symbols
        if triggerBookmark {
            HapticManager.shared.impact(.medium, intensity: 0.6)
            showBookmark = true
        }
    }

    // MARK: - History

    func pushHistory() {
        guard let r = result else { return }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.locale = Locale(identifier: "en_US_POSIX")
        let dateISO = df.string(from: castDate)
        let codableLines: [HistoryRecord.CoinTossCodable]? = lines.isEmpty ? nil : lines.map {
            HistoryRecord.CoinTossCodable(coins: $0.coins, backs: $0.backs, symbol: $0.symbol, moving: $0.moving)
        }
        let rec = HistoryRecord(
            id: UUID().uuidString,
            ts: Date().timeIntervalSince1970 * 1000,
            dateISO: dateISO,
            ganzhiText: ganzhiText,
            yongshen: yongshen,
            hgKey: r.hg.key,
            changedKey: r.changed?.key,
            hgName: r.hg.name,
            changedName: r.changed?.name,
            moving: r.moving,
            movingSymbols: movingSymbols,
            bits: r.hg.bits,
            dayIdx: dayInfo.dayIdx,
            dayGan: dayInfo.dayGan,
            dayZhi: dayInfo.dayZhi,
            lines: codableLines,
            source: lines.isEmpty ? "numbers" : "coins",
            inputs: nil
        )
        HistoryStore.push(rec)
        history = HistoryStore.load()
    }

    func removeHistory(id: String) {
        HistoryStore.remove(id: id)
        history = HistoryStore.load()
    }

    func clearHistory() {
        HistoryStore.clear()
        history = []
    }

    func gradeForRecord(_ rec: HistoryRecord) -> Grade? {
        guard rec.hgKey.count == 2,
              let upper = Int(String(rec.hgKey.prefix(1))),
              let lower = Int(String(rec.hgKey.suffix(1))) else { return nil }
        let hg = buildHexagram(upper: upper, lower: lower, data: data)
        return computeGrade(hg: hg, moving: rec.moving, yongshen: rec.yongshen, dayZhi: rec.dayZhi, dayIdx: rec.dayIdx)
    }

    func restore(record: HistoryRecord) {
        yongshen = record.yongshen
        // 還原占日
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.locale = Locale(identifier: "en_US_POSIX")
        if let d = df.date(from: record.dateISO) {
            castDate = d
            updateDay()
            // 以紀錄的 dayIdx/dayGan/dayZhi 覆蓋，xunStart/kongText 依 dayIdx 重算以保一致
            let head = (record.dayIdx / 10) * 10
            let xunStart = String(STEMS[head % 10]) + String(BRANCHES[head % 12])
            let kongText = xunkongBranches(dayIdx: record.dayIdx).map { String(BRANCHES[$0]) }.joined()
            dayInfo = DayInfo(
                dayIdx: record.dayIdx, dayGan: record.dayGan, dayZhi: record.dayZhi,
                yearGan: dayInfo.yearGan, yearZhi: dayInfo.yearZhi,
                monthZhi: dayInfo.monthZhi,
                xunStart: xunStart, kongText: kongText
            )
        } else {
            // fallback：直接覆蓋日柱
            let head = (record.dayIdx / 10) * 10
            let xunStart = String(STEMS[head % 10]) + String(BRANCHES[head % 12])
            let kongText = xunkongBranches(dayIdx: record.dayIdx).map { String(BRANCHES[$0]) }.joined()
            dayInfo = DayInfo(
                dayIdx: record.dayIdx, dayGan: record.dayGan, dayZhi: record.dayZhi,
                yearGan: dayInfo.yearGan, yearZhi: dayInfo.yearZhi,
                monthZhi: dayInfo.monthZhi,
                xunStart: xunStart, kongText: kongText
            )
        }
        lines = record.coinTosses ?? []
        movingSymbols = record.movingSymbols
        guard record.hgKey.count == 2,
              let upper = Int(String(record.hgKey.prefix(1))),
              let lower = Int(String(record.hgKey.suffix(1))) else { return }
        result = cast(upper: upper, lower: lower, moving: record.moving, data: data)
    }
}