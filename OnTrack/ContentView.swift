import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var config = ConfigStore.shared.commuteConfig
    @State private var fetchHistory: [FetchedTrainInfo] = []
    @State private var showSaveConfirmation: Bool = false

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

                Section("Recent Train Fetches") {
                    if fetchHistory.isEmpty {
                        Text("No recent train fetches.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(fetchHistory) { info in
                            HStack(spacing: 8) {
                                Text("\(info.route)")
                                    .fontWeight(.semibold)
                                Text(DateFormatting.formatTime(info.timestamp))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(info.departure.displayTime) \(info.status.label)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        }
                    }
                }
            }
            .navigationTitle("OnTrack")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        save()
                        showSaveConfirmation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            showSaveConfirmation = false
                        }
                    }
                }
            }
            .onChange(of: config) { _ in
                save()
                loadFetchHistory()
            }
            .onAppear {
                loadFetchHistory()
            }
            .alert("Saved!", isPresented: $showSaveConfirmation) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    private func save() {
        ConfigStore.shared.commuteConfig = config
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func loadFetchHistory() {
        let userDefaults = UserDefaults(suiteName: "group.com.ontrack.shared")

        var allHistories: [FetchedTrainInfo] = []

        let routes = [config.morningWindow.route, config.eveningWindow.route].compactMap { $0.isEmpty ? nil : $0 }

        for route in routes {
            if let data = userDefaults?.array(forKey: route) as? [Data] {
                let infos = data.compactMap { try? JSONDecoder().decode(FetchedTrainInfo.self, from: $0) }
                allHistories.append(contentsOf: infos)
            }
        }

        allHistories.sort { $0.timestamp > $1.timestamp }
        fetchHistory = Array(allHistories.prefix(20))
    }
}
