import Foundation
import SwiftUI

struct MainMenuView: View {
    @ObservedObject var model: GameViewModel
    @ObservedObject private var director: AIDirector
    @ObservedObject private var performance: PerformanceGovernor
    @ObservedObject private var archive: RunArchive
    @ObservedObject private var motion: MotionAimService
    @ObservedObject private var settings: SettingsStore
    @ObservedObject private var progression: MetaProgressionStore
    @ObservedObject private var music: AppleMusicService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace
    @State private var appeared = false

    init(model: GameViewModel) {
        self.model = model
        self._director = ObservedObject(wrappedValue: model.aiDirector)
        self._performance = ObservedObject(wrappedValue: model.performance)
        self._archive = ObservedObject(wrappedValue: model.archive)
        self._motion = ObservedObject(wrappedValue: model.motionAim)
        self._settings = ObservedObject(wrappedValue: model.settings)
        self._progression = ObservedObject(wrappedValue: model.progression)
        self._music = ObservedObject(wrappedValue: model.appleMusic)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = proxy.phaseZeroLayout
            let compact = proxy.size.width < 940 || proxy.size.height < 600
            let horizontalPadding = max(18, proxy.safeAreaInsets.leading + 14)
            let verticalPadding = max(12, proxy.safeAreaInsets.top + 8)

            if layout.isPhoneLandscape {
                PhoneMainMenuView(model: model)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                Group {
                    if compact {
                        HStack(spacing: 14) {
                            heroStage(compact: true)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            commandDeck(compact: true)
                                .frame(width: min(480, proxy.size.width * 0.53))
                        }
                    } else {
                        HStack(spacing: max(24, proxy.size.width * 0.032)) {
                            heroStage(compact: false)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            commandDeck(compact: false)
                                .frame(width: min(500, proxy.size.width * 0.42))
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.985)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.smooth(duration: 0.62)) { appeared = true }
            }
        }
    }

