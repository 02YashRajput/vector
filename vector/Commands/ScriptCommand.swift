import Foundation
import AppKit
import Combine

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
    var scriptPath: String?
    var inlineScript: String?
    var executablePath: String?
    var arguments: String?
    var acceptsQuery: Bool
    var isInternal: Bool

    init(id: UUID = UUID(), name: String, mode: ScriptMode, scriptPath: String? = nil, inlineScript: String? = nil, executablePath: String? = nil, arguments: String? = nil, acceptsQuery: Bool = false, isInternal: Bool = false) {
        self.id = id
        self.name = name
        self.mode = mode
        self.scriptPath = scriptPath
        self.inlineScript = inlineScript
        self.executablePath = executablePath
        self.arguments = arguments
        self.acceptsQuery = acceptsQuery
        self.isInternal = isInternal
    }

    func subtitle(showAcceptsHint: Bool = false) -> String {
        let base: String
        switch mode {
        case .scriptFile:
            base = scriptPath ?? ""
        case .inlineScript:
            let lines = inlineScript?.components(separatedBy: .newlines) ?? []
            base = lines.first ?? "Inline script"
        case .command:
            let args = arguments ?? ""
            base = "\(executablePath ?? "") \(args)".trimmingCharacters(in: .whitespaces)
        }
        if showAcceptsHint && base.isEmpty {
            return "Accepts arguments"
        }
        return base
    }
}

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
        if script.isInternal {
            return
        }
        let command = ScriptCommand(script: script)
        CommandRegistry.shared.register(command)
    }

    func getScript(byId id: UUID) -> ScriptItem? {
        scripts.first { $0.id == id }
    }

    func getCommand(forScriptId id: UUID) -> ScriptCommand? {
        CommandRegistry.shared.getCommand(byId: "script.\(id.uuidString)") as? ScriptCommand
    }
}

final class ScriptCommand: BaseCommand {
    let scriptItem: ScriptItem

    init(script: ScriptItem) {
        self.scriptItem = script
        super.init(
            id: "script.\(script.id.uuidString)",
            title: script.name,
            subtitle: script.subtitle(showAcceptsHint: script.acceptsQuery),
            icon: NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: nil),
            type: .script,
            acceptsArguments: script.acceptsQuery
        )
    }

    override func execute(withArgument argument: String) {
        let args = scriptItem.acceptsQuery ? parseArguments(argument) : []
        executeScript(arguments: args, completion: nil)
    }

    func execute(withArgument argument: String, completion: @escaping (Result<String, Error>) -> Void) {
        let args = scriptItem.acceptsQuery ? parseArguments(argument) : []
        executeScript(arguments: args, completion: completion)
    }

    private func executeScript(arguments: [String], completion: ((Result<String, Error>) -> Void)?) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        switch scriptItem.mode {
        case .scriptFile:
            guard let path = scriptItem.scriptPath else {
                completion?(.failure(NSError(domain: "ScriptCommand", code: 1, userInfo: [NSLocalizedDescriptionKey: "No script path"])))
                return
            }
            var args = ["-l", path]
            args.append(contentsOf: arguments)
            task.arguments = args

        case .inlineScript:
            guard let script = scriptItem.inlineScript else {
                completion?(.failure(NSError(domain: "ScriptCommand", code: 1, userInfo: [NSLocalizedDescriptionKey: "No inline script"])))
                return
            }
            var args = ["-l", "-c", script]
            if !arguments.isEmpty {
                args.append(contentsOf: arguments)
            }
            task.arguments = args

        case .command:
            guard let executable = scriptItem.executablePath else {
                completion?(.failure(NSError(domain: "ScriptCommand", code: 1, userInfo: [NSLocalizedDescriptionKey: "No executable path"])))
                return
            }
            var command = executable
            if let existingArgs = scriptItem.arguments, !existingArgs.isEmpty {
                let parsedArgs = parseArguments(existingArgs)
                command += " " + parsedArgs.joined(separator: " ")
            }
            if !arguments.isEmpty {
                command += " " + arguments.joined(separator: " ")
            }
            task.arguments = ["-l", "-c", command]
        }

        if let completion = completion {
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    completion(.success(output))
                }
            }
        }

        do {
            try task.run()
        } catch {
            if let completion = completion {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } else {
                print("Failed to execute script: \(error)")
            }
        }
    }

    private func parseArguments(_ input: String) -> [String] {
        var args: [String] = []
        var current = ""
        var inQuotes = false
        var quoteChar: Character?

        for char in input {
            switch char {
            case "\"", "'", "`":
                if inQuotes {
                    if char == quoteChar {
                        inQuotes = false
                        quoteChar = nil
                    } else {
                        current.append(char)
                    }
                } else {
                    inQuotes = true
                    quoteChar = char
                }

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
