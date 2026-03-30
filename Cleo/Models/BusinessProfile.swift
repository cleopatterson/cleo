import Foundation
import CoreData

/// Singleton business profile entity (§4.6, §8)
@objc(BusinessProfile)
public class BusinessProfile: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?

    // Business details
    @NSManaged public var businessName: String
    @NSManaged public var abn: String?
    @NSManaged public var address: String?
    @NSManaged public var email: String?
    @NSManaged public var phone: String?
    @NSManaged public var logoImagePath: String?
    @NSManaged public var tagline: String?

    // Personalisation
    @NSManaged public var appDisplayName: String     // "Cleo", "Arkie", etc.
    @NSManaged public var brandAccentHex: String     // "#b794f6"
    @NSManaged public var isOnboarded: Bool

    // Payment details (printed on invoices)
    @NSManaged public var accountName: String?   // Bank account name (may differ from business name)
    @NSManaged public var bankName: String?
    @NSManaged public var bsb: String?
    @NSManaged public var accountNumber: String?
    @NSManaged public var payID: String?

    // Invoice defaults
    @NSManaged public var defaultTaxRate: Double       // 0.10 for 10% GST
    @NSManaged public var defaultPaymentTermsDays: Int16
    @NSManaged public var invoicePrefix: String        // "INV"
    @NSManaged public var nextInvoiceSequence: Int32   // auto-incrementing
}
