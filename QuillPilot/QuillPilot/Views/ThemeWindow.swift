//
//  ThemeWindow.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class ThemeWindowController: NSWindowController {

    private var scrollView: NSScrollView!

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

        scrollView.documentView = textView
        contentView.addSubview(scrollView)
        window.contentView = contentView

        applyTheme(textView)
    }

    private func applyTheme(_ textView: NSTextView) {
        let theme = ThemeManager.shared.currentTheme
        textView.backgroundColor = theme.pageAround
        textView.textColor = theme.textColor
        scrollView.backgroundColor = theme.pageAround
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

        // Theme content extracted from PureTheme document
        content.append(makeBody("""
The theme of the story centers on the tension between personal integrity and the morally ambiguous world of political and covert operations. It delves into how individuals—whether they are politicians like Senator Kessler, operatives like Alex, or investigators like Allison—navigate a complex landscape fraught with ethical dilemmas and hidden agendas.

Amidst high-stakes political games and clandestine activities, the characters are forced to confront their own values, loyalties, and limits. In doing so, the story raises questions about the sacrifices one must make for the greater good, the ethical compromises that may or may not be justifiable, and the blurry line between right and wrong in a world where every decision has far-reaching consequences.

Furthermore, it will attempt to tie into fundamental questions about governance, the balance of power, and the erosion of democratic values. This added layer should give the story a compelling depth and contemporary relevance, making it not just a tale of individual characters but a reflection on the state of the society they inhabit.
""", color: bodyColor))

        textView.textStorage?.setAttributedString(content)

        // Size to fit
        textView.sizeToFit()
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
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.paragraphSpacing = 12

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func makeNewline() -> NSAttributedString {
        return NSAttributedString(string: "\n")
    }
}
