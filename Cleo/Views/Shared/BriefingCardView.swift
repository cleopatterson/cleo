import SwiftUI

/// AI Briefing Card — Layer 1 of the three-layer visual hierarchy (§2.3)
/// Gradient background, sparkle badge, headline, summary, stat pills
struct BriefingCardView: View {
    let badge: String
    let headline: String
    let summary: String
    var dateRange: String? = nil
    var stats: [StatPill] = []
    let accent: TabAccent
    var isLoading: Bool = false

    @Environment(ThemeManager.self) private var theme
    private var accentColor: Color { theme.color(for: accent) }

    struct StatPill: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Badge + optional date range
            if let dateRange {
                Text("✦ \(badge) · \(dateRange)")
                    .font(.cleoBadge)
                    .foregroundStyle(accentColor)
                    .tracking(1.5)
            } else {
                Text("✦ \(badge)")
                    .font(.cleoBadge)
                    .foregroundStyle(accentColor)
                    .tracking(1.5)
            }

            // Headline
            Text(headline)
                .font(.cleoHeadline)
                .foregroundStyle(.white)
                .lineLimit(1)

            // Summary
            if !summary.isEmpty {
                Text(summary)
                    .font(.cleoBody)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(3)
            }

            // Stat pills
            if !stats.isEmpty {
                HStack(spacing: 8) {
                    ForEach(stats) { stat in
                        statPill(label: stat.label, value: stat.value)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background {
            ZStack {
                // Dark base
                Color(red: 0.05, green: 0.05, blue: 0.10)

                // Accent glow — strong enough to tint the card visibly
                RadialGradient(
                    colors: [accentColor.opacity(0.35), accentColor.opacity(0.12), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 350
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .overlay {
            if isLoading {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .overlay { shimmer }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func statPill(label: String, value: String) -> some View {
        let text = label.isEmpty ? value : "\(label): \(value)"
        return Text(text)
            .font(.cleoPill)
            .foregroundStyle(accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(accentColor.opacity(0.15), in: Capsule())
    }

    private var shimmer: some View {
        GeometryReader { geo in
            let w = geo.size.width
            TimelineView(.animation(minimumInterval: 0.016)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let offset = CGFloat(t.truncatingRemainder(dividingBy: 2.0)) / 2.0

                LinearGradient(
                    colors: [.clear, .white.opacity(0.08), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: w * 0.4)
                .offset(x: -w * 0.2 + w * 1.4 * offset)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    BriefingCardView(
        badge: "AI BRIEFING",
        headline: "2 invoices due, $4,200 outstanding",
        summary: "You sent 3 invoices in February totalling $12,600. Two are still unpaid — the Acme project ($2,800) is 5 days overdue.",
        stats: [
            .init(label: "Revenue", value: "$8,400"),
            .init(label: "Outstanding", value: "$4,200"),
            .init(label: "Expenses", value: "$1,430")
        ],
        accent: .invoicing
    )
    .padding()
    .cleoBackground()
}
