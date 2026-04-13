import SwiftUI
import EventKit

struct CalendarSourcesView: View {
    @Bindable var viewModel: CalendarViewModel
    @Bindable var service: DeviceCalendarService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Categories
                Section("Categories") {
                    Button {
                        DispatchQueue.main.async {
                            viewModel.toggleHistory()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.primary)
                                .imageScale(.large)

                            Text("Show history")
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: viewModel.showHistory ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(viewModel.showHistory ? .green : .secondary)
                                .imageScale(.large)
                        }
                    }
                    .tint(.primary)
                }

                // MARK: - Device Calendars
                switch service.authorizationStatus {
                case .notDetermined:
                    Section {
                        Button {
                            Task { await service.requestAccess() }
                        } label: {
                            Label("Allow Calendar Access", systemImage: "calendar.badge.plus")
                        }
                    } footer: {
                        Text("Grant access to show events from calendars on this device.")
                    }

                case .fullAccess:
                    if !service.availableCalendars.isEmpty {
                        let grouped = Dictionary(grouping: service.availableCalendars) { $0.source.title }
                        let sortedKeys = grouped.keys.sorted()

                        ForEach(sortedKeys, id: \.self) { source in
                            Section(source) {
                                ForEach(grouped[source]!, id: \.calendarIdentifier) { calendar in
                                    calendarRow(calendar)
                                }
                            }
                        }
                    }

                case .denied, .restricted:
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Calendar access denied")
                                .font(.headline)
                            Text("Go to Settings > Cleo > Calendars to enable access.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }

                default:
                    EmptyView()
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                service.refreshStatus()
            }
        }
    }

    // MARK: - Calendar Row

    private func calendarRow(_ calendar: EKCalendar) -> some View {
        let enabled = service.isEnabled(calendar)

        return Button {
            // Defer mutation to next runloop tick to avoid
            // "setting value during update" AttributeGraph crash
            DispatchQueue.main.async {
                service.toggle(calendar)
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(cgColor: calendar.cgColor))
                    .frame(width: 14, height: 14)

                Text(calendar.title)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(enabled ? .green : .secondary)
                    .imageScale(.large)
            }
        }
        .tint(.primary)
    }
}
