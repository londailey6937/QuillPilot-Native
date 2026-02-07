//
//  EditorViewController.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa
import CoreText
import ImageIO
import UniformTypeIdentifiers

extension NSAttributedString.Key {
    /// Marks a section break. Value is SectionBreak encoded as Data.
    static let qpSectionBreak = NSAttributedString.Key("QPSectionBreak")

    /// Marks a page break. Value is `true`.
    /// Internally represented as a spacer attachment that expands to fill the remainder of the current page.
    static let qpPageBreak = NSAttributedString.Key("QPPageBreak")
}

struct SectionBreakInfo: Identifiable, Equatable {
    let id: String
    var name: String
    var startPageNumber: Int
    var numberFormatDisplay: String
    var location: Int
}

private struct SectionBreak: Codable, Equatable {
    let id: String
    var name: String
    var startPageNumber: Int
    var numberFormat: SectionPageNumberFormat

    static func newID() -> String {
        "_Section" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10)
    }

    init(id: String, name: String, startPageNumber: Int, numberFormat: SectionPageNumberFormat = .arabic) {
        self.id = id
        self.name = name
        self.startPageNumber = startPageNumber
        self.numberFormat = numberFormat
    }

    enum CodingKeys: String, CodingKey {
        case id, name, startPageNumber, numberFormat
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startPageNumber = try container.decode(Int.self, forKey: .startPageNumber)
        numberFormat = try container.decodeIfPresent(SectionPageNumberFormat.self, forKey: .numberFormat) ?? .arabic
    }
}

private enum SectionPageNumberFormat: String, CaseIterable, Codable {
    case arabic = "Arabic (1, 2, 3)"
    case romanUpper = "Roman (I, II, III)"
    case romanLower = "Roman (i, ii, iii)"
}

private final class AttachmentClickableTextView: NSTextView {
    var onMouseDownInTextView: ((NSPoint) -> Void)?

    var onImageDrop: ((NSImage, URL?, NSPoint, NSRange?) -> Void)?
    private var draggedAttachmentRange: NSRange?
    private var draggedAttachmentImage: NSImage?
    private var pendingAttachmentSelection: NSRange?

    private func acceptedDragOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard

        if sender.draggingSource as? AttachmentClickableTextView != nil {
            return .move
        }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            return .copy
        }
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], !images.isEmpty {
            return .copy
        }
        if pasteboard.data(forType: .tiff) != nil || pasteboard.data(forType: .png) != nil {
            return .copy
        }
        if let string = pasteboard.string(forType: .string), URL(string: string) != nil {
            return .copy
        }
        return []
    }

    // Menu/command hooks (handled by the owning editor).
    var onToggleBulletedList: (() -> Void)?
    var onToggleNumberedList: (() -> Void)?
    var onRestartNumbering: (() -> Void)?

    var showsParagraphMarks: Bool = false
    var paragraphMarksColor: NSColor = .systemOrange
    var spaceDotsColor: NSColor = .darkGray
    var showsSectionBreaks: Bool = false
    var sectionBreaksColor: NSColor = .systemOrange
    var showsPageBreaks: Bool = false
    var pageBreaksColor: NSColor = .systemOrange
    private let paragraphGlyph = "¶"
    private let spaceGlyph = "•"
    private let tabGlyph = "→"
    private let sectionBreakGlyph = "§"
    private let pageBreakLabel = "⇣ Page Break"

    @objc func qpToggleBulletedList(_ sender: Any?) {
        onToggleBulletedList?()
    }

    @objc func qpToggleNumberedList(_ sender: Any?) {
        onToggleNumberedList?()
    }

    @objc func qpRestartNumbering(_ sender: Any?) {
        onRestartNumbering?()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        draggedAttachmentRange = nil
        draggedAttachmentImage = nil

        // If the user clicked a visible section break marker (the drawn §), select the underlying
        // zero-width anchor so the user gets immediate selection feedback.
        if selectSectionBreakMarkerIfClicked(at: point) {
            onMouseDownInTextView?(point)
            return
        }

        if selectPageBreakMarkerIfClicked(at: point) {
            onMouseDownInTextView?(point)
            return
        }

        // If the user clicked an image attachment, select it and prep for dragging.
        if let layoutManager = layoutManager,
           let textContainer = textContainer,
           let storage = textStorage {
            let p = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
            var fraction: CGFloat = 0
            let index = layoutManager.characterIndex(for: p, in: textContainer, fractionOfDistanceBetweenInsertionPoints: &fraction)

            func attachmentAt(_ loc: Int) -> (NSRange, NSTextAttachment)? {
                guard storage.length > 0 else { return nil }
                let clamped = max(0, min(loc, storage.length - 1))
                var effective = NSRange(location: NSNotFound, length: 0)
                if storage.attribute(.qpPageBreak, at: clamped, effectiveRange: nil) != nil {
                    return nil
                }
                guard let attachment = storage.attribute(.attachment, at: clamped, effectiveRange: &effective) as? NSTextAttachment,
                      effective.location != NSNotFound else { return nil }
                return (effective, attachment)
            }

            let hit = attachmentAt(index) ?? (index > 0 ? attachmentAt(index - 1) : nil)
            if let (range, attachment) = hit {
                window?.makeFirstResponder(self)
                setSelectedRange(range)
                draggedAttachmentRange = range
                pendingAttachmentSelection = range

                if attachment.image == nil, let data = attachment.fileWrapper?.regularFileContents {
                    attachment.image = NSImage(data: data)
                }
                draggedAttachmentImage = attachment.image

                // Notify owner (selection-based UI like image controls) and keep selection.
                onMouseDownInTextView?(point)
                needsDisplay = true
                return
            }
        }

        onMouseDownInTextView?(point)
        super.mouseDown(with: event)
    }

    private func selectSectionBreakMarkerIfClicked(at viewPoint: NSPoint) -> Bool {
        guard showsSectionBreaks,
              let layoutManager,
              let textContainer,
              let storage = textStorage,
              storage.length > 0 else { return false }

        let containerPoint = NSPoint(
            x: viewPoint.x - textContainerOrigin.x,
            y: viewPoint.y - textContainerOrigin.y
        )

        // Find the line fragment at this point.
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        var lineGlyphRange = NSRange(location: 0, length: 0)
        let lineFragmentRect = layoutManager.lineFragmentRect(
            forGlyphAt: glyphIndex,
            effectiveRange: &lineGlyphRange,
            withoutAdditionalLayout: true
        )

        let charRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
        guard charRange.length > 0 else { return false }

        // Only treat clicks near the drawn glyph position as a marker click.
        let styleIndex = max(0, min(charRange.location, storage.length - 1))
        let paragraphStyle = (storage.attribute(.paragraphStyle, at: styleIndex, effectiveRange: nil) as? NSParagraphStyle)
            ?? (typingAttributes[.paragraphStyle] as? NSParagraphStyle)
            ?? defaultParagraphStyle
            ?? NSParagraphStyle.default

        let glyphX = textContainerOrigin.x + lineFragmentRect.origin.x + paragraphStyle.firstLineHeadIndent
        let clickableRect = NSRect(
            x: glyphX - 6,
            y: textContainerOrigin.y + lineFragmentRect.origin.y,
            width: 26,
            height: lineFragmentRect.height
        )
        guard clickableRect.contains(viewPoint) else { return false }

        // If this line contains a section break marker, select it.
        var markerRange: NSRange?
        storage.enumerateAttribute(.qpSectionBreak, in: charRange, options: []) { value, range, stop in
            if value != nil {
                markerRange = range
                stop.pointee = true
            }
        }
        guard let markerRange, markerRange.location != NSNotFound else { return false }

        window?.makeFirstResponder(self)
        setSelectedRange(markerRange)
        scrollRangeToVisible(markerRange)
        showFindIndicator(for: markerRange)
        needsDisplay = true
        return true
    }

    private func selectPageBreakMarkerIfClicked(at viewPoint: NSPoint) -> Bool {
        guard showsPageBreaks,
              let layoutManager,
              let textContainer,
              let storage = textStorage,
              storage.length > 0 else { return false }

        let containerPoint = NSPoint(
            x: viewPoint.x - textContainerOrigin.x,
            y: viewPoint.y - textContainerOrigin.y
        )

        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        var lineGlyphRange = NSRange(location: 0, length: 0)
        let lineFragmentRect = layoutManager.lineFragmentRect(
            forGlyphAt: glyphIndex,
            effectiveRange: &lineGlyphRange,
            withoutAdditionalLayout: true
        )

        let charRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
        guard charRange.length > 0 else { return false }

        let styleIndex = max(0, min(charRange.location, storage.length - 1))
        let paragraphStyle = (storage.attribute(.paragraphStyle, at: styleIndex, effectiveRange: nil) as? NSParagraphStyle)
            ?? (typingAttributes[.paragraphStyle] as? NSParagraphStyle)
            ?? defaultParagraphStyle
            ?? NSParagraphStyle.default

        let glyphX = textContainerOrigin.x + lineFragmentRect.origin.x + paragraphStyle.firstLineHeadIndent
        let clickableRect = NSRect(
            x: glyphX - 6,
            y: textContainerOrigin.y + lineFragmentRect.origin.y,
            width: 120,
            height: max(18, min(28, lineFragmentRect.height))
        )
        guard clickableRect.contains(viewPoint) else { return false }

        var markerRange: NSRange?
        storage.enumerateAttribute(.qpPageBreak, in: charRange, options: []) { value, range, stop in
            if value != nil {
                markerRange = range
                stop.pointee = true
            }
        }
        guard let markerRange, markerRange.location != NSNotFound else { return false }

        window?.makeFirstResponder(self)
        setSelectedRange(markerRange)
        scrollRangeToVisible(markerRange)
        showFindIndicator(for: markerRange)
        needsDisplay = true
        return true
    }

    override func mouseDragged(with event: NSEvent) {
        let attachmentRange: NSRange?
        if let pending = pendingAttachmentSelection {
            attachmentRange = pending
        } else {
            let sel = selectedRange()
            attachmentRange = sel.length == 1 ? sel : nil
        }

        if let range = attachmentRange,
           let storage = textStorage,
           range.location < storage.length,
           storage.attribute(.attachment, at: range.location, effectiveRange: nil) != nil,
           let image = draggedAttachmentImage {
            setSelectedRange(range)
            pendingAttachmentSelection = nil


            let pasteboardItem = NSPasteboardItem()
            if let tiff = image.tiffRepresentation {
                pasteboardItem.setData(tiff, forType: .tiff)
            }
            if let png = image.pngData() {
                pasteboardItem.setData(png, forType: .png)
            }

            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
            if let layoutManager = layoutManager, let textContainer = textContainer {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                rect.origin.x += textContainerOrigin.x
                rect.origin.y += textContainerOrigin.y
                draggingItem.setDraggingFrame(rect, contents: image)
            } else {
                let fallbackRect = NSRect(origin: convert(event.locationInWindow, from: nil), size: image.size)
                draggingItem.setDraggingFrame(fallbackRect, contents: image)
            }

            beginDraggingSession(with: [draggingItem], event: event, source: self)
            return
        }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if let pending = pendingAttachmentSelection {
            setSelectedRange(pending)
            pendingAttachmentSelection = nil
        }
    }

    override func doCommand(by selector: Selector) {
        if selector == #selector(deleteBackward(_:)) {
            if deleteAdjacentSectionBreak(isBackward: true) { return }
            if deleteAdjacentPageBreak(isBackward: true) { return }
        } else if selector == #selector(deleteForward(_:)) {
            if deleteAdjacentSectionBreak(isBackward: false) { return }
            if deleteAdjacentPageBreak(isBackward: false) { return }
        }
        super.doCommand(by: selector)
    }

    private func deleteAdjacentSectionBreak(isBackward: Bool) -> Bool {
        guard let storage = textStorage, storage.length > 0 else { return false }
        let sel = selectedRange()

        // If the user selected a marker, delete it directly.
        if sel.length > 0 {
            var effective = NSRange(location: NSNotFound, length: 0)
            let hasMarker = storage.attribute(.qpSectionBreak, at: sel.location, effectiveRange: &effective) != nil
            if hasMarker && effective.location != NSNotFound {
                return deleteSectionBreak(range: effective)
            }
            return false
        }

        let cursor = sel.location
        let index = isBackward ? (cursor - 1) : cursor
        guard index >= 0, index < storage.length else { return false }
        var effective = NSRange(location: NSNotFound, length: 0)
        let hasMarker = storage.attribute(.qpSectionBreak, at: index, effectiveRange: &effective) != nil
        guard hasMarker, effective.location != NSNotFound else { return false }
        return deleteSectionBreak(range: effective)
    }

    private func deleteSectionBreak(range: NSRange) -> Bool {
        guard let storage = textStorage else { return false }
        if shouldChangeText(in: range, replacementString: "") {
            storage.beginEditing()
            storage.deleteCharacters(in: range)
            storage.endEditing()
            didChangeText()
            undoManager?.setActionName("Delete Section Break")
            return true
        }
        return false
    }

    private func deleteAdjacentPageBreak(isBackward: Bool) -> Bool {
        guard let storage = textStorage, storage.length > 0 else { return false }
        let sel = selectedRange()

        // If the user selected a marker, delete it directly.
        if sel.length > 0 {
            var effective = NSRange(location: NSNotFound, length: 0)
            let hasMarker = storage.attribute(.qpPageBreak, at: sel.location, effectiveRange: &effective) != nil
            if hasMarker && effective.location != NSNotFound {
                return deletePageBreak(range: effective)
            }
            return false
        }

        let cursor = sel.location
        let index = isBackward ? (cursor - 1) : cursor
        guard index >= 0, index < storage.length else { return false }
        var effective = NSRange(location: NSNotFound, length: 0)
        let hasMarker = storage.attribute(.qpPageBreak, at: index, effectiveRange: &effective) != nil
        guard hasMarker, effective.location != NSNotFound else { return false }
        return deletePageBreak(range: effective)
    }

    private func deletePageBreak(range: NSRange) -> Bool {
        guard let storage = textStorage else { return false }
        if shouldChangeText(in: range, replacementString: "") {
            storage.beginEditing()
            storage.deleteCharacters(in: range)
            storage.endEditing()
            didChangeText()
            undoManager?.setActionName("Delete Page Break")
            return true
        }
        return false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

          guard showsParagraphMarks || showsSectionBreaks || showsPageBreaks,
              let layoutManager = layoutManager,
              let textContainer = textContainer,
              let textStorage = textStorage else { return }

        let glyphRange = layoutManager.glyphRange(forBoundingRect: dirtyRect, in: textContainer)
        let textNSString = textStorage.string as NSString
        let origin = textContainerOrigin

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineFragmentRect, usedRect, _, lineGlyphRange, _ in
            let charRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
            guard charRange.length > 0 else { return }

            let lineString = textNSString.substring(with: charRange)
            let emptyLineCharacters = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{00A0}"))
            let isEmptyLine = lineString.trimmingCharacters(in: emptyLineCharacters).isEmpty

            // Find first non-newline character for font lookup
            let fontIndex: Int = {
                let end = NSMaxRange(charRange)
                var idx = charRange.location
                while idx < end {
                    let ch = textNSString.character(at: idx)
                    if ch != 0x0A && ch != 0x0D && ch != 0x2029 && ch != 0x2028 {
                        return idx
                    }
                    idx += 1
                }
                return max(0, min(charRange.location, textStorage.length - 1))
            }()

            let lineFont: NSFont = {
                if isEmptyLine {
                    // For empty lines, use previous paragraph's font
                    let prevIndex = max(0, charRange.location - 1)
                    if prevIndex < textStorage.length,
                       let prevFont = textStorage.attribute(.font, at: prevIndex, effectiveRange: nil) as? NSFont {
                        return prevFont
                    }
                    if let typingFont = self.typingAttributes[.font] as? NSFont {
                        return typingFont
                    }
                }
                return (textStorage.attribute(.font, at: fontIndex, effectiveRange: nil) as? NSFont)
                    ?? self.typingAttributes[.font] as? NSFont
                    ?? self.font
                    ?? NSFont.systemFont(ofSize: 12)
            }()

            let paragraphStyle: NSParagraphStyle = {
                if isEmptyLine,
                   let typingPara = self.typingAttributes[.paragraphStyle] as? NSParagraphStyle {
                    return typingPara
                }
                return (textStorage.attribute(.paragraphStyle, at: fontIndex, effectiveRange: nil) as? NSParagraphStyle)
                    ?? self.defaultParagraphStyle
                    ?? NSParagraphStyle.default
            }()

            // Calculate baseline Y using line fragment rect + glyph location within it
            // location(forGlyphAt:) returns position where Y is baseline from top of line fragment
            // NSString.draw(at:) draws with Y as top of glyph, so subtract ascender to align baselines
            let firstGlyphLocation = layoutManager.location(forGlyphAt: lineGlyphRange.location)
            let baselineY = origin.y + lineFragmentRect.origin.y + firstGlyphLocation.y - lineFont.ascender

            if isEmptyLine && self.showsParagraphMarks {
                // Use firstLineHeadIndent so the pilcrow aligns with where the cursor actually sits.
                let drawX = origin.x + lineFragmentRect.origin.x + paragraphStyle.firstLineHeadIndent
                let drawPoint = NSPoint(x: drawX, y: baselineY)
                (self.paragraphGlyph as NSString).draw(at: drawPoint, withAttributes: [.font: lineFont, .foregroundColor: self.paragraphMarksColor])
            }

            if self.showsSectionBreaks {
                var hasSectionBreak = false
                textStorage.enumerateAttribute(.qpSectionBreak, in: charRange, options: []) { value, _, stop in
                    if value != nil {
                        hasSectionBreak = true
                        stop.pointee = true
                    }
                }
                if hasSectionBreak {
                    let drawX = origin.x + lineFragmentRect.origin.x + paragraphStyle.firstLineHeadIndent
                    let drawPoint = NSPoint(x: drawX, y: baselineY)
                    (self.sectionBreakGlyph as NSString).draw(at: drawPoint, withAttributes: [.font: lineFont, .foregroundColor: self.sectionBreaksColor])
                }
            }

            if self.showsPageBreaks {
                var hasPageBreak = false
                textStorage.enumerateAttribute(.qpPageBreak, in: charRange, options: []) { value, _, stop in
                    if value != nil {
                        hasPageBreak = true
                        stop.pointee = true
                    }
                }
                if hasPageBreak {
                    let drawX = origin.x + lineFragmentRect.origin.x + paragraphStyle.firstLineHeadIndent
                    let drawPoint = NSPoint(x: drawX, y: baselineY)
                    (self.pageBreakLabel as NSString).draw(at: drawPoint, withAttributes: [.font: lineFont, .foregroundColor: self.pageBreaksColor])
                }
            }

            // Check if line is centered (skip space dots for centered text)
            let centeredLine: Bool = {
                let leftInset = usedRect.minX - lineFragmentRect.minX
                let rightInset = lineFragmentRect.maxX - usedRect.maxX
                let symmetry = abs(leftInset - rightInset)
                return usedRect.width > 0 && symmetry < 2 && leftInset > 6
            }()

            let drawSpaceDots = !centeredLine

            // Draw space and tab markers
            for i in charRange.location..<(NSMaxRange(charRange)) {
                let ch = textNSString.character(at: i)

                // Skip newline characters
                if ch == 0x0A || ch == 0x0D || ch == 0x2029 || ch == 0x2028 {
                    continue
                }

                // Tab character
                if ch == 0x09 {
                    let glyphIndex = layoutManager.glyphIndexForCharacter(at: i)
                    let glyphLoc = layoutManager.location(forGlyphAt: glyphIndex)
                    let drawX = origin.x + lineFragmentRect.origin.x + glyphLoc.x
                    let drawY = origin.y + lineFragmentRect.origin.y + glyphLoc.y - lineFont.ascender
                    let drawPoint = NSPoint(x: drawX, y: drawY)
                    if self.showsParagraphMarks {
                        (self.tabGlyph as NSString).draw(at: drawPoint, withAttributes: [.font: lineFont, .foregroundColor: self.paragraphMarksColor])
                    }
                    continue
                }

                // Space characters
                if ch == 0x20 || ch == 0x00A0 || ch == 0x202F {
                    if !drawSpaceDots || !self.showsParagraphMarks { continue }
                    // Skip space dots adjacent to periods (e.g., ellipsis)
                    let prevChar = i > charRange.location ? textNSString.character(at: i - 1) : 0
                    let nextChar = i + 1 < NSMaxRange(charRange) ? textNSString.character(at: i + 1) : 0
                    if prevChar == 0x2E || nextChar == 0x2E { continue }

                    let glyphIndex = layoutManager.glyphIndexForCharacter(at: i)
                    let glyphLoc = layoutManager.location(forGlyphAt: glyphIndex)
                    let attrs = textStorage.attributes(at: i, effectiveRange: nil)
                    let charFont = (attrs[.font] as? NSFont) ?? lineFont

                    // Get actual rendered space width by checking next glyph position
                    let actualSpaceWidth: CGFloat
                    if i + 1 < NSMaxRange(charRange) {
                        let nextGlyphIndex = layoutManager.glyphIndexForCharacter(at: i + 1)
                        let nextGlyphLoc = layoutManager.location(forGlyphAt: nextGlyphIndex)
                        actualSpaceWidth = nextGlyphLoc.x - glyphLoc.x
                    } else {
                        actualSpaceWidth = (" " as NSString).size(withAttributes: [.font: charFont]).width
                    }

                    let dotSize = (self.spaceGlyph as NSString).size(withAttributes: [.font: charFont]).width
                    let drawX = origin.x + lineFragmentRect.origin.x + glyphLoc.x + (actualSpaceWidth - dotSize) / 2
                    let drawY = origin.y + lineFragmentRect.origin.y + glyphLoc.y - charFont.ascender
                    let drawPoint = NSPoint(x: drawX, y: drawY)
                    (self.spaceGlyph as NSString).draw(at: drawPoint, withAttributes: [.font: charFont, .foregroundColor: self.paragraphMarksColor])
                }
            }

            // Draw pilcrow at end of paragraph
            let lastCharIndex = NSMaxRange(charRange) - 1
            if lastCharIndex >= 0, self.showsParagraphMarks {
                let ch = textNSString.character(at: lastCharIndex)
                let endsWithNewline = (ch == 0x0A || ch == 0x0D || ch == 0x2029 || ch == 0x2028)
                let isDocumentEnd = NSMaxRange(charRange) == textStorage.length

                if endsWithNewline || isDocumentEnd {
                    // Find the last visible (non-newline) character to position the pilcrow after it
                    var endCharIndex = NSMaxRange(charRange) - 1
                    while endCharIndex >= charRange.location {
                        let c = textNSString.character(at: endCharIndex)
                        if c != 0x0A && c != 0x0D && c != 0x2029 && c != 0x2028 {
                            break
                        }
                        if endCharIndex == 0 { break }
                        endCharIndex -= 1
                    }

                    // For empty lines (only newline), draw at head indent
                    if endCharIndex < charRange.location || (endCharIndex == charRange.location && {
                        let c = textNSString.character(at: endCharIndex)
                        return c == 0x0A || c == 0x0D || c == 0x2029 || c == 0x2028
                    }()) {
                        let drawX = origin.x + lineFragmentRect.origin.x + paragraphStyle.headIndent
                        let drawPoint = NSPoint(x: drawX, y: baselineY)
                        (self.paragraphGlyph as NSString).draw(at: drawPoint, withAttributes: [.font: lineFont, .foregroundColor: self.paragraphMarksColor])
                    } else {
                        // Draw pilcrow after last visible character
                        let glyphIndex = layoutManager.glyphIndexForCharacter(at: endCharIndex)
                        let glyphLoc = layoutManager.location(forGlyphAt: glyphIndex)
                        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
                        let drawX = origin.x + lineFragmentRect.origin.x + glyphLoc.x + glyphRect.width
                        let drawY = origin.y + lineFragmentRect.origin.y + glyphLoc.y - lineFont.ascender
                        let drawPoint = NSPoint(x: drawX, y: drawY)
                        (self.paragraphGlyph as NSString).draw(at: drawPoint, withAttributes: [.font: lineFont, .foregroundColor: self.paragraphMarksColor])
                    }
                }
            }
        }
    }

    override func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return context == .withinApplication ? .move : .copy
    }

    override func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        super.draggingSession(session, endedAt: screenPoint, operation: operation)
        draggedAttachmentRange = nil
        draggedAttachmentImage = nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Internal drags should use NSTextView's default behavior (selection movement).
        if sender.draggingSource as? NSTextView != nil {
            return super.draggingEntered(sender)
        }

        let op = acceptedDragOperation(for: sender)
        if op != [] {
            window?.makeFirstResponder(self)
        }
        return op
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingSource as? NSTextView != nil {
            return super.draggingUpdated(sender)
        }

        let op = acceptedDragOperation(for: sender)
        guard op != [] else { return [] }

        // Provide a clear insertion caret during dragging so users can see drop placement.
        let dropPoint = convert(sender.draggingLocation, from: nil)
        let insertionIndex = characterIndexForInsertion(at: dropPoint)
        let maxLen = textStorage?.length ?? 0
        let clamped = max(0, min(insertionIndex, maxLen))
        setSelectedRange(NSRange(location: clamped, length: 0))
        return op
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if sender.draggingSource as? NSTextView != nil {
            return super.prepareForDragOperation(sender)
        }
        return acceptedDragOperation(for: sender) != []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if sender.draggingSource as? NSTextView != nil {
            return super.performDragOperation(sender)
        }

        let pasteboard = sender.draggingPasteboard
        let dropPoint = convert(sender.draggingLocation, from: nil)

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            let sourceRange = (sender.draggingSource as? AttachmentClickableTextView)?.draggedAttachmentRange
            if url.isFileURL, let image = NSImage(contentsOf: url) {
                // Defer insertion to the next runloop tick; mutating text storage during the drop
                // can coincide with AppKit/CA commit and result in no-op inserts.
                DispatchQueue.main.async { [weak self] in
                    self?.onImageDrop?(image, url, dropPoint, sourceRange)
                }
                return true
            }

            // Remote URLs can block the main thread if we fetch synchronously. Fetch in the background.
            if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self else { return }
                    let data = try? Data(contentsOf: url)
                    let image = data.flatMap { NSImage(data: $0) }
                    guard let image else { return }
                    DispatchQueue.main.async {
                        self.onImageDrop?(image, url, dropPoint, sourceRange)
                    }
                }
                return true
            }

            // Best-effort for other URL types (may be local-ish but not file://)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                let data = try? Data(contentsOf: url)
                let image = data.flatMap { NSImage(data: $0) }
                guard let image else { return }
                DispatchQueue.main.async {
                    self.onImageDrop?(image, url, dropPoint, sourceRange)
                }
            }
            return true
        }

        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            let sourceRange = (sender.draggingSource as? AttachmentClickableTextView)?.draggedAttachmentRange
            DispatchQueue.main.async { [weak self] in
                self?.onImageDrop?(image, nil, dropPoint, sourceRange)
            }
            return true
        }

        if let string = pasteboard.string(forType: .string),
           let url = URL(string: string) {
            let sourceRange = (sender.draggingSource as? AttachmentClickableTextView)?.draggedAttachmentRange
            let scheme = url.scheme?.lowercased()
            if scheme == "http" || scheme == "https" {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self else { return }
                    let data = try? Data(contentsOf: url)
                    let image = data.flatMap { NSImage(data: $0) }
                    guard let image else { return }
                    DispatchQueue.main.async {
                        self.onImageDrop?(image, url, dropPoint, sourceRange)
                    }
                }
                return true
            }
        }

        if let tiffData = pasteboard.data(forType: .tiff), let image = NSImage(data: tiffData) {
            let sourceRange = (sender.draggingSource as? AttachmentClickableTextView)?.draggedAttachmentRange
            DispatchQueue.main.async { [weak self] in
                self?.onImageDrop?(image, nil, dropPoint, sourceRange)
            }
            return true
        }

        if let pngData = pasteboard.data(forType: .png), let image = NSImage(data: pngData) {
            let sourceRange = (sender.draggingSource as? AttachmentClickableTextView)?.draggedAttachmentRange
            DispatchQueue.main.async { [weak self] in
                self?.onImageDrop?(image, nil, dropPoint, sourceRange)
            }
            return true
        }

        return false
    }
}

private final class ImageResizeSlider: NSSlider {
    var onMouseDown: (() -> Void)?
    var onMouseUp: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        onMouseUp?()
    }
}

private final class QuillPilotResizableAttachmentCell: NSTextAttachmentCell {
    var forcedSize: NSSize

    init(image: NSImage, size: NSSize) {
        self.forcedSize = size
        super.init(imageCell: image)
    }

    required init(coder: NSCoder) {
        self.forcedSize = .zero
        super.init(coder: coder)
    }

    override var cellSize: NSSize {
        forcedSize
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        // Draw the image scaled into the provided frame.
        if let image {
            image.draw(in: cellFrame, from: .zero, operation: .sourceOver, fraction: 1.0, respectFlipped: true, hints: nil)
        } else {
            super.draw(withFrame: cellFrame, in: controlView)
        }
    }
}
fileprivate let quillIndexMarkerRegex: NSRegularExpression? = {
    try? NSRegularExpression(pattern: "\\{\\{index:[^}]+\\}\\}", options: [])
}()

fileprivate func indexMarkerRanges(in targetRange: NSRange, storage: NSTextStorage) -> [NSRange] {
    guard let regex = quillIndexMarkerRegex else { return [] }
    let safeRange = NSIntersectionRange(targetRange, NSRange(location: 0, length: storage.length))
    guard safeRange.length > 0 else { return [] }
    return regex.matches(in: storage.string, options: [], range: safeRange).map { $0.range }
}

fileprivate func subrangesExcluding(_ excluded: [NSRange], from range: NSRange) -> [NSRange] {
    guard range.length > 0 else { return [] }
    if excluded.isEmpty { return [range] }
    let sorted = excluded.sorted { $0.location < $1.location }
    var result: [NSRange] = []
    var cursor = range.location
    let end = range.location + range.length

    for ex in sorted {
        let exStart = max(range.location, ex.location)
        let exEnd = min(end, ex.location + ex.length)
        if exEnd <= cursor { continue }
        if exStart > cursor {
            result.append(NSRange(location: cursor, length: exStart - cursor))
        }
        cursor = max(cursor, exEnd)
        if cursor >= end { break }
    }

    if cursor < end {
        result.append(NSRange(location: cursor, length: end - cursor))
    }
    return result.filter { $0.length > 0 }
}

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
    func authorDidChange(_ author: String)
    func selectionDidChange()
    func suspendAnalysisForLayout()
    func resumeAnalysisAfterLayout()
}

class EditorViewController: NSViewController {

    private let styleAttributeKey = NSAttributedString.Key("QuillStyleName")
    private let baselineOriginalFontKey = NSAttributedString.Key("QPBaselineOriginalFont")

    /// Manages bookmarks and cross-references for this document.
    private(set) var fieldsManager = DocumentFieldsManager()

    /// Manages footnotes and endnotes for this document.
    private(set) var notesManager = NotesManager()

    /// Window controllers for bookmark/cross-reference dialogs
    private var bookmarkWindowController: InsertBookmarkWindowController?
    private var crossReferenceWindowController: InsertCrossReferenceWindowController?

    /// Window controllers for footnote/endnote dialogs
    private var footnoteWindowController: InsertNoteWindowController?
    private var endnoteWindowController: InsertNoteWindowController?

    private let standardMargin: CGFloat = 72
    private let standardIndentStep: CGFloat = 36
    var editorZoom: CGFloat = 1.4  // 140% zoom for better readability on large displays

    private let editorZoomMin: CGFloat = 0.6
    private let editorZoomMax: CGFloat = 2.5
    private let editorZoomStep: CGFloat = 0.1

    func setEditorZoom(_ zoom: CGFloat) {
        let clamped = max(editorZoomMin, min(editorZoomMax, zoom))
        guard abs(clamped - editorZoom) >= 0.001 else { return }
        editorZoom = clamped

        // Update frames first so pagination measurement uses the new container size.
        updateShadowPath()
        updatePageCentering(ensureSelectionVisible: false)
        updatePageLayout()
    }

    func zoomIn() {
        setEditorZoom(editorZoom + editorZoomStep)
    }

    func zoomOut() {
        setEditorZoom(editorZoom - editorZoomStep)
    }

    func zoomActualSize() {
        setEditorZoom(1.0)
    }

    // Horizontal page margins in points (72pt = 1"). These must drive layout in updatePageCentering.
    private var leftPageMargin: CGFloat = 72
    private var rightPageMargin: CGFloat = 72

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
    private var suppressLayoutDuringImageResize: Bool = false
    private var imageResizeEndWorkItem: DispatchWorkItem?

    private var moveImageModeActive: Bool = false
    private var moveImagePending: NSImage?
    private var moveImageSourceRange: NSRange?

    // Format painter state
    private var formatPainterActive: Bool = false
    private var copiedAttributes: [NSAttributedString.Key: Any]?

    @MainActor
    func showStyleDiagnostics(_ sender: Any? = nil) {
        guard let storage = textView.textStorage else {
            showDiagnosticsAlert(title: "Style Diagnostics", message: "No text storage available.")
            return
        }

        let templateName = StyleCatalog.shared.currentTemplateName
        let isScreenplay = StyleCatalog.shared.isScreenplayTemplate

        let selection = textView.selectedRange()

        let paragraphRange: NSRange? = {
            guard storage.length > 0 else { return nil }
            let safeLocation = min(selection.location, max(0, storage.length - 1))
            let full = storage.string as NSString
            return full.paragraphRange(for: NSRange(location: safeLocation, length: 0))
        }()

        let attributeIndex: Int? = {
            guard let range = paragraphRange else { return nil }
            return min(range.location, max(0, storage.length - 1))
        }()

        let styleName: String = {
            if let idx = attributeIndex,
               let name = storage.attribute(styleAttributeKey, at: idx, effectiveRange: nil) as? String {
                return name
            }
            if let typing = textView.typingAttributes[styleAttributeKey] as? String {
                return typing
            }
            return "(none)"
        }()

        let paragraphStyle: NSParagraphStyle = {
            if let idx = attributeIndex,
               let para = storage.attribute(.paragraphStyle, at: idx, effectiveRange: nil) as? NSParagraphStyle {
                return para
            }
            if let para = textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle {
                return para
            }
            return textView.defaultParagraphStyle ?? NSParagraphStyle.default
        }()

        let font: NSFont? = {
            if let idx = attributeIndex {
                return (storage.attribute(.font, at: idx, effectiveRange: nil) as? NSFont) ?? textView.font
            }
            return (textView.typingAttributes[.font] as? NSFont) ?? textView.font
        }()

        let catalogDefinition: StyleDefinition? = {
            guard styleName != "(none)" else { return nil }
            return StyleCatalog.shared.style(named: styleName)
        }()

        let overrideStyleNames = StyleCatalog.shared.overrideStyleNames(for: templateName)
        let isOverridden = (styleName != "(none)") ? StyleCatalog.shared.isStyleOverridden(styleName, inTemplate: templateName) : false

        let containerWidthPoints: CGFloat = {
            guard editorZoom > 0 else { return textView.frame.width }
            return textView.frame.width / editorZoom
        }()

        func inches(_ points: CGFloat) -> String {
            let value = points / 72.0
            return String(format: "%.3f\"", value)
        }

        func points(_ value: CGFloat) -> String {
            String(format: "%.2fpt", value)
        }

        func pageX(_ x: CGFloat) -> String {
            "\(points(x)) (\(inches(x)))"
        }

        let firstLineLeftEdge = leftPageMargin + paragraphStyle.firstLineHeadIndent
        let bodyLeftEdge = leftPageMargin + paragraphStyle.headIndent
        let rightEdgeFromTextViewLeft: CGFloat = {
            if paragraphStyle.tailIndent >= 0 {
                return paragraphStyle.tailIndent
            }
            return containerWidthPoints + paragraphStyle.tailIndent
        }()
        let rightEdge = leftPageMargin + rightEdgeFromTextViewLeft

        var lines: [String] = []
        lines.append("Template: \(templateName)\(isScreenplay ? " (Screenplay)" : "")")
        lines.append("Selection: location=\(selection.location) length=\(selection.length)")
        if let pr = paragraphRange {
            lines.append("Paragraph range: \(pr.location)..<\(pr.location + pr.length)")
        } else {
            lines.append("Paragraph range: (document empty)")
        }
        lines.append("Style tag: \(styleName)\(isOverridden ? " (OVERRIDDEN)" : "")")

        if let font {
            lines.append("Font: \(font.fontName) \(Int(font.pointSize))")
        } else {
            lines.append("Font: (none)")
        }

        lines.append("Zoom: \(String(format: "%.2fx", editorZoom))")
        lines.append("Page width: \(points(pageWidth))  | left margin: \(points(leftPageMargin))  | right margin: \(points(rightPageMargin))")
        lines.append("Text container width: \(points(containerWidthPoints))")

        lines.append("")
        lines.append("ParagraphStyle")
        lines.append("  alignment: \(paragraphStyle.alignment.rawValue)")
        lines.append("  headIndent: \(points(paragraphStyle.headIndent))")
        lines.append("  firstLineHeadIndent: \(points(paragraphStyle.firstLineHeadIndent))")
        lines.append("  tailIndent: \(points(paragraphStyle.tailIndent))")
        lines.append("  lineSpacing: \(points(paragraphStyle.lineSpacing))")
        lines.append("  paragraphSpacingBefore: \(points(paragraphStyle.paragraphSpacingBefore))")
        lines.append("  paragraphSpacing: \(points(paragraphStyle.paragraphSpacing))")
        lines.append("  lineHeightMultiple: \(String(format: "%.2f", paragraphStyle.lineHeightMultiple))")

        lines.append("")
        lines.append("Computed edges (from page left)")
        lines.append("  first line left edge: \(pageX(firstLineLeftEdge))")
        lines.append("  body left edge: \(pageX(bodyLeftEdge))")
        lines.append("  right edge: \(pageX(rightEdge))")
        lines.append("  content width (body): \(pageX(max(0, rightEdge - bodyLeftEdge)))")

        if let def = catalogDefinition {
            lines.append("")
            lines.append("Catalog definition")
            lines.append("  fontName: \(def.fontName)")
            lines.append("  fontSize: \(Int(def.fontSize))")
            lines.append("  isBold: \(def.isBold)")
            lines.append("  isItalic: \(def.isItalic)")
            lines.append("  useSmallCaps: \(def.useSmallCaps)")
            lines.append("  alignment: \(def.alignmentRawValue)")
            lines.append("  headIndent: \(points(def.headIndent))")
            lines.append("  firstLineIndent: \(points(def.firstLineIndent))")
            lines.append("  tailIndent: \(points(def.tailIndent))")
            lines.append("  spacingBefore: \(points(def.spacingBefore))")
            lines.append("  spacingAfter: \(points(def.spacingAfter))")
            lines.append("  lineHeightMultiple: \(String(format: "%.2f", def.lineHeightMultiple))")
        }

        if !overrideStyleNames.isEmpty {
            lines.append("")
            lines.append("Overrides in this template: \(overrideStyleNames.count)")
            lines.append("  \(overrideStyleNames.joined(separator: ", "))")
        }

        showDiagnosticsAlert(
            title: "Style Diagnostics",
            message: lines.joined(separator: "\n"),
            allowCopy: true
        )
    }

