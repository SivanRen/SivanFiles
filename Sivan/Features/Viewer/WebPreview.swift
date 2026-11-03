import SwiftUI
import WebKit

// MARK: - 网页视图

struct WebViewRepresentable: UIViewRepresentable {

    let url: URL
    /// 长按页面时回调（用来弹「查看源码」）
    var onLongPress: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onLongPress: onLongPress)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.allowsBackForwardNavigationGestures = true

        // 长按页面 → 查看源码。与 WebKit 自己的手势并存，不影响正常的滚动与点按。
        let press = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        press.minimumPressDuration = 0.7
        press.numberOfTouchesRequired = 1
        press.cancelsTouchesInView = false
        press.delegate = context.coordinator
        webView.addGestureRecognizer(press)

        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onLongPress = onLongPress
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        var onLongPress: () -> Void

        init(onLongPress: @escaping () -> Void) {
            self.onLongPress = onLongPress
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            onLongPress()
        }

        /// 允许和 WebKit 内部手势同时识别，否则长按会把页面手势全部吃掉
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

// MARK: - 网页 / SVG 预览
//
// 页面满屏显示，顶部不再放「网页 / 源码」切换键（那样会挤掉一截预览高度）。
// 长按页面 → 菜单里选「查看源码」；看源码时长按或点右下角小胶囊回到网页。

struct WebPage: View {

    let url: URL
    /// 源码视图的顶部留白，避开悬浮的返回 / 省略号按钮
    var topInset: CGFloat = 104

    @State private var showSource = false
    @State private var showMenu = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Theme.bg.ignoresSafeArea()

            if showSource {
                CodePage(url: url, topInset: topInset)
            } else {
                WebViewRepresentable(url: url) {
                    showMenu = true
                }
            }

            if showSource {
                sourceChip
                    .transition(.opacity)
            }
        }
        .confirmationDialog(titleText, isPresented: $showMenu, titleVisibility: .hidden) {
            if showSource {
                Button("显示网页") { switchTo(false) }
            } else {
                Button("查看源码") { switchTo(true) }
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var titleText: String {
        showSource ? "源码" : "网页"
    }

    private func switchTo(_ source: Bool) {
        withAnimation(.easeInOut(duration: 0.18)) {
            showSource = source
        }
    }

    // 源码模式下唯一的返回入口：浮在右下角，不占预览高度
    private var sourceChip: some View {
        Button {
            switchTo(false)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "globe")
                    .font(.system(size: 10, weight: .semibold))
                Text("网页")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .padding(.trailing, 16)
        .padding(.bottom, 24)
    }
}
