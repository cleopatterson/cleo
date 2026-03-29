import SwiftUI
import EventKit

@MainActor
@Observable
final class CalendarViewModel {
    let persistence: PersistenceController
    let calendarService: DeviceCalendarService
    let claudeService: ClaudeAPIService

    var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    var showingMonthPicker = false
    var showingEventForm = false
    var showingCalendarSources = false
    var selectedEvent: CalendarEvent?
    var selectedExternalEvent: EKEvent?
    var showHistory = false
    var briefing: AIBriefingResponse?
    var isLoadingBriefing = false
    var nextWeekBriefing: AIBriefingResponse?
    var isLoadingNextWeekBriefing = false

    private let showHistoryKey = "cleo_showCalendarHistory"

    // Cache management
    @ObservationIgnored private var _cachedVisibleDays: [Date] = []
    @ObservationIgnored private var _cacheKey: String = ""
    @ObservationIgnored private var _cachedEventsByDay: [Date: [CalendarEvent]] = [:]
    @ObservationIgnored private var _eventsCacheKey: String = ""
    @ObservationIgnored private var _cachedAllEvents: [CalendarEvent] = []
    @ObservationIgnored private var _allEventsCacheKey: String = ""
    @ObservationIgnored private var hasLoadedBriefing = false
    @ObservationIgnored private var hasLoadedNextWeekBriefing = false

    /// Incremented on every event mutation to invalidate caches.
    var eventsVersion: Int = 0

    init(persistence: PersistenceController, calendarService: DeviceCalendarService, claudeService: ClaudeAPIService) {
        self.persistence = persistence
        self.calendarService = calendarService
        self.claudeService = claudeService
        showHistory = UserDefaults.standard.bool(forKey: showHistoryKey)
    }

    // MARK: - Events

    /// All user events from Core Data (cached, refreshed on mutation).
    private var allEvents: [CalendarEvent] {
        let key = "\(eventsVersion)"
        if key != _allEventsCacheKey {
            _allEventsCacheKey = key
            _cachedAllEvents = persistence.fetchCalendarEvents()
        }
        return _cachedAllEvents
    }

    /// Events for a specific day (Core Data events only).
    func events(for day: Date) -> [CalendarEvent] {
        let key = "\(eventsVersion)"
        if key != _eventsCacheKey {
            _eventsCacheKey = key
            _cachedEventsByDay = [:]
        }
        if let cached = _cachedEventsByDay[day] {
            return cached
        }
        let result = allEvents.filter { $0.occursOn(day) }
            .sorted { lhs, rhs in
                // Todos after events, then by start date
                if lhs.isTodo != rhs.isTodo { return !lhs.isTodo }
                return lhs.wrappedStartDate < rhs.wrappedStartDate
            }
        _cachedEventsByDay[day] = result
        return result
    }

    /// External device calendar events for a day.
    func externalEvents(for day: Date) -> [EKEvent] {
        calendarService.events(on: day)
    }

    // MARK: - Visible Days (feed)

