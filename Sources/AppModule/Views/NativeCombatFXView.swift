import SwiftUI
import UIKit

struct NativeCombatFXView: View {
    let event: SpectacleEvent
    let strength: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 0.0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch event.kind {
                case .phase:
                    phaseFX(size: proxy.size)
                case .dash:
                    dashFX(size: proxy.size)
                case .graze:
                    grazeFX(size: proxy.size)
                case .shield:
                    shieldFX(size: proxy.size)
                case .damage, .death:
                    damageFX(size: proxy.size, fatal: event.kind == .death)
                case .boss:
                    bossFX(size: proxy.size, defeated: false)
                case .bossDefeat:
                    bossFX(size: proxy.size, defeated: true)
                case .overdrive:
                    overdriveFX(size: proxy.size)
                case .rank:
                    rankFX(size: proxy.size)
                case .upgrade, .revive:
                    upgradeFX(size: proxy.size)
                case .wave, .sectorClear:
                    announcementFX(size: proxy.size)
                case .pulse:
                    pulseFX(size: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            if reduceMotion {
                progress = 1
            } else {
                withAnimation(.timingCurve(0.12, 0.82, 0.20, 1, duration: animationDuration)) {
                    progress = 1
                }
            }
        }
    }

    private var intensity: Double {
        let deviceScale = UIDevice.current.userInterfaceIdiom == .phone ? 0.82 : 1.0
        return min(max(event.intensity * strength * deviceScale, 0.30), 1.65)
    }

    private var animationDuration: Double {
        switch event.kind {
        case .boss, .bossDefeat, .death: return 1.26
        case .overdrive, .rank, .sectorClear: return 0.92
        case .graze: return 0.28
        default: return 0.62
        }
    }

