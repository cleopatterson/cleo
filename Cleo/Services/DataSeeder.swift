import CoreData
import Foundation

/// One-time backfill of historical invoices (FY 2025-26).
/// Runs only if no invoices exist yet. Seeds data based on the business profile name.
struct DataSeeder {

    static func seedIfNeeded(context: NSManagedObjectContext) {
        let request = NSFetchRequest<Invoice>(entityName: "Invoice")
        request.fetchLimit = 1
        let count = (try? context.count(for: request)) ?? 0
        guard count == 0 else { return }

        // Check business name to determine whose data to seed
        let profileRequest = NSFetchRequest<BusinessProfile>(entityName: "BusinessProfile")
        let profile = (try? context.fetch(profileRequest))?.first
        let name = (profile?.businessName ?? "").lowercased()

        if name.contains("arkie") {
            seedCleoData(context: context)
        } else {
            seedTonyData(context: context)
        }
    }

    // MARK: - Helpers

    private static func dc(_ year: Int, _ month: Int, _ day: Int) -> DateComponents {
        DateComponents(year: year, month: month, day: day)
    }

    private static func makeClient(
        context: NSManagedObjectContext,
        name: String,
        email: String,
        terms: Int16 = 14,
        isPinned: Bool = false
    ) -> Client {
        let client = Client(context: context)
        client.id = UUID()
        client.name = name
        client.email = email
        client.defaultPaymentTermsDays = terms
        client.isPinned = isPinned
        return client
    }

    private static func makeInvoice(
        context: NSManagedObjectContext,
        number: String,
        clientName: String,
        clientEmail: String,
        issueDate: Date,
        dueDate: Date,
        terms: Int16 = 14,
        status: InvoiceStatus,
        sentDate: Date? = nil,
        paidDate: Date? = nil,
        taxRate: Double,
        description: String,
        amount: Double
    ) {
        let invoice = Invoice(context: context)
        invoice.id = UUID()
        invoice.invoiceNumber = number
        invoice.clientName = clientName
        invoice.clientEmail = clientEmail
        invoice.issueDate = issueDate
        invoice.dueDate = dueDate
        invoice.paymentTermsDays = terms
        invoice.statusRaw = status.rawValue
        invoice.sentDate = sentDate
        invoice.paidDate = paidDate
        invoice.taxRate = taxRate
        invoice.notes = nil

        let item = InvoiceLineItem(context: context)
        item.id = UUID()
        item.itemDescription = description
        item.quantity = 1
        item.unitPrice = amount
        item.sortOrder = 0
        item.invoice = invoice
    }

    // MARK: - Tony's Data (Service Seeking)

    private struct TonyInvoiceRecord {
        let number: String
        let date: DateComponents
        let dueDate: DateComponents
        let retainer: Double
        let software: Double
        let description: String
    }

    private static let tonyInvoices: [TonyInvoiceRecord] = [
        TonyInvoiceRecord(number: "00008", date: dc(2025, 7, 14),  dueDate: dc(2025, 7, 18),  retainer: 15000, software: 0,   description: "Pilot monthly retainer 04"),
        TonyInvoiceRecord(number: "00009", date: dc(2025, 8, 23),  dueDate: dc(2025, 8, 29),  retainer: 15000, software: 0,   description: "Pilot monthly retainer 05"),
        TonyInvoiceRecord(number: "00010", date: dc(2025, 9, 15),  dueDate: dc(2025, 9, 19),  retainer: 15000, software: 0,   description: "Pilot monthly retainer 06"),
        TonyInvoiceRecord(number: "00011", date: dc(2025, 10, 16), dueDate: dc(2025, 10, 21), retainer: 15000, software: 445, description: "Pilot monthly retainer 07"),
        TonyInvoiceRecord(number: "00012", date: dc(2025, 11, 14), dueDate: dc(2025, 11, 20), retainer: 15000, software: 461, description: "Integration monthly retainer 01"),
        TonyInvoiceRecord(number: "00013", date: dc(2025, 12, 15), dueDate: dc(2025, 12, 20), retainer: 15000, software: 461, description: "Integration monthly retainer 02"),
        TonyInvoiceRecord(number: "00014", date: dc(2026, 1, 15),  dueDate: dc(2026, 1, 20),  retainer: 15000, software: 461, description: "Integration monthly retainer 03"),
        TonyInvoiceRecord(number: "00015", date: dc(2026, 2, 14),  dueDate: dc(2026, 2, 20),  retainer: 15000, software: 607, description: "Integration monthly retainer 04"),
        TonyInvoiceRecord(number: "00016", date: dc(2026, 3, 16),  dueDate: dc(2026, 3, 20),  retainer: 15000, software: 632, description: "Integration monthly retainer 05"),
    ]

