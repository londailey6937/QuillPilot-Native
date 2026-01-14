//
//  ThemeWindow.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

extension Notification.Name {
    static let storyThemeDidChange = Notification.Name("storyThemeDidChange")
}

class ThemeWindowController: NSWindowController, NSTextViewDelegate {

    private var scrollView: NSScrollView!
    private var textView: NSTextView?
    private var saveTimer: Timer?
    private var currentDocumentURL: URL?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Story Theme"
        window.minSize = NSSize(width: 500, height: 400)

        // Center the window
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let x = (screenFrame.width - 700) / 2
            let y = (screenFrame.height - 500) / 2
            window.setFrame(NSRect(x: x, y: y, width: 700, height: 500), display: true)
        }

        self.init(window: window)
        setupUI()
        loadThemeContent()
    }

    convenience init(documentURL: URL?) {
        self.init()
        setDocumentURL(documentURL)
    }

    func setDocumentURL(_ url: URL?) {
        currentDocumentURL = url
        StoryNotesStore.shared.load(for: url)
        loadThemeContent()
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

        // Create text view for theme content - EDITABLE
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

    private func loadThemeContent() {
        guard let scrollView = scrollView,
              let textView = scrollView.documentView as? NSTextView else { return }

        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        // Title
        content.append(makeTitle("Story Theme", color: titleColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Load saved theme or use default
        let savedTheme = StoryNotesStore.shared.notes.theme
        content.append(makeBody(savedTheme, color: bodyColor))

        textView.textStorage?.setAttributedString(content)

        // Ensure newly-typed text uses theme-visible attributes (fixes invisible typing in Night mode).
        applyBodyTypingAttributes(to: textView, theme: theme)

        // Size to fit
        textView.sizeToFit()
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        // Debounce saves - save 1 second after typing stops
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.saveTheme()
        }
    }

    // MARK: - Persistence

    private func saveTheme() {
        guard let textView = textView,
              let text = textView.textStorage?.string else { return }

        // Extract just the theme content, not the title
        let lines = text.components(separatedBy: .newlines)
        let contentLines = lines.filter { !$0.isEmpty && !$0.contains("Story Theme") }
        let themeContent = contentLines.joined(separator: "\n")

        StoryNotesStore.shared.setDocumentURL(currentDocumentURL)
        StoryNotesStore.shared.updateTheme(themeContent)

        // Notify that theme changed
        NotificationCenter.default.post(name: .storyThemeDidChange, object: nil)
    }

    static func saveThemeContent(_ content: String) {
        // Backwards-compat shim; prefer per-document storage.
        StoryNotesStore.shared.updateTheme(content)
    }

    static func loadSavedTheme() -> String {
        // Backwards-compat shim; prefer per-document storage.
        return StoryNotesStore.shared.notes.theme
    }

    static func getCurrentTheme() -> String {
        return StoryNotesStore.shared.notes.theme
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
