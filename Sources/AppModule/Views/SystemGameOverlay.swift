import SwiftUI

struct SystemGameOverlay: View {
    @ObservedObject private var settings: SettingsStore
    @ObservedObject private var performance: PerformanceGovernor
    @ObservedObject private var motion: MotionAimService
    let directive: RunDirective

    init(model: GameViewModel) {
        self._settings = ObservedObject(wrappedValue: model.settings)
        self._performance = ObservedObject(wrappedValue: model.performance)
        self._motion = ObservedObject(wrappedValue: model.motionAim)
        self.directive = model.activeDirective
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = proxy.phaseZeroLayout

            if settings.showPerformanceHUD {
                telemetry(phone: layout.isPhoneLandscape)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: layout.isPhoneLandscape ? .bottomLeading : .topLeading
                    )
                    .padding(.leading, layout.leadingInset)
                    .padding(.bottom, layout.isPhoneLandscape ? layout.bottomInset + 22 : 0)
                    .padding(.top, layout.isPhoneLandscape ? 0 : 82)
            }
        }
        .allowsHitTesting(false)
    }

    private func telemetry(phone: Bool) -> some View {
        VStack(alignment: .leading, spacing: phone ? 2 : 5) {
            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: phone ? 4 : 6, height: phone ? 4 : 6)
                Text(phone ? "SYS" : "SYSTEM TELEMETRY")
                    .font(.system(size: phone ? 5.5 : 8, weight: .black, design: .monospaced))
                    .tracking(phone ? 0.7 : 1.0)
            }

            if phone {
                Text("\(Int(performance.snapshot.fps.rounded()))/\(performance.snapshot.targetFPS) · ×\(performance.snapshot.renderScale, specifier: "%.2f") · FX\(Int(performance.snapshot.particleScale * 100))")
                    .font(.system(size: 5.5, weight: .black, design: .monospaced))
                    .monospacedDigit()
                if motion.isActive {
                    Text("GYRO \(motion.liveTurnRate, specifier: "%+.2f")")
                        .font(.system(size: 5, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
            } else {
                Text("\(Int(performance.snapshot.fps.rounded())) / \(performance.snapshot.targetFPS) FPS")
                    .font(.caption2.weight(.black).monospacedDigit())
                Text("RENDER ×\(performance.snapshot.renderScale, specifier: "%.2f") · FX \(Int(performance.snapshot.particleScale * 100))%")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(performance.snapshot.thermalLabel)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                if directive.mode == .daily {
                    Text("DAILY ×\(directive.scoreMultiplier, specifier: "%.2f")")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.purple)
                }
                if motion.isActive {
                    Text("GYRO \(motion.liveTurnRate, specifier: "%+.2f")")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
            }
        }
        .padding(.horizontal, phone ? 7 : 11)
        .padding(.vertical, phone ? 5 : 9)
        .background(.black.opacity(phone ? 0.06 : 0.09), in: RoundedRectangle(cornerRadius: phone ? 10 : 15, style: .continuous))
        .glassEffect(
            .regular.tint(statusColor.opacity(phone ? 0.07 : 0.10)),
            in: RoundedRectangle(cornerRadius: phone ? 10 : 15, style: .continuous)
        )
    }

    private var statusColor: Color {
        switch performance.snapshot.thermalLabel {
        case "高温降载", "紧急降载": return .orange
        default: return .mint
        }
    }
}
