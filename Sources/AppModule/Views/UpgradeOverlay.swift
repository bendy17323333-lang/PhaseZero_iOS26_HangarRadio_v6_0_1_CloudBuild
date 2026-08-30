import SwiftUI

struct UpgradeOverlay: View {
    @ObservedObject var model: GameViewModel
    @ObservedObject private var motion: MotionAimService
    @Namespace private var glassNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: GameViewModel) {
        self.model = model
        self._motion = ObservedObject(wrappedValue: model.motionAim)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = proxy.phaseZeroLayout

            if layout.isPhoneLandscape {
                PhoneUpgradeOverlay(model: model)
            } else {
                let compact = proxy.size.height < 520 || proxy.size.width < 900

                ZStack {
                    ProtocolLatticeBackdrop(
                        tint: model.isRelicChoice ? .orange : model.hud.phaseColor,
                        intensity: model.settings.spectaclePreset.nativeFXScale
                    )

                    VStack(spacing: compact ? 10 : 16) {
                        header(compact: compact)
                        cards(width: proxy.size.width, compact: compact)
                        footer(compact: compact)
                    }
                    .safeAreaPadding(.horizontal, compact ? 16 : 26)
                    .safeAreaPadding(.vertical, compact ? 10 : 16)
                }
            }
        }
    }

    private func header(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ProtocolSeal(
                tint: model.isRelicChoice ? .orange : .cyan,
                relic: model.isRelicChoice,
                compact: compact
            )

            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                Text(model.isRelicChoice ? "WARDEN RELIC // BUILD BREAKER" : "PROTOCOL INJECTION")
                    .font(.system(size: compact ? 8 : 10, weight: .black, design: .monospaced))
                    .tracking(compact ? 1.5 : 2.4)
                    .foregroundStyle(model.isRelicChoice ? .orange : .cyan)
                Text(model.isRelicChoice ? "选择一件失控遗物" : "给构筑装上一项不负责任的协议")
                    .font(.system(size: compact ? 20 : 29, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            Spacer(minLength: 8)

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    telemetry("RUN", value: "LV.\(model.hud.level)", tint: .cyan)
                    telemetry("STYLE", value: model.hud.styleRank, tint: model.hud.styleColor)
                    if !compact {
                        telemetry("REROLL", value: "×\(model.rerolls)", tint: .purple)
                    }
                }
            }
        }
    }

    private func cards(width: CGFloat, compact: Bool) -> some View {
        let visibleCount = min(max(model.upgrades.count, 1), compact ? 3 : 4)
        let sideAllowance: CGFloat = compact ? 38 : 64
        let cardWidth = min(
            compact ? 244 : 292,
            max(compact ? 186 : 220, (width - CGFloat(visibleCount - 1) * 14 - sideAllowance) / CGFloat(visibleCount))
        )
        let cardHeight: CGFloat = compact ? 232 : 292

        return ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 14) {
                    LazyHStack(spacing: 14) {
                        ForEach(model.upgrades) { choice in
                            HolographicProtocolCard(
                                choice: choice,
                                selected: model.controllerConnected && model.selectedUpgradeIndex == choice.index,
                                width: cardWidth,
                                height: cardHeight,
                                namespace: glassNamespace,
                                reduceMotion: reduceMotion,
                                tiltX: model.settings.interfaceParallaxEnabled ? motion.interfaceTiltX : 0,
                                tiltY: model.settings.interfaceParallaxEnabled ? motion.interfaceTiltY : 0
                            ) {
                                model.selectedUpgradeIndex = choice.index
                                model.chooseUpgrade(choice.index)
                            }
                            .id(choice.index)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                    .rotation3DEffect(
                                        .degrees(phase.isIdentity ? 0 : 7),
                                        axis: (x: 0.10, y: 1, z: 0),
                                        perspective: 0.62
                                    )
                                    .opacity(phase.isIdentity ? 1 : 0.74)
                            }
                        }
                    }
                    .padding(.vertical, compact ? 5 : 9)
                    .padding(.horizontal, 3)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .onChange(of: model.selectedUpgradeIndex) { _, value in
                withAnimation(.snappy(duration: 0.34, extraBounce: 0.08)) {
                    reader.scrollTo(value, anchor: .center)
                }
            }
        }
    }

    private func footer(compact: Bool) -> some View {
        HStack(spacing: 12) {
            Label(
                model.controllerConnected ? "方向键选择 · A 安装 · X 重抽" : "滑动浏览 · 点击即安装",
                systemImage: model.controllerConnected ? "gamecontroller.fill" : "hand.draw.fill"
            )
            .lineLimit(1)

            Spacer(minLength: 8)

            if !compact {
                Text("协议不会负责，玩家也不太会。")
                    .foregroundStyle(.tertiary)
            }

            Button {
                model.reroll()
            } label: {
                Label("重抽 × \(model.rerolls)", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.glass)
            .tint(.purple)
            .disabled(model.rerolls <= 0)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private func telemetry(_ title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.black))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(tint.opacity(0.11)), in: Capsule())
    }
}

