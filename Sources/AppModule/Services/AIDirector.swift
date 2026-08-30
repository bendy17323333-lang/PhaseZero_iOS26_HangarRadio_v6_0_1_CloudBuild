import Foundation
import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AIDirectorAvailability: Equatable {
    case checking
    case available
    case unavailable(String)

    var title: String {
        switch self {
        case .checking: return "检查中"
        case .available: return "Apple Intelligence 可用"
        case .unavailable: return "使用本地脚本"
        }
    }

    var detail: String {
        switch self {
        case .checking:
            return "正在询问系统模型。它可能只是需要一点时间摆出神秘姿态。"
        case .available:
            return "任务简报与战后报告会在设备上生成，不上传游戏记录。"
        case .unavailable(let reason):
            return reason
        }
    }

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
}

@MainActor
final class AIDirector: ObservableObject {
    @Published private(set) var availability: AIDirectorAvailability = .checking
    @Published private(set) var briefing = "相位导演正在整理今日事故清单。"
    @Published private(set) var debrief: String?
    @Published private(set) var isGenerating = false
    @Published private(set) var isGeneratingContract = false
    @Published private(set) var briefingDirectiveID = ""

    private var briefingTask: Task<Void, Never>?
    private var debriefTask: Task<Void, Never>?

    func refreshAvailability() {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            availability = .available
        case .unavailable(let reason):
            availability = .unavailable("系统模型当前不可用：\(String(describing: reason))。游戏会使用确定性文案，玩法不受影响。")
        @unknown default:
            availability = .unavailable("系统模型返回了当前 SDK 不认识的状态。游戏会使用确定性文案，玩法不受影响。")
        }
        #else
        availability = .unavailable("当前 Swift Playground SDK 没有 Foundation Models 模块。游戏会继续运行，只是少了一位爱写报告的本地 AI。")
        #endif
    }

    func prepareBriefing(for directive: RunDirective, enabled: Bool) {
        briefingTask?.cancel()
        briefingDirectiveID = directive.id
        briefing = fallbackBriefing(for: directive)
        guard enabled else { return }

        briefingTask = Task { [weak self] in
            guard let self else { return }
            await self.generateBriefing(for: directive)
        }
    }


    func briefingText(for directive: RunDirective) -> String {
        briefingDirectiveID == directive.id ? briefing : fallbackBriefing(for: directive)
    }

    func generateDirectorContract(
        seed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1_000),
        enabled: Bool
    ) async -> RunDirective {
        let fallback = RunDirective.directorFallback(seed: seed)
        guard enabled, availability.isAvailable else { return fallback }

        #if canImport(FoundationModels)
        isGeneratingContract = true
        defer { isGeneratingContract = false }

        let options = RunDirective.allModifiers
            .map { "\($0.id)=\($0.name)：\($0.detail)" }
            .joined(separator: "；")
        let session = LanguageModelSession(
            instructions: """
            你是科幻街机肉鸽《零点相位》的挑战导演。你只能从给定白名单中选择恰好三个互不重复的协议。
            输出必须严格为一行：短标题|协议ID,协议ID,协议ID|中文简报
            标题不超过14个汉字，简报不超过70个汉字，不要使用 Markdown，不要输出额外解释。
            """
        )

        do {
            let response = try await session.respond(
                to: "随机种子：\(seed)。白名单：\(options)。组合一场有明确主题、危险但可玩的挑战。"
            )
            guard !Task.isCancelled,
                  let directive = parseDirectorContract(response.content, seed: seed)
            else { return fallback }
            return directive
        } catch {
            return fallback
        }
        #else
        return fallback
        #endif
    }

    func prepareDebrief(record: RunRecord, directive: RunDirective, enabled: Bool) {
        debriefTask?.cancel()
        debrief = fallbackDebrief(record: record, directive: directive)
        guard enabled else { return }

        debriefTask = Task { [weak self] in
            guard let self else { return }
            await self.generateDebrief(record: record, directive: directive)
        }
    }

    private func generateBriefing(for directive: RunDirective) async {
        #if canImport(FoundationModels)
        guard availability.isAvailable else { return }
        isGenerating = true
        defer { isGenerating = false }

        let modifierText = directive.modifiers.isEmpty
            ? "标准规则，没有额外协议"
            : directive.modifiers.map { "\($0.name)：\($0.detail)" }.joined(separator: "；")

        let session = LanguageModelSession(
            instructions: """
            你是科幻街机游戏《零点相位》的任务导演。用简洁、冷静、略带黑色幽默的中文写任务简报。
            不要发明数值，不要改变规则，不要使用 Markdown，不要超过 85 个汉字。只输出一段话。
            """
        )

        do {
            let response = try await session.respond(
                to: "模式：\(directive.mode.title)。协议：\(modifierText)。为玩家写一段出击简报。"
            )
            guard !Task.isCancelled else { return }
            let cleaned = clean(response.content, limit: 120)
            if !cleaned.isEmpty { briefing = cleaned }
        } catch {
            availability = .unavailable("系统模型生成失败：\(error.localizedDescription)。本局已切回本地简报。")
        }
        #endif
    }

    private func generateDebrief(record: RunRecord, directive: RunDirective) async {
        #if canImport(FoundationModels)
        guard availability.isAvailable else { return }
        isGenerating = true
        defer { isGenerating = false }

        let session = LanguageModelSession(
            instructions: """
            你是科幻街机游戏《零点相位》的战后分析员。根据确定的数据写一句中文点评。
            语气克制、聪明、稍带讽刺，但不要侮辱玩家。不要发明数据，不要使用 Markdown，不超过 72 个汉字。
            """
        )

        do {
            let response = try await session.respond(
                to: "模式：\(directive.mode.title)，得分 \(record.score)，抵达第 \(record.wave) 波，等级 \(record.level)，击杀 \(record.kills)。写战后结论。"
            )
            guard !Task.isCancelled else { return }
            let cleaned = clean(response.content, limit: 100)
            if !cleaned.isEmpty { debrief = cleaned }
        } catch {
            // Keep the deterministic fallback. A failed joke generator should not hold the results screen hostage.
        }
        #endif
    }

    private func fallbackBriefing(for directive: RunDirective) -> String {
        switch directive.mode {
        case .free:
            return "标准裂隙已开放。没有预设借口，也没有委员会替你决定构筑。"
        case .daily:
            let names = directive.modifiers.map(\.name).joined(separator: "、")
            return "今日协议为\(names)。规则固定，失败原因终于可以精确归档。"
        case .director:
            return directive.subtitle
        }
    }

    private func fallbackDebrief(record: RunRecord, directive: RunDirective) -> String {
        if record.wave >= 10 {
            return "裂隙坚持到第 \(record.wave) 波，系统已经开始怀疑自己是不是设计得太客气。"
        }
        if record.kills >= 100 {
            return "击杀记录非常积极，生存记录则保持了必要的谦逊。"
        }
        return "本次同步结束。数据已保存，尊严属于可选附件。"
    }

    private func parseDirectorContract(_ value: String, seed: UInt64) -> RunDirective? {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = normalized.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }

        let title = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let identifiers = parts[1]
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        let briefing = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !briefing.isEmpty, identifiers.count == 3 else { return nil }

        let allowed = Set(RunDirective.allModifiers.map(\.id))
        guard Set(identifiers).count == 3, identifiers.allSatisfy(allowed.contains) else { return nil }
        return RunDirective.directorContract(
            seed: seed,
            title: title,
            briefing: briefing,
            modifierIDs: identifiers
        )
    }

    private func clean(_ value: String, limit: Int) -> String {
        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsed.prefix(limit))
    }
}
