import Foundation
import AppKit

/// Command to launch macOS applications
final class ApplicationCommand: BaseCommand {
    let bundleIdentifier: String
    let url: URL

    init(name: String, bundleIdentifier: String, icon: NSImage?, url: URL) {
        self.bundleIdentifier = bundleIdentifier
        self.url = url
        super.init(
            id: "app.\(bundleIdentifier)",
            title: name,
            subtitle: url.path,
            icon: icon,
            type: .application
        )
    }

    override func execute() {
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error = error {
                print("Failed to launch \(self.title): \(error)")
            }
        }
    }
}
