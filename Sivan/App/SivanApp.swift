import SwiftUI

@main
struct SivanApp: App {

    @StateObject private var app = AppModel()
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                // 外观三态：跟随系统 / 浅色 / 深色。
                // Theme 里全部是动态色，切换后整棵视图树立刻重新取色。
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(Theme.accent)
                .onOpenURL { url in
                    app.handleIncoming(url: url)
                }
        }
    }
}
