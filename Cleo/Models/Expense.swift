import Foundation
import CoreData

enum ExpenseCategory: String, CaseIterable, Codable {
    case software = "Software"
    case equipment = "Equipment"
    case travel = "Travel"
    case advertising = "Advertising"
    case subscriptions = "Subscriptions"
    case materials = "Materials"
    case other = "Other"

    var emoji: String {
        switch self {
        case .software: "💻"
        case .equipment: "🔧"
        case .travel: "✈️"
        case .advertising: "📢"
        case .subscriptions: "🔄"
        case .materials: "📦"
        case .other: "📎"
        }
    }
}

@objc(Expense)
public class Expense: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var amount: Double
    @NSManaged public var categoryRaw: String
    @NSManaged public var date: Date?
    @NSManaged public var note: String?
    @NSManaged public var receiptImagePath: String?
    @NSManaged public var isRecurring: Bool

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}
