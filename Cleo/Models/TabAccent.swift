import SwiftUI

enum TabAccent: String, CaseIterable {
    case calendar
    case invoicing
    case todo
    case roadmap
    case metrics

    // MARK: - Colour (single brand accent across all tabs)

    var color: Color {
        Color(hex: ThemeManager.currentBrandAccentHex)
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

    // MARK: - Gradients

    var heroGradientColors: [Color] {
        let accent = color
        return [accent.atBrightness(0.36), accent.atBrightness(0.48), accent.atBrightness(0.28)]
    }
}
