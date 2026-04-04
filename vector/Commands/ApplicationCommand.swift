import Foundation
import AppKit
import Combine

struct Application: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let icon: NSImage?
    let url: URL

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }

    static func == (lhs: Application, rhs: Application) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}

final class ApplicationManager: ObservableObject {
    static let shared = ApplicationManager()

    @Published var apps: [Application] = []

    private var refreshTimer: Timer?

    /// Interval for rescanning installed applications (5 minutes)
    private let refreshInterval: TimeInterval = 5 * 60

    private init() {
        loadApps()
    }

    // MARK: - Periodic Timer

    func startPeriodicTimer() {
        stopPeriodicTimer()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refreshApps()
        }

        // Also run once immediately
        refreshApps()
    }

    func stopPeriodicTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refreshApps() {
        let oldIdentifiers = Set(apps.map { $0.bundleIdentifier })
        loadApps()
        let newIdentifiers = Set(apps.map { $0.bundleIdentifier })

        if oldIdentifiers != newIdentifiers {
            CommandRegistry.shared.reregisterApplications()
        }
    }

    func loadApps() {
        var foundApps: Set<Application> = []

        let fileManager = FileManager.default

        let searchPaths: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        for path in searchPaths {
            guard fileManager.fileExists(atPath: path.path) else { continue }

            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: path,
                    includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey],
                    options: .skipsHiddenFiles
                )

                for url in contents {
                    if url.pathExtension == "app" {
                        if let app = createApp(from: url) {
                            foundApps.insert(app)
                        }
                    }
                }
            } catch {
                print("Error reading directory at \(path): \(error)")
            }
        }

        apps = foundApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func registerAllApplications() {
        for app in apps {
            let cmd = ApplicationCommand(
                name: app.name,
                bundleIdentifier: app.bundleIdentifier,
                icon: app.icon,
                url: app.url
            )
            CommandRegistry.shared.register(cmd)
        }
    }

    private func createApp(from url: URL) -> Application? {
        guard let bundle = Bundle(url: url) else { return nil }

        let bundleIdentifier = bundle.bundleIdentifier ?? url.lastPathComponent
        let infoPlist = bundle.infoDictionary

        let name = infoPlist?["CFBundleDisplayName"] as? String
            ?? infoPlist?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent

        var icon: NSImage? = nil
        if let iconName = infoPlist?["CFBundleIconName"] as? String {
            icon = bundle.image(forResource: iconName)
        } else if let iconFile = infoPlist?["CFBundleIconFile"] as? String {
            let iconPath = iconFile.hasSuffix(".icns") ? iconFile : iconFile + ".icns"
            icon = NSImage(contentsOf: bundle.resourceURL?.appendingPathComponent(iconPath) ?? url)
        }

        if icon == nil {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        }

        return Application(name: name, bundleIdentifier: bundleIdentifier, icon: icon, url: url)
    }
}

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

    override func execute(withArgument argument: String) {
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error = error {
                print("Failed to launch \(self.title): \(error)")
            }
        }
    }
}
