import SwiftUI

/// Roadmap tab — Timeline + Board views (§5)
struct RoadmapTabView: View {
    @Bindable var viewModel: RoadmapViewModel
    @Binding var showingProfile: Bool
    @Bindable var theme: ThemeManager
    @State private var showCreateMilestone = false
    @State private var milestoneToDelete: Milestone?
    @State private var showDeleteMilestoneConfirmation = false
    @State private var taskToDelete: RoadmapTask?
    @State private var showDeleteTaskConfirmation = false
    @State private var selectedMilestone: Milestone?
    @State private var showAddTaskSheet = false
    @State private var addTaskToMilestone: Milestone?

    // Milestone creation fields
    @State private var newMilestoneTitle = ""
    @State private var newMilestoneEmoji = "🚀"
    @State private var newMilestoneDate: Date? = nil
    @State private var newMilestoneDateEnabled = false

    // Task creation fields
    @State private var newTaskTitle = ""
    @State private var newTaskPriority = TaskPriority.medium

    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                // Layer 1: AI Briefing
                BriefingCardView(
                    badge: "AI BRIEFING",
                    headline: viewModel.briefing?.headline ?? "\(activeMilestoneCount) milestones, \(viewModel.inProgressTaskCount) tasks in progress",
                    summary: viewModel.briefing?.summary ?? "Loading your roadmap briefing...",
                    stats: viewModel.briefing?.stats.map {
                        BriefingCardView.StatPill(label: $0.label, value: $0.value)
                    } ?? defaultStats,
                    accent: .roadmap,
                    isLoading: viewModel.isLoadingBriefing
                )

                // Layer 2: Hero Card — Next Milestone
                if let milestone = viewModel.heroMilestone {
                    let progress = Int(milestone.progressFraction * 100)
                    HeroCardView(
                        label: "NEXT MILESTONE",
                        title: milestone.title,
                        subtitle: milestoneSubtitle(milestone),
                        emoji: milestone.emoji,
                        accent: .roadmap
                    ) {
                        HeroCardView<AnyView>.coloredPill(text: "\(progress)%", color: TabAccent.roadmap.color)
                        if let target = milestone.targetDate {
                            HeroCardView<AnyView>.surfacePill(text: daysUntil(target))
                        }
                        if viewModel.blockedTaskCount > 0 {
                            HeroCardView<AnyView>.coloredPill(text: "\(viewModel.blockedTaskCount) blocked", color: .red)
                        }
                    }
                } else {
                    HeroCardView<EmptyView>(
                        label: "ROADMAP",
                        title: "",
                        subtitle: "",
                        emoji: "🗺️",
                        accent: .roadmap,
                        isEmpty: true,
                        emptyMessage: "No milestones yet"
                    ) { EmptyView() }
                }

                // View Toggle
                viewToggle

                // Layer 3: Content
                if viewModel.showBoardView {
                    boardView
                } else {
                    timelineView
                }

