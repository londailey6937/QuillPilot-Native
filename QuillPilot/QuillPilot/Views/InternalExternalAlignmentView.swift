//
//  InternalExternalAlignmentView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

/// Internal vs External Alignment Charts
/// Track the gap between who they are inside and how they act.
/// Two parallel tracks: Inner truth, Outer behavior
/// As chapters progress, the gap widens (denial), stabilizes (coping), or closes (integration/collapse)

class InternalExternalAlignmentView: NSView {

    struct AlignmentDataPoint {
        let chapter: Int
        let innerTruth: Double      // 0.0 to 1.0 - inner emotional/belief state
        let outerBehavior: Double   // 0.0 to 1.0 - external presentation
        let innerLabel: String      // Description of inner state
        let outerLabel: String      // Description of outer behavior
    }

    struct CharacterAlignment {
        let characterName: String
        var dataPoints: [AlignmentDataPoint]
        var gapTrend: GapTrend
    }

    enum GapTrend: String {
        case widening = "Widening (Denial/Repression)"
        case stabilizing = "Stabilizing (Coping)"
        case closing = "Closing (Integration)"
        case collapsing = "Closing (Collapse)"
        case fluctuating = "Fluctuating"
    }

    private var alignments: [CharacterAlignment] = []
    private var selectedCharacterIndex: Int = 0

    func setAlignments(_ alignments: [CharacterAlignment]) {
        self.alignments = alignments
        needsDisplay = true
    }

    func setSelectedCharacter(_ index: Int) {
        guard index >= 0 && index < alignments.count else { return }
        selectedCharacterIndex = index
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !alignments.isEmpty else {
            drawEmptyState()
            return
        }

        let theme = ThemeManager.shared.currentTheme
        let isDarkMode = ThemeManager.shared.isDarkMode
        let backgroundColor = theme.pageAround
        let textColor = theme.textColor

        backgroundColor.setFill()
        dirtyRect.fill()

        let padding: CGFloat = 60
        let topPadding: CGFloat = 50
        let bottomPadding: CGFloat = 150
        let chartWidth = bounds.width - (padding * 2)
        let chartHeight = bounds.height - topPadding - bottomPadding
        let chartRect = NSRect(x: padding, y: bottomPadding, width: chartWidth, height: chartHeight)

        // Draw title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: textColor
        ]
        let title = "Internal vs External Alignment"
        let titleSize = title.size(withAttributes: titleAttributes)
        title.draw(at: NSPoint(x: (bounds.width - titleSize.width) / 2, y: bounds.height - 30), withAttributes: titleAttributes)

