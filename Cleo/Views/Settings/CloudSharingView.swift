import SwiftUI
import CloudKit
import CoreData

/// Presents UICloudSharingController directly from the UIKit window,
/// avoiding SwiftUI sheet presentation conflicts.
struct CloudSharingButton: View {
    let trustSyncService: TrustSyncService

    var body: some View {
        Button("Invite Partner") {
            presentSharingController()
        }
        .foregroundStyle(.blue)
    }

    private func presentSharingController() {
        let container = PersistenceController.shared.container
        let trustSettings = trustSyncService.getOrCreateSettings()
        let ckContainer = CKContainer(identifier: "iCloud.com.wallboard.cleo")

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first?.rootViewController else {
            print("[CloudSharing] No root view controller found")
            return
        }

        // Find the topmost presented controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        // Check for existing share
        let existingShare: CKShare? = {
            do {
                let shares = try container.fetchShares(matching: [trustSettings.objectID])
                let share = shares[trustSettings.objectID]
                if share != nil { print("[CloudSharing] Found existing share") }
                return share
            } catch {
                print("[CloudSharing] fetchShares error: \(error.localizedDescription)")
                return nil
            }
        }()

        let coordinator = SharingCoordinator()

        if let existingShare {
            let controller = UICloudSharingController(share: existingShare, container: ckContainer)
            controller.delegate = coordinator
            controller.availablePermissions = [.allowReadWrite, .allowPrivate]
            // Retain coordinator for the duration of the presentation
            objc_setAssociatedObject(controller, &SharingCoordinator.key, coordinator, .OBJC_ASSOCIATION_RETAIN)
            topVC.present(controller, animated: true)
        } else {
            let controller = UICloudSharingController { controller, prepareHandler in
                // Ensure record is saved before sharing
                try? container.viewContext.save()

                container.share([trustSettings], to: nil) { _, share, _, error in
                    if let error {
                        print("[CloudSharing] share() error: \(error.localizedDescription)")
                        prepareHandler(nil, nil, error)
                        return
                    }
                    guard let share else {
                        print("[CloudSharing] share() returned nil share without error")
                        prepareHandler(nil, nil, nil)
                        return
                    }
                    share[CKShare.SystemFieldKey.title] = "Cleo Trust Data"
                    print("[CloudSharing] Share created successfully")
                    prepareHandler(share, ckContainer, nil)
                }
            }
            controller.delegate = coordinator
            controller.availablePermissions = [.allowReadWrite, .allowPrivate]
            objc_setAssociatedObject(controller, &SharingCoordinator.key, coordinator, .OBJC_ASSOCIATION_RETAIN)
            topVC.present(controller, animated: true)
        }
    }
}

private class SharingCoordinator: NSObject, UICloudSharingControllerDelegate {
    static var key: UInt8 = 0

    func cloudSharingController(
        _ csc: UICloudSharingController,
        failedToSaveShareWithError error: Error
    ) {
        print("[CloudSharing] Save failed: \(error.localizedDescription)")
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        "Cleo Trust Data"
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        print("[CloudSharing] Share saved successfully")
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        print("[CloudSharing] Sharing stopped")
    }
}
