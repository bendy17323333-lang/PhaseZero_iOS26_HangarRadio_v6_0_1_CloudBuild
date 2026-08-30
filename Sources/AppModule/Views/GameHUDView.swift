import Foundation
import SwiftUI

struct GameHUDView: View {
    @ObservedObject var model: GameViewModel
    @ObservedObject private var settings: SettingsStore

    init(model: GameViewModel) {
        self.model = model
        self._settings = ObservedObject(wrappedValue: model.settings)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = proxy.phaseZeroLayout
            let compact = proxy.size.width < 820 || proxy.size.height < 450

            if layout.isPhoneLandscape {
                PhoneGameHUDView(model: model)
            } else {
                VStack(spacing: compact ? 6 : 10) {
                    topHUD(compact: compact)

                    if let boss = model.hud.bossProgress {
                        bossBar(progress: boss, compact: compact)
                    }

                    Spacer()
                    bottomHUD(compact: compact)
                }
                .safeAreaPadding(.horizontal, compact ? 10 : 18)
                .safeAreaPadding(.vertical, compact ? 7 : 12)
            }
        }
        .allowsHitTesting(true)
    }

    private func topHUD(compact: Bool) -> some View {
        GlassEffectContainer(spacing: compact ? 7 : 10) {
            HStack(alignment: .top, spacing: compact ? 7 : 10) {
                statusCluster(compact: compact)

                Spacer(minLength: compact ? 4 : 12)

                PhaseLensHUD(hud: model.hud, compact: compact)
                    .frame(width: compact ? 190 : 276)

                Spacer(minLength: compact ? 4 : 12)

                combatCluster(compact: compact)
            }
        }
    }

    private func statusCluster(compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 9) {
            GlassHUDCard(tint: model.hud.phaseColor) {
                HStack(spacing: compact ? 8 : 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("WAVE")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%02d", model.hud.wave))
                            .font(.system(size: compact ? 19 : 25, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    integrityDisplay(compact: compact)
                }
            }

            if !compact {
                GlassHUDCard(tint: .mint) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SCORE // CHAIN")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(.secondary)
                        Text("\(model.hud.score.formatted())  ×\(model.hud.combo)")
                            .font(.subheadline.weight(.black))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
            }
        }
    }

    private func combatCluster(compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 9) {
            if !compact {
                StyleRankCard(hud: model.hud)
            }

            ControllerBadge(name: model.controllerName)
                .opacity(compact ? 0 : 1)
                .frame(width: compact ? 0 : nil)

            Button {
                model.pauseGame()
            } label: {
                Image(systemName: "pause.fill")
                    .font(.headline)
                    .frame(width: compact ? 27 : 31, height: compact ? 27 : 31)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("暂停")
        }
    }

    private func integrityDisplay(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                ForEach(0..<model.hud.maxHP, id: \.self) { index in
                    Capsule()
                        .fill(index < model.hud.hp ? Color.white : Color.white.opacity(0.12))
                        .frame(width: compact ? 10 : 13, height: 5)
                        .shadow(color: index < model.hud.hp ? .white.opacity(0.55) : .clear, radius: 4)
                }
            }
            if model.hud.maxShield > 0 {
                HStack(spacing: 4) {
                    ForEach(0..<model.hud.maxShield, id: \.self) { index in
                        Capsule()
                            .fill(index < model.hud.shield ? Color.cyan : Color.cyan.opacity(0.12))
                            .frame(width: compact ? 10 : 13, height: 4)
                            .shadow(color: index < model.hud.shield ? .cyan.opacity(0.65) : .clear, radius: 5)
                    }
                }
            }
        }
    }

    private func bossBar(progress: Double, compact: Bool) -> some View {
        GlassHUDCard(tint: .orange) {
            VStack(spacing: 5) {
                HStack {
                    Label("PRISM WARDEN", systemImage: "exclamationmark.triangle.fill")
                    Spacer()
                    Text("\(Int(progress * 100))%")
                }
                .font(.system(size: compact ? 8 : 9, weight: .black, design: .monospaced))
                .tracking(compact ? 1.2 : 1.8)
                ThinProgressBar(progress: progress, tint: .orange, height: compact ? 4 : 5)
            }
            .frame(width: compact ? 290 : 440)
        }
    }

    private func bottomHUD(compact: Bool) -> some View {
        HStack(alignment: .bottom) {
            if compact {
                StyleRankCard(hud: model.hud, compact: true)
            }

            Spacer()

            GlassHUDCard(tint: .cyan) {
                VStack(spacing: 4) {
                    HStack {
                        Text("PROTOCOL \(model.hud.level)")
                        Spacer()
                        Text("\(Int(model.hud.xp)) / \(Int(model.hud.xpNeed)) XP")
                    }
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                    ThinProgressBar(progress: model.hud.xpProgress, tint: .cyan, height: 4)
                }
                .frame(width: compact ? 210 : 280)
            }
            .allowsHitTesting(false)

            Spacer()

            if settings.motionAimEnabled && !compact {
                GlassHUDCard(tint: .mint) {
                    Label("GYRO FINE AIM", systemImage: "gyroscope")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct PhaseLensHUD: View {
    let hud: HUDSnapshot
    let compact: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                lens(time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { timeline in
                    lens(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
    }

    private func lens(time: TimeInterval) -> some View {
        let palette = PhasePalette.forPhase(hud.phase)
        return HStack(spacing: compact ? 7 : 11) {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.05))
                    .glassEffect(.regular.tint(palette.primary.opacity(hud.overdriveActive ? 0.25 : 0.13)), in: Circle())

                Circle()
                    .trim(from: 0, to: CGFloat(min(max(hud.sync / 100, 0), 1)))
                    .stroke(
                        AngularGradient(colors: [palette.primary, .white, palette.secondary], center: .center),
                        style: StrokeStyle(lineWidth: compact ? 3 : 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(compact ? 4 : 5)
                    .shadow(color: palette.primary.opacity(0.72), radius: 8)

                Circle()
                    .trim(from: 0.08, to: 0.78)
                    .stroke(.white.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                    .padding(compact ? 10 : 13)
                    .rotationEffect(.radians(time * (hud.overdriveActive ? 1.4 : 0.45)))

                Text(hud.phase == 0 ? "青" : "赤")
                    .font(.system(size: compact ? 15 : 20, weight: .black, design: .rounded))
                    .foregroundStyle(palette.primary)
            }
            .frame(width: compact ? 48 : 64, height: compact ? 48 : 64)

            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                HStack(spacing: 6) {
                    Text(hud.phaseName)
                        .font(.system(size: compact ? 11 : 13, weight: .black))
                        .foregroundStyle(palette.primary)
                    Text(hud.overdriveActive ? "OVERDRIVE" : "PHASE LOCK")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(hud.overdriveActive ? .white : .secondary)
                }

                Text("SYNC \(Int(hud.sync))%")
                    .font(.system(size: compact ? 8 : 9, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)

                HStack(spacing: 7) {
                    cooldownGlyph(system: "arrow.triangle.2.circlepath", progress: hud.phaseReady, tint: palette.primary)
                    cooldownGlyph(system: "forward.end.fill", progress: hud.dashReady, tint: palette.secondary)
                    Text("×\(hud.dashCharges)/\(hud.dashChargesMax)")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, compact ? 9 : 13)
        .padding(.vertical, compact ? 6 : 8)
        .glassEffect(
            .regular.tint(palette.primary.opacity(hud.overdriveActive ? 0.22 : 0.10)),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(
                    AngularGradient(colors: [.clear, palette.primary.opacity(0.48), .clear, palette.secondary.opacity(0.28), .clear], center: .center),
                    lineWidth: hud.overdriveActive ? 1.5 : 0.7
                )
        }
    }

    private func cooldownGlyph(system: String, progress: Double, tint: Color) -> some View {
        ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: system)
                .font(.system(size: 6, weight: .black))
        }
        .frame(width: 16, height: 16)
    }
}

private struct StyleRankCard: View {
    let hud: HUDSnapshot
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 7 : 10) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.10), lineWidth: compact ? 3 : 4)
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(hud.style / 100, 0.015), 1)))
                    .stroke(
                        AngularGradient(colors: [hud.styleColor, .white, hud.styleColor.opacity(0.42)], center: .center),
                        style: StrokeStyle(lineWidth: compact ? 3 : 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: hud.styleColor.opacity(0.70), radius: 8)
                Text(hud.styleRank)
                    .font(.system(size: compact ? 22 : 31, weight: .black, design: .rounded))
                    .tracking(hud.styleRank.count > 1 ? (compact ? -2 : -3) : -1)
                    .foregroundStyle(hud.styleColor.gradient)
                    .shadow(color: hud.styleColor.opacity(0.72), radius: 10)
                    .contentTransition(.numericText())
            }
            .frame(width: compact ? 43 : 58, height: compact ? 43 : 58)

            VStack(alignment: .leading, spacing: 2) {
                Text(hud.overdriveActive ? "STYLE // LIVE" : "STYLE ENGINE")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(hud.overdriveActive ? hud.styleColor : .secondary)
                Text("×\(hud.styleMultiplier, specifier: "%.2f")")
                    .font(.caption2.weight(.black))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(compact ? "\(hud.score.formatted()) PTS" : "GRAZE \(hud.grazes) // \(Int(hud.style))%")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 5 : 7)
        .glassEffect(
            .regular.tint(hud.styleColor.opacity(hud.overdriveActive ? 0.20 : 0.11)),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(hud.overdriveActive ? hud.styleColor.opacity(0.52) : .clear, lineWidth: 1)
                .shadow(color: hud.overdriveActive ? hud.styleColor.opacity(0.42) : .clear, radius: 12)
        }
    }
}
