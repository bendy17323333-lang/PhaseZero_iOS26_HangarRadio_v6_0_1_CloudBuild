import SwiftUI

/// iPhone-specific protocol selection. It keeps the gyro-driven reflection, but
/// removes the tablet-sized cards and perpetual decorative animation that were
/// cheerfully spending frame time while the player tried to read.
struct PhoneUpgradeOverlay: View {
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
            let usableWidth = max(420, proxy.size.width - layout.leadingInset - layout.trailingInset)
            let cardWidth = min(
                layout.isSmallPhone ? 190 : 214,
                max(layout.isSmallPhone ? 170 : 184, (usableWidth - 24) / 3)
            )
            let cardHeight: CGFloat = layout.isSmallPhone ? 186 : 204

            ZStack {
                PhoneProtocolBackdrop(
                    tint: model.isRelicChoice ? .orange : model.hud.phaseColor,
                    intensity: model.settings.spectaclePreset.nativeFXScale
                )

                VStack(spacing: layout.isSmallPhone ? 5 : 7) {
                    header(small: layout.isSmallPhone)
                    cards(
                        width: cardWidth,
                        height: cardHeight,
                        small: layout.isSmallPhone
                    )
                    footer(small: layout.isSmallPhone)
                }
                .padding(.leading, layout.leadingInset)
                .padding(.trailing, layout.trailingInset)
                .padding(.top, layout.topInset)
                .padding(.bottom, layout.bottomInset)
            }
        }
    }

    private func header(small: Bool) -> some View {
        HStack(spacing: small ? 7 : 9) {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.08))
                    .glassEffect(
                        .regular.tint((model.isRelicChoice ? Color.orange : Color.cyan).opacity(0.14)),
                        in: Circle()
                    )
                Image(systemName: model.isRelicChoice ? "seal.fill" : "shippingbox.and.arrow.backward.fill")
                    .font(.system(size: small ? 13 : 15, weight: .black))
                    .foregroundStyle(model.isRelicChoice ? .orange : .cyan)
            }
            .frame(width: small ? 31 : 36, height: small ? 31 : 36)

            VStack(alignment: .leading, spacing: 0) {
                Text(model.isRelicChoice ? "WARDEN RELIC" : "PROTOCOL INJECTION")
                    .font(.system(size: small ? 6 : 7, weight: .black, design: .monospaced))
                    .tracking(1.25)
                    .foregroundStyle(model.isRelicChoice ? .orange : .cyan)
                Text(model.isRelicChoice ? "选择失控遗物" : "安装一项新协议")
                    .font(.system(size: small ? 14 : 17, weight: .black, design: .rounded))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            HStack(spacing: 5) {
                metric("LV", value: "\(model.hud.level)", tint: .cyan, small: small)
                metric("STYLE", value: model.hud.styleRank, tint: model.hud.styleColor, small: small)
                metric("REROLL", value: "×\(model.rerolls)", tint: .purple, small: small)
            }
        }
    }

    private func cards(width: CGFloat, height: CGFloat, small: Bool) -> some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: small ? 8 : 10) {
                    LazyHStack(spacing: small ? 8 : 10) {
                        ForEach(model.upgrades) { choice in
                            PhoneProtocolCard(
                                choice: choice,
                                selected: model.controllerConnected && model.selectedUpgradeIndex == choice.index,
                                width: width,
                                height: height,
                                namespace: glassNamespace,
                                reduceMotion: reduceMotion,
                                small: small,
                                tiltX: model.settings.interfaceParallaxEnabled ? motion.interfaceTiltX : 0,
                                tiltY: model.settings.interfaceParallaxEnabled ? motion.interfaceTiltY : 0
                            ) {
                                model.selectedUpgradeIndex = choice.index
                                model.chooseUpgrade(choice.index)
                            }
                            .id(choice.index)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.95)
                                    .rotation3DEffect(
                                        .degrees(phase.isIdentity ? 0 : 4.5),
                                        axis: (x: 0.08, y: 1, z: 0),
                                        perspective: 0.72
                                    )
                                    .opacity(phase.isIdentity ? 1 : 0.82)
                            }
                        }
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 2)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .onChange(of: model.selectedUpgradeIndex) { _, value in
                withAnimation(.snappy(duration: 0.28, extraBounce: 0.04)) {
                    reader.scrollTo(value, anchor: .center)
                }
            }
        }
    }

    private func footer(small: Bool) -> some View {
        HStack(spacing: 8) {
            Label(
                model.controllerConnected ? "方向键选择 · A 安装" : "滑动浏览 · 点击安装",
                systemImage: model.controllerConnected ? "gamecontroller.fill" : "hand.draw.fill"
            )
            .font(.system(size: small ? 7 : 8, weight: .bold))
            .foregroundStyle(.secondary)
            .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                model.reroll()
            } label: {
                Label("重抽 ×\(model.rerolls)", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: small ? 8 : 9, weight: .black))
            }
            .buttonStyle(.glass)
            .tint(.purple)
            .controlSize(.small)
            .disabled(model.rerolls <= 0)
        }
    }

    private func metric(_ title: String, value: String, tint: Color, small: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 5, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: small ? 8 : 9, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .padding(.horizontal, small ? 6 : 7)
        .padding(.vertical, small ? 4 : 5)
        .glassEffect(.regular.tint(tint.opacity(0.09)), in: Capsule())
    }
}

