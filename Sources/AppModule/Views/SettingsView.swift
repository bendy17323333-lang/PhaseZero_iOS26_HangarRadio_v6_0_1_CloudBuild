import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: GameViewModel
    @ObservedObject private var settings: SettingsStore
    @ObservedObject private var director: AIDirector
    @ObservedObject private var performance: PerformanceGovernor
    @ObservedObject private var motion: MotionAimService
    @ObservedObject private var music: AppleMusicService
    @Environment(\.dismiss) private var dismiss
    @State private var musicVisualizerSuspended = false

    init(model: GameViewModel) {
        self.model = model
        self._settings = ObservedObject(wrappedValue: model.settings)
        self._director = ObservedObject(wrappedValue: model.aiDirector)
        self._performance = ObservedObject(wrappedValue: model.performance)
        self._motion = ObservedObject(wrappedValue: model.motionAim)
        self._music = ObservedObject(wrappedValue: model.appleMusic)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 285), spacing: 16)], spacing: 16) {
                    spectaclePanel
                    feedbackPanel
                    musicPanel
                    aimPanel
                    performancePanel
                    aiPanel
                    systemPanel
                }
                .padding(20)
            }
            .navigationTitle("系统调校")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        model.flushSettingsChanges()
                        dismiss()
                    }
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .presentationSizing(.page)
        .onDisappear { model.flushSettingsChanges() }
    }

    private var spectaclePanel: some View {
        GlassPanel(tint: .pink, cornerRadius: 28, padding: 18) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.08))
                            .glassEffect(.regular.tint(.pink.opacity(0.16)), in: Circle())
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.title2.weight(.black))
                            .foregroundStyle(.pink.gradient)
                            .shadow(color: .pink.opacity(0.6), radius: 10)
                    }
                    .frame(width: 50, height: 50)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("SPECTACLE ENGINE")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(2.0)
                            .foregroundStyle(.pink)
                        Text("演出强度")
                            .font(.headline.weight(.black))
                    }
                    Spacer()
                    Text("×\(settings.spectaclePreset.nativeFXScale, specifier: "%.2f")")
                        .font(.title3.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(.pink)
                }

                Picker("演出强度", selection: $settings.spectaclePreset) {
                    ForEach(SpectaclePreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.segmented)

                Text(settings.spectaclePreset.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineSpacing(3)

                Toggle("设备姿态驱动玻璃景深", isOn: $settings.interfaceParallaxEnabled)
                    .disabled(!motion.isSupported)

                HStack(spacing: 10) {
                    spectacleMetric("NATIVE FX", value: "\(Int(settings.spectaclePreset.nativeFXScale * 100))%", tint: .pink)
                    spectacleMetric("PARTICLES", value: "\(Int(settings.spectaclePreset.particleMultiplier * 100))%", tint: .cyan)
                    spectacleMetric("TILT", value: settings.interfaceParallaxEnabled ? "LIVE" : "OFF", tint: .mint)
                }

                if settings.spectaclePreset == .unhinged {
                    Label("失控模式会优先保留全屏冲击、玻璃形变与粒子密度；性能调度器仍会在高温时踩刹车。芯片有尊严，但没有表决权。", systemImage: "bolt.horizontal.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var feedbackPanel: some View {
        GlassPanel(tint: .cyan, cornerRadius: 24, padding: 18) {
            VStack(alignment: .leading, spacing: 15) {
                settingsHeader("游戏反馈", icon: "waveform.path")
                Toggle("声音", isOn: $settings.soundEnabled)
                Toggle("触觉反馈", isOn: $settings.hapticsEnabled)
                HStack {
                    Text(model.haptics.supportsAdvancedHaptics ? "Core Haptics 波形" : "UIKit 反馈兜底")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("测试") {
                        model.haptics.play("overdrive", enabled: true)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
            }
        }
    }

    private var musicPanel: some View {
        let appleMode = model.radioSource == .appleMusic
        let gameTrack = model.activeBuiltInSoundtrack
        let title = appleMode ? music.currentTitle : gameTrack.title
        let subtitle = appleMode ? music.currentSubtitle : "\(gameTrack.subtitle) · \(gameTrack.tempoLabel)"
        let seed = appleMode ? music.currentTrackSeed : "game|\(gameTrack.id)"
        let playing = appleMode ? music.isPlaying : model.isBuiltInSoundtrackAudible
        let tint = appleMode ? Color.pink : gameTrack.tint
        let secondaryTint = appleMode ? Color.cyan : gameTrack.secondaryTint

        return GlassPanel(tint: tint, cornerRadius: 24, padding: 18) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    settingsHeader("相位电台", icon: appleMode ? "music.note" : "waveform.path.ecg")
                    Spacer()
                    Text(appleMode ? (music.isPlaying ? "APPLE LIVE" : "APPLE PAUSED") : (settings.gameMusicEnabled ? "GAME OST" : "OST PAUSED"))
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(playing ? .mint : .secondary)
                }

                HStack(spacing: 12) {
                    RadioArtworkView(
                        source: model.radioSource,
                        music: music,
                        gameTrack: gameTrack,
                        size: 58
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.subheadline.weight(.black))
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(appleMode ? music.accessState.detail : "游戏原声无需账号，连接 Apple Music 后也不会从电台消失。")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.56))
                            .lineLimit(2)
                    }
                }

                PhaseAudioVisualizer(
                    seed: seed,
                    playbackTime: appleMode ? music.playbackTime : 0,
                    isPlaying: playing,
                    tint: secondaryTint,
                    secondaryTint: tint,
                    suspended: musicVisualizerSuspended,
                    barCount: 26
                )
                .frame(height: 48)
                .padding(.horizontal, 7)
                .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                if appleMode, music.accessState == .authorized {
                    DeferredSeekSlider(
                        playbackTime: music.playbackTime,
                        duration: music.duration,
                        tint: .pink,
                        onBegin: { music.beginScrubbing() },
                        onCommit: { music.commitSeek(to: $0) },
                        onCancel: { music.cancelScrubbing() },
                        onEditingChanged: { musicVisualizerSuspended = $0 }
                    )

                    HStack(spacing: 8) {
                        Button { model.skipAppleMusicPrevious() } label: {
                            Image(systemName: "backward.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)

                        Button { model.toggleAppleMusicPlayback() } label: {
                            Group {
                                if music.isPreparingPlayback {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.pink)

                        Button { model.skipAppleMusicNext() } label: {
                            Image(systemName: "forward.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                    }
                    .disabled(music.isPreparingPlayback)
                } else if appleMode {
                    Button {
                        Task { await music.requestAccessAndLoad() }
                    } label: {
                        Label("连接 Apple Music", systemImage: "person.badge.key.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.pink)
                    .disabled(music.accessState == .restricted || music.accessState == .unavailable)
                } else {
                    HStack(spacing: 8) {
                        Button { model.skipBuiltInSoundtrack(delta: -1) } label: {
                            Image(systemName: "backward.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)

                        Button { model.toggleBuiltInSoundtrack() } label: {
                            Image(systemName: settings.gameMusicEnabled ? "pause.fill" : "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(gameTrack.tint)

                        Button { model.skipBuiltInSoundtrack(delta: 1) } label: {
                            Image(systemName: "forward.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                    }
                }

                if appleMode, let error = music.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(3)
                }

                Toggle("播放 Apple Music 时压低游戏原声", isOn: $settings.duckGameMusicForAppleMusic)
                    .font(.caption)

                Button {
                    model.flushSettingsChanges()
                    dismiss()
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 320_000_000)
                        model.showPhaseRadio = true
                    }
                } label: {
                    Label("打开完整音乐库", systemImage: "music.note.list")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var aimPanel: some View {
        GlassPanel(tint: .mint, cornerRadius: 24, padding: 18) {
            VStack(alignment: .leading, spacing: 15) {
                settingsHeader("辅助瞄准", icon: "scope")
                Picker("软锁强度", selection: $settings.aimAssist) {
                    ForEach(AimAssistPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("陀螺仪精细修正", isOn: $settings.motionAimEnabled)
                    .disabled(!motion.isSupported)

                if settings.motionAimEnabled {
                    LabeledContent("陀螺灵敏度") {
                        DeferredSettingSlider(value: settings.motionSensitivity, in: 0.25...2.5) { value in
                            settings.motionSensitivity = value
                            model.flushSettingsChanges()
                        }
                        .frame(width: 145)
                    }
                    Toggle("反转陀螺方向", isOn: $settings.invertMotion)
                    Button {
                        model.recenterMotionAim()
                    } label: {
                        Label("重新归零", systemImage: "scope")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }

                Toggle("反转摇杆 Y 轴", isOn: $settings.invertAimY)
                Text("陀螺仪只负责细微转向，右摇杆或触控仍决定主要方向。它不是让玩家把 iPad 当方向盘甩。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var performancePanel: some View {
        GlassPanel(tint: .orange, cornerRadius: 24, padding: 18) {
            VStack(alignment: .leading, spacing: 15) {
                settingsHeader("显示与性能", icon: "gauge.with.dots.needle.67percent")
                Picker("渲染", selection: $settings.renderProfile) {
                    ForEach(RenderProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("触控 UI 透明度") {
                    DeferredSettingSlider(value: settings.touchOpacity, in: 0.28...0.90) { value in
                        settings.touchOpacity = value
                        model.flushSettingsChanges()
                    }
                    .frame(width: 145)
                }
                Toggle("连接手柄时仍显示触控区", isOn: $settings.showTouchWithController)
                Toggle("游戏中显示性能状态", isOn: $settings.showPerformanceHUD)

                Divider().opacity(0.22)
                LabeledContent("实时帧率") {
                    Text("\(Int(performance.snapshot.fps.rounded())) / \(performance.snapshot.targetFPS) FPS")
                        .monospacedDigit()
                }
                LabeledContent("内部倍率") {
                    Text("×\(performance.snapshot.renderScale, specifier: "%.2f")")
                        .monospacedDigit()
                }
                LabeledContent("粒子预算") {
                    Text("\(Int(performance.snapshot.particleScale * settings.spectaclePreset.particleMultiplier * 100))%")
                        .monospacedDigit()
                }
                LabeledContent("热状态") {
                    Text(performance.snapshot.thermalLabel)
                        .foregroundStyle(performance.snapshot.lowPower ? .orange : .secondary)
                }
            }
        }
    }

    private var aiPanel: some View {
        GlassPanel(tint: .purple, cornerRadius: 24, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                settingsHeader("相位导演", icon: "brain.head.profile")
                Toggle("使用设备端 AI 简报", isOn: $settings.aiDirectorEnabled)
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: director.availability.isAvailable ? "checkmark.circle.fill" : "arrow.trianglehead.2.clockwise.rotate.90")
                        .foregroundStyle(director.availability.isAvailable ? .mint : .orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(director.availability.title)
                            .font(.caption.weight(.bold))
                        Text(director.availability.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("AI 只生成简报和战后点评。每日协议、数值和掉落仍由确定性规则决定，免得语言模型临时发明一把伤害九千的行政许可证。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var systemPanel: some View {
        GlassPanel(tint: .blue, cornerRadius: 24, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                settingsHeader("系统适配", icon: "apple.logo")
                LabeledContent("当前系统") {
                    Text("iOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("玻璃配置") {
                    Text(PlatformGlassProfile.displayName)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("屏幕刷新上限") {
                    Text("\(performance.maximumRefreshRate) Hz")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("姿态景深") {
                    Text(motion.statusText)
                        .foregroundStyle(motion.isAmbientActive ? .mint : .secondary)
                }
                Button {
                    model.showSystemLab = true
                    dismiss()
                } label: {
                    Label("打开系统实验室", systemImage: "cpu")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
            }
        }
    }

    private func spectacleMetric(_ title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2.weight(.black))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func settingsHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline.weight(.bold))
    }
}
