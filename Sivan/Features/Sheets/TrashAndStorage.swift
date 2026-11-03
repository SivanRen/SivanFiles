import SwiftUI

// MARK: - 最近删除

struct TrashView: View {

    @EnvironmentObject private var app: AppModel

    @State private var items: [FileItem] = []
    @State private var confirmEmpty = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "最近删除",
                confirmTitle: items.isEmpty ? nil : "清空",
                confirmDisabled: items.isEmpty,
                onConfirm: { confirmEmpty = true }
            )

            if items.isEmpty {
                EmptyHint(symbol: "trash", title: "回收站是空的", subtitle: "删除的文件会先移动到这里，可随时恢复")
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(items) { item in
                            row(item)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(Theme.bg)
        .onAppear { load() }
        .confirmationDialog("清空最近删除？", isPresented: $confirmEmpty, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                app.emptyTrash()
                load()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("共 \(items.count) 项，操作不可恢复")
        }
    }

    private func row(_ item: FileItem) -> some View {
        HStack(spacing: 12) {
            FileThumbnail(item: item, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text("\(Fmt.size(item.size)) · \(Fmt.shortDate(item.modified))")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 4)

            Button {
                restore(item)
            } label: {
                Text("恢复")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.accentSoft))
            }
            .buttonStyle(.plain)

            Button {
                app.deletePermanently([item.url])
                load()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.danger)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func restore(_ item: FileItem) {
        do {
            try app.store.move([item.url], to: app.store.root)
            app.toast("已恢复到主目录")
            load()
            app.reloadAll()
        } catch {
            app.toast(error.localizedDescription, isError: true)
        }
    }

    private func load() {
        items = app.store.trashItems()
    }
}

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
                    Capsule().fill(Color.white.opacity(0.08))
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