private struct PhoneProtocolCard: View {
    let choice: UpgradeChoice
    let selected: Bool
    let width: CGFloat
    let height: CGFloat
    let namespace: Namespace.ID
    let reduceMotion: Bool
    let small: Bool
    let tiltX: Double
    let tiltY: Double
    let action: () -> Void

    private var premium: Bool {
        choice.rarity == "legendary" || choice.rarity == "cursed" || choice.rarity == "evolution"
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: small ? 18 : 21, style: .continuous)
                    .fill(.black.opacity(0.16))

                PhoneCardFoil(tint: choice.tint, premium: premium, selected: selected)
                    .clipShape(RoundedRectangle(cornerRadius: small ? 18 : 21, style: .continuous))

                PhoneGyroReflection(
                    tint: choice.tint,
                    tiltX: reduceMotion ? 0 : tiltX,
                    tiltY: reduceMotion ? 0 : tiltY,
                    premium: premium
                )
                .clipShape(RoundedRectangle(cornerRadius: small ? 18 : 21, style: .continuous))

                VStack(alignment: .leading, spacing: small ? 5 : 7) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(choice.tint)
                            .frame(width: 5, height: 5)
                            .shadow(color: choice.tint, radius: 4)
                        Text(choice.rarityLabel.uppercased())
                            .font(.system(size: small ? 6 : 6.5, weight: .black, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(choice.tint)
                        Spacer()
                        Text(String(format: "%02d", choice.index + 1))
                            .font(.system(size: 6, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: small ? 7 : 9) {
                        ZStack {
                            RoundedRectangle(cornerRadius: small ? 12 : 14, style: .continuous)
                                .fill(.black.opacity(0.10))
                                .glassEffect(
                                    .regular.tint(choice.tint.opacity(0.14)),
                                    in: RoundedRectangle(cornerRadius: small ? 12 : 14, style: .continuous)
                                )
                            Text(choice.icon)
                                .font(.system(size: small ? 25 : 30, weight: .black, design: .rounded))
                                .foregroundStyle(choice.tint.gradient)
                                .shadow(color: choice.tint.opacity(0.58), radius: 8)
                        }
                        .frame(width: small ? 42 : 48, height: small ? 42 : 48)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(choice.name)
                                .font(.system(size: small ? 11 : 12.5, weight: .black))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.74)
                            Text(choice.tag.uppercased())
                                .font(.system(size: 6, weight: .black, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(choice.tint)
                        }
                    }

                    Text(choice.detail)
                        .font(.system(size: small ? 7.5 : 8.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(small ? 3 : 4)
                        .lineSpacing(1.5)
                        .frame(maxHeight: .infinity, alignment: .topLeading)

                    HStack(spacing: 5) {
                        Text("STACK \(choice.current)/\(choice.maxStack)")
                            .font(.system(size: 6, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Label(
                            choice.current > 0 ? "叠加" : "安装",
                            systemImage: selected ? "scope" : "plus.circle.fill"
                        )
                        .font(.system(size: small ? 7 : 8, weight: .black))
                        .foregroundStyle(choice.tint)
                    }
                }
                .padding(small ? 10 : 12)
            }
            .frame(width: width, height: height)
            .glassEffect(
                .regular.tint(choice.tint.opacity(selected ? 0.20 : 0.085)).interactive(),
                in: RoundedRectangle(cornerRadius: small ? 18 : 21, style: .continuous)
            )
            .glassEffectID("phone-\(choice.id)", in: namespace)
            .overlay {
                RoundedRectangle(cornerRadius: small ? 18 : 21, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                selected ? .white.opacity(0.78) : choice.tint.opacity(0.32),
                                choice.tint.opacity(selected ? 0.84 : 0.20),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: selected ? 1.4 : 0.7
                    )
                    .shadow(color: selected ? choice.tint.opacity(0.58) : .clear, radius: 10)
            }
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : tiltY * -1.8),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.82
            )
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : tiltX * 2.0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.82
            )
            .scaleEffect(selected ? 1.018 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(choice.name)，\(choice.rarityLabel)，\(choice.detail)")
    }
}

private struct PhoneGyroReflection: View {
    let tint: Color
    let tiltX: Double
    let tiltY: Double
    let premium: Bool

    var body: some View {
        GeometryReader { proxy in
            let x = CGFloat(tiltX) * proxy.size.width * 0.48
            let y = CGFloat(tiltY) * proxy.size.height * 0.36

            ZStack {
                RadialGradient(
                    colors: [
                        .white.opacity(premium ? 0.36 : 0.24),
                        tint.opacity(premium ? 0.18 : 0.10),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.48
                )
                .frame(width: proxy.size.width * 0.92, height: proxy.size.height * 0.92)
                .offset(x: x, y: y)
                .blendMode(.screen)

                LinearGradient(
                    colors: [.clear, .white.opacity(premium ? 0.32 : 0.20), tint.opacity(0.10), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: proxy.size.width * 0.20)
                .rotationEffect(.degrees(-25 + tiltX * 15))
                .offset(x: x * 0.76, y: y * 0.50)
                .blur(radius: premium ? 6 : 9)
                .blendMode(.plusLighter)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct PhoneCardFoil: View {
    let tint: Color
    let premium: Bool
    let selected: Bool

    var body: some View {
        ZStack {
            AngularGradient(
                colors: [
                    .clear,
                    tint.opacity(premium ? 0.16 : 0.06),
                    .white.opacity(premium ? 0.12 : 0.04),
                    .clear,
                    tint.opacity(premium ? 0.12 : 0.04),
                    .clear
                ],
                center: .center,
                angle: .degrees(premium ? 28 : 12)
            )
            .scaleEffect(1.45)
            .blendMode(.plusLighter)

            Canvas { context, size in
                let count = premium ? 14 : 6
                for index in 0..<count {
                    let x = CGFloat(pseudoRandom(index * 37 + 11)) * size.width
                    let y = CGFloat(pseudoRandom(index * 19 + 7)) * size.height
                    let radius = CGFloat(0.45 + pseudoRandom(index * 29 + 3) * (premium ? 1.25 : 0.65))
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity((selected ? 0.27 : 0.14) * (premium ? 1 : 0.6)))
                    )
                }
            }
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func pseudoRandom(_ seed: Int) -> Double {
        let value = sin(Double(seed) * 12.9898 + 78.233) * 43_758.5453
        return value - floor(value)
    }
}

private struct PhoneProtocolBackdrop: View {
    let tint: Color
    let intensity: Double

    var body: some View {
        ZStack {
            Color.black.opacity(0.60)
            RadialGradient(
                colors: [tint.opacity(0.14 * intensity), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 520
            )
            .blendMode(.screen)

            Canvas { context, size in
                let spacing: CGFloat = 46
                var grid = Path()
                var x: CGFloat = 0
                while x < size.width {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x + size.height * 0.12, y: size.height))
                    x += spacing
                }
                var y: CGFloat = 0
                while y < size.height {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                context.stroke(grid, with: .color(tint.opacity(0.025 * intensity)), lineWidth: 0.6)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
