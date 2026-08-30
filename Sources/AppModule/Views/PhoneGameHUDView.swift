import Foundation
import SwiftUI

/// iPhone HUD keeps the combat rectangle visible. Information is compressed,
/// not merely scaled down until it becomes decorative dust.
struct PhoneGameHUDView: View {
    @ObservedObject var model: GameViewModel

    var body: some View {
        GeometryReader { proxy in
            let layout = proxy.phaseZeroLayout

            VStack(spacing: layout.isSmallPhone ? 3 : 4) {
                topRail(small: layout.isSmallPhone)

                if let boss = model.hud.bossProgress {
                    bossRail(progress: boss, small: layout.isSmallPhone)
                }

                Spacer(minLength: 0)

                experienceRail(small: layout.isSmallPhone)
                    .allowsHitTesting(false)
            }
            .padding(.leading, layout.leadingInset)
            .padding(.trailing, layout.trailingInset)
            .padding(.top, layout.topInset)
            .padding(.bottom, layout.bottomInset)
        }
    }

    private func topRail(small: Bool) -> some View {
        HStack(spacing: small ? 5 : 7) {
            statusCluster(small: small)
                .frame(width: small ? 116 : 138)

            Spacer(minLength: 2)

            phaseCluster(small: small)
                .frame(width: small ? 144 : 166)

            Spacer(minLength: 2)

            styleCluster(small: small)
                .frame(width: small ? 76 : 94)

            Button {
                model.pauseGame()
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: small ? 11 : 12, weight: .black))
                    .frame(width: small ? 30 : 34, height: small ? 30 : 34)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("暂停")
        }
    }

    private func statusCluster(small: Bool) -> some View {
        HStack(spacing: small ? 5 : 7) {
            VStack(alignment: .leading, spacing: 0) {
                Text("WAVE")
                    .font(.system(size: 5.5, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(String(format: "%02d", model.hud.wave))
                    .font(.system(size: small ? 16 : 19, weight: .black, design: .rounded))
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 2.5) {
                    ForEach(0..<model.hud.maxHP, id: \.self) { index in
                        Capsule()
                            .fill(index < model.hud.hp ? Color.white : Color.white.opacity(0.13))
                            .frame(width: small ? 7 : 9, height: 4)
                    }
                }

                if model.hud.maxShield > 0 {
                    HStack(spacing: 2.5) {
                        ForEach(0..<model.hud.maxShield, id: \.self) { index in
                            Capsule()
                                .fill(index < model.hud.shield ? Color.cyan : Color.cyan.opacity(0.13))
                                .frame(width: small ? 7 : 9, height: 3)
                        }
                    }
                }

                Text(model.hud.score.formatted())
                    .font(.system(size: small ? 6 : 7, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, small ? 7 : 9)
        .padding(.vertical, small ? 5 : 6)
        .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .glassEffect(
            .regular.tint(model.hud.phaseColor.opacity(0.09)),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .allowsHitTesting(false)
    }

    private func phaseCluster(small: Bool) -> some View {
        let palette = PhasePalette.forPhase(model.hud.phase)

        return HStack(spacing: small ? 5 : 7) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(model.hud.sync / 100, 0), 1)))
                    .stroke(
                        AngularGradient(colors: [palette.primary, .white, palette.secondary], center: .center),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text(model.hud.phase == 0 ? "青" : "赤")
                    .font(.system(size: small ? 9 : 11, weight: .black, design: .rounded))
                    .foregroundStyle(palette.primary)
            }
            .frame(width: small ? 27 : 31, height: small ? 27 : 31)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(model.hud.phaseName)
                        .font(.system(size: small ? 8 : 9, weight: .black))
                        .foregroundStyle(palette.primary)
                    Text(model.hud.overdriveActive ? "OVER" : "LOCK")
                        .font(.system(size: 5.5, weight: .black, design: .monospaced))
                        .foregroundStyle(model.hud.overdriveActive ? .white : .secondary)
                }

                ThinProgressBar(progress: model.hud.sync / 100, tint: palette.primary, height: 3)

                HStack(spacing: 5) {
                    Label("\(Int(model.hud.phaseReady * 100))", systemImage: "arrow.triangle.2.circlepath")
                    Label("\(model.hud.dashCharges)", systemImage: "forward.end.fill")
                }
                .font(.system(size: 5.5, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, small ? 7 : 9)
        .padding(.vertical, small ? 4 : 5)
        .background(.black.opacity(0.08), in: Capsule())
        .glassEffect(
            .regular.tint(palette.primary.opacity(model.hud.overdriveActive ? 0.18 : 0.09)),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(palette.primary.opacity(model.hud.overdriveActive ? 0.48 : 0.18), lineWidth: 0.7)
        }
        .allowsHitTesting(false)
    }

    private func styleCluster(small: Bool) -> some View {
        HStack(spacing: small ? 4 : 6) {
            Text(model.hud.styleRank)
                .font(.system(size: small ? 19 : 23, weight: .black, design: .rounded))
                .tracking(model.hud.styleRank.count > 1 ? -2 : -1)
                .foregroundStyle(model.hud.styleColor.gradient)
                .shadow(color: model.hud.styleColor.opacity(0.55), radius: 6)

            VStack(alignment: .leading, spacing: 0) {
                Text("×\(model.hud.styleMultiplier, specifier: "%.1f")")
                    .font(.system(size: small ? 7 : 8, weight: .black, design: .monospaced))
                Text("C\(model.hud.combo)")
                    .font(.system(size: 5.5, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, small ? 6 : 8)
        .padding(.vertical, small ? 5 : 6)
        .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .glassEffect(
            .regular.tint(model.hud.styleColor.opacity(0.10)),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .allowsHitTesting(false)
    }

    private func bossRail(progress: Double, small: Bool) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text("PRISM WARDEN")
                Spacer()
                Text("\(Int(progress * 100))%")
            }
            .font(.system(size: small ? 5.5 : 6.5, weight: .black, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(.orange)

            ThinProgressBar(progress: progress, tint: .orange, height: 3)
        }
        .padding(.horizontal, small ? 8 : 10)
        .padding(.vertical, 4)
        .frame(width: small ? 230 : 300)
        .background(.black.opacity(0.09), in: Capsule())
        .glassEffect(.regular.tint(.orange.opacity(0.10)), in: Capsule())
        .allowsHitTesting(false)
    }

    private func experienceRail(small: Bool) -> some View {
        HStack(spacing: 6) {
            Text("P\(model.hud.level)")
                .font(.system(size: 6, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)

            ThinProgressBar(progress: model.hud.xpProgress, tint: .cyan, height: 3)
                .frame(width: small ? 118 : 160)

            Text("\(Int(model.hud.xp))/\(Int(model.hud.xpNeed))")
                .font(.system(size: 5.5, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.07), in: Capsule())
        .glassEffect(.regular.tint(.cyan.opacity(0.07)), in: Capsule())
    }
}
