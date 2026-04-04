import SwiftUI
import AppKit
import Combine

struct QuickLinksPage: View {
    @Binding var page: Page
    @StateObject private var quickLinkManager = QuickLinkManager.shared
    @State private var showCreateSheet = false
    @State private var editingLink: QuickLinkItem?
    @State private var escMonitor: Any?
    @State private var clickOutsideMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                BackButton(action: { page = .search })

                Spacer()

                Text("Quick Links")
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

            if quickLinkManager.quickLinks.isEmpty {
                // Empty State
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "link")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    VStack(spacing: 8) {
                        Text("No Quick Links Yet")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Add URLs you visit often and open them\ninstantly from search.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Button(action: { showCreateSheet = true }) {
                        Text("Add Your First Quick Link")
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
                // Quick Links List
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(quickLinkManager.quickLinks) { link in
                            QuickLinkRowView(link: link) {
                                editingLink = link
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(width: 700, height: 500)
        .sheet(isPresented: $showCreateSheet) {
            QuickLinkEditorSheet(editingLink: nil) { link in
                quickLinkManager.addQuickLink(link)
                showCreateSheet = false
            }
        }
        .sheet(item: $editingLink) { link in
            QuickLinkEditorSheet(editingLink: link) { updated in
                quickLinkManager.updateQuickLink(updated)
                editingLink = nil
            }
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
}

// MARK: - Quick Link Row View
struct QuickLinkRowView: View {
    let link: QuickLinkItem
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: "link")
                    .font(.system(size: 22))
                    .foregroundColor(.accentColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(link.name)
                    .font(.system(size: 16, weight: .semibold))

                Text(link.url)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let bundleId = link.browserBundleId,
                   let name = browserName(for: bundleId) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.system(size: 10))
                        Text(name)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary.opacity(0.8))
                }
            }

            Spacer()

            // Edit Button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.cursor)

            // Delete Button
            Button(action: { QuickLinkManager.shared.deleteQuickLink(link) }) {
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

    private func browserName(for bundleId: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
              let bundle = Bundle(url: url) else { return nil }
        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
    }
}

// MARK: - Quick Link Editor Sheet
struct QuickLinkEditorSheet: View {
    let editingLink: QuickLinkItem?
    let onSave: (QuickLinkItem) -> Void

    @State private var name: String = ""
    @State private var url: String = ""
    @State private var selectedBrowser: String?
    @State private var installedBrowsers: [(name: String, bundleId: String, icon: NSImage?)] = []
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { editingLink != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Quick Link" : "Add Quick Link")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
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
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.system(size: 13, weight: .medium))

                        TextField("e.g., GitHub", text: $name)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 14))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.windowBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    // URL
                    VStack(alignment: .leading, spacing: 8) {
                        Text("URL")
                            .font(.system(size: 13, weight: .medium))

                        TextField("https://github.com", text: $url)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 14, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.windowBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )

                        Text("Enter a full URL including https://")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    // Browser Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Open With")
                            .font(.system(size: 13, weight: .medium))

                        PopoverPicker(
                            selection: $selectedBrowser,
                            options: [
                                PopoverPickerOption(id: "__default__", label: "Default (from Settings)", systemIcon: "globe")
                            ] + installedBrowsers.map {
                                PopoverPickerOption(id: $0.bundleId, label: $0.name, icon: $0.icon)
                            },
                            placeholder: "Default (from Settings)"
                        )

                        Text("Choose a specific browser for this link, or use the default from Settings.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    // Error
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

                Button("Cancel") { dismiss() }
                    .font(.system(size: 13))
                    .buttonStyle(.cursor)

                Button(action: save) {
                    Text(isEditing ? "Save" : "Add Quick Link")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(canSave ? Color.accentColor : Color.secondary.opacity(0.15))
                        .cornerRadius(8)
                }
                .buttonStyle(.cursor)
                .disabled(!canSave)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 480, height: 460)
        .onAppear {
            loadInstalledBrowsers()
            if let link = editingLink {
                name = link.name
                url = link.url
                selectedBrowser = link.browserBundleId ?? "__default__"
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !url.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        var trimmedURL = url.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty, !trimmedURL.isEmpty else { return }

        // Auto-prepend https:// if no scheme
        if !trimmedURL.contains("://") {
            trimmedURL = "https://" + trimmedURL
        }

        guard URL(string: trimmedURL) != nil else {
            errorMessage = "Invalid URL"
            return
        }

        let link = QuickLinkItem(
            id: editingLink?.id ?? UUID(),
            name: trimmedName,
            url: trimmedURL,
            browserBundleId: selectedBrowser == "__default__" ? nil : selectedBrowser
        )
        onSave(link)
    }

    private func loadInstalledBrowsers() {
        guard let testURL = URL(string: "https://example.com"),
              let apps = LSCopyApplicationURLsForURL(testURL as CFURL, .all)?.takeRetainedValue() as? [URL] else {
            installedBrowsers = []
            return
        }

        var browsers: [(name: String, bundleId: String, icon: NSImage?)] = []

        for appURL in apps {
            guard let bundle = Bundle(url: appURL),
                  let bundleId = bundle.bundleIdentifier else { continue }

            let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? appURL.deletingPathExtension().lastPathComponent

            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 18, height: 18)

            browsers.append((name: name, bundleId: bundleId, icon: icon))
        }

        browsers.sort { $0.name < $1.name }
        installedBrowsers = browsers
    }
}

#Preview {
    QuickLinksPage(page: .constant(.quickLinks))
}
