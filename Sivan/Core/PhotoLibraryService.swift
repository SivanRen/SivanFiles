import Foundation
import Photos
import UIKit

/// 把文件保存进系统相册（App 内叫「图库」）
enum PhotoLibraryService {

    enum SaveError: LocalizedError {
        case unsupported
        case denied
        case missingFile
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .unsupported:
                return "只有图片、动图和视频可以存入图库"
            case .denied:
                return "没有相册写入权限，请在「设置 → Sivan → 照片」中允许“添加照片”"
            case .missingFile:
                return "文件已不在原位置"
            case .failed(let reason):
                return "存入图库失败：\(reason)"
            }
        }
    }

    /// 只有图片 / 动图 / 视频可以进相册
    static func canSave(_ url: URL) -> Bool {
        switch FileKind.kind(for: url, isDirectory: false) {
        case .image, .gif, .video:
            return true
        default:
            return false
        }
    }

    static func save(_ url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        guard canSave(url) else {
            completion(.failure(SaveError.unsupported))
            return
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            completion(.failure(SaveError.missingFile))
            return
        }

        let kind = FileKind.kind(for: url, isDirectory: false)

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion(.failure(SaveError.denied)) }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                if kind == .video {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                } else {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                }
            }, completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(.success(Void()))
                    } else {
                        completion(.failure(SaveError.failed(error?.localizedDescription ?? "未知原因")))
                    }
                }
            })
        }
    }
}