    private static func seedTonyData(context: NSManagedObjectContext) {
        let cal = Calendar.current

        for record in tonyInvoices {
            guard let issueDate = cal.date(from: record.date),
                  let dueDate = cal.date(from: record.dueDate) else { continue }

            let invoice = Invoice(context: context)
            invoice.id = UUID()
            invoice.invoiceNumber = record.number
            invoice.clientName = "Service Seeking"
            invoice.clientEmail = "oliver@serviceseeking.com.au"
            invoice.clientAddress = "1 Bulkara Rd, Bellevue Hill NSW 2023"
            invoice.issueDate = issueDate
            invoice.dueDate = dueDate
            invoice.paymentTermsDays = 7
            invoice.statusRaw = InvoiceStatus.paid.rawValue
            invoice.sentDate = issueDate
            invoice.paidDate = dueDate
            invoice.taxRate = 0.0
            invoice.notes = nil

            let retainerItem = InvoiceLineItem(context: context)
            retainerItem.id = UUID()
            retainerItem.itemDescription = record.description
            retainerItem.quantity = 1
            retainerItem.unitPrice = record.retainer
            retainerItem.sortOrder = 0
            retainerItem.invoice = invoice

            if record.software > 0 {
                let softwareItem = InvoiceLineItem(context: context)
                softwareItem.id = UUID()
                softwareItem.itemDescription = "Software monthly expenses"
                softwareItem.quantity = 1
                softwareItem.unitPrice = record.software
                softwareItem.sortOrder = 1
                softwareItem.invoice = invoice

                let expense = Expense(context: context)
                expense.id = UUID()
                expense.amount = record.software
                expense.categoryRaw = ExpenseCategory.software.rawValue
                expense.date = issueDate
                expense.note = "Software reimbursed by Service Seeking — \(record.description)"
                expense.isRecurring = true
            }
        }

        let profileRequest = NSFetchRequest<BusinessProfile>(entityName: "BusinessProfile")
        if let profile = (try? context.fetch(profileRequest))?.first {
            profile.invoicePrefix = ""
            profile.nextInvoiceSequence = 17
        }

        let client = Client(context: context)
        client.id = UUID()
        client.name = "Service Seeking"
        client.email = "oliver@serviceseeking.com.au"
        client.phone = nil
        client.address = "1 Bulkara Rd, Bellevue Hill NSW 2023"
        client.defaultPaymentTermsDays = 7
        client.isPinned = true

        do {
            try context.save()
        } catch {
            print("DataSeeder (Tony) save error: \(error.localizedDescription)")
        }
    }

    // MARK: - Cleo's Data (Arkie & Co)

