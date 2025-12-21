//
//  StoryDirectionsWindow.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class StoryDirectionsWindowController: NSWindowController {

    private var scrollView: NSScrollView!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Potential Story Directions"
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
        loadDirectionsContent()
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

        // Create text view for directions content - EDITABLE
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

    private func loadDirectionsContent() {
        guard let scrollView = scrollView,
              let textView = scrollView.documentView as? NSTextView else { return }

        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        // Title
        content.append(makeTitle("Potential Story Directions", color: titleColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Instructions
        content.append(makeBody("""
Explore different narrative possibilities and plot variations. These directions can help guide your story development and provide options when you reach decision points in your writing.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Sample directions structure
        content.append(makeHeading("Direction 1: [Title]", color: headingColor))
        content.append(makeNewline())
        content.append(makeBody("""
• Premise: [Core concept or "what if" scenario]
• Key Plot Points:
  - [Major event or turning point 1]
  - [Major event or turning point 2]
  - [Major event or turning point 3]
• Character Impact: [How this direction affects main characters]
• Thematic Implications: [How this aligns with or challenges your theme]
• Potential Ending: [Possible resolution]
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        content.append(makeHeading("Direction 2: [Title]", color: headingColor))
        content.append(makeNewline())
        content.append(makeBody("""
• Premise: [Core concept or "what if" scenario]
• Key Plot Points:
  - [Major event or turning point 1]
  - [Major event or turning point 2]
  - [Major event or turning point 3]
• Character Impact: [How this direction affects main characters]
• Thematic Implications: [How this aligns with or challenges your theme]
• Potential Ending: [Possible resolution]
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        content.append(makeHeading("Direction 3: [Title]", color: headingColor))
        content.append(makeNewline())
        content.append(makeBody("""
• Premise: [Core concept or "what if" scenario]
• Key Plot Points:
  - [Major event or turning point 1]
  - [Major event or turning point 2]
  - [Major event or turning point 3]
• Character Impact: [How this direction affects main characters]
• Thematic Implications: [How this aligns with or challenges your theme]
• Potential Ending: [Possible resolution]
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        content.append(makeHeading("Notes", color: headingColor))
        content.append(makeNewline())
        content.append(makeBody("""
[Use this space to brainstorm additional directions, track which elements work well together, or note reader feedback on different possibilities]
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
