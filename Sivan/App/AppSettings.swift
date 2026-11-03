import Foundation
import SwiftUI
import Combine

/// 外观：跟随系统 / 强制浅色 / 强制深色
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    /// `nil` 表示不干预，由系统外观决定
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// 轻量偏好设置（UserDefaults 落盘）
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    private enum Keys {
        static let showHidden = "sivan.showHidden"
        static let foldersFirst = "sivan.foldersFirst"
        static let sortKey = "sivan.sortKey"
        static let ascending = "sivan.ascending"
        static let layout = "sivan.layout"
        static let codeFontSize = "sivan.codeFontSize"
        static let lastPath = "sivan.lastPath"
        static let appearance = "sivan.appearance"
    }

    private let store = UserDefaults.standard

    @Published var showHidden: Bool {
        didSet { store.set(showHidden, forKey: Keys.showHidden) }
    }

    @Published var foldersFirst: Bool {
        didSet { store.set(foldersFirst, forKey: Keys.foldersFirst) }
    }

    @Published var sortKey: SortKey {
        didSet { store.set(sortKey.rawValue, forKey: Keys.sortKey) }
    }

    @Published var ascending: Bool {
        didSet { store.set(ascending, forKey: Keys.ascending) }
    }

    @Published var layout: LayoutMode {
        didSet { store.set(layout.rawValue, forKey: Keys.layout) }
    }

    @Published var codeFontSize: Double {
        didSet { store.set(codeFontSize, forKey: Keys.codeFontSize) }
    }

    @Published var lastPath: String {
        didSet { store.set(lastPath, forKey: Keys.lastPath) }
    }

    @Published var appearance: AppAppearance {
        didSet { store.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    private init() {
        showHidden = store.bool(forKey: Keys.showHidden)
        foldersFirst = store.object(forKey: Keys.foldersFirst) as? Bool ?? true
        sortKey = SortKey(rawValue: store.string(forKey: Keys.sortKey) ?? "") ?? .name
        ascending = store.object(forKey: Keys.ascending) as? Bool ?? true
        layout = LayoutMode(rawValue: store.string(forKey: Keys.layout) ?? "") ?? .list
        codeFontSize = store.object(forKey: Keys.codeFontSize) as? Double ?? 14
        lastPath = store.string(forKey: Keys.lastPath) ?? ""
        appearance = AppAppearance(rawValue: store.string(forKey: Keys.appearance) ?? "") ?? .system
    }
}
