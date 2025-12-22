//
//  RelationshipEvolutionMapView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class RelationshipEvolutionMapView: NSView {

    struct RelationshipNode {
        let character: String
        let emotionalInvestment: Double // 0.0 to 1.0
        var position: NSPoint
    }

    struct RelationshipEdge {
        let from: String
        let to: String
        let trustLevel: Double // -1.0 (conflict) to 1.0 (trust)
        let powerDirection: PowerDirection // who has more influence
        let evolution: [EvolutionPoint] // changes over time
    }

    struct EvolutionPoint {
        let chapter: Int
        let trustLevel: Double
        let description: String
    }

    enum PowerDirection {
        case balanced
        case fromToTo // 'from' has power over 'to'
        case toToFrom // 'to' has power over 'from'
    }

    private var nodes: [RelationshipNode] = []
    private var edges: [RelationshipEdge] = []
    private var selectedChapter: Int = 0
    private var draggingNodeIndex: Int? = nil
    private var networkRect: NSRect = .zero

    func setRelationships(nodes: [RelationshipNode], edges: [RelationshipEdge]) {
        self.nodes = nodes
        self.edges = edges
        needsDisplay = true
    }

    func setSelectedChapter(_ chapter: Int) {
        self.selectedChapter = chapter
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !nodes.isEmpty else {
            drawEmptyState()
            return
        }

        // Get theme colors
        let theme = ThemeManager.shared.currentTheme
        let backgroundColor = theme.pageAround
        let textColor = theme.textColor
        let gridColor = theme.textColor.withAlphaComponent(0.05)

        // Fill background
        backgroundColor.setFill()
        dirtyRect.fill()

        let padding: CGFloat = 60
        let topPadding: CGFloat = 0
        let bottomPadding: CGFloat = 80
        let networkWidth = bounds.width - (padding * 2)
        let networkHeight = bounds.height - topPadding - bottomPadding - 45  // 45 for header
        networkRect = NSRect(x: padding, y: bottomPadding, width: networkWidth, height: networkHeight)

        // Draw title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: textColor
        ]
        let title = "Relationship Evolution Maps"
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = NSRect(
            x: (bounds.width - titleSize.width) / 2,
            y: bounds.height - 25,
            width: titleSize.width,
            height: titleSize.height
        )
        title.draw(in: titleRect, withAttributes: titleAttributes)

        // Draw subtitle (removed for space)
        // Combine subtitle and technique into one compact line
        let infoAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]
        let info = "Node size = emotional investment  •  Line thickness = trust/conflict  •  Arrows = power direction"
        let infoSize = info.size(withAttributes: infoAttributes)
        let infoRect = NSRect(
            x: (bounds.width - infoSize.width) / 2,
            y: bounds.height - 38,
            width: infoSize.width,
            height: infoSize.height
        )
        info.draw(in: infoRect, withAttributes: infoAttributes)

        // Draw subtle grid background
        drawGridBackground(in: networkRect, gridColor: gridColor)

        // Draw edges first (so they appear behind nodes)
        for edge in edges {
            drawEdge(edge, in: networkRect, textColor: textColor)
        }

        // Draw nodes on top
        for node in nodes {
            drawNode(node, in: networkRect, textColor: textColor)
        }

        // Draw legend
        drawLegend(textColor: textColor)
    }

    private func drawGridBackground(in rect: NSRect, gridColor: NSColor) {
        let spacing: CGFloat = 40
        let path = NSBezierPath()

        // Vertical lines
        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: NSPoint(x: x, y: rect.minY))
            path.line(to: NSPoint(x: x, y: rect.maxY))
            x += spacing
        }

        // Horizontal lines
        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: NSPoint(x: rect.minX, y: y))
            path.line(to: NSPoint(x: rect.maxX, y: y))
            y += spacing
        }

        gridColor.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    private func drawEdge(_ edge: RelationshipEdge, in rect: NSRect, textColor: NSColor) {
        guard let fromNode = nodes.first(where: { $0.character == edge.from }),
              let toNode = nodes.first(where: { $0.character == edge.to }) else {
            return
        }

        // Calculate actual positions in the network rect
        let fromPoint = NSPoint(
            x: rect.minX + (fromNode.position.x * rect.width),
            y: rect.minY + (fromNode.position.y * rect.height)
        )
        let toPoint = NSPoint(
            x: rect.minX + (toNode.position.x * rect.width),
            y: rect.minY + (toNode.position.y * rect.height)
        )

        // Find trust level for selected chapter, or use latest
        var currentTrust = edge.trustLevel
        if let evolutionPoint = edge.evolution.last(where: { $0.chapter <= selectedChapter }) {
            currentTrust = evolutionPoint.trustLevel
        }

        // Calculate line thickness based on trust level (absolute value = stronger relationship)
        let lineThickness: CGFloat = 2 + (abs(currentTrust) * 8)

        // Calculate color based on trust level
        let edgeColor: NSColor
        if currentTrust > 0 {
            // Trust = green tones
            edgeColor = NSColor(red: 0.2, green: 0.6 + (currentTrust * 0.4), blue: 0.3, alpha: 0.7)
        } else if currentTrust < 0 {
            // Conflict = red tones
            let intensity = abs(currentTrust)
            edgeColor = NSColor(red: 0.8, green: 0.2 + (1.0 - intensity) * 0.3, blue: 0.2, alpha: 0.7)
        } else {
            // Neutral = gray
            edgeColor = textColor.withAlphaComponent(0.3)
        }

        // Draw the line
        let path = NSBezierPath()
        path.move(to: fromPoint)
        path.line(to: toPoint)
        path.lineWidth = lineThickness
        edgeColor.setStroke()
        path.stroke()

        // Draw arrow for power direction
        drawPowerArrow(from: fromPoint, to: toPoint, direction: edge.powerDirection, color: edgeColor)

        // Draw midpoint label for trust/conflict level
        let midPoint = NSPoint(
            x: (fromPoint.x + toPoint.x) / 2,
            y: (fromPoint.y + toPoint.y) / 2
        )
        let labelStr = currentTrust > 0 ? "Trust: \(Int(currentTrust * 100))%" : currentTrust < 0 ? "Conflict: \(Int(abs(currentTrust) * 100))%" : "Neutral"
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]
        let labelSize = labelStr.size(withAttributes: labelAttributes)
        let labelRect = NSRect(
            x: midPoint.x - labelSize.width / 2,
            y: midPoint.y + 5,
            width: labelSize.width,
            height: labelSize.height
        )

        // Draw background for label with theme support
        let isDarkMode = ThemeManager.shared.isDarkMode
        let labelBgColor = isDarkMode ? NSColor.black.withAlphaComponent(0.7) : NSColor.white.withAlphaComponent(0.8)
        labelBgColor.setFill()
        NSBezierPath(roundedRect: labelRect.insetBy(dx: -3, dy: -1), xRadius: 3, yRadius: 3).fill()

        labelStr.draw(in: labelRect, withAttributes: labelAttributes)
    }

    private func drawPowerArrow(from: NSPoint, to: NSPoint, direction: PowerDirection, color: NSColor) {
        guard direction != .balanced else { return }

        let arrowPoint: NSPoint
        let arrowDirection: NSPoint

        switch direction {
        case .fromToTo:
            // Arrow points toward 'to'
            let progress: CGFloat = 0.7
            arrowPoint = NSPoint(
                x: from.x + (to.x - from.x) * progress,
                y: from.y + (to.y - from.y) * progress
            )
            arrowDirection = NSPoint(x: to.x - from.x, y: to.y - from.y)

        case .toToFrom:
            // Arrow points toward 'from'
            let progress: CGFloat = 0.3
            arrowPoint = NSPoint(
                x: from.x + (to.x - from.x) * progress,
                y: from.y + (to.y - from.y) * progress
            )
            arrowDirection = NSPoint(x: from.x - to.x, y: from.y - to.y)

        case .balanced:
            return
        }

        // Normalize direction
        let length = sqrt(arrowDirection.x * arrowDirection.x + arrowDirection.y * arrowDirection.y)
        let normalized = NSPoint(x: arrowDirection.x / length, y: arrowDirection.y / length)

        // Draw arrowhead
        let arrowSize: CGFloat = 10
        let arrowAngle: CGFloat = 0.5 // radians

        let arrowPath = NSBezierPath()
        arrowPath.move(to: arrowPoint)

        let perpX = -normalized.y
        let perpY = normalized.x

        let point1 = NSPoint(
            x: arrowPoint.x - normalized.x * arrowSize + perpX * arrowSize * sin(arrowAngle),
            y: arrowPoint.y - normalized.y * arrowSize + perpY * arrowSize * sin(arrowAngle)
        )
        let point2 = NSPoint(
            x: arrowPoint.x - normalized.x * arrowSize - perpX * arrowSize * sin(arrowAngle),
            y: arrowPoint.y - normalized.y * arrowSize - perpY * arrowSize * sin(arrowAngle)
        )

        arrowPath.line(to: point1)
        arrowPath.move(to: arrowPoint)
        arrowPath.line(to: point2)

        color.setStroke()
        arrowPath.lineWidth = 2.5
        arrowPath.stroke()
    }

    private func drawNode(_ node: RelationshipNode, in rect: NSRect, textColor: NSColor) {
        // Get dark mode status once for entire function
        let isDarkMode = ThemeManager.shared.isDarkMode

        // Calculate actual position in the network rect
        let position = NSPoint(
            x: rect.minX + (node.position.x * rect.width),
            y: rect.minY + (node.position.y * rect.height)
        )

        // Node size based on emotional investment (20 to 60 points diameter)
        let diameter: CGFloat = 20 + (node.emotionalInvestment * 40)

        // Draw node circle with gradient
        let nodeRect = NSRect(
            x: position.x - diameter / 2,
            y: position.y - diameter / 2,
            width: diameter,
            height: diameter
        )

        let nodePath = NSBezierPath(ovalIn: nodeRect)

        // Color based on emotional investment with better dark mode support
        let baseColor: NSColor
        let lightColor: NSColor

        if isDarkMode {
            // Brighter, more vibrant colors for dark mode
            baseColor = NSColor(
                red: 0.4 + (node.emotionalInvestment * 0.5),
                green: 0.6 + (node.emotionalInvestment * 0.3),
                blue: 0.9,
                alpha: 1.0
            )
            lightColor = NSColor(
                red: min(baseColor.redComponent + 0.4, 1.0),
                green: min(baseColor.greenComponent + 0.3, 1.0),
                blue: min(baseColor.blueComponent + 0.1, 1.0),
                alpha: 1.0
            )
        } else {
            // Original colors for light mode
            baseColor = NSColor(
                red: 0.3 + (node.emotionalInvestment * 0.5),
                green: 0.5 + (node.emotionalInvestment * 0.3),
                blue: 0.8,
                alpha: 0.9
            )
            lightColor = NSColor(
                red: min(baseColor.redComponent + 0.3, 1.0),
                green: min(baseColor.greenComponent + 0.3, 1.0),
                blue: min(baseColor.blueComponent + 0.2, 1.0),
                alpha: 0.9
            )
        }

        let gradient = NSGradient(starting: lightColor, ending: baseColor)
        gradient?.draw(in: nodePath, angle: 135)

        // Draw node border with theme-aware color
        let borderColor = isDarkMode ? NSColor.white.withAlphaComponent(0.9) : NSColor.white.withAlphaComponent(0.8)
        borderColor.setStroke()
        nodePath.lineWidth = isDarkMode ? 2.5 : 2
        nodePath.stroke()

        // Draw character name
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: textColor
        ]
        let nameSize = node.character.size(withAttributes: nameAttributes)
        let nameRect = NSRect(
            x: position.x - nameSize.width / 2,
            y: position.y + diameter / 2 + 8,
            width: nameSize.width,
            height: nameSize.height
        )

        // Draw background for name with theme support
        let nameBgColor = isDarkMode ? NSColor.black.withAlphaComponent(0.8) : NSColor.white.withAlphaComponent(0.9)
        nameBgColor.setFill()
        NSBezierPath(roundedRect: nameRect.insetBy(dx: -4, dy: -2), xRadius: 4, yRadius: 4).fill()

        node.character.draw(in: nameRect, withAttributes: nameAttributes)

        // Draw emotional investment percentage inside node - always show with high contrast
        let investmentStr = "\(Int(node.emotionalInvestment * 100))%"
        // Use dark text with white outline for maximum readability
        let fontSize: CGFloat = diameter > 40 ? 12 : (diameter > 30 ? 10 : 8)
        let investmentAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: NSColor.black,
            .strokeColor: NSColor.white,
            .strokeWidth: -3.0  // Negative = fill + stroke
        ]
        let investmentSize = investmentStr.size(withAttributes: investmentAttributes)
        let investmentRect = NSRect(
            x: position.x - investmentSize.width / 2,
            y: position.y - investmentSize.height / 2,
            width: investmentSize.width,
            height: investmentSize.height
        )
        investmentStr.draw(in: investmentRect, withAttributes: investmentAttributes)
    }

    private func drawLegend(textColor: NSColor) {
        let legendX: CGFloat = 20
        let legendY: CGFloat = 20

        let legendItems = [
            ("Node Size", "Emotional Investment"),
            ("Line Thickness", "Trust/Conflict Strength"),
            ("Green Line", "Trust"),
            ("Red Line", "Conflict"),
            ("Arrow", "Power Direction")
        ]

        var currentY = legendY

        for (key, value) in legendItems {
            let itemText = "\(key): \(value)"
            let itemAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: textColor.withAlphaComponent(0.7)
            ]
            itemText.draw(at: NSPoint(x: legendX, y: currentY), withAttributes: itemAttributes)
            currentY += 16
        }

        // Draw "Great for" section
        currentY += 10
        let greatForTitle = "Great for:"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: textColor.withAlphaComponent(0.8)
        ]
        greatForTitle.draw(at: NSPoint(x: legendX, y: currentY), withAttributes: titleAttributes)
        currentY += 16

        let greatForItems = [
            "• Ensemble casts",
            "• Romance arcs",
            "• Mentor/rival dynamics"
        ]

        for item in greatForItems {
            let itemAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: textColor.withAlphaComponent(0.6)
            ]
            item.draw(at: NSPoint(x: legendX + 5, y: currentY), withAttributes: itemAttributes)
            currentY += 14
        }

        // Draw insight
        currentY += 10
        let insight = "💡 Character growth is\nrelationship reconfiguration"
        let insightAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.systemPurple.withAlphaComponent(0.8)
        ]
        let insightRect = NSRect(x: legendX, y: currentY, width: 180, height: 30)
        insight.draw(in: insightRect, withAttributes: insightAttributes)
    }

    private func drawEmptyState() {
        let theme = ThemeManager.shared.currentTheme
        theme.pageAround.setFill()
        bounds.fill()

        let message = "No relationship data available\nRun Character Analysis to generate relationship maps"
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

    // MARK: - Mouse Dragging for Nodes

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        draggingNodeIndex = nodeIndex(at: location)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let index = draggingNodeIndex else { return }
        let location = convert(event.locationInWindow, from: nil)

        // Convert screen position to normalized position (0-1)
        let normalizedX = (location.x - networkRect.minX) / networkRect.width
        let normalizedY = (location.y - networkRect.minY) / networkRect.height

        // Clamp to valid range
        nodes[index].position = NSPoint(
            x: min(max(normalizedX, 0.05), 0.95),
            y: min(max(normalizedY, 0.05), 0.95)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        draggingNodeIndex = nil
    }

    private func nodeIndex(at point: NSPoint) -> Int? {
        for (index, node) in nodes.enumerated() {
            let position = NSPoint(
                x: networkRect.minX + (node.position.x * networkRect.width),
                y: networkRect.minY + (node.position.y * networkRect.height)
            )
            let diameter: CGFloat = 20 + (node.emotionalInvestment * 40)
            let nodeRect = NSRect(
                x: position.x - diameter / 2,
                y: position.y - diameter / 2,
                width: diameter,
                height: diameter
            )
            if nodeRect.contains(point) {
                return index
            }
        }
        return nil
    }
}
