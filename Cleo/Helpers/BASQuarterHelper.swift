import Foundation

/// Australian BAS quarter definition
struct BASQuarter {
    let label: String   // e.g. "Q3 FY26"
    let start: Date
    let end: Date
    let dueDate: Date

    var daysUntilDue: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0)
    }
}

/// Australian FY quarter logic
///   Q1: Jul–Sep  → BAS due 28 Oct
///   Q2: Oct–Dec  → BAS due 28 Feb
///   Q3: Jan–Mar  → BAS due 28 Apr
///   Q4: Apr–Jun  → BAS due 28 Jul
enum BASQuarterHelper {
    static func currentQuarter(for referenceDate: Date = Date()) -> BASQuarter {
        let cal = Calendar.current
        let month = cal.component(.month, from: referenceDate)
        let year  = cal.component(.year,  from: referenceDate)

        switch month {
        case 7...9:
            let fy = (year + 1) % 100
            return BASQuarter(
                label:   "Q1 FY\(fy)",
                start:   makeDate(year, 7, 1),
                end:     makeDate(year, 9, 30),
                dueDate: makeDate(year, 10, 28)
            )
        case 10...12:
            let fy = (year + 1) % 100
            return BASQuarter(
                label:   "Q2 FY\(fy)",
                start:   makeDate(year, 10, 1),
                end:     makeDate(year, 12, 31),
                dueDate: makeDate(year + 1, 2, 28)
            )
        case 1...3:
            let fy = year % 100
            return BASQuarter(
                label:   "Q3 FY\(fy)",
                start:   makeDate(year, 1, 1),
                end:     makeDate(year, 3, 31),
                dueDate: makeDate(year, 4, 28)
            )
        case 4...6:
            let fy = year % 100
            return BASQuarter(
                label:   "Q4 FY\(fy)",
                start:   makeDate(year, 4, 1),
                end:     makeDate(year, 6, 30),
                dueDate: makeDate(year, 7, 28)
            )
        default:
            fatalError("Invalid month: \(month)")
        }
    }

    /// Returns all "yyyy-MM" strings spanning the quarter
    static func monthStrings(for quarter: BASQuarter) -> [String] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        var months: [String] = []
        var cursor = quarter.start
        let cal = Calendar.current
        while cursor <= quarter.end {
            months.append(fmt.string(from: cursor))
            guard let next = cal.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return months
    }

    private static func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        return Calendar.current.date(from: c) ?? Date()
    }
}
