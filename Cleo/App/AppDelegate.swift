import UIKit
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        print("[CloudKit] configurationForConnecting called")
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        print("[CloudKit] SceneDelegate: userDidAcceptCloudKitShareWith called")
        Self.acceptShare(cloudKitShareMetadata)
    }

    static func acceptShare(_ metadata: CKShare.Metadata) {
        guard let sharedStore = PersistenceController.shared.sharedStore else {
            print("[CloudKit] Share acceptance failed: shared store not available")
            return
        }

        print("[CloudKit] Accepting share into shared store...")
        PersistenceController.shared.container.acceptShareInvitations(
            from: [metadata],
            into: sharedStore
        ) { _, error in
            if let error {
                print("[CloudKit] Failed to accept share: \(error.localizedDescription)")
            } else {
                print("[CloudKit] Successfully accepted share!")
            }
        }
    }
}
