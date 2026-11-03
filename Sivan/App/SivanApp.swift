import SwiftUI

@main
struct SivanApp: App {

    @StateObject private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onOpenURL { url in
                    app.handleIncoming(url: url)
                }
        }
    }
}
