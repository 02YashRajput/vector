import SwiftUI

struct SearchPage: View {
    @Binding var page: Page
    @FocusState private var isSearchFocused: Bool
    @State private var escMonitor: Any?
    @State private var clickOutsideMonitor: Any?
    @State private var searchText: String = ""
    @StateObject private var panelManager = PanelManager.shared

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(.secondary)
            TextField("Search…", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 20))
                .frame(height: 36)
                .padding(.horizontal, 4)
                .focused($isSearchFocused)
            Spacer(minLength: 0)
            Text("esc")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color(.windowBackgroundColor).opacity(0.7))
                .cornerRadius(6)
        }
        .padding(.horizontal, 20)
        .frame(width: 700, height: 60)
        .onAppear {
            RootView.updatePanel(size: NSSize(width: 700, height: 60))

            escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 {
                    PanelManager.shared.hide()
                    return nil
                }
                return event
            }
            clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
                PanelManager.shared.hide()
            }
        }
        .onChange(of: panelManager.isKeyAndVisible) { isKey in
            if isKey {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isSearchFocused = true
                }
            }
        }
        .onDisappear {
            if let monitor = escMonitor {
                NSEvent.removeMonitor(monitor)
                escMonitor = nil
            }
            if let monitor = clickOutsideMonitor {
                NSEvent.removeMonitor(monitor)
                clickOutsideMonitor = nil
            }
        }
    }
}
