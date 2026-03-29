import Foundation
import CoreData

// MARK: - Invoice Status

enum InvoiceStatus: String, CaseIterable, Codable {
    case draft
    case sent
    case paid
    case overdue

    var label: String {
        rawValue.capitalized
    }

    var emoji: String {
        switch self {
        case .draft: "📝"
        case .sent: "📨"
        case .paid: "💰"
        case .overdue: "🔴"
        }
    }
}

// MARK: - Payment Terms

enum PaymentTerms: Int, CaseIterable, Codable {
    case net7 = 7
    case net14 = 14
    case net30 = 30
    case net60 = 60

    var label: String {
        "Net \(rawValue)"
    }
}

// MARK: - Invoice (Core Data Managed Object)

@objc(Invoice)
public class Invoice: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var invoiceNumber: String      // INV-2026-0001
    @NSManaged public var clientName: String
    @NSManaged public var clientEmail: String
    @NSManaged public var clientAddress: String?
    @NSManaged public var issueDate: Date?
    @NSManaged public var dueDate: Date?
    @NSManaged public var paymentTermsDays: Int16
    @NSManaged public var statusRaw: String
    @NSManaged public var sentDate: Date?
    @NSManaged public var paidDate: Date?
    @NSManaged public var notes: String?
    @NSManaged public var taxRate: Double             // default 0.10 GST
    @NSManaged public var pdfData: Data?
    @NSManaged public var lineItems: NSSet?

    var status: InvoiceStatus {
        get {
            // Overdue is computed: sent + past due
            if statusRaw == InvoiceStatus.sent.rawValue, let due = dueDate, due < Date() {
                return .overdue
            }
            return InvoiceStatus(rawValue: statusRaw) ?? .draft
        }
        set { statusRaw = newValue.rawValue }
    }

    var paymentTerms: PaymentTerms {
        get { PaymentTerms(rawValue: Int(paymentTermsDays)) ?? .net14 }
        set { paymentTermsDays = Int16(newValue.rawValue) }
    }

    var lineItemsArray: [InvoiceLineItem] {
        let set = lineItems as? Set<InvoiceLineItem> ?? []
        return set.sorted { $0.sortOrder < $1.sortOrder }
    }

    var subtotal: Double {
        lineItemsArray.reduce(0) { $0 + ($1.quantity * $1.unitPrice) }
    }

    var taxAmount: Double {
        subtotal * taxRate
    }

    var total: Double {
        subtotal + taxAmount
    }
}
