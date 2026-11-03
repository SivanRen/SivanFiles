import SwiftUI

/// 分页预览：点开文件后进入，左右滑动浏览同目录的文件。
/// 顶栏只保留「返回」与「⋯」，底栏不再显示文件列表。
/// 「⋯」打开快捷栏：文件属性 + 快捷操作（导入、图库、分享…）。
struct PagedViewer: View {

    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var items: [FileItem]
    @State private var index: Int
    @State private var showPanel = false
    @State private var toastMessage: ToastMessage?

    @State private var shareItems: [Any] = []
    @State private var showsShare = false
    @State private var infoItem: FileItem?
    @State private var confirmDelete = false

    init(request: PreviewRequest) {
        _items = State(initialValue: request.items)
        _index = State(initialValue: min(max(request.index, 0), max(request.items.count - 1, 0)))
    }

    private var current: FileItem? {
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }

    /// 当前页是不是视频：视频页由 AVKit 接管整屏，系统播放器自带顶栏
    /// （左上「播放设备/投放」、右上「音量」），我们的悬浮按钮必须让位。
    private var isVideo: Bool {
        current?.kind == .video
    }

    /// 视频页把悬浮按钮整体下移，避开系统播放器顶栏那一条的可点区域。
    /// 系统播放器的「投放 / 音量」贴着安全区顶部，这里多留一行的高度。
    private var chromeTopPadding: CGFloat {
        isVideo ? 72 : 6
    }

    var body: some View {
        // 外层 GeometryReader 本身不忽略安全区，才能拿到真实的安全区高度
        GeometryReader { proxy in
            ZStack {
                Theme.bg.ignoresSafeArea()

                TabView(selection: $index) {
                    ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
                        PreviewPage(
                            item: item,
                            isActive: offset == index,
                            topInset: proxy.safeAreaInsets.top + 46
                        )
                        .tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
                    if items.count > 1 && !isVideo {
                        pageCounter
                            .padding(.bottom, 14)
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: isVideo)

                if showPanel, let current {
                    panelLayer(for: current)
                }

                toastLayer
            }
        }
        .background(Theme.bg)
        .sheet(isPresented: $showsShare) {
            ShareSheet(items: shareItems)
        }
        .sheet(item: $infoItem) { item in
            InfoSheet(item: item)
                .environmentObject(app)
        }
        .confirmationDialog("移到“最近删除”？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("移到最近删除", role: .destructive) { deleteCurrent() }
            Button("取消", role: .cancel) {}
        } message: {
            Text(current?.name ?? "")
        }
    }

    // MARK: - 顶栏：左上返回，右上省略号
    //
    // 视频页特殊处理：系统播放器的「投放 / 音量」就在常规位置的顶栏上，
    // 这里把整行下移到它的下方（页码也顺势移到中间），避免遮挡原生按键。

    private var topBar: some View {
        HStack(spacing: 10) {
            circleButton("chevron.left") { dismiss() }

            Spacer(minLength: 8)

            if isVideo && items.count > 1 {
                pageCounter
                Spacer(minLength: 8)
            }

            circleButton("ellipsis") {
                withAnimation(.easeOut(duration: 0.2)) { showPanel = true }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, chromeTopPadding)
        .padding(.bottom, 8)
    }

    private func circleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(width: 34, height: 34)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    /// 轻量页码（不是文件列表，仅提示当前是第几个）
    private var pageCounter: some View {
        Text("\(index + 1) / \(items.count)")
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            .opacity(showPanel ? 0 : 1)
    }

    // MARK: - 快捷栏

    private func panelLayer(for item: FileItem) -> some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture { closePanel() }

            ViewerActionPanel(
                item: item,
                onClose: { closePanel() },
                onShare: {
                    shareItems = [item.url]
                    closePanel()
                    showsShare = true
                },
                onImport: {
                    closePanel()
                    app.beginImport(into: item.url.deletingLastPathComponent())
                },
                onExtract: {
                    closePanel()
                    app.extract(item, to: item.url.deletingLastPathComponent())
                },
                onDelete: {
                    closePanel()
                    confirmDelete = true
                },
                onRenamed: { newURL in
                    if items.indices.contains(index) {
                        items[index] = FileItem(url: newURL)
                    }
                },
                onShowInfo: {
                    closePanel()
                    infoItem = item
                },
                onNotify: { text, isError in
                    notify(text, isError: isError)
                }
            )
            .environmentObject(app)
            .transition(.move(edge: .bottom))
        }
    }

    private func closePanel() {
        withAnimation(.easeOut(duration: 0.2)) { showPanel = false }
    }

    // MARK: - 删除

    private func deleteCurrent() {
        guard let current else { return }
        let removedURL = current.url
        app.moveToTrash([removedURL])
        items.removeAll { $0.url == removedURL }
        if items.isEmpty {
            dismiss()
            return
        }
        index = min(index, items.count - 1)
    }

    // MARK: - 轻提示（预览页浮在最上层，用自带提示条）

    @ViewBuilder
    private var toastLayer: some View {
        if let toast = toastMessage {
            VStack {
                ToastBanner(toast: toast)
                    .padding(.top, isVideo ? 132 : 54)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .task(id: toast.id) {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                if toastMessage?.id == toast.id { toastMessage = nil }
            }
        }
    }

    private func notify(_ text: String, isError: Bool = false) {
        withAnimation(.easeOut(duration: 0.16)) {
            toastMessage = ToastMessage(text: text, isError: isError)
        }
    }
}
