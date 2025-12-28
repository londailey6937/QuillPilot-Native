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

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 450),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to QuillPilot"
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        setupUI()
        loadRecentFiles()
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(red: 0.97, green: 0.90, blue: 0.82, alpha: 1.0).cgColor
        window.contentView = contentView

        // Left side - Logo and buttons
        let leftPanel = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 450))
        leftPanel.wantsLayer = true
        leftPanel.layer?.backgroundColor = NSColor(red: 0.95, green: 0.88, blue: 0.80, alpha: 1.0).cgColor
        contentView.addSubview(leftPanel)

        // Logo
        let logoView = createLogoView()
        logoView.frame = NSRect(x: 75, y: 280, width: 150, height: 150)
        leftPanel.addSubview(logoView)

        // App title
        let titleLabel = NSTextField(labelWithString: "QuillPilot")
        titleLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = NSColor(red: 0.17, green: 0.24, blue: 0.31, alpha: 1.0)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 25, y: 235, width: 250, height: 40)
        leftPanel.addSubview(titleLabel)

        // Tagline
        let taglineLabel = NSTextField(labelWithString: "Your Creative Writing Companion")
        taglineLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        taglineLabel.textColor = NSColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        taglineLabel.alignment = .center
        taglineLabel.frame = NSRect(x: 25, y: 210, width: 250, height: 20)
        leftPanel.addSubview(taglineLabel)

        // New Document button
        let newButton = createActionButton(title: "New Document", icon: "doc.badge.plus", action: #selector(newDocumentClicked))
        newButton.frame = NSRect(x: 50, y: 130, width: 200, height: 44)
        leftPanel.addSubview(newButton)

        // Open Document button
        let openButton = createActionButton(title: "Open Document", icon: "folder", action: #selector(openDocumentClicked))
        openButton.frame = NSRect(x: 50, y: 75, width: 200, height: 44)
        leftPanel.addSubview(openButton)

        // Right side - Recent files
        let rightPanel = NSView(frame: NSRect(x: 300, y: 0, width: 400, height: 450))
        contentView.addSubview(rightPanel)

        // Recent Documents header
        let recentLabel = NSTextField(labelWithString: "Recent Documents")
        recentLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        recentLabel.textColor = NSColor(red: 0.17, green: 0.24, blue: 0.31, alpha: 1.0)
        recentLabel.frame = NSRect(x: 20, y: 405, width: 360, height: 25)
        rightPanel.addSubview(recentLabel)

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
        recentFilesTableView.selectionHighlightStyle = .regular
        recentFilesTableView.delegate = self
        recentFilesTableView.dataSource = self
        recentFilesTableView.doubleAction = #selector(recentFileDoubleClicked)
        recentFilesTableView.target = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("RecentFile"))
        column.width = 340
        recentFilesTableView.addTableColumn(column)

        scrollView.documentView = recentFilesTableView
        rightPanel.addSubview(scrollView)
    }

    private func createLogoView() -> NSView {
        // Use the same LogoView as the header for consistency
        let logoView = LogoView(size: 150)
        return logoView
    }

    private func createActionButton(title: String, icon: String, action: Selector) -> NSButton {
        let button = NSButton(frame: .zero)
        button.title = title
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        button.font = NSFont.systemFont(ofSize: 14, weight: .medium)

        // Style the button
        button.wantsLayer = true
        button.layer?.cornerRadius = 8

        if let symbolImage = NSImage(systemSymbolName: icon, accessibilityDescription: title) {
            button.image = symbolImage
            button.imagePosition = .imageLeading
            button.imageScaling = .scaleProportionallyDown
        }

        return button
    }

    private func loadRecentFiles() {
        recentFiles = NSDocumentController.shared.recentDocumentURLs
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

        if recentFiles.isEmpty {
            // Show empty state
            let label = NSTextField(labelWithString: "No recent documents")
            label.font = NSFont.systemFont(ofSize: 13)
            label.textColor = .secondaryLabelColor
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
            nameLabel.textColor = NSColor(red: 0.17, green: 0.24, blue: 0.31, alpha: 1.0)
            nameLabel.frame = NSRect(x: 48, y: 26, width: 280, height: 18)
            nameLabel.lineBreakMode = .byTruncatingTail
            cellView.addSubview(nameLabel)

            // File path
            let pathLabel = NSTextField(labelWithString: url.deletingLastPathComponent().path)
            pathLabel.font = NSFont.systemFont(ofSize: 11)
            pathLabel.textColor = .secondaryLabelColor
            pathLabel.frame = NSRect(x: 48, y: 8, width: 280, height: 16)
            pathLabel.lineBreakMode = .byTruncatingMiddle
            cellView.addSubview(pathLabel)
        }

        return cellView
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return !recentFiles.isEmpty
    }
}
