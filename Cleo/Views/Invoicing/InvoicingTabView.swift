import SwiftUI

struct InvoicingTabView: View {
    @Bindable var viewModel: InvoicingViewModel
    @Binding var showingProfile: Bool
    @Bindable var theme: ThemeManager
    @State private var showCreateSheet = false
    @State private var showReceiptScanner = false
    @State private var sharedReceiptURL: URL?
    @State private var selectedInvoice: Invoice?
    @State private var invoiceToDelete: Invoice?
    @State private var showDeleteConfirmation = false
    @State private var prefillClient: Client?

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Layer 1: AI Briefing
                    BriefingCardView(
                        badge: "AI BRIEFING",
                        headline: viewModel.briefing?.headline ?? "\(unpaidCount) invoices, $\(formattedOutstanding) outstanding",
                        summary: viewModel.briefing?.summary ?? "Loading your invoicing briefing...",
                        stats: viewModel.briefing?.stats.map {
                            BriefingCardView.StatPill(label: $0.label, value: $0.value)
                        } ?? defaultStats,
                        accent: .invoicing,
                        isLoading: viewModel.isLoadingBriefing
                    )

                    // Quick Invoice cards
                    quickInvoiceSection

                    // Invoice list
                    invoiceList
                }
                .padding(.horizontal, 16)
            }
            .contentMargins(.top, 8, for: .scrollContent)
            .cleoBackground(theme: theme)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileButtonView { showingProfile = true }
                }
                ToolbarItem(placement: .principal) {
                    Text("Money")
                        .font(.system(.headline, design: .serif))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        prefillClient = nil
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .onAppear { viewModel.loadBriefing() }
            .onReceive(NotificationCenter.default.publisher(for: .sharedReceiptAvailable)) { notification in
                if let url = notification.userInfo?["fileURL"] as? URL {
                    sharedReceiptURL = url
                    showReceiptScanner = true
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                InvoiceCreateView(
                    viewModel: viewModel,
                    claudeService: viewModel.claudeService,
                    prefillClient: prefillClient
                )
            }
            .sheet(isPresented: $showReceiptScanner) {
                if let url = sharedReceiptURL {
                    SharedReceiptView(fileURL: url, viewModel: viewModel)
                        .presentationBackground(.ultraThinMaterial)
                }
            }
            .sheet(item: $selectedInvoice) { invoice in
                InvoiceDetailView(viewModel: viewModel, invoice: invoice)
            }
            .confirmationDialog(
                "Delete \"\(invoiceToDelete?.invoiceNumber ?? "")\"?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let invoice = invoiceToDelete {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        viewModel.deleteInvoice(invoice)
                    }
                }
            }
        }
    }

    // MARK: - Quick Invoice Section

    private let clientColors: [Color] = [
        TabAccent.invoicing.color, // teal
        TabAccent.invoicing.color, // amber
        Color(hex: "#a78bfa"), // purple
        Color(hex: "#f472b6"), // pink
        Color(hex: "#38bdf8"), // sky
    ]

    private func clientColor(for index: Int) -> Color {
        clientColors[index % clientColors.count]
    }

    private var quickInvoiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("QUICK INVOICE")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
                Spacer()
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(viewModel.quickInvoiceClients.enumerated()), id: \.element.objectID) { index, client in
                        quickInvoiceCard(client: client, colorIndex: index)
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                prefillClient = client
                                showCreateSheet = true
                            }
                    }

                    // "+ New" card
                    Button {
                        prefillClient = nil
                        showCreateSheet = true
                    } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white.opacity(0.3))
                                )
                            Text("New")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .frame(width: 100)
                        .frame(maxHeight: .infinity)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.08), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        )
                    }
                }
            }
        }
    }

    private func quickInvoiceCard(client: Client, colorIndex: Int) -> some View {
        let color = clientColor(for: colorIndex)
        let lastInv = viewModel.lastInvoice(for: client)
        let nudge = viewModel.smartNudge(for: client)

        return VStack(alignment: .leading, spacing: 0) {
            // Client header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Text(client.initials)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(color)

                    if client.isPinned {
                        Circle()
                            .fill(TabAccent.invoicing.color)
                            .frame(width: 6, height: 6)
                            .offset(x: 13, y: -13)
                    }
                }

                Text(client.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.bottom, 10)

            // Last invoice amount
            if let inv = lastInv {
                Text("$\(String(format: "%.0f", inv.total))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 2)

                Text("\(inv.invoiceNumber) · \(Self.shortDateFormatter.string(from: inv.issueDate ?? Date()))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
            } else {
                Text("—")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, 2)

                Text("No invoices yet")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
            }

            // Smart nudge
            if !nudge.text.isEmpty {
                Text(nudge.text)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(nudge.isSmart ? TabAccent.invoicing.color : .white.opacity(0.35))
                    .padding(.top, 6)
            }
        }
        .frame(width: 156)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Invoice List

    private var invoiceList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INVOICES")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)
                .padding(.horizontal, 4)

            if viewModel.sortedInvoices.isEmpty {
                Text("No invoices yet. Tap + or a client card to create one.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(viewModel.sortedInvoices) { invoice in
                    invoiceRow(invoice)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedInvoice = invoice
                        }
                }
            }
        }
    }

    private func invoiceRow(_ invoice: Invoice) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(invoice.clientName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))

                HStack(spacing: 6) {
                    Text(invoice.invoiceNumber)
                    if let date = invoice.issueDate {
                        Text("·")
                        Text(date.formatted(.dateTime.day().month(.abbreviated).year()))
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.0f", invoice.total))")
                    .font(.subheadline.bold().monospaced())
                    .foregroundStyle(.white)

                statusBadge(invoice.status)
            }
        }
        .padding(13)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.04), lineWidth: 1)
        )
        .contextMenu {
            if invoice.status != .paid {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    viewModel.markAsPaid(invoice)
                } label: {
                    Label("Mark as Paid", systemImage: "checkmark.circle.fill")
                }
            }
            Button(role: .destructive) {
                invoiceToDelete = invoice
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func statusBadge(_ status: InvoiceStatus) -> some View {
        Text(status.label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Helpers

    private var unpaidCount: Int {
        viewModel.invoices.filter { $0.status == .sent || $0.status == .overdue }.count
    }

    private var formattedOutstanding: String {
        String(format: "%.0f", viewModel.totalOutstanding)
    }

    private var defaultStats: [BriefingCardView.StatPill] {
        [
            .init(label: "Revenue", value: "$\(String(format: "%.0f", viewModel.monthlyRevenue))"),
            .init(label: "Outstanding", value: "$\(formattedOutstanding)"),
        ]
    }

    private func statusColor(_ status: InvoiceStatus) -> Color {
        switch status {
        case .draft: TabAccent.invoicing.color
        case .sent: TabAccent.invoicing.color
        case .paid: .green
        case .overdue: .red
        }
    }
}
