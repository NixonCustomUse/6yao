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
        guard !casting, lines.count < 6 else { return }
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
        numError = ""
        let upper = a % 8 == 0 ? 8 : a % 8
        let lower = b % 8 == 0 ? 8 : b % 8
        let moving = c % 6 == 0 ? 6 : c % 6
        result = cast(upper: upper, lower: lower, moving: [moving - 1], data: data)
        movingSymbols = [moving - 1: "●"]
        HapticManager.shared.impact(.light, intensity: 0.5)
        HapticManager.shared.impact(.medium, intensity: 0.6)
        showBookmark = true
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
}