import Foundation
import CoreData

enum MilestoneStatus: String, CaseIterable, Codable {
    case planning
    case inProgress
    case completed
    case deferred

    var label: String {
        switch self {
        case .planning: "Planning"
        case .inProgress: "In Progress"
        case .completed: "Completed"
        case .deferred: "Deferred"
        }
    }
}

@objc(Milestone)
public class Milestone: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String
    @NSManaged public var emoji: String
    @NSManaged public var targetDate: Date?
    @NSManaged public var statusRaw: String
    @NSManaged public var notes: String?
    @NSManaged public var sortOrder: Int16
    @NSManaged public var tasks: NSSet?

    var status: MilestoneStatus {
        get { MilestoneStatus(rawValue: statusRaw) ?? .planning }
        set { statusRaw = newValue.rawValue }
    }

    var tasksArray: [RoadmapTask] {
        let set = tasks as? Set<RoadmapTask> ?? []
        return set.sorted { $0.sortOrder < $1.sortOrder }
    }

    var completedTaskCount: Int {
        tasksArray.filter { $0.status == .done }.count
    }

    var totalTaskCount: Int {
        tasksArray.count
    }

    var progressFraction: Double {
        guard totalTaskCount > 0 else { return 0 }
        return Double(completedTaskCount) / Double(totalTaskCount)
    }
}
