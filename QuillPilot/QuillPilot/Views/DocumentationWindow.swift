//
//  DocumentationWindow.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa
import WebKit

class DocumentationWindowController: NSWindowController {

    private var webView: WKWebView!
    private var scrollView: NSScrollView!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "QuillPilot Help"
        window.minSize = NSSize(width: 600, height: 400)

        self.init(window: window)
        setupUI()
        loadDocumentation()
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

        // Create text view for documentation
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentView.bounds.width - 40, height: 0))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.autoresizingMask = [.width]

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

    private func loadDocumentation() {
        guard let scrollView = scrollView,
              let textView = scrollView.documentView as? NSTextView else { return }

        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        // Title
        content.append(makeTitle("QuillPilot Help & Documentation", color: titleColor))
        content.append(makeNewline())

        // Format Painter Section
        content.append(makeHeading("🎨 Format Painter", color: headingColor))
        content.append(makeBody("""
The Format Painter allows you to copy formatting from one text selection and apply it to another.

How to use:
1. Select text with the formatting you want to copy
2. Click the Format Painter button (🖌️) in the toolbar
3. The cursor changes to indicate Format Painter is active
4. Click or drag to select the text where you want to apply the formatting
5. The formatting is applied and Format Painter automatically deactivates

What it copies:
• Font family and size
• Bold, italic, underline
• Text color
• Paragraph alignment
• Line spacing
• Indentation

Note: Format Painter preserves table structures and column layouts when copying.
""", color: bodyColor))
        content.append(makeNewline())

        // Analysis Tool Section
        content.append(makeHeading("📊 Document Analysis", color: headingColor))
        content.append(makeBody("""
The Analysis panel on the right provides real-time feedback on your writing.

Current Metrics:
• Word Count - Total words in your document
• Sentence Count - Number of sentences
• Reading Level - Flesch-Kincaid grade level
• Paragraph Analysis - Average length and dialogue percentage
• Passive Voice - Detection and percentage
• Adverb Usage - Count and examples
• Sentence Length - Variety score and visual graph
• Weak Verbs - Detection of common weak verbs (is, was, get, make, etc.)
• Clichés - Common overused phrases to avoid
• Filter Words - Perception words that distance readers (saw, felt, thought, etc.)
• Sensory Details - Balance of sensory descriptions

The analysis updates automatically as you type and does not affect your document formatting.
""", color: bodyColor))
        content.append(makeNewline())

        // Search & Replace Section
        content.append(makeHeading("🔍 Find & Replace", color: headingColor))
        content.append(makeBody("""
Quickly find and replace text throughout your document.

How to use:
1. Click the 🔍 button in the toolbar
2. Enter text to find in the "Find" field
3. (Optional) Enter replacement text in the "Replace" field
4. Choose options:
   • Case sensitive - Match exact capitalization
   • Whole words only - Don't match partial words

Buttons:
• Previous/Next - Navigate through matches
• Replace - Replace current selection if it matches
• Replace All - Replace all occurrences at once

Keyboard shortcuts:
• Press Enter to find next
• The search wraps around to the beginning/end

The replacement preserves your text formatting.
""", color: bodyColor))
        content.append(makeNewline())

        // Styles Section
        content.append(makeHeading("✍️ Paragraph Styles", color: headingColor))
        content.append(makeBody("""
Apply professional formatting with one click using the Styles dropdown.

Fiction Styles:
• Book Title, Author Name, Chapter Title
• Body Text, Body Text – No Indent
• Dialogue, Internal Thought
• Scene Break, Epigraph
• And more...

Non-Fiction Styles:
• Heading 1, 2, 3
• Body Text, Block Quote
• Callout, Sidebar
• Figure/Table Captions
• And more...

You can customize styles in the Style Editor (click the ⚙️ button next to Styles).
""", color: bodyColor))
        content.append(makeNewline())

        // Tips Section
        content.append(makeHeading("💡 Tips & Best Practices", color: headingColor))
        content.append(makeBody("""
• Use analysis metrics as guidelines, not strict rules
• The sentence variety graph helps you maintain reader interest
• Watch for passive voice percentages above 10% in most genres
• Filter words can be effective when used intentionally
• Weak verbs are acceptable in dialogue and certain contexts
• Use Format Painter to maintain consistency across chapters
• Regular saving is automatic, but use File > Save to export
• The reading level adjusts to your genre and audience
""", color: bodyColor))
        content.append(makeNewline())

        // Keyboard Shortcuts
        content.append(makeHeading("⌨️ Keyboard Shortcuts", color: headingColor))
        content.append(makeBody("""
File Operations:
• ⌘O - Open document
• ⌘S - Save document
• ⌘P - Print

Editing:
• ⌘Z - Undo
• ⌘⇧Z - Redo
• ⌘X, ⌘C, ⌘V - Cut, Copy, Paste
• ⌘A - Select All

Formatting:
• ⌘B - Bold
• ⌘I - Italic
• ⌘U - Underline

View:
• ⌘W - Close window
• ⌘M - Minimize
""", color: bodyColor))

        textView.textStorage?.setAttributedString(content)
    }

    private func makeTitle(_ text: String, color: NSColor) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: color
        ]
        return NSAttributedString(string: text + "\n", attributes: attributes)
    }

    private func makeHeading(_ text: String, color: NSColor) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: color
        ]
        return NSAttributedString(string: text + "\n\n", attributes: attributes)
    }

    private func makeBody(_ text: String, color: NSColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func makeNewline() -> NSAttributedString {
        return NSAttributedString(string: "\n\n")
    }
}
