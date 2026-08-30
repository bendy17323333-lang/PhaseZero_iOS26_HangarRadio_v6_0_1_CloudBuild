import SwiftUI

struct HangarView: View {
    @ObservedObject var model: GameViewModel
    @ObservedObject private var progression: MetaProgressionStore
    @ObservedObject private var motion: MotionAimService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFrameID: CombatFrameID

    init(model: GameViewModel) {
        self.model = model
        self._progression = ObservedObject(wrappedValue: model.progression)
        self._motion = ObservedObject(wrappedValue: model.motionAim)
        self._selectedFrameID = State(initialValue: model.progression.activeFrameID)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let compact = proxy.size.height < 520 || proxy.size.width < 780
                ScrollView {
                    HStack(alignment: .top, spacing: compact ? 12 : 18) {
                        frameSelector(compact: compact)
                            .frame(width: compact ? min(250, proxy.size.width * 0.34) : min(360, proxy.size.width * 0.36))
                        traitDeck(compact: compact)
                    }
                    .padding(compact ? 12 : 20)
                }
            }
            .navigationTitle("相位机库")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 7) {
                        Image(systemName: "function")
                        Text("\(progression.points) Φ")
                            .monospacedDigit()
                    }
                    .font(.headline.weight(.black))
                    .foregroundStyle(.cyan)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .presentationSizing(.page)
    }

    private func frameSelector(compact: Bool) -> some View {
        GlassPanel(tint: selectedFrame.tint, cornerRadius: compact ? 22 : 30, padding: compact ? 12 : 18) {
            VStack(alignment: .leading, spacing: compact ? 8 : 13) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FRAME HANGAR // META LOADOUT")
                        .font(.system(size: compact ? 7 : 9, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(selectedFrame.tint)
                    Text("机型选择")
                        .font(compact ? .headline : .title3)
                        .fontWeight(.black)
                }

                FrameHologram(
                    frame: selectedFrame,
                    unlocked: progression.isUnlocked(selectedFrame.id),
                    tiltX: model.settings.interfaceParallaxEnabled ? motion.interfaceTiltX : 0,
                    tiltY: model.settings.interfaceParallaxEnabled ? motion.interfaceTiltY : 0,
                    compact: compact
                )
                .frame(height: compact ? 105 : 180)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 7) {
                        ForEach(CombatFrameDefinition.all) { frame in
                            Button {
                                withAnimation(.snappy(duration: 0.28)) { selectedFrameID = frame.id }
                                model.haptics.play("selection", enabled: model.settings.hapticsEnabled)
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: frame.icon)
                                    Text(frame.code)
                                        .font(.system(size: 7, weight: .black, design: .monospaced))
                                }
                                .foregroundStyle(selectedFrameID == frame.id ? frame.tint : .white.opacity(0.64))
                                .frame(width: compact ? 45 : 54, height: compact ? 39 : 47)
                            }
                            .buttonStyle(.glass)
                            .opacity(progression.isUnlocked(frame.id) ? 1 : 0.54)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(selectedFrame.code) // \(selectedFrame.name)")
                            .font(compact ? .subheadline.weight(.black) : .headline.weight(.black))
                        Spacer()
                        if progression.activeFrameID == selectedFrame.id {
                            Text("ACTIVE")
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .foregroundStyle(.mint)
                        }
                    }
                    Text(selectedFrame.role)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(selectedFrame.tint)
                    Text(selectedFrame.summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(compact ? 3 : 4)
                }

                frameActionButton
            }
        }
    }

    private var frameActionButton: some View {
        Group {
            if !progression.isUnlocked(selectedFrame.id) {
                Button {
                    if progression.unlock(selectedFrame.id) {
                        _ = progression.equip(selectedFrame.id)
                        model.haptics.play("upgrade", enabled: model.settings.hapticsEnabled)
                    }
                } label: {
                    Label("解锁 \(selectedFrame.name) · \(selectedFrame.unlockCost) Φ", systemImage: "lock.open.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(selectedFrame.tint)
                .disabled(progression.points < selectedFrame.unlockCost)
            } else if progression.activeFrameID != selectedFrame.id {
                Button {
                    _ = progression.equip(selectedFrame.id)
                    model.haptics.play("launch", enabled: model.settings.hapticsEnabled)
                } label: {
                    Label("设为当前机型", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(selectedFrame.tint)
            } else {
                Label("当前出击机型", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.mint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.tint(.mint.opacity(0.10)), in: Capsule())
            }
        }
    }

    private func traitDeck(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("INTEGRATED TRAITS")
                        .font(.system(size: compact ? 7 : 9, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(selectedFrame.tint)
                    Text("机型固有特性")
                        .font(compact ? .headline : .title3)
                        .fontWeight(.black)
                }
                Spacer()
                Text("\(progression.points) Φ")
                    .font(compact ? .headline.monospacedDigit() : .title3.monospacedDigit())
                    .fontWeight(.black)
                    .foregroundStyle(.cyan)
            }

            ForEach(selectedFrame.traits) { trait in
                let level = progression.effectiveTraitLevel(frameID: selectedFrame.id, traitID: trait.id)
                GyroTraitCard(
                    frame: selectedFrame,
                    trait: trait,
                    level: level,
                    compact: compact,
                    tiltX: model.settings.interfaceParallaxEnabled ? motion.interfaceTiltX : 0,
                    tiltY: model.settings.interfaceParallaxEnabled ? motion.interfaceTiltY : 0
                ) {
                    if progression.upgrade(frameID: selectedFrame.id, traitID: trait.id) {
                        model.haptics.play("upgrade", enabled: model.settings.hapticsEnabled)
                    }
                }
                .disabled(!progression.canUpgrade(frameID: selectedFrame.id, traitID: trait.id))
            }

            if !progression.isUnlocked(selectedFrame.id) {
                Label("解锁机型后才能升级固有特性。被锁着的硬件拒绝接受职业培训。", systemImage: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var selectedFrame: CombatFrameDefinition {
        CombatFrameDefinition.definition(for: selectedFrameID)
    }
}

private struct FrameHologram: View {
    let frame: CombatFrameDefinition
    let unlocked: Bool
    let tiltX: Double
    let tiltY: Double
    let compact: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 18 : 25, style: .continuous)
                .fill(.black.opacity(0.12))
            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.52)
                let scale = min(size.width, size.height)
                var hull = Path()
                hull.move(to: CGPoint(x: center.x, y: center.y - scale * 0.34))
                hull.addLine(to: CGPoint(x: center.x + scale * 0.19, y: center.y - scale * 0.02))
                hull.addLine(to: CGPoint(x: center.x + scale * 0.33, y: center.y + scale * 0.20))
                hull.addLine(to: CGPoint(x: center.x + scale * 0.09, y: center.y + scale * 0.12))
                hull.addLine(to: CGPoint(x: center.x, y: center.y + scale * 0.31))
                hull.addLine(to: CGPoint(x: center.x - scale * 0.09, y: center.y + scale * 0.12))
                hull.addLine(to: CGPoint(x: center.x - scale * 0.33, y: center.y + scale * 0.20))
                hull.addLine(to: CGPoint(x: center.x - scale * 0.19, y: center.y - scale * 0.02))
                hull.closeSubpath()
                context.fill(hull, with: .color(frame.tint.opacity(unlocked ? 0.28 : 0.08)))
                context.stroke(hull, with: .color(frame.tint.opacity(unlocked ? 0.94 : 0.30)), lineWidth: compact ? 1.6 : 2.2)

                let coreRect = CGRect(x: center.x - scale * 0.07, y: center.y - scale * 0.06, width: scale * 0.14, height: scale * 0.14)
                context.fill(Path(ellipseIn: coreRect), with: .color(unlocked ? .white.opacity(0.92) : .white.opacity(0.22)))
            }
            .offset(x: CGFloat(tiltX) * 7, y: CGFloat(tiltY) * 5)

            Circle()
                .trim(from: 0.08, to: 0.80)
                .stroke(frame.tint.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [4, 5]))
                .padding(compact ? 15 : 25)
                .rotationEffect(.degrees(Double(tiltX) * 8 - 18))

            if !unlocked {
                Image(systemName: "lock.fill")
                    .font(compact ? .title3 : .title)
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .rotation3DEffect(.degrees(tiltY * -2.4), axis: (x: 1, y: 0, z: 0), perspective: 0.65)
        .rotation3DEffect(.degrees(tiltX * 2.8), axis: (x: 0, y: 1, z: 0), perspective: 0.65)
    }
}

private struct GyroTraitCard: View {
    let frame: CombatFrameDefinition
    let trait: FrameTraitDefinition
    let level: Int
    let compact: Bool
    let tiltX: Double
    let tiltY: Double
    let upgrade: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: compact ? 9 : 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.black.opacity(0.10))
                Image(systemName: trait.icon)
                    .font(compact ? .headline : .title3)
                    .foregroundStyle(frame.tint)
            }
            .frame(width: compact ? 41 : 50, height: compact ? 41 : 50)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(trait.title)
                        .font(compact ? .subheadline.weight(.black) : .headline.weight(.black))
                    Text("LV \(roman(level))")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(frame.tint)
                    Spacer()
                }
                Text(trait.detail(at: level))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(compact ? 2 : 3)
            }

            Button(action: upgrade) {
                VStack(spacing: 1) {
                    Image(systemName: level >= 4 ? "checkmark.seal.fill" : "arrow.up.circle.fill")
                    Text(level >= 4 ? "MAX" : costText)
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                }
                .frame(width: compact ? 43 : 54, height: compact ? 36 : 44)
            }
            .buttonStyle(.glassProminent)
            .tint(frame.tint)
        }
        .padding(compact ? 10 : 13)
        .background(.black.opacity(0.09), in: RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous))
        .glassEffect(.regular.tint(frame.tint.opacity(0.10)), in: RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous))
        .overlay {
            GeometryReader { proxy in
                let x = proxy.size.width * (0.50 + CGFloat(tiltX) * 0.22)
                let y = proxy.size.height * (0.48 + CGFloat(tiltY) * 0.24)
                RadialGradient(
                    colors: [.white.opacity(0.28), frame.tint.opacity(0.10), .clear],
                    center: UnitPoint(x: min(max(x / max(proxy.size.width, 1), 0), 1), y: min(max(y / max(proxy.size.height, 1), 0), 1)),
                    startRadius: 0,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.52
                )
                .blendMode(.screen)
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous))
            }
        }
        .rotation3DEffect(.degrees(tiltY * -1.1), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
        .rotation3DEffect(.degrees(tiltX * 1.2), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
        .opacity(isEnabled ? 1 : 0.82)
    }

    private var costText: String {
        switch level {
        case 1: return "2 Φ"
        case 2: return "4 Φ"
        case 3: return "6 Φ"
        default: return "MAX"
        }
    }

    private func roman(_ value: Int) -> String {
        switch min(max(value, 1), 4) {
        case 1: return "I"
        case 2: return "II"
        case 3: return "III"
        default: return "IV"
        }
    }
}
