import Foundation
import CoreData

@objc(TrustSettings)
public class TrustSettings: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var trustName: String
    @NSManaged public var trustABN: String
    @NSManaged public var monthlyIncomeTarget: Double   // default 20000
    @NSManaged public var estimatedTaxRate: Double      // default 0.30
    @NSManaged public var basQuarterStartMonth: Int16   // 7 = July (Australian FY)
    @NSManaged public var lastUpdated: Date?
    @NSManaged public var updatedBy: String             // contributorID of last editor
}
