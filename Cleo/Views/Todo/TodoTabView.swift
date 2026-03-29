import SwiftUI

struct TodoTabView: View {
    @Bindable var viewModel: TodoViewModel
    @Binding var showingProfile: Bool
    @Bindable var theme: ThemeManager
    @State private var noteToDelete: TodoNote?

    private static let timestampFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.notes.isEmpty {
                        VStack(spacing: 8) {
                            Text("No notes yet")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.3))
                            Text("Tap + to create your first note.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.2))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else {
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
                                    Button(role: .destructive) {
                                        noteToDelete = note
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
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
                    Text("To Do")
                        .font(.system(.headline, design: .serif))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.editingNote = nil
                        viewModel.showingNoteEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .confirmationDialog(
                "Delete \"\(noteToDelete?.wrappedTitle ?? "")\"?",
                isPresented: Binding(
                    get: { noteToDelete != nil },
                    set: { if !$0 { noteToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let note = noteToDelete {
                        viewModel.deleteNote(note)
                        noteToDelete = nil
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
            }
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
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
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
