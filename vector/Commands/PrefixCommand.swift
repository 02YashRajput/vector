import Foundation
import AppKit
import Combine

// MARK: - Prefix Type

enum PrefixType: String, Codable, CaseIterable {
    case url = "url"
    case app = "app"
    case script = "script"

    var displayName: String {
        switch self {
        case .url: return "URL"
        case .app: return "Application"
        case .script: return "Script"
        }
    }

    var iconName: String {
        switch self {
        case .url: return "globe"
        case .app: return "app.fill"
        case .script: return "terminal.fill"
        }
    }
}

// MARK: - Prefix Action

enum PrefixAction: Codable {
    case url(template: String, browserBundleId: String?)
    case application(bundleIdentifier: String, name: String, url: URL)
    case script(scriptId: UUID)

    var type: PrefixType {
        switch self {
        case .url: return .url
        case .application: return .app
        case .script: return .script
        }
    }

    var displayName: String {
        switch self {
        case .url(let template, _): return template
        case .application(_, let name, _): return name
        case .script(let scriptId):
            return ScriptManager.shared.getScript(byId: scriptId)?.name ?? "Unknown Script"
        }
    }

    // Custom Codable

    enum CodingKeys: String, CodingKey {
        case type, template, browserBundleId, bundleIdentifier, name, url, scriptId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "url":
            let template = try container.decode(String.self, forKey: .template)
            let browserBundleId = try container.decodeIfPresent(String.self, forKey: .browserBundleId)
            self = .url(template: template, browserBundleId: browserBundleId)
        case "application":
            let bundleId = try container.decode(String.self, forKey: .bundleIdentifier)
            let name = try container.decode(String.self, forKey: .name)
            let url = try container.decode(URL.self, forKey: .url)
            self = .application(bundleIdentifier: bundleId, name: name, url: url)
        case "script":
            let scriptId = try container.decode(UUID.self, forKey: .scriptId)
            self = .script(scriptId: scriptId)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown prefix action type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .url(let template, let browserBundleId):
            try container.encode("url", forKey: .type)
            try container.encode(template, forKey: .template)
            try container.encodeIfPresent(browserBundleId, forKey: .browserBundleId)
        case .application(let bundleId, let name, let url):
            try container.encode("application", forKey: .type)
            try container.encode(bundleId, forKey: .bundleIdentifier)
            try container.encode(name, forKey: .name)
            try container.encode(url, forKey: .url)
        case .script(let scriptId):
            try container.encode("script", forKey: .type)
            try container.encode(scriptId, forKey: .scriptId)
        }
    }
}

// MARK: - Prefix Item

struct PrefixItem: Codable, Identifiable {
    let id: UUID
    var name: String
    var keyword: String
    var action: PrefixAction
    var useProjectSuggestions: Bool

    init(id: UUID = UUID(), name: String, keyword: String, action: PrefixAction, useProjectSuggestions: Bool = false) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.action = action
        self.useProjectSuggestions = useProjectSuggestions
    }
}

extension PrefixItem: Hashable {
    static func == (lhs: PrefixItem, rhs: PrefixItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Prefix Manager

class PrefixManager: ObservableObject {
    static let shared = PrefixManager()

    @Published var prefixes: [PrefixItem] = []

    private let userDefaultsKey = "saved_prefixes"

    private init() {
        loadPrefixes()
    }

    func loadPrefixes() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([PrefixItem].self, from: data) else {
            return
        }
        prefixes = decoded
    }

    func savePrefixes() {
        guard let data = try? JSONEncoder().encode(prefixes) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    func addPrefix(_ prefix: PrefixItem) {
        prefixes.append(prefix)
        savePrefixes()
        registerPrefix(prefix)
    }

    func updatePrefix(_ prefix: PrefixItem) {
        if let index = prefixes.firstIndex(where: { $0.id == prefix.id }) {
            prefixes[index] = prefix
            savePrefixes()
            CommandRegistry.shared.reregisterPrefixes()
        }
    }

    func deletePrefix(_ prefix: PrefixItem) {
        HotkeyManager.shared.remove(name: "prefix.\(prefix.id.uuidString)")
        prefixes.removeAll { $0.id == prefix.id }
        savePrefixes()
        CommandRegistry.shared.reregisterPrefixes()
    }

    func registerAllPrefixes() {
        for prefix in prefixes {
            registerPrefix(prefix)
        }
    }

    private func registerPrefix(_ prefix: PrefixItem) {
        let command = PrefixCommand(prefix: prefix)
        CommandRegistry.shared.register(command)
    }

    func getPrefix(byId id: UUID) -> PrefixItem? {
        prefixes.first { $0.id == id }
    }
}

// MARK: - Prefix Command

final class PrefixCommand: BaseCommand {
    let prefixItem: PrefixItem

    init(prefix: PrefixItem) {
        self.prefixItem = prefix

        let icon: NSImage?
        switch prefix.action {
        case .url:
            icon = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        case .application(_, _, let appURL):
            icon = NSWorkspace.shared.icon(forFile: appURL.path)
        case .script:
            icon = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: nil)
        }

        super.init(
            id: "prefix.\(prefix.id.uuidString)",
            title: prefix.name,
            subtitle: "\(prefix.keyword): → \(prefix.action.displayName)",
            icon: icon,
            type: .prefix,
            acceptsArguments: true
        )
    }

    override func execute(withArgument argument: String) {
        let query = argument.trimmingCharacters(in: .whitespaces)

        switch prefixItem.action {
        case .url(let template, let browserBundleId):
            executeURL(template: template, query: query, browserBundleId: browserBundleId)
        case .application(_, _, let appURL):
            executeApplication(url: appURL, query: query)
        case .script(let scriptId):
            executeScript(scriptId: scriptId, query: query)
        }
    }

    private func executeURL(template: String, query: String, browserBundleId: String?) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = template.replacingOccurrences(of: "{query}", with: encoded)

        guard let url = URL(string: urlString) else {
            print("Invalid prefix URL: \(urlString)")
            return
        }

        let bundleId = browserBundleId ?? UserDefaults.standard.string(forKey: "preferred_browser")

        if let bundleId = bundleId,
           let browserURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.open([url], withApplicationAt: browserURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    private func executeApplication(url: URL, query: String) {
        if !query.isEmpty {
            let fileURL = URL(fileURLWithPath: query)
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([fileURL], withApplicationAt: url, configuration: config) { _, error in
                if let error = error {
                    print("Failed to open with application: \(error)")
                }
            }
        } else {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error = error {
                    print("Failed to launch application: \(error)")
                }
            }
        }
    }

    private func executeScript(scriptId: UUID, query: String) {
        guard let script = ScriptManager.shared.getScript(byId: scriptId) else {
            print("Script not found for prefix: \(scriptId)")
            return
        }
        let command = ScriptCommand(script: script)
        command.execute(withArgument: query)
    }
}
