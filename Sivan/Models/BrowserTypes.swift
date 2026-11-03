import Foundation

enum SortKey: String, CaseIterable, Identifiable {
    case name
    case date
    case size
    case kind

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: return "名称"
        case .date: return "修改时间"
        case .size: return "大小"
        case .kind: return "类型"
        }
    }

    var symbol: String {
        switch self {
        case .name: return "textformat.abc"
        case .date: return "clock"
        case .size: return "arrow.up.and.down"
        case .kind: return "square.grid.2x2"
        }
    }
}

enum LayoutMode: String, CaseIterable, Identifiable {
    case list
    case grid

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}

/// 预览请求：整页左右滑动浏览目录内的所有文件
struct PreviewRequest: Identifiable {
    let id = UUID()
    var items: [FileItem]
    var index: Int
}

/// 应用内剪贴板（复制 / 剪切）
struct ClipboardState {
    var urls: [URL]
    var isCut: Bool = false
}
