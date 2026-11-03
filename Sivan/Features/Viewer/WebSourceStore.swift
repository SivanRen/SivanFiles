import SwiftUI

/// 网页预览的「渲染 / 源码」状态。
///
/// 之所以抽成共享对象：HTML 页在 `PreviewPage` 里，而「预览源代码」的入口在
/// 顶栏「⋯」弹出的 `ViewerActionPanel` 里，两者没有直接的视图层级关系。
/// 这里按 URL 记录哪些文件要看源码，页面自己订阅状态即可。
final class WebSourceStore: ObservableObject {

    @Published private(set) var sourceURLs: Set<URL> = []

    func isSource(_ url: URL) -> Bool {
        sourceURLs.contains(url)
    }

    func setSource(_ url: URL, _ isSource: Bool) {
        var next = sourceURLs
        if isSource {
            next.insert(url)
        } else {
            next.remove(url)
        }
        guard next != sourceURLs else { return }
        sourceURLs = next
    }

    func toggle(_ url: URL) {
        setSource(url, !isSource(url))
    }
}
