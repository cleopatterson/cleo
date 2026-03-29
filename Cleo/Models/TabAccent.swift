import SwiftUI

enum TabAccent: String, CaseIterable {
    case calendar
    case invoicing
    case todo
    case roadmap
    case metrics

    /// Shared theme reference — set once on app launch.
    /// All `accent.color` calls resolve through this.
    static var activeTheme: ThemeManager?

    // MARK: - Colour (theme-aware, falls back to static defaults)

    var color: Color {
        if let theme = Self.activeTheme {
            return theme.color(for: self)
        }
        // Static fallback (only used before theme loads)
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

    // MARK: - Gradients (always theme-aware via .color)

    var briefingGradientColors: [Color] {
        let (r, g, b) = color.rgbComponents
        return [
            Color(red: r * 0.35, green: g * 0.35, blue: b * 0.35),
            Color(red: r * 0.50, green: g * 0.50, blue: b * 0.50),
            Color(red: r * 0.30, green: g * 0.30, blue: b * 0.30)
        ]
    }

    var heroGradientColors: [Color] {
        let (r, g, b) = color.rgbComponents
        return [
            Color(red: r * 0.40, green: g * 0.40, blue: b * 0.40),
            Color(red: r * 0.55, green: g * 0.55, blue: b * 0.55),
            Color(red: r * 0.30, green: g * 0.30, blue: b * 0.30)
        ]
    }
}
