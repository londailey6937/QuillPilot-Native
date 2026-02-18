//
//  FootnoteEndnoteWindows.swift
//  QuillPilot
//
//  UI dialogs for inserting and managing footnotes and endnotes.
//

import Cocoa

// MARK: - Insert Footnote/Endnote Dialog

@MainActor
class InsertNoteWindowController: NSWindowController {

    private var noteType: NoteType
    private var contentField: NSTextView!
    private var notesList: NSTableView!
    private var notes: [Note] = []
    private var numberingStylePopup: NSPopUpButton!
    private var insertButton: NSButton!
    private var deleteButton: NSButton!
    private var goToButton: NSButton!
    private var convertButton: NSButton!
    private var closeButton: NSButton!

    var onInsert: ((String) -> Void)?  // Returns note content
    var onGoTo: ((String) -> Void)?    // Pass note ID
    var onDelete: ((String) -> Void)?  // Pass note ID
    var onEditNote: ((String, String) -> Void)?  // Pass note ID and new content
    var onConvert: ((String) -> Void)?  // Pass note ID to convert type
    var notesManager: NotesManager?

    init(noteType: NoteType) {
        self.noteType = noteType
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = noteType == .footnote ? "Footnote" : "Endnote"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 350)
        super.init(window: window)
        setupUI()
        applyTheme()
        DispatchQueue.main.async { [weak self] in
            self?.applyTheme()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange(_:)), name: Notification.Name.themeDidChange, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.themeDidChange, object: nil)
    }

    func refreshTheme() {
        applyTheme()
    }

    @objc private func themeDidChange(_ note: Notification) {
        applyTheme()
    }

    private var listScrollView: NSScrollView!
    private var contentScrollView: NSScrollView!

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.wantsLayer = true
        window.contentView = contentView

        // Note content label
        let contentLabel = NSTextField(labelWithString: "Note content:")
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.tag = 300
        contentView.addSubview(contentLabel)

        // Note content text view (multi-line)
        contentScrollView = NSScrollView()
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.hasVerticalScroller = true
        contentScrollView.borderType = .bezelBorder

        contentField = NSTextView()
        contentField.isRichText = false
        contentField.font = NSFont.systemFont(ofSize: 13)
        contentField.textContainerInset = NSSize(width: 5, height: 5)
        contentField.isVerticallyResizable = true
        contentField.isHorizontallyResizable = false
        contentField.autoresizingMask = [.width]
        contentField.textContainer?.widthTracksTextView = true

        contentScrollView.documentView = contentField
        contentView.addSubview(contentScrollView)

        // Numbering style
        let styleLabel = NSTextField(labelWithString: "Numbering style:")
        styleLabel.translatesAutoresizingMaskIntoConstraints = false
        styleLabel.tag = 301
        contentView.addSubview(styleLabel)

        numberingStylePopup = NSPopUpButton()
        numberingStylePopup.translatesAutoresizingMaskIntoConstraints = false
        for style in NoteNumberingStyle.allCases {
            numberingStylePopup.addItem(withTitle: style.rawValue)
        }
        numberingStylePopup.target = self
        numberingStylePopup.action = #selector(numberingStyleChanged)
        contentView.addSubview(numberingStylePopup)

        // Existing notes label
        let existingLabel = NSTextField(labelWithString: "Existing \(noteType.rawValue.lowercased())s:")
        existingLabel.translatesAutoresizingMaskIntoConstraints = false
        existingLabel.tag = 302
        contentView.addSubview(existingLabel)

        // Notes list
        listScrollView = NSScrollView()
        listScrollView.translatesAutoresizingMaskIntoConstraints = false
        listScrollView.hasVerticalScroller = true
        listScrollView.borderType = .bezelBorder

        notesList = NSTableView()
        notesList.headerView = nil
        notesList.delegate = self
        notesList.dataSource = self
        notesList.doubleAction = #selector(goToNote)
        notesList.target = self

        let numberColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("number"))
        numberColumn.width = 40
        numberColumn.title = "#"
        notesList.addTableColumn(numberColumn)

        let contentColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("content"))
        contentColumn.width = 380
        contentColumn.title = "Content"
        notesList.addTableColumn(contentColumn)

        listScrollView.documentView = notesList
        contentView.addSubview(listScrollView)

        // Buttons
        insertButton = NSButton(title: "Insert", target: self, action: #selector(insertNote))
        insertButton.translatesAutoresizingMaskIntoConstraints = false
        insertButton.keyEquivalent = "\r"
        contentView.addSubview(insertButton)

        deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteNote))
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(deleteButton)

        goToButton = NSButton(title: "Go To", target: self, action: #selector(goToNote))
        goToButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(goToButton)

        convertButton = NSButton(title: noteType == .footnote ? "→ Endnote" : "→ Footnote", target: self, action: #selector(convertNote))
        convertButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(convertButton)

        closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            // Content label
            contentLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            contentLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Content field
            contentScrollView.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 8),
            contentScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            contentScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            contentScrollView.heightAnchor.constraint(equalToConstant: 80),

            // Style label
            styleLabel.topAnchor.constraint(equalTo: contentScrollView.bottomAnchor, constant: 12),
            styleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Style popup
            numberingStylePopup.centerYAnchor.constraint(equalTo: styleLabel.centerYAnchor),
            numberingStylePopup.leadingAnchor.constraint(equalTo: styleLabel.trailingAnchor, constant: 8),
            numberingStylePopup.widthAnchor.constraint(equalToConstant: 150),

            // Existing notes label
            existingLabel.topAnchor.constraint(equalTo: styleLabel.bottomAnchor, constant: 16),
            existingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Notes list
            listScrollView.topAnchor.constraint(equalTo: existingLabel.bottomAnchor, constant: 8),
            listScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            listScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            listScrollView.bottomAnchor.constraint(equalTo: insertButton.topAnchor, constant: -16),

            // Buttons row
            insertButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            insertButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            insertButton.widthAnchor.constraint(equalToConstant: 70),

            deleteButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            deleteButton.leadingAnchor.constraint(equalTo: insertButton.trailingAnchor, constant: 8),
            deleteButton.widthAnchor.constraint(equalToConstant: 70),

            goToButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            goToButton.leadingAnchor.constraint(equalTo: deleteButton.trailingAnchor, constant: 8),
            goToButton.widthAnchor.constraint(equalToConstant: 70),

            convertButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            convertButton.leadingAnchor.constraint(equalTo: goToButton.trailingAnchor, constant: 8),
            convertButton.widthAnchor.constraint(equalToConstant: 90),

            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 70),
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

        stylePopup(numberingStylePopup, theme: theme)

        // Theme the table view
        notesList.backgroundColor = theme.pageBackground
        styleTextAreaScrollView(listScrollView, theme: theme)

        // Theme the content text view
        contentField.backgroundColor = theme.pageBackground
        contentField.textColor = theme.textColor
        styleTextAreaScrollView(contentScrollView, theme: theme)

        // Theme buttons
        themeButton(insertButton, theme: theme)
        themeButton(deleteButton, theme: theme)
        themeButton(goToButton, theme: theme)
        themeButton(convertButton, theme: theme)
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

    private func stylePopup(_ popup: NSPopUpButton, theme: AppTheme) {
        popup.contentTintColor = theme.textColor
        popup.isBordered = false
        popup.wantsLayer = true
        popup.layer?.backgroundColor = theme.pageBackground.cgColor
        popup.layer?.borderColor = theme.pageBorder.cgColor
        popup.layer?.borderWidth = 1
        popup.layer?.cornerRadius = 4
    }

    private func styleTextAreaScrollView(_ scrollView: NSScrollView, theme: AppTheme) {
        // NSScrollView is sometimes finicky about rendering its own layer border.
        // Styling the clip view (contentView) is more reliable visually.
        scrollView.drawsBackground = true
        scrollView.backgroundColor = theme.pageBackground
        scrollView.borderType = .noBorder

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

    func reloadNotes() {
        guard let manager = notesManager else { return }

        switch noteType {
        case .footnote:
            notes = manager.footnotesSortedByPosition()
            numberingStylePopup.selectItem(withTitle: manager.footnoteNumberingStyle.rawValue)
        case .endnote:
            notes = manager.endnotesSortedByPosition()
            numberingStylePopup.selectItem(withTitle: manager.endnoteNumberingStyle.rawValue)
        }

        notesList.reloadData()
    }

    @objc private func numberingStyleChanged() {
        guard let manager = notesManager,
              let styleTitle = numberingStylePopup.selectedItem?.title,
              let style = NoteNumberingStyle.allCases.first(where: { $0.rawValue == styleTitle }) else { return }

        switch noteType {
        case .footnote:
            manager.footnoteNumberingStyle = style
        case .endnote:
            manager.endnoteNumberingStyle = style
        }

        // Update all markers
        manager.updateAllNoteMarkers()
        notesList.reloadData()
    }

    @objc private func insertNote() {
        let content = contentField.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.isEmpty {
            // Insert with empty content - user can edit later
            onInsert?("")
        } else {
            onInsert?(content)
        }
        contentField.string = ""
        reloadNotes()
    }

    @objc private func deleteNote() {
        let selectedRow = notesList.selectedRow
        guard selectedRow >= 0 && selectedRow < notes.count else { return }

        let note = notes[selectedRow]

        // Confirm deletion
        let alert = NSAlert()
        alert.messageText = "Delete \(noteType.rawValue)?"
        alert.informativeText = "This will remove the \(noteType.rawValue.lowercased()) and its reference from the document."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            onDelete?(note.id)
            reloadNotes()
        }
    }

    @objc private func goToNote() {
        let selectedRow = notesList.selectedRow
        guard selectedRow >= 0 && selectedRow < notes.count else { return }

        let note = notes[selectedRow]
        onGoTo?(note.id)
    }

    @objc private func convertNote() {
        let selectedRow = notesList.selectedRow
        guard selectedRow >= 0 && selectedRow < notes.count else { return }

        let note = notes[selectedRow]
        onConvert?(note.id)
        reloadNotes()
    }

    @objc private func closeWindow() {
        window?.close()
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate

/// Themed row view for footnote/endnote table views.
/// Replaces system-blue selection highlight with the current theme's page border color.
private final class NoteThemedRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }
        let theme = ThemeManager.shared.currentTheme
        let fill: NSColor = {
            switch theme {
            case .night:
                return theme.pageBorder.withAlphaComponent(0.35)
            case .day, .cream:
                return theme.pageBorder.withAlphaComponent(0.22)
            }
        }()
        fill.setFill()
        NSBezierPath(rect: bounds).fill()
    }
}

