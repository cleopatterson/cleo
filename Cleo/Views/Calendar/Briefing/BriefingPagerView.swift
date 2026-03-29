import SwiftUI

struct BriefingPagerView: View {
    @Bindable var viewModel: CalendarViewModel
    @Binding var selectedPage: Int

    @State private var highlightScrollDate: Date?
    @State private var thisWeekHeight: CGFloat = 0
    @State private var nextWeekHeight: CGFloat = 0

    private var pagerHeight: CGFloat {
        max(thisWeekHeight, nextWeekHeight, 200)
    }

    private static let weekRangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedPage) {
                thisWeekCard
                    .readHeight {
                        thisWeekHeight = $0
                        print("[Pager] thisWeek height=\($0), nextWeek height=\(nextWeekHeight), pager=\(pagerHeight)")
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .tag(0)

                nextWeekCard
                    .readHeight {
                        nextWeekHeight = $0
                        print("[Pager] nextWeek height=\($0), thisWeek height=\(thisWeekHeight), pager=\(pagerHeight)")
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: pagerHeight)
            .onChange(of: pagerHeight) { _, h in
                print("[Pager] frame updated to height=\(h)")
            }

            // Page indicators
            HStack(spacing: 6) {
                Circle()
                    .fill(.white.opacity(selectedPage == 0 ? 0.5 : 0.15))
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(.white.opacity(selectedPage == 1 ? 0.5 : 0.15))
                    .frame(width: 6, height: 6)
            }
            .padding(.top, 16)
        }
    }

    // MARK: - This Week Card

    private var thisWeekCard: some View {
        let weekDays = viewModel.weekDays
        let weekLabel = "\(Self.weekRangeFormatter.string(from: weekDays.first ?? Date())) – \(Self.weekRangeFormatter.string(from: weekDays.last ?? Date()))"

        return VStack(spacing: 12) {
            // Briefing cover (AI headline/summary with date range)
            BriefingCardView(
                badge: "This week",
                headline: viewModel.briefing?.headline ?? viewModel.fallbackHeadline,
                summary: viewModel.briefing?.summary ?? viewModel.fallbackSummary,
                dateRange: weekLabel,
                accent: .calendar,
                isLoading: viewModel.isLoadingBriefing
            )

            // Glass card with timeline + carousel
            VStack(spacing: 12) {
                WeekTimelineView(
                    weekDays: weekDays,
                    eventCounts: eventCounts(for: weekDays)
                ) { day in
                    highlightScrollDate = day
                }

                HighlightsCarouselView(
                    highlights: buildHighlights(for: weekDays),
                    heading: "THIS WEEK'S HIGHLIGHTS",
                    scrollToDate: highlightScrollDate,
                    onEventTap: { highlightId in
                        handleEventTap(highlightId: highlightId, days: weekDays)
                    }
                )

                Spacer(minLength: 0)
            }
            .frame(minHeight: 220)
            .padding(14)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Next Week Card

    private var nextWeekCard: some View {
        let cal = Calendar.current
        let nextWeekStart = cal.date(byAdding: .day, value: 7, to: viewModel.weekStart) ?? viewModel.weekStart
        let nextWeekDays = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: nextWeekStart) }
        let weekLabel = "\(Self.weekRangeFormatter.string(from: nextWeekDays.first ?? Date())) – \(Self.weekRangeFormatter.string(from: nextWeekDays.last ?? Date()))"

        let fallback = viewModel.nextWeekSummary(nextWeekDays: nextWeekDays)

        return VStack(spacing: 12) {
            // Briefing cover for next week (AI-powered, same as this week)
            BriefingCardView(
                badge: "Next week",
                headline: viewModel.nextWeekBriefing?.headline ?? fallback.headline,
                summary: viewModel.nextWeekBriefing?.summary ?? fallback.summary,
                dateRange: weekLabel,
                accent: .calendar,
                isLoading: viewModel.isLoadingNextWeekBriefing
            )

            // Glass card with timeline + carousel
            VStack(spacing: 12) {
                WeekTimelineView(
                    weekDays: nextWeekDays,
                    eventCounts: eventCounts(for: nextWeekDays)
                )

                HighlightsCarouselView(
                    highlights: buildHighlights(for: nextWeekDays),
                    heading: "NEXT WEEK'S HIGHLIGHTS",
                    onEventTap: { highlightId in
                        handleEventTap(highlightId: highlightId, days: nextWeekDays)
                    }
                )

                Spacer(minLength: 0)
            }
            .frame(minHeight: 220)
            .padding(14)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Event Tap

    private func handleEventTap(highlightId: String, days: [Date]) {
        print("[BriefingPager] handleEventTap called with id: \(highlightId)")
        let cal = Calendar.current
        // Try to find a matching Core Data event
        for day in days {
            let dayStart = cal.startOfDay(for: day)
            for event in viewModel.events(for: dayStart) {
                let id = event.objectID.uriRepresentation().absoluteString + dayStart.description
                print("[BriefingPager]   checking CD event: \(event.wrappedTitle) id=\(id)")
                if id == highlightId {
                    print("[BriefingPager]   MATCH — setting selectedEvent to \(event.wrappedTitle)")
                    viewModel.selectedEvent = event
                    return
                }
            }
        }
        // External (EKEvent) highlights — show detail sheet
        for day in days {
            let dayStart = cal.startOfDay(for: day)
            for ekEvent in viewModel.externalEvents(for: dayStart) {
                let id = ekEvent.eventIdentifier + dayStart.description
                print("[BriefingPager]   checking EK event: \(ekEvent.title ?? "nil") id=\(id)")
                if id == highlightId {
                    print("[BriefingPager]   MATCH (external) — showing detail for \(ekEvent.title ?? "")")
                    viewModel.selectedExternalEvent = ekEvent
                    return
                }
            }
        }
        print("[BriefingPager]   NO MATCH found for highlight id")
    }

    // MARK: - Helpers

    private func eventCounts(for days: [Date]) -> [Date: Int] {
        var counts: [Date: Int] = [:]
        for day in days {
            let dayStart = Calendar.current.startOfDay(for: day)
            let userEvents = viewModel.events(for: dayStart)
            let extEvents = viewModel.externalEvents(for: dayStart)
            counts[dayStart] = userEvents.count + extEvents.count
        }
        return counts
    }

    private func buildHighlights(for days: [Date]) -> [WeekHighlight] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var highlights: [WeekHighlight] = []

        for day in days {
            let dayStart = cal.startOfDay(for: day)
            let isPast = dayStart < today

            for event in viewModel.events(for: dayStart) {
                let icon = eventEmoji(for: event)
                highlights.append(WeekHighlight(
                    id: event.objectID.uriRepresentation().absoluteString + dayStart.description,
                    title: event.wrappedTitle,
                    date: dayStart,
                    icon: icon,
                    isPast: isPast,
                    isTodo: event.isTodo,
                    todoUrgency: event.isTodo ? event.urgencyState : nil,
                    isCompleted: event.isCompleted
                ))
            }

            for ekEvent in viewModel.externalEvents(for: dayStart) {
                highlights.append(WeekHighlight(
                    id: ekEvent.eventIdentifier + dayStart.description,
                    title: ekEvent.title ?? "Untitled",
                    date: dayStart,
                    icon: eventEmoji(for: ekEvent.title ?? ""),
                    isPast: isPast,
                    isTodo: false,
                    todoUrgency: nil,
                    isCompleted: false
                ))
            }
        }

        return highlights
    }

    private func eventEmoji(for event: CalendarEvent) -> String {
        if event.isTodo {
            return event.todoEmoji ?? "✅"
        }
        return eventEmoji(for: event.wrappedTitle)
    }

    private func eventEmoji(for title: String) -> String {
        let lower = title.lowercased()
        if lower.containsAny("lunch", "dinner", "brunch", "food", "restaurant", "breakfast") { return "🍽️" }
        if lower.containsAny("coffee", "cafe") { return "☕" }
        if lower.containsAny("birthday", "party") { return "🎉" }
        if lower.containsAny("meeting", "call", "zoom", "teams") { return "🤝" }
        if lower.containsAny("doctor", "medical", "hospital", "physio") { return "🏥" }
        if lower.containsAny("gym", "workout", "exercise") { return "💪" }
        if lower.containsAny("travel", "flight", "airport") { return "✈️" }
        if lower.containsAny("holiday", "vacation", "beach") { return "🏖️" }
        if lower.containsAny("movie", "cinema", "film") { return "🎬" }
        if lower.containsAny("concert", "music", "gig") { return "🎵" }
        if lower.containsAny("invoice", "client", "proposal") { return "📄" }
        if lower.containsAny("tax", "accounting") { return "💰" }
        if lower.containsAny("deadline", "due") { return "⏰" }
        return "📅"
    }

}

// MARK: - Height Measurement (matches Choo pattern)

private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    func readHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: HeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(HeightKey.self, perform: onChange)
    }
}
