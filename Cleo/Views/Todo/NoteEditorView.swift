import SwiftUI

private struct ListItemRowView: View {
    @Binding var item: ListItem

    var body: some View {
        HStack(spacing: 10) {
            Button {
                item.isChecked.toggle()
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? .green : .secondary)
                    .imageScale(.large)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            TextField("Item", text: $item.text, axis: .vertical)
                .lineLimit(1...10)
                .strikethrough(item.isChecked, color: .secondary)
                .foregroundStyle(item.isChecked ? .secondary : .primary)
        }
    }
}

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let existingNote: TodoNote?
    let onSave: (String, String, Bool) -> Void

    @State private var title: String
    @State private var isList: Bool
    @State private var content: String
    @State private var listItems: [ListItem]
    @State private var newItemText = ""
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title, newItem
    }

    private var isNewNote: Bool { existingNote == nil }

    init(existingNote: TodoNote? = nil, onSave: @escaping (String, String, Bool) -> Void) {
        self.existingNote = existingNote
        self.onSave = onSave

        let noteIsList = existingNote?.isList ?? false
        _title = State(initialValue: existingNote?.wrappedTitle ?? "")
        _isList = State(initialValue: noteIsList)

        if noteIsList {
            _content = State(initialValue: "")
            _listItems = State(initialValue: ListItem.parse(existingNote?.wrappedContent ?? ""))
        } else {
            _content = State(initialValue: existingNote?.wrappedContent ?? "")
            _listItems = State(initialValue: [])
        }
    }

    private var contentToSave: String {
        isList ? ListItem.serialize(listItems) : content
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .focused($focusedField, equals: .title)

                    if isNewNote {
                        Picker("Type", selection: $isList) {
                            Label("Note", systemImage: "note.text").tag(false)
                            Label("List", systemImage: "checklist").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if isList {
                    listSection
                } else {
                    noteSection
                }
            }
            .scrollContentBackground(.hidden)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .navigationTitle(isNewNote ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
            .onAppear {
                if isNewNote {
                    focusedField = .title
                }
            }
        }
    }

    // MARK: - Note Mode

    private var noteSection: some View {
        Section("Content") {
            TextEditor(text: $content)
                .frame(minHeight: 200)
        }
    }

    // MARK: - List Mode

    private var listSection: some View {
        Section {
            ForEach($listItems) { $item in
                ListItemRowView(item: $item)
            }
            .onDelete { listItems.remove(atOffsets: $0) }
            .onMove { listItems.move(fromOffsets: $0, toOffset: $1) }

            addItemRow
        } header: {
            HStack {
                Text("Items")
                Spacer()
                if listItems.contains(where: \.isChecked) {
                    Button("Clear done") {
                        listItems.removeAll(where: \.isChecked)
                    }
                    .font(.caption)
                    .textCase(nil)
                }
            }
        }
    }

    private var addItemRow: some View {
        HStack(spacing: 10) {
            Button {
                addNewItem()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(newItemText.isEmpty ? Color.secondary : Color.green)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .disabled(newItemText.isEmpty)

            TextField("Add item", text: $newItemText)
                .focused($focusedField, equals: .newItem)
                .onSubmit {
                    addNewItem()
                }
        }
    }

    // MARK: - Actions

    private func save() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            listItems.append(ListItem(text: trimmed, isChecked: false))
            newItemText = ""
        }
        isSaving = true
        onSave(title.trimmingCharacters(in: .whitespacesAndNewlines), contentToSave, isList)
        isSaving = false
        dismiss()
    }

    private func addNewItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        listItems.append(ListItem(text: trimmed, isChecked: false))
        newItemText = ""
        focusedField = .newItem
    }
}
