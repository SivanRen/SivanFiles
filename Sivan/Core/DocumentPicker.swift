import UIKit
import UniformTypeIdentifiers

/// 自建文档选择器。
///
/// 为什么不用 SwiftUI 的 `.fileImporter`：
/// 1. 从 `Menu`（工具栏弹层）里触发、`allowsMultipleSelection: true`、来源是
///    File Provider（iCloud Drive / 「我的 iPhone」/ 第三方 App 目录）三者叠加时，
///    常见表现就是「选了文件点确认，回到 App 毫无反应」——补全回调丢失或拿到空数组。
/// 2. 它把安全作用域 URL 直接丢给我们，跨容器读取的成败取决于对方 App 的实现，
///    失败时很容易变成一次静默失败。
///
/// 这里固定用 `asCopy: true`：系统会先把文件复制到本 App 的 `tmp` 再交给我们，
/// 于是拿到的永远是本地普通文件——不需要 `startAccessingSecurityScopedResource`，
/// 也不可能再出现「没有访问 xx 的许可」。复制完我们再把 tmp 里的副本删掉。
enum DocumentPickerPresenter {

    /// 弹出系统「文件」选择器。用户取消时回调空数组。
    static func present(onPick: @escaping ([URL]) -> Void) {
        // 点击发生在 Menu 收起的过程中，等一个 runloop 再弹，避免两层模态打架
        DispatchQueue.main.async {
            guard let host = topViewController() else {
                onPick([])
                return
            }

            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: [UTType.item],
                asCopy: true
            )
            picker.allowsMultipleSelection = true
            picker.shouldShowFileExtensions = true

            // delegate 是 weak 的，必须自己持有，否则回调还没触发就被释放
            let handler = Handler(onPick: onPick)
            picker.delegate = handler
            objc_setAssociatedObject(picker, &delegateKey, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            picker.presentationController?.delegate = handler

            host.present(picker, animated: true)
        }
    }

    private static var delegateKey: UInt8 = 0

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

        let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    private final class Handler: NSObject, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {

        private let onPick: ([URL]) -> Void
        private var finished = false

        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard !finished else { return }
            finished = true
            onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            guard !finished else { return }
            finished = true
            onPick([])
        }

        /// 从 App 内用菜单/手势下拉关闭时，也要保证状态收尾
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            guard !finished else { return }
            finished = true
            onPick([])
        }
    }
}
