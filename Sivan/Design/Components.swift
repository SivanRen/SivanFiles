import SwiftUI

/// 弹层通用头部
struct SheetHeader: View {

    let title: String
    var confirmTitle: String? = nil
    var confirmDisabled: Bool = false
    var onConfirm: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)

            Spacer()

            if let confirmTitle, let onConfirm {
                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(confirmDisabled ? Theme.textTertiary : Theme.inverse)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(confirmDisabled ? Theme.veil(0.08) : Theme.text)
                        )
                }
                .buttonStyle(.plain)
                .disabled(confirmDisabled)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Theme.veil(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }
}

/// 设置 / 信息面板里的一行
struct PanelRow<Trailing: View>: View {

    let title: String
    let subtitle: String?
    let trailing: () -> Trailing

    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

extension PanelRow where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// 分组容器
struct PanelGroup<Content: View>: View {

    let title: String?
    let content: () -> Content

    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.leading, 6)
            }
            VStack(spacing: 0) {
                content()
            }
            .surfaceCard(radius: 14, fill: Theme.surface)
        }
    }
}

/// 空列表占位
struct EmptyHint: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(Theme.textTertiary)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
