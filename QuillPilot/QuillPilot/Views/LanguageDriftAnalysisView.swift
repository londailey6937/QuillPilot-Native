//
//  LanguageDriftAnalysisView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

/// Language Drift Analysis - Track how character's language changes
/// Tracks: pronouns, modal verbs, emotional vocabulary density, sentence length, certainty
/// Reveals growth you didn't consciously plan

class LanguageDriftAnalysisView: NSView {

    struct LanguageMetrics {
        let chapter: Int
        let pronounI: Double      // "I" usage (0-1 normalized)
        let pronounWe: Double     // "we" usage (0-1 normalized)
        let modalMust: Double     // obligation modals: must, have to, need to
        let modalChoice: Double   // choice modals: choose, can, could, want to
        let emotionalDensity: Double  // emotional words per sentence
        let avgSentenceLength: Double // average words per sentence (normalized 0-1)
        let certaintyScore: Double    // certainty indicators (0-1)
    }

    struct CharacterLanguageDrift {
        let characterName: String
        var metrics: [LanguageMetrics]
        var driftSummary: DriftSummary
    }

    struct DriftSummary {
        let pronounShift: String      // "I → We", "We → I", "Stable"
        let modalShift: String        // "Obligation → Choice", etc.
        let emotionalTrend: String    // "Increasing", "Decreasing", "Stable"
        let sentenceTrend: String     // "Longer", "Shorter", "Stable"
        let certaintyTrend: String    // "More Certain", "Less Certain", "Stable"
    }

    enum MetricType: String, CaseIterable {
        case pronouns = "Pronouns (I vs We)"
        case modals = "Modal Verbs (Must vs Choose)"
        case emotional = "Emotional Vocabulary"
        case sentence = "Sentence Length"
        case certainty = "Certainty Level"
    }

    private var driftData: [CharacterLanguageDrift] = []
    private var selectedCharacterIndex: Int = 0
    private var selectedMetric: MetricType = .pronouns
    private var characterSelectorHitRects: [NSRect] = []

    func setDriftData(_ data: [CharacterLanguageDrift]) {
        let previouslySelectedName: String? = {
            guard selectedCharacterIndex >= 0, selectedCharacterIndex < self.driftData.count else { return nil }
            return self.driftData[selectedCharacterIndex].characterName
        }()

        let libraryOrder = CharacterLibrary.shared.analysisCharacterKeys
        let librarySet = Set(libraryOrder)

        let ordered: [CharacterLanguageDrift]
        if !libraryOrder.isEmpty {
            ordered = data
                .filter { librarySet.contains($0.characterName) }
                .sorted {
                    (libraryOrder.firstIndex(of: $0.characterName) ?? Int.max) < (libraryOrder.firstIndex(of: $1.characterName) ?? Int.max)
                }
        } else {
            ordered = data
        }

        self.driftData = ordered

        if let name = previouslySelectedName, let idx = self.driftData.firstIndex(where: { $0.characterName == name }) {
            selectedCharacterIndex = idx
        } else {
            selectedCharacterIndex = 0
        }
        needsDisplay = true
    }

    func setSelectedCharacter(_ index: Int) {
        guard index >= 0 && index < driftData.count else { return }
        selectedCharacterIndex = index
        needsDisplay = true
    }

    func setSelectedMetric(_ metric: MetricType) {
        selectedMetric = metric
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !driftData.isEmpty else {
            drawEmptyState()
            return
        }

        let theme = ThemeManager.shared.currentTheme
        let isDarkMode = ThemeManager.shared.isDarkMode
        let backgroundColor = theme.pageAround
        let textColor = theme.textColor

        backgroundColor.setFill()
        dirtyRect.fill()

        let leftPadding: CGFloat = 220  // More space for left side text
        let rightPadding: CGFloat = 220  // More space for right side text
        let topPadding: CGFloat = 140
        // Extra room for wrapped character selector.
        let bottomPadding: CGFloat = 130
        let chartWidth = bounds.width - leftPadding - rightPadding
        let chartHeight = bounds.height - topPadding - bottomPadding
        let chartRect = NSRect(x: leftPadding, y: bottomPadding, width: chartWidth, height: chartHeight)

        // Draw title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: textColor
        ]
        let title = "Language Drift Analysis"
        let titleSize = title.size(withAttributes: titleAttributes)
        title.draw(at: NSPoint(x: (bounds.width - titleSize.width) / 2, y: bounds.height - 25), withAttributes: titleAttributes)

