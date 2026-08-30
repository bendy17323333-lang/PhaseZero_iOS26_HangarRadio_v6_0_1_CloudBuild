import Foundation
import CoreMotion
import Combine

@MainActor
final class MotionAimService: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var isAmbientActive = false
    @Published private(set) var liveTurnRate = 0.0
    @Published private(set) var interfaceTiltX = 0.0
    @Published private(set) var interfaceTiltY = 0.0

    var onTurnRate: ((Double) -> Void)?

    private let manager = CMMotionManager()
    private var sensitivity = 1.0
    private var inverted = false
    private var aimEnabled = false
    private var ambientEnabled = false
    private var filteredRate = 0.0
    private var smoothedTiltX = 0.0
    private var smoothedTiltY = 0.0
    private var baselineRoll: Double?
    private var baselinePitch: Double?
    private var lastInterfacePublish = 0.0
    private var lastAimPublish = 0.0
    private var lastSentTurnRate = 0.0

    var isSupported: Bool { manager.isDeviceMotionAvailable }

    var statusText: String {
        if !isSupported { return "设备不提供陀螺仪数据" }
        if isActive { return "陀螺精瞄运行中" }
        if isAmbientActive { return "界面景深采样中" }
        return "陀螺仪待机"
    }

    func configure(
        aimEnabled: Bool,
        ambientEnabled: Bool,
        sensitivity: Double,
        inverted: Bool
    ) {
        self.aimEnabled = aimEnabled
        self.ambientEnabled = ambientEnabled
        self.sensitivity = min(max(sensitivity, 0.25), 2.5)
        self.inverted = inverted
        self.isActive = aimEnabled && isSupported
        self.isAmbientActive = ambientEnabled && isSupported

        if aimEnabled || ambientEnabled {
            startSampling()
        } else {
            stop()
        }
    }

    func recenter() {
        baselineRoll = nil
        baselinePitch = nil
        filteredRate = 0
        smoothedTiltX = 0
        smoothedTiltY = 0
        liveTurnRate = 0
        interfaceTiltX = 0
        interfaceTiltY = 0
        lastSentTurnRate = 0
        onTurnRate?(0)
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isActive = false
        isAmbientActive = false
        filteredRate = 0
        smoothedTiltX = 0
        smoothedTiltY = 0
        liveTurnRate = 0
        interfaceTiltX = 0
        interfaceTiltY = 0
        baselineRoll = nil
        baselinePitch = nil
        lastInterfacePublish = 0
        lastAimPublish = 0
        lastSentTurnRate = 0
        onTurnRate?(0)
    }

    private func startSampling() {
        guard isSupported else {
            isActive = false
            isAmbientActive = false
            return
        }
        guard !manager.isDeviceMotionActive else {
            manager.deviceMotionUpdateInterval = aimEnabled ? 1.0 / 60.0 : 1.0 / 30.0
            return
        }

        // The sensor may sample quickly, but the UI does not need to rebuild at
        // 90 Hz just to move one highlight by two pixels.
        manager.deviceMotionUpdateInterval = aimEnabled ? 1.0 / 60.0 : 1.0 / 30.0
        manager.showsDeviceMovementDisplay = false
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if error != nil {
                    self.stop()
                    return
                }
                guard let motion else { return }
                self.consume(motion)
            }
        }
    }

    private func consume(_ motion: CMDeviceMotion) {
        if baselineRoll == nil {
            baselineRoll = motion.attitude.roll
            baselinePitch = motion.attitude.pitch
        }

        if ambientEnabled,
           let baseRoll = baselineRoll,
           let basePitch = baselinePitch {
            let rollDelta = shortestAngle(from: baseRoll, to: motion.attitude.roll)
            let pitchDelta = shortestAngle(from: basePitch, to: motion.attitude.pitch)
            let targetX = min(max(rollDelta / 0.42, -1), 1)
            let targetY = min(max(pitchDelta / 0.34, -1), 1)
            smoothedTiltX += (targetX - smoothedTiltX) * 0.14
            smoothedTiltY += (targetY - smoothedTiltY) * 0.14
        } else {
            smoothedTiltX += (0 - smoothedTiltX) * 0.18
            smoothedTiltY += (0 - smoothedTiltY) * 0.18
        }

        // Limit SwiftUI invalidation to roughly 24 Hz and quantise tiny changes.
        if motion.timestamp - lastInterfacePublish >= 1.0 / 24.0 {
            lastInterfacePublish = motion.timestamp
            let nextX = (smoothedTiltX * 250).rounded() / 250
            let nextY = (smoothedTiltY * 250).rounded() / 250
            if abs(nextX - interfaceTiltX) > 0.003 { interfaceTiltX = nextX }
            if abs(nextY - interfaceTiltY) > 0.003 { interfaceTiltY = nextY }
        }

        guard aimEnabled else {
            if liveTurnRate != 0 || lastSentTurnRate != 0 {
                filteredRate = 0
                liveTurnRate = 0
                lastSentTurnRate = 0
                onTurnRate?(0)
            }
            return
        }

        var raw = motion.rotationRate.z * sensitivity
        if inverted { raw *= -1 }
        raw = min(max(raw, -3.2), 3.2)
        filteredRate += (raw - filteredRate) * 0.24
        if abs(filteredRate) < 0.015 { filteredRate = 0 }

        if motion.timestamp - lastAimPublish >= 1.0 / 30.0 {
            lastAimPublish = motion.timestamp
            let next = (filteredRate * 1000).rounded() / 1000
            liveTurnRate = next
            if abs(next - lastSentTurnRate) >= 0.004 || (next == 0 && lastSentTurnRate != 0) {
                lastSentTurnRate = next
                onTurnRate?(next)
            }
        }
    }

    private func shortestAngle(from: Double, to: Double) -> Double {
        atan2(sin(to - from), cos(to - from))
    }
}
