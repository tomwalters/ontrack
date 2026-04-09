import SwiftUI

struct CommuteConfigView: View {
    @Binding var window: TimeWindow
    let label: String

    var body: some View {
        HStack {
            Text("From")
                .foregroundStyle(.secondary)
            TextField("CRS", text: $window.originCRS)
                .textInputAutocapitalization(.characters)
                .frame(maxWidth: 80)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .onChange(of: window.originCRS) { newValue in
                    if newValue.count > 3 {
                        window.originCRS = String(newValue.prefix(3))
                    }
                }

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)

            Text("To")
                .foregroundStyle(.secondary)
            TextField("CRS", text: $window.destinationCRS)
                .textInputAutocapitalization(.characters)
                .frame(maxWidth: 80)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .onChange(of: window.destinationCRS) { newValue in
                    if newValue.count > 3 {
                        window.destinationCRS = String(newValue.prefix(3))
                    }
                }
        }

        HStack {
            Text("Active")
                .foregroundStyle(.secondary)
            DatePicker(
                "",
                selection: startTimeBinding,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()

            Text("to")
                .foregroundStyle(.secondary)

            DatePicker(
                "",
                selection: endTimeBinding,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: { dateFromComponents(hour: window.startHour, minute: window.startMinute) },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                window.startHour = components.hour ?? 0
                window.startMinute = components.minute ?? 0
            }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: { dateFromComponents(hour: window.endHour, minute: window.endMinute) },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                window.endHour = components.hour ?? 0
                window.endMinute = components.minute ?? 0
            }
        )
    }

    private func dateFromComponents(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}
