import Foundation
import UserNotifications

@MainActor
final class TrainUpdateManager: ObservableObject {
    private let interval: TimeInterval = 5 * 60
    private var timer: Timer?
    private var isChecking = false

    func start() async {
        await requestAuthorizationIfNeeded()
        scheduleTimer()
        await checkForUpdates()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.checkForUpdates() }
        }
        timer?.tolerance = 30
    }

    private func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    private func checkForUpdates() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        await TrainUpdateChecker.checkForUpdates()
    }
}
