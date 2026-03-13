import Foundation
import AppKit
import SwiftUI

/// Command to navigate to internal Vector app pages
final class AppSettingsCommand: BaseCommand {
    let targetPage: AppPage

    enum AppPage: String {
        case settings = "settings"

        var displayName: String {
            switch self {
            case .settings: return "Settings"
            }
        }

        var subtitle: String {
            switch self {
            case .settings: return "Open Vector settings"
            }
        }

        var iconName: String {
            switch self {
            case .settings: return "gearshape.fill"
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

    override func execute() {
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
