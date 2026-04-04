import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app doesn't show in Dock
        NSApp.setActivationPolicy(.accessory)

        PanelManager.shared.setup()
        PanelManager.shared.show()

        HotkeyManager.shared.registerFromDefaults()
        registerLaunchAtLoginFromDefaults()

        // Start periodic project refresh & path validation
        ProjectManager.shared.startPeriodicTimers()

        // Start periodic application refresh
        ApplicationManager.shared.startPeriodicTimer()
    }

    private func registerLaunchAtLoginFromDefaults() {
        let launchAtStartup = UserDefaults.standard.bool(forKey: "launch_at_startup")

        if #available(macOS 13.0, *) {
            do {
                if launchAtStartup {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(launchAtStartup ? "register" : "unregister") launch at login: \(error)")
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            PanelManager.shared.show()
        }
        return true
    }
}
