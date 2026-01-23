//
//  BookmarkCrossReferenceWindows.swift
//  QuillPilot
//
//  UI dialogs for inserting bookmarks and cross-references.
//

import Cocoa

// MARK: - Insert Bookmark Dialog

@MainActor
class InsertBookmarkWindowController: NSWindowController {

    private var nameField: NSTextField!
    private var existingBookmarksList: NSTableView!
    private var bookmarks: [BookmarkTarget] = []
    private var scrollView: NSScrollView!
    private var addButton: NSButton!
    private var deleteButton: NSButton!
    private var goToButton: NSButton!
    private var closeButton: NSButton!
    private var themeObserver: NSObjectProtocol?

    var onInsert: ((String) -> Void)?
    var onGoTo: ((String) -> Void)?
    var onDelete: ((String) -> Void)?
    var fieldsManager: DocumentFieldsManager?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Bookmark"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        setupUI()
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(forName: .themeDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.applyTheme()
        }
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }

    func refreshTheme() {
        applyTheme()
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.wantsLayer = true
        window.contentView = contentView

        // Bookmark name label
        let nameLabel = NSTextField(labelWithString: "Bookmark name:")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.tag = 100
        contentView.addSubview(nameLabel)

        // Bookmark name field
        nameField = NSTextField()
        nameField.placeholderString = "Enter bookmark name"
        nameField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameField)

        // Existing bookmarks label
        let existingLabel = NSTextField(labelWithString: "Existing bookmarks:")
        existingLabel.translatesAutoresizingMaskIntoConstraints = false
        existingLabel.tag = 101
        contentView.addSubview(existingLabel)

        // Bookmarks list
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        existingBookmarksList = NSTableView()
        existingBookmarksList.headerView = nil
        existingBookmarksList.delegate = self
        existingBookmarksList.dataSource = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.width = 340
        existingBookmarksList.addTableColumn(column)

        scrollView.documentView = existingBookmarksList
        contentView.addSubview(scrollView)

        // Buttons
        addButton = NSButton(title: "Add", target: self, action: #selector(addBookmark))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addButton)

        deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteBookmark))
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(deleteButton)

        goToButton = NSButton(title: "Go To", target: self, action: #selector(goToBookmark))
        goToButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(goToButton)

        closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            nameField.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            nameField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            nameField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            existingLabel.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 16),
            existingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            scrollView.topAnchor.constraint(equalTo: existingLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.heightAnchor.constraint(equalToConstant: 150),

            addButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 16),
            addButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            addButton.widthAnchor.constraint(equalToConstant: 80),

            deleteButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 16),
            deleteButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 8),
            deleteButton.widthAnchor.constraint(equalToConstant: 80),

            goToButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 16),
            goToButton.leadingAnchor.constraint(equalTo: deleteButton.trailingAnchor, constant: 8),
            goToButton.widthAnchor.constraint(equalToConstant: 80),

            closeButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 80),

            contentView.bottomAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 20)
        ])
    }

    private func applyTheme() {
        let theme = ThemeManager.shared.currentTheme
        let isDark = ThemeManager.shared.isDarkMode

        window?.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        window?.backgroundColor = theme.pageBackground

        if let contentView = window?.contentView {
            contentView.layer?.backgroundColor = theme.pageBackground.cgColor

            // Update labels
            for view in contentView.subviews {
                if let label = view as? NSTextField, !label.isEditable {
                    label.textColor = theme.textColor
                }
            }
        }

        nameField.textColor = theme.textColor
        nameField.backgroundColor = theme.pageBackground
        nameField.drawsBackground = true
        nameField.isBordered = false
        nameField.wantsLayer = true
        nameField.layer?.borderColor = theme.pageBorder.cgColor
        nameField.layer?.borderWidth = 1
        nameField.layer?.cornerRadius = 4

        // Theme the table view
        existingBookmarksList.backgroundColor = theme.pageBackground
        scrollView.backgroundColor = theme.pageBackground
        scrollView.drawsBackground = true

        // Theme scroll view border
        scrollView.wantsLayer = true
        scrollView.layer?.borderColor = theme.pageBorder.cgColor
        scrollView.layer?.borderWidth = 1
        scrollView.borderType = .noBorder

        // Theme buttons
        themeButton(addButton, theme: theme)
        themeButton(deleteButton, theme: theme)
        themeButton(goToButton, theme: theme)
        themeButton(closeButton, theme: theme)
    }

    private func themeButton(_ button: NSButton, theme: AppTheme) {
        button.contentTintColor = theme.textColor
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = theme.pageBackground.cgColor
        button.layer?.borderColor = theme.pageBorder.cgColor
        button.layer?.borderWidth = 1
        button.layer?.cornerRadius = 6
        let font = button.font ?? NSFont.systemFont(ofSize: 13)
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .foregroundColor: theme.textColor,
                .font: font
            ]
        )
    }

    func reloadBookmarks() {
        bookmarks = fieldsManager?.allBookmarksSorted().filter { $0.type == .bookmark } ?? []
        existingBookmarksList.reloadData()
    }

    @objc private func addBookmark() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            NSSound.beep()
            return
        }
        onInsert?(name)
        nameField.stringValue = ""
        reloadBookmarks()
    }

    @objc private func deleteBookmark() {
        let row = existingBookmarksList.selectedRow
        guard row >= 0, row < bookmarks.count else {
            NSSound.beep()
            return
        }
        let bookmark = bookmarks[row]
        onDelete?(bookmark.id)
        reloadBookmarks()
    }

    @objc private func goToBookmark() {
        let row = existingBookmarksList.selectedRow
        guard row >= 0, row < bookmarks.count else {
            NSSound.beep()
            return
        }
        let bookmark = bookmarks[row]
        onGoTo?(bookmark.id)
    }

    @objc private func closeWindow() {
        window?.close()
    }
}

