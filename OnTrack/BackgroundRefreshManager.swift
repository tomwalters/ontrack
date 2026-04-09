import BackgroundTasks
import Foundation

final class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()
    static let taskIdentifier = "com.ontrack.refresh"

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handle(refreshTask)
        }
    }

    func schedule() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            return
        }
    }

    private func handle(_ task: BGAppRefreshTask) {
        schedule()

        let taskHandle = Task {
            await TrainUpdateChecker.checkForUpdates()
        }

        task.expirationHandler = {
            taskHandle.cancel()
        }

        Task {
            _ = await taskHandle.result
            task.setTaskCompleted(success: !taskHandle.isCancelled)
        }
    }
}
