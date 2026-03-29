import Foundation
import CoreData

@objc(TodoNote)
public class TodoNote: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var content: String?
    @NSManaged public var isList: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?

    var wrappedTitle: String { title ?? "" }
    var wrappedContent: String { content ?? "" }
    var wrappedUpdatedAt: Date { updatedAt ?? Date() }
}

// MARK: - List Item (markdown-based checklist)

struct ListItem: Identifiable {
    let id = UUID()
    var text: String
    var isChecked: Bool

    static func parse(_ content: String) -> [ListItem] {
        let lines = content.components(separatedBy: "\n")
        var items: [ListItem] = []
        for line in lines {
            if line.hasPrefix("- [x] ") {
                items.append(ListItem(text: String(line.dropFirst(6)), isChecked: true))
            } else if line.hasPrefix("- [ ] ") {
                items.append(ListItem(text: String(line.dropFirst(6)), isChecked: false))
            } else if !line.isEmpty {
                items.append(ListItem(text: line, isChecked: false))
            }
        }
        return items
    }

    static func serialize(_ items: [ListItem]) -> String {
        items.map { item in
            item.isChecked ? "- [x] \(item.text)" : "- [ ] \(item.text)"
        }.joined(separator: "\n")
    }
}