    private func phaseFX(size: CGSize) -> some View {
        ZStack {
            RadialGradient(
                colors: [event.tint.opacity(0.34 * intensity * (1 - progress)), .clear],
                center: .center,
                startRadius: 0,
                endRadius: min(size.width, size.height) * 0.62
            )
            .blendMode(.plusLighter)

            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .trim(from: index.isMultiple(of: 2) ? 0.04 : 0.54, to: index.isMultiple(of: 2) ? 0.46 : 0.96)
                    .stroke(
                        index.isMultiple(of: 2) ? event.tint : alternateTint,
                        style: StrokeStyle(lineWidth: index == 0 ? 4 : 1.4, lineCap: .round)
                    )
                    .frame(width: 80 + CGFloat(index) * 54, height: 80 + CGFloat(index) * 54)
                    .scaleEffect(CGFloat(0.45 + progress * (3.1 + Double(index) * 0.40)))
                    .rotationEffect(.degrees(progress * (index.isMultiple(of: 2) ? 170 : -130)))
                    .opacity((1 - progress) * (0.85 - Double(index) * 0.12) * intensity)
                    .shadow(color: event.tint.opacity(0.65), radius: 10)
            }
        }
    }

    private func dashFX(size: CGSize) -> some View {
        ZStack {
            SpeedStreakCanvas(
                progress: progress,
                tint: event.tint,
                directionX: abs(event.directionX) > 0.05 ? event.directionX : 1,
                directionY: event.directionY,
                density: intensity
            )
            .blendMode(.screen)

            LinearGradient(
                colors: [.clear, event.tint.opacity(0.26 * (1 - progress) * intensity), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: size.height * 0.32)
            .rotationEffect(.degrees(atan2(event.directionY, max(0.001, event.directionX)) * 180 / .pi))
            .blur(radius: 18)
        }
    }

    private func grazeFX(size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(.white.opacity((1 - progress) * 0.85))
                .frame(width: 10, height: 10)
                .shadow(color: event.tint, radius: 18)
                .offset(x: size.width * 0.32, y: -size.height * 0.16)
                .scaleEffect(CGFloat(0.6 + progress * 2.8))

            Capsule()
                .fill(event.tint.opacity((1 - progress) * 0.60))
                .frame(width: size.width * 0.26, height: 2)
                .offset(x: size.width * CGFloat(0.36 - progress * 0.18), y: -size.height * 0.16)
                .blur(radius: 1.2)
        }
    }

    private func shieldFX(size: CGSize) -> some View {
        ZStack {
            RadialGradient(
                colors: [Color.cyan.opacity(0.26 * (1 - progress) * intensity), .clear],
                center: .center,
                startRadius: 0,
                endRadius: min(size.width, size.height) * 0.52
            )
            .blendMode(.screen)

            ForEach(0..<3, id: \.self) { index in
                ShieldHexagonLayer(index: index, progress: progress)
            }
        }
    }

    private func damageFX(size: CGSize, fatal: Bool) -> some View {
        ZStack {
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [.clear, Color.red.opacity((fatal ? 0.62 : 0.38) * (1 - progress) * intensity)],
                        center: .center,
                        startRadius: min(size.width, size.height) * 0.15,
                        endRadius: max(size.width, size.height) * 0.72
                    )
                )

            CrackCanvas(progress: progress, fatal: fatal)
                .blendMode(.screen)

            if fatal {
                Text("PHASE FAILURE")
                    .font(.system(size: min(46, size.height * 0.11), weight: .black, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(.white)
                    .shadow(color: .red, radius: 18)
                    .opacity(max(0, 1 - progress * 0.72))
                    .scaleEffect(CGFloat(0.84 + progress * 0.28))
            }
        }
    }

    private func bossFX(size: CGSize, defeated: Bool) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 40 + CGFloat(index) * 8, style: .continuous)
                    .stroke(
                        defeated ? Color.mint.opacity(0.78) : Color.orange.opacity(0.82),
                        style: StrokeStyle(lineWidth: index == 0 ? 4 : 1.3, lineCap: .round, dash: index > 0 ? [8, 14] : [])
                    )
                    .padding(18 + CGFloat(index) * 22)
                    .scaleEffect(CGFloat(0.92 + progress * (0.18 + Double(index) * 0.04)))
                    .opacity((1 - progress) * (0.92 - Double(index) * 0.18))
            }

            VStack(spacing: 5) {
                Text(defeated ? "WARDEN COLLAPSED" : "PRISM WARDEN")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(defeated ? .mint : .orange)
                Text(defeated ? "棱镜守卫已解体" : "高能目标接入")
                    .font(.system(size: min(38, size.height * 0.085), weight: .black, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 15)
            .glassEffect(
                .regular.tint((defeated ? Color.mint : Color.orange).opacity(0.15)),
                in: Capsule()
            )
            .scaleEffect(CGFloat(0.82 + min(progress, 0.48) * 0.38))
            .opacity(max(0, 1 - max(0, progress - 0.58) * 2.4))
        }
    }

    private func overdriveFX(size: CGSize) -> some View {
        ZStack {
            Rectangle()
                .fill(.white.opacity(max(0, 0.46 - progress * 0.60) * intensity))
                .blendMode(.plusLighter)

            RadialGradient(
                colors: [.white.opacity(0.72 * (1 - progress)), event.tint.opacity(0.44 * (1 - progress)), .clear],
                center: .center,
                startRadius: 0,
                endRadius: min(size.width, size.height) * CGFloat(0.24 + progress * 0.72)
            )
            .blendMode(.screen)

            ForEach(0..<9, id: \.self) { index in
                Circle()
                    .trim(from: CGFloat(index) * 0.073, to: min(1, CGFloat(index) * 0.073 + 0.18))
                    .stroke(index.isMultiple(of: 2) ? event.tint : alternateTint, style: StrokeStyle(lineWidth: index < 2 ? 4 : 1.4, lineCap: .round))
                    .frame(width: 100 + CGFloat(index) * 31, height: 100 + CGFloat(index) * 31)
                    .scaleEffect(CGFloat(0.50 + progress * (2.3 + Double(index) * 0.13)))
                    .rotationEffect(.degrees(progress * (index.isMultiple(of: 2) ? 260 : -220)))
                    .opacity((1 - progress) * (0.92 - Double(index) * 0.07))
            }

            VStack(spacing: 2) {
                Text("OVERDRIVE")
                    .font(.system(size: min(52, size.height * 0.12), weight: .black, design: .rounded))
                    .tracking(2)
                Text("WHITEOUT PROTOCOL")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(3.4)
                    .foregroundStyle(event.tint)
            }
            .shadow(color: .white.opacity(0.8), radius: 18)
            .scaleEffect(CGFloat(0.72 + min(progress, 0.44) * 0.82))
            .opacity(max(0, 1 - max(0, progress - 0.52) * 2.2))
        }
    }

    private func rankFX(size: CGSize) -> some View {
        let rank = event.rank.isEmpty ? "S" : event.rank
        return HStack(spacing: 14) {
            Text(rank)
                .font(.system(size: min(126, size.height * 0.31), weight: .black, design: .rounded))
                .italic()
                .foregroundStyle(event.tint.gradient)
                .shadow(color: event.tint.opacity(0.85), radius: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.label.isEmpty ? "STYLE BREAK" : event.label)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2.8)
                Text(event.detail.isEmpty ? "相位核心批准了这次不必要的炫耀" : event.detail)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 16)
        .glassEffect(.regular.tint(event.tint.opacity(0.16)), in: Capsule())
        .scaleEffect(CGFloat(0.72 + min(progress, 0.46) * 0.70))
        .rotationEffect(.degrees((1 - progress) * -7))
        .opacity(max(0, 1 - max(0, progress - 0.62) * 2.7))
        .offset(x: -size.width * 0.18, y: size.height * 0.17)
    }

    private func upgradeFX(size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .stroke(event.tint.opacity((1 - progress) * 0.70), lineWidth: 3)
                .frame(width: size.width * 0.46, height: size.height * 0.56)
                .scaleEffect(CGFloat(0.42 + progress * 1.72))
                .rotation3DEffect(.degrees((1 - progress) * 22), axis: (x: 1, y: 1, z: 0), perspective: 0.5)
                .shadow(color: event.tint.opacity(0.72), radius: 18)

            Text(event.kind == .revive ? "RECONSTRUCTED" : "PROTOCOL INSTALLED")
                .font(.system(size: min(34, size.height * 0.075), weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(event.tint)
                .opacity(max(0, 1 - max(0, progress - 0.50) * 2.2))
                .scaleEffect(CGFloat(0.78 + min(progress, 0.48) * 0.62))
        }
    }

    private func announcementFX(size: CGSize) -> some View {
        VStack(spacing: 4) {
            Text(event.kind == .sectorClear ? "SECTOR PURGED" : "WAVE \(event.detail)")
                .font(.system(size: min(48, size.height * 0.105), weight: .black, design: .rounded))
                .tracking(2.4)
            Text(event.label.isEmpty ? "相位空间重新计算中" : event.label)
                .font(.caption.weight(.black))
                .tracking(2)
                .foregroundStyle(event.tint)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .glassEffect(.regular.tint(event.tint.opacity(0.13)), in: Capsule())
        .offset(y: CGFloat((1 - progress) * 42) - size.height * 0.18)
        .opacity(max(0, 1 - max(0, progress - 0.62) * 2.5))
    }

    private func pulseFX(size: CGSize) -> some View {
        Circle()
            .stroke(event.tint.opacity((1 - progress) * 0.58), lineWidth: 3)
            .frame(width: min(size.width, size.height) * 0.24, height: min(size.width, size.height) * 0.24)
            .scaleEffect(CGFloat(0.4 + progress * 4.0))
            .shadow(color: event.tint, radius: 14)
    }

    private var alternateTint: Color {
        event.phase == 1 ? .cyan : Color(red: 1.0, green: 0.48, blue: 0.39)
    }
}

private struct ShieldHexagonLayer: View {
    let index: Int
    let progress: Double

    var body: some View {
        let alpha = max(0, (1 - progress) * (0.82 - Double(index) * 0.18))
        let lineWidth: CGFloat = index == 0 ? 4 : 1.5
        let side = 110 + CGFloat(index) * 58
        let scale = CGFloat(0.55 + progress * (2.4 + Double(index) * 0.36))
        let rotation = progress * (index.isMultiple(of: 2) ? 80.0 : -62.0)

        PhaseHexagon()
            .stroke(Color.cyan.opacity(alpha), lineWidth: lineWidth)
            .frame(width: side, height: side)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .shadow(color: Color.cyan.opacity(0.7), radius: 12)
    }
}

private struct PhaseHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        for index in 0..<6 {
            let angle = Double(index) / 6 * .pi * 2 - .pi / 2
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

private struct SpeedStreakCanvas: View {
    let progress: Double
    let tint: Color
    let directionX: Double
    let directionY: Double
    let density: Double

    var body: some View {
        Canvas { context, size in
            let length = hypot(directionX, directionY)
            let dx = length > 0.001 ? directionX / length : 1
            let dy = length > 0.001 ? directionY / length : 0
            let count = max(28, Int(54 * min(max(density, 0.6), 1.7)))

            for index in 0..<count {
                let cross = random(index * 31 + 4) - 0.5
                let along = random(index * 17 + 9)
                let base = CGPoint(
                    x: size.width * CGFloat(0.5 + cross * 1.2) - CGFloat(dx * (1 - along)) * size.width * 0.58,
                    y: size.height * CGFloat(0.5 + cross * 1.2) - CGFloat(dy * (1 - along)) * size.height * 0.58
                )
                let travel = (0.08 + random(index * 23 + 2) * 0.34) * (0.45 + progress * 1.4)
                let end = CGPoint(
                    x: base.x + CGFloat(dx * travel) * size.width,
                    y: base.y + CGFloat(dy * travel) * size.height
                )
                var path = Path()
                path.move(to: base)
                path.addLine(to: end)
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [.clear, tint.opacity((1 - progress) * 0.58), .clear]),
                        startPoint: base,
                        endPoint: end
                    ),
                    style: StrokeStyle(lineWidth: CGFloat(0.7 + random(index * 7) * 2.1), lineCap: .round)
                )
            }
        }
    }

    private func random(_ seed: Int) -> Double {
        let value = sin(Double(seed) * 12.9898 + 31.17) * 19_421.912
        return value - floor(value)
    }
}

