import AppKit
import SwiftUI
import Combine

final class PanelManager: ObservableObject {
    static let shared = PanelManager()

    private(set) var panel: FloatingPanel?
    @Published var isKeyAndVisible = false
    /// nil means show all commands; a CommandType value filters to that type only
    @Published var commandTypeFilter: CommandType? = nil

    private init() {}

    func setup() {
        let panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 700, height: 400))

        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true

        let hostingView = NSHostingView(rootView: RootView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        visualEffect.addSubview(hostingView)
        panel.contentView = visualEffect

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])

        self.panel = panel
        centerOnScreen(size: NSSize(width: 700, height: 400))
    }

    func show(filterType: CommandType? = nil) {
        guard let panel else { return }

        commandTypeFilter = filterType
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            panel.makeKeyAndOrderFront(self)
            self.isKeyAndVisible = true
        }
    }

    func hide() {
        guard let panel else { return }
        panel.orderOut(nil)
        isKeyAndVisible = false
        commandTypeFilter = nil
    }

    func toggle(filterType: CommandType? = nil) {
        guard let panel else { return }
        if panel.isVisible {
            hide()
        } else {
            show(filterType: filterType)
        }
    }

    func centerOnScreen(size: NSSize) {
        guard let panel, let screen = NSScreen.main else { return }
        let x = (screen.frame.width - size.width) / 2
        let y = (screen.frame.height - size.height) / 2
        panel.setFrame(
            NSRect(origin: NSPoint(x: x, y: y), size: size),
            display: true,
            animate: true
        )
    }

    func updateSize(width: CGFloat, height: CGFloat) {
        guard let panel else { return }
        var frame = panel.frame
        frame.size = NSSize(width: width, height: height)
        panel.setFrame(frame, display: true, animate: true)
    }
}
