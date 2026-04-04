import SwiftUI
import AppKit
import Combine

// MARK: - Prefixes Page

struct PrefixesPage: View {
    @Binding var page: Page
    @StateObject private var prefixManager = PrefixManager.shared
    @State private var showCreateSheet = false
    @State private var editingPrefix: PrefixItem?
    @State private var escMonitor: Any?
    @State private var clickOutsideMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                BackButton(action: { page = .search })

                Spacer()

                Text("Prefixes")
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

            if prefixManager.prefixes.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "text.cursor")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    VStack(spacing: 8) {
                        Text("No Prefixes Yet")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Create keyword triggers that accept input\nto open URLs, apps, or run scripts.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Button(action: { showCreateSheet = true }) {
                        Text("Add Your First Prefix")
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
                    LazyVStack(spacing: 8) {
                        ForEach(prefixManager.prefixes) { prefix in
                            PrefixRowView(prefix: prefix) {
                                editingPrefix = prefix
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
            PrefixEditorSheet(editingPrefix: nil) { prefix in
                prefixManager.addPrefix(prefix)
                showCreateSheet = false
            }
        }
        .sheet(item: $editingPrefix) { prefix in
            PrefixEditorSheet(editingPrefix: prefix) { updated in
                prefixManager.updatePrefix(updated)
                editingPrefix = nil
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
                guard NSApp.modalWindow == nil else { return }
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
}

// MARK: - Prefix Row View

private struct PrefixRowView: View {
    let prefix: PrefixItem
    let onEdit: () -> Void

    private var hotkeyDisplay: String? {
        HotkeyManager.shared.loadConfig(name: "prefix.\(prefix.id.uuidString)")?.display
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: prefix.action.type.iconName)
                    .font(.system(size: 22))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(prefix.name)
                        .font(.system(size: 16, weight: .semibold))

                    Text(prefix.keyword)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(4)
                        .foregroundColor(.accentColor)
                }

                Text(prefix.action.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if prefix.useProjectSuggestions {
                        HStack(spacing: 3) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 9))
                            Text("Projects")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.secondary.opacity(0.8))
                    }

                    if let hotkey = hotkeyDisplay {
                        HStack(spacing: 3) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 9))
                            Text(hotkey)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.secondary.opacity(0.8))
                    }
                }
            }

            Spacer()

            Text(prefix.action.type.displayName)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
                .foregroundColor(.secondary)

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.cursor)

            Button(action: { PrefixManager.shared.deletePrefix(prefix) }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.7))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.cursor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - Prefix Editor Sheet

struct PrefixEditorSheet: View {
    let editingPrefix: PrefixItem?
    let onSave: (PrefixItem) -> Void

    @State private var name: String = ""
    @State private var keyword: String = ""
    @State private var selectedType: PrefixType = .url
    @State private var useProjectSuggestions: Bool = false

    // URL fields
    @State private var urlTemplate: String = ""
    @State private var selectedBrowser: String?
    @State private var installedBrowsers: [(name: String, bundleId: String, icon: NSImage?)] = []

    // App fields
    @State private var selectedAppBundleId: String?
    @State private var availableApps: [(name: String, bundleIdentifier: String, url: URL, icon: NSImage?)] = []

    // Script fields
    @State private var selectedScriptId: String?

