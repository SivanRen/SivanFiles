import SwiftUI

// MARK: - 单页内容分发

struct PreviewPage: View {

    let item: FileItem
    let isActive: Bool

    var body: some View {
        Group {
            switch item.kind {
            case .image:
                ImagePage(url: item.url)
            case .gif:
                GifPage(url: item.url)
            case .video:
                VideoPage(url: item.url, isActive: isActive)
            case .audio:
                AudioPage(url: item.url, isActive: isActive)
            case .text, .code:
                CodePage(url: item.url)
            case .html:
                WebPage(url: item.url)
            case .archive:
                ArchivePage(item: item)
            case .pdf, .office, .unknown, .folder:
                QuickLookPage(url: item.url)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - 压缩包内页

struct ArchivePage: View {

    let item: FileItem

    @EnvironmentObject private var app: AppModel
    @State private var entries: [ZipEntry] = []
    @State private var errorText: String?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.stroke)

            if isLoading {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if let errorText {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 36, weight: .thin))
                        .foregroundStyle(Theme.textTertiary)
                    Text(errorText)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(entries) { entry in
                            entryRow(entry)
                            Hairline()
                        }
                    }
                    .padding(.bottom, 150)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(Theme.bg)
        .task { load() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            IconTile(
                symbol: "archivebox.fill",
                tint: FileKind.tint(for: .archive),
                size: 46,
                radius: 12
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text("\(entries.count) 个条目 · \(Fmt.size(item.size))")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            if FileKind.isZipFamily(item.url) && !entries.isEmpty {
                Button {
                    app.extract(item)
                } label: {
                    Text("解压")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.text))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 104)
        .padding(.bottom, 12)
    }

    private func entryRow(_ entry: ZipEntry) -> some View {
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
        .padding(.leading, CGFloat(min(entry.depth, 6)) * 14 + 16)
        .padding(.trailing, 16)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private func load() {
        guard isLoading else { return }
        defer { isLoading = false }
        guard FileKind.isZipFamily(item.url) else {
            errorText = "该格式暂不支持在线浏览（仅支持 zip / jar / ipa / apk 等）"
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
