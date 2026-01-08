//
//  EmotionalTrajectoryView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class EmotionalTrajectoryView: NSView {

    struct EmotionalState {
        let position: Double // 0.0 to 1.0 (percentage through document)
        let confidence: Double // -1.0 to 1.0
        let hope: Double // -1.0 (despair) to 1.0 (hope)
        let control: Double // -1.0 (chaos) to 1.0 (control)
        let attachment: Double // -1.0 (isolation) to 1.0 (attachment)
    }

    struct CharacterTrajectory {
        let characterName: String
        let color: NSColor
        let states: [EmotionalState]
        let isDashed: Bool // For subtext vs surface behavior
    }

    private var trajectories: [CharacterTrajectory] = []
    private var selectedMetric: EmotionalMetric = .confidence
    private var showOverlay: Bool = false

    enum EmotionalMetric: String, CaseIterable {
        case confidence = "Confidence"
        case hope = "Hope vs Despair"
        case control = "Control vs Chaos"
        case attachment = "Attachment vs Isolation"

        var range: (min: String, max: String) {
            switch self {
            case .confidence: return ("Low", "High")
            case .hope: return ("Despair", "Hope")
            case .control: return ("Chaos", "Control")
            case .attachment: return ("Isolation", "Attachment")
            }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupThemeObserver()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupThemeObserver()
    }

    private func setupThemeObserver() {
        NotificationCenter.default.addObserver(forName: .themeDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.needsDisplay = true
        }
    }

    func setTrajectories(_ trajectories: [CharacterTrajectory], metric: EmotionalMetric = .confidence) {
        self.trajectories = trajectories
        self.selectedMetric = metric
        self.needsDisplay = true
    }

    func setMetric(_ metric: EmotionalMetric) {
        self.selectedMetric = metric
        self.needsDisplay = true
    }

    func toggleOverlay(_ enabled: Bool) {
        self.showOverlay = enabled
        self.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !trajectories.isEmpty else {
            drawEmptyState()
            return
        }

        let context = NSGraphicsContext.current?.cgContext

        // Draw background using theme colors
        let theme = ThemeManager.shared.currentTheme
        theme.popoutBackground.setFill()
        bounds.fill()

        // Define chart area with padding for axes and labels
        let padding: CGFloat = 60
        let chartRect = bounds.insetBy(dx: padding, dy: padding)

        // Draw grid and axes
        drawGrid(in: chartRect)
        drawAxes(in: chartRect)

        // Draw trajectories
        for (index, trajectory) in trajectories.enumerated() {
            drawTrajectory(trajectory, in: chartRect, context: context, index: index, total: trajectories.count)
        }

        // Draw legend
        drawLegend(in: bounds)
    }

    private func drawEmptyState() {
        let theme = ThemeManager.shared.currentTheme
        theme.popoutBackground.setFill()
        bounds.fill()

        let text = "No emotional trajectory data available.\nAnalyze your document to see character emotional arcs."
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: theme.popoutSecondaryColor
        ]

        let attrString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attrString.size()
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )

        attrString.draw(in: textRect)
    }

    private func drawGrid(in chartRect: NSRect) {
        let theme = ThemeManager.shared.currentTheme
        theme.popoutSecondaryColor.withAlphaComponent(0.3).setStroke()

        let gridPath = NSBezierPath()
        gridPath.lineWidth = 0.5

        // Horizontal grid lines (5 lines for -1, -0.5, 0, 0.5, 1)
        for i in 0...4 {
            let y = chartRect.minY + (chartRect.height / 4) * CGFloat(i)
            gridPath.move(to: NSPoint(x: chartRect.minX, y: y))
            gridPath.line(to: NSPoint(x: chartRect.maxX, y: y))
        }

        // Vertical grid lines (10 lines for 0%, 10%, 20%...100%)
        for i in 0...10 {
            let x = chartRect.minX + (chartRect.width / 10) * CGFloat(i)
            gridPath.move(to: NSPoint(x: x, y: chartRect.minY))
            gridPath.line(to: NSPoint(x: x, y: chartRect.maxY))
        }

        gridPath.stroke()
    }

    private func drawAxes(in chartRect: NSRect) {
        // Draw axis labels using theme colors
        let theme = ThemeManager.shared.currentTheme
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: theme.popoutTextColor
        ]

        // Y-axis labels
        let range = selectedMetric.range
        let yLabels = [range.max, "", "Neutral", "", range.min]
        for (i, label) in yLabels.enumerated() {
            let y = chartRect.maxY - (chartRect.height / 4) * CGFloat(i) - 6
            let labelString = NSAttributedString(string: label, attributes: labelAttributes)
            labelString.draw(at: NSPoint(x: chartRect.minX - 55, y: y))
        }

        // X-axis label
        let xLabel = NSAttributedString(string: "Document Progress →", attributes: labelAttributes)
        xLabel.draw(at: NSPoint(x: chartRect.midX - 60, y: chartRect.minY - 40))

        // X-axis percentage markers
        for i in stride(from: 0, through: 100, by: 20) {
            let x = chartRect.minX + (chartRect.width * CGFloat(i)) / 100 - 10
            let percentLabel = NSAttributedString(string: "\(i)%", attributes: labelAttributes)
            percentLabel.draw(at: NSPoint(x: x, y: chartRect.minY - 25))
        }
    }

    private func drawTrajectory(_ trajectory: CharacterTrajectory, in chartRect: NSRect, context: CGContext?, index: Int, total: Int) {
        guard !trajectory.states.isEmpty else { return }

        let spacingStep: CGFloat = 6.0
        let spacingOffset = (CGFloat(index) - CGFloat(total - 1) / 2.0) * spacingStep

        let path = NSBezierPath()

        // Get the appropriate value for the selected metric
        func getValue(from state: EmotionalState) -> Double {
            switch selectedMetric {
            case .confidence: return state.confidence
            case .hope: return state.hope
            case .control: return state.control
            case .attachment: return state.attachment
            }
        }

        // Plot points
        var isFirst = true
        for state in trajectory.states {
            let x = chartRect.minX + chartRect.width * CGFloat(state.position)
            // Map value from [-1, 1] to chart coordinates
            let normalizedValue = (getValue(from: state) + 1.0) / 2.0 // Convert to [0, 1]
            let baseY = chartRect.minY + chartRect.height * CGFloat(normalizedValue)
            let y = max(chartRect.minY, min(chartRect.maxY, baseY + spacingOffset))

            if isFirst {
                path.move(to: NSPoint(x: x, y: y))
                isFirst = false
            } else {
                path.line(to: NSPoint(x: x, y: y))
            }
        }

        // Apply line style
        trajectory.color.setStroke()
        path.lineWidth = 2.5

        if trajectory.isDashed {
            path.setLineDash([5, 3], count: 2, phase: 0)
        }

        // Smooth the curve
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        path.stroke()

        // Draw data points
        for state in trajectory.states {
            let x = chartRect.minX + chartRect.width * CGFloat(state.position)
            let normalizedValue = (getValue(from: state) + 1.0) / 2.0
            let baseY = chartRect.minY + chartRect.height * CGFloat(normalizedValue)
            let y = max(chartRect.minY, min(chartRect.maxY, baseY + spacingOffset))

            let point = NSBezierPath(ovalIn: NSRect(x: x - 3, y: y - 3, width: 6, height: 6))
            trajectory.color.setFill()
            point.fill()

            trajectory.color.darker().setStroke()
            point.lineWidth = 1
            point.stroke()
        }
    }

    private func drawLegend(in bounds: NSRect) {
        let theme = ThemeManager.shared.currentTheme

        // List each character once (color), and provide a line-style key for surface vs subtext
        let baseTrajectories = trajectories.filter { !$0.isDashed }

        // Use two-column layout for legend to save space
        let legendWidth: CGFloat = 400
        let columnWidth: CGFloat = 200
        let legendX: CGFloat = bounds.maxX - legendWidth - 10
        let legendTopY: CGFloat = bounds.maxY - 24

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: theme.popoutTextColor
        ]

        // Line-style key
        do {
            let keyX = legendX
            let keyY = legendTopY

            let solid = NSBezierPath()
            solid.move(to: NSPoint(x: keyX, y: keyY))
            solid.line(to: NSPoint(x: keyX + 22, y: keyY))
            theme.popoutTextColor.setStroke()
            solid.lineWidth = 2.5
            solid.stroke()
            NSAttributedString(string: "Surface", attributes: labelAttributes)
                .draw(at: NSPoint(x: keyX + 28, y: keyY - 5))

            let dashedY = keyY - 14
            let dashed = NSBezierPath()
            dashed.move(to: NSPoint(x: keyX, y: dashedY))
            dashed.line(to: NSPoint(x: keyX + 22, y: dashedY))
            theme.popoutTextColor.setStroke()
            dashed.lineWidth = 2.5
            dashed.setLineDash([5, 3], count: 2, phase: 0)
            dashed.stroke()
            NSAttributedString(string: "Subtext", attributes: labelAttributes)
                .draw(at: NSPoint(x: keyX + 28, y: dashedY - 5))
        }

        let listStartY = legendTopY - 34
        let itemsPerColumn = (baseTrajectories.count + 1) / 2

        for (index, trajectory) in baseTrajectories.enumerated() {
            let column = index / itemsPerColumn
            let row = index % itemsPerColumn
            let currentX = legendX + CGFloat(column) * columnWidth
            let currentY = listStartY - CGFloat(row) * 18

            // Color sample
            let linePath = NSBezierPath()
            linePath.move(to: NSPoint(x: currentX, y: currentY))
            linePath.line(to: NSPoint(x: currentX + 25, y: currentY))
            trajectory.color.setStroke()
            linePath.lineWidth = 2.5
            linePath.stroke()

            // Label - truncate if needed
            var labelText = trajectory.characterName
            if labelText.count > 25 {
                let cut = labelText.index(labelText.startIndex, offsetBy: 22)
                labelText = String(labelText[..<cut]) + "..."
            }
            NSAttributedString(string: labelText, attributes: labelAttributes)
                .draw(at: NSPoint(x: currentX + 32, y: currentY - 5))
        }
    }
}

// Helper extension
extension NSColor {
    func darker() -> NSColor {
        // Convert to RGB colorspace first to handle system colors
        guard let rgbColor = self.usingColorSpace(.deviceRGB) else {
            return self
        }

        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgbColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: h, saturation: s, brightness: max(b - 0.2, 0), alpha: a)
    }
}
