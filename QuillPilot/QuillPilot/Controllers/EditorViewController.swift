//
//  EditorViewController.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

// Flipped view so y=0 is at the top (standard for scroll views)
class FlippedView: NSView {
    override var isFlipped: Bool { return true }
}

protocol EditorViewControllerDelegate: AnyObject {
    func textDidChange()
    func titleDidChange(_ title: String)
}

class EditorViewController: NSViewController {

    private let styleAttributeKey = NSAttributedString.Key("QuillStyleName")

    private let standardMargin: CGFloat = 72
    private let standardIndentStep: CGFloat = 36
    var editorZoom: CGFloat = 1.4  // 140% zoom for better readability on large displays

    // Page dimensions (US Letter)
    private let pageWidth: CGFloat = 612  // 8.5 inches
    private let pageHeight: CGFloat = 792  // 11 inches
    private let headerHeight: CGFloat = 36  // 0.5 inch
    private let footerHeight: CGFloat = 36  // 0.5 inch

    var textView: NSTextView!
    var pageContainer: NSView!  // Exposed for printing

    private var scrollView: NSScrollView!
    private var documentView: NSView!
    private var currentTheme: AppTheme = ThemeManager.shared.currentTheme

    // Multi-page support
    private var pages: [NSView] = []

    private class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }
    private var headerViews: [NSTextField] = []
    private var footerViews: [NSTextField] = []

    // Manuscript metadata
    var manuscriptTitle: String = "Untitled"
    var manuscriptAuthor: String = "Author Name"

    // Header/Footer configuration
    var showHeaders: Bool = true
    var showFooters: Bool = true
    var showPageNumbers: Bool = true
    var headerText: String = "" // Empty means use author/title
    var footerText: String = "" // Empty means use page number

    weak var delegate: EditorViewControllerDelegate?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextView()
    }

    private func setupTextView() {
        // Outer scroll view for scrolling the entire page view
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = true
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 12, bottom: 50, right: 12)

        // Page container grows to fit all content (starts at US Letter height)
        pageContainer = FlippedView(frame: NSRect(x: 0, y: 0, width: 612 * editorZoom, height: 10000 * editorZoom))
        pageContainer.wantsLayer = true
        pageContainer.layer?.borderWidth = 1
        pageContainer.layer?.masksToBounds = false  // Don't clip - let page grow
        pageContainer.layer?.shadowOpacity = 0.35
        pageContainer.layer?.shadowOffset = NSSize(width: 0, height: 2)
        pageContainer.layer?.shadowRadius = 10

        // Create text view that grows with content
        let textFrame = pageContainer.bounds.insetBy(dx: standardMargin * editorZoom, dy: standardMargin * editorZoom)
        textView = NSTextView(frame: textFrame)
        textView.minSize = NSSize(width: textFrame.width, height: textFrame.height)
        textView.maxSize = NSSize(width: textFrame.width, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = []  // Remove autoresizing to prevent constraint conflicts
        textView.textContainer?.containerSize = NSSize(width: textFrame.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isRichText = true
        textView.importsGraphics = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isAutomaticTextReplacementEnabled = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.delegate = self

        let font = NSFont(name: "Times New Roman", size: 12) ?? NSFont.systemFont(ofSize: 12)
        textView.font = font

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 2.0
        paragraphStyle.paragraphSpacing = 12
        paragraphStyle.firstLineHeadIndent = standardIndentStep
        textView.defaultParagraphStyle = paragraphStyle.copy() as? NSParagraphStyle

        // Add text view directly to page (text scrolls via outer scroll view)
        pageContainer.addSubview(textView)

        // Document view holds the page - use FlippedView so y=0 is at top
        documentView = FlippedView()
        documentView.wantsLayer = true
        documentView.addSubview(pageContainer)

        scrollView.documentView = documentView
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        applyTheme(currentTheme)
        updateShadowPath()
        updatePageCentering()
    }

    func getTextContent() -> String? {
        return textView.string
    }

    func setManuscriptInfo(title: String, author: String) {
        manuscriptTitle = title
        manuscriptAuthor = author
        updatePageCentering()
    }

    func toggleBold() {
        guard let textStorage = textView.textStorage else { return }
        guard let selectedRange = textView.selectedRanges.first?.rangeValue else { return }

        let fontManager = NSFontManager.shared

        if selectedRange.length == 0 {
            // Toggle for typing attributes
            if let currentFont = textView.typingAttributes[.font] as? NSFont {
                let traits = fontManager.traits(of: currentFont)
                let newFont = traits.contains(.boldFontMask)
                    ? fontManager.convert(currentFont, toNotHaveTrait: .boldFontMask)
                    : fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
                textView.typingAttributes[.font] = newFont
            }
            return
        }

        // Apply to selected text, preserving font size
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, _ in
            guard let currentFont = value as? NSFont else { return }
            let traits = fontManager.traits(of: currentFont)
            let newFont = traits.contains(.boldFontMask)
                ? fontManager.convert(currentFont, toNotHaveTrait: .boldFontMask)
                : fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
            textStorage.addAttribute(.font, value: newFont, range: range)
        }
        textStorage.endEditing()
    }

    func toggleItalic() {
        guard let textStorage = textView.textStorage else { return }
        guard let selectedRange = textView.selectedRanges.first?.rangeValue else { return }

        let fontManager = NSFontManager.shared

        if selectedRange.length == 0 {
            // Toggle for typing attributes
            if let currentFont = textView.typingAttributes[.font] as? NSFont {
                let traits = fontManager.traits(of: currentFont)
                let newFont = traits.contains(.italicFontMask)
                    ? fontManager.convert(currentFont, toNotHaveTrait: .italicFontMask)
                    : fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
                textView.typingAttributes[.font] = newFont
            }
            return
        }

        // Apply to selected text, preserving font size
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, _ in
            guard let currentFont = value as? NSFont else { return }
            let traits = fontManager.traits(of: currentFont)
            let newFont = traits.contains(.italicFontMask)
                ? fontManager.convert(currentFont, toNotHaveTrait: .italicFontMask)
                : fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
            textStorage.addAttribute(.font, value: newFont, range: range)
        }
        textStorage.endEditing()
    }

    func toggleUnderline() {
        guard let textStorage = textView.textStorage else { return }
        guard let selectedRange = textView.selectedRanges.first?.rangeValue else { return }

        if selectedRange.length == 0 {
            let current = (textView.typingAttributes[.underlineStyle] as? Int) ?? 0
            let next = current == 0 ? NSUnderlineStyle.single.rawValue : 0
            textView.typingAttributes[.underlineStyle] = next == 0 ? nil : next
            return
        }

        var hasUnderline = false
        textStorage.enumerateAttribute(.underlineStyle, in: selectedRange, options: []) { value, _, stop in
            if let intValue = value as? Int, intValue != 0 {
                hasUnderline = true
                stop.pointee = true
            }
        }

        textStorage.beginEditing()
        if hasUnderline {
            textStorage.removeAttribute(.underlineStyle, range: selectedRange)
        } else {
            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
        }
        textStorage.endEditing()
    }

    func setAlignment(_ alignment: NSTextAlignment) {
        let shouldClearFirstLineIndent = (alignment == .center)

        applyParagraphEditsToSelectedParagraphs { style in
            style.alignment = alignment

            // Centered lines should not keep manuscript first-line indents.
            if shouldClearFirstLineIndent {
                style.headIndent = 0
                style.firstLineHeadIndent = 0
                style.tailIndent = 0
            }
        }

        if let defaultStyle = (textView.defaultParagraphStyle as? NSMutableParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle {
            defaultStyle.alignment = alignment

            if shouldClearFirstLineIndent {
                defaultStyle.headIndent = 0
                defaultStyle.firstLineHeadIndent = 0
                defaultStyle.tailIndent = 0
            } else if defaultStyle.firstLineHeadIndent == 0 {
                // Restore manuscript default when leaving centered mode.
                defaultStyle.firstLineHeadIndent = standardIndentStep
            }
            textView.defaultParagraphStyle = defaultStyle.copy() as? NSParagraphStyle
            refreshTypingAttributesUsingDefaultParagraphStyle()
        }
    }

    func setFontFamily(_ family: String) {
        applyFontChange { current in
            NSFontManager.shared.convert(current, toFamily: family)
        }
    }

    func setFontSize(_ size: CGFloat) {
        applyFontChange { current in
            NSFontManager.shared.convert(current, toSize: size)
        }
    }

    func toggleBulletedList() {
        togglePrefixList(
            isPrefixed: { $0.hasPrefix("• ") },
            makePrefix: { _ in "• " }
        )
    }

    func toggleNumberedList() {
        togglePrefixList(
            isPrefixed: { line in
                let trimmed = line
                guard let dot = trimmed.firstIndex(of: ".") else { return false }
                if dot == trimmed.startIndex { return false }
                let numberPart = trimmed[..<dot]
                return numberPart.allSatisfy { $0.isNumber } && trimmed[trimmed.index(after: dot)...].hasPrefix(" ")
            },
            makePrefix: { index in "\(index + 1). " }
        )
    }

    func insertPageBreak() {
        // Use form feed as a lightweight page-break marker.
        textView.insertText("\u{000C}", replacementRange: textView.selectedRange())
    }

    func insertColumnBreak() {
        guard let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()

        // Insert a line break that forces text to next column in the same text block row
        let separator = "\n"
        let attrs = textView.typingAttributes
        let breakString = NSAttributedString(string: separator, attributes: attrs)

        textStorage.insert(breakString, at: range.location)
        textView.setSelectedRange(NSRange(location: range.location + separator.count, length: 0))
    }

    func scrollToTop() {
        // Force scroll to absolute top by setting clip view origin to zero
        scrollView.contentView.scroll(to: NSPoint.zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        // Also try the text view method as backup
        textView.scrollToBeginningOfDocument(nil)
    }

    func indent() {
        adjustIndent(by: standardIndentStep)
    }

    func outdent() {
        adjustIndent(by: -standardIndentStep)
    }

    func setPageMargins(left: CGFloat, right: CGFloat) {
        let leftMargin = max(0, left)
        let rightMargin = max(0, right)

        let availableWidth = max(36, pageContainer.bounds.width - leftMargin - rightMargin)
        let availableHeight = max(36, pageContainer.bounds.height - (standardMargin * 2 * editorZoom))

        let newFrame = NSRect(
            x: leftMargin,
            y: standardMargin * editorZoom,
            width: availableWidth,
            height: availableHeight
        )

        textView.frame = newFrame
        textView.minSize = NSSize(width: newFrame.width, height: newFrame.height)
        textView.maxSize = NSSize(width: newFrame.width, height: .greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(width: newFrame.width, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        updatePageCentering()
    }

    func setFirstLineIndent(_ indent: CGFloat) {
        applyParagraphEditsToSelectedParagraphs { style in
            style.firstLineHeadIndent = style.headIndent + indent
        }

        if let defaultStyle = (textView.defaultParagraphStyle as? NSMutableParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle {
            defaultStyle.firstLineHeadIndent = defaultStyle.headIndent + indent
            textView.defaultParagraphStyle = defaultStyle.copy() as? NSParagraphStyle
            refreshTypingAttributesUsingDefaultParagraphStyle()
        }
    }

    func attributedContent() -> NSAttributedString {
        (textView.textStorage?.copy() as? NSAttributedString) ?? NSAttributedString(string: textView.string)
    }

    func plainTextContent() -> String {
        textView.string
    }

    func rtfData() throws -> Data {
        let attributed = exportReadyAttributedContent()
        let fullRange = NSRange(location: 0, length: attributed.length)
        guard let data = attributed.rtf(from: fullRange, documentAttributes: [:]) else {
            throw NSError(domain: "QuillPilot", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate RTF."])
        }
        return data
    }

    /// Returns an attributed string with paragraph, font, and color attributes normalized for export.
    /// This prevents fallback defaults (e.g., all-bold, left-justified) when generating DOCX.
    func exportReadyAttributedContent() -> NSAttributedString {
        // Ensure the text storage has consistent attributes before exporting
        if let storage = textView.textStorage {
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.fixAttributes(in: fullRange)
        }

        let normalized = NSMutableAttributedString(attributedString: attributedContent())
        let fullString = normalized.string as NSString
        let defaultParagraph = textView.defaultParagraphStyle ?? NSParagraphStyle.default
        let defaultFont = textView.font ?? NSFont.systemFont(ofSize: 12)
        let defaultColor = currentTheme.textColor

        // Reapply catalog-defined paragraph and font attributes based on stored style name
        var location = 0
        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
            if let styleName = normalized.attribute(styleAttributeKey, at: paragraphRange.location, effectiveRange: nil) as? String,
               let definition = StyleCatalog.shared.style(named: styleName) {
                let paragraph = paragraphStyle(from: definition)
                let font = font(from: definition)
                let textColor = color(fromHex: definition.textColorHex, fallback: defaultColor)
                let backgroundColor = definition.backgroundColorHex.flatMap { color(fromHex: $0, fallback: .clear) }

                // Apply paragraph and font at paragraph level; colors applied per-run below to preserve inline formatting
                normalized.addAttribute(.paragraphStyle, value: paragraph, range: paragraphRange)
                normalized.addAttribute(.font, value: font, range: paragraphRange)

                // Apply catalog colors per run to preserve any inline color overrides
                normalized.enumerateAttributes(in: paragraphRange, options: []) { attrs, runRange, _ in
                    if attrs[.foregroundColor] == nil {
                        normalized.addAttribute(.foregroundColor, value: textColor, range: runRange)
                    }
                    if let backgroundColor, attrs[.backgroundColor] == nil {
                        normalized.addAttribute(.backgroundColor, value: backgroundColor, range: runRange)
                    }
                }
            } else {
                // Paragraph without a catalog style tag: try to infer a catalog style based on size/alignment and apply it
                let attrs = normalized.attributes(at: paragraphRange.location, effectiveRange: nil)
                let paragraph = (attrs[.paragraphStyle] as? NSParagraphStyle) ?? defaultParagraph
                let font = (attrs[.font] as? NSFont) ?? defaultFont

                let size = font.pointSize
                let alignment = paragraph.alignment

                let inferredStyleName: String?
                if size >= 21.5 && alignment == .center {
                    inferredStyleName = "Book Title"
                } else if size >= 16.5 && size < 21.5 && alignment == .center {
                    inferredStyleName = "Chapter Title"
                } else if size >= 13.5 && size < 16.5 && alignment == .center {
                    inferredStyleName = "Subtitle"
                } else {
                    inferredStyleName = "Body"
                }

                if let styleName = inferredStyleName, let definition = StyleCatalog.shared.style(named: styleName) {
                    let para = paragraphStyle(from: definition)
                    let styleFont = self.font(from: definition)
                    let styleColor = color(fromHex: definition.textColorHex, fallback: defaultColor)
                    let bgColor = definition.backgroundColorHex.flatMap { color(fromHex: $0, fallback: .clear) }

                    normalized.addAttribute(styleAttributeKey, value: styleName, range: paragraphRange)
                    normalized.addAttribute(.paragraphStyle, value: para, range: paragraphRange)
                    normalized.addAttribute(.font, value: styleFont, range: paragraphRange)
                    normalized.enumerateAttributes(in: paragraphRange, options: []) { attrs, runRange, _ in
                        if attrs[.foregroundColor] == nil {
                            normalized.addAttribute(.foregroundColor, value: styleColor, range: runRange)
                        }
                        if let bgColor, attrs[.backgroundColor] == nil {
                            normalized.addAttribute(.backgroundColor, value: bgColor, range: runRange)
                        }
                    }
                } else {
                    // No inferred style: only ensure paragraph style exists, preserve existing colors/fonts
                    let hasParagraph = normalized.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) != nil
                    if !hasParagraph {
                        normalized.addAttribute(.paragraphStyle, value: defaultParagraph, range: paragraphRange)
                    }
                }
            }
            location = NSMaxRange(paragraphRange)
        }

        // Ensure every paragraph carries an explicit paragraph style
        location = 0
        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
            let hasParagraphStyle = normalized.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) != nil
            if !hasParagraphStyle {
                normalized.addAttribute(.paragraphStyle, value: defaultParagraph, range: paragraphRange)
            }
            location = NSMaxRange(paragraphRange)
        }

        // Ensure runs have font and color; preserve loaded values, only fill true gaps
        normalized.enumerateAttributes(in: NSRange(location: 0, length: normalized.length), options: []) { attrs, range, _ in
            if attrs[.font] == nil {
                normalized.addAttribute(.font, value: defaultFont, range: range)
            }
            if attrs[.foregroundColor] == nil {
                normalized.addAttribute(.foregroundColor, value: defaultColor, range: range)
            }
        }

        return normalized
    }


    func shunnManuscriptRTFData(documentTitle: String) throws -> Data {
        // Shunn standard manuscript format:
        // - Courier 12pt (or Times New Roman 12pt for prose)
        // - Double-spaced
        // - 1" margins all around
        // - 0.5" first-line indent
        // - Title page: title centered, author name below, contact info lower left

        let attributed = attributedContent()
        let mutable = NSMutableAttributedString(attributedString: attributed)

        // Create Shunn paragraph style
        let shunnStyle = NSMutableParagraphStyle()
        shunnStyle.alignment = .left
        shunnStyle.firstLineHeadIndent = 36  // 0.5" indent
        shunnStyle.headIndent = 0
        shunnStyle.tailIndent = 0
        shunnStyle.lineSpacing = 12  // Double spacing
        shunnStyle.paragraphSpacing = 0
        shunnStyle.paragraphSpacingBefore = 0

        // Apply Shunn formatting to all body text
        let fullRange = NSRange(location: 0, length: mutable.length)
        let shunnFont = NSFont(name: "Courier", size: 12) ?? NSFont(name: "Times New Roman", size: 12) ?? NSFont.systemFont(ofSize: 12)

        mutable.addAttribute(.font, value: shunnFont, range: fullRange)
        mutable.addAttribute(.paragraphStyle, value: shunnStyle.copy(), range: fullRange)

        // Generate RTF
        guard let data = mutable.rtf(from: fullRange, documentAttributes: [:]) else {
            throw NSError(domain: "QuillPilot", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate Shunn manuscript RTF."])
        }

        return data
    }
    func pdfData() -> Data {
        pageContainer.dataWithPDF(inside: pageContainer.bounds)
    }

    func printPDFData() -> Data {
        // Create a clean text view without background for printing
        let printWidth: CGFloat = 612
        let printHeight: CGFloat = 792
        let margin = standardMargin

        let printView = NSView(frame: NSRect(x: 0, y: 0, width: printWidth, height: printHeight))

        let printTextView = NSTextView(frame: printView.bounds.insetBy(dx: margin, dy: margin))
        printTextView.backgroundColor = .white
        printTextView.textStorage?.setAttributedString(textView.attributedString())
        printTextView.isHorizontallyResizable = false
        printTextView.isVerticallyResizable = true
        printTextView.textContainer?.containerSize = NSSize(width: printTextView.frame.width, height: CGFloat.greatestFiniteMagnitude)

        // Force layout
        printTextView.layoutManager?.ensureLayout(for: printTextView.textContainer!)
        let usedRect = printTextView.layoutManager?.usedRect(for: printTextView.textContainer!) ?? .zero
        let totalHeight = max(printHeight, usedRect.height + margin * 2)

        printView.frame.size.height = totalHeight
        printTextView.frame = printView.bounds.insetBy(dx: margin, dy: margin)
        printView.addSubview(printTextView)

        return printView.dataWithPDF(inside: printView.bounds)
    }

    func setAttributedContent(_ attributed: NSAttributedString) {
        // Before setting content, detect and re-tag catalog styles based on font/size/alignment
        let retagged = detectAndRetagStyles(in: attributed)
        textView.textStorage?.setAttributedString(retagged)

        // Verify colors after setting into textStorage
        NSLog("=== AFTER setAttributedString ===")
        if let storage = textView.textStorage {
            let str = storage.string as NSString
            var loc = 0
            var count = 0
            while loc < str.length && count < 3 {
                let pRange = str.paragraphRange(for: NSRange(location: loc, length: 0))
                let attrs = storage.attributes(at: pRange.location, effectiveRange: nil)
                let text = str.substring(with: pRange).prefix(20)
                NSLog("P[\(pRange.location)]: \"\(text)\" color=\(attrs[.foregroundColor] ?? "nil")")
                loc = NSMaxRange(pRange)
                count += 1
            }
        }
        NSLog("=================================")

        // Use neutral defaults for new typing so loaded heading styles don't bleed into new paragraphs
        let neutralParagraph = NSMutableParagraphStyle()
        neutralParagraph.alignment = .left
        neutralParagraph.lineHeightMultiple = 2.0
        neutralParagraph.paragraphSpacing = 0
        neutralParagraph.firstLineHeadIndent = 36
        textView.defaultParagraphStyle = neutralParagraph
        textView.font = NSFont(name: "Times New Roman", size: 12) ?? NSFont.systemFont(ofSize: 12)
        // Don't set textView.textColor - it can interfere with attributed string colors
        // textView.textColor = currentTheme.textColor
        refreshTypingAttributesUsingDefaultParagraphStyle()

        // Final verification of colors after all setup
        NSLog("=== FINAL CHECK (after all setup) ===")
        if let storage = textView.textStorage, storage.length > 0 {
            let attrs = storage.attributes(at: 0, effectiveRange: nil)
            NSLog("First char color: \(attrs[.foregroundColor] ?? "nil")")
        }
        NSLog("=====================================")

        // Force immediate layout and page resize to accommodate all content
        updatePageCentering()
        scrollToTop()
        delegate?.textDidChange()
    }

    private func detectAndRetagStyles(in attributed: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let fullString = mutable.string as NSString

        var location = 0
        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))

            // Get paragraph attributes
            let attrs = mutable.attributes(at: paragraphRange.location, effectiveRange: nil)
            guard let font = attrs[.font] as? NSFont,
                  let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle else {
                location = NSMaxRange(paragraphRange)
                continue
            }

            let fontSize = font.pointSize
            let alignment = paragraphStyle.alignment
            let existingColor = attrs[.foregroundColor] as? NSColor

            NSLog("detectAndRetagStyles P[\(paragraphRange.location)]: font=\(fontSize)pt align=\(alignment.rawValue) existingColor=\(existingColor?.description ?? "nil")")

            // Match against catalog style definitions
            let styleName: String?
            if fontSize >= 21.5 && alignment == .center {
                styleName = "Book Title"
            } else if fontSize >= 16.5 && fontSize < 21.5 && alignment == .center {
                styleName = "Chapter Title"
            } else if fontSize >= 13.5 && fontSize < 16.5 && alignment == .center {
                styleName = "Subtitle"
            } else {
                styleName = "Body"
            }

            if let styleName = styleName,
               let definition = StyleCatalog.shared.style(named: styleName) {
                NSLog("  -> Matched style '\(styleName)'")
                // Tag the paragraph
                mutable.addAttribute(styleAttributeKey, value: styleName, range: paragraphRange)

                // Apply catalog style colors and formatting to make them visible immediately
                let catalogParagraph = self.paragraphStyle(from: definition)
                let catalogFont = self.font(from: definition)
                let textColor = self.color(fromHex: definition.textColorHex, fallback: currentTheme.textColor)
                let backgroundColor = definition.backgroundColorHex.flatMap { self.color(fromHex: $0, fallback: .clear) }

                mutable.addAttribute(.paragraphStyle, value: catalogParagraph, range: paragraphRange)
                mutable.addAttribute(.font, value: catalogFont, range: paragraphRange)

                mutable.enumerateAttributes(in: paragraphRange, options: []) { attrs, runRange, _ in
                    let existingFg = attrs[.foregroundColor] as? NSColor
                    if existingFg == nil {
                        NSLog("    -> Adding catalog color \(textColor) at run \(runRange.location)")
                        mutable.addAttribute(.foregroundColor, value: textColor, range: runRange)
                    } else {
                        NSLog("    -> Preserving existing color \(existingFg!) at run \(runRange.location)")
                    }
                    if let backgroundColor = backgroundColor, attrs[.backgroundColor] == nil {
                        mutable.addAttribute(.backgroundColor, value: backgroundColor, range: runRange)
                    }
                }
            }

            location = NSMaxRange(paragraphRange)
        }

        return mutable
    }

    func setPlainTextContent(_ text: String) {
        let attributed = NSAttributedString(string: text, attributes: textView.typingAttributes)
        setAttributedContent(attributed)
    }

    func clearAll() {
        // Reset to single column first
        setColumnCount(1)

        // Clear all text
        textView.string = ""

        // Reset to default formatting
        let font = NSFont(name: "Times New Roman", size: 12) ?? NSFont.systemFont(ofSize: 12)
        textView.font = font

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 2.0
        paragraphStyle.paragraphSpacing = 12
        paragraphStyle.firstLineHeadIndent = standardIndentStep
        textView.defaultParagraphStyle = paragraphStyle.copy() as? NSParagraphStyle

        textView.typingAttributes = [
            .font: font,
            .foregroundColor: currentTheme.textColor,
            .paragraphStyle: paragraphStyle.copy() as Any,
            styleAttributeKey: "Body Text"
        ]

        delegate?.textDidChange()
        updatePageCentering()
    }

    func applyStyle(named styleName: String) {
        let styledByCatalog = applyCatalogStyle(named: styleName)
        if styledByCatalog {
            if styleName == "Book Title" {
                if let range = textView.selectedRanges.first as? NSRange, range.length == 0 {
                    let paragraphRange = (textView.string as NSString).paragraphRange(for: range)
                    let titleText = (textView.string as NSString).substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !titleText.isEmpty {
                        delegate?.titleDidChange(titleText)
                    }
                }
            }
            applyStyleAttribute(styleName)
            return
        }
        switch styleName {
        // MARK: Front Matter
        case "Book Title":
            applyManuscriptParagraphStyle { style in
                style.alignment = .center
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 18
            }
            applyFontChange { current in
                let base = NSFont(name: "Times New Roman", size: 24) ?? current
                return base
            }

            // Sync title to header
            if let range = textView.selectedRanges.first as? NSRange, range.length == 0 {
                let paragraphRange = (textView.string as NSString).paragraphRange(for: range)
                let titleText = (textView.string as NSString).substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !titleText.isEmpty {
                    delegate?.titleDidChange(titleText)
                }
            }
case "Book Subtitle":
            applyManuscriptParagraphStyle { style in
                style.alignment = .center
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 12
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 16) ?? current
            }
        case "Author Name":
            applyManuscriptParagraphStyle { style in
                style.alignment = .center
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 12
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 14) ?? current
            }
        case "Front Matter Heading":
            applyManuscriptParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 12
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 14) ?? current
            }
        case "Epigraph":
            applyManuscriptParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 36
                style.headIndent = 36
                style.tailIndent = -36
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 12
            }
            applyFontChange { current in
                NSFontManager.shared.convert(current, toHaveTrait: .italicFontMask)
            }
        case "Epigraph Attribution":
            applyManuscriptParagraphStyle { style in
                style.alignment = .right
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 6
                style.paragraphSpacing = 18
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 11) ?? current
            }

        // MARK: Structural
        case "Part Title":
            applyManuscriptParagraphStyle { style in
                style.alignment = .center
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 18
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 20) ?? current
            }
        case "Part Subtitle":
            applyManuscriptParagraphStyle { style in
                style.alignment = .center
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 18
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 14) ?? current
            }
        case "Chapter Number":
            applyManuscriptParagraphStyle { style in
                style.alignment = .center
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 12
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 14) ?? current
            }
        case "Chapter Title":
            applyManuscriptParagraphStyle { style in
                style.alignment = .center
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 18
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 18) ?? current
            }
        case "Chapter Subtitle":
            applyManuscriptParagraphStyle { style in
                style.alignment = .center
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 18
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 14) ?? current
            }

        // MARK: Body Text
        case "Body Text":
            applyManuscriptParagraphStyle { style in
                style.alignment = .left
                style.headIndent = 0
                style.firstLineHeadIndent = standardIndentStep
                style.tailIndent = 0
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 0
            }
            applyFontChange { _ in
                NSFont(name: "Times New Roman", size: 12) ?? NSFont.systemFont(ofSize: 12)
            }
        case "Body Text – No Indent":
            applyManuscriptParagraphStyle { style in
                style.alignment = .left
                style.headIndent = 0
                style.firstLineHeadIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 0
            }
            applyFontChange { _ in
                NSFont(name: "Times New Roman", size: 12) ?? NSFont.systemFont(ofSize: 12)
            }
        case "Heading 1":
            applyManuscriptParagraphStyle { style in
                style.alignment = .left
                style.headIndent = 0
                style.firstLineHeadIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 12
            }
            applyFontChange { current in
                let base = NSFont(name: "Times New Roman", size: 14) ?? current
                return NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
            }
        case "Heading 2":
            applyManuscriptParagraphStyle { style in
                style.alignment = .left
                style.headIndent = 0
                style.firstLineHeadIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 18
                style.paragraphSpacing = 6
            }
            applyFontChange { current in
                let base = NSFont(name: "Times New Roman", size: 13) ?? current
                return NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
            }
        case "Heading 3":
            applyManuscriptParagraphStyle { style in
                style.alignment = .left
                style.headIndent = 0
                style.firstLineHeadIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 6
            }
            applyFontChange { current in
                let base = NSFont(name: "Times New Roman", size: 12) ?? current
                return NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
            }
        case "Scene Break":
            applyManuscriptParagraphStyle { style in
                style.alignment = .center
                style.headIndent = 0
                style.firstLineHeadIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 18
                style.paragraphSpacing = 18
            }
        case "Dialogue":
            applyStyle(named: "Body Text")
        case "Internal Thought":
            applyStyle(named: "Body Text")
            applyFontChange { current in
                NSFontManager.shared.convert(current, toHaveTrait: .italicFontMask)
            }
        case "Letter / Document":
            applyManuscriptParagraphStyle { style in
                style.alignment = .left
                style.headIndent = 36
                style.firstLineHeadIndent = 36
                style.tailIndent = -36
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 12
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 11) ?? current
            }

        // MARK: Quotes
        case "Block Quote":
            applyManuscriptParagraphStyle { style in
                style.alignment = .left
                style.headIndent = 36
                style.firstLineHeadIndent = 36
                style.tailIndent = -36
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 12
            }
        case "Block Quote Attribution":
            applyManuscriptParagraphStyle { style in
                style.alignment = .right
                style.headIndent = 36
                style.firstLineHeadIndent = 36
                style.tailIndent = -36
                style.paragraphSpacingBefore = 6
                style.paragraphSpacing = 12
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 11) ?? current
            }

        // MARK: Lists & Inserts
        case "Bullet List":
            toggleBulletedList()
        case "Numbered List":
            toggleNumberedList()
        case "Sidebar":
            applyManuscriptParagraphStyle { style in
                style.alignment = .left
                style.headIndent = 18
                style.firstLineHeadIndent = 18
                style.tailIndent = -18
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 12
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 11) ?? current
            }
        case "Callout":
            applyManuscriptParagraphStyle { style in
                style.alignment = .left
                style.headIndent = 18
                style.firstLineHeadIndent = 18
                style.tailIndent = -18
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 12
                style.lineHeightMultiple = 1.0
            }
            applyFontChange { current in
                let base = NSFont(name: "Times New Roman", size: 11) ?? current
                return NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
            }
        case "Figure Caption", "Table Caption":
            applyManuscriptParagraphStyle { style in
                style.alignment = .left
                style.headIndent = 18
                style.firstLineHeadIndent = 18
                style.tailIndent = 0
                style.paragraphSpacingBefore = 6
                style.paragraphSpacing = 12
                style.lineHeightMultiple = 1.0
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 11) ?? current
            }
        case "Footnote / Endnote":
            applyManuscriptParagraphStyle { style in
                style.alignment = .left
                style.headIndent = 0
                style.firstLineHeadIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 6
                style.paragraphSpacing = 6
                style.lineHeightMultiple = 1.0
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 10) ?? current
            }

        // MARK: Back Matter
        case "Back Matter Heading":
            applyManuscriptParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 12
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 14) ?? current
            }
        case "Notes Entry", "Bibliography Entry", "Index Entry":
            applyManuscriptParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 18
                style.tailIndent = 0
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 6
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 11) ?? current
            }

        // MARK: Screenplay
        case "Screenplay — Slugline":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 0
            }
            applyScreenplayFont()
        case "Screenplay — Action":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 0
            }
            applyScreenplayFont()
        case "Screenplay — Character":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 158
                style.headIndent = 158
                style.tailIndent = -72
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 0
            }
            applyScreenplayFont()
        case "Screenplay — Parenthetical":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 115
                style.headIndent = 115
                style.tailIndent = -72
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 0
            }
            applyScreenplayFont()
        case "Screenplay — Dialogue":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 72
                style.headIndent = 72
                style.tailIndent = -72
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 0
            }
            applyScreenplayFont()
        case "Screenplay — Transition":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .right
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 0
            }
            applyScreenplayFont()
        case "Screenplay — Shot":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 0
            }
            applyScreenplayFont()

        // MARK: Inline character styles
        case "Emphasis (Italic)":
            toggleItalic()
        case "Strong (Bold)":
            toggleBold()
        case "Superscript":
            applyBaselineOffset(+6)
        case "Subscript":
            applyBaselineOffset(-6)
        case "Small Caps":
            applySmallCaps()

        default:
            break
        }

        applyStyleAttribute(styleName)
    }

    private func applyStyleAttribute(_ styleName: String) {
        textView.typingAttributes[styleAttributeKey] = styleName

        if let selected = textView.selectedRanges.first as? NSRange {
            let paragraphRange = (textView.string as NSString).paragraphRange(for: selected)
            textView.textStorage?.addAttribute(styleAttributeKey, value: styleName, range: paragraphRange)
        }
    }

    private func applyCatalogStyle(named styleName: String) -> Bool {
        guard let definition = StyleCatalog.shared.style(named: styleName) else { return false }

        let paragraph = paragraphStyle(from: definition)
        let font = font(from: definition)
        let textColor = color(fromHex: definition.textColorHex, fallback: currentTheme.textColor)
        let backgroundColor = definition.backgroundColorHex.flatMap { color(fromHex: $0, fallback: .clear) }

        applyParagraphEditsToSelectedParagraphs { style in
            style.setParagraphStyle(paragraph)
        }

        if let storage = textView.textStorage {
            let selection = textView.selectedRange()
            let range = selection.length == 0 ? (textView.string as NSString).paragraphRange(for: selection) : selection
            storage.addAttribute(.paragraphStyle, value: paragraph, range: range)
            storage.addAttribute(.font, value: font, range: range)
            storage.addAttribute(.foregroundColor, value: textColor, range: range)
            if let backgroundColor {
                storage.addAttribute(.backgroundColor, value: backgroundColor, range: range)
            } else {
                storage.removeAttribute(.backgroundColor, range: range)
            }
        }

        return true
    }

    private func paragraphStyle(from definition: StyleDefinition) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment(rawValue: definition.alignmentRawValue) ?? .left
        style.lineHeightMultiple = definition.lineHeightMultiple
        style.paragraphSpacingBefore = definition.spacingBefore
        style.paragraphSpacing = definition.spacingAfter
        style.headIndent = definition.headIndent
        style.firstLineHeadIndent = definition.firstLineIndent
        style.tailIndent = definition.tailIndent
        style.lineBreakMode = .byWordWrapping
        return style.copy() as! NSParagraphStyle
    }

    private func font(from definition: StyleDefinition) -> NSFont {
        var font = NSFont(name: definition.fontName, size: definition.fontSize) ?? NSFont.systemFont(ofSize: definition.fontSize)
        if definition.isBold {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
        if definition.isItalic {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        return font
    }

    private func color(fromHex hex: String, fallback: NSColor) -> NSColor {
        NSColor(hex: hex) ?? fallback
    }

    struct OutlineEntry {
        let title: String
        let level: Int
        let range: NSRange
        let page: Int?
    }

    func buildOutlineEntries() -> [OutlineEntry] {
        guard let storage = textView.textStorage, let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else {
            return []
        }

        let levels: [String: Int] = [
            "Part Title": 0,
            "Chapter Number": 1,
            "Chapter Title": 1,
            "Heading 1": 1,
            "Heading 2": 2,
            "Heading 3": 3
        ]

        var results: [OutlineEntry] = []
        let fullString = storage.string as NSString
        var location = 0
        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
            guard paragraphRange.length > 0 else { break }

            let styleName = storage.attribute(styleAttributeKey, at: paragraphRange.location, effectiveRange: nil) as? String
            if let styleName, let level = levels[styleName] {
                let rawTitle = fullString.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !rawTitle.isEmpty {
                    let glyphRange = layoutManager.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
                    let bounds = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                    let pageHeight = pageHeight * editorZoom
                    let pageIndex = max(0, Int(floor(bounds.midY / pageHeight))) + 1
                    results.append(OutlineEntry(title: rawTitle, level: level, range: paragraphRange, page: pageIndex))
                }
            }

            location = NSMaxRange(paragraphRange)
        }

        return results
    }

    private func manuscriptBaseParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineHeightMultiple = 2.0
        style.paragraphSpacingBefore = 0
        style.paragraphSpacing = 0
        style.headIndent = 0
        style.firstLineHeadIndent = standardIndentStep
        style.tailIndent = 0
        style.lineBreakMode = .byWordWrapping
        return style.copy() as! NSParagraphStyle
    }

    private func applyManuscriptParagraphStyle(_ configure: (NSMutableParagraphStyle) -> Void) {
        let base = manuscriptBaseParagraphStyle()
        applyParagraphEditsToSelectedParagraphs { style in
            style.setParagraphStyle(base)
            configure(style)
        }
    }

    private func screenplayBaseParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineHeightMultiple = 1.0
        style.paragraphSpacingBefore = 0
        style.paragraphSpacing = 0
        style.headIndent = 0
        style.firstLineHeadIndent = 0
        style.tailIndent = 0
        style.lineBreakMode = .byWordWrapping
        return style.copy() as! NSParagraphStyle
    }

    private func applyScreenplayParagraphStyle(_ configure: (NSMutableParagraphStyle) -> Void) {
        let base = screenplayBaseParagraphStyle()
        applyParagraphEditsToSelectedParagraphs { style in
            style.setParagraphStyle(base)
            configure(style)
        }
    }

    private func applyScreenplayFont() {
        applyFontChange { current in
            NSFont(name: "Courier New", size: 12) ?? current
        }
    }

    private func applyScreenplayPageDefaultsIfNeeded() {
        // Screenplay industry defaults: 1.5" left, 1" right (US Letter).
        setPageMargins(left: 108, right: 72)
    }

    private func applyBaselineOffset(_ offset: CGFloat) {
        guard let textStorage = textView.textStorage else { return }
        guard let selectedRange = textView.selectedRanges.first?.rangeValue else { return }
        if selectedRange.length == 0 { return }
        textStorage.beginEditing()
        textStorage.addAttribute(.baselineOffset, value: offset, range: selectedRange)
        textStorage.endEditing()
    }

    private func applySmallCaps() {
        // Best-effort small caps using font feature settings when available.
        applyFontChange { current in
            let attrs: [NSFontDescriptor.AttributeName: Any] = [
                .featureSettings: [
                    [
                        NSFontDescriptor.FeatureKey.typeIdentifier: kLowerCaseType,
                        NSFontDescriptor.FeatureKey.selectorIdentifier: kLowerCaseSmallCapsSelector
                    ]
                ]
            ]
            let desc = current.fontDescriptor.addingAttributes(attrs)
            return NSFont(descriptor: desc, size: current.pointSize) ?? current
        }
    }

    func updatePageCentering() {
        guard let scrollView else { return }

        let visibleWidth = scrollView.contentView.bounds.width
        let scaledPageWidth = pageWidth * editorZoom
        let scaledPageHeight = pageHeight * editorZoom
        let pageX = max((visibleWidth - scaledPageWidth) / 2, 0)

        // Calculate number of pages by walking laid out line fragments at correct width
        var numPages = 1
        if let layoutManager = textView.layoutManager,
           let textContainer = textView.textContainer {
            let activeHeaderHeight = showHeaders ? headerHeight : 0
            let activeFooterHeight = showFooters ? footerHeight : 0
            let pageTextHeight = scaledPageHeight - (standardMargin * 2 + activeHeaderHeight + activeFooterHeight) * editorZoom
            let textWidth = scaledPageWidth - (standardMargin * 2) * editorZoom

            // Preserve current state
            let oldSize = textContainer.size
            let oldExclusions = textContainer.exclusionPaths

            // Measure with clean container sized to single-page text area
            textContainer.exclusionPaths = []
            textContainer.size = NSSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude)
            layoutManager.textContainerChangedGeometry(textContainer)

            // Force layout and iterate line fragments to accumulate height into pages
            layoutManager.ensureLayout(for: textContainer)
            let glyphRange = layoutManager.glyphRange(for: textContainer)
            var currentHeight: CGFloat = 0
            var pages: Int = 1
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
                let lineHeight = usedRect.height
                if currentHeight + lineHeight > pageTextHeight {
                    pages += 1
                    currentHeight = lineHeight
                } else {
                    currentHeight += lineHeight
                }
            }

            numPages = max(1, pages)

            // Restore container state
            textContainer.size = oldSize
            textContainer.exclusionPaths = oldExclusions
        }

        // Total height includes all pages plus gaps between them
        let pageGap: CGFloat = 20
        let totalHeight = CGFloat(numPages) * scaledPageHeight + CGFloat(numPages - 1) * pageGap

        pageContainer.frame = NSRect(x: pageX, y: 0, width: scaledPageWidth, height: totalHeight)

        // Text view spans all pages with proper margins for header/footer
        let activeHeaderHeight = showHeaders ? headerHeight : 0
        let activeFooterHeight = showFooters ? footerHeight : 0
        let textInsetTop = (standardMargin + activeHeaderHeight) * editorZoom
        let textInsetBottom = (standardMargin + activeFooterHeight) * editorZoom
        let textInsetH = standardMargin * editorZoom
        textView.frame = NSRect(
            x: textInsetH,
            y: textInsetBottom,
            width: scaledPageWidth - (textInsetH * 2),
            height: totalHeight - textInsetTop - textInsetBottom
        )

        // Set text container inset to keep text within safe area
        textView.textContainerInset = NSSize(width: 0, height: 0)

        // Create exclusion paths for header/footer areas on each page
        if let textContainer = textView.textContainer {
            var exclusionPaths: [NSBezierPath] = []
            let pageGap: CGFloat = 20

            for pageNum in 0..<numPages {
                let pageYInContainer = CGFloat(pageNum) * (scaledPageHeight + pageGap)

                // Exclude header area at top of each page
                if showHeaders {
                    let headerY = pageYInContainer - textInsetBottom
                    let headerRect = NSRect(
                        x: 0,
                        y: headerY,
                        width: textView.frame.width,
                        height: textInsetTop
                    )
                    exclusionPaths.append(NSBezierPath(rect: headerRect))
                }

                // Exclude footer area at bottom of each page
                if showFooters {
                    let footerY = pageYInContainer + scaledPageHeight - textInsetBottom - textInsetTop
                    let footerRect = NSRect(
                        x: 0,
                        y: footerY,
                        width: textView.frame.width,
                        height: textInsetBottom
                    )
                    exclusionPaths.append(NSBezierPath(rect: footerRect))
                }

                // Exclude the gaps between pages
                if pageNum < numPages - 1 {
                    let gapY = pageYInContainer + scaledPageHeight - textInsetBottom
                    let gapRect = NSRect(
                        x: 0,
                        y: gapY,
                        width: textView.frame.width,
                        height: pageGap
                    )
                    exclusionPaths.append(NSBezierPath(rect: gapRect))
                }
            }

            textContainer.exclusionPaths = exclusionPaths
        }

        updateHeadersAndFooters(numPages)
        updateShadowPath()

        let docWidth = max(visibleWidth, pageX + scaledPageWidth + 20)
        let docHeight = totalHeight + 1000
        documentView.frame = NSRect(x: 0, y: 0, width: docWidth, height: docHeight)
    }

    private func updateHeadersAndFooters(_ numPages: Int) {
        // Clear existing
        headerViews.forEach { $0.removeFromSuperview() }
        footerViews.forEach { $0.removeFromSuperview() }
        pages.forEach { $0.removeFromSuperview() }
        headerViews.removeAll()
        footerViews.removeAll()
        pages.removeAll()

        let scaledPageWidth = pageWidth * editorZoom
        let scaledPageHeight = pageHeight * editorZoom
        let scaledHeaderHeight = headerHeight * editorZoom
        let scaledFooterHeight = footerHeight * editorZoom
        let margin = standardMargin * editorZoom

        for pageNum in 1...numPages {
            let pageY = CGFloat(pageNum - 1) * (scaledPageHeight + 20) // 20pt gap between pages

            // Create page background to visualize page boundaries (behind text)
            let pageView = NSView(frame: NSRect(
                x: 0,
                y: pageY,
                width: scaledPageWidth,
                height: scaledPageHeight
            ))
            pageView.wantsLayer = true
            pageView.layer?.backgroundColor = currentTheme.pageBackground.cgColor
            pageView.layer?.borderWidth = 1
            pageView.layer?.borderColor = currentTheme.pageBorder.cgColor
            pageContainer.addSubview(pageView, positioned: .below, relativeTo: textView)
            pages.append(pageView)

            // Header (top band)
            if showHeaders {
                let headerContent = headerText
                let headerField = NSTextField(labelWithString: headerContent)
                headerField.isEditable = false
                headerField.isSelectable = false
                headerField.isBordered = false
                headerField.backgroundColor = .clear
                headerField.font = NSFont(name: "Courier", size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                headerField.textColor = currentTheme.textColor.withAlphaComponent(0.5)
                headerField.alignment = .left
                headerField.frame = NSRect(
                    x: margin,
                    y: pageY + margin / 2,
                    width: scaledPageWidth - margin * 2,
                    height: scaledHeaderHeight
                )
                pageContainer.addSubview(headerField)
                headerViews.append(headerField)

                // Separator under header
                let headerLine = NSView(frame: NSRect(
                    x: margin,
                    y: pageY + margin / 2 + scaledHeaderHeight + 2,
                    width: scaledPageWidth - margin * 2,
                    height: 1
                ))
                headerLine.wantsLayer = true
                headerLine.layer?.backgroundColor = currentTheme.textColor.withAlphaComponent(0.2).cgColor
                pageContainer.addSubview(headerLine)
            }

            // Footer (bottom band)
            if showFooters {
                let footerContent: String
                if !footerText.isEmpty {
                    footerContent = footerText
                } else if showPageNumbers {
                    footerContent = pageNum > 1 ? "\(pageNum)" : ""
                } else {
                    footerContent = ""
                }
                let footerField = NSTextField(labelWithString: footerContent)
                footerField.isEditable = false
                footerField.isSelectable = false
                footerField.isBordered = false
                footerField.backgroundColor = .clear
                footerField.font = NSFont(name: "Courier", size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                footerField.textColor = currentTheme.textColor.withAlphaComponent(0.5)
                footerField.alignment = .right
                footerField.frame = NSRect(
                    x: margin,
                    y: pageY + scaledPageHeight - margin / 2 - scaledFooterHeight,
                    width: scaledPageWidth - margin * 2,
                    height: scaledFooterHeight
                )
                pageContainer.addSubview(footerField)
                footerViews.append(footerField)

                // Separator above footer
                let footerLine = NSView(frame: NSRect(
                    x: margin,
                    y: pageY + scaledPageHeight - margin / 2 - scaledFooterHeight - 2,
                    width: scaledPageWidth - margin * 2,
                    height: 1
                ))
                footerLine.wantsLayer = true
                footerLine.layer?.backgroundColor = currentTheme.textColor.withAlphaComponent(0.2).cgColor
                pageContainer.addSubview(footerLine)
            }
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updatePageCentering()
    }

    private func updateShadowPath() {
        let rect = CGRect(origin: .zero, size: pageContainer.bounds.size)
        pageContainer.layer?.shadowPath = CGPath(rect: rect, transform: nil)
    }

    func getStats() -> (wordCount: Int, charCount: Int) {
        let text = textView.string
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let chars = text.count
        return (words.count, chars)
    }

    func getColumnCount() -> Int {
        return textView.textContainer?.layoutManager?.textContainers.count ?? 1
    }

    func setColumnCount(_ columns: Int) {
        guard columns >= 2, columns <= 4 else { return }
        guard let textStorage = textView.textStorage else { return }

        let currentRange = textView.selectedRange()

        // Create text table for columns
        let textTable = NSTextTable()
        textTable.numberOfColumns = columns
        textTable.layoutAlgorithm = .automaticLayoutAlgorithm
        textTable.collapsesBorders = false

        // Light brown border color
        let borderColor = (ThemeManager.shared.currentTheme.headerBackground).withAlphaComponent(0.5)

        // Create attributed string with table blocks for each column
        let result = NSMutableAttributedString()

        for i in 0..<columns {
            let textBlock = NSTextTableBlock(table: textTable, startingRow: 0, rowSpan: 1, startingColumn: i, columnSpan: 1)

            // Add borders to each column
            textBlock.setBorderColor(borderColor, for: .minX)
            textBlock.setBorderColor(borderColor, for: .maxX)
            textBlock.setBorderColor(borderColor, for: .minY)
            textBlock.setBorderColor(borderColor, for: .maxY)

            // Set border width
            textBlock.setWidth(1.0, type: .absoluteValueType, for: .border)

            // Add padding for better spacing
            textBlock.setWidth(8.0, type: .absoluteValueType, for: .padding, edge: .minX)
            textBlock.setWidth(8.0, type: .absoluteValueType, for: .padding, edge: .maxX)
            textBlock.setWidth(8.0, type: .absoluteValueType, for: .padding, edge: .minY)
            textBlock.setWidth(8.0, type: .absoluteValueType, for: .padding, edge: .maxY)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.textBlocks = [textBlock]

            var attrs = textView.typingAttributes
            attrs[.paragraphStyle] = paragraphStyle

            let columnContent = NSAttributedString(string: "Column \(i + 1) content...\n", attributes: attrs)
            result.append(columnContent)
        }

        // Add final newline to exit table
        let finalNewline = NSAttributedString(string: "\n", attributes: textView.typingAttributes)
        result.append(finalNewline)

        textStorage.insert(result, at: currentRange.location)
        textView.setSelectedRange(NSRange(location: currentRange.location + 1, length: 0))
    }

    func applyTheme(_ theme: AppTheme) {
        currentTheme = theme
        view.layer?.backgroundColor = theme.pageAround.cgColor
        scrollView?.backgroundColor = theme.pageAround
        documentView?.layer?.backgroundColor = theme.pageAround.cgColor
        pageContainer?.layer?.backgroundColor = theme.pageBackground.cgColor
        pageContainer?.layer?.borderColor = theme.pageBorder.cgColor
        let shadowColor = NSColor.black.withAlphaComponent(theme == .day ? 0.3 : 0.65)
        pageContainer?.layer?.shadowColor = shadowColor.cgColor
        textView?.backgroundColor = theme.pageBackground
        textView?.textColor = theme.textColor
        textView?.insertionPointColor = theme.insertionPointColor

        if let font = textView?.font,
           let paragraphStyle = textView?.defaultParagraphStyle {
            textView?.typingAttributes = [
                .font: font,
                .foregroundColor: theme.textColor,
                .paragraphStyle: paragraphStyle
            ]
        }
    }

    private func adjustIndent(by delta: CGFloat) {
        applyParagraphEditsToSelectedParagraphs { style in
            let firstLineDelta = style.firstLineHeadIndent - style.headIndent
            let newHeadIndent = max(0, style.headIndent + delta)
            style.headIndent = newHeadIndent
            style.firstLineHeadIndent = newHeadIndent + firstLineDelta
        }

        if let defaultStyle = (textView.defaultParagraphStyle as? NSMutableParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle {
            let firstLineDelta = defaultStyle.firstLineHeadIndent - defaultStyle.headIndent
            let newHeadIndent = max(0, defaultStyle.headIndent + delta)
            defaultStyle.headIndent = newHeadIndent
            defaultStyle.firstLineHeadIndent = newHeadIndent + firstLineDelta
            textView.defaultParagraphStyle = defaultStyle.copy() as? NSParagraphStyle
            refreshTypingAttributesUsingDefaultParagraphStyle()
        }
    }

    private func applyParagraphEditsToSelectedParagraphs(_ edit: (NSMutableParagraphStyle) -> Void) {
        guard let textStorage = textView.textStorage else { return }
        guard let selected = textView.selectedRanges.first?.rangeValue else { return }
        let fullText = (textStorage.string as NSString)
        let paragraphsRange = fullText.paragraphRange(for: selected)

        textStorage.beginEditing()
        textStorage.enumerateAttribute(.paragraphStyle, in: paragraphsRange, options: []) { value, range, _ in
            let current = (value as? NSParagraphStyle) ?? textView.defaultParagraphStyle ?? NSParagraphStyle.default
            guard let mutable = current.mutableCopy() as? NSMutableParagraphStyle else { return }
            edit(mutable)
            textStorage.addAttribute(.paragraphStyle, value: mutable.copy() as! NSParagraphStyle, range: range)
        }
        textStorage.endEditing()
    }

    private func refreshTypingAttributesUsingDefaultParagraphStyle() {
        guard let font = textView.font else { return }
        guard let paragraphStyle = textView.defaultParagraphStyle else { return }
        let mutableStyle = (paragraphStyle as? NSMutableParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        if mutableStyle.lineHeightMultiple == 0 {
            mutableStyle.lineHeightMultiple = 2.0  // Ensure double-spacing
        }
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: currentTheme.textColor,
            .paragraphStyle: mutableStyle.copy() as! NSParagraphStyle
        ]
    }

    private func applyFontChange(_ transform: (NSFont) -> NSFont) {
        guard let textStorage = textView.textStorage else { return }
        let baseFont = (textView.typingAttributes[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: 16)
        guard let selectedRange = textView.selectedRanges.first?.rangeValue else { return }

        // If no selection, apply to the current paragraph (not the whole document)
        let fullText = (textStorage.string as NSString)
        let targetRange = selectedRange.length == 0 ? fullText.paragraphRange(for: selectedRange) : selectedRange

        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: targetRange, options: []) { value, range, _ in
            let current = (value as? NSFont) ?? baseFont
            let newFont = transform(current)
            textStorage.addAttribute(.font, value: newFont, range: range)
        }
        textStorage.endEditing()

        // Update typing attributes only for future typing at cursor position
        if selectedRange.length == 0 {
            let newTypingFont = transform(baseFont)
            textView.typingAttributes[.font] = newTypingFont
        }
    }

    private func togglePrefixList(isPrefixed: (String) -> Bool, makePrefix: (Int) -> String) {
        guard let textStorage = textView.textStorage else { return }
        guard let selectedRange = textView.selectedRanges.first?.rangeValue else { return }

        let fullText = textStorage.string as NSString
        let paragraphsRange = fullText.paragraphRange(for: selectedRange)

        var paragraphs: [(range: NSRange, text: String)] = []
        fullText.enumerateSubstrings(in: paragraphsRange, options: [.byParagraphs, .substringNotRequired]) { _, subrange, _, _ in
            let text = fullText.substring(with: subrange)
            paragraphs.append((subrange, text))
        }

        let allPrefixed = paragraphs.allSatisfy { isPrefixed($0.text) || $0.text.isEmpty }

        textStorage.beginEditing()
        for (idx, para) in paragraphs.enumerated().reversed() {
            guard !para.text.isEmpty else { continue }
            if allPrefixed {
                // Remove prefix and hanging indent
                if isPrefixed(para.text) {
                    // Calculate prefix length including the tab character we inserted
                    var prefixLen = (para.text.hasPrefix("• ") ? 2 : (para.text.firstIndex(of: ".") ?? para.text.startIndex).utf16Offset(in: para.text) + 2)
                    // Also remove the tab if present
                    if para.text.count > prefixLen && para.text[para.text.index(para.text.startIndex, offsetBy: prefixLen)] == "\t" {
                        prefixLen += 1
                    }
                    let removeRange = NSRange(location: para.range.location, length: min(prefixLen, para.range.length))
                    textStorage.replaceCharacters(in: removeRange, with: "")

                    // Remove hanging indent
                    let adjustedRange = NSRange(location: para.range.location, length: max(0, para.range.length - prefixLen))
                    if adjustedRange.length > 0 {
                        textStorage.enumerateAttribute(.paragraphStyle, in: adjustedRange, options: []) { value, range, _ in
                            let current = (value as? NSParagraphStyle) ?? textView.defaultParagraphStyle ?? NSParagraphStyle.default
                            guard let mutable = current.mutableCopy() as? NSMutableParagraphStyle else { return }
                            mutable.headIndent = standardIndentStep
                            mutable.firstLineHeadIndent = standardIndentStep
                            textStorage.addAttribute(.paragraphStyle, value: mutable.copy() as! NSParagraphStyle, range: range)
                        }
                    }
                }
            } else {
                // Add prefix
                let prefix = makePrefix(idx)
                textStorage.replaceCharacters(in: NSRange(location: para.range.location, length: 0), with: prefix)

                // Add tab after bullet/number to align text properly
                let tabInsertLocation = para.range.location + prefix.count
                textStorage.replaceCharacters(in: NSRange(location: tabInsertLocation, length: 0), with: "\t")

                // Set up hanging indent with tab stop
                let adjustedRange = NSRange(location: para.range.location, length: para.range.length + prefix.count + 1)
                textStorage.enumerateAttribute(.paragraphStyle, in: adjustedRange, options: []) { value, range, _ in
                    let current = (value as? NSParagraphStyle) ?? textView.defaultParagraphStyle ?? NSParagraphStyle.default
                    guard let mutable = current.mutableCopy() as? NSMutableParagraphStyle else { return }

                    // Set up tab stop for alignment
                    let tabLocation = standardIndentStep + 18 // Tab position after bullet
                    let tabStop = NSTextTab(textAlignment: .left, location: tabLocation, options: [:])
                    mutable.tabStops = [tabStop]
                    mutable.defaultTabInterval = 0

                    // Hanging indent: first line at standard indent, wrapped lines at tab position
                    mutable.firstLineHeadIndent = standardIndentStep
                    mutable.headIndent = tabLocation

                    textStorage.addAttribute(.paragraphStyle, value: mutable.copy() as! NSParagraphStyle, range: range)
                }
            }
        }
        textStorage.endEditing()
    }
}

extension EditorViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        delegate?.textDidChange()

        // Check if current paragraph is the title and update if so
        checkAndUpdateTitle()

        // Update page height dynamically as text is typed/pasted
        updatePageCentering()
    }

    private func checkAndUpdateTitle() {
        guard let textStorage = textView?.textStorage,
              let selectedRange = textView?.selectedRanges.first as? NSRange else {
            return
        }

        // Get the current paragraph
        let paragraphRange = (textView.string as NSString).paragraphRange(for: selectedRange)

        // Check if this paragraph has "Book Title" formatting (centered, 24pt Times New Roman)
        var isBookTitle = false
        textStorage.enumerateAttributes(in: paragraphRange, options: []) { attributes, range, stop in
            if let font = attributes[.font] as? NSFont,
               let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle {
                // Check for Book Title characteristics: centered alignment, Times New Roman font, 24pt size
                let isCentered = paragraphStyle.alignment == .center
                let isTimesNewRoman = font.familyName == "Times New Roman" || font.fontName.contains("TimesNewRoman")
                let isCorrectSize = font.pointSize == 24

                if isCentered && isTimesNewRoman && isCorrectSize {
                    isBookTitle = true
                    stop.pointee = true
                }
            }
        }

        // If this is the title paragraph, extract and update
        if isBookTitle {
            let titleText = (textView.string as NSString).substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if !titleText.isEmpty {
                delegate?.titleDidChange(titleText)
            }
        }
    }
}
