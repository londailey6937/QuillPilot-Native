//
//  DecisionBeliefLoopView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

/// AppKit view for Decision-Belief Loop visualization
/// Uses draw() method for proper theme support
class DecisionBeliefLoopView: NSView {

    private var loops: [DecisionBeliefLoop] = []
    private var scrollView: NSScrollView!
    private var contentView: NSView!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupScrollView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScrollView()
    }

    private func setupScrollView() {
        scrollView = NSScrollView(frame: bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        contentView = NSView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: 2000))
        scrollView.documentView = contentView

        addSubview(scrollView)
    }

    func setLoops(_ loops: [DecisionBeliefLoop]) {
        let libraryOrder = CharacterLibrary.shared.analysisCharacterKeys
        if !libraryOrder.isEmpty {
            var canonicalOrderIndex: [String: Int] = [:]
            for (idx, name) in libraryOrder.enumerated() {
                let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if canonicalOrderIndex[key] == nil {
                    canonicalOrderIndex[key] = idx
                }
            }
            self.loops = loops.sorted {
                (canonicalOrderIndex[$0.characterName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] ?? Int.max) <
                (canonicalOrderIndex[$1.characterName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] ?? Int.max)
            }
        } else {
            self.loops = loops
        }
        updateContent()
    }

    func scrollToTop() {
        // Scroll the content view to the top
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: contentView.bounds.maxY - scrollView.contentView.bounds.height))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func updateContent() {
        // Remove old subviews
        contentView.subviews.forEach { $0.removeFromSuperview() }

        let theme = ThemeManager.shared.currentTheme
        let textColor = theme.textColor

        var yOffset: CGFloat = 20
        let leftPadding: CGFloat = 20
        let contentWidth = bounds.width - 40

        // Header
        let headerLabel = createLabel(
            text: "The Decision–Belief Loop Framework",
            font: NSFont.boldSystemFont(ofSize: 24),
            textColor: textColor
        )
        headerLabel.frame = NSRect(x: leftPadding, y: 0, width: contentWidth, height: 30)
        contentView.addSubview(headerLabel)
        yOffset += 40

        // Subtitle
        let subtitleLabel = createLabel(
            text: "Characters evolve because decisions reshape beliefs, and beliefs reshape future decisions. Everything you track flows through that loop.",
            font: NSFont.systemFont(ofSize: 13),
            textColor: textColor.withAlphaComponent(0.7)
        )
        subtitleLabel.frame = NSRect(x: leftPadding, y: 0, width: contentWidth, height: 40)
        contentView.addSubview(subtitleLabel)
        yOffset += 50

        // Divider
        let divider1 = NSView(frame: NSRect(x: leftPadding, y: 0, width: contentWidth, height: 1))
        divider1.wantsLayer = true
        divider1.layer?.backgroundColor = textColor.withAlphaComponent(0.2).cgColor
        contentView.addSubview(divider1)
        yOffset += 15

        // "The Loop" section header
        let loopHeaderLabel = createLabel(
            text: "The Loop (per scene)",
            font: NSFont.boldSystemFont(ofSize: 16),
            textColor: textColor
        )
        loopHeaderLabel.frame = NSRect(x: leftPadding, y: 0, width: contentWidth, height: 24)
        contentView.addSubview(loopHeaderLabel)
        yOffset += 35

        // Loop elements
        let loopElements = [
            ("1", "Pressure", "What new force acts on the character here? (external event, emotional demand, moral dilemma)"),
            ("2", "Belief in Play", "Which core belief is being tested? (often unstated in the prose)"),
            ("3", "Decision", "What choice does the character make because of that belief?"),
            ("4", "Outcome", "What happens immediately because of the decision? (success, partial win, failure, avoidance)"),
            ("5", "Belief Shift", "How does the belief change after the outcome? (reinforced, weakened, reframed, contradicted)")
        ]

        for (number, title, description) in loopElements {
            let elementView = createLoopElementView(
                number: number,
                title: title,
                description: description,
                width: contentWidth - 20,
                textColor: textColor
            )
            elementView.frame.origin = NSPoint(x: leftPadding + 10, y: 0)
            contentView.addSubview(elementView)
            yOffset += elementView.frame.height + 8
        }

        yOffset += 15

        // Divider
        let divider2 = NSView(frame: NSRect(x: leftPadding, y: 0, width: contentWidth, height: 1))
        divider2.wantsLayer = true
        divider2.layer?.backgroundColor = textColor.withAlphaComponent(0.2).cgColor
        contentView.addSubview(divider2)
        yOffset += 15

        // "How Evolution Emerges" section
        let evolutionHeaderLabel = createLabel(
            text: "How Evolution Emerges",
            font: NSFont.boldSystemFont(ofSize: 16),
            textColor: textColor
        )
        evolutionHeaderLabel.frame = NSRect(x: leftPadding, y: 0, width: contentWidth, height: 24)
        contentView.addSubview(evolutionHeaderLabel)
        yOffset += 35

        let evolutionIntro = createLabel(
            text: "Character growth becomes visible when:",
            font: NSFont.systemFont(ofSize: 13),
            textColor: textColor
        )
        evolutionIntro.frame = NSRect(x: leftPadding, y: 0, width: contentWidth, height: 20)
        contentView.addSubview(evolutionIntro)
        yOffset += 28

        let evolutionPoints = [
            "• Decisions stop being automatic",
            "• Beliefs gain nuance",
            "• Outcomes carry moral or emotional cost",
            "• The same pressure produces different choices later"
        ]

        for point in evolutionPoints {
            let pointLabel = createLabel(
                text: point,
                font: NSFont.systemFont(ofSize: 12),
                textColor: textColor.withAlphaComponent(0.7)
            )
            pointLabel.frame = NSRect(x: leftPadding + 15, y: 0, width: contentWidth - 15, height: 18)
            contentView.addSubview(pointLabel)
            yOffset += 22
        }

        yOffset += 10

        let measureNote = createLabel(
            text: "You don't measure intensity—you observe pattern change.",
            font: NSFont.systemFont(ofSize: 13),
            textColor: textColor
        )
        measureNote.frame = NSRect(x: leftPadding, y: 0, width: contentWidth, height: 20)
        contentView.addSubview(measureNote)
        yOffset += 40

        // Character sections
        for loop in loops {
            let characterSection = createCharacterSection(loop: loop, width: contentWidth, textColor: textColor)
            characterSection.frame.origin = NSPoint(x: leftPadding, y: 0)
            contentView.addSubview(characterSection)
            yOffset += characterSection.frame.height + 30
        }

        // Update positions (from bottom to top since NSView origin is bottom-left)
        let totalHeight = yOffset + 20
        contentView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: totalHeight)

        var currentY = totalHeight - 20
        for subview in contentView.subviews {
            let height = subview.frame.height
            subview.frame.origin.y = currentY - height
            currentY -= (height + (subview is NSTextField ? 8 : 15))
        }

        needsDisplay = true
    }

    private func createLabel(text: String, font: NSFont, textColor: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = textColor
        label.backgroundColor = .clear
        label.isBordered = false
        label.isEditable = false
        label.isSelectable = true
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        return label
    }

    private func createLoopElementView(number: String, title: String, description: String, width: CGFloat, textColor: NSColor) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 45))

        let numberLabel = createLabel(
            text: number,
            font: NSFont.boldSystemFont(ofSize: 14),
            textColor: textColor
        )
        numberLabel.frame = NSRect(x: 0, y: 25, width: 20, height: 20)
        container.addSubview(numberLabel)

        let titleLabel = createLabel(
            text: title,
            font: NSFont.boldSystemFont(ofSize: 14),
            textColor: textColor
        )
        titleLabel.frame = NSRect(x: 25, y: 25, width: width - 25, height: 20)
        container.addSubview(titleLabel)

        let descLabel = createLabel(
            text: description,
            font: NSFont.systemFont(ofSize: 11),
            textColor: textColor.withAlphaComponent(0.7)
        )
        descLabel.frame = NSRect(x: 25, y: 0, width: width - 25, height: 22)
        container.addSubview(descLabel)

        return container
    }

    private func createCharacterSection(loop: DecisionBeliefLoop, width: CGFloat, textColor: NSColor) -> NSView {
        var height: CGFloat = 0

        // Calculate height based on content
        let headerHeight: CGFloat = 40
        let tableHeaderHeight: CGFloat = 30
        let rowHeight: CGFloat = 60
        let entriesHeight = CGFloat(loop.entries.count) * rowHeight
        let timelineHeight: CGFloat = 196
        let diagnosticHeight: CGFloat = 120

        height = headerHeight + tableHeaderHeight + entriesHeight + timelineHeight + diagnosticHeight + 60

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        container.wantsLayer = true
        container.layer?.backgroundColor = textColor.withAlphaComponent(0.03).cgColor
        container.layer?.cornerRadius = 12

        var yPos = height - 20

        // Character name header
        let nameLabel = createLabel(
            text: loop.characterName,
            font: NSFont.boldSystemFont(ofSize: 20),
            textColor: textColor
        )
        nameLabel.frame = NSRect(x: 15, y: yPos - 25, width: width - 150, height: 25)
        container.addSubview(nameLabel)

        // Arc quality badge
        let badgeLabel = NSTextField(labelWithString: loop.arcQuality.rawValue)
        badgeLabel.font = NSFont.systemFont(ofSize: 11)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = arcQualityColor(loop.arcQuality)
        badgeLabel.isBordered = false
        badgeLabel.wantsLayer = true
        badgeLabel.layer?.backgroundColor = arcQualityColor(loop.arcQuality).cgColor
        badgeLabel.layer?.cornerRadius = 6
        badgeLabel.alignment = .center
        badgeLabel.frame = NSRect(x: width - 130, y: yPos - 23, width: 115, height: 22)
        container.addSubview(badgeLabel)

        yPos -= 50

        // Table header
        let columns = ["Ch", "Pressure", "Belief in Play", "Decision", "Outcome", "Belief Shift"]
        let columnWidths: [CGFloat] = [40, (width - 60) / 5, (width - 60) / 5, (width - 60) / 5, (width - 60) / 5, (width - 60) / 5]

        var xPos: CGFloat = 10
        for (index, column) in columns.enumerated() {
            let headerLabel = createLabel(
                text: column,
                font: NSFont.boldSystemFont(ofSize: 10),
                textColor: textColor
            )
            headerLabel.frame = NSRect(x: xPos, y: yPos - 20, width: columnWidths[index], height: 20)
            container.addSubview(headerLabel)
            xPos += columnWidths[index] + 5
        }

        yPos -= 30

        // Table rows
        for entry in loop.entries {
            let rowValues = [
                "\(entry.chapter)",
                entry.pressure.isEmpty ? "—" : entry.pressure,
                entry.beliefInPlay.isEmpty ? "—" : entry.beliefInPlay,
                entry.decision.isEmpty ? "—" : entry.decision,
                entry.outcome.isEmpty ? "—" : entry.outcome,
                entry.beliefShift.isEmpty ? "—" : entry.beliefShift
            ]

            xPos = 10
            for (index, value) in rowValues.enumerated() {
                let valueLabel = createLabel(
                    text: value,
                    font: NSFont.systemFont(ofSize: 10),
                    textColor: textColor
                )
                valueLabel.frame = NSRect(x: xPos, y: yPos - rowHeight + 10, width: columnWidths[index], height: rowHeight - 15)
                container.addSubview(valueLabel)
                xPos += columnWidths[index] + 5
            }

            yPos -= rowHeight
        }

        yPos -= 20

        // Timeline section
        let timelineLabel = createLabel(
            text: "Character Arc Timeline",
            font: NSFont.boldSystemFont(ofSize: 14),
            textColor: textColor
        )
        timelineLabel.frame = NSRect(x: 15, y: yPos - 20, width: width - 30, height: 20)
        container.addSubview(timelineLabel)

        let timelineSubLabel = createLabel(
            text: "Key inflection points across scenes",
            font: NSFont.systemFont(ofSize: 10),
            textColor: textColor.withAlphaComponent(0.6)
        )
        timelineSubLabel.frame = NSRect(x: 15, y: yPos - 38, width: width - 30, height: 16)
        container.addSubview(timelineSubLabel)

        // Timeline legend (dot colors)
        let legendItems: [(String, NSColor)] = [
            ("Reinforced", beliefShiftColor("reinforced")),
            ("Weakened", beliefShiftColor("weakened")),
            ("Reframed", beliefShiftColor("reframed")),
            ("Contradicted", beliefShiftColor("contradicted")),
            ("Other shift", beliefShiftColor("other shift")),
            ("No shift", beliefShiftColor(""))
        ]
        let legendView = TimelineLegendView(items: legendItems, textColor: textColor.withAlphaComponent(0.7))
        legendView.frame = NSRect(x: 15, y: yPos - 72, width: width - 30, height: 32)
        container.addSubview(legendView)

        // Simple timeline visualization
        let timelineView = createTimelineView(entries: loop.entries, width: width - 40, textColor: textColor)
        timelineView.frame.origin = NSPoint(x: 20, y: yPos - 161)
        container.addSubview(timelineView)

        return container
    }

    private func createTimelineView(entries: [DecisionBeliefLoop.LoopEntry], width: CGFloat, textColor: NSColor) -> NSView {
        let view = TimelineDrawingView(frame: NSRect(x: 0, y: 0, width: width, height: 80))
        view.entries = entries
        view.textColor = textColor

        // Pre-compute colors for each entry
        view.nodeColors = entries.map { beliefShiftColor($0.beliefShift) }

        // Add scene labels
        guard !entries.isEmpty else { return view }

        let lineY: CGFloat = 40
        let spacing = width / CGFloat(max(entries.count, 1) + 1)

        for (index, entry) in entries.enumerated() {
            let x = spacing * CGFloat(index + 1)

            // Scene label
            let chapterLabel = createLabel(
                text: "Sc \(entry.chapter)",
                font: NSFont.systemFont(ofSize: 9),
                textColor: textColor.withAlphaComponent(0.7)
            )
            chapterLabel.frame = NSRect(x: x - 15, y: lineY + 15, width: 30, height: 14)
            chapterLabel.alignment = .center
            view.addSubview(chapterLabel)
        }

        return view
    }

    private func beliefShiftColor(_ shift: String) -> NSColor {
        let lowercased = shift.lowercased()
        if lowercased.contains("reinforce") || lowercased.contains("strength") || lowercased.contains("confirm") {
            return NSColor.systemBlue
        } else if lowercased.contains("weaken") || lowercased.contains("doubt") || lowercased.contains("question") {
            return NSColor.systemOrange
        } else if lowercased.contains("reframe") || lowercased.contains("shift") || lowercased.contains("change") {
            return NSColor.systemPurple
        } else if lowercased.contains("contradict") || lowercased.contains("break") || lowercased.contains("shatter") {
            return NSColor.systemRed
        } else if !shift.isEmpty && shift != "—" {
            // If there's actual content but no keywords, use green as "evolving"
            return NSColor.systemGreen
        } else {
            return NSColor.systemGray
        }
    }

    private func arcQualityColor(_ quality: DecisionBeliefLoop.ArcQuality) -> NSColor {
        switch quality {
        case .evolving:
            return NSColor.systemGreen
        case .developing:
            return NSColor.systemBlue
        case .flat:
            return NSColor.systemOrange
        case .insufficient:
            return NSColor.systemGray
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let theme = ThemeManager.shared.currentTheme
        let backgroundColor = theme.pageAround

        backgroundColor.setFill()
        dirtyRect.fill()

        // Update scroll view background
        scrollView.backgroundColor = theme.pageAround
        scrollView.drawsBackground = true
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
        updateContent()
    }
}

