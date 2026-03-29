import Foundation
import CoreData

@MainActor
@Observable
final class TodoViewModel {
    let persistence: PersistenceController
    let claudeService: ClaudeAPIService

    var showingNoteEditor = false
    var editingNote: TodoNote?
    var notes: [TodoNote] = []
    var briefing: AIBriefingResponse?
    var isLoadingBriefing = false
    @ObservationIgnored private var hasLoadedBriefing = false
    @ObservationIgnored private var briefingTask: Task<Void, Never>?

    init(persistence: PersistenceController, claudeService: ClaudeAPIService) {
        self.persistence = persistence
        self.claudeService = claudeService
        fetchNotes()
    }

    func fetchNotes() {
        let request = NSFetchRequest<TodoNote>(entityName: "TodoNote")
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        notes = (try? persistence.viewContext.fetch(request)) ?? []
    }

    func createNote(title: String, content: String, isList: Bool) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let note = TodoNote(context: persistence.viewContext)
        note.id = UUID()
        note.title = trimmed
        note.content = content
        note.isList = isList
        note.createdAt = Date()
        note.updatedAt = Date()
        persistence.save()
        fetchNotes()
    }

    func updateNote(_ note: TodoNote, title: String, content: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        note.title = trimmed
        note.content = content
        note.updatedAt = Date()
        persistence.save()
        fetchNotes()
    }

    func deleteNote(_ note: TodoNote) {
        persistence.viewContext.delete(note)
        persistence.save()
        fetchNotes()
    }

    // MARK: - Briefing

    var noteCount: Int { notes.count }
    var listCount: Int { notes.filter(\.isList).count }
    var recentCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return notes.filter { ($0.updatedAt ?? .distantPast) > weekAgo }.count
    }

    func loadBriefing() {
        guard !hasLoadedBriefing || briefing == nil else { return }
        guard briefingTask == nil else { return }
        hasLoadedBriefing = true
        isLoadingBriefing = true

        let payload: [String: Any] = [
            "noteCount": noteCount,
            "listCount": listCount,
            "recentlyUpdated": recentCount,
            "titles": notes.prefix(10).compactMap(\.title)
        ]

        briefingTask = Task {
            let result = await claudeService.generateBriefing(tab: .todo, dataPayload: payload)
            briefing = result
            isLoadingBriefing = false
            briefingTask = nil
            if result == nil { hasLoadedBriefing = false }
        }
    }
}
