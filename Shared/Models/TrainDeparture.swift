import Foundation

struct TrainDeparture: Codable, Equatable {
    let scheduledTime: Date
    let expectedTime: Date
    let status: TrainStatus

    var displayTime: String {
        DateFormatting.formatTime(expectedTime)
    }

    var scheduledDisplayTime: String {
        DateFormatting.formatTime(scheduledTime)
    }
}

enum TrainStatus: Codable, Equatable {
    case onTime
    case delayed(minutes: Int)
    case cancelled
    case unknown

    var label: String {
        switch self {
        case .onTime:
            return "On time"
        case .delayed(let minutes):
            return "+\(minutes)m late"
        case .cancelled:
            return "Cancelled"
        case .unknown:
            return "Unknown"
        }
    }

    var shortLabel: String {
        switch self {
        case .onTime:
            return "On time"
        case .delayed(let minutes):
            return "+\(minutes)m"
        case .cancelled:
            return "Canc."
        case .unknown:
            return "?"
        }
    }

    var symbolName: String {
        switch self {
        case .onTime:
            return "checkmark.circle.fill"
        case .delayed:
            return "exclamationmark.triangle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
}
