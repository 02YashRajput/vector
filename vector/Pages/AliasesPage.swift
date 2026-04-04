import SwiftUI
import AppKit
import Combine

struct AliasesPage: View {
    @Binding var page: Page
    @StateObject private var aliasManager = AliasManager.shared
    @StateObject private var commandRegistry = CommandRegistry.shared
    @State private var showCreateSheet = false
    @State private var escMonitor: Any?
    @State private var clickOutsideMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                BackButton(action: { page = .search })

                Spacer()

                Text("Aliases")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                Button(action: { showCreateSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("New")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.cursor)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(.windowBackgroundColor))

            Divider()

            if aliasManager.aliases.isEmpty {
                // Empty State
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "arrow.forward.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    VStack(spacing: 8) {
                        Text("No Aliases Yet")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Create aliases to quickly access your favorite commands.\nType the alias in search to launch instantly.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Button(action: { showCreateSheet = true }) {
                        Text("Create Your First Alias")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.cursor)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // Aliases List
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(aliasManager.aliases) { alias in
                            AliasRowView(alias: alias, command: findCommand(for: alias))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(width: 700, height: 500)
        .sheet(isPresented: $showCreateSheet) {
            CreateAliasSheet(
                commandRegistry: commandRegistry,
                onCreate: { commandId, alias in
                    let success = aliasManager.addAlias(commandId: commandId, alias: alias)
                    if success {
                        showCreateSheet = false
                    }
                },
                onDismiss: { showCreateSheet = false }
            )
        }
        .onAppear {
            escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 {
                    page = .search
                    return nil
                }
                return event
            }
            clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
                guard NSApp.modalWindow == nil else { return }
                PanelManager.shared.hide()
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

    private func findCommand(for alias: AliasItem) -> (any Command)? {
        return commandRegistry.allCommands.first { $0.id == alias.commandId }
    }
}

// MARK: - Alias Row View
struct AliasRowView: View {
    let alias: AliasItem
    let command: (any Command)?

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 44, height: 44)

                if let command = command, let icon = command.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(alias.alias)
                        .font(.system(size: 16, weight: .semibold))
                        .fontDesign(.monospaced)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    if let command = command {
                        Text(command.title)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                    } else {
                        Text("Command not found")
                            .font(.system(size: 15))
                            .foregroundColor(.orange)
                    }
                }

                if let command = command {
                    Text(command.type.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Delete Button
            Button(action: { AliasManager.shared.deleteAlias(alias) }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.7))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.cursor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - Create Alias Sheet
struct CreateAliasSheet: View {
    let commandRegistry: CommandRegistry
    let onCreate: (String, String) -> Void
    let onDismiss: () -> Void

    @State private var searchText: String = ""
    @State private var selectedCommandId: String?
    @State private var aliasText: String = ""
    @State private var errorMessage: String?

    private var filteredCommands: [any Command] {
        let commands = commandRegistry.allCommands.filter { $0.type != .alias }
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()

        guard !trimmed.isEmpty else { return Array(commands.prefix(20)) }

        return commands.filter { command in
            command.title.lowercased().contains(trimmed) ||
            command.id.lowercased().contains(trimmed)
        }
    }

    private var selectedCommand: (any Command)? {
        guard let id = selectedCommandId else { return nil }
        return commandRegistry.allCommands.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Alias")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.cursor)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Command Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Command")
                            .font(.system(size: 13, weight: .medium))

                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            TextField("Search commands...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.windowBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )

                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(filteredCommands.prefix(15), id: \.id) { command in
                                    CommandPickerRow(command: command, isSelected: selectedCommandId == command.id) {
                                        selectedCommandId = command.id
                                    }
                                }
                            }
                            .padding(4)
                        }
                        .frame(height: 200)
                        .background(Color(.windowBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    }

                    // Alias Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alias")
                            .font(.system(size: 13, weight: .medium))

                        HStack(spacing: 12) {
                            TextField("e.g., chrome", text: $aliasText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(.windowBackgroundColor).opacity(0.5))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )

                            if let command = selectedCommand {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Text(command.title)
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                            }
                        }

                        Text("Type this alias in search to quickly launch the command")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    // Error Message
                    if let error = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer
            HStack(spacing: 12) {
                Spacer()

                Button("Cancel") {
                    onDismiss()
                }
                .font(.system(size: 13))
                .buttonStyle(.cursor)

                Button(action: createAlias) {
                    Text("Create Alias")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(selectedCommandId != nil && !aliasText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.accentColor : Color.secondary.opacity(0.15))
                        .cornerRadius(8)
                }
                .buttonStyle(.cursor)
                .disabled(selectedCommandId == nil || aliasText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 500, height: 520)
    }

    private func createAlias() {
        guard let commandId = selectedCommandId else { return }
        let trimmedAlias = aliasText.trimmingCharacters(in: .whitespaces).lowercased()

        // Check if alias already exists
        if AliasManager.shared.aliases.contains(where: { $0.alias == trimmedAlias }) {
            errorMessage = "This alias already exists"
            return
        }

        onCreate(commandId, trimmedAlias)
    }
}

// MARK: - Command Picker Row
struct CommandPickerRow: View {
    let command: any Command
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if let icon = command.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: command.type.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                    .frame(width: 22, height: 22)
            }

            Text(command.title)
                .font(.system(size: 13))
                .lineLimit(1)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

#Preview {
    AliasesPage(page: .constant(.aliases))
}
