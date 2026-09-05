import Foundation

// MARK: - Data models (Codable, mirror JSON resources)

struct TrigramInfo: Codable {
    let name: String
    let five: String
    let inner: [String]
    let outer: [String]
}

struct HexagramEntry: Codable {
    let name: String
    let palace: Int
    let shi: Int
    let ying: Int
}

struct YijingEntry: Codable {
    let t: String   // 卦辭
    let d: String   // 象曰
    let y: String?  // 用九/用六 (乾/坤專用)
    let j: String   // 卦意簡解
    let l: [String] // 六爻爻辭
}

struct BaiEntry: Codable {
    let t: String
    let l: [String]
}

struct YiData {
    let hexagramTable: [String: HexagramEntry]
    let yijing: [String: YijingEntry]
    let bai: [String: BaiEntry]

    static func load(from directory: URL) throws -> YiData {
        let json = JSONDecoder()
        let ht = try json.decode([String: HexagramEntry].self, from: Data(contentsOf: directory.appendingPathComponent("hexagram_table.json")))
        let yj = try json.decode([String: YijingEntry].self, from: Data(contentsOf: directory.appendingPathComponent("yijing.json")))
        let bai = try json.decode([String: BaiEntry].self, from: Data(contentsOf: directory.appendingPathComponent("bai.json")))
        return YiData(hexagramTable: ht, yijing: yj, bai: bai)
    }
}

// MARK: - Computed structures

struct Hexagram {
    let key: String
    let name: String
    let palace: String
    let branches: [String]
    let bits: [Int]      // bottom → top
    let liuqin: [String]
    let shi: Int
    let ying: Int
}

struct CastResult {
    let hg: Hexagram
    let changed: Hexagram?
    let moving: [Int]    // 動爻 index 0-5
}

struct CoinToss {
    let coins: [Bool]    // true = 背
    let backs: Int
    let symbol: String
    let moving: Bool
}

struct Grade {
    let grade: String
    let label: String
}

struct DayInfo {
    let dayIdx: Int
    let dayGan: String
    let dayZhi: String
    let yearGan: String
    let yearZhi: String
    let monthZhi: String
    let xunStart: String
    let kongText: String
}