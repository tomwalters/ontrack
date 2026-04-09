import SwiftUI

@main
struct OnTrackApp: App {
    init() {
        BackgroundRefreshManager.shared.register()
        BackgroundRefreshManager.shared.schedule()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
