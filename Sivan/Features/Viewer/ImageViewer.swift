import SwiftUI
import UIKit
import ImageIO

// MARK: - 图片加载

enum ImageLoader {

    static func load(_ url: URL, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return UIImage(contentsOfFile: url.path)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixel, 256),
            kCGImageSourceShouldCacheImmediately: true
        ]
        if let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return UIImage(cgImage: cg)
        }
        return UIImage(contentsOfFile: url.path)
    }

    static func animated(_ url: URL, maxFrames: Int = 160) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }
        let count = CGImageSourceGetCount(source)
        if count <= 1 { return load(url, maxPixel: 2400) }

        var frames: [UIImage] = []
        var duration: Double = 0
        let limit = min(count, maxFrames)

        for index in 0..<limit {
            guard let cg = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cg))

            var delay = 0.1
            if let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
               let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                if let d = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double, d > 0.011 {
                    delay = d
                } else if let d = gif[kCGImagePropertyGIFDelayTime] as? Double, d > 0.011 {
                    delay = d
                }
            }
            duration += delay
        }

        guard !frames.isEmpty else { return nil }
        if frames.count == 1 { return frames[0] }
        return UIImage.animatedImage(with: frames, duration: duration)
    }
}

// MARK: - 可缩放图片

final class ZoomScrollView: UIScrollView, UIScrollViewDelegate {

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 5
        bouncesZoom = true
        backgroundColor = .clear
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        decelerationRate = .fast
        contentInsetAdjustmentBehavior = .never

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(_ image: UIImage) {
        imageView.image = image
        setNeedsLayout()
        layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if zoomScale == 1 {
            imageView.frame = bounds
            contentSize = bounds.size
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > 1.05 {
            setZoomScale(1, animated: true)
            return
        }
        let point = gesture.location(in: imageView)
        let target: CGFloat = 2.6
        let width = bounds.width / target
        let height = bounds.height / target
        zoom(
            to: CGRect(x: point.x - width / 2, y: point.y - height / 2, width: width, height: height),
            animated: true
        )
    }
}

struct ZoomableImageView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> ZoomScrollView {
        let view = ZoomScrollView()
        DispatchQueue.global(qos: .userInitiated).async {
            let image = ImageLoader.load(url, maxPixel: 2800)
            DispatchQueue.main.async {
                if let image { view.setImage(image) }
            }
        }
        return view
    }

    func updateUIView(_ uiView: ZoomScrollView, context: Context) {}
}

// MARK: - GIF / 动图

struct AnimatedImageView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        DispatchQueue.global(qos: .userInitiated).async {
            let image = ImageLoader.animated(url)
            DispatchQueue.main.async {
                imageView.image = image
                imageView.startAnimating()
            }
        }
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}
}

// MARK: - 页面封装

struct ImagePage: View {
    let url: URL
    var body: some View {
        ZoomableImageView(url: url)
            .ignoresSafeArea()
    }
}

struct GifPage: View {
    let url: URL
    var body: some View {
        AnimatedImageView(url: url)
            .ignoresSafeArea()
    }
}
