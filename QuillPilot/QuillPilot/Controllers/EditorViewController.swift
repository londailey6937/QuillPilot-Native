//
//  EditorViewController.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa
import UniformTypeIdentifiers

// Flipped view so y=0 is at the top (standard for scroll views)
class FlippedView: NSView {
    override var isFlipped: Bool { return true }
}

// MARK: - Image Utilities

private extension NSImage {
    /// Convert the image to PNG data for consistent on-disk representation
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

protocol EditorViewControllerDelegate: AnyObject {
    func textDidChange()
    func titleDidChange(_ title: String)
    func selectionDidChange()
    func suspendAnalysisForLayout()
    func resumeAnalysisAfterLayout()
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

    private var imageControlsPopover: NSPopover?
    private var lastImageRange: NSRange?
    private var imageScaleLabel: NSTextField?
    private var popoverScrollObserver: NSObjectProtocol?

    // Format painter state
    private var formatPainterActive: Bool = false
    private var copiedAttributes: [NSAttributedString.Key: Any]?

    // Flag to suppress text change notifications during programmatic edits
    private var suppressTextChangeNotifications: Bool = false

    // Helper to register undo/redo and notify text system
    private func replaceCharacters(in range: NSRange, with attributed: NSAttributedString, undoPlaceholder: String) {
        guard let storage = textView.textStorage else { return }
        guard textView.shouldChangeText(in: range, replacementString: undoPlaceholder) else { return }
        storage.beginEditing()
        storage.replaceCharacters(in: range, with: attributed)
        storage.endEditing()
        textView.didChangeText()
    }

    private var scrollView: NSScrollView!
    private var documentView: NSView!
    private var currentTheme: AppTheme = ThemeManager.shared.currentTheme

    // Multi-page support
    private var pages: [NSView] = []

    private class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    private class PageContainerView: NSView {
        override var isFlipped: Bool { true }
        var numPages: Int = 1
        var pageHeight: CGFloat = 792
        var pageGap: CGFloat = 20
        var pageBackgroundColor: NSColor = .white

        // Disable layer backing for this view to ensure draw() is called
        override var wantsUpdateLayer: Bool { false }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)

