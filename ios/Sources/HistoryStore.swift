import Foundation

struct HistoryRecord: Codable, Identifiable, Equatable {
    let id: String
    let ts: Double
    let dateISO: String
    let ganzhiText: String
    let yongshen: String
    let hgKey: String
    let changedKey: String?
    let hgName: String
    let changedName: String?
    let moving: [Int]
    let movingSymbols: [Int: String]
    let bits: [Int]
    let dayIdx: Int
    let dayGan: String
    let dayZhi: String
    let lines: [CoinTossCodable]?
    let source: String
    let inputs: NumbersInput?

    struct CoinTossCodable: Codable, Equatable {
        let coins: [Bool]
        let backs: Int
        let symbol: String
        let moving: Bool
    }

    struct NumbersInput: Codable, Equatable {
        let a: Int
        let b: Int
        let c: Int
    }
}

extension HistoryRecord {
    var coinTosses: [CoinToss]? {
        lines?.map { CoinToss(coins: $0.coins, backs: $0.backs, symbol: $0.symbol, moving: $0.moving) }
    }
}

enum HistoryStore {
    static let key = "6yao.history.v1"
    static let limit = 50

    static func load() -> [HistoryRecord] {
        guard let d = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([HistoryRecord].self, from: d)) ?? []
    }

    static func save(_ list: [HistoryRecord]) {
        if let d = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }

    static func push(_ r: HistoryRecord) {
        var l = load()
        l.insert(r, at: 0)
        if l.count > limit {
            l = Array(l.prefix(limit))
        }
        save(l)
    }

    static func remove(id: String) {
        save(load().filter { $0.id != id })
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
