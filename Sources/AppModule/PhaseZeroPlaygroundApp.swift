import SwiftUI
import UIKit

@main
struct PhaseZeroPlaygroundApp: App {
    @StateObject private var model = GameViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .background(Color(red: 0.012, green: 0.027, blue: 0.067))
                .task {
                    print("[PhaseZero] Root task entered")
                    await Task.yield()
                    model.startServices()
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    requestLandscape()
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        model.appBecameActive()
                        requestLandscape()
                    case .inactive, .background:
                        model.appWillResignActive()
                    @unknown default:
                        break
                    }
                }
        }
        .commands {
            CommandMenu("裂隙") {
                Button("开始自由裂隙") {
                    model.startGame(mode: .free)
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("开始每日裂隙") {
                    model.startGame(mode: .daily)
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("生成导演裂隙") {
                    model.selectRunMode(.director)
                    model.refreshDirectorContract()
                }
                .keyboardShortcut("3", modifiers: [.command])

                Divider()

                Button(model.state == .paused ? "继续战斗" : "暂停战斗") {
                    if model.state == .paused {
                        model.resumeGame()
                    } else {
                        model.pauseGame()
                    }
                }
                .keyboardShortcut("p", modifiers: [.command])
                .disabled(model.state != .playing && model.state != .paused)

                Button("切换相位") { model.shiftPhase() }
                    .keyboardShortcut("e", modifiers: [.command])
                    .disabled(model.state != .playing)

                Button("紧急冲刺") { model.dash() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                    .disabled(model.state != .playing)

                Divider()

                Button("切换陀螺精瞄") {
                    model.settings.motionAimEnabled.toggle()
                    model.pushSettings()
                }
                .keyboardShortcut("g", modifiers: [.command])

                Button("设置") { model.showSettings = true }
                    .keyboardShortcut(",", modifiers: [.command])

                Button("系统实验室") { model.showSystemLab = true }
                    .keyboardShortcut("l", modifiers: [.command, .option])
            }
        }
    }

    @MainActor
    private func requestLandscape() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
        scene.requestGeometryUpdate(preferences) { error in
            #if DEBUG
            print("Landscape request:", error.localizedDescription)
            #endif
        }
    }
}
