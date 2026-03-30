import CoreData
import Foundation

/// One-time backfill of Tony's historical invoices and software expenses (FY 2025-26).
/// Runs only if UserDefaults flag "didSeedHistoricalData" is false.
struct DataSeeder {

    static func seedIfNeeded(context: NSManagedObjectContext) {
        // Check if invoices already exist rather than relying on a flag,
        // so re-installs and fresh builds always get the seed data.
        let request = NSFetchRequest<Invoice>(entityName: "Invoice")
        request.fetchLimit = 1
        let count = (try? context.count(for: request)) ?? 0
        guard count == 0 else { return }
        seed(context: context)
    }

    // MARK: - Data

    private struct InvoiceRecord {
        let number: String
        let date: DateComponents
        let dueDate: DateComponents
        let retainer: Double
        let software: Double   // 0 = no software line
        let description: String
    }

    private static let invoices: [InvoiceRecord] = [
        InvoiceRecord(number: "00008", date: dc(2025, 7, 14),  dueDate: dc(2025, 7, 18),  retainer: 15000, software: 0,   description: "Pilot monthly retainer 04"),
        InvoiceRecord(number: "00009", date: dc(2025, 8, 23),  dueDate: dc(2025, 8, 29),  retainer: 15000, software: 0,   description: "Pilot monthly retainer 05"),
        InvoiceRecord(number: "00010", date: dc(2025, 9, 15),  dueDate: dc(2025, 9, 19),  retainer: 15000, software: 0,   description: "Pilot monthly retainer 06"),
        InvoiceRecord(number: "00011", date: dc(2025, 10, 16), dueDate: dc(2025, 10, 21), retainer: 15000, software: 445, description: "Pilot monthly retainer 07"),
        InvoiceRecord(number: "00012", date: dc(2025, 11, 14), dueDate: dc(2025, 11, 20), retainer: 15000, software: 461, description: "Integration monthly retainer 01"),
        InvoiceRecord(number: "00013", date: dc(2025, 12, 15), dueDate: dc(2025, 12, 20), retainer: 15000, software: 461, description: "Integration monthly retainer 02"),
        InvoiceRecord(number: "000014", date: dc(2026, 1, 15), dueDate: dc(2026, 1, 20),  retainer: 15000, software: 461, description: "Integration monthly retainer 03"),
        InvoiceRecord(number: "000015", date: dc(2026, 2, 14), dueDate: dc(2026, 2, 20),  retainer: 15000, software: 607, description: "Integration monthly retainer 04"),
        InvoiceRecord(number: "000016", date: dc(2026, 3, 16), dueDate: dc(2026, 3, 20),  retainer: 15000, software: 632, description: "Integration monthly retainer 05"),
    ]

    // MARK: - Seed

    private static func seed(context: NSManagedObjectContext) {
        let cal = Calendar.current

        for record in invoices {
            guard let issueDate = cal.date(from: record.date),
                  let dueDate = cal.date(from: record.dueDate) else { continue }

            // Invoice
            let invoice = Invoice(context: context)
            invoice.id = UUID()
            invoice.invoiceNumber = record.number
            invoice.clientName = "Oliver Pennington"
            invoice.clientEmail = "oliver@serviceseeking.com.au"
            invoice.clientAddress = "1 Bulkara Rd, Bellevue Hill NSW 2023"
            invoice.issueDate = issueDate
            invoice.dueDate = dueDate
            invoice.paymentTermsDays = 7
            invoice.statusRaw = InvoiceStatus.paid.rawValue
            invoice.sentDate = issueDate
            invoice.paidDate = dueDate
            invoice.taxRate = 0.0  // No GST until April 2026
            invoice.notes = nil

            // Line item 1: retainer
            let retainerItem = InvoiceLineItem(context: context)
            retainerItem.id = UUID()
            retainerItem.itemDescription = record.description
            retainerItem.quantity = 1
            retainerItem.unitPrice = record.retainer
            retainerItem.sortOrder = 0
            retainerItem.invoice = invoice

            // Line item 2: software (if applicable)
            if record.software > 0 {
                let softwareItem = InvoiceLineItem(context: context)
                softwareItem.id = UUID()
                softwareItem.itemDescription = "Software monthly expenses"
                softwareItem.quantity = 1
                softwareItem.unitPrice = record.software
                softwareItem.sortOrder = 1
                softwareItem.invoice = invoice

                // Matching expense record
                let expense = Expense(context: context)
                expense.id = UUID()
                expense.amount = record.software
                expense.categoryRaw = ExpenseCategory.software.rawValue
                expense.date = issueDate
                expense.note = "Software reimbursed by Service Seeking — \(record.description)"
                expense.isRecurring = true
            }
        }

        // Service Seeking client record
        let client = Client(context: context)
        client.id = UUID()
        client.name = "Oliver Pennington"
        client.email = "oliver@serviceseeking.com.au"
        client.phone = nil
        client.address = "1 Bulkara Rd, Bellevue Hill NSW 2023"
        client.defaultPaymentTermsDays = 7
        client.isPinned = true

        do {
            try context.save()
        } catch {
            print("DataSeeder save error: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private static func dc(_ year: Int, _ month: Int, _ day: Int) -> DateComponents {
        DateComponents(year: year, month: month, day: day)
    }
}
