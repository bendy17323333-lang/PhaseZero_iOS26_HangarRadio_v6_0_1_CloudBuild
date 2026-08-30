import SwiftUI
import WebKit

struct PhaseZeroWebView: UIViewRepresentable {
    let bridge: GameBridge

    func makeUIView(context: Context) -> WKWebView {
        bridge.makeWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
