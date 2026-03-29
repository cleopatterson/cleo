import SwiftUI

struct EventDetailView: View {
    let event: CalendarEvent
    @Bindable var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showConfetti = false

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if event.isTodo {
                        LabeledContent("Start Date", value: Self.dateOnlyFormatter.string(from: event.wrappedStartDate))

                        if event.todoHasDueDate {
                            LabeledContent("Due Date", value: Self.dateOnlyFormatter.string(from: event.wrappedEndDate))
                        }

                        if let emoji = event.todoEmoji, !emoji.isEmpty {
                            LabeledContent("Emoji", value: emoji)
                        }

                        LabeledContent {
                            let state = event.urgencyState
                            Text(todoStatusLabel(state))
                                .foregroundStyle(todoStatusColor(state))
                        } label: {
                            Label("Status", systemImage: event.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(event.isCompleted ? .green : .secondary)
                        }
                    } else if event.isAllDay {
                        let startDay = Self.dateOnlyFormatter.string(from: event.wrappedStartDate)
                        LabeledContent("Date", value: startDay)
                        if !Calendar.current.isDate(event.wrappedStartDate, inSameDayAs: event.wrappedEndDate) {
                            LabeledContent("End Date", value: Self.dateOnlyFormatter.string(from: event.wrappedEndDate))
                        }
                    } else {
                        LabeledContent("Date & Time", value: Self.dateTimeFormatter.string(from: event.wrappedStartDate))
                    }

                    if !event.isTodo, let location = event.location, !location.isEmpty {
                        LabeledContent {
                            Text(location)
                        } label: {
                            Label("Location", systemImage: "mappin")
                        }
                    }

                    if let freq = event.recurrence {
                        LabeledContent {
                            Text(freq.displayName)
                        } label: {
                            Label("Repeats", systemImage: "repeat")
                        }

                        if let recEnd = event.recurrenceEndDate {
                            LabeledContent("Until", value: Self.dateOnlyFormatter.string(from: recEnd))
                        }
                    }

                    if event.reminderEnabled {
                        LabeledContent {
                            Text(event.isAllDay ? "9 AM on the day" : "15 min before")
                        } label: {
                            Label("Reminder", systemImage: "bell.fill")
                        }
                    }
                }

                if event.isTodo {
                    Section {
                        Button {
                            let isCurrentlyDone = event.isCompleted
                            if !isCurrentlyDone {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                showConfetti = true
                            }
                            viewModel.toggleTodoCompleted(event)
                            if !isCurrentlyDone {
                                Task {
                                    try? await Task.sleep(for: .seconds(2.0))
                                    showConfetti = false
                                }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label(
                                    event.isCompleted ? "Mark as Incomplete" : "Mark as Done",
                                    systemImage: event.isCompleted ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill"
                                )
                                .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .tint(event.isCompleted ? .orange : .green)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label(event.isTodo ? "Delete To-Do" : "Delete Event", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(event.wrappedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EventFormView(
                    initialDate: event.wrappedStartDate,
                    existingEvent: event
                ) { title, start, end, isAllDay, location, recFreq, recEnd, reminder, isTodo, todoEmoji in
                    event.title = title
                    event.startDate = start
                    event.endDate = end
                    event.isAllDay = isAllDay
                    event.location = location
                    event.recurrenceFrequencyRaw = recFreq
                    event.recurrenceEndDate = recEnd
                    event.reminderEnabled = reminder
                    event.isTodo = isTodo
                    event.todoEmoji = todoEmoji
                    viewModel.updateEvent(event)
                }
                .presentationBackground(.ultraThinMaterial)
            }
            .overlay {
                if showConfetti {
                    ConfettiView()
                }
            }
            .confirmationDialog(
                event.isTodo ? "Delete this to-do?" : "Delete this event?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    viewModel.deleteEvent(event)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func todoStatusLabel(_ state: TodoUrgencyState) -> String {
        switch state {
        case .done: "Done"
        case .overdue: "Overdue"
        case .dueSoon: "Due Soon"
        case .active: "Active"
        case .flexible: "Flexible"
        case .notStarted: "Not Started"
        }
    }

    private func todoStatusColor(_ state: TodoUrgencyState) -> Color {
        switch state {
        case .done: .green
        case .overdue: .red
        case .dueSoon: .orange
        case .active: .cyan
        case .flexible: .secondary
        case .notStarted: .secondary
        }
    }
}
