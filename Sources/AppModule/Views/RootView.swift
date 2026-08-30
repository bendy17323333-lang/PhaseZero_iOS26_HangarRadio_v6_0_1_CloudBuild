import SwiftUI

struct RootView: View {
    @ObservedObject var model: GameViewModel
    @State private var engineMounted = false

    var body: some View {
        ZStack {
            // Never expose an uninitialised compositor surface. This base remains
            // fully opaque even while WebKit and Liquid Glass rebuild their layers.
            Color(red: 0.006, green: 0.014, blue: 0.040)
                .ignoresSafeArea()

            // The expensive animated backdrop is useful on loading/menu screens,
            // but contributes nothing during combat except GPU work and bad manners.
            if model.state == .loading || model.state == .menu {
                NativeBackdrop(model: model)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
            }

            if engineMounted {
                PhaseZeroWebView(bridge: model.bridge)
                    .allowsHitTesting(false)
                    .opacity(webSurfaceVisible ? 1 : 0)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
            }

            switch model.state {
            case .loading:
                LoadingView(model: model)
            case .menu:
                MainMenuView(model: model)
            case .playing, .ending, .paused, .upgrade, .over:
                GameScreen(model: model)
            case .error:
                ErrorView(model: model)
            }

            if model.isLaunching {
                LaunchSequenceOverlay(model: model)
                    .zIndex(200)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .sheet(isPresented: $model.showHangar) {
            HangarView(model: model)
        }
        .sheet(isPresented: $model.showPhaseRadio) {
            PhaseRadioView(model: model)
        }
        .sheet(isPresented: $model.showSettings) {
            SettingsView(model: model)
        }
        .sheet(isPresented: $model.showSystemLab) {
            SystemLabView(model: model)
        }
        .task {
            print("[PhaseZero] Hangar Radio 6.0.6 root appeared")
            await Task.yield()
            try? await Task.sleep(nanoseconds: 180_000_000)
            engineMounted = true
            model.beginEngineBootWatchdog()
            print("[PhaseZero] Hangar Radio 6.0.6 web engine mounted")
        }
    }

    private var webSurfaceVisible: Bool {
        guard model.webReady else { return false }
        switch model.state {
        case .playing, .ending, .paused, .upgrade, .over:
            return true
        case .loading, .menu, .error:
            return false
        }
    }
}

private struct LoadingView: View {
    @ObservedObject var model: GameViewModel
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 12) {
            AdaptivePhaseReactorView(model: model, size: 190, showsReadout: false)
                .scaleEffect(appeared ? 1 : 0.82)
                .opacity(appeared ? 1 : 0)

            Text("正在接入相位核心")
                .font(.title3.weight(.black))
            Text("机库与相位电台正在等待 WebKit 完成启动。")
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView()
                .controlSize(.large)
                .tint(.cyan)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 24)
        .glassEffect(.regular.tint(.cyan.opacity(0.12)), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .onAppear {
            withAnimation(.smooth(duration: 0.48)) { appeared = true }
        }
    }
}

private struct ErrorView: View {
    @ObservedObject var model: GameViewModel

    var body: some View {
        GlassPanel(tint: .red) {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text("相位核心未能启动")
                    .font(.title2.bold())
                Text(model.errorMessage ?? "未知错误")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("重新加载") { model.bridge.loadGame() }
                    .buttonStyle(.glassProminent)
                    .tint(.red)
            }
        }
        .frame(maxWidth: 520)
        .padding(28)
    }
}