    private func heroStage(compact: Bool) -> some View {
        GeometryReader { proxy in
            let coreSize = min(
                compact ? proxy.size.height * 0.74 : proxy.size.height * 0.82,
                compact ? proxy.size.width * 0.92 : proxy.size.width * 0.78
            )

            ZStack(alignment: .topLeading) {
                AdaptivePhaseReactorView(model: model, size: max(210, coreSize))
                    .position(x: proxy.size.width * (compact ? 0.54 : 0.58), y: proxy.size.height * 0.54)

                VStack(alignment: .leading, spacing: compact ? 7 : 12) {
                    HStack(spacing: 9) {
                        PhaseLogo(size: compact ? 31 : 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("SPECTACLE ENGINE // iOS 26")
                                .font(.system(size: compact ? 8 : 10, weight: .black, design: .monospaced))
                                .tracking(compact ? 1.6 : 2.4)
                                .foregroundStyle(selectedTint)
                            Text("NATIVE GLASS PERFORMANCE BUILD")
                                .font(.system(size: compact ? 7 : 8, weight: .bold, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("零点相位")
                        .font(.system(size: compact ? 45 : 76, weight: .black, design: .rounded))
                        .tracking(compact ? -3 : -5.5)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.88), selectedTint.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: selectedTint.opacity(0.22), radius: 24)
                        .minimumScaleFactor(0.62)
                        .lineLimit(1)

                    Text("PHASE ZERO // SPECTACLE OVERDRIVE")
                        .font(.system(size: compact ? 8 : 10, weight: .black, design: .monospaced))
                        .tracking(compact ? 1.7 : 3.3)
                        .foregroundStyle(.white.opacity(0.64))

                    if !compact {
                        Text("不是把发光强度拧到最大，而是让相位核心、设备姿态、Liquid Glass、ProMotion 与战斗事件真的组成一套会呼吸的界面。昂贵芯片终于开始做表演，而不是只负责把掌心烤熟。")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                            .lineSpacing(4)
                            .frame(maxWidth: 610, alignment: .leading)
                    }
                }
                .offset(x: CGFloat(motion.interfaceTiltX) * 8, y: CGFloat(motion.interfaceTiltY) * 5)

                VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                    capabilityRail(compact: compact)
                    if !compact {
                        HStack(spacing: 8) {
                            telemetryPill("\(Int(performance.snapshot.fps.rounded())) FPS", icon: "gauge.open.with.lines.needle.67percent", tint: .mint)
                            telemetryPill(performance.snapshot.thermalLabel, icon: "thermometer.medium", tint: .orange)
                            telemetryPill(settings.spectaclePreset.title, icon: "sparkles", tint: .pink)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.bottom, compact ? 4 : 12)
            }
        }
    }

    private func commandDeck(compact: Bool) -> some View {
        GlassPanel(tint: selectedTint, cornerRadius: compact ? 25 : 34, padding: compact ? 13 : 21) {
            Group {
                if compact {
                    ScrollView(.vertical, showsIndicators: false) {
                        commandDeckContents(compact: true)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                } else {
                    commandDeckContents(compact: false)
                }
            }
        }
        .rotation3DEffect(.degrees(Double(motion.interfaceTiltY) * -2.6), axis: (x: 1, y: 0, z: 0), perspective: 0.65)
        .rotation3DEffect(.degrees(Double(motion.interfaceTiltX) * 2.8), axis: (x: 0, y: 1, z: 0), perspective: 0.65)
        .offset(x: CGFloat(motion.interfaceTiltX) * -4, y: CGFloat(motion.interfaceTiltY) * -3)
    }

    private func commandDeckContents(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 15) {
            deckHeader(compact: compact)
            modeSelector(compact: compact)
            directivePanel(compact: compact)

            Button {
                model.startSelectedRun()
            } label: {
                HStack(spacing: 10) {
                    if selectedDirective.mode == .director && director.isGeneratingContract {
                        ProgressView()
                            .controlSize(.small)
                        Text("导演正在制造事故")
                    } else {
                        Image(systemName: "play.fill")
                        Text("启动 \(selectedDirective.mode.title)")
                        Spacer(minLength: 2)
                        Text(selectedDirective.mode.shortCode)
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .tracking(1.4)
                            .opacity(0.72)
                    }
                }
                .font(.headline.weight(.black))
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(selectedTint)
            .controlSize(compact ? .large : .extraLarge)
            .disabled(model.isLaunching || (selectedDirective.mode == .director && director.isGeneratingContract))

            VStack(spacing: 8) {
                HStack(spacing: 9) {
                    Button {
                        model.showHangar = true
                    } label: {
                        Label("机库", systemImage: "airplane")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(progression.activeFrame.tint)

                    Button {
                        model.showPhaseRadio = true
                    } label: {
                        Label("相位电台", systemImage: music.isPlaying ? "waveform" : "music.note.list")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }

                HStack(spacing: 9) {
                    Button {
                        model.showSettings = true
                    } label: {
                        Label("设置", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)

                    Button {
                        model.showSystemLab = true
                    } label: {
                        Label("实验室", systemImage: "cpu")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            }

            footerStatus(compact: compact)
        }
    }

    private func deckHeader(compact: Bool) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("COMMAND DECK")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(2.1)
                    .foregroundStyle(selectedTint)
                Text("选择裂隙协议")
                    .font(compact ? .headline : .title3)
                    .fontWeight(.black)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("LOCAL BEST")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text(model.bestScore, format: .number)
                    .font(.system(size: compact ? 21 : 28, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("\(progression.activeFrame.code) · \(progression.points) Φ")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(progression.activeFrame.tint)
            }
        }
    }

    private func modeSelector(compact: Bool) -> some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(RunMode.allCases) { mode in
                    let selected = model.selectedRunMode == mode
                    Button {
                        withAnimation(.snappy(duration: 0.34, extraBounce: 0.08)) {
                            model.selectRunMode(mode)
                        }
                    } label: {
                        VStack(spacing: compact ? 4 : 6) {
                            Image(systemName: mode.icon)
                                .font(compact ? .subheadline : .headline)
                                .foregroundStyle(selected ? mode.spectacleTint : .secondary)
                            Text(mode.title.replacingOccurrences(of: "裂隙", with: ""))
                                .font(.system(size: compact ? 8 : 9, weight: .black))
                                .lineLimit(1)
                            Text(mode.shortCode)
                                .font(.system(size: 6, weight: .black, design: .monospaced))
                                .tracking(0.9)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, compact ? 7 : 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selected ? .primary : .secondary)
                    .background(.black.opacity(selected ? 0.04 : 0.01), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .glassEffect(
                        .regular
                            .tint(mode.spectacleTint.opacity(selected ? 0.19 : 0.045))
                            .interactive(),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .glassEffectID(selected ? "active-mode" : "mode-\(mode.rawValue)", in: glassNamespace)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(selected ? mode.spectacleTint.opacity(0.70) : .clear, lineWidth: 1)
                            .shadow(color: selected ? mode.spectacleTint.opacity(0.40) : .clear, radius: 10)
                    }
                    .scaleEffect(selected ? 1.025 : 0.985)
                }
            }
        }
    }

    private func directivePanel(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDirective.title)
                        .font(.subheadline.weight(.black))
                        .lineLimit(1)
                    Text("倍率 ×\(selectedDirective.scoreMultiplier, specifier: "%.2f") · \(selectedDirective.shareCode)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if selectedDirective.mode == .director {
                    Button {
                        model.refreshDirectorContract()
                    } label: {
                        Image(systemName: director.isGeneratingContract ? "hourglass" : "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .disabled(director.isGeneratingContract)
                }

                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }

            if !selectedDirective.modifiers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(selectedDirective.modifiers) { modifier in
                            Label(modifier.name, systemImage: modifier.icon)
                                .font(.system(size: 8, weight: .black))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .glassEffect(.regular.tint(modifier.tint.opacity(0.12)), in: Capsule())
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: selectedDirective.mode == .director ? "brain.head.profile.fill" : selectedDirective.mode.icon)
                    .foregroundStyle(selectedTint)
                Text(briefing)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(compact ? 3 : 5)
                    .lineSpacing(2)
            }
        }
        .padding(compact ? 11 : 13)
        .background(.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [selectedTint.opacity(0.30), .clear, selectedDirective.mode.spectacleSecondaryTint.opacity(0.20)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    private func footerStatus(compact: Bool) -> some View {
        HStack(spacing: 8) {
            ControllerBadge(name: model.controllerName)
            Spacer(minLength: 6)
            if !compact, let latest = archive.latest {
                Text("上局 \(latest.score) · W\(latest.wave)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Text("\(progression.activeFrame.code) · \(progression.points) Φ")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(progression.activeFrame.tint)
            Text(music.isPlaying ? "RADIO LIVE" : "FX \(settings.spectaclePreset.title)")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(music.isPlaying ? .green : .pink)
        }
    }

    private func capabilityRail(compact: Bool) -> some View {
        HStack(spacing: compact ? 5 : 7) {
            telemetryPill("Liquid Glass", icon: "circle.hexagongrid.fill", tint: .cyan)
            telemetryPill("\(performance.maximumRefreshRate)Hz", icon: "gauge.with.dots.needle.67percent", tint: .mint)
            telemetryPill(director.availability.isAvailable ? "本地 AI" : "AI 兜底", icon: "brain.head.profile", tint: .purple)
            if !compact {
                telemetryPill(motion.isAmbientActive ? "姿态景深" : "静态景深", icon: "gyroscope", tint: .blue)
            }
        }
    }

    private func telemetryPill(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 8, weight: .black))
            .foregroundStyle(.white.opacity(0.70))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .glassEffect(.regular.tint(tint.opacity(0.10)), in: Capsule())
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
            return "标准规则，所有奇怪构筑与后续行政事故均由玩家自行负责。"
        }
    }

    private var shareText: String {
        let protocolNames = selectedDirective.modifiers.map(\.name).joined(separator: "、")
        return "《零点相位》\(selectedDirective.mode.title) \(selectedDirective.shareCode)，倍率 ×\(String(format: "%.2f", selectedDirective.scoreMultiplier))。协议：\(protocolNames)"
    }
}
