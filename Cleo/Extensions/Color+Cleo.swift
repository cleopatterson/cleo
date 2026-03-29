import SwiftUI

// MARK: - Cleo Design Tokens
// Distinct from Choo: warmer dark base, slightly different surface tones

extension Color {
    // Surfaces — warmer than Choo's indigo-teal sweep
    static let cleoBackground = Color(hex: "#0D0B1E")
    static let cleoCardSurface = Color(hex: "#181030")
    static let cleoElevatedSurface = Color(hex: "#1C1236")

    // Text
    static let cleoPrimaryText = Color(hex: "#f0e6ff")

    // Border
    static let cleoBorder = Color.white.opacity(0.06)

    // Default tab accents (overridden by ThemeManager for calendar tab)
    static let cleoCalendarPurple = Color(hex: "#4CAE8D")
    static let cleoInvoicingGreen = Color(hex: "#f0a946")
    static let cleoTodoPink = Color(hex: "#f472b6")
    static let cleoRoadmapAmber = Color(hex: "#fb923c")
    static let cleoMetricsBlue = Color(hex: "#74b9ff")

    // Hex initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Background

extension View {
    func cleoBackground() -> some View {
        self.background {
            Color.cleoBackground
                .ignoresSafeArea()
        }
    }

    /// Theme-aware background with radial glow from brand accent
    func cleoBackground(theme: ThemeManager) -> some View {
        self.background {
            ZStack {
                Color.cleoBackground
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        theme.brandAccent.opacity(0.06),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }
        }
    }

    func glassField() -> some View {
        self
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

// MARK: - String Helpers

extension String {
    func containsAny(_ terms: String...) -> Bool {
        terms.contains { contains($0) }
    }
}

// MARK: - Typography

extension Font {
    static let cleoHeadline = Font.system(.title2, design: .serif).bold()
    static let cleoTitle = Font.title2.bold()
    static let cleoBody = Font.subheadline
    static let cleoBadge = Font.caption.bold()
    static let cleoPill = Font.caption2.weight(.medium)
}
