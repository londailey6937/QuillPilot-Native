//
//  PoetryLineNumberView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

/// A view that displays line numbers and syllable counts in the margin for poetry
final class PoetryLineNumberView: NSView {

    enum DisplayMode {
        case lineNumbers
        case syllables
        case both
    }

    // MARK: - Properties

    weak var textView: NSTextView?
    var displayMode: DisplayMode = .both {
        didSet { needsDisplay = true }
    }
    var showLineNumbers: Bool = true {
        didSet { needsDisplay = true }
    }
    var showSyllables: Bool = true {
        didSet { needsDisplay = true }
    }

    private var lineNumberFont: NSFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
    private var syllableFont: NSFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .light)
    private var lineNumberColor: NSColor = .secondaryLabelColor
    private var syllableColor: NSColor = .tertiaryLabelColor

    private let lineNumberPadding: CGFloat = 4
    private let syllablePadding: CGFloat = 4

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let textStorage = textView.textStorage ?? NSTextStorage()
        let content = textStorage.string
        let visibleRect = textView.visibleRect

        // Get the range of visible glyphs
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        // Determine which lines are visible
        let lines = content.components(separatedBy: .newlines)

        var charIndex = 0
        var lineNumber = 1

        // Calculate text view offset relative to this view
        let textOrigin = textView.textContainerOrigin

        for line in lines {
            let lineRange = NSRange(location: charIndex, length: line.count)

            // Check if this line intersects with visible range
            if NSIntersectionRange(lineRange, charRange).length > 0 ||
               (lineRange.location < charRange.upperBound && lineRange.upperBound >= charRange.location) {

                // Get the bounding rect for this line
                let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: lineRange.location, length: max(1, lineRange.length)), actualCharacterRange: nil)
                var lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

                // Adjust for text view position
                lineRect.origin.y += textOrigin.y

                // Convert to this view's coordinate system
                let localY = convert(NSPoint(x: 0, y: lineRect.origin.y), from: textView).y

                // Draw line number
                if showLineNumbers {
                    drawLineNumber(lineNumber, at: localY, lineHeight: lineRect.height)
                }

                // Draw syllable count
                if showSyllables && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    let syllableCount = SyllableCounter.countSyllablesInLine(line)
                    drawSyllableCount(syllableCount, at: localY, lineHeight: lineRect.height)
                }
            }

            charIndex += line.count + 1 // +1 for newline
            lineNumber += 1

            // Break if we've gone past visible range
            if charIndex > charRange.upperBound + 100 {
                break
            }
        }
    }

    private func drawLineNumber(_ number: Int, at y: CGFloat, lineHeight: CGFloat) {
        let text = "\(number)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: lineNumberColor
        ]

        let size = text.size(withAttributes: attributes)
        let x = bounds.width - size.width - lineNumberPadding - (showSyllables ? 30 : 0)
        let yOffset = (lineHeight - size.height) / 2

        text.draw(at: NSPoint(x: max(lineNumberPadding, x), y: y + yOffset), withAttributes: attributes)
    }

    private func drawSyllableCount(_ count: Int, at y: CGFloat, lineHeight: CGFloat) {
        let text = "(\(count))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: syllableFont,
            .foregroundColor: syllableColor
        ]

        let size = text.size(withAttributes: attributes)
        let x = bounds.width - size.width - syllablePadding
        let yOffset = (lineHeight - size.height) / 2

        text.draw(at: NSPoint(x: x, y: y + yOffset), withAttributes: attributes)
    }

    // MARK: - Update

    func updateLineNumbers() {
        needsDisplay = true
    }

    override var isFlipped: Bool { true }
}

// MARK: - Poetry Gutter Manager

/// Manages the poetry line number gutter for EditorViewController
final class PoetryGutterManager {

    weak var scrollView: NSScrollView?
    weak var textView: NSTextView?

    private var gutterView: PoetryLineNumberView?
    private var boundsObserver: NSObjectProtocol?
    private var textObserver: NSObjectProtocol?

    var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                setupGutter()
            } else {
                removeGutter()
            }
        }
    }

    var showLineNumbers: Bool = true {
        didSet {
            gutterView?.showLineNumbers = showLineNumbers
        }
    }

    var showSyllables: Bool = true {
        didSet {
            gutterView?.showSyllables = showSyllables
        }
    }

    private let gutterWidth: CGFloat = 60

    func setupGutter() {
        guard isEnabled, let scrollView = scrollView, let textView = textView else { return }

        // Remove existing gutter if any
        gutterView?.removeFromSuperview()

        // Create gutter view
        let gutter = PoetryLineNumberView(frame: NSRect(x: 0, y: 0, width: gutterWidth, height: scrollView.contentView.bounds.height))
        gutter.textView = textView
        gutter.showLineNumbers = showLineNumbers
        gutter.showSyllables = showSyllables
        gutter.autoresizingMask = [.height]
        gutterView = gutter

        // Add to scroll view
        scrollView.addSubview(gutter)

        // Observe scroll changes
        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            self?.gutterView?.needsDisplay = true
        }

        // Observe text changes
        textObserver = NotificationCenter.default.addObserver(
            forName: NSText.didChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            self?.gutterView?.needsDisplay = true
        }

        updateGutterFrame()
    }

    func removeGutter() {
        if let observer = boundsObserver {
            NotificationCenter.default.removeObserver(observer)
            boundsObserver = nil
        }
        if let observer = textObserver {
            NotificationCenter.default.removeObserver(observer)
            textObserver = nil
        }
        gutterView?.removeFromSuperview()
        gutterView = nil
    }

    func updateGutterFrame() {
        guard let scrollView = scrollView, let gutter = gutterView else { return }

        let contentBounds = scrollView.contentView.bounds
        gutter.frame = NSRect(
            x: contentBounds.origin.x,
            y: contentBounds.origin.y,
            width: gutterWidth,
            height: contentBounds.height
        )
        gutter.needsDisplay = true
    }

    func refresh() {
        gutterView?.needsDisplay = true
    }

    deinit {
        removeGutter()
    }
}
