import Foundation

/// 一个文件 / 文件夹的轻量快照
struct FileItem: Identifiable, Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let isPackage: Bool
    let isSymbolicLink: Bool
    let size: Int64
    let modified: Date
    let created: Date
    let isHidden: Bool
    let ext: String

    var id: URL { url }

    var kind: PreviewKind { FileKind.kind(for: url, isDirectory: isDirectory) }

    var sizeText: String {
        if isDirectory { return "文件夹" }
        return Fmt.size(size)
    }

    var extLabel: String {
        ext.isEmpty ? (isDirectory ? "文件夹" : "文件") : ext.uppercased()
    }

    init(url: URL) {
        self.url = url
        let rawName = url.lastPathComponent
        self.name = rawName.isEmpty ? url.path : rawName

        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .fileSizeKey,
            .contentModificationDateKey, .creationDateKey, .isHiddenKey
        ]
        let values = try? url.resourceValues(forKeys: keys)

        let dir = values?.isDirectory ?? false
        let mod = values?.contentModificationDate ?? Date(timeIntervalSince1970: 0)
        let cre = values?.creationDate ?? mod

        self.isDirectory = dir
        self.isPackage = values?.isPackage ?? false
        self.isSymbolicLink = values?.isSymbolicLink ?? false
        self.size = dir ? 0 : Int64(values?.fileSize ?? 0)
        self.modified = mod
        self.created = cre
        self.isHidden = (values?.isHidden ?? false) || rawName.hasPrefix(".")
        self.ext = url.pathExtension.lowercased()
    }
}
