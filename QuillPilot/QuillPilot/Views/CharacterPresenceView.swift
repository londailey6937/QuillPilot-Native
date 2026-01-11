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

            // Layout constants
            let padding: CGFloat = 60
            let topPadding: CGFloat = 70
            let bottomPadding: CGFloat = 110
            let chartWidth = bounds.width - padding * 2
            let chartHeight = bounds.height - topPadding - bottomPadding
            let chartRect = NSRect(x: padding, y: bottomPadding, width: max(1, chartWidth), height: max(1, chartHeight))

            // Find max mentions for scale
            let maxMentions = dataPoints.map { $0.mentions }.max() ?? 1

            // Draw Y axis
            drawYAxis(in: chartRect, maxValue: maxMentions, textColor: textColor)

            // Draw bars
            let barGroupWidth = chartRect.width / CGFloat(max(1, chapters.count))
            let groupInnerPadding = min(10, max(0, barGroupWidth * 0.2))
            let availableGroupWidth = max(1, barGroupWidth - groupInnerPadding)
            let perCharacterWidth = availableGroupWidth / CGFloat(max(1, characters.count))
            let barWidth = max(1, min(32, floor(perCharacterWidth)))

            // If the chart is very dense, suppress tiny per-bar value labels.
            let totalBars = chapters.count * characters.count
            let showValueLabels = (barWidth >= 14) && (totalBars <= 240)

            // Auto-skip scene labels when there are many scenes.
            // Use the visible viewport width rather than the full scrollable width.
            let viewportWidth = max(1, visibleWidth)
            let maxSceneLabels = max(6, min(14, Int(floor(viewportWidth / 70))))
            let sceneLabelStride = max(1, Int(ceil(Double(chapters.count) / Double(maxSceneLabels))))
            let rotateSceneLabels = sceneLabelStride > 1

            for (chapterIndex, chapter) in chapters.enumerated() {
                let totalGroupBarsWidth = CGFloat(characters.count) * barWidth
                let groupX = chartRect.minX + (CGFloat(chapterIndex) * barGroupWidth) + (barGroupWidth - totalGroupBarsWidth) / 2

                for (charIndex, character) in characters.enumerated() {
                    if let dataPoint = dataPoints.first(where: { $0.character == character && $0.chapter == chapter }) {
                        let barHeight = (CGFloat(dataPoint.mentions) / CGFloat(maxMentions)) * chartRect.height
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

                        if showValueLabels, dataPoint.mentions > 0 {
                            let valueStr = "\(dataPoint.mentions)"
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

                // Draw x tick label
                if chapterIndex % sceneLabelStride == 0 || chapterIndex == chapters.count - 1 {
                    let sceneLabel = "\(xTickPrefix) \(chapter)"
                    let labelAttrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 9),
                        .foregroundColor: textColor.withAlphaComponent(0.5)
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
            }

            // Axis labels
            let xAxisLabel = xAxisTitle
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
            if let context = NSGraphicsContext.current?.cgContext {
                context.saveGState()
                context.translateBy(x: chartRect.minX - 55, y: chartRect.midY)
                context.rotate(by: .pi / 2)
                let ySize = yAxisLabel.size(withAttributes: yAxisAttrs)
                yAxisLabel.draw(at: NSPoint(x: -ySize.width / 2, y: -ySize.height / 2), withAttributes: yAxisAttrs)
                context.restoreGState()
            }
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

        private func drawYAxis(in rect: NSRect, maxValue: Int, textColor: NSColor) {
            let axisPath = NSBezierPath()
            axisPath.move(to: NSPoint(x: rect.minX, y: rect.minY))
            axisPath.line(to: NSPoint(x: rect.minX, y: rect.maxY))
            axisPath.move(to: NSPoint(x: rect.minX, y: rect.minY))
            axisPath.line(to: NSPoint(x: rect.maxX, y: rect.minY))

            textColor.withAlphaComponent(0.25).setStroke()
            axisPath.lineWidth = 1
            axisPath.stroke()

            let ticks = 5
            for i in 0...ticks {
                let value = Int(round(Double(maxValue) * Double(i) / Double(ticks)))
                let y = rect.minY + (rect.height * CGFloat(i) / CGFloat(ticks))
                let tickPath = NSBezierPath()
                tickPath.move(to: NSPoint(x: rect.minX - 4, y: y))
                tickPath.line(to: NSPoint(x: rect.minX, y: y))
                tickPath.lineWidth = 1
                tickPath.stroke()

                let label = "\(value)"
                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9),
                    .foregroundColor: textColor.withAlphaComponent(0.6)
                ]
                let labelSize = label.size(withAttributes: labelAttrs)
                label.draw(at: NSPoint(x: rect.minX - 8 - labelSize.width, y: y - labelSize.height / 2), withAttributes: labelAttrs)
            }
        }
    }

    private var presence: [CharacterPresence] = []
    private var rawPresence: [CharacterPresence] = []
    private var xAxisMode: XAxisMode = .scenes

    private let chartScrollView = NSScrollView()
    private let chartView = CharacterPresenceChartView(frame: .zero)
    private var chartContentWidth: CGFloat = 0
    private var desiredChartContentWidth: CGFloat = 0

    // Always-visible horizontal scroll control.
    // macOS can hide overlay scrollbars; using a slider guarantees an on-screen control.
    private let hScrollSlider: NSSlider = {
        let s = NSSlider(value: 0.0, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)
        s.isContinuous = true
        s.controlSize = .small
        s.sliderType = .linear
        return s
    }()
    private var chartClipBoundsObserver: NSObjectProtocol?

    private let modeControl: NSSegmentedControl = {
        let control = NSSegmentedControl(labels: ["Scenes", "Acts"], trackingMode: .selectOne, target: nil, action: nil)
        control.selectedSegment = 0
        control.controlSize = .small
        return control
    }()

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
        setupHorizontalSlider()
        startObservingTheme()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupChartViews()
        setupLegendViews()
        setupModeControl()
        setupHorizontalSlider()
        startObservingTheme()
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
        if let chartClipBoundsObserver {
            NotificationCenter.default.removeObserver(chartClipBoundsObserver)
        }
    }

    private func setupChartViews() {
        chartScrollView.documentView = chartView
        chartScrollView.hasHorizontalScroller = false
        chartScrollView.hasVerticalScroller = false
        chartScrollView.drawsBackground = true
        chartScrollView.backgroundColor = ThemeManager.shared.currentTheme.pageAround
        chartScrollView.borderType = .noBorder

        chartScrollView.contentView.postsBoundsChangedNotifications = true

        chartView.wantsLayer = true
        addSubview(chartScrollView)
    }

    private func setupHorizontalSlider() {
        hScrollSlider.target = self
        hScrollSlider.action = #selector(hScrollSliderChanged)
        addSubview(hScrollSlider)

        chartClipBoundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: chartScrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            self?.updateHorizontalSlider()
        }
    }

    private func setupModeControl() {
        modeControl.target = self
        modeControl.action = #selector(xAxisModeChanged)
        addSubview(modeControl)
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
        let padding: CGFloat = 60
        return padding * 2 + CGFloat(max(1, chaptersCount)) * groupWidth
    }

    override func layout() {
        super.layout()

        let topPadding: CGFloat = 70
        let bottomPadding: CGFloat = 100

        let chartHeight = bounds.height - topPadding - bottomPadding
        let legendX = bounds.width - legendWidth - 10
        legendScrollView.frame = NSRect(x: legendX, y: bottomPadding, width: legendWidth, height: chartHeight)

        let scrollerHeight: CGFloat = 18

        // Chart area takes the remaining space on the left.
        let chartAreaWidth = max(1, legendX - 10)
        chartScrollView.frame = NSRect(x: 0, y: scrollerHeight, width: chartAreaWidth, height: bounds.height - scrollerHeight)

        hScrollSlider.frame = NSRect(x: 10, y: 0, width: max(1, chartAreaWidth - 20), height: scrollerHeight)

        // Keep the chart view tall; width can exceed the visible area for scrolling.
        if chartContentWidth <= 0 { chartContentWidth = chartAreaWidth }
        if desiredChartContentWidth > 0 {
            chartContentWidth = max(chartAreaWidth, desiredChartContentWidth)
        }
        chartView.frame = NSRect(x: 0, y: 0, width: chartContentWidth, height: bounds.height - scrollerHeight)
        chartView.visibleWidth = chartScrollView.contentView.bounds.width

        modeControl.sizeToFit()
        modeControl.frame = NSRect(
            x: 20,
            y: bounds.height - 44,
            width: modeControl.frame.width,
            height: modeControl.frame.height
        )

        // Size stack for scroll.
        legendStack.frame = NSRect(x: 0, y: 0, width: legendWidth, height: legendStack.fittingSize.height)

        updateHorizontalSlider()
    }

    private func updateHorizontalSlider() {
        let viewportWidth = max(1, chartScrollView.contentView.bounds.width)
        let contentWidth = max(viewportWidth, chartView.bounds.width)
        let maxOffset = max(0, contentWidth - viewportWidth)

        hScrollSlider.isHidden = false
        hScrollSlider.isEnabled = (maxOffset > 0.5)

        let currentX = chartScrollView.contentView.bounds.origin.x
        hScrollSlider.doubleValue = (maxOffset > 0.5) ? Double(currentX / maxOffset) : 0.0
    }

    @objc private func hScrollSliderChanged() {
        let viewportWidth = max(1, chartScrollView.contentView.bounds.width)
        let contentWidth = max(viewportWidth, chartView.bounds.width)
        let maxOffset = max(0, contentWidth - viewportWidth)
        guard maxOffset > 0 else { return }

        let newX = CGFloat(hScrollSlider.doubleValue) * maxOffset
        chartScrollView.contentView.scroll(to: NSPoint(x: newX, y: 0))
        chartScrollView.reflectScrolledClipView(chartScrollView.contentView)
    }

    func setPresence(_ presence: [CharacterPresence]) {
        rawPresence = presence
        applyXAxisMode()
    }

    @objc private func xAxisModeChanged() {
        xAxisMode = XAxisMode(rawValue: modeControl.selectedSegment) ?? .scenes
        applyXAxisMode()
    }

    private func applyXAxisMode() {
        presence = (xAxisMode == .acts) ? aggregatePresenceToActs(rawPresence) : rawPresence

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

        if xAxisMode == .acts {
            chartView.xAxisTitle = "Act"
            chartView.xTickPrefix = "Act"
        } else {
            chartView.xAxisTitle = "Scene"
            chartView.xTickPrefix = "Sc"
        }

        desiredChartContentWidth = computeDesiredChartWidth(chaptersCount: chapters.count, charactersCount: characters.count)
        chartContentWidth = max(bounds.width - legendWidth - 20, desiredChartContentWidth)

        rebuildLegend(characters: characters, colors: colors)
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
        let backgroundColor = theme.pageAround
        let textColor = theme.textColor

        backgroundColor.setFill()
        dirtyRect.fill()

        // Draw title/subtitle (fixed; chart scrolls independently)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: textColor
        ]
        let title: String = (xAxisMode == .acts)
            ? "Character Presence by Act"
            : "Character Presence by Scene"
        let titleSize = title.size(withAttributes: titleAttributes)
        title.draw(at: NSPoint(x: (bounds.width - titleSize.width) / 2, y: bounds.height - 40), withAttributes: titleAttributes)

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]
        let subtitle: String = (xAxisMode == .acts)
            ? "Number of mentions per character per act"
            : "Number of mentions per character per scene"
        let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
        subtitle.draw(at: NSPoint(x: (bounds.width - subtitleSize.width) / 2, y: bounds.height - 58), withAttributes: subtitleAttributes)
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
