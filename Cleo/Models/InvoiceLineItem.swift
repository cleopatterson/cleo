import Foundation
import CoreData

@objc(InvoiceLineItem)
public class InvoiceLineItem: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var itemDescription: String
    @NSManaged public var quantity: Double
    @NSManaged public var unitPrice: Double
    @NSManaged public var sortOrder: Int16
    @NSManaged public var invoice: Invoice?

    var lineTotal: Double {
        quantity * unitPrice
    }
}
