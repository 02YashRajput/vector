import SwiftUI
import AppKit

struct CursorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onHover { isHovering in
                if isHovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

extension ButtonStyle where Self == CursorButtonStyle {
    static var cursor: CursorButtonStyle {
        CursorButtonStyle()
    }
}
