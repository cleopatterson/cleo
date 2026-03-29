import SwiftUI
import PDFKit

struct SharedReceiptView: View {
    let fileURL: URL
    @Bindable var viewModel: InvoicingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isScanning = true
    @State private var scanFailed = false
    @State private var expenseAmount = ""
    @State private var expenseCategory: ExpenseCategory = .other
    @State private var expenseDate = Date()
    @State private var expenseNote = ""
    @State private var previewImage: UIImage?

    var body: some View {
        NavigationStack {
            Form {
                // Preview section
                Section {
                    if let image = previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(maxWidth: .infinity)
                    }

                    if isScanning {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("AI is reading your receipt...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                    } else if scanFailed {
                        Label("Couldn't read the receipt. Fill in the details manually.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Label("Receipt scanned", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                } header: {
                    Text("Receipt")
                }

                // Expense fields
                Section("Amount") {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $expenseAmount)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $expenseCategory) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            HStack {
                                Text(cat.emoji)
                                Text(cat.rawValue)
                            }
                            .tag(cat)
                        }
                    }
                }

                Section("Date") {
                    DatePicker("Date", selection: $expenseDate, displayedComponents: .date)
                }

                Section("Note") {
                    TextField("Description (optional)", text: $expenseNote)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cleanUpSharedFile()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveExpense() }
                        .bold()
                        .disabled(expenseAmount.isEmpty || isScanning)
                }
            }
            .task {
                await loadAndScan()
            }
        }
    }

    private func loadAndScan() async {
        // Generate preview image
        let isPDF = fileURL.pathExtension.lowercased() == "pdf"
        if isPDF {
            previewImage = renderPDFFirstPage(url: fileURL)
        } else {
            if let data = try? Data(contentsOf: fileURL) {
                previewImage = UIImage(data: data)
            }
        }

        // Get image data for AI scanning
        var imageData: Data?
        if isPDF, let image = previewImage {
            imageData = image.jpegData(compressionQuality: 0.7)
        } else if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            imageData = image.jpegData(compressionQuality: 0.7)
        }

        guard let imageData else {
            isScanning = false
            scanFailed = true
            return
        }

        // Send to Claude Vision
        guard let result = await viewModel.claudeService.parseReceiptImage(imageData) else {
            isScanning = false
            scanFailed = true
            return
        }

        // Pre-fill fields
        if let amount = result.amount {
            expenseAmount = String(format: "%.2f", amount)
        }
        if let date = result.date {
            expenseDate = date
        }
        if let category = result.category,
           let matched = ExpenseCategory.allCases.first(where: { $0.rawValue.lowercased() == category.lowercased() }) {
            expenseCategory = matched
        }

        var noteparts: [String] = []
        if let vendor = result.vendor { noteparts.append(vendor) }
        if let desc = result.description { noteparts.append(desc) }
        if !noteparts.isEmpty {
            expenseNote = noteparts.joined(separator: " — ")
        }

        isScanning = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func renderPDFFirstPage(url: URL) -> UIImage? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return nil }

        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }

    private func saveExpense() {
        guard let amount = Double(expenseAmount), amount > 0 else { return }
        let note = expenseNote.trimmingCharacters(in: .whitespacesAndNewlines)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        viewModel.addExpense(
            amount: amount,
            category: expenseCategory,
            date: expenseDate,
            note: note.isEmpty ? nil : note
        )
        cleanUpSharedFile()
        dismiss()
    }

    private func cleanUpSharedFile() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
