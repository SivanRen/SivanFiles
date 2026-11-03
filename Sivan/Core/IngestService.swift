import Foundation

/// 把文件从「外部容器」安全地搬进应用自己的沙盒。
///
/// 背景：微信 / QQ / 其他 App 通过「用 xxx 打开」把文件传进来时，URL 指向的是
/// **对方沙盒**（常见于 `对方容器/Documents/Inbox/xxx`）。这种 URL 只申请安全作用域
/// 往往不够，`FileManager.copyItem` 会直接抛 NSCocoaErrorDomain 257
/// （"you don't have permission to access 'Inbox'"）。
///
/// 这里按可靠性从高到低做三层回退：协调读 → 直接拷贝 → 分块流式拷贝，
/// 任何一层成功就返回，全失败才把最后一个错误抛给调用方。
enum IngestService {

    /// 把 `source` 复制进 `directory`，返回最终落盘位置。
    /// 目标已存在同名文件时自动改名为 `name 2.ext`。
    @discardableResult
    static func ingest(_ source: URL, into directory: URL) throws -> URL {
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let srcDir = source.deletingLastPathComponent().standardizedFileURL
        let dstDir = directory.standardizedFileURL

        var name = source.lastPathComponent
        if name.isEmpty { name = "未命名" }

        var destination = dstDir.appendingPathComponent(name)
        if fm.fileExists(atPath: destination.path) {
            destination = FileStore.shared.uniqueURL(for: name, in: dstDir)
        }

        // 源和目标就是同一个文件（例如文件本来就在当前目录里被再次导入）
        if source.standardizedFileURL == destination.standardizedFileURL {
            return source
        }

        var lastError: Error?

        // ① 协调读：File Provider / iCloud / 其他 App 容器都走这条最稳
        do {
            try coordinatedCopy(source, to: destination)
            return destination
        } catch {
            lastError = error
        }

        // ② 普通拷贝（本地文件、目录都适用）
        do {
            if fm.fileExists(atPath: destination.path) { try? fm.removeItem(at: destination) }
            try fm.copyItem(at: source, to: destination)
            return destination
        } catch {
            lastError = error
        }

        // ③ 分块流式拷贝：copyItem 在特殊 ACL / 超大文件上偶发失败时兜底
        do {
            try streamCopy(source, to: destination)
            return destination
        } catch {
            lastError = error
        }

        if fm.fileExists(atPath: destination.path) { try? fm.removeItem(at: destination) }
        throw lastError ?? FileError.fail("无法读取来源文件")
    }

    /// 系统投递到 `Documents/Inbox` 的临时副本，导入成功后清掉，避免堆积。
    static func cleanUpDeliveredCopy(_ source: URL) {
        let inbox = FileStore.shared.inboxURL.standardizedFileURL
        guard source.standardizedFileURL.deletingLastPathComponent() == inbox else { return }
        try? FileManager.default.removeItem(at: source)
    }

    /// 文档选择器（`asCopy: true`）为本次导入放在 `tmp` 里的副本，搬完即删。
    /// 只清理确实位于本 App 临时目录下的路径，绝不误删用户文件。
    static func cleanUpTemporaryCopy(_ source: URL) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).standardizedFileURL
        let path = source.standardizedFileURL
        guard path.path.hasPrefix(tmp.path) else { return }
        // 选择器会把副本放在 tmp 下的子目录里，整个子目录一起清掉
        let parent = path.deletingLastPathComponent()
        if parent.path != tmp.path, path.path.hasPrefix(parent.path) {
            try? FileManager.default.removeItem(at: parent)
        } else {
            try? FileManager.default.removeItem(at: path)
        }
    }

    // MARK: - 内部实现

    private static func coordinatedCopy(_ source: URL, to destination: URL) throws {
        var coordError: NSError?
        var innerError: Error?
        var didCopy = false

        NSFileCoordinator(filePresenter: nil).coordinate(
            readingItemAt: source,
            options: [.withoutChanges],
            error: &coordError
        ) { url in
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try? FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: url, to: destination)
                didCopy = true
            } catch {
                innerError = error
            }
        }

        if didCopy { return }
        if let innerError { throw innerError }
        if let coordError { throw coordError }
        throw FileError.fail("来源文件无法读取")
    }

    private static func streamCopy(_ source: URL, to destination: URL) throws {
        let fm = FileManager.default
        guard !FileStore.shared.isDirectory(source) else {
            // 目录交给 copyItem，流式拷贝只处理单文件
            if fm.fileExists(atPath: destination.path) { try? fm.removeItem(at: destination) }
            try fm.copyItem(at: source, to: destination)
            return
        }

        if fm.fileExists(atPath: destination.path) { try? fm.removeItem(at: destination) }
        guard fm.createFile(atPath: destination.path, contents: nil) else {
            throw FileError.fail("无法在目标位置创建文件")
        }

        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }

        let chunkSize = 1 << 20  // 1 MB
        while true {
            let chunk = try input.read(upToCount: chunkSize) ?? Data()
            if chunk.isEmpty { break }
            try output.write(contentsOf: chunk)
        }
    }
}
