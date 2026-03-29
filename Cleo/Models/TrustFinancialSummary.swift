import Foundation
import CoreData

@objc(TrustFinancialSummary)
public class TrustFinancialSummary: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var contributorID: String
    @NSManaged public var contributorName: String
    @NSManaged public var yearMonth: String              // "2026-03"
    @NSManaged public var totalInvoiced: Double
    @NSManaged public var totalPaid: Double
    @NSManaged public var totalOutstanding: Double
    @NSManaged public var invoiceCount: Int32
    @NSManaged public var gstCollected: Double
    @NSManaged public var gstOnExpenses: Double
    @NSManaged public var totalExpenses: Double
    @NSManaged public var expensesByCategoryJSON: String // JSON-encoded [String: Double]
    @NSManaged public var lastUpdated: Date?

    var expensesByCategory: [String: Double] {
        guard let data = expensesByCategoryJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return dict
    }
}
