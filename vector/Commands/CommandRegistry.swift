import Foundation
import AppKit
import Combine

/// Central registry for all available commands
final class CommandRegistry: ObservableObject {
    static let shared = CommandRegistry()

    @Published private(set) var allCommands: [any Command] = []
    @Published private(set) var aliases: [String: any Command] = [:]

    private var prefixHandlers: [String: PrefixHandler] = [:]

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

    func registerPrefixHandler(_ prefix: String, handler: PrefixHandler) {
        prefixHandlers[prefix.lowercased()] = handler
    }

    // MARK: - Query / Search

    func search(query: String) -> [any Command] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return allCommands
        }

        // Check for prefix syntax: "prefix:query"
        if let colonIndex = trimmed.firstIndex(of: ":") {
            let prefix = String(trimmed[..<colonIndex]).lowercased()
            let queryPart = String(trimmed[trimmed.index(after: colonIndex)...])

            if let handler = prefixHandlers[prefix] {
                return handler.handle(query: queryPart)
            }
        }

        // Check for aliases first
        if let aliasedCommand = aliases[trimmed.lowercased()] {
            return [aliasedCommand]
        }

        // Filter all commands by searchable text
        let lowerQuery = trimmed.lowercased()
        return allCommands.filter { command in
            command.searchableText.contains(lowerQuery) ||
            command.title.lowercased().contains(lowerQuery)
        }
    }

    // MARK: - Batch Registration

    func registerApplications(from appManager: AppManager) {
        for app in appManager.apps {
            let cmd = ApplicationCommand(
                name: app.name,
                bundleIdentifier: app.bundleIdentifier,
                icon: app.icon,
                url: app.url
            )
            register(cmd)
        }
    }
    
}

// MARK: - Prefix Handler Protocol

protocol PrefixHandler {
    func handle(query: String) -> [any Command]
}

// MARK: - Built-in Prefix Handlers

/// Handler for browser-based prefixes (git:, jira:, etc.)
struct BrowserPrefixHandler: PrefixHandler {
    let name: String
    let baseURL: String
    let icon: NSImage?

    func handle(query: String) -> [any Command] {
        guard !query.isEmpty else {
            // Return a placeholder command
            return [BrowserCommand(
                name: "Open \(name)",
                baseURL: baseURL,
                icon: icon
            )]
        }

        return [BrowserCommand(
            name: "\(name): \(query)",
            baseURL: baseURL,
            query: query,
            icon: icon
        )]
    }
}

/// Handler for script-based prefixes
struct ScriptPrefixHandler: PrefixHandler {
    let name: String
    let scriptContent: String
    let icon: NSImage?

    func handle(query: String) -> [any Command] {
        guard !query.isEmpty else {
            // Return a placeholder command to show it's available
            return [ScriptCommand(
                name: "\(name) <query>",
                script: scriptContent,
                icon: icon
            )]
        }

        return [DynamicScriptCommand(
            name: name,
            script: scriptContent,
            query: query,
            icon: icon
        )]
    }
}
