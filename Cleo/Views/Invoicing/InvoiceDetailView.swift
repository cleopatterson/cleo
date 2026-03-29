import SwiftUI
import PDFKit
import MessageUI

/// Invoice detail sheet — view invoice, mark as paid, share/resend PDF, delete
struct InvoiceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: InvoicingViewModel
    let invoice: Invoice

    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @State private var showMailComposer = false
    @State private var pdfData: Data?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusHeader
                    clientSection
                    lineItemsSection
                    totalsSection

                    if let pdfData {
                        pdfPreviewSection(pdfData)
                    }

                    actionsSection

                    deleteSection
                }
                .padding(16)
            }
            .navigationTitle(invoice.invoiceNumber)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
        .onAppear { pdfData = invoice.pdfData }
        .confirmationDialog(
            "Delete \"\(invoice.invoiceNumber)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                viewModel.deleteInvoice(invoice)
                dismiss()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let pdfData {
                ShareSheetView(items: [pdfData])
            }
        }
        .sheet(isPresented: $showMailComposer) {
            if let pdfData {
                let profile = PersistenceController.shared.getOrCreateBusinessProfile()
                MailComposeView(
                    toRecipients: [invoice.clientEmail],
                    subject: "Invoice \(invoice.invoiceNumber) from \(profile.businessName)",
                    body: "",
                    pdfData: pdfData,
                    pdfFilename: "\(invoice.invoiceNumber).pdf"
                ) {
                    viewModel.markAsSent(invoice)
                }
            }
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.clientName)
                    .font(.cleoTitle)
                    .foregroundStyle(.white)

                if let desc = invoice.lineItemsArray.first?.itemDescription {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", invoice.total))")
                    .font(.title2.bold().monospaced())
                    .foregroundStyle(TabAccent.invoicing.color)

                HeroCardView<AnyView>.coloredPill(
                    text: invoice.status.label,
                    color: statusColor(invoice.status)
                )
            }
        }
        .padding(14)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Client Section

    private var clientSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CLIENT")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)

            VStack(alignment: .leading, spacing: 6) {
                detailRow("Name", value: invoice.clientName)
                detailRow("Email", value: invoice.clientEmail)
                if let address = invoice.clientAddress, !address.isEmpty {
                    detailRow("Address", value: address)
                }
                detailRow("Issued", value: (invoice.issueDate ?? Date()).formatted(.dateTime.day().month(.abbreviated).year()))
                detailRow("Due", value: (invoice.dueDate ?? Date()).formatted(.dateTime.day().month(.abbreviated).year()))
                detailRow("Terms", value: invoice.paymentTerms.label)

                if let sentDate = invoice.sentDate {
                    detailRow("Sent", value: sentDate.formatted(.dateTime.day().month(.abbreviated).year()))
                }
                if let paidDate = invoice.paidDate {
                    detailRow("Paid", value: paidDate.formatted(.dateTime.day().month(.abbreviated).year()))
                }
            }
            .padding(14)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Line Items

    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LINE ITEMS")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)

            VStack(spacing: 0) {
                ForEach(invoice.lineItemsArray) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.itemDescription)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.8))
                            Text("\(formatQty(item.quantity)) × $\(String(format: "%.2f", item.unitPrice))")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }

                        Spacer()

                        Text("$\(String(format: "%.2f", item.quantity * item.unitPrice))")
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.vertical, 8)

                    if item.id != invoice.lineItemsArray.last?.id {
                        Divider().overlay(.white.opacity(0.06))
                    }
                }
            }
            .padding(14)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Totals

    private var totalsSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Subtotal")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("$\(String(format: "%.2f", invoice.subtotal))")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.white.opacity(0.8))
            }
            HStack {
                Text("GST (\(Int(invoice.taxRate * 100))%)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("$\(String(format: "%.2f", invoice.taxAmount))")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.white.opacity(0.8))
            }
            Divider().overlay(.white.opacity(0.06))
            HStack {
                Text("Total")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("$\(String(format: "%.2f", invoice.total))")
                    .font(.headline.monospaced())
                    .foregroundStyle(TabAccent.invoicing.color)
            }
        }
        .padding(14)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - PDF Preview

    private func pdfPreviewSection(_ data: Data) -> some View {
        PDFPreviewView(data: data)
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 8) {
            if invoice.status != .paid {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    viewModel.markAsPaid(invoice)
                    dismiss()
                } label: {
                    Label("Mark as Paid", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(TabAccent.invoicing.color, in: RoundedRectangle(cornerRadius: 12))
                }
            }

            HStack(spacing: 8) {
                if pdfData != nil {
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(TabAccent.invoicing.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(TabAccent.invoicing.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                if MFMailComposeViewController.canSendMail(), pdfData != nil {
                    Button {
                        showMailComposer = true
                    } label: {
                        Label("Resend", systemImage: "envelope")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(TabAccent.invoicing.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(TabAccent.invoicing.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Button("Delete Invoice", role: .destructive) {
            showDeleteConfirmation = true
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }

    private func formatQty(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.2f", value)
    }

    private func statusColor(_ status: InvoiceStatus) -> Color {
        switch status {
        case .draft: .white.opacity(0.6)
        case .sent: .cleoInvoicingGreen
        case .paid: .green
        case .overdue: .red
        }
    }
}
