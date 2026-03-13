import AppKit
import SwiftUI

final class PanelManager {
    static let shared = PanelManager()

    private(set) var panel: FloatingPanel?

    private init() {}

    func setup() {
        let panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 700, height: 60))

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
        centerOnScreen(size: NSSize(width: 700, height: 60))
    }

    func show() {
        guard let panel else { return }
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard let panel else { return }
        panel.orderOut(nil)
    }

    func toggle() {
        guard let panel else { return }
        if panel.isVisible {
            hide()
        } else {
            show()
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
}
