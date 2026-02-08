import Cocoa

// MARK: - Scene Inspector Window Controller
/// Displays and edits metadata for a single scene.
/// IMPORTANT: This window only manages metadata - it NEVER accesses the editor.
final class SceneInspectorWindowController: NSWindowController {

    private var sluglineField: NSTextField!
    private var titleField: NSTextField!
    private var summaryField: NSTextField!
    private var notesView: NSTextView!
    private var intentPopup: NSPopUpButton!
    private var statePopup: NSPopUpButton!
    private var povComboBox: NSComboBox!
    private var locationComboBox: NSComboBox!
    private var timeField: NSTextField!
    private var charactersField: NSTextField!
    private var goalField: NSTextField!
    private var conflictField: NSTextField!
    private var outcomeField: NSTextField!

    // Scene Writer components
    private var sceneWriterTextView: NSTextView!
    private var sceneWriterStatusLabel: NSTextField!
    private var sceneWriterStatusIcon: NSTextField!
    private var sceneWriterTitleLabel: NSTextField?
    private var dramaticHeaderLabel: NSTextField?
    private var saveButton: NSButton?
    private var cancelButton: NSButton?
    private var copyButton: NSButton?
    private var saveWriterButton: NSButton?

    private var currentScene: Scene?
    private var currentDocumentURL: URL?
    private var onSave: ((Scene) -> Void)?
    private var onPaste: ((String) -> Void)?

