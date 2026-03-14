import SwiftUI

struct SearchPage: View {
    @Binding var page: Page
    @FocusState private var isSearchFocused: Bool
    @State private var escMonitor: Any?
    @State private var clickOutsideMonitor: Any?
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @StateObject private var panelManager = PanelManager.shared
    @StateObject private var commandRegistry = CommandRegistry.shared

    private var filteredCommands: [any Command] {
        commandRegistry.search(query: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(.secondary)
                TextField("Search apps, commands...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 20))
                    .frame(height: 36)
                    .padding(.horizontal, 4)
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { oldValue, newValue in
                        selectedIndex = 0
                    }
                Spacer(minLength: 0)
                Text("esc")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color(.windowBackgroundColor).opacity(0.7))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 20)
            .frame(height: 60)

            Divider()
                .padding(.horizontal, 12)

            // Results list
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                            CommandRow(command: command, isSelected: index == selectedIndex)
                                .id(index)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedIndex = index
                                    executeSelectedCommand()
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .id(searchText)
                .onChange(of: selectedIndex) { oldValue, newValue in
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .frame(width: 700, height: 400)
        .onAppear {
            // Initialize commands if empty
            if commandRegistry.allCommands.isEmpty {
                commandRegistry.registerApplications(from: AppManager.shared)
                commandRegistry.registerAppSettings()
                commandRegistry.registerSystemCommands()
                // Load saved aliases
                AliasManager.shared.registerAllAliases()
                // Load saved scripts
                ScriptManager.shared.registerAllScripts()
            }

            // Focus search bar when page appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }

            escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 {
                    PanelManager.shared.hide()
                    return nil
                }
                if handleKeyEvent(event) {
                    return nil
                }
                return event
            }
            clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
                PanelManager.shared.hide()
            }
        }
        .onChange(of: panelManager.isKeyAndVisible) { oldValue, newValue in
            if newValue {
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

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 126: // Up arrow
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return true
        case 125: // Down arrow
            if selectedIndex < filteredCommands.count - 1 {
                selectedIndex += 1
            }
            return true
        case 36: // Return/Enter
            executeSelectedCommand()
            return true
        default:
            return false
        }
    }

    private func executeSelectedCommand() {
        guard !filteredCommands.isEmpty, selectedIndex < filteredCommands.count else { return }

        let command = filteredCommands[selectedIndex]
        command.execute()

        // Don't hide panel for app settings commands (internal navigation)
        if command.type != .appSettings {
            PanelManager.shared.hide()
        }

        searchText = ""
        selectedIndex = 0
    }
}

// MARK: - Command Row View
struct CommandRow: View {
    let command: any Command
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            if let icon = command.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
            } else {
                Image(systemName: command.type.iconName)
                    .font(.system(size: 24))
                    .frame(width: 36, height: 36)
                    .foregroundColor(.accentColor)
            }

            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(.system(size: 16))
                    .lineLimit(1)

                if let subtitle = command.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Type badge
            Text(command.type.displayName)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(8)
    }
}
