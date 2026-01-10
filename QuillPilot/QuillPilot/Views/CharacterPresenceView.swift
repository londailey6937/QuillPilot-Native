//
//  CharacterPresenceView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

/// AppKit view for Character Presence bar chart visualization
/// Uses draw() method for proper theme support
class CharacterPresenceView: NSView {

    private var presence: [CharacterPresence] = []

    private let legendWidth: CGFloat = 180
    private let legendScrollView = NSScrollView()
    private let legendStack = NSStackView()
    private var legendCharacters: [String] = []
    private var legendColors: [NSColor] = []
    private var themeObserver: NSObjectProtocol?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLegendViews()
        startObservingTheme()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLegendViews()
        startObservingTheme()
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }

    private func setupLegendViews() {
        legendStack.orientation = .vertical
        legendStack.alignment = .leading
        legendStack.spacing = 8
        legendStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        legendScrollView.documentView = legendStack
        legendScrollView.hasVerticalScroller = true
        legendScrollView.autohidesScrollers = true
        legendScrollView.drawsBackground = false
        legendScrollView.borderType = .noBorder

        addSubview(legendScrollView)
    }

    private func startObservingTheme() {
        themeObserver = NotificationCenter.default.addObserver(
            forName: .themeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyThemeToLegend()
            self?.needsDisplay = true
        }
    }

    override func layout() {
        super.layout()

        let topPadding: CGFloat = 70
        let bottomPadding: CGFloat = 100

        let chartHeight = bounds.height - topPadding - bottomPadding
        let legendX = bounds.width - legendWidth - 10
        legendScrollView.frame = NSRect(x: legendX, y: bottomPadding, width: legendWidth, height: chartHeight)

        // Size stack for scroll.
        legendStack.frame = NSRect(x: 0, y: 0, width: legendWidth, height: legendStack.fittingSize.height)
    }

    func setPresence(_ presence: [CharacterPresence]) {
        self.presence = presence
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let theme = ThemeManager.shared.currentTheme
        let backgroundColor = theme.pageAround
        let textColor = theme.textColor

        backgroundColor.setFill()
        dirtyRect.fill()

        guard !presence.isEmpty else {
            drawEmptyState(textColor: textColor)
            return
        }

        // Collect data
        var dataPoints: [(character: String, chapter: Int, mentions: Int)] = []
        for entry in presence {
            for (chapter, mentions) in entry.chapterPresence {
                dataPoints.append((entry.characterName, chapter, mentions))
            }
        }

        guard !dataPoints.isEmpty else {
            drawEmptyState(textColor: textColor)
            return
        }

        let chapters = Array(Set(dataPoints.map { $0.chapter })).sorted()
        let characters = Array(Set(dataPoints.map { $0.character })).sorted()

        // Layout constants
        let padding: CGFloat = 60
        let topPadding: CGFloat = 70
        let bottomPadding: CGFloat = 100

        let chartWidth = bounds.width - padding - legendWidth - 20
        let chartHeight = bounds.height - topPadding - bottomPadding
        let chartRect = NSRect(x: padding, y: bottomPadding, width: chartWidth, height: chartHeight)

        // Draw title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: textColor
        ]
        let title = "Character Presence by Chapter"
        let titleSize = title.size(withAttributes: titleAttributes)
        title.draw(at: NSPoint(x: (bounds.width - titleSize.width) / 2, y: bounds.height - 40), withAttributes: titleAttributes)

        // Draw subtitle
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]
        let subtitle = "Number of mentions per character per chapter"
        let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
        subtitle.draw(at: NSPoint(x: (bounds.width - subtitleSize.width) / 2, y: bounds.height - 58), withAttributes: subtitleAttributes)

        // Find max mentions for scale
        let maxMentions = dataPoints.map { $0.mentions }.max() ?? 1

        // Draw Y axis
        drawYAxis(in: chartRect, maxValue: maxMentions, textColor: textColor)

        // Draw bars
        let barGroupWidth = chartWidth / CGFloat(chapters.count)
        let barWidth = min(25, (barGroupWidth - 10) / CGFloat(characters.count))
        let colors = generateColors(count: characters.count)

        if legendCharacters != characters || legendColors.count != colors.count {
            rebuildLegend(characters: characters, colors: colors)
        }

        for (chapterIndex, chapter) in chapters.enumerated() {
            let groupX = chartRect.minX + (CGFloat(chapterIndex) * barGroupWidth) + (barGroupWidth - CGFloat(characters.count) * barWidth) / 2

            for (charIndex, character) in characters.enumerated() {
                if let dataPoint = dataPoints.first(where: { $0.character == character && $0.chapter == chapter }) {
                    let barHeight = (CGFloat(dataPoint.mentions) / CGFloat(maxMentions)) * chartRect.height
                    let barX = groupX + CGFloat(charIndex) * barWidth

                    let barRect = NSRect(
                        x: barX,
                        y: chartRect.minY,
                        width: barWidth - 2,
                        height: barHeight
                    )

                    colors[charIndex].setFill()
                    NSBezierPath(roundedRect: barRect, xRadius: 2, yRadius: 2).fill()

                    // Draw value label on top of bar
                    if dataPoint.mentions > 0 {
                        let valueStr = "\(dataPoint.mentions)"
                        let valueAttrs: [NSAttributedString.Key: Any] = [
                            .font: NSFont.systemFont(ofSize: 8),
                            .foregroundColor: textColor.withAlphaComponent(0.7)
                        ]
                        let valueSize = valueStr.size(withAttributes: valueAttrs)
                        valueStr.draw(at: NSPoint(x: barX + (barWidth - 2 - valueSize.width) / 2, y: chartRect.minY + barHeight + 3), withAttributes: valueAttrs)
                    }
                }
            }

            // Draw chapter label
            let chapterLabel = "Ch \(chapter)"
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: textColor
            ]
            let labelSize = chapterLabel.size(withAttributes: labelAttrs)
            let labelX = chartRect.minX + (CGFloat(chapterIndex) * barGroupWidth) + (barGroupWidth - labelSize.width) / 2
            chapterLabel.draw(at: NSPoint(x: labelX, y: chartRect.minY - 20), withAttributes: labelAttrs)
        }

        // Draw axis labels
        let xAxisLabel = "Chapter"
        let xAxisAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: textColor
        ]
        let xAxisSize = xAxisLabel.size(withAttributes: xAxisAttrs)
        xAxisLabel.draw(at: NSPoint(x: chartRect.midX - xAxisSize.width / 2, y: chartRect.minY - 45), withAttributes: xAxisAttrs)

        let yAxisLabel = "Mentions"
        let yAxisAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: textColor
        ]
        // Draw rotated Y axis label
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        let yAxisSize = yAxisLabel.size(withAttributes: yAxisAttrs)
        context?.translateBy(x: padding - 45, y: chartRect.midY + yAxisSize.width / 2)
        context?.rotate(by: -.pi / 2)
        yAxisLabel.draw(at: .zero, withAttributes: yAxisAttrs)
        context?.restoreGState()
    }

    private func drawEmptyState(textColor: NSColor) {
        let message = "No character presence data"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: textColor.withAlphaComponent(0.5)
        ]
        let size = message.size(withAttributes: attrs)
        message.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attrs)
    }

    private func drawYAxis(in rect: NSRect, maxValue: Int, textColor: NSColor) {
        let steps = 5
        let stepValue = maxValue / steps

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]

        for i in 0...steps {
            let y = rect.minY + (rect.height * CGFloat(i) / CGFloat(steps))

            // Grid line
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: y))
            path.line(to: NSPoint(x: rect.maxX, y: y))
            textColor.withAlphaComponent(0.1).setStroke()
            path.lineWidth = 0.5
            path.stroke()

            // Label
            let value = i * stepValue
            let label = "\(value)"
            let labelSize = label.size(withAttributes: labelAttrs)
            label.draw(at: NSPoint(x: rect.minX - labelSize.width - 8, y: y - labelSize.height / 2), withAttributes: labelAttrs)
        }
    }

    private func rebuildLegend(characters: [String], colors: [NSColor]) {
        legendCharacters = characters
        legendColors = colors

        legendStack.arrangedSubviews.forEach { sub in
            legendStack.removeArrangedSubview(sub)
            sub.removeFromSuperview()
        }

        let header = NSTextField(labelWithString: "Characters")
        header.font = NSFont.boldSystemFont(ofSize: 11)
        legendStack.addArrangedSubview(header)

        for (index, character) in characters.enumerated() {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8

            let swatch = NSView(frame: NSRect(x: 0, y: 0, width: 12, height: 12))
            swatch.wantsLayer = true
            swatch.layer?.cornerRadius = 2
            swatch.layer?.backgroundColor = colors[index].cgColor

            let label = NSTextField(labelWithString: character)
            label.font = NSFont.systemFont(ofSize: 10)
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1

            row.addArrangedSubview(swatch)
            row.addArrangedSubview(label)

            legendStack.addArrangedSubview(row)
        }

        applyThemeToLegend()
        needsLayout = true
    }

    private func applyThemeToLegend() {
        let theme = ThemeManager.shared.currentTheme
        let textColor = theme.textColor

        for view in legendStack.arrangedSubviews {
            if let label = view as? NSTextField {
                label.textColor = textColor
            } else if let row = view as? NSStackView {
                for sub in row.arrangedSubviews {
                    if let label = sub as? NSTextField {
                        label.textColor = textColor
                    }
                }
            }
        }
    }

    private func generateColors(count: Int) -> [NSColor] {
        // High-contrast qualitative palette (15 distinct swatches)
        let palette: [NSColor] = [
            NSColor(calibratedRed: 0.12, green: 0.47, blue: 0.71, alpha: 1.0), // blue
            NSColor(calibratedRed: 0.84, green: 0.15, blue: 0.16, alpha: 1.0), // red
            NSColor(calibratedRed: 0.17, green: 0.63, blue: 0.17, alpha: 1.0), // green
            NSColor(calibratedRed: 1.00, green: 0.50, blue: 0.05, alpha: 1.0), // orange
            NSColor(calibratedRed: 0.55, green: 0.34, blue: 0.76, alpha: 1.0), // purple
            NSColor(calibratedRed: 0.60, green: 0.31, blue: 0.21, alpha: 1.0), // brown
            NSColor(calibratedRed: 0.90, green: 0.47, blue: 0.76, alpha: 1.0), // pink
            NSColor(calibratedRed: 0.50, green: 0.50, blue: 0.50, alpha: 1.0), // gray
            NSColor(calibratedRed: 0.74, green: 0.74, blue: 0.13, alpha: 1.0), // olive
            NSColor(calibratedRed: 0.09, green: 0.75, blue: 0.81, alpha: 1.0), // cyan
            NSColor(calibratedRed: 0.11, green: 0.62, blue: 0.52, alpha: 1.0), // teal
            NSColor(calibratedRed: 0.90, green: 0.67, blue: 0.00, alpha: 1.0), // gold
            NSColor(calibratedRed: 0.30, green: 0.43, blue: 0.96, alpha: 1.0), // navy
            NSColor(calibratedRed: 0.84, green: 0.12, blue: 0.55, alpha: 1.0), // magenta
            NSColor(calibratedRed: 0.40, green: 0.76, blue: 0.65, alpha: 1.0)  // seafoam
        ]

        var colors: [NSColor] = []
        for i in 0..<count {
            colors.append(palette[i % palette.count])
        }
        return colors
    }
}
