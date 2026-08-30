import Foundation
import Combine
import UIKit
import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {
    let bridge = GameBridge()
    let settings = SettingsStore()
    let controllerService = ControllerService()
    let haptics = Haptics()
    let motionAim = MotionAimService()
    let performance = PerformanceGovernor()
    let aiDirector = AIDirector()
    let archive = RunArchive()
    let progression = MetaProgressionStore()
    let appleMusic = AppleMusicService()

    @Published var state: PhaseZeroState = .loading {
        didSet {
            updateIdleTimer()
            updateMotionState()
        }
    }
    @Published var hud = HUDSnapshot()
    @Published var upgrades: [UpgradeChoice] = []
    @Published var isRelicChoice = false
    @Published var rerolls = 0
    @Published var selectedUpgradeIndex = 0
    @Published var gameOver = GameOverSnapshot()
    @Published var toast: ToastMessage?
    @Published var webReady = false
    @Published var controllerName: String?
    @Published var showSettings = false
    @Published var showSystemLab = false
    @Published var showHangar = false
    @Published var showPhaseRadio = false
    @Published var lastPhiReward = 0
    @Published var errorMessage: String?
    @Published var selectedRunMode: RunMode = .free
    @Published var activeDirective: RunDirective = .free
    @Published var dailyDirective: RunDirective = .daily()
    @Published var directorDirective: RunDirective = .directorFallback()
    @Published var spectacleEvent: SpectacleEvent?
    @Published var isLaunching = false
    @Published var launchDirective: RunDirective?

    private var pendingDirective: RunDirective?
    private var toastTask: Task<Void, Never>?
    private var bootWatchdog: Task<Void, Never>?
    private var directorTask: Task<Void, Never>?
    private var launchTask: Task<Void, Never>?
    private var spectacleTask: Task<Void, Never>?
    private var servicesStarted = false
    private var directorHasBeenRequested = false
    private var runSequence = 0
    private var lastArchivedRunSequence = -1

    init() {
        bridge.model = self
        controllerService.delegate = self

        settings.onChange = { [weak self] in
            self?.settingsDidChange()
        }
        performance.onPayload = { [weak self] _ in
            self?.pushSettings()
        }
        motionAim.onTurnRate = { [weak self] rate in
            guard let self, self.state == .playing else { return }
            self.bridge.send(command: "motion", payload: ["turnRate": rate])
        }
        appleMusic.onPlaybackActivityChanged = { [weak self] _ in
            self?.pushSettings()
        }
    }

    var bestScore: Int { max(hud.highScore, gameOver.highScore) }
    var controllerConnected: Bool { controllerName != nil }
    var dailyBest: Int { archive.bestScore(for: dailyDirective) }
    var menuDirective: RunDirective {
        switch selectedRunMode {
        case .free: return .free
        case .daily: return dailyDirective
        case .director: return directorDirective
        }
    }

    func startServices() {
        guard !servicesStarted else { return }
        servicesStarted = true
        print("[PhaseZero] Starting spectacle-engine services")

        controllerService.start()
        haptics.prepare()
        performance.start(profile: settings.renderProfile)
        aiDirector.refreshAvailability()
        appleMusic.bootstrap()
        aiDirector.prepareBriefing(for: dailyDirective, enabled: settings.aiDirectorEnabled)
        updateMotionState()
        processPendingIntent()
    }

    func beginEngineBootWatchdog() {
        bootWatchdog?.cancel()
        bootWatchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, !self.webReady, self.state == .loading else { return }
                self.bridgeFailed("游戏引擎 12 秒内没有回应。请打开左下角控制台查看 [PhaseZero] 日志。")
            }
        }
    }

    func selectRunMode(_ mode: RunMode) {
        guard selectedRunMode != mode else { return }
        selectedRunMode = mode
        haptics.play("selection", enabled: settings.hapticsEnabled)
        switch mode {
        case .daily:
            aiDirector.prepareBriefing(for: dailyDirective, enabled: settings.aiDirectorEnabled)
        case .director:
            if !directorHasBeenRequested { refreshDirectorContract() }
        case .free:
            break
        }
    }

    func startSelectedRun() {
        beginLaunch(directive: menuDirective)
    }

    func beginLaunch(directive: RunDirective) {
        guard !isLaunching else { return }
        launchTask?.cancel()
        launchDirective = directive
        isLaunching = true
        haptics.play("launch", enabled: settings.hapticsEnabled)

        let duration: UInt64
        switch settings.spectaclePreset {
        case .balanced: duration = 480_000_000
        case .cinematic: duration = 820_000_000
        case .unhinged: duration = 980_000_000
        }

        launchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: duration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                self.isLaunching = false
                self.launchDirective = nil
                self.startGame(directive: directive)
            }
        }
    }

    func startGame(mode: RunMode = .free) {
        let directive: RunDirective
        switch mode {
        case .free: directive = .free
        case .daily: directive = dailyDirective
        case .director: directive = directorDirective
        }
        startGame(directive: directive)
    }

    func refreshDirectorContract(startAfterGeneration: Bool = false) {
        guard !aiDirector.isGeneratingContract else { return }
        directorHasBeenRequested = true
        let seed = UInt64(Date().timeIntervalSince1970 * 1_000)
        directorDirective = .directorFallback(seed: seed)
        haptics.play("selection", enabled: settings.hapticsEnabled)

        directorTask?.cancel()
        directorTask = Task { [weak self] in
            guard let self else { return }
            let generated = await self.aiDirector.generateDirectorContract(
                seed: seed,
                enabled: self.settings.aiDirectorEnabled
            )
            guard !Task.isCancelled else { return }
            self.directorDirective = generated
            if startAfterGeneration {
                self.beginLaunch(directive: generated)
            }
            if self.selectedRunMode == .director {
                self.showToast(
                    self.aiDirector.availability.isAvailable ? "本地 AI 已重组导演协议" : "已使用离线白名单生成协议",
                    durationMS: 1200
                )
            }
        }
    }

    func startGame(directive: RunDirective) {
        selectedRunMode = directive.mode
        activeDirective = directive
        runSequence += 1
        lastArchivedRunSequence = -1
        lastPhiReward = 0

        guard webReady else {
            pendingDirective = directive
            return
        }

        bridge.send(
            command: "start",
            payload: runPayload(for: directive)
        )
    }

    func restartGame() {
        runSequence += 1
        lastArchivedRunSequence = -1
        lastPhiReward = 0
        bridge.send(
            command: "restart",
            payload: runPayload(for: activeDirective)
        )
    }

    func pauseGame() { bridge.send(command: "pause") }
    func resumeGame() { bridge.send(command: "resume") }
    func returnToMenu() { bridge.send(command: "menu") }
    func shiftPhase() { bridge.send(command: "phase") }
    func dash() { bridge.send(command: "dash") }

    func chooseUpgrade(_ index: Int) {
        bridge.send(command: "chooseUpgrade", payload: ["index": index])
    }

    func reroll() { bridge.send(command: "reroll") }

    func move(x: Double, y: Double, magnitude: Double, active: Bool) {
        bridge.send(command: "move", payload: ["x": x, "y": y, "magnitude": magnitude, "active": active])
    }

    func aim(x: Double, y: Double, magnitude: Double, active: Bool) {
        let adjustedY = settings.invertAimY ? -y : y
        bridge.send(command: "aim", payload: ["x": x, "y": adjustedY, "magnitude": magnitude, "active": active])
    }

    func recenterMotionAim() {
        motionAim.recenter()
        haptics.play("selection", enabled: settings.hapticsEnabled)
        showToast("陀螺精瞄已归零", durationMS: 900)
    }

    func previewSpectacle(_ kind: SpectacleKind) {
        let label: String
        let detail: String
        let hapticKind: String
        let rank: String

        switch kind {
        case .phase:
            label = "PHASE SHIFT"
            detail = "REFRACTION RING // TEST"
            hapticKind = "phase"
            rank = hud.styleRank
        case .boss:
            label = "PRISM WARDEN"
            detail = "HOSTILE SIGNATURE // TEST"
            hapticKind = "boss"
            rank = hud.styleRank
        case .overdrive:
            label = "OVERDRIVE"
            detail = "SAFETY INTERLOCK // TEST"
            hapticKind = "overdrive"
            rank = hud.styleRank
        case .rank:
            label = "SSS"
            detail = "STYLE ENGINE // TEST"
            hapticKind = "rank"
            rank = "SSS"
        default:
            label = kind.rawValue.uppercased()
            detail = "SPECTACLE PREVIEW"
            hapticKind = "selection"
            rank = hud.styleRank
        }

        haptics.play(hapticKind, enabled: settings.hapticsEnabled)
        presentSpectacle(
            SpectacleEvent(
                kind: kind,
                label: label,
                detail: detail,
                phase: hud.phase,
                intensity: settings.spectaclePreset.nativeFXScale,
                directionX: 0.9,
                directionY: -0.15,
                rank: rank
            )
        )
    }

    func pushSettings() {
        bridge.send(
            command: "settings",
            payload: settings.nativePayload(
                performance: performance.snapshot,
                externalMusicActive: appleMusic.isPlaying
            )
        )
    }

    func flushSettingsChanges() {
        settings.flushPendingChanges()
    }

    func activateLaboratoryOverride() {
        guard progression.activateLaboratoryOverride() else { return }
        haptics.play("overdrive", enabled: settings.hapticsEnabled)
        presentSpectacle(
            SpectacleEvent(
                kind: .overdrive,
                label: "ACCESS LEVEL // ROOT",
                detail: "FRAME AUTHORITY OVERRIDE",
                phase: hud.phase,
                intensity: max(1.05, settings.spectaclePreset.nativeFXScale),
                directionX: 0,
                directionY: -1,
                rank: "ROOT"
            )
        )
        showToast("机库权限已提升", durationMS: 1_150)
    }

    func appWillResignActive() {
        UIApplication.shared.isIdleTimerDisabled = false
        settings.flushPendingChanges()
        motionAim.stop()
        if state == .playing { pauseGame() }
    }

    func appBecameActive() {
        refreshDailyDirectiveIfNeeded()
        processPendingIntent()
        haptics.prepare()
        appleMusic.refreshAuthorizationState()
        appleMusic.startMonitoring()
        appleMusic.refreshPlaybackSnapshot()
        updateIdleTimer()
        updateMotionState()
        pushSettings()
    }

    func handleBridgeMessage(_ body: [String: Any]) {
        let type = body.string("type")
        let payload = body.dictionary("payload")

        switch type {
        case "ready":
            bootWatchdog?.cancel()
            webReady = true
            hud.highScore = payload.int("highScore")
            pushSettings()
            if let pendingDirective {
                self.pendingDirective = nil
                bridge.send(
                    command: "start",
                    payload: runPayload(for: pendingDirective)
                )
            }
        case "state":
            if let next = PhaseZeroState(rawValue: payload.string("state")) {
                withAnimation(.snappy(duration: 0.28)) { state = next }
            }
            hud.highScore = max(hud.highScore, payload.int("highScore"))
        case "hud":
            hud = HUDSnapshot.decode(payload)
        case "upgrade":
            isRelicChoice = payload.bool("relic")
            rerolls = payload.int("rerolls")
            upgrades = payload.dictionaries("choices").map(UpgradeChoice.decode)
            selectedUpgradeIndex = min(selectedUpgradeIndex, max(0, upgrades.count - 1))
        case "gameOver":
            gameOver = GameOverSnapshot.decode(payload)
            archiveCurrentRunIfNeeded()
        case "toast":
            showToast(payload.string("text"), durationMS: payload.double("duration"))
        case "haptic":
            let kind = payload.string("kind")
            haptics.play(kind, enabled: settings.hapticsEnabled)
        case "spectacle":
            presentSpectacle(SpectacleEvent.decode(payload))
        case "bridgeError":
            bridgeFailed("JavaScript 引擎错误：\(payload.string("message", fallback: "未知错误"))")
        default:
            break
        }
    }

    func bridgeFailed(_ message: String) {
        bootWatchdog?.cancel()
        errorMessage = message
        state = .error
    }

    func bridgeWarning(_ message: String) {
        #if DEBUG
        print("PhaseZero bridge warning:", message)
        #endif
    }

    func webProcessTerminated() {
        showToast("游戏渲染进程已重启", durationMS: 1500)
        state = .loading
        webReady = false
    }

    private func settingsDidChange() {
        performance.setProfile(settings.renderProfile)
        updateMotionState()
        if settings.aiDirectorEnabled, selectedRunMode == .daily {
            aiDirector.prepareBriefing(for: dailyDirective, enabled: true)
        }
        pushSettings()
    }

    private func updateMotionState() {
        motionAim.configure(
            aimEnabled: state == .playing && settings.motionAimEnabled,
            ambientEnabled: settings.interfaceParallaxEnabled && state != .error,
            sensitivity: settings.motionSensitivity,
            inverted: settings.invertMotion
        )
    }


    private func presentSpectacle(_ event: SpectacleEvent) {
        spectacleTask?.cancel()
        spectacleEvent = event
        let duration: UInt64
        switch event.kind {
        case .boss, .bossDefeat, .death: duration = 1_420_000_000
        case .overdrive, .rank, .sectorClear: duration = 1_000_000_000
        case .phase, .dash, .damage, .shield, .upgrade, .wave, .revive: duration = 700_000_000
        case .graze, .pulse: duration = 360_000_000
        }
        spectacleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: duration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self?.spectacleEvent?.id == event.id {
                    self?.spectacleEvent = nil
                }
            }
        }
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = state == .playing || state == .ending || state == .upgrade
    }

    private func refreshDailyDirectiveIfNeeded() {
        let refreshed = RunDirective.daily()
        guard refreshed.id != dailyDirective.id else { return }
        dailyDirective = refreshed
        aiDirector.prepareBriefing(for: refreshed, enabled: settings.aiDirectorEnabled)
    }

    private func processPendingIntent() {
        guard let command = IntentCommandStore.consume() else { return }
        switch command {
        case "daily":
            selectedRunMode = .daily
            startGame(mode: .daily)
        case "free":
            selectedRunMode = .free
            startGame(mode: .free)
        case "director":
            selectedRunMode = .director
            refreshDirectorContract(startAfterGeneration: true)
        case "toggleMotion":
            settings.motionAimEnabled.toggle()
            showToast(settings.motionAimEnabled ? "陀螺精瞄已启用" : "陀螺精瞄已关闭", durationMS: 1000)
        case "systemLab":
            showSystemLab = true
        default:
            break
        }
    }

    private func archiveCurrentRunIfNeeded() {
        guard lastArchivedRunSequence != runSequence else { return }
        lastArchivedRunSequence = runSequence
        lastPhiReward = progression.award(for: gameOver, directive: activeDirective)
        let record = RunRecord(
            mode: activeDirective.mode,
            directiveID: activeDirective.id,
            score: gameOver.score,
            wave: gameOver.wave,
            level: gameOver.level,
            kills: gameOver.kills,
            shareCode: activeDirective.shareCode
        )
        archive.append(record)
        aiDirector.prepareDebrief(
            record: record,
            directive: activeDirective,
            enabled: settings.aiDirectorEnabled
        )
    }

    private func runPayload(for directive: RunDirective) -> [String: Any] {
        var payload = directive.payload(briefing: aiDirector.briefingText(for: directive))
        payload["machine"] = progression.activeLoadoutPayload()
        return payload
    }

    private func cycleRunMode(delta: Int) {
        let modes = RunMode.allCases
        guard let current = modes.firstIndex(of: selectedRunMode), !modes.isEmpty else { return }
        let next = (current + delta + modes.count) % modes.count
        selectRunMode(modes[next])
    }

    private func showToast(_ text: String, durationMS: Double) {
        let duration = max(0.5, durationMS / 1000)
        let message = ToastMessage(text: text, duration: duration)
        toastTask?.cancel()
        toast = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self?.toast?.id == message.id { self?.toast = nil }
            }
        }
    }
}