private struct CrackCanvas: View {
    let progress: Double
    let fatal: Bool

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let branchCount = fatal ? 22 : 12
            for branch in 0..<branchCount {
                let angle = Double(branch) / Double(branchCount) * .pi * 2 + random(branch * 9) * 0.22
                var path = Path()
                path.move(to: center)
                var current = center
                let segments = fatal ? 5 : 3
                for segment in 1...segments {
                    let distance = min(size.width, size.height) * CGFloat(
                        (Double(segment) / Double(segments)) * (0.15 + progress * 0.62)
                    )
                    let jitter = (random(branch * 37 + segment * 13) - 0.5) * 0.42
                    let point = CGPoint(
                        x: center.x + CGFloat(cos(angle + jitter)) * distance,
                        y: center.y + CGFloat(sin(angle + jitter)) * distance
                    )
                    path.addLine(to: point)
                    current = point
                }
                _ = current
                context.stroke(
                    path,
                    with: .color(Color.white.opacity((1 - progress) * (fatal ? 0.42 : 0.22))),
                    style: StrokeStyle(lineWidth: fatal ? 1.5 : 0.8, lineCap: .round)
                )
            }
        }
    }

    private func random(_ seed: Int) -> Double {
        let value = sin(Double(seed) * 18.913 + 6.71) * 15_319.22
        return value - floor(value)
    }
}
