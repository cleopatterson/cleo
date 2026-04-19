import SwiftUI

struct BASQuarterCard: View {
    let bas: BASQuarterSummary

    private let teal  = Color(hex: "#3ECF9A")
    private let coral = Color(hex: "#F87171")
    private let amber = Color(hex: "#FB923C")

    private var dueDateLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        return "Due \(fmt.string(from: bas.dueDate))"
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            metricsGrid
            warningBanner
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
                Text("BAS — \(bas.quarterLabel)")
                    .font(.caption.bold())
                    .foregroundStyle(coral)
                    .tracking(1)
                newBadge
            }
            Spacer()
            Text(dueDateLabel)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
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

    // MARK: - 2×2 Metrics Grid

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            metricCell(
                label: "GST collected",
                value: bas.gstCollected,
                subLabel: "On $\(String(format: "%.0f", bas.totalRevenue)) revenue",
                color: teal
            )
            metricCell(
                label: "GST paid",
                value: bas.gstOnExpenses,
                subLabel: "On $\(String(format: "%.0f", bas.totalExpenses)) expenses",
                color: coral
            )
            metricCell(
                label: "Net GST payable",
                value: bas.netGSTPayable,
                subLabel: "Set aside now",
                color: amber
            )
            metricCell(
                label: "Tax provision",
                value: bas.taxProvision,
                subLabel: "PAYG estimate",
                color: amber
            )
        }
    }

    private func metricCell(label: String, value: Double, subLabel: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
            Text("$\(String(format: "%.0f", value))")
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
            Text(subLabel)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.04), lineWidth: 1)
        )
    }

    // MARK: - Warning Banner

    private var warningBanner: some View {
        HStack(spacing: 10) {
            Text("⚠")
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 2) {
                Text("$\(String(format: "%.0f", bas.notYourMoney)) in your account is not yours")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(amber)
                Text("GST owed + tax provision for this quarter")
                    .font(.caption2)
                    .foregroundStyle(amber.opacity(0.7))
            }
            Spacer()
        }
        .padding(12)
        .background(amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(amber.opacity(0.15), lineWidth: 1)
        )
    }
}
