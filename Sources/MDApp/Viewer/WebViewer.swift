import AppKit
import SwiftUI
import WebKit

struct WebPayload: Equatable {
    enum Mode: String { case code, markdown }

    /// Identifies the content; a new value triggers a re-render.
    var id: String
    var mode: Mode
    var text: String
    var lang: String?
    var baseURL: URL?

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }

    var json: String? {
        var object: [String: Any] = ["mode": mode.rawValue, "text": text]
        if let lang { object["lang"] = lang }
        if let baseURL { object["base"] = baseURL.absoluteString }
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

enum WebResources {
    /// SwiftPM's `Bundle.module` looks next to the .app rather than inside Contents/Resources,
    /// so check the app bundle's resources first.
    static let directory: URL = {
        let bundleName = "MDApp_MDApp.bundle"
        if let resources = Bundle.main.resourceURL,
           let bundle = Bundle(url: resources.appendingPathComponent(bundleName)),
           let web = bundle.url(forResource: "Web", withExtension: nil) {
            return web
        }
        return Bundle.module.url(forResource: "Web", withExtension: nil)!
    }()
}

struct WebViewer: NSViewRepresentable {
    let payload: WebPayload
    var onOpenFile: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        context.coordinator.onOpenFile = onOpenFile
        let page = WebResources.directory.appendingPathComponent("viewer.html")
        webView.loadFileURL(page, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        context.coordinator.render(payload)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onOpenFile = onOpenFile
        context.coordinator.render(payload)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var onOpenFile: ((URL) -> Void)?
        private var isReady = false
        private var pending: WebPayload?
        private var rendered: WebPayload?

        func render(_ payload: WebPayload) {
            guard payload != rendered else { return }
            guard isReady, let webView, let json = payload.json else {
                pending = payload
                return
            }
            rendered = payload
            pending = nil
            webView.evaluateJavaScript("window.mdappRender(\(json))") { _, error in
                if let error { NSLog("MDApp viewer render failed: \(error)") }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isReady = true
            if let pending { render(pending) }
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            guard action.navigationType == .linkActivated, let url = action.request.url else {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
            if url.isFileURL {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.fragment = nil
                if let fileURL = components?.url, FileManager.default.fileExists(atPath: fileURL.path) {
                    onOpenFile?(fileURL)
                }
            } else {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
