import Foundation

/// Reads time-tracking data synced via iCloud Drive from the Mac heartbeat logger
@Observable
class TimeTrackingService {
    var weeks: [WeekSummary] = []
    var lastLoaded: Date?
    var loadError: String?

    private let containerID = "iCloud.com.wallboard.cleo"
    private let fileName = "time-summary.json"
    private let staleDuration: TimeInterval = 300 // 5 minutes

    var isStale: Bool {
        guard let last = lastLoaded else { return true }
        return Date().timeIntervalSince(last) > staleDuration
    }

    // MARK: - Current Week

    var currentWeek: WeekSummary? {
        let cal = Calendar.current
        let today = Date()
        return weeks.first { week in
            guard let start = Self.dateFromString(week.weekStart),
                  let end = Self.dateFromString(week.weekEnd) else { return false }
            return start <= today && cal.date(byAdding: .day, value: 1, to: end)! > today
        }
    }

    var previousWeek: WeekSummary? {
        guard let current = currentWeek,
              let currentStart = Self.dateFromString(current.weekStart) else {
            return weeks.dropLast(0).last // fallback to most recent
        }
        let cal = Calendar.current
        let prevWeekDate = cal.date(byAdding: .weekOfYear, value: -1, to: currentStart)!
        return weeks.first { week in
            guard let start = Self.dateFromString(week.weekStart) else { return false }
            return cal.isDate(start, inSameDayAs: prevWeekDate)
        }
    }

    var heroClient: ClientHours? {
        currentWeek?.clients.first // Already sorted by hours descending
    }

    var totalHoursThisWeek: Double {
        currentWeek?.totalHours ?? 0
    }

    var totalHoursLastWeek: Double {
        previousWeek?.totalHours ?? 0
    }

    var weekOverWeekChange: Double? {
        guard totalHoursLastWeek > 0 else { return nil }
        return ((totalHoursThisWeek - totalHoursLastWeek) / totalHoursLastWeek) * 100
    }

    // MARK: - Load Data

    func loadIfNeeded() async {
        guard isStale else { return }
        await load()
    }

    func load() async {
        // Try iCloud first, fall back to bundled data (for simulator / first launch)
        if let data = await loadFromICloud() ?? loadFromBundle() {
            do {
                let summary = try JSONDecoder().decode(TimeSummary.self, from: data)
                weeks = summary.weeks
                lastLoaded = Date()
                loadError = nil
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    private func loadFromICloud() async -> Data? {
        guard let fileURL = iCloudFileURL() else { return nil }

        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            try? fm.startDownloadingUbiquitousItem(at: fileURL)
            try? await Task.sleep(for: .seconds(2))
        }

        guard fm.fileExists(atPath: fileURL.path) else { return nil }
        return try? await coordinatedRead(at: fileURL)
    }

    private func loadFromBundle() -> Data? {
        guard let url = Bundle.main.url(forResource: "time-summary", withExtension: "json") else {
            loadError = "No time data available. Rebuild app after running sync."
            return nil
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            loadError = "Bundle read failed: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - iCloud

    private func iCloudFileURL() -> URL? {
        // Try app-specific iCloud container first
        if let container = FileManager.default.url(forUbiquityContainerIdentifier: containerID) {
            let url = container.appendingPathComponent("Documents").appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // Fallback: check general iCloud Drive (com~apple~CloudDocs/Cleo/)
        if let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            // Navigate up from the default container to the Mobile Documents root
            let mobileDocsRoot = container.deletingLastPathComponent()
            let url = mobileDocsRoot
                .appendingPathComponent("com~apple~CloudDocs")
                .appendingPathComponent("Cleo")
                .appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // If iCloud isn't available at all, return the container path (will show helpful error)
        return FileManager.default.url(forUbiquityContainerIdentifier: containerID)?
            .appendingPathComponent("Documents")
            .appendingPathComponent(fileName)
    }

    private func coordinatedRead(at url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let coordinator = NSFileCoordinator()
            var error: NSError?
            coordinator.coordinate(readingItemAt: url, options: [], error: &error) { readURL in
                do {
                    let data = try Data(contentsOf: readURL)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            if let error {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Helpers

    static func dateFromString(_ str: String) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        return fmt.date(from: str)
    }

    static func weekLabel(_ weekStart: String) -> String {
        guard let date = dateFromString(weekStart) else { return weekStart }
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        let end = Calendar.current.date(byAdding: .day, value: 6, to: date)!
        return "\(fmt.string(from: date)) – \(fmt.string(from: end))"
    }
}

// MARK: - Models

struct TimeSummary: Codable {
    let generated: String
    let weeks: [WeekSummary]
}

struct WeekSummary: Codable, Identifiable {
    var id: String { weekStart }
    let weekStart: String
    let weekEnd: String
    let clients: [ClientHours]
    let totalHours: Double
}

struct ClientHours: Codable, Identifiable {
    var id: String { name }
    let name: String
    let hours: Double
    let sessions: Int

    var formattedHours: String {
        if hours < 1 {
            return String(format: "%.0fm", hours * 60)
        }
        return String(format: "%.1fh", hours)
    }
}
