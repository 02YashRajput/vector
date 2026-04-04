import SwiftUI
import AppKit

// MARK: - NSImage Resize Helper

extension NSImage {
    func resized(to size: NSSize) -> NSImage {
        let img = NSImage(size: size)
        img.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .sourceOver,
                  fraction: 1.0)
        img.unlockFocus()
        return img
    }
}

/// A generic dropdown picker that shows the selected item as an elevated button
/// and opens a popover with all options when clicked.
///
/// Usage:
/// ```
/// PopoverPicker(
///     selection: $selectedId,
///     options: browsers.map { .init(id: $0.bundleId, label: $0.name, icon: $0.icon) },
///     placeholder: "Select...",
///     width: 260
/// )
/// ```
struct PopoverPickerOption: Identifiable {
    let id: String
    let label: String
    let icon: NSImage?
    let systemIcon: String?

    init(id: String, label: String, icon: NSImage? = nil, systemIcon: String? = nil) {
        self.id = id
        self.label = label
        self.icon = icon
        self.systemIcon = systemIcon
    }
}

struct PopoverPicker: View {
    @Binding var selection: String?
    let options: [PopoverPickerOption]
    var placeholder: String = "Select..."
    var popoverWidth: CGFloat = 260

    @State private var showPopover = false

    private var selectedOption: PopoverPickerOption? {
        guard let id = selection else { return nil }
        return options.first { $0.id == id }
    }

    var body: some View {
        Button(action: { showPopover.toggle() }) {
            HStack(spacing: 10) {
                if let option = selectedOption {
                    optionIcon(option)
                    Text(option.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                } else {
                    Text(placeholder)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        let isSelected = selection == option.id

                        Button(action: {
                            selection = option.id
                            showPopover = false
                        }) {
                            HStack(spacing: 10) {
                                optionIcon(option)

                                Text(option.label)
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)

                        if index < options.count - 1 {
                            Divider().padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(width: popoverWidth)
            .frame(maxHeight: 300)
        }
    }

    @ViewBuilder
    private func optionIcon(_ option: PopoverPickerOption) -> some View {
        if let icon = option.icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 20, height: 20)
        } else if let systemIcon = option.systemIcon {
            Image(systemName: systemIcon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
        }
    }
}
