import Foundation
import AppKit
import Combine

// MARK: - Open Method

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

extension ProjectOpenMethod {
    enum CodingKeys: String, CodingKey {
        case type, bundleIdentifier, name, url, commandId
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

// MARK: - Project

struct Project: Codable, Identifiable {
    let id: UUID
    var path: String
    var groupId: UUID
    var openMethodOverride: ProjectOpenMethod?
    var active: Bool

    init(id: UUID = UUID(), path: String, groupId: UUID, openMethodOverride: ProjectOpenMethod? = nil, active: Bool = true) {
        self.id = id
        self.path = path
        self.groupId = groupId
        self.openMethodOverride = openMethodOverride
        self.active = active
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

    /// Resolved open method: per-project override or fall back to group default
    func resolvedOpenMethod(fallback: ProjectOpenMethod) -> ProjectOpenMethod {
        openMethodOverride ?? fallback
    }
}

// MARK: - Project Group

struct ProjectGroup: Codable, Identifiable {
    let id: UUID
    var name: String
    var openMethod: ProjectOpenMethod
    var discoveryScriptId: UUID?
    var editable: Bool

    /// True if this is the built-in manual group
    var isManual: Bool { discoveryScriptId == nil }

    init(id: UUID = UUID(), name: String, openMethod: ProjectOpenMethod, discoveryScriptId: UUID? = nil, editable: Bool = true) {
        self.id = id
        self.name = name
        self.openMethod = openMethod
        self.discoveryScriptId = discoveryScriptId
        self.editable = editable
    }
}

// MARK: - Project Manager

class ProjectManager: ObservableObject {
    static let shared = ProjectManager()

    @Published var groups: [ProjectGroup] = []
    @Published var projects: [Project] = []

    private let groupsKey = "saved_project_groups"
    private let projectsKey = "saved_projects_v2"
    private var refreshTimer: Timer?
    private var validationTimer: Timer?

    private let refreshInterval: TimeInterval = 5 * 60
    private let validationInterval: TimeInterval = 5 * 60

    private init() {
        load()
        ensureManualGroup()
    }

    // MARK: - Manual Group

    /// The default "Manual" group — always exists. Lazily created on first access.
    var manualGroup: ProjectGroup {
        groups.first { $0.isManual }!
    }

    private func ensureManualGroup() {
        if !groups.contains(where: { $0.isManual }) {
            let defaultOpenMethod = ProjectOpenMethod.application(
                bundleIdentifier: "com.apple.finder",
                name: "Finder",
                url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
            )
            let group = ProjectGroup(name: "Manual", openMethod: defaultOpenMethod, discoveryScriptId: nil)
            groups.insert(group, at: 0)
            save()
        }
    }

    // MARK: - Persistence

