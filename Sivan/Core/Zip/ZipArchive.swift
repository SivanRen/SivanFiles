import Foundation

struct ZipEntry: Identifiable {
    let name: String              // 完整路径，文件夹以 / 结尾
    let isDirectory: Bool
    let method: UInt16
    let crc32: UInt32
    let compressedSize: Int
    let uncompressedSize: Int
    let localHeaderOffset: Int

    var id: String { "\(localHeaderOffset)-\(name)" }

    var displayName: String {
        let trimmed = name.hasSuffix("/") ? String(name.dropLast()) : name
        return (trimmed as NSString).lastPathComponent
    }

    var depth: Int {
        let trimmed = name.hasSuffix("/") ? String(name.dropLast()) : name
        return max(0, trimmed.components(separatedBy: "/").count - 1)
    }

    var sizeText: String {
        isDirectory ? "" : Fmt.size(Int64(uncompressedSize))
    }
}

enum ZipError: LocalizedError {
    case notZip
    case truncated
    case zip64Unsupported
    case unsupportedMethod(UInt16)
    case crcMismatch

    var errorDescription: String? {
        switch self {
        case .notZip: return "不是有效的 zip 压缩包（暂不支持 rar / 7z）"
        case .truncated: return "压缩包结构不完整"
        case .zip64Unsupported: return "暂不支持 ZIP64 格式的超大压缩包"
        case .unsupportedMethod(let m): return "不支持的压缩算法（method \(m)）"
        case .crcMismatch: return "CRC 校验失败，文件可能已损坏"
        }
    }
}

/// 只读 zip 解析器
final class ZipArchive {

    let url: URL
    private let data: Data
    let entries: [ZipEntry]

    init(url: URL) throws {
        self.url = url
        self.data = try Data(contentsOf: url, options: [.mappedIfSafe])
        self.entries = try ZipArchive.parseCentralDirectory(in: data)
        if entries.isEmpty { throw ZipError.notZip }
    }

    // MARK: - 读取

    func data(for entry: ZipEntry) throws -> Data {
        let base = data.startIndex
        let lho = entry.localHeaderOffset
        guard lho >= 0, lho + 30 <= data.count else { throw ZipError.truncated }

        let nameLength = Int(readU16(lho + 26))
        let extraLength = Int(readU16(lho + 28))
        let start = lho + 30 + nameLength + extraLength
        let end = start + entry.compressedSize
        guard start >= 0, end <= data.count, start <= end else { throw ZipError.truncated }

        let raw = data.subdata(in: (base + start)..<(base + end))

        switch entry.method {
        case 0:
            if entry.crc32 != 0, CRC32.checksum(raw) != entry.crc32 { throw ZipError.crcMismatch }
            return raw
        case 8:
            let out = try Inflater.inflate(raw, expectedSize: entry.uncompressedSize)
            if CRC32.checksum(out) != entry.crc32 { throw ZipError.crcMismatch }
            return out
        default:
            throw ZipError.unsupportedMethod(entry.method)
        }
    }

    /// 解压全部到目录（自动防目录穿越）
    @discardableResult
    func extractAll(to directory: URL, progress: ((Double) -> Void)? = nil) throws -> Int {
        let fm = FileManager.default
        var count = 0
        let total = max(entries.count, 1)

        for (offset, entry) in entries.enumerated() {
            let safePath = ZipArchive.sanitize(entry.name)
            guard !safePath.isEmpty else { continue }
            if safePath.hasPrefix("__MACOSX/") || safePath.contains("/._") { continue }

            let target = directory.appendingPathComponent(safePath)
            if entry.isDirectory {
                try? fm.createDirectory(at: target, withIntermediateDirectories: true)
            } else {
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                let payload = try data(for: entry)
                try payload.write(to: target, options: .atomic)
                count += 1
            }
            progress?(Double(offset + 1) / Double(total))
        }
        return count
    }

    /// 解压单个条目到指定目录
    @discardableResult
    func extract(_ entry: ZipEntry, to directory: URL) throws -> URL {
        let safePath = ZipArchive.sanitize(entry.name)
        let target = directory.appendingPathComponent(safePath)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let payload = try data(for: entry)
        try payload.write(to: target, options: .atomic)
        return target
    }

