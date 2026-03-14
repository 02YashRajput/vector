import SwiftUI
import AppKit

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
            Text("ESC")
                .font(.system(size: 14))
        }
        .foregroundColor(.accentColor)
        .contentShape(Rectangle())
        .onTapGesture { action() }
        .onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

#Preview {
    BackButton(action: {})
}
