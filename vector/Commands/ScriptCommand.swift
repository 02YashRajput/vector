import Foundation
import AppKit

import Foundation
import AppKit

/// Command to execute bash scripts directly
final class ScriptCommand: BaseCommand {
    let scriptContent: String

    init(name: String, script: String, icon: NSImage? = nil) {
        self.scriptContent = script

        super.init(
            id: "script.\(name.lowercased().replacingOccurrences(of: " ", with: "_"))",
            title: name,
            subtitle: "Run script",
            icon: icon,
            type: .script
        )
    }

    override func execute() {
        runScript(scriptContent)
    }

    fileprivate func runScript(_ script: String) {
        do {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".sh")

            try script.write(to: tempURL, atomically: true, encoding: .utf8)

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [tempURL.path]

            try task.run()

        } catch {
            print("Failed to execute script: \(error)")
        }
    }
}
final class DynamicScriptCommand: BaseCommand {
    let scriptContent: String
    let query: String

    init(name: String, script: String, query: String, icon: NSImage? = nil) {
        self.scriptContent = script
        self.query = query

        super.init(
            id: "script.\(name.lowercased().replacingOccurrences(of: " ", with: "_")).\(query.lowercased().replacingOccurrences(of: " ", with: "_"))",
            title: "\(name): \(query)",
            subtitle: "Run script with '\(query)'",
            icon: icon,
            type: .script
        )
    }

    override func execute() {
        do {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".sh")

            try scriptContent.write(to: tempURL, atomically: true, encoding: .utf8)

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [tempURL.path, query]

            try task.run()

        } catch {
            print("Failed to execute script: \(error)")
        }
    }
}