    // Store labels for theme updates
    private var allLabels: [NSTextField] = []

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1050, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Scene Inspector"
        window.minSize = NSSize(width: 900, height: 500)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]

        // Set initial window background
        let theme = ThemeManager.shared.currentTheme
        window.backgroundColor = theme.popoutBackground

        // Set window appearance to match theme (light/dark mode)
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        super.init(window: window)

        setupUI()
        applyCurrentTheme()

        // Listen for theme changes
        NotificationCenter.default.addObserver(forName: .themeDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.applyCurrentTheme()
        }
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadScene(_ scene: Scene, documentURL: URL?, onSave: @escaping (Scene) -> Void, onPaste: ((String) -> Void)? = nil) {
        self.currentScene = scene
        self.currentDocumentURL = documentURL
        self.onSave = onSave
        self.onPaste = onPaste

        let cachedSlugline = ScreenplaySluglineCache.shared.slugline(for: documentURL, sceneOrder: scene.order) ?? ""
        sluglineField.stringValue = cachedSlugline
        sluglineField.toolTip = cachedSlugline.isEmpty ? nil : cachedSlugline

        titleField.stringValue = scene.title
        summaryField.stringValue = scene.summary
        notesView.string = scene.notes
        povComboBox.stringValue = scene.pointOfView
        locationComboBox.stringValue = scene.location
        timeField.stringValue = scene.timeOfDay
        charactersField.stringValue = scene.characters.joined(separator: ", ")
        goalField.stringValue = scene.goal
        conflictField.stringValue = scene.conflict
        outcomeField.stringValue = scene.outcome

        // Update Scene Writer status
        updateSceneWriterStatus(scene.revisionState)

        // Set popup selections
        if let intentIndex = SceneIntent.allCases.firstIndex(of: scene.intent) {
            intentPopup.selectItem(at: intentIndex)
        }
        if let stateIndex = RevisionState.allCases.firstIndex(of: scene.revisionState) {
            statePopup.selectItem(at: stateIndex)
        }
    }

    private func setupUI() {
        guard let window = window else { return }

        let theme = ThemeManager.shared.currentTheme

        let contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = theme.popoutBackground.cgColor
        window.contentView = contentView

        // Create horizontal split container
        let inspectorPanel = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: contentView.bounds.height))
        inspectorPanel.autoresizingMask = [.height]
        inspectorPanel.wantsLayer = true
        inspectorPanel.layer?.backgroundColor = theme.popoutBackground.cgColor
        contentView.addSubview(inspectorPanel)

        // Vertical separator line
        let separator = NSBox()
        separator.boxType = .separator
        separator.frame = NSRect(x: 420, y: 0, width: 1, height: contentView.bounds.height)
        separator.autoresizingMask = [.height]
        contentView.addSubview(separator)

        // Scene Writer panel
        let writerPanel = NSView(frame: NSRect(x: 421, y: 0, width: contentView.bounds.width - 421, height: contentView.bounds.height))
        writerPanel.autoresizingMask = [.width, .height]
        writerPanel.wantsLayer = true
        writerPanel.layer?.backgroundColor = theme.popoutBackground.cgColor
        contentView.addSubview(writerPanel)

        // Setup Inspector Panel (left side)
        setupInspectorPanel(inspectorPanel)

        // Setup Scene Writer Panel (right side)
        setupSceneWriterPanel(writerPanel)
    }

    private func setupInspectorPanel(_ panel: NSView) {
        var y: CGFloat = panel.bounds.height - 40
        let fieldX: CGFloat = 100
        let fieldWidth: CGFloat = panel.bounds.width - fieldX - 20
        let rowHeight: CGFloat = 28
        let spacing: CGFloat = 8

        // Slugline (read-only annotation)
        addLabel("Slugline:", at: NSPoint(x: 10, y: y), in: panel)
        sluglineField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 24))
        sluglineField.autoresizingMask = [.width]
        sluglineField.isEditable = false
        sluglineField.isSelectable = true
        sluglineField.isBezeled = true
        sluglineField.bezelStyle = .roundedBezel
        sluglineField.lineBreakMode = .byTruncatingTail
        sluglineField.placeholderString = "(derived from screenplay text)"
        panel.addSubview(sluglineField)
        y -= rowHeight + spacing

        // Title
        addLabel("Title:", at: NSPoint(x: 10, y: y), in: panel)
        titleField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 24))
        titleField.autoresizingMask = [.width]
        titleField.placeholderString = "Scene title"
        panel.addSubview(titleField)
        y -= rowHeight + spacing

        // Intent
        addLabel("Intent:", at: NSPoint(x: 10, y: y), in: panel)
        intentPopup = NSPopUpButton(frame: NSRect(x: fieldX, y: y - 2, width: 150, height: 26))
        for intent in SceneIntent.allCases {
            intentPopup.addItem(withTitle: intent.rawValue)
        }
        panel.addSubview(intentPopup)
        y -= rowHeight + spacing

        // Revision State
        addLabel("Status:", at: NSPoint(x: 10, y: y), in: panel)
        statePopup = NSPopUpButton(frame: NSRect(x: fieldX, y: y - 2, width: 150, height: 26))
        statePopup.target = self
        statePopup.action = #selector(statusChanged)
        for state in RevisionState.allCases {
            statePopup.addItem(withTitle: "\(state.icon) \(state.rawValue)")
        }
        panel.addSubview(statePopup)
        y -= rowHeight + spacing

        // POV - Connected to Character Library
        addLabel("POV:", at: NSPoint(x: 10, y: y), in: panel)
        povComboBox = NSComboBox(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 26))
        povComboBox.autoresizingMask = []
        povComboBox.placeholderString = "Point of view character"
        povComboBox.completes = true
        // Populate with characters from Character Library (first name from fullName)
        let characterNames = CharacterLibrary.shared.characters.compactMap { character -> String? in
            let fullName = character.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fullName.isEmpty else { return nil }
            return fullName.components(separatedBy: .whitespaces).first
        }
        povComboBox.addItems(withObjectValues: characterNames)
        panel.addSubview(povComboBox)
        y -= rowHeight + spacing

        // Location - Editable dropdown with previously used locations
        addLabel("Location:", at: NSPoint(x: 10, y: y), in: panel)
        locationComboBox = NSComboBox(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 26))
        locationComboBox.autoresizingMask = []
        locationComboBox.placeholderString = "Where the scene takes place"
        locationComboBox.completes = true
        // Populate with previously used locations from UserDefaults
        if let savedLocations = UserDefaults.standard.stringArray(forKey: "QuillPilot.Scene.Locations") {
            locationComboBox.addItems(withObjectValues: savedLocations)
        }
        panel.addSubview(locationComboBox)
        y -= rowHeight + spacing

        // Time
        addLabel("Time:", at: NSPoint(x: 10, y: y), in: panel)
        timeField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 24))
        timeField.autoresizingMask = []
        timeField.placeholderString = "Time of day or period"
        panel.addSubview(timeField)
        y -= rowHeight + spacing

        // Characters
        addLabel("Characters:", at: NSPoint(x: 10, y: y), in: panel)
        charactersField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 24))
        charactersField.autoresizingMask = []
        charactersField.placeholderString = "Character names (comma separated)"
        panel.addSubview(charactersField)
        y -= rowHeight + spacing + 10

        // Separator line
        let separator1 = NSBox(frame: NSRect(x: 10, y: y + 4, width: panel.bounds.width - 20, height: 1))
        separator1.boxType = .separator
        panel.addSubview(separator1)
        y -= 10

        // Section header: Dramatic Elements
        let dramaticHeader = NSTextField(labelWithString: "Dramatic Elements")
        dramaticHeader.frame = NSRect(x: 10, y: y, width: 200, height: 18)
        dramaticHeader.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        dramaticHeader.textColor = ThemeManager.shared.currentTheme.popoutSecondaryColor
        panel.addSubview(dramaticHeader)
        dramaticHeaderLabel = dramaticHeader
        y -= rowHeight

        // Goal
        addLabel("Goal:", at: NSPoint(x: 10, y: y), in: panel)
        goalField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 24))
        goalField.autoresizingMask = []
        goalField.placeholderString = "What does the POV character want?"
        panel.addSubview(goalField)
        y -= rowHeight + spacing

        // Conflict
        addLabel("Conflict:", at: NSPoint(x: 10, y: y), in: panel)
        conflictField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 24))
        conflictField.autoresizingMask = []
        conflictField.placeholderString = "What opposes the goal?"
        panel.addSubview(conflictField)
        y -= rowHeight + spacing

        // Outcome
        addLabel("Outcome:", at: NSPoint(x: 10, y: y), in: panel)
        outcomeField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 24))
        outcomeField.autoresizingMask = []
        outcomeField.placeholderString = "Success / Failure / Complication"
        panel.addSubview(outcomeField)
        y -= rowHeight + spacing + 10

        // Separator line
        let separator2 = NSBox(frame: NSRect(x: 10, y: y + 4, width: panel.bounds.width - 20, height: 1))
        separator2.boxType = .separator
        panel.addSubview(separator2)
        y -= 10

        // Summary
        addLabel("Summary:", at: NSPoint(x: 10, y: y), in: panel)
        summaryField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 24))
        summaryField.autoresizingMask = []
        summaryField.placeholderString = "Brief summary of scene"
        panel.addSubview(summaryField)
        y -= rowHeight + spacing + 10

        // Notes label
        addLabel("Notes:", at: NSPoint(x: 10, y: y), in: panel)
        y -= 20

        // Notes text view
        let notesScrollView = NSScrollView(frame: NSRect(x: 10, y: 60, width: panel.bounds.width - 20, height: y - 50))
        notesScrollView.hasVerticalScroller = true
        notesScrollView.borderType = .bezelBorder

        notesView = NSTextView(frame: notesScrollView.bounds)
        notesView.autoresizingMask = [.width, .height]
        notesView.isRichText = false
        notesView.font = NSFont.systemFont(ofSize: 13)
        notesView.textContainerInset = NSSize(width: 5, height: 5)
        notesScrollView.documentView = notesView
        panel.addSubview(notesScrollView)

        // Save button
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveScene))
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: panel.bounds.width - 90, y: 15, width: 80, height: 32)
        panel.addSubview(saveButton)
        self.saveButton = saveButton

        // Cancel button
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelEdit))
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.frame = NSRect(x: panel.bounds.width - 180, y: 15, width: 80, height: 32)
        panel.addSubview(cancelButton)
        self.cancelButton = cancelButton
    }

    private func setupSceneWriterPanel(_ panel: NSView) {
        // Header with status
        let headerView = NSView(frame: NSRect(x: 0, y: panel.bounds.height - 40, width: panel.bounds.width, height: 40))
        headerView.autoresizingMask = [.width]
        panel.addSubview(headerView)

        let titleLabel = NSTextField(labelWithString: "Scene Writer")
        titleLabel.frame = NSRect(x: 15, y: 10, width: 150, height: 20)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        headerView.addSubview(titleLabel)
        sceneWriterTitleLabel = titleLabel

        // Status icon and label
        sceneWriterStatusIcon = NSTextField(labelWithString: "⚪️")
        sceneWriterStatusIcon.frame = NSRect(x: panel.bounds.width - 120, y: 10, width: 30, height: 20)
        sceneWriterStatusIcon.autoresizingMask = [.minXMargin]
        sceneWriterStatusIcon.alignment = .center
        headerView.addSubview(sceneWriterStatusIcon)

        sceneWriterStatusLabel = NSTextField(labelWithString: "Draft")
        sceneWriterStatusLabel.frame = NSRect(x: panel.bounds.width - 85, y: 10, width: 70, height: 20)
        sceneWriterStatusLabel.autoresizingMask = [.minXMargin]
        sceneWriterStatusLabel.font = NSFont.systemFont(ofSize: 11)
        sceneWriterStatusLabel.textColor = ThemeManager.shared.currentTheme.popoutSecondaryColor
        headerView.addSubview(sceneWriterStatusLabel)

        // Text view with scroll view
        let scrollView = NSScrollView(frame: NSRect(x: 10, y: 60, width: panel.bounds.width - 20, height: panel.bounds.height - 110))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        sceneWriterTextView = NSTextView(frame: scrollView.bounds)
        sceneWriterTextView.autoresizingMask = [.width, .height]
        sceneWriterTextView.isRichText = true
        sceneWriterTextView.textContainerInset = NSSize(width: 5, height: 5)
        sceneWriterTextView.isAutomaticQuoteSubstitutionEnabled = true
        sceneWriterTextView.isAutomaticDashSubstitutionEnabled = true

        // Apply Body Text style from StyleCatalog
        if let bodyStyle = StyleCatalog.shared.style(named: "Body Text") {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = NSTextAlignment(rawValue: bodyStyle.alignmentRawValue) ?? .left
            paragraphStyle.lineHeightMultiple = bodyStyle.lineHeightMultiple
            paragraphStyle.paragraphSpacingBefore = bodyStyle.spacingBefore
            paragraphStyle.paragraphSpacing = bodyStyle.spacingAfter
            paragraphStyle.headIndent = bodyStyle.headIndent
            paragraphStyle.firstLineHeadIndent = bodyStyle.headIndent + bodyStyle.firstLineIndent
            paragraphStyle.tailIndent = bodyStyle.tailIndent
            paragraphStyle.lineBreakMode = .byWordWrapping

            var font = NSFont.quillPilotResolve(nameOrFamily: bodyStyle.fontName, size: bodyStyle.fontSize) ?? NSFont.systemFont(ofSize: bodyStyle.fontSize)
            if bodyStyle.isBold {
                font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            }
            if bodyStyle.isItalic {
                font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            }

            sceneWriterTextView.font = font
            sceneWriterTextView.typingAttributes = [
                .font: font,
                .paragraphStyle: paragraphStyle,
                .foregroundColor: NSColor.textColor
            ]
        } else {
            sceneWriterTextView.font = NSFont.systemFont(ofSize: 13)
        }

        scrollView.documentView = sceneWriterTextView
        panel.addSubview(scrollView)

        // Button container
        let buttonContainer = NSView(frame: NSRect(x: 0, y: 0, width: panel.bounds.width, height: 50))
        buttonContainer.autoresizingMask = [.width]
        panel.addSubview(buttonContainer)

        // Copy to Clipboard button
        let copyButton = NSButton(title: "Copy to Clipboard", target: self, action: #selector(copyToClipboard))
        copyButton.frame = NSRect(x: panel.bounds.width - 165, y: 10, width: 145, height: 32)
        copyButton.autoresizingMask = [.minXMargin]
        buttonContainer.addSubview(copyButton)
        self.copyButton = copyButton

        // Save button
        let saveWriterButton = NSButton(title: "Save", target: self, action: #selector(saveSceneWriter))
        saveWriterButton.frame = NSRect(x: panel.bounds.width - 300, y: 10, width: 125, height: 32)
        saveWriterButton.autoresizingMask = [.minXMargin]
        buttonContainer.addSubview(saveWriterButton)
        self.saveWriterButton = saveWriterButton
    }

    @objc private func statusChanged() {
        guard statePopup.indexOfSelectedItem >= 0 else { return }
        let newState = RevisionState.allCases[statePopup.indexOfSelectedItem]
        updateSceneWriterStatus(newState)
    }

    private func updateSceneWriterStatus(_ state: RevisionState) {
        sceneWriterStatusIcon.stringValue = state.icon
        sceneWriterStatusLabel.stringValue = state.rawValue
    }

    @objc private func copyToClipboard() {
        let sceneText = sceneWriterTextView.string

        // Get current status
        let statusIcon = sceneWriterStatusIcon.stringValue
        let statusLabel = sceneWriterStatusLabel.stringValue

        // Format: Status icon + label on first line, then scene text with page break
        let formattedText = "\(statusIcon) \(statusLabel)\n\n\(sceneText)\n\n---\n\n"

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(formattedText, forType: .string)
    }

    @objc private func saveSceneWriter() {
        // Save the scene writer content to the scene's notes or a dedicated field
        // For now, we'll just save it along with the scene
        saveScene()
    }

    private func addLabel(_ text: String, at point: NSPoint, in view: NSView) {
        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: point.x, y: point.y, width: 85, height: 20)
        label.alignment = .right
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = ThemeManager.shared.currentTheme.popoutSecondaryColor
        allLabels.append(label)
        view.addSubview(label)
    }

    private func applyCurrentTheme() {
        let theme = ThemeManager.shared.currentTheme
        guard let contentView = window?.contentView else { return }

        // Window background and appearance
        window?.backgroundColor = theme.popoutBackground
        let isDarkMode = ThemeManager.shared.isDarkMode
        window?.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = theme.popoutBackground.cgColor

        // Update all subviews recursively
        updateSubviewBackgrounds(contentView, theme: theme)

        // Text fields
        let fieldColor = theme.popoutTextColor
        sluglineField?.textColor = fieldColor
        sluglineField?.backgroundColor = theme.popoutBackground
        titleField?.textColor = fieldColor
        titleField?.backgroundColor = theme.popoutBackground
        summaryField?.textColor = fieldColor
        summaryField?.backgroundColor = theme.popoutBackground
        timeField?.textColor = fieldColor
        timeField?.backgroundColor = theme.popoutBackground
        charactersField?.textColor = fieldColor
        charactersField?.backgroundColor = theme.popoutBackground
        goalField?.textColor = fieldColor
        goalField?.backgroundColor = theme.popoutBackground
        conflictField?.textColor = fieldColor
        conflictField?.backgroundColor = theme.popoutBackground
        outcomeField?.textColor = fieldColor
        outcomeField?.backgroundColor = theme.popoutBackground
        povComboBox?.textColor = fieldColor
        locationComboBox?.textColor = fieldColor

        // Notes text view
        notesView?.textColor = fieldColor
        notesView?.backgroundColor = theme.popoutBackground

        // Scene writer text view
        sceneWriterTextView?.textColor = fieldColor
        sceneWriterTextView?.backgroundColor = theme.popoutBackground

        // Labels
        let labelColor = theme.popoutTextColor.withAlphaComponent(0.7)
        allLabels.forEach { $0.textColor = labelColor }
        dramaticHeaderLabel?.textColor = theme.popoutSecondaryColor
        sceneWriterTitleLabel?.textColor = theme.popoutTextColor
        sceneWriterStatusLabel?.textColor = theme.popoutSecondaryColor

        [saveButton, cancelButton, copyButton, saveWriterButton].forEach { button in
            guard let button else { return }
            styleActionButton(button, theme: theme)
        }

        intentPopup?.qpApplyDropdownBorder(theme: theme)
        statePopup?.qpApplyDropdownBorder(theme: theme)
    }

    private func styleActionButton(_ button: NSButton, theme: AppTheme) {
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.layer?.backgroundColor = theme.pageAround.cgColor
        button.layer?.borderWidth = 1
        button.layer?.borderColor = theme.pageBorder.cgColor
        button.contentTintColor = theme.textColor

        let title = button.title
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: theme.textColor
        ])
    }

    private func updateSubviewBackgrounds(_ view: NSView, theme: AppTheme) {
        view.wantsLayer = true
        // Set background for all container views but not for controls
        if !(view is NSButton) && !(view is NSTextField) && !(view is NSPopUpButton) &&
           !(view is NSTextView) && !(view is NSComboBox) && !(view is NSBox) {
            view.layer?.backgroundColor = theme.popoutBackground.cgColor
        }
        for subview in view.subviews {
            updateSubviewBackgrounds(subview, theme: theme)
        }
    }

    @objc private func saveScene() {
        guard var scene = currentScene else { return }

        scene.title = titleField.stringValue
        scene.summary = summaryField.stringValue
        scene.notes = notesView.string
        scene.pointOfView = povComboBox.stringValue
        scene.location = locationComboBox.stringValue
        scene.timeOfDay = timeField.stringValue
        scene.characters = charactersField.stringValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // Save location to history if not empty and not already saved
        if !scene.location.isEmpty {
            var savedLocations = UserDefaults.standard.stringArray(forKey: "QuillPilot.Scene.Locations") ?? []
            if !savedLocations.contains(scene.location) {
                savedLocations.append(scene.location)
                UserDefaults.standard.set(savedLocations, forKey: "QuillPilot.Scene.Locations")
            }
        }

        // Dramatic elements
        scene.goal = goalField.stringValue
        scene.conflict = conflictField.stringValue
        scene.outcome = outcomeField.stringValue

        if intentPopup.indexOfSelectedItem >= 0 {
            scene.intent = SceneIntent.allCases[intentPopup.indexOfSelectedItem]
        }
        if statePopup.indexOfSelectedItem >= 0 {
            scene.revisionState = RevisionState.allCases[statePopup.indexOfSelectedItem]
        }

        scene.touch()
        onSave?(scene)
        window?.close()
    }

    @objc private func cancelEdit() {
        window?.close()
    }
}
