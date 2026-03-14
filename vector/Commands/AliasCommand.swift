import Foundation
import AppKit

/// Command that acts as an alias/wrapper for another command
final class AliasCommand: BaseCommand {
    let aliasName: String
    let targetCommand: any Command
    let originalTitle: String

    init(aliasName: String, target: any Command) {
        self.aliasName = aliasName
        self.targetCommand = target
        self.originalTitle = target.title

        super.init(
            id: "alias.\(aliasName)",
            title: "\(aliasName) → \(target.title)",
            subtitle: nil,
            icon: target.icon,
            type: .alias
        )
    }

    override func execute() {
        targetCommand.execute()
    }
}
