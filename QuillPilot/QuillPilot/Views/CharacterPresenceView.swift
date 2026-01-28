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

    enum DisplayMode {
        case scenes
        case chapters
    }

    private enum XAxisMode: Int {
        case scenes = 0
        case acts = 1
    }

    private final class CharacterPresenceChartView: NSView {
        var presence: [CharacterPresence] = [] { didSet { needsDisplay = true } }
        var characters: [String] = [] { didSet { needsDisplay = true } }
        var colors: [NSColor] = [] { didSet { needsDisplay = true } }

        var xAxisTitle: String = "Scene" { didSet { needsDisplay = true } }
        var xTickPrefix: String = "Sc" { didSet { needsDisplay = true } }

        // Width of the visible viewport (used for label density decisions).
        var visibleWidth: CGFloat = 0 { didSet { needsDisplay = true } }

        // Shared scale for Y-axis rendering.
        var maxMentions: Int = 1 { didSet { needsDisplay = true } }

        // MARK: Drawing
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

            // Collect data into a fast lookup map.
            var mentionMap: [String: [Int: Int]] = [:]
            var chaptersSet = Set<Int>()
            var maxMentions = 0
            for entry in presence {
                var perChapter: [Int: Int] = mentionMap[entry.characterName] ?? [:]
                for (chapter, mentions) in entry.chapterPresence {
                    perChapter[chapter] = mentions
                    chaptersSet.insert(chapter)
                    if mentions > maxMentions { maxMentions = mentions }
                }
                mentionMap[entry.characterName] = perChapter
            }

            let chapters = Array(chaptersSet).sorted()
            guard !chapters.isEmpty else {
                drawEmptyState(textColor: textColor)
                return
            }

            // Layout constants (Y-axis is rendered by a separate fixed view).
            let padding: CGFloat = 20
            // Header (title/subtitle/mode control) is outside the chart scroll view.
            let topPadding: CGFloat = 24
            let bottomPadding: CGFloat = 100
            let chartWidth = bounds.width - padding * 2
            let chartHeight = bounds.height - topPadding - bottomPadding
            let chartRect = NSRect(x: padding, y: bottomPadding, width: max(1, chartWidth), height: max(1, chartHeight))

            // Draw bars
            let barGroupWidth = chartRect.width / CGFloat(max(1, chapters.count))
            let groupInnerPadding = min(10, max(0, barGroupWidth * 0.2))
            let availableGroupWidth = max(1, barGroupWidth - groupInnerPadding)
            let perCharacterWidth = availableGroupWidth / CGFloat(max(1, characters.count))
            let barWidth = max(1, min(32, floor(perCharacterWidth)))

            // If the chart is very dense, suppress tiny per-bar value labels.
            let totalBars = chapters.count * characters.count
            let showValueLabels = (barWidth >= 14) && (totalBars <= 240)

            // Scene labels should be shown for every scene.
            // Rotate when dense to reduce overlap.
            let viewportWidth = max(1, visibleWidth)
            let approxLabelCountThatFits = max(6, Int(floor(viewportWidth / 60)))
            let rotateSceneLabels = chapters.count > approxLabelCountThatFits

            for (chapterIndex, chapter) in chapters.enumerated() {
                let totalGroupBarsWidth = CGFloat(characters.count) * barWidth
                let groupX = chartRect.minX + (CGFloat(chapterIndex) * barGroupWidth) + (barGroupWidth - totalGroupBarsWidth) / 2

                for (charIndex, character) in characters.enumerated() {
                    let mentions = mentionMap[character]?[chapter] ?? 0
                    if mentions >= 0 {
                        let barHeight = (CGFloat(mentions) / CGFloat(maxMentions)) * chartRect.height
                        let barX = groupX + CGFloat(charIndex) * barWidth

                        let barDrawWidth = max(1, barWidth - 1)
                        let barRect = NSRect(
                            x: barX,
                            y: chartRect.minY,
                            width: barDrawWidth,
                            height: barHeight
                        )

                        if charIndex < colors.count {
                            colors[charIndex].setFill()
                        }
                        if barDrawWidth >= 4 {
                            NSBezierPath(roundedRect: barRect, xRadius: 2, yRadius: 2).fill()
                        } else {
                            NSBezierPath(rect: barRect).fill()
                        }

                        if showValueLabels, mentions > 0 {
                            let valueStr = "\(mentions)"
                            let valueAttrs: [NSAttributedString.Key: Any] = [
                                .font: NSFont.systemFont(ofSize: 9),
                                .foregroundColor: textColor.withAlphaComponent(0.75)
                            ]
                            let valueSize = valueStr.size(withAttributes: valueAttrs)
                            valueStr.draw(
                                at: NSPoint(x: barX + (barWidth - 2 - valueSize.width) / 2, y: chartRect.minY + barHeight + 3),
                                withAttributes: valueAttrs
                            )
                        }
                    }
                }

                // Draw x tick label (every scene)
                let sceneLabel = "\(xTickPrefix) \(chapter)"
                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: rotateSceneLabels ? 9 : 11),
                    .foregroundColor: textColor.withAlphaComponent(0.78)
                ]
                let labelSize = sceneLabel.size(withAttributes: labelAttrs)
                let centerX = chartRect.minX + (CGFloat(chapterIndex) * barGroupWidth) + (barGroupWidth / 2)

                if rotateSceneLabels, let context = NSGraphicsContext.current?.cgContext {
                    context.saveGState()
                    context.translateBy(x: centerX, y: chartRect.minY - 18)
                    context.rotate(by: -.pi / 4)
                    sceneLabel.draw(at: NSPoint(x: -labelSize.width / 2, y: -labelSize.height / 2), withAttributes: labelAttrs)
                    context.restoreGState()
                } else {
                    let labelX = centerX - (labelSize.width / 2)
                    sceneLabel.draw(at: NSPoint(x: labelX, y: chartRect.minY - 20), withAttributes: labelAttrs)
                }
            }

            // Axis labels
            let xAxisLabel = xAxisTitle
            let xAxisAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: textColor
            ]
            let xAxisSize = xAxisLabel.size(withAttributes: xAxisAttrs)
            xAxisLabel.draw(at: NSPoint(x: chartRect.midX - xAxisSize.width / 2, y: chartRect.minY - 45), withAttributes: xAxisAttrs)

        }

        private func drawEmptyState(textColor: NSColor) {
            let message = "No character presence data"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: textColor.withAlphaComponent(0.5)
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

    private final class CharacterPresenceYAxisView: NSView {
        var maxValue: Int = 1 { didSet { needsDisplay = true } }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)

            let theme = ThemeManager.shared.currentTheme
            let textColor = theme.textColor

            theme.pageAround.setFill()
            dirtyRect.fill()

            let topPadding: CGFloat = 24
            let bottomPadding: CGFloat = 100
            let leftPadding: CGFloat = 8
            let rightPadding: CGFloat = 8

            let axisX = bounds.maxX - rightPadding
            let axisRect = NSRect(
                x: leftPadding,
                y: bottomPadding,
                width: max(1, bounds.width - leftPadding - rightPadding),
                height: max(1, bounds.height - topPadding - bottomPadding)
            )

            // Y axis line
            let axisPath = NSBezierPath()
            axisPath.move(to: NSPoint(x: axisX, y: axisRect.minY))
            axisPath.line(to: NSPoint(x: axisX, y: axisRect.maxY))
            textColor.withAlphaComponent(0.25).setStroke()
            axisPath.lineWidth = 1
            axisPath.stroke()

            let ticks = 5
            let maxV = max(1, maxValue)
            for i in 0...ticks {
                let value = Int(round(Double(maxV) * Double(i) / Double(ticks)))
                let y = axisRect.minY + (axisRect.height * CGFloat(i) / CGFloat(ticks))

                let tickPath = NSBezierPath()
                tickPath.move(to: NSPoint(x: axisX - 4, y: y))
                tickPath.line(to: NSPoint(x: axisX, y: y))
                tickPath.lineWidth = 1
                tickPath.stroke()

                let label = "\(value)"
                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9),
                    .foregroundColor: textColor.withAlphaComponent(0.6)
                ]
                let labelSize = label.size(withAttributes: labelAttrs)
                label.draw(at: NSPoint(x: axisX - 8 - labelSize.width, y: y - labelSize.height / 2), withAttributes: labelAttrs)
            }

            // Rotated axis title
            let yAxisLabel = "Mentions"
            let yAxisAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: textColor
            ]
            if let context = NSGraphicsContext.current?.cgContext {
                context.saveGState()
                context.translateBy(x: 14, y: axisRect.midY)
                context.rotate(by: .pi / 2)
                let ySize = yAxisLabel.size(withAttributes: yAxisAttrs)
                yAxisLabel.draw(at: NSPoint(x: -ySize.width / 2, y: -ySize.height / 2), withAttributes: yAxisAttrs)
                context.restoreGState()
            }
        }
    }

    private var presence: [CharacterPresence] = []
    private var rawPresence: [CharacterPresence] = []
    private var xAxisMode: XAxisMode = .scenes
    private var displayMode: DisplayMode = .scenes

    private let chartScrollView = NSScrollView()
    private let chartView = CharacterPresenceChartView(frame: .zero)
    private let yAxisView = CharacterPresenceYAxisView(frame: .zero)
    private var chartContentWidth: CGFloat = 0
    private var desiredChartContentWidth: CGFloat = 0

    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

    private let modeControlContainer = NSView()
    private let scenesButton = NSButton(title: "Scenes", target: nil, action: nil)
    private let actsButton = NSButton(title: "Acts", target: nil, action: nil)

    private let legendWidth: CGFloat = 180
    private let legendScrollView = NSScrollView()
    private let legendStack = NSStackView()
    private var legendCharacters: [String] = []
    private var legendColors: [NSColor] = []
    private var themeObserver: NSObjectProtocol?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupChartViews()
        setupLegendViews()
        setupModeControl()
        setupHeaderLabels()
        applyThemeToModeControl()
        startObservingTheme()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupChartViews()
        setupLegendViews()
        setupModeControl()
        setupHeaderLabels()
        applyThemeToModeControl()
        startObservingTheme()
    }

    func setDisplayMode(_ mode: DisplayMode) {
        displayMode = mode

        switch displayMode {
        case .chapters:
            modeControlContainer.isHidden = true
            xAxisMode = .scenes
        case .scenes:
            modeControlContainer.isHidden = false
        }

        applyXAxisMode()
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }

    private func setupChartViews() {
        chartScrollView.documentView = chartView
        chartScrollView.hasHorizontalScroller = true
        chartScrollView.hasVerticalScroller = false
        chartScrollView.autohidesScrollers = false
        chartScrollView.drawsBackground = true
        chartScrollView.backgroundColor = ThemeManager.shared.currentTheme.pageAround
        chartScrollView.borderType = .noBorder

        // Keep wheel/trackpad scrolling responsive.
        chartScrollView.horizontalScrollElasticity = .allowed

        chartView.wantsLayer = true
        addSubview(yAxisView)
        addSubview(chartScrollView)
    }

    private func setupHeaderLabels() {
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.alignment = .center
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 1

        addSubview(titleLabel)
        addSubview(subtitleLabel)
    }

    private func setupModeControl() {
        scenesButton.target = self
        scenesButton.action = #selector(scenesModeTapped)
        scenesButton.isBordered = false
        scenesButton.wantsLayer = true

        actsButton.target = self
        actsButton.action = #selector(actsModeTapped)
        actsButton.isBordered = false
        actsButton.wantsLayer = true

        modeControlContainer.addSubview(scenesButton)
        modeControlContainer.addSubview(actsButton)
        addSubview(modeControlContainer)
    }

    private func setupLegendViews() {
        legendStack.orientation = .vertical
        legendStack.alignment = .leading
        legendStack.spacing = 8
        legendStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        legendScrollView.documentView = legendStack
        legendScrollView.hasVerticalScroller = true
        legendScrollView.autohidesScrollers = false
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
            self?.applyThemeToModeControl()
            let theme = ThemeManager.shared.currentTheme
            self?.chartScrollView.backgroundColor = theme.pageAround
            self?.needsDisplay = true
        }
    }

    private func computeDesiredChartWidth(chaptersCount: Int, charactersCount: Int) -> CGFloat {
        // Match sizing logic in applyXAxisMode, but keep it independent of the view’s current bounds.
        let minBarWidthPerCharacter: CGFloat = 16
        let groupOuterPadding: CGFloat = 18
        let minGroupWidth: CGFloat = 80
        let groupWidth = max(minGroupWidth, CGFloat(charactersCount) * minBarWidthPerCharacter + groupOuterPadding)
        let padding: CGFloat = 20
        return padding * 2 + CGFloat(max(1, chaptersCount)) * groupWidth
    }

    override func layout() {
        super.layout()

        let headerHeight: CGFloat = 70
        let chartHeight = max(1, bounds.height - headerHeight)
        let legendX = bounds.width - legendWidth - 10
        legendScrollView.frame = NSRect(x: legendX, y: 0, width: legendWidth, height: chartHeight)

        // Chart area takes the remaining space on the left.
        let chartAreaWidth = max(1, legendX - 10)

        let yAxisWidth: CGFloat = 70
        yAxisView.frame = NSRect(x: 0, y: 0, width: yAxisWidth, height: chartHeight)
        chartScrollView.frame = NSRect(x: yAxisWidth, y: 0, width: max(1, chartAreaWidth - yAxisWidth), height: chartHeight)

        // Keep the chart view tall; width can exceed the visible area for scrolling.
        if chartContentWidth <= 0 { chartContentWidth = chartAreaWidth }
        if desiredChartContentWidth > 0 {
            chartContentWidth = max(chartAreaWidth, desiredChartContentWidth)
        }
        chartView.frame = NSRect(x: 0, y: 0, width: chartContentWidth, height: chartHeight)
        chartView.visibleWidth = chartScrollView.contentView.bounds.width

        let buttonHeight: CGFloat = 24
        scenesButton.sizeToFit()
        actsButton.sizeToFit()
        let buttonWidth = max(scenesButton.frame.width, actsButton.frame.width) + 18
        scenesButton.frame = NSRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight)
        actsButton.frame = NSRect(x: buttonWidth + 6, y: 0, width: buttonWidth, height: buttonHeight)

        modeControlContainer.frame = NSRect(
            x: 20,
            y: bounds.height - buttonHeight - 10,
            width: actsButton.frame.maxX,
            height: buttonHeight
        )

        // Header labels
        titleLabel.frame = NSRect(x: 0, y: bounds.height - 46, width: bounds.width, height: 22)
        subtitleLabel.frame = NSRect(x: 0, y: bounds.height - 64, width: bounds.width, height: 16)

        // Size stack for scroll.
        let legendViewportH = max(1, legendScrollView.contentSize.height)
        let legendTargetH = max(legendStack.fittingSize.height + 12, legendViewportH + 1)
        legendStack.frame = NSRect(x: 0, y: 0, width: legendWidth, height: legendTargetH)
    }

    func setPresence(_ presence: [CharacterPresence]) {
        rawPresence = presence
        applyXAxisMode()
    }

    @objc private func scenesModeTapped() {
        guard displayMode == .scenes else { return }
        xAxisMode = .scenes
        applyXAxisMode()
    }

    @objc private func actsModeTapped() {
        guard displayMode == .scenes else { return }
        xAxisMode = .acts
        applyXAxisMode()
    }

    private func applyXAxisMode() {
        switch displayMode {
        case .chapters:
            presence = rawPresence
        case .scenes:
            presence = (xAxisMode == .acts) ? aggregatePresenceToActs(rawPresence) : rawPresence
        }

        // Collect data
        var dataPoints: [(character: String, chapter: Int, mentions: Int)] = []
        for entry in presence {
            for (chapter, mentions) in entry.chapterPresence {
                dataPoints.append((entry.characterName, chapter, mentions))
            }
        }

        let chapters = Array(Set(dataPoints.map { $0.chapter })).sorted()
        let presentCharacters = Set(dataPoints.map { $0.character })
        let libraryOrder = CharacterLibrary.shared.analysisCharacterKeys
        let characters = !libraryOrder.isEmpty
            ? libraryOrder.filter { presentCharacters.contains($0) }
            : Array(presentCharacters).sorted()

        let colors = generateColors(count: characters.count)

        chartView.presence = presence
        chartView.characters = characters
        chartView.colors = colors

        // Update shared Y-axis scaling for the fixed axis view.
        var maxMentions = 0
        for entry in presence {
            for mentions in entry.chapterPresence.values {
                if mentions > maxMentions { maxMentions = mentions }
            }
        }
        if maxMentions <= 0 { maxMentions = 1 }
        chartView.maxMentions = maxMentions
        yAxisView.maxValue = maxMentions

        switch displayMode {
        case .chapters:
            chartView.xAxisTitle = "Chapter"
            chartView.xTickPrefix = "Ch"
        case .scenes:
            if xAxisMode == .acts {
                chartView.xAxisTitle = "Act"
                chartView.xTickPrefix = "Act"
            } else {
                chartView.xAxisTitle = "Scene"
                chartView.xTickPrefix = "Sc"
            }
        }

        desiredChartContentWidth = computeDesiredChartWidth(chaptersCount: chapters.count, charactersCount: characters.count)
        chartContentWidth = max(bounds.width - legendWidth - 20, desiredChartContentWidth)

        rebuildLegend(characters: characters, colors: colors)

        // Update header labels
        switch displayMode {
        case .chapters:
            titleLabel.stringValue = "Character Presence by Chapter"
            subtitleLabel.stringValue = "Number of mentions per character per chapter"
        case .scenes:
            if xAxisMode == .acts {
                titleLabel.stringValue = "Character Presence by Act"
                subtitleLabel.stringValue = "Number of mentions per character per act"
            } else {
                titleLabel.stringValue = "Character Presence by Scene"
                subtitleLabel.stringValue = "Number of mentions per character per scene"
            }
        }

        updateModeButtonAppearance()

        needsLayout = true
        needsDisplay = true
    }

    private func aggregatePresenceToActs(_ input: [CharacterPresence]) -> [CharacterPresence] {
        // Prefer an explicit scene->act mapping emitted by the analyzer when ACT I/II/III headings exist.
        if let explicitMap = input.first?.chapterToAct, !explicitMap.isEmpty {
            return input.map { entry in
                var out = CharacterPresence(characterName: entry.characterName)
                out.chapterToAct = [:]
                for (scene, mentions) in entry.chapterPresence {
                    guard let act = explicitMap[scene] else { continue }
                    out.chapterPresence[act, default: 0] += mentions
                }
                return out
            }
        }

        // Fallback: derive act buckets by equal partitioning when no act markers are available.
        let scenes = Array(Set(input.flatMap { $0.chapterPresence.keys })).sorted()
        guard scenes.count >= 2 else { return input }

        let actCount: Int = scenes.count >= 3 ? 3 : 1
        guard actCount > 1 else { return input }

        var sceneToAct: [Int: Int] = [:]
        let n = scenes.count
        for (i, scene) in scenes.enumerated() {
            let bucket = min(actCount - 1, Int(floor(Double(i) * Double(actCount) / Double(n))))
            sceneToAct[scene] = bucket + 1
        }

        return input.map { entry in
            var out = CharacterPresence(characterName: entry.characterName)
            for (scene, mentions) in entry.chapterPresence {
                guard let act = sceneToAct[scene] else { continue }
                out.chapterPresence[act, default: 0] += mentions
            }
            return out
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let theme = ThemeManager.shared.currentTheme
        theme.pageAround.setFill()
        dirtyRect.fill()
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
        header.lineBreakMode = .byTruncatingTail
        header.maximumNumberOfLines = 1
        legendStack.addArrangedSubview(header)

        for (index, character) in characters.enumerated() {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8

            let swatch = NSView(frame: NSRect(x: 0, y: 0, width: 12, height: 12))
            swatch.wantsLayer = true
            swatch.layer?.cornerRadius = 2
            let swatchColor = (index < colors.count) ? colors[index] : NSColor.systemBlue
            swatch.layer?.backgroundColor = swatchColor.cgColor
            swatch.translatesAutoresizingMaskIntoConstraints = false
            swatch.widthAnchor.constraint(equalToConstant: 12).isActive = true
            swatch.heightAnchor.constraint(equalToConstant: 12).isActive = true

            let label = NSTextField(labelWithString: character)
            label.font = NSFont.systemFont(ofSize: 11)
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

        titleLabel.textColor = textColor
        subtitleLabel.textColor = textColor.withAlphaComponent(0.65)

        for view in legendStack.arrangedSubviews {
            if let label = view as? NSTextField {
                label.textColor = textColor
            } else if let stack = view as? NSStackView {
                for sub in stack.arrangedSubviews {
                    if let label = sub as? NSTextField {
                        label.textColor = textColor
                    }
                }
            }
        }
    }

    private func applyThemeToModeControl() {
        let theme = ThemeManager.shared.currentTheme

        modeControlContainer.wantsLayer = true
        modeControlContainer.layer?.cornerRadius = 6
        modeControlContainer.layer?.borderWidth = 1
        modeControlContainer.layer?.borderColor = theme.pageBorder.cgColor
        modeControlContainer.layer?.backgroundColor = theme.pageBackground.cgColor

        updateModeButtonAppearance()
    }

    private func updateModeButtonAppearance() {
        let theme = ThemeManager.shared.currentTheme

        func styleButton(_ button: NSButton, selected: Bool) {
            button.wantsLayer = true
            button.layer?.cornerRadius = 5
            button.layer?.borderWidth = 0
            button.layer?.backgroundColor = selected ? theme.pageBorder.cgColor : theme.pageBackground.cgColor
            let textColor = selected ? theme.pageBackground : theme.textColor
            let font = button.font ?? NSFont.systemFont(ofSize: 12)
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [
                    .foregroundColor: textColor,
                    .font: font
                ]
            )
        }

        styleButton(scenesButton, selected: xAxisMode == .scenes)
        styleButton(actsButton, selected: xAxisMode == .acts)
    }

    private func generateColors(count: Int) -> [NSColor] {
        guard count > 0 else { return [] }

        let baseHue: CGFloat = 0.58
        let goldenRatio: CGFloat = 0.61803398875
        return (0..<count).map { i in
            let hue = (baseHue + (CGFloat(i) * goldenRatio)).truncatingRemainder(dividingBy: 1)
            return NSColor(calibratedHue: hue, saturation: 0.65, brightness: 0.85, alpha: 0.9)
        }
    }

}
