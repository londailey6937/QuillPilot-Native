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

    private var imageControlsPopover: NSPopover?
    private var lastImageRange: NSRange?
    private var imageScaleLabel: NSTextField?
    private var popoverScrollObserver: NSObjectProtocol?

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
            // The dirtyRect optimization was preventing pages beyond a certain point from rendering
            for pageNum in 0..<numPages {
                let pageY = CGFloat(pageNum) * (pageHeight + pageGap)
                let pageRect = NSRect(x: 0, y: pageY, width: bounds.width, height: pageHeight)

                pageBackgroundColor.setFill()
                pageRect.fill()

                // Draw page border
                NSColor.lightGray.setStroke()
                NSBezierPath.stroke(pageRect)
            }
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
        let initialPageContainer = PageContainerView(frame: NSRect(x: 0, y: 0, width: 612 * editorZoom, height: 1650000 * editorZoom))
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
        guard let textStorage = textView.textStorage,
              let layoutManager = textView.layoutManager else { return }

        let currentRange = textView.selectedRange()

        // Force layout to ensure we have accurate glyph information
            layoutManager.ensureLayout(for: textView.textContainer!)
            let fullGlyphRange = NSRange(location: 0, length: layoutManager.numberOfGlyphs)
            layoutManager.ensureLayout(forGlyphRange: fullGlyphRange)

        // Get the current Y position of the cursor
        let glyphRange = layoutManager.glyphRange(forCharacterRange: currentRange, actualCharacterRange: nil)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer!)
        let currentY = glyphRect.origin.y

        // Calculate which page we're on and how much space until next page
        let scaledPageHeight = pageHeight * editorZoom
        let pageGap: CGFloat = 20
        let pageWithGap = scaledPageHeight + pageGap

        let currentPage = floor(currentY / pageWithGap)
        let nextPageY = (currentPage + 1) * pageWithGap
        let spaceToNextPage = nextPageY - currentY

        // Create a paragraph style with spacing to reach next page
        let breakStyle = NSMutableParagraphStyle()
        breakStyle.paragraphSpacing = max(0, spaceToNextPage)
        breakStyle.paragraphSpacingBefore = 0

        // Begin editing to register with undo manager
        textStorage.beginEditing()

        // Insert a newline with the page break style
        let breakString = NSAttributedString(string: "\n", attributes: [
            .paragraphStyle: breakStyle,
            .font: textView.font ?? NSFont.systemFont(ofSize: 12)
        ])

        if textView.shouldChangeText(in: currentRange, replacementString: "\n") {
            textStorage.replaceCharacters(in: currentRange, with: breakString)
            textStorage.endEditing()
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: currentRange.location + 1, length: 0))
        } else {
            textStorage.endEditing()
        }

        // Force layout update
        updatePageCentering()
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
        let maxWidth = textContainerWidth
        let scale = min(1.0, maxWidth / image.size.width)
        let targetSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(origin: .zero, size: targetSize)

        textView.window?.makeFirstResponder(textView)

        // Store the current insertion point before any modal dialogs affect focus
        let caretRange = textView.selectedRange()
        let insertionPoint = min(caretRange.location, textView.string.count)
        let insertionRange = NSRange(location: insertionPoint, length: 0)

        // Create a simple image paragraph without extra newlines that could push content into exclusion zones
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.paragraphSpacing = 0
        para.paragraphSpacingBefore = 0
        para.firstLineHeadIndent = 0
        para.headIndent = 0
        para.tailIndent = 0

        let imageString = NSMutableAttributedString(attachment: attachment)
        imageString.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: imageString.length))

        replaceCharacters(in: insertionRange, with: imageString, undoPlaceholder: "\u{FFFC}")

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
        let currentWidth = (textView.textStorage?.attribute(.attachment, at: attachmentRange.location, effectiveRange: nil) as? NSTextAttachment)?.bounds.width ?? maxWidth
        let currentScale = max(0.1, min(1.5, currentWidth / maxWidth))

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
            makeButton("↓", action: #selector(moveImageDown))
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

        let slider = NSSlider(value: currentScale, minValue: 0.25, maxValue: 1.5, target: self, action: #selector(resizeSliderChanged(_:)))
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

        let currentText = storage.attributedSubstring(from: currentPara)

        if direction < 0 {
            if currentPara.location == 0 { return }
            let prevPara = fullString.paragraphRange(for: NSRange(location: max(0, currentPara.location - 1), length: 0))
            if prevPara.location == currentPara.location { return }
            let prevText = storage.attributedSubstring(from: prevPara)
            let combinedRange = NSRange(location: prevPara.location, length: NSMaxRange(currentPara) - prevPara.location)
            let swapped = NSMutableAttributedString()
            swapped.append(currentText)
            swapped.append(prevText)

            guard textView.shouldChangeText(in: combinedRange, replacementString: swapped.string) else { return }
            storage.beginEditing()
            storage.replaceCharacters(in: combinedRange, with: swapped)
            storage.endEditing()
            textView.setSelectedRange(NSRange(location: prevPara.location, length: currentText.length))
        } else {
            let nextStart = NSMaxRange(currentPara)
            if nextStart >= storage.length { return }
            let nextPara = fullString.paragraphRange(for: NSRange(location: nextStart, length: 0))
            if nextPara.location == currentPara.location { return }
            let nextText = storage.attributedSubstring(from: nextPara)
            let combinedRange = NSRange(location: currentPara.location, length: NSMaxRange(nextPara) - currentPara.location)
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
        let naturalSize = attachment.image?.size ?? attachment.bounds.size
        let clampedScale = max(0.25, min(1.5, scale))
        let targetWidth = max(40, maxWidth * clampedScale)
        let aspect = (naturalSize.width > 0) ? (naturalSize.height / naturalSize.width) : 1
        let targetHeight = targetWidth * aspect

        attachment.bounds = NSRect(origin: .zero, size: NSSize(width: targetWidth, height: targetHeight))
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
        replaceCharacters(in: range, with: NSAttributedString(string: ""), undoPlaceholder: "")
        imageControlsPopover?.performClose(nil)
        imageControlsPopover = nil
    }

    @objc private func replaceImage() {
        guard let storage = textView.textStorage else { return }
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

                // Apply paragraph style at paragraph level
                normalized.addAttribute(.paragraphStyle, value: paragraph, range: paragraphRange)

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

                let inferredStyleName = inferStyle(font: font, paragraphStyle: paragraph)

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
        // Before setting content, detect and re-tag catalog styles based on font/size/alignment
        let retagged = detectAndRetagStyles(in: attributed)
        textView.textStorage?.setAttributedString(retagged)

        // Verify colors after setting into textStorage
        // NSLog("=== AFTER setAttributedString ===")
        /*
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
        */
        // NSLog("=================================")

        // Use neutral defaults for new typing so loaded heading styles don't bleed into new paragraphs
        let neutralParagraph = NSMutableParagraphStyle()
        neutralParagraph.alignment = .left
        neutralParagraph.lineHeightMultiple = 2.0
        neutralParagraph.paragraphSpacing = 0
        neutralParagraph.firstLineHeadIndent = 36
        textView.defaultParagraphStyle = neutralParagraph

        // Update typing attributes for new text without overwriting existing content
        let defaultFont = NSFont(name: "Times New Roman", size: 14) ?? NSFont.systemFont(ofSize: 14)
        var newTypingAttributes = textView.typingAttributes
        newTypingAttributes[.font] = defaultFont
        newTypingAttributes[.paragraphStyle] = neutralParagraph
        textView.typingAttributes = newTypingAttributes

        // Don't set textView.textColor - it can interfere with attributed string colors
        // textView.textColor = currentTheme.textColor
        refreshTypingAttributesUsingDefaultParagraphStyle()

        // Force immediate layout and page resize to accommodate all content
        updatePageCentering()
        scrollToTop()

        // Notify delegate that content changed (for analysis, etc.)
        NSLog("📄 setAttributedContent complete, notifying delegate")
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

            // Infer style based on font and paragraph attributes
            let styleName = inferStyle(font: font, paragraphStyle: paragraphStyle)

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

    private func inferStyle(font: NSFont, paragraphStyle: NSParagraphStyle) -> String {
        let currentTemplate = StyleCatalog.shared.currentTemplateName
        let styleNames = StyleCatalog.shared.styleNames(for: currentTemplate)

        var bestMatch: String = "Body Text"
        var bestScore: Int = -100

        let fontTraits = NSFontManager.shared.traits(of: font)
        let isBold = fontTraits.contains(.boldFontMask)
        let isItalic = fontTraits.contains(.italicFontMask)

        for name in styleNames {
            guard let style = StyleCatalog.shared.style(named: name) else { continue }

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

            // Invalidate and force layout for all glyphs to get an accurate total height
            let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
            layoutManager.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
            let fullGlyphRange = NSRange(location: 0, length: layoutManager.numberOfGlyphs)
            layoutManager.ensureLayout(forGlyphRange: fullGlyphRange)
            let usedHeight = layoutManager.usedRect(for: textContainer).height
            let measuredPages = Int(ceil(usedHeight / pageTextHeight))

            // Heuristic safety net: estimate pages from character count to avoid undercounts on very long texts
            let charsPerPageEstimate = 1200.0  // rough average for 12pt double-spaced text
            let estimatedPages = Int(ceil(Double(textView.string.utf16.count) / charsPerPageEstimate))

            numPages = max(1, max(measuredPages, estimatedPages))

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
        newTable.collapsesBorders = false

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
        scrollView?.backgroundColor = theme.pageAround
        documentView?.layer?.backgroundColor = theme.pageAround.cgColor

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

    func textViewDidChangeSelection(_ notification: Notification) {
        showImageControlsIfNeeded()
    }
}