private final class TimelineLegendView: NSView {
    let items: [(String, NSColor)]
    let textColor: NSColor

    init(items: [(String, NSColor)], textColor: NSColor) {
        self.items = items
        self.textColor = textColor
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let font = NSFont.systemFont(ofSize: 10)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        let dotDiameter: CGFloat = 7
        let dotYOffset: CGFloat = 2
        let gapAfterDot: CGFloat = 5
        let itemGap: CGFloat = 12

        var x: CGFloat = 0
        var y: CGFloat = bounds.height - 14

        for (label, color) in items {
            let labelSize = label.size(withAttributes: attrs)
            let neededWidth = dotDiameter + gapAfterDot + labelSize.width + itemGap

            if x + neededWidth > bounds.width, x > 0 {
                x = 0
                y -= 14
            }

            let dotRect = NSRect(x: x, y: y + dotYOffset, width: dotDiameter, height: dotDiameter)
            let dotPath = NSBezierPath(ovalIn: dotRect)
            color.withAlphaComponent(0.9).setFill()
            dotPath.fill()

            label.draw(at: NSPoint(x: x + dotDiameter + gapAfterDot, y: y), withAttributes: attrs)
            x += dotDiameter + gapAfterDot + labelSize.width + itemGap
        }
    }
}
// MARK: - Timeline Drawing View

