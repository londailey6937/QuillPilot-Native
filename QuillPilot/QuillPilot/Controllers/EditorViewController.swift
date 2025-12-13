//
//  EditorViewController.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

protocol EditorViewControllerDelegate: AnyObject {
    func textDidChange()
    func titleDidChange(_ title: String)
}

class EditorViewController: NSViewController {

    private let standardMargin: CGFloat = 72
    private let standardIndentStep: CGFloat = 36

    var textView: NSTextView!

    private var pageContainer: NSView!
    private var scrollView: NSScrollView!
    private var documentView: NSView!
    private var currentTheme: AppTheme = ThemeManager.shared.currentTheme

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
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = true
        // Keep the page flush with the ruler (no top inset).
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 12, bottom: 50, right: 12)

        pageContainer = NSView(frame: NSRect(x: 0, y: 0, width: 612, height: 3000))
        pageContainer.wantsLayer = true
        pageContainer.layer?.borderWidth = 1
        pageContainer.layer?.masksToBounds = false
        pageContainer.layer?.shadowOpacity = 0.35
        pageContainer.layer?.shadowOffset = NSSize(width: 0, height: 2)
        pageContainer.layer?.shadowRadius = 10

        
        // Fix page width to US Letter (8.5" = 612pt)
        pageContainer.translatesAutoresizingMaskIntoConstraints = false
        pageContainer.widthAnchor.constraint(equalToConstant: 612).isActive = true
let textFrame = pageContainer.bounds.insetBy(dx: standardMargin, dy: standardMargin)
        textView = NSTextView(frame: textFrame)
        textView.minSize = NSSize(width: textFrame.width, height: textFrame.height)
        textView.maxSize = NSSize(width: textFrame.width, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: textFrame.width, height: .greatestFiniteMagnitude)
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
        paragraphStyle.lineHeightMultiple = 2.0  // Double-spacing for manuscript format
        paragraphStyle.paragraphSpacing = 12
        paragraphStyle.firstLineHeadIndent = standardIndentStep  // 0.5" first-line indent
        textView.defaultParagraphStyle = paragraphStyle.copy() as? NSParagraphStyle

        pageContainer.addSubview(textView)

        documentView = NSView()
        documentView.wantsLayer = true
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(pageContainer)
        
        // Position pageContainer within documentView
        NSLayoutConstraint.activate([
            pageContainer.topAnchor.constraint(equalTo: documentView.topAnchor),
            pageContainer.centerXAnchor.constraint(equalTo: documentView.centerXAnchor),
            pageContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 3000),
            documentView.widthAnchor.constraint(greaterThanOrEqualTo: pageContainer.widthAnchor),
            documentView.heightAnchor.constraint(greaterThanOrEqualTo: pageContainer.heightAnchor, constant: 100)
        ])

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

    func toggleBold() {
        guard let selectedRange = textView.selectedRanges.first?.rangeValue else { return }
        let fontManager = NSFontManager.shared
        if let currentFont = textView.font {
            let newFont = fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
            textView.setFont(newFont, range: selectedRange)
        }
    }

    func toggleItalic() {
        guard let selectedRange = textView.selectedRanges.first?.rangeValue else { return }
        let fontManager = NSFontManager.shared
        if let currentFont = textView.font {
            let newFont = fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
            textView.setFont(newFont, range: selectedRange)
        }
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

    func scrollToTop() {
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
        let availableHeight = max(36, pageContainer.bounds.height - (standardMargin * 2))

        let newFrame = NSRect(
            x: leftMargin,
            y: standardMargin,
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
        let attributed = attributedContent()
        let fullRange = NSRange(location: 0, length: attributed.length)
        guard let data = attributed.rtf(from: fullRange, documentAttributes: [:]) else {
            throw NSError(domain: "QuillPilot", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate RTF."])
        }
        return data
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

    func setAttributedContent(_ attributed: NSAttributedString) {
        textView.textStorage?.setAttributedString(attributed)
        refreshTypingAttributesUsingDefaultParagraphStyle()
        scrollToTop()
        delegate?.textDidChange()
    }

    func setPlainTextContent(_ text: String) {
        let attributed = NSAttributedString(string: text, attributes: textView.typingAttributes)
        setAttributedContent(attributed)
    }

    func applyStyle(named styleName: String) {
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

    private func updatePageCentering() {
        guard let scrollView else { return }

        // Center within the *inset* content area so the page truly aligns with the ruler.
        let insets = scrollView.contentInsets
        let visibleWidth = scrollView.contentView.bounds.width
        let availableWidth = max(0, visibleWidth - insets.left - insets.right)

        let pageWidth: CGFloat = 612
        let centerOffset = max((availableWidth - pageWidth) / 2, 0) + insets.left
        pageContainer.frame.origin.x = centerOffset

        let docWidth = max(visibleWidth, pageWidth + insets.left + insets.right)
        documentView.frame = NSRect(x: 0, y: 0,
                                    width: docWidth,
                                    height: pageContainer.frame.height + 100)
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

        if selectedRange.length == 0 {
            let newFont = transform(baseFont)
            textView.font = newFont
            textView.typingAttributes[.font] = newFont
            return
        }

        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, _ in
            let current = (value as? NSFont) ?? baseFont
            let newFont = transform(current)
            textStorage.addAttribute(.font, value: newFont, range: range)
        }
        textStorage.endEditing()

        let newTypingFont = transform(baseFont)
        textView.typingAttributes[.font] = newTypingFont
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
                if isPrefixed(para.text) {
                    let prefixLen = (para.text.hasPrefix("• ") ? 2 : (para.text.firstIndex(of: ".") ?? para.text.startIndex).utf16Offset(in: para.text) + 2)
                    let removeRange = NSRange(location: para.range.location, length: min(prefixLen, para.range.length))
                    textStorage.replaceCharacters(in: removeRange, with: "")
                }
            } else {
                let prefix = makePrefix(idx)
                textStorage.replaceCharacters(in: NSRange(location: para.range.location, length: 0), with: prefix)
            }
        }
        textStorage.endEditing()
    }
}

extension EditorViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        delegate?.textDidChange()

        let contentHeight = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 0
        let minPageHeight: CGFloat = 792
        let neededHeight = max(minPageHeight, contentHeight + 144)

        if pageContainer.frame.height < neededHeight {
            pageContainer.frame.size.height = neededHeight
            documentView.frame.size.height = neededHeight + 100
            updateShadowPath()
        }
    }
}
