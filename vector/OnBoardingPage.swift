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

    private var isHotkeySet: Bool {
        !hotkeyDisplay.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("Welcome to Vector")
                    .font(.system(size: 26, weight: .bold))

                Text("Your keyboard-powered command launcher")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 36)
            .padding(.bottom, 28)

            VStack(spacing: 12) {
                FeatureRow(icon: "⌘", label: "Instant Access", description: "Open anywhere with your hotkey")
                FeatureRow(icon: "→", label: "Smart Commands", description: "Use prefixes like git:, code:, jira:")
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 28)

            Divider()
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 16) {
                Text("Let's get you set up")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text("Keyboard shortcut")
                            .font(.system(size: 14, weight: .medium))
                        Text("*")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                    }

                    HStack {
                        if hotkeyDisplay.isEmpty {
                            Text("Click to set your hotkey")
                                .foregroundColor(.secondary)
                                .font(.system(size: 15))
                        } else {
                            Text(hotkeyDisplay)
                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                        }
                        Spacer()
                        if isHotkeySet {
                            Button(action: clearHotkey) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.windowBackgroundColor).opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isCapturing ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isCapturing ? 2 : 1)
                    )
                    .onTapGesture {
                        startCapturing()
                    }

                    Text("Include Cmd, Ctrl, Alt, or Shift • e.g., Cmd+Space")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Toggle(isOn: $launchAtStartup) {
                    Text("Launch Vector at startup")
                        .font(.system(size: 14))
                }
                .toggleStyle(.checkbox)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)

            Spacer()

            Button(action: completeOnboarding) {
                HStack {
                    Text("Get Started")
                        .font(.system(size: 16, weight: .semibold))
                    Text("→")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isHotkeySet ? Color.accentColor : Color.gray.opacity(0.3))
                .foregroundColor(isHotkeySet ? .white : .secondary)
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!isHotkeySet)
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
        .frame(width: 700, height: 560)
        .onAppear {
            PanelManager.shared.centerOnScreen(size: NSSize(width: 700, height: 560))
        }
        .onDisappear {
            stopCapturing()
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


struct FeatureRow: View {
    let icon: String
    let label: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
                .background(Color(.windowBackgroundColor).opacity(0.5))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.windowBackgroundColor).opacity(0.3))
        )
    }
}
