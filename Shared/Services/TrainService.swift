import Foundation

enum TrainServiceError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
    case httpError(Int)
    case noDepartures

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data received"
        case .decodingError: return "Failed to decode response"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .httpError(let code): return "HTTP error: \(code)"
        case .noDepartures: return "No departures found"
        }
    }
}

actor TrainService {

    static let shared = TrainService()

    private let endpoint = URL(string: "https://jpservices.nationalrail.co.uk/journey-planner")!

    private var headers: [String: String] {
        [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Origin": "https://www.nationalrail.co.uk",
            "Referer": "https://www.nationalrail.co.uk/",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "x-jp-platform": "web"
        ]
    }

    func fetchDepartures(from originCRS: String, to destinationCRS: String) async throws -> [TrainDeparture] {
        let request = JourneyRequest(originCRS: originCRS, destinationCRS: destinationCRS)
        let body = try JSONEncoder().encode(request)

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = body
        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TrainServiceError.noData
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TrainServiceError.httpError(httpResponse.statusCode)
        }

        let journeyResponse: JourneyResponse
        do {
            journeyResponse = try JSONDecoder().decode(JourneyResponse.self, from: data)
        } catch {
            throw TrainServiceError.decodingError
        }

        guard let journeys = journeyResponse.outwardJourneys, !journeys.isEmpty else {
            throw TrainServiceError.noDepartures
        }

        let departures = journeys.prefix(4).compactMap { journey -> TrainDeparture? in
            parseDeparture(from: journey)
        }

        return departures
    }

    func fetchNextDeparture(from originCRS: String, to destinationCRS: String) async throws -> TrainDeparture {
        let departures = try await fetchDepartures(from: originCRS, to: destinationCRS)
        // Skip cancelled trains and find the next actual departure
        if let next = departures.first(where: { $0.status != .cancelled }) {
            let defaults = UserDefaults(suiteName: "group.com.ontrack.shared") ?? .standard
            defaults.set(Date().timeIntervalSince1970, forKey: "lastFetchDate")

            let routeKey = "\(originCRS.uppercased())-\(destinationCRS.uppercased())"
            let record = FetchedTrainInfo(route: routeKey, timestamp: Date(), departure: next)
            let historyDefaults = UserDefaults(suiteName: "group.com.ontrack.shared") ?? .standard
            var history = historyDefaults.fetchHistory(forRoute: routeKey)
            history.insert(record, at: 0)
            if history.count > 10 { history = Array(history.prefix(10)) }
            historyDefaults.saveHistory(history, forRoute: routeKey)

            return next
        }
        if let first = departures.first {
            let defaults = UserDefaults(suiteName: "group.com.ontrack.shared") ?? .standard
            defaults.set(Date().timeIntervalSince1970, forKey: "lastFetchDate")

            let routeKey = "\(originCRS.uppercased())-\(destinationCRS.uppercased())"
            let record = FetchedTrainInfo(route: routeKey, timestamp: Date(), departure: first)
            let historyDefaults = UserDefaults(suiteName: "group.com.ontrack.shared") ?? .standard
            var history = historyDefaults.fetchHistory(forRoute: routeKey)
            history.insert(record, at: 0)
            if history.count > 10 { history = Array(history.prefix(10)) }
            historyDefaults.saveHistory(history, forRoute: routeKey)

            return first
        }
        throw TrainServiceError.noDepartures
    }

    private func parseDeparture(from journey: Journey) -> TrainDeparture? {
        guard let timetable = journey.timetable,
              let scheduled = timetable.scheduled,
              let scheduledDepartureStr = scheduled.departure,
              let scheduledDate = DateFormatting.parseISO8601(scheduledDepartureStr) else {
            return nil
        }

        let realtimeDate: Date
        if let realtime = timetable.realtime,
           let realtimeDepartureStr = realtime.departure,
           let parsed = DateFormatting.parseISO8601(realtimeDepartureStr) {
            realtimeDate = parsed
        } else {
            realtimeDate = scheduledDate
        }

        let status = parseStatus(journey.status, delayMinutes: journey.delayInMinutes)

        return TrainDeparture(
            scheduledTime: scheduledDate,
            expectedTime: realtimeDate,
            status: status
        )
    }

    private func parseStatus(_ statusString: String?, delayMinutes: Int?) -> TrainStatus {
        guard let statusString = statusString?.lowercased() else {
            return .unknown
        }
        switch statusString {
        case "ontime", "on time":
            return .onTime
        case "delayed":
            return .delayed(minutes: delayMinutes ?? 0)
        case "cancelled":
            return .cancelled
        default:
            return .unknown
        }
    }
}
