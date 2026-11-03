import SwiftUI
import UIKit

// MARK: - Hex 颜色

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}

// MARK: - 自适应主题

/// 全部颜色都是动态色：跟随系统外观，也跟随应用内「外观」设置。
/// 因为用的是 `UIColor` 的动态 provider，切换外观时整棵视图树会立刻重新取色，
/// 不需要重建窗口，也不会有一次「白闪」。
enum Theme {

    /// 深色 / 浅色两套取值
    private static func adaptive(dark: UInt32, light: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// 叠在背景上的浅色/深色蒙层：深色下用白，浅色下用黑
    static func veil(dark: CGFloat, light: CGFloat) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            return UIColor(white: isDark ? 1 : 0, alpha: isDark ? dark : light)
        })
    }

    static func veil(_ alpha: CGFloat) -> Color {
        veil(dark: alpha, light: alpha)
    }

    /// 页面底色
    static let bg = adaptive(dark: 0x000000, light: 0xF4F4F7)
    /// 卡片 / 列表容器
    static let surface = adaptive(dark: 0x0E0E10, light: 0xFFFFFF)
    /// 抬升表面（菜单、悬浮层）
    static let elevated = adaptive(dark: 0x18181C, light: 0xFFFFFF)
    /// 再高一层（选中态）
    static let elevatedHi = adaptive(dark: 0x232329, light: 0xE7E7EC)

    static let stroke = veil(dark: 0.07, light: 0.10)
    static let strokeStrong = veil(dark: 0.16, light: 0.20)

    static let text = adaptive(dark: 0xF3F3F6, light: 0x111114)
    static let textSecondary = adaptive(dark: 0x9B9BA4, light: 0x5C5C66)
    static let textTertiary = adaptive(dark: 0x61616B, light: 0x8D8D97)

    /// 填充色按钮上的文字：深色下用黑（按钮是浅色），浅色下用白（按钮是深色）
    static let inverse = adaptive(dark: 0x000000, light: 0xFFFFFF)

    static let accent = adaptive(dark: 0x4D8DFF, light: 0x0A6CFF)
    static let accentSoft = adaptive(dark: 0x1C2B44, light: 0xE1EBFF)
    static let danger = adaptive(dark: 0xFF4D4F, light: 0xD9292E)
    static let success = adaptive(dark: 0x35C759, light: 0x118A44)

    static let radius: CGFloat = 14
    static let radiusLarge: CGFloat = 22

    static let mono = Font.system(size: 13, design: .monospaced)
}

// MARK: - 常用修饰器

struct SurfaceCard: ViewModifier {
    var radius: CGFloat = Theme.radius
    var fill: Color = Theme.surface
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func surfaceCard(radius: CGFloat = Theme.radius, fill: Color = Theme.surface) -> some View {
        modifier(SurfaceCard(radius: radius, fill: fill))
    }

    /// 点击时轻微缩放 + 变暗，替代系统高亮
    func pressable() -> some View {
        buttonStyle(PressableStyle())
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 细线

struct Hairline: View {
    var color: Color = Theme.stroke
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1 / UIScreen.main.scale)
    }
}

// MARK: - 图标底片

struct IconTile: View {
    let symbol: String
    var tint: Color = Theme.textSecondary
    var size: CGFloat = 38
    var radius: CGFloat = 10
    /// 按文件类型的实际缩略图（可为 nil）
    var image: UIImage? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(image == nil ? tint.opacity(0.15) : Theme.veil(0.04))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.44, weight: .medium))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: image == nil ? 0 : 1)
        )
    }
}

// MARK: - 小标签

struct Chip: View {
    let text: String
    var selected: Bool = false
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(selected ? Theme.inverse : Theme.textSecondary)
            .background(
                Capsule().fill(selected ? Theme.text : Theme.veil(0.06))
            )
    }
}
