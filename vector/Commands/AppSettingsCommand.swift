import Foundation
import AppKit
import SwiftUI

/// Command to navigate to internal Vector app pages
final class AppSettingsCommand: BaseCommand {
    let targetPage: AppPage

    enum AppPage: String {
        case settings = "settings"
        case aliases = "aliases"
        case scripts = "scripts"
        case projects = "projects"
        case quickLinks = "quickLinks"
        case prefixes = "prefixes"

        var displayName: String {
            switch self {
            case .settings: return "Settings"
            case .aliases: return "Aliases"
            case .scripts: return "Scripts and Commands"
            case .projects: return "Projects"
            case .quickLinks: return "Quick Links"
            case .prefixes: return "Prefixes"
            }
        }

        var subtitle: String {
            switch self {
            case .settings: return "Open Vector settings"
            case .aliases: return "Create command shortcuts"
            case .scripts: return "Run shell scripts and commands"
            case .projects: return "Quick access to your projects"
            case .quickLinks: return "Open bookmarked URLs in browser"
            case .prefixes: return "Keyword triggers with input"
            }
        }

        var iconName: String {
            switch self {
            case .settings: return "gearshape.fill"
            case .aliases: return "arrow.forward.circle.fill"
            case .scripts: return "terminal.fill"
            case .projects: return "folder.fill"
            case .quickLinks: return "link"
            case .prefixes: return "text.cursor"
            }
        }
    }

    init(page: AppPage) {
        self.targetPage = page

        super.init(
            id: "app.\(page.rawValue)",
            title: page.displayName,
            subtitle: page.subtitle,
            icon: nil,
            type: .appSettings
        )
    }

    override func execute(withArgument argument: String) {
        // Post notification to change page in RootView
        NotificationCenter.default.post(
            name: .changePage,
            object: nil,
            userInfo: ["page": targetPage.rawValue]
        )
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let changePage = Notification.Name("changePage")
}
