import Foundation
import SwiftUI

// MARK: - Run directives

enum RunMode: String, Codable, CaseIterable, Identifiable {
    case free
    case daily
    case director

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free: return "自由裂隙"
        case .daily: return "每日裂隙"
        case .director: return "导演裂隙"
        }
    }

    var icon: String {
        switch self {
        case .free: return "infinity"
        case .daily: return "calendar.badge.clock"
        case .director: return "brain.head.profile"
        }
    }

    var visualTint: Color {
        switch self {
        case .free: return .cyan
        case .daily: return .purple
        case .director: return .indigo
        }
    }

    var systemCode: String {
        switch self {
        case .free: return "FREE // UNBOUNDED"
        case .daily: return "DAILY // SYNCHRONIZED"
        case .director: return "AI // CURATED CHAOS"
        }
    }
}

struct RunModifier: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let detail: String
    let icon: String
    let scoreBonus: Double

    var tint: Color {
        switch id {
        case "glass_cannon": return .red
        case "phase_debt": return .cyan
        case "bullet_harvest": return .purple
        case "elite_market": return .orange
        case "dash_ritual": return .mint
        case "unstable_capacitor": return .yellow
        default: return .white
        }
    }

    var payload: [String: Any] {
        [
            "id": id,
            "name": name,
            "detail": detail,
            "icon": icon,
            "scoreBonus": scoreBonus
        ]
    }
}

struct RunDirective: Identifiable, Codable, Equatable {
    let id: String
    let mode: RunMode
    let seed: UInt64
    let title: String
    let subtitle: String
    let shareCode: String
    let modifiers: [RunModifier]
    let scoreMultiplier: Double

    static let free = RunDirective(
        id: "free",
        mode: .free,
        seed: 0,
        title: "自由裂隙",
        subtitle: "标准规则，所有事故由你的构筑负责。",
        shareCode: "FREE",
        modifiers: [],
        scoreMultiplier: 1
    )

