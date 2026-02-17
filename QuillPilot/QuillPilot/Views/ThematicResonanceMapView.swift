//
//  ThematicResonanceMapView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

/// Thematic Resonance Map - Track how characters interact with story theme
/// Character evolution emerges as thematic stance, not trait accumulation

class ThematicResonanceMapView: NSView {

    struct ThematicStance {
        let chapter: Int
        let alignment: Double      // -1 to 1: How aligned with theme (-1 = opposed, 0 = neutral, 1 = embodied)
        let awareness: Double      // 0 to 1: Character's conscious awareness of theme
        let influence: Double      // 0 to 1: How much character drives thematic exploration
        let cost: Double           // 0 to 1: Personal cost of engaging with theme
    }

    struct CharacterThematicJourney {
        let characterName: String
        let color: NSColor
        var stances: [ThematicStance]
        var overallTrajectory: ThematicTrajectory
    }

    enum ThematicTrajectory: String {
        case embracing = "Embracing Theme"
        case resisting = "Resisting Theme"
        case transforming = "Transformed by Theme"
        case embodying = "Embodies Theme"
        case conflicted = "Conflicted"
        case awakening = "Awakening to Theme"
    }

    enum MetricType: String, CaseIterable {
        case alignment = "Theme Alignment"
        case awareness = "Theme Awareness"
        case influence = "Thematic Influence"
        case cost = "Personal Cost"
    }

    private var journeys: [CharacterThematicJourney] = []
    private var storyTheme: String = ""
    private var selectedMetric: MetricType = .alignment

    func setThematicData(_ data: [CharacterThematicJourney], theme: String) {
        let libraryOrder = CharacterLibrary.shared.analysisCharacterKeys
        let librarySet = Set(libraryOrder)

        if !libraryOrder.isEmpty {
            self.journeys = data
                .filter { librarySet.contains($0.characterName) }
                .sorted {
                    (libraryOrder.firstIndex(of: $0.characterName) ?? Int.max) < (libraryOrder.firstIndex(of: $1.characterName) ?? Int.max)
                }
        } else {
            self.journeys = data
        }
        self.storyTheme = theme
        needsDisplay = true
    }

    func setSelectedMetric(_ metric: MetricType) {
        selectedMetric = metric
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

        guard !journeys.isEmpty else {
            drawEmptyState()
            return
        }

        let leftPadding: CGFloat = 200
        let rightPadding: CGFloat = 240
        let topPadding: CGFloat = 160
        let bottomPadding: CGFloat = 160
        let chartWidth = bounds.width - leftPadding - rightPadding
        let chartHeight = bounds.height - topPadding - bottomPadding
        let chartRect = NSRect(x: leftPadding, y: bottomPadding, width: chartWidth, height: chartHeight)

        // Draw title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: textColor
        ]
        let title = "Thematic Resonance Map"
        let titleSize = title.size(withAttributes: titleAttributes)
        title.draw(at: NSPoint(x: (bounds.width - titleSize.width) / 2, y: bounds.height - 25), withAttributes: titleAttributes)

