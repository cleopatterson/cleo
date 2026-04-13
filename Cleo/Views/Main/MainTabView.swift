import SwiftUI

/// Main tab navigation with 5 tabs
/// Profile button top-left, + button top-right (consistent across tabs)
struct MainTabView: View {
    @Bindable var calendarVM: CalendarViewModel
    @Bindable var invoicingVM: InvoicingViewModel
    @Bindable var todoVM: TodoViewModel
    @Bindable var bugReportsVM: BugReportsViewModel
    @Bindable var roadmapVM: RoadmapViewModel
    @Bindable var metricsVM: MetricsViewModel
    @Bindable var theme: ThemeManager
    var trustSyncService: TrustSyncService { metricsVM.trustSyncService }
    @State private var selectedTab = 0
    @State private var showingProfile = false

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarTabView(viewModel: calendarVM, showingProfile: $showingProfile, theme: theme)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(0)

            InvoicingTabView(viewModel: invoicingVM, showingProfile: $showingProfile, theme: theme)
                .tabItem {
                    Label("Money", systemImage: "dollarsign.circle")
                }
                .tag(1)

            RoadmapTabView(viewModel: roadmapVM, showingProfile: $showingProfile, theme: theme)
                .tabItem {
                    Label("Roadmap", systemImage: "map")
                }
                .tag(2)

            MetricsTabView(viewModel: metricsVM, showingProfile: $showingProfile, theme: theme)
                .tabItem {
                    Label("Metrics", systemImage: "chart.bar")
                }
                .tag(3)

            TodoTabView(viewModel: todoVM, bugReportsViewModel: bugReportsVM, showingProfile: $showingProfile, theme: theme)
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
                .tag(4)
        }
        .sheet(isPresented: $showingProfile) {
            NavigationStack {
                BusinessProfileView(theme: theme, trustSyncService: trustSyncService)
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(.ultraThinMaterial)
        }
        .tint(accentForTab)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    }

    private var accentForTab: Color {
        theme.brandAccent
    }
}
