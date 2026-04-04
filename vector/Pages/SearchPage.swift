import SwiftUI

enum SearchMode {
    case normal
    case filtered(CommandType)
    case argument(any Command)

    var isArgument: Bool {
        if case .argument = self { return true }
        return false
    }

    var argumentCommand: (any Command)? {
        if case .argument(let cmd) = self { return cmd }
        return nil
    }

    var filterType: CommandType? {
        if case .filtered(let type) = self { return type }
        return nil
    }
}

struct SearchPage: View {
    @Binding var page: Page
    @FocusState private var isSearchFocused: Bool
    @State private var escMonitor: Any?
    @State private var clickOutsideMonitor: Any?
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @State private var mode: SearchMode = .normal
    @StateObject private var panelManager = PanelManager.shared
    @StateObject private var commandRegistry = CommandRegistry.shared

    private var filteredCommands: [any Command] {
        if mode.isArgument { return [] }
        let results = commandRegistry.search(query: searchText)
        if let filterType = mode.filterType {
            return results.filter { $0.type == filterType }
        }
        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 16) {
                switch mode {
                case .argument(let command):
                    Text("\(command.title):")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.accentColor)
                case .filtered(let filterType):
                    HStack(spacing: 6) {
                        Image(systemName: filterType.iconName)
                            .font(.system(size: 16))
                        Text(filterType.displayName)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(6)
                case .normal:
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(.secondary)
                }

                TextField(searchPlaceholder, text: $searchText)
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

            // Results list or argument mode hint
            if case .argument(let command) = mode {
                VStack(spacing: 12) {
                    Spacer()
                    HStack(spacing: 12) {
                        if let icon = command.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: command.type.iconName)
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(command.title)
                                .font(.system(size: 16, weight: .medium))
                            if let subtitle = command.subtitle {
                                Text(subtitle)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Text("Type your argument and press Enter to execute")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Text("Press Escape to cancel")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.7))

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                                CommandRow(command: command, isSelected: index == selectedIndex)
                                    .id(index)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedIndex = index
                                        handleCommandSelection(command)
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
        }
        .frame(width: 700, height: 400)
        .onAppear {
            if commandRegistry.allCommands.isEmpty {
                commandRegistry.registerApplications()
                commandRegistry.registerAppSettings()
                commandRegistry.registerSystemCommands()
                AliasManager.shared.registerAllAliases()
                ScriptManager.shared.registerAllScripts()
                ProjectManager.shared.registerAllProjects()
                QuickLinkManager.shared.registerAllQuickLinks()
                PrefixManager.shared.registerAllPrefixes()
            }

            // Focus search bar when page appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }

            escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 {
                    switch mode {
                    case .argument:
                        mode = .normal
                        searchText = ""
                    case .filtered:
                        mode = .normal
                        searchText = ""
                        selectedIndex = 0
                    case .normal:
                        PanelManager.shared.hide()
                    }
                    return nil
                }
                if handleKeyEvent(event) {
                    return nil
                }
                return event
            }
            clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
                guard NSApp.modalWindow == nil else { return }
                PanelManager.shared.hide()
            }
        }
        .onChange(of: panelManager.isKeyAndVisible) { oldValue, newValue in
            if newValue {
                searchText = ""
                selectedIndex = 0
                if let prefixCommandId = panelManager.pendingPrefixCommandId,
                   let command = commandRegistry.getCommand(byId: prefixCommandId) {
                    mode = .argument(command)
                    panelManager.pendingPrefixCommandId = nil
                } else if let filter = panelManager.commandTypeFilter {
                    mode = .filtered(filter)
                } else {
                    mode = .normal
                }
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
            if !mode.isArgument && selectedIndex > 0 {
                selectedIndex -= 1
            }
            return true
        case 125: // Down arrow
            if !mode.isArgument && selectedIndex < filteredCommands.count - 1 {
                selectedIndex += 1
            }
            return true
        case 36: // Return/Enter
            if mode.isArgument {
                executeWithArgument()
            } else {
                handleCommandSelection(filteredCommands[selectedIndex])
            }
            return true
        default:
            return false
        }
    }

    private func handleCommandSelection(_ command: any Command) {
        guard !filteredCommands.isEmpty, selectedIndex < filteredCommands.count else { return }

        if command.acceptsArguments {
            mode = .argument(command)
            searchText = ""
        } else {
            command.execute()

            if command.type != .appSettings {
                PanelManager.shared.hide()
            }

            searchText = ""
            selectedIndex = 0
        }
    }

    private func executeWithArgument() {
        guard let command = mode.argumentCommand else { return }

        command.execute(withArgument: searchText.trimmingCharacters(in: .whitespaces))

        mode = .normal
        searchText = ""
        selectedIndex = 0
        PanelManager.shared.hide()
    }

    private var searchPlaceholder: String {
        switch mode {
        case .argument: return "Enter argument..."
        case .filtered(let type): return "Search \(type.displayName.lowercased())s..."
        case .normal: return "Search apps, commands..."
        }
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
                HStack(spacing: 6) {
                    Text(command.title)
                        .font(.system(size: 16))
                        .lineLimit(1)

                    if command.acceptsArguments {
                        Image(systemName: "text.append")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                    }
                }

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
