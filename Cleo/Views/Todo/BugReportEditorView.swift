import SwiftUI

struct BugReportEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var theme: ThemeManager

    let existingReport: BugReport?
    let onSave: (String, String, BugSeverity) async -> Void

    @State private var title: String
    @State private var description: String
    @State private var severity: BugSeverity
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case title, description }
    private var isNew: Bool { existingReport == nil }

    init(existingReport: BugReport? = nil, theme: ThemeManager, onSave: @escaping (String, String, BugSeverity) async -> Void) {
        self.existingReport = existingReport
        self.theme = theme
        self.onSave = onSave
        _title = State(initialValue: existingReport?.title ?? "")
        _description = State(initialValue: existingReport?.bugDescription ?? "")
        _severity = State(initialValue: existingReport?.severity ?? .medium)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Bug title", text: $title)
                        .focused($focusedField, equals: .title)
                }

                Section("Severity") {
                    Picker("Severity", selection: $severity) {
                        ForEach(BugSeverity.allCases) { sev in
                            Text(sev.displayName).tag(sev)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 120)
                        .focused($focusedField, equals: .description)
                }

                if let report = existingReport {
                    Section("Status") {
                        HStack {
                            Circle()
                                .fill(statusColor(report.status))
                                .frame(width: 8, height: 8)
                            Text(report.status.displayName)
                                .foregroundStyle(.secondary)
                        }

                        if let urlString = report.githubIssueUrl,
                           let url = URL(string: urlString),
                           report.hasGitHubIssue {
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "link")
                                    Text("GH-\(report.githubIssueNumber)")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                }
                            }
                        } else if report.hasGitHubIssue {
                            HStack {
                                Image(systemName: "link")
                                Text("GH-\(report.githubIssueNumber)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .cleoBackground(theme: theme)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .navigationTitle(isNew ? "Report Bug" : "Bug Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if isNew {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit") { save() }
                            .disabled(title.isEmpty || isSaving)
                    }
                }
            }
            .onAppear {
                if isNew { focusedField = .title }
            }
        }
    }

    private func statusColor(_ status: BugStatus) -> Color {
        switch status {
        case .open: .orange
        case .inProgress: .blue
        case .fixed: .green
        case .closed: .gray
        }
    }

    private func save() {
        isSaving = true
        Task {
            await onSave(title.trimmingCharacters(in: .whitespacesAndNewlines), description, severity)
            isSaving = false
            dismiss()
        }
    }
}
