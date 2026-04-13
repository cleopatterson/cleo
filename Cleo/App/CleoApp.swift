import SwiftUI
import CloudKit

@main
struct CleoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let persistence = PersistenceController.shared
    let calendarService = DeviceCalendarService()
    let claudeService = ClaudeAPIService()
    let trustSyncService: TrustSyncService
    @State private var theme = ThemeManager()

    init() {
        trustSyncService = TrustSyncService(persistence: PersistenceController.shared)
        // Seed after onboarding sets the business name — but also try here
        // for existing installs that are already onboarded.
        let profile = PersistenceController.shared.getOrCreateBusinessProfile()
        if profile.isOnboarded {
            DataSeeder.seedIfNeeded(context: PersistenceController.shared.viewContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                calendarService: calendarService,
                claudeService: claudeService,
                persistence: persistence,
                theme: theme,
                trustSyncService: trustSyncService
            )
            .preferredColorScheme(.dark)
            .environment(theme)
            .onAppear {
                let profile = persistence.getOrCreateBusinessProfile()
                theme.loadFromProfile(profile)
                checkForSharedReceipt()
            }
            .onOpenURL { url in
                if url.scheme == "cleo" && url.host == "scan-receipt" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        checkForSharedReceipt()
                    }
                }
            }
            // Handle CloudKit share acceptance (backup path for SwiftUI)
            .onContinueUserActivity(
                "com.apple.cloudsharingd.accept-share"
            ) { activity in
                print("[CloudKit] onContinueUserActivity: accept-share fired")
                guard let metadata = activity.userInfo?["CKShareMetadata"] as? CKShare.Metadata else {
                    print("[CloudKit] onContinueUserActivity: no CKShareMetadata in userInfo")
                    return
                }
                SceneDelegate.acceptShare(metadata)
            }
        }
    }

    private func checkForSharedReceipt() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.wallboard.cleo") else { return }

        let flagURL = containerURL.appendingPathComponent("pending-receipt.flag")
        guard let flagContent = try? String(contentsOf: flagURL, encoding: .utf8) else { return }

        let isPDF = flagContent.trimmingCharacters(in: .whitespacesAndNewlines) == "pdf"
        let filename = isPDF ? "shared-receipt.pdf" : "shared-receipt.jpg"
        let fileURL = containerURL.appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        try? FileManager.default.removeItem(at: flagURL)

        NotificationCenter.default.post(
            name: .sharedReceiptAvailable,
            object: nil,
            userInfo: ["fileURL": fileURL, "isPDF": isPDF]
        )
    }
}

extension Notification.Name {
    static let sharedReceiptAvailable = Notification.Name("sharedReceiptAvailable")
}
