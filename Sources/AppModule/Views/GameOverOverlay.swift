import SwiftUI

struct GameOverOverlay: View {
    @ObservedObject var model: GameViewModel
    @ObservedObject private var director: AIDirector
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: GameViewModel) {
        self.model = model
        self._director = ObservedObject(wrappedValue: model.aiDirector)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = proxy.phaseZeroLayout

            if layout.isPhoneLandscape {
                PhoneGameOverOverlay(model: model)
            } else {
                let compact = proxy.size.width < 850 || proxy.size.height < 500

                ZStack {
                    ResultSpectrumField(
                        success: model.gameOver.newRecord,
                        tint: resultTint,
                        reduceMotion: reduceMotion
                    )
                    .ignoresSafeArea()

                    Color.black.opacity(0.44)
                        .ignoresSafeArea()

                    GlassPanel(tint: resultTint, cornerRadius: compact ? 25 : 34, padding: compact ? 15 : 22) {
                        Group {
                            if compact {
                                HStack(spacing: 15) {
                                    resultIdentity(compact: true)
                                        .frame(width: min(230, proxy.size.width * 0.30))
                                    resultDetails(compact: true)
                                }
                            } else {
                                HStack(spacing: 24) {
                                    resultIdentity(compact: false)
                                        .frame(width: 240)
                                    resultDetails(compact: false)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: compact ? 820 : 900)
                    .padding(compact ? 12 : 24)
                }
            }
        }
    }

    private func resultIdentity(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 13) {
            OutcomeReactor(
                rank: model.gameOver.peakStyleRank,
                tint: resultTint,
                record: model.gameOver.newRecord,
                compact: compact
            )

            VStack(spacing: 2) {
                Text(model.gameOver.newRecord ? "NEW LOCAL RECORD" : "CONNECTION LOST")
                    .font(.system(size: compact ? 7 : 9, weight: .black, design: .monospaced))
                    .tracking(compact ? 1.5 : 2.4)
                    .foregroundStyle(resultTint)
                Text(model.gameOver.newRecord ? "纪录刷新" : "相位崩解")
                    .font(compact ? .title3 : .title)
                    .fontWeight(.black)
            }

            HStack(spacing: 8) {
                resultChip("PEAK", value: model.gameOver.peakStyleRank, tint: styleTint)
                resultChip("GRAZE", value: "\(model.gameOver.grazes)", tint: .cyan)
                resultChip("PHI", value: "+\(model.lastPhiReward)", tint: .mint)
            }
        }
    }

    private func resultDetails(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.activeDirective.title)
                        .font(compact ? .headline : .title3)
                        .fontWeight(.black)
                        .lineLimit(1)
                    Text("\(model.activeDirective.mode.shortCode) // \(model.progression.activeFrame.code) // \(model.activeDirective.shareCode) // ×\(model.activeDirective.scoreMultiplier, specifier: "%.2f")")
                        .font(.system(size: compact ? 7 : 8, weight: .black, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(model.activeDirective.mode.spectacleTint)
                }
                Spacer()
                Text(model.gameOver.score, format: .number)
                    .font(.system(size: compact ? 27 : 42, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            HStack(spacing: compact ? 7 : 10) {
                stat("WAVE", model.gameOver.wave, tint: .cyan, compact: compact)
                stat("LEVEL", model.gameOver.level, tint: .purple, compact: compact)
                stat("KILLS", model.gameOver.kills, tint: .orange, compact: compact)
                stat("BEST", model.gameOver.highScore, tint: .yellow, compact: compact)
            }

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: director.isGenerating ? "ellipsis.bubble.fill" : "brain.head.profile.fill")
                    .foregroundStyle(.purple)
                    .symbolEffect(.pulse, isActive: director.isGenerating)
                Text(director.debrief ?? "战后分析正在把混乱整理成一段听起来像计划的文字。")
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.white.opacity(0.76))
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(compact ? 10 : 12)
            .background(.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(.purple.opacity(0.16), lineWidth: 1)
            }

            HStack(spacing: compact ? 7 : 10) {
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
                        .frame(width: compact ? 23 : 27, height: compact ? 23 : 27)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
        }
    }

    private var shareText: String {
        "《零点相位》\(model.progression.activeFrame.code) \(model.activeDirective.mode.title)：\(model.gameOver.score) 分，第 \(model.gameOver.wave) 波，击杀 \(model.gameOver.kills)，风格峰值 \(model.gameOver.peakStyleRank)，擦弹 \(model.gameOver.grazes)，获得 \(model.lastPhiReward) Φ。裂隙代码 \(model.activeDirective.shareCode)。"
    }

    private var resultTint: Color {
        model.gameOver.newRecord ? .yellow : .red
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

    private func stat(_ title: String, _ value: Int, tint: Color, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: compact ? 6 : 7, weight: .black, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(.secondary)
            Text(value, format: .number)
                .font(compact ? .caption.weight(.black) : .title3.weight(.black))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 8 : 11)
        .padding(.vertical, compact ? 7 : 10)
        .glassEffect(.regular.tint(tint.opacity(0.10)), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func resultChip(_ title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 6, weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.black))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .glassEffect(.regular.tint(tint.opacity(0.10)), in: Capsule())
    }
}

