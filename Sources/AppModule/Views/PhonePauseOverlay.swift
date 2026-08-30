import SwiftUI

struct PhonePauseOverlay: View {
    @ObservedObject var model: GameViewModel

    var body: some View {
        GeometryReader { proxy in
            let layout = proxy.phaseZeroLayout

            ZStack {
                Color.black.opacity(0.50)
                    .ignoresSafeArea()

                GlassPanel(
                    tint: .cyan,
                    cornerRadius: layout.isSmallPhone ? 18 : 22,
                    padding: layout.isSmallPhone ? 11 : 14
                ) {
                    HStack(spacing: layout.isSmallPhone ? 11 : 16) {
                        identity(small: layout.isSmallPhone)
                            .frame(width: layout.isSmallPhone ? 176 : 220)

                        VStack(spacing: layout.isSmallPhone ? 7 : 9) {
                            Button {
                                model.resumeGame()
                            } label: {
                                Label("继续同步", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.cyan)

                            HStack(spacing: 7) {
                                Button {
                                    model.showSettings = true
                                } label: {
                                    Label("设置", systemImage: "slider.horizontal.3")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.glass)

                                Button(role: .destructive) {
                                    model.returnToMenu()
                                } label: {
                                    Label("主界面", systemImage: "house.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.glass)
                            }
                        }
                        .font(.system(size: layout.isSmallPhone ? 10 : 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: layout.isSmallPhone ? 560 : 650)
                .padding(.leading, layout.leadingInset)
                .padding(.trailing, layout.trailingInset)
                .padding(.top, layout.topInset)
                .padding(.bottom, layout.bottomInset)
            }
        }
    }

    private func identity(small: Bool) -> some View {
        HStack(spacing: small ? 9 : 12) {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.08))
                    .glassEffect(.regular.tint(.cyan.opacity(0.15)), in: Circle())
                Image(systemName: "pause.fill")
                    .font(.system(size: small ? 18 : 22, weight: .black))
                    .foregroundStyle(.cyan)
            }
            .frame(width: small ? 45 : 54, height: small ? 45 : 54)

            VStack(alignment: .leading, spacing: 2) {
                Text("SIGNAL SUSPENDED")
                    .font(.system(size: 6, weight: .black, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(.cyan)
                Text("连接暂停")
                    .font(.system(size: small ? 16 : 19, weight: .black, design: .rounded))
                Text("敌弹已冻结。系统偶尔也会表现出基本礼貌。")
                    .font(.system(size: small ? 7.5 : 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}
