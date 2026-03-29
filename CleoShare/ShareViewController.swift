import UIKit
import Social
import UniformTypeIdentifiers
import MobileCoreServices

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedItems()
    }

    private func handleSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            close()
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { [weak self] data, error in
                        self?.handleLoadedItem(data, isPDF: true)
                    }
                    return
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] data, error in
                        self?.handleLoadedItem(data, isPDF: false)
                    }
                    return
                }
            }
        }

        close()
    }

    private func handleLoadedItem(_ data: Any?, isPDF: Bool) {
        var fileData: Data?

        if let url = data as? URL {
            fileData = try? Data(contentsOf: url)
        } else if let d = data as? Data {
            fileData = d
        } else if let image = data as? UIImage {
            fileData = image.jpegData(compressionQuality: 0.8)
        }

        guard let fileData else {
            DispatchQueue.main.async { self.close() }
            return
        }

        // Save to App Group shared container
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.wallboard.cleo") {
            let filename = isPDF ? "shared-receipt.pdf" : "shared-receipt.jpg"
            let fileURL = containerURL.appendingPathComponent(filename)
            try? fileData.write(to: fileURL)

            // Write a flag file so the main app knows there's a pending receipt
            let flagURL = containerURL.appendingPathComponent("pending-receipt.flag")
            let flagContent = isPDF ? "pdf" : "image"
            try? flagContent.write(to: flagURL, atomically: true, encoding: .utf8)
        }

        // Open the main app via URL scheme
        DispatchQueue.main.async {
            self.openMainApp()
            self.close()
        }
    }

    private func openMainApp() {
        guard let url = URL(string: "cleo://scan-receipt") else { return }
        var responder: UIResponder? = self
        while let r = responder {
            if let application = r as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = r.next
        }
        // Fallback: use selector-based approach for extensions
        let selector = sel_registerName("openURL:")
        var current: UIResponder? = self
        while let r = current {
            if r.responds(to: selector) {
                r.perform(selector, with: url)
                return
            }
            current = r.next
        }
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
