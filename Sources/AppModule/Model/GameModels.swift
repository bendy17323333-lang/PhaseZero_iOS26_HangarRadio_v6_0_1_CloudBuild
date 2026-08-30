import Foundation
import SwiftUI

enum PhaseZeroState: String, Equatable {
    case loading
    case menu
    case playing
    case ending
    case paused
    case upgrade
    case over
    case error
}

struct HUDSnapshot: Equatable {
    var score = 0
    var wave = 0
    var combo = 1
    var hp = 5
    var maxHP = 5
    var shield = 0
    var maxShield = 0
    var phase = 0
    var phaseName = "青频"
    var sync = 0.0
    var phaseReady = 1.0
    var dashReady = 1.0
    var dashCharges = 1
    var dashChargesMax = 1
    var level = 1
    var xp = 0.0
    var xpNeed = 75.0
    var bossProgress: Double?
    var highScore = 0
    var style = 0.0
    var styleRank = "D"
    var styleMultiplier = 1.0
    var overdriveActive = false
    var grazes = 0

    var phaseColor: Color {
        phase == 0 ? Color(red: 0.37, green: 0.91, blue: 1.0) : Color(red: 1.0, green: 0.48, blue: 0.39)
    }

    var xpProgress: Double {
        guard xpNeed > 0 else { return 0 }
        return min(max(xp / xpNeed, 0), 1)
    }

    var styleColor: Color {
        switch styleRank {
        case "SSS": return .pink
        case "SS": return .purple
        case "S": return .yellow
        case "A": return .orange
        case "B": return .mint
        case "C": return .cyan
        default: return .white
        }
    }

    static func decode(_ json: [String: Any]) -> HUDSnapshot {
        var value = HUDSnapshot()
        value.score = json.int("score")
        value.wave = json.int("wave")
        value.combo = max(1, json.int("combo"))
        value.hp = json.int("hp")
        value.maxHP = max(1, json.int("maxHp"))
        value.shield = json.int("shield")
        value.maxShield = json.int("maxShield")
        value.phase = json.int("phase")
        value.phaseName = json.string("phaseName", fallback: value.phase == 0 ? "青频" : "赤频")
        value.sync = json.double("sync")
        value.phaseReady = json.double("phaseReady")
        value.dashReady = json.double("dashReady")
        value.dashCharges = json.int("dashCharges")
        value.dashChargesMax = max(1, json.int("dashChargesMax"))
        value.level = max(1, json.int("level"))
        value.xp = json.double("xp")
        value.xpNeed = max(1, json.double("xpNeed"))
        value.bossProgress = json.optionalDouble("bossProgress")
        value.highScore = json.int("highScore")
        value.style = json.double("style")
        value.styleRank = json.string("styleRank", fallback: "D")
        value.styleMultiplier = max(1, json.double("styleMultiplier"))
        value.overdriveActive = json.bool("overdriveActive")
        value.grazes = json.int("grazes")
        return value
    }
}

struct UpgradeChoice: Identifiable, Equatable {
    let index: Int
    let protocolID: String
    let name: String
    let icon: String
    let rarity: String
    let rarityLabel: String
    let tag: String
    let detail: String
    let current: Int
    let maxStack: Int

    var id: String { protocolID }

    var tint: Color {
        switch rarity {
        case "rare": return .blue
        case "legendary": return .yellow
        case "cursed": return .purple
        case "evolution": return .mint
        default: return .white
        }
    }

    static func decode(_ json: [String: Any]) -> UpgradeChoice {
        UpgradeChoice(
            index: json.int("index"),
            protocolID: json.string("id", fallback: UUID().uuidString),
            name: json.string("name", fallback: "未知协议"),
            icon: json.string("icon", fallback: "◇"),
            rarity: json.string("rarity", fallback: "common"),
            rarityLabel: json.string("rarityLabel", fallback: "稳定"),
            tag: json.string("tag", fallback: "协议"),
            detail: json.string("description", fallback: "系统拒绝提供说明。很有企业精神。"),
            current: json.int("current"),
            maxStack: max(1, json.int("max"))
        )
    }
}

