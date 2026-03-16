import Foundation
import AppKit
import Combine

struct AliasItem: Codable, Identifiable {
    let id: UUID
    let commandId: String
    let alias: String

    init(id: UUID = UUID(), commandId: String, alias: String) {
        self.id = id
        self.commandId = commandId
        self.alias = alias
    }
}

class AliasManager: ObservableObject {
    static let shared = AliasManager()

    @Published var aliases: [AliasItem] = []

    private let userDefaultsKey = "saved_aliases"

    private init() {
        loadAliases()
    }

    func loadAliases() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([AliasItem].self, from: data) else {
            return
        }
        aliases = decoded
    }

    func saveAliases() {
        guard let data = try? JSONEncoder().encode(aliases) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    func addAlias(commandId: String, alias: String) -> Bool {
        let trimmedAlias = alias.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmedAlias.isEmpty else { return false }

        if aliases.contains(where: { $0.alias == trimmedAlias }) {
            return false
        }

        let newAlias = AliasItem(commandId: commandId, alias: trimmedAlias)
        aliases.append(newAlias)
        saveAliases()

        registerAlias(newAlias)
        return true
    }

    func deleteAlias(_ alias: AliasItem) {
        aliases.removeAll { $0.id == alias.id }
        saveAliases()

        CommandRegistry.shared.reregisterAliases()
    }

    func registerAllAliases() {
        for alias in aliases {
            registerAlias(alias)
        }
    }

    private func registerAlias(_ alias: AliasItem) {
        let registry = CommandRegistry.shared
        guard let command = registry.allCommands.first(where: { $0.id == alias.commandId }) else { return }
        registry.register(alias: alias.alias, for: command)
    }
}

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

    override func execute(withArgument argument: String) {
        targetCommand.execute(withArgument: argument)
    }
}
