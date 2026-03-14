import SwiftUI
import AppKit
import Combine

struct AliasItem: Codable, Identifiable {
    let id: UUID
    let commandId: String
    let alias: String

    init(id: UUID = UUID(), commandId: String, alias: String) {
        self.id = id
        self.commandId = commandId
        self.alias = alias
    }
}

class AliasManager: ObservableObject {
    static let shared = AliasManager()

    @Published var aliases: [AliasItem] = []

    private let userDefaultsKey = "saved_aliases"

    private init() {
        loadAliases()
    }

    func loadAliases() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([AliasItem].self, from: data) else {
            return
        }
        aliases = decoded
    }

    func saveAliases() {
        guard let data = try? JSONEncoder().encode(aliases) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    func addAlias(commandId: String, alias: String) -> Bool {
        let trimmedAlias = alias.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmedAlias.isEmpty else { return false }

        // Check if alias already exists
        if aliases.contains(where: { $0.alias == trimmedAlias }) {
            return false
        }

        let newAlias = AliasItem(commandId: commandId, alias: trimmedAlias)
        aliases.append(newAlias)
        saveAliases()

        // Register in CommandRegistry
        registerAlias(newAlias)
        return true
    }

    func deleteAlias(_ alias: AliasItem) {
        aliases.removeAll { $0.id == alias.id }
        saveAliases()

        // Re-register all aliases to update CommandRegistry
        CommandRegistry.shared.reregisterAliases()
    }

    func registerAllAliases() {
        for alias in aliases {
            registerAlias(alias)
        }
    }

    private func registerAlias(_ alias: AliasItem) {
        let registry = CommandRegistry.shared
        guard let command = registry.allCommands.first(where: { $0.id == alias.commandId }) else { return }
        registry.register(alias: alias.alias, for: command)
    }
}

struct AliasesPage: View {
    @Binding var page: Page
    @StateObject private var aliasManager = AliasManager.shared
    @StateObject private var commandRegistry = CommandRegistry.shared
    @State private var showCreateSheet = false
    @State private var escMonitor: Any?

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
                .buttonStyle(PlainButtonStyle())
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
                    .buttonStyle(PlainButtonStyle())
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
                if event.keyCode == 53 { // ESC
                    page = .search
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = escMonitor {
                NSEvent.removeMonitor(monitor)
                escMonitor = nil
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
            .buttonStyle(PlainButtonStyle())
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
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(20)
            .background(Color(.windowBackgroundColor))

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                // Command Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Command")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    // Search Field
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
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)

                    // Command List
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(filteredCommands.prefix(15), id: \.id) { command in
                                CommandPickerRow(command: command, isSelected: selectedCommandId == command.id) {
                                    selectedCommandId = command.id
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .background(Color(.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }

                // Alias Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Alias")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        TextField("e.g., chrome", text: $aliasText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)

                        if let command = selectedCommand {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text(command.title)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Text("Type this alias in search to quickly launch the command")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Error Message
                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                    }
                }

                // Create Button
                HStack {
                    Spacer()
                    Button(action: createAlias) {
                        Text("Create Alias")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(selectedCommandId != nil && !aliasText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.accentColor : Color.gray)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(selectedCommandId == nil || aliasText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(20)
        }
        .frame(width: 500, height: 480)
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
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
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
