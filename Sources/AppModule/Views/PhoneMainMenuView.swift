import Foundation
import SwiftUI

/// Dedicated landscape layout for iPhone. The iPad command deck was technically
/// capable of shrinking, in the same sense that a sofa is technically capable of
/// fitting through a doorway after sufficient violence.
struct PhoneMainMenuView: View {
    @ObservedObject var model: GameViewModel
    @ObservedObject private var director: AIDirector
    @ObservedObject private var performance: PerformanceGovernor
    @ObservedObject private var motion: MotionAimService
    @ObservedObject private var settings: SettingsStore
    @ObservedObject private var progression: MetaProgressionStore
    @ObservedObject private var music: AppleMusicService
    @Namespace private var glassNamespace

    init(model: GameViewModel) {
        self.model = model
        self._director = ObservedObject(wrappedValue: model.aiDirector)
        self._performance = ObservedObject(wrappedValue: model.performance)
        self._motion = ObservedObject(wrappedValue: model.motionAim)
        self._settings = ObservedObject(wrappedValue: model.settings)
        self._progression = ObservedObject(wrappedValue: model.progression)
        self._music = ObservedObject(wrappedValue: model.appleMusic)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = proxy.phaseZeroLayout

            HStack(spacing: layout.isSmallPhone ? 8 : 11) {
                hero(layout: layout)
                    .frame(width: layout.phoneHeroWidth)
                    .frame(maxHeight: .infinity)

                commandDeck(layout: layout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.leading, layout.leadingInset)
            .padding(.trailing, layout.trailingInset)
            .padding(.top, layout.topInset)
            .padding(.bottom, layout.bottomInset)
        }
    }

