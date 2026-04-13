import SwiftUI
import CoreData

@MainActor
@Observable
class InvoicingViewModel {
    let context: NSManagedObjectContext
    let claudeService: ClaudeAPIService
    let trustSyncService: TrustSyncService

    var invoices: [Invoice] = []
    var expenses: [Expense] = []
    var clients: [Client] = []
    var briefing: AIBriefingResponse?
    var isLoadingBriefing = false
    @ObservationIgnored private var hasLoadedBriefing = false

    init(context: NSManagedObjectContext,
         claudeService: ClaudeAPIService,
         trustSyncService: TrustSyncService) {
        self.context = context
        self.claudeService = claudeService
        self.trustSyncService = trustSyncService
        fetchInvoices()
        fetchExpenses()
        fetchClients()
        backfillAndPushTrust()
    }

    // MARK: - Fetch

    func fetchInvoices() {
        let request = NSFetchRequest<Invoice>(entityName: "Invoice")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Invoice.dueDate, ascending: true)]
        invoices = (try? context.fetch(request)) ?? []
    }

    func fetchExpenses() {
        let request = NSFetchRequest<Expense>(entityName: "Expense")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        expenses = (try? context.fetch(request)) ?? []
    }

    func fetchClients() {
        let request = NSFetchRequest<Client>(entityName: "Client")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Client.name, ascending: true)]
        clients = (try? context.fetch(request)) ?? []
    }

    // MARK: - Computed

    var sortedInvoices: [Invoice] {
        invoices.sorted { lhs, rhs in
            let order: [InvoiceStatus] = [.overdue, .sent, .draft, .paid]
            let lhsIdx = order.firstIndex(of: lhs.status) ?? 99
            let rhsIdx = order.firstIndex(of: rhs.status) ?? 99
            if lhsIdx != rhsIdx { return lhsIdx < rhsIdx }
            // Most recent first within each status group
            return (lhs.issueDate ?? .distantPast) > (rhs.issueDate ?? .distantPast)
        }
    }

    var heroInvoice: Invoice? {
        sortedInvoices.first { $0.status != .paid }
    }

    var totalOutstanding: Double {
        invoices.filter { $0.status == .sent || $0.status == .overdue }.reduce(0) { $0 + $1.total }
    }

    var monthlyRevenue: Double {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        return invoices
            .filter { $0.status == .paid && $0.paidDate ?? .distantPast >= start }
            .reduce(0) { $0 + $1.total }
    }

    var monthlyExpenses: Double {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        return expenses.filter { ($0.date ?? .distantPast) >= start }.reduce(0) { $0 + $1.amount }
    }

    // MARK: - CRUD

    // MARK: - Trust Sync

    private func pushTrustSummary() {
        let profile = PersistenceController.shared.getOrCreateBusinessProfile()
        Task {
            await trustSyncService.pushSummary(invoices: invoices, expenses: expenses, profile: profile)
        }
    }

    /// On first load, backfill historical monthly summaries then push current month.
    private func backfillAndPushTrust() {
        let profile = PersistenceController.shared.getOrCreateBusinessProfile()
        Task {
            await trustSyncService.backfillMonthlyHistory(invoices: invoices, expenses: expenses, profile: profile)
            await trustSyncService.pushSummary(invoices: invoices, expenses: expenses, profile: profile)
        }
    }

    // MARK: - CRUD

    func createInvoice(clientName: String, clientEmail: String, paymentTerms: PaymentTerms, lineItems: [(description: String, quantity: Double, unitPrice: Double)]) -> Invoice {
        let invoice = Invoice(context: context)
        invoice.id = UUID()
        invoice.invoiceNumber = PersistenceController.shared.nextInvoiceNumber()
        invoice.clientName = clientName
        invoice.clientEmail = clientEmail
        invoice.issueDate = Date()
        invoice.paymentTerms = paymentTerms
        invoice.dueDate = Calendar.current.date(byAdding: .day, value: paymentTerms.rawValue, to: Date())
        invoice.statusRaw = InvoiceStatus.draft.rawValue
        invoice.taxRate = PersistenceController.shared.getOrCreateBusinessProfile().defaultTaxRate

        for (i, item) in lineItems.enumerated() {
            let li = InvoiceLineItem(context: context)
            li.id = UUID()
            li.itemDescription = item.description
            li.quantity = item.quantity
            li.unitPrice = item.unitPrice
            li.sortOrder = Int16(i)
            li.invoice = invoice
        }

        PersistenceController.shared.save()
        fetchInvoices()
        pushTrustSummary()
        return invoice
    }

    func markAsSent(_ invoice: Invoice) {
        invoice.statusRaw = InvoiceStatus.sent.rawValue
        invoice.sentDate = Date()
        PersistenceController.shared.save()
        fetchInvoices()
        pushTrustSummary()
    }

    func markAsPaid(_ invoice: Invoice) {
        invoice.statusRaw = InvoiceStatus.paid.rawValue
        invoice.paidDate = Date()
        do {
            try context.save()
        } catch {
            print("markAsPaid save error: \(error.localizedDescription)")
        }
        fetchInvoices()
        pushTrustSummary()
    }

    func deleteInvoice(_ invoice: Invoice) {
        context.delete(invoice)
        PersistenceController.shared.save()
        fetchInvoices()
        pushTrustSummary()
    }

    func deleteExpense(_ expense: Expense) {
        context.delete(expense)
        PersistenceController.shared.save()
        fetchExpenses()
        pushTrustSummary()
    }

    func addExpense(amount: Double, category: ExpenseCategory, date: Date, note: String?) {
        let expense = Expense(context: context)
        expense.id = UUID()
        expense.amount = amount
        expense.category = category
        expense.date = date
        expense.note = note
        expense.isRecurring = false
        PersistenceController.shared.save()
        fetchExpenses()
        pushTrustSummary()
    }

    // MARK: - Quick Invoice

    /// Clients sorted for Quick Invoice cards: pinned first, then by most recent invoice date.
    var quickInvoiceClients: [Client] {
        let sorted = clients.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            let lhsDate = lastInvoice(for: lhs)?.issueDate ?? .distantPast
            let rhsDate = lastInvoice(for: rhs)?.issueDate ?? .distantPast
            return lhsDate > rhsDate
        }
        return sorted
    }

    /// Most recent invoice for a given client.
    func lastInvoice(for client: Client) -> Invoice? {
        invoices
            .filter { $0.clientName.lowercased() == client.name.lowercased() }
            .sorted { ($0.issueDate ?? .distantPast) > ($1.issueDate ?? .distantPast) }
            .first
    }

    /// Smart nudge text for a client card.
    func smartNudge(for client: Client) -> (text: String, isSmart: Bool) {
        guard let last = lastInvoice(for: client) else { return ("New client", false) }

        // Check for monthly pattern: 2+ invoices roughly 28-35 days apart
        let clientInvoices = invoices
            .filter { $0.clientName.lowercased() == client.name.lowercased() }
            .sorted { ($0.issueDate ?? .distantPast) > ($1.issueDate ?? .distantPast) }

        if clientInvoices.count >= 2,
           let latest = clientInvoices[0].issueDate,
           let previous = clientInvoices[1].issueDate {
            let gap = Calendar.current.dateComponents([.day], from: previous, to: latest).day ?? 0
            if gap >= 25 && gap <= 38 {
                return ("✦ Monthly due", true)
            }
        }

        // Fallback: show days since last invoice
        if let date = last.issueDate {
            let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
            if days == 0 { return ("Today", false) }
            return ("\(days) days ago", false)
        }

        return ("", false)
    }

    func toggleClientPin(_ client: Client) {
        client.isPinned.toggle()
        PersistenceController.shared.save()
        fetchClients()
    }

    // MARK: - Clients

    @discardableResult
    func createClient(name: String, email: String, phone: String?, address: String?, paymentTerms: PaymentTerms = .net14) -> Client {
        let client = Client(context: context)
        client.id = UUID()
        client.name = name
        client.email = email
        client.phone = phone?.isEmpty == true ? nil : phone
        client.address = address?.isEmpty == true ? nil : address
        client.paymentTerms = paymentTerms
        PersistenceController.shared.save()
        fetchClients()
        return client
    }

    func deleteClient(_ client: Client) {
        context.delete(client)
        PersistenceController.shared.save()
        fetchClients()
    }

    /// Creates or updates a client from invoice details
    func saveClientFromInvoice(name: String, email: String, address: String?, paymentTerms: PaymentTerms) {
        // Check if client with same name already exists
        if let existing = clients.first(where: { $0.name.lowercased() == name.lowercased() }) {
            existing.email = email
            if let addr = address, !addr.isEmpty { existing.address = addr }
            existing.paymentTerms = paymentTerms
            PersistenceController.shared.save()
            fetchClients()
        } else {
            createClient(name: name, email: email, phone: nil, address: address, paymentTerms: paymentTerms)
        }
    }

    // MARK: - Briefing

    @ObservationIgnored private var briefingTask: Task<Void, Never>?

    func loadBriefing() {
        print("[Invoicing Briefing] loadBriefing called — hasLoaded=\(hasLoadedBriefing), briefing=\(briefing != nil ? "set" : "nil"), taskRunning=\(briefingTask != nil)")
        guard !hasLoadedBriefing || briefing == nil else {
            print("[Invoicing Briefing] Skipped — already loaded")
            return
        }
        guard briefingTask == nil else {
            print("[Invoicing Briefing] Skipped — task already running")
            return
        }
        hasLoadedBriefing = true
        isLoadingBriefing = true

        let payload: [String: Any] = [
            "unpaidCount": invoices.filter { $0.status != .paid && $0.status != .draft }.count,
            "outstanding": totalOutstanding,
            "monthlyRevenue": monthlyRevenue,
            "monthlyExpenses": monthlyExpenses
        ]
        print("[Invoicing Briefing] Calling API with payload: \(payload)")

        briefingTask = Task {
            let result = await claudeService.generateBriefing(tab: .invoicing, dataPayload: payload)
            print("[Invoicing Briefing] API returned — result=\(result != nil ? "success" : "nil")")
            if let r = result {
                print("[Invoicing Briefing] headline=\"\(r.headline)\", stats=\(r.stats.count)")
            }
            briefing = result
            isLoadingBriefing = false
            briefingTask = nil
            if result == nil {
                print("[Invoicing Briefing] Resetting hasLoadedBriefing so next onAppear retries")
                hasLoadedBriefing = false
            }
        }
    }
}
