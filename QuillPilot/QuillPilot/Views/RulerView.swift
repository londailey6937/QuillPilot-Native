//
//  RulerView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

protocol RulerViewDelegate: AnyObject {
    func rulerView(_ ruler: EnhancedRulerView, didChangeLeftMargin: CGFloat)
    func rulerView(_ ruler: EnhancedRulerView, didChangeRightMargin: CGFloat)
    func rulerView(_ ruler: EnhancedRulerView, didChangeFirstLineIndent: CGFloat)
}

class EnhancedRulerView: NSView {

    weak var delegate: RulerViewDelegate?
    // Visual scale factor. Margins and pageWidth are stored in unscaled points (72pt = 1 inch).
    // This zoom should match the editor's zoom so ruler markings align with the rendered page.
    var rulerZoom: CGFloat = 1.4 {
        didSet {
            if abs(oldValue - rulerZoom) < 0.001 { return }
            needsLayout = true
            needsDisplay = true
        }
    }

    var scaledPageWidth: CGFloat {
        pageWidth * rulerZoom
    }

    private var leftMarginHandle: MarginHandle!
    private var rightMarginHandle: MarginHandle!
    private var firstLineIndentHandle: MarginHandle!
    private var markingsColor: NSColor = ThemeManager.shared.currentTheme.rulerMarkings

    // Margin values in points (72pt = 1 inch)
    var leftMargin: CGFloat = 72 {
        didSet { updateHandlePositions() }
    }
    var rightMargin: CGFloat = 72 {
        didSet { updateHandlePositions() }
    }
    var firstLineIndent: CGFloat = 36 {
        didSet { updateHandlePositions() }
    }

    // Page width for reference (8.5" = 612pt)
    var pageWidth: CGFloat = 612

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        applyTheme(ThemeManager.shared.currentTheme)

        // Create left margin handle (down-pointing triangle)
        leftMarginHandle = MarginHandle(type: .leftMargin)
        leftMarginHandle.ruler = self
        addSubview(leftMarginHandle)

        // Create right margin handle (down-pointing triangle)
        rightMarginHandle = MarginHandle(type: .rightMargin)
        rightMarginHandle.ruler = self
        addSubview(rightMarginHandle)

        // Create first-line indent handle (up-pointing triangle)
        firstLineIndentHandle = MarginHandle(type: .firstLineIndent)
        firstLineIndentHandle.ruler = self
        addSubview(firstLineIndentHandle)

        updateHandlePositions()
    }

    private func updateHandlePositions() {
        let rulerHeight = bounds.height
        let centerOffset = (bounds.width - scaledPageWidth) / 2

        // Left margin handle at bottom
        leftMarginHandle.frame = NSRect(
            x: centerOffset + (leftMargin * rulerZoom) - 6,
            y: rulerHeight - 12,
            width: 12,
            height: 10
        )

        // Right margin handle at bottom
        let rightX = centerOffset + ((pageWidth - rightMargin) * rulerZoom)
        rightMarginHandle.frame = NSRect(
            x: rightX - 6,
            y: rulerHeight - 12,
            width: 12,
            height: 10
        )

        // First-line indent handle at top
        firstLineIndentHandle.frame = NSRect(
            x: centerOffset + ((leftMargin + firstLineIndent) * rulerZoom) - 6,
            y: 2,
            width: 12,
            height: 10
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rulerHeight = bounds.height
        let fontSize: CGFloat = 9

        // Center the ruler markings to align with page
        let centerOffset = (bounds.width - scaledPageWidth) / 2

        markingsColor.set()

        // Draw tick marks every 0.5 inch
        for i in 0...17 {
            let x = CGFloat(i) * 36 * rulerZoom
            let tickHeight: CGFloat = (i % 2 == 0) ? 8 : 4

            let path = NSBezierPath()
            path.move(to: NSPoint(x: x + centerOffset, y: rulerHeight - tickHeight))
            path.line(to: NSPoint(x: x + centerOffset, y: rulerHeight))
            path.lineWidth = 1
            path.stroke()

            // Draw inch numbers
            if i % 2 == 0 && i > 0 {
                let label = "\(i/2)"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: fontSize),
                    .foregroundColor: ThemeManager.shared.currentTheme.rulerMarkings
                ]
                let size = (label as NSString).size(withAttributes: attrs)
                label.draw(
                    at: NSPoint(x: x + centerOffset - (size.width / 2), y: rulerHeight/2 - (size.height / 2)),
                    withAttributes: attrs
                )
            } else if i == 17 {  // Special case for 8.5"
                let label = "8.5"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: fontSize - 1),
                    .foregroundColor: ThemeManager.shared.currentTheme.rulerMarkings
                ]
                let size = (label as NSString).size(withAttributes: attrs)
                label.draw(
                    at: NSPoint(x: x + centerOffset - (size.width / 2), y: rulerHeight/2 - (size.height / 2)),
                    withAttributes: attrs
                )
            }
        }
    }

    override func layout() {
        super.layout()
        updateHandlePositions()
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            leftMargin = 72
            rightMargin = 72
            firstLineIndent = 36
            delegate?.rulerView(self, didChangeLeftMargin: leftMargin)
            delegate?.rulerView(self, didChangeRightMargin: rightMargin)
            delegate?.rulerView(self, didChangeFirstLineIndent: firstLineIndent)
            return
        }
        super.mouseDown(with: event)
    }

    func applyTheme(_ theme: AppTheme) {
        layer?.backgroundColor = theme.rulerBackground.cgColor
        if theme == .cream {
            layer?.borderWidth = 0
        } else {
            layer?.borderWidth = 1
            layer?.borderColor = theme.rulerBorder.cgColor
        }
        markingsColor = theme.rulerMarkings
        needsDisplay = true
    }
}

