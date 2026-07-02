import AppKit
import NowPlayingCore

final class PreferencesWindowController: NSWindowController, NSTextFieldDelegate {
    private var preferences: Preferences
    private let onSave: (Preferences) -> Void
    private let clientIDField = NSTextField()
    private let intervalPopup = NSPopUpButton()
    private let formatField = NSTextField()
    private let formatErrorLabel = NSTextField(labelWithString: "")
    private let variablesHint = NSTextField(
        labelWithString: "Variables: <title> <artist> <artists> <album> <year>")
    private let saveButton = NSButton(title: "Save", target: nil, action: nil)
    private static let intervals: [TimeInterval] = [1, 3, 5, 10]

    private let progressEnabledButton = NSButton(
        checkboxWithTitle: "Show progress bar", target: nil, action: nil)
    private let thicknessStepper = NSStepper()
    private let thicknessLabel = NSTextField(labelWithString: "")
    private let colorWell = NSColorWell()
    private let scrollEnabledButton = NSButton(
        checkboxWithTitle: "Scroll long titles", target: nil, action: nil)
    private let speedField = NSTextField()
    private let useStaticWidthButton = NSButton(
        checkboxWithTitle: "Use static width (instead of max width)", target: nil, action: nil)
    private let staticWidthField = NSTextField()
    private let maxWidthField = NSTextField()
    private let pauseField = NSTextField()
    private let alignmentPopup = NSPopUpButton()
    private let barBackgroundWell = NSColorWell()
    private let appBackgroundWell = NSColorWell()
    private let appTextWell = NSColorWell()
    private let menuBarTextWell = NSColorWell()
    private let themePopup = NSPopUpButton()
    private let tabView = NSTabView()

    // Working color values; nil = system color. Persisted directly on Save.
    private var workingBackground: String?
    private var workingText: String?
    private var workingMenuBarText: String?
    private var workingBarColor = "#1DB954FF"
    private var workingBarBackground: String?