private class TimelineDrawingView: NSView {
    var entries: [DecisionBeliefLoop.LoopEntry] = []
    var textColor: NSColor = .labelColor
    var nodeColors: [NSColor] = []

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !entries.isEmpty else { return }

        let lineY: CGFloat = 40
        let nodeRadius: CGFloat = 8
        let spacing = bounds.width / CGFloat(max(entries.count, 1) + 1)

        // Draw timeline line
        let linePath = NSBezierPath()
        linePath.move(to: NSPoint(x: 20, y: lineY))
        linePath.line(to: NSPoint(x: bounds.width - 20, y: lineY))
        textColor.withAlphaComponent(0.3).setStroke()
        linePath.lineWidth = 2
        linePath.stroke()

        // Draw nodes
        for (index, _) in entries.enumerated() {
            let x = spacing * CGFloat(index + 1)

            // Node circle
            let nodePath = NSBezierPath(ovalIn: NSRect(x: x - nodeRadius, y: lineY - nodeRadius, width: nodeRadius * 2, height: nodeRadius * 2))

            let fillColor = index < nodeColors.count ? nodeColors[index] : NSColor.systemGray
            fillColor.setFill()
            nodePath.fill()

            textColor.withAlphaComponent(0.5).setStroke()
            nodePath.lineWidth = 1
            nodePath.stroke()
        }
    }
}
