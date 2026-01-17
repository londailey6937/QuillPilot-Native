//
//  WelcomeWindow.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class WelcomeWindowController: NSWindowController {

    var onNewDocument: (() -> Void)?
    var onOpenDocument: (() -> Void)?
    var onOpenRecent: ((URL) -> Void)?

    private var recentFiles: [URL] = []
    private var recentFilesTableView: NSTableView!

    private var contentBackgroundView: NSView?
    private var leftPanel: NSView?
    private var rightPanel: NSView?
    private var titleLabel: NSTextField?
    private var taglineLabel1: NSTextField?
    private var taglineLabel2: NSTextField?
    private var recentLabel: NSTextField?
    private var actionButtons: [NSButton] = []
    private var themeObserver: NSObjectProtocol?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 450),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Quill Pilot"
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        setupUI()
        loadRecentFiles()

        themeObserver = NotificationCenter.default.addObserver(
            forName: .themeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.wantsLayer = true
        window.contentView = contentView
        contentBackgroundView = contentView

        // Left side - Logo and buttons
        let leftPanel = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 450))
        leftPanel.wantsLayer = true
        contentView.addSubview(leftPanel)
        self.leftPanel = leftPanel

        // Logo
        let logoView = createLogoView()
        logoView.frame = NSRect(x: 75, y: 280, width: 150, height: 150)
        leftPanel.addSubview(logoView)

        // App title
        let titleLabel = NSTextField(labelWithString: "Quill Pilot")
        titleLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 25, y: 235, width: 250, height: 40)
        leftPanel.addSubview(titleLabel)
        self.titleLabel = titleLabel

        // Tagline - Line 1
        let tagline1 = NSTextField(labelWithString: "Your Writing Tool")
        tagline1.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        tagline1.alignment = .center
        tagline1.frame = NSRect(x: 0, y: 218, width: 300, height: 18)
        leftPanel.addSubview(tagline1)
        self.taglineLabel1 = tagline1

        // Tagline - Line 2
        let tagline2 = NSTextField(labelWithString: "for Fiction & Non-Fiction")
        tagline2.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        tagline2.alignment = .center
        tagline2.frame = NSRect(x: 0, y: 202, width: 300, height: 18)
        leftPanel.addSubview(tagline2)
        self.taglineLabel2 = tagline2

        // New Document button
        let newButton = createActionButton(title: "New Document", icon: "doc.badge.plus", action: #selector(newDocumentClicked))
        newButton.frame = NSRect(x: 50, y: 130, width: 200, height: 44)
        leftPanel.addSubview(newButton)
        actionButtons.append(newButton)

        // Open Document button
        let openButton = createActionButton(title: "Open Document", icon: "folder", action: #selector(openDocumentClicked))
        openButton.frame = NSRect(x: 50, y: 75, width: 200, height: 44)
        leftPanel.addSubview(openButton)
        actionButtons.append(openButton)

        // Right side - Recent files
        let rightPanel = NSView(frame: NSRect(x: 300, y: 0, width: 400, height: 450))
        contentView.addSubview(rightPanel)
        self.rightPanel = rightPanel

        // Recent Documents header
        let recentLabel = NSTextField(labelWithString: "Recent Documents")
        recentLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        recentLabel.frame = NSRect(x: 20, y: 405, width: 360, height: 25)
        rightPanel.addSubview(recentLabel)
        self.recentLabel = recentLabel

        // Recent files table
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 20, width: 360, height: 375))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        recentFilesTableView = NSTableView()
        recentFilesTableView.backgroundColor = .clear
        recentFilesTableView.headerView = nil
        recentFilesTableView.rowHeight = 50
        recentFilesTableView.intercellSpacing = NSSize(width: 0, height: 4)
        recentFilesTableView.selectionHighlightStyle = .none
        recentFilesTableView.delegate = self
        recentFilesTableView.dataSource = self
        recentFilesTableView.doubleAction = #selector(recentFileDoubleClicked)
        recentFilesTableView.target = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("RecentFile"))
        column.width = 340
        recentFilesTableView.addTableColumn(column)

        scrollView.documentView = recentFilesTableView
        rightPanel.addSubview(scrollView)

        applyTheme()
    }

    private func createLogoView() -> NSView {
        // Use the same LogoView as the header for consistency
        let logoView = LogoView(size: 150)
        return logoView
    }

    private func createActionButton(title: String, icon: String, action: Selector) -> NSButton {
        let button = NSButton(frame: .zero)
        button.target = self
        button.action = action
        button.isBordered = false  // Remove default styling
        button.title = title
        button.identifier = NSUserInterfaceItemIdentifier(icon)

        // Style the button with theme colors
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.layer?.borderWidth = 1
        button.layer?.borderColor = ThemeManager.shared.currentTheme.pageBorder.cgColor

        applyButtonTheme(button)

        return button
    }

    private func applyTheme() {
        let theme = ThemeManager.shared.currentTheme

        contentBackgroundView?.layer?.backgroundColor = theme.pageAround.cgColor
        leftPanel?.layer?.backgroundColor = theme.pageBackground.cgColor

        titleLabel?.textColor = theme.textColor
        taglineLabel1?.textColor = theme.popoutSecondaryColor
        taglineLabel2?.textColor = theme.popoutSecondaryColor
        recentLabel?.textColor = theme.textColor

        for button in actionButtons {
            applyButtonTheme(button)
        }

        recentFilesTableView?.reloadData()
    }

    private func applyButtonTheme(_ button: NSButton) {
        let theme = ThemeManager.shared.currentTheme
        button.layer?.backgroundColor = theme.pageAround.cgColor
        button.layer?.borderColor = theme.pageBorder.cgColor

        let title = button.title
        let iconName = button.identifier?.rawValue ?? ""

        let attachment = NSTextAttachment()
        if let symbolImage = NSImage(systemSymbolName: iconName, accessibilityDescription: title) {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            if let configuredImage = symbolImage.withSymbolConfiguration(config) {
                let tintedImage = configuredImage.copy() as! NSImage
                tintedImage.lockFocus()
                theme.textColor.set()
                NSRect(origin: .zero, size: tintedImage.size).fill(using: .sourceAtop)
                tintedImage.unlockFocus()
                attachment.image = tintedImage
            }
        }

        let imageString = NSMutableAttributedString(attachment: attachment)
        let textString = NSAttributedString(string: "  \(title)", attributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: theme.textColor
        ])
        imageString.append(textString)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        imageString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: imageString.length))

        button.attributedTitle = imageString
    }

    private func loadRecentFiles() {
        recentFiles = RecentDocuments.shared.recentURLs()
        recentFilesTableView?.reloadData()
    }

    @objc private func newDocumentClicked() {
        close()
        onNewDocument?()
    }

    @objc private func openDocumentClicked() {
        close()
        onOpenDocument?()
    }

    @objc private func recentFileDoubleClicked() {
        let row = recentFilesTableView.clickedRow
        guard row >= 0, row < recentFiles.count else { return }

        let url = recentFiles[row]
        close()
        onOpenRecent?(url)
    }
}

