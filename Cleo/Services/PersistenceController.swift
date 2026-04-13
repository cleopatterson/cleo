import CoreData
import CloudKit

/// Core Data stack using NSPersistentCloudKitContainer.
///
/// Three stores:
///   - "Local" config   → Cleo-Local.sqlite, no CloudKit sync (invoices, expenses, etc.)
///   - "Shared" config (private) → Cleo-Shared.sqlite, owner's trust data in CloudKit private DB
///   - "Shared" config (shared)  → Cleo-SharedZone.sqlite, partner's trust data from CloudKit shared DB
class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    /// Store reference for the CloudKit private database (owner's trust data)
    private(set) var privateStore: NSPersistentStore?
    /// Store reference for the CloudKit shared database (partner's trust data)
    private(set) var sharedStore: NSPersistentStore?

    /// Main context — all stores feed into this
    var viewContext: NSManagedObjectContext { container.viewContext }

    /// Context for shared trust entities — same viewContext since both stores
    /// are loaded into the same container. Entity assignment separates them.
    var sharedContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Cleo")

        let baseURL = NSPersistentContainer.defaultDirectoryURL()

        if inMemory {
            let localDesc = NSPersistentStoreDescription()
            localDesc.configuration = "Local"
            localDesc.type = NSInMemoryStoreType
            localDesc.url = URL(fileURLWithPath: "/dev/null/local")

            let sharedDesc = NSPersistentStoreDescription()
            sharedDesc.configuration = "Shared"
            sharedDesc.type = NSInMemoryStoreType
            sharedDesc.url = URL(fileURLWithPath: "/dev/null/shared")

            container.persistentStoreDescriptions = [localDesc, sharedDesc]
        } else {
            // Store 1: Local — existing entities, no CloudKit
            let localDesc = NSPersistentStoreDescription(url: baseURL.appendingPathComponent("Cleo-Local.sqlite"))
            localDesc.configuration = "Local"
            localDesc.cloudKitContainerOptions = nil

            // Store 2: Private — owner's trust data in CloudKit private database
            let privateDesc = NSPersistentStoreDescription(url: baseURL.appendingPathComponent("Cleo-Shared.sqlite"))
            privateDesc.configuration = "Shared"
            let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.wallboard.cleo")
            privateOptions.databaseScope = .private
            privateDesc.cloudKitContainerOptions = privateOptions

            // Store 3: Shared — partner's trust data from CloudKit shared database
            let sharedDesc = NSPersistentStoreDescription(url: baseURL.appendingPathComponent("Cleo-SharedZone.sqlite"))
            sharedDesc.configuration = "Shared"
            let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.wallboard.cleo")
            sharedOptions.databaseScope = .shared
            sharedDesc.cloudKitContainerOptions = sharedOptions

            container.persistentStoreDescriptions = [localDesc, privateDesc, sharedDesc]
        }

        container.loadPersistentStores { [weak self] desc, error in
            if let error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
            // Capture store references by database scope
            if let options = desc.cloudKitContainerOptions {
                switch options.databaseScope {
                case .private:
                    self?.privateStore = desc.url.flatMap { url in
                        self?.container.persistentStoreCoordinator.persistentStore(for: url)
                    }
                case .shared:
                    self?.sharedStore = desc.url.flatMap { url in
                        self?.container.persistentStoreCoordinator.persistentStore(for: url)
                    }
                default:
                    break
                }
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Sharing Helpers

    /// Whether a managed object lives in the shared (participant) store
    func isShared(object: NSManagedObject) -> Bool {
        guard let store = object.objectID.persistentStore else { return false }
        return store == sharedStore
    }

    // MARK: - Save

    func save() {
        let ctx = container.viewContext
        guard ctx.hasChanges else { return }
        do {
            try ctx.save()
        } catch {
            print("Core Data save error: \(error.localizedDescription)")
        }
    }

    func saveShared() {
        save()  // Both stores share the same viewContext
    }

    // MARK: - Business Profile (singleton)

    func getOrCreateBusinessProfile() -> BusinessProfile {
        let request = NSFetchRequest<BusinessProfile>(entityName: "BusinessProfile")
        request.fetchLimit = 1

        if let existing = try? viewContext.fetch(request).first {
            return existing
        }

        let profile = BusinessProfile(context: viewContext)
        profile.id = UUID()
        profile.businessName = ""
        profile.appDisplayName = ""
        profile.brandAccentHex = "#4CAE8D"
        profile.isOnboarded = false
        profile.defaultTaxRate = 0.10
        profile.defaultPaymentTermsDays = 14
        profile.invoicePrefix = "INV"
        profile.nextInvoiceSequence = 1
        try? viewContext.save()
        return profile
    }

    // MARK: - Invoice Number Generation

    func nextInvoiceNumber() -> String {
        let profile = getOrCreateBusinessProfile()
        let seq = profile.nextInvoiceSequence
        let prefix = profile.invoicePrefix.trimmingCharacters(in: .whitespaces)
        let number: String
        if prefix.isEmpty {
            number = String(format: "%05d", seq)
        } else {
            let year = Calendar.current.component(.year, from: Date())
            number = String(format: "%@-%d-%04d", prefix, year, seq)
        }
        profile.nextInvoiceSequence = seq + 1
        try? viewContext.save()
        return number
    }

    func resetInvoiceSequence(to value: Int32 = 1) {
        let profile = getOrCreateBusinessProfile()
        profile.nextInvoiceSequence = value
        save()
    }

    // MARK: - Calendar Events

    func fetchCalendarEvents() -> [CalendarEvent] {
        let request = NSFetchRequest<CalendarEvent>(entityName: "CalendarEvent")
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
        return (try? viewContext.fetch(request)) ?? []
    }

    @discardableResult
    func createCalendarEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        recurrenceFrequency: String? = nil,
        recurrenceEndDate: Date? = nil,
        reminderEnabled: Bool = false,
        isTodo: Bool = false,
        todoEmoji: String? = nil
    ) -> CalendarEvent {
        let event = CalendarEvent(context: viewContext)
        event.id = UUID()
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.location = location
        event.recurrenceFrequencyRaw = recurrenceFrequency
        event.recurrenceEndDate = recurrenceEndDate
        event.reminderEnabled = reminderEnabled
        event.isTodo = isTodo
        event.isCompleted = false
        event.todoEmoji = todoEmoji
        event.createdAt = Date()
        save()
        return event
    }

    func updateCalendarEvent(_ event: CalendarEvent) {
        save()
    }

    func deleteCalendarEvent(_ event: CalendarEvent) {
        viewContext.delete(event)
        save()
    }
}
