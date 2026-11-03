import Foundation
import UIKit
import UniformTypeIdentifiers

enum FileError: LocalizedError {
    case emptyName
    case invalidName
    case alreadyExists(String)
    case fail(String)

    var errorDescription: String? {
        switch self {
        case .emptyName: return "名称不能为空"
        case .invalidName: return "名称不能包含 / 或 : 等字符"
        case .alreadyExists(let n): return "“\(n)”已存在"
        case .fail(let m): return m
        }
    }
}

struct InfoRow: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

/// 文件系统操作集中入口
final class FileStore {

    static let shared = FileStore()

    let fm = FileManager.default
    let root: URL

    private init() {
        root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? fm.createDirectory(at: trashURL, withIntermediateDirectories: true)
        try? fm.createDirectory(at: importURL, withIntermediateDirectories: true)
    }

    var trashURL: URL { root.appendingPathComponent(".SivanTrash", isDirectory: true) }

    /// 用户可见的「导入」目录：从其他 App 传进来的文件统一落到这里
    var importURL: URL { root.appendingPathComponent("导入", isDirectory: true) }

    /// **系统保留目录**。iOS 通过「用 Sivan 打开」投递文件时会往这里放，
    /// App 不应该主动写入（会被沙盒判为无许可）。这里只用于导入成功后清理临时副本。
    var inboxURL: URL { root.appendingPathComponent("Inbox", isDirectory: true) }

    var rootTitle: String { "我的文件" }

    // MARK: - 读取

