import SwiftUI
import AppKit
import Combine

// MARK: - Script Group Model

private struct ScriptGroup: Identifiable {
    let id: UUID
    let script: ScriptItem?
    let projects: [Project]
}

// MARK: - Projects Page

struct ProjectsPage: View {
    @Binding var page: Page
    @StateObject private var projectManager = ProjectManager.shared
    @StateObject private var scriptManager = ScriptManager.shared
    @State private var showCreateSheet = false
    @State private var editingProject: Project?
    @State private var scriptToEdit: ScriptItem?
    @State private var escMonitor: Any?
    @State private var clickOutsideMonitor: Any?
    @State private var refreshingScriptIds: Set<UUID> = []

    private var manualProjects: [Project] {
        projectManager.projects.filter { $0.source == .manual }
    }

    private var scriptGroups: [ScriptGroup] {
        let scriptProjects = projectManager.projects.filter { $0.source == .script && $0.discoveryScriptId != nil }
        let grouped = Dictionary(grouping: scriptProjects) { $0.discoveryScriptId! }
        return grouped.map { (scriptId, projects) in
            ScriptGroup(
                id: scriptId,
                script: ScriptManager.shared.getScript(byId: scriptId),
                projects: projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            )
        }.sorted { ($0.script?.name ?? "") < ($1.script?.name ?? "") }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                BackButton(action: { page = .search })
                Spacer()
                Text("Projects")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button(action: { showCreateSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("New")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.cursor)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(.windowBackgroundColor))

            Divider()

            if projectManager.projects.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    VStack(spacing: 8) {
                        Text("No Projects Yet")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Add projects manually or discover them\nwith a custom script.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Button(action: { showCreateSheet = true }) {
                        Text("Add Your First Project")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.cursor)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Manual Projects Section
                        if !manualProjects.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ProjectSectionHeader(title: "Manual", icon: "folder.fill", color: .green)

                                VStack(spacing: 6) {
                                    ForEach(manualProjects) { project in
                                        ProjectRow(project: project, onEdit: { editingProject = project })
                                    }
                                }
                            }
                        }

                        // Script Discovery Sections
                        ForEach(scriptGroups) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    ProjectSectionHeader(
                                        title: group.script?.name ?? "Unknown Script",
                                        icon: "terminal",
                                        color: .blue
                                    )

                                    Text("\(group.projects.count)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)

                                    Spacer()

                                    if refreshingScriptIds.contains(group.id) {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Button(action: { refreshScriptGroup(group.id) }) {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.cursor)
                                        .help("Re-run discovery script")
                                    }

                                    if group.script != nil {
                                        Button(action: { scriptToEdit = group.script }) {
                                            Image(systemName: "pencil")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.cursor)
                                        .help("Edit discovery script")
                                    }

                                    Button(action: { deleteScriptGroup(group.id) }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.red.opacity(0.7))
                                    }
                                    .buttonStyle(.cursor)
                                    .help("Remove all projects from this script")
                                }

                                VStack(spacing: 6) {
                                    ForEach(group.projects) { project in
                                        ProjectRow(project: project, onEdit: { editingProject = project })
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(width: 700, height: 500)
        .sheet(isPresented: $showCreateSheet) {
            CreateProjectSheet()
        }
        .sheet(item: $editingProject) { project in
            EditProjectSheet(project: project) { updated in
                projectManager.updateProject(updated)
                editingProject = nil
            }
        }
        .sheet(item: $scriptToEdit) { script in
            ScriptEditorSheet(
                mode: script.mode,
                editingScript: script,
                sheetTitle: "Edit Discovery Script",
                isInternalScript: true,
                allowArgumentsOption: false
            ) { updatedScript in
                ScriptManager.shared.updateScript(updatedScript)
                scriptToEdit = nil
            }
        }
        .onAppear {
            escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 {
                    page = .search
                    return nil
                }
                return event
            }
            clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
                PanelManager.shared.hide()
            }
        }
        .onDisappear {
            if let monitor = escMonitor {
                NSEvent.removeMonitor(monitor)
                escMonitor = nil
            }
            if let monitor = clickOutsideMonitor {
                NSEvent.removeMonitor(monitor)
                clickOutsideMonitor = nil
            }
        }
    }

    private func refreshScriptGroup(_ scriptId: UUID) {
        guard let script = ScriptManager.shared.getScript(byId: scriptId) else { return }
        let command = ScriptCommand(script: script)

        refreshingScriptIds.insert(scriptId)

        command.execute(withArgument: "") { result in
            DispatchQueue.main.async {
                refreshingScriptIds.remove(scriptId)

                guard case .success(let output) = result else { return }

                let paths = output
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && FileManager.default.fileExists(atPath: $0) }

                let pathSet = Set(paths)
                let pm = ProjectManager.shared
                let existing = pm.projects.filter { $0.discoveryScriptId == scriptId }
                let openMethod = existing.first?.openMethod ?? .application(
                    bundleIdentifier: "com.apple.finder",
                    name: "Finder",
                    url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
                )

                // Remove stale projects
                pm.projects.removeAll { $0.discoveryScriptId == scriptId && !pathSet.contains($0.path) }

                // Add new projects
                let existingPaths = Set(pm.projects.map { $0.path })
                for path in paths where !existingPaths.contains(path) {
                    let project = Project(path: path, source: .script, openMethod: openMethod, discoveryScriptId: scriptId)
                    if project.exists && project.isDirectory {
                        pm.projects.append(project)
                    }
                }

                pm.saveProjects()
                CommandRegistry.shared.reregisterProjects()
            }
        }
    }

    private func deleteScriptGroup(_ scriptId: UUID) {
        let pm = ProjectManager.shared
        pm.projects.removeAll { $0.discoveryScriptId == scriptId }
        pm.saveProjects()
        CommandRegistry.shared.reregisterProjects()

        if let script = ScriptManager.shared.getScript(byId: scriptId), script.isInternal {
            ScriptManager.shared.deleteScript(script)
        }
    }
}