    @MainActor
    private func showDiagnosticsAlert(title: String, message: String, allowCopy: Bool = false) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        if allowCopy {
            alert.addButton(withTitle: "Copy")
            alert.addButton(withTitle: "OK")
        } else {
            alert.addButton(withTitle: "OK")
        }

        if let window = view.window {
            alert.beginSheetModal(for: window) { response in
                guard allowCopy else { return }
                if response == .alertFirstButtonReturn {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message, forType: .string)
                }
            }
        } else {
            let response = alert.runModal()
            if allowCopy, response == .alertFirstButtonReturn {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message, forType: .string)
            }
        }
    }

    // When applying composite formatting operations (e.g. a catalog style), suppress sub-step
    // undo labels so the menu shows a single meaningful action name.
    private var suppressUndoActionNames: Bool = false

    // Flag to suppress text change notifications during programmatic edits
    private var suppressTextChangeNotifications: Bool = false

    // Work items to hide temporary column outlines (keyed by table identity)
    private var columnOutlineHideWorkItems: [ObjectIdentifier: DispatchWorkItem] = [:]
    private var outlineFlashWorkItem: DispatchWorkItem?
    private var outlineFlashRange: NSRange?
    private var outlineFlashOverlay: OutlineFlashOverlayView?
    private var persistentColumnOutline: (table: NSTextTable, range: NSRange)?

    private var paragraphMarksVisibleState: Bool = false

    private final class OutlineFlashOverlayView: NSView {
        var rects: [NSRect] = []
        var strokeColor: NSColor = .secondaryLabelColor
        var lineWidth: CGFloat = 1.5
        var cornerRadius: CGFloat = 6

        override var isFlipped: Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            guard !rects.isEmpty else { return }
            strokeColor.setStroke()
            for rect in rects {
                let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
                path.lineWidth = lineWidth
                path.stroke()
            }
        }
    }

    func repairTOCAndIndexFormattingAfterImport(force: Bool = false) {
        guard let storage = textView.textStorage, storage.length > 0 else { return }

        // Match the insertion logic in TOCIndexWindowController.
        let pageTextWidth: CGFloat = textView.textContainer?.size.width ?? (612 - (72 * 2))
        let rightPadding: CGFloat = 10
        let rightTab = pageTextWidth - rightPadding

        let stylesNeedingRightTab: Set<String> = [
            "TOC Entry",
            "TOC Entry Level 1",
            "TOC Entry Level 2",
            "TOC Entry Level 3",
            "Index Entry"
        ]

        DebugLog.log("📚TOC[\(qpTS())] start force=\(force) rightTab=\(rightTab) last=\(String(describing: lastTOCRightTab))")

        // Heuristic: some imports (or retagging) can misclassify TOC/Index entries as other styles
        // (commonly "Author Name"). Detect by structure: separator + trailing page number(s).
        // We also use a capture group to locate the page-number token so we can safely replace
        // the whitespace before it with a single tab (without rewriting the whole paragraph).
        let tocLineRegex: NSRegularExpression? = {
            // Examples:
            // "Chapter One...............\t12"
            // "Chapter One  12" (tab lost on reopen)
            // "Term..................  12, 14"
            // Keep it conservative: require a separator and trailing integer(s).
            try? NSRegularExpression(pattern: "(?:\\t|\\s{2,})\\s*(\\d+(?:\\s*,\\s*\\d+)*)\\s*$", options: [])
        }()

        enum LeaderPattern {
            case toc
            case index

            func make(count: Int) -> String {
                switch self {
                case .toc:
                    return " " + String(repeating: ". ", count: count)
                case .index:
                    return " " + String(repeating: " .", count: count)
                }
            }

            func dotUnitWidth(font: NSFont) -> CGFloat {
                let attrs: [NSAttributedString.Key: Any] = [.font: font]
                switch self {
                case .toc:
                    let dotWidth = ("." as NSString).size(withAttributes: attrs).width
                    let spaceWidth = (" " as NSString).size(withAttributes: attrs).width
                    return dotWidth + spaceWidth
                case .index:
                    return (" ." as NSString).size(withAttributes: attrs).width
                }
            }
        }

        func effectiveFont(at location: Int) -> NSFont {
            (storage.attribute(.font, at: location, effectiveRange: nil) as? NSFont)
                ?? textView.font
                ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        }

        func splitTitleAndExistingLeader(from leftPart: String) -> (title: String, dotCount: Int) {
            // Extract a trailing leader region (spaces + dots) if it looks like a leader run.
            // Be conservative: require at least 3 dots in the trailing region.
            var end = leftPart.endIndex
            while end > leftPart.startIndex, leftPart[leftPart.index(before: end)].isWhitespace {
                end = leftPart.index(before: end)
            }

            var dotCount = 0
            var startOfLeader = end
            var i = end
            while i > leftPart.startIndex {
                let prev = leftPart.index(before: i)
                let ch = leftPart[prev]
                if ch == "." {
                    dotCount += 1
                    startOfLeader = prev
                    i = prev
                    continue
                }
                if ch == " " {
                    startOfLeader = prev
                    i = prev
                    continue
                }
                break
            }

            if dotCount >= 3 {
                let titlePart = String(leftPart[..<startOfLeader]).trimmingCharacters(in: .whitespacesAndNewlines)
                return (titlePart, dotCount)
            }

            return (leftPart.trimmingCharacters(in: .whitespacesAndNewlines), 0)
        }

        func computeNeededLeaderDots(
            title: String,
            pageList: String,
            font: NSFont,
            leftIndent: CGFloat,
            rightTab: CGFloat,
            pattern: LeaderPattern
        ) -> Int {
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let titleWidth = (title as NSString).size(withAttributes: attrs).width
            let pageWidth = (pageList as NSString).size(withAttributes: attrs).width

            switch pattern {
            case .toc:
                let spaceWidth = (" " as NSString).size(withAttributes: attrs).width
                let dotSpaceWidth = pattern.dotUnitWidth(font: font)
                let availableForDots = max(0, rightTab - leftIndent - titleWidth - pageWidth - (spaceWidth * 4))
                return max(3, Int(floor(availableForDots / max(1, dotSpaceWidth))))
            case .index:
                let dotWidth = pattern.dotUnitWidth(font: font)
                let availableWidth = max(0, rightTab - leftIndent - titleWidth - pageWidth - 20)
                return max(3, Int(floor(availableWidth / max(1, dotWidth))))
            }
        }

        func classifyTOCOrIndex(from paragraph: String, paragraphStyle: NSParagraphStyle) -> String? {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let regex = tocLineRegex else { return nil }
            let range = NSRange(location: 0, length: (trimmed as NSString).length)
            guard regex.firstMatch(in: trimmed, options: [], range: range) != nil else { return nil }

            // Index entries are usually indented; prefer that signal over TOC.
            let isIndented = (paragraphStyle.headIndent > 10) || (paragraphStyle.firstLineHeadIndent > 10)
            if isIndented {
                return "Index Entry"
            }

            // If it looks like multiple page refs, treat as Index Entry; otherwise TOC Entry.
            if let last = trimmed.split(separator: "\t").last, last.contains(",") {
                return "Index Entry"
            }
            return "TOC Entry"
        }

        func paragraphHasRightTabStop(_ style: NSParagraphStyle, expectedRightTab: CGFloat) -> Bool {
            for tab in style.tabStops {
                // NSTextTab's location is the key; alignment should be right.
                if tab.alignment == .right && abs(tab.location - expectedRightTab) < 0.75 {
                    return true
                }
            }
            return false
        }

        // If we've already applied the same right-tab location, we still need to re-run the repair
        // when formatting drifts after reloads (tab stops lost / whitespace replaces tabs).
        if !force, let last = lastTOCRightTab, abs(last - rightTab) < 0.5 {
            let fullString = storage.string as NSString
            var location = 0
            var scanned = 0
            let maxParagraphsToScan = 6000
            var foundRepairCandidate = false
            var breakReason: String = ""

            while location < fullString.length && scanned < maxParagraphsToScan {
                let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
                guard paragraphRange.length > 0 else { break }
                scanned += 1

                let existingStyleName = storage.attribute(styleAttributeKey, at: paragraphRange.location, effectiveRange: nil) as? String
                let paragraphText = fullString.substring(with: paragraphRange)
                let existingParagraphStyle = (storage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle) ?? NSParagraphStyle.default
                let inferredTOCStyle = classifyTOCOrIndex(from: paragraphText, paragraphStyle: existingParagraphStyle)
                let shouldInspect = (existingStyleName != nil && stylesNeedingRightTab.contains(existingStyleName!)) || inferredTOCStyle != nil

                if shouldInspect {
                    // If a line looks like a TOC/Index entry but lacks the correct style tag,
                    // we MUST repair even when tabs/tabstops look fine. Otherwise later style
                    // passes can mis-tag it as a heading, and the outline will navigate to the
                    // TOC entry (e.g. "Index .... 197") instead of the real Index section.
                    if let inferred = inferredTOCStyle {
                        if existingStyleName == nil || !stylesNeedingRightTab.contains(existingStyleName!) {
                            foundRepairCandidate = true
                            breakReason = "missingStyleTag(\(inferred))"
                            break
                        }
                    }

                    // If tab stop is missing, or the paragraph lacks a literal tab (common after reopen), we need repair.
                    if !paragraphHasRightTabStop(existingParagraphStyle, expectedRightTab: rightTab) {
                        foundRepairCandidate = true
                        breakReason = "missingRightTabStop"
                        break
                    }
                    if !paragraphText.contains("\t"), inferredTOCStyle != nil {
                        foundRepairCandidate = true
                        breakReason = "missingLiteralTab"
                        break
                    }

                    // Leader dots can drift even when tab stop survives (geometry/zoom changes).
                    // Detect mismatch between existing dot-run length and the newly required length.
                    if let regex = tocLineRegex,
                       let match = regex.firstMatch(in: paragraphText, options: [], range: NSRange(location: 0, length: (paragraphText as NSString).length)) {
                        let pageRange = match.range(at: 1)
                        if pageRange.location != NSNotFound {
                            let pageList = (paragraphText as NSString).substring(with: pageRange)
                            let font = effectiveFont(at: paragraphRange.location)
                            let leftIndent = max(existingParagraphStyle.firstLineHeadIndent, existingParagraphStyle.headIndent)
                            let isIndex = (existingStyleName == "Index Entry") || (inferredTOCStyle == "Index Entry")
                            let pattern: LeaderPattern = isIndex ? .index : .toc

                            // Determine left-part (title + existing dots) by splitting at the last tab if present.
                            let line = paragraphText.trimmingCharacters(in: .newlines)
                            let leftPart: String
                            if let tabIdx = line.lastIndex(of: "\t") {
                                leftPart = String(line[..<tabIdx])
                            } else {
                                leftPart = String(line[..<line.index(line.startIndex, offsetBy: pageRange.location)])
                            }
                            let parts = splitTitleAndExistingLeader(from: leftPart)
                            if !parts.title.isEmpty {
                                let neededDots = computeNeededLeaderDots(
                                    title: parts.title,
                                    pageList: pageList,
                                    font: font,
                                    leftIndent: leftIndent,
                                    rightTab: rightTab,
                                    pattern: pattern
                                )
                                if parts.dotCount > 0, abs(parts.dotCount - neededDots) >= 2 {
                                    foundRepairCandidate = true
                                    breakReason = "leaderDotsMismatch"
                                    break
                                }
                            }
                        }
                    }
                }

                location = NSMaxRange(paragraphRange)
            }

            // If we scanned the whole region without finding a repair candidate, skip work.
            if !foundRepairCandidate {
                DebugLog.log("📚TOC[\(qpTS())] skip (no drift) scanned=\(scanned) max=\(maxParagraphsToScan)")
                return
            }
            DebugLog.log("📚TOC[\(qpTS())] drift detected reason=\(breakReason) scanned=\(scanned)")
            // Otherwise: fall through and repair.
        }

        suppressTextChangeNotifications = true
        defer { suppressTextChangeNotifications = false }

        // IMPORTANT: Never mutate the text storage while using a captured `NSString` snapshot
        // for paragraph iteration. It causes range drift and can corrupt downstream scanning.
        // We first collect repair actions, then apply them (tab insertions are applied in reverse).
        struct ParagraphRepair {
            let paragraphRange: NSRange
            let inferredStyleName: String?
            let whitespaceBeforePageNumberRange: NSRange?
            let lineReplaceRange: NSRange?
            let lineReplacement: NSAttributedString?
        }

        let fullString = storage.string as NSString
        var repairs: [ParagraphRepair] = []
        repairs.reserveCapacity(64)

        func newlineSuffixLength(_ paragraph: NSString) -> Int {
            let len = paragraph.length
            guard len > 0 else { return 0 }
            if len >= 2 {
                let lastTwo = paragraph.substring(with: NSRange(location: len - 2, length: 2))
                if lastTwo == "\r\n" { return 2 }
            }
            let lastOne = paragraph.substring(with: NSRange(location: len - 1, length: 1))
            if lastOne == "\n" || lastOne == "\r" { return 1 }
            return 0
        }

        func computeWhitespaceBeforePageNumberRange(paragraphText: NSString, regex: NSRegularExpression) -> NSRange? {
            // Operate on the paragraph without its trailing newline so offsets match storage.
            let suffixLen = newlineSuffixLength(paragraphText)
            let lineLen = max(0, paragraphText.length - suffixLen)
            guard lineLen > 0 else { return nil }

            let lineRange = NSRange(location: 0, length: lineLen)
            let line = paragraphText.substring(with: lineRange) as NSString
            if (line as String).contains("\t") { return nil }

            let matchRange = NSRange(location: 0, length: line.length)
            guard let match = regex.firstMatch(in: line as String, options: [], range: matchRange) else { return nil }
            let digitsRange = match.range(at: 1)
            guard digitsRange.location != NSNotFound, digitsRange.location > 0 else { return nil }

            // Walk backward from the first digit to collapse the immediate whitespace run into a tab.
            var wsStart = digitsRange.location
            while wsStart > 0 {
                let charRange = NSRange(location: wsStart - 1, length: 1)
                let ch = line.substring(with: charRange)
                if ch == " " || ch == "\t" {
                    wsStart -= 1
                } else {
                    break
                }
            }

            guard wsStart < digitsRange.location else { return nil }
            return NSRange(location: wsStart, length: digitsRange.location - wsStart)
        }

        var location = 0
        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
            guard paragraphRange.length > 0 else { break }

            let existingStyleName = storage.attribute(styleAttributeKey, at: paragraphRange.location, effectiveRange: nil) as? String
            let paragraphText = fullString.substring(with: paragraphRange)
            let existingParagraphStyle = (storage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle) ?? NSParagraphStyle.default

            let inferredTOCStyle = classifyTOCOrIndex(from: paragraphText, paragraphStyle: existingParagraphStyle)
            let shouldRepair = (existingStyleName != nil && stylesNeedingRightTab.contains(existingStyleName!)) || inferredTOCStyle != nil

            if shouldRepair {
                let paragraphNSString = paragraphText as NSString
                let whitespaceRange: NSRange?
                if let regex = tocLineRegex {
                    whitespaceRange = computeWhitespaceBeforePageNumberRange(paragraphText: paragraphNSString, regex: regex)
                } else {
                    whitespaceRange = nil
                }

                // Optionally recompute leader dots and rewrite the whole line (preserving attributes).
                var lineReplaceRange: NSRange? = nil
                var lineReplacement: NSAttributedString? = nil
                if let regex = tocLineRegex {
                    let paraLen = paragraphNSString.length
                    let suffixLen = newlineSuffixLength(paragraphNSString)
                    let lineLen = max(0, paraLen - suffixLen)
                    if lineLen > 0 {
                        let lineRange = NSRange(location: 0, length: lineLen)
                        let line = paragraphNSString.substring(with: lineRange)
                        if let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: (line as NSString).length)) {
                            let pageRange = match.range(at: 1)
                            if pageRange.location != NSNotFound {
                                let pageList = (line as NSString).substring(with: pageRange)

                                let font = effectiveFont(at: paragraphRange.location)
                                let leftIndent = max(existingParagraphStyle.firstLineHeadIndent, existingParagraphStyle.headIndent)
                                let isIndex = (existingStyleName == "Index Entry") || (inferredTOCStyle == "Index Entry")
                                let pattern: LeaderPattern = isIndex ? .index : .toc

                                let leftPart: String
                                if let tabIdx = line.lastIndex(of: "\t") {
                                    leftPart = String(line[..<tabIdx])
                                } else if let ws = whitespaceRange {
                                    leftPart = String((line as NSString).substring(with: NSRange(location: 0, length: ws.location)))
                                } else {
                                    leftPart = String(line)
                                }

                                let parts = splitTitleAndExistingLeader(from: leftPart)
                                if !parts.title.isEmpty {
                                    let neededDots = computeNeededLeaderDots(
                                        title: parts.title,
                                        pageList: pageList,
                                        font: font,
                                        leftIndent: leftIndent,
                                        rightTab: rightTab,
                                        pattern: pattern
                                    )

                                    // Rewrite if leader is missing or materially mismatched.
                                    if parts.dotCount == 0 || abs(parts.dotCount - neededDots) >= 2 {
                                        let rebuilt = "\(parts.title)\(pattern.make(count: neededDots))\t\(pageList)"
                                        let baseAttrs = storage.attributes(at: paragraphRange.location, effectiveRange: nil)
                                        lineReplaceRange = NSRange(location: paragraphRange.location, length: lineLen)
                                        lineReplacement = NSAttributedString(string: rebuilt, attributes: baseAttrs)
                                    }
                                }
                            }
                        }
                    }
                }

                let absoluteWhitespaceRange = whitespaceRange.map { NSRange(location: paragraphRange.location + $0.location, length: $0.length) }
                repairs.append(ParagraphRepair(
                    paragraphRange: paragraphRange,
                    inferredStyleName: inferredTOCStyle,
                    whitespaceBeforePageNumberRange: absoluteWhitespaceRange,
                    lineReplaceRange: lineReplaceRange,
                    lineReplacement: lineReplacement
                ))
            }

            location = NSMaxRange(paragraphRange)
        }

        guard !repairs.isEmpty else {
            lastTOCRightTab = rightTab
            DebugLog.log("📚TOC[\(qpTS())] no matching paragraphs; done")
            return
        }

        storage.beginEditing()
        defer { storage.endEditing() }

        // Apply paragraph-style + style-tag repairs first (no length changes).
        for repair in repairs {
            let existing = (storage.attribute(.paragraphStyle, at: repair.paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle) ?? NSParagraphStyle.default
            let merged = (existing.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            merged.lineBreakMode = .byClipping
            merged.tabStops = [NSTextTab(textAlignment: .right, location: rightTab, options: [:])]
            storage.addAttribute(.paragraphStyle, value: merged.copy() as! NSParagraphStyle, range: repair.paragraphRange)

            if let inferred = repair.inferredStyleName {
                storage.addAttribute(styleAttributeKey, value: inferred, range: repair.paragraphRange)
            }
        }

        // Apply whitespace→tab substitutions in reverse order (these change length).
        var tabInsertions = 0
        for repair in repairs.reversed() {
            if let replaceRange = repair.lineReplaceRange, let replacement = repair.lineReplacement {
                if replaceRange.location + replaceRange.length <= storage.length {
                    storage.replaceCharacters(in: replaceRange, with: replacement)
                }
                // Whole-line rewrite already includes the tab; skip whitespace replacement.
                continue
            }
            guard let wsRange = repair.whitespaceBeforePageNumberRange else { continue }
            // Guard against drift (e.g., if another operation already fixed it).
            if wsRange.location + wsRange.length <= storage.length {
                storage.replaceCharacters(in: wsRange, with: "\t")
                tabInsertions += 1
            }
        }

        lastTOCRightTab = rightTab
        DebugLog.log("📚TOC[\(qpTS())] applied paragraphRepairs=\(repairs.count) tabInsertions=\(tabInsertions) rightTab=\(rightTab)")
    }

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
    private var lastTOCRightTab: CGFloat?
    private var pendingNavigationScroll = false
    private var pendingNavigationTarget: Int?
    private var navigationWorkItem: DispatchWorkItem?
    private var navigationScrollSuppressionUntil: CFAbsoluteTime = 0

    @inline(__always)
    private func qpTS() -> String {
        String(format: "%.3f", CFAbsoluteTimeGetCurrent())
    }

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
    private var headerFooterDecorationViews: [NSView] = []
    private var pendingListIndentOnReturn = false
    private var pendingListIndentTargetLevel: Int?

    // Manuscript metadata
    var manuscriptTitle: String = "Untitled"
    var manuscriptAuthor: String = "Author Name"

    // Header/Footer configuration
    var showHeaders: Bool = false
    var showFooters: Bool = false
    var showPageNumbers: Bool = true
    var hidePageNumberOnFirstPage: Bool = true
    var centerPageNumbers: Bool = false
    var facingPageNumbers: Bool = false
    var headerText: String = "" // Empty means use author/title
    var headerTextRight: String = "" // Optional right-side header text
    var footerText: String = "" // Optional footer text
    var footerTextRight: String = "" // Optional right-side footer text

    weak var delegate: EditorViewControllerDelegate?

    override func loadView() {
        view = NSView()
        // Root view can be layer-backed for theming (content height is bounded by window)
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextView()

        // Initialize fields manager with text storage
        fieldsManager.textStorage = textView.textStorage

        // Initialize notes manager with text storage
        notesManager.textStorage = textView.textStorage
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // When reopening/importing, the scroll view’s final width can settle after content is set.
        // Re-center after the view is in a window so the page doesn’t appear left-justified.
        DispatchQueue.main.async { [weak self] in
            self?.updatePageCentering(ensureSelectionVisible: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.updatePageCentering(ensureSelectionVisible: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.updatePageCentering(ensureSelectionVisible: false)
        }
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
        // Start with a reasonable initial size (10 pages) - will expand/shrink as needed
        let initialPages = 10
        let initialHeight = pageHeight * editorZoom * CGFloat(initialPages)
        let initialPageContainer = PageContainerView(frame: NSRect(x: 0, y: 0, width: 612 * editorZoom, height: initialHeight))
        initialPageContainer.pageHeight = pageHeight * editorZoom
        initialPageContainer.pageGap = 20
        initialPageContainer.numPages = initialPages
        pageContainer = initialPageContainer

        // Create text view. We manage its height via our page container sizing logic
        // so it stays aligned with drawn page backgrounds.
        let textFrame = pageContainer.bounds.insetBy(dx: standardMargin * editorZoom, dy: standardMargin * editorZoom)
        let clickable = AttachmentClickableTextView(frame: textFrame)
        clickable.onToggleBulletedList = { [weak self] in
            self?.toggleBulletedList()
        }
        clickable.onToggleNumberedList = { [weak self] in
            self?.toggleNumberedList()
        }
        clickable.onRestartNumbering = { [weak self] in
            self?.restartNumberingAtCursor()
        }
        clickable.onMouseDownInTextView = { [weak self, weak clickable] point in
            guard let self, let textView = clickable else { return }
            guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return }

            if self.moveImageModeActive, let image = self.moveImagePending {
                let insertionPoint = self.insertionIndex(for: point)
                let sourceRange = self.moveImageSourceRange
                self.moveImageModeActive = false
                self.moveImagePending = nil
                self.moveImageSourceRange = nil
                textView.setSelectedRange(NSRange(location: insertionPoint, length: 0))
                self.insertImage(image, sourceURL: nil, insertionPoint: insertionPoint, sourceRange: sourceRange)
                return
            }

            // Hit-test the clicked point to a character index, then check for an attachment at that index.
            let p = NSPoint(x: point.x - textView.textContainerOrigin.x, y: point.y - textView.textContainerOrigin.y)
            var fraction: CGFloat = 0
            let index = layoutManager.characterIndex(for: p, in: textContainer, fractionOfDistanceBetweenInsertionPoints: &fraction)
            guard let attachmentRange = self.imageAttachmentRange(at: index) else { return }

            // Select the attachment itself so selection-change based logic works.
            textView.setSelectedRange(attachmentRange)
            self.lastImageRange = attachmentRange
            self.showImageControlsIfNeeded()
        }
        clickable.onImageDrop = { [weak self, weak clickable] image, url, point, sourceRange in
            guard let self, let textView = clickable else { return }
            let insertionPoint = self.insertionIndex(for: point)
            textView.setSelectedRange(NSRange(location: insertionPoint, length: 0))
            self.insertImage(image, sourceURL: url, insertionPoint: insertionPoint, sourceRange: sourceRange)
        }
        textView = clickable
        applyParagraphMarksVisibility()
        textView.minSize = NSSize(width: textFrame.width, height: textFrame.height)
        textView.maxSize = NSSize(width: textFrame.width, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.autoresizingMask = []  // Remove autoresizing to prevent constraint conflicts
        textView.textContainer?.containerSize = NSSize(width: textFrame.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        // Remove the default internal padding so ruler marks match actual text position.
        textView.textContainer?.lineFragmentPadding = 0
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

        // Enable drag and drop.
        // IMPORTANT: Include rich-text types so internal drags (attachments are typically RTFD)
        // still work, especially into tables.
        textView.registerForDraggedTypes([
            .rtfd,
            .rtf,
            .string,
            .fileURL,
            .URL,
            .tiff,
            .png
        ])

        textView.font = NSFont(name: "Times New Roman", size: 12) ?? NSFont.systemFont(ofSize: 12)

        // Ensure undo works predictably (one step per Cmd-Z)
        textView.allowsUndo = true
        if let um = textView.undoManager {
            um.groupsByEvent = true
            um.levelsOfUndo = 10000
        }

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
        applyDefaultTypingAttributes()
        updateShadowPath()
        updatePageCentering()
    }

    private func insertionIndex(for dropPoint: NSPoint) -> Int {
        let index = textView.characterIndexForInsertion(at: dropPoint)
        let maxLen = textView.textStorage?.length ?? 0
        return max(0, min(index, maxLen))
    }

    func getTextContent() -> String? {
        return textView.string
    }

    /// Update the page container to accommodate all content with proper pagination
    func updatePageLayout() {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            debugLog("📄 Pagination: missing layoutManager/textContainer; forcing 1 page")
            setPageCount(1)
            return
        }

        let textLength = textView.textStorage?.length ?? 0
        debugLog("📄 Pagination.updatePageLayout: len=\(textLength) zoom=\(editorZoom) mainThread=\(Thread.isMainThread)")

        // Force layout so usedRect reflects real rendered height (important for rich imports like RTF).
        // `ensureLayout(for:)` can still under-measure if the text system hasn't finished laying out
        // the full range yet, so for moderately-sized documents we ensure layout for the full range.
        if let storage = textView.textStorage, storage.length > 0, storage.length <= 250_000 {
            layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: storage.length))
        } else {
            layoutManager.ensureLayout(for: textContainer)
        }

        // Update page-break spacers so usedRect reflects forced page boundaries.
        updatePageBreakSpacerHeights(layoutManager: layoutManager, textContainer: textContainer)
        layoutManager.ensureLayout(for: textContainer)

        let usedRect = layoutManager.usedRect(for: textContainer)
        let usedHeight = max(0, usedRect.height)
        let scaledPageHeight = pageHeight * editorZoom
        let gap: CGFloat = 20
        let margin = standardMargin * editorZoom

        // We need enough total container height so the text frame can contain `usedHeight`.
        // textFrameHeight = totalHeight - 2*margin
        // totalHeight(pages) = pages*(scaledPageHeight + gap) - gap
        // Solve for minimal pages.
        let denominator = max(1, scaledPageHeight + gap)
        let numerator = usedHeight + (margin * 2) + gap
        let neededPages = max(1, Int(ceil(numerator / denominator)))

        debugLog(
            "📄 Pagination.measure: usedRect=\(NSStringFromRect(usedRect)) usedH=\(usedHeight.rounded()) scaledPageH=\(scaledPageHeight.rounded()) neededPages=\(neededPages)"
        )

        // During an explicit navigation, don't allow late/partial layout to shrink the page
        // container (it clamps scroll range and makes the user click repeatedly).
        if let pageContainerView = pageContainer as? PageContainerView {
            let now = CFAbsoluteTimeGetCurrent()
            let suppressShrink = pendingNavigationScroll || now < navigationScrollSuppressionUntil
            if suppressShrink {
                let clampedPages = max(pageContainerView.numPages, neededPages)
                if clampedPages != neededPages {
                    debugLog("📄 Pagination: suppress shrink needed=\(neededPages) keeping=\(clampedPages)")
                }
                setPageCount(clampedPages)
            } else {
                setPageCount(neededPages)
            }
        } else {
            setPageCount(neededPages)
        }
    }

    private func currentTextInsetsForPagination() -> (top: CGFloat, bottom: CGFloat) {
        // Must mirror the header/footer exclusion sizing used in updatePageCentering().
        let headerClearance = showHeaders ? (headerHeight * editorZoom * 0.25) : 0
        let footerClearance = showFooters ? (footerHeight * editorZoom * 0.5) : 0
        let textInsetTop = (standardMargin * editorZoom) + headerClearance
        let textInsetBottom = (standardMargin * editorZoom) + footerClearance
        return (textInsetTop, textInsetBottom)
    }

    private var isUpdatingPageBreakSpacers = false

    private func updatePageBreakSpacerHeights(layoutManager: NSLayoutManager, textContainer: NSTextContainer) {
        // Page breaks use fixed-height spacers set at insertion time.
        // Dynamic resizing creates feedback loops that cause text to disappear or runaway pagination.
        // This function is kept as a no-op stub to avoid breaking callers.
    }

    private func ensurePageCountForCharacterLocation(_ location: Int) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let pageContainerView = pageContainer as? PageContainerView,
              let storage = textView.textStorage,
              storage.length > 0 else { return }

        let clamped = min(max(0, location), max(0, storage.length - 1))
        let ensureRange = NSRange(location: clamped, length: 1)
        layoutManager.ensureLayout(forCharacterRange: ensureRange)

        let glyphRange = layoutManager.glyphRange(forCharacterRange: ensureRange, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        // If the text system hasn't fully laid out far-down content yet (common right after DOCX/RTF import),
        // boundingRect can be empty which would incorrectly keep the page container at 1 page.
        // Force a broader layout pass and retry so late-document headings (e.g. "Index") can be navigated to immediately.
        if rect.isEmpty || rect.maxY <= 1 {
            layoutManager.ensureLayout(for: textContainer)
            rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            if rect.isEmpty || rect.maxY <= 1 {
                updatePageLayout()
                layoutManager.ensureLayout(forCharacterRange: ensureRange)
                rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            }
        }

        let requiredHeight = max(0, rect.maxY)

        let scaledPageHeight = pageHeight * editorZoom
        let gap: CGFloat = 20
        let margin = standardMargin * editorZoom
        let denominator = max(1, scaledPageHeight + gap)
        let numerator = requiredHeight + (margin * 2) + gap
        let neededPages = max(1, Int(ceil(numerator / denominator)))

        if neededPages > pageContainerView.numPages {
            debugLog("📄 Pagination.ensureForLoc: loc=\(clamped) rectMaxY=\(requiredHeight.rounded()) pages \(pageContainerView.numPages)→\(neededPages)")
            setPageCount(neededPages)
        }
    }

    /// Set exact page count and resize containers
    private func setPageCount(_ neededPages: Int) {
        guard let pageContainerView = pageContainer as? PageContainerView else { return }

        let scaledPageHeight = pageHeight * editorZoom
        let desiredGap: CGFloat = 20
        let totalHeight = CGFloat(neededPages) * (scaledPageHeight + desiredGap) - desiredGap
        let containerWidth = pageWidth * editorZoom

        // If nothing materially changes, skip work.
        let heightMatches = abs(pageContainer.frame.height - totalHeight) < 0.5
        let widthMatches = abs(pageContainer.frame.width - containerWidth) < 0.5
        let pagesMatch = pageContainerView.numPages == neededPages
        let pageHeightMatches = abs(pageContainerView.pageHeight - scaledPageHeight) < 0.5
        let gapMatches = abs(pageContainerView.pageGap - desiredGap) < 0.5
        if pagesMatch && pageHeightMatches && gapMatches && heightMatches && widthMatches {
            debugLog("📄 Pagination.setPageCount: no-op (pages=\(neededPages), frame=\(NSStringFromRect(pageContainer.frame)))")
            return
        }

        debugLog(
            "📄 Pagination.setPageCount: pages \(pageContainerView.numPages)→\(neededPages) containerSize \(pageContainer.frame.size)→(\(containerWidth.rounded()), \(totalHeight.rounded()))"
        )

        pageContainerView.numPages = neededPages
        pageContainerView.pageHeight = scaledPageHeight
        pageContainerView.pageGap = desiredGap
        pageContainer.frame = NSRect(x: 0, y: 0, width: containerWidth, height: totalHeight)

        let textFrame = NSRect(
            x: standardMargin * editorZoom,
            y: standardMargin * editorZoom,
            width: containerWidth - (standardMargin * editorZoom * 2),
            height: totalHeight - (standardMargin * editorZoom * 2)
        )
        textView.frame = textFrame
        textView.textContainer?.containerSize = NSSize(width: textFrame.width, height: CGFloat.greatestFiniteMagnitude)
        // Keep internal padding consistent when resizing.
        textView.textContainer?.lineFragmentPadding = 0

        documentView.frame = NSRect(x: 0, y: 0, width: containerWidth, height: totalHeight)
        pageContainer.needsDisplay = true
        updatePageCentering()

        // updatePageCentering() can change the effective text geometry (frames + exclusion paths),
        // so we must recompute page-break spacer heights afterwards to ensure they land on the
        // next page boundary in the final layout.
        if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
            updatePageBreakSpacerHeights(layoutManager: layoutManager, textContainer: textContainer)
            layoutManager.ensureLayout(for: textContainer)
        }

        debugLog(
            "📄 Pagination.frames: pageContainer=\(NSStringFromRect(pageContainer.frame)) textView=\(NSStringFromRect(textView.frame)) documentView=\(NSStringFromRect(documentView.frame))"
        )
    }

    // MARK: - Search and Replace

    /// Find all occurrences of a search string in the document
    /// - Parameters:
    ///   - searchText: The text to search for
    ///   - caseSensitive: Whether the search should be case sensitive
    ///   - wholeWords: Whether to match whole words only
    func findAll(_ searchText: String, caseSensitive: Bool = false, wholeWords: Bool = false) -> [NSRange] {
        guard !searchText.isEmpty else { return [] }

        let nsText = textView.string as NSString
        let textLength = nsText.length
        var options: String.CompareOptions = []

        if !caseSensitive {
            options.insert(.caseInsensitive)
        }

        var ranges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: textLength)

        while searchRange.location < textLength {
            let foundRange = nsText.range(of: searchText, options: options, range: searchRange)

            if foundRange.location == NSNotFound {
                break
            }

            if !wholeWords || isWholeWordMatch(foundRange, in: nsText) {
                ranges.append(foundRange)
            }

            let nextLocation = foundRange.location + foundRange.length
            searchRange.location = nextLocation
            searchRange.length = max(0, textLength - nextLocation)
        }

        return ranges
    }

    private func isWholeWordMatch(_ range: NSRange, in text: NSString) -> Bool {
        let wordChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))

        if range.location > 0 {
            let beforeChar = text.character(at: range.location - 1)
            if let scalar = UnicodeScalar(beforeChar), wordChars.contains(scalar) {
                return false
            }
        }

        let afterIndex = range.location + range.length
        if afterIndex < text.length {
            let afterChar = text.character(at: afterIndex)
            if let scalar = UnicodeScalar(afterChar), wordChars.contains(scalar) {
                return false
            }
        }

        return true
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

        let nsText = textView.string as NSString
        let textLength = nsText.length
        let currentRange = textView.selectedRange()
        var options: String.CompareOptions = forward ? [] : .backwards

        if !caseSensitive {
            options.insert(.caseInsensitive)
        }

        func findMatch(in range: NSRange) -> NSRange? {
            var searchRange = range
            while searchRange.length > 0 {
                let foundRange = nsText.range(of: searchText, options: options, range: searchRange)
                if foundRange.location == NSNotFound {
                    return nil
                }

                if !wholeWords || isWholeWordMatch(foundRange, in: nsText) {
                    return foundRange
                }

                if options.contains(.backwards) {
                    let newLength = foundRange.location
                    searchRange = NSRange(location: 0, length: max(0, newLength))
                } else {
                    let nextLocation = foundRange.location + foundRange.length
                    searchRange = NSRange(location: nextLocation, length: max(0, textLength - nextLocation))
                }
            }
            return nil
        }

        let searchStart = forward ? (currentRange.location + currentRange.length) : 0
        let searchLength = forward ? max(0, textLength - searchStart) : currentRange.location
        let primaryRange = NSRange(location: searchStart, length: searchLength)

        if let foundRange = findMatch(in: primaryRange) {
            textView.setSelectedRange(foundRange)
            textView.scrollRangeToVisible(foundRange)
            return true
        }

        // Wrap around if nothing found
        if forward && searchStart > 0 {
            let wrapRange = NSRange(location: 0, length: min(textLength, currentRange.location))
            if let wrappedRange = findMatch(in: wrapRange) {
                textView.setSelectedRange(wrappedRange)
                textView.scrollRangeToVisible(wrappedRange)
                return true
            }
        } else if !forward {
            let wrapStart = currentRange.location + currentRange.length
            let wrapLength = max(0, textLength - wrapStart)
            let wrapRange = NSRange(location: wrapStart, length: wrapLength)
            if let wrappedRange = findMatch(in: wrapRange) {
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

        guard textView.shouldChangeText(in: selectedRange, replacementString: nil) else { return }

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

        textView.didChangeText()
        textView.undoManager?.setActionName("Bold")
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

        guard textView.shouldChangeText(in: selectedRange, replacementString: nil) else { return }

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

        textView.didChangeText()
        textView.undoManager?.setActionName("Italic")
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

        guard textView.shouldChangeText(in: selectedRange, replacementString: nil) else { return }

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

        textView.didChangeText()
        textView.undoManager?.setActionName("Underline")
    }

    func toggleStrikethrough() {
        guard let textStorage = textView.textStorage else { return }
        guard let selectedRange = textView.selectedRanges.first?.rangeValue else { return }

        if selectedRange.length == 0 {
            let current = (textView.typingAttributes[.strikethroughStyle] as? Int) ?? 0
            let next = current == 0 ? NSUnderlineStyle.single.rawValue : 0
            textView.typingAttributes[.strikethroughStyle] = next == 0 ? nil : next
            if next == 0 {
                textView.typingAttributes[.strikethroughColor] = nil
            }
            return
        }

        guard textView.shouldChangeText(in: selectedRange, replacementString: nil) else { return }

        var hasStrikethrough = false
        textStorage.enumerateAttribute(.strikethroughStyle, in: selectedRange, options: []) { value, _, stop in
            if let intValue = value as? Int, intValue != 0 {
                hasStrikethrough = true
                stop.pointee = true
            }
        }

        textStorage.beginEditing()
        if hasStrikethrough {
            textStorage.removeAttribute(.strikethroughStyle, range: selectedRange)
            textStorage.removeAttribute(.strikethroughColor, range: selectedRange)
        } else {
            textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
        }
        textStorage.endEditing()

        textView.didChangeText()
        textView.undoManager?.setActionName("Strikethrough")
    }

    @discardableResult
    func toggleParagraphMarks() -> Bool {
        paragraphMarksVisibleState.toggle()
        applyParagraphMarksVisibility()
        return paragraphMarksVisibleState
    }

    func paragraphMarksVisible() -> Bool {
        paragraphMarksVisibleState
    }

    private func applyParagraphMarksVisibility() {
        guard let paragraphTextView = textView as? AttachmentClickableTextView else { return }
        paragraphTextView.showsParagraphMarks = paragraphMarksVisibleState
        paragraphTextView.paragraphMarksColor = paragraphMarksColor(for: currentTheme)
        paragraphTextView.spaceDotsColor = spaceDotsColor(for: currentTheme)
        paragraphTextView.showsSectionBreaks = sectionBreaksVisibleState
        paragraphTextView.sectionBreaksColor = sectionBreaksColor(for: currentTheme)
        paragraphTextView.showsPageBreaks = pageBreaksVisibleState
        paragraphTextView.pageBreaksColor = pageBreaksColor(for: currentTheme)
        paragraphTextView.needsDisplay = true
    }

    // MARK: - Section break visibility

    private var sectionBreaksVisibleState: Bool = QuillPilotSettings.showSectionBreaks

    // MARK: - Page break visibility

    private var pageBreaksVisibleState: Bool = QuillPilotSettings.showPageBreaks

    @discardableResult
    func togglePageBreaksVisibility() -> Bool {
        pageBreaksVisibleState.toggle()
        QuillPilotSettings.showPageBreaks = pageBreaksVisibleState
        applyParagraphMarksVisibility()
        return pageBreaksVisibleState
    }

    func pageBreaksVisible() -> Bool {
        pageBreaksVisibleState
    }

    @discardableResult
    func toggleSectionBreaksVisibility() -> Bool {
        sectionBreaksVisibleState.toggle()
        QuillPilotSettings.showSectionBreaks = sectionBreaksVisibleState
        applyParagraphMarksVisibility()
        return sectionBreaksVisibleState
    }

    func sectionBreaksVisible() -> Bool {
        sectionBreaksVisibleState
    }

    private func sectionBreaksColor(for theme: AppTheme) -> NSColor {
        switch theme {
        case .night:
            return theme.insertionPointColor.withAlphaComponent(0.7)
        case .day, .cream:
            return theme.pageBorder.withAlphaComponent(0.7)
        }
    }

    private func pageBreaksColor(for theme: AppTheme) -> NSColor {
        sectionBreaksColor(for: theme)
    }

    private func paragraphMarksColor(for theme: AppTheme) -> NSColor {
        switch theme {
        case .night:
            return theme.insertionPointColor.withAlphaComponent(0.75)
        case .day, .cream:
            return theme.pageBorder.withAlphaComponent(0.8)
        }
    }

    private func spaceDotsColor(for theme: AppTheme) -> NSColor {
        switch theme {
        case .night:
            return NSColor.white.withAlphaComponent(0.5)
        case .day:
            return NSColor.black.withAlphaComponent(0.35)
        case .cream:
            return NSColor(calibratedRed: 0.3, green: 0.25, blue: 0.2, alpha: 0.45)
        }
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
            NSFontManager.shared.convert(current, toFamily: resolveInstalledFontFamilyName(family))
        }
    }

    private func resolveInstalledFontFamilyName(_ requested: String) -> String {
        let families = NSFontManager.shared.availableFontFamilies
        if families.contains(requested) {
            return requested
        }

        let requestedLower = requested.lowercased()
        let requestedCompact = requestedLower.replacingOccurrences(of: " ", with: "")

        // Try substring match first ("Garamond" -> "Garamond Premier Pro")
        if let match = families.first(where: { $0.lowercased().contains(requestedLower) }) {
            return match
        }

        // Try compact match ignoring spaces ("Source Sans Pro" -> "SourceSans3")
        if let match = families.first(where: { $0.lowercased().replacingOccurrences(of: " ", with: "").contains(requestedCompact) }) {
            return match
        }

        return requested
    }

    func setFontSize(_ size: CGFloat) {
        applyFontChange { current in
            NSFontManager.shared.convert(current, toSize: size)
        }
    }

    private func parseBulletPrefix(in line: String) -> (prefix: String, prefixLengthUTF16: Int, hasTabAfter: Bool)? {
        for style in QuillPilotSettings.BulletStyle.allCases {
            let prefix = style.prefix
            guard line.hasPrefix(prefix) else { continue }

            let prefixLen = (prefix as NSString).length
            let ns = line as NSString
            let hasTabAfter: Bool
            if ns.length > prefixLen {
                hasTabAfter = ns.substring(with: NSRange(location: prefixLen, length: 1)) == "\t"
            } else {
                hasTabAfter = false
            }
            return (prefix: prefix, prefixLengthUTF16: prefixLen, hasTabAfter: hasTabAfter)
        }
        return nil
    }

    func toggleBulletedList() {
        let bulletPrefixes = QuillPilotSettings.BulletStyle.allCases.map { $0.prefix }
        let desiredPrefix = QuillPilotSettings.bulletStyle.prefix
        togglePrefixList(
            isPrefixed: { line in
                bulletPrefixes.contains(where: { line.hasPrefix($0) })
            },
            makePrefix: { _ in desiredPrefix }
        )
    }

    func toggleNumberedList() {
        let scheme = QuillPilotSettings.numberingScheme
        togglePrefixList(
            isPrefixed: { line in
                return parseNumberPrefix(in: line, scheme: scheme) != nil
            },
            makePrefix: { index in
                return makeNumberPrefix(from: [index + 1], scheme: scheme)
            }
        )
    }

    private func alphabeticValue(from text: String) -> Int? {
        let letters = text.uppercased()
        guard !letters.isEmpty else { return nil }
        var value = 0
        for scalar in letters.unicodeScalars {
            let v = Int(scalar.value)
            guard v >= 65 && v <= 90 else { return nil }
            value = value * 26 + (v - 64)
        }
        return value
    }

    private func alphabeticString(for number: Int, uppercase: Bool) -> String {
        guard number > 0 else { return uppercase ? "A" : "a" }
        var n = number
        var chars: [UnicodeScalar] = []
        while n > 0 {
            n -= 1
            let remainder = n % 26
            let scalar = UnicodeScalar(65 + remainder)!
            chars.append(scalar)
            n /= 26
        }
        let string = String(String.UnicodeScalarView(chars.reversed()))
        return uppercase ? string : string.lowercased()
    }

    private func parseNumberPrefix(in line: String, scheme: QuillPilotSettings.NumberingScheme) -> (components: [Int], prefixLength: Int, hasTabAfter: Bool)? {
        switch scheme {
        case .decimalDotted:
            return parseDecimalPrefix(in: line)
        case .alphabetUpper:
            return parseAlphabeticPrefix(in: line, uppercase: true)
        case .alphabetLower:
            return parseAlphabeticPrefix(in: line, uppercase: false)
        }
    }

    private func parseDecimalPrefix(in line: String) -> (components: [Int], prefixLength: Int, hasTabAfter: Bool)? {
        // Accept: "1. ", "1.\t", "1.2. ", "1.2.\t".
        // We treat a trailing dot before whitespace/tab as required.
        var idx = line.startIndex
        var components: [Int] = []

        func readInt() -> Int? {
            let start = idx
            while idx < line.endIndex, line[idx].isNumber {
                idx = line.index(after: idx)
            }
            if start == idx { return nil }
            return Int(line[start..<idx])
        }

        guard let first = readInt() else { return nil }
        components.append(first)

        // Read zero or more ".<int>" components.
        while idx < line.endIndex, line[idx] == "." {
            let nextIndex = line.index(after: idx)
            // If dot is followed by whitespace/tab, that's the final terminator.
            if nextIndex >= line.endIndex {
                return nil
            }
            let ch = line[nextIndex]
            if ch == " " || ch == "\t" {
                // Terminator dot.
                idx = nextIndex
                break
            }
            // Otherwise expect another integer component.
            idx = nextIndex
            guard let n = readInt() else { return nil }
            components.append(n)
        }

        // Require whitespace/tab after the terminator dot.
        guard idx < line.endIndex else { return nil }
        var hasTabAfter = false
        if line[idx] == "\t" {
            hasTabAfter = true
        } else if line[idx] == " " {
            // consume spaces until optional tab
            while idx < line.endIndex, line[idx] == " " {
                idx = line.index(after: idx)
            }
            if idx < line.endIndex, line[idx] == "\t" {
                hasTabAfter = true
            }
        } else {
            return nil
        }

        let prefixLength = line.distance(from: line.startIndex, to: idx)
        return (components, prefixLength, hasTabAfter)
    }

    private func parseAlphabeticPrefix(in line: String, uppercase: Bool) -> (components: [Int], prefixLength: Int, hasTabAfter: Bool)? {
        var idx = line.startIndex
        var components: [Int] = []

        func readLetters() -> Int? {
            let start = idx
            while idx < line.endIndex, line[idx].isLetter {
                idx = line.index(after: idx)
            }
            if start == idx { return nil }
            let letters = String(line[start..<idx])
            return alphabeticValue(from: letters)
        }

        guard let first = readLetters() else { return nil }
        components.append(first)

        while idx < line.endIndex, line[idx] == "." {
            let nextIndex = line.index(after: idx)
            if nextIndex >= line.endIndex { return nil }
            let ch = line[nextIndex]
            if ch == " " || ch == "\t" {
                idx = nextIndex
                break
            }
            idx = nextIndex
            guard let value = readLetters() else { return nil }
            components.append(value)
        }

        guard idx < line.endIndex else { return nil }
        var hasTabAfter = false
        if line[idx] == "\t" {
            hasTabAfter = true
        } else if line[idx] == " " {
            while idx < line.endIndex, line[idx] == " " {
                idx = line.index(after: idx)
            }
            if idx < line.endIndex, line[idx] == "\t" {
                hasTabAfter = true
            }
        } else {
            return nil
        }

        let prefixLength = line.distance(from: line.startIndex, to: idx)
        return (components, prefixLength, hasTabAfter)
    }

    private func makeNumberPrefix(from components: [Int], scheme: QuillPilotSettings.NumberingScheme) -> String {
        switch scheme {
        case .decimalDotted:
            return components.map(String.init).joined(separator: ".") + ". "
        case .alphabetUpper:
            let level = max(1, components.count)
            let value = components.last ?? 1
            let isUpper = (level % 2 == 1)
            return "\(alphabeticString(for: value, uppercase: isUpper)). "
        case .alphabetLower:
            let level = max(1, components.count)
            let value = components.last ?? 1
            let isUpper = (level % 2 == 0)
            return "\(alphabeticString(for: value, uppercase: isUpper)). "
        }
    }

    private func restartNumberingAtCursor() {
        restartNumbering(atCursorStartingAt: 1)
    }

    func restartNumbering(startAt: Int) {
        let start = max(1, startAt)
        restartNumbering(atCursorStartingAt: start)
    }

    private func restartNumbering(atCursorStartingAt startAt: Int) {
        guard let storage = textView.textStorage else { return }
        let selection = textView.selectedRange()
        guard selection.location <= storage.length else { return }

        let full = storage.string as NSString
        let paragraphRange = full.paragraphRange(for: NSRange(location: selection.location, length: 0))
        let paragraphText = full.substring(with: paragraphRange)
        let scheme = QuillPilotSettings.numberingScheme
        guard let parsed = parseNumberPrefix(in: paragraphText, scheme: scheme) else { return }

        let levelCount = parsed.components.count
        var baseComponents = parsed.components
        baseComponents[levelCount - 1] = startAt

        // Collect contiguous paragraphs of the same level directly following this one.
        var targetParagraphs: [(range: NSRange, existingPrefixLen: Int, hasTab: Bool)] = []
        var cursor = paragraphRange.location
        let running = 0

        while cursor < full.length {
            let pr = full.paragraphRange(for: NSRange(location: cursor, length: 0))
            let text = full.substring(with: pr)
            guard let p = parseNumberPrefix(in: text, scheme: scheme) else { break }
            guard p.components.count == levelCount else { break }
            targetParagraphs.append((pr, p.prefixLength, p.hasTabAfter))
            cursor = NSMaxRange(pr)
        }

        guard !targetParagraphs.isEmpty else { return }

        // Apply changes from bottom-up so ranges remain valid.
        storage.beginEditing()
        defer { storage.endEditing() }

        for (idx, item) in targetParagraphs.enumerated().reversed() {
            let n = startAt + running + idx
            var comps = baseComponents
            comps[levelCount - 1] = n
            let prefix = makeNumberPrefix(from: comps, scheme: scheme)
            // Replace the prefix (and optional tab that follows it).
            let replaceLen = item.existingPrefixLen + (item.hasTab ? 1 : 0)
            let replaceRange = NSRange(location: item.range.location, length: min(replaceLen, item.range.length))
            storage.replaceCharacters(in: replaceRange, with: prefix + (item.hasTab ? "\t" : ""))
        }

        // Keep caret at original logical position if possible.
        textView.didChangeText()
        // Trigger relayout so page backgrounds stay in sync.
        updatePageLayout()
    }

    func insertColumnBreak() {
        guard let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        guard range.location < textStorage.length else { return }

        let attrs = textStorage.attributes(at: range.location, effectiveRange: nil)
        guard let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle,
              let blocks = paragraphStyle.textBlocks as? [NSTextTableBlock],
              let block = blocks.first,
              block.startingRow == 0,
              block.table.numberOfColumns > 1 else {
            NSSound.beep()
            return
        }

        let table = block.table
        let currentColumn = block.startingColumn
        let totalColumns = table.numberOfColumns
        guard currentColumn < totalColumns - 1 else {
            NSSound.beep()
            return
        }

        let fullString = textStorage.string as NSString

        // Find table range
        var startLocation = range.location
        var endLocation = range.location

        while startLocation > 0 {
            let prevLocation = startLocation - 1
            let prevAttrs = textStorage.attributes(at: prevLocation, effectiveRange: nil)
            if let prevStyle = prevAttrs[.paragraphStyle] as? NSParagraphStyle,
               let prevBlocks = prevStyle.textBlocks as? [NSTextTableBlock],
               let prevBlock = prevBlocks.first,
               prevBlock.table === table {
                let prevRange = fullString.paragraphRange(for: NSRange(location: prevLocation, length: 0))
                startLocation = prevRange.location
            } else {
                break
            }
        }

        endLocation = startLocation
        while endLocation < textStorage.length {
            let nextAttrs = textStorage.attributes(at: endLocation, effectiveRange: nil)
            if let nextStyle = nextAttrs[.paragraphStyle] as? NSParagraphStyle,
               let nextBlocks = nextStyle.textBlocks as? [NSTextTableBlock],
               let nextBlock = nextBlocks.first,
               nextBlock.table === table {
                let paragraphRange = fullString.paragraphRange(for: NSRange(location: endLocation, length: 0))
                endLocation = NSMaxRange(paragraphRange)
            } else {
                break
            }
        }

        // Collect column paragraph ranges within table
        var columnRanges: [(location: Int, column: Int, paragraphStyle: NSParagraphStyle)] = []
        var searchLocation = startLocation
        while searchLocation < endLocation {
            let attrs = textStorage.attributes(at: searchLocation, effectiveRange: nil)
            if let ps = attrs[.paragraphStyle] as? NSParagraphStyle,
               let blocks = ps.textBlocks as? [NSTextTableBlock],
               let b = blocks.first,
               b.table === table {
                let pRange = fullString.paragraphRange(for: NSRange(location: searchLocation, length: 0))
                columnRanges.append((location: pRange.location, column: b.startingColumn, paragraphStyle: ps))
                searchLocation = NSMaxRange(pRange)
            } else {
                break
            }
        }

        guard let nextColumnEntry = columnRanges
            .filter({ $0.column == currentColumn + 1 })
            .sorted(by: { $0.location < $1.location })
            .first else {
            NSSound.beep()
            return
        }

        let currentParagraphRange = fullString.paragraphRange(for: range)
        let trailingRange = NSRange(location: range.location, length: NSMaxRange(currentParagraphRange) - range.location)
        let trailingContent = textStorage.attributedSubstring(from: trailingRange)

        let updatedTrailing = NSMutableAttributedString(attributedString: trailingContent)
        updatedTrailing.addAttribute(.paragraphStyle, value: nextColumnEntry.paragraphStyle, range: NSRange(location: 0, length: updatedTrailing.length))

        textStorage.beginEditing()
        if trailingRange.length > 0 {
            textStorage.deleteCharacters(in: trailingRange)
        }
        textStorage.insert(updatedTrailing, at: nextColumnEntry.location)
        textStorage.endEditing()

        textView.setSelectedRange(NSRange(location: nextColumnEntry.location, length: 0))
    }

    func balanceColumnsAtCursor() {
        guard let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        guard range.location < textStorage.length else { return }

        let attrs = textStorage.attributes(at: range.location, effectiveRange: nil)
        guard let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle,
              let blocks = paragraphStyle.textBlocks as? [NSTextTableBlock],
              let block = blocks.first,
              block.startingRow == 0,
              block.table.numberOfColumns > 1 else {
            NSSound.beep()
            return
        }

        let table = block.table
        let totalColumns = table.numberOfColumns
        let fullString = textStorage.string as NSString

        // Find table range
        var startLocation = range.location
        var endLocation = range.location

        while startLocation > 0 {
            let prevLocation = startLocation - 1
            let prevAttrs = textStorage.attributes(at: prevLocation, effectiveRange: nil)
            if let prevStyle = prevAttrs[.paragraphStyle] as? NSParagraphStyle,
               let prevBlocks = prevStyle.textBlocks as? [NSTextTableBlock],
               let prevBlock = prevBlocks.first,
               prevBlock.table === table {
                let prevRange = fullString.paragraphRange(for: NSRange(location: prevLocation, length: 0))
                startLocation = prevRange.location
            } else {
                break
            }
        }

        endLocation = startLocation
        while endLocation < textStorage.length {
            let nextAttrs = textStorage.attributes(at: endLocation, effectiveRange: nil)
            if let nextStyle = nextAttrs[.paragraphStyle] as? NSParagraphStyle,
               let nextBlocks = nextStyle.textBlocks as? [NSTextTableBlock],
               let nextBlock = nextBlocks.first,
               nextBlock.table === table {
                let paragraphRange = fullString.paragraphRange(for: NSRange(location: endLocation, length: 0))
                endLocation = NSMaxRange(paragraphRange)
            } else {
                break
            }
        }

        // Collect column paragraphs
        var columnEntries: [(range: NSRange, column: Int, paragraphStyle: NSParagraphStyle)] = []
        var searchLocation = startLocation
        while searchLocation < endLocation {
            let attrs = textStorage.attributes(at: searchLocation, effectiveRange: nil)
            if let ps = attrs[.paragraphStyle] as? NSParagraphStyle,
               let blocks = ps.textBlocks as? [NSTextTableBlock],
               let b = blocks.first,
               b.table === table {
                let pRange = fullString.paragraphRange(for: NSRange(location: searchLocation, length: 0))
                columnEntries.append((range: pRange, column: b.startingColumn, paragraphStyle: ps))
                searchLocation = NSMaxRange(pRange)
            } else {
                break
            }
        }

        let sortedEntries = columnEntries.sorted { $0.column < $1.column }
        guard sortedEntries.count == totalColumns else { return }

        // Concatenate content across columns
        let combined = NSMutableAttributedString()
        for entry in sortedEntries {
            let chunk = NSMutableAttributedString(attributedString: textStorage.attributedSubstring(from: entry.range))
            if chunk.string.hasSuffix("\n") {
                chunk.deleteCharacters(in: NSRange(location: chunk.length - 1, length: 1))
            }
            combined.append(chunk)
        }

        guard combined.length > 0 else { return }

        // Split content evenly by character count
        let totalLength = combined.length
        var replacements: [NSAttributedString] = []
        for i in 0..<totalColumns {
            let start = totalLength * i / totalColumns
            let end = (i == totalColumns - 1) ? totalLength : (totalLength * (i + 1) / totalColumns)
            let length = max(0, end - start)
            let slice = combined.attributedSubstring(from: NSRange(location: start, length: length))
            let mutable = NSMutableAttributedString(attributedString: slice)
            if mutable.length == 0 || !mutable.string.hasSuffix("\n") {
                let attrs = textView.typingAttributes
                mutable.append(NSAttributedString(string: "\n", attributes: attrs))
            }
            replacements.append(mutable)
        }

        // Apply paragraph styles per column and replace from bottom up
        textStorage.beginEditing()
        for (index, entry) in sortedEntries.enumerated().reversed() {
            let replacement = NSMutableAttributedString(attributedString: replacements[index])
            replacement.addAttribute(.paragraphStyle, value: entry.paragraphStyle, range: NSRange(location: 0, length: replacement.length))
            textStorage.replaceCharacters(in: entry.range, with: replacement)
        }
        textStorage.endEditing()

        textView.setSelectedRange(NSRange(location: sortedEntries.first!.range.location, length: 0))
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

        insertImage(image, sourceURL: url, insertionPoint: nil, sourceRange: nil)
    }

    private func insertImage(_ image: NSImage, sourceURL: URL?, insertionPoint: Int?, sourceRange: NSRange?) {
        // Calculate max width based on text container width (accounts for margins and zoom)
        let textContainerWidth = textView.textContainer?.size.width ?? ((pageWidth - standardMargin * 2) * editorZoom)
        // Default to 50% of text width to prevent images from blowing out text
        var maxWidth = textContainerWidth * 0.5
        let maxHeight = (pageHeight - headerHeight - footerHeight - (standardMargin * 2)) * editorZoom * 0.6 // keep well inside a single page

        var caretLocation = insertionPoint ?? textView.selectedRange().location

        if let sourceRange, let storage = textView.textStorage, sourceRange.location + sourceRange.length <= storage.length {
            if caretLocation > sourceRange.location {
                caretLocation = max(sourceRange.location, caretLocation - sourceRange.length)
            }
            replaceCharacters(in: sourceRange, with: NSAttributedString(string: ""), undoPlaceholder: "")
        }

        // Check if cursor is in a table cell - if so, use much smaller max width to avoid breaking the cell
        if let textStorage = textView.textStorage, caretLocation < textStorage.length {
            let attrs = textStorage.attributes(at: caretLocation, effectiveRange: nil)
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
        attachment.attachmentCell = QuillPilotResizableAttachmentCell(image: image, size: targetSize)

        // Preserve image data and size in fileWrapper; normalize to PNG for consistency
        if let pngData = image.pngData() {
            let wrapper = FileWrapper(regularFileWithContents: pngData)
            wrapper.preferredFilename = encodeImageFilename(size: targetSize, ext: "png")
            attachment.fileWrapper = wrapper
        } else if let sourceURL, let data = try? Data(contentsOf: sourceURL) { // fallback to source data
            let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
            let wrapper = FileWrapper(regularFileWithContents: data)
            wrapper.preferredFilename = encodeImageFilename(size: targetSize, ext: ext)
            attachment.fileWrapper = wrapper
        }

        textView.window?.makeFirstResponder(textView)

        // Store the current insertion point before any modal dialogs affect focus
        let maxLen = textView.textStorage?.length ?? 0
        let insertionPoint = max(0, min(caretLocation, maxLen))
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

        if !textView.shouldChangeText(in: insertionRange, replacementString: "\u{FFFC}") {
            return
        }
        if let storage = textView.textStorage {
            storage.beginEditing()
            storage.replaceCharacters(in: insertionRange, with: finalImageString)
            storage.endEditing()
            textView.didChangeText()
        }

        // Images can change layout height significantly; recompute pagination now,
        // and repeat shortly after to catch any async attachment/layout settling.
        updatePageLayout()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.updatePageLayout()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
            self?.updatePageLayout()
        }

        // Place caret after the attachment
        let attachmentPos = insertionRange.location
        textView.setSelectedRange(NSRange(location: min(attachmentPos + 1, (textView.textStorage?.length ?? 0)), length: 0))

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

        func attachmentRangeIfPresent(at loc: Int) -> NSRange? {
            let clampedLoc = max(0, min(loc, storage.length - 1))
            var effectiveRange = NSRange(location: NSNotFound, length: 0)
            if storage.attribute(.qpPageBreak, at: clampedLoc, effectiveRange: nil) != nil {
                return nil
            }
            if storage.attribute(.attachment, at: clampedLoc, effectiveRange: &effectiveRange) != nil {
                // Only treat as an image attachment if we have our size stamp.
                if storage.attribute(NSAttributedString.Key("QuillPilotImageSize"), at: clampedLoc, effectiveRange: nil) != nil {
                    return effectiveRange
                }
            }
            return nil
        }

        // Clicking an attachment often places the caret *after* the attachment character.
        // Check both the current location and the preceding character.
        if let found = attachmentRangeIfPresent(at: location) { return found }
        if location > 0, let found = attachmentRangeIfPresent(at: location - 1) { return found }
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
        if let storage = textView.textStorage,
           let attachment = storage.attribute(.attachment, at: attachmentRange.location, effectiveRange: nil) as? NSTextAttachment {
            // Ensure the attachment has an image loaded for resizing/drawing.
            if attachment.image == nil, let data = attachment.fileWrapper?.regularFileContents {
                attachment.image = NSImage(data: data)
            }

            // If an attachment is oversized (common with paste/import), clamp it immediately
            // so it doesn't render off the page and so the slider is meaningful.
            let currentSize = attachment.bounds.size
            if currentSize.width > maxWidth * 1.02 {
                let aspect = (currentSize.width > 0) ? (currentSize.height / currentSize.width) : 1
                let targetWidth = max(40, maxWidth)
                let targetHeight = max(40, targetWidth * aspect)
                let newBounds = NSRect(origin: .zero, size: NSSize(width: targetWidth, height: targetHeight))
                attachment.bounds = newBounds
                if let img = attachment.image {
                    attachment.attachmentCell = QuillPilotResizableAttachmentCell(image: img, size: newBounds.size)
                }
                storage.addAttribute(NSAttributedString.Key("QuillPilotImageSize"), value: NSStringFromRect(newBounds), range: attachmentRange)
            }
        }

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
            makeButton("Move", action: #selector(beginMoveImage))
        ])
        moveRow.orientation = .horizontal
        moveRow.spacing = 3

        let captionRow = NSStackView(views: [
            makeButton("Caption", action: #selector(addOrEditCaption))
        ])
        captionRow.orientation = .horizontal
        captionRow.spacing = 3

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

        let slider = ImageResizeSlider(value: currentScale, minValue: 0.1, maxValue: 1.0, target: self, action: #selector(resizeSliderChanged(_:)))
        slider.isContinuous = true
        slider.onMouseDown = { [weak self] in
            guard let self else { return }
            self.suppressLayoutDuringImageResize = true
            // Prevent any pending delayed relayout from firing mid-drag.
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updatePageCenteringDelayed), object: nil)
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(checkAndUpdateTitleDelayed), object: nil)
            self.imageResizeEndWorkItem?.cancel()
        }
        slider.onMouseUp = { [weak self] in
            self?.commitImageResizeChanges()
        }

        let resizeRow = NSStackView(views: [scaleLabel, slider])
        resizeRow.orientation = .horizontal
        resizeRow.spacing = 3
        resizeRow.distribution = .fillProportionally

        stack.addArrangedSubview(alignRow)
        stack.addArrangedSubview(moveRow)
        stack.addArrangedSubview(captionRow)
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
            // firstRect(forCharacterRange:) returns screen coordinates.
            let screenRect = textView.firstRect(forCharacterRange: attachmentRange, actualRange: nil)
            if let win = textView.window {
                let windowRect = win.convertFromScreen(screenRect)
                rect = textView.convert(windowRect, from: nil)
            } else {
                rect = .zero
            }
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
        resizeImageLive(toScale: scale)
    }

    private func commitImageResizeChanges() {
        suppressLayoutDuringImageResize = false
        guard let storage = textView.textStorage else { return }
        guard let range = lastImageRange ?? imageAttachmentRange(at: textView.selectedRange().location) else { return }

        // Commit the change into undo + downstream update pipeline once.
        storage.edited(.editedAttributes, range: range, changeInLength: 0)
        textView.didChangeText()

        // Reflow pages without scrolling the view.
        updatePageCentering(ensureSelectionVisible: false)
        showImageControlsIfNeeded()
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

    private func resizeImageLive(toScale scale: CGFloat) {
        guard let storage = textView.textStorage else { return }
        guard let range = lastImageRange ?? imageAttachmentRange(at: textView.selectedRange().location) else { return }
        guard let attachment = storage.attribute(.attachment, at: range.location, effectiveRange: nil) as? NSTextAttachment else { return }

        // Ensure we have an NSImage for predictable resizing/drawing.
        if attachment.image == nil, let data = attachment.fileWrapper?.regularFileContents {
            attachment.image = NSImage(data: data)
        }

        // Cancel any pending layout work from earlier edits so it can't fire mid-drag and jump the view.
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updatePageCenteringDelayed), object: nil)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(checkAndUpdateTitleDelayed), object: nil)

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

        let newBounds = NSRect(origin: .zero, size: NSSize(width: targetWidth, height: targetHeight))
        attachment.bounds = newBounds
        if let img = attachment.image {
            if let cell = attachment.attachmentCell as? QuillPilotResizableAttachmentCell {
                cell.forcedSize = newBounds.size
            } else {
                attachment.attachmentCell = QuillPilotResizableAttachmentCell(image: img, size: newBounds.size)
            }
        }

        // Persist size for QuillPilot reopen/migration logic.
        storage.beginEditing()
        storage.addAttribute(NSAttributedString.Key("QuillPilotImageSize"), value: NSStringFromRect(newBounds), range: range)
        storage.endEditing()

        // Update the stored size in the fileWrapper filename for persistence
        if let wrapper = attachment.fileWrapper, let oldName = wrapper.preferredFilename {
            let ext = (oldName as NSString).pathExtension
            wrapper.preferredFilename = encodeImageFilename(size: NSSize(width: targetWidth, height: targetHeight), ext: ext)
        }

        // Invalidate layout so the attachment redraws at the new size immediately.
        let paragraphRange = (storage.string as NSString).paragraphRange(for: NSRange(location: range.location, length: 1))
        textView.layoutManager?.invalidateLayout(forCharacterRange: paragraphRange, actualCharacterRange: nil)
        textView.layoutManager?.invalidateDisplay(forCharacterRange: paragraphRange)
        textView.layoutManager?.ensureLayout(forCharacterRange: paragraphRange)

        // Do not call didChangeText() while dragging; that triggers expensive relayout
        // and can cause the page to jump horizontally.
        storage.edited(.editedAttributes, range: range, changeInLength: 0)
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

    @objc private func beginMoveImage() {
        guard let range = lastImageRange,
              let storage = textView.textStorage,
              range.location < storage.length,
              let attachment = storage.attribute(.attachment, at: range.location, effectiveRange: nil) as? NSTextAttachment else {
            return
        }

        if attachment.image == nil, let data = attachment.fileWrapper?.regularFileContents {
            attachment.image = NSImage(data: data)
        }

        guard let image = attachment.image else { return }

        moveImageModeActive = true
        moveImagePending = image
        moveImageSourceRange = range

        imageControlsPopover?.performClose(nil)
        imageControlsPopover = nil
        textView.window?.makeFirstResponder(textView)
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
        // Scroll to the absolute top while preserving horizontal position.
        // Resetting x to 0 makes the page appear left-justified until a later layout pass.
        let currentX = scrollView.contentView.bounds.origin.x
        scrollView.contentView.scroll(to: NSPoint(x: currentX, y: 0))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        // Also try the text view method as backup
        textView.scrollToBeginningOfDocument(nil)
    }

    func scrollToBottom() {
        guard let storage = textView.textStorage else { return }
        let length = storage.length
        guard length > 0 else { return }

        let target = max(0, length - 1)
        navigateToLocation(target)
    }

    func scrollToOutlineEntry(_ entry: OutlineEntry) {
        guard let storage = textView.textStorage else { return }
        let length = storage.length
        guard length > 0 else { return }

        guard let resolvedRange = resolveOutlineEntryRange(entry) else { return }
        let clampedLocation = min(resolvedRange.location, max(0, length - 1))
        navigateToLocation(clampedLocation, flash: true)
    }

    private func navigateToLocation(_ location: Int, flash: Bool = false) {
        navigationWorkItem?.cancel()

        // Explicit navigation should win over any delayed centering/layout work that may have
        // been scheduled by prior text changes (e.g. TOC/Index insertion). Those delayed passes
        // can restore a pre-jump scroll position and make the user click repeatedly.
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updatePageCenteringDelayed), object: nil)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(checkAndUpdateTitleDelayed), object: nil)

        DebugLog.log("🧭NAV[\(qpTS())] request location=\(location) flash=\(flash)")

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard let storage = self.textView.textStorage, storage.length > 0 else { return }

            // Outline-driven navigation (flash=true) should land on stable geometry.
            // After import/reopen, AppKit can be partially laid out; as layout finishes, glyph Y
            // positions can shift and it feels like a snap/jump when the user scrolls. Force a bounded
            // full layout + pagination pass first.
            let clamped = min(max(0, location), max(0, storage.length - 1))
            if flash, storage.length <= 1_000_000, let layoutManager = self.textView.layoutManager {
                layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: storage.length))
                self.updatePageLayout()
            }

            // Prevent the layout pipeline from restoring the previous scroll position.
            self.pendingNavigationScroll = true
            self.navigationScrollSuppressionUntil = CFAbsoluteTimeGetCurrent() + 4.5

            // Make sure the page container is tall enough to reach the target BEFORE we try to scroll.
            // This avoids the "click 3 times" symptom when pagination is still settling near the end.
            self.ensurePageCountForCharacterLocation(clamped)
            self.view.layoutSubtreeIfNeeded()

            let ensureRange = NSRange(location: clamped, length: 1)
            self.textView.layoutManager?.ensureLayout(forCharacterRange: ensureRange)
            self.textView.setSelectedRange(NSRange(location: clamped, length: 0))
            self.textView.scrollRangeToVisible(ensureRange)

            // Nudge the target into a preferred position (near the top) so a jump doesn't land
            // with the destination barely visible at the bottom (which feels like it didn't work).
            if let layoutManager = self.textView.layoutManager, let textContainer = self.textView.textContainer {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: ensureRange, actualCharacterRange: nil)
                var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                rect.origin.x += self.textView.textContainerOrigin.x
                rect.origin.y += self.textView.textContainerOrigin.y
                let rectInDoc = self.textView.convert(rect, to: self.documentView)
                let visible = self.scrollView.documentVisibleRect
                let preferredTopInset = max(24, visible.height * 0.18)
                let targetY = max(0, rectInDoc.minY - preferredTopInset)
                self.scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
                self.scrollView.reflectScrolledClipView(self.scrollView.contentView)
            }

            DebugLog.log("🧭NAV[\(self.qpTS())] initial scroll clamped=\(clamped) visY=\(self.scrollView.documentVisibleRect.origin.y.rounded())")

            if flash {
                self.flashOutlineLocation(clamped)
            }

            // Late layout passes can still adjust geometry; retry visibility a few times automatically.
            func verifyAndRescroll(_ attempt: Int) {
                guard let layoutManager = self.textView.layoutManager, let textContainer = self.textView.textContainer else {
                    self.pendingNavigationScroll = false
                    return
                }
                let glyphRange = layoutManager.glyphRange(forCharacterRange: ensureRange, actualCharacterRange: nil)
                var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                rect.origin.x += self.textView.textContainerOrigin.x
                rect.origin.y += self.textView.textContainerOrigin.y
                let rectInDoc = self.textView.convert(rect, to: self.documentView)

                let visible = self.scrollView.documentVisibleRect
                let preferredTopInset = max(24, visible.height * 0.18)
                let preferredBottomInset = max(24, visible.height * 0.28)
                let preferredBand = NSRect(
                    x: visible.minX,
                    y: visible.minY + preferredTopInset,
                    width: visible.width,
                    height: max(1, visible.height - preferredTopInset - preferredBottomInset)
                )

                if preferredBand.intersects(rectInDoc) {
                    DebugLog.log("🧭NAV[\(self.qpTS())] target preferred-visible attempt=\(attempt) rectY=\(rectInDoc.midY.rounded()) visY=\(visible.origin.y.rounded())")
                    self.pendingNavigationScroll = false
                    return
                }

                DebugLog.log("🧭NAV[\(self.qpTS())] target NOT preferred-visible attempt=\(attempt) rectY=\(rectInDoc.midY.rounded()) visY=\(visible.origin.y.rounded())")

                // Scroll so the target lands near the top.
                let targetY = max(0, rectInDoc.minY - preferredTopInset)
                self.scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
                self.scrollView.reflectScrolledClipView(self.scrollView.contentView)
                // Also ensure selection is visible in case text-view scrolling behaves differently.
                self.textView.scrollRangeToVisible(ensureRange)

                if attempt >= 3 {
                    self.pendingNavigationScroll = false
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + (0.08 * Double(attempt + 1))) {
                    verifyAndRescroll(attempt + 1)
                }
            }

            DispatchQueue.main.async { verifyAndRescroll(0) }
        }

        navigationWorkItem = work
        DispatchQueue.main.async(execute: work)
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

        // Calculate page based on Y position. The text view spans multiple pages with gaps.
        let scaledPageHeight = pageHeight * editorZoom
        let pageGap: CGFloat = 20
        let pageStride = scaledPageHeight + pageGap
        let pageIndex = max(0, Int(floor(bounds.midY / pageStride)))

        return pageIndex + 1
    }

    func totalPageCount() -> Int {
        if let pageContainerView = pageContainer as? PageContainerView {
            return max(1, pageContainerView.numPages)
        }
        if let storage = textView.textStorage, storage.length > 0 {
            return max(1, getPageNumber(forCharacterPosition: storage.length - 1))
        }
        return 1
    }

    func indent() {
        if isSelectionInNumberedList() {
            _ = adjustNumberingLevelInSelection(by: 1)
            return
        }
        adjustIndent(by: standardIndentStep)
    }

    func outdent() {
        if isSelectionInNumberedList() {
            _ = adjustNumberingLevelInSelection(by: -1)
            return
        }
        adjustIndent(by: -standardIndentStep)
    }

    private func isSelectionInNumberedList() -> Bool {
        guard let storage = textView.textStorage else { return false }
        let sel = textView.selectedRange()
        guard storage.length > 0 else { return false }
        let safeLocation = min(sel.location, max(0, storage.length - 1))
        let full = storage.string as NSString
        let paragraphRange = full.paragraphRange(for: NSRange(location: safeLocation, length: 0))
        let paragraphText = full.substring(with: paragraphRange)
        let scheme = QuillPilotSettings.numberingScheme
        return parseNumberPrefix(in: paragraphText, scheme: scheme) != nil
    }

    func setPageMargins(left: CGFloat, right: CGFloat) {
        let leftMargin = max(0, left)
        let rightMargin = max(0, right)

        // Keep at least a small printable area.
        let maxMargin = max(0, pageWidth - 36)
        leftPageMargin = min(leftMargin, maxMargin)
        rightPageMargin = min(rightMargin, maxMargin)

        // Re-layout using the new margins; avoid forced scroll-to-caret during interactive drags.
        updatePageCentering(ensureSelectionVisible: false)
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
        // Export should be appearance-neutral (dark mode shouldn't produce white ink).
        // Use a fixed, standard default color for any missing ink.
        let defaultColor: NSColor = .black

        func colorsAreClose(_ a: NSColor, _ b: NSColor, tolerance: CGFloat = 0.02) -> Bool {
            let ca = (a.usingColorSpace(.sRGB) ?? a)
            let cb = (b.usingColorSpace(.sRGB) ?? b)
            return abs(ca.redComponent - cb.redComponent) <= tolerance &&
                abs(ca.greenComponent - cb.greenComponent) <= tolerance &&
                abs(ca.blueComponent - cb.blueComponent) <= tolerance
        }

        func perceivedBrightness(_ c: NSColor) -> CGFloat {
            let rgb = (c.usingColorSpace(.sRGB) ?? c)
            return (0.299 * rgb.redComponent) + (0.587 * rgb.greenComponent) + (0.114 * rgb.blueComponent)
        }

        func enforceBodyIndentIfNeeded(
            styleName: String,
            merged: NSParagraphStyle,
            existing: NSParagraphStyle?,
            catalog: NSParagraphStyle
        ) -> NSParagraphStyle {
            let enforceNames: Set<String> = ["Body Text", "Body Text – No Indent", "Dialogue"]
            guard enforceNames.contains(styleName) else { return merged }
            guard let mutable = merged.mutableCopy() as? NSMutableParagraphStyle else { return merged }

            let existingFirst = (existing ?? merged).firstLineHeadIndent
            let catalogFirst = catalog.firstLineHeadIndent

            if styleName == "Body Text" || styleName == "Dialogue" {
                // If existing lost the indent (≈0) but the catalog expects one, enforce the catalog indents.
                if existingFirst <= 0.5 && catalogFirst > 0.5 {
                    mutable.headIndent = catalog.headIndent
                    mutable.firstLineHeadIndent = catalog.firstLineHeadIndent
                    mutable.tailIndent = catalog.tailIndent
                }
            } else if styleName == "Body Text – No Indent" {
                // If existing incorrectly has an indent but the catalog expects none, enforce the catalog indents.
                if existingFirst > 0.5 && catalogFirst <= 0.5 {
                    mutable.headIndent = catalog.headIndent
                    mutable.firstLineHeadIndent = catalog.firstLineHeadIndent
                    mutable.tailIndent = catalog.tailIndent
                }
            }

            return mutable.copy() as! NSParagraphStyle
        }

        func resolveStyleDefinition(for styleName: String) -> StyleDefinition? {
            if let def = StyleCatalog.shared.style(named: styleName) {
                return def
            }
            if let templateName = StyleCatalog.shared.templateName(containingStyleName: styleName) {
                return StyleCatalog.shared.style(named: styleName, inTemplate: templateName)
            }
            return nil
        }

        // Reapply catalog-defined paragraph and font attributes based on stored style name
        var location = 0
        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
                if let styleName = normalized.attribute(styleAttributeKey, at: paragraphRange.location, effectiveRange: nil) as? String,
                    let definition = resolveStyleDefinition(for: styleName) {
                let catalogParagraph = paragraphStyle(from: definition)
                let font = font(from: definition)
                let textColor = color(fromHex: definition.textColorHex, fallback: defaultColor)
                let backgroundColor = definition.backgroundColorHex.flatMap { color(fromHex: $0, fallback: .clear) }

                // Get existing paragraph style to preserve textBlocks (columns/tables)
                let existingParagraph = normalized.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle
                let mergedParagraph = mergedParagraphStyle(existing: existingParagraph, style: catalogParagraph)
                let finalParagraph = enforceBodyIndentIfNeeded(styleName: styleName, merged: mergedParagraph, existing: existingParagraph, catalog: catalogParagraph)

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

                if let definition = resolveStyleDefinition(for: inferredStyleName) {
                    let para = paragraphStyle(from: definition)
                    let styleFont = self.font(from: definition)
                    let styleColor = color(fromHex: definition.textColorHex, fallback: defaultColor)
                    let bgColor = definition.backgroundColorHex.flatMap { color(fromHex: $0, fallback: .clear) }

                    normalized.addAttribute(styleAttributeKey, value: inferredStyleName, range: paragraphRange)

                    // Merge paragraph style to preserve manual alignment overrides
                    let mergedParagraph = mergedParagraphStyle(existing: paragraph, style: para)
                    let finalParagraph = enforceBodyIndentIfNeeded(styleName: inferredStyleName, merged: mergedParagraph, existing: paragraph, catalog: para)
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

        // If the editor is in a dark theme, the text storage may carry theme-injected light ink.
        // Normalize those runs back to standard black for export so Word/LibreOffice remain readable.
        let themeText = currentTheme.textColor
        let themeBg = currentTheme.pageBackground
        let themeTextBrightness = perceivedBrightness(themeText)
        if themeTextBrightness > 0.70 {
            let fullRange = NSRange(location: 0, length: normalized.length)
            normalized.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
                if let fg = attrs[.foregroundColor] as? NSColor {
                    // Only rewrite colors that are essentially the current theme's text color.
                    // This avoids destroying intentional colored spans.
                    if colorsAreClose(fg, themeText) {
                        normalized.addAttribute(.foregroundColor, value: NSColor.black, range: range)
                    }
                }

                if let bg = attrs[.backgroundColor] as? NSColor {
                    // Strip theme page background fills so exports don't carry dark shading.
                    if colorsAreClose(bg, themeBg) {
                        normalized.removeAttribute(.backgroundColor, range: range)
                    }
                }
            }
        }

        injectSectionBreakPersistenceLinks(into: normalized)
        materializePageBreaksForExport(into: normalized)
        return normalized
    }

    private func materializePageBreaksForExport(into attributed: NSMutableAttributedString) {
        guard attributed.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: attributed.length)

        // Replace internal marker attachments with a form-feed character for broad exporter compatibility.
        attributed.enumerateAttribute(.qpPageBreak, in: fullRange, options: [.reverse]) { value, range, _ in
            guard value != nil, range.length > 0 else { return }
            let attrs = attributed.attributes(at: range.location, effectiveRange: nil)
            var cleaned = attrs
            cleaned[.attachment] = nil
            cleaned[.qpPageBreak] = nil
            let replacement = NSAttributedString(string: "\u{000C}", attributes: cleaned)
            attributed.replaceCharacters(in: range, with: replacement)
        }
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

        lastTOCRightTab = nil

        // Reset manuscript metadata (prevents leaking across documents)
        manuscriptTitle = "Untitled"
        manuscriptAuthor = "Author Name"

        // Restore page breaks from form-feed markers before style inference.
        let restoredPageBreaks = restorePageBreakMarkersFromFormFeed(in: attributed)

        // Apply style retagging to infer paragraph styles
        let retagged = detectAndRetagStyles(in: restoredPageBreaks)
        textView.textStorage?.setAttributedString(retagged)
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        // Sync title/author from the first paragraph if tagged.
        checkAndUpdateTitle()

        clampImportedImageAttachmentsToSafeBounds()

        repairBodyTextIndentAfterLoadIfNeeded()

        applyDefaultTypingAttributes()
        updatePageLayout()
        // On reopen/import, the scroll view may not have its final width during the first layout pass.
        // Center immediately, then once more on the next runloop so the page doesn't appear left-justified
        // until the user triggers another layout change (e.g., by clicking a style).
        updatePageCentering(ensureSelectionVisible: false)
        DispatchQueue.main.async { [weak self] in
            self?.updatePageCentering(ensureSelectionVisible: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.updatePageCentering(ensureSelectionVisible: false)
        }
        scrollToTop()

        // Ensure TOC/Index leader alignment survives reopen.
        DispatchQueue.main.async { [weak self] in
            self?.repairTOCAndIndexFormattingAfterImport()
        }

        delegate?.resumeAnalysisAfterLayout()
    }

    /// Fast content setter for imported documents - runs style inference for outline detection
    func setAttributedContentDirect(_ attributed: NSAttributedString) {
        delegate?.suspendAnalysisForLayout()

        lastTOCRightTab = nil

        // Reset manuscript metadata (prevents leaking across documents)
        manuscriptTitle = "Untitled"
        manuscriptAuthor = "Author Name"

        debugLog("📥 Import.setAttributedContentDirect: len=\(attributed.length) zoom=\(editorZoom)")

        // For large documents, defer layout to prevent UI freeze
        let isLargeDocument = attributed.length > 100_000

        if isLargeDocument {
            // Disable layout during bulk insert
            textView.layoutManager?.backgroundLayoutEnabled = false
        }

        // Restore QuillPilot internal markers (e.g. section breaks) from safe, cross-format attributes
        // before retagging so they don't interfere with style inference.
        let restoredSectionBreaks = restoreSectionBreaksFromPersistenceLinks(in: attributed)
        let restored = restorePageBreakMarkersFromFormFeed(in: restoredSectionBreaks)

        // Run style detection to ensure TOC Title, Index Title, etc. appear in document outline
        let retagged = detectAndRetagStyles(in: restored)
        textView.textStorage?.setAttributedString(retagged)
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        // Sync title/author from the first paragraph if tagged.
        checkAndUpdateTitle()

        clampImportedImageAttachmentsToSafeBounds()

        repairBodyTextIndentAfterLoadIfNeeded()

        // Some importers preserve style identity via QuillStyleName but can lose visible formatting
        // when AppKit normalizes attributed strings. Re-apply catalog formatting for any tagged
        // paragraphs so Screenplay/Fiction/Poetry styles actually render on the page.
        materializeCatalogStylesFromTags()

        // Don't reset typing attributes - let them inherit from document content
        // This preserves the Body Text style and other attributes when typing
        updateTypingAttributesFromContent()

        if isLargeDocument {
            // Re-enable and do layout in chunks
            textView.layoutManager?.backgroundLayoutEnabled = true
            // Defer heavy layout work AND analysis until pages are ready
            DispatchQueue.main.async { [weak self] in
                debugLog("📥 Import: running deferred updatePageLayout (large doc)")
                self?.updatePageLayout()
                self?.updatePageCentering(ensureSelectionVisible: false)
                self?.scrollToTop()
                self?.repairTOCAndIndexFormattingAfterImport()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                    self?.updatePageCentering(ensureSelectionVisible: false)
                }
                // Wait for layout to settle before triggering analysis
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.delegate?.resumeAnalysisAfterLayout()
                }
            }
        } else {
            debugLog("📥 Import: running immediate updatePageLayout")
            updatePageLayout()
            updatePageCentering(ensureSelectionVisible: false)
            scrollToTop()
            repairTOCAndIndexFormattingAfterImport()
            // For rich imports (RTF/RTFD/HTML/ODT), AppKit may continue layout asynchronously.
            // Recompute pagination after a short delay so page backgrounds match the final flow.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                debugLog("📥 Import: delayed updatePageLayout (+0.25s)")
                self?.updatePageLayout()
                self?.updatePageCentering(ensureSelectionVisible: false)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                self?.updatePageCentering(ensureSelectionVisible: false)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
                debugLog("📥 Import: delayed updatePageLayout (+0.75s)")
                self?.updatePageLayout()
                self?.updatePageCentering(ensureSelectionVisible: false)
            }
            delegate?.resumeAnalysisAfterLayout()
        }
    }

    private func materializeCatalogStylesFromTags(in range: NSRange? = nil) {
        guard let storage = textView.textStorage, storage.length > 0 else { return }

        let fullString = storage.string as NSString
        let targetRange = range ?? NSRange(location: 0, length: storage.length)

        // For TOC/Index entries, preserve ALL existing formatting (especially tab stops)
        // These have custom formatting that shouldn't be overwritten by catalog styles.
        let preserveFormattingStyles = [
            "TOC Entry", "TOC Entry Level 1", "TOC Entry Level 2", "TOC Entry Level 3",
            "Index Entry", "Index Letter"
        ]

        let currentTemplate = StyleCatalog.shared.currentTemplateName

        storage.beginEditing()
        defer { storage.endEditing() }

        var location = targetRange.location
        let end = NSMaxRange(targetRange)
        while location < end {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
            let safeParagraphRange = NSIntersectionRange(paragraphRange, targetRange)
            guard safeParagraphRange.length > 0 else {
                location = NSMaxRange(paragraphRange)
                continue
            }

            let attrs = storage.attributes(at: safeParagraphRange.location, effectiveRange: nil)
            guard let styleName = attrs[styleAttributeKey] as? String,
                  !preserveFormattingStyles.contains(styleName),
                  let definition = StyleCatalog.shared.style(named: styleName) else {
                location = NSMaxRange(paragraphRange)
                continue
            }

            // Ensure the tag covers the full paragraph range.
            storage.addAttribute(styleAttributeKey, value: styleName, range: safeParagraphRange)

            var catalogParagraph = self.paragraphStyle(from: definition)
            let catalogFont = self.font(from: definition)

            let existingPara = (attrs[.paragraphStyle] as? NSParagraphStyle) ?? (textView.defaultParagraphStyle ?? NSParagraphStyle.default)

            // Industry-standard screenplay style names that need exact layout
            let screenplayStyles: Set<String> = [
                "Scene Heading", "Action", "Character", "Parenthetical", "Dialogue", "Transition",
                "Shot", "Montage", "Montage Header", "Montage Item", "Montage End",
                "Series of Shots Header", "Series of Shots Item", "Series of Shots End",
                "Flashback", "Back To Present",
                "Intercut", "End Intercut",
                "Act Break", "Chyron", "Lyrics",
                "Insert", "On Screen", "Text Message", "Email",
                "Note", "More", "Continued", "Title", "Author", "Contact", "Draft"
            ]

            // For Screenplay Action, spacingBefore is contextual (after Scene Heading/Dialogue).
            if currentTemplate == "Screenplay", styleName == "Action" {
                let prevLoc = max(0, safeParagraphRange.location - 1)
                if prevLoc < fullString.length {
                    let prevPara = fullString.paragraphRange(for: NSRange(location: prevLoc, length: 0))
                    let prevStyle = (prevPara.location < storage.length)
                        ? (storage.attribute(styleAttributeKey, at: prevPara.location, effectiveRange: nil) as? String)
                        : nil
                    let desiredBefore: CGFloat = (prevStyle == "Scene Heading" || prevStyle == "Dialogue") ? 12 : 0
                    if let mutable = catalogParagraph.mutableCopy() as? NSMutableParagraphStyle {
                        mutable.paragraphSpacingBefore = desiredBefore
                        catalogParagraph = mutable.copy() as! NSParagraphStyle
                    }
                }
            }

            // Screenplay styles are layout-sensitive; force exact catalog paragraph style.
            let finalParagraph: NSParagraphStyle
            if currentTemplate == "Screenplay", screenplayStyles.contains(styleName) {
                finalParagraph = catalogParagraph
            } else {
                finalParagraph = mergedParagraphStyle(existing: existingPara, style: catalogParagraph)
            }
            storage.addAttribute(.paragraphStyle, value: finalParagraph, range: safeParagraphRange)

            // Apply font per run to preserve inline bold/italic.
            storage.enumerateAttributes(in: safeParagraphRange, options: []) { runAttrs, runRange, _ in
                let existingFont = runAttrs[.font] as? NSFont
                let finalFont: NSFont
                if currentTemplate == "Screenplay", screenplayStyles.contains(styleName) {
                    finalFont = mergedScreenplayFont(existing: existingFont, style: catalogFont)
                } else {
                    finalFont = mergedFont(existing: existingFont, style: catalogFont)
                }
                storage.addAttribute(.font, value: finalFont, range: runRange)
                if runAttrs[.foregroundColor] == nil {
                    storage.addAttribute(.foregroundColor, value: currentTheme.textColor, range: runRange)
                }
            }

            location = NSMaxRange(paragraphRange)
        }
    }

    private func clampImportedImageAttachmentsToSafeBounds() {
        guard let storage = textView.textStorage, storage.length > 0 else { return }

        // Bounds are in points (not zoomed). Keep images within the page text area.
        let maxWidth = max(120, (pageWidth - (leftPageMargin + rightPageMargin)) * 0.95)
        let maxHeight = max(120, (pageHeight - headerHeight - footerHeight - (standardMargin * 2.0)) * 0.90)

        let fullRange = NSRange(location: 0, length: storage.length)
        let sizeKey = NSAttributedString.Key("QuillPilotImageSize")

        func imagePixelInfo(from data: Data) -> (width: Int, height: Int)? {
            let cfData = data as CFData
            guard let source = CGImageSourceCreateWithData(cfData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
            guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary) as? [CFString: Any] else { return nil }
            let w = props[kCGImagePropertyPixelWidth] as? Int
            let h = props[kCGImagePropertyPixelHeight] as? Int
            if let w, let h, w > 0, h > 0 { return (w, h) }
            return nil
        }

        func downscaledPngData(from data: Data, maxPixel: Int) -> Data? {
            let cfData = data as CFData
            guard let source = CGImageSourceCreateWithData(cfData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }

            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                kCGImageSourceShouldCacheImmediately: false,
                kCGImageSourceShouldCache: false
            ]
            guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            let rep = NSBitmapImageRep(cgImage: cgThumb)
            return rep.representation(using: .png, properties: [:])
        }

        storage.beginEditing()
        storage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            guard let attachment = value as? NSTextAttachment else { return }

            // Determine current intended size.
            var size = attachment.bounds.size
            if size.width <= 1 || size.height <= 1 {
                if let stored = storage.attribute(sizeKey, at: range.location, effectiveRange: nil) as? String {
                    let rect = NSRectFromString(stored)
                    if rect.width > 1 && rect.height > 1 {
                        size = rect.size
                    }
                }
            }
            if size.width <= 1 || size.height <= 1, let img = attachment.image {
                size = img.size
            }

            guard size.width > 1, size.height > 1 else { return }

            // Clamp bounds to safe page area.
            let scale = min(1.0, maxWidth / size.width, maxHeight / size.height)
            if scale < 0.999 {
                let newSize = NSSize(width: floor(size.width * scale), height: floor(size.height * scale))
                let newBounds = NSRect(origin: .zero, size: newSize)
                attachment.bounds = newBounds
                storage.addAttribute(sizeKey, value: NSStringFromRect(newBounds), range: range)
            } else if attachment.bounds.width > 0 && attachment.bounds.height > 0 {
                // Ensure we persist whatever bounds we currently have.
                storage.addAttribute(sizeKey, value: NSStringFromRect(attachment.bounds), range: range)
            }

            // Optional safety: downscale huge embedded image data to reduce memory pressure.
            // Only triggers for very large images.
            if let wrapper = attachment.fileWrapper, let data = wrapper.regularFileContents {
                let dataTooLarge = data.count > (30 * 1024 * 1024)
                let pixelInfo = imagePixelInfo(from: data)
                let pixelTooLarge = pixelInfo.map { ($0.width * $0.height) > 40_000_000 || max($0.width, $0.height) > 8000 } ?? false

                if dataTooLarge || pixelTooLarge {
                    if let png = downscaledPngData(from: data, maxPixel: 4096) {
                        let newWrapper = FileWrapper(regularFileWithContents: png)
                        newWrapper.preferredFilename = encodeImageFilename(size: attachment.bounds.size, ext: "png")
                        attachment.fileWrapper = newWrapper
                        attachment.image = NSImage(data: png)
                    }
                }
            }
        }
        storage.endEditing()
    }

    private func updateTypingAttributesFromContent() {
        // If document has content, inherit attributes from it
        // Otherwise use default manuscript formatting
        guard let textStorage = textView.textStorage, textStorage.length > 0 else {
            applyDefaultTypingAttributes()
            return
        }

        // Prefer inheriting typing attributes from the first writer-facing paragraph style.
        // This avoids imported documents where the first paragraph is a title/heading (often no-indent)
        // from forcing the editor default into "Body Text – No Indent".
        let fullRange = NSRange(location: 0, length: textStorage.length)
        var preferredLocation: Int? = nil
        textStorage.enumerateAttribute(styleAttributeKey, in: fullRange, options: []) { value, range, stop in
            if let styleName = value as? String {
                if StyleCatalog.shared.isPoetryTemplate {
                    // Poetry docs should type in Verse by default.
                    if styleName == "Verse" || styleName == "Poetry — Verse" {
                        preferredLocation = range.location
                        stop.pointee = true
                    }
                } else if styleName == "Body Text" {
                preferredLocation = range.location
                stop.pointee = true
                }
            }
        }

        let attrs = textStorage.attributes(at: preferredLocation ?? 0, effectiveRange: nil)

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

    private func repairBodyTextIndentAfterLoadIfNeeded() {
        guard let storage = textView.textStorage, storage.length > 0 else { return }
        let bodyNames: [String] = ["Body Text", "Body Text – No Indent", "Dialogue"]
        let definitions = Dictionary(uniqueKeysWithValues: bodyNames.compactMap { name in
            StyleCatalog.shared.style(named: name).map { (name, $0) }
        })
        guard !definitions.isEmpty else { return }
        let fullString = storage.string as NSString

        storage.beginEditing()
        defer { storage.endEditing() }

        var location = 0
        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
            let attrs = storage.attributes(at: paragraphRange.location, effectiveRange: nil)
            let existingPara = (attrs[.paragraphStyle] as? NSParagraphStyle) ?? (textView.defaultParagraphStyle ?? NSParagraphStyle.default)
            let existingFont = (attrs[.font] as? NSFont) ?? (textView.font ?? NSFont.systemFont(ofSize: 12))
            let paragraphText = fullString.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)

            let currentStyleName = (attrs[styleAttributeKey] as? String)
                ?? inferStyle(font: existingFont, paragraphStyle: existingPara, text: paragraphText)

            // Only enforce for Body Text / No Indent / Dialogue.
            if let def = definitions[currentStyleName] {
                let catalogPara = paragraphStyle(from: def)

                let expectsIndent = catalogPara.firstLineHeadIndent > 0.5
                let hasIndent = existingPara.firstLineHeadIndent > 0.5

                var shouldEnforce = false
                if currentStyleName == "Body Text" || currentStyleName == "Dialogue" {
                    shouldEnforce = (!hasIndent && expectsIndent)
                } else if currentStyleName == "Body Text – No Indent" {
                    shouldEnforce = (hasIndent && !expectsIndent)
                }

                if shouldEnforce {
                    // Preserve alignment/textBlocks/tabStops via mergedParagraphStyle, but force indents to catalog.
                    let merged = mergedParagraphStyle(existing: existingPara, style: catalogPara)
                    if let mutable = merged.mutableCopy() as? NSMutableParagraphStyle {
                        mutable.headIndent = catalogPara.headIndent
                        mutable.firstLineHeadIndent = catalogPara.firstLineHeadIndent
                        mutable.tailIndent = catalogPara.tailIndent
                        storage.addAttribute(.paragraphStyle, value: mutable.copy() as! NSParagraphStyle, range: paragraphRange)
                        storage.addAttribute(styleAttributeKey, value: currentStyleName, range: paragraphRange)
                    }
                } else if currentStyleName == "Body Text" || currentStyleName == "Body Text – No Indent" || currentStyleName == "Dialogue" {
                    // Ensure the tag exists so DOCX export can preserve it via w:pStyle.
                    storage.addAttribute(styleAttributeKey, value: currentStyleName, range: paragraphRange)
                }
            }

            location = NSMaxRange(paragraphRange)
        }
    }

    private func setColumnOutlineVisible(_ visible: Bool, for table: NSTextTable, in range: NSRange) {
        guard let layoutManager = textView.layoutManager else { return }
        let outlineColor: NSColor = visible ? currentTheme.textColor.withAlphaComponent(0.15) : .clear
        let outlineWidth: CGFloat = visible ? 0.5 : 0.0

        layoutManager.ensureLayout(forCharacterRange: range)

        textView.textStorage?.enumerateAttribute(.paragraphStyle, in: range, options: []) { value, _, _ in
            guard let style = value as? NSParagraphStyle,
                  let blocks = style.textBlocks as? [NSTextTableBlock] else { return }
            for block in blocks where block.table === table {
                block.setBorderColor(outlineColor, for: .minX)
                block.setBorderColor(outlineColor, for: .maxX)
                block.setBorderColor(outlineColor, for: .minY)
                block.setBorderColor(outlineColor, for: .maxY)
                block.setWidth(outlineWidth, type: .absoluteValueType, for: .border, edge: .minX)
                block.setWidth(outlineWidth, type: .absoluteValueType, for: .border, edge: .maxX)
                block.setWidth(outlineWidth, type: .absoluteValueType, for: .border, edge: .minY)
                block.setWidth(outlineWidth, type: .absoluteValueType, for: .border, edge: .maxY)
            }
        }

        layoutManager.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
        layoutManager.invalidateDisplay(forCharacterRange: range)
        textView.needsDisplay = true
    }

    private func flashColumnOutline(for table: NSTextTable, in range: NSRange, duration: TimeInterval = 2.0) {
        let key = ObjectIdentifier(table)
        columnOutlineHideWorkItems[key]?.cancel()
        columnOutlineHideWorkItems[key] = nil

        setColumnOutlineVisible(true, for: table, in: range)

        let hide = DispatchWorkItem { [weak self] in
            self?.setColumnOutlineVisible(false, for: table, in: range)
            self?.columnOutlineHideWorkItems[key] = nil
        }
        columnOutlineHideWorkItems[key] = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: hide)
    }

    private func showPersistentColumnOutline(for table: NSTextTable, in range: NSRange) {
        let key = ObjectIdentifier(table)
        columnOutlineHideWorkItems[key]?.cancel()
        columnOutlineHideWorkItems[key] = nil
        persistentColumnOutline = (table: table, range: range)
        setColumnOutlineVisible(true, for: table, in: range)
    }

    private func clearPersistentColumnOutline() {
        guard let outline = persistentColumnOutline else { return }
        setColumnOutlineVisible(false, for: outline.table, in: outline.range)
        persistentColumnOutline = nil
    }

    private func applyDefaultTypingAttributes() {
        let defaultStyleName: String
        if StyleCatalog.shared.isScreenplayTemplate {
            // Screenplay defaults rely on non-1" margins (1.5" left, 1" right).
            // Apply these immediately so catalog-driven styles render with the correct baseline.
            applyScreenplayPageDefaultsIfNeeded()
            defaultStyleName = "Action"
        } else if StyleCatalog.shared.isPoetryTemplate {
            defaultStyleName = "Verse"
        } else {
            defaultStyleName = "Body Text"
        }

        if let definition = StyleCatalog.shared.style(named: defaultStyleName) {
            let paragraph = paragraphStyle(from: definition)
            let font = self.font(from: definition)
            textView.defaultParagraphStyle = paragraph
            textView.font = font

            var newTypingAttributes = textView.typingAttributes
            newTypingAttributes[.font] = font
            newTypingAttributes[.foregroundColor] = currentTheme.textColor
            newTypingAttributes[.paragraphStyle] = paragraph
            newTypingAttributes[styleAttributeKey] = defaultStyleName
            if let backgroundHex = definition.backgroundColorHex {
                newTypingAttributes[.backgroundColor] = color(fromHex: backgroundHex, fallback: .clear)
            } else {
                newTypingAttributes.removeValue(forKey: .backgroundColor)
            }
            textView.typingAttributes = newTypingAttributes
            refreshTypingAttributesUsingDefaultParagraphStyle()
            return
        }

        let neutralParagraph = NSMutableParagraphStyle()
        neutralParagraph.alignment = .left
        neutralParagraph.lineHeightMultiple = 2.0
        neutralParagraph.paragraphSpacing = 0
        neutralParagraph.firstLineHeadIndent = 36
        textView.defaultParagraphStyle = neutralParagraph

        let defaultFont = NSFont(name: "Times New Roman", size: 14) ?? NSFont.systemFont(ofSize: 14)
        var newTypingAttributes = textView.typingAttributes
        newTypingAttributes[.font] = defaultFont
        newTypingAttributes[.foregroundColor] = currentTheme.textColor
        newTypingAttributes[.paragraphStyle] = neutralParagraph
        newTypingAttributes[styleAttributeKey] = defaultStyleName
        textView.typingAttributes = newTypingAttributes
        refreshTypingAttributesUsingDefaultParagraphStyle()
    }

    private func detectAndRetagStyles(in attributed: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let fullString = mutable.string as NSString

        let currentTemplate = StyleCatalog.shared.currentTemplateName

        // Stateful screenplay inference when formatting is missing/ambiguous.
        var screenplayInTitlePage = true
        var screenplaySawTitleLine = false
        var screenplaySawAuthorLine = false
        var screenplayExpectingDialogue = false

        var location = 0
        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))

            // Get paragraph attributes
            let attrs = mutable.attributes(at: paragraphRange.location, effectiveRange: nil)

            // Get paragraph text to help with content-based style detection
            let paragraphText = fullString.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)

            // Plain-text and some conversions can arrive with missing font/paragraph style attributes.
            // Seed *only missing attributes* so rendering is stable, but do not force a style tag here.
            let defaultSeedStyleName: String
            if currentTemplate == "Screenplay" {
                defaultSeedStyleName = "Action"
            } else if currentTemplate == "Poetry" {
                // Poetry: Verse is the writer-facing style.
                defaultSeedStyleName = "Verse"
            } else {
                defaultSeedStyleName = "Body Text"
            }
            var effectiveFont = attrs[.font] as? NSFont
            var effectiveParagraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle

            if effectiveFont == nil || effectiveParagraphStyle == nil,
               let definition = StyleCatalog.shared.style(named: defaultSeedStyleName) {
                let seedParagraph = self.paragraphStyle(from: definition)
                let seedFont = self.font(from: definition)

                if effectiveParagraphStyle == nil {
                    mutable.addAttribute(.paragraphStyle, value: seedParagraph, range: paragraphRange)
                    effectiveParagraphStyle = seedParagraph
                }
                if effectiveFont == nil {
                    mutable.addAttribute(.font, value: seedFont, range: paragraphRange)
                    effectiveFont = seedFont
                }
                if attrs[.foregroundColor] == nil {
                    mutable.addAttribute(.foregroundColor, value: currentTheme.textColor, range: paragraphRange)
                }
            }

            guard let font = effectiveFont,
                  let paragraphStyle = effectiveParagraphStyle else {
                location = NSMaxRange(paragraphRange)
                continue
            }

            // If the paragraph already has a valid Quill style tag (common for our own imports),
            // trust it. This avoids ambiguous re-inference when multiple styles share identical
            // formatting (e.g., Screenplay sluglines vs action).
            let existingTaggedStyle = attrs[styleAttributeKey] as? String
            let styleName: String
            if let existingTaggedStyle,
               StyleCatalog.shared.style(named: existingTaggedStyle) != nil {
                styleName = existingTaggedStyle
            } else {
                if currentTemplate == "Screenplay" {
                    // Content-based screenplay inference (robust even when all paragraphs share the same formatting).
                    let trimmed = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let upper = trimmed.uppercased()

                    func isSlugline(_ upper: String) -> Bool {
                        let prefixes = ["INT.", "EXT.", "INT/EXT.", "EXT/INT.", "I/E.", "EST."]
                        return prefixes.first(where: { upper.hasPrefix($0) }) != nil
                    }

                    func isActHeading(_ upper: String) -> Bool {
                        let t = upper.trimmingCharacters(in: .whitespacesAndNewlines)
                        if t == "ACT" { return true }
                        if t.hasPrefix("ACT ") { return true }
                        return false
                    }

                    func isInsertLine(_ upper: String) -> Bool {
                        let t = upper.trimmingCharacters(in: .whitespacesAndNewlines)
                        return t.hasPrefix("INSERT")
                    }

                    func isSfxOrVO(_ upper: String) -> Bool {
                        let t = upper.trimmingCharacters(in: .whitespacesAndNewlines)
                        if t.hasPrefix("SFX") { return true }
                        if t.hasPrefix("SFX/") || t.hasPrefix("SFX -") || t.hasPrefix("SFX:") { return true }
                        if t.hasPrefix("VO") || t.hasPrefix("V.O.") || t.hasPrefix("V.O") { return true }
                        return false
                    }

                    func isParenthetical(_ trimmed: String) -> Bool {
                        trimmed.hasPrefix("(") && trimmed.contains(")")
                    }

                    func isTransition(_ upper: String) -> Bool {
                        if upper.hasSuffix("TO:") { return true }
                        let known = [
                            "CUT TO:", "SMASH CUT TO:", "DISSOLVE TO:", "MATCH CUT TO:",
                            "FADE IN:", "FADE OUT.", "FADE OUT:", "FADE TO BLACK.", "FADE TO BLACK:",
                            "WIPE TO:", "JUMP CUT TO:"
                        ]
                        if known.contains(upper) { return true }
                        if upper.count <= 30 && upper.hasSuffix(":") { return true }
                        return false
                    }

                    func isShot(_ upper: String) -> Bool {
                        let prefixes = [
                            "ANGLE ON", "CLOSE ON", "CLOSE-UP", "CU ", "WIDE SHOT", "ESTABLISHING", "CUTAWAY",
                            "POV", "TRACKING", "DOLLY", "PAN", "TILT", "OVER", "ON "
                        ]
                        return prefixes.first(where: { upper.hasPrefix($0) }) != nil
                    }

                    func isCharacter(_ trimmed: String, upper: String) -> Bool {
                        if isSlugline(upper) || isTransition(upper) || isInsertLine(upper) || isSfxOrVO(upper) || isShot(upper) { return false }
                        let plain = trimmed.trimmingCharacters(in: .whitespaces)
                        guard !plain.isEmpty, plain.count <= 35 else { return false }
                        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .'-()")
                        let scalars = plain.unicodeScalars
                        guard scalars.allSatisfy({ allowed.contains($0) }) else { return false }
                        guard scalars.contains(where: { CharacterSet.uppercaseLetters.contains($0) }) else { return false }
                        return plain == upper
                    }

                    if screenplayInTitlePage {
                        let bodyStart = isSlugline(upper) || isActHeading(upper) || isTransition(upper) || isInsertLine(upper) || isSfxOrVO(upper) || isShot(upper) || isCharacter(trimmed, upper: upper)
                        if bodyStart {
                            screenplayInTitlePage = false
                            screenplayExpectingDialogue = false
                        }
                    }

                    if trimmed.isEmpty {
                        styleName = "Action"
                        screenplayExpectingDialogue = false
                    } else if screenplayInTitlePage {
                        if isSlugline(upper) {
                            screenplayInTitlePage = false
                            screenplayExpectingDialogue = false
                            styleName = "Scene Heading"
                        } else {
                            let lower = trimmed.lowercased()
                            if lower.contains("contact") || lower.contains("@") || lower.contains("tel") || lower.contains("phone") {
                                styleName = "Action"
                            } else if lower.contains("draft") || lower.contains("copyright") || lower.contains("(c)") {
                                styleName = "Action"
                            } else if !screenplaySawTitleLine {
                                screenplaySawTitleLine = true
                                styleName = "Scene Heading"
                            } else if !screenplaySawAuthorLine {
                                screenplaySawAuthorLine = true
                                styleName = "Action"
                            } else {
                                styleName = "Action"
                            }
                        }
                    } else if isSlugline(upper) {
                        screenplayExpectingDialogue = false
                        styleName = "Scene Heading"
                    } else if isActHeading(upper) {
                        screenplayExpectingDialogue = false
                        styleName = "Scene Heading"
                    } else if isTransition(upper) {
                        screenplayExpectingDialogue = false
                        styleName = "Transition"
                    } else if isInsertLine(upper) {
                        screenplayExpectingDialogue = false
                        styleName = "Action"
                    } else if isSfxOrVO(upper) {
                        screenplayExpectingDialogue = false
                        styleName = "Action"
                    } else if isShot(upper) {
                        screenplayExpectingDialogue = false
                        styleName = "Action"
                    } else if isCharacter(trimmed, upper: upper) {
                        screenplayExpectingDialogue = true
                        styleName = "Character"
                    } else if screenplayExpectingDialogue && isParenthetical(trimmed) {
                        screenplayExpectingDialogue = true
                        styleName = "Parenthetical"
                    } else if screenplayExpectingDialogue {
                        styleName = "Dialogue"
                    } else {
                        styleName = "Action"
                    }
                } else {
                    // Infer style based on font, paragraph attributes, and text content
                    styleName = inferStyle(font: font, paragraphStyle: paragraphStyle, text: paragraphText)
                }
            }

            // Tag the paragraph with the style name
            mutable.addAttribute(styleAttributeKey, value: styleName, range: paragraphRange)

            // For TOC/Index entries, preserve ALL existing formatting (especially tab stops)
            // These have custom formatting that shouldn't be overwritten by catalog styles
            let preserveFormattingStyles = ["TOC Entry", "TOC Entry Level 1", "TOC Entry Level 2", "TOC Entry Level 3",
                                           "Index Entry", "Index Letter"]
            if preserveFormattingStyles.contains(styleName) {
                // Just tag it, don't modify any attributes
                location = NSMaxRange(paragraphRange)
                continue
            }

            if let definition = StyleCatalog.shared.style(named: styleName) {
                // Apply catalog style colors and formatting to make them visible immediately
                var catalogParagraph = self.paragraphStyle(from: definition)
                let catalogFont = self.font(from: definition)
                let textColor = self.color(fromHex: definition.textColorHex, fallback: currentTheme.textColor)
                let backgroundColor = definition.backgroundColorHex.flatMap { self.color(fromHex: $0, fallback: .clear) }

                // Industry-standard screenplay style names that need exact layout
                let screenplayStyles: Set<String> = [
                    "Scene Heading", "Action", "Character", "Parenthetical", "Dialogue", "Transition",
                    "Shot", "Montage", "Montage Header", "Montage Item", "Montage End",
                    "Series of Shots Header", "Series of Shots Item", "Series of Shots End",
                    "Flashback", "Back To Present",
                    "Intercut", "End Intercut",
                    "Act Break", "Chyron", "Lyrics",
                    "Insert", "On Screen", "Text Message", "Email",
                    "Note", "More", "Continued", "Title", "Author", "Contact", "Draft"
                ]

                // For Screenplay Action, spacingBefore is contextual (after Scene Heading/Dialogue).
                if currentTemplate == "Screenplay", styleName == "Action" {
                    let prevLoc = max(0, paragraphRange.location - 1)
                    let prevPara = prevLoc < fullString.length ? fullString.paragraphRange(for: NSRange(location: prevLoc, length: 0)) : NSRange(location: NSNotFound, length: 0)
                    let prevStyle = (prevPara.location != NSNotFound && prevPara.location < mutable.length)
                        ? (mutable.attribute(styleAttributeKey, at: prevPara.location, effectiveRange: nil) as? String)
                        : nil
                    let desiredBefore: CGFloat = (prevStyle == "Scene Heading" || prevStyle == "Dialogue") ? 12 : 0
                    if let mutableStyle = catalogParagraph.mutableCopy() as? NSMutableParagraphStyle {
                        mutableStyle.paragraphSpacingBefore = desiredBefore
                        catalogParagraph = mutableStyle.copy() as! NSParagraphStyle
                    }
                }

                // Screenplay styles are layout-sensitive; don't preserve imported/manual alignment overrides
                // that can accidentally center an entire document.
                let finalParagraph: NSParagraphStyle
                if currentTemplate == "Screenplay", screenplayStyles.contains(styleName) {
                    finalParagraph = catalogParagraph
                } else {
                    finalParagraph = mergedParagraphStyle(existing: paragraphStyle, style: catalogParagraph)
                }
                mutable.addAttribute(.paragraphStyle, value: finalParagraph, range: paragraphRange)

                // Apply font per run to preserve inline formatting (bold, italic, size changes)
                mutable.enumerateAttributes(in: paragraphRange, options: []) { attrs, runRange, _ in
                    // Merge style font with existing font to preserve inline changes
                    let existingFont = attrs[.font] as? NSFont
                    let finalFont: NSFont
                    if currentTemplate == "Screenplay", screenplayStyles.contains(styleName) {
                        finalFont = mergedScreenplayFont(existing: existingFont, style: catalogFont)
                    } else {
                        finalFont = mergedFont(existing: existingFont, style: catalogFont)
                    }
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

        // Tab + trailing page number(s) -> TOC or Index entry.
        // This is more reliable than font-based matching after DOCX round-trips.
        if trimmedText.contains("\t") {
            let parts = trimmedText.split(separator: "\t", omittingEmptySubsequences: false)
            if parts.count >= 2 {
                let lastPart = parts.last.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
                let digitsAndCommas = CharacterSet(charactersIn: "0123456789, ")
                if !lastPart.isEmpty && lastPart.unicodeScalars.allSatisfy({ digitsAndCommas.contains($0) }) {
                    // Prefer indentation as an Index indicator.
                    if paragraphStyle.firstLineHeadIndent > 10 || paragraphStyle.headIndent > 10 {
                        return "Index Entry"
                    }
                    if lastPart.contains(",") {
                        return "Index Entry"
                    }
                    return "TOC Entry"
                }
            }
        }

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

        var bestMatch: String = StyleCatalog.shared.isPoetryTemplate ? "Verse" : "Body Text"
        var bestScore: Int = -100

        let isItalic = fontTraits.contains(.italicFontMask)

        for name in styleNames {
            guard let style = StyleCatalog.shared.style(named: name) else { continue }

            // Skip Index/TOC styles in general matching - they should only be matched by content detection above
            let skipStyles = ["Index Letter", "Index Entry", "Index Title", "TOC Entry", "TOC Title",
                              "TOC Entry Level 1", "TOC Entry Level 2", "TOC Entry Level 3"]
            if skipStyles.contains(name) { continue }

            var score = 0

            // Indentation match (helps disambiguate styles with identical fonts, e.g. Body Text vs Body Text – No Indent)
            let expectedHeadIndent = style.headIndent
            let expectedFirstLineHeadIndent = style.headIndent + style.firstLineIndent
            let expectedTailIndent = style.tailIndent
            if abs(paragraphStyle.headIndent - expectedHeadIndent) < 0.5 {
                score += 12
            } else {
                score -= 4
            }
            if abs(paragraphStyle.firstLineHeadIndent - expectedFirstLineHeadIndent) < 0.5 {
                score += 12
            } else {
                score -= 4
            }
            if abs(paragraphStyle.tailIndent - expectedTailIndent) < 0.5 {
                score += 4
            }

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

        // Reset manuscript metadata (prevents leaking across documents)
        manuscriptTitle = "Untitled"
        manuscriptAuthor = "Author Name"

        // Clear all text
        textView.string = ""

        // Reset to template default formatting
        applyDefaultTypingAttributes()

        delegate?.textDidChange()
        updatePageCentering()

        // Ensure the new document starts at the top.
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        DispatchQueue.main.async { [weak self] in
            self?.scrollToTop()
        }
    }

    // MARK: - Efficient Text Insertion

    /// Insert plain text at the current selection, preserving the current typing attributes.
    func insertTextAtSelection(_ text: String) {
        guard let selectedRange = textView.selectedRanges.first?.rangeValue else { return }
        textView.insertText(text, replacementRange: selectedRange)
        textView.window?.makeFirstResponder(textView)
    }

    // MARK: - Page Breaks

    func insertPageBreak() {
        guard let storage = textView.textStorage else { return }

        let selection = textView.selectedRange()
        let insertionLocation = selection.location

        debugLog("📄 InsertPageBreak: selection=\(selection) storageLength=\(storage.length)")

        // Avoid inserting page breaks inside text tables.
        if storage.length > 0 {
            let styleIndex = max(0, min(insertionLocation, storage.length - 1))
            let paragraphStyle = (storage.attribute(.paragraphStyle, at: styleIndex, effectiveRange: nil) as? NSParagraphStyle)
                ?? (textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle)
                ?? textView.defaultParagraphStyle
                ?? NSParagraphStyle.default

            if !paragraphStyle.textBlocks.isEmpty {
                let alert = NSAlert()
                alert.messageText = "Page Break"
                alert.informativeText = "Page breaks can't be inserted inside tables."
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return
            }
        }

        let ns = storage.string as NSString
        let isLineBreakChar: (unichar) -> Bool = { ch in
            ch == 0x0A || ch == 0x0D || ch == 0x2029 || ch == 0x2028
        }

        let needsLeadingNewline: Bool = {
            guard insertionLocation > 0 else { return false }
            return !isLineBreakChar(ns.character(at: insertionLocation - 1))
        }()

        let needsTrailingNewline: Bool = {
            guard insertionLocation < ns.length else { return false }
            return !isLineBreakChar(ns.character(at: insertionLocation))
        }()

        let baseAttrs: [NSAttributedString.Key: Any] = {
            if storage.length == 0 { return textView.typingAttributes }
            let i = max(0, min(insertionLocation, storage.length - 1))
            return storage.attributes(at: i, effectiveRange: nil)
        }()

        let spacerParagraphStyle: NSParagraphStyle = {
            let style = (baseAttrs[.paragraphStyle] as? NSParagraphStyle)
                ?? textView.defaultParagraphStyle
                ?? NSParagraphStyle.default
            let mutable = (style.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            mutable.paragraphSpacing = 0
            mutable.paragraphSpacingBefore = 0
            mutable.lineSpacing = 0
            mutable.lineHeightMultiple = 1
            mutable.minimumLineHeight = 0
            mutable.maximumLineHeight = 0
            return mutable.copy() as! NSParagraphStyle
        }()

        var spacerAttrs = baseAttrs
        spacerAttrs[.paragraphStyle] = spacerParagraphStyle

        let block = NSMutableAttributedString()
        if needsLeadingNewline {
            block.append(NSAttributedString(string: "\n", attributes: spacerAttrs))
        }

        // Calculate height to fill the remainder of the page
        var spacerHeight: CGFloat = 300 // Fallback
        if let layoutManager = textView.layoutManager, let _ = textView.textContainer {
            let limitIndex = max(0, insertionLocation - 1)
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: limitIndex)
            let rect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

            if rect.height > 0 || insertionLocation == 0 {
                let safetyBuffer: CGFloat = 8.0
                let lineHeight = (rect.height > 0) ? rect.height : 14.0
                let insets = currentTextInsetsForPagination()

                var startY: CGFloat = insertionLocation == 0 ? 0 : rect.maxY
                if needsLeadingNewline {
                    startY += lineHeight
                }

                DebugLog.log("📄 PageBreakCalc: rectMaxY=\(rect.maxY) needsLeading=\(needsLeadingNewline) startY=\(startY)")

                let pHeight = pageHeight * editorZoom
                let pGap: CGFloat = 20
                let totalPageStride = pHeight + pGap
                let textAreaHeight = max(1.0, pHeight - insets.top - insets.bottom)

                let pageIndex = floor(startY / totalPageStride)
                let pageStartY = pageIndex * totalPageStride
                let offsetWithinPage = max(0, startY - pageStartY)

                DebugLog.log("📄 PageBreakCalc: pageIndex=\(pageIndex) pageStartY=\(pageStartY) offset=\(offsetWithinPage)")

                if offsetWithinPage < textAreaHeight {
                    let available = textAreaHeight - offsetWithinPage
                    spacerHeight = max(1.0, min(textAreaHeight, available - safetyBuffer))
                    DebugLog.log("📄 PageBreakCalc: available=\(available) spacer=\(spacerHeight)")
                } else {
                    spacerHeight = 1.0
                    DebugLog.log("📄 PageBreakCalc: Already past text area. Forced minimal spacer=\(spacerHeight)")
                }
            }
        }

        let attachment = makePageBreakAttachment(initialHeight: spacerHeight)
        let marker = NSMutableAttributedString(attachment: attachment)
        marker.addAttributes(spacerAttrs, range: NSRange(location: 0, length: 1))
        marker.addAttribute(.qpPageBreak, value: true, range: NSRange(location: 0, length: 1))
        block.append(marker)

        if needsTrailingNewline {
            block.append(NSAttributedString(string: "\n", attributes: spacerAttrs))
        }

        debugLog("📄 InsertPageBreak: blockLength=\(block.length) needsLeading=\(needsLeadingNewline) needsTrailing=\(needsTrailingNewline)")

        if !textView.shouldChangeText(in: selection, replacementString: block.string) {
            debugLog("📄 InsertPageBreak: shouldChangeText returned false")
            return
        }

        storage.beginEditing()
        storage.replaceCharacters(in: selection, with: block)
        storage.endEditing()
        textView.didChangeText()
        textView.undoManager?.setActionName("Insert Page Break")

        debugLog("📄 InsertPageBreak: after replace, storageLength=\(storage.length)")

        let newLoc = min(selection.location + block.length, storage.length)
        textView.setSelectedRange(NSRange(location: newLoc, length: 0))
        updatePageLayout()
    }

    // MARK: - Section Breaks

    private let sectionBreakAnchor = "\u{200B}"
    private let sectionBreakPersistenceScheme = "quillpilot"
    private let sectionBreakPersistenceHost = "section-break"

    func insertSectionBreak() {
        guard let storage = textView.textStorage else { return }
        let insertLocation = textView.selectedRange().location

        if let found = sectionBreak(inParagraphAt: insertLocation, in: storage) {
            promptForSectionBreak(defaultName: found.section.name, defaultStart: found.section.startPageNumber, defaultFormat: found.section.numberFormat, existing: found.section) { [weak self] updated, didRemove in
                guard let self else { return }
                if didRemove {
                    self.removeSectionBreak(in: storage, range: found.range)
                    return
                }
                guard let updated else { return }
                self.updateSectionBreak(in: storage, range: found.range, with: updated)
            }
            return
        }

        let nextIndex = sectionBreaks(in: storage).count + 1
        let defaultName = "Section \(nextIndex)"

        promptForSectionBreak(defaultName: defaultName, defaultStart: 1, defaultFormat: .arabic, existing: nil) { [weak self] section, _ in
            guard let self, let section else { return }

            self.insertSectionBreak(in: storage, at: insertLocation, section: section)

            textView.setSelectedRange(NSRange(location: insertLocation + 1, length: 0))
            delegate?.textDidChange()
        }
    }

    func sectionBreakInfos() -> [SectionBreakInfo] {
        guard let storage = textView.textStorage else { return [] }
        return sectionBreaks(in: storage).map { entry in
            SectionBreakInfo(
                id: entry.section.id,
                name: entry.section.name,
                startPageNumber: entry.section.startPageNumber,
                numberFormatDisplay: entry.section.numberFormat.rawValue,
                location: entry.range.location
            )
        }
    }

    @discardableResult
    func removeSectionBreak(withID id: String) -> Bool {
        guard let storage = textView.textStorage else { return false }
        guard let found = sectionBreaks(in: storage).first(where: { $0.section.id == id }) else { return false }
        removeSectionBreak(in: storage, range: found.range)
        return true
    }

    func goToSectionBreak(withID id: String) {
        guard let storage = textView.textStorage else { return }
        guard let found = sectionBreaks(in: storage).first(where: { $0.section.id == id }) else {
            NSSound.beep()
            return
        }
        textView.window?.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: found.range.location, length: 0))
        textView.scrollRangeToVisible(NSRange(location: found.range.location, length: 0))
    }

    func editSectionBreak(withID id: String) {
        goToSectionBreak(withID: id)
        DispatchQueue.main.async { [weak self] in
            self?.editSectionSettingsAtCursor()
        }
    }

    private func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func base64URLDecode(_ string: String) -> Data? {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = s.count % 4
        if remainder != 0 {
            s.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: s)
    }

    private func makeSectionBreakPersistenceURL(for section: SectionBreak) -> URL? {
        guard let data = try? JSONEncoder().encode(section) else { return nil }
        let token = base64URLEncode(data)
        var components = URLComponents()
        components.scheme = sectionBreakPersistenceScheme
        components.host = sectionBreakPersistenceHost
        components.path = "/" + token
        return components.url
    }

    private func decodeSectionBreak(fromPersistenceURL url: URL) -> SectionBreak? {
        guard url.scheme == sectionBreakPersistenceScheme,
              url.host == sectionBreakPersistenceHost else { return nil }
        let token = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !token.isEmpty,
              let data = base64URLDecode(token),
              let section = try? JSONDecoder().decode(SectionBreak.self, from: data) else { return nil }
        return section
    }

    private func injectSectionBreakPersistenceLinks(into attributed: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: attributed.length)
        attributed.enumerateAttribute(.qpSectionBreak, in: fullRange, options: []) { value, range, _ in
            guard let data = value as? Data,
                  let section = try? JSONDecoder().decode(SectionBreak.self, from: data),
                  let url = makeSectionBreakPersistenceURL(for: section) else { return }
            // Using a QuillPilot-only hyperlink makes the marker survive DOCX/RTF/ODT round-trips
            // without introducing visible placeholder characters in other editors.
            attributed.addAttribute(.link, value: url, range: range)
        }
    }

    private func restoreSectionBreaksFromPersistenceLinks(in attributed: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let fullRange = NSRange(location: 0, length: mutable.length)

        var matches: [(range: NSRange, section: SectionBreak)] = []
        mutable.enumerateAttribute(.link, in: fullRange, options: []) { value, range, _ in
            let url: URL?
            if let u = value as? URL {
                url = u
            } else if let s = value as? String {
                url = URL(string: s)
            } else {
                url = nil
            }
            guard let url, let section = decodeSectionBreak(fromPersistenceURL: url) else { return }
            matches.append((range, section))
        }

        guard !matches.isEmpty else { return mutable }

        // Apply in reverse so replacements don't invalidate later ranges.
        for match in matches.reversed() {
            let range = match.range
            let section = match.section

            var attrs = mutable.attributes(at: max(0, min(range.location, max(0, mutable.length - 1))), effectiveRange: nil)
            attrs[.link] = nil
            if let data = try? JSONEncoder().encode(section) {
                attrs[.qpSectionBreak] = data
            }
            // Keep it invisible.
            attrs[.foregroundColor] = NSColor.clear

            // Ensure the stored representation is our zero-width anchor.
            let current = (mutable.string as NSString).substring(with: range)
            if current != sectionBreakAnchor {
                let marker = NSAttributedString(string: sectionBreakAnchor, attributes: attrs)
                mutable.beginEditing()
                mutable.replaceCharacters(in: range, with: marker)
                mutable.endEditing()
            } else {
                mutable.beginEditing()
                mutable.setAttributes(attrs, range: range)
                mutable.endEditing()
            }
        }

        return mutable
    }

    private func restorePageBreakMarkersFromFormFeed(in attributed: NSAttributedString) -> NSAttributedString {
        guard attributed.length > 0 else { return attributed }
        guard (attributed.string as NSString).range(of: "\u{000C}").location != NSNotFound else { return attributed }

        let mutable = NSMutableAttributedString(attributedString: attributed)
        var searchLocation = 0

        while searchLocation < mutable.length {
            let current = mutable.string as NSString
            let r = current.range(
                of: "\u{000C}",
                options: [],
                range: NSRange(location: searchLocation, length: current.length - searchLocation)
            )
            if r.location == NSNotFound { break }

            let attrs = mutable.attributes(at: r.location, effectiveRange: nil)
            // Use a moderate default height for imported breaks since we can't measure layout yet
            let attachment = makePageBreakAttachment(initialHeight: 200)
            let marker = NSMutableAttributedString(attachment: attachment)
            marker.addAttributes(attrs, range: NSRange(location: 0, length: 1))
            marker.addAttribute(.qpPageBreak, value: true, range: NSRange(location: 0, length: 1))

            mutable.replaceCharacters(in: r, with: marker)
            searchLocation = r.location + 1
        }

        return mutable
    }

    private func makePageBreakAttachment(initialHeight: CGFloat) -> NSTextAttachment {
        let attachment = NSTextAttachment()
        // Use the requested height, or a safe default, capped to avoid infinite pagination.
        // We allow small spacers (down to 1pt) to avoid forcing a wrap when near the margin.
        // We cap at pageHeight to prevent "500 page" explosions.
        let safeHeight = min(max(1.0, initialHeight), (pageHeight * editorZoom))
        let cell = SpacerAttachmentCell(height: safeHeight)
        attachment.attachmentCell = cell
        attachment.bounds = NSRect(x: 0, y: 0, width: 0.1, height: safeHeight)
        return attachment
    }

    func editSectionSettingsAtCursor() {
        guard let storage = textView.textStorage else { return }
        let cursor = textView.selectedRange().location
        guard let found = sectionBreak(atOrBefore: cursor, in: storage) else {
            NSSound.beep()
            return
        }

        promptForSectionBreak(defaultName: found.section.name, defaultStart: found.section.startPageNumber, defaultFormat: found.section.numberFormat, existing: found.section) { [weak self] updated, didRemove in
            guard let self else { return }
            if didRemove {
                self.removeSectionBreak(in: storage, range: found.range)
                return
            }
            guard let updated else { return }
            self.updateSectionBreak(in: storage, range: found.range, with: updated)
        }
    }

    private func sectionBreaks(in storage: NSTextStorage) -> [(range: NSRange, section: SectionBreak)] {
        var results: [(NSRange, SectionBreak)] = []
        storage.enumerateAttribute(.qpSectionBreak, in: NSRange(location: 0, length: storage.length), options: []) { value, range, _ in
            guard let data = value as? Data,
                  let section = try? JSONDecoder().decode(SectionBreak.self, from: data) else { return }
            results.append((range, section))
        }
        return results.sorted(by: { (lhs: (range: NSRange, section: SectionBreak), rhs: (range: NSRange, section: SectionBreak)) in
            lhs.range.location < rhs.range.location
        })
    }

    private func sectionBreak(at location: Int, in storage: NSTextStorage) -> (range: NSRange, section: SectionBreak)? {
        guard storage.length > 0, location >= 0, location < storage.length else { return nil }
        var range = NSRange(location: 0, length: 0)
        guard let data = storage.attribute(.qpSectionBreak, at: location, effectiveRange: &range) as? Data,
              let section = try? JSONDecoder().decode(SectionBreak.self, from: data) else { return nil }
        return (range, section)
    }

    private func sectionBreak(inParagraphAt location: Int, in storage: NSTextStorage) -> (range: NSRange, section: SectionBreak)? {
        let safeLocation = max(0, min(location, max(0, storage.length - 1)))
        let paragraphRange = (storage.string as NSString).paragraphRange(for: NSRange(location: safeLocation, length: 0))
        var found: (range: NSRange, section: SectionBreak)?
        storage.enumerateAttribute(.qpSectionBreak, in: paragraphRange, options: []) { value, range, stop in
            if let data = value as? Data, let section = try? JSONDecoder().decode(SectionBreak.self, from: data) {
                found = (range, section)
                stop.pointee = true
            }
        }
        return found
    }

    private func insertSectionBreak(in storage: NSTextStorage, at location: Int, section: SectionBreak) {
        var existingAttrs: [NSAttributedString.Key: Any] = [:]
        if storage.length > 0 {
            // Prefer inheriting from the character AT the insertion location.
            // This prevents inserting a section break at the start of a styled paragraph
            // (e.g. Book Title) from inheriting the previous paragraph's (Body Text) style.
            let index: Int
            if location >= 0 && location < storage.length {
                index = location
            } else {
                index = max(0, min(location - 1, storage.length - 1))
            }
            existingAttrs = storage.attributes(at: index, effectiveRange: nil)
        }

        var attrs = existingAttrs
        if let data = try? JSONEncoder().encode(section) {
            attrs[.qpSectionBreak] = data
        }
        attrs[.foregroundColor] = NSColor.clear
        if attrs[.font] == nil {
            attrs[.font] = textView.font ?? NSFont.systemFont(ofSize: 12)
        }

        let marker = NSAttributedString(string: sectionBreakAnchor, attributes: attrs)
        storage.beginEditing()
        storage.insert(marker, at: location)
        storage.endEditing()

        textView.setSelectedRange(NSRange(location: location + 1, length: 0))
        delegate?.textDidChange()
    }

    private func updateSectionBreak(in storage: NSTextStorage, range: NSRange, with section: SectionBreak) {
        var attrs = storage.attributes(at: range.location, effectiveRange: nil)
        if let data = try? JSONEncoder().encode(section) {
            attrs[.qpSectionBreak] = data
        }
        attrs[.foregroundColor] = NSColor.clear
        if attrs[.font] == nil {
            attrs[.font] = textView.font ?? NSFont.systemFont(ofSize: 12)
        }

        let marker = NSAttributedString(string: sectionBreakAnchor, attributes: attrs)
        storage.beginEditing()
        storage.replaceCharacters(in: range, with: marker)
        storage.endEditing()
        delegate?.textDidChange()
    }

    private func removeSectionBreak(in storage: NSTextStorage, range: NSRange) {
        storage.beginEditing()
        storage.deleteCharacters(in: range)
        storage.endEditing()
        delegate?.textDidChange()
    }

    private func sectionBreak(atOrBefore location: Int, in storage: NSTextStorage) -> (range: NSRange, section: SectionBreak)? {
        let all = sectionBreaks(in: storage)
        let eligible = all.filter { $0.range.location <= location }
        return eligible.last
    }

    private func promptForSectionBreak(defaultName: String, defaultStart: Int, defaultFormat: SectionPageNumberFormat, existing: SectionBreak?, completion: @escaping (SectionBreak?, Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = existing == nil ? "Insert Section Break" : "Edit Section Settings"
        alert.informativeText = "Set the section name, page number start, and number format."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        if existing != nil {
            alert.addButton(withTitle: "Remove")
        }

        let nameField = NSTextField(string: defaultName)
        let startField = NSTextField(string: "\(defaultStart)")
        startField.formatter = NumberFormatter()

        let formatPopup = NSPopUpButton()
        SectionPageNumberFormat.allCases.forEach { formatPopup.addItem(withTitle: $0.rawValue) }
        formatPopup.selectItem(withTitle: defaultFormat.rawValue)

        let nameLabel = NSTextField(labelWithString: "Section name")
        let startLabel = NSTextField(labelWithString: "Start page number")
        let formatLabel = NSTextField(labelWithString: "Number format")

        let stack = NSStackView(views: [nameLabel, nameField, startLabel, startField, formatLabel, formatPopup])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.setCustomSpacing(6, after: nameLabel)
        stack.setCustomSpacing(6, after: startLabel)
        stack.setCustomSpacing(6, after: formatLabel)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 185))
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            nameField.widthAnchor.constraint(equalToConstant: 320),
            startField.widthAnchor.constraint(equalToConstant: 140),
            formatPopup.widthAnchor.constraint(equalToConstant: 220)
        ])

        alert.accessoryView = container

        // Apply theme to alert controls
        let theme = currentTheme
        [nameLabel, startLabel, formatLabel].forEach { label in
            label.textColor = theme.textColor
        }

        [nameField, startField].forEach { field in
            field.textColor = theme.textColor
            field.drawsBackground = true
            field.backgroundColor = theme.pageBackground
            field.wantsLayer = true
            field.layer?.borderColor = theme.pageBorder.cgColor
            field.layer?.borderWidth = 1
            field.layer?.cornerRadius = 5
            field.focusRingType = .none
        }

        for button in alert.buttons {
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.backgroundColor = theme.pageBackground.cgColor
            button.layer?.borderColor = theme.pageBorder.cgColor
            button.layer?.borderWidth = 1
            button.layer?.cornerRadius = 6
            button.contentTintColor = theme.textColor
            let font = button.font ?? NSFont.systemFont(ofSize: 13)
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [.foregroundColor: theme.textColor, .font: font]
            )
        }
        formatPopup.contentTintColor = theme.textColor
        formatPopup.qpApplyDropdownBorder(theme: theme)

        guard let window = textView.window else {
            completion(nil, false)
            return
        }

        alert.beginSheetModal(for: window) { response in
            if existing != nil, response == .alertThirdButtonReturn {
                completion(nil, true)
                return
            }
            guard response == .alertFirstButtonReturn else {
                completion(nil, false)
                return
            }

            let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let startValue = Int(startField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? defaultStart
            let safeStart = max(1, startValue)

            let selectedFormat = SectionPageNumberFormat(rawValue: formatPopup.selectedItem?.title ?? "") ?? defaultFormat
            let section = SectionBreak(
                id: existing?.id ?? SectionBreak.newID(),
                name: name.isEmpty ? defaultName : name,
                startPageNumber: safeStart,
                numberFormat: selectedFormat
            )
            completion(section, false)
        }
    }

    /// Show the Insert Footnote dialog (Word-style structured footnotes).
    func insertFootnote() {
        showInsertNoteDialog(type: .footnote)
    }

    /// Show the Insert Endnote dialog (Word-style structured endnotes).
    func insertEndnote() {
        showInsertNoteDialog(type: .endnote)
    }

    /// Show the Insert Bookmark dialog (Word-style bookmark system).
    func insertBookmark() {
        showInsertBookmarkDialog()
    }

    /// Show the Insert Cross-reference dialog (Word-style field reference).
    func insertCrossReference() {
        showInsertCrossReferenceDialog()
    }

    // MARK: - Bookmark Dialog

    func showInsertBookmarkDialog() {
        if bookmarkWindowController == nil {
            bookmarkWindowController = InsertBookmarkWindowController()
        }

        guard let controller = bookmarkWindowController else { return }
        controller.fieldsManager = fieldsManager

        controller.onInsert = { [weak self] name in
            self?.insertBookmarkAtCursor(named: name)
        }

        controller.onGoTo = { [weak self] bookmarkID in
            self?.goToBookmark(id: bookmarkID)
        }

        controller.onDelete = { [weak self] bookmarkID in
            self?.deleteBookmark(id: bookmarkID)
        }

        controller.reloadBookmarks()
        controller.refreshTheme()
        presentUtilityWindow(controller.window)
    }

    /// Insert a bookmark anchor at the current cursor position.
    private func insertBookmarkAtCursor(named name: String) {
        guard let storage = textView.textStorage else { return }
        let location = textView.selectedRange().location

        // Create the bookmark in the fields manager
        let bookmark = fieldsManager.createBookmark(name: name, type: .bookmark)

        // Get existing attributes at the insertion point to preserve paragraph style
        var existingAttrs: [NSAttributedString.Key: Any] = [:]
        if location > 0 && location <= storage.length {
            existingAttrs = storage.attributes(at: max(0, location - 1), effectiveRange: nil)
        } else if storage.length > 0 {
            existingAttrs = storage.attributes(at: 0, effectiveRange: nil)
        }

        // Insert an invisible anchor character with bookmark attributes
        // We use a zero-width space as the anchor
        let anchorChar = "\u{200B}"

        // Start with existing attributes to preserve paragraph style
        var attrs = existingAttrs
        // Add bookmark-specific attributes
        attrs[.qpBookmarkID] = bookmark.id
        attrs[.qpBookmarkName] = bookmark.name
        attrs[.foregroundColor] = NSColor.clear
        // Keep existing font if available, otherwise use default
        if attrs[.font] == nil {
            attrs[.font] = textView.font ?? NSFont.systemFont(ofSize: 12)
        }

        let anchorString = NSAttributedString(string: anchorChar, attributes: attrs)

        storage.beginEditing()
        storage.insert(anchorString, at: location)
        storage.endEditing()

        textView.setSelectedRange(NSRange(location: location + 1, length: 0))
        delegate?.textDidChange()

        DebugLog.log("Inserted bookmark '\(name)' with ID \(bookmark.id) at location \(location)")
    }

    /// Navigate to a bookmark by ID.
    private func goToBookmark(id: String) {
        guard let location = fieldsManager.findBookmarkLocation(id: id) else {
            NSSound.beep()
            return
        }
        textView.setSelectedRange(NSRange(location: location, length: 0))
        textView.scrollRangeToVisible(NSRange(location: location, length: 1))
        textView.window?.makeFirstResponder(textView)
    }

    /// Delete a bookmark by ID.
    private func deleteBookmark(id: String) {
        guard let storage = textView.textStorage else { return }

        // Find and remove the bookmark anchor from the text
        var rangeToDelete: NSRange?
        storage.enumerateAttribute(.qpBookmarkID, in: NSRange(location: 0, length: storage.length), options: []) { value, range, stop in
            if let bookmarkID = value as? String, bookmarkID == id {
                rangeToDelete = range
                stop.pointee = true
            }
        }

        if let range = rangeToDelete {
            storage.beginEditing()
            storage.deleteCharacters(in: range)
            storage.endEditing()
            delegate?.textDidChange()
        }

        // Remove from fields manager
        fieldsManager.removeBookmark(id: id)

        DebugLog.log("Deleted bookmark with ID \(id)")
    }

    // MARK: - Cross-Reference Dialog

    func showInsertCrossReferenceDialog() {
        if crossReferenceWindowController == nil {
            crossReferenceWindowController = InsertCrossReferenceWindowController()
        }

        guard let controller = crossReferenceWindowController else { return }
        controller.fieldsManager = fieldsManager

        controller.onInsert = { [weak self] field, target in
            self?.insertCrossReferenceField(field, target: target)
        }

        controller.reloadTargets()
        controller.refreshTheme()
        presentUtilityWindow(controller.window)
    }

    /// Insert a cross-reference field at the current cursor position.
    private func insertCrossReferenceField(_ field: CrossReferenceField, target: BookmarkTarget) {
        guard let storage = textView.textStorage else { return }
        let insertLocation = textView.selectedRange().location

        // Resolve the initial display text
        let displayText = fieldsManager.resolveField(field, referenceLocation: insertLocation) { [weak self] charPos in
            self?.getPageNumber(forCharacterPosition: charPos)
        }

        // Encode the field data
        guard let fieldData = field.encode() else {
            DebugLog.log("Failed to encode cross-reference field")
            return
        }

        // Get existing attributes at the insertion point to preserve paragraph style
        var existingAttrs: [NSAttributedString.Key: Any] = [:]
        if insertLocation > 0 && insertLocation <= storage.length {
            existingAttrs = storage.attributes(at: max(0, insertLocation - 1), effectiveRange: nil)
        } else if storage.length > 0 {
            existingAttrs = storage.attributes(at: 0, effectiveRange: nil)
        }

        // Build attributes for the field, preserving paragraph style
        var attrs = existingAttrs
        attrs[.qpCrossReferenceField] = fieldData
        attrs[.foregroundColor] = field.isHyperlink ? NSColor.linkColor : currentTheme.textColor
        // Keep existing font if available, otherwise use default
        if attrs[.font] == nil {
            attrs[.font] = textView.font ?? NSFont.systemFont(ofSize: 12)
        }

        if field.isHyperlink {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        let fieldString = NSAttributedString(string: displayText, attributes: attrs)

        storage.beginEditing()
        storage.insert(fieldString, at: insertLocation)
        storage.endEditing()

        textView.setSelectedRange(NSRange(location: insertLocation + displayText.count, length: 0))
        delegate?.textDidChange()

        DebugLog.log("Inserted cross-reference to '\(target.name)' displaying '\(displayText)'")
    }

    /// Update all cross-reference fields in the document.
    func updateFields() {
        fieldsManager.updateAllFields { [weak self] charPos in
            guard let self else { return nil }
            return self.getPageNumber(forCharacterPosition: charPos)
        }
        // Also update note markers
        notesManager.updateAllNoteMarkers()
        delegate?.textDidChange()
        DebugLog.log("Updated all fields and note markers")
    }

    // MARK: - Footnote/Endnote Dialog

    func showInsertNoteDialog(type: NoteType) {
        let controller: InsertNoteWindowController

        switch type {
        case .footnote:
            if footnoteWindowController == nil {
                footnoteWindowController = InsertNoteWindowController(noteType: .footnote)
            }
            controller = footnoteWindowController!
        case .endnote:
            if endnoteWindowController == nil {
                endnoteWindowController = InsertNoteWindowController(noteType: .endnote)
            }
            controller = endnoteWindowController!
        }

        controller.notesManager = notesManager

        controller.onInsert = { [weak self] content in
            self?.insertNoteAtCursor(type: type, content: content)
        }

        controller.onGoTo = { [weak self] noteID in
            self?.goToNote(id: noteID)
        }

        controller.onDelete = { [weak self] noteID in
            self?.deleteNote(id: noteID)
        }

        controller.onConvert = { [weak self] noteID in
            self?.convertNote(id: noteID, from: type)
        }

        controller.reloadNotes()
        controller.refreshTheme()
        presentUtilityWindow(controller.window)
    }

    private func presentUtilityWindow(_ window: NSWindow?) {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.level = .floating
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    /// Insert a footnote or endnote at the current cursor position.
    private func insertNoteAtCursor(type: NoteType, content: String) {
        guard let storage = textView.textStorage else { return }
        let location = textView.selectedRange().location

        // Create the note in the notes manager
        let note: Note
        switch type {
        case .footnote:
            note = notesManager.createFootnote(content: content)
        case .endnote:
            note = notesManager.createEndnote(content: content)
        }

        // Get the marker text
        let marker: String
        switch type {
        case .footnote:
            marker = notesManager.footnoteMarker(for: note.id)
        case .endnote:
            marker = notesManager.endnoteMarker(for: note.id)
        }

        // Build attributes for the note reference (superscript)
        let baseFont = textView.font ?? NSFont.systemFont(ofSize: 12)
        let smallerFont = NSFontManager.shared.convert(baseFont, toSize: baseFont.pointSize * 0.7)

        let attrs: [NSAttributedString.Key: Any] = [
            type.attributeKey: note.id,
            .font: smallerFont,
            .foregroundColor: currentTheme.textColor,
            .baselineOffset: 6  // Superscript
        ]

        let markerString = NSAttributedString(string: marker, attributes: attrs)

        storage.beginEditing()
        storage.insert(markerString, at: location)
        storage.endEditing()

        textView.setSelectedRange(NSRange(location: location + marker.count, length: 0))
        delegate?.textDidChange()

        DebugLog.log("Inserted \(type.rawValue) '\(note.id)' with marker '\(marker)' at location \(location)")

        // Refresh the notes list in the dialog if open
        switch type {
        case .footnote:
            footnoteWindowController?.reloadNotes()
        case .endnote:
            endnoteWindowController?.reloadNotes()
        }
    }

    /// Navigate to a note reference by ID.
    private func goToNote(id: String) {
        guard let location = notesManager.findNoteReferenceLocation(id: id) else {
            NSSound.beep()
            return
        }
        textView.setSelectedRange(NSRange(location: location, length: 0))
        textView.scrollRangeToVisible(NSRange(location: location, length: 1))
        textView.window?.makeFirstResponder(textView)
    }

    /// Delete a note by ID.
    private func deleteNote(id: String) {
        notesManager.deleteNote(id: id)
        delegate?.textDidChange()
        DebugLog.log("Deleted note with ID \(id)")

        // Update all remaining note markers to renumber
        notesManager.updateAllNoteMarkers()
    }

    /// Convert a note between footnote and endnote.
    private func convertNote(id: String, from type: NoteType) {
        switch type {
        case .footnote:
            notesManager.convertFootnoteToEndnote(id: id)
            // Update markers
            notesManager.updateAllNoteMarkers()
            footnoteWindowController?.reloadNotes()
        case .endnote:
            notesManager.convertEndnoteToFootnote(id: id)
            // Update markers
            notesManager.updateAllNoteMarkers()
            endnoteWindowController?.reloadNotes()
        }
        delegate?.textDidChange()
        DebugLog.log("Converted note \(id) from \(type.rawValue)")
    }

    /// Toggle superscript on the selection (or typing attributes if no selection).
    func toggleSuperscript() {
        toggleBaselineOffset(desiredOffset: +6)
    }

    /// Toggle subscript on the selection (or typing attributes if no selection).
    func toggleSubscript() {
        toggleBaselineOffset(desiredOffset: -6)
    }

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

        // Find all ranges of invisible characters
        var allRanges: [(range: NSRange, name: String)] = []

        for (char, name) in invisibleChars {
            var searchRange = NSRange(location: 0, length: text.count)
            while searchRange.location < text.count {
                let foundRange = (text as NSString).range(of: char, options: [], range: searchRange)
                if foundRange.location != NSNotFound {
                    allRanges.append((foundRange, name))
                    searchRange.location = foundRange.location + foundRange.length
                    searchRange.length = text.count - searchRange.location
                } else {
                    break
                }
            }
        }

        if allRanges.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.showThemedAlert(title: "Document Clean", message: "No invisible characters found in document.")
            }
            return
        }

        // Sort ranges from back to front so we can delete without invalidating indices
        allRanges.sort { $0.range.location > $1.range.location }

        // Count by type for the report
        var foundChars: [String: Int] = [:]
        for (_, name) in allRanges {
            foundChars[name, default: 0] += 1
        }

        let savedSelection = textView.selectedRange()
        suppressTextChangeNotifications = true

        // Remove characters one at a time from back to front - this preserves all formatting
        textStorage.beginEditing()
        for (range, _) in allRanges {
            textStorage.deleteCharacters(in: range)
        }
        textStorage.endEditing()

        // Restore selection (adjust if necessary)
        let newLocation = min(savedSelection.location, textStorage.length)
        textView.setSelectedRange(NSRange(location: newLocation, length: 0))

        suppressTextChangeNotifications = false

        delegate?.textDidChange()
        updatePageCentering()

        // Show detailed report
        let totalRemoved = allRanges.count
        var report = "Removed \(totalRemoved) invisible character(s):\n\n"
        for (name, count) in foundChars.sorted(by: { $0.value > $1.value }) {
            report += "• \(count) \(name)\n"
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let alert = NSAlert.themedInformational(title: "Invisible Characters Removed", message: report)
            if let window = self.view.window {
                alert.runThemedSheet(for: window)
            } else {
                _ = alert.runThemedModal()
            }
        }
    }

    @objc func qpRemoveHiddenText(_ sender: Any?) {
        removeHiddenText()
    }

    /// Remove hidden/invisible text runs.
    ///
    /// This is broader than `removeInvisibleCharacters()`:
    /// - Deletes common zero-width/invisible Unicode characters.
    /// - Deletes any ranges explicitly hidden by `.foregroundColor = .clear` (used by some importers and anchors).
    func removeHiddenText() {
        guard let textStorage = textView.textStorage else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        guard fullRange.length > 0 else {
            NSSound.beep()
            return
        }

        let text = textStorage.string

        // 1) Find invisible/problematic unicode characters.
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

        var rangesToDelete: [(range: NSRange, name: String)] = []

        for (char, name) in invisibleChars {
            var searchRange = NSRange(location: 0, length: (text as NSString).length)
            while searchRange.location < (text as NSString).length {
                let foundRange = (text as NSString).range(of: char, options: [], range: searchRange)
                if foundRange.location != NSNotFound {
                    rangesToDelete.append((foundRange, name))
                    let nextLocation = foundRange.location + foundRange.length
                    searchRange = NSRange(location: nextLocation, length: (text as NSString).length - nextLocation)
                } else {
                    break
                }
            }
        }

        // 2) Find explicitly hidden runs (foreground is clear / fully transparent).
        textStorage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            guard let color = value as? NSColor else { return }
            if color.alphaComponent <= 0.01 {
                rangesToDelete.append((range, "Hidden Text"))
            }
        }

        if rangesToDelete.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.showThemedAlert(title: "No Hidden Text Found", message: "No hidden/invisible text was detected in this document.")
            }
            return
        }

        // Merge overlaps/adjacent ranges to avoid double deletes.
        let sorted = rangesToDelete
            .map { ($0.range, $0.name) }
            .sorted(by: { $0.0.location < $1.0.location })

        var merged: [(range: NSRange, names: [String])] = []
        for (range, name) in sorted {
            if let last = merged.last {
                let lastEnd = last.range.location + last.range.length
                if range.location <= lastEnd {
                    let newEnd = max(lastEnd, range.location + range.length)
                    let newRange = NSRange(location: last.range.location, length: newEnd - last.range.location)
                    var newNames = last.names
                    newNames.append(name)
                    merged[merged.count - 1] = (newRange, newNames)
                } else {
                    merged.append((range, [name]))
                }
            } else {
                merged.append((range, [name]))
            }
        }

        // Delete back-to-front.
        let savedSelection = textView.selectedRange()
        suppressTextChangeNotifications = true

        textStorage.beginEditing()
        for (range, _) in merged.sorted(by: { $0.range.location > $1.range.location }) {
            textStorage.deleteCharacters(in: range)
        }
        textStorage.endEditing()

        let newLocation = min(savedSelection.location, textStorage.length)
        textView.setSelectedRange(NSRange(location: newLocation, length: 0))

        suppressTextChangeNotifications = false
        delegate?.textDidChange()
        updatePageCentering()

        // Report
        let totalRemoved = merged.reduce(0) { $0 + $1.range.length }
        var counts: [String: Int] = [:]
        for (_, names) in merged {
            for n in Set(names) {
                counts[n, default: 0] += 1
            }
        }
        var report = "Removed \(totalRemoved) hidden character(s).\n\n"
        for (name, count) in counts.sorted(by: { $0.value > $1.value }) {
            report += "• \(count) block(s) matched: \(name)\n"
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let alert = NSAlert.themedInformational(title: "Hidden Text Removed", message: report)
            if let window = self.view.window {
                alert.runThemedSheet(for: window)
            } else {
                _ = alert.runThemedModal()
            }
        }
    }

    /// Remove extra blank lines between paragraphs
    func removeExtraBlankLines() {
        guard let textStorage = textView.textStorage else { return }

        let text = textStorage.string
        var rangesToDelete: [NSRange] = []

        // Debug: Count different line break types
        let newlineCount = text.components(separatedBy: "\n").count - 1
        let crCount = text.components(separatedBy: "\r").count - 1
        let paragraphSepCount = text.components(separatedBy: "\u{2029}").count - 1
        let lineSepCount = text.components(separatedBy: "\u{2028}").count - 1

        DebugLog.log("DEBUG: Document has \(newlineCount) newlines, \(crCount) carriage returns, \(paragraphSepCount) paragraph separators, \(lineSepCount) line separators")

        // Try multiple patterns to catch different types of blank lines
        // Pattern 1: Standard newlines with optional whitespace
        // Pattern 2: Carriage returns
        // Pattern 3: Unicode paragraph/line separators
        let patterns = [
            "(\\n[ \\t]*){2,}",           // 2+ newlines with optional whitespace (reduce to 1)
            "(\\r\\n?[ \\t]*){2,}",       // 2+ carriage returns with optional whitespace
            "(\\u2029[ \\t]*){2,}",       // 2+ paragraph separators
            "(\\u2028[ \\t]*){2,}",       // 2+ line separators
            "\\n([ \\t]*\\n)+",           // newline followed by blank lines
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.count))
            DebugLog.log("DEBUG: Pattern '\(pattern)' found \(matches.count) matches")

            for match in matches {
                // Keep only 1 line break, delete the rest
                if match.range.length > 1 {
                    let deleteStart = match.range.location + 1
                    let deleteLength = match.range.length - 1
                    // Avoid duplicate ranges
                    let newRange = NSRange(location: deleteStart, length: deleteLength)
                    if !rangesToDelete.contains(where: { NSIntersectionRange($0, newRange).length > 0 }) {
                        rangesToDelete.append(newRange)
                    }
                }
            }
        }

        DebugLog.log("DEBUG: Total ranges to delete: \(rangesToDelete.count)")

        if rangesToDelete.isEmpty {
            // Show what characters are around visible blank areas
            var debugInfo = "Document analysis:\n"
            debugInfo += "• \(newlineCount) newlines (\\n)\n"
            debugInfo += "• \(crCount) carriage returns (\\r)\n"
            debugInfo += "• \(paragraphSepCount) paragraph separators\n"
            debugInfo += "• \(lineSepCount) line separators\n\n"
            debugInfo += "The blank space may be caused by paragraph styling (spacing before/after paragraphs) rather than actual blank lines."

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let alert = NSAlert.themedInformational(title: "No Extra Blank Lines Found", message: debugInfo)
                if let window = self.view.window {
                    alert.runThemedSheet(for: window)
                } else {
                    _ = alert.runThemedModal()
                }
            }
            return
        }

        // Sort ranges from back to front so indices remain valid
        rangesToDelete.sort { $0.location > $1.location }

        let savedSelection = textView.selectedRange()
        suppressTextChangeNotifications = true

        // Delete extra newlines from back to front to preserve formatting
        textStorage.beginEditing()
        for range in rangesToDelete {
            textStorage.deleteCharacters(in: range)
        }
        textStorage.endEditing()

        // Restore selection
        let newLocation = min(savedSelection.location, textStorage.length)
        textView.setSelectedRange(NSRange(location: newLocation, length: 0))

        suppressTextChangeNotifications = false

        delegate?.textDidChange()
        updatePageCentering()

        let totalRemoved = rangesToDelete.reduce(0) { $0 + $1.length }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let alert = NSAlert.themedInformational(
                title: "Extra Blank Lines Removed",
                message: "Removed \(totalRemoved) extra line break(s), reducing excessive spacing between paragraphs."
            )
            if let window = self.view.window {
                alert.runThemedSheet(for: window)
            } else {
                _ = alert.runThemedModal()
            }
        }
    }

    @objc func qpRemoveExtraBlankLines(_ sender: Any?) {
        removeExtraBlankLines()
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
                guard let self else { return }
                self.showThemedAlert(title: "No Invisible Characters", message: "No invisible characters were found in the document.")
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

        // Show dialog with option to remove or navigate
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.view.window else { return }
            let alert = NSAlert()
            alert.messageText = "Found \(ranges.count) Invisible Character(s)"
            alert.informativeText = "These characters have been highlighted in yellow with red underlines. They may cause cursor flashing or other display issues.\n\nYou can navigate to see them or remove them."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Go to First")
            alert.addButton(withTitle: "Remove All")
            alert.addButton(withTitle: "Keep Highlighting")
            alert.addButton(withTitle: "Cancel")

            alert.runThemedSheet(for: window) { response in
                if response == .alertFirstButtonReturn {
                    // Go to First - scroll to first invisible character
                    if let firstRange = ranges.first {
                        self.textView.setSelectedRange(firstRange)
                        self.textView.scrollRangeToVisible(firstRange)
                        self.textView.window?.makeFirstResponder(self.textView)
                    }
                } else if response == .alertSecondButtonReturn {
                    // Remove All - remove highlights first
                    textStorage.beginEditing()
                    for range in ranges {
                        textStorage.removeAttribute(.backgroundColor, range: range)
                        textStorage.removeAttribute(.underlineStyle, range: range)
                        textStorage.removeAttribute(.underlineColor, range: range)
                    }
                    textStorage.endEditing()

                    // Then remove the characters
                    self.removeInvisibleCharacters()
                } else if response == NSApplication.ModalResponse(rawValue: 1003) {
                    // Cancel (4th button) - remove highlights
                    textStorage.beginEditing()
                    for range in ranges {
                        textStorage.removeAttribute(.backgroundColor, range: range)
                        textStorage.removeAttribute(.underlineStyle, range: range)
                        textStorage.removeAttribute(.underlineColor, range: range)
                    }
                    textStorage.endEditing()
                }
                // If "Keep Highlighting" (3rd button) is selected, do nothing - leave highlights in place
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

                DebugLog.log("Format Painter activated - copied formatting")
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
        DebugLog.log("Format Painter deactivated")
    }

    private func applyFormatPainterToSelection() {
        guard formatPainterActive,
              let copiedAttrs = copiedAttributes,
              let selectedRange = textView.selectedRanges.first?.rangeValue,
              selectedRange.length > 0 else { return }

        performUndoableTextStorageEdit(in: selectedRange, actionName: "Format Painter") { storage in
            // Apply all copied attributes except attachments.
            for (key, value) in copiedAttrs {
                if key != .attachment {
                    storage.addAttribute(key, value: value, range: selectedRange)
                }
            }
        }

        DebugLog.log("Format Painter applied to selection")

        // Deactivate after one use
        deactivateFormatPainter()
    }

    func applyStyle(named styleName: String) {
        if StyleCatalog.shared.isPoetryTemplate && (styleName == "Stanza" || styleName == "Verse" || styleName == "Poetry — Stanza" || styleName == "Poetry — Verse") {
            guard let storage = textView.textStorage else { return }
            guard let selected = textView.selectedRanges.first?.rangeValue else { return }

            let canonical = "Stanza"

            // If the user selected a range, apply the canonical stanza style to that selection.
            if selected.length > 0 {
                let styledByCatalog = applyCatalogStyle(named: canonical)
                if styledByCatalog {
                    applyStyleAttribute(canonical)
                }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name("QuillPilotOutlineRefresh"), object: nil)
                }
                return
            }

            let full = storage.string as NSString
            if full.length == 0 { return }
            if selected.location >= full.length { return }

            func paragraphRange(at location: Int) -> NSRange {
                let clamped = max(0, min(location, max(0, full.length - 1)))
                return full.paragraphRange(for: NSRange(location: clamped, length: 0))
            }

            func isStanzaSeparator(_ paragraphRange: NSRange) -> Bool {
                let raw = full.substring(with: paragraphRange)
                if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
                let style = storage.attribute(styleAttributeKey, at: paragraphRange.location, effectiveRange: nil) as? String
                return style == "Poetry — Stanza Break"
            }

            // Find the first non-separator paragraph at/after insertion point.
            var startPara = paragraphRange(at: selected.location)
            var scanLoc = startPara.location
            while isStanzaSeparator(startPara) && NSMaxRange(startPara) < full.length {
                scanLoc = NSMaxRange(startPara)
                startPara = paragraphRange(at: scanLoc)
            }
            if isStanzaSeparator(startPara) {
                return
            }

            // Expand forward until blank line / stanza break.
            let start = startPara.location
            var end = NSMaxRange(startPara)
            var nextLoc = end
            while nextLoc < full.length {
                let nextPara = paragraphRange(at: nextLoc)
                if isStanzaSeparator(nextPara) { break }
                end = NSMaxRange(nextPara)
                nextLoc = end
            }
            let stanzaRange = NSRange(location: start, length: max(0, end - start))
            if stanzaRange.length == 0 { return }

            // Apply style to the whole stanza.
            textView.setSelectedRange(stanzaRange)
            let styledByCatalog = applyCatalogStyle(named: canonical)
            if styledByCatalog {
                applyStyleAttribute(canonical)
            }

            // Advance insertion point to the next stanza start.
            var afterLoc = end
            while afterLoc < full.length {
                let para = paragraphRange(at: afterLoc)
                if !isStanzaSeparator(para) { break }
                afterLoc = NSMaxRange(para)
            }
            textView.setSelectedRange(NSRange(location: min(afterLoc, full.length), length: 0))
            textView.window?.makeFirstResponder(textView)

            // Refresh stanza outline.
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("QuillPilotOutlineRefresh"), object: nil)
            }
            return
        }

        // Screenplay styles are layout-sensitive and depend on screenplay page margins.
        // `applyCatalogStyle` may return early (bypassing the Screenplay switch cases), so make
        // sure the page defaults are applied up-front.
        let screenplayStyles: Set<String> = [
            "Scene Heading", "Action", "Character", "Parenthetical", "Dialogue", "Transition",
            "Shot", "Montage", "Montage Header", "Montage Item", "Montage End",
            "Series of Shots Header", "Series of Shots Item", "Series of Shots End",
            "Flashback", "Back To Present",
            "Intercut", "End Intercut",
            "Act Break", "Chyron", "Lyrics",
            "Insert", "On Screen", "Text Message", "Email",
            "Note", "More", "Continued", "Title", "Author", "Contact", "Draft"
        ]
        if StyleCatalog.shared.isScreenplayTemplate, screenplayStyles.contains(styleName) {
            debugLog("🎬 applyStyle(\(styleName)) template=Screenplay margins(before)=L=\(leftPageMargin) R=\(rightPageMargin)")
            applyScreenplayPageDefaultsIfNeeded()
            debugLog("🎬 applyStyle(\(styleName)) template=Screenplay margins(after)=L=\(leftPageMargin) R=\(rightPageMargin)")
        }

        let styledByCatalog = applyCatalogStyle(named: styleName)
        if styledByCatalog {
            if styleName == "Book Title" || styleName == "Poem Title" || styleName == "Poetry — Title" {
                if let range = textView.selectedRanges.first?.rangeValue, range.length == 0 {
                    let paragraphRange = (textView.string as NSString).paragraphRange(for: range)
                    let titleText = (textView.string as NSString).substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !titleText.isEmpty {
                        delegate?.titleDidChange(titleText)
                    }
                }
            }

            if styleName == "Author Name" || styleName == "Poetry — Author" || styleName == "Poet Name" {
                if let range = textView.selectedRanges.first?.rangeValue, range.length == 0 {
                    let paragraphRange = (textView.string as NSString).paragraphRange(for: range)
                    let authorText = (textView.string as NSString).substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !authorText.isEmpty {
                        delegate?.authorDidChange(authorText)
                    }
                }
            }

            if StyleCatalog.shared.isScreenplayTemplate {
                normalizeScreenplayTextIfNeeded(for: styleName)
                if styleName == "Action" {
                    adjustScreenplayActionSpacingBeforeIfNeeded()
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
            if let range = textView.selectedRanges.first?.rangeValue, range.length == 0 {
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
        // "Dialogue" for prose templates uses StyleCatalog (which aliases to Body Text)
        // Screenplay "Dialogue" has specific formatting handled in the Screenplay section below
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

        // MARK: Screenplay (Industry Standard)

        // Title page styles
        case "Title":
            if StyleCatalog.shared.isScreenplayTemplate {
                applyScreenplayPageDefaultsIfNeeded()
                applyScreenplayParagraphStyle { style in
                    style.alignment = .center
                    style.firstLineHeadIndent = 0
                    style.headIndent = 0
                    style.tailIndent = 0
                    style.paragraphSpacingBefore = 144
                    style.paragraphSpacing = 24
                }
                applyScreenplayFont(bold: true)
            }
        case "Author":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .center
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 0
            }
            applyScreenplayFont()
        case "Contact":
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
        case "Draft":
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

        // Core screenplay elements
        case "Scene Heading":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "Action":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "Character":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 158.4
                style.headIndent = 158.4
                style.tailIndent = -129.6
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 0
            }
            applyScreenplayFont()
        case "Parenthetical":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 115.2
                style.headIndent = 115.2
                style.tailIndent = -129.6
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 0
            }
            applyScreenplayFont()
        case "Dialogue":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 72
                style.headIndent = 72
                style.tailIndent = -108
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "Transition":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .right
                style.firstLineHeadIndent = 288
                style.headIndent = 288
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 24
            }
            applyScreenplayFont()

        // Camera & special screenplay elements
        case "Shot":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "Montage":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "Montage Header":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "Montage Item":
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
        case "Montage End":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "Series of Shots Header":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "Series of Shots Item":
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
        case "Series of Shots End":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "Flashback":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "Back To Present":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "Intercut":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "End Intercut":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()

        // Other screenplay elements
        case "Act Break":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .center
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 36
                style.paragraphSpacing = 36
            }
            applyScreenplayFont(bold: true)
        case "Chyron":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "Insert":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "On Screen":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "On-Screen Text":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "Text Message":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 72
                style.headIndent = 72
                style.tailIndent = -108
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "Email":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 12
            }
            applyScreenplayFont()
        case "Lyrics":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 36
                style.headIndent = 36
                style.tailIndent = -36
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 0
            }
            applyScreenplayFont(italic: true)
        case "Note":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 12
            }
            applyScreenplayFont(italic: true)
        case "More":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 158
                style.headIndent = 158
                style.tailIndent = 0
                style.paragraphSpacingBefore = 0
                style.paragraphSpacing = 0
            }
            applyScreenplayFont()
        case "Continued":
            applyScreenplayPageDefaultsIfNeeded()
            applyScreenplayParagraphStyle { style in
                style.alignment = .left
                style.firstLineHeadIndent = 158
                style.headIndent = 158
                style.tailIndent = 0
                style.paragraphSpacingBefore = 0
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

        if let selected = textView.selectedRanges.first?.rangeValue {
            let paragraphRange = (textView.string as NSString).paragraphRange(for: selected)
            performUndoableTextStorageEdit(in: paragraphRange, actionName: "Apply Style") { storage in
                storage.addAttribute(styleAttributeKey, value: styleName, range: paragraphRange)
            }
        }
    }

    func getCurrentStyleName() -> String? {
        guard let storage = textView.textStorage,
                            let selected = textView.selectedRanges.first?.rangeValue else {
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

        // Group paragraph + font/color changes into a single undo step.
        let undoManager = textView.undoManager
        undoManager?.beginUndoGrouping()
        let previousSuppress = suppressUndoActionNames
        suppressUndoActionNames = true
        defer {
            suppressUndoActionNames = previousSuppress
            undoManager?.endUndoGrouping()
        }

        applyParagraphEditsToSelectedParagraphs { style in
            style.setParagraphStyle(paragraph)
        }

        // Apply font and color changes without overriding the paragraph style
        // (which was already applied with textBlocks preserved). Also avoid touching
        // {{index:...}} marker ranges so they remain invisible.
        if let storage = textView.textStorage {
            let selection = textView.selectedRange()
            let range = selection.length == 0 ? (textView.string as NSString).paragraphRange(for: selection) : selection
            let markerRanges = indexMarkerRanges(in: range, storage: storage)

            performUndoableTextStorageEdit(in: range, actionName: nil) { storage in
                for subrange in subrangesExcluding(markerRanges, from: range) {
                    storage.addAttribute(.font, value: font, range: subrange)
                    storage.addAttribute(.foregroundColor, value: textColor, range: subrange)
                    if let backgroundColor {
                        storage.addAttribute(.backgroundColor, value: backgroundColor, range: subrange)
                    } else {
                        storage.removeAttribute(.backgroundColor, range: subrange)
                    }
                }
            }
        }

        undoManager?.setActionName("Apply Style: \(styleName)")

        return true
    }

    private func paragraphStyle(from definition: StyleDefinition) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment(rawValue: definition.alignmentRawValue) ?? .left
        style.lineHeightMultiple = definition.lineHeightMultiple
        style.paragraphSpacingBefore = definition.spacingBefore
        style.paragraphSpacing = definition.spacingAfter
        style.headIndent = definition.headIndent
        style.firstLineHeadIndent = definition.headIndent + definition.firstLineIndent
        style.tailIndent = definition.tailIndent
        style.lineBreakMode = .byWordWrapping
        return style.copy() as! NSParagraphStyle
    }

    private func font(from definition: StyleDefinition) -> NSFont {
        var font = NSFont.quillPilotResolve(nameOrFamily: definition.fontName, size: definition.fontSize)
            ?? NSFont.systemFont(ofSize: definition.fontSize)
        if definition.isBold {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
        if definition.isItalic {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        // Apply professional typography features
        font = fontWithTypographyFeatures(font, fontName: definition.fontName, smallCaps: definition.useSmallCaps)
        return font
    }

    // MARK: - Professional Typography Features

    /// Enhances font with professional typography features (ligatures, kerning, OpenType)
    private func fontWithTypographyFeatures(_ baseFont: NSFont, fontName: String, smallCaps: Bool = false) -> NSFont {
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

        if smallCaps {
            // Best-effort small caps using OpenType features.
            // Include both lower and upper case selectors so "Argument" can be typed naturally.
            features.append([
                .typeIdentifier: kLowerCaseType,
                .selectorIdentifier: kLowerCaseSmallCapsSelector
            ])
            features.append([
                .typeIdentifier: kUpperCaseType,
                .selectorIdentifier: kUpperCaseSmallCapsSelector
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

    private func effectiveSelectionOrParagraphRange() -> NSRange? {
        guard let storage = textView.textStorage, storage.length > 0 else { return nil }

        let selected = textView.selectedRange()
        if selected.location != NSNotFound, selected.length > 0 {
            return NSRange(location: selected.location, length: min(selected.length, storage.length - selected.location))
        }

        let paragraph = (textView.string as NSString).paragraphRange(for: selected)
        guard paragraph.location != NSNotFound, paragraph.length > 0 else { return nil }
        return NSRange(location: paragraph.location, length: min(paragraph.length, storage.length - paragraph.location))
    }

    private func registerAttributedUndo(for range: NSRange, before: NSAttributedString, actionName: String) {
        guard let undoManager = textView.undoManager else { return }

        undoManager.registerUndo(withTarget: self) { target in
            guard let storage = target.textView.textStorage else { return }
            storage.beginEditing()
            storage.replaceCharacters(in: range, with: before)
            storage.endEditing()
            target.textView.didChangeText()
        }
        undoManager.setActionName(actionName)
    }

    private func fontByAddingFeature(_ font: NSFont, typeIdentifier: Int, selectorIdentifier: Int) -> NSFont {
        var features = font.fontDescriptor.object(forKey: .featureSettings) as? [[NSFontDescriptor.FeatureKey: Int]] ?? []

        // Remove any existing entry for this feature type to avoid duplicates.
        features.removeAll(where: { $0[.typeIdentifier] == typeIdentifier })
        features.append([
            .typeIdentifier: typeIdentifier,
            .selectorIdentifier: selectorIdentifier
        ])

        let descriptor = font.fontDescriptor.addingAttributes([.featureSettings: features])
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
    }

    private func bestKerningFeature(for font: NSFont) -> (typeIdentifier: Int, selectorIdentifier: Int)? {
        // Prefer Optical Kerning when available; otherwise fall back to any explicit Kerning "On" selector.
        guard let raw = CTFontCopyFeatures(font as CTFont) as? [[CFString: Any]] else { return nil }

        func intValue(_ any: Any?) -> Int? {
            if let i = any as? Int { return i }
            if let n = any as? NSNumber { return n.intValue }
            return nil
        }

        for feature in raw {
            let typeName = (feature[kCTFontFeatureTypeNameKey] as? String) ?? ""
            let typeId = intValue(feature[kCTFontFeatureTypeIdentifierKey])

            let isKerningType = typeName.localizedCaseInsensitiveContains("kern") || typeName.localizedCaseInsensitiveContains("kerning")
            guard isKerningType, let typeIdentifier = typeId else { continue }

            let selectors = feature[kCTFontFeatureTypeSelectorsKey] as? [[CFString: Any]] ?? []

            var optical: Int?
            var on: Int?

            for selector in selectors {
                let selectorName = (selector[kCTFontFeatureSelectorNameKey] as? String) ?? ""
                let selectorId = intValue(selector[kCTFontFeatureSelectorIdentifierKey])
                guard let selectorIdentifier = selectorId else { continue }

                if selectorName.localizedCaseInsensitiveContains("optical") {
                    optical = selectorIdentifier
                }
                if selectorName.localizedCaseInsensitiveContains("on") {
                    on = selectorIdentifier
                }
            }

            if let optical {
                return (typeIdentifier, optical)
            }
            if let on {
                return (typeIdentifier, on)
            }
        }

        return nil
    }

    /// Apply optical kerning to selection or entire document
    func applyOpticalKerning(to range: NSRange? = nil) {
        guard let storage = textView.textStorage else { return }
        guard let targetRange = range ?? effectiveSelectionOrParagraphRange() else { return }

        let before = storage.attributedSubstring(from: targetRange)
        registerAttributedUndo(for: targetRange, before: before, actionName: "Apply Optical Kerning")

        storage.beginEditing()
        storage.enumerateAttribute(.font, in: targetRange) { value, subrange, _ in
            guard let font = value as? NSFont else { return }
            if let f = bestKerningFeature(for: font) {
                let newFont = fontByAddingFeature(font, typeIdentifier: f.typeIdentifier, selectorIdentifier: f.selectorIdentifier)
                storage.addAttribute(.font, value: newFont, range: subrange)
            }
        }
        storage.endEditing()
        textView.didChangeText()
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

        let before = storage.attributedSubstring(from: firstCharRange)
        registerAttributedUndo(for: firstCharRange, before: before, actionName: "Apply Drop Cap")

        storage.beginEditing()
        storage.addAttribute(.font, value: dropCapFont, range: firstCharRange)
        storage.addAttribute(.baselineOffset, value: -(dropCapSize * 0.2), range: firstCharRange)
        storage.endEditing()
        textView.didChangeText()
    }

    /// Enable OpenType features for old-style numerals
    func applyOldStyleNumerals(to range: NSRange? = nil) {
        guard let storage = textView.textStorage else { return }
        guard let targetRange = range ?? effectiveSelectionOrParagraphRange() else { return }

        let before = storage.attributedSubstring(from: targetRange)
        registerAttributedUndo(for: targetRange, before: before, actionName: "Use Old-Style Numerals")

        storage.beginEditing()
        storage.enumerateAttribute(.font, in: targetRange) { value, subrange, _ in
            guard let font = value as? NSFont else { return }
            let newFont = fontByAddingFeature(font, typeIdentifier: kNumberCaseType, selectorIdentifier: kLowerCaseNumbersSelector)
            storage.addAttribute(.font, value: newFont, range: subrange)
        }
        storage.endEditing()
        textView.didChangeText()
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

    private func mergedScreenplayFont(existing existingFont: NSFont?, style styleFont: NSFont) -> NSFont {
        guard let existing = existingFont else { return styleFont }

        // Always use the screenplay style's family (e.g. Courier), but preserve bold/italic and size
        // that may be present on imported run spans.
        let existingTraits = NSFontManager.shared.traits(of: existing)
        var font = NSFontManager.shared.convert(styleFont, toSize: existing.pointSize)
        if existingTraits.contains(.boldFontMask) {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
        if existingTraits.contains(.italicFontMask) {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        return font
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

        // Preserve custom tab stops (used for TOC/Index leader + page-number alignment,
        // and also for hanging indents in lists).
        if !existing.tabStops.isEmpty {
            mutable.tabStops = existing.tabStops
            mutable.defaultTabInterval = existing.defaultTabInterval
        }

        // Preserve explicit indents if they differ from the style defaults.
        // This matters for TOC nesting and other programmatic formatting.
        if existing.headIndent != style.headIndent {
            mutable.headIndent = existing.headIndent
        }
        if existing.firstLineHeadIndent != style.firstLineHeadIndent {
            mutable.firstLineHeadIndent = existing.firstLineHeadIndent
        }
        if existing.tailIndent != style.tailIndent {
            mutable.tailIndent = existing.tailIndent
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
        let styleName: String?
    }

    func resolveOutlineEntryRange(_ entry: OutlineEntry) -> NSRange? {
        guard let storage = textView.textStorage else { return nil }
        let full = storage.string as NSString
        guard full.length > 0 else { return nil }

        let desiredTitle = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)

        let clampedLocation = min(entry.range.location, max(0, full.length - 1))
        let initialRange = full.paragraphRange(for: NSRange(location: clampedLocation, length: 0))

        func normalizedTitle(_ range: NSRange) -> String {
            full.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func paragraphStyleName(atParagraphStart range: NSRange) -> String? {
            storage.attribute(styleAttributeKey, at: range.location, effectiveRange: nil) as? String
        }

        if !desiredTitle.isEmpty {
            let initialTitle = normalizedTitle(initialRange)
            if initialTitle.caseInsensitiveCompare(desiredTitle) == .orderedSame {
                return initialRange
            }

            var matches: [NSRange] = []
            var location = 0
            while location < full.length {
                let paragraphRange = full.paragraphRange(for: NSRange(location: location, length: 0))
                let paragraphTitle = normalizedTitle(paragraphRange)
                if !paragraphTitle.isEmpty && paragraphTitle.caseInsensitiveCompare(desiredTitle) == .orderedSame {
                    if let styleName = entry.styleName, let currentStyle = paragraphStyleName(atParagraphStart: paragraphRange) {
                        if currentStyle == styleName {
                            matches.append(paragraphRange)
                        }
                    } else {
                        matches.append(paragraphRange)
                    }
                }
                location = NSMaxRange(paragraphRange)
            }

            if !matches.isEmpty {
                let anchor = entry.range.location
                return matches.min(by: { abs($0.location - anchor) < abs($1.location - anchor) })
            }
        }

        return initialRange
    }

    func extractScreenplayCharacterCues(maxScanParagraphs: Int = 5000) -> [String] {
        guard StyleCatalog.shared.currentTemplateName == "Screenplay" else { return [] }
        guard let storage = textView.textStorage else { return [] }

        let full = storage.string as NSString
        var location = 0
        var scanned = 0

        var results: [String] = []
        var seenUpper = Set<String>()

        func isEffectivelyEmptyParagraph(_ range: NSRange) -> Bool {
            full.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        func styleName(atParagraphStart range: NSRange) -> String? {
            storage.attribute(styleAttributeKey, at: range.location, effectiveRange: nil) as? String
        }

        func isDialogueFollowingCharacterCue(startingAfter range: NSRange, maxLookaheadParagraphs: Int = 6) -> Bool {
            var nextLocation = NSMaxRange(range)
            var looked = 0
            while nextLocation < full.length, looked < maxLookaheadParagraphs {
                let nextRange = full.paragraphRange(for: NSRange(location: nextLocation, length: 0))
                guard nextRange.length > 0 else { break }
                looked += 1

                if isEffectivelyEmptyParagraph(nextRange) {
                    nextLocation = NSMaxRange(nextRange)
                    continue
                }

                let nextStyle = styleName(atParagraphStart: nextRange) ?? ""
                if nextStyle == "Parenthetical" || nextStyle == "Dialogue" {
                    return true
                }

                // If the next non-empty paragraph is something else (action/slugline/transition),
                // treat this as a non-speaking cue (often mis-styled locations).
                return false
            }
            return false
        }

        func normalizeCue(_ raw: String) -> [String] {
            var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !s.isEmpty else { return [] }

            // Remove parentheticals in cue lines: "JOHN (O.S.)" -> "JOHN"
            if let idx = s.firstIndex(of: "(") {
                s = String(s[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Remove common continuation suffixes if they appear outside parentheses.
            // Examples: "JOHN CONT'D" / "JOHN CONT'D." / "JOHN CONTINUED"
            s = s.replacingOccurrences(of: "\\s+CONT'?D\\.?$", with: "", options: .regularExpression)
            s = s.replacingOccurrences(of: "\\s+CONTINUED\\.?$", with: "", options: .regularExpression)

            // Filter obvious transitions that sometimes get mis-styled.
            let upper = s.uppercased()
            let transitionPrefixes = ["FADE IN", "FADE OUT", "CUT TO", "SMASH CUT", "DISSOLVE TO", "MATCH CUT", "WIPE TO"]
            if transitionPrefixes.contains(where: { upper.hasPrefix($0) }) {
                return []
            }

            // Split dual dialogue cues: "JOHN/MIKE" -> ["JOHN", "MIKE"]
            let parts = s.split(separator: "/").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let cleaned = parts
                .map { $0.replacingOccurrences(of: "[^A-Za-z0-9 '\\-]", with: "", options: .regularExpression) }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            return cleaned
        }

        while location < full.length && scanned < maxScanParagraphs {
            let paragraphRange = full.paragraphRange(for: NSRange(location: location, length: 0))
            guard paragraphRange.length > 0 else { break }
            scanned += 1

            let styleName = storage.attribute(styleAttributeKey, at: paragraphRange.location, effectiveRange: nil) as? String
            if styleName == "Character" {
                // Only treat this as a character cue if it actually introduces dialogue.
                guard isDialogueFollowingCharacterCue(startingAfter: paragraphRange) else {
                    location = NSMaxRange(paragraphRange)
                    continue
                }
                let raw = full.substring(with: paragraphRange)
                for cue in normalizeCue(raw) {
                    let key = cue.uppercased()
                    guard key.count >= 2 && key.count <= 40 else { continue }
                    guard key.range(of: "[A-Z]", options: .regularExpression) != nil else { continue }
                    if !seenUpper.contains(key) {
                        seenUpper.insert(key)
                        results.append(cue)
                    }
                }
            }

            location = NSMaxRange(paragraphRange)
        }

        return results
    }

    func extractFictionCharacterCues(maxScanParagraphs: Int = 5000) -> [String] {
        guard StyleCatalog.shared.currentTemplateName != "Screenplay" else { return [] }
        guard let storage = textView.textStorage else { return [] }

        let full = storage.string as NSString
        var location = 0
        var scanned = 0

        var results: [String] = []
        var seenLower = Set<String>()

        func normalizeCue(_ raw: String) -> [String] {
            var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !s.isEmpty else { return [] }

            // If someone styled a whole line like "John (nervous)", keep just the name.
            if let idx = s.firstIndex(of: "(") {
                s = String(s[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Allow multiple names separated by common delimiters.
            let parts = s
                .replacingOccurrences(of: "&", with: "/")
                .split(whereSeparator: { $0 == "/" || $0 == "," })
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

            let cleaned = parts
                .map { $0.replacingOccurrences(of: "[^A-Za-z0-9 '\\-]", with: "", options: .regularExpression) }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            return cleaned
        }

        while location < full.length && scanned < maxScanParagraphs {
            let paragraphRange = full.paragraphRange(for: NSRange(location: location, length: 0))
            guard paragraphRange.length > 0 else { break }
            scanned += 1

            let styleName = storage.attribute(styleAttributeKey, at: paragraphRange.location, effectiveRange: nil) as? String
            if styleName == "Fiction — Character" {
                let raw = full.substring(with: paragraphRange)
                for cue in normalizeCue(raw) {
                    let key = cue.lowercased()
                    guard key.count >= 2 && key.count <= 60 else { continue }
                    guard key.range(of: "[A-Za-z]", options: .regularExpression) != nil else { continue }
                    if !seenLower.contains(key) {
                        seenLower.insert(key)
                        results.append(cue)
                    }
                }
            }

            location = NSMaxRange(paragraphRange)
        }

        return results
    }

    func buildOutlineEntries() -> [OutlineEntry] {
        guard let storage = textView.textStorage, let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else {
            DebugLog.log("📋🔍 buildOutlineEntries: Missing required components")
            return []
        }

        // Ensure page numbers reflect *final* layout.
        // Immediately after DOCX/RTF import/reopen, the text system can be partially laid out,
        // which commonly causes the last headings (e.g. Index) to show incorrect page numbers.
        // Force a bounded full layout and run pagination once before scanning headings.
        if storage.length > 0 {
            if storage.length <= 1_000_000 {
                layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: storage.length))
            } else {
                layoutManager.ensureLayout(for: textContainer)
            }
            updatePageLayout()
        }

        DebugLog.log("📋🔍 buildOutlineEntries: Starting scan of \(storage.length) characters")
        DebugLog.log("📋🔍 styleAttributeKey: \(styleAttributeKey)")
        if StyleCatalog.shared.isPoetryTemplate {
            return buildPoetryStanzaOutlineEntries(storage: storage, layoutManager: layoutManager, textContainer: textContainer)
        }

        let isScreenplayTemplate = StyleCatalog.shared.isScreenplayTemplate

        var levels: [String: Int] = [
            "Part Title": 0,
            "Chapter Number": 1,
            "Chapter Title": 1,
            "Chapter Heading": 1,
            "Heading 1": 1,
            "Heading 2": 2,
            "Heading 3": 3,
            "TOC Title": 1,
            "Index Title": 1,
            "Glossary Title": 1,
            "Appendix Title": 1
        ]

        if isScreenplayTemplate {
            // Screenplay outline should be driven by scene sluglines.
            levels["Scene Heading"] = 1
        }

        var results: [OutlineEntry] = []
        var stylesFound = Set<String>()
        var paragraphCount = 0
        let fullString = storage.string as NSString

        func looksLikeScreenplaySlugline(_ text: String) -> Bool {
            let upper = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !upper.isEmpty else { return false }
            let prefixes = ["INT.", "EXT.", "INT/EXT.", "EXT/INT.", "I/E.", "EST."]
            return prefixes.contains(where: { upper.hasPrefix($0) })
        }

        func looksLikeScreenplayActHeading(_ text: String) -> Bool {
            let upper = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard upper.hasPrefix("ACT") else { return false }
            // Accept: ACT I / ACT II / ACT III / ACT 1 / ACT 2 / ACT 3 (optionally punctuated)
            let cleaned = upper.replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: ":", with: " ")
                .replacingOccurrences(of: "-", with: " ")
            let parts = cleaned.split(whereSeparator: { $0.isWhitespace })
            guard parts.count >= 2 else { return false }
            let token = String(parts[1])
            return token == "I" || token == "II" || token == "III" || token == "1" || token == "2" || token == "3"
        }

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
                        let pageIndex = getPageNumber(forCharacterPosition: paragraphRange.location)
                        results.append(OutlineEntry(title: rawTitle, level: level, range: paragraphRange, page: pageIndex, styleName: styleName))
                        if results.count <= 3 {
                            DebugLog.log("📋✅ Found: '\(rawTitle)' style='\(styleName)' level=\(level)")
                        }
                    }
                }
            } else if isScreenplayTemplate {
                let rawTitle = fullString.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if looksLikeScreenplaySlugline(rawTitle) {
                    let pageIndex = getPageNumber(forCharacterPosition: paragraphRange.location)
                    results.append(OutlineEntry(title: rawTitle, level: 1, range: paragraphRange, page: pageIndex, styleName: "Scene Heading"))
                } else if looksLikeScreenplayActHeading(rawTitle) {
                    let pageIndex = getPageNumber(forCharacterPosition: paragraphRange.location)
                    results.append(OutlineEntry(title: rawTitle, level: 0, range: paragraphRange, page: pageIndex, styleName: "Scene Heading"))
                }
            }

            location = NSMaxRange(paragraphRange)
        }

        DebugLog.log("📋🔍 Scanned \(paragraphCount) paragraphs, found \(stylesFound.count) unique styles")
        DebugLog.log("📋🔍 Styles present: \(stylesFound.sorted())")
        DebugLog.log("📋🔍 Outline entries found: \(results.count)")

        return results
    }

    private func buildPoetryStanzaOutlineEntries(storage: NSTextStorage, layoutManager: NSLayoutManager, textContainer: NSTextContainer) -> [OutlineEntry] {
        let fullString = storage.string as NSString

        let stanzaBreakStyles: Set<String> = [
            "Poetry — Stanza Break",
            "Section Break"
        ]
        let headerStyles: Set<String> = [
            "Poetry — Title",
            "Poetry — Author",
            "Poetry — Poet Name",
            "Poem Title",
            "Title",
            "Author Name",
            "Poet Name",
            "Dedication",
            "Epigraph",
            "Argument Title",
            "Argument",
            "Section / Sequence Title",
            "Part Number",
            "Notes",
            "Draft / Margin Note",
            "Marginal Note",
            "Footnote"
        ]

        var results: [OutlineEntry] = []
        var stanzaIndex = 0
        var sawExplicitStanzaBreak = false

        var stanzaStart: Int?
        var stanzaEnd: Int?
        var stanzaFirstParagraphRange: NSRange?
        var stanzaSawVerseLine = false
        var stanzaLineCount = 0

        func pageIndexForParagraph(_ paragraphRange: NSRange) -> Int {
            getPageNumber(forCharacterPosition: paragraphRange.location)
        }

        func finalizeStanzaIfNeeded() {
            guard let start = stanzaStart, let end = stanzaEnd, let firstPara = stanzaFirstParagraphRange, stanzaSawVerseLine else {
                stanzaStart = nil
                stanzaEnd = nil
                stanzaFirstParagraphRange = nil
                stanzaSawVerseLine = false
                stanzaLineCount = 0
                return
            }

            // Only treat a stanza as outline-worthy if it is exactly four lines (quatrain).
            guard stanzaLineCount == 4 else {
                stanzaStart = nil
                stanzaEnd = nil
                stanzaFirstParagraphRange = nil
                stanzaSawVerseLine = false
                stanzaLineCount = 0
                return
            }

            stanzaIndex += 1
            let range = NSRange(location: start, length: max(0, end - start))
            let pageIndex = pageIndexForParagraph(firstPara)

            let title = "Stanza \(stanzaIndex) — Quatrain"

            results.append(OutlineEntry(title: title, level: 1, range: range, page: pageIndex, styleName: "Poetry — Stanza"))

            stanzaStart = nil
            stanzaEnd = nil
            stanzaFirstParagraphRange = nil
            stanzaSawVerseLine = false
            stanzaLineCount = 0
        }

        var location = 0
        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
            guard paragraphRange.length > 0 else { break }

            let styleName = storage.attribute(styleAttributeKey, at: paragraphRange.location, effectiveRange: nil) as? String
            let raw = fullString.substring(with: paragraphRange)
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

            let isHeader = styleName.map { headerStyles.contains($0) } ?? false
            let isStanzaBreak = styleName.map { stanzaBreakStyles.contains($0) } ?? false
            let isBlank = trimmed.isEmpty
            let isStanzaLine = !isBlank && !isHeader && !isStanzaBreak

            if isHeader {
                finalizeStanzaIfNeeded()
                location = NSMaxRange(paragraphRange)
                continue
            }

            if isStanzaBreak {
                sawExplicitStanzaBreak = true
                finalizeStanzaIfNeeded()
                location = NSMaxRange(paragraphRange)
                continue
            }

            if isBlank {
                location = NSMaxRange(paragraphRange)
                continue
            }

            // Verse line (or best-effort fallback when styles are missing).
            if stanzaStart == nil {
                stanzaStart = paragraphRange.location
                stanzaFirstParagraphRange = paragraphRange
            }
            stanzaEnd = NSMaxRange(paragraphRange)
            let countsAsStanzaLine = isStanzaLine
            stanzaSawVerseLine = stanzaSawVerseLine || countsAsStanzaLine
            if countsAsStanzaLine {
                stanzaLineCount += 1
            }

            location = NSMaxRange(paragraphRange)
        }

        finalizeStanzaIfNeeded()
        guard sawExplicitStanzaBreak else { return [] }
        return results
    }

    func flashOutlineLocation(_ location: Int, duration: TimeInterval = 0.7) {
        guard let textStorage = textView.textStorage else { return }
        let full = textStorage.string as NSString
        let safeLocation = max(0, min(location, max(0, full.length - 1)))
        let paragraphRange = full.paragraphRange(for: NSRange(location: safeLocation, length: 0))
        flashOutlineRange(paragraphRange, duration: duration)
    }

    private func flashOutlineRange(_ range: NSRange, duration: TimeInterval) {
        guard let layoutManager = textView.layoutManager else { return }
        guard let textContainer = textView.textContainer else { return }

        outlineFlashWorkItem?.cancel()
        if let previous = outlineFlashRange {
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: previous)
        }

        outlineFlashOverlay?.removeFromSuperview()
        outlineFlashOverlay = nil

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rects: [NSRect] = []
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
            var r = usedRect
            r.origin.x += self.textView.textContainerOrigin.x
            r.origin.y += self.textView.textContainerOrigin.y
            // Slight padding around the line fragment; keeps it subtle without a fill.
            r = r.insetBy(dx: -6, dy: -2)
            rects.append(r)
        }

        if rects.isEmpty {
            // Fallback: use the full bounding rect for the glyph range.
            var r = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            r.origin.x += textView.textContainerOrigin.x
            r.origin.y += textView.textContainerOrigin.y
            r = r.insetBy(dx: -6, dy: -2)
            rects = [r]
        }

        let overlay = OutlineFlashOverlayView(frame: textView.bounds)
        overlay.autoresizingMask = [.width, .height]
        // Avoid the Cream theme's orange/yellow accents; use the neutral ruler markings.
        overlay.strokeColor = ThemeManager.shared.currentTheme.rulerMarkings.withAlphaComponent(0.35)
        overlay.lineWidth = 1.75
        overlay.cornerRadius = 6
        overlay.rects = rects
        textView.addSubview(overlay)
        outlineFlashOverlay = overlay
        overlay.needsDisplay = true
        outlineFlashRange = range

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.textView.layoutManager?.removeTemporaryAttribute(.backgroundColor, forCharacterRange: range)
            self.outlineFlashOverlay?.removeFromSuperview()
            self.outlineFlashOverlay = nil
            self.textView.needsDisplay = true
            self.outlineFlashRange = nil
            self.outlineFlashWorkItem = nil
        }
        outlineFlashWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    /// Build a comprehensive character-position-to-page mapping for accurate page lookups
    func buildPageMapping() -> [(location: Int, page: Int)] {
        guard let storage = textView.textStorage,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
                        DebugLog.log("📄 buildPageMapping: Missing text storage/layout manager")
            return []
        }

        var mapping: [(location: Int, page: Int)] = []
        let totalLength = storage.length

        guard totalLength > 0 else {
            DebugLog.log("📄 buildPageMapping: Empty document")
            return []
        }

        // Force layout to complete before we try to get page numbers
        DebugLog.log("📄 buildPageMapping: Forcing layout for \(totalLength) characters...")
        layoutManager.ensureLayout(for: textContainer)
        DebugLog.log("📄 buildPageMapping: Layout complete, starting sampling...")

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

        DebugLog.log("📄 buildPageMapping: Created \(mapping.count) page mapping entries for \(totalLength) characters")
        if !mapping.isEmpty {
            DebugLog.log("📄 First entry: location=\(mapping.first!.location) page=\(mapping.first!.page)")
            DebugLog.log("📄 Last entry: location=\(mapping.last!.location) page=\(mapping.last!.page)")
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

    // MARK: - Screenplay Text Normalization

    private func normalizeScreenplayTextIfNeeded(for styleName: String) {
        switch styleName {
        case "Scene Heading":
            normalizeSelectedParagraphText(transform: { raw in
                var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return trimmed }

                // Uppercase, then normalize common slugline prefixes.
                trimmed = trimmed.uppercased()

                func normalizePrefix(_ prefix: String, replacement: String) -> String? {
                    if trimmed.hasPrefix(prefix) {
                        let rest = trimmed.dropFirst(prefix.count)
                        if rest.hasPrefix(" ") {
                            return replacement + rest
                        }
                    }
                    return nil
                }

                if let fixed = normalizePrefix("INT/EXT", replacement: "INT./EXT.") { return fixed }
                if let fixed = normalizePrefix("INT.", replacement: "INT.") { return fixed }
                if let fixed = normalizePrefix("EXT.", replacement: "EXT.") { return fixed }
                if let fixed = normalizePrefix("INT", replacement: "INT.") { return fixed }
                if let fixed = normalizePrefix("EXT", replacement: "EXT.") { return fixed }
                return trimmed
            })
        case "Character":
            normalizeSelectedParagraphText(transform: { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() })
        case "Parenthetical":
            normalizeSelectedParagraphText(transform: { raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return trimmed }

                var core = trimmed
                if !core.hasPrefix("(") { core = "(" + core }
                if !core.hasSuffix(")") { core = core + ")" }

                // Lowercase the inner content but preserve the parentheses.
                if core.count >= 2, core.hasPrefix("("), core.hasSuffix(")") {
                    let start = core.index(after: core.startIndex)
                    let end = core.index(before: core.endIndex)
                    let inner = String(core[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    return "(" + inner + ")"
                }
                return core.lowercased()
            })
        case "Transition":
            normalizeSelectedParagraphText(transform: { raw in
                var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return trimmed }
                trimmed = trimmed.uppercased()
                if trimmed.hasSuffix(":") { return trimmed }
                if trimmed.hasSuffix(".") { trimmed.removeLast() }
                return trimmed + ":"
            })
        case "Chyron", "On Screen", "On-Screen Text":
            normalizeSelectedParagraphText(transform: { raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return trimmed }

                let allowedPrefixes: Set<String> = [
                    "CHYRON", "SUPER", "TITLE CARD", "TITLE OVER", "TITLE", "ON SCREEN", "ON-SCREEN", "SUBTITLE"
                ]

                let colonIndex = trimmed.firstIndex(of: ":")
                let prefix: String
                let body: String
                if let colonIndex {
                    prefix = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let start = trimmed.index(after: colonIndex)
                    body = String(trimmed[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    prefix = "CHYRON"
                    body = trimmed
                }

                let upperPrefix = prefix.isEmpty ? "CHYRON" : prefix.uppercased()
                let normalizedPrefix = allowedPrefixes.contains(upperPrefix) ? upperPrefix : upperPrefix

                var normalizedBody = body
                if !normalizedBody.isEmpty {
                    let hasQuotes = normalizedBody.hasPrefix("\"") && normalizedBody.hasSuffix("\"")
                    if !hasQuotes {
                        normalizedBody = "\"" + normalizedBody + "\""
                    }
                    return "\(normalizedPrefix): \(normalizedBody)"
                }

                return "\(normalizedPrefix):"
            })
        case "Shot", "Montage", "Montage Header", "Montage End",
             "Series of Shots Header", "Series of Shots End",
             "Flashback", "Back To Present",
             "Intercut", "End Intercut",
             "Act Break",
             "Insert",
             "More", "Continued":
            normalizeSelectedParagraphText(transform: { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() })
        default:
            break
        }
    }

    private func adjustScreenplayActionSpacingBeforeIfNeeded() {
        guard StyleCatalog.shared.isScreenplayTemplate else { return }
        guard let storage = textView.textStorage, storage.length > 0 else { return }
        guard let selected = textView.selectedRanges.first?.rangeValue else { return }

        let full = storage.string as NSString
        let safeLocation = min(selected.location, max(0, storage.length - 1))
        let safeRange = NSRange(location: safeLocation, length: selected.length)
        let paragraphsRange = full.paragraphRange(for: safeRange)
        guard paragraphsRange.length > 0 else { return }

        performUndoableTextStorageEdit(in: paragraphsRange, actionName: "Screenplay Action Spacing") { storage in
            var location = paragraphsRange.location
            let end = NSMaxRange(paragraphsRange)
            while location < end {
                let paraRange = full.paragraphRange(for: NSRange(location: location, length: 0))
                let safePara = NSIntersectionRange(paraRange, paragraphsRange)
                guard safePara.length > 0 else {
                    location = NSMaxRange(paraRange)
                    continue
                }

                let styleName = storage.attribute(styleAttributeKey, at: safePara.location, effectiveRange: nil) as? String
                if styleName == "Action" {
                    let prevLoc = max(0, safePara.location - 1)
                    let prevPara = prevLoc < full.length ? full.paragraphRange(for: NSRange(location: prevLoc, length: 0)) : NSRange(location: NSNotFound, length: 0)
                    let prevStyle = (prevPara.location != NSNotFound && prevPara.location < storage.length)
                        ? (storage.attribute(styleAttributeKey, at: prevPara.location, effectiveRange: nil) as? String)
                        : nil

                    let needsBlankBefore = (prevStyle == "Scene Heading" || prevStyle == "Dialogue")
                    let desiredBefore: CGFloat = needsBlankBefore ? 12 : 0

                    let existing = (storage.attribute(.paragraphStyle, at: safePara.location, effectiveRange: nil) as? NSParagraphStyle)
                        ?? (textView.defaultParagraphStyle ?? NSParagraphStyle.default)
                    if let mutable = existing.mutableCopy() as? NSMutableParagraphStyle {
                        if mutable.paragraphSpacingBefore != desiredBefore {
                            mutable.paragraphSpacingBefore = desiredBefore
                            storage.addAttribute(.paragraphStyle, value: mutable.copy() as! NSParagraphStyle, range: safePara)
                        }
                    }
                }

                location = NSMaxRange(paraRange)
            }
        }
    }

    private func normalizeSelectedParagraphText(transform: (String) -> String) {
        guard let storage = textView.textStorage else { return }
        let selection = textView.selectedRange()
        let full = storage.string as NSString
        guard full.length > 0 else { return }

        let paragraphRange = full.paragraphRange(for: selection)
        guard paragraphRange.length > 0 else { return }

        // Exclude trailing newline(s) so we only rewrite the content.
        var end = paragraphRange.location + paragraphRange.length
        while end > paragraphRange.location {
            let ch = full.character(at: end - 1)
            if ch == 10 || ch == 13 { // \n or \r
                end -= 1
            } else {
                break
            }
        }
        let contentRange = NSRange(location: paragraphRange.location, length: max(0, end - paragraphRange.location))
        guard contentRange.length > 0 else { return }

        let original = full.substring(with: contentRange)
        let updated = transform(original)
        guard updated != original else { return }

        performUndoableTextStorageEdit(in: contentRange, actionName: "Normalize Screenplay Text") { storage in
            storage.replaceCharacters(in: contentRange, with: updated)
        }
    }

    private func applyScreenplayFont(bold: Bool = false, italic: Bool = false) {
        applyFontChange { current in
            var font = NSFont(name: "Courier New", size: 12) ?? current
            let fontManager = NSFontManager.shared
            if bold {
                font = fontManager.convert(font, toHaveTrait: .boldFontMask)
            }
            if italic {
                font = fontManager.convert(font, toHaveTrait: .italicFontMask)
            }
            return font
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
        debugLog("🎬 applyScreenplayPageDefaultsIfNeeded: setPageMargins(left=108,right=72) current=L=\(leftPageMargin) R=\(rightPageMargin)")
        setPageMargins(left: 108, right: 72)
    }

    private func applyBaselineOffset(_ offset: CGFloat) {
        guard let textStorage = textView.textStorage else { return }
        guard let selectedRange = textView.selectedRanges.first?.rangeValue else { return }
        if selectedRange.length == 0 { return }
        textStorage.beginEditing()
        applySupersubscriptAttributes(to: selectedRange, desiredOffset: offset)
        textStorage.endEditing()
    }

    private func toggleBaselineOffset(desiredOffset: CGFloat) {
        guard let textStorage = textView.textStorage else { return }
        guard let selectedRange = textView.selectedRanges.first?.rangeValue else { return }

        if selectedRange.length == 0 {
            let current = (textView.typingAttributes[.baselineOffset] as? NSNumber)?.doubleValue ?? 0
            if (desiredOffset > 0 && current > 0) || (desiredOffset < 0 && current < 0) {
                if let original = textView.typingAttributes[baselineOriginalFontKey] as? NSFont {
                    textView.typingAttributes[.font] = original
                }
                textView.typingAttributes.removeValue(forKey: baselineOriginalFontKey)
                textView.typingAttributes.removeValue(forKey: .baselineOffset)
            } else {
                let baseFont = (textView.typingAttributes[.font] as? NSFont)
                    ?? textView.font
                    ?? NSFont.systemFont(ofSize: 12)
                if textView.typingAttributes[baselineOriginalFontKey] == nil {
                    textView.typingAttributes[baselineOriginalFontKey] = baseFont
                }
                let metrics = supersubscriptMetrics(for: baseFont, desiredOffset: desiredOffset)
                textView.typingAttributes[.font] = metrics.font
                textView.typingAttributes[.baselineOffset] = metrics.offset
            }
            return
        }

        let attrValue = textStorage.attribute(.baselineOffset, at: selectedRange.location, effectiveRange: nil)
        let current = (attrValue as? NSNumber)?.doubleValue ?? 0
        let shouldClear = (desiredOffset > 0 && current > 0) || (desiredOffset < 0 && current < 0)

        textStorage.beginEditing()
        if shouldClear {
            clearSupersubscriptAttributes(in: selectedRange)
        } else {
            applySupersubscriptAttributes(to: selectedRange, desiredOffset: desiredOffset)
        }
        textStorage.endEditing()
    }

    private func supersubscriptMetrics(for font: NSFont, desiredOffset: CGFloat) -> (font: NSFont, offset: CGFloat) {
        let direction: CGFloat = desiredOffset >= 0 ? 1 : -1
        let offsetMagnitude = max(2, min(6, font.pointSize * 0.3))
        let scaledSize = max(6, font.pointSize * 0.7)
        let scaledFont = NSFont(descriptor: font.fontDescriptor, size: scaledSize) ?? NSFont.systemFont(ofSize: scaledSize)
        return (scaledFont, direction * offsetMagnitude)
    }

    private func applySupersubscriptAttributes(to range: NSRange, desiredOffset: CGFloat) {
        guard let textStorage = textView.textStorage else { return }
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let baseFont = (value as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: 12)
            if textStorage.attribute(baselineOriginalFontKey, at: subrange.location, effectiveRange: nil) == nil {
                textStorage.addAttribute(baselineOriginalFontKey, value: baseFont, range: subrange)
            }
            let metrics = supersubscriptMetrics(for: baseFont, desiredOffset: desiredOffset)
            textStorage.addAttribute(.font, value: metrics.font, range: subrange)
            textStorage.addAttribute(.baselineOffset, value: metrics.offset, range: subrange)
        }
    }

    private func clearSupersubscriptAttributes(in range: NSRange) {
        guard let textStorage = textView.textStorage else { return }
        textStorage.enumerateAttribute(baselineOriginalFontKey, in: range, options: []) { value, subrange, _ in
            if let original = value as? NSFont {
                textStorage.addAttribute(.font, value: original, range: subrange)
            }
        }
        textStorage.removeAttribute(.baselineOffset, range: range)
        textStorage.removeAttribute(baselineOriginalFontKey, range: range)
    }

    private func nextMarkerNumber(counter: inout Int) -> Int {
        counter += 1
        return counter
    }

    private func insertNoteMarker(kind: String, counter: inout Int, desiredOffset: CGFloat) {
        let number = nextMarkerNumber(counter: &counter)
        let marker = "\(number)"
        let insertionRange = textView.selectedRange()
        textView.insertText(marker, replacementRange: insertionRange)
        let insertedRange = NSRange(location: insertionRange.location, length: marker.count)
        if insertedRange.length > 0 {
            if let storage = textView.textStorage {
                storage.beginEditing()
                applySupersubscriptAttributes(to: insertedRange, desiredOffset: desiredOffset)
                storage.endEditing()
            }
        }
        textView.setSelectedRange(NSRange(location: insertedRange.location + insertedRange.length, length: 0))
        textView.window?.makeFirstResponder(textView)
        DebugLog.log("Inserted \(kind) marker \(number)")
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

    func updatePageCentering(ensureSelectionVisible: Bool = true) {
        guard let scrollView else { return }

        // Ensure screenplay templates always use industry-standard page margins
        // even if the document loads before any style application occurs.
        if StyleCatalog.shared.isScreenplayTemplate {
            let desiredLeft: CGFloat = 108
            let desiredRight: CGFloat = 72
            if abs(leftPageMargin - desiredLeft) > 0.5 || abs(rightPageMargin - desiredRight) > 0.5 {
                let maxMargin = max(0, pageWidth - 36)
                leftPageMargin = min(max(0, desiredLeft), maxMargin)
                rightPageMargin = min(max(0, desiredRight), maxMargin)
            }
        }

        let now = CFAbsoluteTimeGetCurrent()
        let suppressRestore = pendingNavigationScroll || now < navigationScrollSuppressionUntil
        if suppressRestore {
            DebugLog.log("📐CENTER[\(qpTS())] suppress restore pending=\(pendingNavigationScroll) now=\(now) until=\(navigationScrollSuppressionUntil)")
        }

        // Preserve current cursor position AND scroll position BEFORE any layout changes
        let savedSelection = textView.selectedRange()
        let savedScrollPosition = scrollView.contentView.bounds.origin

        let visibleWidth = scrollView.contentView.bounds.width
        // If the scroll view hasn't been laid out yet, we can't compute a correct pageX.
        // Retry shortly (common right after opening a document).
        if visibleWidth < 50 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.updatePageCentering(ensureSelectionVisible: ensureSelectionVisible)
            }
            return
        }
        let scaledPageWidth = pageWidth * editorZoom
        let scaledPageHeight = pageHeight * editorZoom
        let pageX = max((visibleWidth - scaledPageWidth) / 2, 0)

        // IMPORTANT: Do not recompute the page count here.
        // Pagination is owned by updatePageLayout() / setPageCount(), which measures the actual
        // laid out text height. This method should only center horizontally and update frames.
        let numPages = max(1, (pageContainer as? PageContainerView)?.numPages ?? 1)

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

        // Text view spans all pages with standard margins.
        // Add a small extra clearance so body text isn't flush against header/footer bands.
        let headerClearance = showHeaders ? (headerHeight * editorZoom * 0.25) : 0
        let footerClearance = showFooters ? (footerHeight * editorZoom * 0.5) : 0

        let textInsetTop = (standardMargin * editorZoom) + headerClearance
        let textInsetBottom = (standardMargin * editorZoom) + footerClearance
        let textInsetLeft = leftPageMargin * editorZoom
        let textInsetRight = rightPageMargin * editorZoom
        textView.frame = NSRect(
            x: textInsetLeft,
            y: textInsetBottom,
            width: max(36, scaledPageWidth - textInsetLeft - textInsetRight),
            height: totalHeight - textInsetTop - textInsetBottom
        )

        // Set text container inset to keep text within safe area
        textView.textContainerInset = NSSize(width: 0, height: 0)

        // Ensure ruler/paragraph indents map cleanly to rendered text.
        textView.textContainer?.lineFragmentPadding = 0

        // Create exclusion paths for header/footer areas on each page
        if let textContainer = textView.textContainer {
            var exclusionPaths: [NSBezierPath] = []
            let pageGap: CGFloat = 20

            for pageNum in 0..<numPages {
                let pageYInContainer = CGFloat(pageNum) * (scaledPageHeight + pageGap)

                // Exclude the standard top margin at the top of each page
                let headerY = pageYInContainer - textInsetBottom
                let headerRect = NSRect(
                    x: 0,
                    y: headerY,
                    width: textView.frame.width,
                    height: textInsetTop
                )
                exclusionPaths.append(NSBezierPath(rect: headerRect))

                // Exclude the standard bottom margin at the bottom of each page
                let footerY = pageYInContainer + scaledPageHeight - textInsetBottom - textInsetTop
                let footerRect = NSRect(
                    x: 0,
                    y: footerY,
                    width: textView.frame.width,
                    height: textInsetBottom
                )
                exclusionPaths.append(NSBezierPath(rect: footerRect))

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
        repairTOCAndIndexFormattingAfterImport()

        let docWidth = max(visibleWidth, pageX + scaledPageWidth + 20)
        // Keep the document view sized to the content (with a small bottom pad).
        let docHeight = max(totalHeight + 200, scrollView.contentView.bounds.height + 20)
        documentView.frame = NSRect(x: 0, y: 0, width: docWidth, height: docHeight)

        // Restore cursor position AFTER layout changes, except during an explicit navigation.
        // Navigation will set its own selection and we must not restore a pre-jump selection.
        if !suppressRestore, savedSelection.location <= textView.string.count {
            textView.setSelectedRange(savedSelection)
        }

        if suppressRestore {
            // Navigation owns scroll/selection visibility.
        } else {
            // Restore scroll position to prevent view jumping during layout updates,
            // but then ensure cursor is visible (which will scroll if needed)
            scrollView.contentView.scroll(to: savedScrollPosition)

            if ensureSelectionVisible {
                // Ensure the cursor is visible after layout - this allows natural scrolling
                // when typing at the end of the document without jumping back up
                textView.scrollRangeToVisible(textView.selectedRange())
            }
        }
    }

    private func updateHeadersAndFooters(_ numPages: Int) {
        // Clear existing
        headerViews.forEach { $0.removeFromSuperview() }
        footerViews.forEach { $0.removeFromSuperview() }
        headerFooterDecorationViews.forEach { $0.removeFromSuperview() }
        pages.forEach { $0.removeFromSuperview() }
        headerViews.removeAll()
        footerViews.removeAll()
        headerFooterDecorationViews.removeAll()
        pages.removeAll()

        let scaledPageWidth = pageWidth * editorZoom
        let scaledPageHeight = pageHeight * editorZoom
        let scaledHeaderHeight = headerHeight * editorZoom
        let scaledFooterHeight = footerHeight * editorZoom
        let marginY = standardMargin * editorZoom
        let marginXLeft = leftPageMargin * editorZoom
        let marginXRight = rightPageMargin * editorZoom
        let contentWidth = max(36, scaledPageWidth - marginXLeft - marginXRight)

        // Build section map for page numbering
        let sectionMap: [(startPage: Int, startNumber: Int, format: SectionPageNumberFormat, explicit: Bool)] = {
            guard let storage = textView.textStorage else { return [(1, 1, .arabic, false)] }
            var items: [(Int, Int, SectionPageNumberFormat, Bool)] = []
            for entry in sectionBreaks(in: storage) {
                let pageIndex = getPageNumber(forCharacterPosition: entry.range.location)
                if pageIndex >= 1 {
                    items.append((pageIndex, max(1, entry.section.startPageNumber), entry.section.numberFormat, true))
                }
            }
            if items.isEmpty {
                return [(1, 1, .arabic, false)]
            }
            let sorted = items.sorted { $0.0 < $1.0 }
            // Ensure first section always starts at page 1 if none before it.
            if sorted.first?.0 != 1 {
                return [(1, 1, .arabic, false)] + sorted
            }
            return sorted
        }()

        func sectionInfo(for pageNum: Int) -> (startPage: Int, startNumber: Int, format: SectionPageNumberFormat, explicit: Bool) {
            var current = sectionMap.first ?? (1, 1, .arabic, false)
            for entry in sectionMap {
                if entry.startPage <= pageNum {
                    current = entry
                } else {
                    break
                }
            }
            return current
        }

        func displayedPageNumber(for pageNum: Int) -> String {
            let current = sectionInfo(for: pageNum)
            let number = current.startNumber + (pageNum - current.startPage)
            return formatPageNumber(number, format: current.format)
        }

        func formatPageNumber(_ number: Int, format: SectionPageNumberFormat) -> String {
            switch format {
            case .arabic:
                return "\(number)"
            case .romanUpper:
                return romanNumeral(number).uppercased()
            case .romanLower:
                return romanNumeral(number).lowercased()
            }
        }

        func romanNumeral(_ number: Int) -> String {
            guard number > 0 else { return "" }
            let romanMap: [(Int, String)] = [
                (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
                (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
                (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")
            ]
            var result = ""
            var value = number
            for (arabic, roman) in romanMap {
                while value >= arabic {
                    result += roman
                    value -= arabic
                }
            }
            return result
        }

        for pageNum in 1...numPages {
            let pageY = CGFloat(pageNum - 1) * (scaledPageHeight + 20) // 20pt gap between pages

            // Note: Page backgrounds are now drawn by PageContainerView.draw(_:)
            // This ensures proper page separation and performance

            // Header (top band)
            if showHeaders {
                let headerFont = NSFont(name: "Courier", size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                let headerColor = currentTheme.textColor.withAlphaComponent(0.5)
                let half = max(36, (contentWidth / 2) - 8)

                // Left
                if !headerText.isEmpty {
                    let headerLeftField = NSTextField(labelWithString: headerText)
                    headerLeftField.isEditable = false
                    headerLeftField.isSelectable = false
                    headerLeftField.isBordered = false
                    headerLeftField.backgroundColor = .clear
                    headerLeftField.font = headerFont
                    headerLeftField.textColor = headerColor
                    headerLeftField.alignment = .left
                    headerLeftField.frame = NSRect(
                        x: marginXLeft,
                        y: pageY + marginY / 2,
                        width: half,
                        height: scaledHeaderHeight
                    )
                    pageContainer.addSubview(headerLeftField)
                    headerViews.append(headerLeftField)
                }

                // Right
                if !headerTextRight.isEmpty {
                    let headerRightField = NSTextField(labelWithString: headerTextRight)
                    headerRightField.isEditable = false
                    headerRightField.isSelectable = false
                    headerRightField.isBordered = false
                    headerRightField.backgroundColor = .clear
                    headerRightField.font = headerFont
                    headerRightField.textColor = headerColor
                    headerRightField.alignment = .right
                    headerRightField.frame = NSRect(
                        x: marginXLeft + contentWidth - half,
                        y: pageY + marginY / 2,
                        width: half,
                        height: scaledHeaderHeight
                    )
                    pageContainer.addSubview(headerRightField)
                    headerViews.append(headerRightField)
                }

                // Separator under header
                let headerLine = NSView(frame: NSRect(
                    x: marginXLeft,
                    y: pageY + marginY / 2 + scaledHeaderHeight + 2,
                    width: contentWidth,
                    height: 1
                ))
                headerLine.wantsLayer = true
                headerLine.layer?.backgroundColor = currentTheme.textColor.withAlphaComponent(0.2).cgColor
                pageContainer.addSubview(headerLine)
                headerFooterDecorationViews.append(headerLine)
            }

            // Footer (bottom band)
            if showFooters {
                let footerY = pageY + scaledPageHeight - marginY / 2 - scaledFooterHeight

                let footerFont = NSFont(name: "Courier", size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                let footerColor = currentTheme.textColor.withAlphaComponent(0.5)

                let section = sectionInfo(for: pageNum)
                let isFirstPageOfSection = pageNum == section.startPage
                let shouldHideFirst = hidePageNumberOnFirstPage && isFirstPageOfSection
                let shouldShowPageNumber = showPageNumbers && !shouldHideFirst
                let isEvenPage = pageNum % 2 == 0
                let reserveLeft: CGFloat = (shouldShowPageNumber && !centerPageNumbers && facingPageNumbers && isEvenPage) ? 72 : 0
                let reserveRight: CGFloat = (shouldShowPageNumber && !centerPageNumbers && (!facingPageNumbers || !isEvenPage)) ? 72 : 0
                let reservedForPageNumber: CGFloat = reserveLeft + reserveRight
                let halfWidth = max(36, (contentWidth - reservedForPageNumber) / 2)

                // Footer text (left)
                if !footerText.isEmpty {
                    let footerField = NSTextField(labelWithString: footerText)
                    footerField.isEditable = false
                    footerField.isSelectable = false
                    footerField.isBordered = false
                    footerField.backgroundColor = .clear
                    footerField.font = footerFont
                    footerField.textColor = footerColor
                    footerField.alignment = .left
                    footerField.frame = NSRect(
                        x: marginXLeft + reserveLeft,
                        y: footerY,
                        width: centerPageNumbers ? halfWidth : max(36, contentWidth - reservedForPageNumber - halfWidth),
                        height: scaledFooterHeight
                    )
                    pageContainer.addSubview(footerField)
                    footerViews.append(footerField)
                }

                // Footer right text
                if !footerTextRight.isEmpty {
                    let rightField = NSTextField(labelWithString: footerTextRight)
                    rightField.isEditable = false
                    rightField.isSelectable = false
                    rightField.isBordered = false
                    rightField.backgroundColor = .clear
                    rightField.font = footerFont
                    rightField.textColor = footerColor
                    rightField.alignment = .right

                    let rightX: CGFloat
                    let rightW: CGFloat
                    if centerPageNumbers {
                        rightX = marginXLeft + contentWidth - halfWidth
                        rightW = halfWidth
                    } else {
                        // Leave room for page number at far right (if any)
                        rightX = marginXLeft + contentWidth - reserveRight - halfWidth
                        rightW = halfWidth
                    }

                    rightField.frame = NSRect(
                        x: rightX,
                        y: footerY,
                        width: max(36, rightW),
                        height: scaledFooterHeight
                    )
                    pageContainer.addSubview(rightField)
                    footerViews.append(rightField)
                }

                // Page number (right or center), hidden on first page if configured
                if shouldShowPageNumber {
                    let displayNum = displayedPageNumber(for: pageNum)
                    let pageField = NSTextField(labelWithString: displayNum)
                    pageField.isEditable = false
                    pageField.isSelectable = false
                    pageField.isBordered = false
                    pageField.backgroundColor = .clear
                    pageField.font = footerFont
                    pageField.textColor = footerColor
                    if centerPageNumbers {
                        pageField.alignment = .center
                    } else if facingPageNumbers {
                        pageField.alignment = isEvenPage ? .left : .right
                    } else {
                        pageField.alignment = .right
                    }
                    pageField.frame = NSRect(
                        x: marginXLeft,
                        y: footerY,
                        width: contentWidth,
                        height: scaledFooterHeight
                    )
                    pageContainer.addSubview(pageField)
                    footerViews.append(pageField)
                }

                // Separator above footer
                let footerLine = NSView(frame: NSRect(
                    x: marginXLeft,
                    y: pageY + scaledPageHeight - marginY / 2 - scaledFooterHeight - 2,
                    width: contentWidth,
                    height: 1
                ))
                footerLine.wantsLayer = true
                footerLine.layer?.backgroundColor = currentTheme.textColor.withAlphaComponent(0.2).cgColor
                pageContainer.addSubview(footerLine)
                headerFooterDecorationViews.append(footerLine)
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
        DebugLog.log("setColumnCount called with \(columns)")
        guard columns >= 2, columns <= 4 else {
            DebugLog.log("setColumnCount: columns out of range (must be 2-4)")
            return
        }
        guard let textStorage = textView.textStorage else {
            DebugLog.log("setColumnCount: no textStorage")
            return
        }

        // Ensure text view can accept input
        textView.window?.makeFirstResponder(textView)

        let currentRange = textView.selectedRange()
        DebugLog.log("setColumnCount: inserting at location \(currentRange.location)")

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

        let insertedRange = NSRange(location: currentRange.location, length: result.length)

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

        // Keep a faint outline where the columns are until the user starts typing.
        showPersistentColumnOutline(for: textTable, in: insertedRange)

        DebugLog.log("setColumnCount: columns inserted successfully")
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
            DebugLog.log("addColumnToExisting: already at max columns (4)")
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

        let newColumnRange = NSRange(location: startLocation, length: result.length)

        // Replace the old column layout with the new one
        textStorage.replaceCharacters(in: columnRange, with: result)
        textView.setSelectedRange(NSRange(location: startLocation + 1, length: 0))
        showPersistentColumnOutline(for: newTable, in: newColumnRange)
        DebugLog.log("addColumnToExisting: expanded from \(currentColumns) to \(newColumnCount) columns")
    }

    /// Set the column count for an existing column layout at the cursor.
    /// If not in columns, falls back to inserting a new column layout.
    func setColumnCountInExistingLayout(_ columns: Int) {
        DebugLog.log("setColumnCountInExistingLayout called with \(columns)")
        guard columns >= 2, columns <= 4 else {
            DebugLog.log("setColumnCountInExistingLayout: columns out of range (must be 2-4)")
            return
        }
        guard let textStorage = textView.textStorage else { return }
        let cursorLocation = textView.selectedRange().location
        guard cursorLocation < textStorage.length else { return }

        let attrs = textStorage.attributes(at: cursorLocation, effectiveRange: nil)
        guard let style = attrs[.paragraphStyle] as? NSParagraphStyle,
              let blocks = style.textBlocks as? [NSTextTableBlock],
              let block = blocks.first else {
            setColumnCount(columns)
            return
        }

        let existingTable = block.table
        let currentColumns = existingTable.numberOfColumns
        guard currentColumns != columns else { return }

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

        let columnRange = NSRange(location: startLocation, length: endLocation - startLocation)

        // Collect content per existing column
        let columnContents = Array(repeating: NSMutableAttributedString(), count: currentColumns)
        var scanLocation = startLocation
        while scanLocation < endLocation {
            let paragraphRange = string.paragraphRange(for: NSRange(location: scanLocation, length: 0))
            let attrs = textStorage.attributes(at: paragraphRange.location, effectiveRange: nil)
            if let pStyle = attrs[.paragraphStyle] as? NSParagraphStyle,
               let pBlocks = pStyle.textBlocks as? [NSTextTableBlock],
               let pBlock = pBlocks.first,
               pBlock.table === existingTable {
                let columnIndex = min(max(pBlock.startingColumn, 0), currentColumns - 1)
                let content = textStorage.attributedSubstring(from: paragraphRange)
                columnContents[columnIndex].append(content)
            }
            scanLocation = NSMaxRange(paragraphRange)
        }

        // Create new table with the requested column count
        let newTable = NSTextTable()
        newTable.numberOfColumns = columns
        newTable.layoutAlgorithm = .automaticLayoutAlgorithm
        newTable.collapsesBorders = true

        let result = NSMutableAttributedString()

        for i in 0..<columns {
            let textBlock = NSTextTableBlock(table: newTable, startingRow: 0, rowSpan: 1, startingColumn: i, columnSpan: 1)

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

            if i < currentColumns, columnContents[i].length > 0 {
                let mutableContent = NSMutableAttributedString(attributedString: columnContents[i])
                mutableContent.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: mutableContent.length), options: []) { value, range, _ in
                    let pStyle = (value as? NSParagraphStyle) ?? NSParagraphStyle.default
                    let mutablePStyle = (pStyle.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
                    mutablePStyle.textBlocks = [textBlock]
                    mutableContent.addAttribute(.paragraphStyle, value: mutablePStyle.copy() as! NSParagraphStyle, range: range)
                }
                result.append(mutableContent)
            } else {
                var colAttrs = textView.typingAttributes
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.textBlocks = [textBlock]
                colAttrs[.paragraphStyle] = paragraphStyle

                let columnContent = NSAttributedString(string: " \n", attributes: colAttrs)
                result.append(columnContent)
            }
        }

        let finalNewline = NSAttributedString(string: "\n", attributes: textView.typingAttributes)
        result.append(finalNewline)

        let newColumnRange = NSRange(location: startLocation, length: result.length)
        textStorage.replaceCharacters(in: columnRange, with: result)
        textView.setSelectedRange(NSRange(location: startLocation + 1, length: 0))
        showPersistentColumnOutline(for: newTable, in: newColumnRange)
        DebugLog.log("setColumnCountInExistingLayout: updated from \(currentColumns) to \(columns) columns")
    }

    // MARK: - Table System (separate from columns)

    func insertTable(rows: Int, columns: Int) {
        DebugLog.log("insertTable called with rows=\(rows), columns=\(columns)")
        guard rows >= 1, rows <= 10, columns >= 1, columns <= 6 else {
            DebugLog.log("insertTable: rows/columns out of range")
            return
        }
        guard let textStorage = textView.textStorage else {
            DebugLog.log("insertTable: no textStorage")
            return
        }

        // Ensure text view can accept input
        textView.window?.makeFirstResponder(textView)

        let currentRange = textView.selectedRange()
        DebugLog.log("insertTable: inserting at location \(currentRange.location)")

        // Tables should not inherit theme accent/chrome colors.
        // Use the document's current text color so tables read like text, not UI.
        let currentTextColor: NSColor = {
            if let c = textView.typingAttributes[.foregroundColor] as? NSColor { return c }
            return ThemeManager.shared.currentTheme.textColor
        }()
        let borderColor = currentTextColor.withAlphaComponent(0.35)

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
        var exitAttrs: [NSAttributedString.Key: Any] = [
            .font: textView.font ?? NSFont.systemFont(ofSize: 12),
            .paragraphStyle: textView.defaultParagraphStyle ?? NSParagraphStyle.default,
            .foregroundColor: currentTextColor
        ]
        // Avoid carrying any table/chrome styling onto the paragraph after the table.
        exitAttrs[.backgroundColor] = nil
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

        DebugLog.log("insertTable: table inserted successfully")
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
        guard let (table, _, rowToDelete, _) = findTableAtLocation(currentRange.location) else {
            return
        }

        DebugLog.log("deleteTableRow: row=\(rowToDelete) location=\(currentRange.location)")

        // Find the table range (current table only)
        let fullString = textStorage.string as NSString
        var startLocation = currentRange.location
        var endLocation = currentRange.location

        // Scan backward to table start
        while startLocation > 0 {
            let prevLocation = startLocation - 1
            let prevAttrs = textStorage.attributes(at: prevLocation, effectiveRange: nil)
            if let prevStyle = prevAttrs[.paragraphStyle] as? NSParagraphStyle,
               let prevBlocks = prevStyle.textBlocks as? [NSTextTableBlock],
               let prevBlock = prevBlocks.first,
               prevBlock.table === table {
                let prevRange = fullString.paragraphRange(for: NSRange(location: prevLocation, length: 0))
                startLocation = prevRange.location
            } else {
                break
            }
        }

        // Scan forward to table end
        endLocation = startLocation
        while endLocation < textStorage.length {
            let attrs = textStorage.attributes(at: endLocation, effectiveRange: nil)
            if let style = attrs[.paragraphStyle] as? NSParagraphStyle,
               let blocks = style.textBlocks as? [NSTextTableBlock],
               let block = blocks.first,
               block.table === table {
                let paragraphRange = fullString.paragraphRange(for: NSRange(location: endLocation, length: 0))
                endLocation = NSMaxRange(paragraphRange)
            } else {
                break
            }
        }

        // Collect all cells in this table range only
        var tableCells: [(range: NSRange, row: Int, column: Int, content: NSAttributedString)] = []
        var searchLocation = startLocation
        while searchLocation < endLocation {
            let attrs = textStorage.attributes(at: searchLocation, effectiveRange: nil)
            if let ps = attrs[.paragraphStyle] as? NSParagraphStyle,
               let blocks = ps.textBlocks as? [NSTextTableBlock],
               let block = blocks.first,
               block.table === table {
                let pRange = fullString.paragraphRange(for: NSRange(location: searchLocation, length: 0))
                let content = textStorage.attributedSubstring(from: pRange)
                tableCells.append((range: pRange, row: block.startingRow, column: block.startingColumn, content: content))
                searchLocation = NSMaxRange(pRange)
            } else {
                break
            }
        }

        guard !tableCells.isEmpty else { return }

        DebugLog.log("deleteTableRow: table range=\(startLocation)-\(endLocation), cells=\(tableCells.count)")

        let uniqueRows = Array(Set(tableCells.map { $0.row })).sorted()
        let remainingRows = uniqueRows.filter { $0 != rowToDelete }
        let totalRows = remainingRows.count
        let totalColumns = table.numberOfColumns

        DebugLog.log("deleteTableRow: rows=\(uniqueRows), remaining=\(remainingRows), cols=\(totalColumns)")

        if totalRows <= 0 {
            deleteTable()
            return
        }

        let fullTableRange = NSRange(location: startLocation, length: endLocation - startLocation)

        let newTable = NSTextTable()
        newTable.numberOfColumns = totalColumns
        newTable.layoutAlgorithm = .automaticLayoutAlgorithm
        newTable.collapsesBorders = true

        let borderColor = (ThemeManager.shared.currentTheme.headerBackground).withAlphaComponent(0.5)
        let result = NSMutableAttributedString()

        for (newRowIndex, row) in remainingRows.enumerated() {
            for col in 0..<totalColumns {
                let textBlock = NSTextTableBlock(table: newTable, startingRow: newRowIndex, rowSpan: 1, startingColumn: col, columnSpan: 1)

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

                if let cell = tableCells.first(where: { $0.row == row && $0.column == col })?.content {
                    let mutableContent = NSMutableAttributedString(attributedString: cell)
                    mutableContent.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: mutableContent.length))
                    result.append(mutableContent)
                } else {
                    var attrs = textView.typingAttributes
                    attrs[.paragraphStyle] = paragraphStyle
                    let placeholder = NSAttributedString(string: " \n", attributes: attrs)
                    result.append(placeholder)
                }
            }

        }

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

        textStorage.replaceCharacters(in: fullTableRange, with: result)
        textView.setSelectedRange(NSRange(location: startLocation, length: 0))
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
                        DebugLog.log("No table column found at cursor position")
            return
        }

        let table = currentBlock.table
        let columnToDelete = currentBlock.startingColumn
        let totalColumns = table.numberOfColumns

        if isColumnLayout(block: currentBlock) {
            deleteColumnFromColumnLayout(table: table, columnToDelete: columnToDelete, totalColumns: totalColumns, cursorPosition: cursorPosition)
            return
        }

        DebugLog.log("Deleting column \(columnToDelete) from table with \(totalColumns) columns")

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
            DebugLog.log("Converting table to body text (only \(totalColumns - 1) column(s) would remain)")

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

    private func isColumnLayout(block: NSTextTableBlock) -> Bool {
        let borderMinX = block.width(for: .border, edge: .minX)
        let borderMaxX = block.width(for: .border, edge: .maxX)
        let borderMinY = block.width(for: .border, edge: .minY)
        let borderMaxY = block.width(for: .border, edge: .maxY)

        let paddingMinX = block.width(for: .padding, edge: .minX)
        let paddingMaxX = block.width(for: .padding, edge: .maxX)
        let paddingMinY = block.width(for: .padding, edge: .minY)
        let paddingMaxY = block.width(for: .padding, edge: .maxY)

        // Columns are implemented with a 1-row NSTextTable where vertical padding is 0.
        // We also draw a *persistent outline* by temporarily setting a ~0.5pt border.
        // Treat that outline as still being a column layout so delete operations don't fall
        // back to the table code path (which rebuilds with table borders/padding).
        let maxBorderWidth = max(borderMinX, max(borderMaxX, max(borderMinY, borderMaxY)))
        let borderLooksLikeColumns = maxBorderWidth <= 0.6

        let verticalPaddingIsClear = paddingMinY <= 0.1 && paddingMaxY <= 0.1
        let horizontalPaddingLooksLikeColumns = paddingMinX >= 6.0 && paddingMaxX >= 6.0

        return borderLooksLikeColumns && verticalPaddingIsClear && horizontalPaddingLooksLikeColumns
    }

    private func deleteColumnFromColumnLayout(table: NSTextTable,
                                              columnToDelete: Int,
                                              totalColumns: Int,
                                              cursorPosition: Int) {
        guard let textStorage = textView.textStorage else { return }

        let fullString = textStorage.string as NSString
        var startLocation = cursorPosition
        var endLocation = cursorPosition

        // Scan backward to find start
        while startLocation > 0 {
            let prevLoc = startLocation - 1
            let prevAttrs = textStorage.attributes(at: prevLoc, effectiveRange: nil)
            if let prevStyle = prevAttrs[.paragraphStyle] as? NSParagraphStyle,
               let prevBlocks = prevStyle.textBlocks as? [NSTextTableBlock],
               let prevBlock = prevBlocks.first,
               prevBlock.table === table {
                let paragraphRange = fullString.paragraphRange(for: NSRange(location: prevLoc, length: 0))
                startLocation = paragraphRange.location
            } else {
                break
            }
        }

        // Scan forward to find end
        while endLocation < textStorage.length {
            let attrs = textStorage.attributes(at: endLocation, effectiveRange: nil)
            if let style = attrs[.paragraphStyle] as? NSParagraphStyle,
               let blocks = style.textBlocks as? [NSTextTableBlock],
               let block = blocks.first,
               block.table === table {
                let paragraphRange = fullString.paragraphRange(for: NSRange(location: endLocation, length: 0))
                endLocation = NSMaxRange(paragraphRange)
            } else {
                break
            }
        }

        let columnRange = NSRange(location: startLocation, length: endLocation - startLocation)

        let columnContents = Array(repeating: NSMutableAttributedString(), count: totalColumns)
        var scanLocation = startLocation
        while scanLocation < endLocation {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: scanLocation, length: 0))
            let attrs = textStorage.attributes(at: paragraphRange.location, effectiveRange: nil)
            if let pStyle = attrs[.paragraphStyle] as? NSParagraphStyle,
               let pBlocks = pStyle.textBlocks as? [NSTextTableBlock],
               let pBlock = pBlocks.first,
               pBlock.table === table {
                let columnIndex = min(max(pBlock.startingColumn, 0), totalColumns - 1)
                let content = textStorage.attributedSubstring(from: paragraphRange)
                columnContents[columnIndex].append(content)
            }
            scanLocation = NSMaxRange(paragraphRange)
        }

        let remainingColumns = totalColumns - 1
        if remainingColumns <= 1 {
            let bodyParagraphStyle = NSMutableParagraphStyle()
            bodyParagraphStyle.alignment = .left
            bodyParagraphStyle.lineHeightMultiple = 2.0
            bodyParagraphStyle.paragraphSpacing = 0
            bodyParagraphStyle.firstLineHeadIndent = 36

            let bodyText = NSMutableAttributedString()
            let bodyFont = NSFont(name: "Times New Roman", size: 12) ?? NSFont.systemFont(ofSize: 12)

            for column in 0..<totalColumns where column != columnToDelete {
                let mutableContent = NSMutableAttributedString(attributedString: columnContents[column])
                mutableContent.removeAttribute(.paragraphStyle, range: NSRange(location: 0, length: mutableContent.length))
                mutableContent.addAttribute(.paragraphStyle, value: bodyParagraphStyle, range: NSRange(location: 0, length: mutableContent.length))
                mutableContent.enumerateAttribute(.font, in: NSRange(location: 0, length: mutableContent.length), options: []) { value, range, _ in
                    if value == nil {
                        mutableContent.addAttribute(.font, value: bodyFont, range: range)
                    }
                }
                bodyText.append(mutableContent)
            }

            textStorage.replaceCharacters(in: columnRange, with: bodyText)
            textView.setSelectedRange(NSRange(location: startLocation, length: 0))
            return
        }

        let newTable = NSTextTable()
        newTable.numberOfColumns = remainingColumns
        newTable.layoutAlgorithm = .automaticLayoutAlgorithm
        newTable.collapsesBorders = true

        let result = NSMutableAttributedString()
        var newColumnIndex = 0
        for column in 0..<totalColumns {
            if column == columnToDelete {
                continue
            }

            let textBlock = NSTextTableBlock(table: newTable, startingRow: 0, rowSpan: 1, startingColumn: newColumnIndex, columnSpan: 1)
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

            let columnContent = columnContents[column]
            if columnContent.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // For empty columns, generate a single clean paragraph like setColumnCount()
                // so we don't accidentally accumulate extra empty paragraphs in the first column.
                var attrs = textView.typingAttributes

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

                result.append(NSAttributedString(string: "\n", attributes: attrs))
            } else {
                let mutableContent = NSMutableAttributedString(attributedString: columnContent)
                // Retarget paragraph styles *per paragraph* so each paragraph (including its trailing newline)
                // is assigned to the correct column block.
                let columnString = mutableContent.string as NSString
                var paragraphLocation = 0
                while paragraphLocation < columnString.length {
                    let paragraphRange = columnString.paragraphRange(for: NSRange(location: paragraphLocation, length: 0))
                    let attrs = mutableContent.attributes(at: paragraphRange.location, effectiveRange: nil)
                    let pStyle = (attrs[.paragraphStyle] as? NSParagraphStyle) ?? NSParagraphStyle.default
                    let mutablePStyle = (pStyle.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
                    mutablePStyle.textBlocks = [textBlock]
                    mutableContent.addAttribute(.paragraphStyle, value: mutablePStyle.copy() as! NSParagraphStyle, range: paragraphRange)
                    paragraphLocation = NSMaxRange(paragraphRange)
                }
                result.append(mutableContent)
            }

            newColumnIndex += 1
        }

        // Add a final newline *outside* the column layout. Do not use typingAttributes here,
        // because they may still contain a table paragraph style and would keep the newline
        // inside the column blocks (creating extra blank lines).
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

        let newColumnRange = NSRange(location: startLocation, length: result.length)
        textStorage.replaceCharacters(in: columnRange, with: result)
        // Place the caret just after the first column's paragraph terminator so typing
        // inherits the first column's block attributes.
        textView.setSelectedRange(NSRange(location: min(startLocation + 1, startLocation + max(0, result.length - 1)), length: 0))
        showPersistentColumnOutline(for: newTable, in: newColumnRange)
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
        let shadowColor = NSColor.black.withAlphaComponent(theme == .night ? 0.65 : 0.3)
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

        applyParagraphMarksVisibility()
    }

    private func adjustIndent(by delta: CGFloat) {
        applyParagraphEditsToSelectedParagraphs { style in
            let firstLineDelta = style.firstLineHeadIndent - style.headIndent
            let newHeadIndent = max(0, style.headIndent + delta)
            style.headIndent = newHeadIndent
            style.firstLineHeadIndent = max(0, newHeadIndent + firstLineDelta)
        }

        if let defaultStyle = (textView.defaultParagraphStyle as? NSMutableParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle {
            let firstLineDelta = defaultStyle.firstLineHeadIndent - defaultStyle.headIndent
            let newHeadIndent = max(0, defaultStyle.headIndent + delta)
            defaultStyle.headIndent = newHeadIndent
            defaultStyle.firstLineHeadIndent = max(0, newHeadIndent + firstLineDelta)
            textView.defaultParagraphStyle = defaultStyle.copy() as? NSParagraphStyle
            refreshTypingAttributesUsingDefaultParagraphStyle()
        }
    }

    private func applyParagraphEditsToSelectedParagraphs(_ edit: (NSMutableParagraphStyle) -> Void) {
        guard let textStorage = textView.textStorage else { return }
        guard textStorage.length > 0 else { return }
        guard let selected = textView.selectedRanges.first?.rangeValue else { return }
        let fullText = (textStorage.string as NSString)
        let safeLocation = min(selected.location, max(0, textStorage.length - 1))
        let safeRange = NSRange(location: safeLocation, length: selected.length)
        let paragraphsRange = fullText.paragraphRange(for: safeRange)
        guard paragraphsRange.location < textStorage.length else { return }
        guard paragraphsRange.length > 0 else { return }

        performUndoableTextStorageEdit(in: paragraphsRange, actionName: "Paragraph Formatting") { storage in
            storage.enumerateAttribute(.paragraphStyle, in: paragraphsRange, options: []) { value, range, _ in
                let current = (value as? NSParagraphStyle) ?? textView.defaultParagraphStyle ?? NSParagraphStyle.default
                guard let mutable = current.mutableCopy() as? NSMutableParagraphStyle else { return }

                // Preserve textBlocks (for tables/columns) before editing
                let existingTextBlocks = current.textBlocks

                edit(mutable)

                // Restore textBlocks after editing to keep table/column structure
                if !existingTextBlocks.isEmpty {
                    mutable.textBlocks = existingTextBlocks
                }

                storage.addAttribute(.paragraphStyle, value: mutable.copy() as! NSParagraphStyle, range: range)
            }
        }
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

        let markerRanges = indexMarkerRanges(in: targetRange, storage: textStorage)

        performUndoableTextStorageEdit(in: targetRange, actionName: "Font Change") { storage in
            storage.enumerateAttribute(.font, in: targetRange, options: []) { value, range, _ in
                let current = (value as? NSFont) ?? baseFont
                let newFont = transform(current)

                for subrange in subrangesExcluding(markerRanges, from: range) {
                    storage.addAttribute(.font, value: newFont, range: subrange)
                }
            }
        }

        // Update typing attributes only for future typing at cursor position
        if selectedRange.length == 0 {
            let newTypingFont = transform(baseFont)
            textView.typingAttributes[.font] = newTypingFont
        }
    }

    private func performUndoableTextStorageEdit(in range: NSRange, actionName: String?, _ edit: (NSTextStorage) -> Void) {
        guard let storage = textView.textStorage else { return }
        guard range.location != NSNotFound else { return }
        guard range.length >= 0 else { return }
        guard textView.shouldChangeText(in: range, replacementString: nil) else { return }

        storage.beginEditing()
        edit(storage)
        storage.endEditing()

        textView.didChangeText()
        if let actionName, !suppressUndoActionNames {
            textView.undoManager?.setActionName(actionName)
        }
    }

    private func currentListLevel(for paragraphRange: NSRange) -> Int {
        guard let storage = textView.textStorage, paragraphRange.location < storage.length else { return 1 }
        let style = (storage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle)
            ?? textView.defaultParagraphStyle
            ?? NSParagraphStyle.default
        let base = standardIndentStep
        let indent = style.firstLineHeadIndent
        if indent <= base + 0.5 { return 1 }
        let delta = max(0, indent - base)
        let levelOffset = Int(round(delta / standardIndentStep))
        return max(1, levelOffset + 1)
    }

    private func normalizedComponents(_ components: [Int], for level: Int, scheme: QuillPilotSettings.NumberingScheme) -> [Int] {
        if scheme == .decimalDotted { return components }
        let target = max(1, level)
        if components.count == target { return components }
        if components.count > target { return Array(components.prefix(target)) }
        var padded = components
        while padded.count < target {
            padded.append(1)
        }
        return padded
    }

    private func applyListIndent(levelCount: Int, paragraphRange: NSRange) {
        guard let storage = textView.textStorage else { return }
        guard storage.length > 0 else { return }
        guard paragraphRange.location < storage.length else { return }
        guard paragraphRange.length > 0 else { return }
        let clampedLevel = max(1, levelCount)
        let baseIndent: CGFloat = (clampedLevel <= 1) ? 0 : standardIndentStep
        let levelOffset = CGFloat(clampedLevel - 1) * standardIndentStep
        let firstLineIndent = baseIndent + levelOffset

        let font = (storage.attribute(.font, at: paragraphRange.location, effectiveRange: nil) as? NSFont)
            ?? textView.font
            ?? NSFont.systemFont(ofSize: 12)

        storage.enumerateAttribute(.paragraphStyle, in: paragraphRange, options: []) { value, range, _ in
            let current = (value as? NSParagraphStyle) ?? textView.defaultParagraphStyle ?? NSParagraphStyle.default
            guard let mutable = current.mutableCopy() as? NSMutableParagraphStyle else { return }

            let paragraphText = (storage.string as NSString).substring(with: range)
            let scheme = QuillPilotSettings.numberingScheme
            let prefixString: String
            if let parsed = parseNumberPrefix(in: paragraphText, scheme: scheme) {
                let endIndex = paragraphText.index(paragraphText.startIndex, offsetBy: parsed.prefixLength)
                prefixString = String(paragraphText[..<endIndex])
            } else if let bullet = parseBulletPrefix(in: paragraphText) {
                prefixString = bullet.prefix
            } else {
                prefixString = ""
            }
            let prefixWidth = (prefixString as NSString).size(withAttributes: [.font: font]).width
            let tabLocation = max(firstLineIndent + 18, firstLineIndent + prefixWidth + 8)

            let tabStop = NSTextTab(textAlignment: .left, location: tabLocation, options: [:])
            mutable.tabStops = [tabStop]
            mutable.defaultTabInterval = 0
            mutable.firstLineHeadIndent = firstLineIndent
            mutable.headIndent = tabLocation
            storage.addAttribute(.paragraphStyle, value: mutable.copy() as! NSParagraphStyle, range: range)
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
                    var prefixLen: Int
                    if let bullet = parseBulletPrefix(in: para.text) {
                        prefixLen = bullet.prefixLengthUTF16 + (bullet.hasTabAfter ? 1 : 0)
                    } else if let parsed = parseNumberPrefix(in: para.text, scheme: QuillPilotSettings.numberingScheme) {
                        prefixLen = parsed.prefixLength + (parsed.hasTabAfter ? 1 : 0)
                    } else {
                        prefixLen = (para.text.firstIndex(of: ".") ?? para.text.startIndex).utf16Offset(in: para.text) + 2
                        if para.text.count > prefixLen && para.text[para.text.index(para.text.startIndex, offsetBy: prefixLen)] == "\t" {
                            prefixLen += 1
                        }
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
                let tabInsertLocation = para.range.location + (prefix as NSString).length
                textStorage.replaceCharacters(in: NSRange(location: tabInsertLocation, length: 0), with: "\t")

                // Set up hanging indent with tab stop (level 1 starts at the margin)
                let adjustedRange = NSRange(location: para.range.location, length: para.range.length + (prefix as NSString).length + 1)
                textStorage.enumerateAttribute(.paragraphStyle, in: adjustedRange, options: []) { value, range, _ in
                    let current = (value as? NSParagraphStyle) ?? textView.defaultParagraphStyle ?? NSParagraphStyle.default
                    guard let mutable = current.mutableCopy() as? NSMutableParagraphStyle else { return }

                    // Set up tab stop for alignment
                    let prefixWidth = (prefix as NSString).size(withAttributes: [.font: textView.font ?? NSFont.systemFont(ofSize: 12)]).width
                    let tabLocation = max(18, prefixWidth + 8)
                    let tabStop = NSTextTab(textAlignment: .left, location: tabLocation, options: [:])
                    mutable.tabStops = [tabStop]
                    mutable.defaultTabInterval = 0

                    // Hanging indent: first line at margin, wrapped lines at tab position
                    mutable.firstLineHeadIndent = 0
                    mutable.headIndent = tabLocation

                    textStorage.addAttribute(.paragraphStyle, value: mutable.copy() as! NSParagraphStyle, range: range)
                }
            }
        }
        textStorage.endEditing()
    }
}

extension EditorViewController: NSTextViewDelegate {
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertBacktab(_:)) {
            return false
        }
        if commandSelector == #selector(NSResponder.moveToEndOfDocument(_:)) {
            scrollToBottom()
            return true
        }

        if commandSelector == #selector(NSResponder.moveToBeginningOfDocument(_:)) {
            scrollToTop()
            return true
        }

        guard let storage = textView.textStorage else { return false }
        let sel = textView.selectedRange()
        guard sel.location <= storage.length else { return false }

        guard sel.length == 0 else { return false }

        // Avoid interfering with complex structures.
        if isCurrentPositionInTable() || isCurrentPositionInColumns() {
            return false
        }

        let full = storage.string as NSString
        let paragraphRange = full.paragraphRange(for: NSRange(location: sel.location, length: 0))
        let paragraphText = full.substring(with: paragraphRange)

        if commandSelector == #selector(insertTab(_:)) {
            // Tab sets the next Return to create a sub-level without changing the current line.
            let scheme = QuillPilotSettings.numberingScheme
            let isNumbered = parseNumberPrefix(in: paragraphText, scheme: scheme) != nil
            let isBulleted = parseBulletPrefix(in: paragraphText) != nil
            guard isNumbered || isBulleted else { return false }
            pendingListIndentOnReturn = true
            let currentLevel = currentListLevel(for: paragraphRange)
            pendingListIndentTargetLevel = currentLevel + 1
            return true
        }

        guard commandSelector == #selector(insertNewline(_:)) else {
            pendingListIndentOnReturn = false
            pendingListIndentTargetLevel = nil
            return false
        }
        guard QuillPilotSettings.autoNumberOnReturn else { return false }

        let scheme = QuillPilotSettings.numberingScheme

        if let parsed = parseNumberPrefix(in: paragraphText, scheme: scheme) {
            // If the list item is empty (only a prefix), pressing Return should end the list.
            let contentStart = min(paragraphText.count, parsed.prefixLength + (parsed.hasTabAfter ? 1 : 0))
            let remainder = String(paragraphText.dropFirst(contentStart)).trimmingCharacters(in: .whitespacesAndNewlines)
            if remainder.isEmpty {
                // Remove prefix and let AppKit insert a normal newline.
                let deleteLen = parsed.prefixLength + (parsed.hasTabAfter ? 1 : 0)
                storage.replaceCharacters(in: NSRange(location: paragraphRange.location, length: min(deleteLen, paragraphRange.length)), with: "")
                return false
            }

            if pendingListIndentOnReturn {
                let currentLevel = currentListLevel(for: paragraphRange)
                let targetLevel = pendingListIndentTargetLevel ?? (currentLevel + 1)
                var next = normalizedComponents(parsed.components, for: max(1, targetLevel - 1), scheme: scheme)
                next.append(1)
                let nextPrefix = makeNumberPrefix(from: next, scheme: scheme) + (parsed.hasTabAfter ? "\t" : "")
                textView.insertText("\n" + nextPrefix, replacementRange: sel)

                let newSelection = textView.selectedRange()
                let updatedFull = textView.string as NSString
                let newParagraphRange = updatedFull.paragraphRange(for: NSRange(location: newSelection.location, length: 0))
                applyListIndent(levelCount: next.count, paragraphRange: newParagraphRange)

                pendingListIndentOnReturn = false
                pendingListIndentTargetLevel = nil
                return true
            }

            // Insert a newline plus the next number prefix.
            let currentLevel = currentListLevel(for: paragraphRange)
            var next = normalizedComponents(parsed.components, for: currentLevel, scheme: scheme)
            next[next.count - 1] += 1
            let nextPrefix = makeNumberPrefix(from: next, scheme: scheme) + (parsed.hasTabAfter ? "\t" : "")
            textView.insertText("\n" + nextPrefix, replacementRange: sel)
            let newSelection = textView.selectedRange()
            let updatedFull = textView.string as NSString
            let newParagraphRange = updatedFull.paragraphRange(for: NSRange(location: newSelection.location, length: 0))
            applyListIndent(levelCount: currentLevel, paragraphRange: newParagraphRange)
            pendingListIndentOnReturn = false
            pendingListIndentTargetLevel = nil
            return true
        }

        if let bullet = parseBulletPrefix(in: paragraphText) {
            // If the list item is empty (only a prefix), pressing Return should end the list.
            let deleteLen = bullet.prefixLengthUTF16 + (bullet.hasTabAfter ? 1 : 0)
            let ns = paragraphText as NSString
            let remainderStart = min(ns.length, deleteLen)
            let remainder = ns.substring(from: remainderStart).trimmingCharacters(in: .whitespacesAndNewlines)
            if remainder.isEmpty {
                storage.replaceCharacters(in: NSRange(location: paragraphRange.location, length: min(deleteLen, paragraphRange.length)), with: "")
                return false
            }

            let currentLevel = currentListLevel(for: paragraphRange)
            let targetLevel: Int
            if pendingListIndentOnReturn {
                targetLevel = pendingListIndentTargetLevel ?? (currentLevel + 1)
            } else {
                targetLevel = currentLevel
            }

            // Continue with the bullet style already in use for this list (not necessarily the current global preference).
            let nextPrefix = bullet.prefix + "\t"
            textView.insertText("\n" + nextPrefix, replacementRange: sel)
            let newSelection = textView.selectedRange()
            let updatedFull = textView.string as NSString
            let newParagraphRange = updatedFull.paragraphRange(for: NSRange(location: newSelection.location, length: 0))
            applyListIndent(levelCount: targetLevel, paragraphRange: newParagraphRange)
            pendingListIndentOnReturn = false
            pendingListIndentTargetLevel = nil
            return true
        }

        return false
    }

    func textDidChange(_ notification: Notification) {
        // Skip notification if we're suppressing changes (e.g., during column insertion)
        guard !suppressTextChangeNotifications else { return }

        // Make undo granular: stop the text system from coalescing many edits into one undo step.
        textView.breakUndoCoalescing()

        if persistentColumnOutline != nil {
            clearPersistentColumnOutline()
        }

        delegate?.textDidChange()

        // When resizing an image, we still want to mark the doc dirty, but we don't
        // want the delayed page-centering pass to scroll-jump on every slider tick.
        if suppressLayoutDuringImageResize {
            return
        }

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
        guard textStorage.length > 0 else { return false }
        let selection = textView.selectedRange()
        let location = min(selection.location, max(0, textStorage.length - 1))
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
        guard textStorage.length > 0 else { return false }
        let selection = textView.selectedRange()
        let location = min(selection.location, max(0, textStorage.length - 1))
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
              let selectedRange = textView?.selectedRanges.first?.rangeValue else {
            return
        }

        // Get the current paragraph
        let paragraphRange = (textView.string as NSString).paragraphRange(for: selectedRange)

        // Prefer explicit style tagging (more reliable than heuristics).
        if let styleName = textStorage.attribute(styleAttributeKey, at: paragraphRange.location, effectiveRange: nil) as? String {
            let trimmed = (textView.string as NSString)
                .substring(with: paragraphRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let isTitleStyle = (styleName == "Poem Title" || styleName == "Poetry — Title" || styleName == "Book Title")
            let isAuthorStyle = (styleName == "Poetry — Author" || styleName == "Poet Name" || styleName == "Author Name")

            if !trimmed.isEmpty {
                if isTitleStyle {
                    delegate?.titleDidChange(trimmed)
                }
                if isAuthorStyle {
                    delegate?.authorDidChange(trimmed)
                }
            }

            if isTitleStyle || isAuthorStyle {
                return
            }
        }

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

        pendingListIndentOnReturn = false
        pendingListIndentTargetLevel = nil

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

private extension EditorViewController {
    func adjustNumberingLevelInSelection(by delta: Int) -> Bool {
        guard delta != 0 else { return false }
        let scheme = QuillPilotSettings.numberingScheme
        guard let textStorage = textView.textStorage else { return false }
        guard textStorage.length > 0 else { return false }
        guard let selectedRange = textView.selectedRanges.first?.rangeValue else { return false }

        let fullText = textStorage.string as NSString
        let safeLocation = min(selectedRange.location, max(0, textStorage.length - 1))
        let safeRange = NSRange(location: safeLocation, length: selectedRange.length)
        let paragraphsRange = fullText.paragraphRange(for: safeRange)
        guard paragraphsRange.location < textStorage.length else { return false }
        guard paragraphsRange.length > 0 else { return false }

        var paragraphs: [(range: NSRange, text: String)] = []
        fullText.enumerateSubstrings(in: paragraphsRange, options: [.byParagraphs, .substringNotRequired]) { _, subrange, _, _ in
            let text = fullText.substring(with: subrange)
            paragraphs.append((subrange, text))
        }

        var anyChanged = false
        performUndoableTextStorageEdit(in: paragraphsRange, actionName: delta > 0 ? "Indent" : "Outdent") { storage in
            for para in paragraphs.reversed() {
                guard let parsed = parseNumberPrefix(in: para.text, scheme: scheme) else { continue }
                let currentLevel = currentListLevel(for: para.range)
                var nextComponents = normalizedComponents(parsed.components, for: currentLevel, scheme: scheme)

                if delta > 0 {
                    nextComponents.append(1)
                } else {
                    guard nextComponents.count > 1 else { continue }
                    nextComponents.removeLast()
                }

                let replaceLen = parsed.prefixLength + (parsed.hasTabAfter ? 1 : 0)
                let replaceRange = NSRange(location: para.range.location, length: min(replaceLen, para.range.length))
                let prefix = makeNumberPrefix(from: nextComponents, scheme: scheme)
                let replacement = prefix + (parsed.hasTabAfter ? "\t" : "")
                storage.replaceCharacters(in: replaceRange, with: replacement)

                applyListIndent(levelCount: nextComponents.count, paragraphRange: para.range)

                anyChanged = true
            }
        }

        return anyChanged
    }
}
