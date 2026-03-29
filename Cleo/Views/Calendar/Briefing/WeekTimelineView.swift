import SwiftUI

struct WeekTimelineView: View {
    let weekDays: [Date]
    let eventCounts: [Date: Int]
    var onDayTap: ((Date) -> Void)?

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                let isToday = Calendar.current.isDateInToday(day)
                let isPast = Calendar.current.startOfDay(for: day) < Calendar.current.startOfDay(for: Date())
                let count = eventCounts[Calendar.current.startOfDay(for: day)] ?? 0

                Button {
                    onDayTap?(day)
                } label: {
                    VStack(spacing: 4) {
                        Text(Self.dayFormatter.string(from: day).uppercased().prefix(3))
                            .font(.caption2.bold())
                            .foregroundStyle(.white.opacity(isPast ? 0.25 : 1.0))

                        ZStack {
                            if isToday {
                                Circle()
                                    .fill(TabAccent.calendar.color)
                                    .frame(width: 24, height: 24)
                            }
                            Text("\(Calendar.current.component(.day, from: day))")
                                .font(.caption.bold())
                                .foregroundStyle(isToday ? .white : .white.opacity(isPast ? 0.25 : 0.8))
                        }
                        .frame(width: 24, height: 24)

                        HStack(spacing: 2) {
                            ForEach(0..<min(count, 3), id: \.self) { _ in
                                Circle()
                                    .fill(isPast ? Color.white.opacity(0.15) : TabAccent.calendar.color.opacity(0.6))
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(isPast ? 0.6 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}
