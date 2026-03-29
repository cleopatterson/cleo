import Foundation
import CoreData

// MARK: - CalendarEvent Core Data Entity

@objc(CalendarEvent)
public class CalendarEvent: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var isAllDay: Bool
    @NSManaged public var location: String?
    @NSManaged public var recurrenceFrequencyRaw: String?
    @NSManaged public var recurrenceEndDate: Date?
    @NSManaged public var reminderEnabled: Bool
    @NSManaged public var isTodo: Bool
    @NSManaged public var isCompleted: Bool
    @NSManaged public var completedDate: Date?
    @NSManaged public var todoEmoji: String?
    @NSManaged public var createdAt: Date?
}

// MARK: - Recurrence

enum RecurrenceFrequency: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case fortnightly
    case monthly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .fortnightly: "Fortnightly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }
}

// MARK: - To-do Urgency

enum TodoUrgencyState {
    case notStarted
    case active
    case dueSoon
    case overdue
    case done
    case flexible
}

// MARK: - CalendarEvent Identifiable (for SwiftUI sheet binding)

extension CalendarEvent: Identifiable {
    // Uses Core Data's objectID internally; `id` attribute is the UUID for CloudKit.
}

// MARK: - CalendarEvent Extensions

extension CalendarEvent {

    var wrappedTitle: String { title ?? "" }
    var wrappedStartDate: Date { startDate ?? Date() }
    var wrappedEndDate: Date { endDate ?? Date() }

    var recurrence: RecurrenceFrequency? {
        guard let raw = recurrenceFrequencyRaw else { return nil }
        return RecurrenceFrequency(rawValue: raw)
    }

    var todoHasDueDate: Bool {
        guard isTodo else { return false }
        guard let s = startDate, let e = endDate else { return false }
        return !Calendar.current.isDate(s, inSameDayAs: e)
    }

    var urgencyState: TodoUrgencyState {
        guard isTodo else { return .active }
        if isCompleted { return .done }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.startOfDay(for: wrappedStartDate)
        if start > today { return .notStarted }

        guard todoHasDueDate else { return .flexible }

        let due = cal.startOfDay(for: wrappedEndDate)
        if due < today { return .overdue }

        if let twoDaysBefore = cal.date(byAdding: .day, value: -2, to: due),
           today >= cal.startOfDay(for: twoDaysBefore) {
            return .dueSoon
        }

        return .active
    }

    var daysOverdue: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let due = cal.startOfDay(for: wrappedEndDate)
        return cal.dateComponents([.day], from: due, to: today).day ?? 0
    }

    /// Whether this to-do should appear on a given calendar day.
    func todoShouldAppearOn(_ day: Date) -> Bool {
        guard isTodo else { return false }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        if isCompleted {
            if let completed = completedDate {
                return cal.isDate(completed, inSameDayAs: day)
            }
            return false
        }

        if cal.isDate(wrappedStartDate, inSameDayAs: day) { return true }

        if todoHasDueDate && cal.isDate(wrappedEndDate, inSameDayAs: day) { return true }

        let dayStart = cal.startOfDay(for: day)
        if dayStart == today && urgencyState == .overdue { return true }

        return false
    }

    /// Whether this to-do is relevant for a given week (for briefing).
    func todoRelevantForWeek(weekStart: Date, weekEnd: Date) -> Bool {
        guard isTodo else { return false }
        let cal = Calendar.current

        if isCompleted {
            if let completed = completedDate {
                let completedDay = cal.startOfDay(for: completed)
                return completedDay >= cal.startOfDay(for: weekStart) && completedDay <= cal.startOfDay(for: weekEnd)
            }
            return false
        }

        let start = cal.startOfDay(for: wrappedStartDate)
        let wEnd = cal.startOfDay(for: weekEnd)
        if start > wEnd { return false }

        return true
    }

    /// Whether this event occurs on a given calendar day, accounting for all-day spans and recurrence.
    func occursOn(_ day: Date) -> Bool {
        if isTodo { return todoShouldAppearOn(day) }

        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)

        if let recEnd = recurrenceEndDate, dayStart > cal.startOfDay(for: recEnd) {
            return false
        }

        guard let freq = recurrence else {
            if isAllDay {
                let eventStart = cal.startOfDay(for: wrappedStartDate)
                let eventEnd = cal.startOfDay(for: wrappedEndDate)
                return dayStart >= eventStart && dayStart <= eventEnd
            } else {
                return cal.isDate(wrappedStartDate, inSameDayAs: day)
            }
        }

        let anchorDay = cal.startOfDay(for: wrappedStartDate)
        guard dayStart >= anchorDay else { return false }

        let spanDays: Int
        if isAllDay {
            spanDays = max(0, cal.dateComponents([.day], from: cal.startOfDay(for: wrappedStartDate), to: cal.startOfDay(for: wrappedEndDate)).day ?? 0)
        } else {
            spanDays = 0
        }

        switch freq {
        case .daily:
            return true
        case .weekly:
            let daysDiff = cal.dateComponents([.day], from: anchorDay, to: dayStart).day ?? 0
            return daysDiff % 7 <= spanDays
        case .fortnightly:
            let daysDiff = cal.dateComponents([.day], from: anchorDay, to: dayStart).day ?? 0
            return daysDiff % 14 <= spanDays
        case .monthly:
            let monthsDiff = cal.dateComponents([.month], from: anchorDay, to: dayStart).month ?? 0
            for m in max(0, monthsDiff - 1)...(monthsDiff + 1) {
                guard let occurrence = cal.date(byAdding: .month, value: m, to: anchorDay) else { continue }
                let occStart = cal.startOfDay(for: occurrence)
                if spanDays == 0 {
                    if dayStart == occStart { return true }
                } else {
                    for offset in 0...spanDays {
                        if let d = cal.date(byAdding: .day, value: offset, to: occStart), cal.startOfDay(for: d) == dayStart {
                            return true
                        }
                    }
                }
            }
            return false
        case .yearly:
            let anchorComps = cal.dateComponents([.month, .day], from: wrappedStartDate)
            let dayComps = cal.dateComponents([.month, .day], from: day)
            if spanDays == 0 {
                return anchorComps.month == dayComps.month && anchorComps.day == dayComps.day
            }
            for offset in 0...spanDays {
                if let d = cal.date(byAdding: .day, value: offset, to: anchorDay) {
                    let c = cal.dateComponents([.month, .day], from: d)
                    if c.month == dayComps.month && c.day == dayComps.day { return true }
                }
            }
            return false
        }
    }
}