private struct HolographicProtocolCard: View {
    let choice: UpgradeChoice
    let selected: Bool
    let width: CGFloat
    let height: CGFloat
    let namespace: Namespace.ID
    let reduceMotion: Bool
    let tiltX: Double
    let tiltY: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(.black.opacity(0.13))

                ProtocolFoil(
                    tint: choice.tint,
                    rarity: choice.rarity,
                    active: selected,
                    reduceMotion: reduceMotion
                )
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))

                GyroCardReflection(
                    tint: choice.tint,
                    tiltX: reduceMotion ? 0 : tiltX,
                    tiltY: reduceMotion ? 0 : tiltY,
                    premium: choice.rarity == "legendary" || choice.rarity == "cursed" || choice.rarity == "evolution"
                )
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))

                VStack(alignment: .leading, spacing: 11) {
                    HStack(alignment: .center) {
                        rarityBadge
                        Spacer()
                        Text(String(format: "%02d", choice.index + 1))
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .center, spacing: 13) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(.black.opacity(0.10))
                                .glassEffect(.regular.tint(choice.tint.opacity(0.17)), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                            Text(choice.icon)
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(choice.tint.gradient)
                                .shadow(color: choice.tint.opacity(0.72), radius: 13)
                        }
                        .frame(width: 66, height: 66)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(choice.name)
                                .font(.headline.weight(.black))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                            Text(choice.tag.uppercased())
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .tracking(1.4)
                                .foregroundStyle(choice.tint)
                        }
                    }

                    Text(choice.detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.74))
                        .lineSpacing(3)
                        .frame(maxHeight: .infinity, alignment: .topLeading)

                    Divider().opacity(0.22)

                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("STACK")
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .tracking(1.1)
                                .foregroundStyle(.secondary)
                            Text("\(choice.current) / \(choice.maxStack)")
                                .font(.caption.weight(.black))
                                .monospacedDigit()
                        }
                        Spacer()
                        Label(choice.current > 0 ? "继续叠加" : "安装协议", systemImage: selected ? "scope" : "plus.circle.fill")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(choice.tint)
                    }
                }
                .padding(17)
            }
            .frame(width: width, height: height)
            .glassEffect(
                .regular.tint(choice.tint.opacity(selected ? 0.22 : PlatformGlassProfile.tintOpacity)).interactive(),
                in: RoundedRectangle(cornerRadius: 27, style: .continuous)
            )
            .glassEffectID(choice.id, in: namespace)
            .overlay {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                selected ? .white.opacity(0.86) : choice.tint.opacity(0.34),
                                choice.tint.opacity(selected ? 0.92 : 0.26),
                                .clear,
                                choice.tint.opacity(0.24)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: selected ? 1.8 : 0.8
                    )
                    .shadow(color: selected ? choice.tint.opacity(0.82) : .clear, radius: 16)
            }
            .scaleEffect(selected ? 1.035 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(choice.name)，\(choice.rarityLabel)，\(choice.detail)")
    }

    private var rarityBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(choice.tint)
                .frame(width: 6, height: 6)
                .shadow(color: choice.tint, radius: 5)
            Text("\(choice.rarityLabel) // \(choice.rarity.uppercased())")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(1.1)
        }
        .foregroundStyle(choice.tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .glassEffect(.regular.tint(choice.tint.opacity(0.11)), in: Capsule())
    }
}


private struct GyroCardReflection: View {
    let tint: Color
    let tiltX: Double
    let tiltY: Double
    let premium: Bool

