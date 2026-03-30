import Foundation
import CoreData

// MARK: - Aggregate Value Types

struct TrustMonthlyAggregate {
    let contributors: [ContributorSummary]
    let combinedRevenue: Double
    let combinedExpenses: Double
    let netProfit: Double
    let gstCollected: Double
    let gstOnExpenses: Double
    let netGSTPayable: Double
    let taxProvision: Double
    let safeToSpend: Double
    let incomeTarget: Double
    let gapAmount: Double
    let gapPercent: Double      // 0–100
    let isSoloMode: Bool

    static var empty: TrustMonthlyAggregate {
        TrustMonthlyAggregate(
            contributors: [], combinedRevenue: 0, combinedExpenses: 0,
            netProfit: 0, gstCollected: 0, gstOnExpenses: 0,
            netGSTPayable: 0, taxProvision: 0, safeToSpend: 0,
            incomeTarget: 20000, gapAmount: 20000, gapPercent: 0, isSoloMode: true
        )
    }
}

struct ContributorSummary {
    let name: String
    let revenue: Double
    let expenses: Double
    let gstCollected: Double
}

struct BASQuarterSummary {
    let quarterLabel: String
    let quarterStart: Date
    let quarterEnd: Date
    let dueDate: Date
    let daysUntilDue: Int
    let gstCollected: Double    // Field 1A
    let gstOnExpenses: Double   // Field 1B
    let netGSTPayable: Double   // 1A - 1B
    let totalRevenue: Double
    let totalExpenses: Double
    let taxProvision: Double
    let notYourMoney: Double    // netGSTPayable + taxProvision
}

// MARK: - TrustSyncService

@MainActor
@Observable
class TrustSyncService {
    private let persistence: PersistenceController

    var lastSyncDate: Date?
    var isConnected: Bool = false   // true once a partner's summary appears in the shared store

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    // MARK: - Settings

    func getOrCreateSettings() -> TrustSettings {
        let req = NSFetchRequest<TrustSettings>(entityName: "TrustSettings")
        req.fetchLimit = 1
        if let existing = try? persistence.sharedContext.fetch(req).first {
            return existing
        }
        let settings = TrustSettings(context: persistence.sharedContext)
        settings.id = UUID()
        settings.trustName = ""
        settings.trustABN = ""
        settings.monthlyIncomeTarget = 20000
        settings.estimatedTaxRate = 0.30
        settings.basQuarterStartMonth = 7
        settings.lastUpdated = Date()
        settings.updatedBy = ""
        persistence.saveShared()
        return settings
    }

    // MARK: - Push

    /// Backfills TrustFinancialSummary for every historical month that has invoice/expense data
    /// but no existing summary. Call once on first load after seeding.
    func backfillMonthlyHistory(invoices: [Invoice], expenses: [Expense], profile: BusinessProfile) async {
        let contributorID = profile.id?.uuidString ?? "unknown"
        let contributorName: String = {
            if !profile.appDisplayName.isEmpty { return profile.appDisplayName }
            if !profile.businessName.isEmpty   { return profile.businessName }
            return "Me"
        }()

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"

        // Group by month
        var invoicesByMonth: [String: [Invoice]] = [:]
        for inv in invoices {
            let ym = fmt.string(from: inv.issueDate ?? Date())
            invoicesByMonth[ym, default: []].append(inv)
        }
        var expensesByMonth: [String: [Expense]] = [:]
        for exp in expenses {
            let ym = fmt.string(from: exp.date ?? Date())
            expensesByMonth[ym, default: []].append(exp)
        }

        let allMonths = Set(invoicesByMonth.keys).union(Set(expensesByMonth.keys))
        let currentYM = currentYearMonth()

        for ym in allMonths {
            // Upsert — update existing record if present so numbers stay accurate
            let req = NSFetchRequest<TrustFinancialSummary>(entityName: "TrustFinancialSummary")
            req.predicate = NSPredicate(format: "contributorID == %@ AND yearMonth == %@", contributorID, ym)
            req.fetchLimit = 1

            // For the current month, skip — pushSummary handles that live
            if ym == currentYM { continue }

            let monthInvoices = invoicesByMonth[ym] ?? []
            let monthExpenses = expensesByMonth[ym] ?? []

            let totalInvoiced    = monthInvoices.reduce(0) { $0 + $1.total }
            let totalPaid        = monthInvoices.filter { $0.status == .paid }.reduce(0) { $0 + $1.total }
            let totalOutstanding = monthInvoices.filter { $0.status == .sent || $0.status == .overdue }.reduce(0) { $0 + $1.total }
            let gstCollected     = monthInvoices.reduce(0) { $0 + $1.taxAmount }
            let totalExpenses    = monthExpenses.reduce(0) { $0 + $1.amount }
            // Only apply GST-on-expenses formula for months where GST applies (Apr 2026+)
            let isGSTMonth       = ym >= "2026-04"
            let gstOnExpenses    = isGSTMonth ? totalExpenses / 11.0 : 0.0

            var categoryTotals: [String: Double] = [:]
            for exp in monthExpenses { categoryTotals[exp.categoryRaw, default: 0] += exp.amount }
            let categoryJSON = (try? String(data: JSONEncoder().encode(categoryTotals), encoding: .utf8)) ?? "{}"

            let summary: TrustFinancialSummary
            if let existing = try? persistence.sharedContext.fetch(req).first {
                summary = existing
            } else {
                summary = TrustFinancialSummary(context: persistence.sharedContext)
                summary.id = UUID()
                summary.contributorID = contributorID
            }
            summary.contributorName        = contributorName
            summary.yearMonth              = ym
            summary.totalInvoiced          = totalInvoiced
            summary.totalPaid              = totalPaid
            summary.totalOutstanding       = totalOutstanding
            summary.invoiceCount           = Int32(monthInvoices.count)
            summary.gstCollected           = gstCollected
            summary.gstOnExpenses          = gstOnExpenses
            summary.totalExpenses          = totalExpenses
            summary.expensesByCategoryJSON = categoryJSON
            summary.lastUpdated            = Date()
        }

        persistence.saveShared()
        lastSyncDate = Date()
    }

