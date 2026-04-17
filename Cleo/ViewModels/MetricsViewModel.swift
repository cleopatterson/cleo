import Foundation
import CoreData

@MainActor
@Observable
class MetricsViewModel {
    let timeService: TimeTrackingService
    let persistence: PersistenceController
    let trustSyncService: TrustSyncService

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

    @ObservationIgnored private var hasLoadedData = false

    init(timeService: TimeTrackingService,
         claudeService: ClaudeAPIService,
         persistence: PersistenceController,
         trustSyncService: TrustSyncService) {
        self.timeService = timeService
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

    // MARK: - Annual P&L

    struct MonthlyPLPoint: Identifiable {
        let id = UUID()
        let shortMonth: String
        let yearMonth: String
        let revenue: Double
        let expenses: Double
        var netProfit: Double { revenue - expenses }
        let isFuture: Bool
        let isCurrentMonth: Bool
    }

    private(set) var annualPLPoints: [MonthlyPLPoint] = []

    var annualRevenue: Double  { annualPLPoints.filter { !$0.isFuture }.reduce(0) { $0 + $1.revenue } }
    var annualExpenses: Double { annualPLPoints.filter { !$0.isFuture }.reduce(0) { $0 + $1.expenses } }
    var annualNetProfit: Double { annualRevenue - annualExpenses }

    var fyLabel: String {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let month = cal.component(.month, from: Date())
        let fy = month >= 7 ? (year + 1) % 100 : year % 100
        return "FY\(String(format: "%02d", fy))"
    }

    func refreshAnnualPL() {
        let cal = Calendar.current
        let now = Date()
        let currentMonth = cal.component(.month, from: now)
        let currentYear  = cal.component(.year,  from: now)
        let fyStartYear  = currentMonth >= 7 ? currentYear : currentYear - 1

        let ymFmt = DateFormatter(); ymFmt.dateFormat = "yyyy-MM"
        let moFmt = DateFormatter(); moFmt.dateFormat = "MMM"

        // Build 12 months Jul → Jun
        var fyMonths: [(ym: String, short: String, date: Date, isFuture: Bool, isCurrent: Bool)] = []
        let currentYM = ymFmt.string(from: now)
        for i in 0..<12 {
            let month = (6 + i) % 12 + 1
            let year  = month >= 7 ? fyStartYear : fyStartYear + 1
            var dc = DateComponents(); dc.year = year; dc.month = month; dc.day = 1
            guard let date = cal.date(from: dc) else { continue }
            fyMonths.append((ymFmt.string(from: date), moFmt.string(from: date), date, date > now, ymFmt.string(from: date) == currentYM))
        }

        // Read directly from local viewContext — no CloudKit dependency
        guard let fyStart = fyMonths.first?.date,
              let lastMonth = fyMonths.last,
              let fyEnd = cal.date(byAdding: .month, value: 1, to: lastMonth.date) else { return }

        let invReq = NSFetchRequest<Invoice>(entityName: "Invoice")
        invReq.predicate = NSPredicate(format: "issueDate >= %@ AND issueDate < %@",
                                       fyStart as NSDate, fyEnd as NSDate)
        let invoices = (try? persistence.viewContext.fetch(invReq)) ?? []

        let expReq = NSFetchRequest<Expense>(entityName: "Expense")
        expReq.predicate = NSPredicate(format: "date >= %@ AND date < %@",
                                       fyStart as NSDate, fyEnd as NSDate)
        let expenses = (try? persistence.viewContext.fetch(expReq)) ?? []

        var revenueByYM: [String: Double] = [:]
        var expensesByYM: [String: Double] = [:]
        for inv in invoices { revenueByYM[ymFmt.string(from: inv.issueDate ?? now), default: 0] += inv.total }
        for exp in expenses { expensesByYM[ymFmt.string(from: exp.date ?? now), default: 0] += exp.amount }

        annualPLPoints = fyMonths.map { m in
            MonthlyPLPoint(
                shortMonth: m.short,
                yearMonth: m.ym,
                revenue: revenueByYM[m.ym] ?? 0,
                expenses: expensesByYM[m.ym] ?? 0,
                isFuture: m.isFuture,
                isCurrentMonth: m.isCurrent
            )
        }
    }

    // MARK: - Load

    func loadData() async {
        guard !hasLoadedData else { return }
        hasLoadedData = true
        await timeService.loadIfNeeded()
        refreshFinancials()
        trustAggregate = trustSyncService.combinedMonthlyData()
        basQuarter = trustSyncService.currentQuarterBAS()
        refreshAnnualPL()
    }

    // MARK: - Briefing Fallbacks (kept for other tabs that may reference)

    var currentMonthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
}
