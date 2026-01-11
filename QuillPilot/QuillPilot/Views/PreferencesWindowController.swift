import Cocoa

final class PreferencesWindowController: NSWindowController {
    private var themePopup: NSPopUpButton!
    private var autoSavePopup: NSPopUpButton!
    private var defaultExportPopup: NSPopUpButton!
    private var numberingSchemePopup: NSPopUpButton!
    private var autoNumberOnReturnCheckbox: NSButton!
    private var autoAnalyzeOnOpenCheckbox: NSButton!
    private var autoAnalyzeWhileTypingCheckbox: NSButton!
    private var resetTemplateOverridesButton: NSButton!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        setupUI()
        loadFromSettings()
    }

    private func setupUI() {
        guard let window else { return }
        let theme = ThemeManager.shared.currentTheme

        let contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = theme.pageAround.cgColor

        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        container.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)

        // Theme
        themePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        themePopup.addItems(withTitles: ["Day", "Night"])
        themePopup.target = self
        themePopup.action = #selector(themeChanged(_:))

        // Auto-save interval
        autoSavePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        autoSavePopup.addItems(withTitles: [
            "Off",
            "Every 15 seconds",
            "Every 30 seconds",
            "Every 60 seconds"
        ])
        autoSavePopup.target = self
        autoSavePopup.action = #selector(autoSaveIntervalChanged(_:))

        // Default export format
        defaultExportPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        ExportFormat.allCases.forEach { defaultExportPopup.addItem(withTitle: $0.displayName) }
        defaultExportPopup.target = self
        defaultExportPopup.action = #selector(defaultExportFormatChanged(_:))

        // Numbering
        numberingSchemePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        QuillPilotSettings.NumberingScheme.allCases.forEach { numberingSchemePopup.addItem(withTitle: $0.displayName) }
        numberingSchemePopup.target = self
        numberingSchemePopup.action = #selector(numberingSchemeChanged(_:))

        autoNumberOnReturnCheckbox = NSButton(checkboxWithTitle: "Auto-number lists on Return", target: self, action: #selector(numberingTogglesChanged(_:)))

        // Analysis toggles
        autoAnalyzeOnOpenCheckbox = NSButton(checkboxWithTitle: "Auto-run analysis when opening documents/tools", target: self, action: #selector(analysisTogglesChanged(_:)))
        autoAnalyzeWhileTypingCheckbox = NSButton(checkboxWithTitle: "Auto-run analysis while typing", target: self, action: #selector(analysisTogglesChanged(_:)))

        let grid = NSGridView(views: [
            [label("Theme"), themePopup],
            [label("Auto-save"), autoSavePopup],
            [label("Default Save As format"), defaultExportPopup],
            [label("Numbering style"), numberingSchemePopup]
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 12
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.xPlacement = .fill

        container.addArrangedSubview(grid)
        container.addArrangedSubview(NSView())
        container.addArrangedSubview(autoNumberOnReturnCheckbox)
        container.addArrangedSubview(autoAnalyzeOnOpenCheckbox)
        container.addArrangedSubview(autoAnalyzeWhileTypingCheckbox)

        resetTemplateOverridesButton = NSButton(title: "Reset Template Overrides…", target: self, action: #selector(resetTemplateOverrides(_:)))
        resetTemplateOverridesButton.bezelStyle = .rounded
        resetTemplateOverridesButton.controlSize = .small
        resetTemplateOverridesButton.setButtonType(.momentaryPushIn)

        let resetRow = NSStackView()
        resetRow.orientation = .horizontal
        resetRow.spacing = 8
        resetRow.addArrangedSubview(NSView())
        resetRow.addArrangedSubview(resetTemplateOverridesButton)
        container.addArrangedSubview(resetRow)

        contentView.addSubview(container)
        window.contentView = contentView

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            container.topAnchor.constraint(equalTo: contentView.topAnchor),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        applyTheme(theme)

        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange(_:)), name: .themeDidChange, object: nil)
    }

    @objc private func resetTemplateOverrides(_ sender: Any?) {
        let templateName = StyleCatalog.shared.currentTemplateName

        let alert = NSAlert()
        alert.messageText = "Reset Template Overrides?"
        alert.informativeText = "This will reset any custom style edits you made for the “\(templateName)” template back to defaults. This can’t be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        StyleCatalog.shared.resetAllOverridesAndNotify()
    }

    private func label(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        l.setContentHuggingPriority(.required, for: .horizontal)
        return l
    }

    private func applyTheme(_ theme: AppTheme) {
        window?.backgroundColor = theme.pageAround
        window?.contentView?.layer?.backgroundColor = theme.pageAround.cgColor
    }

    private func loadFromSettings() {
        // Theme
        themePopup.selectItem(withTitle: ThemeManager.shared.currentTheme == .day ? "Day" : "Night")

        // Auto-save
        let interval = QuillPilotSettings.autoSaveIntervalSeconds
        switch interval {
        case 0:
            autoSavePopup.selectItem(at: 0)
        case 15:
            autoSavePopup.selectItem(at: 1)
        case 60:
            autoSavePopup.selectItem(at: 3)
        default:
            autoSavePopup.selectItem(at: 2)
        }

        // Default export format
        let format = QuillPilotSettings.defaultExportFormat
        if let idx = ExportFormat.allCases.firstIndex(of: format) {
            defaultExportPopup.selectItem(at: idx)
        }

        // Numbering
        if let idx = QuillPilotSettings.NumberingScheme.allCases.firstIndex(of: QuillPilotSettings.numberingScheme) {
            numberingSchemePopup.selectItem(at: idx)
        }
        autoNumberOnReturnCheckbox.state = QuillPilotSettings.autoNumberOnReturn ? .on : .off

        autoAnalyzeOnOpenCheckbox.state = QuillPilotSettings.autoAnalyzeOnOpen ? .on : .off
        autoAnalyzeWhileTypingCheckbox.state = QuillPilotSettings.autoAnalyzeWhileTyping ? .on : .off
    }

    @objc private func themeChanged(_ sender: Any?) {
        let selection = themePopup.indexOfSelectedItem
        ThemeManager.shared.currentTheme = (selection == 1) ? .night : .day
    }

    @objc private func autoSaveIntervalChanged(_ sender: Any?) {
        switch autoSavePopup.indexOfSelectedItem {
        case 0:
            QuillPilotSettings.autoSaveIntervalSeconds = 0
        case 1:
            QuillPilotSettings.autoSaveIntervalSeconds = 15
        case 3:
            QuillPilotSettings.autoSaveIntervalSeconds = 60
        default:
            QuillPilotSettings.autoSaveIntervalSeconds = 30
        }
    }

    @objc private func defaultExportFormatChanged(_ sender: Any?) {
        let idx = defaultExportPopup.indexOfSelectedItem
        guard idx >= 0, idx < ExportFormat.allCases.count else { return }
        QuillPilotSettings.defaultExportFormat = ExportFormat.allCases[idx]
    }

    @objc private func numberingSchemeChanged(_ sender: Any?) {
        let idx = numberingSchemePopup.indexOfSelectedItem
        guard idx >= 0, idx < QuillPilotSettings.NumberingScheme.allCases.count else { return }
        QuillPilotSettings.numberingScheme = QuillPilotSettings.NumberingScheme.allCases[idx]
    }

    @objc private func numberingTogglesChanged(_ sender: Any?) {
        QuillPilotSettings.autoNumberOnReturn = (autoNumberOnReturnCheckbox.state == .on)
    }

    @objc private func analysisTogglesChanged(_ sender: Any?) {
        QuillPilotSettings.autoAnalyzeOnOpen = (autoAnalyzeOnOpenCheckbox.state == .on)
        QuillPilotSettings.autoAnalyzeWhileTyping = (autoAnalyzeWhileTypingCheckbox.state == .on)
    }

    @objc private func themeDidChange(_ note: Notification) {
        applyTheme(ThemeManager.shared.currentTheme)
    }
}
