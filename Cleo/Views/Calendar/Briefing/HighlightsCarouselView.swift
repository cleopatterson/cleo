import SwiftUI

struct WeekHighlight: Identifiable {
    let id: String
    let title: String
    let date: Date
    let icon: String
    let isPast: Bool
    let isTodo: Bool
    let todoUrgency: TodoUrgencyState?
    let isCompleted: Bool

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    var dateLabel: String {
        if isTodo {
            if isCompleted { return "Done" }
            if let urgency = todoUrgency {
                switch urgency {
                case .overdue: return "Overdue"
                case .dueSoon: return "Due soon"
                default: break
                }
            }
            return Self.dayFormatter.string(from: date)
        }
        return Self.dayFormatter.string(from: date)
    }
}

struct HighlightsCarouselView: View {
    let highlights: [WeekHighlight]
    var heading: String = "THIS WEEK'S HIGHLIGHTS"
    var scrollToDate: Date?
    var onEventTap: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading)
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)
                .padding(.horizontal, 4)

            if highlights.isEmpty {
                Text("No events this week")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(highlights) { highlight in
                                Button {
                                    print("[HighlightsCarousel] Tapped highlight: \(highlight.id) title=\(highlight.title)")
                                    onEventTap?(highlight.id)
                                } label: {
                                    highlightCard(highlight)
                                }
                                .buttonStyle(.plain)
                                .id(highlight.id)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .onAppear {
                        if let firstUpcoming = highlights.first(where: { !$0.isPast }) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(firstUpcoming.id, anchor: .leading)
                            }
                        }
                    }
                    .onChange(of: scrollToDate) {
                        if let target = scrollToDate,
                           let match = highlights.first(where: { Calendar.current.isDate($0.date, inSameDayAs: target) }) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(match.id, anchor: .leading)
                            }
                        }
                    }
                }
            }
        }
    }

    private func highlightCard(_ highlight: WeekHighlight) -> some View {
        let borderColor = cardBorderColor(highlight)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(highlight.icon)
                    .font(.title3)
                Spacer()
                if highlight.isTodo && !highlight.isCompleted, let urgency = highlight.todoUrgency {
                    urgencyBadge(urgency)
                } else if highlight.isTodo && highlight.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if highlight.isPast {
                    Text("Done")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            Text(highlight.title)
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(highlight.isPast ? 0.35 : 1.0))
                .lineLimit(2)
                .strikethrough(highlight.isTodo && highlight.isPast)

            Spacer()

            Text(highlight.dateLabel)
                .font(.caption2)
                .foregroundStyle(dateLabelColor(highlight))
        }
        .frame(width: 120)
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .saturation(highlight.isPast ? 0 : 1)
        .opacity(highlight.isPast ? 0.7 : 1.0)
    }

    private func cardBorderColor(_ highlight: WeekHighlight) -> Color {
        if highlight.isTodo, let urgency = highlight.todoUrgency {
            switch urgency {
            case .overdue: return .red.opacity(0.25)
            case .dueSoon: return .orange.opacity(0.2)
            case .active: return .cyan.opacity(0.15)
            default: break
            }
        }
        return .white.opacity(0.08)
    }

    private func dateLabelColor(_ highlight: WeekHighlight) -> Color {
        if highlight.isTodo, let urgency = highlight.todoUrgency {
            switch urgency {
            case .overdue: return .red
            case .dueSoon: return .orange
            case .active, .flexible: return .cyan
            default: break
            }
        }
        return .white.opacity(0.4)
    }

    @ViewBuilder
    private func urgencyBadge(_ urgency: TodoUrgencyState) -> some View {
        let (label, color): (String, Color) = {
            switch urgency {
            case .overdue: ("Overdue", .red)
            case .dueSoon: ("Due soon", .orange)
            case .active: ("To-Do", .cyan)
            case .flexible: ("Flexible", Color.white.opacity(0.4))
            default: ("", .clear)
            }
        }()
        if !label.isEmpty {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(color)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(color.opacity(0.15), in: Capsule())
        }
    }
}
