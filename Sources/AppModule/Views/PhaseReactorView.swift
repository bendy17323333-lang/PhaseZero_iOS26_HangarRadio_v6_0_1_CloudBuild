import SwiftUI

struct AdaptivePhaseReactorView: View {
    @ObservedObject var model: GameViewModel
    @ObservedObject private var motion: MotionAimService
    @ObservedObject private var settings: SettingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var size: CGFloat
    var showsReadout = true

    init(model: GameViewModel, size: CGFloat, showsReadout: Bool = true) {
        self.model = model
        self.size = size
        self.showsReadout = showsReadout
        self._motion = ObservedObject(wrappedValue: model.motionAim)
        self._settings = ObservedObject(wrappedValue: model.settings)
    }

    var body: some View {
        Group {
            if reduceMotion {
                reactor(time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { timeline in
                    reactor(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .frame(width: size, height: size)
        .rotation3DEffect(.degrees(Double(motion.interfaceTiltY) * -7), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
        .rotation3DEffect(.degrees(Double(motion.interfaceTiltX) * 8), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
        .offset(x: CGFloat(motion.interfaceTiltX) * 10, y: CGFloat(motion.interfaceTiltY) * 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("相位反应堆，当前模式 \(mode.title)")
    }

    private func reactor(time: TimeInterval) -> some View {
        let primary = mode.spectacleTint
        let secondary = mode.spectacleSecondaryTint
        let pulse = 1 + sin(time * 1.55) * 0.018 * settings.spectaclePreset.nativeFXScale

        return ZStack {
            Circle()
                .fill(.black.opacity(0.16))
                .frame(width: size * 0.77, height: size * 0.77)
                .shadow(color: primary.opacity(0.32), radius: size * 0.14)

            Circle()
                .fill(
                    MeshGradient(
                        width: 3,
                        height: 3,
                        points: corePoints(time: time),
                        colors: [
                            primary.opacity(0.88), secondary.opacity(0.50), primary.opacity(0.32),
                            secondary.opacity(0.74), .white.opacity(0.94), primary.opacity(0.72),
                            primary.opacity(0.34), secondary.opacity(0.82), Color.black.opacity(0.20)
                        ],
                        background: primary.opacity(0.35),
                        smoothsColors: true
                    )
                )
                .frame(width: size * 0.62, height: size * 0.62)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.26), lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    Ellipse()
                        .fill(.white.opacity(0.40))
                        .frame(width: size * 0.25, height: size * 0.12)
                        .blur(radius: size * 0.035)
                        .offset(x: size * 0.10, y: size * 0.09)
                        .blendMode(.plusLighter)
                }
                .glassEffect(
                    .regular.tint(primary.opacity(0.13)).interactive(),
                    in: Circle()
                )
                .scaleEffect(CGFloat(pulse))

            ForEach(0..<5, id: \.self) { index in
                let diameter = size * (0.69 + CGFloat(index) * 0.072)
                let direction = index.isMultiple(of: 2) ? 1.0 : -1.0
                Circle()
                    .trim(from: CGFloat(0.02 + Double(index) * 0.037), to: CGFloat(0.42 + Double(index) * 0.075))
                    .stroke(
                        AngularGradient(
                            colors: [.clear, index.isMultiple(of: 2) ? primary : secondary, .white.opacity(0.8), .clear],
                            center: .center
                        ),
                        style: StrokeStyle(
                            lineWidth: index == 0 ? 3.2 : 1.2,
                            lineCap: .round,
                            dash: index >= 3 ? [4, 9] : []
                        )
                    )
                    .frame(width: diameter, height: diameter)
                    .rotationEffect(.degrees(time * direction * (13 + Double(index) * 5) + Double(index) * 48))
                    .shadow(color: (index.isMultiple(of: 2) ? primary : secondary).opacity(0.35), radius: index == 0 ? 8 : 3)
            }

            ForEach(0..<8, id: \.self) { index in
                let angle = time * (index.isMultiple(of: 2) ? 0.42 : -0.31) + Double(index) * (.pi / 4)
                let radius = size * (0.36 + CGFloat(index % 3) * 0.035)
                let nodeSize = size * (index.isMultiple(of: 3) ? 0.025 : 0.015)
                Circle()
                    .fill(index.isMultiple(of: 2) ? primary : secondary)
                    .frame(width: nodeSize, height: nodeSize)
                    .shadow(color: index.isMultiple(of: 2) ? primary : secondary, radius: 8)
                    .offset(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius * 0.70)
            }

            Circle()
                .stroke(.white.opacity(0.06), lineWidth: size * 0.045)
                .frame(width: size * 0.90, height: size * 0.90)
                .blur(radius: size * 0.015)

            PhaseLogo(size: size * 0.22)
                .shadow(color: .white.opacity(0.45), radius: 16)

            if showsReadout {
                VStack(spacing: 3) {
                    Spacer()
                    Text(mode.shortCode)
                        .font(.system(size: max(8, size * 0.028), weight: .black, design: .monospaced))
                        .tracking(size * 0.008)
                        .foregroundStyle(.white.opacity(0.74))
                    Text(readout)
                        .font(.system(size: max(7, size * 0.022), weight: .bold, design: .monospaced))
                        .foregroundStyle(primary)
                        .monospacedDigit()
                }
                .padding(.bottom, size * 0.14)
            }
        }
        .frame(width: size, height: size)
    }

    private var mode: RunMode {
        model.state == .menu ? model.selectedRunMode : model.activeDirective.mode
    }

    private var readout: String {
        if model.state == .playing {
            return "SYNC \(Int(model.hud.sync))% // \(model.hud.styleRank)"
        }
        return model.menuDirective.shareCode
    }

    private func corePoints(time: TimeInterval) -> [SIMD2<Float>] {
        let wobble = Float(0.045 * settings.spectaclePreset.nativeFXScale)
        return [
            SIMD2<Float>(0, 0),
            SIMD2<Float>(0.5 + sin(Float(time * 0.34)) * wobble, 0),
            SIMD2<Float>(1, 0),
            SIMD2<Float>(0, 0.5 + cos(Float(time * 0.28)) * wobble),
            SIMD2<Float>(0.5 + cos(Float(time * 0.22)) * wobble, 0.5 + sin(Float(time * 0.27)) * wobble),
            SIMD2<Float>(1, 0.5 + sin(Float(time * 0.31)) * wobble),
            SIMD2<Float>(0, 1),
            SIMD2<Float>(0.5 + cos(Float(time * 0.19)) * wobble, 1),
            SIMD2<Float>(1, 1)
        ]
    }
}
