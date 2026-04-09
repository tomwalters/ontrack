import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct TrainEntry: TimelineEntry {
    let date: Date
    let departure: TrainDeparture?
    let isActive: Bool
    let errorMessage: String?

    static let placeholder = TrainEntry(
        date: .now,
        departure: TrainDeparture(
            scheduledTime: .now,
            expectedTime: .now,
            status: .onTime
        ),
        isActive: true,
        errorMessage: nil
    )

    static let inactive = TrainEntry(
        date: .now,
        departure: nil,
        isActive: false,
        errorMessage: nil
    )
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
            // Refresh every 15 minutes when active, every hour when inactive
            let refreshInterval: TimeInterval = entry.isActive ? 15 * 60 : 60 * 60
            let refreshDate = Date().addingTimeInterval(refreshInterval)
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }

    private func fetchEntry(completion: @escaping (TrainEntry) -> Void) {
        guard let route = ConfigStore.shared.activeRoute(at: .now) else {
            completion(.inactive)
            return
        }

        Task {
            do {
                let departure = try await TrainService.shared.fetchNextDeparture(
                    from: route.originCRS,
                    to: route.destinationCRS
                )
                let entry = TrainEntry(
                    date: .now,
                    departure: departure,
                    isActive: true,
                    errorMessage: nil
                )
                completion(entry)
            } catch {
                let entry = TrainEntry(
                    date: .now,
                    departure: nil,
                    isActive: true,
                    errorMessage: "Unable to load"
                )
                completion(entry)
            }
        }
    }
}

// MARK: - Widget Views

struct RectangularWidgetView: View {
    let entry: TrainEntry

    var body: some View {
        if !entry.isActive {
            inactiveView
        } else if let departure = entry.departure {
            departureView(departure)
        } else {
            errorView
        }
    }

    private var inactiveView: some View {
        HStack {
            Image(systemName: "tram.fill")
            Text("No trains today")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    private func departureView(_ departure: TrainDeparture) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "tram.fill")
                .font(.title3)

            VStack(alignment: .leading, spacing: 1) {
                Text(departure.displayTime)
                    .font(.headline)
                    .fontWeight(.bold)

                HStack(spacing: 3) {
                    Image(systemName: departure.status.symbolName)
                        .font(.caption2)
                    Text(departure.status.label)
                        .font(.caption2)
                }
                .foregroundStyle(statusColor(for: departure.status))
            }

            Spacer()
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
            Text("No trains today")
        } else if let departure = entry.departure {
            switch departure.status {
            case .onTime:
                Text("\(Image(systemName: "tram.fill")) \(departure.displayTime) On time")
            case .delayed(let minutes):
                Text("\(Image(systemName: "tram.fill")) \(departure.displayTime) +\(minutes)m")
            case .cancelled:
                Text("\(Image(systemName: "tram.fill")) \(departure.scheduledDisplayTime) Canc.")
            case .unknown:
                Text("\(Image(systemName: "tram.fill")) \(departure.displayTime)")
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
        } else if let departure = entry.departure {
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
        switch family {
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
}

// MARK: - Previews

#if DEBUG
struct OnTrackWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RectangularWidgetView(entry: TrainEntry(
                date: .now,
                departure: TrainDeparture(
                    scheduledTime: .now.addingTimeInterval(20 * 60),
                    expectedTime: .now.addingTimeInterval(23 * 60),
                    status: .delayed(minutes: 3)
                ),
                isActive: true,
                errorMessage: nil
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Rectangular - Delayed")

            RectangularWidgetView(entry: .inactive)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Rectangular - Inactive")

            CircularWidgetView(entry: TrainEntry(
                date: .now,
                departure: TrainDeparture(
                    scheduledTime: .now.addingTimeInterval(20 * 60),
                    expectedTime: .now.addingTimeInterval(20 * 60),
                    status: .onTime
                ),
                isActive: true,
                errorMessage: nil
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular - On Time")
        }
    }
}
#endif
