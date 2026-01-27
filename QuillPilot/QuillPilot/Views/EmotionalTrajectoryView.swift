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

        // Draw background
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        // Define chart area with padding for axes and labels
        let padding: CGFloat = 60
        let chartRect = bounds.insetBy(dx: padding, dy: padding)

        // Draw grid and axes
        drawGrid(in: chartRect)
        drawAxes(in: chartRect)

        // Draw trajectories
        for trajectory in trajectories {
            drawTrajectory(trajectory, in: chartRect, context: context)
        }

        // Draw legend
        drawLegend(in: bounds)
    }

    private func drawEmptyState() {
        let text = "No emotional trajectory data available.\nAnalyze your document to see character emotional arcs."
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.secondaryLabelColor
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
        NSColor.separatorColor.withAlphaComponent(0.3).setStroke()

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
        // Draw axis labels
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor
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
        let xLabel = NSAttributedString(string: "Story Progress →", attributes: labelAttributes)
        xLabel.draw(at: NSPoint(x: chartRect.midX - 60, y: chartRect.minY - 40))

        // X-axis percentage markers
        for i in stride(from: 0, through: 100, by: 20) {
            let x = chartRect.minX + (chartRect.width * CGFloat(i)) / 100 - 10
            let percentLabel = NSAttributedString(string: "\(i)%", attributes: labelAttributes)
            percentLabel.draw(at: NSPoint(x: x, y: chartRect.minY - 25))
        }
    }

    private func drawTrajectory(_ trajectory: CharacterTrajectory, in chartRect: NSRect, context: CGContext?) {
        guard !trajectory.states.isEmpty else { return }

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
            let y = chartRect.minY + chartRect.height * CGFloat(normalizedValue)

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
            let y = chartRect.minY + chartRect.height * CGFloat(normalizedValue)

            let point = NSBezierPath(ovalIn: NSRect(x: x - 3, y: y - 3, width: 6, height: 6))
            trajectory.color.setFill()
            point.fill()

            trajectory.color.darker().setStroke()
            point.lineWidth = 1
            point.stroke()
        }
    }

    private func drawLegend(in bounds: NSRect) {
        // Use two-column layout for legend to save space
        let legendWidth: CGFloat = 400
        let columnWidth: CGFloat = 200
        let legendX: CGFloat = bounds.maxX - legendWidth - 10
        let legendY: CGFloat = bounds.maxY - 40
        let itemsPerColumn = (trajectories.count + 1) / 2

        for (index, trajectory) in trajectories.enumerated() {
            let column = index / itemsPerColumn
            let row = index % itemsPerColumn
            let currentX = legendX + CGFloat(column) * columnWidth
            let currentY = legendY - CGFloat(row) * 18

            // Line sample
            let linePath = NSBezierPath()
            linePath.move(to: NSPoint(x: currentX, y: currentY))
            linePath.line(to: NSPoint(x: currentX + 25, y: currentY))
            trajectory.color.setStroke()
            linePath.lineWidth = 2.5

            if trajectory.isDashed {
                linePath.setLineDash([5, 3], count: 2, phase: 0)
            }

            linePath.stroke()

            // Label - truncate if needed
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.labelColor
            ]

            var labelText = trajectory.characterName
            // Truncate long names
            if labelText.count > 25 {
                let index = labelText.index(labelText.startIndex, offsetBy: 22)
                labelText = String(labelText[..<index]) + "..."
            }
            let label = NSAttributedString(string: labelText, attributes: labelAttributes)
            label.draw(at: NSPoint(x: currentX + 32, y: currentY - 5))
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
