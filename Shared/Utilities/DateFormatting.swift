import Foundation

enum DateFormatting {

    // MARK: - ISO8601 Formatting (for API requests)

    static func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    // MARK: - ISO8601 Parsing (for API responses)

    private static let iso8601Formatters: [ISO8601DateFormatter] = {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]

        return [withFractional, withoutFractional]
    }()

    static func parseISO8601(_ string: String) -> Date? {
        for formatter in iso8601Formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    // MARK: - Display Formatting

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_GB")
        return formatter
    }()

    static func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}
