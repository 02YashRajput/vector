import Foundation
import AppKit
import Combine

/// Central registry for all available commands
final class CommandRegistry: ObservableObject {
    static let shared = CommandRegistry()

    @Published private(set) var allCommands: [any Command] = []
    @Published private(set) var aliases: [String: any Command] = [:]

    private init() {}

    // MARK: - Registration

    func register(_ command: any Command) {
        if !allCommands.contains(where: { $0.id == command.id }) {
            allCommands.append(command)
        }
    }

    func register(alias: String, for command: any Command) {
        aliases[alias.lowercased()] = command
        let aliasCmd = AliasCommand(aliasName: alias, target: command)
        register(aliasCmd)
    }

    // MARK: - Query / Search

    func getCommand(byId id: String) -> (any Command)? {
        allCommands.first { $0.id == id }
    }

    func search(query: String) -> [any Command] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return allCommands
        }

        var results: [any Command] = []
        var addedIds = Set<String>()

        // Check for alias match first - add alias command
        if let aliasedCommand = aliases[trimmed.lowercased()] {
            results.append(aliasedCommand)
            addedIds.insert(aliasedCommand.id)
        }

        // Filter all commands by searchable text (including the original command)
        let lowerQuery = trimmed.lowercased()
        for command in allCommands {
            if addedIds.contains(command.id) { continue }

            if command.searchableText.contains(lowerQuery) ||
               command.title.lowercased().contains(lowerQuery) {
                results.append(command)
                addedIds.insert(command.id)
            }
        }

        // Always append web search command at the end
        let webSearchCommand = WebSearchCommand(query: trimmed)
        results.append(webSearchCommand)

        return results
    }

    // MARK: - Batch Registration

    func registerApplications() {
        ApplicationManager.shared.registerAllApplications()
    }

    func registerAppSettings() {
        let settingsCommand = AppSettingsCommand(page: .settings)
        register(settingsCommand)

        let aliasesCommand = AppSettingsCommand(page: .aliases)
        register(aliasesCommand)

        let scriptsCommand = AppSettingsCommand(page: .scripts)
        register(scriptsCommand)

        let projectsCommand = AppSettingsCommand(page: .projects)
        register(projectsCommand)
    }

    func registerSystemCommands() {
        let actions: [SystemCommand.Action] = [.sleep, .restart, .shutdown, .emptyTrash, .displaySleep]
        for action in actions {
            let command = SystemCommand(action: action)
            register(command)
        }
    }

    func reregisterAliases() {
        // Remove all existing alias commands
        allCommands.removeAll { $0.type == .alias }
        aliases.removeAll()

        // Re-register from AliasManager
        AliasManager.shared.registerAllAliases()
    }

    func reregisterScripts() {
        allCommands.removeAll { $0.type == .script }
        ScriptManager.shared.registerAllScripts()
    }

    func reregisterProjects() {
        allCommands.removeAll { $0.type == .project }
        ProjectManager.shared.registerAllProjects()
    }

    func reregisterApplications() {
        allCommands.removeAll { $0.type == .application }
        ApplicationManager.shared.registerAllApplications()
    }
}