    private static func seedCleoData(context: NSManagedObjectContext) {
        let cal = Calendar.current

        // Clients
        _ = makeClient(context: context, name: "Casey Vincent", email: "", isPinned: false)
        _ = makeClient(context: context, name: "Tristan Barnes", email: "", isPinned: true)
        _ = makeClient(context: context, name: "Nina Stromqvist", email: "", isPinned: false)
        _ = makeClient(context: context, name: "Nimmi Demel", email: "", isPinned: false)
        _ = makeClient(context: context, name: "Kate Stirling", email: "", isPinned: false)
        _ = makeClient(context: context, name: "Elle Johnson", email: "", isPinned: false)
        _ = makeClient(context: context, name: "Angela Mayer", email: "", isPinned: false)
        _ = makeClient(context: context, name: "Jess Mcleod", email: "", isPinned: false)
        _ = makeClient(context: context, name: "Johanna Rigg-Smith", email: "", isPinned: true)
        _ = makeClient(context: context, name: "Liza Goodall", email: "", isPinned: false)
        _ = makeClient(context: context, name: "Jess Stirling", email: "", isPinned: false)
        _ = makeClient(context: context, name: "Emma Maxwell", email: "", isPinned: false)
        _ = makeClient(context: context, name: "Ethan McDonald", email: "", isPinned: false)
        _ = makeClient(context: context, name: "Indira", email: "", isPinned: false)
        _ = makeClient(context: context, name: "Kylie Snook", email: "", isPinned: false)
        _ = makeClient(context: context, name: "Katie McDonald", email: "", isPinned: true)
        _ = makeClient(context: context, name: "Meera", email: "", isPinned: false)

        // Helper to build dates
        func d(_ year: Int, _ month: Int, _ day: Int) -> Date {
            cal.date(from: dc(year, month, day)) ?? Date()
        }

        // --- FY 25/26 Paid invoices (pre-April 2026 — no GST) ---

        makeInvoice(context: context, number: "#2506001",
                    clientName: "Casey Vincent", clientEmail: "",
                    issueDate: d(2025, 6, 26), dueDate: d(2025, 7, 10), terms: 14,
                    status: .paid, sentDate: d(2025, 6, 26), paidDate: d(2025, 7, 29),
                    taxRate: 0.0,
                    description: "Business Performance Coaching and Marketing", amount: 1550)

        makeInvoice(context: context, number: "#2506002",
                    clientName: "Tristan Barnes", clientEmail: "",
                    issueDate: d(2025, 6, 27), dueDate: d(2025, 7, 11), terms: 14,
                    status: .paid, sentDate: d(2025, 6, 27), paidDate: d(2025, 8, 10),
                    taxRate: 0.0,
                    description: "Template project (12-15 hours)", amount: 2100)

        makeInvoice(context: context, number: "#2506003A",
                    clientName: "Tristan Barnes", clientEmail: "",
                    issueDate: d(2025, 6, 27), dueDate: d(2025, 7, 11), terms: 14,
                    status: .paid, sentDate: d(2025, 6, 27), paidDate: d(2025, 8, 10),
                    taxRate: 0.0,
                    description: "Change Management Coaching June-October 2025", amount: 880)

        makeInvoice(context: context, number: "#2509001",
                    clientName: "Nina Stromqvist", clientEmail: "",
                    issueDate: d(2025, 9, 10), dueDate: d(2025, 9, 24), terms: 14,
                    status: .paid, sentDate: d(2025, 9, 10), paidDate: d(2025, 9, 24),
                    taxRate: 0.0,
                    description: "Workshop: Roadmap planning & Coaching", amount: 292.50)

        makeInvoice(context: context, number: "#2509002",
                    clientName: "Nimmi Demel", clientEmail: "",
                    issueDate: d(2025, 9, 22), dueDate: d(2025, 10, 6), terms: 14,
                    status: .paid, sentDate: d(2025, 9, 22), paidDate: d(2025, 10, 6),
                    taxRate: 0.0,
                    description: "Six month Performance Program - Part 1", amount: 960)

        makeInvoice(context: context, number: "#2509003",
                    clientName: "Nimmi Demel", clientEmail: "",
                    issueDate: d(2025, 12, 2), dueDate: d(2025, 12, 16), terms: 14,
                    status: .paid, sentDate: d(2025, 12, 2), paidDate: d(2025, 12, 16),
                    taxRate: 0.0,
                    description: "Six month Performance Program - Part 2", amount: 960)

        makeInvoice(context: context, number: "#2509004",
                    clientName: "Tristan Barnes", clientEmail: "",
                    issueDate: d(2025, 9, 24), dueDate: d(2025, 10, 8), terms: 14,
                    status: .paid, sentDate: d(2025, 9, 24), paidDate: d(2025, 10, 8),
                    taxRate: 0.0,
                    description: "Heidi AI template instruction creation for NEW patient / Breast / GC (extract)", amount: 750)

        makeInvoice(context: context, number: "#2510001",
                    clientName: "Kate Stirling", clientEmail: "",
                    issueDate: d(2025, 10, 24), dueDate: d(2025, 11, 7), terms: 14,
                    status: .paid, sentDate: d(2025, 10, 24), paidDate: d(2025, 11, 7),
                    taxRate: 0.0,
                    description: "Strategic Work Life Workshop (90 mins)", amount: 270)

        makeInvoice(context: context, number: "#2510002",
                    clientName: "Elle Johnson", clientEmail: "",
                    issueDate: d(2025, 10, 8), dueDate: d(2025, 10, 22), terms: 14,
                    status: .paid, sentDate: d(2025, 10, 8), paidDate: d(2025, 10, 22),
                    taxRate: 0.0,
                    description: "One month Engagement - Recruitment Coaching", amount: 540)

        makeInvoice(context: context, number: "#2510003",
                    clientName: "Angela Mayer", clientEmail: "",
                    issueDate: d(2025, 10, 13), dueDate: d(2025, 10, 27), terms: 14,
                    status: .paid, sentDate: d(2025, 10, 13), paidDate: d(2025, 10, 27),
                    taxRate: 0.0,
                    description: "Recruitment Coaching", amount: 900)

        makeInvoice(context: context, number: "#2510004",
                    clientName: "Jess Mcleod", clientEmail: "",
                    issueDate: d(2025, 10, 16), dueDate: d(2025, 10, 30), terms: 14,
                    status: .paid, sentDate: d(2025, 10, 16), paidDate: d(2025, 10, 30),
                    taxRate: 0.0,
                    description: "Work Life Workshop Two Hours", amount: 595)

        makeInvoice(context: context, number: "#2510005",
                    clientName: "Johanna Rigg-Smith", clientEmail: "",
                    issueDate: d(2025, 10, 24), dueDate: d(2025, 11, 7), terms: 14,
                    status: .paid, sentDate: d(2025, 10, 24), paidDate: d(2025, 11, 7),
                    taxRate: 0.0,
                    description: "Performance Intensive Part 1", amount: 650)

        makeInvoice(context: context, number: "#2511001",
                    clientName: "Johanna Rigg-Smith", clientEmail: "",
                    issueDate: d(2025, 11, 24), dueDate: d(2025, 12, 8), terms: 14,
                    status: .paid, sentDate: d(2025, 11, 24), paidDate: d(2025, 12, 8),
                    taxRate: 0.0,
                    description: "Performance Intensive Part 2", amount: 650)

        makeInvoice(context: context, number: "#2511002",
                    clientName: "Jess Stirling", clientEmail: "",
                    issueDate: d(2025, 12, 2), dueDate: d(2025, 12, 16), terms: 14,
                    status: .paid, sentDate: d(2025, 12, 2), paidDate: d(2025, 12, 16),
                    taxRate: 0.0,
                    description: "Strategic Work Life Workshop (90 mins)", amount: 270)

        makeInvoice(context: context, number: "#251103",
                    clientName: "Liza Goodall", clientEmail: "",
                    issueDate: d(2025, 11, 14), dueDate: d(2025, 11, 28), terms: 14,
                    status: .paid, sentDate: d(2025, 11, 14), paidDate: d(2025, 11, 28),
                    taxRate: 0.0,
                    description: "Strategic Work Life Workshop (90 mins) - deposit", amount: 300)

        makeInvoice(context: context, number: "#251104",
                    clientName: "Liza Goodall", clientEmail: "",
                    issueDate: d(2025, 12, 16), dueDate: d(2025, 12, 30), terms: 14,
                    status: .paid, sentDate: d(2025, 12, 16), paidDate: d(2025, 12, 30),
                    taxRate: 0.0,
                    description: "Strategic Work Life Workshop (90 mins) - remainder", amount: 300)

        makeInvoice(context: context, number: "#2512001",
                    clientName: "Johanna Rigg-Smith", clientEmail: "",
                    issueDate: d(2025, 12, 16), dueDate: d(2025, 12, 30), terms: 14,
                    status: .paid, sentDate: d(2025, 12, 16), paidDate: d(2025, 12, 30),
                    taxRate: 0.0,
                    description: "Performance Intensive Part 3", amount: 200)

        makeInvoice(context: context, number: "#2601001",
                    clientName: "Johanna Rigg-Smith", clientEmail: "",
                    issueDate: d(2026, 1, 27), dueDate: d(2026, 2, 10), terms: 14,
                    status: .paid, sentDate: d(2026, 1, 27), paidDate: d(2026, 2, 10),
                    taxRate: 0.0,
                    description: "Performance Intensive Part 4 - 27 Jan 60 mins", amount: 200)

        makeInvoice(context: context, number: "#2601002",
                    clientName: "Kate Stirling", clientEmail: "",
                    issueDate: d(2026, 1, 30), dueDate: d(2026, 2, 13), terms: 14,
                    status: .paid, sentDate: d(2026, 1, 30), paidDate: d(2026, 2, 13),
                    taxRate: 0.0,
                    description: "Job application readiness part 1", amount: 600)

        // --- March 2026 — Sent (no GST, pre-April) ---

        makeInvoice(context: context, number: "#260301",
                    clientName: "Emma Maxwell", clientEmail: "",
                    issueDate: d(2026, 3, 29), dueDate: d(2026, 4, 12), terms: 14,
                    status: .sent, sentDate: d(2026, 3, 29),
                    taxRate: 0.0,
                    description: "Deep-dive workshop - deposit", amount: 300)

        makeInvoice(context: context, number: "#260302",
                    clientName: "Ethan McDonald", clientEmail: "",
                    issueDate: d(2026, 3, 29), dueDate: d(2026, 4, 12), terms: 14,
                    status: .draft,
                    taxRate: 0.0,
                    description: "Job application readiness - $1200 - 25% discount", amount: 900)

        makeInvoice(context: context, number: "#260303",
                    clientName: "Indira", clientEmail: "",
                    issueDate: d(2026, 3, 29), dueDate: d(2026, 4, 12), terms: 14,
                    status: .sent, sentDate: d(2026, 3, 29),
                    taxRate: 0.0,
                    description: "Burnout Solution Session", amount: 249)

        makeInvoice(context: context, number: "#260304",
                    clientName: "Katie McDonald", clientEmail: "",
                    issueDate: d(2026, 3, 29), dueDate: d(2026, 4, 12), terms: 14,
                    status: .sent, sentDate: d(2026, 3, 29),
                    taxRate: 0.0,
                    description: "Rebrand communications strategy and delivery Part 1", amount: 2925)

        makeInvoice(context: context, number: "#260305",
                    clientName: "Katie McDonald", clientEmail: "",
                    issueDate: d(2026, 3, 29), dueDate: d(2026, 4, 12), terms: 14,
                    status: .sent, sentDate: d(2026, 3, 29),
                    taxRate: 0.0,
                    description: "Website build Part 1", amount: 1625)

        // --- April 2026 — Drafts (10% GST from April onwards) ---

        makeInvoice(context: context, number: "#260401",
                    clientName: "Emma Maxwell", clientEmail: "",
                    issueDate: d(2026, 4, 1), dueDate: d(2026, 4, 15), terms: 14,
                    status: .draft,
                    taxRate: 0.10,
                    description: "Deep-dive workshop - remainder", amount: 300)

        makeInvoice(context: context, number: "#260402",
                    clientName: "Kylie Snook", clientEmail: "",
                    issueDate: d(2026, 4, 1), dueDate: d(2026, 4, 15), terms: 14,
                    status: .draft,
                    taxRate: 0.10,
                    description: "Deep dive workshop", amount: 600)

        makeInvoice(context: context, number: "#260403",
                    clientName: "Katie McDonald", clientEmail: "",
                    issueDate: d(2026, 4, 1), dueDate: d(2026, 4, 15), terms: 14,
                    status: .draft,
                    taxRate: 0.10,
                    description: "Rebrand communications strategy and delivery Part 2", amount: 2925)

        makeInvoice(context: context, number: "#260404",
                    clientName: "Katie McDonald", clientEmail: "",
                    issueDate: d(2026, 4, 1), dueDate: d(2026, 4, 15), terms: 14,
                    status: .draft,
                    taxRate: 0.10,
                    description: "Website build Part 2", amount: 1625)

        makeInvoice(context: context, number: "#260405",
                    clientName: "Meera", clientEmail: "",
                    issueDate: d(2026, 4, 1), dueDate: d(2026, 4, 15), terms: 14,
                    status: .draft,
                    taxRate: 0.10,
                    description: "Presentation to Leadership Group", amount: 2000)

        // Set next invoice sequence past the seeded data
        let profileRequest = NSFetchRequest<BusinessProfile>(entityName: "BusinessProfile")
        if let profile = (try? context.fetch(profileRequest))?.first {
            profile.nextInvoiceSequence = 406  // next after #260405
        }

        do {
            try context.save()
        } catch {
            print("DataSeeder (Cleo) save error: \(error.localizedDescription)")
        }
    }
}
