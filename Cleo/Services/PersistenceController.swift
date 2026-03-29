import CoreData

/// Core Data stack using NSPersistentCloudKitContainer for future CloudKit sync (§9.2)
struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Cleo")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
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

    // MARK: - Invoice Number Generation (§4.3)

    func nextInvoiceNumber() -> String {
        let profile = getOrCreateBusinessProfile()
        let seq = profile.nextInvoiceSequence
        let year = Calendar.current.component(.year, from: Date())
        let number = String(format: "%@-%d-%04d", profile.invoicePrefix, year, seq)
        profile.nextInvoiceSequence = seq + 1
        try? viewContext.save()
        return number
    }

    func resetInvoiceSequence(to value: Int32 = 1) {
        let profile = getOrCreateBusinessProfile()
        profile.nextInvoiceSequence = value
        save()
    }

    func save() {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            print("Core Data save error: \(error.localizedDescription)")
        }
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
