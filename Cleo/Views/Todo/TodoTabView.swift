import SwiftUI

private enum TabMode: String, CaseIterable {
    case notes = "Notes"
    case bugs = "Bugs"
}

struct TodoTabView: View {
    @Bindable var viewModel: TodoViewModel
    @Bindable var bugReportsViewModel: BugReportsViewModel
    @Binding var showingProfile: Bool
    @Bindable var theme: ThemeManager
    @State private var mode: TabMode = .notes
    @State private var noteToDelete: TodoNote?
    @State private var bugToDelete: BugReport?

    private static let timestampFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(TabMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                Group {
                    if mode == .notes {
                        notesContent
                    } else {
                        bugsContent
                    }
                }
            }
            .cleoBackground(theme: theme)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileButtonView { showingProfile = true }
                }
                ToolbarItem(placement: .principal) {
                    Text("Notes")
                        .font(.system(.headline, design: .serif))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if mode == .notes {
                            viewModel.editingNote = nil
                            viewModel.showingNoteEditor = true
                        } else {
                            bugReportsViewModel.editingBugReport = nil
                            bugReportsViewModel.showingBugEditor = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingNoteEditor) {
                NoteEditorView(existingNote: viewModel.editingNote) { title, content, isList in
                    if let note = viewModel.editingNote {
                        viewModel.updateNote(note, title: title, content: content)
                    } else {
                        viewModel.createNote(title: title, content: content, isList: isList)
                    }
                }
                .presentationBackground(.ultraThinMaterial)
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $bugReportsViewModel.showingBugEditor) {
                BugReportEditorView(
                    existingReport: bugReportsViewModel.editingBugReport,
                    theme: theme
                ) { title, description, severity in
                    await bugReportsViewModel.createBugReport(title: title, description: description, severity: severity)
                }
                .presentationBackground(.ultraThinMaterial)
                .presentationDetents([.medium, .large])
            }
            .confirmationDialog(
                "Delete \"\(noteToDelete?.wrappedTitle ?? "")\"?",
                isPresented: Binding(get: { noteToDelete != nil }, set: { if !$0 { noteToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let note = noteToDelete { viewModel.deleteNote(note); noteToDelete = nil }
                }
            }
            .confirmationDialog(
                "Delete \"\(bugToDelete?.title ?? "")\"?",
                isPresented: Binding(get: { bugToDelete != nil }, set: { if !$0 { bugToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let bug = bugToDelete { bugReportsViewModel.deleteBugReport(bug); bugToDelete = nil }
                }
            }
            .task(id: mode) {
                if mode == .bugs {
                    await bugReportsViewModel.syncStatusFromGitHub()
                }
            }
        }
    }

    // MARK: - Notes Content

    @ViewBuilder
    private var notesContent: some View {
        if viewModel.notes.isEmpty {
            ContentUnavailableView("No Notes", systemImage: "note.text", description: Text("Tap + to create your first note."))
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.notes) { note in
                        Button {
                            viewModel.editingNote = note
                            viewModel.showingNoteEditor = true
                        } label: {
                            noteRow(note)
                        }
                        .tint(.primary)
                        .contextMenu {
                            Button(role: .destructive) { noteToDelete = note } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .contentMargins(.top, 8, for: .scrollContent)
        }
    }

    // MARK: - Bugs Content

    @ViewBuilder
    private var bugsContent: some View {
        if bugReportsViewModel.bugReports.isEmpty {
            ContentUnavailableView("No Bug Reports", systemImage: "ladybug", description: Text("Tap + to report a bug."))
        } else {
            List {
                ForEach(bugReportsViewModel.bugReports) { report in
                    Button {
                        bugReportsViewModel.editingBugReport = report
                        bugReportsViewModel.showingBugEditor = true
                    } label: {
                        bugRow(report)
                    }
                    .tint(.primary)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.thinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                            .padding(.vertical, 4)
                    )
                }
                .onDelete { indexSet in
                    if let index = indexSet.first { bugToDelete = bugReportsViewModel.bugReports[index] }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Note Row

    private func noteRow(_ note: TodoNote) -> some View {
        HStack(spacing: 12) {
            Image(systemName: note.isList ? "checklist" : "note.text")
                .foregroundStyle(.secondary)
                .imageScale(.large)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.wrappedTitle)
                    .font(.headline)
                    .lineLimit(1)

                if !note.wrappedContent.isEmpty {
                    if note.isList {
                        listPreview(for: note.wrappedContent)
                    } else {
                        Text(note.wrappedContent)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                HStack {
                    Spacer()
                    Text(Self.timestampFormatter.localizedString(for: note.wrappedUpdatedAt, relativeTo: Date()))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Bug Row

    private func bugRow(_ report: BugReport) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor(report.status))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(report.title)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Text(report.severity.displayName)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(severityColor(report.severity).opacity(0.15))
                        .foregroundStyle(severityColor(report.severity))
                        .clipShape(Capsule())
                }

                if !report.bugDescription.isEmpty {
                    Text(report.bugDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    Text(report.status.displayName)
                        .font(.caption)
                        .foregroundStyle(statusColor(report.status))

                    if report.hasGitHubIssue {
                        Text("GH-\(report.githubIssueNumber)")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if let date = report.updatedAt {
                        Text(Self.timestampFormatter.localizedString(for: date, relativeTo: Date()))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func statusColor(_ status: BugStatus) -> Color {
        switch status {
        case .open: .orange
        case .inProgress: .blue
        case .fixed: .green
        case .closed: .gray
        }
    }

    private func severityColor(_ severity: BugSeverity) -> Color {
        switch severity {
        case .low: .gray
        case .medium: .orange
        case .high: .red
        }
    }

    @ViewBuilder
    private func listPreview(for content: String) -> some View {
        let items = ListItem.parse(content)
        let unchecked = items.filter { !$0.isChecked }
        let checked = items.filter(\.isChecked).count
        let total = items.count

        VStack(alignment: .leading, spacing: 2) {
            ForEach(unchecked.prefix(3)) { item in
                HStack(spacing: 4) {
                    Image(systemName: "circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(item.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if unchecked.count > 3 {
                Text("+\(unchecked.count - 3) more")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if checked > 0 {
                Text("\(checked)/\(total) done")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
}
