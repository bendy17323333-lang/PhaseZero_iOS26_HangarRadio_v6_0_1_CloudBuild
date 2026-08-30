import SwiftUI

struct PhoneGameOverOverlay: View {
    @ObservedObject var model: GameViewModel
    @ObservedObject private var director: AIDirector

    init(model: GameViewModel) {
        self.model = model
        self._director = ObservedObject(wrappedValue: model.aiDirector)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = proxy.phaseZeroLayout
            let tint: Color = model.gameOver.newRecord ? .yellow : .red

            ZStack {
                Color.black.opacity(0.60)
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [tint.opacity(0.18), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.72
                )
                .ignoresSafeArea()
                .blendMode(.screen)

                GlassPanel(
                    tint: tint,
                    cornerRadius: layout.isSmallPhone ? 19 : 23,
                    padding: layout.isSmallPhone ? 10 : 13
                ) {
                    HStack(spacing: layout.isSmallPhone ? 10 : 14) {
                        identity(tint: tint, small: layout.isSmallPhone)
                            .frame(width: layout.isSmallPhone ? 125 : 155)
                        details(tint: tint, small: layout.isSmallPhone)
                    }
                }
                .frame(maxWidth: layout.isSmallPhone ? 600 : 760)
                .padding(.leading, layout.leadingInset)
                .padding(.trailing, layout.trailingInset)
                .padding(.top, layout.topInset)
                .padding(.bottom, layout.bottomInset)
            }
        }
    }

    private func identity(tint: Color, small: Bool) -> some View {
        VStack(spacing: small ? 5 : 7) {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.09))
                    .glassEffect(.regular.tint(tint.opacity(0.15)), in: Circle())
                Circle()
                    .trim(from: 0.06, to: 0.78)
                    .stroke(
                        AngularGradient(colors: [tint, styleTint, .white, tint], center: .center),
                        style: StrokeStyle(lineWidth: small ? 2.4 : 3, lineCap: .round)
                    )
                    .padding(5)
                    .rotationEffect(.degrees(-26))
                    .shadow(color: tint.opacity(0.45), radius: 8)
                Text(model.gameOver.peakStyleRank)
                    .font(.system(size: small ? 37 : 47, weight: .black, design: .rounded))
                    .tracking(model.gameOver.peakStyleRank.count > 1 ? -4 : -2)
                    .foregroundStyle(styleTint.gradient)
                    .shadow(color: styleTint.opacity(0.62), radius: 10)
            }
            .frame(width: small ? 82 : 104, height: small ? 82 : 104)

            Text(model.gameOver.newRecord ? "NEW RECORD" : "LINK LOST")
                .font(.system(size: 6, weight: .black, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(tint)
            Text(model.gameOver.newRecord ? "纪录刷新" : "相位崩解")
                .font(.system(size: small ? 14 : 17, weight: .black, design: .rounded))

            HStack(spacing: 5) {
                miniChip("PEAK", model.gameOver.peakStyleRank, tint: styleTint)
                miniChip("GRAZE", "\(model.gameOver.grazes)", tint: .cyan)
                miniChip("PHI", "+\(model.lastPhiReward)", tint: .mint)
            }
        }
    }

    private func details(tint: Color, small: Bool) -> some View {
        VStack(alignment: .leading, spacing: small ? 6 : 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.activeDirective.title)
                        .font(.system(size: small ? 11 : 13, weight: .black))
                        .lineLimit(1)
                    Text("\(model.activeDirective.mode.shortCode) · \(model.progression.activeFrame.code) · \(model.activeDirective.shareCode) · ×\(model.activeDirective.scoreMultiplier, specifier: "%.2f")")
                        .font(.system(size: 6, weight: .black, design: .monospaced))
                        .foregroundStyle(model.activeDirective.mode.spectacleTint)
                }
                Spacer(minLength: 4)
                Text(model.gameOver.score, format: .number)
                    .font(.system(size: small ? 23 : 30, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.58)
                    .lineLimit(1)
            }

            HStack(spacing: 5) {
                stat("W", model.gameOver.wave, tint: .cyan, small: small)
                stat("LV", model.gameOver.level, tint: .purple, small: small)
                stat("K", model.gameOver.kills, tint: .orange, small: small)
                stat("BEST", model.gameOver.highScore, tint: .yellow, small: small)
            }

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: director.isGenerating ? "ellipsis.bubble.fill" : "brain.head.profile.fill")
                    .font(.system(size: small ? 9 : 10, weight: .bold))
                    .foregroundStyle(.purple)
                Text(director.debrief ?? "战后分析正在把混乱整理成一段听起来像计划的文字。")
                    .font(.system(size: small ? 7 : 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(small ? 2 : 3)
                    .lineSpacing(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(small ? 7 : 8)
            .background(.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            HStack(spacing: 6) {
                Button {
                    model.restartGame()
                } label: {
                    Label("重新接入", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(model.gameOver.newRecord ? .yellow : .cyan)

                Button {
                    model.returnToMenu()
                } label: {
                    Label("主界面", systemImage: "house.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: small ? 18 : 21, height: small ? 18 : 21)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
            .font(.system(size: small ? 9 : 10, weight: .bold))
        }
    }

    private func stat(_ title: String, _ value: Int, tint: Color, small: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 5, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value, format: .number)
                .font(.system(size: small ? 8 : 9, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, small ? 6 : 7)
        .padding(.vertical, small ? 4 : 5)
        .glassEffect(.regular.tint(tint.opacity(0.08)), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func miniChip(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 4.5, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .glassEffect(.regular.tint(tint.opacity(0.08)), in: Capsule())
    }

    private var styleTint: Color {
        switch model.gameOver.peakStyleRank {
        case "SSS": return .pink
        case "SS": return .purple
        case "S": return .yellow
        case "A": return .orange
        case "B": return .mint
        case "C": return .cyan
        default: return .white
        }
    }

    private var shareText: String {
        "《零点相位》\(model.progression.activeFrame.code) \(model.activeDirective.mode.title)：\(model.gameOver.score) 分，第 \(model.gameOver.wave) 波，击杀 \(model.gameOver.kills)，风格峰值 \(model.gameOver.peakStyleRank)，擦弹 \(model.gameOver.grazes)，获得 \(model.lastPhiReward) Φ。裂隙代码 \(model.activeDirective.shareCode)。"
    }
}
