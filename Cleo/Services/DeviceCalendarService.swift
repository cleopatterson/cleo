import EventKit
import SwiftUI

/// EventKit integration for business calendar (§3.2)
@Observable
class DeviceCalendarService {
    private let store = EKEventStore()
    private var yearCache: [Int: [String: [EKEvent]]] = [:]  // year → dateKey → events
    var enabledCalendarIDs: Set<String> = []
    var cacheVersion: Int = 0

    private static let dayKeyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    var availableCalendars: [EKCalendar] {
        store.calendars(for: .event)
    }

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            print("EventKit access error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Calendar Selection

    func toggleCalendar(_ id: String) {
        if enabledCalendarIDs.contains(id) {
            enabledCalendarIDs.remove(id)
        } else {
            enabledCalendarIDs.insert(id)
        }
        saveEnabledCalendars()
        yearCache.removeAll()
        cacheVersion += 1
    }

    func loadEnabledCalendars() {
        if let saved = UserDefaults.standard.array(forKey: "cleo_enabledCalendars") as? [String] {
            enabledCalendarIDs = Set(saved)
        } else {
            // Default: enable all calendars
            enabledCalendarIDs = Set(availableCalendars.map { $0.calendarIdentifier })
        }
    }

    private func saveEnabledCalendars() {
        UserDefaults.standard.set(Array(enabledCalendarIDs), forKey: "cleo_enabledCalendars")
    }

    // MARK: - Event Fetching

    func refreshCache(for year: Int) {
        let cal = Calendar.current
        guard let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else { return }

        let calendars = availableCalendars.filter { enabledCalendarIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else {
            yearCache[year] = [:]
            cacheVersion += 1
            return
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = store.events(matching: predicate)

        var dict: [String: [EKEvent]] = [:]
        let df = Self.dayKeyFormatter

        for event in events {
            // Flatten multi-day events
            guard let startDate = event.startDate else { continue }
            var day = startDate
            let endDay = event.endDate ?? startDate
            while day <= endDay {
                let key = df.string(from: day)
                dict[key, default: []].append(event)
                guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }

        yearCache[year] = dict
        cacheVersion += 1
    }

    func events(on date: Date) -> [EKEvent] {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        if yearCache[year] == nil {
            refreshCache(for: year)
        }
        return yearCache[year]?[Self.dayKeyFormatter.string(from: date)] ?? []
    }

    func eventCount(on date: Date) -> Int {
        events(on: date).count
    }

    /// All days in a year that have at least one event (for visible days computation).
    func eventDays(in year: Int) -> Set<Date> {
        let cal = Calendar.current
        if yearCache[year] == nil {
            refreshCache(for: year)
        }
        var days = Set<Date>()
        for key in yearCache[year]?.keys ?? Dictionary<String, [EKEvent]>().keys {
            if let date = Self.dayKeyFormatter.date(from: key) {
                days.insert(cal.startOfDay(for: date))
            }
        }
        return days
    }

    func isEnabled(_ calendar: EKCalendar) -> Bool {
        enabledCalendarIDs.contains(calendar.calendarIdentifier)
    }

    func toggle(_ calendar: EKCalendar) {
        toggleCalendar(calendar.calendarIdentifier)
    }

    func invalidateCache() {
        yearCache.removeAll()
        cacheVersion += 1
    }

    func refreshStatus() {
        // Force re-read of authorization status (triggers @Observable update)
        _ = authorizationStatus
    }

    // MARK: - Event Creation

    func createEvent(title: String, startDate: Date, endDate: Date, calendarID: String?, location: String?, notes: String?) throws -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes

        if let calID = calendarID,
           let calendar = availableCalendars.first(where: { $0.calendarIdentifier == calID }) {
            event.calendar = calendar
        } else {
            event.calendar = store.defaultCalendarForNewEvents
        }

        try store.save(event, span: .thisEvent)
        yearCache.removeAll()
        cacheVersion += 1
        return event
    }
}
