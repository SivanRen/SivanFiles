import SwiftUI
import Combine
import UIKit
import UniformTypeIdentifiers

// MARK: - 路由

enum PromptKind: Identifiable {
    case newFolder
    case newFile
    case rename(FileItem)

    var id: String {
        switch self {
        case .newFolder: return "newFolder"
        case .newFile: return "newFile"
        case .rename(let item): return "rename:\(item.url.path)"
        }
    }

    var title: String {
        switch self {
        case .newFolder: return "新建文件夹"
        case .newFile: return "新建文本文件"
        case .rename: return "重命名"
        }
    }

    var placeholder: String {
        switch self {
        case .newFolder: return "文件夹名称"
        case .newFile: return "文件名（含后缀）"
        case .rename(let item): return item.name
        }
    }

    var initialText: String {
        switch self {
        case .newFolder: return ""
        case .newFile: return "新建文本.txt"
        case .rename(let item): return item.name
        }
    }
}

enum AppSheet: Identifiable {
    case info(FileItem)
    case prompt(PromptKind)
    case share([URL])
    case settings
    case zip(FileItem)
    case storage

    var id: String {
        switch self {
        case .info(let item): return "info:\(item.url.path)"
        case .prompt(let kind): return "prompt:\(kind.id)"
        case .share(let urls): return "share:" + urls.map { $0.path }.joined(separator: "|")
        case .settings: return "settings"
        case .zip(let item): return "zip:\(item.url.path)"
        case .storage: return "storage"
        }
    }
}

/// 顶层页面：文件浏览 / 最近删除（独立分页，不用弹窗）
enum AppPage: Equatable {
    case browser
    case trash
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    var isError: Bool = false
}

// MARK: - 全局状态

final class AppModel: ObservableObject {

    @Published var tabs: [BrowserModel] = []
    @Published var activeIndex: Int = 0

    @Published var page: AppPage = .browser
    @Published var preview: PreviewRequest?
    @Published var sheet: AppSheet?
    @Published var toastMessage: ToastMessage?
    @Published var clipboard: ClipboardState?
    @Published var busyText: String?
    @Published var showAbout = false

    let settings = AppSettings.shared
    let store = FileStore.shared

    init() {
        let settings = AppSettings.shared
        var startURL = FileStore.shared.root
        if !settings.lastPath.isEmpty {
            let candidate = URL(fileURLWithPath: settings.lastPath)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue {
                startURL = candidate
            }
        }
        tabs = [BrowserModel(url: startURL)]
    }

    // MARK: - 当前页面

    var active: BrowserModel {
        let index = min(max(activeIndex, 0), max(tabs.count - 1, 0))
        if tabs.isEmpty {
            let model = BrowserModel(url: store.root)
            tabs = [model]
            activeIndex = 0
            return model
        }
        return tabs[index]
    }

    // MARK: - Toast

    func toast(_ text: String, isError: Bool = false) {
        toastMessage = ToastMessage(text: text, isError: isError)
    }

    func clearToast(_ id: UUID) {
        if toastMessage?.id == id { toastMessage = nil }
    }

    // MARK: - 打开 / 预览

    func open(_ item: FileItem) {
        if item.isDirectory {
            active.navigate(to: item.url)
            return
        }
        previewFile(item)
    }

    func previewFile(_ item: FileItem) {
        let all = active.visibleItems.filter { !$0.isDirectory }
        guard !all.isEmpty else {
            toast("这里没有可预览的文件", isError: true)
            return
        }
        // 左右滑动只在「同一目录 + 同一类型」的文件之间切换
        let group = item.kind.browseGroup
        let sameKind = all.filter { $0.kind.browseGroup == group }
        let files = sameKind.isEmpty ? [item] : sameKind
        let index = files.firstIndex(where: { $0.url == item.url }) ?? 0
        preview = PreviewRequest(items: files, index: index)
    }

