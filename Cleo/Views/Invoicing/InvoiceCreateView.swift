import SwiftUI
import MessageUI
import PDFKit
import PhotosUI

struct InvoiceCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var theme
    @Bindable var viewModel: InvoicingViewModel
    let claudeService: ClaudeAPIService
    let prefillClient: Client?

    enum Mode: Int, CaseIterable {
        case invoice = 0
        case expense = 1
        var label: String {
            switch self {
            case .invoice: "Invoice"
            case .expense: "Expense"
            }
        }
    }

    @State private var mode: Mode = .invoice

    // Invoice fields
    @State private var clientName = ""
    @State private var clientEmail = ""
    @State private var clientAddress = ""
    @State private var invoiceDate = Date()
    @State private var dueDate = Date()
    @State private var invoiceNumber = ""
    @State private var paymentTerms = PaymentTerms.net14
    @State private var notes = ""
    @State private var lineItems: [LineItemDraft] = [LineItemDraft()]
    @State private var showClientPicker = false
    @State private var selectedClient: Client?
    @State private var isPrefilled = false

    // Expense fields
    @State private var expenseAmount = ""
    @State private var expenseCategory: ExpenseCategory = .other
    @State private var expenseDate = Date()
    @State private var expenseNote = ""

    // Receipt scanning
    @State private var showCamera = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var receiptImage: UIImage?
    @State private var isScanning = false
    @State private var scanComplete = false

    // Preview & send
    @State private var showPreview = false
    @State private var createdInvoice: Invoice?
    @State private var pdfData: Data?

    struct LineItemDraft: Identifiable {
        let id = UUID()
        var description = ""
        var quantity = "1"
        var unitPrice = ""
        var discount = ""

        var quantityValue: Double { Double(quantity) ?? 1 }
        var unitPriceValue: Double { Double(unitPrice) ?? 0 }
        var discountValue: Double { Double(discount) ?? 0 }
        var lineTotal: Double {
            let base = quantityValue * unitPriceValue
            return base * (1.0 - discountValue / 100.0)
        }
    }

    private var subtotal: Double { lineItems.reduce(0) { $0 + $1.lineTotal } }
    private var taxRate: Double { PersistenceController.shared.getOrCreateBusinessProfile().defaultTaxRate }
    private var taxAmount: Double { subtotal * taxRate }
    private var total: Double { subtotal + taxAmount }
    private var computedDueDate: Date { Calendar.current.date(byAdding: .day, value: paymentTerms.rawValue, to: invoiceDate) ?? invoiceDate }
    private var hasValidLineItems: Bool { lineItems.contains { !$0.description.isEmpty && $0.unitPriceValue > 0 } }

    init(viewModel: InvoicingViewModel, claudeService: ClaudeAPIService, prefillClient: Client? = nil) {
        self.viewModel = viewModel
        self.claudeService = claudeService
        self.prefillClient = prefillClient
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Toggle
                    modeToggle

                    if mode == .invoice {
                        invoiceForm
                    } else {
                        expenseForm
                    }
                }
                .padding(16)
            }
            .cleoBackground()
            .navigationTitle(mode == .invoice ? (isPrefilled ? "New Invoice" : "New") : "New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if mode == .expense {
                        Button("Save") { saveExpense() }
                            .bold()
                            .disabled(expenseAmount.isEmpty)
                    } else {
                        Button("Save") { saveDraft() }
                            .bold()
                            .disabled(clientName.trimmingCharacters(in: .whitespaces).isEmpty || !hasValidLineItems)
                    }
                }
            }
            .onAppear { prefillFromClient() }
            .sheet(isPresented: $showClientPicker) {
                ClientPickerView(viewModel: viewModel) { client in
                    applyClient(client)
                } onAddNew: { }
            }
            .sheet(isPresented: $showPreview) {
                if let invoice = createdInvoice, let pdf = pdfData {
                    InvoicePreviewSheet(
                        invoice: invoice,
                        pdfData: pdf,
                        viewModel: viewModel,
                        claudeService: claudeService
                    ) {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    receiptImage = image
                    Task { await scanReceipt(image) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: selectedPhoto) {
                if let photo = selectedPhoto {
                    Task { await loadAndScan(photo: photo) }
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(Mode.allCases, id: \.rawValue) { m in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { mode = m }
                } label: {
                    Text(m.label)
                        .font(.subheadline.weight(mode == m ? .semibold : .regular))
                        .foregroundStyle(mode == m ? Color.black : .white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(mode == m ? TabAccent.invoicing.color : .clear, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Invoice Form

    private var invoiceForm: some View {
        VStack(spacing: 16) {
            // Client section
            clientSection

            // Smart banner
            if isPrefilled {
                HStack(spacing: 8) {
                    Text("✦ Pre-filled from your last invoice")
                        .font(.subheadline)
                        .foregroundStyle(TabAccent.invoicing.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(TabAccent.invoicing.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(TabAccent.invoicing.color.opacity(0.2), lineWidth: 1)
                )
            }

            // Invoice details 2x2 grid
            invoiceDetailsGrid

            // Divider
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)

            // Line items
            lineItemsSection

            // Totals
            totalsCard

            // Actions
            invoiceActions
        }
    }

    private var clientSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Client")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            if selectedClient != nil {
                // Pre-filled client header
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(TabAccent.invoicing.color.opacity(0.12))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(selectedClient?.initials ?? "")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(TabAccent.invoicing.color)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(clientName)
                            .font(.headline)
                        Text(clientEmail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    Button {
                        showClientPicker = true
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.2))
                    }
                }
            } else {
                // Empty state: select client + chips
                Button {
                    showClientPicker = true
                } label: {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(TabAccent.invoicing.color.opacity(0.12))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text("👤")
                                    .font(.caption)
                            )

                        Text("Select or add client")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.35))

                        Spacer()

                        Text("›")
                            .foregroundStyle(.white.opacity(0.2))
                    }
                    .padding(12)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                    )
                }

                // Recent client chips
                if !viewModel.clients.isEmpty {
                    let chipColors: [Color] = [TabAccent.invoicing.color, TabAccent.roadmap.color, TabAccent.todo.color]
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(viewModel.quickInvoiceClients.prefix(4).enumerated()), id: \.element.objectID) { index, client in
                                Button {
                                    applyClient(client)
                                } label: {
                                    HStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(chipColors[index % chipColors.count].opacity(0.12))
                                            .frame(width: 20, height: 20)
                                            .overlay(
                                                Text(client.initials)
                                                    .font(.system(size: 9, weight: .semibold))
                                                    .foregroundStyle(chipColors[index % chipColors.count])
                                            )

                                        Text(client.name)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var invoiceDetailsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Editable invoice number
                VStack(alignment: .leading, spacing: 4) {
                    Text("Invoice #")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    TextField("", text: $invoiceNumber)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.color(for: .invoicing))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(11)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.06), lineWidth: 1))
                }

                // Terms picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Terms")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    Picker("", selection: $paymentTerms) {
                        ForEach(PaymentTerms.allCases, id: \.self) { term in
                            Text(term.label).tag(term)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(7)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.06), lineWidth: 1))
                }
            }
            HStack(spacing: 10) {
                // Editable invoice date
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    DatePicker("", selection: $invoiceDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(theme.color(for: .invoicing))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(7)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.06), lineWidth: 1))
                }

                // Editable due date
                VStack(alignment: .leading, spacing: 4) {
                    Text("Due")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(theme.color(for: .invoicing))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(7)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.06), lineWidth: 1))
                }
            }
        }
        .onAppear {
            if invoiceNumber.isEmpty { invoiceNumber = previewInvoiceNumber }
            dueDate = computedDueDate
        }
        .onChange(of: paymentTerms) {
            dueDate = computedDueDate
        }
        .onChange(of: invoiceDate) {
            dueDate = computedDueDate
        }
    }

    // MARK: - Line Items

    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Line Items")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            ForEach($lineItems) { $item in
                lineItemCard(item: $item)
            }

            Button {
                lineItems.append(LineItemDraft())
            } label: {
                Text("+ Add Line Item")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TabAccent.invoicing.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    )
            }
        }
    }

    private func lineItemCard(item: Binding<LineItemDraft>) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                TextField("Description", text: item.description, axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1...4)

                if lineItems.count > 1 {
                    Button {
                        lineItems.removeAll { $0.id == item.wrappedValue.id }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.6))
                            .frame(width: 22, height: 22)
                            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            Divider().background(.white.opacity(0.06))

            HStack(spacing: 6) {
                TextField("1", text: item.quantity)
                    .keyboardType(.decimalPad)
                    .frame(width: 44)
                    .multilineTextAlignment(.center)
                    .padding(6)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.06), lineWidth: 1))

                Text("×")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))

                TextField("$0.00", text: item.unitPrice)
                    .keyboardType(.decimalPad)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .padding(6)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.06), lineWidth: 1))

                HStack(spacing: 2) {
                    TextField("0", text: item.discount)
                        .keyboardType(.decimalPad)
                        .frame(width: 36)
                        .multilineTextAlignment(.trailing)
                        .padding(6)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.06), lineWidth: 1))
                    Text("%")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                }

                Spacer()

                Text("$\(String(format: "%.2f", item.wrappedValue.lineTotal))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TabAccent.invoicing.color)
            }
        }
        .padding(12)
        .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Totals

    private var totalsCard: some View {
        VStack(spacing: 3) {
            totalRow("Subtotal", value: subtotal)
            totalRow("GST (\(Int(taxRate * 100))%)", value: taxAmount)

            Divider().background(.white.opacity(0.06)).padding(.vertical, 4)

            HStack {
                Text("Total")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("$\(String(format: "%.2f", total))")
                    .font(.headline)
                    .foregroundStyle(TabAccent.invoicing.color)
            }
        }
        .padding(12)
        .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }

    private func totalRow(_ label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text("$\(String(format: "%.2f", value))")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Invoice Actions

    private var invoiceActions: some View {
        Button {
            createAndPreview()
        } label: {
            HStack(spacing: 8) {
                Text("✉")
                Text(hasValidLineItems && total > 0 ? "Preview & Send — $\(String(format: "%.2f", total))" : "Preview & Send")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                (clientName.isEmpty || !hasValidLineItems)
                    ? Color.white.opacity(0.1)
                    : TabAccent.invoicing.color,
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .disabled(clientName.isEmpty || !hasValidLineItems)
    }

    // MARK: - Expense Form

    private var expenseForm: some View {
        VStack(spacing: 16) {
            // Receipt scan
            receiptScanSection

            formSection("Amount") {
                HStack {
                    Text("$")
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $expenseAmount)
                        .keyboardType(.decimalPad)
                }
            }

            formSection("Category") {
                Picker("Category", selection: $expenseCategory) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                        HStack { Text(cat.emoji); Text(cat.rawValue) }.tag(cat)
                    }
                }
            }

            formSection("Date") {
                DatePicker("Date", selection: $expenseDate, displayedComponents: .date)
            }

            formSection("Note") {
                TextField("What was this for? (optional)", text: $expenseNote)
            }
        }
    }

    private var receiptScanSection: some View {
        Group {
            if isScanning {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Scanning receipt...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            } else if let image = receiptImage {
                VStack(spacing: 8) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    if scanComplete {
                        Label("Receipt scanned", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    Button { receiptImage = nil; scanComplete = false } label: {
                        Text("Remove").font(.caption).foregroundStyle(.red.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            } else {
                HStack(spacing: 12) {
                    Button { showCamera = true } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                            .font(.subheadline)
                            .foregroundStyle(TabAccent.invoicing.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(TabAccent.invoicing.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Photo Library", systemImage: "photo.fill")
                            .font(.subheadline)
                            .foregroundStyle(TabAccent.invoicing.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(TabAccent.invoicing.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Actions

    private func prefillFromClient() {
        guard let client = prefillClient else { return }
        applyClient(client)
    }

    private func applyClient(_ client: Client) {
        selectedClient = client
        clientName = client.name
        clientEmail = client.email
        clientAddress = client.address ?? ""
        paymentTerms = client.paymentTerms

        // Pre-fill line items from last invoice
        if let lastInv = viewModel.lastInvoice(for: client) {
            lineItems = lastInv.lineItemsArray.map { item in
                LineItemDraft(
                    description: item.itemDescription,
                    quantity: String(format: "%.0f", item.quantity),
                    unitPrice: String(format: "%.2f", item.unitPrice),
                    discount: item.discountPercent > 0 ? String(format: "%.0f", item.discountPercent) : ""
                )
            }
            if lineItems.isEmpty { lineItems = [LineItemDraft()] }
            isPrefilled = true
        }
    }

    private func createAndPreview() {
        let invoice = createInvoice()
        let profile = PersistenceController.shared.getOrCreateBusinessProfile()
        let pdf = InvoicePDFGenerator.generate(invoice: invoice, profile: profile, brandColor: UIColor(theme.brandAccent))
        invoice.pdfData = pdf
        PersistenceController.shared.save()
        createdInvoice = invoice
        pdfData = pdf
        showPreview = true
    }

    private func saveDraft() {
        createInvoice()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    private func createAndGeneratePDFOnly() {
        let invoice = createInvoice()
        let profile = PersistenceController.shared.getOrCreateBusinessProfile()
        let pdf = InvoicePDFGenerator.generate(invoice: invoice, profile: profile, brandColor: UIColor(theme.brandAccent))
        invoice.pdfData = pdf
        PersistenceController.shared.save()
        createdInvoice = invoice
        pdfData = pdf
        showPreview = true
    }

    @discardableResult
    private func createInvoice() -> Invoice {
        let validItems = lineItems.filter { !$0.description.isEmpty && $0.unitPriceValue > 0 }
        let invoice = viewModel.createInvoice(
            clientName: clientName,
            clientEmail: clientEmail,
            paymentTerms: paymentTerms,
            lineItems: validItems.map { ($0.description, $0.quantityValue, $0.unitPriceValue, $0.discountValue) }
        )
        invoice.clientAddress = clientAddress.isEmpty ? nil : clientAddress
        invoice.notes = notes.isEmpty ? nil : notes
        invoice.issueDate = invoiceDate
        invoice.dueDate = dueDate
        if !invoiceNumber.isEmpty { invoice.invoiceNumber = invoiceNumber }
        PersistenceController.shared.save()

        if !clientName.trimmingCharacters(in: .whitespaces).isEmpty {
            viewModel.saveClientFromInvoice(name: clientName, email: clientEmail, address: clientAddress, paymentTerms: paymentTerms)
        }

        return invoice
    }

    private func saveExpense() {
        guard let amount = Double(expenseAmount), amount > 0 else { return }
        let note = expenseNote.trimmingCharacters(in: .whitespacesAndNewlines)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        viewModel.addExpense(amount: amount, category: expenseCategory, date: expenseDate, note: note.isEmpty ? nil : note)
        dismiss()
    }

    private func loadAndScan(photo: PhotosPickerItem) async {
        guard let data = try? await photo.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        receiptImage = image
        await scanReceipt(image)
    }

    private func scanReceipt(_ image: UIImage) async {
        guard let jpegData = image.jpegData(compressionQuality: 0.6) else { return }
        isScanning = true
        defer { isScanning = false }
        guard let result = await claudeService.parseReceiptImage(jpegData) else { return }
        if let amount = result.amount { expenseAmount = String(format: "%.2f", amount) }
        if let date = result.date { expenseDate = date }
        if let category = result.category,
           let matched = ExpenseCategory.allCases.first(where: { $0.rawValue.lowercased() == category.lowercased() }) {
            expenseCategory = matched
        }
        var noteparts: [String] = []
        if let vendor = result.vendor { noteparts.append(vendor) }
        if let desc = result.description { noteparts.append(desc) }
        if !noteparts.isEmpty { expenseNote = noteparts.joined(separator: " — ") }
        scanComplete = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private var previewInvoiceNumber: String {
        let profile = PersistenceController.shared.getOrCreateBusinessProfile()
        let prefix = profile.invoicePrefix.trimmingCharacters(in: .whitespaces)
        if prefix.isEmpty {
            return String(format: "%05d", profile.nextInvoiceSequence)
        } else {
            let year = Calendar.current.component(.year, from: Date())
            return String(format: "%@-%d-%04d", prefix, year, profile.nextInvoiceSequence)
        }
    }

    private func formSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            VStack(spacing: 8) { content() }
                .padding(14)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.06), lineWidth: 1))
        }
    }
}

// MARK: - Invoice Preview & Send Sheet

struct InvoicePreviewSheet: View {
    let invoice: Invoice
    let pdfData: Data
    @Bindable var viewModel: InvoicingViewModel
    let claudeService: ClaudeAPIService
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var emailDraft = ""
    @State private var emailSubject = ""
    @State private var isGeneratingEmail = false
    @State private var showMailComposer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // PDF preview
                    PDFPreviewView(data: pdfData)
                        .frame(height: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.1), lineWidth: 1))

                    // Email subject (editable)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SUBJECT")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.4))
                            .tracking(1)

                        TextField("Email subject", text: $emailSubject)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.06), lineWidth: 1))
                    }

                    // Email body (editable)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("EMAIL")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.4))
                                .tracking(1)
                            Spacer()
                            if isGeneratingEmail {
                                HStack(spacing: 4) {
                                    ProgressView().tint(TabAccent.invoicing.color).scaleEffect(0.7)
                                    Text("AI drafting...").font(.caption).foregroundStyle(TabAccent.invoicing.color)
                                }
                            }
                        }

                        TextEditor(text: $emailDraft)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 150)
                            .padding(12)
                            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.06), lineWidth: 1))
                    }

                    // Send button
                    Button {
                        if MFMailComposeViewController.canSendMail() {
                            showMailComposer = true
                        }
                    } label: {
                        Label("Send Invoice", systemImage: "paperplane.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(TabAccent.invoicing.color, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isGeneratingEmail || emailDraft.isEmpty)
                }
                .padding(16)
            }
            .cleoBackground()
            .navigationTitle("Preview & Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Save the email draft edits to the invoice
                        invoice.notes = emailDraft
                        PersistenceController.shared.save()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                        onDone()
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.ultraThinMaterial)
        .task { await generateEmail() }
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(
                toRecipients: [invoice.clientEmail],
                subject: emailSubject,
                body: emailDraft,
                pdfData: pdfData,
                pdfFilename: "\(invoice.invoiceNumber).pdf"
            ) {
                viewModel.markAsSent(invoice)
                dismiss()
                onDone()
            }
        }
    }

    private func generateEmail() async {
        let profile = PersistenceController.shared.getOrCreateBusinessProfile()
        emailSubject = "Invoice \(invoice.invoiceNumber) from \(profile.businessName)"
        isGeneratingEmail = true

        let lineItemSummary = invoice.lineItemsArray
            .map { "\($0.itemDescription) (\(String(format: "$%.2f", $0.quantity * $0.unitPrice)))" }
            .joined(separator: ", ")

        if let draft = await claudeService.draftInvoiceEmail(
            clientName: invoice.clientName,
            invoiceNumber: invoice.invoiceNumber,
            total: invoice.total,
            dueDate: invoice.dueDate ?? Date(),
            paymentTerms: invoice.paymentTerms.label,
            businessName: profile.businessName,
            lineItemSummary: lineItemSummary
        ) {
            emailDraft = draft
        } else {
            let dueDateStr = (invoice.dueDate ?? Date()).formatted(.dateTime.day().month(.abbreviated).year())
            emailDraft = "Hi \(invoice.clientName),\n\nPlease find attached invoice \(invoice.invoiceNumber) for \(String(format: "$%.2f", invoice.total)).\n\nPayment is due by \(dueDateStr) (\(invoice.paymentTerms.label)).\n\nKind regards,\n\(profile.businessName)"
        }
        isGeneratingEmail = false
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - PDF Preview

struct PDFPreviewView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.backgroundColor = .white
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct MailComposeView: UIViewControllerRepresentable {
    let toRecipients: [String]
    let subject: String
    let body: String
    let pdfData: Data
    let pdfFilename: String
    var onSent: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(onSent: onSent) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(toRecipients)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.addAttachmentData(pdfData, mimeType: "application/pdf", fileName: pdfFilename)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onSent: (() -> Void)?
        init(onSent: (() -> Void)?) { self.onSent = onSent }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
            if result == .sent { onSent?() }
        }
    }
}
