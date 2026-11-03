import SwiftUI

/// 顶部多页面切换条（类 Filza 的多标签浏览）
struct TabStrip: View {

    @EnvironmentObject private var app: AppModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(app.tabs.enumerated()), id: \.element.id) { index, tab in
                    pill(for: tab, index: index)
                }
                addButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg)
    }

    private func pill(for tab: BrowserModel, index: Int) -> some View {
        let isActive = index == app.activeIndex
        return HStack(spacing: 6) {
            Circle()
                .fill(isActive ? Theme.accent : Theme.textTertiary)
                .frame(width: 5, height: 5)

            Text(tab.title)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? Theme.text : Theme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: 120)

            if app.tabs.count > 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        app.closeTab(tab.id)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 14, height: 14)
                        .background(Circle().fill(Theme.veil(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(isActive ? Theme.elevatedHi : Theme.veil(0.03))
        )
        .overlay(
            Capsule().strokeBorder(isActive ? Theme.strokeStrong : Theme.stroke, lineWidth: 1)
        )
        .contentShape(Capsule())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) {
                app.selectTab(index)
            }
        }
    }

    private var addButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                app.addTab()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.veil(0.04)))
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
