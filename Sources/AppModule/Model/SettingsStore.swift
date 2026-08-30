import Foundation
import Combine
import UIKit

enum AimAssistPreset: String, CaseIterable, Identifiable {
    case light
    case standard
    case strong

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "轻度"
        case .standard: return "标准"
        case .strong: return "强力"
        }
    }

    var multiplier: Double {
        switch self {
        case .light: return 0.82
        case .standard: return 1.0
        case .strong: return 1.26
        }
    }
}

enum RenderProfile: String, CaseIterable, Identifiable {
    case adaptive
    case quality
    case battery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .adaptive: return "自适应"
        case .quality: return "画质优先"
        case .battery: return "省电"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let sound = "native.sound"
        static let haptics = "native.haptics"
        static let aimAssist = "native.aimAssist"
        static let renderProfile = "native.renderProfile"
        static let touchOpacity = "native.touchOpacity"
        static let invertAimY = "native.invertAimY"
        static let showTouchWithController = "native.showTouchWithController"
        static let aiDirector = "native.aiDirector"
        static let motionAim = "native.motionAim"
        static let motionSensitivity = "native.motionSensitivity"
        static let invertMotion = "native.invertMotion"
        static let performanceHUD = "native.performanceHUD"
        static let spectaclePreset = "native.spectaclePreset"
        static let interfaceParallax = "native.interfaceParallax"
        static let duckGameMusicForAppleMusic = "native.duckGameMusicForAppleMusic"
    }

    private let defaults: UserDefaults
    private var pendingChangeTask: Task<Void, Never>?
    private var pendingValues: [String: Any] = [:]
    var onChange: (() -> Void)?

    @Published var soundEnabled: Bool { didSet { save(Key.sound, soundEnabled) } }
    @Published var hapticsEnabled: Bool { didSet { save(Key.haptics, hapticsEnabled) } }
    @Published var aimAssist: AimAssistPreset { didSet { save(Key.aimAssist, aimAssist.rawValue) } }
    @Published var renderProfile: RenderProfile { didSet { save(Key.renderProfile, renderProfile.rawValue) } }
    @Published var touchOpacity: Double { didSet { save(Key.touchOpacity, touchOpacity) } }
    @Published var invertAimY: Bool { didSet { save(Key.invertAimY, invertAimY) } }
    @Published var showTouchWithController: Bool { didSet { save(Key.showTouchWithController, showTouchWithController) } }
    @Published var aiDirectorEnabled: Bool { didSet { save(Key.aiDirector, aiDirectorEnabled) } }
    @Published var motionAimEnabled: Bool { didSet { save(Key.motionAim, motionAimEnabled) } }
    @Published var motionSensitivity: Double { didSet { save(Key.motionSensitivity, motionSensitivity) } }
    @Published var invertMotion: Bool { didSet { save(Key.invertMotion, invertMotion) } }
    @Published var showPerformanceHUD: Bool { didSet { save(Key.performanceHUD, showPerformanceHUD) } }
    @Published var spectaclePreset: SpectaclePreset { didSet { save(Key.spectaclePreset, spectaclePreset.rawValue) } }
    @Published var interfaceParallaxEnabled: Bool { didSet { save(Key.interfaceParallax, interfaceParallaxEnabled) } }
    @Published var duckGameMusicForAppleMusic: Bool { didSet { save(Key.duckGameMusicForAppleMusic, duckGameMusicForAppleMusic) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let defaultTouchOpacity = UIDevice.current.userInterfaceIdiom == .phone ? 0.48 : 0.58
        self.soundEnabled = defaults.object(forKey: Key.sound) as? Bool ?? true
        self.hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        self.aimAssist = AimAssistPreset(rawValue: defaults.string(forKey: Key.aimAssist) ?? "") ?? .standard
        self.renderProfile = RenderProfile(rawValue: defaults.string(forKey: Key.renderProfile) ?? "") ?? .adaptive
        self.touchOpacity = defaults.object(forKey: Key.touchOpacity) as? Double ?? defaultTouchOpacity
        self.invertAimY = defaults.object(forKey: Key.invertAimY) as? Bool ?? false
        self.showTouchWithController = defaults.object(forKey: Key.showTouchWithController) as? Bool ?? false
        self.aiDirectorEnabled = defaults.object(forKey: Key.aiDirector) as? Bool ?? true
        self.motionAimEnabled = defaults.object(forKey: Key.motionAim) as? Bool ?? false
        self.motionSensitivity = defaults.object(forKey: Key.motionSensitivity) as? Double ?? 0.86
        self.invertMotion = defaults.object(forKey: Key.invertMotion) as? Bool ?? false
        self.showPerformanceHUD = defaults.object(forKey: Key.performanceHUD) as? Bool ?? false
        self.spectaclePreset = SpectaclePreset(rawValue: defaults.string(forKey: Key.spectaclePreset) ?? "") ?? .cinematic
        self.interfaceParallaxEnabled = defaults.object(forKey: Key.interfaceParallax) as? Bool ?? true
        self.duckGameMusicForAppleMusic = defaults.object(forKey: Key.duckGameMusicForAppleMusic) as? Bool ?? true
    }

    func nativePayload(performance: PerformanceSnapshot, externalMusicActive: Bool) -> [String: Any] {
        let boostedParticles = min(1.2, performance.particleScale * spectaclePreset.particleMultiplier)
        return [
            "sound": soundEnabled,
            "aimAssist": aimAssist.multiplier,
            "renderScale": performance.renderScale,
            "particleScale": boostedParticles,
            "targetFPS": performance.targetFPS,
            "motionAim": motionAimEnabled,
            "spectacleScale": spectaclePreset.nativeFXScale,
            "externalMusicActive": externalMusicActive && duckGameMusicForAppleMusic
        ]
    }

    /// Coalesces both UserDefaults writes and expensive bridge/configuration work.
    /// Continuous sliders used to rebuild several render layers for every pixel of drag.
    private func save(_ key: String, _ value: Any) {
        pendingValues[key] = value
        scheduleChangeNotification()
    }

    private func scheduleChangeNotification() {
        pendingChangeTask?.cancel()
        pendingChangeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 110_000_000)
            guard !Task.isCancelled, let self else { return }
            self.pendingChangeTask = nil
            self.commitPendingValues()
            self.onChange?()
        }
    }

    func flushPendingChanges() {
        pendingChangeTask?.cancel()
        pendingChangeTask = nil
        commitPendingValues()
        onChange?()
    }

    private func commitPendingValues() {
        guard !pendingValues.isEmpty else { return }
        for (key, value) in pendingValues {
            defaults.set(value, forKey: key)
        }
        pendingValues.removeAll(keepingCapacity: true)
    }
}
