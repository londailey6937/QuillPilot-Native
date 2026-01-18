import Cocoa

final class PreferencesWindowController: NSWindowController {
    private var themedLabels: [NSTextField] = []
    private var themedButtons: [NSButton] = []
    private var themedPopups: [NSPopUpButton] = []

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
        themePopup.addItems(withTitles: ["Day", "Cream", "Night"])
        themePopup.target = self
        themePopup.action = #selector(themeChanged(_:))
        themedPopups.append(themePopup)

        // Auto-save interval
        autoSavePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        autoSavePopup.addItems(withTitles: [
            "Off",
            "Every 1 minute",
            "Every 5 minutes"
        ])
        autoSavePopup.target = self
        autoSavePopup.action = #selector(autoSaveIntervalChanged(_:))
        themedPopups.append(autoSavePopup)

        // Default export format
        defaultExportPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        ExportFormat.allCases.forEach { defaultExportPopup.addItem(withTitle: $0.displayName) }
        defaultExportPopup.target = self
        defaultExportPopup.action = #selector(defaultExportFormatChanged(_:))
        themedPopups.append(defaultExportPopup)

        // Numbering
        numberingSchemePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        QuillPilotSettings.NumberingScheme.allCases.forEach { numberingSchemePopup.addItem(withTitle: $0.displayName) }
        numberingSchemePopup.target = self
        numberingSchemePopup.action = #selector(numberingSchemeChanged(_:))
        themedPopups.append(numberingSchemePopup)

        autoNumberOnReturnCheckbox = NSButton(checkboxWithTitle: "Auto-number lists on Return", target: self, action: #selector(numberingTogglesChanged(_:)))
        themedButtons.append(autoNumberOnReturnCheckbox)

        // Analysis toggles
        autoAnalyzeOnOpenCheckbox = NSButton(checkboxWithTitle: "Auto-run analysis when opening documents/tools", target: self, action: #selector(analysisTogglesChanged(_:)))
        autoAnalyzeWhileTypingCheckbox = NSButton(checkboxWithTitle: "Auto-run analysis while typing", target: self, action: #selector(analysisTogglesChanged(_:)))
        themedButtons.append(autoAnalyzeOnOpenCheckbox)
        themedButtons.append(autoAnalyzeWhileTypingCheckbox)

        let grid = NSGridView(views: [
            [label("Theme"), themePopup],
            [label("Auto-save"), autoSavePopup],
            [label("Default Save As format"), defaultExportPopup],
            [label("Numbering style"), numberingSchemePopup]
        ])
        grid.rowSpacing = 14
        grid.columnSpacing = 16
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.xPlacement = .fill
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading

        // Ensure popups have minimum comfortable width
        themePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        autoSavePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        defaultExportPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        numberingSchemePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true

        container.addArrangedSubview(grid)
        container.addArrangedSubview(NSView())
        container.addArrangedSubview(autoNumberOnReturnCheckbox)
        container.addArrangedSubview(autoAnalyzeOnOpenCheckbox)
        container.addArrangedSubview(autoAnalyzeWhileTypingCheckbox)

        resetTemplateOverridesButton = NSButton(title: "Reset Template Overrides…", target: self, action: #selector(resetTemplateOverrides(_:)))
        resetTemplateOverridesButton.bezelStyle = .rounded
        resetTemplateOverridesButton.controlSize = .small
        resetTemplateOverridesButton.setButtonType(.momentaryPushIn)
        themedButtons.append(resetTemplateOverridesButton)

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
        themedLabels.append(l)
        return l
    }

    private func applyTheme(_ theme: AppTheme) {
        window?.backgroundColor = theme.pageAround
        window?.contentView?.layer?.backgroundColor = theme.pageAround.cgColor

        // Keep control rendering aligned with theme.
        let isDarkMode = ThemeManager.shared.isDarkMode
        window?.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Ensure labels and titles remain readable on Cream backgrounds.
        let labelColor = theme.textColor
        for l in themedLabels {
            l.textColor = labelColor
        }

        for b in themedButtons {
            // Checkbox and push button titles can become washed out depending on system vibrancy.
            let title = b.title
            if !title.isEmpty {
                let font = b.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                b.attributedTitle = NSAttributedString(
                    string: title,
                    attributes: [
                        .foregroundColor: labelColor,
                        .font: font
                    ]
                )
            }
            if #available(macOS 10.14, *) {
                b.contentTintColor = labelColor
            }
        }

        for p in themedPopups {
            if #available(macOS 10.14, *) {
                p.contentTintColor = labelColor
            }
            p.qpApplyDropdownBorder(theme: theme)
        }
    }

    private func loadFromSettings() {
        // Theme
        switch ThemeManager.shared.currentTheme {
        case .day:
            themePopup.selectItem(withTitle: "Day")
        case .cream:
            themePopup.selectItem(withTitle: "Cream")
        case .night:
            themePopup.selectItem(withTitle: "Night")
        }

        // Auto-save
        let interval = QuillPilotSettings.autoSaveIntervalSeconds
        switch interval {
        case 0:
            autoSavePopup.selectItem(at: 0)
        case 60:
            autoSavePopup.selectItem(at: 1)
        case 300:
            autoSavePopup.selectItem(at: 2)
        default:
            // Any legacy value: fall back to 1 minute.
            autoSavePopup.selectItem(at: 1)
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
        switch selection {
        case 0:
            ThemeManager.shared.currentTheme = .day
        case 1:
            ThemeManager.shared.currentTheme = .cream
        case 2:
            ThemeManager.shared.currentTheme = .night
        default:
            ThemeManager.shared.currentTheme = .cream
        }
    }

    @objc private func autoSaveIntervalChanged(_ sender: Any?) {
        switch autoSavePopup.indexOfSelectedItem {
        case 0:
            QuillPilotSettings.autoSaveIntervalSeconds = 0
        case 1:
            QuillPilotSettings.autoSaveIntervalSeconds = 60
        case 2:
            QuillPilotSettings.autoSaveIntervalSeconds = 300
        default:
            QuillPilotSettings.autoSaveIntervalSeconds = 60
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
