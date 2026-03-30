import SwiftUI
import Charts

struct YearlyPLCard: View {
    let points: [MetricsViewModel.MonthlyPLPoint]
    let annualRevenue: Double
    let annualExpenses: Double
    let annualNetProfit: Double
    let fyLabel: String

    @Environment(ThemeManager.self) private var theme

    private var accentColor: Color { theme.color(for: .metrics) }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PROFIT & LOSS")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(1)
                    Text("Full year · \(fyLabel)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                }
                Spacer()
                Text(fyLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            }

            // Summary totals
            HStack(spacing: 0) {
                summaryCol(label: "Revenue", value: annualRevenue, color: accentColor)
                Divider().frame(height: 32).background(.white.opacity(0.08))
                summaryCol(label: "Expenses", value: annualExpenses, color: .red.opacity(0.8))
                Divider().frame(height: 32).background(.white.opacity(0.08))
                summaryCol(label: "Net Profit", value: annualNetProfit,
                           color: annualNetProfit >= 0 ? accentColor : .red)
            }

            // Trendline chart
            if !points.isEmpty {
                trendChart
            }
        }
        .padding(18)
        .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Chart

    private var trendChart: some View {
        Chart {
            // Revenue area fill
            ForEach(points.filter { !$0.isFuture }) { point in
                AreaMark(
                    x: .value("Month", point.shortMonth),
                    y: .value("Revenue", point.revenue)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor.opacity(0.25), accentColor.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Revenue line
            ForEach(points.filter { !$0.isFuture }) { point in
                LineMark(
                    x: .value("Month", point.shortMonth),
                    y: .value("Revenue", point.revenue)
                )
                .foregroundStyle(accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }

            // Expenses line
            ForEach(points.filter { !$0.isFuture }) { point in
                LineMark(
                    x: .value("Month", point.shortMonth),
                    y: .value("Expenses", point.expenses)
                )
                .foregroundStyle(.red.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .interpolationMethod(.catmullRom)
            }

            // Current month dot on revenue
            ForEach(points.filter { $0.isCurrentMonth && !$0.isFuture }) { point in
                PointMark(
                    x: .value("Month", point.shortMonth),
                    y: .value("Revenue", point.revenue)
                )
                .foregroundStyle(accentColor)
                .symbolSize(60)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.05))
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text("$\(abbreviate(d))")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }
        }
        .chartLegend(position: .topTrailing, spacing: 8) {
            HStack(spacing: 10) {
                legendDot(color: accentColor, label: "Revenue")
                legendDot(color: .red.opacity(0.7), label: "Expenses", dashed: true)
            }
        }
        .frame(height: 160)
    }

    // MARK: - Helpers

    private func summaryCol(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
            Text("$\(abbreviate(value))")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func legendDot(color: Color, label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 4) {
            if dashed {
                Rectangle()
                    .fill(color)
                    .frame(width: 12, height: 1.5)
            } else {
                Circle().fill(color).frame(width: 7, height: 7)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func abbreviate(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000     { return String(format: "%.0fk", value / 1_000) }
        return String(format: "%.0f", value)
    }
}
