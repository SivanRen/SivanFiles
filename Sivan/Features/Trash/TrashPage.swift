import SwiftUI

/// 最近删除：作为独立分页存在（不再用弹窗），从文件页滑入
struct TrashPage: View {

    @EnvironmentObject private var app: AppModel

    @State private var items: [FileItem] = []
    @State private var confirmEmpty = false
    @State private var pendingDelete: FileItem?

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline()

            if items.isEmpty {
                emptyState
            } else {
                list
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
        .confirmationDialog(
            "永久删除「\(pendingDelete?.name ?? "")」？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("永久删除", role: .destructive) {
                if let item = pendingDelete {
                    app.deletePermanently([item.url])
                    load()
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("该操作不可恢复")
        }
    }

    // MARK: - 顶栏

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                app.closeTrash()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(Theme.text)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text("最近删除")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if !items.isEmpty {
                Button {
                    confirmEmpty = true
                } label: {
                    Text("清空")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.danger.opacity(0.12)))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private var summary: String {
        if items.isEmpty { return "删除的文件会先放在这里" }
        let size = items.reduce(Int64(0)) { $0 + $1.size }
        return "\(items.count) 项 · \(Fmt.size(size))"
    }

    // MARK: - 列表

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(items) { item in
                    row(item)
                        .contextMenu {
                            Button {
                                restore(item)
                            } label: {
                                Label("恢复", systemImage: "arrow.uturn.backward")
                            }
                            Button {
                                app.share([item.url])
                            } label: {
                                Label("分享 / 发送到其他应用", systemImage: "square.and.arrow.up")
                            }
                            Divider()
                            Button(role: .destructive) {
                                pendingDelete = item
                            } label: {
                                Label("永久删除", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
    }

    private func row(_ item: FileItem) -> some View {
        HStack(spacing: 12) {
            FileThumbnail(item: item, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
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
                pendingDelete = item
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "trash")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Theme.textTertiary)
            Text("回收站是空的")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Text("在文件页长按文件选择「删除」，文件会先移动到这里，可随时恢复")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 操作

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
