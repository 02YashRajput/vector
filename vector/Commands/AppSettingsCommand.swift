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

        var displayName: String {
            switch self {
            case .settings: return "Settings"
            case .aliases: return "Aliases"
            case .scripts: return "Scripts and Commands"
            case .projects: return "Projects"
            }
        }

        var subtitle: String {
            switch self {
            case .settings: return "Open Vector settings"
            case .aliases: return "Create command shortcuts"
            case .scripts: return "Run shell scripts and commands"
            case .projects: return "Quick access to your projects"
            }
        }

        var iconName: String {
            switch self {
            case .settings: return "gearshape.fill"
            case .aliases: return "arrow.forward.circle.fill"
            case .scripts: return "terminal.fill"
            case .projects: return "folder.fill"
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
