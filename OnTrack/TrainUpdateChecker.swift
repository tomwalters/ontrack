import Foundation
import UserNotifications

struct TrainUpdateChecker {
    private static let defaults = UserDefaults(suiteName: "group.com.ontrack.shared") ?? .standard

    static func checkForUpdates() async {
        guard !Task.isCancelled else { return }
        guard let route = ConfigStore.shared.activeRoute(at: .now) else { return }

        do {
            let departures = try await TrainService.shared.fetchDepartures(
                from: route.originCRS,
                to: route.destinationCRS
            )
            guard !Task.isCancelled else { return }
            guard let next = departures.first(where: { $0.status != .cancelled }) ?? departures.first else {
                return
            }

            let routeKey = "\(route.originCRS)-\(route.destinationCRS)"
            if let previous = loadLastDeparture(for: routeKey), shouldNotify(previous: previous, current: next) {
                await sendNotification(routeKey: routeKey, previous: previous, current: next)
            }
            saveDeparture(next, for: routeKey)
        } catch {
            return
        }
    }

    private static func shouldNotify(previous: TrainDeparture, current: TrainDeparture) -> Bool {
        guard previous.scheduledTime == current.scheduledTime else { return false }
        return previous.expectedTime != current.expectedTime || previous.status != current.status
    }

    private static func sendNotification(routeKey: String, previous: TrainDeparture, current: TrainDeparture) async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Train update \(routeKey)"
        content.body = notificationBody(previous: previous, current: current)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "train-update-\(routeKey)",
            content: content,
            trigger: nil
        )

        _ = try? await center.add(request)
    }

    private static func notificationBody(previous: TrainDeparture, current: TrainDeparture) -> String {
        let previousTime = DateFormatting.formatTime(previous.expectedTime)
        let currentTime = DateFormatting.formatTime(current.expectedTime)

        switch current.status {
        case .cancelled:
            return "Next train cancelled (was \(previousTime))."
        case .delayed:
            if previous.expectedTime != current.expectedTime {
                return "Next train moved from \(previousTime) to \(currentTime)."
            }
            return "Next train status: \(current.status.label)."
        case .onTime, .unknown:
            if previous.expectedTime != current.expectedTime {
                return "Next train moved from \(previousTime) to \(currentTime)."
            }
            return "Next train status: \(current.status.label)."
        }
    }

    private static func loadLastDeparture(for routeKey: String) -> TrainDeparture? {
        guard let data = defaults.data(forKey: lastDepartureKey(routeKey)) else { return nil }
        return try? JSONDecoder().decode(TrainDeparture.self, from: data)
    }

    private static func saveDeparture(_ departure: TrainDeparture, for routeKey: String) {
        let data = try? JSONEncoder().encode(departure)
        defaults.set(data, forKey: lastDepartureKey(routeKey))
    }

    private static func lastDepartureKey(_ routeKey: String) -> String {
        "lastDeparture_\(routeKey)"
    }
}
