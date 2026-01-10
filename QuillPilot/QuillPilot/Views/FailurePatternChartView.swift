//
//  FailurePatternChartView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

/// Failure Pattern Chart - Track how characters fail differently over time
/// Progress isn't success—it's better failure

class FailurePatternChartView: NSView {

    enum FailureType: String, CaseIterable {
        case naive = "Naive"
        case reactive = "Reactive"
        case misinformed = "Misinformed"
        case strategic = "Strategic"
        case principled = "Principled"
        case costlyChosen = "Costly but Chosen"

        var isEarlyFailure: Bool {
            return [.naive, .reactive, .misinformed].contains(self)
        }

        var color: NSColor {
            switch self {
            case .naive: return NSColor.systemRed.withAlphaComponent(0.7)
            case .reactive: return NSColor.systemOrange.withAlphaComponent(0.7)
            case .misinformed: return NSColor.systemYellow.withAlphaComponent(0.7)
            case .strategic: return NSColor.systemBlue.withAlphaComponent(0.7)
            case .principled: return NSColor.systemPurple.withAlphaComponent(0.7)
            case .costlyChosen: return NSColor.systemGreen.withAlphaComponent(0.7)
            }
        }
    }

    struct Failure {
        let chapter: Int
        let type: FailureType
        let description: String
        let consequence: String
        let growthScore: Double  // 0-1: How much growth this failure represents
    }

    struct CharacterFailurePattern {
        let characterName: String
        let color: NSColor
        var failures: [Failure]
        var progression: FailureProgression
    }

    enum FailureProgression: String {
        case stagnant = "Stagnant (No Growth)"
        case emerging = "Emerging Awareness"
        case transforming = "Transforming"
        case evolved = "Evolved (Better Failures)"
    }

    private var patterns: [CharacterFailurePattern] = []
    private var selectedCharacterIndex: Int = 0
    private var characterSelectorHitRects: [NSRect] = []

    func setFailureData(_ data: [CharacterFailurePattern]) {
        let previouslySelectedName: String? = {
            guard selectedCharacterIndex >= 0, selectedCharacterIndex < self.patterns.count else { return nil }
            return self.patterns[selectedCharacterIndex].characterName
        }()

        let libraryOrder = CharacterLibrary.shared.analysisCharacterKeys
        let librarySet = Set(libraryOrder)

        let ordered: [CharacterFailurePattern]
        if !libraryOrder.isEmpty {
            ordered = data
                .filter { librarySet.contains($0.characterName) }
                .sorted {
                    (libraryOrder.firstIndex(of: $0.characterName) ?? Int.max) < (libraryOrder.firstIndex(of: $1.characterName) ?? Int.max)
                }
        } else {
            ordered = data
        }

        self.patterns = ordered

        if let name = previouslySelectedName, let idx = self.patterns.firstIndex(where: { $0.characterName == name }) {
            selectedCharacterIndex = idx
        } else {
            selectedCharacterIndex = 0
        }
        needsDisplay = true
    }

    func setSelectedCharacter(_ index: Int) {
        guard index >= 0 && index < patterns.count else { return }
        selectedCharacterIndex = index
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let theme = ThemeManager.shared.currentTheme
        let isDarkMode = ThemeManager.shared.isDarkMode
        let backgroundColor = theme.pageAround
        let textColor = theme.textColor

        backgroundColor.setFill()
        dirtyRect.fill()

        guard !patterns.isEmpty else {
            drawEmptyState()
            return
        }

        let leftPadding: CGFloat = 200
        let rightPadding: CGFloat = 200
        let topPadding: CGFloat = 140
        // Extra room for wrapped character selector.
        let bottomPadding: CGFloat = 150
        let chartWidth = bounds.width - leftPadding - rightPadding
        let chartHeight = bounds.height - topPadding - bottomPadding
        let chartRect = NSRect(x: leftPadding, y: bottomPadding, width: chartWidth, height: chartHeight)

        // Draw title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: textColor
        ]
        let title = "Failure Pattern Charts"
        let titleSize = title.size(withAttributes: titleAttributes)
        title.draw(at: NSPoint(x: (bounds.width - titleSize.width) / 2, y: bounds.height - 25), withAttributes: titleAttributes)

