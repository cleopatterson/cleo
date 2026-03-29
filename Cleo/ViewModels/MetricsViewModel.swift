import Foundation
import CoreData

@MainActor
@Observable
class MetricsViewModel {
    let timeService: TimeTrackingService
    let claudeService: ClaudeAPIService
    let persistence: PersistenceController
    let trustSyncService: TrustSyncService

    var briefing: AIBriefingResponse?
    var isLoadingBriefing = false
    var selectedWeekIndex: Int = 0

    // Local financial cache (refreshed once per load)
    private(set) var monthlyRevenue: Double = 0
    private(set) var monthlyExpenses: Double = 0
    private(set) var previousPeriodRevenue: Double = 0
    private(set) var previousPeriodExpenses: Double = 0
    private(set) var totalOutstanding: Double = 0

    // Trust dashboard data
    private(set) var trustAggregate: TrustMonthlyAggregate = .empty
    private(set) var basQuarter: BASQuarterSummary?

    @ObservationIgnored private var hasLoadedBriefing = false

    init(timeService: TimeTrackingService,
         claudeService: ClaudeAPIService,
         persistence: PersistenceController,
         trustSyncService: TrustSyncService) {
        self.timeService = timeService
        self.claudeService = claudeService
        self.persistence = persistence
        self.trustSyncService = trustSyncService
    }

    // MARK: - Local Financial Data

    var netProfit: Double { monthlyRevenue - monthlyExpenses }
    var previousPeriodProfit: Double { previousPeriodRevenue - previousPeriodExpenses }

    var profitTrendPercent: Double? {
        guard previousPeriodProfit != 0 else {
            return netProfit > 0 ? 100 : nil
        }
        return ((netProfit - previousPeriodProfit) / abs(previousPeriodProfit)) * 100
    }

    func refreshFinancials() {
        let now = Date()
        let cal = Calendar.current
        let thirtyDaysAgo = cal.date(byAdding: .day, value: -30, to: now) ?? now
        let sixtyDaysAgo  = cal.date(byAdding: .day, value: -60, to: now) ?? now

        let revReq = NSFetchRequest<Invoice>(entityName: "Invoice")
        revReq.predicate = NSPredicate(format: "statusRaw == %@ AND paidDate >= %@", "paid", thirtyDaysAgo as NSDate)
        monthlyRevenue = ((try? persistence.viewContext.fetch(revReq)) ?? []).reduce(0) { $0 + $1.total }

        let expReq = NSFetchRequest<Expense>(entityName: "Expense")
        expReq.predicate = NSPredicate(format: "date >= %@", thirtyDaysAgo as NSDate)
        monthlyExpenses = ((try? persistence.viewContext.fetch(expReq)) ?? []).reduce(0) { $0 + $1.amount }

        let prevRevReq = NSFetchRequest<Invoice>(entityName: "Invoice")
        prevRevReq.predicate = NSPredicate(format: "statusRaw == %@ AND paidDate >= %@ AND paidDate < %@",
                                            "paid", sixtyDaysAgo as NSDate, thirtyDaysAgo as NSDate)
        previousPeriodRevenue = ((try? persistence.viewContext.fetch(prevRevReq)) ?? []).reduce(0) { $0 + $1.total }

        let prevExpReq = NSFetchRequest<Expense>(entityName: "Expense")
        prevExpReq.predicate = NSPredicate(format: "date >= %@ AND date < %@",
                                            sixtyDaysAgo as NSDate, thirtyDaysAgo as NSDate)
        previousPeriodExpenses = ((try? persistence.viewContext.fetch(prevExpReq)) ?? []).reduce(0) { $0 + $1.amount }

        let outReq = NSFetchRequest<Invoice>(entityName: "Invoice")
        outReq.predicate = NSPredicate(format: "statusRaw == %@", "sent")
        totalOutstanding = ((try? persistence.viewContext.fetch(outReq)) ?? []).reduce(0) { $0 + $1.total }
    }

    // MARK: - Time Tracking

    var weeks: [WeekSummary] { timeService.weeks.reversed() }

    var selectedWeek: WeekSummary? {
        guard selectedWeekIndex >= 0, selectedWeekIndex < weeks.count else { return nil }
        return weeks[selectedWeekIndex]
    }

    var canGoBack: Bool    { selectedWeekIndex < weeks.count - 1 }
    var canGoForward: Bool { selectedWeekIndex > 0 }

    func goToPreviousWeek() { if canGoBack    { selectedWeekIndex += 1 } }
    func goToNextWeek()     { if canGoForward { selectedWeekIndex -= 1 } }

    var heroClient: ClientHours? { selectedWeek?.clients.first }

