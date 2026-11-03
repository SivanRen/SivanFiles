import SwiftUI
import Combine

/// 一个“页面”（标签页）对应一个独立的浏览会话
final class BrowserModel: ObservableObject, Identifiable {

    let id = UUID()

    @Published var url: URL
    @Published var items: [FileItem] = []
    @Published var sortKey: SortKey
    @Published var ascending: Bool
    @Published var foldersFirst: Bool
    @Published var showHidden: Bool
    @Published var layout: LayoutMode

    @Published var selection: Set<URL> = []
    @Published var isEditing = false
    @Published var searchText: String = ""
    @Published var errorText: String?

    private var backStack: [URL] = []
    private var forwardStack: [URL] = []

    private let store = FileStore.shared

    init(url: URL) {
        let settings = AppSettings.shared
        self.url = url
        self.sortKey = settings.sortKey
        self.ascending = settings.ascending
        self.foldersFirst = settings.foldersFirst
        self.showHidden = settings.showHidden
        self.layout = settings.layout
        reload()
    }

    // MARK: - 派生状态

    var title: String {
        if url.standardizedFileURL == store.root.standardizedFileURL { return store.rootTitle }
        if url.standardizedFileURL == store.trashURL.standardizedFileURL { return "最近删除" }
        return url.lastPathComponent
    }

    var isRoot: Bool { url.standardizedFileURL == store.root.standardizedFileURL }
    var isInTrash: Bool { url.standardizedFileURL == store.trashURL.standardizedFileURL }
    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    /// 面包屑路径（从根目录开始）
    var breadcrumbs: [URL] {
        var result: [URL] = []
        var cursor = url.standardizedFileURL
        let rootPath = store.root.standardizedFileURL.path
        while cursor.path.hasPrefix(rootPath), cursor.path.count >= rootPath.count {
            result.insert(cursor, at: 0)
            if cursor.path == rootPath { break }
            let parent = cursor.deletingLastPathComponent()
            if parent.path == cursor.path { break }
            cursor = parent
        }
        if result.isEmpty { result = [store.root] }
        return result
    }

    var visibleItems: [FileItem] {
        var list = items
        if !searchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return sorted(list)
    }

    var selectedItems: [FileItem] {
        items.filter { selection.contains($0.url) }
    }

    var fileCount: Int { items.filter { !$0.isDirectory }.count }
    var folderCount: Int { items.filter { $0.isDirectory }.count }

    private func sorted(_ list: [FileItem]) -> [FileItem] {
        var result = list
        result.sort { lhs, rhs in
            if foldersFirst, lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            let ascendingResult: Bool
            switch sortKey {
            case .name:
                ascendingResult = lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .date:
                ascendingResult = lhs.modified > rhs.modified
            case .size:
                ascendingResult = lhs.size > rhs.size
            case .kind:
                ascendingResult = lhs.extLabel == rhs.extLabel
                    ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                    : lhs.extLabel < rhs.extLabel
            }
            return ascending ? ascendingResult : !ascendingResult
        }
        return result
    }

    // MARK: - 加载

    func reload() {
        do {
            items = try store.list(url, showHidden: showHidden)
            errorText = nil
        } catch {
            items = []
            errorText = error.localizedDescription
        }
        let alive = Set(items.map { $0.url })
        selection = selection.intersection(alive)
        if selection.isEmpty { isEditing = false }
    }

    // MARK: - 导航

    func navigate(to newURL: URL) {
        guard newURL.standardizedFileURL != url.standardizedFileURL else { return }
        backStack.append(url)
        forwardStack.removeAll()
        url = newURL
        searchText = ""
        selection.removeAll()
        isEditing = false
        reload()
        AppSettings.shared.lastPath = newURL.path
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(url)
        url = previous
        searchText = ""
        selection.removeAll()
        reload()
        AppSettings.shared.lastPath = previous.path
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(url)
        url = next
        selection.removeAll()
        reload()
        AppSettings.shared.lastPath = next.path
    }

    func goUp() {
        guard !isRoot else { return }
        navigate(to: url.deletingLastPathComponent())
    }

    // MARK: - 选择

    func toggleEditing() {
        isEditing.toggle()
        if !isEditing { selection.removeAll() }
    }

    func toggleSelection(_ item: FileItem) {
        if selection.contains(item.url) {
            selection.remove(item.url)
        } else {
            selection.insert(item.url)
        }
        if selection.isEmpty { isEditing = false }
    }

    func isSelected(_ item: FileItem) -> Bool { selection.contains(item.url) }

    func selectAll() {
        selection = Set(visibleItems.map { $0.url })
        isEditing = !selection.isEmpty
    }

    func clearSelection() {
        selection.removeAll()
        isEditing = false
    }

    // MARK: - 排序 / 视图

    func setSort(_ key: SortKey) {
        if sortKey == key {
            ascending.toggle()
        } else {
            sortKey = key
            ascending = true
        }
        AppSettings.shared.sortKey = sortKey
        AppSettings.shared.ascending = ascending
    }

    func toggleLayout() {
        layout = layout == .list ? .grid : .list
        AppSettings.shared.layout = layout
    }

    func toggleHidden() {
        showHidden.toggle()
        AppSettings.shared.showHidden = showHidden
        reload()
    }
}
