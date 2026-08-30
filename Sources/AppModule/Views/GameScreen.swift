import SwiftUI

struct GameScreen: View {
    @ObservedObject var model: GameViewModel
    @ObservedObject private var settings: SettingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: GameViewModel) {
        self.model = model
        self._settings = ObservedObject(wrappedValue: model.settings)
    }

    var body: some View {
        ZStack {
            GameplayAtmosphereView(model: model)
                .zIndex(1)

            if model.state == .playing && (!model.controllerConnected || model.settings.showTouchWithController) {
                TouchControlsView(model: model)
                    .transition(.opacity)
                    .zIndex(4)
            }

            // Keep pause above the full-screen joystick zones.
            GameHUDView(model: model)
                .zIndex(5)
            SystemGameOverlay(model: model)
                .zIndex(6)

            if let event = model.spectacleEvent {
                NativeCombatFXView(
                    event: event,
                    strength: settings.spectaclePreset.nativeFXScale
                )
                .id(event.id)
                .zIndex(12)
            }

            if let toast = model.toast {
                ToastView(message: toast, tint: model.hud.phaseColor)
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
                    .zIndex(20)
            }

            switch model.state {
            case .paused:
                PauseOverlay(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(40)
            case .upgrade:
                UpgradeOverlay(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(40)
            case .over:
                GameOverOverlay(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(40)
            default:
                EmptyView()
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.30), value: model.state)
    }
}

private struct GameplayAtmosphereView: View {
    @ObservedObject var model: GameViewModel
    @ObservedObject private var settings: SettingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: GameViewModel) {
        self.model = model
        self._settings = ObservedObject(wrappedValue: model.settings)
    }

    var body: some View {
        Group {
            if reduceMotion || !model.hud.overdriveActive {
                atmosphere(time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    atmosphere(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func atmosphere(time: TimeInterval) -> some View {
        let tint = model.hud.phaseColor
        let scale = settings.spectaclePreset.nativeFXScale
        let overdrivePulse = model.hud.overdriveActive ? 0.06 + (sin(time * 5.2) + 1) * 0.035 : 0.018

        return ZStack {
            Rectangle()
                .strokeBorder(tint.opacity(overdrivePulse * scale), lineWidth: model.hud.overdriveActive ? 8 : 2)
                .blur(radius: model.hud.overdriveActive ? 6 : 1)
                .padding(model.hud.overdriveActive ? 3 : 1)

            LinearGradient(
                colors: [tint.opacity(overdrivePulse * 0.70), .clear, tint.opacity(overdrivePulse * 0.38)],
                startPoint: .top,
                endPoint: .bottom
            )

            if model.hud.overdriveActive {
                RadialGradient(
                    colors: [.clear, tint.opacity(0.08 * scale)],
                    center: .center,
                    startRadius: 80,
                    endRadius: 760
                )
                .blendMode(.screen)
            }
        }
        .ignoresSafeArea()
    }
}

private struct ToastView: View {
    let message: ToastMessage
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
                .shadow(color: tint, radius: 6)
            Text(message.text)
                .lineLimit(1)
        }
        .font(.caption.weight(.black))
        .tracking(1.2)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .glassEffect(.regular.tint(tint.opacity(0.12)), in: Capsule())
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 78)
        .allowsHitTesting(false)
    }
}
