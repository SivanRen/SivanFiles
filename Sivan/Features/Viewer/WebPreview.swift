import SwiftUI
import WebKit

struct WebViewRepresentable: UIViewRepresentable {

    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.allowsBackForwardNavigationGestures = true
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// HTML / SVG 预览，可切换源码
struct WebPage: View {

    let url: URL
    var topInset: CGFloat = 104

    @State private var showSource = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("模式", selection: $showSource) {
                Text("网页").tag(false)
                Text("源码").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
            .padding(.top, topInset)
            .padding(.bottom, 8)

            if showSource {
                CodePage(url: url, topInset: 8)
            } else {
                WebViewRepresentable(url: url)
            }
        }
        .background(Theme.bg)
    }
}
