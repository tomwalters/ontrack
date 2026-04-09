// FetchedTrainInfo.swift
// Stores information about each train info fetch
import Foundation

struct FetchedTrainInfo: Codable, Identifiable, Equatable {
    let id: UUID
    let route: String // e.g., "AAA-BBB"
    let timestamp: Date
    let departure: TrainDeparture
    
    init(route: String, timestamp: Date = Date(), departure: TrainDeparture) {
        self.id = UUID()
        self.route = route
        self.timestamp = timestamp
        self.departure = departure
    }
}

// Helper to encode/decode history arrays in UserDefaults
extension UserDefaults {
    func fetchHistory(forRoute route: String) -> [FetchedTrainInfo] {
        guard let data = data(forKey: "history_\(route)") else { return [] }
        return (try? JSONDecoder().decode([FetchedTrainInfo].self, from: data)) ?? []
    }
    func saveHistory(_ history: [FetchedTrainInfo], forRoute route: String) {
        let data = try? JSONEncoder().encode(history)
        set(data, forKey: "history_\(route)")
    }
}
