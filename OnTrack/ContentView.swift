import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var config = ConfigStore.shared.commuteConfig
    @State private var fetchHistory: [FetchedTrainInfo] = []
    @State private var showSaveConfirmation: Bool = false
    @State private var isFetching: Bool = false
    @State private var showFetchError: Bool = false
    @State private var fetchErrorMessage: String = ""

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

                Section {
                    if fetchHistory.isEmpty {
                        Text("No recent train fetches.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(fetchHistory) { info in
                            HStack(spacing: 8) {
                                let statusLabel = info.departure.status.label
                                Text("\(info.route)")
                                    .fontWeight(.semibold)
                                Text(DateFormatting.formatTime(info.timestamp))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(info.departure.displayTime) \(statusLabel)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        }
                    }
                } header: {
                    HStack {
                        Text("Recent Train Fetches")
                        Spacer()
                        Button(isFetching ? "Fetching..." : "Fetch now") {
                            fetchNow()
                        }
                        .buttonStyle(.borderless)
                        .disabled(isFetching || !config.isConfigured)
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
            .alert("Fetch failed", isPresented: $showFetchError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(fetchErrorMessage)
            }
        }
    }

    private func save() {
        ConfigStore.shared.commuteConfig = config
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func loadFetchHistory() {
        let userDefaults = UserDefaults(suiteName: "group.com.ontrack.shared") ?? .standard

        var allHistories: [FetchedTrainInfo] = []

        let routes = [
            routeKey(for: config.morningWindow),
            routeKey(for: config.eveningWindow)
        ].compactMap { $0 }

        for route in routes {
            allHistories.append(contentsOf: userDefaults.fetchHistory(forRoute: route))
        }

        allHistories.sort { $0.timestamp > $1.timestamp }
        fetchHistory = Array(allHistories.prefix(20))
    }

    private func fetchNow() {
        let routes = configuredRoutes()
        guard !routes.isEmpty else {
            fetchErrorMessage = "Set both stations before fetching."
            showFetchError = true
            return
        }

        save()
        isFetching = true

        Task {
            defer {
                Task { @MainActor in
                    isFetching = false
                }
            }

            for route in routes {
                do {
                    _ = try await TrainService.shared.fetchNextDeparture(
                        from: route.origin,
                        to: route.destination
                    )
                } catch {
                    await MainActor.run {
                        fetchErrorMessage = error.localizedDescription
                        showFetchError = true
                    }
                    return
                }
            }

            await MainActor.run {
                loadFetchHistory()
            }
        }
    }

    private func configuredRoutes() -> [(origin: String, destination: String)] {
        let windows = [config.morningWindow, config.eveningWindow]
        var seen = Set<String>()
        var routes: [(origin: String, destination: String)] = []

        for window in windows {
            guard let parts = routeParts(for: window) else { continue }
            let key = "\(parts.origin)-\(parts.destination)"
            guard seen.insert(key).inserted else { continue }
            routes.append(parts)
        }

        return routes
    }

    private func routeParts(for window: TimeWindow) -> (origin: String, destination: String)? {
        let origin = window.originCRS.uppercased()
        let destination = window.destinationCRS.uppercased()
        guard !origin.isEmpty, !destination.isEmpty else { return nil }
        return (origin, destination)
    }

    private func routeKey(for window: TimeWindow) -> String? {
        guard let parts = routeParts(for: window) else { return nil }
        return "\(parts.origin)-\(parts.destination)"
    }
}
