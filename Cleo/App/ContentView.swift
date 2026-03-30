import SwiftUI

struct ContentView: View {
    let calendarService: DeviceCalendarService
    let claudeService: ClaudeAPIService
    let persistence: PersistenceController
    @Bindable var theme: ThemeManager

    @State private var calendarVM: CalendarViewModel
    @State private var invoicingVM: InvoicingViewModel
    @State private var roadmapVM: RoadmapViewModel
    @State private var todoVM: TodoViewModel
    @State private var metricsVM: MetricsViewModel
    @State private var bugReportsVM: BugReportsViewModel

    init(calendarService: DeviceCalendarService,
         claudeService: ClaudeAPIService,
         persistence: PersistenceController,
         theme: ThemeManager,
         trustSyncService: TrustSyncService) {
        self.calendarService = calendarService
        self.claudeService = claudeService
        self.persistence = persistence
        self.theme = theme

        _calendarVM = State(initialValue: CalendarViewModel(
            persistence: persistence,
            calendarService: calendarService,
            claudeService: claudeService
        ))
        _invoicingVM = State(initialValue: InvoicingViewModel(
            context: persistence.viewContext,
            claudeService: claudeService,
            trustSyncService: trustSyncService
        ))
        _roadmapVM = State(initialValue: RoadmapViewModel(
            context: persistence.viewContext,
            claudeService: claudeService
        ))
        _todoVM = State(initialValue: TodoViewModel(
            persistence: persistence,
            claudeService: claudeService
        ))
        _metricsVM = State(initialValue: MetricsViewModel(
            timeService: TimeTrackingService(),
            claudeService: claudeService,
            persistence: persistence,
            trustSyncService: trustSyncService
        ))
        _bugReportsVM = State(initialValue: BugReportsViewModel(persistence: persistence))
    }

    var body: some View {
        if theme.isOnboarded {
            MainTabView(
                calendarVM: calendarVM,
                invoicingVM: invoicingVM,
                todoVM: todoVM,
                bugReportsVM: bugReportsVM,
                roadmapVM: roadmapVM,
                metricsVM: metricsVM,
                theme: theme
            )
            .task {
                let granted = await calendarService.requestAccess()
                if granted {
                    calendarService.loadEnabledCalendars()
                    calendarService.invalidateCache()
                }
            }
        } else {
            OnboardingView(theme: theme) {
                // Onboarding complete — theme already saved
            }
        }
    }
}
