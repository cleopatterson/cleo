import Foundation
import CoreData

@objc(InvoiceLineItem)
public class InvoiceLineItem: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var itemDescription: String
    @NSManaged public var quantity: Double
    @NSManaged public var unitPrice: Double
    @NSManaged public var sortOrder: Int16
    @NSManaged public var discountPercent: Double
    @NSManaged public var invoice: Invoice?

    var lineTotal: Double {
        let base = quantity * unitPrice
        return base * (1.0 - discountPercent / 100.0)
    }
}
