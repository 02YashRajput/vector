import Foundation
import AppKit
import Combine

enum ProjectSource: String, Codable {
    case manual
    case script

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .script: return "Script"
        }
    }
}

enum ProjectOpenMethod: Codable {
    case application(bundleIdentifier: String, name: String, url: URL)
    case scriptCommand(commandId: String)

    var displayName: String {
        switch self {
        case .application(_, let name, _): return name
        case .scriptCommand: return "Script Command"
        }
    }
}

struct Project: Codable, Identifiable {
    let id: UUID
    var path: String
    var source: ProjectSource
    var openMethod: ProjectOpenMethod
    var discoveryScriptId: UUID?

    init(id: UUID = UUID(), path: String, source: ProjectSource, openMethod: ProjectOpenMethod, discoveryScriptId: UUID? = nil) {
        self.id = id
        self.path = path
        self.source = source
        self.openMethod = openMethod
        self.discoveryScriptId = discoveryScriptId
    }

    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    var isDirectory: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}

extension ProjectOpenMethod {
    enum CodingKeys: String, CodingKey {
        case type
        case bundleIdentifier
        case name
        case url
        case commandId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "application":
            let bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
            let name = try container.decode(String.self, forKey: .name)
            let url = try container.decode(URL.self, forKey: .url)
            self = .application(bundleIdentifier: bundleIdentifier, name: name, url: url)
        case "scriptCommand":
            let commandId = try container.decode(String.self, forKey: .commandId)
            self = .scriptCommand(commandId: commandId)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown open method type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .application(let bundleIdentifier, let name, let url):
            try container.encode("application", forKey: .type)
            try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
            try container.encode(name, forKey: .name)
            try container.encode(url, forKey: .url)
        case .scriptCommand(let commandId):
            try container.encode("scriptCommand", forKey: .type)
            try container.encode(commandId, forKey: .commandId)
        }
    }
}

class ProjectManager: ObservableObject {
    static let shared = ProjectManager()

    @Published var projects: [Project] = []

    private let userDefaultsKey = "saved_projects"

    private init() {
        loadProjects()
    }

    func loadProjects() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([Project].self, from: data) else {
            return
        }
        projects = decoded
    }

    func saveProjects() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    func addProject(_ project: Project) -> Bool {
        guard project.exists && project.isDirectory else { return false }

        if let existingIndex = projects.firstIndex(where: { $0.path == project.path }) {
            let existing = projects[existingIndex]
            if existing.source == .manual && project.source == .script {
                return false
            }
            projects[existingIndex] = project
        } else {
            projects.append(project)
        }

        saveProjects()
        registerProject(project)
        return true
    }

    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        saveProjects()
        CommandRegistry.shared.reregisterProjects()
    }

    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            saveProjects()
            CommandRegistry.shared.reregisterProjects()
        }
    }

    func registerAllProjects() {
        for project in projects {
            registerProject(project)
        }
    }

    private func registerProject(_ project: Project) {
        let command = ProjectCommand(project: project)
        CommandRegistry.shared.register(command)
    }

    func getProject(byId id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    func getProject(byPath path: String) -> Project? {
        projects.first { $0.path == path }
    }

    func refreshScriptProjects() {
        var allDiscoveredPaths: Set<String> = []
        var scriptIdsToProcess: [UUID] = []

        for project in projects where project.source == .script && project.discoveryScriptId != nil {
            scriptIdsToProcess.append(project.discoveryScriptId!)
        }

        scriptIdsToProcess = Array(Set(scriptIdsToProcess))

        for scriptId in scriptIdsToProcess {
            guard let script = ScriptManager.shared.getScript(byId: scriptId) else { continue }
            let command = ScriptCommand(script: script)

            let semaphore = DispatchSemaphore(value: 0)
            var discoveredPaths: [String] = []

            command.execute(withArgument: "") { result in
                if case .success(let output) = result {
                    discoveredPaths = output
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty && FileManager.default.fileExists(atPath: $0) }
                }
                semaphore.signal()
            }

            semaphore.wait()

            for path in discoveredPaths {
                allDiscoveredPaths.insert(path)
                if !projects.contains(where: { $0.path == path }) {
                    if let originalProject = projects.first(where: { $0.discoveryScriptId == scriptId }) {
                        let newProject = Project(
                            path: path,
                            source: .script,
                            openMethod: originalProject.openMethod,
                            discoveryScriptId: scriptId
                        )
                        projects.append(newProject)
                    }
                }
            }
        }

        projects.removeAll { project in
            project.source == .script &&
            project.discoveryScriptId != nil &&
            !allDiscoveredPaths.contains(project.path)
        }

        saveProjects()
        CommandRegistry.shared.reregisterProjects()
    }

    static func getApplications(for path: String) -> [(name: String, bundleIdentifier: String, url: URL)] {
        let url = URL(fileURLWithPath: path)
        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: url)

        return appURLs.compactMap { appURL in
            guard let bundle = Bundle(url: appURL),
                  let bundleIdentifier = bundle.bundleIdentifier,
                  let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                             bundle.object(forInfoDictionaryKey: "CFBundleName") as? String else {
                return nil
            }
            return (name: name, bundleIdentifier: bundleIdentifier, url: appURL)
        }
    }
}

final class ProjectCommand: BaseCommand {
    let project: Project

    init(project: Project) {
        self.project = project
        super.init(
            id: "project.\(project.id.uuidString)",
            title: project.name,
            subtitle: project.path,
            icon: NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil),
            type: .project,
            acceptsArguments: false
        )
    }

    override func execute(withArgument argument: String) {
        switch project.openMethod {
        case .application(_, _, let url):
            openWithApplication(url: url)

        case .scriptCommand(let commandId):
            openWithScriptCommand(commandId: commandId)
        }
    }

    private func openWithApplication(url: URL) {
        let folderURL = URL(fileURLWithPath: project.path)
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([folderURL], withApplicationAt: url, configuration: config) { _, error in
            if let error = error {
                print("Failed to open project with application: \(error)")
            }
        }
    }

    private func openWithScriptCommand(commandId: String) {
        guard let command = CommandRegistry.shared.getCommand(byId: commandId) as? ScriptCommand else {
            print("ScriptCommand not found: \(commandId)")
            return
        }

        command.execute(withArgument: project.path, completion: { _ in })
    }
}
