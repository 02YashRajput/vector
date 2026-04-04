import SwiftUI
import AppKit
import ServiceManagement

struct SettingsPage: View {
    @Binding var page: Page
    @State private var hotkeyDisplay: String = ""
    @State private var hotkeyModifiers: NSEvent.ModifierFlags = []
    @State private var hotkeyKeyCode: UInt16 = 0
    @State private var isCapturing: Bool = false
    @State private var launchAtStartup: Bool = false
    @State private var keyMonitor: Any?
    @State private var escMonitor: Any?
    @State private var clickOutsideMonitor: Any?
    @State private var showHotkeySaved: Bool = false
    @State private var preferredBrowser: String?
    @State private var installedBrowsers: [(name: String, bundleId: String, icon: NSImage?)] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                BackButton(action: { page = .search })

                Spacer()

                Text("Settings")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                // Balance the back button
                BackButton(action: {})
                    .opacity(0)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(Color(.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Keyboard Shortcut Section
                    SettingsSection(title: "Keyboard Shortcut", icon: "keyboard.fill") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Global Hotkey")
                                    .font(.system(size: 13))

                                Spacer()

                                HStack {
                                    if hotkeyDisplay.isEmpty {
                                        Text("Not set")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 13))
                                    } else {
                                        Text(hotkeyDisplay)
                                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.accentColor.opacity(0.12))
                                            .cornerRadius(6)
                                    }

                                    Button(action: startCapturing) {
                                        Text(isCapturing ? "Press keys..." : "Change")
                                            .font(.system(size: 12, weight: .medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(isCapturing ? Color.accentColor : Color.secondary.opacity(0.2))
                                            .foregroundColor(isCapturing ? .white : .primary)
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.cursor)
                                }
                            }
                            .padding(12)
                            .background(Color(.windowBackgroundColor).opacity(0.5))
                            .cornerRadius(8)

