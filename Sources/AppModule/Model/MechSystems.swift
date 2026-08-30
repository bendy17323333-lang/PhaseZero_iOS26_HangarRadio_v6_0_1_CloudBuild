import Foundation
import SwiftUI
import Combine

enum CombatFrameID: String, Codable, CaseIterable, Identifiable {
    case axis = "axis"
    case vector = "vector"
    case prism = "prism"
    case hive = "hive"
    case cataclysm = "cataclysm"
    case oracle = "oracle"

    var id: String { rawValue }
}

struct FrameTraitDefinition: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let summary: String
    let levelDetails: [String]

    func detail(at level: Int) -> String {
        guard !levelDetails.isEmpty else { return summary }
        return levelDetails[min(max(level, 1), levelDetails.count) - 1]
    }
}

struct CombatFrameDefinition: Identifiable, Equatable {
    let id: CombatFrameID
    let code: String
    let name: String
    let role: String
    let icon: String
    let unlockCost: Int
    let summary: String
    let traits: [FrameTraitDefinition]

    var tint: Color {
        switch id {
        case .axis: return .cyan
        case .vector: return .mint
        case .prism: return .purple
        case .hive: return .teal
        case .cataclysm: return .orange
        case .oracle: return .indigo
        }
    }

    static let all: [CombatFrameDefinition] = [
        CombatFrameDefinition(
            id: .axis,
            code: "AX-01",
            name: "衡轴",
            role: "稳定 / 防御 / 过载",
            icon: "shield.lefthalf.filled",
            unlockCost: 0,
            summary: "对新驾驶员最友好的相位机体。容错高，但并不妨碍它在满级时拒绝一次死亡。",
            traits: [
                FrameTraitDefinition(
                    id: "armor",
                    title: "复合装甲",
                    icon: "shield.fill",
                    summary: "提高生命、护盾与故障容错。",
                    levelDetails: [
                        "最大生命 +1。",
                        "最大生命 +1，并获得 1 格护盾。",
                        "增加护盾，并提高维修核心掉率。",
                        "每局第一次致命伤害被驳回，保留 1 点生命并清除弹幕。"
                    ]
                ),
                FrameTraitDefinition(
                    id: "rectifier",
                    title: "相位整流",
                    icon: "arrow.triangle.2.circlepath",
                    summary: "加快换相并扩大清弹半径。",
                    levelDetails: [
                        "换相冷却略微缩短，清弹半径 +8。",
                        "换相冷却进一步缩短，清弹半径 +20。",
                        "同步获取显著提高，清弹半径 +34。",
                        "换相进入高效整流：冷却大幅缩短，清弹半径 +50。"
                    ]
                ),
                FrameTraitDefinition(
                    id: "conduit",
                    title: "过载导管",
                    icon: "bolt.fill",
                    summary: "延长过载并强化火力。",
                    levelDetails: [
                        "过载持续时间 +0.6 秒。",
                        "过载持续时间 +1.2 秒，射速提高。",
                        "过载持续时间 +1.9 秒，伤害提高。",
                        "进入过载时释放双相冲击波，并获得最长持续时间。"
                    ]
                )
            ]
        ),
        CombatFrameDefinition(
            id: .vector,
            code: "VX-07",
            name: "逐矢",
            role: "冲刺 / 近战 / 速度",
            icon: "forward.end.fill",
            unlockCost: 8,
            summary: "把冲刺从逃生工具改造成近战武器。保险公司拒绝为它提供任何形式的解释。",
            traits: [
                FrameTraitDefinition(
                    id: "propulsion",
                    title: "双级推进",
                    icon: "wind",
                    summary: "增加冲刺充能并加快恢复。",
                    levelDetails: [
                        "开局拥有 2 次冲刺充能。",
                        "冲刺恢复速度提高。",
                        "冲刺速度与持续时间提高。",
                        "获得第 3 次冲刺充能，并大幅加快恢复。"
                    ]
                ),
                FrameTraitDefinition(
                    id: "tangentBlade",
                    title: "切线刃",
                    icon: "line.diagonal",
                    summary: "冲刺路径会切割敌人。",
                    levelDetails: [
                        "冲刺对穿过的敌人造成无视相位伤害。",
                        "切割伤害提高，并产生小型终点冲击。",
                        "冲刺冲击波扩大，可破坏附近敌弹。",
                        "冲刺结束自动换相，切割与冲击波达到最大功率。"
                    ]
                ),
                FrameTraitDefinition(
                    id: "inertia",
                    title: "惯性回收",
                    icon: "arrow.clockwise.circle.fill",
                    summary: "高风险移动会返还资源。",
                    levelDetails: [
                        "同步获取提高，冲刺恢复略微加快。",
                        "冲刺恢复进一步加快。",
                        "冲刺持续时间与移动速度提高。",
                        "完美冲刺获得最高同步回收与推进效率。"
                    ]
                )
            ]
        ),
        CombatFrameDefinition(
            id: .prism,
            code: "PR-13",
            name: "棱镜",
            role: "换相 / 弹幕转化",
            icon: "circle.hexagongrid.fill",
            unlockCost: 12,
            summary: "把敌方弹幕重新分类为可回收资产。官僚主义终于被用于某种有益事业。",
            traits: [
                FrameTraitDefinition(
                    id: "echo",
                    title: "双频回声",
                    icon: "waveform.path.ecg",
                    summary: "换相后的齐射携带另一相位弹体。",
                    levelDetails: [
                        "换相后获得 1 次双频齐射。",
                        "换相后获得 2 次双频齐射。",
                        "换相后获得 3 次双频齐射。",
                        "永久获得双相射击，并强化回声弹幕。"
                    ]
                ),
                FrameTraitDefinition(
                    id: "requisition",
                    title: "弹幕征用",
                    icon: "arrow.trianglehead.branch",
                    summary: "把清除的敌弹转成友军追踪弹。",
                    levelDetails: [
                        "每次换相最多征用 2 枚敌弹。",
                        "征用上限提高到 4 枚。",
                        "征用上限提高到 6 枚，伤害提高。",
                        "征用上限提高到 9 枚，并获得最高追踪伤害。"
                    ]
                ),
                FrameTraitDefinition(
                    id: "criticalShift",
                    title: "临界换相",
                    icon: "sparkles",
                    summary: "完美换相返还冷却并恢复防护。",
                    levelDetails: [
                        "清除足够弹幕时返还部分换相冷却。",
                        "完美换相可恢复护盾。",
                        "触发门槛降低，清弹后防护更稳定。",
                        "完美换相会释放棱镜风暴。"
                    ]
                )
            ]
        ),
        CombatFrameDefinition(
            id: .hive,
            code: "HV-03",
            name: "蜂巢",
            role: "无人机 / 集火 / 修复",
            icon: "circle.grid.3x3.fill",
            unlockCost: 16,
            summary: "带着一支逐渐扩编的自动化小队进入裂隙。它们比大多数项目组更擅长共同瞄准。",
            traits: [
                FrameTraitDefinition(
                    id: "wingmen",
                    title: "伴飞单元",
                    icon: "dot.scope",
                    summary: "增加自动射击无人机。",
                    levelDetails: [
                        "开局携带 1 架无人机。",
                        "开局携带 2 架无人机。",
                        "开局携带 3 架无人机。",
                        "开局携带 4 架无人机，并进入蜂群编队。"
                    ]
                ),
                FrameTraitDefinition(
                    id: "lock",
                    title: "群体锁定",
                    icon: "scope",
                    summary: "提高无人机射速与追踪能力。",
                    levelDetails: [
                        "无人机射速略微提高。",
                        "无人机射速与追踪范围提高。",
                        "无人机获得更强的集火能力。",
                        "无人机达到最高射速，并继承强化追踪。"
                    ]
                ),
                FrameTraitDefinition(
                    id: "salvage",
                    title: "残骸自修",
                    icon: "cross.case.fill",
                    summary: "提高维修核心掉率与吸附范围。",
                    levelDetails: [
                        "维修核心掉率提高。",
                        "拾取吸附范围扩大。",
                        "掉率与吸附范围进一步提高。",
                        "残骸溢出时转化为更高的无人机作战效率。"
                    ]
                )
            ]
        ),
        CombatFrameDefinition(
            id: .cataclysm,
            code: "RX-66",
            name: "灾变",
            role: "爆炸 / 高伤 / 高风险",
            icon: "burst.fill",
            unlockCost: 20,
            summary: "把生存空间换成火力与连锁爆炸。设计文件中没有出现“适度”这个词。",
            traits: [
                FrameTraitDefinition(
                    id: "fission",
                    title: "裂变弹头",
                    icon: "atom",
                    summary: "敌人死亡时触发连锁爆炸。",
                    levelDetails: [
                        "敌人死亡时造成小范围伤害。",
                        "爆炸范围与伤害提高。",
                        "死亡爆炸会喷射碎片。",
                        "连锁爆炸达到最大范围，并额外产生碎片弹。"
                    ]
                ),
                FrameTraitDefinition(
                    id: "thermal",
                    title: "热载荷",
                    icon: "thermometer.high",
                    summary: "提高主武器伤害、射速与弹体尺寸。",
                    levelDetails: [
                        "主武器伤害提高。",
                        "伤害与射速提高。",
                        "弹体尺寸与暴击率提高。",
                        "武器进入极限热载荷，伤害与射速达到最大值。"
                    ]
                ),
                FrameTraitDefinition(
                    id: "voidWarranty",
                    title: "保险作废",
                    icon: "exclamationmark.shield.fill",
                    summary: "减少生命，换取更高得分与处决能力。",
                    levelDetails: [
                        "最大生命 -1，得分倍率 +3%。",
                        "得分倍率 +6%，获得低血量处决。",
                        "得分倍率 +9%，处决阈值提高。",
                        "得分倍率 +12%，低血量火力和处决达到最高。"
                    ]
                )
            ]
        ),
        CombatFrameDefinition(
            id: .oracle,
            code: "OR-00",
            name: "先见",
            role: "预测 / 弱点 / 导演交涉",
            icon: "eye.trianglebadge.exclamationmark.fill",
            unlockCost: 26,
            summary: "使用预测火控和额外协议重抽操纵未来。它仍无法预测人类为什么会在满血时撞上最慢的子弹。",
            traits: [
                FrameTraitDefinition(
                    id: "prediction",
                    title: "预测火控",
                    icon: "scope",
                    summary: "强化软锁定、追踪与提前量。",
                    levelDetails: [
                        "辅助瞄准与追踪范围提高。",
                        "追踪转向速度提高。",
                        "弹速和追踪能力进一步提高。",
                        "第一轮火力获得最高预测修正。"
                    ]
                ),
                FrameTraitDefinition(
                    id: "weakness",
                    title: "弱点译码",
                    icon: "viewfinder.circle.fill",
                    summary: "提高暴击与斩杀能力。",
                    levelDetails: [
                        "暴击率提高。",
                        "暴击倍率与斩杀阈值提高。",
                        "持续集火获得更强斩杀。",
                        "弱点译码达到最高暴击率与处决阈值。"
                    ]
                ),
                FrameTraitDefinition(
                    id: "negotiation",
                    title: "交涉权限",
                    icon: "brain.head.profile",
                    summary: "增加重抽并强化换相资源。",
                    levelDetails: [
                        "每局获得 1 次额外协议重抽。",
                        "额外重抽，并提高同步获取。",
                        "获得 2 次额外重抽与更大清弹半径。",
                        "获得 3 次额外重抽，导演协议拥有最高操作余量。"
                    ]
                )
            ]
        )
    ]