                if viewModel.milestones.isEmpty {
                    VStack(spacing: 8) {
                        Text("No milestones yet")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.3))
                        Text("Tap + to create your first milestone.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.2))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                }
            }
            .padding(.horizontal, 16)
        }
        .contentMargins(.top, 8, for: .scrollContent)
        .cleoBackground(theme: theme)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ProfileButtonView { showingProfile = true }
            }
            ToolbarItem(placement: .principal) {
                Text("Roadmap")
                    .font(.system(.headline, design: .serif))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateMilestone = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear { viewModel.loadBriefing() }
        .sheet(isPresented: $showCreateMilestone) {
            milestoneCreateSheet
        }
        .sheet(isPresented: $showAddTaskSheet) {
            taskCreateSheet
        }
        .confirmationDialog(
            "Delete milestone \"\(milestoneToDelete?.title ?? "")\"?",
            isPresented: $showDeleteMilestoneConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let milestone = milestoneToDelete {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    viewModel.deleteMilestone(milestone)
                }
            }
        }
        .confirmationDialog(
            "Delete task \"\(taskToDelete?.title ?? "")\"?",
            isPresented: $showDeleteTaskConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let task = taskToDelete {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    viewModel.deleteTask(task)
                }
            }
        }
        } // NavigationStack
    }

    // MARK: - Milestone Create Sheet

    private var milestoneCreateSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    formSection("MILESTONE") {
                        TextField("Title", text: $newMilestoneTitle)
                            .foregroundStyle(.white)
                    }

                    formSection("EMOJI") {
                        TextField("🚀", text: $newMilestoneEmoji)
                            .foregroundStyle(.white)
                    }

                    formSection("TARGET DATE") {
                        Toggle("Set target date", isOn: $newMilestoneDateEnabled)
                            .foregroundStyle(.white)
                            .tint(TabAccent.roadmap.color)

                        if newMilestoneDateEnabled {
                            DatePicker("Date", selection: Binding(
                                get: { newMilestoneDate ?? Date() },
                                set: { newMilestoneDate = $0 }
                            ), displayedComponents: .date)
                            .foregroundStyle(.white)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("New Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetMilestoneForm()
                        showCreateMilestone = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        _ = viewModel.createMilestone(
                            title: newMilestoneTitle.trimmingCharacters(in: .whitespaces),
                            emoji: newMilestoneEmoji.isEmpty ? "🚀" : newMilestoneEmoji,
                            targetDate: newMilestoneDateEnabled ? (newMilestoneDate ?? Date()) : nil
                        )
                        resetMilestoneForm()
                        showCreateMilestone = false
                    }
                    .bold()
                    .disabled(newMilestoneTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - Task Create Sheet

    private var taskCreateSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let milestone = addTaskToMilestone {
                        HStack(spacing: 8) {
                            Text(milestone.emoji)
                            Text(milestone.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                    }

                    formSection("TASK") {
                        TextField("Task title", text: $newTaskTitle)
                            .foregroundStyle(.white)
                    }

                    formSection("PRIORITY") {
                        Picker("Priority", selection: $newTaskPriority) {
                            ForEach(TaskPriority.allCases, id: \.self) { priority in
                                Text("\(priority.emoji) \(priority.label)").tag(priority)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(16)
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetTaskForm()
                        showAddTaskSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let milestone = addTaskToMilestone {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            _ = viewModel.createTask(
                                title: newTaskTitle.trimmingCharacters(in: .whitespaces),
                                priority: newTaskPriority,
                                milestone: milestone
                            )
                        }
                        resetTaskForm()
                        showAddTaskSheet = false
                    }
                    .bold()
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(.ultraThinMaterial)
    }

    private func resetMilestoneForm() {
        newMilestoneTitle = ""
        newMilestoneEmoji = "🚀"
        newMilestoneDate = nil
        newMilestoneDateEnabled = false
    }

    private func resetTaskForm() {
        newTaskTitle = ""
        newTaskPriority = .medium
        addTaskToMilestone = nil
    }

    // MARK: - View Toggle

    private var viewToggle: some View {
        HStack(spacing: 0) {
            toggleButton("Timeline", isActive: !viewModel.showBoardView) {
                viewModel.showBoardView = false
            }
            toggleButton("Board", isActive: viewModel.showBoardView) {
                viewModel.showBoardView = true
            }
        }
        .background(.white.opacity(0.04), in: Capsule())
    }

    private func toggleButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isActive ? .white : .white.opacity(0.4))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(isActive ? TabAccent.roadmap.color.opacity(0.2) : .clear, in: Capsule())
        }
    }

    // MARK: - Timeline View

    private var timelineView: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.milestones) { milestone in
                milestoneCard(milestone)
            }
        }
    }

    private func milestoneCard(_ milestone: Milestone) -> some View {
        let isCompleted = milestone.status == .completed

        return VStack(alignment: .leading, spacing: 8) {
            // Milestone header
            HStack {
                Text(milestone.emoji)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(isCompleted ? .white.opacity(0.4) : .white)

                    if let target = milestone.targetDate {
                        Text("Due \(target.formatted(.dateTime.day().month(.abbreviated)))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                Spacer()

                Text("\(milestone.completedTaskCount)/\(milestone.totalTaskCount)")
                    .font(.caption.bold())
                    .foregroundStyle(TabAccent.roadmap.color)
            }
            .contentShape(Rectangle())
            .contextMenu {
                Button(role: .destructive) {
                    milestoneToDelete = milestone
                    showDeleteMilestoneConfirmation = true
                } label: {
                    Label("Delete Milestone", systemImage: "trash")
                }
            }

            // Tasks
            ForEach(milestone.tasksArray) { task in
                taskRow(task)
                    .contextMenu {
                        if task.status != .done {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                viewModel.updateTaskStatus(task, to: .done)
                            } label: {
                                Label("Mark as Done", systemImage: "checkmark.circle.fill")
                            }
                        } else {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                viewModel.updateTaskStatus(task, to: .backlog)
                            } label: {
                                Label("Move to Backlog", systemImage: "arrow.uturn.backward")
                            }
                        }
                        Button(role: .destructive) {
                            taskToDelete = task
                            showDeleteTaskConfirmation = true
                        } label: {
                            Label("Delete Task", systemImage: "trash")
                        }
                    }
            }

            // Add task button
            Button {
                addTaskToMilestone = milestone
                showAddTaskSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.caption2)
                    Text("Add task").font(.caption)
                }
                .foregroundStyle(.white.opacity(0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
        }
        .padding(14)
        .background(.white.opacity(isCompleted ? 0.02 : 0.04), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .opacity(isCompleted ? 0.6 : 1)
    }

    private func taskRow(_ task: RoadmapTask) -> some View {
        HStack(spacing: 8) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                let newStatus: TaskStatus = task.status == .done ? .backlog : .done
                viewModel.updateTaskStatus(task, to: newStatus)
            } label: {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(task.status == .done ? .green : .white.opacity(0.3))
            }

            Text(task.title)
                .font(.caption)
                .foregroundStyle(.white.opacity(task.status == .done ? 0.4 : 0.8))
                .strikethrough(task.status == .done)

            Spacer()

            if task.isBlocked {
                HeroCardView<EmptyView>.coloredPill(text: "Blocked", color: .red)
            }

            Text(task.priority.emoji)
                .font(.caption2)
        }
        .padding(.leading, 8)
    }

    // MARK: - Board View (Kanban)

    private var boardView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                boardColumn("Backlog", tasks: viewModel.tasks(for: .backlog), color: .white.opacity(0.6))
                boardColumn("In Progress", tasks: viewModel.tasks(for: .inProgress), color: .cleoRoadmapAmber)
                boardColumn("Done", tasks: viewModel.tasks(for: .done), color: .green)
            }
            .padding(.horizontal, 4)
        }
    }

    private func boardColumn(_ title: String, tasks: [RoadmapTask], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .tracking(1)

                Spacer()

                Text("\(tasks.count)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }

            ForEach(tasks) { task in
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))

                    if let milestone = task.milestone {
                        Text("\(milestone.emoji) \(milestone.title)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }

            if tasks.isEmpty {
                Text("Empty")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.2))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
        }
        .frame(width: 200)
        .padding(12)
        .background(.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Form Section Helper

    private func formSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)

            VStack(spacing: 8) {
                content()
            }
            .padding(14)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers

    private var activeMilestoneCount: Int {
        viewModel.milestones.filter { $0.status != .completed && $0.status != .deferred }.count
    }

    private var defaultStats: [BriefingCardView.StatPill] {
        [
            .init(label: "In Progress", value: "\(viewModel.inProgressTaskCount)"),
            .init(label: "This Month", value: "\(activeMilestoneCount)"),
            .init(label: "Blocked", value: "\(viewModel.blockedTaskCount)")
        ]
    }

    private func milestoneSubtitle(_ milestone: Milestone) -> String {
        var parts: [String] = []
        if let target = milestone.targetDate {
            parts.append("Due \(target.formatted(.dateTime.day().month(.abbreviated)))")
        }
        parts.append("\(milestone.completedTaskCount)/\(milestone.totalTaskCount) tasks done")
        return parts.joined(separator: " · ")
    }

    private func daysUntil(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days < 0 { return "\(abs(days))d overdue" }
        if days == 0 { return "Today" }
        return "\(days)d left"
    }
}
