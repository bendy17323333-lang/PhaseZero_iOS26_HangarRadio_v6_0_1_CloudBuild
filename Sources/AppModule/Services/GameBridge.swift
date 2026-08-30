import Foundation
@preconcurrency import WebKit
import UIKit

@MainActor
final class GameBridge: NSObject, WKNavigationDelegate {
    weak var model: GameViewModel?

    private(set) var webView: WKWebView?
    private var handlerProxy: WeakScriptMessageHandler?
    private var queuedPackets: [[String: Any]] = []
    private var pageReady = false

    func makeWebView() -> WKWebView {
        if let webView { return webView }

        print("[PhaseZero] Creating WKWebView")
        let controller = WKUserContentController()
        controller.addUserScript(
            WKUserScript(
                source: "window.__PHASE_ZERO_NATIVE__ = true;",
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        controller.addUserScript(
            WKUserScript(
                source: """
                (() => {
                  const send = (kind, value) => {
                    try { window.webkit?.messageHandlers?.phaseZero?.postMessage({type: kind, payload: {message: String(value)}}); } catch (_) {}
                  };
                  window.addEventListener('error', event => send('bridgeError', event.message || 'JavaScript error'));
                  window.addEventListener('unhandledrejection', event => send('bridgeError', event.reason || 'Unhandled promise rejection'));
                })();
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        let proxy = WeakScriptMessageHandler(delegate: self)
        handlerProxy = proxy
        controller.add(proxy, name: "phaseZero")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .default()

        let web = WKWebView(frame: .zero, configuration: configuration)
        web.navigationDelegate = self
        let gameBackground = UIColor(red: 0.006, green: 0.014, blue: 0.040, alpha: 1)
        web.isOpaque = true
        web.backgroundColor = gameBackground
        web.scrollView.backgroundColor = gameBackground
        web.underPageBackgroundColor = gameBackground
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.allowsBackForwardNavigationGestures = false
        #if DEBUG
        if #available(iOS 16.4, *) {
            web.isInspectable = true
        }
        #endif
        webView = web
        loadGame()
        return web
    }

    func loadGame() {
        guard let webView else { return }
        guard let url = locateBundledGameURL() else {
            print("[PhaseZero] Missing bundled HTML resource")
            model?.bridgeFailed("找不到内置游戏资源 phase_zero_native.html")
            return
        }
        print("[PhaseZero] Loading HTML:", url.lastPathComponent)
        pageReady = false
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }


    /// Works in both Swift Playground/SwiftPM builds and the XcodeGen IPA build.
    /// Xcode-generated projects do not synthesize `Bundle.module`, so locate the
    /// processed HTML resource without referencing that package-only accessor.
    private func locateBundledGameURL() -> URL? {
        let name = "phase_zero_native"
        let fileName = "\(name).html"

        // Swift Package builds synthesize Bundle.module. Generated Xcode
        // projects do not, so keep this reference behind SWIFT_PACKAGE.
        #if SWIFT_PACKAGE
        if let packageURL = Bundle.module.url(
            forResource: name,
            withExtension: "html",
            subdirectory: "Web"
        ) ?? Bundle.module.url(forResource: name, withExtension: "html") {
            return packageURL
        }
        #endif

        var visited = Set<String>()
        let candidates = [Bundle.main] + Bundle.allBundles + Bundle.allFrameworks

        for bundle in candidates {
            guard visited.insert(bundle.bundlePath).inserted else { continue }
            if let direct = bundle.url(forResource: name, withExtension: "html", subdirectory: "Web")
                ?? bundle.url(forResource: name, withExtension: "html") {
                return direct
            }
        }

        let roots = [Bundle.main.resourceURL, Bundle.main.bundleURL].compactMap { $0 }
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let candidate as URL in enumerator where candidate.lastPathComponent == fileName {
                return candidate
            }
        }
        return nil
    }

    func send(command: String, payload: [String: Any] = [:]) {
        let packet: [String: Any] = ["command": command, "payload": payload]
        guard pageReady, let webView else {
            queuedPackets.append(packet)
            return
        }
        evaluate(packet, on: webView)
    }

    private func evaluate(_ packet: [String: Any], on webView: WKWebView) {
        guard JSONSerialization.isValidJSONObject(packet),
              let data = try? JSONSerialization.data(withJSONObject: packet),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.PhaseZeroNative?.receive(\(json));") { [weak self] _, error in
            if let error {
                self?.model?.bridgeWarning(error.localizedDescription)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[PhaseZero] WKWebView navigation finished")
        pageReady = true
        let packets = queuedPackets
        queuedPackets.removeAll(keepingCapacity: true)
        packets.forEach { evaluate($0, on: webView) }
        send(command: "requestSnapshot")
    }


    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[PhaseZero] WKWebView navigation failed:", error.localizedDescription)
        model?.bridgeFailed("游戏页面加载失败：\(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[PhaseZero] WKWebView provisional navigation failed:", error.localizedDescription)
        model?.bridgeFailed("游戏页面无法打开：\(error.localizedDescription)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        pageReady = false
        model?.webProcessTerminated()
        webView.reload()
    }
}

@MainActor
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: GameBridge?

    init(delegate: GameBridge) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "phaseZero",
              JSONSerialization.isValidJSONObject(message.body),
              let data = try? JSONSerialization.data(withJSONObject: message.body),
              let object = try? JSONSerialization.jsonObject(with: data),
              let body = object as? [String: Any]
        else { return }
        delegate?.model?.handleBridgeMessage(body)
    }
}