    var body: some View {
        GeometryReader { proxy in
            let x = CGFloat(tiltX) * proxy.size.width * 0.42
            let y = CGFloat(tiltY) * proxy.size.height * 0.30
            let angle = Angle.degrees(-24 + tiltX * 12)

            ZStack {
                RadialGradient(
                    colors: [
                        .white.opacity(premium ? 0.34 : 0.22),
                        tint.opacity(premium ? 0.18 : 0.10),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.46
                )
                .frame(width: proxy.size.width * 0.88, height: proxy.size.height * 0.88)
                .offset(x: x, y: y)
                .blendMode(.screen)

                LinearGradient(
                    colors: [.clear, .white.opacity(premium ? 0.30 : 0.18), tint.opacity(0.12), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: proxy.size.width * 0.22)
                .rotationEffect(angle)
                .offset(x: x * 0.72, y: y * 0.45)
                .blur(radius: premium ? 7 : 11)
                .blendMode(.plusLighter)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ProtocolFoil: View {
    let tint: Color
    let rarity: String
    let active: Bool
    let reduceMotion: Bool

    var body: some View {
        Group {
            if reduceMotion {
                foil(time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    foil(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func foil(time: TimeInterval) -> some View {
        let premium = rarity == "legendary" || rarity == "cursed" || rarity == "evolution"
        let rotation = time * (premium ? 18 : 8)
        let sweep = CGFloat((sin(time * 0.72) + 1) * 0.5)

        return ZStack {
            AngularGradient(
                colors: [
                    .clear,
                    tint.opacity(premium ? 0.20 : 0.08),
                    .white.opacity(premium ? 0.17 : 0.05),
                    .clear,
                    tint.opacity(premium ? 0.16 : 0.06),
                    .clear
                ],
                center: .center,
                angle: .degrees(rotation)
            )
            .scaleEffect(1.55)
            .blendMode(.plusLighter)

            LinearGradient(
                colors: [.clear, .white.opacity(premium ? 0.28 : 0.10), tint.opacity(0.16), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 96)
            .rotationEffect(.degrees(-24))
            .offset(x: -260 + sweep * 520)
            .blur(radius: premium ? 8 : 14)
            .blendMode(.screen)

            Canvas { context, size in
                let count = premium ? 28 : 12
                for index in 0..<count {
                    let seed = pseudoRandom(index * 37 + 11)
                    let x = CGFloat(seed) * size.width
                    let y = CGFloat(pseudoRandom(index * 19 + 7)) * size.height
                    let radius = CGFloat(0.5 + pseudoRandom(index * 29 + 3) * (premium ? 1.8 : 0.8))
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity((active ? 0.34 : 0.18) * (premium ? 1 : 0.6))))
                }
            }
            .blendMode(.plusLighter)
        }
        .opacity(active ? 1 : 0.72)
    }

    private func pseudoRandom(_ seed: Int) -> Double {
        let value = sin(Double(seed) * 12.9898 + 78.233) * 43_758.5453
        return value - floor(value)
    }
}

private struct ProtocolLatticeBackdrop: View {
    let tint: Color
    let intensity: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                field(time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    field(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func field(time: TimeInterval) -> some View {
        ZStack {
            Color.black.opacity(0.54)

            RadialGradient(
                colors: [tint.opacity(0.17 * intensity), .clear],
                center: UnitPoint(x: 0.5 + CGFloat(sin(time * 0.18)) * 0.08, y: 0.48 + CGFloat(cos(time * 0.14)) * 0.07),
                startRadius: 0,
                endRadius: 680
            )
            .blendMode(.screen)

            Canvas { context, size in
                let spacing: CGFloat = 42
                var grid = Path()
                var x: CGFloat = -spacing + CGFloat(time.truncatingRemainder(dividingBy: 2.4) / 2.4) * spacing
                while x < size.width + spacing {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x + size.height * 0.16, y: size.height))
                    x += spacing
                }
                var y: CGFloat = 0
                while y < size.height {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                context.stroke(grid, with: .color(tint.opacity(0.035 * intensity)), lineWidth: 0.65)
            }
            .blendMode(.plusLighter)
        }
    }
}

private struct ProtocolSeal: View {
    let tint: Color
    let relic: Bool
    let compact: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                seal(time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    seal(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .frame(width: compact ? 48 : 64, height: compact ? 48 : 64)
    }

    private func seal(time: TimeInterval) -> some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.08))
                .glassEffect(.regular.tint(tint.opacity(0.18)), in: Circle())
            Circle()
                .trim(from: 0.04, to: 0.74)
                .stroke(tint, style: StrokeStyle(lineWidth: compact ? 2 : 3, lineCap: .round))
                .padding(5)
                .rotationEffect(.radians(time * 0.42))
                .shadow(color: tint.opacity(0.72), radius: 8)
            Image(systemName: relic ? "seal.fill" : "shippingbox.and.arrow.backward.fill")
                .font(compact ? .headline : .title3)
                .foregroundStyle(tint.gradient)
        }
    }
}
