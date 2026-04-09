import Foundation

final class ConfigStore {

    static let shared = ConfigStore()

    private let defaults: UserDefaults
    private let configKey = "commuteConfig"

    init() {
        self.defaults = UserDefaults(suiteName: "group.com.ontrack.shared") ?? .standard
    }

    var commuteConfig: CommuteConfig {
        get {
            guard let data = defaults.data(forKey: configKey),
                  let config = try? JSONDecoder().decode(CommuteConfig.self, from: data) else {
                return .default
            }
            return config
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: configKey)
            }
        }
    }

    /// Returns the active route for the given date, or nil if no commute is active.
    func activeRoute(at date: Date) -> ActiveRoute? {
        let config = commuteConfig

        guard config.isConfigured else { return nil }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        guard config.activeDays.contains(weekday) else { return nil }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        if config.morningWindow.contains(hour: hour, minute: minute) {
            return ActiveRoute(
                originCRS: config.morningWindow.originCRS.uppercased(),
                destinationCRS: config.morningWindow.destinationCRS.uppercased(),
                windowName: "Morning"
            )
        }

        if config.eveningWindow.contains(hour: hour, minute: minute) {
            return ActiveRoute(
                originCRS: config.eveningWindow.originCRS.uppercased(),
                destinationCRS: config.eveningWindow.destinationCRS.uppercased(),
                windowName: "Evening"
            )
        }

        return nil
    }
}
