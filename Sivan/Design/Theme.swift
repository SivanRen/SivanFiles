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

// MARK: - 全局暗黑主题

enum Theme {
    /// 页面底色（纯黑，OLED 更省电也更“Filza”）
    static let bg = Color(hex: 0x000000)
    /// 卡片 / 列表容器
    static let surface = Color(hex: 0x0E0E10)
    /// 抬升表面（菜单、悬浮层）
    static let elevated = Color(hex: 0x18181C)
    /// 再高一层（选中态）
    static let elevatedHi = Color(hex: 0x232329)

    static let stroke = Color.white.opacity(0.07)
    static let strokeStrong = Color.white.opacity(0.16)

    static let text = Color(hex: 0xF3F3F6)
    static let textSecondary = Color(hex: 0x9B9BA4)
    static let textTertiary = Color(hex: 0x61616B)

    static let accent = Color(hex: 0x4D8DFF)
    static let accentSoft = Color(hex: 0x4D8DFF, opacity: 0.16)
    static let danger = Color(hex: 0xFF4D4F)
    static let success = Color(hex: 0x35C759)

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
                .fill(image == nil ? tint.opacity(0.15) : Color.white.opacity(0.04))
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
            .foregroundStyle(selected ? Color.black : Theme.textSecondary)
            .background(
                Capsule().fill(selected ? Theme.text : Color.white.opacity(0.06))
            )
    }
}