extension GameViewModel: ControllerServiceDelegate {
    func controllerConnectionChanged(name: String?) {
        controllerName = name
        if let name {
            showToast("\(name) 已连接", durationMS: 1100)
        }
    }

    func controllerAxesChanged(_ payload: [String: Any]) {
        bridge.send(command: "controller", payload: payload)
    }

    func controllerPressed(_ action: ControllerAction) {
        switch state {
        case .menu:
            switch action {
            case .primary:
                startSelectedRun()
            case .previous:
                cycleRunMode(delta: -1)
            case .next:
                cycleRunMode(delta: 1)
            default:
                break
            }
        case .playing:
            switch action {
            case .primary: shiftPhase()
            case .secondary: dash()
            case .pause: pauseGame()
            default: break
            }
        case .paused:
            switch action {
            case .primary, .pause: resumeGame()
            case .secondary: returnToMenu()
            default: break
            }
        case .upgrade:
            switch action {
            case .previous:
                selectedUpgradeIndex = max(0, selectedUpgradeIndex - 1)
                haptics.play("selection", enabled: settings.hapticsEnabled)
            case .next:
                selectedUpgradeIndex = min(max(0, upgrades.count - 1), selectedUpgradeIndex + 1)
                haptics.play("selection", enabled: settings.hapticsEnabled)
            case .primary:
                if upgrades.indices.contains(selectedUpgradeIndex) { chooseUpgrade(upgrades[selectedUpgradeIndex].index) }
            case .reroll:
                if rerolls > 0 { reroll() }
            default: break
            }
        case .over:
            switch action {
            case .primary: restartGame()
            case .secondary: returnToMenu()
            default: break
            }
        default:
            break
        }
    }
}
