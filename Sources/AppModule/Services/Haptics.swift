import UIKit
import CoreHaptics

@MainActor
final class Haptics {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    private var engine: CHHapticEngine?
    private(set) var supportsAdvancedHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    func prepare() {
        light.prepare()
        medium.prepare()
        rigid.prepare()
        selection.prepare()
        notification.prepare()
        prepareEngine()
    }

    func stop() {
        engine?.stop(completionHandler: nil)
        engine = nil
    }

    func play(_ kind: String, enabled: Bool) {
        guard enabled else { return }

        if supportsAdvancedHaptics, playPattern(kind) {
            return
        }
        playFallback(kind)
    }

    private func prepareEngine() {
        guard supportsAdvancedHaptics, engine == nil else { return }
        do {
            let newEngine = try CHHapticEngine()
            newEngine.isAutoShutdownEnabled = true
            newEngine.resetHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    try? self?.engine?.start()
                }
            }
            try newEngine.start()
            engine = newEngine
        } catch {
            supportsAdvancedHaptics = false
            engine = nil
        }
    }

    @discardableResult
    private func playPattern(_ kind: String) -> Bool {
        prepareEngine()
        guard let engine else { return false }

        let events: [CHHapticEvent]
        switch kind {
        case "phase":
            events = [
                transient(time: 0, intensity: 0.92, sharpness: 0.82),
                continuous(time: 0.025, duration: 0.15, intensity: 0.40, sharpness: 0.22),
                transient(time: 0.13, intensity: 0.54, sharpness: 0.98)
            ]
        case "dash":
            events = [
                continuous(time: 0, duration: 0.11, intensity: 0.52, sharpness: 0.35),
                transient(time: 0.08, intensity: 0.70, sharpness: 0.76)
            ]
        case "graze":
            events = [transient(time: 0, intensity: 0.20, sharpness: 1.0)]
        case "shield":
            events = [
                transient(time: 0, intensity: 1.0, sharpness: 0.95),
                continuous(time: 0.01, duration: 0.22, intensity: 0.55, sharpness: 0.16)
            ]
        case "damage":
            events = [
                transient(time: 0, intensity: 1.0, sharpness: 0.35),
                transient(time: 0.10, intensity: 0.72, sharpness: 0.18)
            ]
        case "boss":
            events = [
                transient(time: 0, intensity: 0.86, sharpness: 0.25),
                transient(time: 0.17, intensity: 0.92, sharpness: 0.42),
                transient(time: 0.34, intensity: 1.0, sharpness: 0.70)
            ]
        case "overdrive":
            events = [
                continuous(time: 0, duration: 0.36, intensity: 0.55, sharpness: 0.30),
                transient(time: 0.12, intensity: 0.78, sharpness: 0.75),
                transient(time: 0.30, intensity: 1.0, sharpness: 1.0)
            ]
        case "rank":
            events = [
                transient(time: 0, intensity: 0.46, sharpness: 0.70),
                transient(time: 0.075, intensity: 0.62, sharpness: 0.82),
                transient(time: 0.15, intensity: 0.86, sharpness: 0.96)
            ]
        case "bossDefeat":
            events = [
                transient(time: 0, intensity: 1.0, sharpness: 0.90),
                continuous(time: 0.02, duration: 0.32, intensity: 0.62, sharpness: 0.28),
                transient(time: 0.20, intensity: 0.82, sharpness: 0.70),
                transient(time: 0.39, intensity: 0.54, sharpness: 1.0)
            ]
        case "sectorClear":
            events = [
                transient(time: 0, intensity: 0.38, sharpness: 0.56),
                transient(time: 0.11, intensity: 0.58, sharpness: 0.72)
            ]
        case "launch":
            events = [
                continuous(time: 0, duration: 0.48, intensity: 0.30, sharpness: 0.12),
                transient(time: 0.18, intensity: 0.48, sharpness: 0.58),
                transient(time: 0.38, intensity: 0.72, sharpness: 0.82),
                transient(time: 0.56, intensity: 1.0, sharpness: 1.0)
            ]
        case "upgrade":
            events = [
                transient(time: 0, intensity: 0.42, sharpness: 0.72),
                transient(time: 0.09, intensity: 0.68, sharpness: 0.88)
            ]
        case "selection":
            events = [transient(time: 0, intensity: 0.22, sharpness: 0.78)]
        case "error":
            events = [
                transient(time: 0, intensity: 0.86, sharpness: 0.18),
                transient(time: 0.13, intensity: 0.86, sharpness: 0.18)
            ]
        default:
            events = [transient(time: 0, intensity: 0.32, sharpness: 0.45)]
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }

    private func transient(time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: time
        )
    }

    private func continuous(
        time: TimeInterval,
        duration: TimeInterval,
        intensity: Float,
        sharpness: Float
    ) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: time,
            duration: duration
        )
    }

    private func playFallback(_ kind: String) {
        switch kind {
        case "phase", "boss": rigid.impactOccurred(intensity: 0.78)
        case "bossDefeat": notification.notificationOccurred(.success)
        case "rank", "sectorClear": medium.impactOccurred(intensity: 0.72)
        case "dash": medium.impactOccurred(intensity: 0.64)
        case "upgrade", "overdrive", "launch": notification.notificationOccurred(.success)
        case "damage", "shield", "error": notification.notificationOccurred(.error)
        case "selection", "graze": selection.selectionChanged()
        default: light.impactOccurred(intensity: 0.45)
        }
    }
}
