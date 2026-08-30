import Foundation
import UIKit
import QuartzCore
import Combine

struct PerformanceSnapshot: Equatable {
    var fps: Double = 0
    var renderScale: Double = 1.42
    var particleScale: Double = 0.76
    var targetFPS: Int = 60
    var thermalLabel = "正常"
    var lowPower = false

    var compactLabel: String {
        let roundedFPS = Int(fps.rounded())
        return "\(roundedFPS) FPS · \(thermalLabel)"
    }
}

@MainActor
final class PerformanceGovernor: NSObject, ObservableObject {
    @Published private(set) var snapshot = PerformanceSnapshot()

    var onPayload: (([String: Any]) -> Void)?

    private var displayLink: CADisplayLink?
    private var profile: RenderProfile = .adaptive
    private var sampleStart: CFTimeInterval = 0
    private var frames = 0
    private var observers: [NSObjectProtocol] = []

    var maximumRefreshRate: Int {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.maximumFramesPerSecond }
            .max() ?? 60
    }

    override init() {
        super.init()
        observers.append(
            NotificationCenter.default.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.recalculate(forceSend: true) }
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.recalculate(forceSend: true) }
            }
        )
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        displayLink?.invalidate()
    }

    func start(profile: RenderProfile) {
        self.profile = profile
        guard displayLink == nil else {
            recalculate(forceSend: true)
            return
        }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        let maxFPS = Float(maximumRefreshRate)
        link.preferredFrameRateRange = CAFrameRateRange(
            minimum: 30,
            maximum: maxFPS,
            preferred: maxFPS
        )
        link.add(to: .main, forMode: .common)
        displayLink = link
        recalculate(forceSend: true)
    }

    func setProfile(_ profile: RenderProfile) {
        self.profile = profile
        recalculate(forceSend: true)
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        sampleStart = 0
        frames = 0
    }

    @objc private func tick(_ link: CADisplayLink) {
        if sampleStart == 0 {
            sampleStart = link.timestamp
            return
        }
        frames += 1
        let elapsed = link.timestamp - sampleStart
        guard elapsed >= 0.75 else { return }
        snapshot.fps = Double(frames) / elapsed
        sampleStart = link.timestamp
        frames = 0
        recalculate(forceSend: false)
    }

    private func recalculate(forceSend: Bool) {
        let process = ProcessInfo.processInfo
        let thermal = process.thermalState
        let lowPower = process.isLowPowerModeEnabled
        let fps = snapshot.fps
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone

        var renderScale: Double
        var particleScale: Double
        var targetFPS: Int

        switch profile {
        case .quality:
            renderScale = isPhone
                ? (maximumRefreshRate > 60 ? 1.52 : 1.58)
                : (maximumRefreshRate > 60 ? 1.78 : 1.82)
            particleScale = isPhone ? 0.82 : 0.96
            targetFPS = maximumRefreshRate
        case .battery:
            renderScale = isPhone ? 1.0 : 1.08
            particleScale = isPhone ? 0.38 : 0.48
            targetFPS = 60
        case .adaptive:
            renderScale = isPhone
                ? (maximumRefreshRate > 60 ? 1.26 : 1.32)
                : (maximumRefreshRate > 60 ? 1.42 : 1.50)
            particleScale = isPhone ? 0.60 : 0.74
            targetFPS = maximumRefreshRate > 60 ? 90 : 60
        }

        if lowPower {
            renderScale = min(renderScale, 1.28)
            particleScale = min(particleScale, 0.58)
            targetFPS = min(targetFPS, 60)
        }

        switch thermal {
        case .nominal:
            break
        case .fair:
            renderScale *= 0.90
            particleScale *= 0.82
        case .serious:
            renderScale = min(renderScale, 1.28)
            particleScale = min(particleScale, 0.52)
            targetFPS = min(targetFPS, 60)
        case .critical:
            renderScale = 1.0
            particleScale = 0.34
            targetFPS = 30
        @unknown default:
            renderScale = min(renderScale, 1.4)
            particleScale = min(particleScale, 0.7)
        }

        if profile == .adaptive, fps > 1 {
            let expected = Double(targetFPS)
            if fps < expected * 0.72 {
                renderScale *= 0.82
                particleScale *= 0.70
            } else if fps < expected * 0.88 {
                renderScale *= 0.92
                particleScale *= 0.86
            }
        }

        renderScale = min(max(renderScale, 1.0), isPhone ? 1.65 : 1.90)
        particleScale = min(max(particleScale, 0.28), 1.0)
        let newSnapshot = PerformanceSnapshot(
            fps: fps,
            renderScale: renderScale,
            particleScale: particleScale,
            targetFPS: targetFPS,
            thermalLabel: Self.thermalLabel(thermal),
            lowPower: lowPower
        )
        let policyChanged = abs(newSnapshot.renderScale - snapshot.renderScale) >= 0.019
            || abs(newSnapshot.particleScale - snapshot.particleScale) >= 0.019
            || newSnapshot.targetFPS != snapshot.targetFPS
            || newSnapshot.thermalLabel != snapshot.thermalLabel
            || newSnapshot.lowPower != snapshot.lowPower
        snapshot = newSnapshot

        if policyChanged || forceSend {
            onPayload?([
                "renderScale": renderScale,
                "particleScale": particleScale,
                "targetFPS": targetFPS,
                "thermal": newSnapshot.thermalLabel,
                "lowPower": lowPower
            ])
        }
    }

    private static func thermalLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "温度正常"
        case .fair: return "轻度降载"
        case .serious: return "高温降载"
        case .critical: return "紧急降载"
        @unknown default: return "状态未知"
        }
    }
}
