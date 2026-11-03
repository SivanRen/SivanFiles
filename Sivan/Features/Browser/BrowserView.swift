import SwiftUI
import UniformTypeIdentifiers

struct BrowserView: View {

    @ObservedObject var model: BrowserModel
    @EnvironmentObject private var app: AppModel

    @State private var showSearch = false
    @State private var pendingDelete: [URL] = []
    @State private var confirmDelete = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if showSearch { searchBar }
            BreadcrumbBar(model: model)
            content
            if model.isEditing {
                SelectionBar(model: model)
            } else {
                BottomBar(model: model)
            }
        }
        .background(Theme.bg)
        .confirmationDialog(
            model.isInTrash ? "确定永久删除这些项目？" : "移到“最近删除”？",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button(model.isInTrash ? "永久删除" : "移到最近删除", role: .destructive) {
                if model.isInTrash {
                    app.deletePermanently(pendingDelete)
                } else {
                    app.moveToTrash(pendingDelete)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("共 \(pendingDelete.count) 项")
        }
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { model.goBack() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(model.canGoBack ? Theme.text : Theme.textTertiary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(!model.canGoBack)

            VStack(alignment: .leading, spacing: 1) {
                Text(model.title)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(summaryText)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    showSearch.toggle()
                    if !showSearch { model.searchText = "" }
                }
            } label: {
                Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)

            moreMenu
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var summaryText: String {
        if let error = model.errorText { return error }
        return "\(model.folderCount) 个文件夹 · \(model.fileCount) 个文件"
    }

    private var moreMenu: some View {
        Menu {
            Section("排序") {
                ForEach(SortKey.allCases) { key in
                    Button {
                        model.setSort(key)
                    } label: {
                        Label(
                            key.title + (model.sortKey == key ? (model.ascending ? " ↑" : " ↓") : ""),
                            systemImage: key.symbol
                        )
                    }
                }
            }

            Section {
                Button {
                    model.foldersFirst.toggle()
                    AppSettings.shared.foldersFirst = model.foldersFirst
                } label: {
                    Label(model.foldersFirst ? "文件夹优先：开" : "文件夹优先：关", systemImage: "folder.badge.gearshape")
                }

                Button {
                    model.toggleHidden()
                } label: {
                    Label(model.showHidden ? "显示隐藏文件：开" : "显示隐藏文件：关", systemImage: "eye.slash")
                }

                Button {
                    model.toggleLayout()
                } label: {
                    Label(model.layout == .list ? "切换为网格" : "切换为列表", systemImage: model.layout.symbol)
                }
            }

            Section {
                Button {
                    app.sheet = .prompt(.newFolder)
                } label: {
                    Label("新建文件夹", systemImage: "folder.badge.plus")
                }
                Button {
                    app.sheet = .prompt(.newFile)
                } label: {
                    Label("新建文本文件", systemImage: "doc.badge.plus")
                }
                Button {
                    app.beginImport()
                } label: {
                    Label("从其他应用导入", systemImage: "square.and.arrow.down")
                }
                Button {
                    app.paste()
                } label: {
                    Label("粘贴", systemImage: "doc.on.clipboard")
                }
            }

            Section {
                Button {
                    if model.isEditing {
                        model.clearSelection()
                    } else {
                        model.selectAll()
                    }
                } label: {
                    Label(model.isEditing ? "退出选择" : "选择", systemImage: "checkmark.circle")
                }
                Button {
                    app.sheet = .trash
                } label: {
                    Label("最近删除", systemImage: "trash")
                }
                Button {
                    app.sheet = .storage
                } label: {
                    Label("存储空间", systemImage: "internaldrive")
                }
                Button {
                    app.sheet = .settings
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 30, height: 30)
                .foregroundStyle(Theme.textSecondary)
                .background(Circle().fill(Color.white.opacity(0.05)))
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
            TextField("在当前目录搜索", text: $model.searchText)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Theme.elevated))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        if model.visibleItems.isEmpty {
            emptyState
        } else if model.layout == .list {
            listContent
        } else {
            gridContent
        }
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(model.visibleItems) { item in
                    FileRow(
                        item: item,
                        isSelected: model.isSelected(item),
                        isEditing: model.isEditing
                    )
                    .onTapGesture { handleTap(item) }
                    .contextMenu { contextMenu(for: item) }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 92), spacing: 8)],
                spacing: 8
            ) {
                ForEach(model.visibleItems) { item in
                    FileGridCell(
                        item: item,
                        isSelected: model.isSelected(item),
                        isEditing: model.isEditing
                    )
                    .onTapGesture { handleTap(item) }
                    .contextMenu { contextMenu(for: item) }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: model.searchText.isEmpty ? "folder" : "doc.text.magnifyingglass")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(Theme.textTertiary)
            Text(model.searchText.isEmpty ? "这里是空的" : "没有匹配的文件")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            if model.searchText.isEmpty {
                Text("点右上角 ⋯ 可以新建文件夹或从其他应用导入")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 交互

    private func handleTap(_ item: FileItem) {
        if model.isEditing {
            withAnimation(.easeOut(duration: 0.15)) { model.toggleSelection(item) }
        } else {
            app.open(item)
        }
    }

    @ViewBuilder
    private func contextMenu(for item: FileItem) -> some View {
        Button {
            if item.isDirectory {
                model.navigate(to: item.url)
            } else {
                app.previewFile(item)
            }
        } label: {
            Label(item.isDirectory ? "打开" : "预览", systemImage: item.isDirectory ? "folder" : "eye")
        }

        if !item.isDirectory {
            Button {
                app.share([item.url])
            } label: {
                Label("分享 / 发送到其他应用", systemImage: "square.and.arrow.up")
            }
        }

        Button {
            app.copy([item.url])
        } label: {
            Label("复制", systemImage: "doc.on.doc")
        }

        Button {
            app.copy([item.url], cut: true)
        } label: {
            Label("剪切", systemImage: "scissors")
        }

        Button {
            _ = try? app.store.duplicate(item.url)
            app.reloadAll()
        } label: {
            Label("创建副本", systemImage: "plus.square.on.square")
        }

        Button {
            app.sheet = .prompt(.rename(item))
        } label: {
            Label("重命名", systemImage: "pencil")
        }

        if FileKind.isArchive(item.url) {
            if app.store.isZip(item.url) {
                Button {
                    app.sheet = .zip(item)
                } label: {
                    Label("查看压缩包内容", systemImage: "doc.zipper")
                }
                Button {
                    app.extract(item)
                } label: {
                    Label("解压到当前目录", systemImage: "arrow.down.doc")
                }
            }
        } else {
            Button {
                app.compress([item.url])
            } label: {
                Label("压缩为 zip", systemImage: "archivebox")
            }
        }

        Button {
            PasteboardService.copyText(item.url.path)
            app.toast("路径已复制")
        } label: {
            Label("复制路径", systemImage: "link")
        }

        Button {
            app.sheet = .info(item)
        } label: {
            Label("显示简介", systemImage: "info.circle")
        }

        Divider()

        Button(role: .destructive) {
            pendingDelete = [item.url]
            confirmDelete = true
        } label: {
            Label(model.isInTrash ? "永久删除" : "删除", systemImage: "trash")
        }
    }
}

// MARK: - 面包屑

struct BreadcrumbBar: View {
    @ObservedObject var model: BrowserModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(model.breadcrumbs, id: \.self) { url in
                    let isCurrent = url.standardizedFileURL == model.url.standardizedFileURL
                    Button {
                        model.navigate(to: url)
                    } label: {
                        Text(displayName(url))
                            .font(.system(size: 11.5, weight: isCurrent ? .semibold : .regular))
                            .foregroundStyle(isCurrent ? Theme.text : Theme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(isCurrent ? Color.white.opacity(0.08) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)

                    if url != model.breadcrumbs.last {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .scrollIndicators(.hidden)
    }

    private func displayName(_ url: URL) -> String {
        if url.standardizedFileURL == FileStore.shared.root.standardizedFileURL {
            return "我的文件"
        }
        return url.lastPathComponent
    }
}

// MARK: - 底部工具栏

struct BottomBar: View {
    @ObservedObject var model: BrowserModel
    @EnvironmentObject private var app: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 0) {
                item(icon: "square.and.arrow.down", title: "导入") { app.beginImport() }
                item(icon: "folder.badge.plus", title: "新建") { app.sheet = .prompt(.newFolder) }
                item(icon: "doc.on.clipboard", title: "粘贴", enabled: app.clipboard != nil) { app.paste() }
                item(icon: "rectangle.stack.badge.plus", title: "新页面") { app.addTab() }
                item(icon: "checkmark.circle", title: "选择") { model.selectAll() }
            }
            .padding(.horizontal, 6)
            .padding(.top, 8)
        }
        .background(Theme.bg)
    }

    private func item(icon: String, title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(enabled ? Theme.text : Theme.textTertiary.opacity(0.5))
                    .frame(height: 20)
                Text(title)
                    .font(.system(size: 9.5))
                    .foregroundStyle(enabled ? Theme.textTertiary : Theme.textTertiary.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }
}

// MARK: - 多选操作条

struct SelectionBar: View {
    @ObservedObject var model: BrowserModel
    @EnvironmentObject private var app: AppModel

    private var urls: [URL] { Array(model.selection) }

    var body: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 0) {
                Text("已选 \(model.selection.count) 项")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.leading, 16)

                Spacer()

                Button {
                    model.selectAll()
                } label: {
                    Text("全选")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)

                Button {
                    model.clearSelection()
                } label: {
                    Text("完成")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .padding(.leading, 12)
                .padding(.trailing, 16)
            }
            .padding(.vertical, 8)

            HStack(spacing: 0) {
                action(icon: "doc.on.doc", title: "复制") {
                    app.copy(urls)
                }
                action(icon: "scissors", title: "剪切") {
                    app.copy(urls, cut: true)
                }
                action(icon: "archivebox", title: "压缩") {
                    app.compress(urls)
                }
                action(icon: "square.and.arrow.up", title: "分享") {
                    app.share(urls)
                }
                action(icon: "trash", title: "删除", danger: true) {
                    if model.isInTrash {
                        app.deletePermanently(urls)
                    } else {
                        app.moveToTrash(urls)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
        .background(Theme.bg)
    }

    private func action(icon: String, title: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(danger ? Theme.danger : Theme.text)
                    .frame(height: 20)
                Text(title)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(model.selection.isEmpty && title != "分享")
    }
}
