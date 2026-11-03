import Foundation
import libarchive

enum ArchiveError: LocalizedError {
    case unsupported(String)
    case corrupted(String)
    case encrypted
    case empty

    var errorDescription: String? {
        switch self {
        case .unsupported(let m): return m
        case .corrupted(let m): return m
        case .encrypted: return "压缩包已加密，暂不支持输入密码"
        case .empty: return "压缩包里没有可解压的内容"
        }
    }
}

/// rar / 7z / tar / gz / xz 等格式的解压实现。
///
/// 这些算法（RAR 的专有熵编码、7z 的 LZMA2 + BCJ 链）自己实现风险太高，
/// 这里用 libarchive（BSD 协议，静态链接进主二进制，不引入动态框架，
/// 因此不影响未签名 ipa 的打包与自签）。
///
/// zip 仍然走本工程自带的纯 Swift 实现（`ZipArchive`），两边互不干扰：
/// zip 路径已经被验证过，不因为这次改动而回归。
enum ArchiveService {

    /// zip 家族之外的、由 libarchive 负责的扩展名
    static let libarchiveExts: Set<String> = [
        "rar", "7z",
        "tar", "gz", "tgz", "bz2", "tbz", "tbz2", "xz", "txz",
        "zst", "lz", "lzma", "cab", "iso", "cpio", "xar", "ar", "deb", "rpm"
    ]

    /// 是否由 libarchive 解压（zip 家族返回 false）
    static func handles(_ url: URL) -> Bool {
        libarchiveExts.contains(url.pathExtension.lowercased())
    }

    /// 解压到指定目录（调用方保证目录已创建且为空）
    static func extract(_ archiveURL: URL, into destination: URL) throws {
        let fm = FileManager.default

        // libarchive 的返回码在头文件里是 #define，这里直接写字面量，避免宏导入的类型差异
        let kOK: Int32 = 0
        let kEOF: Int32 = 1
        let kWarn: Int32 = -20

        guard let handle = archive_read_new() else {
            throw ArchiveError.unsupported("无法初始化解压器")
        }
        defer { archive_read_free(handle) }

        archive_read_support_filter_all(handle)
        archive_read_support_format_all(handle)

        let openStatus = archive_read_open_filename(handle, archiveURL.path, 64 * 1024)
        guard openStatus == kOK else {
            throw ArchiveError.corrupted(errorText(handle) ?? "无法打开压缩包")
        }
        defer { archive_read_close(handle) }

        var entry: OpaquePointer?
        var extracted = 0
        var createdDirectories = 0
        var skippedLinks = 0

        while true {
            let status = archive_read_next_header(handle, &entry)
            if status == kEOF { break }
            if status < kWarn {
                throw ArchiveError.corrupted(errorText(handle) ?? "压缩包已损坏或格式不受支持")
            }
            guard let item = entry else { continue }
            // status == kWarn 时头信息部分可用，继续尝试，尽量多解出东西

            let rawName = archive_entry_pathname(item).map { String(cString: $0) } ?? ""
            guard let relative = safeRelativePath(rawName) else { continue }

            let target = destination.appendingPathComponent(relative)
            // 双保险：拼接后仍必须落在目标目录内
            let rootPath = destination.standardizedFileURL.path
            guard target.standardizedFileURL.path.hasPrefix(rootPath + "/") else { continue }

            let mode = archive_entry_filetype(item)
            let isDirectory = (mode & 0o170000) == 0o040000

            if isDirectory {
                try? fm.createDirectory(at: target, withIntermediateDirectories: true)
                createdDirectories += 1
                continue
            }

            // 符号链接 / 硬链接可能指向沙盒外的路径，直接跳过（也避免目录穿越）
            if archive_entry_symlink(item) != nil || archive_entry_hardlink(item) != nil {
                skippedLinks += 1
                continue
            }

            try? fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: target.path) { try? fm.removeItem(at: target) }
            guard fm.createFile(atPath: target.path, contents: nil) else {
                throw ArchiveError.corrupted("无法写入「\(relative)」，可能是存储空间不足")
            }

            let output = try FileHandle(forWritingTo: target)
            do {
                var buffer = [UInt8](repeating: 0, count: 256 * 1024)
                while true {
                    let read = buffer.withUnsafeMutableBytes { raw in
                        archive_read_data(handle, raw.baseAddress, raw.count)
                    }
                    if read < 0 {
                        try? output.close()
                        throw ArchiveError.corrupted(errorText(handle) ?? "解压「\(relative)」失败")
                    }
                    if read == 0 { break }
                    try output.write(contentsOf: Data(bytes: buffer, count: Int(read)))
                }
                try? output.close()
            } catch {
                try? output.close()
                throw error
            }

            let mtime = archive_entry_mtime(item)
            if mtime > 0 {
                try? fm.setAttributes(
                    [.modificationDate: Date(timeIntervalSince1970: Double(mtime))],
                    ofItemAtPath: target.path
                )
            }
            extracted += 1
        }

        // 只有「一个条目都没产出」才算空包。只含空文件夹的包不算空，
        // 只含符号链接的包也算成功（链接已按安全策略跳过）。
        if extracted == 0 && createdDirectories == 0 {
            if archive_read_has_encrypted_entries(handle) == 1 {
                throw ArchiveError.encrypted
            }
            if skippedLinks > 0 { return }
            throw ArchiveError.empty
        }
    }

    // MARK: - 命名

    /// 解压目标文件夹名：`a.tar.gz` → `a`，`b.rar` → `b`
    static func baseName(for url: URL) -> String {
        let name = url.lastPathComponent
        let lower = name.lowercased()
        let doubleExts = [".tar.gz", ".tar.bz2", ".tar.xz", ".tar.zst", ".tgz", ".tbz2", ".txz", ".tar.lzma"]
        for suffix in doubleExts where lower.hasSuffix(suffix) {
            let trimmed = String(name.dropLast(suffix.count))
            return trimmed.isEmpty ? "解压结果" : trimmed
        }
        let base = (name as NSString).deletingPathExtension
        return base.isEmpty ? "解压结果" : base
    }

    // MARK: - 内部

    /// 把压缩包内的路径变成安全的相对路径，拒绝绝对路径与 `..`
    private static func safeRelativePath(_ raw: String) -> String? {
        let unified = raw.replacingOccurrences(of: "\\", with: "/")
        var parts: [String] = []
        for piece in unified.split(separator: "/", omittingEmptySubsequences: true) {
            let name = String(piece)
            if name == "." { continue }
            if name == ".." {
                // 退到上层就说明在往外爬，整条丢弃
                guard !parts.isEmpty else { return nil }
                parts.removeLast()
                continue
            }
            // 过滤 NUL 等控制字符
            if name.unicodeScalars.contains(where: { $0.value == 0 }) { return nil }
            parts.append(name)
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "/")
    }

    private static func errorText(_ handle: OpaquePointer) -> String? {
        guard let cString = archive_error_string(handle) else { return nil }
        let text = String(cString: cString).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
