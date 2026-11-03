import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var app: AppModel
    @ObservedObject private var settings = AppSettings.shared

    @State private var confirmEmptyTrash = false
    @State private var confirmClearCache = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "设置")

            ScrollView {
                VStack(spacing: 16) {
                    PanelGroup("浏览") {
                        PanelRow(title: "显示隐藏文件", subtitle: "以 . 开头的文件与文件夹") {
                            Toggle("", isOn: $settings.showHidden)
                                .labelsHidden()
                                .tint(Theme.accent)
                                .onChange(of: settings.showHidden) { _, value in
                                    for tab in app.tabs { tab.showHidden = value }
                                    app.reloadAll()
                                }
                        }
                        Hairline().padding(.leading, 14)
                        PanelRow(title: "文件夹优先", subtitle: "排序时始终把文件夹排在前面") {
                            Toggle("", isOn: $settings.foldersFirst)
                                .labelsHidden()
                                .tint(Theme.accent)
                                .onChange(of: settings.foldersFirst) { _, value in
                                    for tab in app.tabs { tab.foldersFirst = value }
                                }
                        }
                        Hairline().padding(.leading, 14)
                        PanelRow(title: "默认排序", subtitle: settings.sortKey.title) {
                            Menu {
                                ForEach(SortKey.allCases) { key in
                                    Button(key.title) {
                                        settings.sortKey = key
                                        for tab in app.tabs { tab.sortKey = key }
                                    }
                                }
                            } label: {
                                Text(settings.sortKey.title)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        Hairline().padding(.leading, 14)
                        PanelRow(title: "默认视图") {
                            Picker("", selection: $settings.layout) {
                                Text("列表").tag(LayoutMode.list)
                                Text("网格").tag(LayoutMode.grid)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 130)
                            .onChange(of: settings.layout) { _, value in
                                for tab in app.tabs { tab.layout = value }
                            }
                        }
                    }

                    PanelGroup("阅读") {
                        PanelRow(title: "代码字号", subtitle: "\(Int(settings.codeFontSize)) pt") {
                            Stepper(
                                "",
                                onIncrement: { settings.codeFontSize = min(26, settings.codeFontSize + 1) },
                                onDecrement: { settings.codeFontSize = max(10, settings.codeFontSize - 1) }
                            )
                            .labelsHidden()
                        }
                    }

                    PanelGroup("维护") {
                        Button {
                            confirmClearCache = true
                        } label: {
                            PanelRow(title: "清空缩略图缓存", subtitle: "释放内存与磁盘预览缓存") {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)

                        Hairline().padding(.leading, 14)

                        Button {
                            confirmEmptyTrash = true
                        } label: {
                            PanelRow(title: "清空最近删除", subtitle: "释放被回收站占用的空间") {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    PanelGroup("关于") {
                        PanelRow(title: "Sivan", subtitle: "文件管理器")
                        Hairline().padding(.leading, 14)
                        PanelRow(title: "版本", subtitle: appVersion)
                        Hairline().padding(.leading, 14)
                        PanelRow(title: "Bundle ID", subtitle: "com.sivan.files")
                        Hairline().padding(.leading, 14)
                        PanelRow(title: "文件位置", subtitle: "~/Documents（可在「文件」App 的“我的 iPhone”里访问）")
                    }

                    Text("所有文件保存在应用沙盒内，支持通过「文件」App、iTunes 文件共享、其他 App 的“用其他应用打开”导入。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 26)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.bg)
        .confirmationDialog("清空最近删除？", isPresented: $confirmEmptyTrash, titleVisibility: .visible) {
            Button("清空", role: .destructive) { app.emptyTrash() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("该操作不可恢复")
        }
        .confirmationDialog("清空缩略图缓存？", isPresented: $confirmClearCache, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                ThumbnailService.shared.clear()
                app.toast("缓存已清空")
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
