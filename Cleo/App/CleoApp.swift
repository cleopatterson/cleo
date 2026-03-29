import SwiftUI

@main
struct CleoApp: App {
    let persistence = PersistenceController.shared
    let calendarService = DeviceCalendarService()
    let claudeService = ClaudeAPIService()
    @State private var theme = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView(
                calendarService: calendarService,
                claudeService: claudeService,
                persistence: persistence,
                theme: theme
            )
            .preferredColorScheme(.dark)
            .onAppear {
                let profile = persistence.getOrCreateBusinessProfile()
                theme.loadFromProfile(profile)
                TabAccent.activeTheme = theme
                checkForSharedReceipt()
            }
            .onOpenURL { url in
                if url.scheme == "cleo" && url.host == "scan-receipt" {
                    // Small delay to let the app finish launching/foregrounding
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        checkForSharedReceipt()
                    }
                }
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

        // Clean up flag file
        try? FileManager.default.removeItem(at: flagURL)

        // Post notification with the file URL for the main app to pick up
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
