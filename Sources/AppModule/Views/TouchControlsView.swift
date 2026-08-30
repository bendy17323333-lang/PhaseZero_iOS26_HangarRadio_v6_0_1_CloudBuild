import SwiftUI

struct TouchControlsView: View {
    @ObservedObject var model: GameViewModel

    var body: some View {
        GeometryReader { proxy in
            let layout = proxy.phaseZeroLayout
            let radius: CGFloat = layout.isPhoneLandscape ? (layout.isSmallPhone ? 36 : 39) : 46
            let knob: CGFloat = layout.isPhoneLandscape ? 29 : 34

            ZStack {
                HStack(spacing: 0) {
                    FloatingJoystickZone(
                        tint: .cyan,
                        radius: radius,
                        knobSize: knob
                    ) { x, y, magnitude, active in
                        model.move(x: x, y: y, magnitude: magnitude, active: active)
                    }

                    FloatingJoystickZone(
                        tint: model.hud.phaseColor,
                        radius: radius,
                        knobSize: knob
                    ) { x, y, magnitude, active in
                        model.aim(x: x, y: y, magnitude: magnitude, active: active)
                    }
                }
                .padding(.leading, layout.isPhoneLandscape ? layout.safeArea.leading : 0)
                .padding(.trailing, layout.isPhoneLandscape ? layout.safeArea.trailing : 0)

                actionButtons(layout: layout)
            }
        }
        .onDisappear {
            model.move(x: 0, y: 0, magnitude: 0, active: false)
            model.aim(x: 0, y: 0, magnitude: 0, active: false)
        }
    }

    private func actionButtons(layout: PhaseZeroLayoutMetrics) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

                GlassEffectContainer(spacing: layout.isPhoneLandscape ? 7 : 11) {
                    HStack(spacing: layout.isPhoneLandscape ? 7 : 11) {
                        Button {
                            model.shiftPhase()
                        } label: {
                            if layout.isPhoneLandscape {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: layout.isSmallPhone ? 13 : 14, weight: .black))
                                    .frame(width: layout.isSmallPhone ? 38 : 42, height: layout.isSmallPhone ? 38 : 42)
                            } else {
                                VStack(spacing: 2) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.headline)
                                    Text("相位")
                                        .font(.system(size: 8, weight: .black))
                                }
                                .frame(width: 48, height: 48)
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.circle)
                        .tint(model.hud.phaseColor)
                        .accessibilityLabel("切换相位")

                        Button {
                            model.dash()
                        } label: {
                            if layout.isPhoneLandscape {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: layout.isSmallPhone ? 11 : 12, weight: .black))
                                    .frame(width: layout.isSmallPhone ? 34 : 38, height: layout.isSmallPhone ? 34 : 38)
                            } else {
                                VStack(spacing: 2) {
                                    Image(systemName: "forward.end.fill")
                                        .font(.subheadline)
                                    Text("冲刺")
                                        .font(.system(size: 8, weight: .black))
                                }
                                .frame(width: 42, height: 42)
                            }
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel("冲刺")
                    }
                }
                .opacity(layout.isPhoneLandscape ? min(model.settings.touchOpacity, 0.72) : model.settings.touchOpacity)
            }
            .padding(.trailing, layout.trailingInset)
            .padding(.bottom, layout.isPhoneLandscape ? layout.bottomInset + 1 : 18)
        }
    }
}

private struct FloatingJoystickZone: View {
    let tint: Color
    let radius: CGFloat
    let knobSize: CGFloat
    let onChange: (_ x: Double, _ y: Double, _ magnitude: Double, _ active: Bool) -> Void

    @State private var origin: CGPoint?
    @State private var knobOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                let center = origin ?? bounded(value.startLocation, in: proxy.size)
                                if origin == nil { origin = center }

                                let raw = CGSize(
                                    width: value.location.x - center.x,
                                    height: value.location.y - center.y
                                )
                                let length = hypot(raw.width, raw.height)
                                let scale = length > radius ? radius / length : 1
                                let offset = CGSize(width: raw.width * scale, height: raw.height * scale)
                                knobOffset = offset

                                let magnitude = min(length / radius, 1)
                                onChange(
                                    Double(offset.width / radius),
                                    Double(offset.height / radius),
                                    Double(magnitude),
                                    magnitude > 0.06
                                )
                            }
                            .onEnded { _ in
                                withAnimation(.snappy(duration: 0.15)) {
                                    origin = nil
                                    knobOffset = .zero
                                }
                                onChange(0, 0, 0, false)
                            }
                    )

                if let origin {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.055))
                            .glassEffect(.regular.tint(tint.opacity(0.10)), in: Circle())
                            .frame(width: radius * 2, height: radius * 2)
                        Circle()
                            .fill(tint.opacity(0.14))
                            .glassEffect(.regular.tint(tint.opacity(0.18)).interactive(), in: Circle())
                            .frame(width: knobSize, height: knobSize)
                            .offset(knobOffset)
                            .shadow(color: tint.opacity(0.48), radius: 8)
                    }
                    .position(origin)
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.74).combined(with: .opacity))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func bounded(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, radius + 6), max(radius + 6, size.width - radius - 6)),
            y: min(max(point.y, radius + 6), max(radius + 6, size.height - radius - 6))
        )
    }
}
