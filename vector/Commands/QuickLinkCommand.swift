import Foundation
import AppKit
import Combine

struct QuickLinkItem: Codable, Identifiable {
    let id: UUID
    var name: String
    var url: String
    /// Optional bundle ID for a specific browser; nil means use the global preferred browser (or system default).
    var browserBundleId: String?

    init(id: UUID = UUID(), name: String, url: String, browserBundleId: String? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.browserBundleId = browserBundleId
    }
}

class QuickLinkManager: ObservableObject {
    static let shared = QuickLinkManager()

    @Published var quickLinks: [QuickLinkItem] = []

    private let userDefaultsKey = "saved_quicklinks"

    private init() {
        loadQuickLinks()
    }

    func loadQuickLinks() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([QuickLinkItem].self, from: data) else {
            return
        }
        quickLinks = decoded
    }

    func saveQuickLinks() {
        guard let data = try? JSONEncoder().encode(quickLinks) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    func addQuickLink(_ link: QuickLinkItem) {
        quickLinks.append(link)
        saveQuickLinks()
        registerQuickLink(link)
    }

    func updateQuickLink(_ link: QuickLinkItem) {
        if let index = quickLinks.firstIndex(where: { $0.id == link.id }) {
            quickLinks[index] = link
            saveQuickLinks()
            CommandRegistry.shared.reregisterQuickLinks()
        }
    }

    func deleteQuickLink(_ link: QuickLinkItem) {
        quickLinks.removeAll { $0.id == link.id }
        saveQuickLinks()
        CommandRegistry.shared.reregisterQuickLinks()
    }

    func registerAllQuickLinks() {
        for link in quickLinks {
            registerQuickLink(link)
        }
    }

    private func registerQuickLink(_ link: QuickLinkItem) {
        let command = QuickLinkCommand(quickLink: link)
        CommandRegistry.shared.register(command)
    }
}

/// Command that opens a user-defined quick link URL in a browser
final class QuickLinkCommand: BaseCommand {
    let quickLink: QuickLinkItem

    init(quickLink: QuickLinkItem) {
        self.quickLink = quickLink
        super.init(
            id: "quicklink.\(quickLink.id.uuidString)",
            title: quickLink.name,
            subtitle: quickLink.url,
            icon: NSImage(systemSymbolName: "link", accessibilityDescription: nil),
            type: .quickLink
        )
    }

    override func execute(withArgument argument: String) {
        guard let url = URL(string: quickLink.url) else {
            print("Invalid quick link URL: \(quickLink.url)")
            return
        }

        // Determine which browser to use:
        // 1. Per-link browser override
        // 2. Global preferred browser from settings
        // 3. System default
        let browserBundleId = quickLink.browserBundleId
            ?? UserDefaults.standard.string(forKey: "preferred_browser")

        if let bundleId = browserBundleId,
           let browserURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.open([url], withApplicationAt: browserURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
