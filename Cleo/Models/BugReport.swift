import Foundation
import CoreData

// MARK: - Enums

enum BugSeverity: String, CaseIterable, Identifiable {
    case low, medium, high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

enum BugStatus: String, CaseIterable, Identifiable {
    case open, inProgress, fixed, closed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .open: "Open"
        case .inProgress: "In Progress"
        case .fixed: "Fixed"
        case .closed: "Closed"
        }
    }
}

// MARK: - Core Data Managed Object

@objc(BugReport)
public class BugReport: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String
    @NSManaged public var bugDescription: String
    @NSManaged public var severityRaw: String
    @NSManaged public var statusRaw: String
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var githubIssueUrl: String?
    @NSManaged public var githubIssueNumber: Int32

    var severity: BugSeverity {
        get { BugSeverity(rawValue: severityRaw) ?? .medium }
        set { severityRaw = newValue.rawValue }
    }

    var status: BugStatus {
        get { BugStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    var hasGitHubIssue: Bool { githubIssueNumber > 0 }
}
