//
//  CharacterInteractionsView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class CharacterInteractionsView: NSView {

    struct InteractionData {
        let character1: String
        let character2: String
        let coAppearances: Int
        let relationshipStrength: Double
        let sections: [Int]
    }

    private var interactions: [InteractionData] = []
    private let maxBars = 15 // Show top 15 interactions

    func setInteractions(_ interactions: [InteractionData]) {
        self.interactions = Array(interactions.sorted { $0.coAppearances > $1.coAppearances }.prefix(maxBars))
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !interactions.isEmpty else {
            drawEmptyState()
            return
        }

        // Get theme colors
        let theme = ThemeManager.shared.currentTheme
        let backgroundColor = theme.pageAround
        let textColor = theme.textColor
        let gridColor = theme.textColor.withAlphaComponent(0.1)

        // Fill background
        backgroundColor.setFill()
        dirtyRect.fill()

        let padding: CGFloat = 60
        let topPadding: CGFloat = 100
        let bottomPadding: CGFloat = 120  // Increased for character names
        let chartWidth = bounds.width - (padding * 2)
        let chartHeight = bounds.height - topPadding - bottomPadding

        let maxValue = interactions.map { $0.coAppearances }.max() ?? 1

        // Draw title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: textColor
        ]
        let title = "Character Interactions Network"
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = NSRect(
            x: (bounds.width - titleSize.width) / 2,
            y: bounds.height - 35,
            width: titleSize.width,
            height: titleSize.height
        )
        title.draw(in: titleRect, withAttributes: titleAttributes)

        // Draw subtitle
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]
        let subtitle = "Frequency of character co-appearances in scenes"
        let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
        let subtitleRect = NSRect(
            x: (bounds.width - subtitleSize.width) / 2,
            y: bounds.height - 55,
            width: subtitleSize.width,
            height: subtitleSize.height
        )
        subtitle.draw(in: subtitleRect, withAttributes: subtitleAttributes)

        // Draw horizontal grid lines and labels
        let gridLineCount = 5
        for i in 0...gridLineCount {
            let y = bottomPadding + (chartHeight * CGFloat(i) / CGFloat(gridLineCount))
            let value = maxValue * i / gridLineCount  // Low values at bottom, high at top

            // Draw grid line
            gridColor.setStroke()
            let gridPath = NSBezierPath()
            gridPath.move(to: NSPoint(x: padding, y: y))
            gridPath.line(to: NSPoint(x: padding + chartWidth, y: y))
            gridPath.lineWidth = 1
            gridPath.stroke()

            // Draw value label
            let valueStr = "\(value)"
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: textColor.withAlphaComponent(0.6)
            ]
            let labelSize = valueStr.size(withAttributes: labelAttributes)
            let labelRect = NSRect(
                x: padding - labelSize.width - 8,
                y: y - labelSize.height / 2,
                width: labelSize.width,
                height: labelSize.height
            )
            valueStr.draw(in: labelRect, withAttributes: labelAttributes)
        }

        // Draw bars
        let barCount = CGFloat(interactions.count)
        let barSpacing: CGFloat = 12
        let totalSpacing = barSpacing * (barCount + 1)
        let barWidth = (chartWidth - totalSpacing) / barCount

        let colors: [NSColor] = [
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

        for (index, interaction) in interactions.enumerated() {
            let x = padding + barSpacing + (CGFloat(index) * (barWidth + barSpacing))
            let barHeight = chartHeight * CGFloat(interaction.coAppearances) / CGFloat(maxValue)
            let y = bottomPadding  // Bars start from bottom

            // Draw bar with gradient
            let barRect = NSRect(x: x, y: y, width: barWidth, height: barHeight)
            let color = colors[index % colors.count]

            // Convert to RGB for gradient
            guard let rgbColor = color.usingColorSpace(.deviceRGB) else { continue }
            let lightColor = NSColor(
                red: min(rgbColor.redComponent + 0.2, 1.0),
                green: min(rgbColor.greenComponent + 0.2, 1.0),
                blue: min(rgbColor.blueComponent + 0.2, 1.0),
                alpha: 1.0
            )

            let gradient = NSGradient(starting: lightColor, ending: color)
            gradient?.draw(in: barRect, angle: 90)

            // Draw bar outline
            color.setStroke()
            let barPath = NSBezierPath(rect: barRect)
            barPath.lineWidth = 1.5
            barPath.stroke()

            // Draw value on top of bar
            let valueStr = "\(interaction.coAppearances)"
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 11),
                .foregroundColor: textColor
            ]
            let valueSize = valueStr.size(withAttributes: valueAttributes)
            let valueRect = NSRect(
                x: x + (barWidth - valueSize.width) / 2,
                y: y + barHeight + 4,
                width: valueSize.width,
                height: valueSize.height
            )
            valueStr.draw(in: valueRect, withAttributes: valueAttributes)

            // Draw relationship strength indicator (small circle below x-axis near names)
            let strengthSize: CGFloat = 8 + (CGFloat(interaction.relationshipStrength) * 8)
            let strengthX = x + (barWidth - strengthSize) / 2
            let strengthY = bottomPadding - 35  // Position below x-axis, above character names
            let strengthRect = NSRect(x: strengthX, y: strengthY, width: strengthSize, height: strengthSize)
            let strengthPath = NSBezierPath(ovalIn: strengthRect)

            let strengthColor = NSColor(
                red: 1.0 - CGFloat(interaction.relationshipStrength),
                green: CGFloat(interaction.relationshipStrength),
                blue: 0.3,
                alpha: 0.8
            )
            strengthColor.setFill()
            strengthPath.fill()

            // Draw character names below axis
            let labelStr = "\(interaction.character1)\n↔\n\(interaction.character2)"

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineSpacing = 2

            let fullLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: textColor.withAlphaComponent(0.8),
                .paragraphStyle: paragraphStyle
            ]

            let labelHeight: CGFloat = 45
            let labelRect = NSRect(
                x: x - 10,
                y: bottomPadding - labelHeight - 50,  // Position below strength circles
                width: barWidth + 20,
                height: labelHeight
            )
            labelStr.draw(in: labelRect, withAttributes: fullLabelAttributes)
        }

        // Draw legend for relationship strength
        let legendX: CGFloat = bounds.width - 180
        let legendY: CGFloat = bounds.height - 80

        let legendTitle = "Relationship Strength:"
        let legendTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]
        legendTitle.draw(at: NSPoint(x: legendX, y: legendY), withAttributes: legendTitleAttributes)

        // Draw strength indicators
        let strengthLabels = ["Weak", "Medium", "Strong"]
        let strengthValues: [Double] = [0.3, 0.6, 0.9]

        for (i, label) in strengthLabels.enumerated() {
            let y = legendY - CGFloat(i + 1) * 20
            let strength = strengthValues[i]
            let size: CGFloat = 8 + (CGFloat(strength) * 8)

            let circleRect = NSRect(x: legendX, y: y, width: size, height: size)
            let circlePath = NSBezierPath(ovalIn: circleRect)

            let strengthColor = NSColor(
                red: 1.0 - CGFloat(strength),
                green: CGFloat(strength),
                blue: 0.3,
                alpha: 0.8
            )
            strengthColor.setFill()
            circlePath.fill()

            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: textColor.withAlphaComponent(0.7)
            ]
            label.draw(at: NSPoint(x: legendX + 22, y: y - 2), withAttributes: labelAttributes)
        }
    }

    private func drawEmptyState() {
        let theme = ThemeManager.shared.currentTheme
        theme.pageAround.setFill()
        bounds.fill()

        let message = "No character interactions detected"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: theme.textColor.withAlphaComponent(0.5)
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
}
