//
//  LocationsWindow.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class LocationsWindowController: NSWindowController, NSTextViewDelegate {

    private var scrollView: NSScrollView!
    private var textView: NSTextView?
    private var saveTimer: Timer?
    private var currentDocumentURL: URL?
    private let headerDescription = "Track key settings and notes to keep geography consistent."

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Story Locations"
        window.minSize = NSSize(width: 600, height: 500)

        // Center the window
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let x = (screenFrame.width - 750) / 2
            let y = (screenFrame.height - 600) / 2
            window.setFrame(NSRect(x: x, y: y, width: 750, height: 600), display: true)
        }

        self.init(window: window)
        setupUI()
        loadLocationsContent()
    }

    convenience init(documentURL: URL?) {
        self.init()
        setDocumentURL(documentURL)
    }

    func setDocumentURL(_ url: URL?) {
        currentDocumentURL = url
        StoryNotesStore.shared.load(for: url)
        loadLocationsContent()
    }

    func updateDocumentURL(_ url: URL?) {
        currentDocumentURL = url
        StoryNotesStore.shared.setDocumentURL(url)
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true

        // Create scroll view
        scrollView = NSScrollView(frame: contentView.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        // Create text view for locations content - EDITABLE
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentView.bounds.width - 40, height: 0))
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 30, height: 30)
        textView.autoresizingMask = [.width]
        textView.isRichText = true
        textView.allowsUndo = true
        textView.delegate = self
        self.textView = textView

        scrollView.documentView = textView
        contentView.addSubview(scrollView)
        window.contentView = contentView

        applyTheme(textView)
    }

    private func applyTheme(_ textView: NSTextView) {
        let theme = ThemeManager.shared.currentTheme
        textView.backgroundColor = theme.pageAround
        textView.textColor = theme.textColor
        textView.insertionPointColor = theme.insertionPointColor
        scrollView.backgroundColor = theme.pageAround

        applyBodyTypingAttributes(to: textView, theme: theme)
    }

    private func loadLocationsContent() {
        guard let scrollView = scrollView,
              let textView = scrollView.documentView as? NSTextView else { return }

        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        // Title
        content.append(makeTitle("Story Locations", color: titleColor))
        content.append(makeNewline())
        content.append(makeDescription(headerDescription, color: theme.popoutSecondaryColor))
        content.append(makeNewline())
        content.append(makeNewline())

        let saved = StoryNotesStore.shared.notes.locations
        if !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content.append(makeBody(saved, color: bodyColor))
        }

        textView.textStorage?.setAttributedString(content)

        // Ensure newly-typed text uses theme-visible attributes (fixes invisible typing in Night mode).
        applyBodyTypingAttributes(to: textView, theme: theme)

        // Size to fit
        textView.sizeToFit()
    }

    func textDidChange(_ notification: Notification) {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.saveLocations()
        }
    }

    private func saveLocations() {
        guard let textView = textView,
              let text = textView.textStorage?.string else { return }

        let lines = text.components(separatedBy: .newlines)
        let contentLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && trimmed != "Story Locations" && trimmed != headerDescription
        }
        let locationsContent = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        StoryNotesStore.shared.setDocumentURL(currentDocumentURL)
        StoryNotesStore.shared.updateLocations(locationsContent)
    }

    // MARK: - Helper Methods

    private func makeTitle(_ text: String, color: NSColor) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: color
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func makeHeading(_ text: String, color: NSColor) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: color
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func makeSubheading(_ text: String, color: NSColor) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 16),
            .foregroundColor: color
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func makeDescription(_ text: String, color: NSColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.paragraphSpacing = 8
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func makeBody(_ text: String, color: NSColor) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: color,
            .paragraphStyle: bodyParagraphStyle()
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func bodyParagraphStyle() -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.paragraphSpacing = 12
        return paragraphStyle
    }

    private func applyBodyTypingAttributes(to textView: NSTextView, theme: AppTheme) {
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: theme.textColor,
            .paragraphStyle: bodyParagraphStyle()
        ]
        textView.insertionPointColor = theme.insertionPointColor
        textView.selectedTextAttributes = [
            .backgroundColor: theme.pageBorder.withAlphaComponent(0.30),
            .foregroundColor: theme.textColor
        ]
    }

    private func makeNewline() -> NSAttributedString {
        return NSAttributedString(string: "\n")
    }
}