        // Draw subtitle
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]
        let subtitle = "Track the gap between inner truth and outer behavior"
        let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
        subtitle.draw(at: NSPoint(x: (bounds.width - subtitleSize.width) / 2, y: bounds.height - 48), withAttributes: subtitleAttributes)

        // Get current character data
        let currentAlignment = alignments[selectedCharacterIndex]

        // Draw character name and trend
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 14),
            .foregroundColor: textColor
        ]
        let nameStr = "\(currentAlignment.characterName) — \(currentAlignment.gapTrend.rawValue)"
        nameStr.draw(at: NSPoint(x: padding, y: bounds.height - 70), withAttributes: nameAttributes)

        // Draw chart background
        let gridColor = textColor.withAlphaComponent(0.1)
        drawChartBackground(in: chartRect, gridColor: gridColor, textColor: textColor)

        // Draw the two tracks
        drawAlignmentTracks(alignment: currentAlignment, in: chartRect, textColor: textColor, isDarkMode: isDarkMode)

        // Draw gap fill between tracks
        drawGapFill(alignment: currentAlignment, in: chartRect, isDarkMode: isDarkMode)

        // Draw legend
        drawLegend(textColor: textColor, isDarkMode: isDarkMode)

        // Draw character selector if multiple characters
        if alignments.count > 1 {
            drawCharacterSelector(textColor: textColor)
        }

        // Draw "Great for" section
        drawUseCases(textColor: textColor)
    }

    private func drawChartBackground(in rect: NSRect, gridColor: NSColor, textColor: NSColor) {
        // Draw horizontal grid lines and labels (0%, 25%, 50%, 75%, 100%)
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: textColor.withAlphaComponent(0.5)
        ]

        for i in 0...4 {
            let y = rect.minY + (rect.height * CGFloat(i) / 4)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: y))
            path.line(to: NSPoint(x: rect.maxX, y: y))
            gridColor.setStroke()
            path.lineWidth = 0.5
            path.stroke()

            // Label
            let label = "\(i * 25)%"
            label.draw(at: NSPoint(x: rect.minX - 30, y: y - 5), withAttributes: labelAttributes)
        }

        // Place axis description at bottom
        let axisDesc = "Y-Axis: Alignment level (0% = opposite of true self, 100% = fully authentic)"
        let axisDescAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: textColor.withAlphaComponent(0.5)
        ]
        axisDesc.draw(at: NSPoint(x: rect.minX, y: rect.minY - 20), withAttributes: axisDescAttr)
    }

    private func drawAlignmentTracks(alignment: CharacterAlignment, in rect: NSRect, textColor: NSColor, isDarkMode: Bool) {
        guard !alignment.dataPoints.isEmpty else { return }

        let dataPoints = alignment.dataPoints.sorted { $0.chapter < $1.chapter }
        let maxChapter = dataPoints.map { $0.chapter }.max() ?? 1
        let minChapter = dataPoints.map { $0.chapter }.min() ?? 1
        let chapterRange = max(maxChapter - minChapter, 1)

        // Inner truth track (purple)
        let innerPath = NSBezierPath()
        let innerColor = NSColor.systemPurple

        // Outer behavior track (teal/cyan)
        let outerPath = NSBezierPath()
        let outerColor = NSColor.systemTeal

        var innerPoints: [NSPoint] = []
        var outerPoints: [NSPoint] = []

        for (index, point) in dataPoints.enumerated() {
            let x = rect.minX + (CGFloat(point.chapter - minChapter) / CGFloat(chapterRange)) * rect.width
            let innerY = rect.minY + (CGFloat(point.innerTruth) * rect.height)
            let outerY = rect.minY + (CGFloat(point.outerBehavior) * rect.height)

            innerPoints.append(NSPoint(x: x, y: innerY))
            outerPoints.append(NSPoint(x: x, y: outerY))

            if index == 0 {
                innerPath.move(to: NSPoint(x: x, y: innerY))
                outerPath.move(to: NSPoint(x: x, y: outerY))
            } else {
                innerPath.line(to: NSPoint(x: x, y: innerY))
                outerPath.line(to: NSPoint(x: x, y: outerY))
            }
        }

        // Draw tracks
        innerColor.setStroke()
        innerPath.lineWidth = 3
        innerPath.stroke()

        outerColor.setStroke()
        outerPath.lineWidth = 3
        outerPath.stroke()

        // Draw data points with labels
        for (index, point) in dataPoints.enumerated() {
            let innerPt = innerPoints[index]
            let outerPt = outerPoints[index]

            // Inner point
            drawDataPoint(at: innerPt, color: innerColor, label: "Ch \(point.chapter)", detail: point.innerLabel, textColor: textColor, isDarkMode: isDarkMode, isInner: true)

            // Outer point
            drawDataPoint(at: outerPt, color: outerColor, label: nil, detail: point.outerLabel, textColor: textColor, isDarkMode: isDarkMode, isInner: false)

            // Draw gap indicator line between points
            let gapPath = NSBezierPath()
            gapPath.move(to: innerPt)
            gapPath.line(to: outerPt)
            let gapColor = isDarkMode ? NSColor.white.withAlphaComponent(0.2) : NSColor.black.withAlphaComponent(0.1)
            gapColor.setStroke()
            gapPath.lineWidth = 1
            gapPath.setLineDash([4, 4], count: 2, phase: 0)
            gapPath.stroke()
        }
    }

    private func drawDataPoint(at point: NSPoint, color: NSColor, label: String?, detail: String, textColor: NSColor, isDarkMode: Bool, isInner: Bool) {
        // Draw circle
        let radius: CGFloat = 6
        let circle = NSBezierPath(ovalIn: NSRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        color.setFill()
        circle.fill()

        // White border
        NSColor.white.setStroke()
        circle.lineWidth = 2
        circle.stroke()

        // Draw chapter label (only for inner points to avoid clutter)
        if let label = label {
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 9),
                .foregroundColor: textColor
            ]
            let labelSize = label.size(withAttributes: labelAttributes)
            let labelY = isInner ? point.y + 12 : point.y - 18

            // Background for label
            let bgColor = isDarkMode ? NSColor.black.withAlphaComponent(0.7) : NSColor.white.withAlphaComponent(0.8)
            let labelRect = NSRect(x: point.x - labelSize.width / 2 - 3, y: labelY - 2, width: labelSize.width + 6, height: labelSize.height + 4)
            bgColor.setFill()
            NSBezierPath(roundedRect: labelRect, xRadius: 3, yRadius: 3).fill()

            label.draw(at: NSPoint(x: point.x - labelSize.width / 2, y: labelY), withAttributes: labelAttributes)
        }
    }

    private func drawGapFill(alignment: CharacterAlignment, in rect: NSRect, isDarkMode: Bool) {
        guard alignment.dataPoints.count >= 2 else { return }

        let dataPoints = alignment.dataPoints.sorted { $0.chapter < $1.chapter }
        let maxChapter = dataPoints.map { $0.chapter }.max() ?? 1
        let minChapter = dataPoints.map { $0.chapter }.min() ?? 1
        let chapterRange = max(maxChapter - minChapter, 1)

        // Create filled area between the two tracks
        let fillPath = NSBezierPath()

        // Go forward along inner track
        for (index, point) in dataPoints.enumerated() {
            let x = rect.minX + (CGFloat(point.chapter - minChapter) / CGFloat(chapterRange)) * rect.width
            let innerY = rect.minY + (CGFloat(point.innerTruth) * rect.height)

            if index == 0 {
                fillPath.move(to: NSPoint(x: x, y: innerY))
            } else {
                fillPath.line(to: NSPoint(x: x, y: innerY))
            }
        }

        // Go backward along outer track
        for point in dataPoints.reversed() {
            let x = rect.minX + (CGFloat(point.chapter - minChapter) / CGFloat(chapterRange)) * rect.width
            let outerY = rect.minY + (CGFloat(point.outerBehavior) * rect.height)
            fillPath.line(to: NSPoint(x: x, y: outerY))
        }

        fillPath.close()

        // Fill with semi-transparent color based on gap trend
        let fillColor: NSColor
        switch alignment.gapTrend {
        case .widening:
            fillColor = NSColor.systemRed.withAlphaComponent(0.15)
        case .stabilizing:
            fillColor = NSColor.systemYellow.withAlphaComponent(0.15)
        case .closing:
            fillColor = NSColor.systemGreen.withAlphaComponent(0.15)
        case .collapsing:
            fillColor = NSColor.systemOrange.withAlphaComponent(0.15)
        case .fluctuating:
            fillColor = NSColor.systemGray.withAlphaComponent(0.15)
        }

        fillColor.setFill()
        fillPath.fill()
    }

    private func drawLegend(textColor: NSColor, isDarkMode: Bool) {
        let legendX: CGFloat = bounds.width - 200
        let legendY: CGFloat = bounds.height - 80

        // Track colors
        let items: [(NSColor, String)] = [
            (NSColor.systemPurple, "Inner Truth"),
            (NSColor.systemTeal, "Outer Behavior")
        ]

        var currentY = legendY
        for (color, label) in items {
            // Color swatch
            let swatchRect = NSRect(x: legendX, y: currentY, width: 20, height: 3)
            color.setFill()
            NSBezierPath(rect: swatchRect).fill()

            // Label
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: textColor
            ]
            label.draw(at: NSPoint(x: legendX + 28, y: currentY - 5), withAttributes: labelAttributes)
            currentY -= 18
        }

        // Gap trend indicator
        currentY -= 10
        let trendTitle = "Gap Trend Colors:"
        let trendTitleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 9),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]
        trendTitle.draw(at: NSPoint(x: legendX, y: currentY), withAttributes: trendTitleAttr)

        currentY -= 14
        let trendItems: [(NSColor, String)] = [
            (NSColor.systemRed, "Widening"),
            (NSColor.systemYellow, "Stabilizing"),
            (NSColor.systemGreen, "Closing"),
            (NSColor.systemOrange, "Collapse")
        ]

        for (color, label) in trendItems {
            let swatchRect = NSRect(x: legendX, y: currentY + 3, width: 10, height: 10)
            color.withAlphaComponent(0.3).setFill()
            NSBezierPath(rect: swatchRect).fill()

            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: textColor.withAlphaComponent(0.7)
            ]
            label.draw(at: NSPoint(x: legendX + 15, y: currentY), withAttributes: labelAttr)
            currentY -= 14
        }
    }

    private func drawCharacterSelector(textColor: NSColor) {
        let selectorY: CGFloat = 25
        let startX: CGFloat = 60

        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]
        "Character:".draw(at: NSPoint(x: startX, y: selectorY), withAttributes: labelAttr)

        var currentX = startX + 70
        for (index, alignment) in alignments.enumerated() {
            let isSelected = index == selectedCharacterIndex
            let buttonAttr: [NSAttributedString.Key: Any] = [
                .font: isSelected ? NSFont.boldSystemFont(ofSize: 10) : NSFont.systemFont(ofSize: 10),
                .foregroundColor: isSelected ? NSColor.systemBlue : textColor.withAlphaComponent(0.7)
            ]
            let name = alignment.characterName
            let size = name.size(withAttributes: buttonAttr)

            if isSelected {
                let bgRect = NSRect(x: currentX - 4, y: selectorY - 2, width: size.width + 8, height: size.height + 4)
                NSColor.systemBlue.withAlphaComponent(0.1).setFill()
                NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4).fill()
            }

            name.draw(at: NSPoint(x: currentX, y: selectorY), withAttributes: buttonAttr)
            currentX += size.width + 20
        }
    }

    private func drawUseCases(textColor: NSColor) {
        // Position below the legend on the right side
        let useCaseX: CGFloat = bounds.width - 200
        let useCaseY: CGFloat = bounds.height - 220

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 9),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]
        "Great for:".draw(at: NSPoint(x: useCaseX, y: useCaseY), withAttributes: titleAttr)

        let items = [
            "• Unreliable narrators",
            "• Restrained prose",
            "• Characters who \"say the right thing\"",
            "  while feeling the opposite"
        ]

        let itemAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: textColor.withAlphaComponent(0.5)
        ]

        var currentY = useCaseY - 14
        for item in items {
            item.draw(at: NSPoint(x: useCaseX, y: currentY), withAttributes: itemAttr)
            currentY -= 12
        }

        // Insight
        currentY -= 8
        let insight = "💡 The gap reveals character depth"
        let insightAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.systemPurple.withAlphaComponent(0.8)
        ]
        insight.draw(at: NSPoint(x: useCaseX, y: currentY), withAttributes: insightAttr)
    }

    private func drawEmptyState() {
        let theme = ThemeManager.shared.currentTheme
        theme.pageAround.setFill()
        bounds.fill()

        let message = "No alignment data available\nRun Character Analysis to generate alignment charts"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 4

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: theme.textColor.withAlphaComponent(0.5),
            .paragraphStyle: paragraphStyle
        ]
        let size = message.size(withAttributes: attributes)
        let rect = NSRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        message.draw(in: rect, withAttributes: attributes)
    }

    // MARK: - Mouse Handling for Character Selection

    override func mouseDown(with event: NSEvent) {
        guard alignments.count > 1 else { return }

        let location = convert(event.locationInWindow, from: nil)
        let selectorY: CGFloat = 25
        let startX: CGFloat = 130

        // Check if click is in character selector area
        guard location.y >= selectorY - 5 && location.y <= selectorY + 20 else { return }

        var currentX = startX
        for (index, alignment) in alignments.enumerated() {
            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.black
            ]
            let size = alignment.characterName.size(withAttributes: labelAttr)
            let buttonRect = NSRect(x: currentX - 4, y: selectorY - 5, width: size.width + 8, height: 20)

            if buttonRect.contains(location) {
                selectedCharacterIndex = index
                needsDisplay = true
                return
            }
            currentX += size.width + 20
        }
    }
}
