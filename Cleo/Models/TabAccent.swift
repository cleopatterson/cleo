import SwiftUI

enum TabAccent: String, CaseIterable {
    case calendar
    case invoicing
    case todo
    case roadmap
    case metrics

    // MARK: - Colour (static fallbacks — used in previews and before theme loads)

    var color: Color {
        switch self {
        case .calendar: return Color.cleoCalendarPurple
        case .invoicing: return Color.cleoInvoicingGreen
        case .todo: return Color.cleoTodoPink
        case .roadmap: return Color.cleoRoadmapAmber
        case .metrics: return Color.cleoMetricsBlue
        }
    }

    var softColor: Color {
        color.opacity(0.15)
    }

    var icon: String {
        switch self {
        case .calendar: "calendar"
        case .invoicing: "dollarsign.circle"
        case .todo: "note.text"
        case .roadmap: "map"
        case .metrics: "chart.bar"
        }
    }

    var emoji: String {
        switch self {
        case .calendar: "📅"
        case .invoicing: "💰"
        case .todo: "📝"
        case .roadmap: "🗺️"
        case .metrics: "📊"
        }
    }

    var label: String {
        switch self {
        case .calendar: "Calendar"
        case .invoicing: "Money"
        case .todo: "To Do"
        case .roadmap: "Roadmap"
        case .metrics: "Metrics"
        }
    }

    // MARK: - Convenience (for explicit theme access)

    func color(in theme: ThemeManager) -> Color {
        theme.color(for: self)
    }

    // MARK: - Gradients (static fallback only — live views use ThemeManager via @Environment)

    var heroGradientColors: [Color] {
        [color.atBrightness(0.36), color.atBrightness(0.48), color.atBrightness(0.28)]
    }
}
