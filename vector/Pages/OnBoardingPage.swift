import SwiftUI
import AppKit
import Carbon.HIToolbox
import ServiceManagement

struct OnBoardingPage: View {
    @Binding var page: Page
    @State private var hotkeyDisplay: String = ""
    @State private var hotkeyModifiers: NSEvent.ModifierFlags = []
    @State private var hotkeyKeyCode: UInt16 = 0
    @State private var isCapturing: Bool = false
    @State private var launchAtStartup: Bool = true
    @State private var keyMonitor: Any?
    @State private var clickOutsideMonitor: Any?

    private var isHotkeySet: Bool {
        !hotkeyDisplay.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hero section
            VStack(spacing: 8) {
                Image(systemName: "bolt.horizontal.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
                    .padding(.bottom, 4)

                Text("Welcome to Vector")
                    .font(.system(size: 28, weight: .bold))

                Text("Your keyboard-powered command launcher")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            // Feature highlights
            HStack(spacing: 12) {
                FeatureRow(icon: "command", label: "Instant Access", description: "Open anywhere with your hotkey")
                FeatureRow(icon: "arrow.right", label: "Smart Commands", description: "Use prefixes like git:, code:, jira:")
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)

            Divider()
                .padding(.horizontal, 32)

            // Setup section
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("Let's get you set up")
                        .font(.system(size: 16, weight: .semibold))
                }

                // Hotkey input
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("Keyboard shortcut")
                            .font(.system(size: 13, weight: .medium))
                        Text("*")
                            .foregroundColor(.red)
                            .font(.system(size: 13))
                    }

                    HStack {
                        if hotkeyDisplay.isEmpty {
                            Text(isCapturing ? "Press your shortcut…" : "Click to set your hotkey")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        } else {
                            Text(hotkeyDisplay)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.12))
                                .cornerRadius(6)
                        }
                        Spacer()
                        if isHotkeySet {
                            Button(action: clearHotkey) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.cursor)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.windowBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isCapturing ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isCapturing ? 2 : 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        startCapturing()
                    }

                    Text("Include Cmd, Ctrl, Alt, or Shift • e.g., Cmd+Space")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                // Launch at startup toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at startup")
                            .font(.system(size: 13))
                        Text("Automatically start Vector when you log in")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $launchAtStartup)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .padding(12)
                .background(Color(.windowBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)

            Spacer()

            // CTA button
            Button(action: completeOnboarding) {
                HStack(spacing: 8) {
                    Text("Get Started")
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(isHotkeySet ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundColor(isHotkeySet ? .white : .secondary)
                .cornerRadius(8)
            }
            .buttonStyle(.cursor)
            .disabled(!isHotkeySet)
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
        }
        .frame(width: 700, height: 560)
        .onAppear {
            clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
                PanelManager.shared.hide()
            }
        }
        .onDisappear {
            stopCapturing()
            if let monitor = clickOutsideMonitor {
                NSEvent.removeMonitor(monitor)
                clickOutsideMonitor = nil
            }
        }
    }

    private func startCapturing() {
        isCapturing = true
        hotkeyDisplay = ""
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                return nil
            }
            if event.type == .keyDown {
                let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])

                guard !modifiers.isEmpty else { return nil }

                hotkeyModifiers = modifiers
                hotkeyKeyCode = event.keyCode
                hotkeyDisplay = buildHotkeyString(modifiers: modifiers, keyCode: event.keyCode)
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

    private func clearHotkey() {
        hotkeyDisplay = ""
        hotkeyModifiers = []
        hotkeyKeyCode = 0
    }

    private func buildHotkeyString(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> String {
        return HotkeyUtils.buildHotkeyString(modifiers: modifiers, keyCode: keyCode, separator: " + ")
    }


    private func completeOnboarding() {
        registerHotkey()

        setLaunchAtLogin(enabled: launchAtStartup)

        let hotkeyConfig: [String: Any] = [
            "display": hotkeyDisplay,
            "keycode": Int(hotkeyKeyCode),
            "modifiers": Int(hotkeyModifiers.rawValue)
        ]
        UserDefaults.standard.set(hotkeyConfig, forKey: "hotkey_config")
        UserDefaults.standard.set(launchAtStartup, forKey: "launch_at_startup")
        UserDefaults.standard.set(true, forKey: "is_onboarding_complete")

        page = .search
    }

    private func registerHotkey() {
        HotkeyManager.shared.register(keyCode: UInt32(hotkeyKeyCode), modifiers: hotkeyModifiers)
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
}


// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let label: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.windowBackgroundColor).opacity(0.5))
        )
    }
}
