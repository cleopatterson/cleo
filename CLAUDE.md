# Cleo — iOS Business Planner

## Stack
- SwiftUI, iOS 17+, `@Observable` / `@Bindable` (no `ObservableObject`)
- Core Data via `NSPersistentCloudKitContainer` — two stores:
  - `Local` config: invoices, expenses, clients, milestones, tasks, notes, calendar events
  - `Shared` config: `TrustFinancialSummary`, `TrustSettings` (CloudKit private zone)
- XcodeGen (`project.yml`) — run `xcodegen generate` before building
- Claude Haiku 4.5 API for AI briefing cards (key via `Secrets.xcconfig`)

## Build
```bash
xcodegen generate
xcodebuild -project Cleo.xcodeproj -scheme Cleo \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Architecture
- `CleoApp` → `ContentView` → `MainTabView` → 5 tabs
- Each tab has a `ViewModel` (`@Observable`, `@MainActor`) and a `TabView`
- Core Data context: `PersistenceController.shared.viewContext`
- `TrustSyncService` aggregates monthly financials for the trust dashboard

## Key Patterns
- All Core Data UUIDs and Dates are `optional` (CloudKit compatibility)
- `HeroCardView` is generic — use `HeroCardView<AnyView>` or `HeroCardView<EmptyView>`
- Use `Color.cleoInvoicingGreen` not `.cleoInvoicingGreen` (ShapeStyle inference issue)
- All sheets: `.presentationBackground(.ultraThinMaterial)` + `.presentationDetents([.medium, .large])`
- Haptics: light = select, medium = complete, warning = destructive
- All deletes require confirmation dialog — no bare swipe-to-delete
- Background modifier: `.cleoBackground(theme: theme)` on all tab views

## 5 Tabs
1. **Calendar** (`CalendarViewModel`) — EventKit, month grid, day agenda
2. **Money** (`InvoicingViewModel`) — Invoices, expenses, clients, PDF generation
3. **Roadmap** (`RoadmapViewModel`) — Milestones + tasks, timeline/kanban
4. **Metrics** (`MetricsViewModel`) — Trust dashboard, BAS/GST, income gap, time tracking
5. **Notes** (`TodoViewModel` + `BugReportsViewModel`) — Notes/lists + bug reports → GitHub issues

## Bug Reports → GitHub
- `BugReportsViewModel` creates issues via `GitHubService` (direct GitHub API, token in `Secrets.xcconfig`)
- Issues created with labels: `bug-report`, `severity-{low|medium|high}`
- Status is polled from GitHub when Bugs tab is opened

## Secrets
- `Config/Secrets.xcconfig` — never commit, contains `CLAUDE_API_KEY` and `GITHUB_TOKEN`
- Values exposed to app via `Info.plist` property list entries in `project.yml`

## Don't Do
- Don't add `@Published` or `ObservableObject` — use `@Observable`
- Don't add GST to pre-April 2026 historical invoices (`taxRate = 0.0`)
- Don't sync local Core Data entities to CloudKit (only Trust entities sync)
- Don't use `UIMarkupTextPrintFormatter` for PDF (renders blank — use Core Graphics)
