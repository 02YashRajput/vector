import Foundation
import AppKit
import Combine

protocol Command: Identifiable, Hashable {
    var id: String { get }
    var title: String { get }
    var subtitle: String? { get }
    var icon: NSImage? { get }
    var type: CommandType { get }

    /// Whether this command accepts dynamic arguments (prefix:query format)
    var acceptsArguments: Bool { get }

    /// Execute the command with an optional argument
    func execute(withArgument argument: String)

    /// Execute the command (default implementation calls execute with empty argument)
    func execute()

    /// Get searchable text for filtering
    var searchableText: String { get }
}

extension Command {
    var searchableText: String { title.lowercased() }
    var acceptsArguments: Bool { false }

    func execute() {
        execute(withArgument: "")
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

enum CommandType: String, CaseIterable {
    case application
    case script
    case browser
    case url
    case system
    case alias
    case appSettings
    case project

    var displayName: String {
        switch self {
        case .application: return "App"
        case .script: return "Script"
        case .browser: return "Search"
        case .url: return "URL"
        case .system: return "System"
        case .alias: return "Alias"
        case .appSettings: return "Settings"
        case .project: return "Project"
        }
    }

    var iconName: String {
        switch self {
        case .application: return "app.fill"
        case .script: return "terminal.fill"
        case .browser: return "globe"
        case .url: return "link"
        case .system: return "gearshape.fill"
        case .alias: return "arrow.forward.circle.fill"
        case .appSettings: return "gearshape.2.fill"
        case .project: return "folder.fill"
        }
    }
}

// MARK: - Base Command Implementation
class BaseCommand: Command, ObservableObject {
    let id: String
    let title: String
    let subtitle: String?
    let icon: NSImage?
    let type: CommandType
    let acceptsArguments: Bool

    init(id: String, title: String, subtitle: String? = nil, icon: NSImage? = nil, type: CommandType, acceptsArguments: Bool = false) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.type = type
        self.acceptsArguments = acceptsArguments
    }

    func execute(withArgument argument: String) {
        // Override in subclasses
    }
}
