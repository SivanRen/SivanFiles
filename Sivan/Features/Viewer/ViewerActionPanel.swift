import SwiftUI

/// 预览页里的「快捷栏」：上面是文件属性，下面是快捷操作。
/// 图片 / 动图 / 视频会多出一个「存入图库」。
struct ViewerActionPanel: View {

    let item: FileItem

    var onClose: () -> Void
    var onShare: () -> Void
    var onImport: () -> Void
    var onExtract: () -> Void
    var onDelete: () -> Void
    var onRenamed: (URL) -> Void
    var onShowInfo: () -> Void
    var onNotify: (String, Bool) -> Void

    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var webSource: WebSourceStore
    @ObservedObject private var languagePreference = LanguagePreference.shared

    @State private var rows: [InfoRow] = []
    @State private var isSaving = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showLanguagePicker = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.veil(0.22))
                .frame(width: 38, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 2)

            ScrollView {
                VStack(spacing: 16) {
                    header
                    actionGrid
                    propertyCard
                    footer
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 26)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 470)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.elevated)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
                .ignoresSafeArea(edges: .bottom)
        )
        .task { rows = app.store.infoRows(for: item) }
        .alert("重命名", isPresented: $showRename) {
            TextField("新名称（含扩展名）", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("确定") { performRename() }
        } message: {
            Text("文件会保留在原目录")
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(url: item.url)
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 12) {
            FileThumbnail(item: item, size: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text("\(item.extLabel) · \(Fmt.size(item.size))")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 6)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Theme.veil(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
    }

    // MARK: - 快捷操作

    private struct PanelAction: Identifiable {
        let id: String
        let icon: String
        let title: String
        var tint: Color = Theme.text
        let run: () -> Void
    }

    private var actionItems: [PanelAction] {
        var list: [PanelAction] = []

        list.append(PanelAction(id: "share", icon: "square.and.arrow.up", title: "分享") {
            onShare()
        })

        list.append(PanelAction(id: "import", icon: "square.and.arrow.down", title: "导入文件") {
            onImport()
        })

        if PhotoLibraryService.canSave(item.url) {
            list.append(PanelAction(
                id: "library",
                icon: isSaving ? "hourglass" : "photo.on.rectangle.angled",
                title: isSaving ? "存入中…" : "存入图库"
            ) {
                saveToLibrary()
            })
        }

        list.append(PanelAction(id: "copy", icon: "doc.on.doc", title: "复制") {
            // 预览页盖在最上层，这里不走 app.copy（它的提示条会被盖住），
            // 直接写剪贴板状态 + 系统剪贴板，提示由预览页自己弹。
            app.clipboard = ClipboardState(urls: [item.url])
            PasteboardService.copyFiles([item.url])
            onNotify("已复制文件", false)
        })

        if FileKind.canExtract(item.url) {
            list.append(PanelAction(id: "extract", icon: "arrow.down.doc", title: "解压") {
                onExtract()
            })
        }

        if item.kind == .html {
            let isSource = webSource.isSource(item.url)
            list.append(PanelAction(
                id: "viewSource",
                icon: isSource ? "globe" : "chevron.left.forwardslash.chevron.right",
                title: isSource ? "显示网页" : "预览源代码"
            ) {
                webSource.setSource(item.url, !isSource)
                onClose()
            })
        }

        if item.kind == .text || item.kind == .code || item.kind == .html {
            list.append(PanelAction(id: "copyText", icon: "text.alignleft", title: "复制全文") {
                if let text = app.store.readText(item.url) {
                    PasteboardService.copyText(text)
                    onNotify("全文已复制", false)
                } else {
                    onNotify("这个文件无法按文本读取", true)
                }
            })

            let language = languagePreference.effective(for: item.url)
            list.append(PanelAction(
                id: "language",
                icon: "chevron.left.forwardslash.chevron.right",
                title: language.isPlain ? "语言 · 纯文本" : "语言 · \(language.shortTitle)"
            ) {
                showLanguagePicker = true
            })
        }

        list.append(PanelAction(id: "rename", icon: "pencil", title: "重命名") {
            renameText = item.name
            showRename = true
        })

        list.append(PanelAction(id: "path", icon: "link", title: "复制路径") {
            PasteboardService.copyText(item.url.path)
            onNotify("路径已复制", false)
        })

        list.append(PanelAction(id: "delete", icon: "trash", title: "删除", tint: Theme.danger) {
            onDelete()
        })

        return list
    }

    private var actionGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
            spacing: 8
        ) {
            ForEach(actionItems) { action in
                Button(action: action.run) {
                    VStack(spacing: 6) {
                        Image(systemName: action.icon)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(action.tint)
                            .frame(height: 20)
                        Text(action.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.veil(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    // MARK: - 属性

    private var propertyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("属性")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .padding(.leading, 6)

            VStack(spacing: 0) {
                ForEach(Array(rows.prefix(5).enumerated()), id: \.element.id) { offset, row in
                    HStack(alignment: .top, spacing: 10) {
                        Text(row.title)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 62, alignment: .leading)
                        Text(row.value)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.text)
                            .textSelection(.enabled)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)

                    if offset < min(rows.count, 5) - 1 {
                        Hairline().padding(.leading, 14)
                    }
                }

                Hairline().padding(.leading, 14)

                Button {
                    onShowInfo()
                } label: {
                    HStack {
                        Text("查看完整简介")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.accent)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .surfaceCard(radius: 14, fill: Theme.surface)
        }
    }

    private var footer: some View {
        Button {
            onClose()
        } label: {
            Text("完成")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.inverse)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Theme.text)
                )
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - 动作

    private func saveToLibrary() {
        guard !isSaving else { return }
        isSaving = true
        PhotoLibraryService.save(item.url) { result in
            isSaving = false
            switch result {
            case .success:
                onNotify("已存入图库", false)
            case .failure(let error):
                onNotify(error.localizedDescription, true)
            }
        }
    }

    private func performRename() {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard name != item.name else { return }
        do {
            let newURL = try app.store.rename(item.url, to: name)
            app.reloadAll()
            onRenamed(newURL)
            onNotify("已重命名为 \(newURL.lastPathComponent)", false)
        } catch {
            onNotify(error.localizedDescription, true)
        }
    }
}
