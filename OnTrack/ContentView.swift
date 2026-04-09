import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var config = ConfigStore.shared.commuteConfig

    var body: some View {
        NavigationStack {
            Form {
                if !config.isConfigured {
                    Section {
                        Label("Set your stations below to get started.", systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Morning Commute") {
                    CommuteConfigView(window: $config.morningWindow, label: "Morning")
                }

                Section("Evening Commute") {
                    CommuteConfigView(window: $config.eveningWindow, label: "Evening")
                }

                Section("Active Days") {
                    DayPickerView(activeDays: $config.activeDays)
                }
            }
            .navigationTitle("OnTrack")
            .onChange(of: config) { _ in
                save()
            }
        }
    }

    private func save() {
        ConfigStore.shared.commuteConfig = config
        WidgetCenter.shared.reloadAllTimelines()
    }
}
