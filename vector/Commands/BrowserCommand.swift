import Foundation
import AppKit

/// Command to open URLs in browser
final class BrowserCommand: BaseCommand {
    let baseURL: String
    let query: String?

    init(name: String, baseURL: String, query: String? = nil, icon: NSImage? = nil) {
        self.baseURL = baseURL
        self.query = query

        let fullURL = query != nil ? "\(baseURL)\(query!)" : baseURL

        super.init(
            id: "browser.\(baseURL).\(query ?? "")",
            title: name,
            subtitle: fullURL,
            icon: icon,
            type: .browser
        )
    }

    override func execute(withArgument argument: String) {
        var urlString = baseURL

        if let query = query {
            // URL encode the query
            if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                urlString += encodedQuery
            } else {
                urlString += query
            }
        }

        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            return
        }

        // Check if user has set a preferred browser
        if let browserBundleId = UserDefaults.standard.string(forKey: "preferred_browser"),
           let browserURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browserBundleId) {
            NSWorkspace.shared.open([url], withApplicationAt: browserURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        } else {
            // Use default browser
            NSWorkspace.shared.open(url)
        }
    }
}

/// Web search fallback command - uses Google and default browser
final class WebSearchCommand: BaseCommand {
    let query: String
    private static let searchURL = "https://google.com/search?q="

    init(query: String) {
        self.query = query

        super.init(
            id: "search.\(query)",
            title: "Search for \"\(query)\"",
            subtitle: "Google",
            icon: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil),
            type: .browser
        )
    }

    override func execute(withArgument argument: String) {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = Self.searchURL + encodedQuery

        guard let url = URL(string: urlString) else { return }

        // Check if user has set a preferred browser
        if let browserBundleId = UserDefaults.standard.string(forKey: "preferred_browser"),
           let browserURL = getBrowserURL(bundleId: browserBundleId) {
            NSWorkspace.shared.open([url], withApplicationAt: browserURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        } else {
            // Use default browser
            NSWorkspace.shared.open(url)
        }
    }

    private func getBrowserURL(bundleId: String) -> URL? {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
    }
}
