import SwiftUI

struct RootView: View {

    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack(alignment: .top) {
            Theme.bg.ignoresSafeArea()

            // 顶层页面：文件浏览 ⇄ 最近删除（独立分页，滑动切换）
            ZStack(alignment: .top) {
                if app.page == .browser {
                    VStack(spacing: 0) {
                        TabStrip()
                        BrowserView(model: app.active)
                            .id(app.active.id)
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    TrashPage()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: app.page)

            if let busy = app.busyText {
                BusyOverlay(text: busy)
                    .transition(.opacity)
            }

            toastLayer
        }
        .animation(.easeInOut(duration: 0.2), value: app.busyText)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: app.toastMessage)
        .sheet(item: $app.sheet) { sheet in
            SheetRouter(sheet: sheet)
                .environmentObject(app)
        }
        .fullScreenCover(item: $app.preview) { request in
            PagedViewer(request: request)
                .environmentObject(app)
        }
    }

    @ViewBuilder
    private var toastLayer: some View {
        if let toast = app.toastMessage {
            ToastBanner(toast: toast)
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: toast.id) {
                    try? await Task.sleep(nanoseconds: 2_400_000_000)
                    app.clearToast(toast.id)
                }
        }
    }
}

// MARK: - 提示条

struct ToastBanner: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(toast.isError ? Theme.danger : Theme.success)
            Text(toast.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(Theme.elevated)
        )
        .overlay(Capsule().strokeBorder(Theme.strokeStrong, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
        .padding(.horizontal, 24)
    }
}

// MARK: - 全局忙碌遮罩

struct BusyOverlay: View {
    let text: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Theme.text)
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.strokeStrong, lineWidth: 1)
            )
        }
    }
}

// MARK: - 弹层路由

struct SheetRouter: View {
    let sheet: AppSheet

    var body: some View {
        Group {
            switch sheet {
            case .info(let item):
                InfoSheet(item: item)
            case .prompt(let kind):
                PromptSheet(kind: kind)
            case .share(let urls):
                ShareSheet(items: urls)
            case .settings:
                SettingsView()
            case .zip(let item):
                ZipBrowserView(item: item)
            case .storage:
                StorageView()
            }
        }
        .presentationBackground(Theme.bg)
    }
}
