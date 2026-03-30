import SwiftUI
import PhotosUI

/// Business profile & settings screen — includes personalisation and trust settings
struct BusinessProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var theme: ThemeManager
    var trustSyncService: TrustSyncService

    @State private var businessName = ""
    @State private var appDisplayName = ""
    @State private var abn = ""
    @State private var address = ""
    @State private var email = ""
    @State private var phone = ""

    // Payment details
    @State private var accountName = ""
    @State private var bankName = ""
    @State private var bsb = ""
    @State private var accountNumber = ""
    @State private var payID = ""

    // Invoice defaults
    @State private var defaultPaymentTerms = PaymentTerms.net14
    @State private var taxRatePercent = "10"
    @State private var invoicePrefix = "INV"

    // Logo
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var logoImage: UIImage?

    // Trust settings
    @State private var trustName = ""
    @State private var trustABN = ""
    @State private var incomeTargetText = "20000"
    @State private var taxRateText = "30"
    @State private var showingShareSheet = false

    @State private var hasLoaded = false
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            // MARK: - Personalisation
            Section("Personalisation") {
                HStack {
                    Text("App Name")
                    Spacer()
                    TextField("Cleo", text: $appDisplayName)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 150)
                }

                // Colour palette
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accent Colour")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(ThemeManager.presets, id: \.hex) { preset in
                            Button {
                                withAnimation {
                                    theme.brandAccentHex = preset.hex
                                    // Save immediately so it persists
                                    let profile = PersistenceController.shared.getOrCreateBusinessProfile()
                                    profile.brandAccentHex = preset.hex
                                    PersistenceController.shared.save()
                                }
                            } label: {
                                Circle()
                                    .fill(Color(hex: preset.hex))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if theme.brandAccentHex.uppercased() == preset.hex.uppercased() {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                // Logo picker
                HStack {
                    if let logoImage {
                        Image(uiImage: logoImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(logoImage == nil ? "Add Logo" : "Change Logo", systemImage: "photo")
                    }
                    .onChange(of: selectedPhoto) {
                        Task { await loadLogo() }
                    }
                }
            }

            Section("Business Details") {
                TextField("Business Name", text: $businessName)
                TextField("ABN", text: $abn)
                    .keyboardType(.numberPad)
                TextField("Address", text: $address)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
            }

            Section("Payment Details (on invoices)") {
                TextField("Account Name", text: $accountName)
                TextField("Bank Name", text: $bankName)
                TextField("BSB", text: $bsb)
                    .keyboardType(.numberPad)
                TextField("Account Number", text: $accountNumber)
                    .keyboardType(.numberPad)
                TextField("PayID", text: $payID)
            }

            trustSection

            Section("Invoice Defaults") {
                Picker("Payment Terms", selection: $defaultPaymentTerms) {
                    ForEach(PaymentTerms.allCases, id: \.self) { term in
                        Text(term.label).tag(term)
                    }
                }

                HStack {
                    Text("Tax Rate (GST)")
                    Spacer()
                    TextField("10", text: $taxRatePercent)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("%")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Invoice Prefix")
                    Spacer()
                    TextField("INV", text: $invoicePrefix)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                HStack {
                    Text("Next Invoice #")
                    Spacer()
                    Text(String(PersistenceController.shared.getOrCreateBusinessProfile().nextInvoiceSequence))
                        .foregroundStyle(.secondary)
                }

                Button("Reset Invoice Numbers") {
                    showResetConfirmation = true
                }
                .foregroundStyle(.red)
            }
        }
        .confirmationDialog(
            "Reset invoice numbers back to 1?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to 1", role: .destructive) {
                PersistenceController.shared.resetInvoiceSequence()
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .bold()
            }
        }
        .onAppear { loadProfile() }
    }

    // MARK: - Trust Section

    private var trustSection: some View {
        Section("Trust") {
            TextField("Trust Name", text: $trustName)
                .autocorrectionDisabled()

            TextField("Trust ABN", text: $trustABN)
                .keyboardType(.numberPad)

            HStack {
                Text("Monthly Income Target")
                Spacer()
                Text("$")
                    .foregroundStyle(.secondary)
                TextField("20000", text: $incomeTargetText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            HStack {
                Text("Est. Tax Rate")
                Spacer()
                TextField("30", text: $taxRateText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                Text("%")
                    .foregroundStyle(.secondary)
            }

            if trustSyncService.isConnected {
                Label("Partner connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Invite Partner") {
                    showingShareSheet = true
                }
                .foregroundStyle(.blue)
            }
        }
        .alert("Partner Sharing", isPresented: $showingShareSheet) {
            Button("OK") {}
        } message: {
            Text("CloudKit sharing will be set up once both devices are running Cleo with iCloud sign-in. Use 'Invite Partner' from Settings → Trust once fully configured.")
        }
    }

    private func loadProfile() {
        guard !hasLoaded else { return }
        hasLoaded = true

        let profile = PersistenceController.shared.getOrCreateBusinessProfile()
        businessName = profile.businessName
        appDisplayName = profile.appDisplayName.isEmpty ? theme.appDisplayName : profile.appDisplayName
        abn = profile.abn ?? ""
        address = profile.address ?? ""
        email = profile.email ?? ""
        phone = profile.phone ?? ""
        accountName = profile.accountName ?? ""
        bankName = profile.bankName ?? ""
        bsb = profile.bsb ?? ""
        accountNumber = profile.accountNumber ?? ""
        payID = profile.payID ?? ""
        defaultPaymentTerms = PaymentTerms(rawValue: Int(profile.defaultPaymentTermsDays)) ?? .net14
        taxRatePercent = String(format: "%.0f", profile.defaultTaxRate * 100)
        invoicePrefix = profile.invoicePrefix

        // Load logo if saved
        if let path = profile.logoImagePath {
            logoImage = UIImage(contentsOfFile: path)
        }

        // Trust settings
        let settings = trustSyncService.getOrCreateSettings()
        trustName = settings.trustName
        trustABN = settings.trustABN
        incomeTargetText = String(format: "%.0f", settings.monthlyIncomeTarget)
        taxRateText = String(format: "%.0f", settings.estimatedTaxRate * 100)
    }

    private func save() {
        let profile = PersistenceController.shared.getOrCreateBusinessProfile()
        profile.businessName = businessName
        profile.abn = abn.isEmpty ? nil : abn
        profile.address = address.isEmpty ? nil : address
        profile.email = email.isEmpty ? nil : email
        profile.phone = phone.isEmpty ? nil : phone
        profile.accountName = accountName.isEmpty ? nil : accountName
        profile.bankName = bankName.isEmpty ? nil : bankName
        profile.bsb = bsb.isEmpty ? nil : bsb
        profile.accountNumber = accountNumber.isEmpty ? nil : accountNumber
        profile.payID = payID.isEmpty ? nil : payID
        profile.defaultPaymentTermsDays = Int16(defaultPaymentTerms.rawValue)
        profile.defaultTaxRate = (Double(taxRatePercent) ?? 10) / 100.0
        profile.invoicePrefix = invoicePrefix

        // Update theme
        theme.appDisplayName = appDisplayName
        theme.saveToProfile(profile)

        // Trust settings
        let settings = trustSyncService.getOrCreateSettings()
        settings.trustName = trustName
        settings.trustABN = trustABN
        settings.monthlyIncomeTarget = Double(incomeTargetText) ?? 20000
        settings.estimatedTaxRate = (Double(taxRateText) ?? 30) / 100.0
        settings.lastUpdated = Date()
        settings.updatedBy = profile.id?.uuidString ?? ""
        PersistenceController.shared.saveShared()

        PersistenceController.shared.save()
        dismiss()
    }

    private func loadLogo() async {
        guard let selectedPhoto,
              let data = try? await selectedPhoto.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }

        logoImage = uiImage

        // Save to disk
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let path = docs.appendingPathComponent("business_logo.png")
        try? data.write(to: path)
        let profile = PersistenceController.shared.getOrCreateBusinessProfile()
        profile.logoImagePath = path.path
        PersistenceController.shared.save()

        // Auto-extract colour
        if let hex = LogoColorExtractor.extractDominantColor(from: uiImage) {
            withAnimation { theme.brandAccentHex = hex }
        }
    }
}
