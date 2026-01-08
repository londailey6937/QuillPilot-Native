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

        // Fill background
        backgroundColor.setFill()
        dirtyRect.fill()

        let padding: CGFloat = 36
        let topPadding: CGFloat = 80
        let bottomPadding: CGFloat = 60

        let chartRect = NSRect(
            x: padding,
            y: bottomPadding,
            width: bounds.width - padding * 2,
            height: bounds.height - topPadding - bottomPadding
        )

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

        // Draw a simple network diagram: characters as nodes, interactions as edges.
        let allNames = Set(interactions.flatMap { [$0.character1, $0.character2] })
        let names = Array(allNames).sorted()
        if names.isEmpty {
            drawEmptyState()
            return
        }

        let nodeCount = names.count
        let center = NSPoint(x: chartRect.midX, y: chartRect.midY)
        let radius = max(40, min(chartRect.width, chartRect.height) * 0.35)

        // Place nodes on a circle for stability/readability
        var nodePositions: [String: NSPoint] = [:]
        for (i, name) in names.enumerated() {
            let angle = (2.0 * Double.pi * Double(i)) / Double(max(1, nodeCount))
            let x = center.x + CGFloat(cos(angle)) * radius
            let y = center.y + CGFloat(sin(angle)) * radius
            nodePositions[name] = NSPoint(x: x, y: y)
        }

        let maxCo = max(1, interactions.map { $0.coAppearances }.max() ?? 1)

        func edgeColor(for strength: Double) -> NSColor {
            if strength >= 0.66 { return NSColor.systemGreen.withAlphaComponent(0.7) }
            if strength >= 0.33 { return NSColor.systemOrange.withAlphaComponent(0.65) }
            return textColor.withAlphaComponent(0.25)
        }

        // Draw edges first
        for interaction in interactions {
            guard let p1 = nodePositions[interaction.character1], let p2 = nodePositions[interaction.character2] else { continue }
            let t = CGFloat(interaction.coAppearances) / CGFloat(maxCo)
            let width = 1.0 + 5.0 * t

            let path = NSBezierPath()
            path.move(to: p1)
            path.line(to: p2)
            path.lineWidth = width

            edgeColor(for: interaction.relationshipStrength).setStroke()
            path.stroke()
        }

        // Node styling
        let nodeFill = theme.pageBackground
        let nodeStroke = textColor.withAlphaComponent(0.35)
        let labelBG = theme.pageAround.withAlphaComponent(0.92)

        let nodeRadius: CGFloat = 12
        let labelFont = NSFont.systemFont(ofSize: nodeCount >= 18 ? 10 : 11, weight: .medium)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: textColor
        ]

        func clampRectToChart(_ rect: NSRect) -> NSRect {
            var r = rect
            r.origin.x = min(max(r.origin.x, chartRect.minX), chartRect.maxX - r.width)
            r.origin.y = min(max(r.origin.y, chartRect.minY), chartRect.maxY - r.height)
            return r
        }

        func unitVector(from: NSPoint, to: NSPoint) -> NSPoint {
            let dx = to.x - from.x
            let dy = to.y - from.y
            let len = max(0.0001, sqrt(dx * dx + dy * dy))
            return NSPoint(x: dx / len, y: dy / len)
        }

        // Pre-place labels with simple collision avoidance.
        // Strategy: place each label radially outward from the center (so labels sit outside the network),
        // then nudge outward if the chip overlaps a previously-placed chip.
        var placedLabelRects: [NSRect] = []
        var finalLabelRects: [String: NSRect] = [:]

        for name in names {
            guard let p = nodePositions[name] else { continue }

            let label = name
            let labelSize = label.size(withAttributes: labelAttrs)
            let padX: CGFloat = nodeCount >= 18 ? 5 : 6
            let padY: CGFloat = nodeCount >= 18 ? 2 : 3

            let direction = unitVector(from: center, to: p)
            let baseDistance = nodeRadius + 8 + (labelSize.height / 2) + padY

            var chosenRect: NSRect? = nil
            let maxAttempts = 18

            for attempt in 0..<maxAttempts {
                // Push outward more each attempt. Add a tiny alternating tangential component to break ties.
                let extra = CGFloat(attempt) * (nodeCount >= 18 ? 10 : 12)
                let tangent = NSPoint(x: -direction.y, y: direction.x)
                let wiggle = CGFloat((attempt % 2 == 0) ? 1 : -1) * CGFloat(attempt / 3) * 6

                let anchor = NSPoint(
                    x: p.x + direction.x * (baseDistance + extra) + tangent.x * wiggle,
                    y: p.y + direction.y * (baseDistance + extra) + tangent.y * wiggle
                )

                var rect = NSRect(
                    x: anchor.x - (labelSize.width / 2) - padX,
                    y: anchor.y - (labelSize.height / 2) - padY,
                    width: labelSize.width + padX * 2,
                    height: labelSize.height + padY * 2
                )
                rect = clampRectToChart(rect)

                let overlaps = placedLabelRects.contains { $0.intersects(rect) }
                if !overlaps {
                    chosenRect = rect
                    break
                }

                // On final attempt, accept a clamped rect even if overlapping.
                if attempt == maxAttempts - 1 {
                    chosenRect = rect
                }
            }

            if let rect = chosenRect {
                finalLabelRects[name] = rect
                placedLabelRects.append(rect)
            }
        }

        // Draw nodes
        for name in names {
            guard let p = nodePositions[name] else { continue }

            let nodeRect = NSRect(x: p.x - nodeRadius, y: p.y - nodeRadius, width: nodeRadius * 2, height: nodeRadius * 2)
            let nodePath = NSBezierPath(ovalIn: nodeRect)
            nodeFill.setFill()
            nodePath.fill()
            nodeStroke.setStroke()
            nodePath.lineWidth = 2
            nodePath.stroke()
        }

        // Draw labels last so they sit above edges/nodes
        for name in names {
            guard let labelRect = finalLabelRects[name] else { continue }
            let label = name
            let padX: CGFloat = nodeCount >= 18 ? 5 : 6
            let padY: CGFloat = nodeCount >= 18 ? 2 : 3

            let bgPath = NSBezierPath(roundedRect: labelRect, xRadius: 6, yRadius: 6)
            labelBG.setFill()
            bgPath.fill()
            nodeStroke.setStroke()
            bgPath.lineWidth = 1
            bgPath.stroke()

            label.draw(at: NSPoint(x: labelRect.minX + padX, y: labelRect.minY + padY), withAttributes: labelAttrs)
        }

        // Legend
        let legendX: CGFloat = chartRect.maxX - 190
        let legendY: CGFloat = bounds.height - 80
        let legendTitle = "Relationship Strength:"
        let legendTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]
        legendTitle.draw(at: NSPoint(x: legendX, y: legendY), withAttributes: legendTitleAttributes)

        let strengthLabels = ["Weak", "Medium", "Strong"]
        let strengthValues: [Double] = [0.2, 0.5, 0.85]
        for (i, label) in strengthLabels.enumerated() {
            let y = legendY - CGFloat(i + 1) * 18
            let p1 = NSPoint(x: legendX, y: y + 6)
            let p2 = NSPoint(x: legendX + 26, y: y + 6)
            let line = NSBezierPath()
            line.move(to: p1)
            line.line(to: p2)
            line.lineWidth = 3
            edgeColor(for: strengthValues[i]).setStroke()
            line.stroke()

            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: textColor.withAlphaComponent(0.7)
            ]
            label.draw(at: NSPoint(x: legendX + 32, y: y), withAttributes: labelAttributes)
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
