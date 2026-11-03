import SwiftUI

/// 文本编辑状态：按 URL 记录「哪些文件正在编辑」以及各自的草稿文本。
///
/// 之所以抽成共享对象：编辑入口在顶栏「⋯」弹出的 `ViewerActionPanel` 里，
/// 而真正渲染文本的 `CodePage` 在 `PreviewPage` 里，两者没有直接的视图层级关系。
/// 这里统一保存草稿，退出整个预览页时由 `PagedViewer.onDisappear` 调用
/// `stopAll()` 一并清掉，保证「每次退出文本文件自动关闭编辑」。
final class EditStore: ObservableObject {

    @Published private(set) var editingURLs: Set<URL> = []
    @Published private(set) var drafts: [URL: String] = [:]

    func isEditing(_ url: URL) -> Bool {
        editingURLs.contains(url)
    }

    func draft(for url: URL) -> String? {
        drafts[url]
    }

    /// 进入编辑：initialText 只在还没有草稿时作为初始值写入
    func beginEditing(_ url: URL, initialText: String) {
        if !editingURLs.contains(url) { editingURLs.insert(url) }
        if drafts[url] == nil { drafts[url] = initialText }
    }

    /// 结束编辑但保留草稿：让 `CodePage` 能把最新内容刷回只读视图
    func endEditing(_ url: URL) {
        if editingURLs.contains(url) { editingURLs.remove(url) }
    }

    /// 取消编辑：连草稿一起丢弃，只读视图维持原样
    func discard(_ url: URL) {
        if editingURLs.contains(url) { editingURLs.remove(url) }
        if drafts[url] != nil { drafts.removeValue(forKey: url) }
    }

    func updateDraft(_ text: String, for url: URL) {
        if drafts[url] != text { drafts[url] = text }
    }

    /// 退出整个预览页时清空一切编辑状态与草稿
    func stopAll() {
        if !editingURLs.isEmpty { editingURLs = [] }
        if !drafts.isEmpty { drafts = [:] }
    }
}