// MARK: - NSTableViewDelegate & DataSource
extension WelcomeWindowController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return recentFiles.isEmpty ? 1 : recentFiles.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellView = NSTableCellView()
        cellView.wantsLayer = true
        let theme = ThemeManager.shared.currentTheme
        let isSelected = tableView.selectedRow == row
        cellView.layer?.backgroundColor = isSelected ? theme.pageBorder.withAlphaComponent(0.15).cgColor : NSColor.clear.cgColor

        if recentFiles.isEmpty {
            // Show empty state
            let label = NSTextField(labelWithString: "No recent documents")
            label.font = NSFont.systemFont(ofSize: 13)
            label.textColor = theme.popoutSecondaryColor
            label.frame = NSRect(x: 10, y: 15, width: 320, height: 20)
            cellView.addSubview(label)
        } else {
            let url = recentFiles[row]

            // File icon
            let iconView = NSImageView(frame: NSRect(x: 8, y: 9, width: 32, height: 32))
            iconView.image = NSWorkspace.shared.icon(forFile: url.path)
            iconView.imageScaling = .scaleProportionallyUpOrDown
            cellView.addSubview(iconView)

            // Filename
            let nameLabel = NSTextField(labelWithString: url.deletingPathExtension().lastPathComponent)
            nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            nameLabel.textColor = theme.textColor
            nameLabel.frame = NSRect(x: 48, y: 26, width: 280, height: 18)
            nameLabel.lineBreakMode = .byTruncatingTail
            cellView.addSubview(nameLabel)

            // File path
            let pathLabel = NSTextField(labelWithString: url.deletingLastPathComponent().path)
            pathLabel.font = NSFont.systemFont(ofSize: 11)
            pathLabel.textColor = theme.popoutSecondaryColor
            pathLabel.frame = NSRect(x: 48, y: 8, width: 280, height: 16)
            pathLabel.lineBreakMode = .byTruncatingMiddle
            cellView.addSubview(pathLabel)
        }

        return cellView
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return !recentFiles.isEmpty
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        recentFilesTableView?.reloadData()
    }
}
