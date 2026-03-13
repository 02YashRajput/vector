import AppKit

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.moveToActiveSpace]

        isOpaque = false
        backgroundColor = .clear
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        hasShadow = true

        let movable = UserDefaults.standard.object(forKey: "isMovableByWindowBackground") as? Bool ?? true
        isMovableByWindowBackground = movable

        hidesOnDeactivate = false
    }
}