    static func directorFallback(seed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1_000)) -> RunDirective {
        directorContract(
            seed: seed,
            title: "导演裂隙 // 本地预案",
            briefing: "系统从白名单协议中组装了一场临时事故。Apple Intelligence 不可用时，随机数会勉强代理创意部门。",
            modifierIDs: []
        )
    }

    static func directorContract(
        seed: UInt64,
        title: String,
        briefing: String,
        modifierIDs: [String]
    ) -> RunDirective {
        var selected: [RunModifier] = []
        for identifier in modifierIDs {
            guard !selected.contains(where: { $0.id == identifier }),
                  let modifier = modifierDeck.first(where: { $0.id == identifier })
            else { continue }
            selected.append(modifier)
            if selected.count == 3 { break }
        }

        var generator = PhaseSeededGenerator(seed: seed ^ 0xD1A3_C70F_26A1_27B9)
        var remaining = modifierDeck.filter { candidate in
            !selected.contains(where: { $0.id == candidate.id })
        }
        while selected.count < 3, !remaining.isEmpty {
            let index = Int(generator.next() % UInt64(remaining.count))
            selected.append(remaining.remove(at: index))
        }

        let multiplier = scoreMultiplier(for: selected)
        let code = String(format: "AI-%08llX-%03llX", seed & 0xFFFF_FFFF, generator.next() & 0xFFF)
        let safeTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeBriefing = briefing.trimmingCharacters(in: .whitespacesAndNewlines)

        return RunDirective(
            id: "director-\(seed)-\(selected.map(\.id).joined(separator: "-"))",
            mode: .director,
            seed: seed,
            title: safeTitle.isEmpty ? "导演裂隙" : String(safeTitle.prefix(34)),
            subtitle: safeBriefing.isEmpty ? "协议已生成。理性仍未获邀参加。" : String(safeBriefing.prefix(120)),
            shareCode: code,
            modifiers: selected,
            scoreMultiplier: multiplier
        )
    }

    static var allModifiers: [RunModifier] { modifierDeck }

    static func daily(for date: Date = .now, calendar inputCalendar: Calendar = Calendar(identifier: .gregorian)) -> RunDirective {
        var calendar = inputCalendar
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 2026
        let month = components.month ?? 1
        let day = components.day ?? 1
        let dayNumber = UInt64(year * 10_000 + month * 100 + day)
        var generator = PhaseSeededGenerator(seed: dayNumber ^ 0xA61F_27D4_C9B3_5E01)

        var deck = modifierDeck
        var selected: [RunModifier] = []
        while selected.count < 3, !deck.isEmpty {
            let index = Int(generator.next() % UInt64(deck.count))
            selected.append(deck.remove(at: index))
        }

        let multiplier = scoreMultiplier(for: selected)
        let code = String(format: "PZ-%04d%02d%02d-%03X", year, month, day, Int(generator.next() & 0xFFF))

        return RunDirective(
            id: "daily-\(year)-\(month)-\(day)",
            mode: .daily,
            seed: dayNumber,
            title: "每日裂隙 // \(month)·\(day)",
            subtitle: "全球同日固定协议。不能把坏运气甩给随机数了。",
            shareCode: code,
            modifiers: selected,
            scoreMultiplier: multiplier
        )
    }

    func payload(briefing: String? = nil) -> [String: Any] {
        [
            "id": id,
            "mode": mode.rawValue,
            "seed": String(seed),
            "title": title,
            "briefing": briefing ?? subtitle,
            "shareCode": shareCode,
            "scoreMultiplier": scoreMultiplier,
            "modifiers": modifiers.map(\.payload)
        ]
    }

    private static func scoreMultiplier(for modifiers: [RunModifier]) -> Double {
        let bonus = modifiers.reduce(0) { $0 + $1.scoreBonus }
        return min(1.75, 1 + bonus)
    }

    private static let modifierDeck: [RunModifier] = [
        RunModifier(
            id: "glass_cannon",
            name: "玻璃火控",
            detail: "最大生命 -1，主武器伤害 +30%。谨慎突然有了经济价值。",
            icon: "burst.fill",
            scoreBonus: 0.20
        ),
        RunModifier(
            id: "phase_debt",
            name: "换相债务",
            detail: "换相冷却延长 24%，清弹半径扩大 38。每次点击都像在还贷款。",
            icon: "arrow.triangle.2.circlepath",
            scoreBonus: 0.14
        ),
        RunModifier(
            id: "bullet_harvest",
            name: "弹幕丰收",
            detail: "敌方射速提高 20%，同步获取提高 42%。危险被重新包装成资源。",
            icon: "scope",
            scoreBonus: 0.18
        ),
        RunModifier(
            id: "elite_market",
            name: "精英期货",
            detail: "精英出现率显著提高，经验收益 +22%。市场波动会主动向你开枪。",
            icon: "crown.fill",
            scoreBonus: 0.16
        ),
        RunModifier(
            id: "dash_ritual",
            name: "动量献祭",
            detail: "冲刺恢复变慢 18%，冲刺伤害与冲击波大幅强化。移动终于有了暴力用途。",
            icon: "forward.end.fill",
            scoreBonus: 0.15
        ),
        RunModifier(
            id: "unstable_capacitor",
            name: "非法电网",
            detail: "过载持续更久，但同步会更快自然衰减。电工规范已退出群聊。",
            icon: "bolt.fill",
            scoreBonus: 0.13
        )
    ]
}

private struct PhaseSeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

// MARK: - Run archive

struct RunRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let mode: RunMode
    let directiveID: String
    let score: Int
    let wave: Int
    let level: Int
    let kills: Int
    let shareCode: String

    init(
        id: UUID = UUID(),
        date: Date = .now,
        mode: RunMode,
        directiveID: String,
        score: Int,
        wave: Int,
        level: Int,
        kills: Int,
        shareCode: String
    ) {
        self.id = id
        self.date = date
        self.mode = mode
        self.directiveID = directiveID
        self.score = score
        self.wave = wave
        self.level = level
        self.kills = kills
        self.shareCode = shareCode
    }
}

@MainActor
final class RunArchive: ObservableObject {
    @Published private(set) var records: [RunRecord] = []

    private let defaults: UserDefaults
    private let key = "phasezero.runArchive.v4"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var latest: RunRecord? { records.first }

    func bestScore(for directive: RunDirective) -> Int {
        records
            .filter { $0.directiveID == directive.id }
            .map(\.score)
            .max() ?? 0
    }

    func append(_ record: RunRecord) {
        records.insert(record, at: 0)
        records = Array(records.prefix(24))
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RunRecord].self, from: data)
        else { return }
        records = decoded.sorted { $0.date > $1.date }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }
}