// MARK: - Margin Handle
enum MarginHandleType {
    case leftMargin
    case rightMargin
    case firstLineIndent
}

class MarginHandle: NSView {

    weak var ruler: EnhancedRulerView?
    let type: MarginHandleType
    private var isDragging = false
    private var dragStartLocation: NSPoint = .zero
    private var dragStartMargin: CGFloat = 0

    init(type: MarginHandleType) {
        self.type = type
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let path = NSBezierPath()

        switch type {
        case .leftMargin, .rightMargin:
            // Down-pointing triangle (bottom of ruler)
            path.move(to: NSPoint(x: bounds.width/2, y: 0))
            path.line(to: NSPoint(x: bounds.width, y: bounds.height))
            path.line(to: NSPoint(x: 0, y: bounds.height))
            path.close()

        case .firstLineIndent:
            // Up-pointing triangle (top of ruler)
            path.move(to: NSPoint(x: bounds.width/2, y: bounds.height))
            path.line(to: NSPoint(x: bounds.width, y: 0))
            path.line(to: NSPoint(x: 0, y: 0))
            path.close()
        }

        // Ruler handles use the ruler's marking color for a cohesive look.
        // In Cream mode, avoid any orange tints.
        let theme = ThemeManager.shared.currentTheme
        let handleColor = isDragging
            ? theme.rulerMarkings.withAlphaComponent(0.85)
            : theme.rulerMarkings
        handleColor.setFill()
        path.fill()

        // Border uses the same marking color (no orange accent).
        theme.rulerMarkings.withAlphaComponent(0.6).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        dragStartLocation = event.locationInWindow

        switch type {
        case .leftMargin:
            dragStartMargin = ruler?.leftMargin ?? 0
        case .rightMargin:
            dragStartMargin = ruler?.rightMargin ?? 0
        case .firstLineIndent:
            dragStartMargin = ruler?.firstLineIndent ?? 0
        }

        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let ruler = ruler else { return }

        let currentLocation = event.locationInWindow
        let deltaX = currentLocation.x - dragStartLocation.x
        let deltaPoints = deltaX / ruler.rulerZoom

        switch type {
        case .leftMargin:
            let newMargin = max(0, min(ruler.pageWidth - ruler.rightMargin - 36, dragStartMargin + deltaPoints))
            ruler.leftMargin = newMargin
            ruler.delegate?.rulerView(ruler, didChangeLeftMargin: newMargin)

        case .rightMargin:
            let newMargin = max(0, min(ruler.pageWidth - ruler.leftMargin - 36, dragStartMargin - deltaPoints))
            ruler.rightMargin = newMargin
            ruler.delegate?.rulerView(ruler, didChangeRightMargin: newMargin)

        case .firstLineIndent:
            let maxIndent = ruler.pageWidth - ruler.leftMargin - ruler.rightMargin - 36
            let newIndent = max(-ruler.leftMargin, min(maxIndent, dragStartMargin + deltaPoints))
            ruler.firstLineIndent = newIndent
            ruler.delegate?.rulerView(ruler, didChangeFirstLineIndent: newIndent)
        }
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        needsDisplay = true
    }
}
