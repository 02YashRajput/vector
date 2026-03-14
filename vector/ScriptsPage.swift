import SwiftUI
import AppKit
import Combine

struct ScriptsPage: View {
    @Binding var page: Page
    @StateObject private var scriptManager = ScriptManager.shared
    @State private var showCreateSheet = false
    @State private var editingScript: ScriptItem?
    @State private var escMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                BackButton(action: { page = .search })

                Spacer()

                Text("Scripts")
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
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(.windowBackgroundColor))

            Divider()

            if scriptManager.scripts.isEmpty {
                // Empty State
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "terminal")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    VStack(spacing: 8) {
                        Text("No Scripts Yet")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Create scripts to automate tasks.\nRun shell scripts, commands, or executables.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Button(action: { showCreateSheet = true }) {
                        Text("Create Your First Script")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // Scripts List
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(scriptManager.scripts) { script in
                            ScriptRowView(script: script) {
                                editingScript = script
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
            ScriptEditorSheet(mode: nil) { script in
                scriptManager.addScript(script)
                showCreateSheet = false
            }
        }
        .sheet(item: $editingScript) { script in
            ScriptEditorSheet(mode: script.mode, editingScript: script) { updatedScript in
                scriptManager.updateScript(updatedScript)
                editingScript = nil
            }
        }
        .onAppear {
            escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // ESC
                    page = .search
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = escMonitor {
                NSEvent.removeMonitor(monitor)
                escMonitor = nil
            }
        }
    }
}

// MARK: - Script Row View
struct ScriptRowView: View {
    let script: ScriptItem
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: script.mode.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(script.name)
                    .font(.system(size: 16, weight: .semibold))

                Text(scriptSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Mode Badge
            Text(script.mode.displayName)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(4)
                .foregroundColor(.secondary)

            // Edit & Delete Buttons
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { ScriptManager.shared.deleteScript(script) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }

    private var scriptSubtitle: String {
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
}

// MARK: - Script Editor Sheet
struct ScriptEditorSheet: View {
    let mode: ScriptMode?
    let editingScript: ScriptItem?
    let onSave: (ScriptItem) -> Void

    @State private var scriptName: String = ""
    @State private var selectedMode: ScriptMode = .inlineScript
    @State private var scriptPath: String = ""
    @State private var inlineScript: String = ""
    @State private var executablePath: String = ""
    @State private var arguments: String = ""

    @Environment(\.dismiss) private var dismiss

    init(mode: ScriptMode?, editingScript: ScriptItem? = nil, onSave: @escaping (ScriptItem) -> Void) {
        self.mode = mode
        self.editingScript = editingScript
        self.onSave = onSave

        if let script = editingScript {
            _scriptName = State(initialValue: script.name)
            _selectedMode = State(initialValue: script.mode)
            _scriptPath = State(initialValue: script.scriptPath ?? "")
            _inlineScript = State(initialValue: script.inlineScript ?? "")
            _executablePath = State(initialValue: script.executablePath ?? "")
            _arguments = State(initialValue: script.arguments ?? "")
        } else {
            _selectedMode = State(initialValue: mode ?? .inlineScript)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(editingScript == nil ? "Create Script" : "Edit Script")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(20)
            .background(Color(.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        TextField("My Script", text: $scriptName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 14))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)
                    }

                    // Mode Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mode")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            ForEach([ScriptMode.scriptFile, .inlineScript, .command], id: \.self) { mode in
                                ModeOptionButton(mode: mode, isSelected: selectedMode == mode) {
                                    selectedMode = mode
                                }
                            }
                        }
                    }

                    // Mode-specific fields
                    switch selectedMode {
                    case .scriptFile:
                        ScriptFileFields(scriptPath: $scriptPath)
                    case .inlineScript:
                        InlineScriptFields(inlineScript: $inlineScript)
                    case .command:
                        CommandFields(executablePath: $executablePath, arguments: $arguments)
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)

                Button(action: saveScript) {
                    Text("Save")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(canSave ? Color.accentColor : Color.gray)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canSave)
            }
            .padding(20)
        }
        .frame(width: 550, height: 550)
    }

    private var canSave: Bool {
        guard !scriptName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }

        switch selectedMode {
        case .scriptFile:
            return !scriptPath.trimmingCharacters(in: .whitespaces).isEmpty
        case .inlineScript:
            return !inlineScript.trimmingCharacters(in: .whitespaces).isEmpty
        case .command:
            return !executablePath.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func saveScript() {
        let script = ScriptItem(
            id: editingScript?.id ?? UUID(),
            name: scriptName.trimmingCharacters(in: .whitespaces),
            mode: selectedMode,
            scriptPath: selectedMode == .scriptFile ? scriptPath.trimmingCharacters(in: .whitespaces) : nil,
            inlineScript: selectedMode == .inlineScript ? inlineScript.trimmingCharacters(in: .whitespaces) : nil,
            executablePath: selectedMode == .command ? executablePath.trimmingCharacters(in: .whitespaces) : nil,
            arguments: selectedMode == .command ? arguments.trimmingCharacters(in: .whitespaces) : nil
        )

        onSave(script)
    }
}

// MARK: - Mode Option Button
struct ModeOptionButton: View {
    let mode: ScriptMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 18))
                Text(mode.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Script File Fields
struct ScriptFileFields: View {
    @Binding var scriptPath: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Script Path")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            HStack {
                TextField("/Users/username/scripts/build.sh", text: $scriptPath)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14, design: .monospaced))

                Button(action: browseScriptFile) {
                    Text("Browse")
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            Text("Full path to the script file. Will be executed with bash.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private func browseScriptFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            scriptPath = url.path
        }
    }
}

// MARK: - Inline Script Fields
struct InlineScriptFields: View {
    @Binding var inlineScript: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Script Content")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            TextEditor(text: $inlineScript)
                .font(.system(size: 13, design: .monospaced))
                .frame(height: 150)
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
                .scrollContentBackground(.hidden)

            Text("Write your bash script. Each line will be executed in order.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Command Fields
struct CommandFields: View {
    @Binding var executablePath: String
    @Binding var arguments: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Executable Path")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack {
                    TextField("/opt/homebrew/bin/node", text: $executablePath)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14, design: .monospaced))

                    Button(action: browseExecutable) {
                        Text("Browse")
                            .font(.system(size: 12))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Arguments (Optional)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                TextField("script.js --port 3000", text: $arguments)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)

                Text("Space-separated arguments passed to the executable. Leave empty if not needed.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func browseExecutable() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            executablePath = url.path
        }
    }
}

#Preview {
    ScriptsPage(page: .constant(.scripts))
}
