import AppKit
import Combine

final class AppManager: ObservableObject {
    static let shared = AppManager()

    @Published var apps: [Application] = []

    private init() {
        loadApps()
    }

    func loadApps() {
        var foundApps: Set<Application> = []

        let fileManager = FileManager.default

        // Common directories where apps are installed
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

        // Sort alphabetically
        apps = foundApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func createApp(from url: URL) -> Application? {
        guard let bundle = Bundle(url: url) else { return nil }

        let bundleIdentifier = bundle.bundleIdentifier ?? url.lastPathComponent
        let infoPlist = bundle.infoDictionary

        // Get app name
        let name = infoPlist?["CFBundleDisplayName"] as? String
            ?? infoPlist?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent

        // Get icon
        var icon: NSImage? = nil
        if let iconName = infoPlist?["CFBundleIconName"] as? String {
            icon = bundle.image(forResource: iconName)
        } else if let iconFile = infoPlist?["CFBundleIconFile"] as? String {
            let iconPath = iconFile.hasSuffix(".icns") ? iconFile : iconFile + ".icns"
            icon = NSImage(contentsOf: bundle.resourceURL?.appendingPathComponent(iconPath) ?? url)
        }

        // Fallback to workspace icon
        if icon == nil {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        }

        return Application(name: name, bundleIdentifier: bundleIdentifier, icon: icon, url: url)
    }

}