    static func definition(for id: CombatFrameID) -> CombatFrameDefinition {
        all.first(where: { $0.id == id }) ?? all[0]
    }
}

private struct MetaProgressionSnapshot: Codable {
    var points: Int
    var activeFrameID: CombatFrameID
    var unlockedFrameIDs: Set<CombatFrameID>
    var traitLevels: [String: Int]
    var laboratoryOverride: Bool
    var claimedDailyDirectives: Set<String>
}

@MainActor
final class MetaProgressionStore: ObservableObject {
    @Published private(set) var points = 0
    @Published private(set) var activeFrameID: CombatFrameID = .axis
    @Published private(set) var unlockedFrameIDs: Set<CombatFrameID> = [.axis]
    @Published private(set) var traitLevels: [String: Int] = [:]
    @Published private(set) var laboratoryOverride = false
    @Published private(set) var lastEarnedPoints = 0

    private let defaults: UserDefaults
    private let storageKey = "phasezero.metaProgression.v6"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        unlockedFrameIDs.insert(.axis)
        if !isUnlocked(activeFrameID) { activeFrameID = .axis }
    }

    var activeFrame: CombatFrameDefinition {
        CombatFrameDefinition.definition(for: activeFrameID)
    }

    func isUnlocked(_ id: CombatFrameID) -> Bool {
        laboratoryOverride || unlockedFrameIDs.contains(id)
    }

    func effectiveTraitLevel(frameID: CombatFrameID, traitID: String) -> Int {
        if laboratoryOverride { return 4 }
        return min(max(traitLevels[traitKey(frameID: frameID, traitID: traitID)] ?? 1, 1), 4)
    }

    func unlock(_ frameID: CombatFrameID) -> Bool {
        guard !isUnlocked(frameID) else { return true }
        let frame = CombatFrameDefinition.definition(for: frameID)
        guard points >= frame.unlockCost else { return false }
        points -= frame.unlockCost
        unlockedFrameIDs.insert(frameID)
        save()
        return true
    }

    func equip(_ frameID: CombatFrameID) -> Bool {
        guard isUnlocked(frameID) else { return false }
        activeFrameID = frameID
        save()
        return true
    }

    func upgradeCost(frameID: CombatFrameID, traitID: String) -> Int? {
        let level = effectiveTraitLevel(frameID: frameID, traitID: traitID)
        switch level {
        case 1: return 2
        case 2: return 4
        case 3: return 6
        default: return nil
        }
    }

    func canUpgrade(frameID: CombatFrameID, traitID: String) -> Bool {
        guard isUnlocked(frameID), !laboratoryOverride,
              let cost = upgradeCost(frameID: frameID, traitID: traitID)
        else { return false }
        return points >= cost
    }

    func upgrade(frameID: CombatFrameID, traitID: String) -> Bool {
        guard canUpgrade(frameID: frameID, traitID: traitID),
              let cost = upgradeCost(frameID: frameID, traitID: traitID)
        else { return false }
        let key = traitKey(frameID: frameID, traitID: traitID)
        let next = min(4, effectiveTraitLevel(frameID: frameID, traitID: traitID) + 1)
        points -= cost
        traitLevels[key] = next
        save()
        return true
    }

    @discardableResult
    func activateLaboratoryOverride() -> Bool {
        guard !laboratoryOverride else { return false }
        laboratoryOverride = true
        save()
        return true
    }

    func award(for result: GameOverSnapshot, directive: RunDirective) -> Int {
        var reward = 0
        if result.wave >= 2 { reward += 1 }
        reward += max(0, result.wave / 4)
        reward += max(0, result.wave / 5) * 2

        switch result.peakStyleRank {
        case "SSS": reward += 4
        case "SS": reward += 3
        case "S": reward += 2
        case "A": reward += 1
        default: break
        }

        if directive.mode == .director, result.wave >= 5 { reward += 1 }

        var claimed = claimedDailyDirectives
        if directive.mode == .daily, result.wave >= 2, !claimed.contains(directive.id) {
            reward += 3
            claimed.insert(directive.id)
        }

        reward = min(max(reward, 0), 15)
        points += reward
        lastEarnedPoints = reward
        claimedDailyDirectives = claimed
        save()
        return reward
    }

    func activeLoadoutPayload() -> [String: Any] {
        let frame = activeFrame
        var levels: [String: Int] = [:]
        for trait in frame.traits {
            levels[trait.id] = effectiveTraitLevel(frameID: frame.id, traitID: trait.id)
        }
        let riskLevel = levels["voidWarranty"] ?? 1
        let scoreMultiplier = frame.id == .cataclysm ? 1.0 + Double(riskLevel) * 0.03 : 1.0
        return [
            "id": frame.id.rawValue,
            "code": frame.code,
            "name": frame.name,
            "traits": levels,
            "scoreMultiplier": scoreMultiplier
        ]
    }

    func romanLevel(_ level: Int) -> String {
        switch min(max(level, 1), 4) {
        case 1: return "I"
        case 2: return "II"
        case 3: return "III"
        default: return "IV"
        }
    }

    private var claimedDailyDirectives: Set<String> = []

    private func traitKey(frameID: CombatFrameID, traitID: String) -> String {
        "\(frameID.rawValue).\(traitID)"
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(MetaProgressionSnapshot.self, from: data)
        else { return }
        points = max(0, snapshot.points)
        activeFrameID = snapshot.activeFrameID
        unlockedFrameIDs = snapshot.unlockedFrameIDs
        traitLevels = snapshot.traitLevels
        laboratoryOverride = snapshot.laboratoryOverride
        claimedDailyDirectives = snapshot.claimedDailyDirectives
    }

    private func save() {
        let snapshot = MetaProgressionSnapshot(
            points: points,
            activeFrameID: activeFrameID,
            unlockedFrameIDs: unlockedFrameIDs,
            traitLevels: traitLevels,
            laboratoryOverride: laboratoryOverride,
            claimedDailyDirectives: claimedDailyDirectives
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
