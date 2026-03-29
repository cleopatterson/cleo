import Foundation
import CoreData

@Observable
class MetricsViewModel {
    let timeService: TimeTrackingService
    let claudeService: ClaudeAPIService
    let persistence: PersistenceController

    var briefing: AIBriefingResponse?
    var isLoadingBriefing = false
    var selectedWeekIndex: Int = 0

    // Cached financial data (refreshed once per load, not per render)
    private(set) var monthlyRevenue: Double = 0
    private(set) var monthlyExpenses: Double = 0
    private(set) var previousPeriodRevenue: Double = 0
    private(set) var previousPeriodExpenses: Double = 0
    private(set) var totalOutstanding: Double = 0
    @ObservationIgnored private var hasLoadedBriefing = false

    init(timeService: TimeTrackingService, claudeService: ClaudeAPIService, persistence: PersistenceController) {
        self.timeService = timeService
        self.claudeService = claudeService
        self.persistence = persistence
    }

    // MARK: - Financial Data

    var netProfit: Double { monthlyRevenue - monthlyExpenses }
    var previousPeriodProfit: Double { previousPeriodRevenue - previousPeriodExpenses }

    var profitTrendPercent: Double? {
        guard previousPeriodProfit != 0 else {
            return netProfit > 0 ? 100 : nil
        }
        return ((netProfit - previousPeriodProfit) / abs(previousPeriodProfit)) * 100
    }

    /// Refresh all financial data from Core Data (called once per load).
    func refreshFinancials() {
        let now = Date()
        let cal = Calendar.current
        let thirtyDaysAgo = cal.date(byAdding: .day, value: -30, to: now) ?? now
        let sixtyDaysAgo = cal.date(byAdding: .day, value: -60, to: now) ?? now

        // Current period revenue
        let revRequest = NSFetchRequest<Invoice>(entityName: "Invoice")
        revRequest.predicate = NSPredicate(format: "statusRaw == %@ AND paidDate >= %@", "paid", thirtyDaysAgo as NSDate)
        monthlyRevenue = ((try? persistence.viewContext.fetch(revRequest)) ?? []).reduce(0) { $0 + $1.total }

        // Current period expenses
        let expRequest = NSFetchRequest<Expense>(entityName: "Expense")
        expRequest.predicate = NSPredicate(format: "date >= %@", thirtyDaysAgo as NSDate)
        monthlyExpenses = ((try? persistence.viewContext.fetch(expRequest)) ?? []).reduce(0) { $0 + $1.amount }

        // Previous period revenue
        let prevRevRequest = NSFetchRequest<Invoice>(entityName: "Invoice")
        prevRevRequest.predicate = NSPredicate(format: "statusRaw == %@ AND paidDate >= %@ AND paidDate < %@", "paid", sixtyDaysAgo as NSDate, thirtyDaysAgo as NSDate)
        previousPeriodRevenue = ((try? persistence.viewContext.fetch(prevRevRequest)) ?? []).reduce(0) { $0 + $1.total }

        // Previous period expenses
        let prevExpRequest = NSFetchRequest<Expense>(entityName: "Expense")
        prevExpRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", sixtyDaysAgo as NSDate, thirtyDaysAgo as NSDate)
        previousPeriodExpenses = ((try? persistence.viewContext.fetch(prevExpRequest)) ?? []).reduce(0) { $0 + $1.amount }

        // Outstanding
        let outRequest = NSFetchRequest<Invoice>(entityName: "Invoice")
        outRequest.predicate = NSPredicate(format: "statusRaw == %@", "sent")
        totalOutstanding = ((try? persistence.viewContext.fetch(outRequest)) ?? []).reduce(0) { $0 + $1.total }
    }

    // MARK: - Time Tracking

    var weeks: [WeekSummary] {
        timeService.weeks.reversed()
    }

    var selectedWeek: WeekSummary? {
        guard selectedWeekIndex >= 0, selectedWeekIndex < weeks.count else { return nil }
        return weeks[selectedWeekIndex]
    }

    var canGoBack: Bool { selectedWeekIndex < weeks.count - 1 }
    var canGoForward: Bool { selectedWeekIndex > 0 }

    func goToPreviousWeek() { if canGoBack { selectedWeekIndex += 1 } }
    func goToNextWeek() { if canGoForward { selectedWeekIndex -= 1 } }

    var heroClient: ClientHours? { selectedWeek?.clients.first }

    var heroPercentage: Int {
        guard let hero = heroClient, let week = selectedWeek, week.totalHours > 0 else { return 0 }
        return Int((hero.hours / week.totalHours) * 100)
    }

    var comparisonWeek: WeekSummary? {
        let prevIndex = selectedWeekIndex + 1
        guard prevIndex < weeks.count else { return nil }
        return weeks[prevIndex]
    }

    var weekOverWeekChange: Double? {
        guard let prev = comparisonWeek, prev.totalHours > 0, let current = selectedWeek else { return nil }
        return ((current.totalHours - prev.totalHours) / prev.totalHours) * 100
    }

    // MARK: - Load

    func loadData() async {
        await timeService.loadIfNeeded()
        if selectedWeekIndex == 0 && !weeks.isEmpty {
            selectedWeekIndex = 0
        }
        refreshFinancials()
    }

    // MARK: - Briefing

    @ObservationIgnored private var briefingTask: Task<Void, Never>?

    func loadBriefing() {
        guard !hasLoadedBriefing || briefing == nil else { return }
        guard briefingTask == nil else { return }
        hasLoadedBriefing = true
        isLoadingBriefing = true

        let payload: [String: Any] = [
            "revenue": monthlyRevenue,
            "expenses": monthlyExpenses,
            "netProfit": netProfit,
            "profitTrend": profitTrendPercent ?? 0,
            "outstanding": totalOutstanding,
            "topTimeClient": heroClient?.name ?? "none",
            "weeklyHours": selectedWeek?.totalHours ?? 0
        ]

        briefingTask = Task {
            let result = await claudeService.generateBriefing(tab: .metrics, dataPayload: payload)
            briefing = result
            isLoadingBriefing = false
            briefingTask = nil
            if result == nil { hasLoadedBriefing = false }
        }
    }

    // MARK: - Briefing Fallbacks

    var fallbackHeadline: String {
        if netProfit > 0 {
            return "$\(String(format: "%.0f", netProfit)) profit this month"
        } else if netProfit < 0 {
            return "$\(String(format: "%.0f", abs(netProfit))) loss this month"
        }
        return "Breaking even this month"
    }

    var fallbackSummary: String {
        var parts: [String] = []
        if monthlyRevenue > 0 {
            parts.append("Revenue: $\(String(format: "%.0f", monthlyRevenue))")
        }
        if monthlyExpenses > 0 {
            parts.append("Expenses: $\(String(format: "%.0f", monthlyExpenses))")
        }
        if let trend = profitTrendPercent {
            let arrow = trend >= 0 ? "up" : "down"
            parts.append("\(arrow) \(Int(abs(trend)))% vs last period")
        }
        if parts.isEmpty { return "No financial data yet. Create invoices and log expenses to see your metrics." }
        return parts.joined(separator: ". ") + "."
    }

    var currentMonthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
}