                            Text("Press modifier keys (Cmd, Ctrl, Alt, Shift) plus a key to set your global shortcut.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            if showHotkeySaved {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Hotkey saved")
                                        .font(.system(size: 11))
                                        .foregroundColor(.green)
                                }
                                .transition(.opacity)
                            }
                        }
                    }

                    // Startup Section
                    SettingsSection(title: "Startup", icon: "bolt.fill") {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Launch at Login")
                                    .font(.system(size: 13))
                                Text("Automatically start Vector when you log in")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: $launchAtStartup)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .onChange(of: launchAtStartup) { _, newValue in
                                    setLaunchAtLogin(enabled: newValue)
                                    UserDefaults.standard.set(newValue, forKey: "launch_at_startup")
                                }
                        }
                        .padding(12)
                        .background(Color(.windowBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }

                    // Browser Section
                    SettingsSection(title: "Browser", icon: "globe") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Preferred Browser")
                                    .font(.system(size: 13))

                                Spacer()

                                Menu {
                                    Button(action: {
                                        preferredBrowser = nil
                                        UserDefaults.standard.removeObject(forKey: "preferred_browser")
                                    }) {
                                        HStack {
                                            Text("Default (System)")
                                            if preferredBrowser == nil {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }

                                    Divider()

                                    ForEach(installedBrowsers, id: \.bundleId) { browser in
                                        Button(action: {
                                            preferredBrowser = browser.bundleId
                                            UserDefaults.standard.set(browser.bundleId, forKey: "preferred_browser")
                                        }) {
                                            HStack {
                                                if let icon = browser.icon {
                                                    Image(nsImage: icon)
                                                }
                                                Text(browser.name)
                                                if preferredBrowser == browser.bundleId {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        if let browser = installedBrowsers.first(where: { $0.bundleId == preferredBrowser }) {
                                            if let icon = browser.icon {
                                                Image(nsImage: icon)
                                                    .resizable()
                                                    .frame(width: 18, height: 18)
                                            }
                                            Text(browser.name)
                                                .font(.system(size: 13))
                                        } else {
                                            Text("Default")
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                                        }

                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.windowBackgroundColor).opacity(0.8))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .menuStyle(.borderlessButton)
                                .menuIndicator(.hidden)
                            }
                            .padding(12)
                            .background(Color(.windowBackgroundColor).opacity(0.5))
                            .cornerRadius(8)

                            Text("Choose which browser opens web searches. Default uses your system default browser.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    // About Section
                    SettingsSection(title: "About", icon: "info.circle.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "bolt.horizontal.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.accentColor)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Vector")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Version 1.0.0")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Divider()

                            Text("A keyboard-first command launcher for macOS. Search apps, run scripts, open URLs, and more—all without touching your mouse.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color(.windowBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }



  
             
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
        }
        .frame(width: 700, height: 500)
        .onAppear {
            loadCurrentSettings()

            escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 && !isCapturing {
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
            stopCapturing()
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

    private func loadCurrentSettings() {
        // Load hotkey config
        if let hotkeyConfig = UserDefaults.standard.dictionary(forKey: "hotkey_config"),
           let display = hotkeyConfig["display"] as? String,
           let keycode = hotkeyConfig["keycode"] as? Int,
           let modifiers = hotkeyConfig["modifiers"] as? Int {
            hotkeyDisplay = display
            hotkeyKeyCode = UInt16(keycode)
            hotkeyModifiers = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        }

        // Load launch at startup
        launchAtStartup = UserDefaults.standard.bool(forKey: "launch_at_startup")

        // Load preferred browser
        preferredBrowser = UserDefaults.standard.string(forKey: "preferred_browser")

        // Load installed browsers
        loadInstalledBrowsers()
    }

    private func loadInstalledBrowsers() {
        guard let url = URL(string: "http://example.com"),
              let apps = LSCopyApplicationURLsForURL(url as CFURL, .all)?.takeRetainedValue() as? [URL] else {
            installedBrowsers = []
            return
        }

        var browsers: [(name: String, bundleId: String, icon: NSImage?)] = []

        for appURL in apps {
            // Get bundle identifier
            guard let bundle = Bundle(url: appURL),
                  let bundleId = bundle.bundleIdentifier else { continue }

            // Get display name from bundle, fallback to URL filename
            let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? appURL.deletingPathExtension().lastPathComponent

            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 18, height: 18)

            browsers.append((name: name, bundleId: bundleId, icon: icon))
        }

        // Sort alphabetically
        browsers.sort { $0.name < $1.name }
        installedBrowsers = browsers
    }

    private func startCapturing() {
        isCapturing = true
        showHotkeySaved = false
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                return nil
            }
            if event.type == .keyDown {
                // ESC cancels capturing
                if event.keyCode == 53 {
                    stopCapturing()
                    return nil
                }

                let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])

                guard !modifiers.isEmpty else { return nil }

                hotkeyModifiers = modifiers
                hotkeyKeyCode = event.keyCode
                hotkeyDisplay = HotkeyUtils.buildHotkeyString(modifiers: modifiers, keyCode: hotkeyKeyCode, separator: " + ")

                saveHotkey()
                stopCapturing()
                return nil
            }
            return nil
        }
    }

    private func stopCapturing() {
        isCapturing = false
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func saveHotkey() {
        // Unregister old hotkey
        HotkeyManager.shared.unregister()

        // Register new hotkey
        HotkeyManager.shared.register(keyCode: UInt32(hotkeyKeyCode), modifiers: hotkeyModifiers)

        // Save to UserDefaults
        let hotkeyConfig: [String: Any] = [
            "display": hotkeyDisplay,
            "keycode": Int(hotkeyKeyCode),
            "modifiers": Int(hotkeyModifiers.rawValue)
        ]
        UserDefaults.standard.set(hotkeyConfig, forKey: "hotkey_config")

        // Show saved indicator
        withAnimation {
            showHotkeySaved = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showHotkeySaved = false
            }
        }
    }

    private func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "register" : "unregister") launch at login: \(error)")
            }
        }
    }

    private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "is_onboarding_complete")
        page = .onboarding
    }
}

// MARK: - Settings Section View
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }

            content
        }
    }
}

#Preview {
    SettingsPage(page: .constant(.settings))
}
