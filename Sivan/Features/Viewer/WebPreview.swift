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
        // 先垫一层主题背景色，网页背景探测出来之前也不会露出黑边
        webView.backgroundColor = Theme.bgUIColor
        webView.scrollView.backgroundColor = .clear
        webView.allowsBackForwardNavigationGestures = true

        // 网页铺满整屏：关掉安全区内边距，白底等内容直接延伸到状态栏 / 底栏之下
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        webView.navigationDelegate = context.coordinator

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

    final class Coordinator: NSObject, UIGestureRecognizerDelegate, WKNavigationDelegate {

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

        // MARK: 探测网页背景色，把安全区露出来的「黑边」换成网页自己的底色

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let script = """
            (function () {
                var root = document.compatMode === 'CSS1Compat'
                    ? document.documentElement : document.body;
                return getComputedStyle(root).backgroundColor || '';
            })();
            """
            webView.evaluateJavaScript(script) { [weak webView] result, _ in
                guard let webView, let raw = result as? String else { return }
                Self.applyBackground(raw, to: webView)
            }
        }

        /// 解析 "rgb(255,255,255)" / "rgba(...,0.3)"，透明度太低就不覆盖，保留主题底色
        private static func applyBackground(_ raw: String, to webView: WKWebView) {
            let pattern = #"(\d+(?:\.\d+)?)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let range = NSRange(raw.startIndex..., in: raw)
            let values = regex.matches(in: raw, range: range)
                .prefix(4)
                .compactMap { match -> Double? in
                    guard let r = Range(match.range, in: raw) else { return nil }
                    return Double(raw[r])
                }
            guard values.count >= 3 else { return }
            let alpha = values.count >= 4 ? CGFloat(values[3]) : 1
            guard alpha > 0.2 else { return }
            let color = UIColor(
                red: CGFloat(values[0]) / 255,
                green: CGFloat(values[1]) / 255,
                blue: CGFloat(values[2]) / 255,
                alpha: 1
            )
            webView.backgroundColor = color
            webView.scrollView.backgroundColor = color
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
    var isActive: Bool = true

    @EnvironmentObject private var search: ContentSearchStore
    /// 网页 / 源码状态放在共享对象里，顶栏「⋯」→「预览源代码」才能切换过来
    @EnvironmentObject private var webSource: WebSourceStore
    /// 编辑 HTML 源码时也要切到源码视图
    @EnvironmentObject private var edit: EditStore

    @State private var showMenu = false
    /// 是因为开了搜索才自动切到源码的，搜索关掉后要切回网页
    @State private var autoSwitched = false

    private var showSource: Bool {
        webSource.isSource(url) || edit.isEditing(url)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Theme.bg.ignoresSafeArea()

            if showSource {
                CodePage(url: url, topInset: topInset, isActive: isActive)
                    .transition(.opacity)
            } else {
                WebViewRepresentable(url: url) {
                    showMenu = true
                }
            }

            if showSource && !edit.isEditing(url) {
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
        .onChange(of: search.isActive) { _, active in
            // 搜索搜的是源码文本：在网页模式下点搜索，自动切到源码
            guard isActive else { return }
            if active, !showSource {
                autoSwitched = true
                switchTo(true)
            } else if !active, autoSwitched {
                autoSwitched = false
                switchTo(false)
            }
        }
        .onAppear {
            // 先开了搜索、或先在详情里点了「预览源代码」，再滑到这一页也要进源码
            guard isActive, search.isActive, !showSource else { return }
            autoSwitched = true
            switchTo(true)
        }
        .onChange(of: isActive) { _, active in
            // TabView 会预加载相邻页，滑过来时 onAppear 不一定再触发
            guard active, search.isActive, !showSource else { return }
            autoSwitched = true
            switchTo(true)
        }
    }

    private var titleText: String {
        showSource ? "源码" : "网页"
    }

    private func switchTo(_ source: Bool) {
        withAnimation(.easeInOut(duration: 0.18)) {
            webSource.setSource(url, source)
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
