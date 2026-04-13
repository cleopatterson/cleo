import SwiftUI
import PhotosUI

/// First-launch onboarding: business name, logo, colour pick
struct OnboardingView: View {
    @Bindable var theme: ThemeManager
    let onComplete: () -> Void

    @State private var businessName = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var logoImage: UIImage?
    @State private var extractedHex: String?
    @State private var isExtracting = false
    @State private var step = 0

    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        ZStack {
            Color.cleoBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(i <= step ? theme.brandAccent : .white.opacity(0.15))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 60)
                .padding(.bottom, 40)

                // Steps — ZStack with slide transitions avoids TabView swipe conflicts
                ZStack {
                    nameStep
                        .opacity(step == 0 ? 1 : 0)
                        .offset(x: step == 0 ? 0 : -400)

                    logoStep
                        .opacity(step == 1 ? 1 : 0)
                        .offset(x: step == 1 ? 0 : (step < 1 ? 400 : -400))

                    colorStep
                        .opacity(step == 2 ? 1 : 0)
                        .offset(x: step >= 2 ? 0 : 400)
                }
                .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
    }

    // MARK: - Step 1: Name

    private var nameStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("👋")
                .font(.system(size: 64))

            Text("What's your business called?")
                .font(.cleoHeadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("This becomes your app name. You can change it later.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            TextField("e.g. Cleo, Arkie, Studio Nine", text: $businessName)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(theme.brandAccent.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 40)
                .focused($nameFieldFocused)
                .submitLabel(.next)
                .onSubmit {
                    if !businessName.trimmingCharacters(in: .whitespaces).isEmpty {
                        advanceToLogo()
                    }
                }
                .onChange(of: businessName) {
                    theme.appDisplayName = businessName
                }

            Spacer()

            nextButton(enabled: !businessName.trimmingCharacters(in: .whitespaces).isEmpty) {
                advanceToLogo()
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 2: Logo

    private var logoStep: some View {
        VStack(spacing: 24) {
            Spacer()

            if let logoImage {
                Image(uiImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(theme.brandAccent.opacity(0.4), lineWidth: 2)
                    )

                if isExtracting {
                    ProgressView()
                        .tint(theme.brandAccent)
                } else if let hex = extractedHex {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 20, height: 20)
                        Text("Colour extracted from your logo")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.04))
                    .frame(width: 120, height: 120)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.3))
                    }
            }

            Text("Got a logo?")
                .font(.cleoHeadline)
                .foregroundStyle(.white)

            Text("We'll extract your brand colour from it. Optional — you can pick a colour manually too.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(logoImage == nil ? "Choose Logo" : "Change Logo", systemImage: "photo.badge.plus")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.brandAccent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(theme.brandAccent.opacity(0.12), in: Capsule())
            }
            .onChange(of: selectedPhoto) {
                Task { await loadImage() }
            }

            Spacer()

            HStack(spacing: 16) {
                Button("Skip") {
                    step = 2
                }
                .foregroundStyle(.white.opacity(0.4))

                nextButton(enabled: true) {
                    step = 2
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 3: Colour

    private var colorStep: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text(theme.appDisplayName)
                    .font(.system(.largeTitle, design: .serif).bold())
                    .foregroundStyle(theme.brandAccent)

                Text("Your business planner")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text("Pick your accent colour")
                .font(.cleoHeadline)
                .foregroundStyle(.white)

            // Extracted colour option (if available)
            if let hex = extractedHex {
                Button {
                    theme.brandAccentHex = hex
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if theme.brandAccentHex == hex {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                        Text("From your logo")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        theme.brandAccentHex == hex ? Color(hex: hex).opacity(0.15) : .white.opacity(0.04),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
            }

            // Preset palette
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                ForEach(ThemeManager.presets, id: \.hex) { preset in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            theme.brandAccentHex = preset.hex
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: preset.hex))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    if theme.brandAccentHex == preset.hex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .shadow(color: theme.brandAccentHex == preset.hex ? Color(hex: preset.hex).opacity(0.5) : .clear, radius: 8)

                            Text(preset.name)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                theme.isOnboarded = true
                let profile = PersistenceController.shared.getOrCreateBusinessProfile()
                profile.businessName = businessName
                theme.saveToProfile(profile)
                DataSeeder.seedIfNeeded(context: PersistenceController.shared.viewContext)
                onComplete()
            } label: {
                Text("Let's go")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.brandAccent, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private func advanceToLogo() {
        nameFieldFocused = false
        // Small delay so keyboard dismiss animation completes before slide transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            step = 1
        }
    }

    private func nextButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Next")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    enabled ? theme.brandAccent : .white.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
        .disabled(!enabled)
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }

    private func loadImage() async {
        guard let selectedPhoto,
              let data = try? await selectedPhoto.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }

        logoImage = uiImage
        isExtracting = true

        if let path = saveLogoToDisk(data) {
            let profile = PersistenceController.shared.getOrCreateBusinessProfile()
            profile.logoImagePath = path
            PersistenceController.shared.save()
        }

        if let hex = LogoColorExtractor.extractDominantColor(from: uiImage) {
            extractedHex = hex
            withAnimation {
                theme.brandAccentHex = hex
            }
        }

        isExtracting = false
    }

    private func saveLogoToDisk(_ data: Data) -> String? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let path = docs.appendingPathComponent("business_logo.png")
        do {
            try data.write(to: path)
            return path.path
        } catch {
            return nil
        }
    }
}