    // MARK: - 解析

    private func readU16(_ offset: Int) -> UInt16 {
        let i = data.startIndex + offset
        return UInt16(data[i]) | (UInt16(data[i + 1]) << 8)
    }

    private func readU32(_ offset: Int) -> UInt32 {
        let i = data.startIndex + offset
        return UInt32(data[i])
            | (UInt32(data[i + 1]) << 8)
            | (UInt32(data[i + 2]) << 16)
            | (UInt32(data[i + 3]) << 24)
    }

    private static func parseCentralDirectory(in data: Data) throws -> [ZipEntry] {
        let signature: UInt32 = 0x0201_4B50
        let eocdSignature: UInt32 = 0x0605_4B50

        // 从尾部向前找 EOCD
        let maxScan = min(data.count, 66_000)
        var eocdOffset = -1
        var i = data.count - 22
        let lowerBound = max(0, data.count - maxScan)
        while i >= lowerBound {
            let idx = data.startIndex + i
            if data[idx] == 0x50, data[idx + 1] == 0x4B, data[idx + 2] == 0x05, data[idx + 3] == 0x06 {
                eocdOffset = i
                break
            }
            i -= 1
        }
        guard eocdOffset >= 0 else { throw ZipError.notZip }

        func u16(_ off: Int) -> UInt16 {
            let k = data.startIndex + off
            return UInt16(data[k]) | (UInt16(data[k + 1]) << 8)
        }
        func u32(_ off: Int) -> UInt32 {
            let k = data.startIndex + off
            return UInt32(data[k])
                | (UInt32(data[k + 1]) << 8)
                | (UInt32(data[k + 2]) << 16)
                | (UInt32(data[k + 3]) << 24)
        }

        let entryCount = Int(u16(eocdOffset + 10))
        let cdSize = Int(u32(eocdOffset + 12))
        let cdOffset = Int(u32(eocdOffset + 16))

        guard cdOffset >= 0, cdSize > 0, cdOffset + cdSize <= data.count else {
            if cdOffset == Int(UInt32.max) || entryCount == 0xFFFF { throw ZipError.zip64Unsupported }
            throw ZipError.truncated
        }

        var result: [ZipEntry] = []
        result.reserveCapacity(entryCount)
        var cursor = cdOffset
        var parsed = 0

        while parsed < max(entryCount, 1), cursor + 46 <= data.count {
            guard u32(cursor) == signature else { break }

            let method = u16(cursor + 10)
            let crc = u32(cursor + 16)
            let compSize = Int(u32(cursor + 20))
            let uncompSize = Int(u32(cursor + 24))
            let nameLen = Int(u16(cursor + 28))
            let extraLen = Int(u16(cursor + 30))
            let commentLen = Int(u16(cursor + 32))
            let localOffset = Int(u32(cursor + 42))

            guard cursor + 46 + nameLen <= data.count else { throw ZipError.truncated }
            let nameStart = data.startIndex + cursor + 46
            let nameData = data.subdata(in: nameStart..<(nameStart + nameLen))
            let name = String(data: nameData, encoding: .utf8)
                ?? String(decoding: nameData, as: UTF8.self)

            let isDirectory = name.hasSuffix("/") || (u32(cursor + 38) & 0x10) != 0

            result.append(ZipEntry(
                name: name,
                isDirectory: isDirectory,
                method: method,
                crc32: crc,
                compressedSize: compSize,
                uncompressedSize: uncompSize,
                localHeaderOffset: localOffset
            ))

            cursor += 46 + nameLen + extraLen + commentLen
            parsed += 1
        }

        return result
    }

    /// 去掉 .. / 绝对路径，防止目录穿越
    static func sanitize(_ name: String) -> String {
        var parts: [String] = []
        for component in name.components(separatedBy: "/") {
            if component.isEmpty || component == "." { continue }
            if component == ".." { continue }
            parts.append(component)
        }
        return parts.joined(separator: "/")
    }
}
