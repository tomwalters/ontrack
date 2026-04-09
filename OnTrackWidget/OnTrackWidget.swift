import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct TrainEntry: TimelineEntry {
    let date: Date
    let departures: [TrainDeparture]
    let isActive: Bool
    let errorMessage: String?
    let inactiveMessage: String?

    static let placeholder = TrainEntry(
        date: .now,
        departures: [
            TrainDeparture(
                scheduledTime: .now,
                expectedTime: .now,
                status: .onTime
            ),
            TrainDeparture(
                scheduledTime: .now.addingTimeInterval(15 * 60),
                expectedTime: .now.addingTimeInterval(18 * 60),
                status: .delayed(minutes: 3)
            )
        ],
        isActive: true,
        errorMessage: nil,
        inactiveMessage: nil
    )

    static func inactive(message: String) -> TrainEntry {
        TrainEntry(
            date: .now,
            departures: [],
            isActive: false,
            errorMessage: nil,
            inactiveMessage: message
        )
    }
}

// MARK: - Timeline Provider

struct TrainTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> TrainEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TrainEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        fetchEntry { entry in
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrainEntry>) -> Void) {
        fetchEntry { entry in
            // Refresh every 15 minutes when active, every 30 minutes when inactive
            let refreshInterval: TimeInterval = entry.isActive ? 15 * 60 : 30 * 60
            let refreshDate = Date().addingTimeInterval(refreshInterval)
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }

    private func fetchEntry(completion: @escaping (TrainEntry) -> Void) {
        guard let route = ConfigStore.shared.activeRoute(at: .now) else {
            completion(.inactive(message: inactiveMessage(for: .now)))
            return
        }

        Task {
            do {
                let departures = try await TrainService.shared.fetchDepartures(
                    from: route.originCRS,
                    to: route.destinationCRS
                )
                let entry = TrainEntry(
                    date: .now,
                    departures: Array(departures.prefix(2)),
                    isActive: true,
                    errorMessage: nil,
                    inactiveMessage: nil
                )
                completion(entry)
            } catch {
                let entry = TrainEntry(
                    date: .now,
                    departures: [],
                    isActive: true,
                    errorMessage: "Unable to load",
                    inactiveMessage: nil
                )
                completion(entry)
            }
        }
    }

    private func inactiveMessage(for date: Date) -> String {
        let messages = [
            "No trains needed. Enjoy the calm.",
            "Commuter mode off. Stay put.",
            "No rails required right now.",
            "Your next train is called a couch.",
            "Today is a stay-put day.",
            "No rush. The platform can wait."
        ]
        let interval = 30.0 * 60.0
        let index = Int(date.timeIntervalSinceReferenceDate / interval) % messages.count
        return messages[index]
    }
}

// MARK: - Widget Views

struct RectangularWidgetView: View {
    let entry: TrainEntry

    var body: some View {
        if !entry.isActive {
            inactiveView(entry.inactiveMessage)
        } else if !entry.departures.isEmpty {
            departuresView(entry.departures)
        } else {
            errorView
        }
    }

    private func inactiveView(_ message: String?) -> some View {
        HStack {
            Image(systemName: "tram.fill")
            Text(message ?? "No trains today")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    private func departuresView(_ departures: [TrainDeparture]) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "tram.fill")
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                departureRow(label: "Next", departure: departures[0])
                if departures.count > 1 {
                    departureRow(label: "Then", departure: departures[1])
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func departureRow(label: String, departure: TrainDeparture) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
            Text(departure.displayTime)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
            Text(departure.status.shortLabel)
                .font(.caption2)
                .foregroundStyle(statusColor(for: departure.status))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
        }
    }

    private var errorView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
            Text("Unable to load")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    private func statusColor(for status: TrainStatus) -> HierarchicalShapeStyle {
        switch status {
        case .onTime:
            return .primary
        case .delayed, .cancelled:
            return .primary
        case .unknown:
            return .secondary
        }
    }
}

struct InlineWidgetView: View {
    let entry: TrainEntry

    var body: some View {
        if !entry.isActive {
            Text(entry.inactiveMessage ?? "No trains today")
        } else if let first = entry.departures.first {
            if entry.departures.count > 1 {
                Text("\(Image(systemName: "tram.fill")) \(first.displayTime) then \(entry.departures[1].displayTime)")
            } else {
                switch first.status {
                case .onTime:
                    Text("\(Image(systemName: "tram.fill")) \(first.displayTime) On time")
                case .delayed(let minutes):
                    Text("\(Image(systemName: "tram.fill")) \(first.displayTime) +\(minutes)m")
                case .cancelled:
                    Text("\(Image(systemName: "tram.fill")) \(first.scheduledDisplayTime) Canc.")
                case .unknown:
                    Text("\(Image(systemName: "tram.fill")) \(first.displayTime)")
                }
            }
        } else {
            Text("\(Image(systemName: "exclamationmark.triangle")) Trains unavailable")
        }
    }
}

struct CircularWidgetView: View {
    let entry: TrainEntry

    var body: some View {
        if !entry.isActive {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "tram.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        } else if let departure = entry.departures.first {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "tram.fill")
                        .font(.caption2)
                    Text(departure.displayTime)
                        .font(.body)
                        .fontWeight(.bold)
                        .minimumScaleFactor(0.8)
                }
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "exclamationmark.triangle")
                    .font(.title3)
            }
        }
    }
}

