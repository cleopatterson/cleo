import SwiftUI

struct MetricsTabView: View {
    @Bindable var viewModel: MetricsViewModel
    @Binding var showingProfile: Bool
    @Bindable var theme: ThemeManager

    private let accent = TabAccent.metrics

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // 1. Trust Briefing Card
                    monthlyBriefingCard

                    // 2. Income Gap Tracker (NEW)
                    IncomeGapCard(aggregate: viewModel.trustAggregate)

                    // 3. BAS / GST Card (NEW)
                    if let bas = viewModel.basQuarter {
                        BASQuarterCard(bas: bas)
                    }

                    // 4. Profit & Loss
                    profitLossCard

                    // 5. Time Tracking
                    if !viewModel.weeks.isEmpty {
                        timeTrackingSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
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
                    Text("Metrics")
                        .font(.system(.headline, design: .serif))
                }
            }
            .task {
                await viewModel.loadData()
                viewModel.loadBriefing()
            }
        }
    }

    // MARK: - Monthly Briefing Card

    private var monthlyBriefingCard: some View {
        let tags = viewModel.financialTagPills.map { BriefingCardView.StatPill(label: $0.label, value: $0.value) }
        return BriefingCardView(
            badge: viewModel.currentMonthLabel,
            headline: viewModel.briefing?.headline ?? viewModel.fallbackHeadline,
            summary: viewModel.briefing?.summary ?? viewModel.fallbackSummary,
            stats: tags,
            accent: .metrics,
            isLoading: viewModel.isLoadingBriefing
        )
    }

    // MARK: - Profit & Loss Card

    private var profitLossCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PROFIT & LOSS")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(1)
                    Text(viewModel.trustAggregate.isSoloMode
                         ? "Your business — last 30 days"
                         : "Combined trust — last 30 days")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                }
                Spacer()
                Text("Last 30 days")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            }

            VStack(spacing: 4) {
                Text("Net Profit")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Text("$\(String(format: "%.0f", abs(viewModel.netProfit)))")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(viewModel.netProfit >= 0 ? accent.color : .red)
                if let trend = viewModel.profitTrendPercent {
                    let arrow = trend >= 0 ? "↑" : "↓"
                    Text("\(arrow) \(Int(abs(trend)))% vs previous period")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(trend >= 0 ? accent.color : .red)
                }
            }
            .frame(maxWidth: .infinity)

            let maxVal = max(viewModel.monthlyRevenue, viewModel.monthlyExpenses, 1)
            VStack(spacing: 10) {
                barRow(label: "Revenue",  value: viewModel.monthlyRevenue,  maxValue: maxVal, color: accent.color)
                barRow(label: "Expenses", value: viewModel.monthlyExpenses, maxValue: maxVal, color: .red)
            }
        }
        .padding(18)
        .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func barRow(label: String, value: Double, maxValue: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 70, alignment: .leading)

            GeometryReader { geo in
                let fillWidth = maxValue > 0 ? (value / maxValue) * geo.size.width : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.04))
                    RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.25)).frame(width: max(fillWidth, 0))
                    Text("$\(String(format: "%.0f", value))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                        .padding(.leading, 10)
                }
            }
            .frame(height: 28)
        }
    }

    // MARK: - Time Tracking Section

    private var timeTrackingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TIME TRACKING")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)
                .padding(.top, 8)

            weekSelector

            if let hero = viewModel.heroClient, let week = viewModel.selectedWeek {
                topClientCard(hero: hero, week: week)
            }

            if let week = viewModel.selectedWeek, !week.clients.isEmpty {
                hoursByClientCard(week: week)
            }
        }
    }

    private var weekSelector: some View {
        HStack {
            Button { withAnimation { viewModel.goToPreviousWeek() } } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(viewModel.canGoBack ? accent.color : .white.opacity(0.2))
            }
            .disabled(!viewModel.canGoBack)

            Spacer()

            if let week = viewModel.selectedWeek {
                Text(TimeTrackingService.weekLabel(week.weekStart))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Button { withAnimation { viewModel.goToNextWeek() } } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(viewModel.canGoForward ? accent.color : .white.opacity(0.2))
            }
            .disabled(!viewModel.canGoForward)
        }
        .padding(.horizontal, 8)
    }

    private func topClientCard(hero: ClientHours, week: WeekSummary) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("TOP CLIENT")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
                Spacer()
                Text(TimeTrackingService.weekLabel(week.weekStart))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(hero.name).font(.headline)
                    Text("\(hero.formattedHours) · \(viewModel.heroPercentage)% of your week")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Text("🏆").font(.system(size: 28))
            }

            HStack(spacing: 6) {
                tagPill("\(hero.sessions) sessions")
                tagPill(String(format: "%.1fh total", week.totalHours))
                if let change = viewModel.weekOverWeekChange {
                    tagPill("\(change >= 0 ? "+" : "")\(Int(change))% vs last")
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func tagPill(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(accent.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(accent.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    private func hoursByClientCard(week: WeekSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOURS BY CLIENT")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)
                .padding(.bottom, 4)

            let maxHours = week.clients.first?.hours ?? 1

            ForEach(week.clients) { client in
                HStack(spacing: 8) {
                    Text(client.name)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 90, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geo in
                        let fillWidth = maxHours > 0 ? (client.hours / maxHours) * geo.size.width : 0
                        RoundedRectangle(cornerRadius: 5)
                            .fill(.white.opacity(0.04))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(accent.color.opacity(0.35))
                                    .frame(width: max(fillWidth, 0))
                            }
                    }
                    .frame(height: 18)

                    Text(client.formattedHours)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }
}
