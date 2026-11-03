import UIKit
import UniformTypeIdentifiers

/// 与系统剪贴板互通：既能给其他 App 粘贴，也能接住其他 App 复制来的文件
enum PasteboardService {

    static func copyFiles(_ urls: [URL]) {
        let providers: [NSItemProvider] = urls.compactMap { NSItemProvider(contentsOf: $0) }
        guard !providers.isEmpty else { return }
        UIPasteboard.general.setItemProviders(providers, localOnly: false, expirationDate: nil)
    }

    static func copyText(_ text: String) {
        UIPasteboard.general.string = text
    }

    static func hasFiles() -> Bool {
        UIPasteboard.general.contains(pasteboardTypes: [UTType.fileURL.identifier])
            || !UIPasteboard.general.itemProviders.isEmpty
    }

    /// 读取系统剪贴板中的文件 URL（异步，因为 NSItemProvider 加载可能很慢）
    static func readFileURLs() async -> [URL] {
        let providers = UIPasteboard.general.itemProviders
        guard !providers.isEmpty else { return [] }

        var results: [URL] = []
        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { continue }
            let url: URL? = await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data,
                       let parsed = URL(dataRepresentation: data, relativeTo: nil) {
                        continuation.resume(returning: parsed)
                    } else if let url = item as? URL {
                        continuation.resume(returning: url)
                    } else if let text = item as? String, let url = URL(string: text) {
                        continuation.resume(returning: url)
                    } else if let text = item as? String {
                        continuation.resume(returning: URL(fileURLWithPath: text))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
            if let url, url.isFileURL {
                results.append(url)
            }
        }
        return results
    }
}
