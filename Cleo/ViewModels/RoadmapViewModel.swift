import SwiftUI
import CoreData

@MainActor
@Observable
class RoadmapViewModel {
    let context: NSManagedObjectContext
    let claudeService: ClaudeAPIService

    var milestones: [Milestone] = []
    var briefing: AIBriefingResponse?
    var isLoadingBriefing = false
    @ObservationIgnored private var hasLoadedBriefing = false
    var showBoardView = false  // false = timeline, true = board

    init(context: NSManagedObjectContext, claudeService: ClaudeAPIService) {
        self.context = context
        self.claudeService = claudeService
        fetchMilestones()
    }

    func fetchMilestones() {
        let request = NSFetchRequest<Milestone>(entityName: "Milestone")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Milestone.sortOrder, ascending: true)]
        milestones = (try? context.fetch(request)) ?? []
    }

    // MARK: - Computed

    var heroMilestone: Milestone? {
        milestones.first { $0.status == .inProgress || $0.status == .planning }
    }

    var inProgressTaskCount: Int {
        milestones.flatMap { $0.tasksArray }.filter { $0.status == .inProgress }.count
    }

    var blockedTaskCount: Int {
        milestones.flatMap { $0.tasksArray }.filter { $0.isBlocked }.count
    }

    var allTasks: [RoadmapTask] {
        milestones.flatMap { $0.tasksArray }
    }

    func tasks(for status: TaskStatus) -> [RoadmapTask] {
        allTasks.filter { $0.status == status }
    }

    // MARK: - CRUD

    func createMilestone(title: String, emoji: String, targetDate: Date?) -> Milestone {
        let milestone = Milestone(context: context)
        milestone.id = UUID()
        milestone.title = title
        milestone.emoji = emoji
        milestone.targetDate = targetDate
        milestone.statusRaw = MilestoneStatus.planning.rawValue
        milestone.sortOrder = Int16(milestones.count)
        PersistenceController.shared.save()
        fetchMilestones()
        return milestone
    }

    func createTask(title: String, priority: TaskPriority, milestone: Milestone, dueDate: Date? = nil, assignee: String? = nil) -> RoadmapTask {
        let task = RoadmapTask(context: context)
        task.id = UUID()
        task.title = title
        task.priority = priority
        task.statusRaw = TaskStatus.backlog.rawValue
        task.dueDate = dueDate
        task.assignee = assignee
        task.isBlocked = false
        task.sortOrder = Int16(milestone.tasksArray.count)
        task.milestone = milestone
        PersistenceController.shared.save()
        fetchMilestones()
        return task
    }

    func updateTaskStatus(_ task: RoadmapTask, to status: TaskStatus) {
        task.status = status
        PersistenceController.shared.save()
        fetchMilestones()
    }

    func toggleBlocked(_ task: RoadmapTask) {
        task.isBlocked.toggle()
        PersistenceController.shared.save()
        fetchMilestones()
    }

    func deleteTask(_ task: RoadmapTask) {
        context.delete(task)
        PersistenceController.shared.save()
        fetchMilestones()
    }

    func deleteMilestone(_ milestone: Milestone) {
        context.delete(milestone)
        PersistenceController.shared.save()
        fetchMilestones()
    }

    // MARK: - Briefing

    @ObservationIgnored private var briefingTask: Task<Void, Never>?

    func loadBriefing() {
        guard !hasLoadedBriefing || briefing == nil else { return }
        guard briefingTask == nil else { return }
        hasLoadedBriefing = true
        isLoadingBriefing = true

        let payload: [String: Any] = [
            "milestoneCount": milestones.filter { $0.status != .completed }.count,
            "inProgress": inProgressTaskCount,
            "blocked": blockedTaskCount,
            "totalTasks": allTasks.count
        ]

        briefingTask = Task {
            let result = await claudeService.generateBriefing(tab: .roadmap, dataPayload: payload)
            briefing = result
            isLoadingBriefing = false
            briefingTask = nil
            if result == nil { hasLoadedBriefing = false }
        }
    }
}
