import SwiftUI
import WidgetKit

struct TrainTimesView: View {
    @State private var config = ConfigStore.shared.commuteConfig
    @State private var routeDepartures: [RouteDepartures] = []
    @State private var isFetching = false
    @State private var showFetchError = false
    @State private var fetchErrorMessage = ""

    var body: some View {
        NavigationStack {
            List {
                if !config.isConfigured {
                    Section {
                        Label("Set your stations in Settings to get started.", systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                } else if routeDepartures.isEmpty {
                    Text("No train times yet. Pull to refresh or tap Fetch.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(routeDepartures) { route in
                        Section(route.title) {
                            if route.departures.isEmpty {
                                Text("No departures found.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(route.departures.indices, id: \.self) { index in
                                    let departure = route.departures[index]
                                    HStack {
                                        Text(index == 0 ? "Next" : "Then")
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(departure.displayTime)
                                            .fontWeight(.semibold)
                                        Text(departure.status.shortLabel)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trains")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isFetching ? "Fetching..." : "Fetch") {
                        refresh()
                    }
                    .disabled(isFetching || !config.isConfigured)
                }
            }
            .refreshable {
                await fetchDepartures()
            }
            .onAppear {
                refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                config = ConfigStore.shared.commuteConfig
            }
            .alert("Fetch failed", isPresented: $showFetchError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(fetchErrorMessage)
            }
        }
    }

    private func refresh() {
        Task {
            await fetchDepartures()
        }
    }

    @MainActor
    private func fetchDepartures() async {
        config = ConfigStore.shared.commuteConfig
        let routes = configuredRoutes()
        guard !routes.isEmpty else {
            routeDepartures = []
            return
        }

        isFetching = true
        defer { isFetching = false }

        var newDepartures: [RouteDepartures] = []
        for route in routes {
            do {
                let departures = try await TrainService.shared.fetchDepartures(
                    from: route.origin,
                    to: route.destination
                )
                newDepartures.append(RouteDepartures(
                    id: route.id,
                    title: route.title,
                    departures: Array(departures.prefix(2))
                ))
            } catch {
                fetchErrorMessage = error.localizedDescription
                showFetchError = true
                return
            }
        }

        routeDepartures = newDepartures
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func configuredRoutes() -> [RouteInfo] {
        let windows: [TimeWindow] = [
            config.morningWindow,
            config.eveningWindow
        ]

        var seen = Set<String>()
        var routes: [RouteInfo] = []

        for window in windows {
            guard let parts = routeParts(for: window) else { continue }
            let id = "\(parts.origin)-\(parts.destination)"
            guard seen.insert(id).inserted else { continue }
            routes.append(RouteInfo(
                id: id,
                title: "\(parts.origin) -> \(parts.destination)",
                origin: parts.origin,
                destination: parts.destination
            ))
        }

        return routes
    }

    private func routeParts(for window: TimeWindow) -> (origin: String, destination: String)? {
        let origin = window.originCRS.uppercased()
        let destination = window.destinationCRS.uppercased()
        guard !origin.isEmpty, !destination.isEmpty else { return nil }
        return (origin, destination)
    }
}

private struct RouteInfo {
    let id: String
    let title: String
    let origin: String
    let destination: String
}

private struct RouteDepartures: Identifiable {
    let id: String
    let title: String
    let departures: [TrainDeparture]
}