// MARK: - Section Header

private struct ProjectSectionHeader: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Project Row

private struct ProjectRow: View {
    let project: Project
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 14, weight: .medium))
                Text(project.path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(project.openMethod.displayName)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)

            HStack(spacing: 6) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.cursor)

                Button(action: { ProjectManager.shared.deleteProject(project) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.cursor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Create Project Sheet

struct CreateProjectSheet: View {
    enum Mode: String, CaseIterable {
        case manual = "Manual"
        case discovery = "Discovery Script"
    }

    enum OpenMethodType: String, CaseIterable {
        case application = "Application"
        case scriptCommand = "Script Command"
    }

    @State private var mode: Mode = .manual

    // Manual
    @State private var path: String = ""

    // Discovery
    @State private var discoveryScriptItem: ScriptItem?
    @State private var showScriptSheet = false
    @State private var isDiscovering = false
    @State private var discoveredPaths: [String] = []

    // Open method (shared)
    @State private var openMethodType: OpenMethodType = .application
    @State private var selectedAppIndex: Int = 0
    @State private var selectedScriptCommandId: String = ""
    @State private var availableApps: [(name: String, bundleIdentifier: String, url: URL)] = []

    @State private var errorMessage: String?
    @State private var successMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Project")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.cursor)
            }
            .padding(20)
            .background(Color(.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Source picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        Picker("", selection: $mode) {
                            ForEach(Mode.allCases, id: \.self) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if mode == .manual {
                        manualSection
                    } else {
                        discoverySection
                    }

                    Divider()

                    openMethodSection

                    if let error = errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                    }

                    if let success = successMessage {
                        Label(success, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.cursor)

                Button(action: save) {
                    Text("Add Project")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(canSave ? Color.accentColor : Color.gray)
                        .cornerRadius(8)
                }
                .buttonStyle(.cursor)
                .disabled(!canSave)
            }
            .padding(20)
        }
        .frame(width: 520, height: 560)
        .sheet(isPresented: $showScriptSheet) {
            ScriptEditorSheet(
                mode: .inlineScript,
                editingScript: discoveryScriptItem,
                sheetTitle: discoveryScriptItem == nil ? "Create Discovery Script" : "Edit Discovery Script",
                isInternalScript: true,
                allowArgumentsOption: false
            ) { script in
                discoveryScriptItem = script
                showScriptSheet = false
                discoverProjects()
            }
        }
        .onChange(of: path) { _ in loadAppsForManual() }
        .onChange(of: mode) { newMode in
            errorMessage = nil
            successMessage = nil
            if newMode == .discovery && discoveryScriptItem == nil {
                showScriptSheet = true
            }
        }
    }

    // MARK: Manual Section

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project Path")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                TextField("/path/to/project", text: $path)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)

                Button("Browse") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        path = url.path
                    }
                }
                .buttonStyle(.cursor)
            }
        }
    }

    // MARK: Discovery Section

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Discovery Script")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            Text("A script that outputs project paths, one per line.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                if let script = discoveryScriptItem {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal")
                            .font(.system(size: 11))
                        Text(script.name)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                    .foregroundColor(.blue)
                }

                Button(discoveryScriptItem == nil ? "Create Script" : "Edit Script") {
                    showScriptSheet = true
                }
                .buttonStyle(.cursor)

                if discoveryScriptItem != nil && !isDiscovering {
                    Button("Re-run") { discoverProjects() }
                        .buttonStyle(.cursor)
                }
            }

            if isDiscovering {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Discovering...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            if !discoveredPaths.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Found \(discoveredPaths.count) project\(discoveredPaths.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)

                    ForEach(discoveredPaths.prefix(5), id: \.self) { p in
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(URL(fileURLWithPath: p).lastPathComponent)
                                .font(.system(size: 11, weight: .medium))
                            Text("- \(p)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    if discoveredPaths.count > 5 {
                        Text("+ \(discoveredPaths.count - 5) more")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }
        }
    }

    // MARK: Open Method Section

    private var openMethodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Open With")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            Picker("", selection: $openMethodType) {
                ForEach(OpenMethodType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            if openMethodType == .application {
                if availableApps.isEmpty {
                    Text(mode == .manual ? "Enter a valid path to see applications" : "Run discovery to see applications")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    Picker("Application", selection: $selectedAppIndex) {
                        ForEach(0..<availableApps.count, id: \.self) { i in
                            Text(availableApps[i].name).tag(i)
                        }
                    }
                    .frame(width: 300)
                }
            } else {
                let dynamicScripts = ScriptManager.shared.scripts.filter { $0.acceptsQuery }
                if dynamicScripts.isEmpty {
                    Text("No script commands with arguments found")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                } else {
                    Picker("Command", selection: $selectedScriptCommandId) {
                        Text("Select...").tag("")
                        ForEach(dynamicScripts) { script in
                            Text(script.name).tag("script.\(script.id.uuidString)")
                        }
                    }
                    .frame(width: 300)
                }
            }
        }
    }

    // MARK: Logic

    private var canSave: Bool {
        if mode == .manual {
            guard !path.isEmpty else { return false }
        } else {
            guard !discoveredPaths.isEmpty else { return false }
        }

        if openMethodType == .application {
            return !availableApps.isEmpty
        } else {
            return !selectedScriptCommandId.isEmpty
        }
    }

    private func loadAppsForManual() {
        guard !path.isEmpty else { availableApps = []; return }
        availableApps = ProjectManager.getApplications(for: path)
        if selectedAppIndex >= availableApps.count { selectedAppIndex = 0 }
    }

    private func loadAppsForPaths(_ paths: [String]) {
        guard !paths.isEmpty else { availableApps = []; return }

        var commonApps: Set<String>?
        var appsByBundleId: [String: (name: String, bundleIdentifier: String, url: URL)] = [:]

        for p in paths {
            let appsForPath = ProjectManager.getApplications(for: p)
            let ids = Set(appsForPath.map { $0.bundleIdentifier })
            for app in appsForPath { appsByBundleId[app.bundleIdentifier] = app }
            commonApps = commonApps == nil ? ids : commonApps!.intersection(ids)
        }

        availableApps = (commonApps ?? []).compactMap { appsByBundleId[$0] }
        if selectedAppIndex >= availableApps.count { selectedAppIndex = 0 }
    }

    private func discoverProjects() {
        guard let script = discoveryScriptItem else { return }
        let command = ScriptCommand(script: script)

        isDiscovering = true
        errorMessage = nil
        successMessage = nil
        discoveredPaths = []

        command.execute(withArgument: "") { result in
            DispatchQueue.main.async {
                isDiscovering = false
                switch result {
                case .success(let output):
                    let paths = output
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty && FileManager.default.fileExists(atPath: $0) }

                    if paths.isEmpty {
                        errorMessage = "No valid paths found in script output"
                    } else {
                        discoveredPaths = paths
                        loadAppsForPaths(paths)
                        successMessage = "Found \(paths.count) project\(paths.count > 1 ? "s" : "")"
                    }
                case .failure(let error):
                    errorMessage = "Script failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func save() {
        let openMethod: ProjectOpenMethod

        if openMethodType == .application {
            guard selectedAppIndex < availableApps.count else { return }
            let app = availableApps[selectedAppIndex]
            openMethod = .application(bundleIdentifier: app.bundleIdentifier, name: app.name, url: app.url)
        } else {
            guard !selectedScriptCommandId.isEmpty else { return }
            openMethod = .scriptCommand(commandId: selectedScriptCommandId)
        }

        if mode == .manual {
            let project = Project(path: path, source: .manual, openMethod: openMethod)
            _ = ProjectManager.shared.addProject(project)
        } else {
            // Save the discovery script if new
            if let script = discoveryScriptItem {
                if ScriptManager.shared.getScript(byId: script.id) == nil {
                    ScriptManager.shared.addScript(script)
                }
            }

            for p in discoveredPaths {
                let project = Project(
                    path: p,
                    source: .script,
                    openMethod: openMethod,
                    discoveryScriptId: discoveryScriptItem?.id
                )
                _ = ProjectManager.shared.addProject(project)
            }
        }

        dismiss()
    }
}

// MARK: - Edit Project Sheet

struct EditProjectSheet: View {
    let project: Project
    let onSave: (Project) -> Void

    enum OpenMethodType: String, CaseIterable {
        case application = "Application"
        case scriptCommand = "Script Command"
    }

    @State private var openMethodType: OpenMethodType
    @State private var selectedAppIndex: Int = 0
    @State private var selectedScriptCommandId: String
    @State private var availableApps: [(name: String, bundleIdentifier: String, url: URL)] = []

    @Environment(\.dismiss) private var dismiss

    init(project: Project, onSave: @escaping (Project) -> Void) {
        self.project = project
        self.onSave = onSave

        switch project.openMethod {
        case .application:
            _openMethodType = State(initialValue: .application)
            _selectedScriptCommandId = State(initialValue: "")
        case .scriptCommand(let commandId):
            _openMethodType = State(initialValue: .scriptCommand)
            _selectedScriptCommandId = State(initialValue: commandId)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Project")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.cursor)
            }
            .padding(20)
            .background(Color(.windowBackgroundColor))

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                // Project info (read-only)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name)
                                .font(.system(size: 16, weight: .semibold))

                            Text(project.source.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(project.source == .manual ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                                .cornerRadius(4)
                                .foregroundColor(project.source == .manual ? .green : .blue)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Path")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text(project.path)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                    }
                }

                Divider()

                // Open method (editable)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Open With")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    Picker("", selection: $openMethodType) {
                        ForEach(OpenMethodType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if openMethodType == .application {
                        if availableApps.isEmpty {
                            Text("No applications found for this path")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        } else {
                            Picker("Application", selection: $selectedAppIndex) {
                                ForEach(0..<availableApps.count, id: \.self) { i in
                                    Text(availableApps[i].name).tag(i)
                                }
                            }
                            .frame(width: 300)
                        }
                    } else {
                        let dynamicScripts = ScriptManager.shared.scripts.filter { $0.acceptsQuery }
                        if dynamicScripts.isEmpty {
                            Text("No script commands with arguments found")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        } else {
                            Picker("Command", selection: $selectedScriptCommandId) {
                                Text("Select...").tag("")
                                ForEach(dynamicScripts) { script in
                                    Text(script.name).tag("script.\(script.id.uuidString)")
                                }
                            }
                            .frame(width: 300)
                        }
                    }
                }
            }
            .padding(20)

            Spacer()

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.cursor)

                Button(action: saveProject) {
                    Text("Save")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(canSave ? Color.accentColor : Color.gray)
                        .cornerRadius(8)
                }
                .buttonStyle(.cursor)
                .disabled(!canSave)
            }
            .padding(20)
        }
        .frame(width: 480, height: 420)
        .onAppear { loadApps() }
    }

    private var canSave: Bool {
        if openMethodType == .application {
            return !availableApps.isEmpty
        } else {
            return !selectedScriptCommandId.isEmpty
        }
    }

    private func loadApps() {
        availableApps = ProjectManager.getApplications(for: project.path)

        // Pre-select current app
        if case .application(let bundleId, _, _) = project.openMethod {
            if let idx = availableApps.firstIndex(where: { $0.bundleIdentifier == bundleId }) {
                selectedAppIndex = idx
            }
        }

        if selectedAppIndex >= availableApps.count { selectedAppIndex = 0 }
    }

    private func saveProject() {
        let openMethod: ProjectOpenMethod

        if openMethodType == .application {
            guard selectedAppIndex < availableApps.count else { return }
            let app = availableApps[selectedAppIndex]
            openMethod = .application(bundleIdentifier: app.bundleIdentifier, name: app.name, url: app.url)
        } else {
            guard !selectedScriptCommandId.isEmpty else { return }
            openMethod = .scriptCommand(commandId: selectedScriptCommandId)
        }

        var updated = project
        updated.openMethod = openMethod
        onSave(updated)
    }
}

extension Project: IdentifiableByHashable {
    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

protocol IdentifiableByHashable: Identifiable, Hashable {}

#Preview {
    ProjectsPage(page: .constant(.projects))
}
