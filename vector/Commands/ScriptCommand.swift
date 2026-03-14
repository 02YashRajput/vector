import Foundation
import AppKit
import Combine

// MARK: - Script Types

enum ScriptMode: String, Codable {
    case scriptFile = "script_file"
    case inlineScript = "inline_script"
    case command = "command"

    var displayName: String {
        switch self {
        case .scriptFile: return "Script File"
        case .inlineScript: return "Inline Script"
        case .command: return "Command"
        }
    }

    var description: String {
        switch self {
        case .scriptFile: return "Run a script file from a path"
        case .inlineScript: return "Write inline bash script"
        case .command: return "Run a command with arguments"
        }
    }

    var iconName: String {
        switch self {
        case .scriptFile: return "doc.text"
        case .inlineScript: return "terminal.fill"
        case .command: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct ScriptItem: Codable, Identifiable {
    let id: UUID
    var name: String
    var mode: ScriptMode
    var scriptPath: String?        // For scriptFile mode
    var inlineScript: String?      // For inlineScript mode
    var executablePath: String?    // For command mode
    var arguments: String?         // For command mode

    init(id: UUID = UUID(), name: String, mode: ScriptMode, scriptPath: String? = nil, inlineScript: String? = nil, executablePath: String? = nil, arguments: String? = nil) {
        self.id = id
        self.name = name
        self.mode = mode
        self.scriptPath = scriptPath
        self.inlineScript = inlineScript
        self.executablePath = executablePath
        self.arguments = arguments
    }
}

// MARK: - Script Manager

class ScriptManager: ObservableObject {
    static let shared = ScriptManager()

    @Published var scripts: [ScriptItem] = []

    private let userDefaultsKey = "saved_scripts"

    private init() {
        loadScripts()
    }

    func loadScripts() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([ScriptItem].self, from: data) else {
            return
        }
        scripts = decoded
    }

    func saveScripts() {
        guard let data = try? JSONEncoder().encode(scripts) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    func addScript(_ script: ScriptItem) {
        scripts.append(script)
        saveScripts()
        registerScript(script)
    }

    func deleteScript(_ script: ScriptItem) {
        scripts.removeAll { $0.id == script.id }
        saveScripts()
        CommandRegistry.shared.reregisterScripts()
    }

    func updateScript(_ script: ScriptItem) {
        if let index = scripts.firstIndex(where: { $0.id == script.id }) {
            scripts[index] = script
            saveScripts()
            CommandRegistry.shared.reregisterScripts()
        }
    }

    func registerAllScripts() {
        for script in scripts {
            registerScript(script)
        }
    }

    private func registerScript(_ script: ScriptItem) {
        let command = ScriptCommand(script: script)
        CommandRegistry.shared.register(command)
    }
}

// MARK: - Script Command

final class ScriptCommand: BaseCommand {
    let scriptItem: ScriptItem

    init(script: ScriptItem) {
        self.scriptItem = script

        super.init(
            id: "script.\(script.id.uuidString)",
            title: script.name,
            subtitle: Self.scriptSubtitle(for: script),
            icon: NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: nil),
            type: .script
        )
    }

    private static func scriptSubtitle(for script: ScriptItem) -> String {
        switch script.mode {
        case .scriptFile:
            return script.scriptPath ?? ""
        case .inlineScript:
            let lines = script.inlineScript?.components(separatedBy: .newlines) ?? []
            return lines.first ?? "Inline script"
        case .command:
            let args = script.arguments ?? ""
            return "\(script.executablePath ?? "") \(args)".trimmingCharacters(in: .whitespaces)
        }
    }

    override func execute() {
        switch scriptItem.mode {
        case .scriptFile:
            executeScriptFile()
        case .inlineScript:
            executeInlineScript()
        case .command:
            executeCommand()
        }
    }

    private func executeScriptFile() {
        guard let path = scriptItem.scriptPath else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-l", path]

        do {
            try task.run()
        } catch {
            print("Failed to execute script file: \(error)")
        }
    }

    private func executeInlineScript() {
        guard let script = scriptItem.inlineScript else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-l", "-c", script]

        do {
            try task.run()
        } catch {
            print("Failed to execute inline script: \(error)")
        }
    }

    private func executeCommand() {
        guard let executable = scriptItem.executablePath else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)

        if let args = scriptItem.arguments, !args.isEmpty {
            let parsedArgs = parseArguments(args)
            task.arguments = parsedArgs
        }

        do {
            try task.run()
        } catch {
            print("Failed to execute command: \(error)")
        }
    }
    func parseArguments(_ input: String) -> [String] {
        var args: [String] = []
        var current = ""
        var inQuotes = false

        for char in input {
            switch char {
            case "\"":
                inQuotes.toggle()

            case " " where !inQuotes:
                if !current.isEmpty {
                    args.append(current)
                    current = ""
                }

            default:
                current.append(char)
            }
        }

        if !current.isEmpty {
            args.append(current)
        }

        return args
    }
}
