import SwiftUI

// MARK: - 存储空间

struct StorageView: View {

    @EnvironmentObject private var app: AppModel

    @State private var used: Int64 = 0
    @State private var free: Int64 = 0
    @State private var total: Int64 = 0
    @State private var fileCount = 0
    @State private var trashSize: Int64 = 0

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "存储空间")

            ScrollView {
                VStack(spacing: 16) {
                    card

                    PanelGroup("明细") {
                        PanelRow(title: "应用文件", subtitle: Fmt.size(used))
                        Hairline().padding(.leading, 14)
                        PanelRow(title: "最近删除", subtitle: Fmt.size(trashSize))
                        Hairline().padding(.leading, 14)
                        PanelRow(title: "文件数量", subtitle: "\(fileCount) 个")
                        Hairline().padding(.leading, 14)
                        PanelRow(title: "设备可用", subtitle: Fmt.size(free))
                    }

                    Button {
                        app.emptyTrash()
                        refresh()
                    } label: {
                        Text("清理最近删除")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Theme.stroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.bg)
        .onAppear { refresh() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Fmt.size(used))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("已使用")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("可用 \(Fmt.size(free))")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }

            GeometryReader { geometry in
                let ratio = total > 0 ? min(max(Double(used) / Double(total), 0.02), 1) : 0.02
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.veil(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent, Theme.accent.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * ratio)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .surfaceCard(radius: 16, fill: Theme.surface)
        .padding(.top, 4)
    }

    private func refresh() {
        let summary = app.storageSummary()
        used = summary.used
        free = summary.free
        total = summary.total
        fileCount = app.store.itemCount(in: app.store.root)
        trashSize = app.store.byteSize(of: app.store.trashURL)
    }
}