    var heroPercentage: Int {
        guard let hero = heroClient, let week = selectedWeek, week.totalHours > 0 else { return 0 }
        return Int((hero.hours / week.totalHours) * 100)
    }

    var comparisonWeek: WeekSummary? {
        let prev = selectedWeekIndex + 1
        guard prev < weeks.count else { return nil }
        return weeks[prev]
    }

    var weekOverWeekChange: Double? {
        guard let prev = comparisonWeek, prev.totalHours > 0, let cur = selectedWeek else { return nil }
        return ((cur.totalHours - prev.totalHours) / prev.totalHours) * 100
    }

    // MARK: - Load

    func loadData() async {
        await timeService.loadIfNeeded()
        refreshFinancials()
        trustAggregate = trustSyncService.combinedMonthlyData()
        basQuarter = trustSyncService.currentQuarterBAS()
    }

    // MARK: - Briefing

    @ObservationIgnored private var briefingTask: Task<Void, Never>?

    func loadBriefing() {
        guard !hasLoadedBriefing || briefing == nil else { return }
        guard briefingTask == nil else { return }
        hasLoadedBriefing = true
        isLoadingBriefing = true

        let agg = trustAggregate
        let bas = basQuarter

        var payload: [String: Any] = [
            "revenue": monthlyRevenue,
            "expenses": monthlyExpenses,
            "netProfit": netProfit,
            "profitTrend": profitTrendPercent ?? 0,
            "outstanding": totalOutstanding,
            "topTimeClient": heroClient?.name ?? "none",
            "weeklyHours": selectedWeek?.totalHours ?? 0
        ]

        // Trust-level data (if available)
        if !agg.contributors.isEmpty {
            let contributorsPayload = agg.contributors.map { [
                "name": $0.name,
                "revenue": $0.revenue,
                "expenses": $0.expenses,
                "gstCollected": $0.gstCollected
            ] as [String: Any] }
            payload["contributors"] = contributorsPayload
            payload["combined"] = [
                "totalRevenue": agg.combinedRevenue,
                "totalExpenses": agg.combinedExpenses,
                "netProfit": agg.netProfit,
                "gstCollected": agg.gstCollected,
                "netGSTPayable": agg.netGSTPayable,
                "taxProvision": agg.taxProvision,
                "safeToSpend": agg.safeToSpend,
                "incomeTarget": agg.incomeTarget,
                "incomeGapPercent": Int(agg.gapPercent)
            ] as [String: Any]
        }

        if let bas {
            payload["bas"] = [
                "quarter": bas.quarterLabel,
                "daysUntilDue": bas.daysUntilDue,
                "netGSTPayable": bas.netGSTPayable,
                "taxProvision": bas.taxProvision,
                "notYourMoney": bas.notYourMoney
            ] as [String: Any]
        }

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
        let revenue = trustAggregate.combinedRevenue > 0 ? trustAggregate.combinedRevenue : monthlyRevenue
        if revenue > 0 {
            return "$\(String(format: "%.0f", revenue)) invoiced this month"
        }
        if netProfit > 0 {
            return "$\(String(format: "%.0f", netProfit)) profit this month"
        }
        return "No data yet this month"
    }

    var fallbackSummary: String {
        var parts: [String] = []
        if trustAggregate.combinedRevenue > 0 {
            parts.append("Revenue: $\(String(format: "%.0f", trustAggregate.combinedRevenue))")
        }
        if trustAggregate.combinedExpenses > 0 {
            parts.append("Expenses: $\(String(format: "%.0f", trustAggregate.combinedExpenses))")
        }
        if trustAggregate.netGSTPayable > 0 {
            parts.append("GST owed: $\(String(format: "%.0f", trustAggregate.netGSTPayable))")
        }
        if parts.isEmpty { return "Create invoices and log expenses to see your trust dashboard." }
        return parts.joined(separator: " · ")
    }

    var financialTagPills: [FinancialTagPill] {
        var tags: [FinancialTagPill] = []
        let revenue = trustAggregate.combinedRevenue > 0 ? trustAggregate.combinedRevenue : monthlyRevenue
        tags.append(FinancialTagPill(label: "Revenue", value: "$\(String(format: "%.0f", revenue))"))
        let expenses = trustAggregate.combinedExpenses > 0 ? trustAggregate.combinedExpenses : monthlyExpenses
        tags.append(FinancialTagPill(label: "Expenses", value: "$\(String(format: "%.0f", expenses))"))
        if trustAggregate.netGSTPayable > 0 {
            tags.append(FinancialTagPill(label: "GST owed", value: "$\(String(format: "%.0f", trustAggregate.netGSTPayable))"))
        }
        return tags
    }

    struct FinancialTagPill {
        let label: String
        let value: String
    }

    var currentMonthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
}