        // Draw subtitle
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]
        let subtitle = "Track how character language evolves — reveals growth you didn't consciously plan"
        let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
        subtitle.draw(at: NSPoint(x: (bounds.width - subtitleSize.width) / 2, y: bounds.height - 42), withAttributes: subtitleAttributes)

        // Get current character
        let currentDrift = driftData[selectedCharacterIndex]

        // Draw character name and drift summary
        drawCharacterHeader(drift: currentDrift, textColor: textColor, y: bounds.height - 65)

        // Draw metric selector
        drawMetricSelector(textColor: textColor, y: bounds.height - 90)

        // Draw chart background
        drawChartBackground(in: chartRect, textColor: textColor)

        // Draw the selected metric
        drawMetricChart(drift: currentDrift, in: chartRect, textColor: textColor, isDarkMode: isDarkMode)

        // Draw legend
        drawLegend(textColor: textColor, isDarkMode: isDarkMode)

        // Draw character selector
        if driftData.count > 1 {
            drawCharacterSelector(textColor: textColor)
        }

        // Draw use cases
        drawUseCases(textColor: textColor)
    }

    private func drawCharacterHeader(drift: CharacterLanguageDrift, textColor: NSColor, y: CGFloat) {
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 14),
            .foregroundColor: textColor
        ]
        drift.characterName.draw(at: NSPoint(x: 220, y: y), withAttributes: nameAttributes)

        // Draw drift summary badges
        let badgeY = y - 2
        var badgeX: CGFloat = 220 + drift.characterName.size(withAttributes: nameAttributes).width + 15

        let badges = [
            (drift.driftSummary.pronounShift, NSColor.systemPurple),
            (drift.driftSummary.modalShift, NSColor.systemTeal),
            (drift.driftSummary.certaintyTrend, NSColor.systemOrange)
        ]

        for (text, color) in badges where !text.isEmpty && text != "Stable" {
            drawBadge(text: text, at: NSPoint(x: badgeX, y: badgeY), color: color)
            badgeX += text.size(withAttributes: [.font: NSFont.systemFont(ofSize: 9)]).width + 20
        }
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

    private func drawMetricSelector(textColor: NSColor, y: CGFloat) {
        var currentX: CGFloat = 220

        for metric in MetricType.allCases {
            let isSelected = metric == selectedMetric
            let attributes: [NSAttributedString.Key: Any] = [
                .font: isSelected ? NSFont.boldSystemFont(ofSize: 10) : NSFont.systemFont(ofSize: 10),
                .foregroundColor: isSelected ? NSColor.systemBlue : textColor.withAlphaComponent(0.6)
            ]
            let size = metric.rawValue.size(withAttributes: attributes)

            if isSelected {
                let bgRect = NSRect(x: currentX - 4, y: y - 2, width: size.width + 8, height: size.height + 4)
                NSColor.systemBlue.withAlphaComponent(0.1).setFill()
                NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4).fill()
            }

            metric.rawValue.draw(at: NSPoint(x: currentX, y: y), withAttributes: attributes)
            currentX += size.width + 20
        }
    }

    private func drawChartBackground(in rect: NSRect, textColor: NSColor) {
        let gridColor = textColor.withAlphaComponent(0.1)

        // Horizontal grid lines
        for i in 0...4 {
            let y = rect.minY + (rect.height * CGFloat(i) / 4)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: y))
            path.line(to: NSPoint(x: rect.maxX, y: y))
            gridColor.setStroke()
            path.lineWidth = 0.5
            path.stroke()

            // Labels
            let label = "\(i * 25)%"
            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: textColor.withAlphaComponent(0.5)
            ]
            label.draw(at: NSPoint(x: rect.minX - 30, y: y - 5), withAttributes: labelAttr)
        }
    }

    private func drawMetricChart(drift: CharacterLanguageDrift, in rect: NSRect, textColor: NSColor, isDarkMode: Bool) {
        guard !drift.metrics.isEmpty else { return }

        let metrics = drift.metrics.sorted { $0.chapter < $1.chapter }
        let maxChapter = metrics.map { $0.chapter }.max() ?? 1
        let minChapter = metrics.map { $0.chapter }.min() ?? 1
        let chapterRange = max(maxChapter - minChapter, 1)

        switch selectedMetric {
        case .pronouns:
            drawDualLineChart(
                metrics: metrics,
                value1: { $0.pronounI },
                value2: { $0.pronounWe },
                color1: NSColor.systemPurple,
                color2: NSColor.systemTeal,
                label1: "\"I\"",
                label2: "\"We\"",
                in: rect,
                chapterRange: chapterRange,
                minChapter: minChapter,
                textColor: textColor,
                isDarkMode: isDarkMode
            )

        case .modals:
            drawDualLineChart(
                metrics: metrics,
                value1: { $0.modalMust },
                value2: { $0.modalChoice },
                color1: NSColor.systemRed,
                color2: NSColor.systemGreen,
                label1: "Must/Need",
                label2: "Choose/Can",
                in: rect,
                chapterRange: chapterRange,
                minChapter: minChapter,
                textColor: textColor,
                isDarkMode: isDarkMode
            )

        case .emotional:
            drawSingleLineChart(
                metrics: metrics,
                value: { $0.emotionalDensity },
                color: NSColor.systemPink,
                label: "Emotional Density",
                in: rect,
                chapterRange: chapterRange,
                minChapter: minChapter,
                textColor: textColor,
                isDarkMode: isDarkMode
            )

        case .sentence:
            drawSingleLineChart(
                metrics: metrics,
                value: { $0.avgSentenceLength },
                color: NSColor.systemIndigo,
                label: "Avg Sentence Length",
                in: rect,
                chapterRange: chapterRange,
                minChapter: minChapter,
                textColor: textColor,
                isDarkMode: isDarkMode
            )

        case .certainty:
            drawSingleLineChart(
                metrics: metrics,
                value: { $0.certaintyScore },
                color: NSColor.systemOrange,
                label: "Certainty",
                in: rect,
                chapterRange: chapterRange,
                minChapter: minChapter,
                textColor: textColor,
                isDarkMode: isDarkMode
            )
        }

        // Draw chapter labels
        for metric in metrics {
            let x = rect.minX + (CGFloat(metric.chapter - minChapter) / CGFloat(chapterRange)) * rect.width
            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: textColor.withAlphaComponent(0.5)
            ]
            "Ch \(metric.chapter)".draw(at: NSPoint(x: x - 10, y: rect.minY - 18), withAttributes: labelAttr)
        }
    }

    private func drawDualLineChart(
        metrics: [LanguageMetrics],
        value1: (LanguageMetrics) -> Double,
        value2: (LanguageMetrics) -> Double,
        color1: NSColor,
        color2: NSColor,
        label1: String,
        label2: String,
        in rect: NSRect,
        chapterRange: Int,
        minChapter: Int,
        textColor: NSColor,
        isDarkMode: Bool
    ) {
        let path1 = NSBezierPath()
        let path2 = NSBezierPath()
        var points1: [NSPoint] = []
        var points2: [NSPoint] = []

        for (index, metric) in metrics.enumerated() {
            let x = rect.minX + (CGFloat(metric.chapter - minChapter) / CGFloat(chapterRange)) * rect.width
            let y1 = rect.minY + (CGFloat(value1(metric)) * rect.height)
            let y2 = rect.minY + (CGFloat(value2(metric)) * rect.height)

            points1.append(NSPoint(x: x, y: y1))
            points2.append(NSPoint(x: x, y: y2))

            if index == 0 {
                path1.move(to: NSPoint(x: x, y: y1))
                path2.move(to: NSPoint(x: x, y: y2))
            } else {
                path1.line(to: NSPoint(x: x, y: y1))
                path2.line(to: NSPoint(x: x, y: y2))
            }
        }

        // Draw lines
        color1.setStroke()
        path1.lineWidth = 2.5
        path1.stroke()

        color2.setStroke()
        path2.lineWidth = 2.5
        path2.stroke()

        // Draw points
        for point in points1 {
            drawDataPoint(at: point, color: color1, isDarkMode: isDarkMode)
        }
        for point in points2 {
            drawDataPoint(at: point, color: color2, isDarkMode: isDarkMode)
        }
    }

    private func drawSingleLineChart(
        metrics: [LanguageMetrics],
        value: (LanguageMetrics) -> Double,
        color: NSColor,
        label: String,
        in rect: NSRect,
        chapterRange: Int,
        minChapter: Int,
        textColor: NSColor,
        isDarkMode: Bool
    ) {
        let path = NSBezierPath()
        var points: [NSPoint] = []

        for (index, metric) in metrics.enumerated() {
            let x = rect.minX + (CGFloat(metric.chapter - minChapter) / CGFloat(chapterRange)) * rect.width
            let y = rect.minY + (CGFloat(value(metric)) * rect.height)

            points.append(NSPoint(x: x, y: y))

            if index == 0 {
                path.move(to: NSPoint(x: x, y: y))
            } else {
                path.line(to: NSPoint(x: x, y: y))
            }
        }

        // Draw filled area
        let fillPath = NSBezierPath()
        fillPath.move(to: NSPoint(x: points.first!.x, y: rect.minY))
        for point in points {
            fillPath.line(to: point)
        }
        fillPath.line(to: NSPoint(x: points.last!.x, y: rect.minY))
        fillPath.close()

        color.withAlphaComponent(0.1).setFill()
        fillPath.fill()

        // Draw line
        color.setStroke()
        path.lineWidth = 2.5
        path.stroke()

        // Draw points
        for point in points {
            drawDataPoint(at: point, color: color, isDarkMode: isDarkMode)
        }
    }

    private func drawDataPoint(at point: NSPoint, color: NSColor, isDarkMode: Bool) {
        let radius: CGFloat = 5
        let circle = NSBezierPath(ovalIn: NSRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        color.setFill()
        circle.fill()
        NSColor.white.setStroke()
        circle.lineWidth = 1.5
        circle.stroke()
    }

    private func drawInlineLegendItem(label: String, color: NSColor, at point: NSPoint, textColor: NSColor) {
        let swatchRect = NSRect(x: point.x, y: point.y + 3, width: 15, height: 3)
        color.setFill()
        NSBezierPath(rect: swatchRect).fill()

        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]
        label.draw(at: NSPoint(x: point.x + 20, y: point.y), withAttributes: labelAttr)
    }

    private func drawLegend(textColor: NSColor, isDarkMode: Bool) {
        let legendX: CGFloat = bounds.width - 200
        let legendY: CGFloat = bounds.height / 2 + 60

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]
        "What to Look For:".draw(at: NSPoint(x: legendX, y: legendY), withAttributes: titleAttr)

        let items = [
            "• I→We = Community growth",
            "• Must→Choose = Agency",
            "• ↑ Emotional = Opening up",
            "• ↑ Certainty = Confidence"
        ]

        let itemAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]

        var currentY = legendY - 16
        for item in items {
            item.draw(at: NSPoint(x: legendX, y: currentY), withAttributes: itemAttr)
            currentY -= 14
        }
    }

    private func drawCharacterSelector(textColor: NSColor) {
        characterSelectorHitRects.removeAll(keepingCapacity: true)

        let baseY: CGFloat = 25
        let startX: CGFloat = 220
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
        for (index, drift) in driftData.enumerated() {
            let isSelected = index == selectedCharacterIndex
            let buttonAttr: [NSAttributedString.Key: Any] = [
                .font: isSelected ? NSFont.boldSystemFont(ofSize: 10) : NSFont.systemFont(ofSize: 10),
                .foregroundColor: isSelected ? NSColor.systemBlue : textColor.withAlphaComponent(0.7)
            ]
            let name = drift.characterName
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

    private func drawUseCases(textColor: NSColor) {
        let useCaseX: CGFloat = 20
        let useCaseY: CGFloat = bounds.height / 2 + 60

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]
        "Reveals:".draw(at: NSPoint(x: useCaseX, y: useCaseY), withAttributes: titleAttr)

        let items = [
            "• Unconscious character growth",
            "• Psychological shifts",
            "• Voice consistency issues",
            "• Emotional arc authenticity"
        ]

        let itemAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]

        var currentY = useCaseY - 16
        for item in items {
            item.draw(at: NSPoint(x: useCaseX, y: currentY), withAttributes: itemAttr)
            currentY -= 14
        }

        currentY -= 10
        let insight = "💡 Language reveals what\ncharacters won't say directly"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        let insightAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.systemPurple.withAlphaComponent(0.8),
            .paragraphStyle: paragraphStyle
        ]
        insight.draw(at: NSPoint(x: useCaseX, y: currentY), withAttributes: insightAttr)
    }

    private func drawEmptyState() {
        let theme = ThemeManager.shared.currentTheme
        theme.pageAround.setFill()
        bounds.fill()

        let message = "No language drift data available\nRun Character Analysis to generate language drift analysis"
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

        // Check metric selector clicks
        let metricY = bounds.height - 88
        if location.y >= metricY - 5 && location.y <= metricY + 20 {
            var currentX: CGFloat = 220
            for metric in MetricType.allCases {
                let size = metric.rawValue.size(withAttributes: [.font: NSFont.systemFont(ofSize: 10)])
                let buttonRect = NSRect(x: currentX - 4, y: metricY - 5, width: size.width + 8, height: 20)
                if buttonRect.contains(location) {
                    selectedMetric = metric
                    needsDisplay = true
                    return
                }
                currentX += size.width + 20
            }
        }

        // Check character selector clicks
        guard driftData.count > 1 else { return }

        for (index, rect) in characterSelectorHitRects.enumerated() {
            if rect.contains(location) {
                selectedCharacterIndex = index
                needsDisplay = true
                return
            }
        }
    }
}
