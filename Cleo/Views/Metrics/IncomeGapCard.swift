import SwiftUI

struct IncomeGapCard: View {
    let aggregate: TrustMonthlyAggregate

    private let teal   = Color(hex: "#3ECF9A")
    private let purple = Color(hex: "#B794F6")
    private let amber  = Color(hex: "#FB923C")
    private let coral  = Color(hex: "#F87171")

    var body: some View {
        VStack(spacing: 16) {
            header
            progressBar
            Divider().background(.white.opacity(0.08))
            contributorRow
        }
        .padding(18)
        .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Text("INCOME GAP TRACKER")
                    .font(.caption.bold())
                    .foregroundStyle(amber)
                    .tracking(1)
                newBadge
            }
            Spacer()
            Text("This month")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private var newBadge: some View {
        Text("NEW")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(amber)
            .tracking(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(amber.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let fraction = aggregate.incomeTarget > 0
                    ? min(1, aggregate.combinedRevenue / aggregate.incomeTarget)
                    : 0
                let fillWidth = fraction * geo.size.width

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.04))

                    LinearGradient(
                        colors: [teal.opacity(0.35), teal.opacity(0.2)],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(width: max(fillWidth, 0))

                    Text("$\(String(format: "%.0f", aggregate.combinedRevenue))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(teal)
                        .padding(.leading, 10)
                }
            }
            .frame(height: 28)

            HStack {
                Text("Target: $\(String(format: "%.0f", aggregate.incomeTarget))/mo")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
                if aggregate.gapAmount > 0 {
                    Text("Gap: $\(String(format: "%.0f", aggregate.gapAmount))")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(coral)
                } else {
                    Text("Target met ✓")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(teal)
                }
            }
        }
    }

    // MARK: - Contributor Row

    private var contributorRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(aggregate.contributors.enumerated()), id: \.offset) { i, c in
                amountColumn(label: c.name, amount: c.revenue, color: i == 0 ? teal : purple)
                columnDivider
            }
            amountColumn(
                label: "Safe to spend",
                amount: max(0, aggregate.safeToSpend),
                color: amber
            )
        }
    }

    private func amountColumn(label: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
            Text("$\(String(format: "%.0f", amount))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(width: 1, height: 36)
    }
}