    func load() {
        if let data = UserDefaults.standard.data(forKey: groupsKey),
           let decoded = try? JSONDecoder().decode([ProjectGroup].self, from: data) {
            groups = decoded
        }
        if let data = UserDefaults.standard.data(forKey: projectsKey),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            projects = decoded
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: groupsKey)
        }
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: projectsKey)
        }
    }

    // MARK: - Periodic Timers

    func startPeriodicTimers() {
        stopPeriodicTimers()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .utility).async {
                self?.refreshScriptGroups()
            }
        }

        validationTimer = Timer.scheduledTimer(withTimeInterval: validationInterval, repeats: true) { [weak self] _ in
            self?.validateProjectPaths()
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.refreshScriptGroups()
        }
        validateProjectPaths()
    }

    func stopPeriodicTimers() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        validationTimer?.invalidate()
        validationTimer = nil
    }

    /// Validates all project paths: deactivates missing ones, reactivates restored ones.
    func validateProjectPaths() {
        var changed = false
        for i in projects.indices {
            let pathExists = projects[i].exists
            if projects[i].active && !pathExists {
                projects[i].active = false
                changed = true
            } else if !projects[i].active && pathExists {
                projects[i].active = true
                changed = true
            }
        }
        guard changed else { return }

        DispatchQueue.main.async {
            self.save()
            CommandRegistry.shared.reregisterProjects()
        }
    }

    // MARK: - Group CRUD

    func addGroup(_ group: ProjectGroup) {
        groups.append(group)
        save()
    }

    func updateGroup(_ group: ProjectGroup) {
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[index] = group
        save()
        CommandRegistry.shared.reregisterProjects()
    }

    func deleteGroup(_ group: ProjectGroup) {
        guard !group.isManual else { return }
        projects.removeAll { $0.groupId == group.id }
        groups.removeAll { $0.id == group.id }

        if let scriptId = group.discoveryScriptId,
           let script = ScriptManager.shared.getScript(byId: scriptId),
           script.isInternal {
            ScriptManager.shared.deleteScript(script)
        }

        save()
        CommandRegistry.shared.reregisterProjects()
    }

    func getGroup(byId id: UUID) -> ProjectGroup? {
        groups.first { $0.id == id }
    }

    // MARK: - Project CRUD

    func projects(inGroup groupId: UUID) -> [Project] {
        projects.filter { $0.groupId == groupId }
    }

    func addProject(_ project: Project) -> Bool {
        guard project.exists && project.isDirectory else { return false }

        if let existingIndex = projects.firstIndex(where: { $0.path == project.path }) {
            projects[existingIndex] = project
        } else {
            projects.append(project)
        }

        save()
        registerProject(project)
        return true
    }

    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        save()
        CommandRegistry.shared.reregisterProjects()
    }

    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            save()
            CommandRegistry.shared.reregisterProjects()
        }
    }

    func getProject(byId id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    func getProject(byPath path: String) -> Project? {
        projects.first { $0.path == path }
    }

    // MARK: - Registration

    func registerAllProjects() {
        for project in projects where project.active {
            registerProject(project)
        }
    }

    private func registerProject(_ project: Project) {
        guard let group = getGroup(byId: project.groupId) else { return }
        let openMethod = project.resolvedOpenMethod(fallback: group.openMethod)
        let command = ProjectCommand(project: project, openMethod: openMethod)
        CommandRegistry.shared.register(command)
    }

    // MARK: - Script Group Refresh

    func refreshScriptGroups() {
        let scriptGroups = groups.filter { $0.discoveryScriptId != nil }
        guard !scriptGroups.isEmpty else { return }

        var allResults: [(UUID, [String])] = []

        for group in scriptGroups {
            guard let scriptId = group.discoveryScriptId,
                  let script = ScriptManager.shared.getScript(byId: scriptId) else { continue }

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
            allResults.append((group.id, discoveredPaths))
        }

        DispatchQueue.main.async {
            for (groupId, paths) in allResults {
                let uniquePaths = NSOrderedSet(array: paths).array as! [String]
                let pathSet = Set(uniquePaths)
                let existingPaths = Set(self.projects.map { $0.path })

                // Remove stale projects
                self.projects.removeAll { $0.groupId == groupId && !pathSet.contains($0.path) }

                // Add new projects
                for path in uniquePaths where !existingPaths.contains(path) {
                    let project = Project(path: path, groupId: groupId)
                    if project.exists && project.isDirectory {
                        self.projects.append(project)
                    }
                }
            }

            self.save()
            CommandRegistry.shared.reregisterProjects()
        }
    }

    /// Refresh a single script group by its ID
    func refreshGroup(_ groupId: UUID, completion: ((Bool) -> Void)? = nil) {
        guard let group = getGroup(byId: groupId),
              let scriptId = group.discoveryScriptId,
              let script = ScriptManager.shared.getScript(byId: scriptId) else {
            completion?(false)
            return
        }

        let command = ScriptCommand(script: script)
        command.execute(withArgument: "") { result in
            DispatchQueue.main.async {
                guard case .success(let output) = result else {
                    completion?(false)
                    return
                }

                let paths = output
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && FileManager.default.fileExists(atPath: $0) }

                let uniquePaths = NSOrderedSet(array: paths).array as! [String]
                let pathSet = Set(uniquePaths)
                let existingPaths = Set(self.projects.map { $0.path })

                // Remove stale
                self.projects.removeAll { $0.groupId == groupId && !pathSet.contains($0.path) }

                // Add new (check globally, not just within group)
                for path in uniquePaths where !existingPaths.contains(path) {
                    let project = Project(path: path, groupId: groupId)
                    if project.exists && project.isDirectory {
                        self.projects.append(project)
                    }
                }

                self.save()
                CommandRegistry.shared.reregisterProjects()
                completion?(true)
            }
        }
    }

    // MARK: - Utilities

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

// MARK: - Project Command

final class ProjectCommand: BaseCommand {
    let project: Project
    let openMethod: ProjectOpenMethod

    init(project: Project, openMethod: ProjectOpenMethod) {
        self.project = project
        self.openMethod = openMethod
        let folderIcon: NSImage? = {
            guard let symbol = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil) else { return nil }
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemBlue])
            return symbol.withSymbolConfiguration(config)
        }()

        super.init(
            id: "project.\(project.id.uuidString)",
            title: project.name,
            subtitle: project.path,
            icon: folderIcon,
            type: .project,
            acceptsArguments: false
        )
    }

    override func execute(withArgument argument: String) {
        switch openMethod {
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
