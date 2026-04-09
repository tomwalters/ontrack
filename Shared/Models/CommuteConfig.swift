import Foundation

struct CommuteConfig: Codable, Equatable {
    var morningWindow: TimeWindow
    var eveningWindow: TimeWindow
    var activeDays: Set<Int> // 1=Sunday, 2=Monday, ... 7=Saturday (Calendar.weekday)
    var walkingTimeMinutes: Int

    static let `default` = CommuteConfig(
        morningWindow: TimeWindow(
            startHour: 6, startMinute: 0,
            endHour: 10, endMinute: 0,
            originCRS: "", destinationCRS: ""
        ),
        eveningWindow: TimeWindow(
            startHour: 16, startMinute: 0,
            endHour: 20, endMinute: 0,
            originCRS: "", destinationCRS: ""
        ),
        activeDays: [2, 3, 4, 5, 6], // Monday to Friday
        walkingTimeMinutes: 15
    )

    var isConfigured: Bool {
        !morningWindow.originCRS.isEmpty &&
        !morningWindow.destinationCRS.isEmpty &&
        !eveningWindow.originCRS.isEmpty &&
        !eveningWindow.destinationCRS.isEmpty
    }
}

struct TimeWindow: Codable, Equatable {
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var originCRS: String
    var destinationCRS: String

    func contains(hour: Int, minute: Int) -> Bool {
        let timeValue = hour * 60 + minute
        let startValue = startHour * 60 + startMinute
        let endValue = endHour * 60 + endMinute
        return timeValue >= startValue && timeValue < endValue
    }
}

struct ActiveRoute {
    let originCRS: String
    let destinationCRS: String
    let windowName: String
}