            // Draw ALL page backgrounds regardless of dirtyRect
            for pageNum in 0..<numPages {
                let pageY = CGFloat(pageNum) * (pageHeight + pageGap)
                let pageRect = NSRect(x: 0, y: pageY, width: bounds.width, height: pageHeight)

                pageBackgroundColor.setFill()
                pageRect.fill()

                // Draw page border
                NSColor.lightGray.setStroke()
                let path = NSBezierPath(rect: pageRect)
                path.lineWidth = 1
                path.stroke()
            }
        }
    }

    // Attachment cell that occupies vertical space without drawing
    private final class SpacerAttachmentCell: NSTextAttachmentCell {
        nonisolated(unsafe) private var spacerSize: NSSize

        init(height: CGFloat) {
            self.spacerSize = NSSize(width: 0.1, height: max(0, height))
            super.init(textCell: "")
        }

        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        nonisolated override func cellSize() -> NSSize {
            spacerSize
        }

        nonisolated override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
            // Intentionally empty – spacer is invisible
        }

        func setHeight(_ height: CGFloat) {
            spacerSize.height = max(0, height)
        }
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
        // Root view can be layer-backed for theming (content height is bounded by window)
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

        // Page container grows to fit all content (support up to 2000 pages)
        // 2000 pages × 792pt + 1999 gaps × 20pt = ~1,624,000pts
        // Start with a reasonable initial size (10 pages) - will expand as needed
        let initialHeight = pageHeight * editorZoom * 10
        let initialPageContainer = PageContainerView(frame: NSRect(x: 0, y: 0, width: 612 * editorZoom, height: initialHeight))
        initialPageContainer.pageHeight = pageHeight * editorZoom
        initialPageContainer.pageGap = 20
        pageContainer = initialPageContainer
        // Disable layer backing to allow traditional view drawing for all pages
        // pageContainer.wantsLayer = true
        // pageContainer.layer?.masksToBounds = false
        // pageContainer.layer?.shadowOpacity = 0.35
        // pageContainer.layer?.shadowOffset = NSSize(width: 0, height: 2)
        // pageContainer.layer?.shadowRadius = 10

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

        // Make text view transparent so page backgrounds show through
        textView.drawsBackground = false
        textView.backgroundColor = .clear

        // Enable drag and drop for images
        textView.registerForDraggedTypes([.fileURL, .tiff, .png])

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
        // Keep document view non-layer-backed so very tall content is not clipped by CALayer limits
        documentView.wantsLayer = false
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

    /// Update the page container to accommodate all content with proper pagination
    func updatePageLayout() {
        // Use estimated page count from text length to avoid forcing full layout
        let charCount = textView.string.count
        // Roughly 3000 chars per page at standard formatting
        let estimatedPages = max(1, Int(ceil(Double(charCount) / 3000.0)))

        setPageCount(estimatedPages)
    }

    /// Set exact page count and resize containers
    private func setPageCount(_ neededPages: Int) {
        guard let pageContainerView = pageContainer as? PageContainerView else { return }
        guard pageContainerView.numPages != neededPages else { return }

        let scaledPageHeight = pageHeight * editorZoom
        pageContainerView.numPages = neededPages
        pageContainerView.pageHeight = scaledPageHeight
        pageContainerView.pageGap = 20

        let totalHeight = CGFloat(neededPages) * (scaledPageHeight + pageContainerView.pageGap) - pageContainerView.pageGap
        let containerWidth = pageWidth * editorZoom
        pageContainer.frame = NSRect(x: 0, y: 0, width: containerWidth, height: totalHeight)

        let textFrame = NSRect(
            x: standardMargin * editorZoom,
            y: standardMargin * editorZoom,
            width: containerWidth - (standardMargin * editorZoom * 2),
            height: totalHeight - (standardMargin * editorZoom * 2)
        )
        textView.frame = textFrame
        textView.textContainer?.containerSize = NSSize(width: textFrame.width, height: CGFloat.greatestFiniteMagnitude)

        documentView.frame = NSRect(x: 0, y: 0, width: containerWidth, height: totalHeight)
        pageContainer.needsDisplay = true
        updatePageCentering()
    }

    // MARK: - Search and Replace

    /// Find all occurrences of a search string in the document
    /// - Parameters:
    ///   - searchText: The text to search for
    ///   - caseSensitive: Whether the search should be case sensitive
    ///   - wholeWords: Whether to match whole words only
    /// - Returns: Array of NSRange objects representing match locations
    func findAll(_ searchText: String, caseSensitive: Bool = false, wholeWords: Bool = false) -> [NSRange] {
        guard !searchText.isEmpty else { return [] }

        let text = textView.string
        var options: String.CompareOptions = []

        if !caseSensitive {
            options.insert(.caseInsensitive)
        }

        var ranges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: text.count)

        while searchRange.location < text.count {
            let foundRange = (text as NSString).range(of: searchText, options: options, range: searchRange)

            if foundRange.location == NSNotFound {
                break
            }

            // Check for whole word match if needed
            if wholeWords {
                let beforeOK = foundRange.location == 0 || !text[text.index(text.startIndex, offsetBy: foundRange.location - 1)].isLetter
                let afterIndex = foundRange.location + foundRange.length
                let afterOK = afterIndex >= text.count || !text[text.index(text.startIndex, offsetBy: afterIndex)].isLetter

                if beforeOK && afterOK {
                    ranges.append(foundRange)
                }
            } else {
                ranges.append(foundRange)
            }

            searchRange.location = foundRange.location + foundRange.length
            searchRange.length = text.count - searchRange.location
        }

        return ranges
    }

    /// Find and highlight the next occurrence of search text
    /// - Parameters:
    ///   - searchText: The text to search for
    ///   - forward: Search forward (true) or backward (false) from current selection
    ///   - caseSensitive: Whether the search should be case sensitive
    ///   - wholeWords: Whether to match whole words only
    /// - Returns: true if a match was found, false otherwise
    @discardableResult
    func findNext(_ searchText: String, forward: Bool = true, caseSensitive: Bool = false, wholeWords: Bool = false) -> Bool {
        guard !searchText.isEmpty else { return false }

        let text = textView.string
        let currentRange = textView.selectedRange()
        var options: String.CompareOptions = forward ? [] : .backwards

        if !caseSensitive {
            options.insert(.caseInsensitive)
        }

        let searchStart = forward ? (currentRange.location + currentRange.length) : 0
        let searchLength = forward ? (text.count - searchStart) : currentRange.location
        var searchRange = NSRange(location: searchStart, length: searchLength)

        let foundRange = (text as NSString).range(of: searchText, options: options, range: searchRange)

        if foundRange.location != NSNotFound {
            // Check whole word if needed
            if wholeWords {
                let beforeOK = foundRange.location == 0 || !text[text.index(text.startIndex, offsetBy: foundRange.location - 1)].isLetter
                let afterIndex = foundRange.location + foundRange.length
                let afterOK = afterIndex >= text.count || !text[text.index(text.startIndex, offsetBy: afterIndex)].isLetter

                if beforeOK && afterOK {
                    textView.setSelectedRange(foundRange)
                    textView.scrollRangeToVisible(foundRange)
                    return true
                }
            } else {
                textView.setSelectedRange(foundRange)
                textView.scrollRangeToVisible(foundRange)
                return true
            }
        }

        // Wrap around if nothing found
        if forward && searchStart > 0 {
            searchRange = NSRange(location: 0, length: currentRange.location)
            let wrappedRange = (text as NSString).range(of: searchText, options: options, range: searchRange)
            if wrappedRange.location != NSNotFound {
                textView.setSelectedRange(wrappedRange)
                textView.scrollRangeToVisible(wrappedRange)
                return true
            }
        } else if !forward && searchLength < text.count {
            searchRange = NSRange(location: currentRange.location + currentRange.length, length: text.count - (currentRange.location + currentRange.length))
            let wrappedRange = (text as NSString).range(of: searchText, options: options, range: searchRange)
            if wrappedRange.location != NSNotFound {
                textView.setSelectedRange(wrappedRange)
                textView.scrollRangeToVisible(wrappedRange)
                return true
            }
        }

        return false
    }

    /// Replace the current selection with replacement text if it matches search text
    /// - Parameters:
    ///   - searchText: The text to search for
    ///   - replaceText: The text to replace with
    ///   - caseSensitive: Whether the search should be case sensitive
    /// - Returns: true if replacement was made, false otherwise
    @discardableResult
    func replaceSelection(_ searchText: String, with replaceText: String, caseSensitive: Bool = false) -> Bool {
        let currentRange = textView.selectedRange()
        guard currentRange.length > 0 else { return false }

        let text = textView.string
        let selectedText = (text as NSString).substring(with: currentRange)

        let matches = caseSensitive ? (selectedText == searchText) : (selectedText.caseInsensitiveCompare(searchText) == .orderedSame)

        if matches {
            // Preserve formatting of replaced text
            guard let textStorage = textView.textStorage else { return false }
            let attrs = textStorage.attributes(at: currentRange.location, effectiveRange: nil)
            let replacementString = NSAttributedString(string: replaceText, attributes: attrs)

            textView.shouldChangeText(in: currentRange, replacementString: replaceText)
            textStorage.replaceCharacters(in: currentRange, with: replacementString)
            textView.didChangeText()

            return true
        }

        return false
    }

    /// Replace all occurrences of search text with replacement text
    /// - Parameters:
    ///   - searchText: The text to search for
    ///   - replaceText: The text to replace with
    ///   - caseSensitive: Whether the search should be case sensitive
    ///   - wholeWords: Whether to match whole words only
    /// - Returns: Number of replacements made
    @discardableResult
    func replaceAll(_ searchText: String, with replaceText: String, caseSensitive: Bool = false, wholeWords: Bool = false) -> Int {
        guard !searchText.isEmpty, let textStorage = textView.textStorage else { return 0 }

        let ranges = findAll(searchText, caseSensitive: caseSensitive, wholeWords: wholeWords)
        guard !ranges.isEmpty else { return 0 }

        textStorage.beginEditing()

        // Replace in reverse order to maintain correct ranges
        var replacementCount = 0
        for range in ranges.reversed() {
            let attrs = textStorage.attributes(at: range.location, effectiveRange: nil)
            let replacementString = NSAttributedString(string: replaceText, attributes: attrs)

            textView.shouldChangeText(in: range, replacementString: replaceText)
            textStorage.replaceCharacters(in: range, with: replacementString)
            replacementCount += 1
        }

        textStorage.endEditing()
        textView.didChangeText()

        return replacementCount
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

    // MARK: - Images

    func insertImageFromDisk() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Insert Image"

        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else {
            return
        }

        // Calculate max width based on text container width (accounts for margins and zoom)
        let textContainerWidth = textView.textContainer?.size.width ?? ((pageWidth - standardMargin * 2) * editorZoom)
        // Default to 50% of text width to prevent images from blowing out text
        var maxWidth = textContainerWidth * 0.5
        let maxHeight = (pageHeight - headerHeight - footerHeight - (standardMargin * 2)) * editorZoom * 0.6 // keep well inside a single page

        // Check if cursor is in a table cell - if so, use much smaller max width to avoid breaking the cell
        let cursorLocation = textView.selectedRange().location
        if let textStorage = textView.textStorage, cursorLocation < textStorage.length {
            let attrs = textStorage.attributes(at: cursorLocation, effectiveRange: nil)
            if let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle,
               let textBlocks = paragraphStyle.textBlocks as? [NSTextTableBlock],
               let block = textBlocks.first {
                // In a table cell - limit to a small size to avoid breaking the cell
                let table = block.table
                let cellWidth = textContainerWidth / CGFloat(table.numberOfColumns)
                // Use 40% of cell width minus padding to ensure it fits comfortably
                maxWidth = cellWidth * 0.4
            }
        }

        let scale = min(1.0, maxWidth / image.size.width, maxHeight / image.size.height)
        let targetSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(origin: .zero, size: targetSize)

        // Preserve image data and size in fileWrapper; normalize to PNG for consistency
        if let pngData = image.pngData() {
            let wrapper = FileWrapper(regularFileWithContents: pngData)
            wrapper.preferredFilename = encodeImageFilename(size: targetSize, ext: "png")
            attachment.fileWrapper = wrapper
        } else if let data = try? Data(contentsOf: url) { // fallback to source data
            let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
            let wrapper = FileWrapper(regularFileWithContents: data)
            wrapper.preferredFilename = encodeImageFilename(size: targetSize, ext: ext)
            attachment.fileWrapper = wrapper
        }

        textView.window?.makeFirstResponder(textView)

        // Store the current insertion point before any modal dialogs affect focus
        let caretRange = textView.selectedRange()
        let insertionPoint = min(caretRange.location, textView.string.count)
        let insertionRange = NSRange(location: insertionPoint, length: 0)

        // Check if we're in a table cell - if so, insert as inline attachment without paragraph breaks
        var isInTableCell = false
        if let textStorage = textView.textStorage, insertionPoint < textStorage.length {
            let attrs = textStorage.attributes(at: insertionPoint, effectiveRange: nil)
            if let existingStyle = attrs[.paragraphStyle] as? NSParagraphStyle {
                isInTableCell = !existingStyle.textBlocks.isEmpty
            }
        }

        let imageString: NSAttributedString
        if isInTableCell {
            // In table cell: insert as inline attachment using current attributes
            let currentAttrs = textView.typingAttributes
            let mutableImageString = NSMutableAttributedString(attachment: attachment)
            mutableImageString.addAttributes(currentAttrs, range: NSRange(location: 0, length: mutableImageString.length))
            imageString = mutableImageString
        } else {
            // Not in table: use centered paragraph style
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            para.paragraphSpacing = 0
            para.paragraphSpacingBefore = 0
            para.firstLineHeadIndent = 0
            para.headIndent = 0
            para.tailIndent = 0

            let mutableImageString = NSMutableAttributedString(attachment: attachment)
            mutableImageString.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: mutableImageString.length))
            imageString = mutableImageString
        }
        // Stamp size attribute so reopen can restore dimensions
        let finalImageString = NSMutableAttributedString(attributedString: imageString)
        finalImageString.addAttribute(NSAttributedString.Key("QuillPilotImageSize"), value: NSStringFromRect(NSRect(origin: .zero, size: targetSize)), range: NSRange(location: 0, length: finalImageString.length))

        replaceCharacters(in: insertionRange, with: finalImageString, undoPlaceholder: "\u{FFFC}")

        // Update page layout to account for the new image
        updatePageCentering()

        // Force layout to complete before positioning the caret and scrolling
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)

        // Place caret after the attachment
        let attachmentPos = insertionRange.location
        textView.setSelectedRange(NSRange(location: attachmentPos, length: 0))

        // Scroll to make the inserted image visible
        textView.scrollRangeToVisible(NSRange(location: attachmentPos, length: 1))

        lastImageRange = NSRange(location: attachmentPos, length: 1)
        showImageControlsIfNeeded()
    }

    private func encodeImageFilename(size: CGSize, ext: String) -> String {
        let cleanExt = ext.lowercased()
        let w = Int(round(size.width * 100))
        let h = Int(round(size.height * 100))
        return "image_w\(w)_h\(h).\(cleanExt)"
    }


    private func imageAttachmentRange(at location: Int) -> NSRange? {
        guard let storage = textView.textStorage, storage.length > 0 else { return nil }
        let clampedLoc = max(0, min(location, storage.length - 1))
        var effectiveRange = NSRange(location: NSNotFound, length: 0)
        if storage.attribute(.attachment, at: clampedLoc, effectiveRange: &effectiveRange) != nil {
            return effectiveRange
        }
        return nil
    }

    private func makeImageBlock(with attachment: NSTextAttachment) -> (NSAttributedString, Int) {
        // Build a minimal paragraph-wrapped attachment with neutral spacing
        let block = NSMutableAttributedString()
        let typingAttrs = textView.typingAttributes
        let baseParagraph = (typingAttrs[.paragraphStyle] as? NSParagraphStyle) ?? (textView.defaultParagraphStyle ?? NSParagraphStyle.default)
        let para = baseParagraph.mutableCopy() as! NSMutableParagraphStyle
        para.paragraphSpacing = 0
        para.paragraphSpacingBefore = 0

        // Leading newline
        block.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: para]))
        let attachmentLocation = block.length

        // Attachment
        block.append(NSAttributedString(attachment: attachment))

        // Trailing newline
        block.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: para]))

        // Apply paragraph style over the whole block
        block.addAttribute(.paragraphStyle, value: para.copy() as! NSParagraphStyle, range: NSRange(location: 0, length: block.length))
        return (block.copy() as! NSAttributedString, attachmentLocation)
    }

    private func showImageControlsIfNeeded() {
        guard let window = view.window else { return }
        let selection = textView.selectedRange()
        guard selection.length <= 1, let attachmentRange = imageAttachmentRange(at: selection.location) else {
            imageControlsPopover?.performClose(nil)
            imageControlsPopover = nil
            if let obs = popoverScrollObserver {
                NotificationCenter.default.removeObserver(obs)
                popoverScrollObserver = nil
            }
            lastImageRange = nil
            return
        }

        lastImageRange = attachmentRange

        let maxWidth = textView.textContainer?.size.width ?? ((pageWidth - standardMargin * 2) * editorZoom)
        let currentWidth = (textView.textStorage?.attribute(.attachment, at: attachmentRange.location, effectiveRange: nil) as? NSTextAttachment)?.bounds.width ?? (maxWidth * 0.5)
        // Scale is relative to max width: 0.5 = 50% of text width, 1.0 = 100% of text width
        let currentScale = max(0.1, min(1.0, currentWidth / maxWidth))

        // Always create fresh popover to ensure proper sizing
        let popover = NSPopover()
        popover.behavior = .transient

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)

        func makeButton(_ title: String, action: Selector) -> NSButton {
            let btn = NSButton(title: title, target: self, action: action)
            btn.bezelStyle = .rounded
            btn.setButtonType(.momentaryPushIn)
            return btn
        }

        let alignRow = NSStackView(views: [
            makeButton("Left", action: #selector(alignImageLeft)),
            makeButton("Center", action: #selector(alignImageCenter)),
            makeButton("Right", action: #selector(alignImageRight))
        ])
        alignRow.orientation = .horizontal
        alignRow.spacing = 3

        let moveRow = NSStackView(views: [
            makeButton("↑", action: #selector(moveImageUp)),
            makeButton("↓", action: #selector(moveImageDown)),
            makeButton("Caption", action: #selector(addOrEditCaption))
        ])
        moveRow.orientation = .horizontal
        moveRow.spacing = 3

        let replaceDeleteRow = NSStackView(views: [
            makeButton("Replace", action: #selector(replaceImage)),
            makeButton("Delete", action: #selector(deleteImage))
        ])
        replaceDeleteRow.orientation = .horizontal
        replaceDeleteRow.spacing = 3

        // Resize slider row
        let scaleLabel = NSTextField(labelWithString: "100%")
        scaleLabel.alignment = .right
        scaleLabel.font = NSFont.systemFont(ofSize: 10)
        imageScaleLabel = scaleLabel

        let slider = NSSlider(value: currentScale, minValue: 0.1, maxValue: 1.0, target: self, action: #selector(resizeSliderChanged(_:)))
        slider.isContinuous = true

        let resizeRow = NSStackView(views: [scaleLabel, slider])
        resizeRow.orientation = .horizontal
        resizeRow.spacing = 3
        resizeRow.distribution = .fillProportionally

        stack.addArrangedSubview(alignRow)
        stack.addArrangedSubview(moveRow)
        stack.addArrangedSubview(replaceDeleteRow)
        stack.addArrangedSubview(resizeRow)

        updateScaleLabel(currentScale)

        let contentSize = NSSize(width: 120, height: 95)
        let contentView = NSView(frame: NSRect(origin: .zero, size: contentSize))
        contentView.addSubview(stack)

        // Use simple autoresizing to avoid popover sizing glitches
        stack.frame = contentView.bounds
        stack.autoresizingMask = [.width, .height]

        let viewController = NSViewController()
        viewController.view = contentView
        popover.contentViewController = viewController
        popover.contentSize = contentSize

        imageControlsPopover = popover

        if let lm = textView.layoutManager {
            lm.ensureLayout(forCharacterRange: attachmentRange)
        }
        let glyphRange = textView.layoutManager?.glyphRange(forCharacterRange: attachmentRange, actualCharacterRange: nil) ?? attachmentRange
        var rect = textView.layoutManager?.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer!) ?? .zero
        if rect.isEmpty {
            rect = textView.firstRect(forCharacterRange: attachmentRange, actualRange: nil)
            rect = textView.convert(rect, from: nil)
        } else {
            rect.origin.x += textView.textContainerOrigin.x
            rect.origin.y += textView.textContainerOrigin.y
        }
        if rect.height == 0 { rect.size.height = 24 }
        popover.show(relativeTo: rect, of: textView, preferredEdge: .maxY)
        window.makeFirstResponder(textView)

        // Reposition popover as the user scrolls
        scrollView.contentView.postsBoundsChangedNotifications = true
        if let obs = popoverScrollObserver {
            NotificationCenter.default.removeObserver(obs)
            popoverScrollObserver = nil
        }
        popoverScrollObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.contentView, queue: .main) { [weak self] _ in
            guard let self = self, let pop = self.imageControlsPopover, pop.isShown else { return }
            self.showImageControlsIfNeeded()
        }
    }

    @objc private func resizeSliderChanged(_ sender: NSSlider) {
        let scale = CGFloat(sender.doubleValue)
        resizeImage(toScale: scale)
    }

    @objc private func alignImageLeft() { alignImage(.left) }
    @objc private func alignImageCenter() { alignImage(.center) }
    @objc private func alignImageRight() { alignImage(.right) }

    private func alignImage(_ alignment: NSTextAlignment) {
        guard let range = lastImageRange ?? imageAttachmentRange(at: textView.selectedRange().location) else { return }
        guard let storage = textView.textStorage else { return }
        // Limit to the paragraph containing the attachment only
        let paragraphRange = (storage.string as NSString).paragraphRange(for: NSRange(location: range.location, length: 1))

        // Register with undo for style change
        guard textView.shouldChangeText(in: paragraphRange, replacementString: nil) else { return }

        let base = (textView.textStorage?.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle) ?? (textView.defaultParagraphStyle ?? NSParagraphStyle.default)
        let mutable = base.mutableCopy() as! NSMutableParagraphStyle
        mutable.alignment = alignment
        storage.beginEditing()
        storage.addAttribute(.paragraphStyle, value: mutable.copy() as! NSParagraphStyle, range: paragraphRange)
        storage.endEditing()
        storage.fixAttributes(in: paragraphRange)
        textView.layoutManager?.invalidateLayout(forCharacterRange: paragraphRange, actualCharacterRange: nil)

        // Also update caption alignment if there is one
        let afterImage = NSMaxRange(paragraphRange)
        if afterImage < storage.length {
            let nextParagraphRange = (storage.string as NSString).paragraphRange(for: NSRange(location: afterImage, length: 0))
            var hasCaptionAttr = false
            storage.enumerateAttribute(Self.captionAttributeKey, in: nextParagraphRange, options: []) { value, _, _ in
                if value != nil {
                    hasCaptionAttr = true
                }
            }
            if hasCaptionAttr {
                // Update caption alignment to match image
                let captionBase = (storage.attribute(.paragraphStyle, at: nextParagraphRange.location, effectiveRange: nil) as? NSParagraphStyle) ?? NSParagraphStyle.default
                let captionMutable = captionBase.mutableCopy() as! NSMutableParagraphStyle
                captionMutable.alignment = alignment
                storage.beginEditing()
                storage.addAttribute(.paragraphStyle, value: captionMutable.copy() as! NSParagraphStyle, range: nextParagraphRange)
                storage.endEditing()
                textView.layoutManager?.invalidateLayout(forCharacterRange: nextParagraphRange, actualCharacterRange: nil)
            }
        }

        textView.didChangeText()

        // Close and reopen popover to reposition it correctly
        imageControlsPopover?.performClose(nil)
        imageControlsPopover = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.showImageControlsIfNeeded()
        }
    }

    @objc private func moveImageUp() { moveImage(direction: -1) }
    @objc private func moveImageDown() { moveImage(direction: 1) }

    private func moveImage(direction: Int) {
        guard let storage = textView.textStorage else { return }
        guard let range = lastImageRange ?? imageAttachmentRange(at: textView.selectedRange().location) else { return }
        let fullString = storage.string as NSString
        let currentPara = fullString.paragraphRange(for: range)

        // Check if there's a caption that should move with the image
        var imageAndCaptionRange = currentPara
        let afterImage = NSMaxRange(currentPara)
        if afterImage < storage.length {
            let nextPara = fullString.paragraphRange(for: NSRange(location: afterImage, length: 0))
            var hasCaptionAttr = false
            storage.enumerateAttribute(Self.captionAttributeKey, in: nextPara, options: []) { value, _, _ in
                if value != nil {
                    hasCaptionAttr = true
                }
            }
            if hasCaptionAttr {
                // Include caption in the move
                imageAndCaptionRange = NSRange(location: currentPara.location, length: NSMaxRange(nextPara) - currentPara.location)
            }
        }

        let currentText = storage.attributedSubstring(from: imageAndCaptionRange)

        if direction < 0 {
            if imageAndCaptionRange.location == 0 { return }
            let prevPara = fullString.paragraphRange(for: NSRange(location: max(0, imageAndCaptionRange.location - 1), length: 0))
            if prevPara.location == imageAndCaptionRange.location { return }
            let prevText = storage.attributedSubstring(from: prevPara)
            let combinedRange = NSRange(location: prevPara.location, length: NSMaxRange(imageAndCaptionRange) - prevPara.location)
            let swapped = NSMutableAttributedString()
            swapped.append(currentText)
            swapped.append(prevText)

            guard textView.shouldChangeText(in: combinedRange, replacementString: swapped.string) else { return }
            storage.beginEditing()
            storage.replaceCharacters(in: combinedRange, with: swapped)
            storage.endEditing()
            textView.setSelectedRange(NSRange(location: prevPara.location, length: currentText.length))
        } else {
            let nextStart = NSMaxRange(imageAndCaptionRange)
            if nextStart >= storage.length { return }
            let nextPara = fullString.paragraphRange(for: NSRange(location: nextStart, length: 0))
            if nextPara.location == imageAndCaptionRange.location { return }
            let nextText = storage.attributedSubstring(from: nextPara)
            let combinedRange = NSRange(location: imageAndCaptionRange.location, length: NSMaxRange(nextPara) - imageAndCaptionRange.location)
            let swapped = NSMutableAttributedString()
            swapped.append(nextText)
            swapped.append(currentText)

            guard textView.shouldChangeText(in: combinedRange, replacementString: swapped.string) else { return }
            storage.beginEditing()
            storage.replaceCharacters(in: combinedRange, with: swapped)
            storage.endEditing()
            textView.setSelectedRange(NSRange(location: nextPara.location + nextText.length, length: currentText.length))
        }

        textView.didChangeText()
        showImageControlsIfNeeded()
    }

    private func resizeImage(toScale scale: CGFloat) {
        guard let storage = textView.textStorage else { return }
        guard let range = lastImageRange ?? imageAttachmentRange(at: textView.selectedRange().location) else { return }
        guard let attachment = storage.attribute(.attachment, at: range.location, effectiveRange: nil) as? NSTextAttachment else { return }

        let maxWidth = textView.textContainer?.size.width ?? ((pageWidth - standardMargin * 2) * editorZoom)
        let maxHeight = (pageHeight - headerHeight - footerHeight - (standardMargin * 2)) * editorZoom * 0.8 // Leave margin for safety
        let naturalSize = attachment.bounds.size.width > 0 && attachment.bounds.size.height > 0
            ? attachment.bounds.size
            : (attachment.image?.size ?? NSSize(width: maxWidth * 0.5, height: maxWidth * 0.5))

        // Cap at 100% of text width to prevent blowout
        let clampedScale = max(0.1, min(1.0, scale))
        let aspect = (naturalSize.width > 0) ? (naturalSize.height / naturalSize.width) : 1

        // Width constrained by slider and container
        var targetWidth = max(40, maxWidth * clampedScale)
        // Height constraint to keep on page; if too tall, reduce width accordingly
        let heightForWidth = targetWidth * aspect
        if heightForWidth > maxHeight {
            targetWidth = max(40, maxHeight / aspect)
        }
        let targetHeight = targetWidth * aspect

        attachment.bounds = NSRect(origin: .zero, size: NSSize(width: targetWidth, height: targetHeight))

        // Update the stored size in the fileWrapper filename for persistence
        if let wrapper = attachment.fileWrapper, let oldName = wrapper.preferredFilename {
            let ext = (oldName as NSString).pathExtension
            wrapper.preferredFilename = encodeImageFilename(size: NSSize(width: targetWidth, height: targetHeight), ext: ext)
        }

        textView.textStorage?.edited(.editedAttributes, range: range, changeInLength: 0)
        textView.didChangeText()
        updateScaleLabel(clampedScale)
    }

    private func updateScaleLabel(_ scale: CGFloat) {
        imageScaleLabel?.stringValue = "\(Int(round(scale * 100)))%"
    }

    @objc private func deleteImage() {
        guard let storage = textView.textStorage else { return }
        guard let range = lastImageRange ?? imageAttachmentRange(at: textView.selectedRange().location) else { return }

        // Check if there's a caption to delete along with the image
        let fullString = storage.string as NSString
        let imagePara = fullString.paragraphRange(for: range)
        var deleteRange = imagePara

        let afterImage = NSMaxRange(imagePara)
        if afterImage < storage.length {
            let nextPara = fullString.paragraphRange(for: NSRange(location: afterImage, length: 0))
            var hasCaptionAttr = false
            storage.enumerateAttribute(Self.captionAttributeKey, in: nextPara, options: []) { value, _, _ in
                if value != nil {
                    hasCaptionAttr = true
                }
            }
            if hasCaptionAttr {
                // Include caption in deletion
                deleteRange = NSRange(location: imagePara.location, length: NSMaxRange(nextPara) - imagePara.location)
            }
        }

        replaceCharacters(in: deleteRange, with: NSAttributedString(string: ""), undoPlaceholder: "")
        imageControlsPopover?.performClose(nil)
        imageControlsPopover = nil
    }

    @objc private func replaceImage() {
        guard textView.textStorage != nil else { return }
        guard let range = lastImageRange ?? imageAttachmentRange(at: textView.selectedRange().location) else { return }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Replace Image"

        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else {
            return
        }

        let maxWidth = textView.textContainer?.size.width ?? ((pageWidth - standardMargin * 2) * editorZoom)
        let scale = min(1.0, maxWidth / image.size.width)
        let targetSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(origin: .zero, size: targetSize)

        textView.window?.makeFirstResponder(textView)

        // Create a simple image paragraph without extra newlines
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.paragraphSpacing = 0
        para.paragraphSpacingBefore = 0
        para.firstLineHeadIndent = 0
        para.headIndent = 0
        para.tailIndent = 0

        let imageString = NSMutableAttributedString(attachment: attachment)
        imageString.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: imageString.length))

        replaceCharacters(in: range, with: imageString, undoPlaceholder: "\u{FFFC}")

        // Update page layout to account for the new image
        updatePageCentering()

        // Force layout to complete before positioning the caret and scrolling
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)

        let attachmentPos = range.location
        textView.setSelectedRange(NSRange(location: attachmentPos, length: 0))
        textView.scrollRangeToVisible(NSRange(location: attachmentPos, length: 1))
        lastImageRange = NSRange(location: attachmentPos, length: 1)
        showImageControlsIfNeeded()
    }

    // MARK: - Image Captions

    /// Custom attribute key to mark caption text as belonging to an image
    private static let captionAttributeKey = NSAttributedString.Key("QuillPilotImageCaption")

    @objc private func addOrEditCaption() {
        guard let storage = textView.textStorage else { return }
        guard let range = lastImageRange ?? imageAttachmentRange(at: textView.selectedRange().location) else { return }

        // Close the popover
        imageControlsPopover?.performClose(nil)
        imageControlsPopover = nil

        // Find the paragraph containing the image
        let paragraphRange = (storage.string as NSString).paragraphRange(for: range)

        // Check if there's already a caption on the next line
        let afterImage = NSMaxRange(paragraphRange)
        var existingCaption = ""
        var captionRange: NSRange?

        if afterImage < storage.length {
            let nextParagraphRange = (storage.string as NSString).paragraphRange(for: NSRange(location: afterImage, length: 0))
            // Check if the next paragraph has our caption attribute
            var hasCaptionAttr = false
            storage.enumerateAttribute(Self.captionAttributeKey, in: nextParagraphRange, options: []) { value, _, _ in
                if value != nil {
                    hasCaptionAttr = true
                }
            }
            if hasCaptionAttr {
                let captionText = (storage.string as NSString).substring(with: nextParagraphRange)
                existingCaption = captionText.trimmingCharacters(in: .whitespacesAndNewlines)
                captionRange = nextParagraphRange
            }
        }

        // Show caption input dialog
        let alert = NSAlert()
        alert.messageText = existingCaption.isEmpty ? "Add Caption" : "Edit Caption"
        alert.informativeText = "Enter a caption for this image:"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        if !existingCaption.isEmpty {
            alert.addButton(withTitle: "Remove Caption")
        }

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.stringValue = existingCaption
        inputField.placeholderString = "Figure 1: Description of image"
        alert.accessoryView = inputField
        alert.window.initialFirstResponder = inputField

        // Apply theme to alert
        let response = alert.runThemedModal()

        if response == .alertFirstButtonReturn {
            // OK - add or update caption
            let captionText = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !captionText.isEmpty {
                setCaptionForImage(at: range, caption: captionText, existingCaptionRange: captionRange)
            } else if let existingRange = captionRange {
                // Empty caption, remove it
                removeCaptionAtRange(existingRange)
            }
        } else if response == .alertThirdButtonReturn, let existingRange = captionRange {
            // Remove caption
            removeCaptionAtRange(existingRange)
        }

        // Reshow image controls
        lastImageRange = range
        showImageControlsIfNeeded()
    }

    private func setCaptionForImage(at imageRange: NSRange, caption: String, existingCaptionRange: NSRange?) {
        guard let storage = textView.textStorage else { return }

        // Get the image's paragraph style for alignment
        let imageParagraphRange = (storage.string as NSString).paragraphRange(for: imageRange)
        let imageParaStyle = storage.attribute(.paragraphStyle, at: imageRange.location, effectiveRange: nil) as? NSParagraphStyle ?? NSParagraphStyle.default

        // Create caption paragraph style with same alignment as image
        let captionPara = NSMutableParagraphStyle()
        captionPara.alignment = imageParaStyle.alignment
        captionPara.paragraphSpacing = 6
        captionPara.paragraphSpacingBefore = 2

        // Create caption attributed string with italic font
        let baseFont = NSFont.systemFont(ofSize: 11)
        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)

        let captionString = NSMutableAttributedString(string: caption + "\n", attributes: [
            .font: italicFont,
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: captionPara,
            Self.captionAttributeKey: true
        ])

        if let existingRange = existingCaptionRange {
            // Replace existing caption
            guard textView.shouldChangeText(in: existingRange, replacementString: captionString.string) else { return }
            storage.beginEditing()
            storage.replaceCharacters(in: existingRange, with: captionString)
            storage.endEditing()
            textView.didChangeText()
        } else {
            // Insert new caption after image paragraph
            let insertionPoint = NSMaxRange(imageParagraphRange)
            guard textView.shouldChangeText(in: NSRange(location: insertionPoint, length: 0), replacementString: captionString.string) else { return }
            storage.beginEditing()
            storage.insert(captionString, at: insertionPoint)
            storage.endEditing()
            textView.didChangeText()
        }
    }

    private func removeCaptionAtRange(_ range: NSRange) {
        guard textView.shouldChangeText(in: range, replacementString: "") else { return }
        textView.textStorage?.beginEditing()
        textView.textStorage?.deleteCharacters(in: range)
        textView.textStorage?.endEditing()
        textView.didChangeText()
    }

    func scrollToTop() {
        // Force scroll to absolute top by setting clip view origin to zero
        scrollView.contentView.scroll(to: NSPoint.zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        // Also try the text view method as backup
        textView.scrollToBeginningOfDocument(nil)
    }

    /// Navigate to a specific page number
    /// - Parameter pageNumber: The page to navigate to (1-indexed)
    /// - Returns: True if navigation was successful, false if page number is out of range
    func goToPage(_ pageNumber: Int) -> Bool {
        guard let pageContainerView = pageContainer as? PageContainerView else { return false }

        let totalPages = pageContainerView.numPages
        guard pageNumber >= 1 && pageNumber <= totalPages else { return false }

        let scaledPageHeight = pageHeight * editorZoom
        let pageGap: CGFloat = 20

        // Calculate Y position for the target page (0-indexed internally)
        let pageIndex = pageNumber - 1
        let targetY = CGFloat(pageIndex) * (scaledPageHeight + pageGap)

        // Scroll to the target page
        let targetPoint = NSPoint(x: 0, y: targetY)
        scrollView.contentView.scroll(to: targetPoint)
        scrollView.reflectScrolledClipView(scrollView.contentView)

        return true
    }

    /// Get the current page number and total pages
    /// - Returns: A tuple containing (currentPage, totalPages)
    func getCurrentPageInfo() -> (current: Int, total: Int) {
        guard let pageContainerView = pageContainer as? PageContainerView else { return (1, 1) }

        let totalPages = pageContainerView.numPages
        let scaledPageHeight = pageHeight * editorZoom
        let pageGap: CGFloat = 20

        // Get current scroll position
        let visibleRect = scrollView.documentVisibleRect
        let currentY = visibleRect.origin.y

        // Calculate which page is at the top of the visible area
        let currentPageIndex = max(0, Int(currentY / (scaledPageHeight + pageGap)))
        let currentPage = min(currentPageIndex + 1, totalPages)

        return (currentPage, totalPages)
    }

    /// Calculate the page number for a specific character position in the document
    /// - Parameter characterPosition: The character index in the text
    /// - Returns: The page number (1-indexed)
    func getPageNumber(forCharacterPosition characterPosition: Int) -> Int {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let storage = textView.textStorage else {
            return 1
        }

        // Ensure position is within bounds
        let safePosition = max(0, min(characterPosition, storage.length - 1))
        guard safePosition >= 0 else { return 1 }

        // Get the glyph index for this character
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: safePosition)

        // Get the bounding rect for this glyph
        let glyphRange = NSRange(location: glyphIndex, length: 1)
        let bounds = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        // Calculate page based on Y position
        let scaledPageHeight = pageHeight * editorZoom
        let pageIndex = max(0, Int(floor(bounds.midY / scaledPageHeight)))

        return pageIndex + 1
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
        // Always emit true RTF data so the file stays a single .rtf and doesn't corrupt when reopened
        let attrs: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf
        ]
        let data = try attributed.data(from: fullRange, documentAttributes: attrs)
        return data
    }

    func rtfdData() throws -> Data {
        let attributed = exportReadyAttributedContent()
        let fullRange = NSRange(location: 0, length: attributed.length)
        guard let data = attributed.rtfd(from: fullRange, documentAttributes: [:]) else {
            throw NSError(domain: "QuillPilot", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate RTFD with images."])
        }
        return data
    }

    func hasAttachments() -> Bool {
        guard let storage = textView.textStorage else { return false }
        var found = false
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length), options: []) { value, _, stop in
            if value != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
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
                let catalogParagraph = paragraphStyle(from: definition)
                let font = font(from: definition)
                let textColor = color(fromHex: definition.textColorHex, fallback: defaultColor)
                let backgroundColor = definition.backgroundColorHex.flatMap { color(fromHex: $0, fallback: .clear) }

                // Get existing paragraph style to preserve textBlocks (columns/tables)
                let existingParagraph = normalized.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle
                let finalParagraph = mergedParagraphStyle(existing: existingParagraph, style: catalogParagraph)

                // Apply paragraph style at paragraph level
                normalized.addAttribute(.paragraphStyle, value: finalParagraph, range: paragraphRange)

                // Apply font and colors per run to preserve inline formatting (bold, italic, size changes)
                normalized.enumerateAttributes(in: paragraphRange, options: []) { attrs, runRange, _ in
                    // Merge style font with existing font to preserve inline changes
                    let existingFont = attrs[.font] as? NSFont
                    let finalFont = mergedFont(existing: existingFont, style: font)

                    normalized.addAttribute(.font, value: finalFont, range: runRange)

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

                // Get paragraph text to help with content-based style detection
                let paragraphText = fullString.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)

                let inferredStyleName = inferStyle(font: font, paragraphStyle: paragraph, text: paragraphText)

                if let definition = StyleCatalog.shared.style(named: inferredStyleName) {
                    let para = paragraphStyle(from: definition)
                    let styleFont = self.font(from: definition)
                    let styleColor = color(fromHex: definition.textColorHex, fallback: defaultColor)
                    let bgColor = definition.backgroundColorHex.flatMap { color(fromHex: $0, fallback: .clear) }

                    normalized.addAttribute(styleAttributeKey, value: inferredStyleName, range: paragraphRange)

                    // Merge paragraph style to preserve manual alignment overrides
                    let finalParagraph = mergedParagraphStyle(existing: paragraph, style: para)
                    normalized.addAttribute(.paragraphStyle, value: finalParagraph, range: paragraphRange)

                    // Apply font and colors per run to preserve inline formatting
                    normalized.enumerateAttributes(in: paragraphRange, options: []) { attrs, runRange, _ in
                        // Merge style font with existing font to preserve inline changes
                        let existingFont = attrs[.font] as? NSFont
                        let finalFont = mergedFont(existing: existingFont, style: styleFont)
                        normalized.addAttribute(.font, value: finalFont, range: runRange)

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
        delegate?.suspendAnalysisForLayout()

        // Apply style retagging to infer paragraph styles
        let retagged = detectAndRetagStyles(in: attributed)
        textView.textStorage?.setAttributedString(retagged)
        applyDefaultTypingAttributes()
        updatePageLayout()
        scrollToTop()

        delegate?.resumeAnalysisAfterLayout()
    }

    /// Fast content setter for imported documents - skips expensive style processing
    func setAttributedContentDirect(_ attributed: NSAttributedString) {
        delegate?.suspendAnalysisForLayout()

        // For large documents, defer layout to prevent UI freeze
        let isLargeDocument = attributed.length > 100_000

        if isLargeDocument {
            // Disable layout during bulk insert
            textView.layoutManager?.backgroundLayoutEnabled = false
        }

        textView.textStorage?.setAttributedString(attributed)

        // Don't reset typing attributes - let them inherit from document content
        // This preserves the Body Text style and other attributes when typing
        updateTypingAttributesFromContent()

        if isLargeDocument {
            // Re-enable and do layout in chunks
            textView.layoutManager?.backgroundLayoutEnabled = true
            // Defer heavy layout work AND analysis until pages are ready
            DispatchQueue.main.async { [weak self] in
                self?.updatePageLayout()
                self?.scrollToTop()
                // Wait for layout to settle before triggering analysis
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.delegate?.resumeAnalysisAfterLayout()
                }
            }
        } else {
            updatePageLayout()
            scrollToTop()
            delegate?.resumeAnalysisAfterLayout()
        }
    }

    private func updateTypingAttributesFromContent() {
        // If document has content, inherit attributes from it
        // Otherwise use default manuscript formatting
        guard let textStorage = textView.textStorage, textStorage.length > 0 else {
            applyDefaultTypingAttributes()
            return
        }

        // Get attributes from the start of the document
        let attrs = textStorage.attributes(at: 0, effectiveRange: nil)

        // Start with those attributes for typing
        var newTypingAttributes = attrs

        // Ensure we have a font
        if newTypingAttributes[.font] == nil {
            newTypingAttributes[.font] = NSFont(name: "Times New Roman", size: 14) ?? NSFont.systemFont(ofSize: 14)
        }

        // Override foregroundColor with current theme color
        // (Don't preserve dark colors from documents when in dark mode)
        newTypingAttributes[.foregroundColor] = currentTheme.textColor

        // Ensure we have a paragraph style
        if newTypingAttributes[.paragraphStyle] == nil {
            let neutralParagraph = NSMutableParagraphStyle()
            neutralParagraph.alignment = .left
            neutralParagraph.lineHeightMultiple = 2.0
            neutralParagraph.paragraphSpacing = 0
            neutralParagraph.firstLineHeadIndent = 36
            newTypingAttributes[.paragraphStyle] = neutralParagraph
            textView.defaultParagraphStyle = neutralParagraph
        } else if let paraStyle = newTypingAttributes[.paragraphStyle] as? NSParagraphStyle {
            textView.defaultParagraphStyle = paraStyle
        }

        textView.typingAttributes = newTypingAttributes
    }

    private func applyDefaultTypingAttributes() {
        let neutralParagraph = NSMutableParagraphStyle()
        neutralParagraph.alignment = .left
        neutralParagraph.lineHeightMultiple = 2.0
        neutralParagraph.paragraphSpacing = 0
        neutralParagraph.firstLineHeadIndent = 36
        textView.defaultParagraphStyle = neutralParagraph

        let defaultFont = NSFont(name: "Times New Roman", size: 14) ?? NSFont.systemFont(ofSize: 14)
        var newTypingAttributes = textView.typingAttributes
        newTypingAttributes[.font] = defaultFont
        newTypingAttributes[.paragraphStyle] = neutralParagraph
        textView.typingAttributes = newTypingAttributes
        refreshTypingAttributesUsingDefaultParagraphStyle()
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

            // Get paragraph text to help with content-based style detection
            let paragraphText = fullString.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)

            // Infer style based on font, paragraph attributes, and text content
            let styleName = inferStyle(font: font, paragraphStyle: paragraphStyle, text: paragraphText)

            if let definition = StyleCatalog.shared.style(named: styleName) {
                // Tag the paragraph
                mutable.addAttribute(styleAttributeKey, value: styleName, range: paragraphRange)

                // Apply catalog style colors and formatting to make them visible immediately
                let catalogParagraph = self.paragraphStyle(from: definition)
                let catalogFont = self.font(from: definition)
                let textColor = self.color(fromHex: definition.textColorHex, fallback: currentTheme.textColor)
                let backgroundColor = definition.backgroundColorHex.flatMap { self.color(fromHex: $0, fallback: .clear) }

                // Merge paragraph style to preserve manual alignment overrides
                let finalParagraph = mergedParagraphStyle(existing: paragraphStyle, style: catalogParagraph)
                mutable.addAttribute(.paragraphStyle, value: finalParagraph, range: paragraphRange)

                // Apply font per run to preserve inline formatting (bold, italic, size changes)
                mutable.enumerateAttributes(in: paragraphRange, options: []) { attrs, runRange, _ in
                    // Merge style font with existing font to preserve inline changes
                    let existingFont = attrs[.font] as? NSFont
                    let finalFont = mergedFont(existing: existingFont, style: catalogFont)
                    mutable.addAttribute(.font, value: finalFont, range: runRange)

                    let existingFg = attrs[.foregroundColor] as? NSColor
                    if existingFg == nil {
                        mutable.addAttribute(.foregroundColor, value: textColor, range: runRange)
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

    private func inferStyle(font: NSFont, paragraphStyle: NSParagraphStyle, text: String = "") -> String {
        let currentTemplate = StyleCatalog.shared.currentTemplateName
        let styleNames = StyleCatalog.shared.styleNames(for: currentTemplate)

        // Content-based detection for Index/TOC content (takes priority over formatting)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fontTraits = NSFontManager.shared.traits(of: font)
        let isBold = fontTraits.contains(.boldFontMask)

        // Single uppercase letter with bold formatting -> Index Letter
        if trimmedText.count == 1 && trimmedText.first?.isUppercase == true && isBold {
            if font.pointSize >= 13 && font.pointSize <= 16 {
                return "Index Letter"
            }
        }

        // Text with leader dots pattern (term ... page) -> Index Entry or TOC Entry
        if trimmedText.contains(" . ") || trimmedText.contains("...") || trimmedText.contains(". .") {
            // Check if ends with a number (page reference)
            let lastWord = trimmedText.split(separator: " ").last ?? ""
            if lastWord.allSatisfy({ $0.isNumber || $0 == "," }) {
                // Has indentation -> likely Index Entry
                if paragraphStyle.firstLineHeadIndent > 10 || paragraphStyle.headIndent > 10 {
                    return "Index Entry"
                }
                // No indent or small indent -> likely TOC Entry
                return "TOC Entry"
            }
        }

        // "Index" or "Table of Contents" title detection
        let lowercased = trimmedText.lowercased()
        if (lowercased == "index" || lowercased == "index\n" || lowercased == "index\n\n") &&
           isBold && paragraphStyle.alignment == .center && font.pointSize >= 16 {
            return "Index Title"
        }
        if (lowercased.contains("table of contents") || lowercased == "contents") &&
           isBold && paragraphStyle.alignment == .center && font.pointSize >= 16 {
            return "TOC Title"
        }

        var bestMatch: String = "Body Text"
        var bestScore: Int = -100

        let isItalic = fontTraits.contains(.italicFontMask)

        for name in styleNames {
            guard let style = StyleCatalog.shared.style(named: name) else { continue }

            // Skip Index/TOC styles in general matching - they should only be matched by content detection above
            let skipStyles = ["Index Letter", "Index Entry", "Index Title", "TOC Entry", "TOC Title",
                              "TOC Entry Level 1", "TOC Entry Level 2", "TOC Entry Level 3"]
            if skipStyles.contains(name) { continue }

            var score = 0

            // Alignment match
            if style.alignmentRawValue == paragraphStyle.alignment.rawValue {
                score += 10
            } else {
                // Penalize mismatch but don't skip - user might have manually aligned the text
                score -= 5
            }

            // Font Size match (allow small tolerance)
            if abs(style.fontSize - font.pointSize) < 0.5 {
                score += 20
            } else {
                score -= 10
            }

            // Traits match
            if style.isBold == isBold { score += 5 } else { score -= 5 }
            if style.isItalic == isItalic { score += 5 } else { score -= 5 }

            // Font Family match
            if font.familyName?.contains(style.fontName) == true || style.fontName.contains(font.familyName ?? "") {
                score += 5
            }

            if score > bestScore {
                bestScore = score
                bestMatch = name
            }
        }

        return bestMatch
    }

    func setPlainTextContent(_ text: String) {
        let attributed = NSAttributedString(string: text, attributes: textView.typingAttributes)
        setAttributedContent(attributed)
        // Note: delegate?.textDidChange() is called inside setAttributedContent


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

    // MARK: - Efficient Text Insertion

    /// Insert attributed text at the current cursor position while suppressing expensive layout updates
    /// This is useful for large insertions like TOC/Index that would otherwise cause the app to hang
    func insertAttributedTextEfficiently(_ attributedString: NSAttributedString) {
        guard let textStorage = textView.textStorage else { return }

        let insertLocation = textView.selectedRange().location

        // Suppress text change notifications to prevent cascading layout updates
        suppressTextChangeNotifications = true

        // Perform the insertion
        textStorage.insert(attributedString, at: insertLocation)

        // Move cursor to end of inserted text
        let newLocation = insertLocation + attributedString.length
        textView.setSelectedRange(NSRange(location: newLocation, length: 0))

        // Re-enable notifications
        suppressTextChangeNotifications = false

        // Now trigger a single layout update manually
        delegate?.textDidChange()
        updatePageCentering()

        // Ensure the cursor is visible after insertion
        textView.scrollRangeToVisible(textView.selectedRange())
    }

    /// Remove invisible characters that can cause cursor flashing issues in imported documents
    /// This includes zero-width spaces, zero-width joiners, and other problematic Unicode characters
    func removeInvisibleCharacters() {
        guard let textStorage = textView.textStorage else { return }

        let text = textStorage.string

        // Common invisible/problematic characters that can cause cursor issues
        let invisibleChars: [(char: String, name: String)] = [
            ("\u{200B}", "Zero Width Space"),
            ("\u{200C}", "Zero Width Non-Joiner"),
            ("\u{200D}", "Zero Width Joiner"),
            ("\u{FEFF}", "Zero Width No-Break Space (BOM)"),
            ("\u{2060}", "Word Joiner"),
            ("\u{180E}", "Mongolian Vowel Separator"),
            ("\u{034F}", "Combining Grapheme Joiner"),
            ("\u{00A0}", "Non-Breaking Space"),
            ("\u{202F}", "Narrow No-Break Space"),
        ]

        var cleanedText = text
        var foundChars: [String: Int] = [:]

        for (char, name) in invisibleChars {
            let count = text.components(separatedBy: char).count - 1
            if count > 0 {
                foundChars[name] = count
                cleanedText = cleanedText.replacingOccurrences(of: char, with: "")
            }
        }

        // Only update if we actually found and removed characters
        if cleanedText != text {
            let savedSelection = textView.selectedRange()

            suppressTextChangeNotifications = true

            // Preserve all attributes while replacing the string
            let mutableStorage = NSMutableAttributedString(attributedString: textStorage)
            mutableStorage.mutableString.setString(cleanedText)

            textStorage.beginEditing()
            textStorage.setAttributedString(mutableStorage)
            textStorage.endEditing()

            // Restore selection (adjust if necessary)
            let newLocation = min(savedSelection.location, textStorage.length)
            textView.setSelectedRange(NSRange(location: newLocation, length: 0))

            suppressTextChangeNotifications = false

            delegate?.textDidChange()
            updatePageCentering()

            // Show detailed report
            let totalRemoved = text.count - cleanedText.count
            var report = "Removed \(totalRemoved) invisible character(s):\n\n"
            for (name, count) in foundChars.sorted(by: { $0.value > $1.value }) {
                report += "• \(count) \(name)\n"
            }

            DispatchQueue.main.async { [weak self] in
                guard let window = self?.view.window else { return }
                let alert = NSAlert()
                alert.messageText = "Invisible Characters Removed"
                alert.informativeText = report
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.beginSheetModal(for: window)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let window = self?.view.window else { return }
                let alert = NSAlert()
                alert.messageText = "Document Clean"
                alert.informativeText = "No invisible characters found in document."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.beginSheetModal(for: window)
            }
        }
    }

    /// Highlight invisible characters in the document to identify problematic areas
    func highlightInvisibleCharacters() {
        guard let textStorage = textView.textStorage else { return }

        let text = textStorage.string
        let invisibleChars: [String] = [
            "\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}",
            "\u{2060}", "\u{180E}", "\u{034F}", "\u{00A0}", "\u{202F}"
        ]

        var ranges: [NSRange] = []

        // Find all occurrences of invisible characters
        for char in invisibleChars {
            var searchRange = NSRange(location: 0, length: text.count)
            while searchRange.location < text.count {
                let foundRange = (text as NSString).range(of: char, options: [], range: searchRange)
                if foundRange.location != NSNotFound {
                    ranges.append(foundRange)
                    searchRange.location = foundRange.location + foundRange.length
                    searchRange.length = text.count - searchRange.location
                } else {
                    break
                }
            }
        }

        if ranges.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let window = self?.view.window else { return }
                let alert = NSAlert()
                alert.messageText = "No Invisible Characters"
                alert.informativeText = "No invisible characters were found in the document."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.beginSheetModal(for: window)
            }
            return
        }

        // Temporarily highlight the ranges
        textStorage.beginEditing()
        for range in ranges {
            textStorage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.5), range: range)
            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.thick.rawValue, range: range)
            textStorage.addAttribute(.underlineColor, value: NSColor.systemRed, range: range)
        }
        textStorage.endEditing()

        // Show dialog with option to remove
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.view.window else { return }
            let alert = NSAlert()
            alert.messageText = "Found \(ranges.count) Invisible Character(s)"
            alert.informativeText = "These characters have been highlighted in yellow with red underlines. They may cause cursor flashing or other display issues.\n\nWould you like to remove them?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Remove All")
            alert.addButton(withTitle: "Keep Highlighting")
            alert.addButton(withTitle: "Cancel")

            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    // Remove highlights first
                    textStorage.beginEditing()
                    for range in ranges {
                        textStorage.removeAttribute(.backgroundColor, range: range)
                        textStorage.removeAttribute(.underlineStyle, range: range)
                        textStorage.removeAttribute(.underlineColor, range: range)
                    }
                    textStorage.endEditing()

                    // Then remove the characters
                    self.removeInvisibleCharacters()
                } else if response == .alertThirdButtonReturn {
                    // Cancel - remove highlights
                    textStorage.beginEditing()
                    for range in ranges {
                        textStorage.removeAttribute(.backgroundColor, range: range)
                        textStorage.removeAttribute(.underlineStyle, range: range)
                        textStorage.removeAttribute(.underlineColor, range: range)
                    }
                    textStorage.endEditing()
                }
                // If "Keep Highlighting" is selected, do nothing - leave highlights in place
            }
        }
    }

    // MARK: - Format Painter

    func toggleFormatPainter() {
        guard let textStorage = textView.textStorage else { return }
        guard let selectedRange = textView.selectedRanges.first?.rangeValue else { return }

        if !formatPainterActive {
            // Activate format painter - copy formatting from selection
            if selectedRange.length > 0 {
                // Copy attributes from the start of the selection
                let attrs = textStorage.attributes(at: selectedRange.location, effectiveRange: nil)
                copiedAttributes = attrs
                formatPainterActive = true

                // Change cursor to indicate format painter is active
                NSCursor.crosshair.push()

                NSLog("Format Painter activated - copied formatting")
            } else {
                // No selection, show alert
                showThemedAlert(title: "Format Painter", message: "Select text with the formatting you want to copy first.")
            }
        } else {
            // Deactivate format painter
            deactivateFormatPainter()
        }
    }

    private func deactivateFormatPainter() {
        formatPainterActive = false
        copiedAttributes = nil
        NSCursor.pop()
        NSLog("Format Painter deactivated")
    }

    private func applyFormatPainterToSelection() {
        guard formatPainterActive,
              let copiedAttrs = copiedAttributes,
              let textStorage = textView.textStorage,
              let selectedRange = textView.selectedRanges.first?.rangeValue,
              selectedRange.length > 0 else { return }

        textStorage.beginEditing()

        // Apply all copied attributes except textBlocks (to preserve table/column structure)
        for (key, value) in copiedAttrs {
            if key != .attachment {  // Don't copy attachments
                textStorage.addAttribute(key, value: value, range: selectedRange)
            }
        }

        textStorage.endEditing()

        NSLog("Format Painter applied to selection")

        // Deactivate after one use
        deactivateFormatPainter()
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
            // Check if we're in a table/column - if so, only apply font, no paragraph changes
            guard let textStorage = textView.textStorage else { break }
            guard let selected = textView.selectedRanges.first?.rangeValue else { break }

            // Check if cursor is in a table/column
            var isInTableOrColumn = false
            if selected.location < textStorage.length {
                let attrs = textStorage.attributes(at: selected.location, effectiveRange: nil)
                if let style = attrs[.paragraphStyle] as? NSParagraphStyle {
                    isInTableOrColumn = !style.textBlocks.isEmpty
                }
            }

            if !isInTableOrColumn {
                // Only apply paragraph formatting outside tables/columns
                let fullText = (textStorage.string as NSString)
                let paragraphsRange = fullText.paragraphRange(for: selected)

                textStorage.beginEditing()
                textStorage.enumerateAttribute(.paragraphStyle, in: paragraphsRange, options: []) { value, range, _ in
                    let current = (value as? NSParagraphStyle) ?? textView.defaultParagraphStyle ?? NSParagraphStyle.default
                    let mutable = (current.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()

                    mutable.alignment = .left
                    mutable.lineHeightMultiple = 2.0
                    mutable.headIndent = 0
                    mutable.firstLineHeadIndent = standardIndentStep
                    mutable.tailIndent = 0
                    mutable.paragraphSpacingBefore = 0
                    mutable.paragraphSpacing = 0
                    mutable.lineBreakMode = .byWordWrapping

                    textStorage.addAttribute(.paragraphStyle, value: mutable.copy() as! NSParagraphStyle, range: range)
                }
                textStorage.endEditing()
            }
            // Apply font regardless of table/column
            applyFontChange { _ in
                NSFont(name: "Times New Roman", size: 14) ?? NSFont.systemFont(ofSize: 14)
            }
        case "Body Text – No Indent":
            // Check if we're in a table/column - if so, only apply font, no paragraph changes
            guard let textStorage = textView.textStorage else { break }
            guard let selected = textView.selectedRanges.first?.rangeValue else { break }

            // Check if cursor is in a table/column
            var isInTableOrColumn = false
            if selected.location < textStorage.length {
                let attrs = textStorage.attributes(at: selected.location, effectiveRange: nil)
                if let style = attrs[.paragraphStyle] as? NSParagraphStyle {
                    isInTableOrColumn = !style.textBlocks.isEmpty
                }
            }

            if !isInTableOrColumn {
                // Only apply paragraph formatting outside tables/columns
                let fullText = (textStorage.string as NSString)
                let paragraphsRange = fullText.paragraphRange(for: selected)

                textStorage.beginEditing()
                textStorage.enumerateAttribute(.paragraphStyle, in: paragraphsRange, options: []) { value, range, _ in
                    let current = (value as? NSParagraphStyle) ?? textView.defaultParagraphStyle ?? NSParagraphStyle.default
                    let mutable = (current.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()

                    mutable.alignment = .left
                    mutable.lineHeightMultiple = 2.0
                    mutable.headIndent = 0
                    mutable.firstLineHeadIndent = 0
                    mutable.tailIndent = 0
                    mutable.paragraphSpacingBefore = 0
                    mutable.paragraphSpacing = 0
                    mutable.lineBreakMode = .byWordWrapping

                    textStorage.addAttribute(.paragraphStyle, value: mutable.copy() as! NSParagraphStyle, range: range)
                }
                textStorage.endEditing()
            }
            // Apply font regardless of table/column
            applyFontChange { _ in
                NSFont(name: "Times New Roman", size: 14) ?? NSFont.systemFont(ofSize: 14)
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
            suppressTextChangeNotifications = true
            applyManuscriptParagraphStyle { style in
                style.alignment = .left
                style.headIndent = 0
                style.firstLineHeadIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 6
                style.paragraphSpacing = 12
                style.lineHeightMultiple = 1.0
            }
            applyFontChange { current in
                NSFont(name: "Times New Roman", size: 11) ?? current
            }
            suppressTextChangeNotifications = false
            delegate?.textDidChange()
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
        case "Screenplay — Title":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .center
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 144  // Extra space above title
                style.paragraphSpacing = 12
            }
            applyScreenplayTitleFont()
        case "Screenplay — Author":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .center
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 72
                style.paragraphSpacing = 0
            }
            applyScreenplayFont()
        case "Screenplay — Contact":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = -288  // Left aligned, narrow column
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 0
            }
            applyScreenplayFont()
        case "Screenplay — Draft":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .right
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 0
            }
            applyScreenplayFont()
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

    func getCurrentStyleName() -> String? {
        guard let storage = textView.textStorage,
              let selected = textView.selectedRanges.first as? NSRange else {
            return nil
        }

        // Get the style at the cursor position (or start of selection)
        let position = selected.location
        guard position < storage.length else { return nil }

        // Get the paragraph range to check paragraph-level style
        let paragraphRange = (textView.string as NSString).paragraphRange(for: selected)
        guard paragraphRange.location < storage.length else { return nil }

        // Try to get the stored style name attribute
        if let styleName = storage.attribute(styleAttributeKey, at: paragraphRange.location, effectiveRange: nil) as? String {
            return styleName
        }

        return nil
    }

    private func applyCatalogStyle(named styleName: String) -> Bool {
        guard let definition = StyleCatalog.shared.style(named: styleName) else { return false }

        let paragraph = paragraphStyle(from: definition)
        let font = font(from: definition)
        // Always use theme text color instead of stored color to respect light/dark mode
        let textColor = currentTheme.textColor
        let backgroundColor = definition.backgroundColorHex.flatMap { color(fromHex: $0, fallback: .clear) }

        applyParagraphEditsToSelectedParagraphs { style in
            style.setParagraphStyle(paragraph)
        }

        // Apply font and color changes without overriding the paragraph style
        // (which was already applied with textBlocks preserved)
        if let storage = textView.textStorage {
            let selection = textView.selectedRange()
            let range = selection.length == 0 ? (textView.string as NSString).paragraphRange(for: selection) : selection
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
        // Apply professional typography features
        font = fontWithTypographyFeatures(font, fontName: definition.fontName)
        return font
    }

    // MARK: - Professional Typography Features

    /// Enhances font with professional typography features (ligatures, kerning, OpenType)
    private func fontWithTypographyFeatures(_ baseFont: NSFont, fontName: String) -> NSFont {
        var descriptor = baseFont.fontDescriptor

        var features: [[NSFontDescriptor.FeatureKey: Int]] = []

        // Enable ligatures for serif and professional fonts
        let supportsLigatures = ["Times New Roman", "Georgia", "Baskerville", "Garamond", "Palatino", "Hoefler Text"].contains(fontName)
        if supportsLigatures {
            features.append([
                .typeIdentifier: kLigaturesType,
                .selectorIdentifier: kCommonLigaturesOnSelector
            ])
        }

        // Apply features if any were added
        if !features.isEmpty {
            descriptor = descriptor.addingAttributes([
                .featureSettings: features
            ])
        }

        return NSFont(descriptor: descriptor, size: baseFont.pointSize) ?? baseFont
    }

    /// Apply smart typography (smart quotes, em/en dashes) to text
    func enableSmartTypography() {
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isAutomaticTextReplacementEnabled = true
    }

    /// Apply optical kerning to selection or entire document
    func applyOpticalKerning(to range: NSRange? = nil) {
        guard let storage = textView.textStorage else { return }
        let targetRange = range ?? NSRange(location: 0, length: storage.length)
        storage.addAttribute(.kern, value: 0.0, range: targetRange) // 0.0 = use font's optical kerning
    }

    /// Apply drop cap to the current paragraph
    func applyDropCap(lines: Int = 3) {
        guard let storage = textView.textStorage else { return }
        let selected = textView.selectedRange()
        let paragraphRange = (textView.string as NSString).paragraphRange(for: selected)

        guard paragraphRange.length > 0 else { return }

        // Get first character
        let firstCharRange = NSRange(location: paragraphRange.location, length: 1)
        let currentFont = storage.attribute(.font, at: firstCharRange.location, effectiveRange: nil) as? NSFont ?? NSFont.systemFont(ofSize: 14)

        // Make drop cap 3x larger
        let dropCapSize = currentFont.pointSize * CGFloat(lines)
        let dropCapFont = NSFont(descriptor: currentFont.fontDescriptor, size: dropCapSize) ?? currentFont

        storage.addAttribute(.font, value: dropCapFont, range: firstCharRange)
        storage.addAttribute(.baselineOffset, value: -(dropCapSize * 0.2), range: firstCharRange)
    }

    /// Enable OpenType features for old-style numerals
    func applyOldStyleNumerals(to range: NSRange? = nil) {
        guard let storage = textView.textStorage else { return }
        let targetRange = range ?? NSRange(location: 0, length: storage.length)

        storage.enumerateAttribute(.font, in: targetRange) { value, subrange, _ in
            guard let font = value as? NSFont else { return }

            let features: [[NSFontDescriptor.FeatureKey: Int]] = [
                [
                    .typeIdentifier: kNumberCaseType,
                    .selectorIdentifier: kLowerCaseNumbersSelector
                ]
            ]

            let descriptor = font.fontDescriptor.addingAttributes([
                .featureSettings: features
            ])

            if let newFont = NSFont(descriptor: descriptor, size: font.pointSize) {
                storage.addAttribute(.font, value: newFont, range: subrange)
            }
        }
    }

    /// Merges style base font with existing font to preserve intentional inline changes
    /// - Parameters:
    ///   - existingFont: The font currently applied to the text run (may have inline changes)
    ///   - styleFont: The base font from the style definition
    /// - Returns: The appropriate font - style font if no inline changes, or preserved font if intentionally modified
    private func mergedFont(existing existingFont: NSFont?, style styleFont: NSFont) -> NSFont {
        guard let existing = existingFont else { return styleFont }

        // Check if the existing font has been intentionally modified (different size or traits)
        let existingTraits = NSFontManager.shared.traits(of: existing)
        let styleTraits = NSFontManager.shared.traits(of: styleFont)

        let existingBold = existingTraits.contains(.boldFontMask)
        let existingItalic = existingTraits.contains(.italicFontMask)
        let styleBold = styleTraits.contains(.boldFontMask)
        let styleItalic = styleTraits.contains(.italicFontMask)

        // Check for font family difference (e.g. user changed to Helvetica)
        let familyChanged = existing.familyName != styleFont.familyName

        // If size differs or bold/italic traits differ, this is an inline change - preserve it
        // Use a very small epsilon for size comparison to catch even minor differences
        if abs(existing.pointSize - styleFont.pointSize) > 0.1 ||
           existingBold != styleBold ||
           existingItalic != styleItalic ||
           familyChanged {
            // NSLog("mergedFont: Preserving existing \(existing.fontName) \(existing.pointSize)pt (Style: \(styleFont.fontName) \(styleFont.pointSize)pt)")
            return existing  // Preserve inline formatting change
        }

        // No inline changes detected, use style font (to pick up style-level updates)
        return styleFont
    }

    private func mergedParagraphStyle(existing: NSParagraphStyle?, style: NSParagraphStyle) -> NSParagraphStyle {
        guard let existing = existing else { return style }
        guard let mutable = style.mutableCopy() as? NSMutableParagraphStyle else { return style }

        // Preserve alignment if it differs from the style default (user manual override)
        if existing.alignment != style.alignment {
            mutable.alignment = existing.alignment
        }

        // CRITICAL: Preserve textBlocks (columns and tables) from existing style
        if !existing.textBlocks.isEmpty {
            mutable.textBlocks = existing.textBlocks
        }

        return mutable.copy() as! NSParagraphStyle
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
            NSLog("📋🔍 buildOutlineEntries: Missing required components")
            return []
        }

        NSLog("📋🔍 buildOutlineEntries: Starting scan of \(storage.length) characters")
        NSLog("📋🔍 styleAttributeKey: \(styleAttributeKey)")

        let levels: [String: Int] = [
            "Part Title": 0,
            "Chapter Number": 1,
            "Chapter Title": 1,
            "Heading 1": 1,
            "Heading 2": 2,
            "Heading 3": 3,
            "TOC Title": 1,
            "Index Title": 1,
            "Glossary Title": 1,
            "Appendix Title": 1
        ]

        var results: [OutlineEntry] = []
        var stylesFound = Set<String>()
        var paragraphCount = 0
        let fullString = storage.string as NSString
        var location = 0
        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
            guard paragraphRange.length > 0 else { break }
            paragraphCount += 1

            let styleName = storage.attribute(styleAttributeKey, at: paragraphRange.location, effectiveRange: nil) as? String
            if let styleName {
                stylesFound.insert(styleName)
                if let level = levels[styleName] {
                    let rawTitle = fullString.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !rawTitle.isEmpty {
                        let glyphRange = layoutManager.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
                        let bounds = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                        let scaledPageHeight = pageHeight * editorZoom
                        let pageGap: CGFloat = 20
                        // Account for page gaps when calculating page number
                        let pageIndex = max(0, Int(floor(bounds.midY / (scaledPageHeight + pageGap)))) + 1
                        results.append(OutlineEntry(title: rawTitle, level: level, range: paragraphRange, page: pageIndex))
                        if results.count <= 3 {
                            NSLog("📋✅ Found: '\(rawTitle)' style='\(styleName)' level=\(level)")
                        }
                    }
                }
            }

            location = NSMaxRange(paragraphRange)
        }

        NSLog("📋🔍 Scanned \(paragraphCount) paragraphs, found \(stylesFound.count) unique styles")
        NSLog("📋🔍 Styles present: \(stylesFound.sorted())")
        NSLog("📋🔍 Outline entries found: \(results.count)")

        return results
    }

    /// Build a comprehensive character-position-to-page mapping for accurate page lookups
    func buildPageMapping() -> [(location: Int, page: Int)] {
        guard let storage = textView.textStorage,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            NSLog("📄 buildPageMapping: Missing text storage/layout manager")
            return []
        }

        var mapping: [(location: Int, page: Int)] = []
        let totalLength = storage.length

        guard totalLength > 0 else {
            NSLog("📄 buildPageMapping: Empty document")
            return []
        }

        // Force layout to complete before we try to get page numbers
        NSLog("📄 buildPageMapping: Forcing layout for \(totalLength) characters...")
        layoutManager.ensureLayout(for: textContainer)
        NSLog("📄 buildPageMapping: Layout complete, starting sampling...")

        // Sample every 500 characters for better accuracy (reduced from 1000)
        let sampleInterval = 500
        var location = 0

        while location < totalLength {
            let pageNum = getPageNumber(forCharacterPosition: location)
            mapping.append((location: location, page: pageNum))

            location = min(location + sampleInterval, totalLength - 1)
        }

        // Always add the last position
        if mapping.last?.location != totalLength - 1 {
            let lastPageNum = getPageNumber(forCharacterPosition: totalLength - 1)
            mapping.append((location: totalLength - 1, page: lastPageNum))
        }

        NSLog("📄 buildPageMapping: Created \(mapping.count) page mapping entries for \(totalLength) characters")
        if !mapping.isEmpty {
            NSLog("📄 First entry: location=\(mapping.first!.location) page=\(mapping.first!.page)")
            NSLog("📄 Last entry: location=\(mapping.last!.location) page=\(mapping.last!.page)")
        }
        return mapping
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

    private func applyScreenplayTitleFont() {
        applyFontChange { current in
            // Title page uses larger, bold Courier
            let baseFont = NSFont(name: "Courier New", size: 18) ?? current
            if let boldFont = NSFont(name: "Courier New Bold", size: 18) {
                return boldFont
            }
            return baseFont
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

        // Preserve current cursor position AND scroll position BEFORE any layout changes
        let savedSelection = textView.selectedRange()
        let savedScrollPosition = scrollView.contentView.bounds.origin

        let visibleWidth = scrollView.contentView.bounds.width
        let scaledPageWidth = pageWidth * editorZoom
        let scaledPageHeight = pageHeight * editorZoom
        let pageX = max((visibleWidth - scaledPageWidth) / 2, 0)

        // Use fast estimation for page count to avoid expensive layout operations
        var numPages = 1

        // Estimate pages based on word/character count (much faster than full layout)
        let textLength = textView.string.utf16.count
        if textLength > 0 {
            // Average ~250 words per page, ~5 chars per word = ~1250 chars per page
            // Add some buffer for formatting, headers, etc.
            let charsPerPageEstimate = 1200.0
            numPages = max(1, Int(ceil(Double(textLength) / charsPerPageEstimate)))
        }

        // Skip expensive layout calculation if currently in columns or tables
        // Modifying textContainer geometry while in a table/column can cause layout loops
        let isInColumnsOrTables = isCurrentPositionInColumns() || isCurrentPositionInTable()

        // Only do expensive full layout calculation if:
        // - Document is very small (< 5 pages estimated)
        // - NOT currently in columns or tables (to avoid layout loops)
        if numPages < 5 && !isInColumnsOrTables,
           let layoutManager = textView.layoutManager,
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

            // For small documents, do a quick layout without full invalidation
            let usedHeight = layoutManager.usedRect(for: textContainer).height
            let measuredPages = Int(ceil(usedHeight / pageTextHeight))

            numPages = max(1, measuredPages)

            // Restore container state
            textContainer.size = oldSize
            textContainer.exclusionPaths = oldExclusions
            layoutManager.textContainerChangedGeometry(textContainer)
        }

        // Total height includes all pages plus gaps between them
        let pageGap: CGFloat = 20
        let totalHeight = CGFloat(numPages) * scaledPageHeight + CGFloat(numPages - 1) * pageGap

        pageContainer.frame = NSRect(x: pageX, y: 0, width: scaledPageWidth, height: totalHeight)

        // Update page container to draw correct number of pages
        if let pageContainerView = pageContainer as? PageContainerView {
            pageContainerView.numPages = numPages
            pageContainerView.pageHeight = scaledPageHeight
            pageContainerView.pageGap = pageGap
            // Force complete redraw of all pages
            pageContainerView.setNeedsDisplay(pageContainerView.bounds)
        }

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
        let docHeight = max(totalHeight + 1000, 1650000 * editorZoom)  // Ensure enough space for large documents
        documentView.frame = NSRect(x: 0, y: 0, width: docWidth, height: docHeight)

        // Restore cursor position AFTER layout changes
        if savedSelection.location <= textView.string.count {
            textView.setSelectedRange(savedSelection)
        }

        // Restore scroll position to prevent view jumping during layout updates,
        // but then ensure cursor is visible (which will scroll if needed)
        scrollView.contentView.scroll(to: savedScrollPosition)

        // Ensure the cursor is visible after layout - this allows natural scrolling
        // when typing at the end of the document without jumping back up
        textView.scrollRangeToVisible(textView.selectedRange())
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

            // Note: Page backgrounds are now drawn by PageContainerView.draw(_:)
            // This ensures proper page separation and performance

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
        guard let textStorage = textView.textStorage else { return 1 }
        let cursor = textView.selectedRange().location
        guard cursor < textStorage.length else { return 1 }

        let attrs = textStorage.attributes(at: cursor, effectiveRange: nil)
        if let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle,
           let textBlocks = paragraphStyle.textBlocks as? [NSTextTableBlock],
           let block = textBlocks.first {
            return block.table.numberOfColumns
        }
        return 1
    }

    func setColumnCount(_ columns: Int) {
        NSLog("setColumnCount called with \(columns)")
        guard columns >= 2, columns <= 4 else {
            NSLog("setColumnCount: columns out of range (must be 2-4)")
            return
        }
        guard let textStorage = textView.textStorage else {
            NSLog("setColumnCount: no textStorage")
            return
        }

        // Ensure text view can accept input
        textView.window?.makeFirstResponder(textView)

        let currentRange = textView.selectedRange()
        NSLog("setColumnCount: inserting at location \(currentRange.location)")

        // Suppress text change notifications during column insertion to prevent hang
        suppressTextChangeNotifications = true
        defer { suppressTextChangeNotifications = false }

        // Disable background layout to prevent hang during table insertion
        let wasBackgroundLayoutEnabled = textView.layoutManager?.backgroundLayoutEnabled ?? false
        textView.layoutManager?.backgroundLayoutEnabled = false

        // Create text table for columns - but with NO visible borders
        let textTable = NSTextTable()
        textTable.numberOfColumns = columns
        textTable.layoutAlgorithm = .automaticLayoutAlgorithm
        textTable.collapsesBorders = true

        // Create attributed string with table blocks for each column
        let result = NSMutableAttributedString()

        for i in 0..<columns {
            let textBlock = NSTextTableBlock(table: textTable, startingRow: 0, rowSpan: 1, startingColumn: i, columnSpan: 1)

            // No borders for columns - just use padding for spacing
            textBlock.setBorderColor(.clear, for: .minX)
            textBlock.setBorderColor(.clear, for: .maxX)
            textBlock.setBorderColor(.clear, for: .minY)
            textBlock.setBorderColor(.clear, for: .maxY)
            textBlock.setWidth(0.0, type: .absoluteValueType, for: .border, edge: .minX)
            textBlock.setWidth(0.0, type: .absoluteValueType, for: .border, edge: .maxX)
            textBlock.setWidth(0.0, type: .absoluteValueType, for: .border, edge: .minY)
            textBlock.setWidth(0.0, type: .absoluteValueType, for: .border, edge: .maxY)

            // Add padding for column spacing
            textBlock.setWidth(12.0, type: .absoluteValueType, for: .padding, edge: .minX)
            textBlock.setWidth(12.0, type: .absoluteValueType, for: .padding, edge: .maxX)
            textBlock.setWidth(0.0, type: .absoluteValueType, for: .padding, edge: .minY)
            textBlock.setWidth(0.0, type: .absoluteValueType, for: .padding, edge: .maxY)

            var attrs = textView.typingAttributes

            // Apply Body Text style if available
            if let bodyStyle = StyleCatalog.shared.style(named: "Body Text") {
                let pStyle = paragraphStyle(from: bodyStyle)
                if let mutablePStyle = pStyle.mutableCopy() as? NSMutableParagraphStyle {
                    mutablePStyle.textBlocks = [textBlock]
                    attrs[.paragraphStyle] = mutablePStyle
                }
                attrs[.font] = font(from: bodyStyle)
                attrs[.foregroundColor] = color(fromHex: bodyStyle.textColorHex, fallback: currentTheme.textColor)
            } else {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.textBlocks = [textBlock]
                attrs[.paragraphStyle] = paragraphStyle
            }

            let columnContent = NSAttributedString(string: "\n", attributes: attrs)
            result.append(columnContent)
        }

        // Add final newline to exit columns
        let finalNewline = NSAttributedString(string: "\n", attributes: textView.typingAttributes)
        result.append(finalNewline)

        // Wrap insertion in beginEditing/endEditing to batch all text notifications
        textStorage.beginEditing()
        textStorage.insert(result, at: currentRange.location)

        // Set cursor position BEFORE endEditing to prevent multiple layout passes
        let newCursorLocation = currentRange.location + 1
        textView.setSelectedRange(NSRange(location: newCursorLocation, length: 0))

        textStorage.endEditing()

        // Re-enable background layout
        textView.layoutManager?.backgroundLayoutEnabled = wasBackgroundLayoutEnabled

        // Manually trigger a single text change notification now that insertion is complete
        delegate?.textDidChange()

        NSLog("setColumnCount: columns inserted successfully")
    }

    /// Add one column to an existing column layout (up to max of 4)
    func addColumnToExisting() {
        guard let textStorage = textView.textStorage else { return }
        let cursorLocation = textView.selectedRange().location
        guard cursorLocation < textStorage.length else { return }

        // Find the existing table at cursor
        let attrs = textStorage.attributes(at: cursorLocation, effectiveRange: nil)
        guard let style = attrs[.paragraphStyle] as? NSParagraphStyle,
              let blocks = style.textBlocks as? [NSTextTableBlock],
              let block = blocks.first else {
            // Not in a column layout - create new 2-column layout instead
            setColumnCount(2)
            return
        }

        let existingTable = block.table
        let currentColumns = existingTable.numberOfColumns

        guard currentColumns < 4 else {
            NSLog("addColumnToExisting: already at max columns (4)")
            return
        }

        // Find the full range of the existing column layout
        let string = textStorage.string as NSString
        var startLocation = cursorLocation
        var endLocation = cursorLocation

        // Scan backward to find start
        while startLocation > 0 {
            let prevLoc = startLocation - 1
            let prevAttrs = textStorage.attributes(at: prevLoc, effectiveRange: nil)
            if let prevStyle = prevAttrs[.paragraphStyle] as? NSParagraphStyle,
               let prevBlocks = prevStyle.textBlocks as? [NSTextTableBlock],
               let prevBlock = prevBlocks.first,
               prevBlock.table === existingTable {
                let paragraphRange = string.paragraphRange(for: NSRange(location: prevLoc, length: 0))
                startLocation = paragraphRange.location
            } else {
                break
            }
        }

        // Scan forward to find end
        while endLocation < textStorage.length {
            let nextAttrs = textStorage.attributes(at: endLocation, effectiveRange: nil)
            if let nextStyle = nextAttrs[.paragraphStyle] as? NSParagraphStyle,
               let nextBlocks = nextStyle.textBlocks as? [NSTextTableBlock],
               let nextBlock = nextBlocks.first,
               nextBlock.table === existingTable {
                let paragraphRange = string.paragraphRange(for: NSRange(location: endLocation, length: 0))
                endLocation = NSMaxRange(paragraphRange)
            } else {
                break
            }
        }

        // Extract content from each existing column
        var columnContents: [NSAttributedString] = []
        var scanLocation = startLocation
        while scanLocation < endLocation {
            let paragraphRange = string.paragraphRange(for: NSRange(location: scanLocation, length: 0))
            let content = textStorage.attributedSubstring(from: paragraphRange)
            columnContents.append(content)
            scanLocation = NSMaxRange(paragraphRange)
        }

        let columnRange = NSRange(location: startLocation, length: endLocation - startLocation)

        // Create new table with one more column
        let newColumnCount = currentColumns + 1
        let newTable = NSTextTable()
        newTable.numberOfColumns = newColumnCount
        newTable.layoutAlgorithm = .automaticLayoutAlgorithm
        newTable.collapsesBorders = true

        // Build new column content - preserving existing content and adding new empty column
        let result = NSMutableAttributedString()

        for i in 0..<newColumnCount {
            let textBlock = NSTextTableBlock(table: newTable, startingRow: 0, rowSpan: 1, startingColumn: i, columnSpan: 1)

            // No borders for columns - just use padding for spacing
            textBlock.setBorderColor(.clear, for: .minX)
            textBlock.setBorderColor(.clear, for: .maxX)
            textBlock.setBorderColor(.clear, for: .minY)
            textBlock.setBorderColor(.clear, for: .maxY)
            textBlock.setWidth(0.0, type: .absoluteValueType, for: .border, edge: .minX)
            textBlock.setWidth(0.0, type: .absoluteValueType, for: .border, edge: .maxX)
            textBlock.setWidth(0.0, type: .absoluteValueType, for: .border, edge: .minY)
            textBlock.setWidth(0.0, type: .absoluteValueType, for: .border, edge: .maxY)

            textBlock.setWidth(12.0, type: .absoluteValueType, for: .padding, edge: .minX)
            textBlock.setWidth(12.0, type: .absoluteValueType, for: .padding, edge: .maxX)
            textBlock.setWidth(0.0, type: .absoluteValueType, for: .padding, edge: .minY)
            textBlock.setWidth(0.0, type: .absoluteValueType, for: .padding, edge: .maxY)

            if i < columnContents.count {
                // Preserve existing column content with new textBlock
                let existingContent = columnContents[i]
                let mutableContent = NSMutableAttributedString(attributedString: existingContent)

                // Update the paragraph style to use the new textBlock
                mutableContent.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: mutableContent.length), options: []) { value, range, _ in
                    let pStyle = (value as? NSParagraphStyle) ?? NSParagraphStyle.default
                    let mutablePStyle = (pStyle.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
                    mutablePStyle.textBlocks = [textBlock]
                    mutableContent.addAttribute(.paragraphStyle, value: mutablePStyle.copy() as! NSParagraphStyle, range: range)
                }
                result.append(mutableContent)
            } else {
                // New empty column
                var colAttrs = textView.typingAttributes
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.textBlocks = [textBlock]
                colAttrs[.paragraphStyle] = paragraphStyle

                let columnContent = NSAttributedString(string: " \n", attributes: colAttrs)
                result.append(columnContent)
            }
        }

        // Add final newline to exit columns
        let finalNewline = NSAttributedString(string: "\n", attributes: textView.typingAttributes)
        result.append(finalNewline)

        // Replace the old column layout with the new one
        textStorage.replaceCharacters(in: columnRange, with: result)
        textView.setSelectedRange(NSRange(location: startLocation + 1, length: 0))
        NSLog("addColumnToExisting: expanded from \(currentColumns) to \(newColumnCount) columns")
    }

    // MARK: - Table System (separate from columns)

    func insertTable(rows: Int, columns: Int) {
        NSLog("insertTable called with rows=\(rows), columns=\(columns)")
        guard rows >= 1, rows <= 10, columns >= 1, columns <= 6 else {
            NSLog("insertTable: rows/columns out of range")
            return
        }
        guard let textStorage = textView.textStorage else {
            NSLog("insertTable: no textStorage")
            return
        }

        // Ensure text view can accept input
        textView.window?.makeFirstResponder(textView)

        let currentRange = textView.selectedRange()
        NSLog("insertTable: inserting at location \(currentRange.location)")
        let borderColor = (ThemeManager.shared.currentTheme.headerBackground).withAlphaComponent(0.5)

        let result = NSMutableAttributedString()

        // Create table with visible borders - use collapsesBorders for consistent border widths
        let textTable = NSTextTable()
        textTable.numberOfColumns = columns
        textTable.layoutAlgorithm = .automaticLayoutAlgorithm
        textTable.collapsesBorders = true

        for row in 0..<rows {
            for col in 0..<columns {
                let textBlock = NSTextTableBlock(table: textTable, startingRow: row, rowSpan: 1, startingColumn: col, columnSpan: 1)

                // Add visible borders to table cells - set width for each edge individually
                textBlock.setBorderColor(borderColor, for: .minX)
                textBlock.setBorderColor(borderColor, for: .maxX)
                textBlock.setBorderColor(borderColor, for: .minY)
                textBlock.setBorderColor(borderColor, for: .maxY)
                textBlock.setWidth(1.0, type: .absoluteValueType, for: .border, edge: .minX)
                textBlock.setWidth(1.0, type: .absoluteValueType, for: .border, edge: .maxX)
                textBlock.setWidth(1.0, type: .absoluteValueType, for: .border, edge: .minY)
                textBlock.setWidth(1.0, type: .absoluteValueType, for: .border, edge: .maxY)

                // Cell padding - increased for 14pt text
                textBlock.setWidth(10.0, type: .absoluteValueType, for: .padding, edge: .minX)
                textBlock.setWidth(10.0, type: .absoluteValueType, for: .padding, edge: .maxX)
                textBlock.setWidth(8.0, type: .absoluteValueType, for: .padding, edge: .minY)
                textBlock.setWidth(8.0, type: .absoluteValueType, for: .padding, edge: .maxY)

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.textBlocks = [textBlock]
                paragraphStyle.alignment = .left

                var attrs = textView.typingAttributes
                attrs[.paragraphStyle] = paragraphStyle

                let cellContent = NSAttributedString(string: " \n", attributes: attrs)
                result.append(cellContent)
            }
        }

        // Exit table with clean paragraph
        let exitAttrs: [NSAttributedString.Key: Any] = [
            .font: textView.font ?? NSFont.systemFont(ofSize: 12),
            .paragraphStyle: textView.defaultParagraphStyle ?? NSParagraphStyle.default
        ]
        result.append(NSAttributedString(string: "\n", attributes: exitAttrs))

        // Suppress text change notifications during table insertion
        suppressTextChangeNotifications = true
        defer { suppressTextChangeNotifications = false }

        // Wrap insertion in beginEditing/endEditing to batch notifications
        textStorage.beginEditing()
        textStorage.insert(result, at: currentRange.location)

        // Set cursor position BEFORE endEditing
        let newCursorLocation = currentRange.location + 1
        textView.setSelectedRange(NSRange(location: newCursorLocation, length: 0))

        textStorage.endEditing()

        // Manually trigger a single text change notification
        delegate?.textDidChange()

        NSLog("insertTable: table inserted successfully")
    }

    // MARK: - Table Editing Methods

    func addTableRow() {
        guard let textStorage = textView.textStorage else { return }
        let currentRange = textView.selectedRange()

        // Find the table at cursor
        guard let (table, _, row, _) = findTableAtLocation(currentRange.location) else {
            return
        }

        let borderColor = (ThemeManager.shared.currentTheme.headerBackground).withAlphaComponent(0.5)
        let result = NSMutableAttributedString()

        // Add a new row after the current row
        for i in 0..<table.numberOfColumns {
            let textBlock = NSTextTableBlock(table: table, startingRow: row + 1, rowSpan: 1, startingColumn: i, columnSpan: 1)

            textBlock.setBorderColor(borderColor, for: .minX)
            textBlock.setBorderColor(borderColor, for: .maxX)
            textBlock.setBorderColor(borderColor, for: .minY)
            textBlock.setBorderColor(borderColor, for: .maxY)
            textBlock.setWidth(1.0, type: .absoluteValueType, for: .border)

            textBlock.setWidth(8.0, type: .absoluteValueType, for: .padding, edge: .minX)
            textBlock.setWidth(8.0, type: .absoluteValueType, for: .padding, edge: .maxX)
            textBlock.setWidth(4.0, type: .absoluteValueType, for: .padding, edge: .minY)
            textBlock.setWidth(4.0, type: .absoluteValueType, for: .padding, edge: .maxY)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.textBlocks = [textBlock]
            paragraphStyle.alignment = .left

            var attrs = textView.typingAttributes
            attrs[.paragraphStyle] = paragraphStyle

            let cellContent = NSAttributedString(string: " \n", attributes: attrs)
            result.append(cellContent)
        }

        // Find insertion point (after current paragraph)
        var insertLocation = currentRange.location
        let string = textStorage.string as NSString
        let paragraphRange = string.paragraphRange(for: currentRange)
        insertLocation = NSMaxRange(paragraphRange)

        textStorage.insert(result, at: insertLocation)
    }

    func addTableColumn() {
        // Adding a column requires rebuilding the entire table
        // This is complex with NSTextTable, so we'll notify the user
        showThemedAlert(title: "Add Column", message: "To add a column, please insert a new table with the desired column count.")
    }

    func deleteTableRow() {
        guard let textStorage = textView.textStorage else { return }
        let currentRange = textView.selectedRange()

        // Find the table at cursor
        guard let (table, _, _, _) = findTableAtLocation(currentRange.location) else {
            return
        }

        // Delete the current paragraph (row)
        let string = textStorage.string as NSString
        let paragraphRange = string.paragraphRange(for: currentRange)

        // Delete all cells in this row
        var rangeToDelete = paragraphRange
        for _ in 1..<table.numberOfColumns {
            let nextParagraphStart = NSMaxRange(rangeToDelete)
            if nextParagraphStart < textStorage.length {
                let nextParagraphRange = string.paragraphRange(for: NSRange(location: nextParagraphStart, length: 0))
                rangeToDelete = NSUnionRange(rangeToDelete, nextParagraphRange)
            }
        }

        textStorage.deleteCharacters(in: rangeToDelete)
    }

    func deleteTableColumn() {
        showThemedAlert(title: "Delete Column", message: "To delete a column, please recreate the table with the desired column count.")
    }

    func deleteTable() {
        guard let textStorage = textView.textStorage else { return }
        let currentRange = textView.selectedRange()

        // Find the table at cursor
        guard let (table, startLocation, _, _) = findTableAtLocation(currentRange.location) else {
            return
        }

        // Find the entire range of the table
        var endLocation = startLocation
        let string = textStorage.string as NSString

        // Scan forward to find all cells in the table
        while endLocation < textStorage.length {
            let attrs = textStorage.attributes(at: endLocation, effectiveRange: nil)
            if let style = attrs[.paragraphStyle] as? NSParagraphStyle,
               let blocks = style.textBlocks as? [NSTextTableBlock],
               let block = blocks.first,
               block.table === table {
                let paragraphRange = string.paragraphRange(for: NSRange(location: endLocation, length: 0))
                endLocation = NSMaxRange(paragraphRange)
            } else {
                break
            }
        }

        let tableRange = NSRange(location: startLocation, length: endLocation - startLocation)
        textStorage.deleteCharacters(in: tableRange)
    }

    private func findTableAtLocation(_ location: Int) -> (table: NSTextTable, startLocation: Int, row: Int, column: Int)? {
        guard let textStorage = textView.textStorage, location < textStorage.length else { return nil }

        let attrs = textStorage.attributes(at: location, effectiveRange: nil)
        guard let style = attrs[.paragraphStyle] as? NSParagraphStyle,
              let blocks = style.textBlocks as? [NSTextTableBlock],
              let block = blocks.first else {
            return nil
        }

        let table = block.table
        let row = block.startingRow
        let column = block.startingColumn

        // Find start of table
        var startLocation = location
        let string = textStorage.string as NSString
        while startLocation > 0 {
            let prevLocation = startLocation - 1
            let prevAttrs = textStorage.attributes(at: prevLocation, effectiveRange: nil)
            if let prevStyle = prevAttrs[.paragraphStyle] as? NSParagraphStyle,
               let prevBlocks = prevStyle.textBlocks as? [NSTextTableBlock],
               let prevBlock = prevBlocks.first,
               prevBlock.table === table {
                let paragraphRange = string.paragraphRange(for: NSRange(location: prevLocation, length: 0))
                startLocation = paragraphRange.location
            } else {
                break
            }
        }

        return (table, startLocation, row, column)
    }

    func deleteColumnAtCursor() {
        guard let textStorage = textView.textStorage else { return }
        let cursorPosition = textView.selectedRange().location
        guard cursorPosition < textStorage.length else { return }

        // Get the paragraph style at cursor position
        let attrs = textStorage.attributes(at: cursorPosition, effectiveRange: nil)
        guard let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle,
              let textBlocks = paragraphStyle.textBlocks as? [NSTextTableBlock],
              let currentBlock = textBlocks.first else {
            NSLog("No table column found at cursor position")
            return
        }

        let table = currentBlock.table
        let columnToDelete = currentBlock.startingColumn
        let totalColumns = table.numberOfColumns

        NSLog("Deleting column \(columnToDelete) from table with \(totalColumns) columns")

        // Find all paragraphs in the table first
        let fullString = textStorage.string as NSString
        var tableRanges: [(range: NSRange, column: Int, content: NSAttributedString)] = []
        var searchLocation = 0

        while searchLocation < textStorage.length {
            let attrs = textStorage.attributes(at: searchLocation, effectiveRange: nil)
            if let ps = attrs[.paragraphStyle] as? NSParagraphStyle,
               let blocks = ps.textBlocks as? [NSTextTableBlock],
               let block = blocks.first,
               block.table == table {
                let pRange = fullString.paragraphRange(for: NSRange(location: searchLocation, length: 0))
                let content = textStorage.attributedSubstring(from: pRange)
                tableRanges.append((range: pRange, column: block.startingColumn, content: content))
                searchLocation = NSMaxRange(pRange)
            } else {
                searchLocation += 1
            }
        }

        guard !tableRanges.isEmpty else { return }

        // Find the full table range
        let tableStart = tableRanges.first!.range.location
        let tableEnd = NSMaxRange(tableRanges.last!.range)
        let fullTableRange = NSRange(location: tableStart, length: tableEnd - tableStart)

        // If this would leave only one column or fewer, convert to body text
        if totalColumns <= 2 {
            NSLog("Converting table to body text (only \(totalColumns - 1) column(s) would remain)")

            // Create standard body text paragraph style
            let bodyParagraphStyle = NSMutableParagraphStyle()
            bodyParagraphStyle.alignment = .left
            bodyParagraphStyle.lineHeightMultiple = 2.0
            bodyParagraphStyle.paragraphSpacing = 0
            bodyParagraphStyle.firstLineHeadIndent = 36

            let bodyText = NSMutableAttributedString()
            let bodyFont = NSFont(name: "Times New Roman", size: 12) ?? NSFont.systemFont(ofSize: 12)

            // Collect content from all columns except the deleted one and convert to body text
            for column in 0..<totalColumns {
                if column == columnToDelete {
                    continue
                }

                if let columnContent = tableRanges.first(where: { $0.column == column })?.content {
                    let mutableContent = NSMutableAttributedString(attributedString: columnContent)
                    // Remove table paragraph style and apply body text style
                    mutableContent.removeAttribute(.paragraphStyle, range: NSRange(location: 0, length: mutableContent.length))
                    mutableContent.addAttribute(.paragraphStyle, value: bodyParagraphStyle, range: NSRange(location: 0, length: mutableContent.length))

                    // Ensure font is set
                    mutableContent.enumerateAttribute(.font, in: NSRange(location: 0, length: mutableContent.length), options: []) { value, range, _ in
                        if value == nil {
                            mutableContent.addAttribute(.font, value: bodyFont, range: range)
                        }
                    }

                    bodyText.append(mutableContent)
                }
            }

            // Replace table with body text
            textStorage.replaceCharacters(in: fullTableRange, with: bodyText)
            textView.setSelectedRange(NSRange(location: tableStart, length: 0))
            return
        }

        // Create new table with one fewer column
        let newTable = NSTextTable()
        newTable.numberOfColumns = totalColumns - 1
        newTable.layoutAlgorithm = .automaticLayoutAlgorithm
        newTable.collapsesBorders = true

        let borderColor = (ThemeManager.shared.currentTheme.headerBackground).withAlphaComponent(0.5)
        let result = NSMutableAttributedString()

        // Rebuild the table without the deleted column
        var newColumnIndex = 0
        for column in 0..<totalColumns {
            if column == columnToDelete {
                continue // Skip the deleted column
            }

            // Find content for this column
            let columnContent = tableRanges.first(where: { $0.column == column })?.content

            let textBlock = NSTextTableBlock(table: newTable, startingRow: 0, rowSpan: 1, startingColumn: newColumnIndex, columnSpan: 1)

            textBlock.setBorderColor(borderColor, for: .minX)
            textBlock.setBorderColor(borderColor, for: .maxX)
            textBlock.setBorderColor(borderColor, for: .minY)
            textBlock.setBorderColor(borderColor, for: .maxY)
            textBlock.setWidth(1.0, type: .absoluteValueType, for: .border)
            textBlock.setWidth(8.0, type: .absoluteValueType, for: .padding, edge: .minX)
            textBlock.setWidth(8.0, type: .absoluteValueType, for: .padding, edge: .maxX)
            textBlock.setWidth(8.0, type: .absoluteValueType, for: .padding, edge: .minY)
            textBlock.setWidth(8.0, type: .absoluteValueType, for: .padding, edge: .maxY)

            let newParagraphStyle = NSMutableParagraphStyle()
            newParagraphStyle.textBlocks = [textBlock]

            if let content = columnContent {
                let mutableContent = NSMutableAttributedString(attributedString: content)
                mutableContent.addAttribute(.paragraphStyle, value: newParagraphStyle, range: NSRange(location: 0, length: mutableContent.length))
                result.append(mutableContent)
            } else {
                var attrs = textView.typingAttributes
                attrs[.paragraphStyle] = newParagraphStyle
                let placeholder = NSAttributedString(string: "Column \(newColumnIndex + 1)\n", attributes: attrs)
                result.append(placeholder)
            }

            newColumnIndex += 1
        }

        // Add final newline to exit table - use clean attributes without table formatting
        let cleanParagraphStyle = NSMutableParagraphStyle()
        cleanParagraphStyle.alignment = .left
        cleanParagraphStyle.lineHeightMultiple = 2.0
        let cleanFont = NSFont(name: "Times New Roman", size: 12) ?? NSFont.systemFont(ofSize: 12)
        let finalNewline = NSAttributedString(string: "\n", attributes: [
            .font: cleanFont,
            .paragraphStyle: cleanParagraphStyle,
            .foregroundColor: currentTheme.textColor
        ])
        result.append(finalNewline)

        // Replace the old table with the new one
        textStorage.replaceCharacters(in: fullTableRange, with: result)
        textView.setSelectedRange(NSRange(location: tableStart, length: 0))
    }

    func removeTableAtCursor() {
        guard let textStorage = textView.textStorage else { return }
        let cursorPosition = textView.selectedRange().location
        guard cursorPosition < textStorage.length else { return }

        let attrs = textStorage.attributes(at: cursorPosition, effectiveRange: nil)
        guard let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle,
              let textBlocks = paragraphStyle.textBlocks as? [NSTextTableBlock],
              let currentBlock = textBlocks.first else {
            return
        }

        let table = currentBlock.table

        // Find all paragraphs in the table
        let fullString = textStorage.string as NSString
        var tableRanges: [NSRange] = []
        var searchLocation = 0

        while searchLocation < textStorage.length {
            let attrs = textStorage.attributes(at: searchLocation, effectiveRange: nil)
            if let ps = attrs[.paragraphStyle] as? NSParagraphStyle,
               let blocks = ps.textBlocks as? [NSTextTableBlock],
               let block = blocks.first,
               block.table == table {
                let pRange = fullString.paragraphRange(for: NSRange(location: searchLocation, length: 0))
                tableRanges.append(pRange)
                searchLocation = NSMaxRange(pRange)
            } else {
                searchLocation += 1
            }
        }

        guard !tableRanges.isEmpty else { return }

        let tableStart = tableRanges.first!.location
        let tableEnd = NSMaxRange(tableRanges.last!)
        let fullTableRange = NSRange(location: tableStart, length: tableEnd - tableStart)

        // Extract text content without table formatting and apply body text style
        let plainText = NSMutableAttributedString()

        // Create standard body text paragraph style
        let bodyParagraphStyle = NSMutableParagraphStyle()
        bodyParagraphStyle.alignment = .left
        bodyParagraphStyle.lineHeightMultiple = 2.0
        bodyParagraphStyle.paragraphSpacing = 0
        bodyParagraphStyle.firstLineHeadIndent = 36

        for range in tableRanges {
            let content = textStorage.attributedSubstring(from: range)
            let mutableContent = NSMutableAttributedString(attributedString: content)

            // Remove table-specific attributes and apply body text style
            mutableContent.removeAttribute(.paragraphStyle, range: NSRange(location: 0, length: mutableContent.length))
            mutableContent.addAttribute(.paragraphStyle, value: bodyParagraphStyle, range: NSRange(location: 0, length: mutableContent.length))

            // Ensure font is set to body text default
            if mutableContent.attribute(.font, at: 0, effectiveRange: nil) == nil {
                let bodyFont = NSFont(name: "Times New Roman", size: 12) ?? NSFont.systemFont(ofSize: 12)
                mutableContent.addAttribute(.font, value: bodyFont, range: NSRange(location: 0, length: mutableContent.length))
            }

            plainText.append(mutableContent)
        }

        textStorage.replaceCharacters(in: fullTableRange, with: plainText)
        textView.setSelectedRange(NSRange(location: tableStart, length: 0))
    }

    func applyTheme(_ theme: AppTheme) {
        currentTheme = theme
        view.layer?.backgroundColor = theme.pageAround.cgColor
        view.layer?.setNeedsDisplay()

        scrollView?.backgroundColor = theme.pageAround
        documentView?.layer?.backgroundColor = theme.pageAround.cgColor
        documentView?.layer?.setNeedsDisplay()

        // Update PageContainerView to draw with theme colors
        if let pageContainerView = pageContainer as? PageContainerView {
            pageContainerView.pageBackgroundColor = theme.pageBackground
            pageContainerView.setNeedsDisplay(pageContainerView.bounds)
        } else {
            pageContainer?.layer?.backgroundColor = theme.pageBackground.cgColor
        }

        pageContainer?.layer?.borderColor = theme.pageBorder.cgColor
        let shadowColor = NSColor.black.withAlphaComponent(theme == .day ? 0.3 : 0.65)
        pageContainer?.layer?.shadowColor = shadowColor.cgColor
        textView?.backgroundColor = .clear  // Transparent so page backgrounds show through
        textView?.textColor = theme.textColor
        textView?.insertionPointColor = theme.insertionPointColor

        // Update all text in the document to use the theme color
        if let textStorage = textView?.textStorage, textStorage.length > 0 {
            textStorage.beginEditing()
            // Apply theme text color to ALL text in the document
            textStorage.addAttribute(.foregroundColor, value: theme.textColor, range: NSRange(location: 0, length: textStorage.length))
            textStorage.endEditing()
        }

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

            // Preserve textBlocks (for tables/columns) before editing
            let existingTextBlocks = current.textBlocks

            edit(mutable)

            // Restore textBlocks after editing to keep table/column structure
            if !existingTextBlocks.isEmpty {
                mutable.textBlocks = existingTextBlocks
            }

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
        // Skip notification if we're suppressing changes (e.g., during column insertion)
        guard !suppressTextChangeNotifications else { return }

        delegate?.textDidChange()

        // Throttle expensive operations to improve typing performance
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(checkAndUpdateTitleDelayed), object: nil)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updatePageCenteringDelayed), object: nil)

        // Different delays for columns vs tables: columns are simpler formatting, tables are complex structures
        let isInColumns = isCurrentPositionInColumns()
        let isInTable = isCurrentPositionInTable()

        let titleDelay: TimeInterval
        let layoutDelay: TimeInterval

        if isInTable {
            // Data tables need aggressive throttling
            titleDelay = 1.0
            layoutDelay = 5.0
        } else if isInColumns {
            // Columns are lighter - just text flow formatting
            titleDelay = 0.5
            layoutDelay = 1.5
        } else {
            // Normal text - use longer delay to avoid frequent expensive layout recalculations
            titleDelay = 0.3
            layoutDelay = 1.0
        }

        perform(#selector(checkAndUpdateTitleDelayed), with: nil, afterDelay: titleDelay)
        perform(#selector(updatePageCenteringDelayed), with: nil, afterDelay: layoutDelay)
    }

    @objc private func checkAndUpdateTitleDelayed() {
        checkAndUpdateTitle()
    }

    @objc private func updatePageCenteringDelayed() {
        updatePageCentering()
        // Only update page layout if not actively typing in tables or columns
        if !isCurrentPositionInTable() && !isCurrentPositionInColumns() {
            updatePageLayout()
        }
    }

    private func isCurrentPositionInTable() -> Bool {
        guard let textStorage = textView?.textStorage else { return false }
        let location = textView.selectedRange().location
        guard location < textStorage.length else { return false }

        let attrs = textStorage.attributes(at: location, effectiveRange: nil)
        if let style = attrs[.paragraphStyle] as? NSParagraphStyle,
           let blocks = style.textBlocks as? [NSTextTableBlock],
           let block = blocks.first {
            // Data tables have cells with different startingRow values
            // Column layouts have all cells with startingRow=0
            // Just check the current row - if it's > 0, it's definitely a data table
            return block.startingRow > 0
        }
        return false
    }

    private func isCurrentPositionInColumns() -> Bool {
        guard let textStorage = textView?.textStorage else { return false }
        let location = textView.selectedRange().location
        guard location < textStorage.length else { return false }

        let attrs = textStorage.attributes(at: location, effectiveRange: nil)
        if let style = attrs[.paragraphStyle] as? NSParagraphStyle,
           let blocks = style.textBlocks as? [NSTextTableBlock],
           let block = blocks.first {
            // Column layouts: all cells have startingRow=0, multiple columns
            // Data tables: cells have varying startingRow values
            return block.startingRow == 0 && block.table.numberOfColumns > 1
        }
        return false
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

    func textViewDidChangeSelection(_ notification: Notification) {
        // Skip if we're suppressing notifications (e.g., during column insertion)
        guard !suppressTextChangeNotifications else { return }

        showImageControlsIfNeeded()

        // If format painter is active and user makes a selection, apply the formatting
        if formatPainterActive,
           let selectedRange = textView.selectedRanges.first?.rangeValue,
           selectedRange.length > 0 {
            applyFormatPainterToSelection()
        }

        // Notify delegate that selection changed (for updating style dropdown)
        delegate?.selectionDidChange()
    }
}