        // Draw theme statement
        let themeAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.systemPurple.withAlphaComponent(0.8)
        ]
        let themePrefix = "Theme: "
        let themePrefixAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]

        // Truncate theme if too long
        let maxThemeLength = 120
        let displayTheme = storyTheme.count > maxThemeLength ? String(storyTheme.prefix(maxThemeLength)) + "..." : storyTheme

        let prefixSize = themePrefix.size(withAttributes: themePrefixAttr)
        let themeSize = displayTheme.size(withAttributes: themeAttributes)
        let totalWidth = prefixSize.width + themeSize.width

        themePrefix.draw(at: NSPoint(x: (bounds.width - totalWidth) / 2, y: bounds.height - 48), withAttributes: themePrefixAttr)
        displayTheme.draw(at: NSPoint(x: (bounds.width - totalWidth) / 2 + prefixSize.width, y: bounds.height - 48), withAttributes: themeAttributes)

        // Draw subtitle
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]
        let subtitle = "Character evolution as thematic stance, not trait accumulation"
        let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
        subtitle.draw(at: NSPoint(x: (bounds.width - subtitleSize.width) / 2, y: bounds.height - 65), withAttributes: subtitleAttributes)

        // Draw metric selector
        drawMetricSelector(textColor: textColor, y: bounds.height - 90)

        // Draw chart background
        drawChartBackground(in: chartRect, textColor: textColor)

        // Draw all character journeys for selected metric
        drawThematicJourneys(in: chartRect, textColor: textColor, isDarkMode: isDarkMode)

        // Draw legend
        drawLegend(textColor: textColor, chartRect: chartRect)

        // Draw interpretation guide
        drawInterpretationGuide(textColor: textColor)

        // Draw insights
        drawInsights(textColor: textColor)
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
            currentX += size.width + 25
        }
    }

    private func drawChartBackground(in rect: NSRect, textColor: NSColor) {
        let gridColor = textColor.withAlphaComponent(0.1)

        // Horizontal grid lines and labels
        let labels: [String]
        let positions: [CGFloat]

        if selectedMetric == .alignment {
            // For alignment: -100% to +100%
            labels = ["-100%", "-50%", "0%", "+50%", "+100%"]
            positions = [0, 0.25, 0.5, 0.75, 1.0]
        } else {
            // For other metrics: 0% to 100%
            labels = ["0%", "25%", "50%", "75%", "100%"]
            positions = [0, 0.25, 0.5, 0.75, 1.0]
        }

        for (index, position) in positions.enumerated() {
            let y = rect.minY + (rect.height * position)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: y))
            path.line(to: NSPoint(x: rect.maxX, y: y))
            gridColor.setStroke()
            path.lineWidth = position == 0.5 ? 1.0 : 0.5
            path.stroke()

            // Labels
            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: textColor.withAlphaComponent(0.5)
            ]
            let labelSize = labels[index].size(withAttributes: labelAttr)
            labels[index].draw(at: NSPoint(x: rect.minX - labelSize.width - 5, y: y - 5), withAttributes: labelAttr)
        }
    }

    private func drawThematicJourneys(in rect: NSRect, textColor: NSColor, isDarkMode: Bool) {
        guard !journeys.isEmpty else { return }

        // Get all chapters across all journeys
        var allChapters: Set<Int> = []
        for journey in journeys {
            for stance in journey.stances {
                allChapters.insert(stance.chapter)
            }
        }

        guard !allChapters.isEmpty else { return }

        let sortedChapters = allChapters.sorted()
        let minChapter = sortedChapters.first!
        let maxChapter = sortedChapters.last!
        let chapterRange = max(maxChapter - minChapter, 1)

        // Draw each character's journey
        for journey in journeys {
            let sortedStances = journey.stances.sorted { $0.chapter < $1.chapter }
            let path = NSBezierPath()
            var points: [NSPoint] = []

            for (index, stance) in sortedStances.enumerated() {
                let x = rect.minX + (CGFloat(stance.chapter - minChapter) / CGFloat(chapterRange)) * rect.width

                // Get value based on selected metric
                let rawValue: Double
                switch selectedMetric {
                case .alignment:
                    rawValue = stance.alignment  // -1 to 1
                case .awareness:
                    rawValue = stance.awareness  // 0 to 1
                case .influence:
                    rawValue = stance.influence  // 0 to 1
                case .cost:
                    rawValue = stance.cost       // 0 to 1
                }

                // Map to chart coordinates
                let normalizedValue: CGFloat
                if selectedMetric == .alignment {
                    // Map -1 to 1 → 0 to 1
                    normalizedValue = CGFloat((rawValue + 1.0) / 2.0)
                } else {
                    normalizedValue = CGFloat(rawValue)
                }

                let y = rect.minY + (normalizedValue * rect.height)
                let point = NSPoint(x: x, y: y)
                points.append(point)

                if index == 0 {
                    path.move(to: point)
                } else {
                    path.line(to: point)
                }
            }

            // Draw line
            journey.color.setStroke()
            path.lineWidth = 2.5
            path.stroke()

            // Draw points
            for point in points {
                drawDataPoint(at: point, color: journey.color, isDarkMode: isDarkMode)
            }
        }

        // Draw chapter/scene labels
        let xTickPrefix = StyleCatalog.shared.isScreenplayTemplate ? "Sc" : "Ch"
        for chapter in sortedChapters {
            let x = rect.minX + (CGFloat(chapter - minChapter) / CGFloat(chapterRange)) * rect.width
            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: textColor.withAlphaComponent(0.5)
            ]
            "\(xTickPrefix) \(chapter)".draw(at: NSPoint(x: x - 10, y: rect.minY - 18), withAttributes: labelAttr)
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

    private func drawLegend(textColor: NSColor, chartRect: NSRect) {
        let legendX: CGFloat = chartRect.maxX + 20
        let legendY: CGFloat = bounds.height / 2 + 60

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]
        "Characters:".draw(at: NSPoint(x: legendX, y: legendY), withAttributes: titleAttr)

        // Lay out in columns to avoid overflowing the window for large casts.
        let itemHeight: CGFloat = 28
        let headerOffset: CGFloat = 16
        let availableHeight = max(1, (legendY - headerOffset) - 20)
        let itemsPerColumn = max(1, Int(floor(availableHeight / itemHeight)))

        let maxColumns = 2
        let maxItems = itemsPerColumn * maxColumns
        let visibleJourneys = journeys.prefix(maxItems)
        let hiddenCount = max(0, journeys.count - visibleJourneys.count)

        let nameAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]
        let badgeAttrBase: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8),
            .foregroundColor: textColor.withAlphaComponent(0.55)
        ]

        let columnWidth: CGFloat = 170
        for (idx, journey) in visibleJourneys.enumerated() {
            let col = idx / itemsPerColumn
            let row = idx % itemsPerColumn

            let x = legendX + CGFloat(col) * columnWidth
            let y = (legendY - headerOffset) - CGFloat(row) * itemHeight

            // Color swatch
            let swatchRect = NSRect(x: x, y: y + 3, width: 15, height: 3)
            journey.color.setFill()
            NSBezierPath(rect: swatchRect).fill()

            // Name
            journey.characterName.draw(at: NSPoint(x: x + 20, y: y), withAttributes: nameAttr)

            // Trajectory
            var badgeAttr = badgeAttrBase
            badgeAttr[.foregroundColor] = journey.color.withAlphaComponent(0.8)
            let trajectoryText = "(\(journey.overallTrajectory.rawValue))"
            trajectoryText.draw(at: NSPoint(x: x + 20, y: y - 10), withAttributes: badgeAttr)
        }

        if hiddenCount > 0 {
            let moreText = "+\(hiddenCount) more"
            let moreAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: textColor.withAlphaComponent(0.55)
            ]
            let x = legendX
            let y: CGFloat = 20
            moreText.draw(at: NSPoint(x: x, y: y), withAttributes: moreAttr)
        }
    }

    private func drawInterpretationGuide(textColor: NSColor) {
        let guideX: CGFloat = 20
        let guideY: CGFloat = bounds.height / 2 + 60

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]
        "What This Shows:".draw(at: NSPoint(x: guideX, y: guideY), withAttributes: titleAttr)

        var items: [String] = []

        switch selectedMetric {
        case .alignment:
            items = [
                "• +100% = Embodies theme",
                "• 0% = Neutral to theme",
                "• -100% = Opposes theme",
                "• Rising = Growing alignment",
                "• Falling = Increasing resistance"
            ]
        case .awareness:
            items = [
                "• High = Consciously engages",
                "• Medium = Intuitive understanding",
                "• Low = Unconscious of theme",
                "• Rising = Awakening",
                "• Flat = Remains unaware"
            ]
        case .influence:
            items = [
                "• High = Drives exploration",
                "• Medium = Participates in theme",
                "• Low = Passive to theme",
                "• Rising = Growing agency",
                "• Falling = Losing voice"
            ]
        case .cost:
            items = [
                "• High = Heavy personal cost",
                "• Medium = Balanced sacrifice",
                "• Low = Theme serves character",
                "• Rising = Increasing stakes",
                "• Falling = Finding peace"
            ]
        }

        let itemAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]

        var currentY = guideY - 16
        for item in items {
            item.draw(at: NSPoint(x: guideX, y: currentY), withAttributes: itemAttr)
            currentY -= 14
        }
    }

    private func drawInsights(textColor: NSColor) {
        let insightX: CGFloat = 20
        let insightY: CGFloat = 100

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 12),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]
        "Key Insight:".draw(at: NSPoint(x: insightX, y: insightY), withAttributes: titleAttr)

        let insightText = "💡 Track thematic stance,\nnot character traits.\nEvolution emerges through\nrelationship with theme."
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2

        let insightAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.systemPurple.withAlphaComponent(0.8),
            .paragraphStyle: paragraphStyle
        ]
        insightText.draw(at: NSPoint(x: insightX, y: insightY - 80), withAttributes: insightAttr)
    }

    private func drawEmptyState() {
        let theme = ThemeManager.shared.currentTheme
        theme.pageAround.setFill()
        bounds.fill()

        let message = "No thematic resonance data available\nRun Character Analysis to generate thematic analysis"
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
                currentX += size.width + 25
            }
        }
    }
}
