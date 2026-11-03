import SwiftUI

/// 分页预览：左右滑动浏览同目录下的所有文件，底部有缩略图胶片条
struct PagedViewer: View {

    let request: PreviewRequest

    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var index: Int
    @State private var showFilmstrip = true

    init(request: PreviewRequest) {
        self.request = request
        _index = State(initialValue: min(max(request.index, 0), max(request.items.count - 1, 0)))
    }

    private var items: [FileItem] { request.items }

    private var current: FileItem? {
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
                    PreviewPage(item: item, isActive: offset == index)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                if showFilmstrip, items.count > 1 {
                    filmstrip
                }
            }
        }
        .statusBarHidden()
    }

    // MARK: - 顶栏

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(PressableStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(current?.name ?? "")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            actionsMenu
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 30)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.92), Color.black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    private var subtitle: String {
        guard let current else { return "" }
        let type = current.isDirectory ? "文件夹" : current.extLabel
        return "\(index + 1)/\(items.count)  ·  \(type)  ·  \(current.isDirectory ? "" : Fmt.size(current.size))"
    }

    private var actionsMenu: some View {
        Menu {
            if let current {
                if !current.isDirectory {
                    Button {
                        app.share([current.url])
                    } label: {
                        Label("分享 / 发送到其他应用", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        PasteboardService.copyFiles([current.url])
                        app.toast("已复制文件")
                    } label: {
                        Label("复制文件", systemImage: "doc.on.doc")
                    }
                    if FileKind.isZipFamily(current.url) {
                        Button {
                            app.extract(current)
                        } label: {
                            Label("解压到当前目录", systemImage: "arrow.down.doc")
                        }
                    }
                    if current.kind == .text || current.kind == .code {
                        Button {
                            if let text = FileStore.shared.readText(current.url) {
                                PasteboardService.copyText(text)
                                app.toast("全文已复制")
                            }
                        } label: {
                            Label("复制全部文本", systemImage: "text.alignleft")
                        }
                    }
                }
                Button {
                    app.sheet = .info(current)
                } label: {
                    Label("显示简介", systemImage: "info.circle")
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showFilmstrip.toggle() }
            } label: {
                Label(showFilmstrip ? "隐藏缩略图条" : "显示缩略图条", systemImage: "rectangle.bottomthird.inset.filled")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(width: 30, height: 30)
                .background(Circle().fill(.ultraThinMaterial))
        }
    }

    // MARK: - 胶片条

    private var filmstrip: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(0..<min(items.count, 14), id: \.self) { dot in
                    Circle()
                        .fill(dot == dotIndex ? Theme.text : Color.white.opacity(0.28))
                        .frame(width: dot == dotIndex ? 5.5 : 4, height: dot == dotIndex ? 5.5 : 4)
                }
                if items.count > 14 {
                    Text("…")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) { index = offset }
                            } label: {
                                filmCell(item: item, active: offset == index)
                            }
                            .buttonStyle(.plain)
                            .id(offset)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }
                .onChange(of: index) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
            .frame(height: 50)
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var dotIndex: Int {
        if items.count <= 14 { return index }
        return Int(round(Double(index) / Double(max(items.count - 1, 1)) * 13))
    }

    private func filmCell(item: FileItem, active: Bool) -> some View {
        FileThumbnail(item: item, size: 40)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(active ? Theme.text : Color.white.opacity(0.12), lineWidth: active ? 1.6 : 1)
            )
            .opacity(active ? 1 : 0.62)
    }
}