    var visibleDays: [Date] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: selectedDate)
        let key = "\(year)-\(eventsVersion)-\(calendarService.cacheVersion)-\(showHistory)"

        if key == _cacheKey && !_cachedVisibleDays.isEmpty {
            return _cachedVisibleDays
        }

        guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31))
        else { return [] }

        var daysSet = Set<Date>()

        let today = calendar.startOfDay(for: Date())
        if today >= startOfYear && today <= endOfYear {
            daysSet.insert(today)
        }

        // 1st of every month for month banners
        for month in 1...12 {
            if let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)) {
                daysSet.insert(firstOfMonth)
            }
        }

        // All days with user events
        for event in allEvents {
            if event.isTodo {
                let start = calendar.startOfDay(for: event.wrappedStartDate)
                if start >= startOfYear && start <= endOfYear { daysSet.insert(start) }
                if event.todoHasDueDate {
                    let due = calendar.startOfDay(for: event.wrappedEndDate)
                    if due != start && due >= startOfYear && due <= endOfYear { daysSet.insert(due) }
                }
                if !event.isCompleted && event.urgencyState == .overdue {
                    daysSet.insert(today)
                }
            } else if event.recurrence != nil {
                enumerateRecurrences(of: event, from: startOfYear, through: endOfYear, into: &daysSet)
            } else {
                let day = calendar.startOfDay(for: event.wrappedStartDate)
                if day >= startOfYear && day <= endOfYear { daysSet.insert(day) }
                if event.isAllDay {
                    let spanEnd = calendar.startOfDay(for: event.wrappedEndDate)
                    var current = day
                    while current <= spanEnd && current <= endOfYear {
                        if current >= startOfYear { daysSet.insert(current) }
                        guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                        current = next
                    }
                }
            }
        }

        // Device calendar days
        let deviceDays = calendarService.eventDays(in: year)
        daysSet.formUnion(deviceDays)

        var result = daysSet.sorted()

        if !showHistory {
            result = result.filter { $0 >= today }
        }

        _cachedVisibleDays = result
        _cacheKey = key
        return result
    }

    private func enumerateRecurrences(of event: CalendarEvent, from rangeStart: Date, through rangeEnd: Date, into daysSet: inout Set<Date>) {
        let calendar = Calendar.current
        guard let freq = event.recurrence else { return }

        let anchor = calendar.startOfDay(for: event.wrappedStartDate)
        let effectiveEnd: Date
        if let recEnd = event.recurrenceEndDate {
            effectiveEnd = min(calendar.startOfDay(for: recEnd), rangeEnd)
        } else {
            effectiveEnd = rangeEnd
        }

        let spanDays: Int
        if event.isAllDay {
            spanDays = max(0, calendar.dateComponents([.day], from: anchor, to: calendar.startOfDay(for: event.wrappedEndDate)).day ?? 0)
        } else {
            spanDays = 0
        }

        var current = anchor
        if current < rangeStart {
            switch freq {
            case .daily:
                current = rangeStart
            case .weekly:
                let daysDiff = calendar.dateComponents([.day], from: anchor, to: rangeStart).day ?? 0
                current = calendar.date(byAdding: .day, value: (daysDiff / 7) * 7, to: anchor) ?? rangeStart
            case .fortnightly:
                let daysDiff = calendar.dateComponents([.day], from: anchor, to: rangeStart).day ?? 0
                current = calendar.date(byAdding: .day, value: (daysDiff / 14) * 14, to: anchor) ?? rangeStart
            case .monthly:
                let comps = calendar.dateComponents([.month], from: anchor, to: rangeStart)
                current = calendar.date(byAdding: .month, value: max(0, (comps.month ?? 0) - 1), to: anchor) ?? rangeStart
            case .yearly:
                let comps = calendar.dateComponents([.year], from: anchor, to: rangeStart)
                current = calendar.date(byAdding: .year, value: max(0, (comps.year ?? 0) - 1), to: anchor) ?? rangeStart
            }
        }

        var count = 0
        while current <= effectiveEnd && count < 400 {
            for offset in 0...spanDays {
                if let day = calendar.date(byAdding: .day, value: offset, to: current) {
                    if day >= rangeStart && day <= effectiveEnd {
                        daysSet.insert(day)
                    }
                }
            }
            switch freq {
            case .daily: current = calendar.date(byAdding: .day, value: 1, to: current) ?? effectiveEnd.addingTimeInterval(86400)
            case .weekly: current = calendar.date(byAdding: .day, value: 7, to: current) ?? effectiveEnd.addingTimeInterval(86400)
            case .fortnightly: current = calendar.date(byAdding: .day, value: 14, to: current) ?? effectiveEnd.addingTimeInterval(86400)
            case .monthly: current = calendar.date(byAdding: .month, value: 1, to: current) ?? effectiveEnd.addingTimeInterval(86400)
            case .yearly: current = calendar.date(byAdding: .year, value: 1, to: current) ?? effectiveEnd.addingTimeInterval(86400)
            }
            count += 1
        }
    }

    // MARK: - Filter

    func toggleHistory() {
        showHistory.toggle()
        _cacheKey = ""
        UserDefaults.standard.set(showHistory, forKey: showHistoryKey)
    }

    // MARK: - Navigation

    func scrollToToday() {
        selectedDate = Calendar.current.startOfDay(for: Date())
    }

    func refreshDeviceCalendarCache() {
        let year = Calendar.current.component(.year, from: selectedDate)
        calendarService.refreshCache(for: year)
        _cacheKey = ""
    }

    // MARK: - CRUD

    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        recurrenceFrequency: String? = nil,
        recurrenceEndDate: Date? = nil,
        reminderEnabled: Bool = false,
        isTodo: Bool = false,
        todoEmoji: String? = nil
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        persistence.createCalendarEvent(
            title: trimmed,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location,
            recurrenceFrequency: recurrenceFrequency,
            recurrenceEndDate: recurrenceEndDate,
            reminderEnabled: reminderEnabled,
            isTodo: isTodo,
            todoEmoji: todoEmoji
        )
        invalidateCache()
    }

    func updateEvent(_ event: CalendarEvent) {
        persistence.updateCalendarEvent(event)
        invalidateCache()
    }

    func deleteEvent(_ event: CalendarEvent) {
        persistence.deleteCalendarEvent(event)
        invalidateCache()
    }

    func toggleTodoCompleted(_ event: CalendarEvent) {
        guard event.isTodo else { return }
        let wasCompleted = event.isCompleted
        event.isCompleted = !wasCompleted
        event.completedDate = wasCompleted ? nil : Date()
        persistence.save()
        invalidateCache()
    }

    private func invalidateCache() {
        eventsVersion += 1
        _cacheKey = ""
        _eventsCacheKey = ""
        _cachedEventsByDay = [:]
    }

    /// Reset briefing flags so they reload with fresh calendar data.
    func reloadBriefings() {
        hasLoadedBriefing = false
        hasLoadedNextWeekBriefing = false
        briefing = nil
        nextWeekBriefing = nil
        briefingTask?.cancel()
        briefingTask = nil
        nextWeekBriefingTask?.cancel()
        nextWeekBriefingTask = nil
        loadBriefing()
        loadNextWeekBriefing()
    }

    // MARK: - Briefing

    @ObservationIgnored private var briefingTask: Task<Void, Never>?

    func loadBriefing() {
        guard !hasLoadedBriefing || briefing == nil else { return }
        guard briefingTask == nil else { return }
        hasLoadedBriefing = true
        isLoadingBriefing = true

        // Gather full week data for a useful briefing
        let cal = Calendar.current
        var weekEventTitles: [String] = []
        var weekEventCount = 0
        for day in weekDays {
            let dayStart = cal.startOfDay(for: day)
            let dayEvents = events(for: dayStart)
            let dayExt = externalEvents(for: dayStart)
            weekEventCount += dayEvents.count + dayExt.count
            weekEventTitles.append(contentsOf: dayEvents.map { $0.wrappedTitle })
            weekEventTitles.append(contentsOf: dayExt.map { $0.title ?? "Untitled" })
        }

        let todos = allEvents.filter { $0.isTodo && !$0.isCompleted }

        let payload: [String: Any] = [
            "eventCount": weekEventCount,
            "eventTitles": Array(weekEventTitles.prefix(15)),
            "activeTodos": todos.count,
            "overdueTodos": todos.filter { $0.urgencyState == .overdue }.count
        ]

        // Use unstructured Task so tab switches don't cancel the API call
        briefingTask = Task {
            let result = await claudeService.generateBriefing(tab: .calendar, dataPayload: payload)
            briefing = result
            isLoadingBriefing = false
            briefingTask = nil

            // Allow retry on next appearance if briefing failed
            if result == nil {
                hasLoadedBriefing = false
            }
        }
    }

    /// Dynamic fallback headline when API hasn't loaded yet.
    var fallbackHeadline: String {
        let cal = Calendar.current
        var total = 0
        for day in weekDays {
            total += events(for: cal.startOfDay(for: day)).count + externalEvents(for: cal.startOfDay(for: day)).count
        }
        let todos = allEvents.filter { $0.isTodo && !$0.isCompleted }
        if total == 0 && todos.isEmpty { return "A clear week ahead" }
        var parts: [String] = []
        if total > 0 { parts.append("\(total) event\(total == 1 ? "" : "s")") }
        if !todos.isEmpty { parts.append("\(todos.count) to-do\(todos.count == 1 ? "" : "s")") }
        return parts.joined(separator: ", ") + " this week"
    }

    /// Dynamic fallback summary.
    var fallbackSummary: String {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let todayEvents = events(for: todayStart).count + externalEvents(for: todayStart).count
        let overdue = allEvents.filter { $0.isTodo && !$0.isCompleted && $0.urgencyState == .overdue }.count
        if todayEvents == 0 && overdue == 0 { return "Nothing on the calendar today. Check the week view for what's coming up." }
        var parts: [String] = []
        if todayEvents > 0 { parts.append("\(todayEvents) event\(todayEvents == 1 ? "" : "s") today") }
        if overdue > 0 { parts.append("\(overdue) overdue to-do\(overdue == 1 ? "" : "s")") }
        return parts.joined(separator: ". ") + "."
    }

    @ObservationIgnored private var nextWeekBriefingTask: Task<Void, Never>?

    func loadNextWeekBriefing() {
        guard !hasLoadedNextWeekBriefing || nextWeekBriefing == nil else { return }
        guard nextWeekBriefingTask == nil else { return }
        hasLoadedNextWeekBriefing = true
        isLoadingNextWeekBriefing = true

        let cal = Calendar.current
        let nextWeekStart = cal.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let nextWeekDays = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: nextWeekStart) }

        var weekEventTitles: [String] = []
        var weekEventCount = 0
        for day in nextWeekDays {
            let dayStart = cal.startOfDay(for: day)
            let dayEvents = events(for: dayStart)
            let dayExt = externalEvents(for: dayStart)
            weekEventCount += dayEvents.count + dayExt.count
            weekEventTitles.append(contentsOf: dayEvents.map { $0.wrappedTitle })
            weekEventTitles.append(contentsOf: dayExt.map { $0.title ?? "Untitled" })
        }

        print("[NextWeekBriefing] eventCount=\(weekEventCount), titles=\(weekEventTitles)")

        let payload: [String: Any] = [
            "week": "next",
            "eventCount": weekEventCount,
            "eventTitles": Array(weekEventTitles.prefix(15))
        ]

        nextWeekBriefingTask = Task {
            let result = await claudeService.generateBriefing(tab: .calendar, dataPayload: payload, cacheKey: "calendar_next")
            nextWeekBriefing = result
            isLoadingNextWeekBriefing = false
            nextWeekBriefingTask = nil
            if result == nil { hasLoadedNextWeekBriefing = false }
        }
    }

    /// Dynamic next week summary (fallback when AI hasn't loaded).
    func nextWeekSummary(nextWeekDays: [Date]) -> (headline: String, summary: String) {
        let cal = Calendar.current
        var total = 0
        var titles: [String] = []
        for day in nextWeekDays {
            let dayStart = cal.startOfDay(for: day)
            let dayEvents = events(for: dayStart)
            let dayExt = externalEvents(for: dayStart)
            total += dayEvents.count + dayExt.count
            titles.append(contentsOf: dayEvents.map { $0.wrappedTitle })
            titles.append(contentsOf: dayExt.map { $0.title ?? "Untitled" })
        }
        if total == 0 {
            return ("Nothing planned yet", "Next week is wide open — a blank canvas for new plans.")
        }
        let headline = "\(total) event\(total == 1 ? "" : "s") next week"
        let preview = titles.prefix(3).joined(separator: ", ")
        let more = total > 3 ? " and more" : ""
        return (headline, "\(preview)\(more) lined up.")
    }

    // MARK: - Week Days (for briefing placement)

    var weekStart: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
    }

    var weekDays: [Date] {
        let cal = Calendar.current
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }
}
