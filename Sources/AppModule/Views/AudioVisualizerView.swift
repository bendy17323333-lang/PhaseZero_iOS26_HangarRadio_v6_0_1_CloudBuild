import Foundation
import SwiftUI

struct PhaseAudioVisualizer: View {
    let seed: String
    let playbackTime: TimeInterval
    let isPlaying: Bool
    var tint: Color = .cyan
    var secondaryTint: Color = .purple
    var suspended = false
    var barCount = 28

    var body: some View {
        Group {
            if isPlaying && !suspended {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: suspended)) { timeline in
                    // Use a monotonic wall-clock phase while playing. Adding the polled
                    // playback position to wall time made the spectrum jump and briefly
                    // run at double speed every time MusicKit refreshed its progress.
                    spectrum(at: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                spectrum(at: playbackTime)
            }
        }
        .accessibilityLabel("程序性音乐响应可视化")
        .accessibilityValue(isPlaying ? "播放中" : "暂停")
    }

    private func spectrum(at time: TimeInterval) -> some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let count = max(12, barCount)
            let spacing = max(2, size.width * 0.006)
            let width = max(1.5, (size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            let seedValue = deterministicSeed(seed)
            let baseline = size.height * 0.50

            var primaryPath = Path()
            var secondaryPath = Path()
            var peakPath = Path()

            for index in 0..<count {
                let i = Double(index)
                let waveA = sin(time * (2.0 + Double(seedValue % 7) * 0.07) + i * 0.49)
                let waveB = sin(time * 0.83 + i * 0.23 + Double((seedValue >> 5) % 13))
                let waveC = cos(time * 3.1 + i * 0.77)
                let pulse = sin(time * 0.42 + Double(seedValue % 31) * 0.11) * 0.06
                let envelope = 0.18 + 0.82 * pow(sin((i + 2) / Double(count + 3) * .pi), 0.72)
                let activity = isPlaying ? 1.0 : 0.18
                let normalized = min(1, max(0.08, (0.43 + pulse + waveA * 0.24 + waveB * 0.18 + waveC * 0.09) * envelope * activity))
                let height = max(3, size.height * normalized)
                let x = CGFloat(index) * (width + spacing)
                let rect = CGRect(x: x, y: baseline - height * 0.5, width: width, height: height)
                let rounded = Path(roundedRect: rect, cornerRadius: min(width * 0.5, 4))
                let mix = Double(index) / Double(max(1, count - 1))

                if normalized > 0.78 {
                    peakPath.addPath(rounded)
                } else if mix < 0.55 {
                    primaryPath.addPath(rounded)
                } else {
                    secondaryPath.addPath(rounded)
                }
            }

            // Three batched fills instead of one render-state change per bar. The
            // visualizer stays decorative and inexpensive even on a 120 Hz display.
            context.fill(primaryPath, with: .color(tint.opacity(0.84)))
            context.fill(secondaryPath, with: .color(secondaryTint.opacity(0.80)))
            context.fill(peakPath, with: .color(.white.opacity(0.90)))

            var horizon = Path()
            horizon.move(to: CGPoint(x: 0, y: baseline))
            horizon.addLine(to: CGPoint(x: size.width, y: baseline))
            context.stroke(horizon, with: .color(.white.opacity(0.08)), lineWidth: 0.7)
        }
    }

    private func deterministicSeed(_ text: String) -> UInt64 {
        var value: UInt64 = 1_469_598_103_934_665_603
        for scalar in text.unicodeScalars {
            value ^= UInt64(scalar.value)
            value &*= 1_099_511_628_211
        }
        return value
    }
}

struct DeferredSeekSlider: View {
    let playbackTime: TimeInterval
    let duration: TimeInterval
    let tint: Color
    let onBegin: () -> Void
    let onCommit: (TimeInterval) -> Void
    let onCancel: () -> Void
    var onEditingChanged: ((Bool) -> Void)?

    @State private var draftValue: TimeInterval = 0
    @State private var isEditing = false

    var body: some View {
        VStack(spacing: 5) {
            Slider(
                value: Binding(
                    get: { isEditing ? draftValue : min(playbackTime, safeDuration) },
                    set: { draftValue = min(max($0, 0), safeDuration) }
                ),
                in: 0...safeDuration,
                onEditingChanged: { editing in
                    isEditing = editing
                    onEditingChanged?(editing)
                    if editing {
                        draftValue = min(playbackTime, safeDuration)
                        onBegin()
                    } else {
                        onCommit(draftValue)
                    }
                }
            )
            .tint(tint)
            .disabled(duration <= 0)
            .transaction { transaction in
                transaction.animation = nil
            }

            HStack {
                Text(format(isEditing ? draftValue : playbackTime))
                Spacer()
                Text(duration > 0 ? format(duration) : "--:--")
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .onDisappear {
            if isEditing { onCancel() }
        }
    }

    private var safeDuration: TimeInterval { max(duration, 1) }

    private func format(_ value: TimeInterval) -> String {
        guard value.isFinite, value >= 0 else { return "00:00" }
        let total = Int(value.rounded(.down))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// A settings slider that keeps its high-frequency drag state local and only
/// publishes to the shared SettingsStore once the finger lifts. This prevents
/// one thumb movement from rebuilding every glass panel that observes settings.
struct DeferredSettingSlider: View {
    let value: Double
    let range: ClosedRange<Double>
    let onCommit: (Double) -> Void

    @State private var draftValue: Double
    @State private var isEditing = false

    init(value: Double, in range: ClosedRange<Double>, onCommit: @escaping (Double) -> Void) {
        self.value = value
        self.range = range
        self.onCommit = onCommit
        self._draftValue = State(initialValue: min(max(value, range.lowerBound), range.upperBound))
    }

    var body: some View {
        Slider(
            value: Binding(
                get: { isEditing ? draftValue : min(max(value, range.lowerBound), range.upperBound) },
                set: { draftValue = min(max($0, range.lowerBound), range.upperBound) }
            ),
            in: range,
            onEditingChanged: { editing in
                if editing {
                    draftValue = min(max(value, range.lowerBound), range.upperBound)
                    isEditing = true
                } else {
                    isEditing = false
                    onCommit(draftValue)
                }
            }
        )
        .transaction { transaction in
            transaction.animation = nil
        }
        .onChange(of: value) { _, next in
            guard !isEditing else { return }
            draftValue = min(max(next, range.lowerBound), range.upperBound)
        }
    }
}
