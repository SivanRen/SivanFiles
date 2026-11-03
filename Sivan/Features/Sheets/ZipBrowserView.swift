import SwiftUI

struct ZipBrowserView: View {

    let item: FileItem

    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [ZipEntry] = []
    @State private var errorText: String?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "压缩包内容",
                confirmTitle: "解压全部",
                confirmDisabled: entries.isEmpty,
                onConfirm: {
                    app.extract(item)
                    dismiss()
                }
            )

            header

            Hairline()

            if isLoading {
                EmptyHint(symbol: "hourglass", title: "正在读取压缩包…")
            } else if let errorText {
                EmptyHint(symbol: "archivebox", title: "无法打开", subtitle: errorText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(entries) { entry in
                            row(entry)
                            Hairline().padding(.leading, 16)
                        }
                    }
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(Theme.bg)
        .task { load() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            IconTile(symbol: "archivebox.fill", tint: FileKind.tint(for: .archive), size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text("\(entries.count) 个条目 · \(Fmt.size(item.size))")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func row(_ entry: ZipEntry) -> some View {
        Button {
            guard !entry.isDirectory else { return }
            do {
                let url = try FileStore.shared.extract(item.url, entry: entry, to: app.active.url)
                app.toast("已导出 \(url.lastPathComponent) 到当前目录")
                app.reloadAll()
            } catch {
                app.toast(error.localizedDescription, isError: true)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(entry.isDirectory ? FileKind.tint(for: .folder) : Theme.textTertiary)
                    .frame(width: 16)
                Text(entry.displayName)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                if !entry.isDirectory {
                    Text(entry.sizeText)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.leading, CGFloat(min(entry.depth, 6)) * 14 + 18)
            .padding(.trailing, 18)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func load() {
        guard isLoading else { return }
        defer { isLoading = false }
        guard FileKind.canBrowseArchive(item.url) else {
            let ext = item.url.pathExtension.uppercased()
            errorText = FileKind.canExtract(item.url)
                ? "\(ext) 格式可在 App 内直接解压，但不支持展开条目列表"
                : "仅支持 zip / jar / ipa / apk 等 zip 系格式"
            return
        }
        do {
            let archive = try ZipArchive(url: item.url)
            entries = archive.entries.filter { !$0.name.hasPrefix("__MACOSX/") }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