private struct OutcomeReactor: View {
    let rank: String
    let tint: Color
    let record: Bool
    let compact: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                reactor(time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { timeline in
                    reactor(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
    }

    private func reactor(time: TimeInterval) -> some View {
        let side: CGFloat = compact ? 116 : 170
        return ZStack {
            Circle()
                .fill(.black.opacity(0.06))
                .glassEffect(.regular.tint(tint.opacity(0.14)), in: Circle())

            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .trim(from: CGFloat(index) * 0.04, to: 0.30 + CGFloat(index) * 0.12)
                    .stroke(
                        index.isMultiple(of: 2) ? tint.opacity(0.72) : styleColor.opacity(0.62),
                        style: StrokeStyle(lineWidth: index == 0 ? 3 : 1, lineCap: .round, dash: index > 2 ? [4, 8] : [])
                    )
                    .padding(CGFloat(index) * (compact ? 7 : 10) + 5)
                    .rotationEffect(.degrees(time * (index.isMultiple(of: 2) ? 22 : -17) + Double(index) * 44))
                    .shadow(color: tint.opacity(0.35), radius: index == 0 ? 9 : 3)
            }

            VStack(spacing: -5) {
                Text(rank)
                    .font(.system(size: compact ? 47 : 70, weight: .black, design: .rounded))
                    .tracking(compact ? -4 : -6)
                    .foregroundStyle(styleColor.gradient)
                    .shadow(color: styleColor.opacity(0.78), radius: compact ? 13 : 22)
                Text(record ? "RECORD" : "PEAK STYLE")
                    .font(.system(size: compact ? 6 : 8, weight: .black, design: .monospaced))
                    .tracking(compact ? 1.2 : 2.0)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: side, height: side)
    }

    private var styleColor: Color {
        switch rank {
        case "SSS": return .pink
        case "SS": return .purple
        case "S": return .yellow
        case "A": return .orange
        case "B": return .mint
        case "C": return .cyan
        default: return .white
        }
    }
}

private struct ResultSpectrumField: View {
    let success: Bool
    let tint: Color
    let reduceMotion: Bool

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
    }

    private func field(time: TimeInterval) -> some View {
        GeometryReader { proxy in
            ZStack {
                RadialGradient(
                    colors: [tint.opacity(success ? 0.22 : 0.15), .clear],
                    center: UnitPoint(x: 0.5 + CGFloat(sin(time * 0.19)) * 0.07, y: 0.5 + CGFloat(cos(time * 0.16)) * 0.06),
                    startRadius: 0,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.78
                )
                .blendMode(.plusLighter)

                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 38 + CGFloat(index) * 5, style: .continuous)
                        .trim(from: CGFloat(index) * 0.035, to: 0.25 + CGFloat(index) * 0.10)
                        .stroke(
                            tint.opacity(0.08 + Double(index.isMultiple(of: 2) ? 1 : 0) * 0.035),
                            style: StrokeStyle(lineWidth: index == 0 ? 2 : 0.7, lineCap: .round, dash: index > 3 ? [6, 14] : [])
                        )
                        .padding(14 + CGFloat(index) * 25)
                        .rotationEffect(.degrees(time * (index.isMultiple(of: 2) ? 3.8 : -2.6) + Double(index) * 15))
                }
            }
        }
    }
}