struct GameOverSnapshot: Equatable {
    var score = 0
    var wave = 0
    var level = 1
    var kills = 0
    var highScore = 0
    var newRecord = false
    var peakStyleRank = "D"
    var grazes = 0

    static func decode(_ json: [String: Any]) -> GameOverSnapshot {
        GameOverSnapshot(
            score: json.int("score"),
            wave: json.int("wave"),
            level: max(1, json.int("level")),
            kills: json.int("kills"),
            highScore: json.int("highScore"),
            newRecord: json.bool("newRecord"),
            peakStyleRank: json.string("peakStyleRank", fallback: "D"),
            grazes: json.int("grazes")
        )
    }
}

enum SpectacleKind: String, Equatable {
    case phase
    case dash
    case graze
    case shield
    case damage
    case boss
    case bossDefeat
    case overdrive
    case wave
    case rank
    case upgrade
    case sectorClear
    case revive
    case death
    case pulse
}

struct SpectacleEvent: Identifiable, Equatable {
    let id = UUID()
    let kind: SpectacleKind
    let label: String
    let detail: String
    let phase: Int
    let intensity: Double
    let directionX: Double
    let directionY: Double
    let rank: String
    let createdAt = Date()

    var tint: Color {
        switch kind {
        case .damage, .death: return .red
        case .shield: return .cyan
        case .boss, .bossDefeat: return .orange
        case .upgrade: return .purple
        case .rank:
            switch rank {
            case "SSS": return .pink
            case "SS": return .purple
            case "S": return .yellow
            case "A": return .orange
            case "B": return .mint
            case "C": return .cyan
            default: return .white
            }
        default:
            return phase == 1
                ? Color(red: 1.0, green: 0.48, blue: 0.39)
                : Color(red: 0.37, green: 0.91, blue: 1.0)
        }
    }

    static func decode(_ json: [String: Any]) -> SpectacleEvent {
        SpectacleEvent(
            kind: SpectacleKind(rawValue: json.string("kind")) ?? .pulse,
            label: json.string("label"),
            detail: json.string("detail"),
            phase: json.int("phase"),
            intensity: max(0.1, json.double("intensity")),
            directionX: json.double("directionX"),
            directionY: json.double("directionY"),
            rank: json.string("rank")
        )
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let duration: TimeInterval
}

extension Dictionary where Key == String, Value == Any {
    func int(_ key: String) -> Int {
        if let value = self[key] as? Int { return value }
        if let value = self[key] as? NSNumber { return value.intValue }
        if let value = self[key] as? String { return Int(value) ?? 0 }
        return 0
    }

    func double(_ key: String) -> Double {
        if let value = self[key] as? Double { return value }
        if let value = self[key] as? NSNumber { return value.doubleValue }
        if let value = self[key] as? String { return Double(value) ?? 0 }
        return 0
    }

    func optionalDouble(_ key: String) -> Double? {
        guard let raw = self[key], !(raw is NSNull) else { return nil }
        if let value = raw as? Double { return value }
        if let value = raw as? NSNumber { return value.doubleValue }
        if let value = raw as? String { return Double(value) }
        return nil
    }

    func string(_ key: String, fallback: String = "") -> String {
        self[key] as? String ?? fallback
    }

    func bool(_ key: String) -> Bool {
        if let value = self[key] as? Bool { return value }
        if let value = self[key] as? NSNumber { return value.boolValue }
        return false
    }

    func dictionary(_ key: String) -> [String: Any] {
        self[key] as? [String: Any] ?? [:]
    }

    func dictionaries(_ key: String) -> [[String: Any]] {
        self[key] as? [[String: Any]] ?? []
    }
}
