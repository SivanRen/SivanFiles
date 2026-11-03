import Foundation
import Compression

/// 使用系统 libcompression 做 raw DEFLATE 解压。
/// Apple 的 COMPRESSION_ZLIB 输出裸 DEFLATE（RFC1951），正好是 zip 条目所需的格式；
/// 为了兼容少数带 zlib 头的实现，失败后会跳过 2 字节头重试一次。
enum Inflater {

    enum InflateError: LocalizedError {
        case failed
        case crcMismatch

        var errorDescription: String? {
            switch self {
            case .failed: return "解压失败：数据损坏或使用了不支持的压缩算法"
            case .crcMismatch: return "解压校验失败：文件已损坏"
            }
        }
    }

    static func inflate(_ source: Data, expectedSize: Int) throws -> Data {
        if expectedSize == 0 { return Data() }
        if let out = try? raw(source, expected: expectedSize), !out.isEmpty {
            return out
        }
        if source.count > 2 {
            let stripped = Data(source.dropFirst(2))
            if let out = try? raw(stripped, expected: expectedSize), !out.isEmpty {
                return out
            }
        }
        throw InflateError.failed
    }

    private static func raw(_ source: Data, expected: Int) throws -> Data {
        guard !source.isEmpty else { return Data() }
        let capacity = max(expected, 4096)
        var destination = Data(count: capacity)

        let written = destination.withUnsafeMutableBytes { dstBuffer -> Int in
            guard let dst = dstBuffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return source.withUnsafeBytes { srcBuffer -> Int in
                guard let src = srcBuffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(
                    dst, capacity,
                    src, source.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard written > 0 else { throw InflateError.failed }
        if written < destination.count {
            destination.removeSubrange(written..<destination.count)
        }
        return destination
    }
}
