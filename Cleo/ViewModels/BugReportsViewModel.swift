import Foundation
import CoreData

@MainActor
@Observable
final class BugReportsViewModel {
    let persistence: PersistenceController
    let github = GitHubService.shared

    var bugReports: [BugReport] = []
    var showingBugEditor = false
    var editingBugReport: BugReport?

    init(persistence: PersistenceController) {
        self.persistence = persistence
        fetchBugReports()
    }

    // MARK: - Fetch

    func fetchBugReports() {
        let request = NSFetchRequest<BugReport>(entityName: "BugReport")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        bugReports = (try? persistence.viewContext.fetch(request)) ?? []
    }

    // MARK: - Create

    func createBugReport(title: String, description: String, severity: BugSeverity) async {
        let report = BugReport(context: persistence.viewContext)
        report.id = UUID()
        report.title = title
        report.bugDescription = description
        report.severity = severity
        report.status = .open
        report.createdAt = Date()
        report.updatedAt = Date()
        report.githubIssueNumber = 0
        persistence.save()
        fetchBugReports()

        // Create GitHub issue in background
        if let (number, url) = await github.createIssue(title: title, description: description, severity: severity) {
            report.githubIssueNumber = Int32(number)
            report.githubIssueUrl = url
            report.status = .inProgress
            report.updatedAt = Date()
            persistence.save()
            fetchBugReports()
        }
    }

    // MARK: - Delete

    func deleteBugReport(_ report: BugReport) {
        persistence.viewContext.delete(report)
        persistence.save()
        fetchBugReports()
    }

    // MARK: - Status Sync

    /// Polls GitHub for updated status on all open/inProgress reports.
    /// Called when the bugs tab becomes visible.
    func syncStatusFromGitHub() async {
        let openReports = bugReports.filter {
            $0.hasGitHubIssue && ($0.status == .open || $0.status == .inProgress)
        }
        for report in openReports {
            if let newStatus = await github.fetchIssueStatus(number: Int(report.githubIssueNumber)) {
                if newStatus != report.status {
                    report.status = newStatus
                    report.updatedAt = Date()
                }
            }
        }
        if !openReports.isEmpty {
            persistence.save()
            fetchBugReports()
        }
    }
}
