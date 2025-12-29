//
//  CharacterLibraryViewController.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class CharacterLibraryViewController: NSViewController {

    private var scrollView: NSScrollView!
    private var contentStack: NSStackView!
    private var characterListStack: NSStackView!
    private var detailView: NSView!
    private var currentTheme: AppTheme = ThemeManager.shared.currentTheme
    private var selectedCharacter: CharacterProfile?
    private var isEditing = false

    // Detail view controls
    private var detailScrollView: NSScrollView!
    private var detailContentStack: NSStackView!
    private var nameField: NSTextField!
    private var nicknameField: NSTextField!
    private var rolePopup: NSPopUpButton!
    private var ageField: NSTextField!
    private var occupationField: NSTextField!
    private var appearanceField: NSTextView!
    private var backgroundField: NSTextView!
    private var educationField: NSTextField!
    private var residenceField: NSTextField!
    private var familyField: NSTextView!
    private var petsField: NSTextField!
    private var traitsField: NSTextView!
    private var principlesField: NSTextView!
    private var skillsField: NSTextView!
    private var motivationsField: NSTextView!
    private var weaknessesField: NSTextView!
    private var connectionsField: NSTextView!
    private var quotesField: NSTextView!
    private var notesField: NSTextView!

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        applyTheme(currentTheme)
        refreshCharacterList()

        // Put the view controller into the responder chain so menu commands (e.g., Cmd+S) reach it
        view.nextResponder = self

        NotificationCenter.default.addObserver(forName: .characterLibraryDidChange, object: nil, queue: .main) { [weak self] _ in
            NSLog("📋 CharacterLibraryViewController: Received characterLibraryDidChange notification")
            self?.refreshCharacterList()
        }

        NotificationCenter.default.addObserver(forName: .themeDidChange, object: nil, queue: .main) { [weak self] notification in
            if let theme = notification.object as? AppTheme {
                self?.applyTheme(theme)
            }
        }
    }

    // MARK: - Responder Chain for Cmd+S

    override var acceptsFirstResponder: Bool { true }

    @objc func saveDocument(_ sender: Any?) {
        // Bridge the standard Save menu action to our custom handler
        performSave(sender)
    }

    @objc func performSave(_ sender: Any?) {
        NSLog("⌨️ Cmd+S pressed in Character Library")

        // First, save the current character to the library
        if let character = selectedCharacter {
            saveCharacterFromFields(character)
            NSLog("💾 Saved character to library: \(character.displayName)")
        }

        // Then trigger the main document save by forwarding to whatever NSDocument is active
        let candidateDocuments: [NSDocument?] = [
            NSApp.keyWindow?.windowController?.document as? NSDocument,
            NSApp.mainWindow?.windowController?.document as? NSDocument
        ] + NSApp.windows.compactMap { $0.windowController?.document as? NSDocument }

        if let document = candidateDocuments.compactMap({ $0 }).first {
            NSLog("💾 Forwarding save to main document: \(String(describing: type(of: document)))")
            document.save(sender)
        } else {
            NSLog("⚠️ Could not find any open document to save")
        }
    }

    override func keyDown(with event: NSEvent) {
        // Capture Cmd+S even when a text field is first responder
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "s" {
            performSave(event)
            return
        }
        super.keyDown(with: event)
    }

    private func setupUI() {
        // Set initial view background
        view.layer?.backgroundColor = currentTheme.popoutBackground.cgColor

        let splitContainer = NSStackView()
        splitContainer.translatesAutoresizingMaskIntoConstraints = false
        splitContainer.orientation = .horizontal
        splitContainer.spacing = 1
        splitContainer.distribution = .fill
        splitContainer.wantsLayer = true
        splitContainer.layer?.backgroundColor = currentTheme.popoutBackground.cgColor
        view.addSubview(splitContainer)

        let listPanel = createCharacterListPanel()
        listPanel.translatesAutoresizingMaskIntoConstraints = false
        splitContainer.addArrangedSubview(listPanel)

        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = currentTheme.popoutSecondaryColor.withAlphaComponent(0.3).cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        splitContainer.addArrangedSubview(separator)

        let detailView = createDetailPanel()
        detailView.translatesAutoresizingMaskIntoConstraints = false
        splitContainer.addArrangedSubview(detailView)

        NSLayoutConstraint.activate([
            splitContainer.topAnchor.constraint(equalTo: view.topAnchor),
            splitContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            listPanel.widthAnchor.constraint(equalToConstant: 200),
            separator.widthAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func createCharacterListPanel() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.popoutBackground.cgColor

        let header = NSStackView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.orientation = .horizontal
        header.spacing = 8
        header.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        let titleLabel = NSTextField(labelWithString: "📚 Characters")
        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.textColor = currentTheme.popoutTextColor
        header.addArrangedSubview(titleLabel)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        header.addArrangedSubview(spacer)

        let addButton = NSButton(title: "+", target: self, action: #selector(addCharacterTapped))
        addButton.bezelStyle = .rounded
        addButton.font = .boldSystemFont(ofSize: 14)
        addButton.toolTip = "Add New Character"
        header.addArrangedSubview(addButton)

        container.addSubview(header)

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        characterListStack = NSStackView()
        characterListStack.translatesAutoresizingMaskIntoConstraints = false
        characterListStack.orientation = .vertical
        characterListStack.alignment = .leading
        characterListStack.spacing = 4
        characterListStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Use a flipped document view so content starts at top
        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(characterListStack)

        scrollView.documentView = documentView
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 40),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            characterListStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            characterListStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            characterListStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            characterListStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])

        return container
    }

    private func createDetailPanel() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.popoutBackground.cgColor

        detailScrollView = NSScrollView()
        detailScrollView.translatesAutoresizingMaskIntoConstraints = false
        detailScrollView.hasVerticalScroller = true
        detailScrollView.hasHorizontalScroller = false
        detailScrollView.autohidesScrollers = true
        detailScrollView.borderType = .noBorder
        detailScrollView.drawsBackground = false

        detailContentStack = NSStackView()
        detailContentStack.translatesAutoresizingMaskIntoConstraints = false
        detailContentStack.orientation = .vertical
        detailContentStack.alignment = .leading
        detailContentStack.spacing = 16
        detailContentStack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        // Use a flipped document view so content starts at top
        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(detailContentStack)

        detailScrollView.documentView = documentView
        container.addSubview(detailScrollView)

        NSLayoutConstraint.activate([
            detailScrollView.topAnchor.constraint(equalTo: container.topAnchor),
            detailScrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            detailScrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            detailScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            detailContentStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            detailContentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            detailContentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            detailContentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: detailScrollView.contentView.widthAnchor)
        ])

        showPlaceholder()
        return container
    }

    private func showPlaceholder() {
        detailContentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let placeholder = NSTextField(labelWithString: "Select a character to view details\nor click + to create a new one")
        placeholder.alignment = .center
        placeholder.textColor = .secondaryLabelColor
        placeholder.font = .systemFont(ofSize: 14)
        placeholder.maximumNumberOfLines = 0
        placeholder.lineBreakMode = .byWordWrapping
        detailContentStack.addArrangedSubview(placeholder)
    }

    private func refreshCharacterList() {
        characterListStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let characters = CharacterLibrary.shared.characters
        let roleOrder: [CharacterRole] = [.protagonist, .antagonist, .supporting, .minor]

        for role in roleOrder {
            let chars = characters.filter { $0.role == role }
            guard !chars.isEmpty else { continue }

            let roleHeader = NSTextField(labelWithString: role.rawValue)
            roleHeader.font = NSFont.boldSystemFont(ofSize: 11)
            roleHeader.textColor = role.color
            roleHeader.translatesAutoresizingMaskIntoConstraints = false
            characterListStack.addArrangedSubview(roleHeader)

            for character in chars {
                let button = createCharacterButton(for: character)
                characterListStack.addArrangedSubview(button)
            }

            let spacer = NSView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
            characterListStack.addArrangedSubview(spacer)
        }
    }

    private func createCharacterButton(for character: CharacterProfile) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.cornerRadius = 6

        let isSelected = selectedCharacter?.id == character.id
        container.layer?.backgroundColor = isSelected
            ? currentTheme.headerBackground.withAlphaComponent(0.3).cgColor
            : NSColor.clear.cgColor

        let button = NSButton(title: "", target: self, action: #selector(characterTapped(_:)))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.alignment = .left
        button.tag = CharacterLibrary.shared.characters.firstIndex(where: { $0.id == character.id }) ?? 0

        let displayName = character.fullName.isEmpty ? "New Character" : character.fullName
        let attrTitle = NSMutableAttributedString(string: "● ", attributes: [
            .foregroundColor: character.role.color,
            .font: NSFont.systemFont(ofSize: 8)
        ])
        attrTitle.append(NSAttributedString(string: displayName, attributes: [
            .foregroundColor: currentTheme.textColor,
            .font: NSFont.systemFont(ofSize: 12)
        ]))
        button.attributedTitle = attrTitle

        container.addSubview(button)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            container.heightAnchor.constraint(equalToConstant: 28),
            container.widthAnchor.constraint(equalToConstant: 180)
        ])

        return container
    }

    @objc private func characterTapped(_ sender: NSButton) {
        let characters = CharacterLibrary.shared.characters
        guard sender.tag < characters.count else { return }
        let character = characters[sender.tag]

        let isDoubleClick = (NSApp.currentEvent?.clickCount ?? 1) >= 2

        selectedCharacter = character

        refreshCharacterList()
        showCharacterDetail()

        // Scroll detail view to top when selecting a character
        scrollDetailToTop()

        // On double-click, also snap the list to the top so the selection is visible immediately
        if isDoubleClick {
            scrollListToTop()
        }
    }

    @objc private func addCharacterTapped() {
        let newCharacter = CharacterLibrary.shared.createNewCharacter()
        CharacterLibrary.shared.addCharacter(newCharacter)
        selectedCharacter = newCharacter
        refreshCharacterList()
        showCharacterDetail()

        // Scroll character list to top to show the newly added character
        scrollListToTop()
        scrollDetailToTop()
    }

    private func scrollListToTop() {
        NSLog("📜 Scrolling character list to top")
        DispatchQueue.main.async { [weak self] in
            guard let scrollView = self?.scrollView else {
                NSLog("⚠️ scrollView is nil")
                return
            }
            scrollView.contentView.setBoundsOrigin(.zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            NSLog("✅ Character list scrolled to top")
        }
    }

    private func scrollDetailToTop() {
        NSLog("📜 Scrolling detail view to top")
        DispatchQueue.main.async { [weak self] in
            guard let detailScrollView = self?.detailScrollView else {
                NSLog("⚠️ detailScrollView is nil")
                return
            }
            detailScrollView.contentView.setBoundsOrigin(.zero)
            detailScrollView.reflectScrolledClipView(detailScrollView.contentView)
            NSLog("✅ Detail view scrolled to top")
        }
    }

    func saveCurrentCharacter() {
        // If we have a selected character and fields are populated, save it
        if let character = selectedCharacter {
            saveCharacterFromFields(character)
        }
    }

    private func showCharacterDetail() {
        guard let character = selectedCharacter else {
            showPlaceholder()
            return
        }

        detailContentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .centerY
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: character.displayName.isEmpty ? "New Character" : character.displayName)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = character.role.color
        headerStack.addArrangedSubview(titleLabel)

        let spacer = NSView()
        headerStack.addArrangedSubview(spacer)

        let deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteCharacterTapped))
        deleteButton.bezelStyle = .rounded
        deleteButton.controlSize = .small
        headerStack.addArrangedSubview(deleteButton)

        detailContentStack.addArrangedSubview(headerStack)

        addSection("Basic Info")
        nameField = addTextField("Full Name", value: character.fullName)
        nicknameField = addTextField("Nickname", value: character.nickname)
        rolePopup = addRolePopup("Role", selected: character.role)
        ageField = addTextField("Age", value: character.age)
        occupationField = addTextField("Occupation", value: character.occupation)

        addSection("Physical & Living")
        appearanceField = addTextArea("Appearance", value: character.appearance, height: 60)
        residenceField = addTextField("Residence", value: character.residence)
        petsField = addTextField("Pets", value: character.pets)

        addSection("Background")
        backgroundField = addTextArea("Background Story", value: character.background, height: 100)
        educationField = addTextField("Education", value: character.education)
        familyField = addTextArea("Family", value: character.family, height: 60)

        addSection("Personality")
        traitsField = addTextArea("Personality Traits (one per line)", value: character.personalityTraits.joined(separator: "\n"), height: 80)
        principlesField = addTextArea("Principles / Beliefs (one per line)", value: character.principles.joined(separator: "\n"), height: 80)

        addSection("Abilities")
        skillsField = addTextArea("Skills (one per line)", value: character.skills.joined(separator: "\n"), height: 100)

        addSection("Motivation & Conflict")
        motivationsField = addTextArea("Motivations", value: character.motivations, height: 60)
        weaknessesField = addTextArea("Weaknesses", value: character.weaknesses, height: 60)
        connectionsField = addTextArea("Connections / Relationships", value: character.connections, height: 60)

        addSection("Voice")
        quotesField = addTextArea("Characteristic Quotes (one per line)", value: character.quotes.joined(separator: "\n"), height: 80)

        addSection("Notes")
        notesField = addTextArea("Additional Notes", value: character.notes, height: 80)

        let saveButton = NSButton(title: "Save Changes", target: self, action: #selector(saveCharacterTapped))
        saveButton.bezelStyle = .rounded
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        detailContentStack.addArrangedSubview(saveButton)

        NSLayoutConstraint.activate([
            headerStack.widthAnchor.constraint(equalTo: detailContentStack.widthAnchor, constant: -32)
        ])
    }

    private func addSection(_ title: String) {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        detailContentStack.addArrangedSubview(spacer)

        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: 13)
        label.textColor = currentTheme.headerBackground
        detailContentStack.addArrangedSubview(label)

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        detailContentStack.addArrangedSubview(divider)
        divider.widthAnchor.constraint(equalTo: detailContentStack.widthAnchor, constant: -32).isActive = true
    }

    private func addTextField(_ label: String, value: String) -> NSTextField {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 8
        container.alignment = .centerY
        container.translatesAutoresizingMaskIntoConstraints = false

        let labelView = NSTextField(labelWithString: label + ":")
        labelView.font = .systemFont(ofSize: 12)
        labelView.textColor = currentTheme.popoutSecondaryColor
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.widthAnchor.constraint(equalToConstant: 120).isActive = true
        container.addArrangedSubview(labelView)

        let textField = NSTextField(string: value)
        textField.font = .systemFont(ofSize: 12)
        textField.isEditable = true
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(textField)

        detailContentStack.addArrangedSubview(container)
        container.widthAnchor.constraint(equalTo: detailContentStack.widthAnchor, constant: -32).isActive = true

        return textField
    }

    private func addTextArea(_ label: String, value: String, height: CGFloat) -> NSTextView {
        let labelView = NSTextField(labelWithString: label + ":")
        labelView.font = .systemFont(ofSize: 12)
        labelView.textColor = currentTheme.popoutSecondaryColor
        detailContentStack.addArrangedSubview(labelView)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.font = .systemFont(ofSize: 12)
        textView.string = value
        textView.isEditable = true
        textView.isRichText = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        detailContentStack.addArrangedSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.heightAnchor.constraint(equalToConstant: height),
            scrollView.widthAnchor.constraint(equalTo: detailContentStack.widthAnchor, constant: -32)
        ])

        return textView
    }

    private func addRolePopup(_ label: String, selected: CharacterRole) -> NSPopUpButton {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 8
        container.alignment = .centerY
        container.translatesAutoresizingMaskIntoConstraints = false

        let labelView = NSTextField(labelWithString: label + ":")
        labelView.font = .systemFont(ofSize: 12)
        labelView.textColor = currentTheme.popoutSecondaryColor
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.widthAnchor.constraint(equalToConstant: 120).isActive = true
        container.addArrangedSubview(labelView)

        let popup = NSPopUpButton()
        popup.translatesAutoresizingMaskIntoConstraints = false

        for role in CharacterRole.allCases {
            popup.addItem(withTitle: role.rawValue)
        }
        popup.selectItem(withTitle: selected.rawValue)

        container.addArrangedSubview(popup)
        detailContentStack.addArrangedSubview(container)
        container.widthAnchor.constraint(equalTo: detailContentStack.widthAnchor, constant: -32).isActive = true

        return popup
    }

    private func saveCharacterFromFields(_ character: CharacterProfile) {
        guard var updatedChar = selectedCharacter else { return }

        updatedChar.fullName = nameField.stringValue
        updatedChar.nickname = nicknameField.stringValue
        updatedChar.role = CharacterRole.allCases.first { $0.rawValue == rolePopup.titleOfSelectedItem } ?? .supporting
        updatedChar.age = ageField.stringValue
        updatedChar.occupation = occupationField.stringValue
        updatedChar.appearance = appearanceField.string
        updatedChar.residence = residenceField.stringValue
        updatedChar.pets = petsField.stringValue
        updatedChar.background = backgroundField.string
        updatedChar.education = educationField.stringValue
        updatedChar.family = familyField.string
        updatedChar.personalityTraits = traitsField.string.components(separatedBy: "\n").filter { !$0.isEmpty }
        updatedChar.principles = principlesField.string.components(separatedBy: "\n").filter { !$0.isEmpty }
        updatedChar.skills = skillsField.string.components(separatedBy: "\n").filter { !$0.isEmpty }
        updatedChar.motivations = motivationsField.string
        updatedChar.weaknesses = weaknessesField.string
        updatedChar.connections = connectionsField.string
        updatedChar.quotes = quotesField.string.components(separatedBy: "\n").filter { !$0.isEmpty }
        updatedChar.notes = notesField.string
        updatedChar.isSampleCharacter = false

        CharacterLibrary.shared.updateCharacter(updatedChar)
        selectedCharacter = updatedChar
    }

    @objc private func saveCharacterTapped() {
        guard let character = selectedCharacter else { return }

        saveCharacterFromFields(character)

        let alert = NSAlert()
        alert.messageText = "Character Saved"
        alert.informativeText = "\(character.displayName) has been saved to your Character Library."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func deleteCharacterTapped() {
        guard let character = selectedCharacter else { return }

        let alert = NSAlert()
        alert.messageText = "Delete Character?"
        alert.informativeText = "Are you sure you want to delete \(character.displayName)? This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            CharacterLibrary.shared.deleteCharacter(character)
            selectedCharacter = nil
            showPlaceholder()
        }
    }

    func applyTheme(_ theme: AppTheme) {
        currentTheme = theme
        view.layer?.backgroundColor = theme.popoutBackground.cgColor

        // Recursively update all subview backgrounds
        updateAllSubviewBackgrounds(view, theme: theme)

        scrollView?.drawsBackground = false
        scrollView?.backgroundColor = theme.popoutBackground
        detailScrollView?.drawsBackground = false
        detailScrollView?.backgroundColor = theme.popoutBackground

        // Update scroll view backgrounds
        if let docView = scrollView?.documentView {
            docView.wantsLayer = true
            docView.layer?.backgroundColor = theme.popoutBackground.cgColor
        }
        if let detailDocView = detailScrollView?.documentView {
            detailDocView.wantsLayer = true
            detailDocView.layer?.backgroundColor = theme.popoutBackground.cgColor
        }

        refreshCharacterList()
        if selectedCharacter != nil {
            showCharacterDetail()
        }
    }

    private func updateAllSubviewBackgrounds(_ view: NSView, theme: AppTheme) {
        view.wantsLayer = true
        // Set background for containers but not for controls like buttons
        if !(view is NSButton) && !(view is NSTextField) && !(view is NSPopUpButton) && !(view is NSTextView) {
            view.layer?.backgroundColor = theme.popoutBackground.cgColor
        }
        for subview in view.subviews {
            updateAllSubviewBackgrounds(subview, theme: theme)
        }
    }
}
