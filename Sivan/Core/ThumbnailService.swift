import UIKit
import QuickLookThumbnailing
import AVFoundation
import ImageIO

/// 列表缩略图：图片走 ImageIO 降采样，视频抽帧，PDF / Office 走 QuickLook
final class ThumbnailService {

    static let shared = ThumbnailService()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 400
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    func cached(for url: URL, size: CGFloat) -> UIImage? {
        cache.object(forKey: key(url, size) as NSString)
    }

    func thumbnail(for url: URL, size: CGFloat, scale: CGFloat = UIScreen.main.scale) async -> UIImage? {
        if let cached = cache.object(forKey: key(url, size) as NSString) { return cached }

        let pixel = size * scale
        let kind = FileKind.kind(for: url, isDirectory: false)
        var image: UIImage?

        switch kind {
        case .image, .gif, .html:
            image = downsampled(url: url, maxPixel: pixel)
        case .video:
            image = await videoFrame(url: url, maxPixel: pixel)
        case .pdf, .office:
            image = await quickLook(url: url, size: CGSize(width: size, height: size), scale: scale)
        default:
            image = nil
        }

        if image == nil, kind == .pdf || kind == .office {
            image = await quickLook(url: url, size: CGSize(width: size, height: size), scale: scale)
        }

        if let image {
            let cost = Int(image.size.width * image.size.height * 4)
            cache.setObject(image, forKey: key(url, size) as NSString, cost: cost)
        }
        return image
    }

    func clear() { cache.removeAllObjects() }

    // MARK: - 私有

    private func key(_ url: URL, _ size: CGFloat) -> String {
        "\(url.path)|\(Int(size))"
    }

    private func downsampled(url: URL, maxPixel: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        let sourceOptions = options as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixel, 48),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }

    private func videoFrame(url: URL, maxPixel: CGFloat) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixel, height: maxPixel)
        let time = CMTime(seconds: 0.4, preferredTimescale: 600)
        do {
            let (cg, _) = try await generator.image(at: time)
            return UIImage(cgImage: cg)
        } catch {
            return nil
        }
    }

    private func quickLook(url: URL, size: CGSize, scale: CGFloat) async -> UIImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )
        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.uiImage)
            }
        }
    }
}