    func list(_ directory: URL, showHidden: Bool) throws -> [FileItem] {
        var options: FileManager.DirectoryEnumerationOptions = []
        if !showHidden { options.insert(.skipsHiddenFiles) }
        let urls = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: options
        )
        return urls.map { FileItem(url: $0) }
    }

    func uniqueURL(for name: String, in directory: URL) -> URL {
        var candidate = directory.appendingPathComponent(name)
        guard fm.fileExists(atPath: candidate.path) else { return candidate }

        let ns = name as NSString
        let base = ns.deletingPathExtension
        let ext = ns.pathExtension
        var index = 2
        while true {
            let nextName = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            candidate = directory.appendingPathComponent(nextName)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            index += 1
            if index > 9999 { return candidate }
        }
    }

    func exists(_ url: URL) -> Bool { fm.fileExists(atPath: url.path) }

    func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    // MARK: - 创建 / 重命名

    @discardableResult
    func createFolder(named name: String, in directory: URL) throws -> URL {
        let clean = try validated(name)
        let target = uniqueURL(for: clean, in: directory)
        do {
            try fm.createDirectory(at: target, withIntermediateDirectories: false)
        } catch {
            throw FileError.fail(error.localizedDescription)
        }
        return target
    }

    @discardableResult
    func createFile(named name: String, in directory: URL, contents: Data = Data()) throws -> URL {
        let clean = try validated(name)
        let target = uniqueURL(for: clean, in: directory)
        guard fm.createFile(atPath: target.path, contents: contents) else {
            throw FileError.fail("创建文件失败")
        }
        return target
    }

    @discardableResult
    func rename(_ url: URL, to newName: String) throws -> URL {
        let clean = try validated(newName)
        if clean == url.lastPathComponent { return url }
        let target = url.deletingLastPathComponent().appendingPathComponent(clean)
        if fm.fileExists(atPath: target.path) { throw FileError.alreadyExists(clean) }
        do {
            try fm.moveItem(at: url, to: target)
        } catch {
            throw FileError.fail(error.localizedDescription)
        }
        return target
    }

    @discardableResult
    func duplicate(_ url: URL) throws -> URL {
        let name = url.lastPathComponent
        let ns = name as NSString
        let base = ns.deletingPathExtension
        let ext = ns.pathExtension
        let copyName = ext.isEmpty ? "\(base) 副本" : "\(base) 副本.\(ext)"
        let target = uniqueURL(for: copyName, in: url.deletingLastPathComponent())
        do {
            try fm.copyItem(at: url, to: target)
        } catch {
            throw FileError.fail(error.localizedDescription)
        }
        return target
    }

    private func validated(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw FileError.emptyName }
        if trimmed.contains("/") || trimmed.contains(":") { throw FileError.invalidName }
        return trimmed
    }

    // MARK: - 删除（进回收站）

    func trash(_ urls: [URL]) throws {
        try? fm.createDirectory(at: trashURL, withIntermediateDirectories: true)
        let trashPath = trashURL.standardizedFileURL.path
        for url in urls {
            if url.standardizedFileURL.path.hasPrefix(trashPath) {
                try? fm.removeItem(at: url)
                continue
            }
            let target = uniqueURL(for: url.lastPathComponent, in: trashURL)
            do {
                try fm.moveItem(at: url, to: target)
            } catch {
                throw FileError.fail(error.localizedDescription)
            }
        }
    }

    func trashItems() -> [FileItem] {
        (try? list(trashURL, showHidden: true)) ?? []
    }

    func emptyTrash() throws {
        guard fm.fileExists(atPath: trashURL.path) else { return }
        let items = (try? fm.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil)) ?? []
        for item in items {
            try? fm.removeItem(at: item)
        }
    }

    // MARK: - 复制 / 移动

    @discardableResult
    func copy(_ urls: [URL], to directory: URL) throws -> [URL] {
        var results: [URL] = []
        for url in urls {
            if url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL {
                results.append(try duplicate(url))
                continue
            }
            let target = uniqueURL(for: url.lastPathComponent, in: directory)
            do {
                try fm.copyItem(at: url, to: target)
                results.append(target)
            } catch {
                throw FileError.fail(error.localizedDescription)
            }
        }
        return results
    }

    @discardableResult
    func move(_ urls: [URL], to directory: URL) throws -> [URL] {
        var results: [URL] = []
        for url in urls {
            if url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL {
                results.append(url)
                continue
            }
            let target = uniqueURL(for: url.lastPathComponent, in: directory)
            do {
                try fm.moveItem(at: url, to: target)
                results.append(target)
            } catch {
                throw FileError.fail(error.localizedDescription)
            }
        }
        return results
    }

    // MARK: - 空间统计

    func byteSize(of url: URL) -> Int64 {
        if !isDirectory(url) {
            return Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        var total: Int64 = 0
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: keys, options: [], errorHandler: nil) {
            for case let child as URL in enumerator {
                let values = try? child.resourceValues(forKeys: Set(keys))
                if values?.isRegularFile == true {
                    total += Int64(values?.fileSize ?? 0)
                }
            }
        }
        return total
    }

    func itemCount(in url: URL) -> Int {
        guard isDirectory(url) else { return 0 }
        var count = 0
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [], errorHandler: nil) {
            for case let child as URL in enumerator {
                if !isDirectory(child) { count += 1 }
            }
        }
        return count
    }

    // MARK: - 信息

    func infoRows(for item: FileItem) -> [InfoRow] {
        var rows: [InfoRow] = []
        rows.append(InfoRow(title: "名称", value: item.name))
        rows.append(InfoRow(title: "位置", value: item.url.deletingLastPathComponent().path.replacingOccurrences(of: root.path, with: "~/Documents")))

        if item.isDirectory {
            let size = byteSize(of: item.url)
            let count = itemCount(in: item.url)
            rows.append(InfoRow(title: "大小", value: "\(Fmt.size(size))（\(count) 个文件）"))
        } else {
            rows.append(InfoRow(title: "大小", value: Fmt.size(item.size)))
        }

        rows.append(InfoRow(title: "类型", value: mimeDescription(for: item)))
        rows.append(InfoRow(title: "创建时间", value: Fmt.date(item.created)))
        rows.append(InfoRow(title: "修改时间", value: Fmt.date(item.modified)))

        let attrs = try? fm.attributesOfItem(atPath: item.url.path)
        if let mode = attrs?[.posixPermissions] as? NSNumber {
            rows.append(InfoRow(title: "权限", value: Fmt.permissions(mode.intValue)))
        }
        if let owner = attrs?[.ownerAccountName] as? String {
            rows.append(InfoRow(title: "所有者", value: owner))
        }
        rows.append(InfoRow(title: "完整路径", value: item.url.path))
        return rows
    }

    func mimeDescription(for item: FileItem) -> String {
        if item.isDirectory { return "文件夹" }
        if let type = UTType(filenameExtension: item.ext) {
            let mime = type.preferredMIMEType ?? "-"
            return "\(item.extLabel) · \(mime)"
        }
        return item.extLabel
    }

    // MARK: - 压缩 / 解压

    func isZip(_ url: URL) -> Bool { FileKind.isZipFamily(url) }

    @discardableResult
    func compress(_ urls: [URL], in directory: URL) throws -> URL {
        guard !urls.isEmpty else { throw ZipWriter.WriteError.empty }

        let baseName: String
        if urls.count == 1 {
            let ns = urls[0].lastPathComponent as NSString
            baseName = ns.deletingPathExtension.isEmpty ? "归档" : ns.deletingPathExtension
        } else {
            baseName = "归档"
        }

        let items = ZipWriter.collect(urls: urls, baseName: baseName)
        let destination = uniqueURL(for: "\(baseName).zip", in: directory)
        return try ZipWriter.write(items: items, to: destination)
    }

    /// 解压到以压缩包名命名的子文件夹。
    /// zip 家族走工程自带的纯 Swift 实现，rar / 7z / tar / gz 等走 libarchive。
    @discardableResult
    func extract(_ archive: URL, to directory: URL) throws -> URL {
        let zipLike = isZip(archive)
        guard zipLike || ArchiveService.handles(archive) else {
            throw FileError.fail("暂不支持解压「\(archive.pathExtension)」格式")
        }

        let base = ArchiveService.baseName(for: archive)
        let target = uniqueURL(for: base, in: directory)
        try fm.createDirectory(at: target, withIntermediateDirectories: true)
        do {
            if zipLike {
                try ZipArchive(url: archive).extractAll(to: target)
            } else {
                try ArchiveService.extract(archive, into: target)
            }
        } catch {
            try? fm.removeItem(at: target)
            throw error
        }
        return target
    }

    @discardableResult
    func extract(_ archive: URL, entry: ZipEntry, to directory: URL) throws -> URL {
        let zip = try ZipArchive(url: archive)
        guard let match = zip.entries.first(where: { $0.id == entry.id }) else { throw ZipError.truncated }
        return try zip.extract(match, to: directory)
    }

    // MARK: - 文本读写

    func readText(_ url: URL, maxBytes: Int = 4 * 1024 * 1024) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: maxBytes)) ?? Data()
        guard !data.isEmpty else { return "" }
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .isoLatin1) { return text }
        // 中文 GBK / GB18030 常见于 PC 传来的 txt
        let gb18030 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
        )
        if let text = String(data: data, encoding: gb18030) { return text }
        return nil
    }

    func writeText(_ text: String, to url: URL) throws {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw FileError.fail(error.localizedDescription)
        }
    }
}