    // Hotkey fields
    @State private var hotkeyDisplay: String = ""
    @State private var hotkeyModifiers: NSEvent.ModifierFlags = []
    @State private var hotkeyKeyCode: UInt16 = 0
    @State private var isCapturingHotkey: Bool = false
    @State private var hotkeyKeyMonitor: Any?
    @State private var showHotkeySaved: Bool = false

    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { editingPrefix != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Prefix" : "Add Prefix")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.cursor)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.system(size: 13, weight: .medium))

                        TextField("e.g., Google Search", text: $name)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 14))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.windowBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    // Keyword
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keyword")
                            .font(.system(size: 13, weight: .medium))

                        TextField("e.g., g", text: $keyword)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 14, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.windowBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )

                        Text("The trigger keyword shown in search results.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Type Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type")
                            .font(.system(size: 13, weight: .medium))

                        Picker("", selection: $selectedType) {
                            ForEach(PrefixType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Dynamic fields based on type
                    switch selectedType {
                    case .url:
                        urlFields
                    case .app:
                        appFields
                    case .script:
                        scriptFields
                    }

                    Divider()

                    // Project suggestions toggle
                    Toggle(isOn: $useProjectSuggestions) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use project suggestions")
                                .font(.system(size: 13, weight: .medium))
                            Text("Show project paths as suggestions when typing input.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Divider()

                    // Hotkey
                    hotkeySection

                    // Error
                    if let error = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer
            HStack(spacing: 12) {
                Spacer()

                Button("Cancel") { dismiss() }
                    .font(.system(size: 13))
                    .buttonStyle(.cursor)

                Button(action: save) {
                    Text(isEditing ? "Save" : "Add Prefix")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(canSave ? Color.accentColor : Color.secondary.opacity(0.15))
                        .cornerRadius(8)
                }
                .buttonStyle(.cursor)
                .disabled(!canSave)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 520, height: 580)
        .onAppear {
            loadBrowsers()
            loadApps()
            if let prefix = editingPrefix {
                name = prefix.name
                keyword = prefix.keyword
                selectedType = prefix.action.type
                useProjectSuggestions = prefix.useProjectSuggestions
                switch prefix.action {
                case .url(let template, let browserBundleId):
                    urlTemplate = template
                    selectedBrowser = browserBundleId ?? "__default__"
                case .application(let bundleId, _, _):
                    selectedAppBundleId = bundleId
                case .script(let scriptId):
                    selectedScriptId = scriptId.uuidString
                }
                if let config = HotkeyManager.shared.loadConfig(name: "prefix.\(prefix.id.uuidString)") {
                    hotkeyDisplay = config.display
                    hotkeyKeyCode = UInt16(config.keyCode)
                    hotkeyModifiers = NSEvent.ModifierFlags(rawValue: UInt(config.modifiers))
                }
            }
        }
        .onDisappear {
            stopCapturingHotkey()
        }
    }

    // MARK: - URL Fields

    private var urlFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("URL Template")
                    .font(.system(size: 13, weight: .medium))

                TextField("https://google.com/search?q={query}", text: $urlTemplate)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.windowBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                Text("Use {query} as a placeholder for user input.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Open With")
                    .font(.system(size: 13, weight: .medium))

                PopoverPicker(
                    selection: $selectedBrowser,
                    options: [
                        PopoverPickerOption(id: "__default__", label: "Default (from Settings)", systemIcon: "globe")
                    ] + installedBrowsers.map {
                        PopoverPickerOption(id: $0.bundleId, label: $0.name, icon: $0.icon)
                    },
                    placeholder: "Default (from Settings)"
                )
            }
        }
    }

    // MARK: - App Fields

    private var appFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Application")
                .font(.system(size: 13, weight: .medium))

            if availableApps.isEmpty {
                Text("No applications found.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                PopoverPicker(
                    selection: $selectedAppBundleId,
                    options: availableApps.map {
                        PopoverPickerOption(id: $0.bundleIdentifier, label: $0.name, icon: $0.icon)
                    },
                    placeholder: "Select an application..."
                )
            }

            Text("Input will be passed to the selected app as a file path.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Script Fields

    private var scriptFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Script")
                .font(.system(size: 13, weight: .medium))

            let argScripts = ScriptManager.shared.scripts.filter { $0.acceptsQuery }

            if argScripts.isEmpty {
                Text("No scripts with argument support found.\nCreate one in Scripts & Commands first.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                PopoverPicker(
                    selection: $selectedScriptId,
                    options: argScripts.map {
                        PopoverPickerOption(id: $0.id.uuidString, label: $0.name, systemIcon: "terminal.fill")
                    },
                    placeholder: "Select a script..."
                )
            }

            Text("Input will be passed as an argument to the selected script.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Hotkey Section

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hotkey (Optional)")
                .font(.system(size: 13, weight: .medium))

            HStack(spacing: 12) {
                if isCapturingHotkey {
                    Text("Press a key combo...")
                        .font(.system(size: 13))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                        )
                } else if hotkeyDisplay.isEmpty {
                    Button(action: startCapturingHotkey) {
                        HStack(spacing: 6) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 12))
                            Text("Set Hotkey")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.cursor)
                } else {
                    HStack(spacing: 8) {
                        Text(hotkeyDisplay)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )

                        Button(action: startCapturingHotkey) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.cursor)

                        Button(action: clearHotkey) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12))
                                .foregroundColor(.red.opacity(0.7))
                        }
                        .buttonStyle(.cursor)
                    }
                }

                if showHotkeySaved {
                    Text("Saved")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }

            Text("Assign a global hotkey to trigger this prefix directly.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Validation

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              !keyword.trimmingCharacters(in: .whitespaces).isEmpty else { return false }

        switch selectedType {
        case .url:
            return !urlTemplate.trimmingCharacters(in: .whitespaces).isEmpty
        case .app:
            return selectedAppBundleId != nil
        case .script:
            return selectedScriptId != nil
        }
    }

    // MARK: - Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespaces).lowercased()

        guard !trimmedName.isEmpty, !trimmedKeyword.isEmpty else { return }

        let action: PrefixAction
        switch selectedType {
        case .url:
            var template = urlTemplate.trimmingCharacters(in: .whitespaces)
            if !template.contains("://") {
                template = "https://" + template
            }
            let browser = selectedBrowser == "__default__" ? nil : selectedBrowser
            action = .url(template: template, browserBundleId: browser)
        case .app:
            guard let bundleId = selectedAppBundleId,
                  let app = availableApps.first(where: { $0.bundleIdentifier == bundleId }) else { return }
            action = .application(bundleIdentifier: app.bundleIdentifier, name: app.name, url: app.url)
        case .script:
            guard let scriptIdStr = selectedScriptId,
                  let scriptId = UUID(uuidString: scriptIdStr) else { return }
            action = .script(scriptId: scriptId)
        }

        let prefixId = editingPrefix?.id ?? UUID()
        let item = PrefixItem(
            id: prefixId,
            name: trimmedName,
            keyword: trimmedKeyword,
            action: action,
            useProjectSuggestions: useProjectSuggestions
        )

        // Save or clear hotkey
        let hotkeyName = "prefix.\(prefixId.uuidString)"
        if !hotkeyDisplay.isEmpty {
            HotkeyManager.shared.set(
                name: hotkeyName,
                keyCode: hotkeyKeyCode,
                modifiers: hotkeyModifiers,
                display: hotkeyDisplay,
                prefixCommandId: "prefix.\(prefixId.uuidString)"
            )
        } else {
            HotkeyManager.shared.remove(name: hotkeyName)
        }

        onSave(item)
    }

    // MARK: - Hotkey Logic

    private func startCapturingHotkey() {
        isCapturingHotkey = true
        showHotkeySaved = false
        hotkeyKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .flagsChanged { return nil }
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    stopCapturingHotkey()
                    return nil
                }
                let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
                guard !modifiers.isEmpty else { return nil }

                hotkeyModifiers = modifiers
                hotkeyKeyCode = event.keyCode
                hotkeyDisplay = HotkeyUtils.buildHotkeyString(modifiers: modifiers, keyCode: event.keyCode, separator: " + ")

                stopCapturingHotkey()

                withAnimation { showHotkeySaved = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showHotkeySaved = false }
                }
                return nil
            }
            return nil
        }
    }

    private func stopCapturingHotkey() {
        isCapturingHotkey = false
        if let monitor = hotkeyKeyMonitor {
            NSEvent.removeMonitor(monitor)
            hotkeyKeyMonitor = nil
        }
    }

    private func clearHotkey() {
        if let prefix = editingPrefix {
            HotkeyManager.shared.remove(name: "prefix.\(prefix.id.uuidString)")
        }
        hotkeyDisplay = ""
        hotkeyKeyCode = 0
        hotkeyModifiers = []
    }

    // MARK: - Data Loading

    private func loadBrowsers() {
        guard let testURL = URL(string: "https://example.com"),
              let apps = LSCopyApplicationURLsForURL(testURL as CFURL, .all)?.takeRetainedValue() as? [URL] else {
            installedBrowsers = []
            return
        }

        var browsers: [(name: String, bundleId: String, icon: NSImage?)] = []
        for appURL in apps {
            guard let bundle = Bundle(url: appURL),
                  let bundleId = bundle.bundleIdentifier else { continue }
            let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? appURL.deletingPathExtension().lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 18, height: 18)
            browsers.append((name: name, bundleId: bundleId, icon: icon))
        }
        browsers.sort { $0.name < $1.name }
        installedBrowsers = browsers
    }

    private func loadApps() {
        availableApps = ApplicationManager.shared.apps.map {
            let icon = $0.icon
            icon?.size = NSSize(width: 18, height: 18)
            return (name: $0.name, bundleIdentifier: $0.bundleIdentifier, url: $0.url, icon: icon)
        }
    }
}

#Preview {
    PrefixesPage(page: .constant(.prefixes))
}