extension InsertNoteWindowController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return notes.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        NoteThemedRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < notes.count else { return nil }
        let theme = ThemeManager.shared.currentTheme
        let note = notes[row]

        let cellIdentifier = NSUserInterfaceItemIdentifier("NoteCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTextField

        if cell == nil {
            cell = NSTextField(labelWithString: "")
            cell?.identifier = cellIdentifier
            cell?.lineBreakMode = NSLineBreakMode.byTruncatingTail
        }

        if let column = tableColumn {
            if column.identifier.rawValue == "number" {
                // Display number
                let marker: String
                switch noteType {
                case .footnote:
                    marker = notesManager?.footnoteMarker(for: note.id) ?? "?"
                case .endnote:
                    marker = notesManager?.endnoteMarker(for: note.id) ?? "?"
                }
                cell?.stringValue = marker
                cell?.alignment = .center
                cell?.textColor = theme.textColor
            } else {
                // Display content preview
                let preview = note.content.isEmpty ? "(empty)" : note.content.prefix(100)
                cell?.stringValue = String(preview)
                cell?.textColor = note.content.isEmpty ? theme.textColor.withAlphaComponent(0.5) : theme.textColor
            }
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = notesList.selectedRow
        guard selectedRow >= 0 && selectedRow < notes.count else { return }

        // Show selected note's content in the text field
        let note = notes[selectedRow]
        contentField.string = note.content
    }
}

