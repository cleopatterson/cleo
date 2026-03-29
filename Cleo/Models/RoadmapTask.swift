import Foundation
import CoreData

enum TaskStatus: String, CaseIterable, Codable {
    case backlog
    case inProgress
    case done

    var label: String {
        switch self {
        case .backlog: "Backlog"
        case .inProgress: "In Progress"
        case .done: "Done"
        }
    }
}

enum TaskPriority: String, CaseIterable, Codable {
    case low
    case medium
    case high
    case urgent

    var label: String {
        rawValue.capitalized
    }

    var emoji: String {
        switch self {
        case .low: "🟢"
        case .medium: "🟡"
        case .high: "🟠"
        case .urgent: "🔴"
        }
    }
}

@objc(RoadmapTask)
public class RoadmapTask: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String
    @NSManaged public var statusRaw: String
    @NSManaged public var priorityRaw: String
    @NSManaged public var dueDate: Date?
    @NSManaged public var assignee: String?           // "Tony", "Cleo"
    @NSManaged public var notes: String?
    @NSManaged public var isBlocked: Bool
    @NSManaged public var blockedReason: String?
    @NSManaged public var sortOrder: Int16
    @NSManaged public var milestone: Milestone?

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .backlog }
        set { statusRaw = newValue.rawValue }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }
}
