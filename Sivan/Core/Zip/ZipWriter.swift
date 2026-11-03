import Foundation

/// 简化 zip 写入器：使用 store（不压缩）模式，兼容性最好，
/// 图片 / 视频本身已压缩，收益有限；文本类也不会显著变大。
enum ZipWriter {

    struct Item {
        let url: URL
        let path: String        // 压缩包内路径，文件夹以 / 结尾
        let isDirectory: Bool
    }

    enum WriteError: LocalizedError {
        case empty
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .empty: return "没有可压缩的内容"
            case .writeFailed: return "写入压缩包失败"
            }
        }
    }

    /// 收集文件（含子目录），返回用于写入的条目列表
    static func collect(urls: [URL], baseName: String) -> [Item] {
        let fm = FileManager.default
        var items: [Item] = []

        for url in urls {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                items.append(Item(url: url, path: baseName + "/", isDirectory: true))
                let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles],
                    errorHandler: nil
                )
                while let child = enumerator?.nextObject() as? URL {
                    let childIsDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    let relative = child.path.replacingOccurrences(of: url.path + "/", with: "")
                    items.append(Item(
                        url: child,
                        path: baseName + "/" + relative + (childIsDir ? "/" : ""),
                        isDirectory: childIsDir
                    ))
                }
            } else {
                items.append(Item(url: url, path: url.lastPathComponent, isDirectory: false))
            }
        }
        return items
    }

    @discardableResult
    static func write(items: [Item], to destination: URL, progress: ((Double) -> Void)? = nil) throws -> URL {
        guard !items.isEmpty else { throw WriteError.empty }

        guard items.count <= 60_000 else { throw ZipError.zip64Unsupported }

        var output = Data()
        var central = Data()
        let total = max(items.count, 1)

        for (index, item) in items.enumerated() {
            let nameData = Data(item.path.utf8)
            guard nameData.count < 60_000 else { throw ZipError.zip64Unsupported }
            let (dosTime, dosDate) = dosStamp(Date())

            var payload = Data()
            var crc: UInt32 = 0
            var size = 0

            if !item.isDirectory {
                payload = (try? Data(contentsOf: item.url, options: [.mappedIfSafe])) ?? Data()
                crc = CRC32.checksum(payload)
                size = payload.count
            }

            let offset = output.count
            guard offset <= Int(UInt32.max), size <= Int(UInt32.max) else {
                throw ZipError.zip64Unsupported
            }

            // 本地文件头
            output.le(UInt32(0x0403_4B50))
            output.le(UInt16(20))            // version needed
            output.le(UInt16(0x0800))        // UTF-8 flag
            output.le(UInt16(0))             // method = store
            output.le(dosTime)
            output.le(dosDate)
            output.le(crc)
            output.le(UInt32(size))
            output.le(UInt32(size))
            output.le(UInt16(nameData.count))
            output.le(UInt16(0))
            output.append(nameData)
            if !item.isDirectory { output.append(payload) }

            // 中央目录记录
            central.le(UInt32(0x0201_4B50))
            central.le(UInt16(20))           // version made by
            central.le(UInt16(20))           // version needed
            central.le(UInt16(0x0800))
            central.le(UInt16(0))
            central.le(dosTime)
            central.le(dosDate)
            central.le(crc)
            central.le(UInt32(size))
            central.le(UInt32(size))
            central.le(UInt16(nameData.count))
            central.le(UInt16(0))            // extra
            central.le(UInt16(0))            // comment
            central.le(UInt16(0))            // disk start
            central.le(UInt16(0))            // internal attrs
            central.le(UInt32(item.isDirectory ? 0x10 : 0)) // external attrs
            central.le(UInt32(offset))
            central.append(nameData)

            progress?(Double(index + 1) / Double(total))
        }

        let centralOffset = output.count
        output.append(central)

        // EOCD
        output.le(UInt32(0x0605_4B50))
        output.le(UInt16(0))
        output.le(UInt16(0))
        output.le(UInt16(items.count))
        output.le(UInt16(items.count))
        output.le(UInt32(central.count))
        output.le(UInt32(centralOffset))
        output.le(UInt16(0))

        do {
            try output.write(to: destination, options: .atomic)
        } catch {
            throw WriteError.writeFailed
        }
        return destination
    }

    // MARK: - DOS 时间

    private static func dosStamp(_ date: Date) -> (UInt16, UInt16) {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max((c.year ?? 1980) - 1980, 0)
        let month = c.month ?? 1
        let day = c.day ?? 1
        let hour = c.hour ?? 0
        let minute = c.minute ?? 0
        let second = c.second ?? 0

        let time = UInt16((hour << 11) | (minute << 5) | (second / 2))
        let dosDate = UInt16((year << 9) | (month << 5) | day)
        return (time, dosDate)
    }
}

private extension Data {
    mutating func le<T: FixedWidthInteger>(_ value: T) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { raw in
            self.append(contentsOf: raw)
        }
    }
}