// MARK: - Edit Note Content Dialog

@MainActor
class EditNoteContentWindowController: NSWindowController {

    private var contentField: NSTextView!
    private let noteID: String
    private let noteType: NoteType
    private var initialContent: String

    var onSave: ((String, String) -> Void)?  // Note ID, new content

    init(noteID: String, noteType: NoteType, content: String) {
        self.noteID = noteID
        self.noteType = noteType
        self.initialContent = content

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Edit \(noteType.rawValue)"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 300, height: 200)
        super.init(window: window)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let window = window else { return }
        let theme = ThemeManager.shared.currentTheme

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = theme.pageBackground.cgColor
        window.contentView = contentView

        // Content label
        let label = NSTextField(labelWithString: "\(noteType.rawValue) content:")
        label.textColor = theme.textColor
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        // Content text view
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        contentField = NSTextView()
        contentField.isRichText = false
        contentField.font = NSFont.systemFont(ofSize: 13)
        contentField.textContainerInset = NSSize(width: 5, height: 5)
        contentField.isVerticallyResizable = true
        contentField.isHorizontallyResizable = false
        contentField.autoresizingMask = [.width]
        contentField.textContainer?.widthTracksTextView = true
        contentField.string = initialContent

        scrollView.documentView = contentField
        contentView.addSubview(scrollView)

        // Buttons
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveNote))
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelEdit))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            scrollView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -16),

            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            saveButton.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -8),
            saveButton.widthAnchor.constraint(equalToConstant: 80),

            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            cancelButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
        ])
    }

    @objc private func saveNote() {
        let newContent = contentField.string
        onSave?(noteID, newContent)
        window?.close()
    }

    @objc private func cancelEdit() {
        window?.close()
    }
}
