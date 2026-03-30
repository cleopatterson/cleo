import SwiftUI

/// Hero Card — Layer 2 of the three-layer visual hierarchy (§2.3)
/// Dark surface card with emoji box, title/subtitle, divider, pill row
struct HeroCardView<Pills: View>: View {
    let label: String
    let title: String
    let subtitle: String
    let emoji: String
    let accent: TabAccent
    var isEmpty: Bool = false
    var emptyMessage: String = ""
    var emptyEmoji: String? = nil
    var emojiSize: CGFloat = 42
    @ViewBuilder var pills: () -> Pills

    @Environment(ThemeManager.self) private var theme
    @State private var bobOffset: CGFloat = 0

    private var accentColor: Color { theme.color(for: accent) }
    private var gradientColors: [Color] { theme.heroGradient(for: accent) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEmpty {
                emptyState
            } else {
                filledState
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RadialGradient(
                    colors: [accentColor.opacity(0.2), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 200
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accentColor.opacity(0.35), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                bobOffset = 6
            }
        }
    }

    @ViewBuilder
    private var filledState: some View {
        // Label
        Text(label)
            .font(.cleoBadge)
            .foregroundStyle(accentColor.opacity(0.8))
            .tracking(1.5)

        // Title + emoji
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.cleoTitle)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.cleoBody)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Text(emoji)
                .font(.system(size: emojiSize))
                .fixedSize()
                .offset(y: -bobOffset)
        }

        // Divider
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 1)
            .padding(.vertical, 4)

        // Pills
        HStack(spacing: 8) {
            pills()
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        HStack(spacing: 12) {
            Text(emptyEmoji ?? emoji)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.cleoBadge)
                    .foregroundStyle(accentColor.opacity(0.6))
                    .tracking(1.5)

                Text(emptyMessage)
                    .font(.cleoBody)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    // MARK: - Pill Helpers

    static func pillBadge(text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.white.opacity(0.1), in: Capsule())
    }

    static func coloredPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.cleoPill)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }

    static func surfacePill(text: String) -> some View {
        Text(text)
            .font(.cleoPill)
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.white.opacity(0.06), in: Capsule())
    }
}

#Preview {
    HeroCardView(
        label: "NEXT INVOICE",
        title: "Acme Corp — Website Redesign",
        subtitle: "$2,800 · Due 3 Mar · 5 days overdue",
        emoji: "🔴",
        accent: .invoicing
    ) {
        HeroCardView<AnyView>.coloredPill(text: "Overdue", color: .red)
        HeroCardView<AnyView>.surfacePill(text: "Sent 15 Feb")
        HeroCardView<AnyView>.surfacePill(text: "Net 14")
    }
    .padding()
    .cleoBackground()
}
