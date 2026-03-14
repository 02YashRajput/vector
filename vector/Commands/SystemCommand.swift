import Foundation
import AppKit
import IOKit.pwr_mgt

/// System-level commands (sleep, restart, shutdown, etc.)
final class SystemCommand: BaseCommand {

    enum Action: CaseIterable {
        case sleep
        case restart
        case shutdown
        case emptyTrash
        case logout
        case displaySleep

        var title: String {
            switch self {
            case .sleep: return "Sleep"
            case .restart: return "Restart"
            case .shutdown: return "Shut Down"
            case .emptyTrash: return "Empty Trash"
            case .logout: return "Log Out"
            case .displaySleep: return "Turn Off Display"
            }
        }

        var iconName: String {
            switch self {
            case .sleep: return "moon.fill"
            case .restart: return "arrow.clockwise"
            case .shutdown: return "power"
            case .emptyTrash: return "trash.fill"
            case .logout: return "rectangle.portrait.and.arrow.right.fill"
            case .displaySleep: return "sun.min.fill"
            }
        }
    }

    let action: Action

    init(action: Action) {
        self.action = action
        super.init(
            id: "system.\(action.title.lowercased().replacingOccurrences(of: " ", with: "_"))",
            title: action.title,
            subtitle: "System Command",
            icon: nil,
            type: .system
        )
    }

    // MARK: - Execute

    override func execute() {
        switch action {
        case .sleep:
            putToSleep()

        case .displaySleep:
            putDisplayToSleep()

        case .restart:
            restart()

        case .shutdown:
            shutdown()

        case .emptyTrash:
            emptyTrash()

        case .logout:
            logout()
        }
    }

    // MARK: - Actions

    private func putToSleep() {
        // Try IOKit first (most reliable)
        let result = IOPMSleepSystem(IOPMFindPowerManagement(mach_port_t(MACH_PORT_NULL)))
        if result != kIOReturnSuccess {
            // Fallback to pmset command (works without sandbox)
            runProcess(executable: "/usr/bin/pmset", arguments: ["sleepnow"])
        }
    }

    private func putDisplayToSleep() {
        // Use pmset to sleep just the display
        runProcess(executable: "/usr/bin/pmset", arguments: ["displaysleepnow"])
    }

    private func restart() {
        // Use osascript for graceful restart with user confirmation dialog
        runProcess(executable: "/usr/bin/osascript", arguments: [
            "-e", "tell application \"System Events\" to restart"
        ])
    }

    private func shutdown() {
        // Use osascript for graceful shutdown
        runProcess(executable: "/usr/bin/osascript", arguments: [
            "-e", "tell application \"System Events\" to shut down"
        ])
    }

    private func logout() {
        // Use osascript to log out current user
        runProcess(executable: "/usr/bin/osascript", arguments: [
            "-e", "tell application \"System Events\" to log out"
        ])
    }

    private func emptyTrash() {
        // Use AppleScript to empty trash with confirmation
        runProcess(executable: "/usr/bin/osascript", arguments: [
            "-e", "tell application \"Finder\" to empty trash"
        ])
    }

    // MARK: - Helpers

    private func runProcess(executable: String, arguments: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: executable)
            task.arguments = arguments

            do {
                try task.run()
            } catch {
                print("Failed to run \(executable): \(error)")
            }
        }
    }
}
