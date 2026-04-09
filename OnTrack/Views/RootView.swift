import SwiftUI

enum AppTab: Hashable {
    case trains
    case settings
}

struct RootView: View {
    @State private var selectedTab: AppTab = .trains
    @StateObject private var updateManager = TrainUpdateManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selectedTab) {
            TrainTimesView()
                .tabItem {
                    Label("Trains", systemImage: "tram.fill")
                }
                .tag(AppTab.trains)

            ContentView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .onOpenURL { url in
            guard url.scheme == "ontrack" else { return }
            switch url.host {
            case "trains":
                selectedTab = .trains
            case "settings":
                selectedTab = .settings
            default:
                break
            }
        }
        .task {
            await updateManager.start()
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                Task { await updateManager.start() }
            case .background:
                updateManager.stop()
                BackgroundRefreshManager.shared.schedule()
            default:
                break
            }
        }
    }
}
