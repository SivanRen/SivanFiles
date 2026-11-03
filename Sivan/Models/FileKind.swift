import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// 预览分流类型
enum PreviewKind {
    case folder
    case image
    case gif
    case video
    case audio
    case pdf
    case office
    case text      // 纯文本 / 日志 / Markdown
    case code      // 源码
    case html      // 网页 / SVG
    case archive   // 压缩包
    case unknown
}

enum FileKind {

    static let imageExts: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "bmp", "tiff", "tif", "ico", "cur",
        "raw", "dng", "cr2", "nef", "arw", "exr", "hdr"
    ]

    static let gifExts: Set<String> = ["gif", "apng", "webp"]

    static let videoExts: Set<String> = [
        "mp4", "mov", "m4v", "3gp", "ts", "m2ts", "mkv", "avi", "flv", "wmv", "webm", "rmvb", "mpg", "mpeg"
    ]

    static let audioExts: Set<String> = [
        "mp3", "m4a", "aac", "wav", "flac", "ogg", "oga", "opus", "aiff", "aif", "caf", "amr", "wma", "ape", "m4b"
    ]

    static let officeExts: Set<String> = [
        "doc", "docx", "xls", "xlsx", "ppt", "pptx", "rtf", "rtfd", "pages", "numbers", "key", "epub", "webarchive"
    ]

    static let htmlExts: Set<String> = ["html", "htm", "xhtml", "shtml", "svg", "mhtml", "xht"]

    static let archiveExts: Set<String> = [
        "zip", "jar", "ipa", "apk", "xpi", "epub_zip", "cbz", "war", "aar", "whl", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "zst", "lz", "lzma", "cab", "iso"
    ]

    static let textExts: Set<String> = [
        "txt", "text", "md", "markdown", "log", "csv", "tsv", "ini", "conf", "cfg", "env", "properties", "gitignore"
    ]

    static let codeExts: Set<String> = [
        "c", "h", "hh", "hpp", "hxx", "cpp", "cc", "cxx", "m", "mm", "swift", "java", "kt", "kts", "go", "rs",
        "js", "jsx", "ts", "tsx", "vue", "svelte", "py", "rb", "php", "pl", "lua", "sh", "bash", "zsh", "fish",
        "json", "json5", "xml", "plist", "yml", "yaml", "toml", "sql", "css", "scss", "sass", "less",
        "gradle", "cmake", "make", "mk", "dockerfile", "pbxproj", "strings", "entitlements", "xcscheme", "xib", "storyboard", "proto", "asm", "s", "vb", "cs", "fs", "dart", "r", "jl", "nim", "zig", "sol", "graphql", "gql"
    ]

    static func isArchive(_ url: URL) -> Bool {
        archiveExts.contains(url.pathExtension.lowercased())
    }

    /// zip 家族之外（rar/7z）目前只能列表提示，不支持解压
    static func isZipFamily(_ url: URL) -> Bool {
        ["zip", "jar", "ipa", "apk", "xpi", "cbz", "war", "aar", "whl"].contains(url.pathExtension.lowercased())
    }

    static func kind(for url: URL, isDirectory: Bool) -> PreviewKind {
        if isDirectory { return .folder }
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()

        if ext.isEmpty {
            if name == "makefile" || name == "dockerfile" || name == "podfile" || name == "gemfile" { return .code }
            return .unknown
        }
        if ext == "pdf" { return .pdf }
        if gifExts.contains(ext) { return .gif }
        if imageExts.contains(ext) { return .image }
        if videoExts.contains(ext) { return .video }
        if audioExts.contains(ext) { return .audio }
        if htmlExts.contains(ext) { return .html }
        if officeExts.contains(ext) { return .office }
        if archiveExts.contains(ext) { return .archive }
        if codeExts.contains(ext) { return .code }
        if textExts.contains(ext) { return .text }
        return .unknown
    }

    static func symbol(for kind: PreviewKind, url: URL? = nil) -> String {
        switch kind {
        case .folder: return "folder.fill"
        case .image: return "photo.fill"
        case .gif: return "sparkles"
        case .video: return "play.rectangle.fill"
        case .audio: return "music.note"
        case .pdf: return "doc.text.fill"
        case .office:
            let ext = url?.pathExtension.lowercased() ?? ""
            if ["xls", "xlsx", "numbers", "csv"].contains(ext) { return "tablecells" }
            if ["ppt", "pptx", "key"].contains(ext) { return "rectangle.on.rectangle.fill" }
            return "doc.richtext.fill"
        case .text: return "text.alignleft"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .html: return "globe"
        case .archive: return "archivebox.fill"
        case .unknown: return "doc.fill"
        }
    }

    static func tint(for kind: PreviewKind) -> Color {
        switch kind {
        case .folder: return Color(hex: 0xE8B44A)
        case .image: return Color(hex: 0x4DABF7)
        case .gif: return Color(hex: 0xB197FC)
        case .video: return Color(hex: 0xFF7A59)
        case .audio: return Color(hex: 0xF76E9C)
        case .pdf: return Color(hex: 0xFF5A5A)
        case .office: return Color(hex: 0x4D8DFF)
        case .text: return Color(hex: 0x9AA0AA)
        case .code: return Color(hex: 0x5ED3A8)
        case .html: return Color(hex: 0xFF8A3D)
        case .archive: return Color(hex: 0xC9A227)
        case .unknown: return Color(hex: 0x7A7F87)
        }
    }

    /// 是否可以用 QuickLook 原生预览
    static func quickLookable(_ url: URL, isDirectory: Bool) -> Bool {
        guard !isDirectory else { return false }
        let k = kind(for: url, isDirectory: false)
        switch k {
        case .image, .gif, .video, .audio, .text, .code, .html, .archive, .folder:
            return false
        default:
            return true
        }
    }
}
