import SwiftUI

struct LaunchSequenceOverlay: View {
    @ObservedObject var model: GameViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 0.0
    @State private var textVisible = false

    var body: some View {
        GeometryReader { proxy in
            let coreSize = min(proxy.size.width, proxy.size.height) * 0.62
            let tint = (model.launchDirective ?? model.menuDirective).mode.spectacleTint
            let secondary = (model.launchDirective ?? model.menuDirective).mode.spectacleSecondaryTint

            ZStack {
                Color.black.opacity(0.78 + progress * 0.18)
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        .white.opacity(progress * 0.32),
                        tint.opacity(0.34),
                        secondary.opacity(0.14),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.62
                )
                .scaleEffect(CGFloat(0.55 + progress * 1.45))
                .blendMode(.plusLighter)

                LaunchStreakField(progress: progress, tint: tint, secondary: secondary)
                    .blendMode(.screen)

                AdaptivePhaseReactorView(model: model, size: coreSize, showsReadout: false)
                    .scaleEffect(CGFloat(0.62 + progress * 1.18))
                    .opacity(1 - max(0, progress - 0.72) * 3.2)
                    .blur(radius: CGFloat(max(0, progress - 0.78) * 40))

                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .stroke(
                            index.isMultiple(of: 2) ? tint.opacity(0.58) : secondary.opacity(0.48),
                            style: StrokeStyle(lineWidth: index == 0 ? 3 : 1, lineCap: .round, dash: index > 1 ? [5, 12] : [])
                        )
                        .frame(width: coreSize * (0.46 + CGFloat(index) * 0.15), height: coreSize * (0.46 + CGFloat(index) * 0.15))
                        .scaleEffect(CGFloat(0.42 + progress * (1.35 + Double(index) * 0.13)))
                        .opacity((1 - progress) * 0.72)
                        .rotationEffect(.degrees(progress * (index.isMultiple(of: 2) ? 210 : -170) + Double(index) * 24))
                }

                VStack(spacing: 7) {
                    Text("PHASE COLLAPSE")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(3.2)
                        .foregroundStyle(tint)
                    Text(model.launchDirective?.title ?? model.menuDirective.title)
                        .font(.system(size: min(34, proxy.size.height * 0.055), weight: .black, design: .rounded))
                        .minimumScaleFactor(0.62)
                        .lineLimit(1)
                    Text("裂隙坐标正在失去礼貌")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .glassEffect(.regular.tint(tint.opacity(0.12)), in: Capsule())
                .opacity(textVisible ? max(0, 1 - progress * 0.72) : 0)
                .offset(y: proxy.size.height * 0.33)
            }
        }
        .allowsHitTesting(true)
        .transition(.opacity)
        .onAppear {
            if reduceMotion {
                progress = 1
                textVisible = true
            } else {
                withAnimation(.easeOut(duration: 0.18)) { textVisible = true }
                withAnimation(.timingCurve(0.16, 0.78, 0.18, 1, duration: 0.92)) {
                    progress = 1
                }
            }
        }
    }
}

private struct LaunchStreakField: View {
    let progress: Double
    let tint: Color
    let secondary: Color

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let diagonal = hypot(size.width, size.height)

            for index in 0..<64 {
                let angle = Double(index) / 64 * .pi * 2 + random(index * 11) * 0.12
                let inner = diagonal * CGFloat((0.04 + random(index * 17) * 0.10) * (1 - progress * 0.46))
                let outer = diagonal * CGFloat((0.18 + random(index * 29) * 0.72) * (0.25 + progress * 1.22))
                let start = CGPoint(x: center.x + CGFloat(cos(angle)) * inner, y: center.y + CGFloat(sin(angle)) * inner)
                let end = CGPoint(x: center.x + CGFloat(cos(angle)) * outer, y: center.y + CGFloat(sin(angle)) * outer)
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                let color = index.isMultiple(of: 3) ? secondary : tint
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [.clear, color.opacity(0.10 + progress * 0.48), .clear]),
                        startPoint: start,
                        endPoint: end
                    ),
                    style: StrokeStyle(lineWidth: CGFloat(0.6 + random(index * 7) * 2.0), lineCap: .round)
                )
            }
        }
    }

    private func random(_ seed: Int) -> Double {
        let value = sin(Double(seed) * 12.9898 + 4.1414) * 22_731.124
        return value - floor(value)
    }
}
