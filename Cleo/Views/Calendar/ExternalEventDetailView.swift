import SwiftUI
import EventKit

struct ExternalEventDetailView: View {
    let event: EKEvent
    @Environment(\.dismiss) private var dismiss

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if event.isAllDay {
                        LabeledContent("Date", value: Self.dateTimeFormatter.string(from: event.startDate))
                    } else {
                        LabeledContent("Start", value: Self.dateTimeFormatter.string(from: event.startDate))
                        LabeledContent("End", value: Self.dateTimeFormatter.string(from: event.endDate))
                    }

                    if let location = event.location, !location.isEmpty {
                        LabeledContent("Location", value: location)
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(cgColor: event.calendar.cgColor))
                            .frame(width: 10, height: 10)
                        Text(event.calendar.title)
                            .foregroundStyle(.secondary)
                    }
                }

                if let notes = event.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                            .font(.body)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(event.title ?? "Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
