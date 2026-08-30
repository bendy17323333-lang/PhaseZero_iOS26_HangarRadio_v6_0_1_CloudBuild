import SwiftUI

struct SystemLabView: View {
    @ObservedObject var model: GameViewModel
    @ObservedObject private var director: AIDirector
    @ObservedObject private var performance: PerformanceGovernor
    @ObservedObject private var motion: MotionAimService
    @ObservedObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var rootNoticeVisible = false

    init(model: GameViewModel) {
        self.model = model
        self._director = ObservedObject(wrappedValue: model.aiDirector)
        self._performance = ObservedObject(wrappedValue: model.performance)
        self._motion = ObservedObject(wrappedValue: model.motionAim)
        self._settings = ObservedObject(wrappedValue: model.settings)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    capabilityGrid
                    liveControls
                    gameplayChain
                }
                .padding(22)
            }
            .navigationTitle("iOS 26 系统实验室")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .presentationSizing(.page)
        .overlay {
            if rootNoticeVisible {
                VStack(spacing: 4) {
                    Text("ACCESS LEVEL // ROOT")
                        .font(.system(size: 21, weight: .black, design: .monospaced))
                        .tracking(2.4)
                    Text("FRAME AUTHORITY OVERRIDE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(.yellow)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 19)
                .background(.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .glassEffect(.regular.tint(.yellow.opacity(0.20)), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .transition(.scale(scale: 0.82).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
    }

    private var header: some View {
        GlassPanel(tint: .cyan, cornerRadius: 26, padding: 20) {
            HStack(spacing: 16) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.cyan)

                VStack(alignment: .leading, spacing: 5) {
                    Text("IOS 26 // SPECTACLE ENGINE")
                        .font(.caption2.weight(.black))
                        .tracking(2.2)
                        .foregroundStyle(.cyan)
                    Text("让系统能力直接参与玩法")
                        .font(.title3.weight(.black))
                    Text("只使用 iOS / iPadOS 26 SDK。AI、陀螺仪、触感、刷新率、窗口系统和快捷指令都有实际职责，不再给未来框架预留一排毫无用处的灰色按钮。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("iOS 26")
                        .font(.headline.monospacedDigit())
                    Text("SDK LOCKED")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.mint)
                    Text(ProcessInfo.processInfo.operatingSystemVersionString)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var capabilityGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 235), spacing: 12)], spacing: 12) {
            capabilityCard(
                title: "Liquid Glass",
                detail: "原生 glassEffect、GlassEffectContainer、交互玻璃按钮与协议卡片形变。降低透明度或增强对比度时自动加深底色。",
                icon: "circle.hexagongrid.fill",
                state: .active,
                tint: .cyan
            )

            capabilityCard(
                title: "Spectacle Engine",
                detail: "当前为\(settings.spectaclePreset.title)档：原生全屏冲击、相位折射、风格评级、启动演出和 Web 战斗粒子共用同一强度预算。",
                icon: "sparkles.rectangle.stack.fill",
                state: .active,
                tint: .pink
            )

            capabilityCard(
                title: "Foundation Models",
                detail: director.availability.isAvailable
                    ? "设备端模型会从受控协议白名单生成导演裂隙，并撰写简报与战后报告；规则数值仍由游戏代码决定。"
                    : director.availability.detail,
                icon: "brain.head.profile",
                state: director.availability.isAvailable ? .active : .fallback,
                tint: .purple
            )

            capabilityCard(
                title: "Core Motion 精瞄",
                detail: "右摇杆或触控决定主方向，陀螺仪只追加小幅角速度修正。\(motion.statusText)",
                icon: "gyroscope",
                state: motion.isSupported ? (motion.isActive ? .active : .available) : .unavailable,
                tint: .blue
            )

            capabilityCard(
                title: "Core Haptics",
                detail: model.haptics.supportsAdvancedHaptics
                    ? "换相、冲刺、擦弹、护盾破裂、Boss 与过载使用不同波形。"
                    : "当前设备没有高级触感硬件，已切换 UIKit 反馈兜底。",
                icon: "waveform.path",
                state: model.haptics.supportsAdvancedHaptics ? .active : .fallback,
                tint: .orange
            )

            capabilityCard(
                title: "ProMotion 与热量调度",
                detail: "屏幕上限 \(performance.maximumRefreshRate) Hz；当前 \(performance.snapshot.compactLabel)。系统会调节内部倍率、粒子预算和目标帧率，不暗改敌人强度。",
                icon: "gauge.open.with.lines.needle.67percent",
                state: performance.maximumRefreshRate > 60 ? .active : .available,
                tint: .mint
            )

            capabilityCard(
                title: "App Intents",
                detail: "安装为 App 后，可从 Siri、快捷指令和操作按钮启动自由裂隙、每日裂隙或导演裂隙。",
                icon: "command.circle.fill",
                state: .available,
                tint: .indigo
            )

            capabilityCard(
                title: "iPadOS 26 菜单栏",
                detail: "顶部菜单与外接键盘快捷键可开始模式、暂停、换相、冲刺和打开实验室。窗口缩小时主菜单会自动改为单列。",
                icon: "menubar.rectangle",
                state: .active,
                tint: .teal
            )

            capabilityCard(
                title: "MusicKit 相位电台",
                detail: model.appleMusic.accessState == .authorized
                    ? "Apple Music 资料库已连接；ApplicationMusicPlayer 使用独立队列播放，游戏合成音乐会按设置自动让位。"
                    : model.appleMusic.accessState.detail,
                icon: "music.note.house.fill",
                state: model.appleMusic.accessState == .authorized ? .active : .available,
                tint: .pink
            )

            capabilityCard(
                title: "离线 WebKit 战斗核心",
                detail: "弹幕、Boss 和肉鸽逻辑随 App 打包，不依赖服务器；原生层只负责系统能力和界面。渲染进程崩溃时会自动重载并给出日志。",
                icon: "network.slash",
                state: model.webReady ? .active : .available,
                tint: .blue
            )

            capabilityCard(
                title: "辅助功能",
                detail: "响应减少动态效果、降低透明度和增强对比度；关键按钮保留语义标签，手柄与触屏不会被迫共享一套可疑尺寸。",
                icon: "accessibility",
                state: .active,
                tint: .yellow
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onLongPressGesture(minimumDuration: 3.0, maximumDistance: 12) {
                guard !model.progression.laboratoryOverride else { return }
                model.activateLaboratoryOverride()
                withAnimation(.snappy(duration: 0.28, extraBounce: 0.08)) {
                    rootNoticeVisible = true
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_250_000_000)
                    withAnimation(.easeOut(duration: 0.24)) {
                        rootNoticeVisible = false
                    }
                }
            }
        }
    }

    private var liveControls: some View {
        GlassPanel(tint: .mint, cornerRadius: 25, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Label("实时测试", systemImage: "waveform.badge.magnifyingglass")
                    .font(.headline.weight(.black))

                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        Button {
                            model.previewSpectacle(.phase)
                        } label: {
                            Label("换相冲击", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)

                        Button {
                            model.previewSpectacle(.overdrive)
                        } label: {
                            Label("过载演出", systemImage: "bolt.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.pink)

                        Button {
                            model.previewSpectacle(.rank)
                        } label: {
                            Label("SSS 评级", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)

                        Button {
                            model.previewSpectacle(.boss)
                        } label: {
                            Label("Boss 警报", systemImage: "exclamationmark.triangle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        model.recenterMotionAim()
                    } label: {
                        Label("陀螺归零", systemImage: "scope")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .disabled(!motion.isSupported)

                    Button {
                        director.prepareBriefing(
                            for: model.dailyDirective,
                            enabled: model.settings.aiDirectorEnabled
                        )
                    } label: {
                        Label("重写简报", systemImage: "brain")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)

                    Button {
                        performance.setProfile(model.settings.renderProfile)
                        model.pushSettings()
                    } label: {
                        Label("重新校准", systemImage: "gauge.with.dots.needle.67percent")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }

                HStack {
                    Label("实时陀螺", systemImage: "rotate.3d")
                    Spacer()
                    Text(motion.liveTurnRate, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit()
                    Text("rad/s")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)

                ThinProgressBar(
                    progress: min(abs(motion.liveTurnRate) / 3.2, 1),
                    tint: motion.liveTurnRate >= 0 ? .cyan : .orange,
                    height: 6
                )

                HStack {
                    Label("界面姿态", systemImage: "move.3d")
                    Spacer()
                    Text("X \(motion.interfaceTiltX, specifier: "%+.2f") · Y \(motion.interfaceTiltY, specifier: "%+.2f")")
                        .monospacedDigit()
                        .foregroundStyle(settings.interfaceParallaxEnabled ? .mint : .secondary)
                }
                .font(.caption)

                HStack {
                    Label("性能预算", systemImage: "speedometer")
                    Spacer()
                    Text("×\(performance.snapshot.renderScale, specifier: "%.2f") · FX \(Int(performance.snapshot.particleScale * settings.spectaclePreset.particleMultiplier * 100))% · \(performance.snapshot.targetFPS) FPS")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
    }

    private var gameplayChain: some View {
        GlassPanel(tint: .purple, cornerRadius: 25, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Label("系统到玩法的完整链路", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.headline.weight(.black))

                chainRow(
                    index: "01",
                    title: "系统能力采样",
                    detail: "读取刷新率、低电量、热状态、手柄、陀螺仪和 Apple Intelligence 可用性。",
                    tint: .cyan
                )
                chainRow(
                    index: "02",
                    title: "原生策略层",
                    detail: "生成每日或导演协议、计算性能预算、过滤陀螺角速度、选择触感波形，并把演出强度映射到原生与 Web 双层渲染。",
                    tint: .purple
                )
                chainRow(
                    index: "03",
                    title: "战斗核心执行",
                    detail: "通过受控 Bridge 把协议、瞄准修正和渲染预算交给弹幕引擎；擦弹、换相清弹和高风险击杀会驱动风格评级与得分倍率。",
                    tint: .mint
                )
                chainRow(
                    index: "04",
                    title: "结果回流",
                    detail: "局内统计进入本地记录，再由设备端模型生成复盘；分享只发送玩家主动选择的战报文本。",
                    tint: .orange
                )
            }
        }
    }

    private func capabilityCard(
        title: String,
        detail: String,
        icon: String,
        state: CapabilityState,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.black))
                Spacer()
                Text(state.label)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(state.color)
            }
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(5)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .glassEffect(.regular.tint(tint.opacity(0.09)), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func chainRow(index: String, title: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(index)
                .font(.caption2.weight(.black))
                .monospacedDigit()
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private enum CapabilityState {
    case active
    case available
    case fallback
    case unavailable

    var label: String {
        switch self {
        case .active: return "运行中"
        case .available: return "可用"
        case .fallback: return "兜底"
        case .unavailable: return "不可用"
        }
    }

    var color: Color {
        switch self {
        case .active: return .mint
        case .available: return .cyan
        case .fallback: return .orange
        case .unavailable: return .red
        }
    }
}
