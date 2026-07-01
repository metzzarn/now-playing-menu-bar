import AppKit
import NowPlayingCore

final class PreferencesWindowController: NSWindowController {
    private var preferences: Preferences
    private let onSave: (Preferences) -> Void
    private let clientIDField = NSTextField()
    private let intervalPopup = NSPopUpButton()
    private static let intervals: [TimeInterval] = [3, 5, 10]

    init(preferences: Preferences, onSave: @escaping (Preferences) -> Void) {
        self.preferences = preferences
        self.onSave = onSave
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 170),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.title = "Preferences"
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    func show() {
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        clientIDField.stringValue = preferences.clientID ?? ""
        clientIDField.placeholderString = "Spotify Client ID"
        clientIDField.translatesAutoresizingMaskIntoConstraints = false
        clientIDField.widthAnchor.constraint(equalToConstant: 220).isActive = true

        Self.intervals.forEach { intervalPopup.addItem(withTitle: "\(Int($0))s") }
        if let index = Self.intervals.firstIndex(of: preferences.refreshInterval) {
            intervalPopup.selectItem(at: index)
        } else {
            intervalPopup.selectItem(at: 1)
        }

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"

        let stack = NSStackView(views: [
            labeledRow("Client ID:", clientIDField),
            labeledRow("Refresh:", intervalPopup),
            saveButton,
        ])
        stack.orientation = .vertical
        stack.alignment = .trailing
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
        ])
    }

    private func labeledRow(_ title: String, _ field: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        let row = NSStackView(views: [label, field])
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    @objc private func save() {
        let trimmed = clientIDField.stringValue.trimmingCharacters(in: .whitespaces)
        preferences.clientID = trimmed.isEmpty ? nil : trimmed
        preferences.refreshInterval = Self.intervals[intervalPopup.indexOfSelectedItem]
        onSave(preferences)
        window?.close()
    }
}