struct SmallWidgetView: View {
    let entry: TrainEntry

    var body: some View {
        if !entry.isActive {
            inactiveView(entry.inactiveMessage)
        } else if !entry.departures.isEmpty {
            departuresView(entry.departures)
        } else {
            errorView
        }
    }

    private func inactiveView(_ message: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "tram.fill")
                .foregroundStyle(.secondary)
            Text(message ?? "No trains today")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func departuresView(_ departures: [TrainDeparture]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            departureBlock(label: "Next", departure: departures[0])
            if departures.count > 1 {
                departureBlock(label: "Then", departure: departures[1])
            }
            Spacer()
        }
    }

    private func departureBlock(label: String, departure: TrainDeparture) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(departure.displayTime)
                .font(.headline)
                .fontWeight(.bold)
            Text(departure.status.shortLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var errorView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
            Text("Unable to load")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct MediumWidgetView: View {
    let entry: TrainEntry

    var body: some View {
        if !entry.isActive {
            inactiveView(entry.inactiveMessage)
        } else if !entry.departures.isEmpty {
            departuresView(entry.departures)
        } else {
            errorView
        }
    }

    private func inactiveView(_ message: String?) -> some View {
        HStack {
            Image(systemName: "tram.fill")
                .foregroundStyle(.secondary)
            Text(message ?? "No trains today")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func departuresView(_ departures: [TrainDeparture]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "tram.fill")
                Text("Next trains")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                departureColumn(label: "Next", departure: departures[0])
                if departures.count > 1 {
                    departureColumn(label: "Then", departure: departures[1])
                } else {
                    Spacer()
                }
            }
        }
    }

    private func departureColumn(label: String, departure: TrainDeparture) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(departure.displayTime)
                .font(.title3)
                .fontWeight(.bold)
            Text(departure.status.shortLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var errorView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
            Text("Unable to load")
                .font(.caption)
            Spacer()
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Widget Definition

struct OnTrackWidget: Widget {
    let kind = "OnTrackWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrainTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                WidgetContentView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                WidgetContentView(entry: entry)
            }
        }
        .configurationDisplayName("Next Train")
        .description("Shows your next train departure with live status.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular
        ])
    }
}

struct WidgetContentView: View {
    @Environment(\.widgetFamily) var family
    let entry: TrainEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .accessoryRectangular:
                RectangularWidgetView(entry: entry)
            case .accessoryInline:
                InlineWidgetView(entry: entry)
            case .accessoryCircular:
                CircularWidgetView(entry: entry)
            default:
                RectangularWidgetView(entry: entry)
            }
        }
        .widgetURL(URL(string: "ontrack://trains")!)
    }
}

// MARK: - Previews

#if DEBUG
struct OnTrackWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RectangularWidgetView(entry: TrainEntry(
                date: .now,
                departures: [
                    TrainDeparture(
                        scheduledTime: .now.addingTimeInterval(20 * 60),
                        expectedTime: .now.addingTimeInterval(23 * 60),
                        status: .delayed(minutes: 3)
                    ),
                    TrainDeparture(
                        scheduledTime: .now.addingTimeInterval(35 * 60),
                        expectedTime: .now.addingTimeInterval(35 * 60),
                        status: .onTime
                    )
                ],
                isActive: true,
                errorMessage: nil,
                inactiveMessage: nil
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Rectangular - Delayed")

            RectangularWidgetView(entry: .inactive(message: "No trains needed. Enjoy the calm."))
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Rectangular - Inactive")

            SmallWidgetView(entry: TrainEntry(
                date: .now,
                departures: [
                    TrainDeparture(
                        scheduledTime: .now.addingTimeInterval(12 * 60),
                        expectedTime: .now.addingTimeInterval(12 * 60),
                        status: .onTime
                    ),
                    TrainDeparture(
                        scheduledTime: .now.addingTimeInterval(26 * 60),
                        expectedTime: .now.addingTimeInterval(28 * 60),
                        status: .delayed(minutes: 2)
                    )
                ],
                isActive: true,
                errorMessage: nil,
                inactiveMessage: nil
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small - Next Two")

            MediumWidgetView(entry: TrainEntry(
                date: .now,
                departures: [
                    TrainDeparture(
                        scheduledTime: .now.addingTimeInterval(8 * 60),
                        expectedTime: .now.addingTimeInterval(10 * 60),
                        status: .delayed(minutes: 2)
                    ),
                    TrainDeparture(
                        scheduledTime: .now.addingTimeInterval(22 * 60),
                        expectedTime: .now.addingTimeInterval(22 * 60),
                        status: .onTime
                    )
                ],
                isActive: true,
                errorMessage: nil,
                inactiveMessage: nil
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium - Next Two")

            CircularWidgetView(entry: TrainEntry(
                date: .now,
                departures: [
                    TrainDeparture(
                        scheduledTime: .now.addingTimeInterval(20 * 60),
                        expectedTime: .now.addingTimeInterval(20 * 60),
                        status: .onTime
                    )
                ],
                isActive: true,
                errorMessage: nil,
                inactiveMessage: nil
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular - On Time")
        }
    }
}
#endif