    /// Recalculates and upserts the current contributor's monthly summary.
    /// Call this after any invoice or expense mutation.
    func pushSummary(invoices: [Invoice], expenses: [Expense], profile: BusinessProfile) async {
        let contributorID = profile.id?.uuidString ?? "unknown"
        let contributorName: String = {
            if !profile.appDisplayName.isEmpty { return profile.appDisplayName }
            if !profile.businessName.isEmpty   { return profile.businessName }
            return "Me"
        }()
        let yearMonth = currentYearMonth()

        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()

        let monthInvoices = invoices.filter { ($0.issueDate ?? .distantPast) >= monthStart }
        let monthExpenses = expenses.filter { ($0.date ?? .distantPast) >= monthStart }

        let totalInvoiced   = monthInvoices.reduce(0) { $0 + $1.total }
        let totalPaid       = monthInvoices.filter { $0.status == .paid }.reduce(0) { $0 + $1.total }
        let totalOutstanding = monthInvoices.filter { $0.status == .sent || $0.status == .overdue }.reduce(0) { $0 + $1.total }
        let gstCollected    = monthInvoices.reduce(0) { $0 + $1.taxAmount }
        let totalExpenses   = monthExpenses.reduce(0) { $0 + $1.amount }
        let isGSTMonth      = currentYearMonth() >= "2026-04"
        let gstOnExpenses   = isGSTMonth ? totalExpenses / 11.0 : 0.0

        var categoryTotals: [String: Double] = [:]
        for exp in monthExpenses {
            categoryTotals[exp.categoryRaw, default: 0] += exp.amount
        }
        let categoryJSON = (try? String(data: JSONEncoder().encode(categoryTotals), encoding: .utf8)) ?? "{}"

        // Upsert
        let req = NSFetchRequest<TrustFinancialSummary>(entityName: "TrustFinancialSummary")
        req.predicate = NSPredicate(format: "contributorID == %@ AND yearMonth == %@", contributorID, yearMonth)
        req.fetchLimit = 1

        let summary: TrustFinancialSummary
        if let existing = try? persistence.sharedContext.fetch(req).first {
            summary = existing
        } else {
            summary = TrustFinancialSummary(context: persistence.sharedContext)
            summary.id = UUID()
            summary.contributorID = contributorID
        }

        summary.contributorName       = contributorName
        summary.yearMonth             = yearMonth
        summary.totalInvoiced         = totalInvoiced
        summary.totalPaid             = totalPaid
        summary.totalOutstanding      = totalOutstanding
        summary.invoiceCount          = Int32(monthInvoices.count)
        summary.gstCollected          = gstCollected
        summary.gstOnExpenses         = gstOnExpenses
        summary.totalExpenses         = totalExpenses
        summary.expensesByCategoryJSON = categoryJSON
        summary.lastUpdated           = Date()

        persistence.saveShared()
        lastSyncDate = Date()

        // Update isConnected: true if >1 contributor has data this month
        let allReq = NSFetchRequest<TrustFinancialSummary>(entityName: "TrustFinancialSummary")
        allReq.predicate = NSPredicate(format: "yearMonth == %@", yearMonth)
        let count = (try? persistence.sharedContext.count(for: allReq)) ?? 0
        isConnected = count > 1
    }

