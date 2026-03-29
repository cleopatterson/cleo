import Foundation

struct ParsedEventInput {
    var title: String
    var date: Date?
    var endDate: Date?
    var time: Date?
    var location: String?
    var isAllDay: Bool

    static func parse(from text: String, referenceDate: Date) -> ParsedEventInput? {
        var title = ""
        var date: Date?
        var endDate: Date?
        var time: Date?
        var location: String?
        var isAllDay = false

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("TITLE:") {
                title = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("END_DATE:") {
                let val = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { endDate = dateFormatter.date(from: val) }
            } else if trimmed.hasPrefix("DATE:") {
                let val = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                date = dateFormatter.date(from: val)
            } else if trimmed.hasPrefix("TIME:") {
                let val = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { time = timeFormatter.date(from: val) }
            } else if trimmed.hasPrefix("LOCATION:") {
                let val = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { location = val }
            } else if trimmed.hasPrefix("IS_ALL_DAY:") {
                isAllDay = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespaces).lowercased() == "true"
            }
        }

        guard !title.isEmpty else { return nil }
        return ParsedEventInput(title: title, date: date, endDate: endDate, time: time, location: location, isAllDay: isAllDay)
    }
}
