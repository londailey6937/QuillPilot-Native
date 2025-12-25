import Cocoa

// MARK: - Scene Inspector Window Controller
/// Displays and edits metadata for a single scene.
/// IMPORTANT: This window only manages metadata - it NEVER accesses the editor.
final class SceneInspectorWindowController: NSWindowController {

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

    private var currentScene: Scene?
    private var onSave: ((Scene) -> Void)?

    // Store labels for theme updates
    private var allLabels: [NSTextField] = []

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Scene Inspector"
        window.minSize = NSSize(width: 380, height: 500)
        window.isReleasedWhenClosed = false

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

    func loadScene(_ scene: Scene, onSave: @escaping (Scene) -> Void) {
        self.currentScene = scene
        self.onSave = onSave

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

        let contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView

        var y: CGFloat = contentView.bounds.height - 40
        let fieldX: CGFloat = 100
        let fieldWidth: CGFloat = contentView.bounds.width - fieldX - 20
        let rowHeight: CGFloat = 28
        let spacing: CGFloat = 8

        // Title
        addLabel("Title:", at: NSPoint(x: 10, y: y), in: contentView)
        titleField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 24))
        titleField.autoresizingMask = [.width]
        titleField.placeholderString = "Scene title"
        contentView.addSubview(titleField)
        y -= rowHeight + spacing

        // Intent
        addLabel("Intent:", at: NSPoint(x: 10, y: y), in: contentView)
        intentPopup = NSPopUpButton(frame: NSRect(x: fieldX, y: y - 2, width: 150, height: 26))
        for intent in SceneIntent.allCases {
            intentPopup.addItem(withTitle: intent.rawValue)
        }
        contentView.addSubview(intentPopup)
        y -= rowHeight + spacing

        // Revision State
        addLabel("Status:", at: NSPoint(x: 10, y: y), in: contentView)
        statePopup = NSPopUpButton(frame: NSRect(x: fieldX, y: y - 2, width: 150, height: 26))
        for state in RevisionState.allCases {
            statePopup.addItem(withTitle: "\(state.icon) \(state.rawValue)")
        }
        contentView.addSubview(statePopup)
        y -= rowHeight + spacing

        // POV - Connected to Character Library
        addLabel("POV:", at: NSPoint(x: 10, y: y), in: contentView)
        povComboBox = NSComboBox(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 26))
        povComboBox.autoresizingMask = [.width]
        povComboBox.placeholderString = "Point of view character"
        povComboBox.completes = true
        // Populate with characters from Character Library
        let characterNames = CharacterLibrary.shared.characters.map { $0.fullName }
        povComboBox.addItems(withObjectValues: characterNames)
        contentView.addSubview(povComboBox)
        y -= rowHeight + spacing

        // Location - Editable dropdown with previously used locations
        addLabel("Location:", at: NSPoint(x: 10, y: y), in: contentView)
        locationComboBox = NSComboBox(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 26))
        locationComboBox.autoresizingMask = [.width]
        locationComboBox.placeholderString = "Where the scene takes place"
        locationComboBox.completes = true
        // Populate with previously used locations from UserDefaults
        if let savedLocations = UserDefaults.standard.stringArray(forKey: "QuillPilot.Scene.Locations") {
            locationComboBox.addItems(withObjectValues: savedLocations)
        }
        contentView.addSubview(locationComboBox)
        y -= rowHeight + spacing

        // Time
        addLabel("Time:", at: NSPoint(x: 10, y: y), in: contentView)
        timeField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 24))
        timeField.autoresizingMask = [.width]
        timeField.placeholderString = "Time of day or period"
        contentView.addSubview(timeField)
        y -= rowHeight + spacing

        // Characters
        addLabel("Characters:", at: NSPoint(x: 10, y: y), in: contentView)
        charactersField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 24))
        charactersField.autoresizingMask = [.width]
        charactersField.placeholderString = "Character names (comma separated)"
        contentView.addSubview(charactersField)
        y -= rowHeight + spacing + 10

        // Separator line
        let separator1 = NSBox(frame: NSRect(x: 10, y: y + 4, width: contentView.bounds.width - 20, height: 1))
        separator1.boxType = .separator
        separator1.autoresizingMask = [.width]
        contentView.addSubview(separator1)
        y -= 10

        // Section header: Dramatic Elements
        let dramaticHeader = NSTextField(labelWithString: "Dramatic Elements")
        dramaticHeader.frame = NSRect(x: 10, y: y, width: 200, height: 18)
        dramaticHeader.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        dramaticHeader.textColor = NSColor.secondaryLabelColor
        contentView.addSubview(dramaticHeader)
        y -= rowHeight

        // Goal
        addLabel("Goal:", at: NSPoint(x: 10, y: y), in: contentView)
        goalField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 24))
        goalField.autoresizingMask = [.width]
        goalField.placeholderString = "What does the POV character want?"
        contentView.addSubview(goalField)
        y -= rowHeight + spacing

        // Conflict
        addLabel("Conflict:", at: NSPoint(x: 10, y: y), in: contentView)
        conflictField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 24))
        conflictField.autoresizingMask = [.width]
        conflictField.placeholderString = "What opposes the goal?"
        contentView.addSubview(conflictField)
        y -= rowHeight + spacing

        // Outcome
        addLabel("Outcome:", at: NSPoint(x: 10, y: y), in: contentView)
        outcomeField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 24))
        outcomeField.autoresizingMask = [.width]
        outcomeField.placeholderString = "Success / Failure / Complication"
        contentView.addSubview(outcomeField)
        y -= rowHeight + spacing + 10

        // Separator line
        let separator2 = NSBox(frame: NSRect(x: 10, y: y + 4, width: contentView.bounds.width - 20, height: 1))
        separator2.boxType = .separator
        separator2.autoresizingMask = [.width]
        contentView.addSubview(separator2)
        y -= 10

        // Summary
        addLabel("Summary:", at: NSPoint(x: 10, y: y), in: contentView)
        summaryField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 24))
        summaryField.autoresizingMask = [.width]
        summaryField.placeholderString = "Brief summary of scene"
        contentView.addSubview(summaryField)
        y -= rowHeight + spacing + 10

        // Notes label
        addLabel("Notes:", at: NSPoint(x: 10, y: y), in: contentView)
        y -= 20

        // Notes text view
        let notesScrollView = NSScrollView(frame: NSRect(x: 10, y: 60, width: contentView.bounds.width - 20, height: y - 50))
        notesScrollView.autoresizingMask = [.width, .height]
        notesScrollView.hasVerticalScroller = true
        notesScrollView.borderType = .bezelBorder

        notesView = NSTextView(frame: notesScrollView.bounds)
        notesView.autoresizingMask = [.width, .height]
        notesView.isRichText = false
        notesView.font = NSFont.systemFont(ofSize: 13)
        notesView.textContainerInset = NSSize(width: 5, height: 5)
        notesScrollView.documentView = notesView
        contentView.addSubview(notesScrollView)

        // Save button
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveScene))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: contentView.bounds.width - 90, y: 15, width: 80, height: 32)
        saveButton.autoresizingMask = [.minXMargin]
        contentView.addSubview(saveButton)

        // Cancel button
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelEdit))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.frame = NSRect(x: contentView.bounds.width - 180, y: 15, width: 80, height: 32)
        cancelButton.autoresizingMask = [.minXMargin]
        contentView.addSubview(cancelButton)
    }

    private func addLabel(_ text: String, at point: NSPoint, in view: NSView) {
        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: point.x, y: point.y, width: 85, height: 20)
        label.alignment = .right
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = NSColor.secondaryLabelColor
        allLabels.append(label)
        view.addSubview(label)
    }

    private func applyCurrentTheme() {
        let theme = ThemeManager.shared.currentTheme
        guard let contentView = window?.contentView else { return }

        // Window background
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = theme.pageBackground.cgColor

        // Text fields
        let fieldColor = theme.textColor
        titleField?.textColor = fieldColor
        summaryField?.textColor = fieldColor
        timeField?.textColor = fieldColor
        charactersField?.textColor = fieldColor
        goalField?.textColor = fieldColor
        conflictField?.textColor = fieldColor
        outcomeField?.textColor = fieldColor
        povComboBox?.textColor = fieldColor
        locationComboBox?.textColor = fieldColor

        // Notes text view
        notesView?.textColor = fieldColor
        notesView?.backgroundColor = theme.pageBackground

        // Labels
        let labelColor = theme.textColor.withAlphaComponent(0.7)
        allLabels.forEach { $0.textColor = labelColor }
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