    // MARK: - Monthly Aggregate

    func combinedMonthlyData() -> TrustMonthlyAggregate {
        let settings = getOrCreateSettings()
        let yearMonth = currentYearMonth()

        let req = NSFetchRequest<TrustFinancialSummary>(entityName: "TrustFinancialSummary")
        req.predicate = NSPredicate(format: "yearMonth == %@", yearMonth)
        let summaries = (try? persistence.sharedContext.fetch(req)) ?? []

        let contributors = summaries.map {
            ContributorSummary(name: $0.contributorName, revenue: $0.totalInvoiced,
                               expenses: $0.totalExpenses, gstCollected: $0.gstCollected)
        }

        let combinedRevenue  = summaries.reduce(0) { $0 + $1.totalInvoiced }
        let combinedExpenses = summaries.reduce(0) { $0 + $1.totalExpenses }
        let gstCollected     = summaries.reduce(0) { $0 + $1.gstCollected }
        let gstOnExpenses    = summaries.reduce(0) { $0 + $1.gstOnExpenses }
        let netGSTPayable    = max(0, gstCollected - gstOnExpenses)
        let netProfit        = combinedRevenue - combinedExpenses
        let taxRate          = settings.estimatedTaxRate
        let taxProvision     = max(0, netProfit * taxRate)
        let safeToSpend      = combinedRevenue - combinedExpenses - netGSTPayable - taxProvision
        let incomeTarget     = settings.monthlyIncomeTarget
        let gapAmount        = max(0, incomeTarget - combinedRevenue)
        let gapPercent       = incomeTarget > 0 ? min(100, (combinedRevenue / incomeTarget) * 100) : 0

        return TrustMonthlyAggregate(
            contributors: contributors,
            combinedRevenue: combinedRevenue,
            combinedExpenses: combinedExpenses,
            netProfit: netProfit,
            gstCollected: gstCollected,
            gstOnExpenses: gstOnExpenses,
            netGSTPayable: netGSTPayable,
            taxProvision: taxProvision,
            safeToSpend: safeToSpend,
            incomeTarget: incomeTarget,
            gapAmount: gapAmount,
            gapPercent: gapPercent,
            isSoloMode: summaries.count <= 1
        )
    }

    // MARK: - BAS Quarter Summary

    func currentQuarterBAS() -> BASQuarterSummary {
        let settings = getOrCreateSettings()
        let quarter = BASQuarterHelper.currentQuarter()
        let months = BASQuarterHelper.monthStrings(for: quarter)

        let req = NSFetchRequest<TrustFinancialSummary>(entityName: "TrustFinancialSummary")
        req.predicate = NSPredicate(format: "yearMonth IN %@", months)
        let summaries = (try? persistence.sharedContext.fetch(req)) ?? []

        let gstCollected  = summaries.reduce(0) { $0 + $1.gstCollected }
        let gstOnExpenses = summaries.reduce(0) { $0 + $1.gstOnExpenses }
        let netGSTPayable = max(0, gstCollected - gstOnExpenses)
        let totalRevenue  = summaries.reduce(0) { $0 + $1.totalInvoiced }
        let totalExpenses = summaries.reduce(0) { $0 + $1.totalExpenses }
        let netProfit     = totalRevenue - totalExpenses
        let taxProvision  = max(0, netProfit * settings.estimatedTaxRate)
        let notYourMoney  = netGSTPayable + taxProvision

        return BASQuarterSummary(
            quarterLabel:  quarter.label,
            quarterStart:  quarter.start,
            quarterEnd:    quarter.end,
            dueDate:       quarter.dueDate,
            daysUntilDue:  quarter.daysUntilDue,
            gstCollected:  gstCollected,
            gstOnExpenses: gstOnExpenses,
            netGSTPayable: netGSTPayable,
            totalRevenue:  totalRevenue,
            totalExpenses: totalExpenses,
            taxProvision:  taxProvision,
            notYourMoney:  notYourMoney
        )
    }

    // MARK: - Helpers

    func currentYearMonth() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        return fmt.string(from: Date())
    }
}
