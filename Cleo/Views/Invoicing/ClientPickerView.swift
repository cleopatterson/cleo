import SwiftUI

/// Search/select existing client or add a new one
struct ClientPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: InvoicingViewModel

    let onSelect: (Client) -> Void
    let onAddNew: () -> Void

    @State private var searchText = ""
    @State private var showAddClient = false
    @State private var clientToDelete: Client?
    @State private var showDeleteConfirmation = false

    // Add client form
    @State private var newName = ""
    @State private var newEmail = ""
    @State private var newPhone = ""
    @State private var newAddress = ""
    @State private var newPaymentTerms = PaymentTerms.net14

    private var filteredClients: [Client] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return viewModel.clients
        }
        let query = searchText.lowercased()
        return viewModel.clients.filter {
            $0.name.lowercased().contains(query) ||
            $0.email.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showAddClient {
                    addClientForm
                } else {
                    clientList
                }
            }
            .cleoBackground()
            .navigationTitle(showAddClient ? "New Client" : "Select Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(showAddClient ? "Back" : "Cancel") {
                        if showAddClient {
                            showAddClient = false
                        } else {
                            dismiss()
                        }
                    }
                }
                if showAddClient {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            let client = viewModel.createClient(
                                name: newName,
                                email: newEmail,
                                phone: newPhone,
                                address: newAddress,
                                paymentTerms: newPaymentTerms
                            )
                            dismiss()
                            onSelect(client)
                        }
                        .bold()
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
        .confirmationDialog(
            "Delete \"\(clientToDelete?.name ?? "")\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let client = clientToDelete {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    viewModel.deleteClient(client)
                }
            }
        }
    }

    // MARK: - Client List

    private var clientList: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.3))
                    TextField("Search clients...", text: $searchText)
                        .foregroundStyle(.white)
                }
                .padding(12)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                // Add new client button
                Button {
                    showAddClient = true
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(TabAccent.invoicing.color.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(TabAccent.invoicing.color)
                        }

                        Text("Add New Client")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(TabAccent.invoicing.color)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.2))
                    }
                    .padding(12)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(TabAccent.invoicing.color.opacity(0.15), lineWidth: 1)
                    )
                }

                // Existing clients
                if filteredClients.isEmpty && !searchText.isEmpty {
                    Text("No clients matching \"\(searchText)\"")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.vertical, 20)
                } else if filteredClients.isEmpty {
                    Text("No clients yet")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.vertical, 20)
                } else {
                    ForEach(filteredClients) { client in
                        clientRow(client)
                    }
                }
            }
            .padding(16)
        }
    }

    private func clientRow(_ client: Client) -> some View {
        Button {
            dismiss()
            onSelect(client)
        } label: {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Text(String(client.name.prefix(1)).uppercased())
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(client.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    if !client.email.isEmpty {
                        Text(client.email)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(12)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                clientToDelete = client
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Add Client Form

    private var addClientForm: some View {
        ScrollView {
            VStack(spacing: 16) {
                formSection("Details") {
                    formField("Client Name", text: $newName)
                    formField("Email", text: $newEmail, keyboard: .emailAddress)
                    formField("Phone (optional)", text: $newPhone, keyboard: .phonePad)
                    formField("Address (optional)", text: $newAddress)
                }

                formSection("Invoice Defaults") {
                    Picker("Payment Terms", selection: $newPaymentTerms) {
                        ForEach(PaymentTerms.allCases, id: \.self) { term in
                            Text(term.label).tag(term)
                        }
                    }
                    .foregroundStyle(.white)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Helpers

    private func formSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)

            VStack(spacing: 8) {
                content()
            }
            .padding(14)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private func formField(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .foregroundStyle(.white)
    }
}