    init(preferences: Preferences, onSave: @escaping (Preferences) -> Void) {
        self.preferences = preferences
        self.onSave = onSave
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Preferences"
        window.contentMinSize = NSSize(width: 460, height: 580)
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
        configureControls()

        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.addTabViewItem(tab("Spotify", view: spotifyTab()))
        tabView.addTabViewItem(tab("Menu Bar", view: menuBarTab()))
        tabView.addTabViewItem(tab("Style", view: styleTab()))
        tabView.selectTabViewItem(at: 1)  // default to Menu Bar

        saveButton.title = "Save"
        saveButton.target = self
        saveButton.action = #selector(save)
        saveButton.keyEquivalent = "\r"
        saveButton.setContentHuggingPriority(.required, for: .horizontal)
        let saveRow = NSStackView(views: [NSView(), saveButton])
        saveRow.orientation = .horizontal
        saveRow.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(tabView)
        content.addSubview(saveRow)
        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            tabView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            tabView.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            saveRow.topAnchor.constraint(equalTo: tabView.bottomAnchor, constant: 12),
            saveRow.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            saveRow.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            saveRow.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
        ])

        applyWindowColors()
    }

    // MARK: - Control configuration

    private func configureControls() {
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
        thicknessLabel.translatesAutoresizingMaskIntoConstraints = false
        thicknessLabel.widthAnchor.constraint(equalToConstant: 34).isActive = true


        scrollEnabledButton.state = preferences.scrollEnabled ? .on : .off
        scrollEnabledButton.target = self
        scrollEnabledButton.action = #selector(scrollModeChanged)
        useStaticWidthButton.state = preferences.useStaticWidth ? .on : .off
        useStaticWidthButton.target = self
        useStaticWidthButton.action = #selector(widthModeChanged)
        configureNumberField(speedField, value: preferences.scrollSpeed)
        configureNumberField(staticWidthField, value: preferences.staticWidth)
        configureNumberField(maxWidthField, value: preferences.scrollMaxWidth)
        configureNumberField(pauseField, value: preferences.scrollPauseAtEnds)

        MenuBarTextAlignment.allCases.forEach {
            alignmentPopup.addItem(withTitle: $0.rawValue.capitalized)
        }
        if let index = MenuBarTextAlignment.allCases.firstIndex(of: preferences.textAlignment) {
            alignmentPopup.selectItem(at: index)
        }

        formatField.stringValue = preferences.trackTemplate
        formatField.placeholderString = Preferences.defaultTrackTemplate
        formatField.delegate = self
        formatField.translatesAutoresizingMaskIntoConstraints = false
        formatField.widthAnchor.constraint(equalToConstant: 260).isActive = true
        formatErrorLabel.textColor = .systemRed
        formatErrorLabel.font = .systemFont(ofSize: 10)

        workingBackground = preferences.appBackgroundColorHex
        workingText = preferences.appTextColorHex
        workingMenuBarText = preferences.menuBarTextColorHex
        workingBarColor = preferences.progressBarColorHex
        workingBarBackground = preferences.progressBarBackgroundColorHex

        configureColorWell(colorWell, hex: workingBarColor, systemColor: .systemGreen)
        configureColorWell(barBackgroundWell, hex: workingBarBackground,
                           systemColor: NSColor.labelColor.withAlphaComponent(0.2))
        configureColorWell(appBackgroundWell, hex: workingBackground,
                           systemColor: .windowBackgroundColor)
        configureColorWell(appTextWell, hex: workingText, systemColor: .labelColor)
        configureColorWell(menuBarTextWell, hex: workingMenuBarText, systemColor: .labelColor)

        themePopup.addItem(withTitle: "Custom")
        Theme.all.forEach { themePopup.addItem(withTitle: $0.name) }
        themePopup.target = self
        themePopup.action = #selector(themeChanged)
        updateThemeSelection()

        updateWidthFieldStates()
        updateScrollFieldStates()
        updateFormatValidation()
    }

    // MARK: - Tabs

    private func spotifyTab() -> NSView {
        tabContainer([
            labeledRow("Client ID:", clientIDField),
            labeledRow("Refresh:", intervalPopup),
        ])
    }

    private func menuBarTab() -> NSView {
        let scrollRow = NSStackView(views: [
            labeledRow("Scroll speed (pt/s):", speedField),
            labeledRow("End pause (s):", pauseField),
        ])
        scrollRow.orientation = .horizontal
        scrollRow.spacing = 20

        variablesHint.font = .systemFont(ofSize: 10)
        variablesHint.textColor = .secondaryLabelColor

        return tabContainer([
            labeledRow("Text alignment:", alignmentPopup),
            labeledRow("Format:", formatField),
            variablesHint,
            formatErrorLabel,
            divider(),
            progressEnabledButton,
            divider(),
            scrollEnabledButton,
            scrollRow,
            divider(),
            useStaticWidthButton,
            labeledRow("Static width (pt):", staticWidthField),
            labeledRow("Max width (pt):", maxWidthField),
        ])
    }

    private func styleTab() -> NSView {
        let thicknessRow = NSStackView(views: [thicknessStepper, thicknessLabel])
        thicknessRow.orientation = .horizontal
        thicknessRow.spacing = 6

        return tabContainer([
            sectionLabel("Theme"),
            labeledRow("Theme:", themePopup),
            divider(),
            sectionLabel("Colors"),
            labeledRow("Background color:", appBackgroundWell),
            labeledRow("Text color:", appTextWell),
            labeledRow("Menu bar text color:", menuBarTextWell),
            divider(),
            sectionLabel("Progress Bar"),
            labeledRow("Bar thickness:", thicknessRow),
            labeledRow("Progress bar color:", colorWell),
            labeledRow("Progress bar background:", barBackgroundWell),
        ])
    }

    private func configureColorWell(_ well: NSColorWell, hex: String?, systemColor: NSColor) {
        well.color = hex.flatMap(NSColor.fromHex) ?? systemColor
        well.target = self
        well.action = #selector(colorWellChanged(_:))
        well.translatesAutoresizingMaskIntoConstraints = false
        well.widthAnchor.constraint(equalToConstant: 44).isActive = true
        well.heightAnchor.constraint(equalToConstant: 24).isActive = true
    }

    @objc private func colorWellChanged(_ sender: NSColorWell) {
        let hex = sender.color.hexRGBA
        switch sender {
        case appBackgroundWell: workingBackground = hex
        case appTextWell: workingText = hex
        case menuBarTextWell: workingMenuBarText = hex
        case colorWell: workingBarColor = hex
        case barBackgroundWell: workingBarBackground = hex
        default: break
        }
        updateThemeSelection()
    }

    @objc private func themeChanged() {
        let title = themePopup.titleOfSelectedItem ?? "Custom"
        guard let theme = Theme.all.first(where: { $0.name == title }) else { return }
        applyTheme(theme)
    }

    private func applyTheme(_ theme: Theme) {
        workingBackground = theme.background
        workingText = theme.text
        workingMenuBarText = theme.menuBarText
        workingBarColor = theme.progressBarColor
        workingBarBackground = theme.progressBarBackground

        appBackgroundWell.color = colorOrSystem(theme.background, .windowBackgroundColor)
        appTextWell.color = colorOrSystem(theme.text, .labelColor)
        menuBarTextWell.color = colorOrSystem(theme.menuBarText, .labelColor)
        colorWell.color = NSColor.fromHex(theme.progressBarColor) ?? .systemGreen
        barBackgroundWell.color = colorOrSystem(theme.progressBarBackground,
                                                NSColor.labelColor.withAlphaComponent(0.2))
    }

    private func colorOrSystem(_ hex: String?, _ system: NSColor) -> NSColor {
        hex.flatMap(NSColor.fromHex) ?? system
    }

    private func updateThemeSelection() {
        let match = Theme.matching(
            background: workingBackground, text: workingText, menuBarText: workingMenuBarText,
            progressBarColor: workingBarColor, progressBarBackground: workingBarBackground)
        themePopup.selectItem(withTitle: match?.name ?? "Custom")
    }

    /// Applies the configured app colors to the Preferences window itself.
    private func applyWindowColors() {
        guard let content = window?.contentView else { return }
        let background = preferences.appBackgroundColorHex.flatMap(NSColor.fromHex)
            ?? .windowBackgroundColor
        let text = preferences.appTextColorHex.flatMap(NSColor.fromHex) ?? .labelColor
        content.wantsLayer = true
        content.layer?.backgroundColor = background.cgColor
        applyTextColor(text, to: content)
        // Non-selected tabs aren't in the view hierarchy, so recolor each tab's view.
        for item in tabView.tabViewItems {
            if let view = item.view { applyTextColor(text, to: view) }
        }
    }

    private func applyTextColor(_ color: NSColor, to view: NSView) {
        for subview in view.subviews {
            if let label = subview as? NSTextField,
               !label.isEditable, !label.isBezeled, subview !== formatErrorLabel {
                label.textColor = color
            }
            if let popup = subview as? NSPopUpButton {
                for item in popup.itemArray {
                    item.attributedTitle = NSAttributedString(
                        string: item.title, attributes: [.foregroundColor: color])
                }
            }
            applyTextColor(color, to: subview)
        }
    }

    /// Wraps rows in a padded, left-aligned vertical stack; separators stretch full width.
    private func tabContainer(_ rows: [NSView]) -> NSView {
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -16),
        ])
        for row in rows where row is NSBox {
            row.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
        }
        return container
    }

    // MARK: - Row helpers

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

    private func divider() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }

    private func sectionLabel(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: 12)
        return label
    }

    private func tab(_ label: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = label
        item.view = view
        return item
    }

    @objc private func thicknessChanged() {
        thicknessLabel.stringValue = "\(thicknessStepper.integerValue) pt"
    }

    @objc private func widthModeChanged() {
        updateWidthFieldStates()
    }

    func controlTextDidChange(_ obj: Notification) {
        if (obj.object as? NSTextField) === formatField { updateFormatValidation() }
    }

    private func updateFormatValidation() {
        let error = TrackTemplate.validate(formatField.stringValue)
        formatErrorLabel.stringValue = error ?? ""
        saveButton.isEnabled = error == nil
    }

    private func updateWidthFieldStates() {
        let staticOn = useStaticWidthButton.state == .on
        staticWidthField.isEnabled = staticOn
        maxWidthField.isEnabled = !staticOn
    }

    @objc private func scrollModeChanged() {
        updateScrollFieldStates()
    }

    private func updateScrollFieldStates() {
        let on = scrollEnabledButton.state == .on
        speedField.isEnabled = on
        pauseField.isEnabled = on
    }

    @objc private func save() {
        let trimmed = clientIDField.stringValue.trimmingCharacters(in: .whitespaces)
        preferences.clientID = trimmed.isEmpty ? nil : trimmed
        preferences.refreshInterval = Self.intervals[intervalPopup.indexOfSelectedItem]
        preferences.progressBarEnabled = progressEnabledButton.state == .on
        preferences.progressBarThickness = thicknessStepper.doubleValue
        preferences.scrollEnabled = scrollEnabledButton.state == .on
        preferences.scrollSpeed = Double(speedField.stringValue) ?? preferences.scrollSpeed
        preferences.useStaticWidth = useStaticWidthButton.state == .on
        preferences.staticWidth = Double(staticWidthField.stringValue) ?? preferences.staticWidth
        preferences.scrollMaxWidth = Double(maxWidthField.stringValue) ?? preferences.scrollMaxWidth
        preferences.scrollPauseAtEnds = Double(pauseField.stringValue) ?? preferences.scrollPauseAtEnds
        preferences.textAlignment = MenuBarTextAlignment.allCases[alignmentPopup.indexOfSelectedItem]
        preferences.trackTemplate = formatField.stringValue
        preferences.appBackgroundColorHex = workingBackground
        preferences.appTextColorHex = workingText
        preferences.menuBarTextColorHex = workingMenuBarText
        preferences.progressBarColorHex = workingBarColor
        preferences.progressBarBackgroundColorHex = workingBarBackground
        onSave(preferences)
        applyWindowColors()
    }
}