    func preview(urls: [URL], startAt index: Int = 0) {
        let all = urls.map { FileItem(url: $0) }.filter { !$0.isDirectory }
        guard !all.isEmpty else { return }
        let anchor = all[min(max(index, 0), all.count - 1)]
        let sameKind = all.filter { $0.kind.browseGroup == anchor.kind.browseGroup }
        let files = sameKind.isEmpty ? all : sameKind
        let start = files.firstIndex(where: { $0.url == anchor.url }) ?? 0
        preview = PreviewRequest(items: files, index: start)
    }

    // MARK: - 页面切换

    // 过渡动画交给 RootView 的 .animation(value:) 处理，模型层只改状态
    func openTrash() {
        page = .trash
    }

    func closeTrash() {
        page = .browser
    }

    // MARK: - 标签页

    func addTab() {
        tabs.append(BrowserModel(url: active.url))
        activeIndex = tabs.count - 1
    }

    func closeTab(_ id: UUID) {
        guard tabs.count > 1 else { return }
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)
        activeIndex = min(activeIndex, tabs.count - 1)
    }

    func selectTab(_ index: Int) {
        guard index >= 0, index < tabs.count else { return }
        activeIndex = index
    }

    // MARK: - 文件操作

    func performPrompt(_ kind: PromptKind, text: String) {
        let name = text
        do {
            switch kind {
            case .newFolder:
                try store.createFolder(named: name, in: active.url)
                toast("已新建文件夹")
            case .newFile:
                let fileName = (name as NSString).pathExtension.isEmpty ? name + ".txt" : name
                try store.createFile(named: fileName, in: active.url)
                toast("已新建文件")
            case .rename(let item):
                let newURL = try store.rename(item.url, to: name)
                if let preview = preview,
                   let index = preview.items.firstIndex(where: { $0.url == item.url }) {
                    var updated = preview
                    updated.items[index] = FileItem(url: newURL)
                    self.preview = updated
                }
                toast("已重命名")
            }
            reloadAll()
        } catch {
            toast(error.localizedDescription, isError: true)
        }
    }

    func moveToTrash(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        do {
            try store.trash(urls)
            active.clearSelection()
            reloadAll()
            toast("已移到“最近删除”")
        } catch {
            toast(error.localizedDescription, isError: true)
        }
    }

    func deletePermanently(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        for url in urls { try? FileManager.default.removeItem(at: url) }
        active.clearSelection()
        reloadAll()
        toast("已删除")
    }

    func emptyTrash() {
        do {
            try store.emptyTrash()
            reloadAll()
            toast("已清空最近删除")
        } catch {
            toast(error.localizedDescription, isError: true)
        }
    }

    func duplicate(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        do {
            for url in urls { _ = try store.duplicate(url) }
            reloadAll()
            toast("已创建副本")
        } catch {
            toast(error.localizedDescription, isError: true)
        }
    }

    func compress(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let target = active.url
        background("正在压缩…") {
            let result = try FileStore.shared.compress(urls, in: target)
            return "已生成 \(result.lastPathComponent)"
        }
    }

    func extract(_ item: FileItem, to directory: URL? = nil) {
        guard FileKind.canExtract(item.url) else {
            toast("「\(item.url.pathExtension)」暂不支持解压", isError: true)
            return
        }
        let target = directory ?? active.url
        background("正在解压…") {
            let folder = try FileStore.shared.extract(item.url, to: target)
            return "已解压到「\(folder.lastPathComponent)」"
        }
    }

    // MARK: - 复制 / 剪切 / 粘贴

    func copy(_ urls: [URL], cut: Bool = false) {
        guard !urls.isEmpty else { return }
        clipboard = ClipboardState(urls: urls, isCut: cut)
        PasteboardService.copyFiles(urls)
        toast(cut ? "已剪切 \(urls.count) 项" : "已复制 \(urls.count) 项")
    }

    func paste() {
        guard let clip = clipboard, !clip.urls.isEmpty else {
            pasteFromSystem()
            return
        }
        let target = active.url
        let isCut = clip.isCut
        do {
            if isCut {
                try store.move(clip.urls, to: target)
                clipboard = nil
            } else {
                try store.copy(clip.urls, to: target)
            }
            reloadAll()
            toast(isCut ? "已移动到此处" : "已粘贴 \(clip.urls.count) 项")
        } catch {
            toast(error.localizedDescription, isError: true)
        }
    }

    func pasteFromSystem() {
        let target = active.url
        Task { @MainActor in
            let urls = await PasteboardService.readFileURLs()
            guard !urls.isEmpty else {
                toast("剪贴板里没有文件", isError: true)
                return
            }
            var count = 0
            var firstError: String?
            for url in urls {
                do {
                    try IngestService.ingest(url, into: target)
                    count += 1
                } catch {
                    if firstError == nil { firstError = error.localizedDescription }
                }
            }
            reloadAll()
            if count > 0 {
                toast("已粘贴 \(count) 个文件")
            } else {
                toast("粘贴失败：\(firstError ?? "来源不可访问")", isError: true)
            }
        }
    }

    // MARK: - 导入 / 分享

    func beginImport(into directory: URL? = nil) {
        let target = directory ?? active.url
        DocumentPickerPresenter.present { [weak self] urls in
            guard let self else { return }
            // 空数组 = 用户取消，保持安静
            guard !urls.isEmpty else { return }
            self.importPicked(urls, into: target)
        }
    }

    /// 导入用户从系统「文件」选择器挑的文件。
    /// 选择器用的是 `asCopy: true`，拿到的已经是本 App tmp 里的本地副本，
    /// 这里只负责搬进当前目录，并在后台线程做，避免大文件把界面卡成「没反应」。
    func importPicked(_ urls: [URL], into directory: URL? = nil) {
        guard !urls.isEmpty else { return }
        let target = directory ?? active.url
        busyText = "正在导入…"

        DispatchQueue.global(qos: .userInitiated).async {
            var count = 0
            var firstError: String?
            var failedNames: [String] = []

            for url in urls {
                do {
                    try IngestService.ingest(url, into: target)
                    count += 1
                } catch {
                    failedNames.append(url.lastPathComponent)
                    if firstError == nil { firstError = error.localizedDescription }
                }
                // 系统为本次导入放在 tmp 的副本，搬完即清
                IngestService.cleanUpTemporaryCopy(url)
            }

            DispatchQueue.main.async {
                self.busyText = nil
                self.reloadAll()
                if count > 0 && failedNames.isEmpty {
                    self.toast("已导入 \(count) 项")
                } else if count > 0 {
                    self.toast("已导入 \(count) 项，\(failedNames.count) 项失败", isError: true)
                } else {
                    let reason = firstError ?? "无法读取所选文件"
                    self.toast("导入失败：\(reason)", isError: true)
                }
            }
        }
    }

    func share(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        sheet = .share(urls)
    }

    /// 从其他 App 通过“用 Sivan 打开”传入的文件
    func handleIncoming(url: URL) {
        guard url.isFileURL else { return }
        let folder = store.importURL
        do {
            let destination = try IngestService.ingest(url, into: folder)
            // 系统投递到 Documents/Inbox 的临时副本，导入成功后清掉
            IngestService.cleanUpDeliveredCopy(url)
            toast("已导入 \(destination.lastPathComponent)")
            if active.url.standardizedFileURL != folder.standardizedFileURL {
                active.navigate(to: folder)
            }
            reloadAll()
        } catch {
            toast("导入失败：\(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - 后台任务

    func background(_ title: String, work: @escaping () throws -> String?) {
        busyText = title
        let task = work
        DispatchQueue.global(qos: .userInitiated).async {
            let outcome: Result<String?, Error>
            do {
                outcome = .success(try task())
            } catch {
                outcome = .failure(error)
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.busyText = nil
                switch outcome {
                case .success(let message):
                    self.reloadAll()
                    if let message { self.toast(message) }
                case .failure(let error):
                    self.toast(error.localizedDescription, isError: true)
                }
            }
        }
    }

    func reloadAll() {
        for tab in tabs { tab.reload() }
    }

    // MARK: - 存储统计

    func storageSummary() -> (used: Int64, free: Int64, total: Int64) {
        let used = store.byteSize(of: store.root)
        let values = try? store.root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        let free = Int64(values?.volumeAvailableCapacityForImportantUsage ?? 0)
        let total = Int64(values?.volumeTotalCapacity ?? 0)
        return (used, free, total)
    }
}
