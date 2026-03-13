import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        PanelManager.shared.setup()
        PanelManager.shared.show()

        HotkeyManager.shared.registerFromDefaults()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            PanelManager.shared.show()
        }
        return true
    }
}
