import SwiftUI

struct DayPickerView: View {
    @Binding var activeDays: Set<Int>

    // Calendar weekday values: 1=Sunday, 2=Monday, ..., 7=Saturday
    // Display Monday first (UK convention)
    private let days: [(name: String, short: String, weekday: Int)] = [
        ("Monday", "M", 2),
        ("Tuesday", "T", 3),
        ("Wednesday", "W", 4),
        ("Thursday", "T", 5),
        ("Friday", "F", 6),
        ("Saturday", "S", 7),
        ("Sunday", "S", 1),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.weekday) { day in
                Button {
                    toggle(day.weekday)
                } label: {
                    Text(day.short)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(width: 34, height: 34)
                        .background(
                            activeDays.contains(day.weekday)
                                ? Color.accentColor
                                : Color(.systemGray5)
                        )
                        .foregroundStyle(
                            activeDays.contains(day.weekday)
                                ? .white
                                : .primary
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.name)
                .accessibilityAddTraits(activeDays.contains(day.weekday) ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)

        HStack(spacing: 12) {
            Button("Weekdays") {
                activeDays = [2, 3, 4, 5, 6]
            }
            .font(.caption)

            Button("Every day") {
                activeDays = [1, 2, 3, 4, 5, 6, 7]
            }
            .font(.caption)

            Button("Clear") {
                activeDays = []
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func toggle(_ weekday: Int) {
        if activeDays.contains(weekday) {
            activeDays.remove(weekday)
        } else {
            activeDays.insert(weekday)
        }
    }
}