        // Draw subtitle
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.systemPurple.withAlphaComponent(0.8)
        ]
        let subtitle = "Progress isn't success—it's better failure"
        let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
        subtitle.draw(at: NSPoint(x: (bounds.width - subtitleSize.width) / 2, y: bounds.height - 45), withAttributes: subtitleAttributes)

        // Get current character
        let currentPattern = patterns[selectedCharacterIndex]

        // Draw character name and progression badge
        drawCharacterHeader(pattern: currentPattern, textColor: textColor, y: bounds.height - 70)

        // Draw chart background
        drawChartBackground(in: chartRect, textColor: textColor)

        // Draw failure timeline
        drawFailureTimeline(pattern: currentPattern, in: chartRect, textColor: textColor, isDarkMode: isDarkMode)

        // Draw legend
        drawLegend(textColor: textColor)

        // Draw character selector
        if patterns.count > 1 {
            drawCharacterSelector(textColor: textColor)
        }

        // Draw failure evolution guide
        drawFailureGuide(textColor: textColor)

        // Draw insights
        drawInsights(textColor: textColor)
    }

    private func drawCharacterHeader(pattern: CharacterFailurePattern, textColor: NSColor, y: CGFloat) {
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 14),
            .foregroundColor: textColor
        ]
        pattern.characterName.draw(at: NSPoint(x: 200, y: y), withAttributes: nameAttributes)

        // Draw progression badge
        let badgeX = 200 + pattern.characterName.size(withAttributes: nameAttributes).width + 15
        let badgeColor: NSColor
        switch pattern.progression {
        case .stagnant: badgeColor = .systemRed
        case .emerging: badgeColor = .systemOrange
        case .transforming: badgeColor = .systemBlue
        case .evolved: badgeColor = .systemGreen
        }
        drawBadge(text: pattern.progression.rawValue, at: NSPoint(x: badgeX, y: y - 2), color: badgeColor)
    }

    private func drawBadge(text: String, at point: NSPoint, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: color
        ]
        let size = text.size(withAttributes: attributes)
        let rect = NSRect(x: point.x - 4, y: point.y - 2, width: size.width + 8, height: size.height + 4)

        color.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()

        text.draw(at: point, withAttributes: attributes)
    }

    private func drawChartBackground(in rect: NSRect, textColor: NSColor) {
        // Horizontal line at center
        let centerY = rect.minY + (rect.height / 2)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: centerY))
        path.line(to: NSPoint(x: rect.maxX, y: centerY))
        textColor.withAlphaComponent(0.3).setStroke()
        path.lineWidth = 1.0
        path.stroke()

        // Label zones
        let zoneAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: textColor.withAlphaComponent(0.5)
        ]

        "Better Failures".draw(at: NSPoint(x: rect.minX - 100, y: rect.maxY - 20), withAttributes: zoneAttr)
        "Worse Failures".draw(at: NSPoint(x: rect.minX - 100, y: rect.minY + 5), withAttributes: zoneAttr)
    }

    private func drawFailureTimeline(pattern: CharacterFailurePattern, in rect: NSRect, textColor: NSColor, isDarkMode: Bool) {
        guard !pattern.failures.isEmpty else { return }

        let sortedFailures = pattern.failures.sorted { $0.chapter < $1.chapter }
        let minChapter = sortedFailures.first!.chapter
        let maxChapter = sortedFailures.last!.chapter
        let chapterRange = max(maxChapter - minChapter, 1)

        // Draw connecting line showing progression
        let linePath = NSBezierPath()
        var linePoints: [NSPoint] = []

        for failure in sortedFailures {
            let x = rect.minX + (CGFloat(failure.chapter - minChapter) / CGFloat(chapterRange)) * rect.width
            let y = rect.minY + (CGFloat(failure.growthScore) * rect.height)
            linePoints.append(NSPoint(x: x, y: y))
        }

        if linePoints.count > 1 {
            linePath.move(to: linePoints[0])
            for point in linePoints.dropFirst() {
                linePath.line(to: point)
            }
            pattern.color.withAlphaComponent(0.3).setStroke()
            linePath.lineWidth = 2.0
            linePath.stroke()
        }

        // Draw failure nodes
        for (_, failure) in sortedFailures.enumerated() {
            let x = rect.minX + (CGFloat(failure.chapter - minChapter) / CGFloat(chapterRange)) * rect.width
            let y = rect.minY + (CGFloat(failure.growthScore) * rect.height)

            drawFailureNode(
                at: NSPoint(x: x, y: y),
                failure: failure,
                textColor: textColor,
                isDarkMode: isDarkMode
            )

            // Draw scene label below
            let chapterLabel = "Sc \(failure.chapter)"
            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: textColor.withAlphaComponent(0.5)
            ]
            let labelSize = chapterLabel.size(withAttributes: labelAttr)
            chapterLabel.draw(at: NSPoint(x: x - labelSize.width / 2, y: rect.minY - 18), withAttributes: labelAttr)
        }
    }

    private func drawFailureNode(at point: NSPoint, failure: Failure, textColor: NSColor, isDarkMode: Bool) {
        let nodeSize: CGFloat = 24
        let nodeRect = NSRect(
            x: point.x - nodeSize / 2,
            y: point.y - nodeSize / 2,
            width: nodeSize,
            height: nodeSize
        )

        // Draw colored background
        failure.type.color.setFill()
        NSBezierPath(ovalIn: nodeRect).fill()

        // Draw white border
        NSColor.white.withAlphaComponent(0.9).setStroke()
        let borderPath = NSBezierPath(ovalIn: nodeRect)
        borderPath.lineWidth = 2.0
        borderPath.stroke()

        // Draw type initial
        let initial = String(failure.type.rawValue.prefix(1))
        let initialAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 11),
            .foregroundColor: NSColor.white
        ]
        let initialSize = initial.size(withAttributes: initialAttr)
        initial.draw(at: NSPoint(
            x: point.x - initialSize.width / 2,
            y: point.y - initialSize.height / 2
        ), withAttributes: initialAttr)
    }

    private func drawLegend(textColor: NSColor) {
        let legendX: CGFloat = bounds.width - 180
        let legendY: CGFloat = bounds.height / 2 + 80

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]
        "Failure Types:".draw(at: NSPoint(x: legendX, y: legendY), withAttributes: titleAttr)

        var currentY = legendY - 16

        // Early failures
        let earlyTitle = "Early Failures:"
        let earlyAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]
        earlyTitle.draw(at: NSPoint(x: legendX, y: currentY), withAttributes: earlyAttr)
        currentY -= 14

        let earlyTypes: [FailureType] = [.naive, .reactive, .misinformed]
        for type in earlyTypes {
            drawLegendItem(type: type, at: NSPoint(x: legendX, y: currentY), textColor: textColor)
            currentY -= 14
        }

        currentY -= 8

        // Later failures
        let laterTitle = "Better Failures:"
        laterTitle.draw(at: NSPoint(x: legendX, y: currentY), withAttributes: earlyAttr)
        currentY -= 14

        let laterTypes: [FailureType] = [.strategic, .principled, .costlyChosen]
        for type in laterTypes {
            drawLegendItem(type: type, at: NSPoint(x: legendX, y: currentY), textColor: textColor)
            currentY -= 14
        }
    }

    private func drawLegendItem(type: FailureType, at point: NSPoint, textColor: NSColor) {
        // Draw color swatch
        let swatchSize: CGFloat = 10
        let swatchRect = NSRect(x: point.x, y: point.y + 2, width: swatchSize, height: swatchSize)
        type.color.setFill()
        NSBezierPath(ovalIn: swatchRect).fill()

        // Draw label
        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]
        type.rawValue.draw(at: NSPoint(x: point.x + swatchSize + 6, y: point.y), withAttributes: labelAttr)
    }

    private func drawCharacterSelector(textColor: NSColor) {
        characterSelectorHitRects.removeAll(keepingCapacity: true)

        let baseY: CGFloat = 25
        let startX: CGFloat = 200
        let maxX: CGFloat = bounds.width - 40
        let rowHeight: CGFloat = 18
        let rowSpacing: CGFloat = 6

        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]
        "Character:".draw(at: NSPoint(x: startX, y: baseY), withAttributes: labelAttr)

        var currentX = startX + 70
        var currentY = baseY
        for (index, pattern) in patterns.enumerated() {
            let isSelected = index == selectedCharacterIndex
            let buttonAttr: [NSAttributedString.Key: Any] = [
                .font: isSelected ? NSFont.boldSystemFont(ofSize: 10) : NSFont.systemFont(ofSize: 10),
                .foregroundColor: isSelected ? NSColor.systemBlue : textColor.withAlphaComponent(0.7)
            ]
            let name = pattern.characterName
            let size = name.size(withAttributes: buttonAttr)

            // Wrap to the next row if this label would overflow.
            if currentX + size.width + 8 > maxX {
                currentX = startX + 70
                currentY += rowHeight + rowSpacing
            }

            if isSelected {
                let bgRect = NSRect(x: currentX - 4, y: currentY - 2, width: size.width + 8, height: size.height + 4)
                NSColor.systemBlue.withAlphaComponent(0.1).setFill()
                NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4).fill()
            }

            name.draw(at: NSPoint(x: currentX, y: currentY), withAttributes: buttonAttr)

            let hitRect = NSRect(x: currentX - 4, y: currentY - 5, width: size.width + 8, height: 20)
            characterSelectorHitRects.append(hitRect)
            currentX += size.width + 25
        }
    }

    private func drawFailureGuide(textColor: NSColor) {
        let guideX: CGFloat = 20
        let guideY: CGFloat = bounds.height / 2 + 80

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]
        "Evolution of Failure:".draw(at: NSPoint(x: guideX, y: guideY), withAttributes: titleAttr)

        let items = [
            "Early → Naive, impulsive",
            "Early → Reactive, no plan",
            "Early → Misinformed, blind",
            "",
            "Later → Strategic calculation",
            "Later → Principled sacrifice",
            "Later → Costly but chosen"
        ]

        let itemAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]

        var currentY = guideY - 16
        for item in items {
            if item.isEmpty {
                currentY -= 8
            } else {
                item.draw(at: NSPoint(x: guideX, y: currentY), withAttributes: itemAttr)
                currentY -= 14
            }
        }
    }

    private func drawInsights(textColor: NSColor) {
        let insightX: CGFloat = 20
        let insightY: CGFloat = 70

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]
        "Key Insight:".draw(at: NSPoint(x: insightX, y: insightY), withAttributes: titleAttr)

        let insightText = "💡 Growth is measured\nby better failures,\nnot by success.\nWatch the upward trend."
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2

        let insightAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.systemPurple.withAlphaComponent(0.8),
            .paragraphStyle: paragraphStyle
        ]
        // Raise the block slightly to leave bottom padding
        insightText.draw(at: NSPoint(x: insightX, y: insightY - 50), withAttributes: insightAttr)
    }

    private func drawEmptyState() {
        let theme = ThemeManager.shared.currentTheme
        theme.pageAround.setFill()
        bounds.fill()

        let message = "No failure pattern data available\nRun Character Analysis to generate failure patterns"
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

    // MARK: - Mouse Handling

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        // Check character selector clicks
        guard patterns.count > 1 else { return }

        for (index, rect) in characterSelectorHitRects.enumerated() {
            if rect.contains(location) {
                selectedCharacterIndex = index
                needsDisplay = true
                return
            }
        }
    }
}
