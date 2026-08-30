import Foundation

enum IntentCommandStore {
    private static let commandKey = "phasezero.pendingIntentCommand"

    static func enqueue(_ command: String) {
        UserDefaults.standard.set(command, forKey: commandKey)
    }

    static func consume() -> String? {
        let command = UserDefaults.standard.string(forKey: commandKey)
        UserDefaults.standard.removeObject(forKey: commandKey)
        return command
    }
}

#if canImport(AppIntents)
import AppIntents

struct StartDailyRiftIntent: AppIntent {
    static var title: LocalizedStringResource = "开始每日裂隙"
    static var description = IntentDescription("打开《零点相位》并启动今天固定协议的挑战。")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentCommandStore.enqueue("daily")
        return .result()
    }
}

struct StartFreeRiftIntent: AppIntent {
    static var title: LocalizedStringResource = "开始自由裂隙"
    static var description = IntentDescription("打开《零点相位》并启动标准肉鸽模式。")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentCommandStore.enqueue("free")
        return .result()
    }
}

struct StartDirectorRiftIntent: AppIntent {
    static var title: LocalizedStringResource = "生成导演裂隙"
    static var description = IntentDescription("打开《零点相位》，让设备端 AI 从白名单协议中生成一场挑战。")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentCommandStore.enqueue("director")
        return .result()
    }
}

struct ToggleMotionAimIntent: AppIntent {
    static var title: LocalizedStringResource = "切换陀螺精瞄"
    static var description = IntentDescription("切换《零点相位》的陀螺仪微调瞄准。")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentCommandStore.enqueue("toggleMotion")
        return .result()
    }
}

struct OpenSystemLabIntent: AppIntent {
    static var title: LocalizedStringResource = "打开系统实验室"
    static var description = IntentDescription("打开《零点相位》的 iOS 26 系统能力与实时诊断页面。")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentCommandStore.enqueue("systemLab")
        return .result()
    }
}

struct PhaseZeroShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartDailyRiftIntent(),
            phrases: [
                "在 \(.applicationName) 开始每日裂隙",
                "用 \(.applicationName) 启动今日挑战"
            ],
            shortTitle: "每日裂隙",
            systemImageName: "calendar.badge.clock"
        )

        AppShortcut(
            intent: StartDirectorRiftIntent(),
            phrases: [
                "在 \(.applicationName) 生成导演裂隙",
                "让 \(.applicationName) 设计一局挑战"
            ],
            shortTitle: "导演裂隙",
            systemImageName: "brain.head.profile"
        )

        AppShortcut(
            intent: StartFreeRiftIntent(),
            phrases: [
                "在 \(.applicationName) 开始自由裂隙",
                "启动 \(.applicationName)"
            ],
            shortTitle: "自由裂隙",
            systemImageName: "infinity"
        )

        AppShortcut(
            intent: ToggleMotionAimIntent(),
            phrases: [
                "在 \(.applicationName) 切换陀螺精瞄"
            ],
            shortTitle: "切换陀螺精瞄",
            systemImageName: "gyroscope"
        )

        AppShortcut(
            intent: OpenSystemLabIntent(),
            phrases: [
                "打开 \(.applicationName) 系统实验室"
            ],
            shortTitle: "系统实验室",
            systemImageName: "cpu"
        )
    }
}
#endif
