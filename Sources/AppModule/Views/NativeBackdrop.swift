import SwiftUI

struct NativeBackdrop: View {
    @ObservedObject var model: GameViewModel
    @ObservedObject private var motion: MotionAimService
    @ObservedObject private var settings: SettingsStore
    @ObservedObject private var performance: PerformanceGovernor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: GameViewModel) {
        self.model = model
        self._motion = ObservedObject(wrappedValue: model.motionAim)
        self._settings = ObservedObject(wrappedValue: model.settings)
        self._performance = ObservedObject(wrappedValue: model.performance)
    }

    var body: some View {
        Group {
            if reduceMotion {
                spectacleField(time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 36.0)) { timeline in
                    spectacleField(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func spectacleField(time: TimeInterval) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let mode = model.state == .menu ? model.selectedRunMode : model.activeDirective.mode
            let primary = model.state == .playing ? model.hud.phaseColor : mode.spectacleTint
            let secondary = mode.spectacleSecondaryTint
            let tiltX = settings.interfaceParallaxEnabled ? motion.interfaceTiltX : 0
            let tiltY = settings.interfaceParallaxEnabled ? motion.interfaceTiltY : 0
            let amplitude = settings.spectaclePreset.nativeFXScale

            ZStack {
                Color(red: 0.006, green: 0.014, blue: 0.040)

                MeshGradient(
                    width: 3,
                    height: 3,
                    points: meshPoints(time: time, tiltX: tiltX, tiltY: tiltY, amplitude: amplitude),
                    colors: [
                        Color(red: 0.005, green: 0.012, blue: 0.035),
                        primary.opacity(0.46),
                        Color(red: 0.015, green: 0.020, blue: 0.080),
                        secondary.opacity(0.34),
                        Color(red: 0.025, green: 0.045, blue: 0.120),
                        primary.opacity(0.26),
                        Color(red: 0.010, green: 0.016, blue: 0.050),
                        secondary.opacity(0.42),
                        Color(red: 0.003, green: 0.010, blue: 0.025)
                    ],
                    background: Color(red: 0.004, green: 0.010, blue: 0.028),
                    smoothsColors: true
                )
                .saturation(1.22)
                .contrast(1.08)
                .scaleEffect(1.18)
                .offset(x: CGFloat(tiltX) * 24, y: CGFloat(tiltY) * 18)

                PhaseCausticCanvas(
                    time: time,
                    primary: primary,
                    secondary: secondary,
                    density: performance.snapshot.particleScale * settings.spectaclePreset.particleMultiplier,
                    tiltX: tiltX,
                    tiltY: tiltY
                )
                .blendMode(.screen)

                Ellipse()
                    .fill(primary.opacity(0.18))
                    .frame(width: size.width * 0.62, height: size.height * 0.46)
                    .blur(radius: 86)
                    .offset(
                        x: -size.width * 0.30 + CGFloat(sin(time * 0.13)) * 34 + CGFloat(tiltX) * 48,
                        y: -size.height * 0.22 + CGFloat(tiltY) * 30
                    )
                    .blendMode(.plusLighter)

                Ellipse()
                    .fill(secondary.opacity(0.15))
                    .frame(width: size.width * 0.54, height: size.height * 0.50)
                    .blur(radius: 96)
                    .offset(
                        x: size.width * 0.34 + CGFloat(cos(time * 0.11)) * 42 - CGFloat(tiltX) * 40,
                        y: size.height * 0.22 - CGFloat(tiltY) * 24
                    )
                    .blendMode(.plusLighter)

                LinearGradient(
                    colors: [.clear, .white.opacity(0.035), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: size.width * 0.14)
                .rotationEffect(.degrees(-18))
                .offset(x: CGFloat(sin(time * 0.18)) * size.width * 0.58)
                .blur(radius: 18)
                .blendMode(.screen)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.42), .clear, Color.black.opacity(0.34)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }

    private func meshPoints(
        time: TimeInterval,
        tiltX: Double,
        tiltY: Double,
        amplitude: Double
    ) -> [SIMD2<Float>] {
        let drift = Float(0.035 * amplitude)
        let tx = Float(tiltX * 0.018)
        let ty = Float(tiltY * 0.018)

        return [
            SIMD2<Float>(0.00, 0.00),
            SIMD2<Float>(0.50 + sin(Float(time * 0.17)) * drift + tx, 0.00),
            SIMD2<Float>(1.00, 0.00),
            SIMD2<Float>(0.00, 0.50 + cos(Float(time * 0.13)) * drift + ty),
            SIMD2<Float>(0.50 + cos(Float(time * 0.11)) * drift - tx, 0.50 + sin(Float(time * 0.15)) * drift - ty),
            SIMD2<Float>(1.00, 0.50 + sin(Float(time * 0.12)) * drift),
            SIMD2<Float>(0.00, 1.00),
            SIMD2<Float>(0.50 + sin(Float(time * 0.09)) * drift, 1.00),
            SIMD2<Float>(1.00, 1.00)
        ]
    }
}

private struct PhaseCausticCanvas: View {
    let time: TimeInterval
    let primary: Color
    let secondary: Color
    let density: Double
    let tiltX: Double
    let tiltY: Double

    var body: some View {
        Canvas { context, size in
            let scale = min(max(density, 0.35), 1.4)
            let particleCount = max(26, Int(76 * scale))
            let diagonal = hypot(size.width, size.height)

            for index in 0..<particleCount {
                let seed = randomUnit(index * 37 + 11)
                let speed = 0.018 + randomUnit(index * 17 + 7) * 0.055
                let orbit = time * speed + seed * .pi * 2
                let radius = diagonal * CGFloat(0.08 + randomUnit(index * 19 + 5) * 0.52)
                let centerX = size.width * CGFloat(0.50 + tiltX * 0.028)
                let centerY = size.height * CGFloat(0.50 + tiltY * 0.035)
                let x = centerX + CGFloat(cos(orbit + Double(index) * 0.21)) * radius
                let y = centerY + CGFloat(sin(orbit * 1.17 + Double(index) * 0.13)) * radius * 0.48
                let particleSize = CGFloat(0.7 + randomUnit(index * 29 + 3) * 2.4 * scale)
                let color = index.isMultiple(of: 3) ? secondary : primary
                let opacity = 0.12 + randomUnit(index * 13 + 9) * 0.40
                let rect = CGRect(
                    x: x - particleSize / 2,
                    y: y - particleSize / 2,
                    width: particleSize,
                    height: particleSize
                )
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
            }

            let center = CGPoint(
                x: size.width * CGFloat(0.50 + tiltX * 0.018),
                y: size.height * CGFloat(0.50 + tiltY * 0.025)
            )
            for ring in 0..<7 {
                let base = min(size.width, size.height) * CGFloat(0.16 + Double(ring) * 0.09)
                let wobble = CGFloat(1 + sin(time * (0.15 + Double(ring) * 0.017) + Double(ring)) * 0.035)
                let rect = CGRect(
                    x: center.x - base * wobble,
                    y: center.y - base * wobble * 0.52,
                    width: base * 2 * wobble,
                    height: base * 1.04 * wobble
                )
                var path = Path(ellipseIn: rect)
                let tint = ring.isMultiple(of: 2) ? primary : secondary
                context.stroke(
                    path,
                    with: .color(tint.opacity(0.035 + Double(ring) * 0.008)),
                    lineWidth: ring == 0 ? 1.6 : 0.7
                )

                path = Path()
                let angle = time * (ring.isMultiple(of: 2) ? 0.07 : -0.055) + Double(ring)
                let length = base * 0.82
                path.move(to: center)
                path.addLine(to: CGPoint(
                    x: center.x + CGFloat(cos(angle)) * length,
                    y: center.y + CGFloat(sin(angle)) * length * 0.52
                ))
                context.stroke(path, with: .color(tint.opacity(0.055)), lineWidth: 0.8)
            }

            for beam in 0..<3 {
                var path = Path()
                let phase = time * (0.07 + Double(beam) * 0.015) + Double(beam) * 2.1
                let startY = size.height * CGFloat(0.18 + Double(beam) * 0.31)
                path.move(to: CGPoint(x: -80, y: startY + CGFloat(sin(phase)) * 38))
                path.addCurve(
                    to: CGPoint(x: size.width + 80, y: startY + CGFloat(cos(phase)) * 56),
                    control1: CGPoint(x: size.width * 0.28, y: startY - 110 + CGFloat(sin(phase * 0.7)) * 30),
                    control2: CGPoint(x: size.width * 0.72, y: startY + 110 + CGFloat(cos(phase * 0.8)) * 30)
                )
                let tint = beam.isMultiple(of: 2) ? primary : secondary
                context.stroke(
                    path,
                    with: .color(tint.opacity(0.065)),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                )
            }
        }
    }

    private func randomUnit(_ seed: Int) -> Double {
        let value = sin(Double(seed) * 12.9898 + 78.233) * 43_758.5453
        return value - floor(value)
    }
}
