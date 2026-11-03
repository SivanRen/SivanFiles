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
    @State private var counterVisible = false
    @State private var toastMessage: ToastMessage?

    @State private var shareItems: [Any] = []
    @State private var showsShare = false
    @State private var infoItem: FileItem?
    @State private var confirmDelete = false

    /// 阅读类内容的搜索状态（文本 / 源码 / HTML 源码共用）
    @StateObject private var search = ContentSearchStore()
    /// 网页 / 源码切换状态：顶栏「⋯」和页面本体共享
    @StateObject private var webSource = WebSourceStore()
    @FocusState private var searchFocused: Bool

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

    /// 只有能当文本读的内容才给搜索入口
    private var canSearch: Bool {
        guard let kind = current?.kind else { return false }
        return kind == .text || kind == .code || kind == .html
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
                        .environmentObject(search)
                        .environmentObject(webSource)
                        .tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    if search.isActive && canSearch {
                        searchHeader
                            .transition(.opacity)
                    } else {
                        topBar
                    }
                    Spacer(minLength: 0)
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
        .onChange(of: search.isActive) { _, active in
            guard active else {
                searchFocused = false
                return
            }
            // 输入框刚插入视图，等一帧再抢焦点
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                searchFocused = true
            }
        }
        .onChange(of: search.showList) { _, open in
            if open { searchFocused = false }
        }
        .onChange(of: index) { _, _ in
            // 换到另一个文件：旧结果作废，关键词保留给新文件继续搜
            search.matches = []
            search.current = 0
            search.errorText = nil
            search.showList = false
            search.revision += 1
            if !canSearch { search.close() }
        }
    }

    // MARK: - 搜索栏（占据顶栏位置）
    //
    // 整块压在内容上方：底衬用模糊材质 + 一层背景色，源码再密也不会透上来干扰阅读。

    private var searchHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)

                    TextField("搜索内容", text: $search.query)
                        .focused($searchFocused)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.text)
                        .tint(Theme.accent)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.search)

                    if !search.query.isEmpty {
                        Button {
                            search.query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Capsule().fill(Theme.veil(0.06)))
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))

                Button {
                    closeSearch()
                } label: {
                    Text("取消")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                SearchOptionChip(title: "Aa 大小写", isOn: search.options.caseSensitive) {
                    search.options.caseSensitive.toggle()
                }
                SearchOptionChip(title: "全字匹配", isOn: search.options.wholeWord) {
                    search.options.wholeWord.toggle()
                }
                SearchOptionChip(title: "正则 .*", isOn: search.options.useRegex) {
                    search.options.useRegex.toggle()
                }

                Spacer(minLength: 6)

                searchStatus
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background {
            ZStack {
                Rectangle().fill(.regularMaterial)
                Rectangle().fill(Theme.bg.opacity(0.62))
            }
            .overlay(alignment: .bottom) { Hairline() }
            .ignoresSafeArea(edges: .top)
        }
    }

    @ViewBuilder
    private var searchStatus: some View {
        if let error = search.errorText {
            statusBadge(error, tint: Theme.danger)
        } else if !search.query.isEmpty {
            if search.matches.isEmpty {
                statusBadge("无结果", tint: Theme.textTertiary)
            } else {
                statusBadge(
                    "\(search.current + 1)/\(search.matches.count)",
                    tint: Theme.textSecondary,
                    mono: true
                )
            }
        }
    }

    private func statusBadge(_ text: String, tint: Color, mono: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: mono ? .monospaced : .default))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.veil(0.06)))
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private func openSearch() {
        withAnimation(.easeOut(duration: 0.18)) { search.open() }
    }

    private func closeSearch() {
        searchFocused = false
        withAnimation(.easeOut(duration: 0.18)) { search.close() }
    }

    // MARK: - 顶栏：左上返回，右上省略号
    //
    // 底栏不再显示任何内容（不列最近打开的文件），页码只在切换/刚打开时
    // 于顶栏中间短暂浮现一下就淡出，不长期占版面。
    // 视频页特殊处理：系统播放器的「投放 / 音量」就在常规位置的顶栏上，
    // 这里把整行下移到它的下方，避免遮挡原生按键。

    private var topBar: some View {
        HStack(spacing: 10) {
            circleButton("chevron.left") { dismiss() }

            Spacer(minLength: 8)

            if canSearch {
                circleButton("magnifyingglass") { openSearch() }
            }

            circleButton("ellipsis") {
                withAnimation(.easeOut(duration: 0.2)) { showPanel = true }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, chromeTopPadding)
        .padding(.bottom, 8)
        .overlay {
            // 页码用 overlay 严格居中：左右按钮数量不同（返回一个、右侧一或两个）
            // 时，夹在 HStack 里会被挤偏，overlay 始终钉在顶栏正中。
            if items.count > 1 {
                pageCounter
                    .opacity(counterVisible && !showPanel ? 1 : 0)
                    .allowsHitTesting(false)
            }
        }
        .task(id: index) {
            guard items.count > 1 else { return }
            withAnimation(.easeOut(duration: 0.15)) { counterVisible = true }
            do {
                try await Task.sleep(nanoseconds: 1_400_000_000)
            } catch {
                return
            }
            withAnimation(.easeOut(duration: 0.35)) { counterVisible = false }
        }
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

    /// 轻量页码（不是文件列表，仅提示当前是同类型文件里的第几个）
    private var pageCounter: some View {
        Text("\(index + 1) / \(items.count)")
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
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
            .environmentObject(webSource)
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
