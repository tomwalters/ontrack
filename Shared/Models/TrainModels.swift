import Foundation

// MARK: - Request Models

struct JourneyRequest: Codable {
    let origin: StationRequest
    let destination: StationRequest
    let outwardTime: OutwardTime
    let fareRequestDetails: FareRequestDetails
    let directTrains: Bool
    let reducedTransferTime: Bool
    let onlySearchForSleeper: Bool
    let overtakenTrains: Bool
    let useAlternativeServices: Bool
    let increasedInterchange: String

    init(originCRS: String, destinationCRS: String, departureDate: Date = Date()) {
        self.origin = StationRequest(crsCode: originCRS, isGroup: false)
        self.destination = StationRequest(crsCode: destinationCRS, isGroup: false)
        self.outwardTime = OutwardTime(
            travelTime: DateFormatting.formatISO8601(departureDate),
            type: "DEPART"
        )
        self.fareRequestDetails = FareRequestDetails(
            passengers: Passengers(adults: 1, children: 0),
            fareClass: "ANY",
            railcards: []
        )
        self.directTrains = false
        self.reducedTransferTime = false
        self.onlySearchForSleeper = false
        self.overtakenTrains = true
        self.useAlternativeServices = false
        self.increasedInterchange = "ZERO"
    }
}

struct StationRequest: Codable {
    let crsCode: String
    let isGroup: Bool
}

struct OutwardTime: Codable {
    let travelTime: String
    let type: String
}

struct FareRequestDetails: Codable {
    let passengers: Passengers
    let fareClass: String
    let railcards: [String]
}

struct Passengers: Codable {
    let adults: Int
    let children: Int
}

// MARK: - Response Models

struct JourneyResponse: Codable {
    let outwardJourneys: [Journey]?
}

struct Journey: Codable {
    let status: String?
    let delayInMinutes: Int?
    let timetable: Timetable?
}

struct Timetable: Codable {
    let scheduled: TimeInfo?
    let realtime: TimeInfo?
}

struct TimeInfo: Codable {
    let departure: String?
    let arrival: String?
}
