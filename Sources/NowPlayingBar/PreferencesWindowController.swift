import AppKit
import NowPlayingCore

final class PreferencesWindowController: NSWindowController {
    private var preferences: Preferences
    private let onSave: (Preferences) -> Void
    private let clientIDField = NSTextField()
    private let intervalPopup = NSPopUpButton()
    private static let intervals: [TimeInterval] = [3, 5, 10]

    private let progressEnabledButton = NSButton(
        checkboxWithTitle: "Show progress bar", target: nil, action: nil)
    private let thicknessStepper = NSStepper()
    private let thicknessLabel = NSTextField(labelWithString: "")
    private let colorWell = NSColorWell()
    private let scrollEnabledButton = NSButton(
        checkboxWithTitle: "Scroll long titles", target: nil, action: nil)
    private let speedField = NSTextField()
    private let maxWidthField = NSTextField()
    private let pauseField = NSTextField()

    init(preferences: Preferences, onSave: @escaping (Preferences) -> Void) {
        self.preferences = preferences
        self.onSave = onSave
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 360),
            styleMask: [.titled, .closable, .resizable],
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
        clientIDField.usesSingleLineMode = true
        clientIDField.lineBreakMode = .byClipping
        (clientIDField.cell as? NSTextFieldCell)?.wraps = false
        (clientIDField.cell as? NSTextFieldCell)?.isScrollable = true
        clientIDField.translatesAutoresizingMaskIntoConstraints = false
        clientIDField.widthAnchor.constraint(equalToConstant: 240).isActive = true

        Self.intervals.forEach { intervalPopup.addItem(withTitle: "\(Int($0))s") }
        if let index = Self.intervals.firstIndex(of: preferences.refreshInterval) {
            intervalPopup.selectItem(at: index)
        } else {
            intervalPopup.selectItem(at: 1)
        }

        progressEnabledButton.state = preferences.progressBarEnabled ? .on : .off

        thicknessStepper.minValue = 1
        thicknessStepper.maxValue = 4
        thicknessStepper.increment = 1
        thicknessStepper.integerValue = Int(preferences.progressBarThickness)
        thicknessStepper.target = self
        thicknessStepper.action = #selector(thicknessChanged)
        thicknessLabel.stringValue = "\(Int(preferences.progressBarThickness)) pt"

        colorWell.color = NSColor.fromHex(preferences.progressBarColorHex) ?? .systemGreen
        colorWell.translatesAutoresizingMaskIntoConstraints = false
        colorWell.widthAnchor.constraint(equalToConstant: 44).isActive = true
        colorWell.heightAnchor.constraint(equalToConstant: 24).isActive = true

        scrollEnabledButton.state = preferences.scrollEnabled ? .on : .off
        configureNumberField(speedField, value: preferences.scrollSpeed)
        configureNumberField(maxWidthField, value: preferences.scrollMaxWidth)
        configureNumberField(pauseField, value: preferences.scrollPauseAtEnds)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"

        let thicknessRow = NSStackView(views: [thicknessStepper, thicknessLabel])
        thicknessRow.orientation = .horizontal
        thicknessRow.spacing = 6

        let barRow = NSStackView(views: [
            labeledRow("Bar thickness:", thicknessRow),
            labeledRow("Bar color:", colorWell),
        ])
        barRow.orientation = .horizontal
        barRow.spacing = 20

        let scrollRow = NSStackView(views: [
            labeledRow("Scroll speed (pt/s):", speedField),
            labeledRow("End pause (s):", pauseField),
        ])
        scrollRow.orientation = .horizontal
        scrollRow.spacing = 20

        let stack = NSStackView(views: [
            labeledRow("Client ID:", clientIDField),
            labeledRow("Refresh:", intervalPopup),
            sectionLabel("Menu Bar"),
            progressEnabledButton,
            barRow,
            scrollEnabledButton,
            scrollRow,
            labeledRow("Max width (pt):", maxWidthField),
            saveButton,
        ])
        stack.orientation = .vertical
        stack.alignment = .trailing
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
        ])
    }

    private func configureNumberField(_ field: NSTextField, value: Double) {
        field.stringValue = value == value.rounded() ? String(Int(value)) : String(value)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 60).isActive = true
    }

    private func labeledRow(_ title: String, _ field: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        let row = NSStackView(views: [label, field])
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    private func sectionLabel(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: 12)
        return label
    }

    @objc private func thicknessChanged() {
        thicknessLabel.stringValue = "\(thicknessStepper.integerValue) pt"
    }

    @objc private func save() {
        let trimmed = clientIDField.stringValue.trimmingCharacters(in: .whitespaces)
        preferences.clientID = trimmed.isEmpty ? nil : trimmed
        preferences.refreshInterval = Self.intervals[intervalPopup.indexOfSelectedItem]
        preferences.progressBarEnabled = progressEnabledButton.state == .on
        preferences.progressBarThickness = thicknessStepper.doubleValue
        preferences.progressBarColorHex = colorWell.color.hexRGBA
        preferences.scrollEnabled = scrollEnabledButton.state == .on
        preferences.scrollSpeed = Double(speedField.stringValue) ?? preferences.scrollSpeed
        preferences.scrollMaxWidth = Double(maxWidthField.stringValue) ?? preferences.scrollMaxWidth
        preferences.scrollPauseAtEnds = Double(pauseField.stringValue) ?? preferences.scrollPauseAtEnds
        onSave(preferences)
    }
}
