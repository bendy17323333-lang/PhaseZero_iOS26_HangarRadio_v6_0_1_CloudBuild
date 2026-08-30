import SwiftUI

struct PauseOverlay: View {
    @ObservedObject var model: GameViewModel

    var body: some View {
        GeometryReader { proxy in
            let layout = proxy.phaseZeroLayout

            if layout.isPhoneLandscape {
                PhonePauseOverlay(model: model)
            } else {
                ZStack {
                    Color.black.opacity(0.42).ignoresSafeArea()

                    GlassPanel(tint: .cyan, cornerRadius: 30, padding: 24) {
                        VStack(spacing: 18) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 30, weight: .black))
                                .foregroundStyle(.cyan)
                            Text("连接暂停")
                                .font(.title.bold())
                            Text("所有试图杀你的东西都暂时被冻结。系统难得表现出了基本礼貌。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 12) {
                                Button {
                                    model.resumeGame()
                                } label: {
                                    Label("继续", systemImage: "play.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.glassProminent)
                                .tint(.cyan)

                                Button {
                                    model.showSettings = true
                                } label: {
                                    Label("设置", systemImage: "slider.horizontal.3")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.glass)
                            }

                            Button(role: .destructive) {
                                model.returnToMenu()
                            } label: {
                                Label("返回主界面", systemImage: "rectangle.portrait.and.arrow.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glass)

                            if model.controllerConnected {
                                Text("手柄：A / Menu 继续，B 返回")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .frame(maxWidth: 470)
                    .padding(24)
                }
            }
        }
    }
}
