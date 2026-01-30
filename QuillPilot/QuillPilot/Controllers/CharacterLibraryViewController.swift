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
    private var characterListHeaderLabel: NSTextField?
    private var characterListHeaderView: NSStackView?
    private var characterListAddButton: NSButton?
    private var detailSaveButton: NSButton?
    private var detailDeleteButton: NSButton?

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
    private var coreBeliefField: NSTextField!
    private var principlesField: NSTextView!
    private var skillsField: NSTextView!
    private var motivationsField: NSTextView!
    private var weaknessesField: NSTextView!
    private var connectionsField: NSTextView!
    private var quotesField: NSTextView!
    private var notesField: NSTextView!

    // Keep row widths aligned to the visible stack content area (stack bounds minus edgeInsets).
    private var detailContentWidthOffset: CGFloat {
        guard let stack = detailContentStack else { return 0 }
        return -(stack.edgeInsets.left + stack.edgeInsets.right)
    }

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
            DebugLog.log("📋 CharacterLibraryViewController: Received characterLibraryDidChange notification")
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
        DebugLog.log("⌨️ Cmd+S pressed in Character Library")

        // First, save the current character to the library
        if let character = selectedCharacter {
            saveCharacterFromFields(character)
            DebugLog.log("💾 Saved character to library: \(character.displayName)")
        }

        // Forward to the main window controller to save the document
        if let mainWindow = NSApp.windows.first(where: { $0.windowController is MainWindowController }),
           let mainController = mainWindow.windowController as? MainWindowController {
            DebugLog.log("💾 Forwarding save to main document")
            mainController.performSaveDocument(sender)
        } else {
            DebugLog.log("⚠️ Could not find main window controller to save document")
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
            splitContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            splitContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            splitContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            splitContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18),
            listPanel.widthAnchor.constraint(equalToConstant: 220),
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
        header.edgeInsets = NSEdgeInsets(top: 8, left: 18, bottom: 8, right: 12)
        header.wantsLayer = true
        header.layer?.backgroundColor = currentTheme.pageAround.cgColor
        header.layer?.cornerRadius = 8
        header.layer?.masksToBounds = true
        header.layer?.borderWidth = 1
        header.layer?.borderColor = currentTheme.pageBorder.cgColor

        let titleLabel = NSTextField(labelWithString: "📚 Characters")
        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.textColor = currentTheme.textColor
        header.addArrangedSubview(titleLabel)
        characterListHeaderLabel = titleLabel
        characterListHeaderView = header

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        header.addArrangedSubview(spacer)

        let addButton = NSButton(title: "+", target: self, action: #selector(addCharacterTapped))
        addButton.bezelStyle = .rounded
        addButton.font = .boldSystemFont(ofSize: 14)
        addButton.toolTip = "Add New Character"
        header.addArrangedSubview(addButton)
        characterListAddButton = addButton

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
        detailContentStack.spacing = 24
        // Extra right padding so fields don't run to the edge.
        detailContentStack.edgeInsets = NSEdgeInsets(top: 34, left: 34, bottom: 34, right: 64)

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
        placeholder.textColor = currentTheme.popoutSecondaryColor
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
        DebugLog.log("📜 Scrolling character list to top")
        DispatchQueue.main.async { [weak self] in
            guard let scrollView = self?.scrollView else {
                DebugLog.log("⚠️ scrollView is nil")
                return
            }
            scrollView.contentView.setBoundsOrigin(.zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            DebugLog.log("✅ Character list scrolled to top")
        }
    }

    private func scrollDetailToTop() {
        DebugLog.log("📜 Scrolling detail view to top")
        DispatchQueue.main.async { [weak self] in
            guard let detailScrollView = self?.detailScrollView else {
                DebugLog.log("⚠️ detailScrollView is nil")
                return
            }
            detailScrollView.contentView.setBoundsOrigin(.zero)
            detailScrollView.reflectScrolledClipView(detailScrollView.contentView)
            DebugLog.log("✅ Detail view scrolled to top")
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
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        headerStack.addArrangedSubview(titleLabel)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        headerStack.addArrangedSubview(spacer)

        let saveButton = NSButton(title: "Save Changes", target: self, action: #selector(saveCharacterTapped))
        saveButton.bezelStyle = .rounded
        saveButton.controlSize = .small
        saveButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        headerStack.addArrangedSubview(saveButton)
        detailSaveButton = saveButton

        let deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteCharacterTapped))
        deleteButton.bezelStyle = .rounded
        deleteButton.controlSize = .small
        deleteButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        headerStack.addArrangedSubview(deleteButton)
        detailDeleteButton = deleteButton

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
        coreBeliefField = addTextField("Core Belief", value: character.coreBelief)
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

        NSLayoutConstraint.activate([
            headerStack.widthAnchor.constraint(equalTo: detailContentStack.widthAnchor, constant: detailContentWidthOffset)
        ])

        applyFieldTheme()
    }

    private func addSection(_ title: String) {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        detailContentStack.addArrangedSubview(spacer)

        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: 13)
        label.textColor = currentTheme.popoutSecondaryColor
        detailContentStack.addArrangedSubview(label)

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        detailContentStack.addArrangedSubview(divider)
        divider.widthAnchor.constraint(equalTo: detailContentStack.widthAnchor, constant: detailContentWidthOffset).isActive = true
    }

    private func addTextField(_ label: String, value: String) -> NSTextField {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 12
        container.alignment = .centerY
        container.distribution = .fill
        container.translatesAutoresizingMaskIntoConstraints = false
        container.edgeInsets = NSEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)

        let labelView = NSTextField(labelWithString: label + ":")
        labelView.font = .systemFont(ofSize: 12)
        labelView.textColor = currentTheme.popoutSecondaryColor
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.widthAnchor.constraint(equalToConstant: 140).isActive = true
        container.addArrangedSubview(labelView)

        let textField = NSTextField(string: value)
        textField.font = .systemFont(ofSize: 12)
        textField.isEditable = true
        textField.isBezeled = false
        textField.isBordered = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        textField.heightAnchor.constraint(equalToConstant: 28).isActive = true
        textField.textColor = currentTheme.textColor
        textField.backgroundColor = currentTheme.pageBackground
        textField.drawsBackground = true
        textField.focusRingType = .none
        textField.wantsLayer = true
        textField.layer?.borderWidth = 1
        textField.layer?.cornerRadius = 4
        textField.layer?.borderColor = currentTheme.pageBorder.cgColor
        container.addArrangedSubview(textField)

        detailContentStack.addArrangedSubview(container)
        container.widthAnchor.constraint(equalTo: detailContentStack.widthAnchor, constant: detailContentWidthOffset).isActive = true

        return textField
    }

    private func addTextArea(_ label: String, value: String, height: CGFloat) -> NSTextView {
        let labelView = NSTextField(labelWithString: label + ":")
        labelView.font = .systemFont(ofSize: 12)
        labelView.textColor = currentTheme.popoutSecondaryColor
        detailContentStack.addArrangedSubview(labelView)
        detailContentStack.setCustomSpacing(6, after: labelView)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.wantsLayer = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = currentTheme.pageBackground
        scrollView.layer?.borderWidth = 1
        scrollView.layer?.cornerRadius = 6
        scrollView.layer?.borderColor = currentTheme.pageBorder.cgColor
        scrollView.contentInsets = NSEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)

        let textView = NSTextView()
        textView.font = .systemFont(ofSize: 12)
        textView.string = value
        textView.isEditable = true
        textView.isRichText = false
        textView.textContainerInset = NSSize(width: 8, height: 6)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textColor = currentTheme.textColor
        textView.backgroundColor = currentTheme.pageBackground
        textView.insertionPointColor = currentTheme.insertionPointColor

        scrollView.documentView = textView
        detailContentStack.addArrangedSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.heightAnchor.constraint(equalToConstant: height),
            scrollView.widthAnchor.constraint(equalTo: detailContentStack.widthAnchor, constant: detailContentWidthOffset)
        ])

        return textView
    }

    private func addRolePopup(_ label: String, selected: CharacterRole) -> NSPopUpButton {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 12
        container.alignment = .centerY
        container.translatesAutoresizingMaskIntoConstraints = false

        let labelView = NSTextField(labelWithString: label + ":")
        labelView.font = .systemFont(ofSize: 12)
        labelView.textColor = currentTheme.popoutSecondaryColor
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.widthAnchor.constraint(equalToConstant: 140).isActive = true
        container.addArrangedSubview(labelView)

        let popup = NSPopUpButton()
        popup.translatesAutoresizingMaskIntoConstraints = false

        for role in CharacterRole.allCases {
            popup.addItem(withTitle: role.rawValue)
        }
        popup.selectItem(withTitle: selected.rawValue)
        popup.qpApplyDropdownBorder(theme: ThemeManager.shared.currentTheme)
        popup.focusRingType = .none

        container.addArrangedSubview(popup)
        detailContentStack.addArrangedSubview(container)
        container.widthAnchor.constraint(equalTo: detailContentStack.widthAnchor, constant: detailContentWidthOffset).isActive = true

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
        updatedChar.coreBelief = coreBeliefField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        var principles = principlesField.string
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !updatedChar.coreBelief.isEmpty {
            let coreLower = updatedChar.coreBelief.lowercased()
            let alreadyIncluded = principles.contains(where: { $0.lowercased() == coreLower })
            if !alreadyIncluded {
                principles.insert(updatedChar.coreBelief, at: 0)
            }
        }

        updatedChar.principles = principles
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

        // Show themed confirmation popup with logo
        showThemedSaveConfirmation(for: character)
    }

    private func showThemedSaveConfirmation(for character: CharacterProfile) {
        let theme = ThemeManager.shared.currentTheme
        let isDarkMode = ThemeManager.shared.isDarkMode

        // Create custom panel for themed alert
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = ""
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.backgroundColor = theme.popoutBackground
        panel.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        let contentView = NSView(frame: panel.contentView!.bounds)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = theme.popoutBackground.cgColor
        panel.contentView = contentView

        // Logo image
        let logoSize: CGFloat = 48
        let logoView = NSImageView(frame: NSRect(x: 20, y: contentView.bounds.height - logoSize - 20, width: logoSize, height: logoSize))
        if let feather = NSImage.quillPilotFeatherImage() {
            logoView.image = feather
        } else {
            logoView.image = NSApp.applicationIconImage
        }
        logoView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(logoView)

        // Title label
        let titleLabel = NSTextField(labelWithString: "Character Saved")
        titleLabel.frame = NSRect(x: 80, y: contentView.bounds.height - 45, width: 220, height: 24)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = theme.popoutTextColor
        contentView.addSubview(titleLabel)

        // Info label
        let infoLabel = NSTextField(labelWithString: "\(character.displayName) has been saved to your Character Library.")
        infoLabel.frame = NSRect(x: 80, y: contentView.bounds.height - 75, width: 220, height: 36)
        infoLabel.font = NSFont.systemFont(ofSize: 13)
        infoLabel.textColor = theme.popoutTextColor.withAlphaComponent(0.8)
        infoLabel.cell?.lineBreakMode = .byWordWrapping
        infoLabel.maximumNumberOfLines = 2
        contentView.addSubview(infoLabel)

        // Center and show
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        // Auto-close after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            panel.close()
        }
    }

    @objc private func deleteCharacterTapped() {
        guard let character = selectedCharacter else { return }

        showThemedConfirmation(
            title: "Delete Character?",
            message: "Are you sure you want to delete \(character.displayName)? This cannot be undone.",
            confirmTitle: "Delete",
            cancelTitle: "Cancel"
        ) { [weak self] confirmed in
            guard let self else { return }
            guard confirmed else { return }
            CharacterLibrary.shared.deleteCharacter(character)
            self.selectedCharacter = nil
            self.showPlaceholder()
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

        characterListHeaderView?.layer?.backgroundColor = theme.pageAround.cgColor
        characterListHeaderView?.layer?.borderWidth = 1
        characterListHeaderView?.layer?.borderColor = theme.pageBorder.cgColor
        characterListHeaderLabel?.textColor = theme.textColor
        if let add = characterListAddButton {
            styleActionButton(add, theme: theme, primary: false)
        }

        refreshCharacterList()
        if selectedCharacter != nil {
            showCharacterDetail()
        }

        applyFieldTheme()

        // Catch-all: borders for any editable controls outside the detail stack
        // (e.g., list header controls), so the window is consistent.
        applyThemeToEditableControls(in: view, theme: theme)
    }

    private func styleActionButton(_ button: NSButton, theme: AppTheme, primary: Bool) {
        button.wantsLayer = true
        button.isBordered = false
        button.focusRingType = .none
        button.layer?.cornerRadius = 8
        button.layer?.borderWidth = 1
        button.layer?.borderColor = theme.pageBorder.cgColor
        button.layer?.backgroundColor = (primary ? theme.pageBorder : theme.pageBackground).cgColor

        let titleColor: NSColor = primary ? .white : theme.textColor
        let font = button.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .foregroundColor: titleColor,
                .font: font
            ]
        )
    }

    private func styleTextAreaScrollView(_ scrollView: NSScrollView, theme: AppTheme) {
        // NSScrollView is sometimes finicky about rendering its own layer border.
        // Styling the clip view (contentView) is more reliable visually.
        scrollView.drawsBackground = true
        scrollView.backgroundColor = theme.pageBackground
        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = theme.pageBackground.cgColor
        scrollView.layer?.cornerRadius = 6
        scrollView.layer?.masksToBounds = false

        scrollView.contentView.wantsLayer = true
        scrollView.contentView.layer?.backgroundColor = theme.pageBackground.cgColor
        scrollView.contentView.layer?.borderWidth = 1
        scrollView.contentView.layer?.cornerRadius = 6
        scrollView.contentView.layer?.borderColor = theme.pageBorder.cgColor
        scrollView.contentView.layer?.masksToBounds = true
    }

    private func applyFieldTheme() {
        let theme = currentTheme

        let textFields: [NSTextField?] = [
            nameField,
            nicknameField,
            ageField,
            occupationField,
            educationField,
            residenceField,
            petsField
        ]

        for field in textFields {
            guard let field else { continue }
            field.textColor = theme.textColor
            field.backgroundColor = theme.pageBackground
            field.isBezeled = false
            field.isBordered = false
            field.drawsBackground = true
            field.focusRingType = .none
            field.wantsLayer = true
            field.layer?.borderWidth = 1
            field.layer?.cornerRadius = 4
            field.layer?.borderColor = theme.pageBorder.cgColor
        }

        rolePopup?.qpApplyDropdownBorder(theme: theme)

        let textAreas: [NSTextView?] = [
            appearanceField,
            backgroundField,
            familyField,
            traitsField,
            principlesField,
            skillsField,
            motivationsField,
            weaknessesField,
            connectionsField,
            quotesField,
            notesField
        ]

        for textView in textAreas {
            guard let textView else { continue }
            textView.textColor = theme.textColor
            textView.backgroundColor = theme.pageBackground
            textView.insertionPointColor = theme.insertionPointColor
            if let scrollView = textView.enclosingScrollView {
                styleTextAreaScrollView(scrollView, theme: theme)
            } else {
                textView.wantsLayer = true
                textView.layer?.borderWidth = 1
                textView.layer?.cornerRadius = 6
                textView.layer?.borderColor = theme.pageBorder.cgColor
            }
        }

        // Catch-all: ensure EVERY editable control in the detail panel is themed.
        // This prevents "some fields have borders, others don't" when controls are
        // created/recreated or not referenced by stored properties.
        if let root = detailContentStack {
            applyThemeToEditableControls(in: root, theme: theme)
        }

        if let save = detailSaveButton {
            styleActionButton(save, theme: theme, primary: false)
        }
        if let del = detailDeleteButton {
            styleActionButton(del, theme: theme, primary: true)
        }
    }

    private func applyThemeToEditableControls(in root: NSView, theme: AppTheme) {
        // NSTextField (editable inputs)
        if let field = root as? NSTextField, field.isEditable {
            field.textColor = theme.textColor
            field.backgroundColor = theme.pageBackground
            field.isBezeled = false
            field.isBordered = false
            field.drawsBackground = true
            field.focusRingType = .none
            field.wantsLayer = true
            field.layer?.borderWidth = 1
            field.layer?.cornerRadius = 4
            field.layer?.borderColor = theme.pageBorder.cgColor
        }

        // Dropdowns
        if let popup = root as? NSPopUpButton {
            popup.qpApplyDropdownBorder(theme: theme)
            popup.focusRingType = .none
        }

        // Text areas (NSTextView typically inside an NSScrollView)
        if let scrollView = root as? NSScrollView,
           let textView = scrollView.documentView as? NSTextView {
            textView.textColor = theme.textColor
            textView.backgroundColor = theme.pageBackground
            textView.insertionPointColor = theme.insertionPointColor

            styleTextAreaScrollView(scrollView, theme: theme)
        }

        for subview in root.subviews {
            applyThemeToEditableControls(in: subview, theme: theme)
        }
    }

    private func updateAllSubviewBackgrounds(_ view: NSView, theme: AppTheme) {
        // Avoid painting empty spacer views (they create odd "boxes" in layouts).
        if !view.subviews.isEmpty {
            view.wantsLayer = true
            // Set background for containers but not for controls like buttons
            if !(view is NSButton) && !(view is NSTextField) && !(view is NSPopUpButton) && !(view is NSTextView) {
                view.layer?.backgroundColor = theme.popoutBackground.cgColor
            }
        }
        for subview in view.subviews {
            updateAllSubviewBackgrounds(subview, theme: theme)
        }
    }
}