extension InsertBookmarkWindowController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        bookmarks.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let theme = ThemeManager.shared.currentTheme
        let cell = NSTextField(labelWithString: bookmarks[row].name)
        cell.lineBreakMode = NSLineBreakMode.byTruncatingTail
        cell.textColor = theme.textColor
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = existingBookmarksList.selectedRow
        if row >= 0, row < bookmarks.count {
            nameField.stringValue = bookmarks[row].name
        }
    }
}

// MARK: - Insert Cross-Reference Dialog

@MainActor
class InsertCrossReferenceWindowController: NSWindowController {

    private var referenceTypePopup: NSPopUpButton!
    private var targetsList: NSTableView!
    private var displayModePopup: NSPopUpButton!
    private var hyperlinkCheckbox: NSButton!
    private var scrollView: NSScrollView!
    private var insertButton: NSButton!
    private var cancelButton: NSButton!
    private var themeObserver: NSObjectProtocol?

    private var targets: [BookmarkTarget] = []
    private var filteredTargets: [BookmarkTarget] = []

    var onInsert: ((CrossReferenceField, BookmarkTarget) -> Void)?
    var fieldsManager: DocumentFieldsManager?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Cross-reference"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        setupUI()
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(forName: .themeDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.applyTheme()
        }
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }

    func refreshTheme() {
        applyTheme()
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.wantsLayer = true
        window.contentView = contentView

        // Reference type
        let typeLabel = NSTextField(labelWithString: "Reference type:")
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.tag = 200
        contentView.addSubview(typeLabel)

        referenceTypePopup = NSPopUpButton()
        referenceTypePopup.translatesAutoresizingMaskIntoConstraints = false
        referenceTypePopup.addItems(withTitles: ["All", "Bookmark", "Heading", "Caption", "Footnote", "Endnote"])
        referenceTypePopup.target = self
        referenceTypePopup.action = #selector(referenceTypeChanged)
        contentView.addSubview(referenceTypePopup)

        // Targets list
        let targetsLabel = NSTextField(labelWithString: "For which item:")
        targetsLabel.translatesAutoresizingMaskIntoConstraints = false
        targetsLabel.tag = 201
        contentView.addSubview(targetsLabel)

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        targetsList = NSTableView()
        targetsList.headerView = nil
        targetsList.delegate = self
        targetsList.dataSource = self

        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 280
        targetsList.addTableColumn(nameColumn)

        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "Type"
        typeColumn.width = 100
        targetsList.addTableColumn(typeColumn)

        scrollView.documentView = targetsList
        contentView.addSubview(scrollView)

        // Display mode
        let displayLabel = NSTextField(labelWithString: "Insert reference to:")
        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        displayLabel.tag = 202
        contentView.addSubview(displayLabel)

        displayModePopup = NSPopUpButton()
        displayModePopup.translatesAutoresizingMaskIntoConstraints = false
        for mode in CrossReferenceField.DisplayMode.allCases {
            displayModePopup.addItem(withTitle: mode.rawValue)
            displayModePopup.lastItem?.toolTip = mode.description
        }
        contentView.addSubview(displayModePopup)

        // Hyperlink checkbox
        hyperlinkCheckbox = NSButton(checkboxWithTitle: "Insert as hyperlink", target: nil, action: nil)
        hyperlinkCheckbox.state = .on
        hyperlinkCheckbox.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hyperlinkCheckbox)

        // Buttons
        insertButton = NSButton(title: "Insert", target: self, action: #selector(insertReference))
        insertButton.translatesAutoresizingMaskIntoConstraints = false
        insertButton.keyEquivalent = "\r"
        contentView.addSubview(insertButton)

        cancelButton = NSButton(title: "Cancel", target: self, action: #selector(closeWindow))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            typeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            typeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            referenceTypePopup.centerYAnchor.constraint(equalTo: typeLabel.centerYAnchor),
            referenceTypePopup.leadingAnchor.constraint(equalTo: typeLabel.trailingAnchor, constant: 8),
            referenceTypePopup.widthAnchor.constraint(equalToConstant: 150),

            targetsLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 16),
            targetsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            scrollView.topAnchor.constraint(equalTo: targetsLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.heightAnchor.constraint(equalToConstant: 180),

            displayLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 16),
            displayLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            displayModePopup.centerYAnchor.constraint(equalTo: displayLabel.centerYAnchor),
            displayModePopup.leadingAnchor.constraint(equalTo: displayLabel.trailingAnchor, constant: 8),
            displayModePopup.widthAnchor.constraint(equalToConstant: 150),

            hyperlinkCheckbox.topAnchor.constraint(equalTo: displayLabel.bottomAnchor, constant: 12),
            hyperlinkCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            cancelButton.topAnchor.constraint(equalTo: hyperlinkCheckbox.bottomAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),

            insertButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            insertButton.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -12),
            insertButton.widthAnchor.constraint(equalToConstant: 80),

            contentView.bottomAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: 20)
        ])
    }

    func reloadTargets() {
        targets = fieldsManager?.collectReferenceableTargets() ?? []
        filterTargets()
    }

    private func applyTheme() {
        let theme = ThemeManager.shared.currentTheme
        let isDark = ThemeManager.shared.isDarkMode

        window?.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        window?.backgroundColor = theme.pageBackground

        if let contentView = window?.contentView {
            contentView.layer?.backgroundColor = theme.pageBackground.cgColor

            // Update labels
            for view in contentView.subviews {
                if let label = view as? NSTextField, !label.isEditable {
                    label.textColor = theme.textColor
                }
            }
        }

        stylePopup(referenceTypePopup, theme: theme)
        stylePopup(displayModePopup, theme: theme)

        // Theme the table view
        targetsList.backgroundColor = theme.pageBackground
        scrollView.backgroundColor = theme.pageBackground
        scrollView.drawsBackground = true

        // Theme scroll view border
        scrollView.wantsLayer = true
        scrollView.layer?.borderColor = theme.pageBorder.cgColor
        scrollView.layer?.borderWidth = 1
        scrollView.borderType = .noBorder

        // Theme checkbox
        hyperlinkCheckbox.contentTintColor = theme.textColor
        let checkboxFont = hyperlinkCheckbox.font ?? NSFont.systemFont(ofSize: 13)
        hyperlinkCheckbox.attributedTitle = NSAttributedString(
            string: hyperlinkCheckbox.title,
            attributes: [
                .foregroundColor: theme.textColor,
                .font: checkboxFont
            ]
        )

        // Theme buttons
        themeButton(insertButton, theme: theme)
        themeButton(cancelButton, theme: theme)
    }

    private func themeButton(_ button: NSButton, theme: AppTheme) {
        button.contentTintColor = theme.textColor
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = theme.pageBackground.cgColor
        button.layer?.borderColor = theme.pageBorder.cgColor
        button.layer?.borderWidth = 1
        button.layer?.cornerRadius = 6
        let font = button.font ?? NSFont.systemFont(ofSize: 13)
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .foregroundColor: theme.textColor,
                .font: font
            ]
        )
    }

    private func stylePopup(_ popup: NSPopUpButton, theme: AppTheme) {
        popup.contentTintColor = theme.textColor
        popup.isBordered = false
        popup.wantsLayer = true
        popup.layer?.backgroundColor = theme.pageBackground.cgColor
        popup.layer?.borderColor = theme.pageBorder.cgColor
        popup.layer?.borderWidth = 1
        popup.layer?.cornerRadius = 4
    }

    private func filterTargets() {
        let selectedType = referenceTypePopup.titleOfSelectedItem ?? "All"
        if selectedType == "All" {
            filteredTargets = targets
        } else {
            let targetType = BookmarkTarget.TargetType(rawValue: selectedType) ?? .bookmark
            filteredTargets = targets.filter { $0.type == targetType }
        }
        targetsList.reloadData()
    }

    @objc private func referenceTypeChanged() {
        filterTargets()
    }

    @objc private func insertReference() {
        let row = targetsList.selectedRow
        guard row >= 0, row < filteredTargets.count else {
            NSSound.beep()
            return
        }

        let target = filteredTargets[row]
        let displayModeIndex = displayModePopup.indexOfSelectedItem
        let displayMode = CrossReferenceField.DisplayMode.allCases[displayModeIndex]
        let isHyperlink = hyperlinkCheckbox.state == .on

        let field = CrossReferenceField(
            targetID: target.id,
            displayMode: displayMode,
            isHyperlink: isHyperlink
        )

        onInsert?(field, target)
        window?.close()
    }

    @objc private func closeWindow() {
        window?.close()
    }
}

extension InsertCrossReferenceWindowController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredTargets.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let theme = ThemeManager.shared.currentTheme
        let target = filteredTargets[row]

        if tableColumn?.identifier.rawValue == "name" {
            let cell = NSTextField(labelWithString: target.name)
            cell.lineBreakMode = NSLineBreakMode.byTruncatingTail
            cell.textColor = theme.textColor
            return cell
        } else if tableColumn?.identifier.rawValue == "type" {
            let cell = NSTextField(labelWithString: target.type.rawValue)
            cell.textColor = theme.textColor.withAlphaComponent(0.6)
            return cell
        }
        return nil
    }
}