    private func hero(layout: PhaseZeroLayoutMetrics) -> some View {
        GeometryReader { proxy in
            let coreSize = min(
                proxy.size.width * 0.90,
                proxy.size.height * (layout.isSmallPhone ? 0.57 : 0.66)
            )

            ZStack(alignment: .topLeading) {
                AdaptivePhaseReactorView(
                    model: model,
                    size: max(layout.isSmallPhone ? 124 : 148, coreSize),
                    showsReadout: false
                )
                .position(x: proxy.size.width * 0.55, y: proxy.size.height * 0.56)
                .opacity(0.88)

                VStack(alignment: .leading, spacing: layout.isSmallPhone ? 3 : 5) {
                    HStack(spacing: 6) {
                        PhaseLogo(size: layout.isSmallPhone ? 22 : 27)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("PHONE CORE // iOS 26")
                                .font(.system(size: layout.isSmallPhone ? 5.5 : 7, weight: .black, design: .monospaced))
                                .tracking(1.1)
                                .foregroundStyle(selectedTint)
                            Text("LIQUID GLASS BUILD")
                                .font(.system(size: 5.5, weight: .bold, design: .monospaced))
                                .tracking(0.75)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("零点相位")
                        .font(.system(size: layout.isSmallPhone ? 27 : 34, weight: .black, design: .rounded))
                        .tracking(layout.isSmallPhone ? -1.7 : -2.4)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.90), selectedTint.opacity(0.78)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: selectedTint.opacity(0.20), radius: 15)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("PHASE ZERO // MOBILE")
                        .font(.system(size: 5.5, weight: .black, design: .monospaced))
                        .tracking(1.15)
                        .foregroundStyle(.white.opacity(0.58))
                }
                .offset(
                    x: settings.interfaceParallaxEnabled ? CGFloat(motion.interfaceTiltX) * 3.5 : 0,
                    y: settings.interfaceParallaxEnabled ? CGFloat(motion.interfaceTiltY) * 2.5 : 0
                )

                VStack(alignment: .leading, spacing: 4) {
                    if !layout.isSmallPhone {
                        HStack(spacing: 5) {
                            miniPill("\(performance.maximumRefreshRate)Hz", icon: "gauge.with.dots.needle.67percent", tint: .mint)
                            miniPill(settings.spectaclePreset.title, icon: "sparkles", tint: .pink)
                        }
                    }
                    Text("BEST \(model.bestScore.formatted())")
                        .font(.system(size: 6.5, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.62))
                        .monospacedDigit()
                    Text("\(progression.activeFrame.code) · \(progression.points) Φ")
                        .font(.system(size: 6.2, weight: .black, design: .monospaced))
                        .foregroundStyle(progression.activeFrame.tint)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
    }

    private func commandDeck(layout: PhaseZeroLayoutMetrics) -> some View {
        GlassPanel(
            tint: selectedTint,
            cornerRadius: layout.phoneCardCornerRadius,
            padding: layout.isSmallPhone ? 8 : 10
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: layout.isSmallPhone ? 5 : 7) {
                    header(small: layout.isSmallPhone)
                    modeSelector(small: layout.isSmallPhone)
                    directivePanel(small: layout.isSmallPhone)
                    startButton(small: layout.isSmallPhone)
                    utilityButtons(small: layout.isSmallPhone)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .rotation3DEffect(
            .degrees(settings.interfaceParallaxEnabled ? Double(motion.interfaceTiltY) * -1.2 : 0),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.78
        )
        .rotation3DEffect(
            .degrees(settings.interfaceParallaxEnabled ? Double(motion.interfaceTiltX) * 1.3 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.78
        )
    }

    private func header(small: Bool) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text("COMMAND DECK")
                    .font(.system(size: 6.5, weight: .black, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(selectedTint)
                Text("选择裂隙协议")
                    .font(.system(size: small ? 14 : 17, weight: .black, design: .rounded))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("LOCAL BEST")
                    .font(.system(size: 5.5, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(model.bestScore.formatted())
                    .font(.system(size: small ? 12 : 15, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("\(progression.activeFrame.code) · \(progression.points) Φ")
                    .font(.system(size: 5.5, weight: .black, design: .monospaced))
                    .foregroundStyle(progression.activeFrame.tint)
            }
        }
    }

    private func modeSelector(small: Bool) -> some View {
        GlassEffectContainer(spacing: 7) {
            HStack(spacing: 5) {
                ForEach(RunMode.allCases) { mode in
                    let selected = model.selectedRunMode == mode
                    Button {
                        withAnimation(.snappy(duration: 0.28, extraBounce: 0.05)) {
                            model.selectRunMode(mode)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .font(.system(size: small ? 9 : 10, weight: .bold))
                            Text(mode.title.replacingOccurrences(of: "裂隙", with: ""))
                                .font(.system(size: small ? 7.5 : 8.5, weight: .black))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selected ? mode.spectacleTint : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, small ? 5 : 6)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(
                        .regular.tint(mode.spectacleTint.opacity(selected ? 0.18 : 0.04)).interactive(),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .glassEffectID(selected ? "phone-active-mode" : "phone-mode-\(mode.rawValue)", in: glassNamespace)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(selected ? mode.spectacleTint.opacity(0.62) : .clear, lineWidth: 0.8)
                    }
                }
            }
        }
    }

    private func directivePanel(small: Bool) -> some View {
        VStack(alignment: .leading, spacing: small ? 3 : 5) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(selectedDirective.title)
                        .font(.system(size: small ? 10.5 : 12, weight: .black))
                        .lineLimit(1)
                    Text("\(selectedDirective.mode.shortCode) · \(selectedDirective.shareCode) · ×\(selectedDirective.scoreMultiplier, specifier: "%.2f")")
                        .font(.system(size: 6, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 3)
                if selectedDirective.mode == .director {
                    Button {
                        model.refreshDirectorContract()
                    } label: {
                        Image(systemName: director.isGeneratingContract ? "hourglass" : "arrow.triangle.2.circlepath")
                            .frame(width: 17, height: 17)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .disabled(director.isGeneratingContract)
                }
            }

            if !selectedDirective.modifiers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(selectedDirective.modifiers) { modifier in
                            Label(modifier.name, systemImage: modifier.icon)
                                .font(.system(size: 6, weight: .black))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3.5)
                                .glassEffect(.regular.tint(modifier.tint.opacity(0.10)), in: Capsule())
                        }
                    }
                }
            }

            Text(briefing)
                .font(.system(size: small ? 7.5 : 8.3, weight: .medium))
                .foregroundStyle(.white.opacity(0.70))
                .lineLimit(small ? 2 : 3)
                .lineSpacing(1)
        }
        .padding(small ? 7 : 8)
        .background(.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selectedTint.opacity(0.24), lineWidth: 0.8)
        }
    }

    private func startButton(small: Bool) -> some View {
        Button {
            model.startSelectedRun()
        } label: {
            HStack(spacing: 6) {
                if selectedDirective.mode == .director && director.isGeneratingContract {
                    ProgressView().controlSize(.small)
                    Text("导演正在制造事故")
                } else {
                    Image(systemName: "play.fill")
                    Text("启动 \(selectedDirective.mode.title)")
                    Spacer(minLength: 2)
                    Text("×\(selectedDirective.scoreMultiplier, specifier: "%.2f")")
                        .font(.system(size: 6.5, weight: .black, design: .monospaced))
                }
            }
            .font(.system(size: small ? 11 : 12.5, weight: .black))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .tint(selectedTint)
        .controlSize(.regular)
        .disabled(model.isLaunching || (selectedDirective.mode == .director && director.isGeneratingContract))
    }

    private func utilityButtons(small: Bool) -> some View {
        HStack(spacing: small ? 4 : 6) {
            Button {
                model.showHangar = true
            } label: {
                Image(systemName: "airplane")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(progression.activeFrame.tint)
            .accessibilityLabel("机库")

            Button {
                model.showPhaseRadio = true
            } label: {
                Image(systemName: music.isPlaying ? "waveform" : "music.note.list")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("相位电台")

            Button {
                model.showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("设置")

            Button {
                model.showSystemLab = true
            } label: {
                Image(systemName: "cpu")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("系统实验室")

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("分享裂隙")
        }
        .font(.system(size: small ? 9 : 10, weight: .bold))
        .controlSize(.small)
    }

    private func miniPill(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 6, weight: .black))
            .foregroundStyle(.white.opacity(0.68))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .glassEffect(.regular.tint(tint.opacity(0.09)), in: Capsule())
    }

    private var selectedDirective: RunDirective { model.menuDirective }
    private var selectedTint: Color { selectedDirective.mode.spectacleTint }

    private var briefing: String {
        switch selectedDirective.mode {
        case .daily:
            return director.briefingText(for: selectedDirective)
        case .director:
            return selectedDirective.subtitle
        case .free:
            return "标准规则。所有构筑事故仍由玩家自行负责。"
        }
    }

    private var shareText: String {
        let protocols = selectedDirective.modifiers.map(\.name).joined(separator: "、")
        return "《零点相位》\(selectedDirective.mode.title) \(selectedDirective.shareCode)，倍率 ×\(String(format: "%.2f", selectedDirective.scoreMultiplier))。协议：\(protocols)"
    }
}
