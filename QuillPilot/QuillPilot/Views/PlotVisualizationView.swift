//
//  PlotVisualizationView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa
import Charts

@available(macOS 13.0, *)
class PlotVisualizationView: NSView {

    private var plotAnalysis: PlotAnalysis?
    private var wrapInScrollView: Bool = true
    private var chartView: NSHostingView<PlotTensionChart>?
    weak var delegate: PlotVisualizationDelegate?

    func configure(with analysis: PlotAnalysis?, wrapInScrollView: Bool = true) {
        self.plotAnalysis = analysis
        self.wrapInScrollView = wrapInScrollView
        setupChartView()
    }

    private func setupChartView() {
        // Remove old chart if exists
        chartView?.removeFromSuperview()

        guard let analysis = plotAnalysis else { return }

        let chart = PlotTensionChart(
            plotAnalysis: analysis,
            onPointTap: { [weak self] wordPosition in
                self?.delegate?.didTapPlotPoint(at: wordPosition)
            },
            onPopout: { [weak self] in
                guard let self else { return }
                self.delegate?.openPlotPopout(analysis)
            },
            wrapInScrollView: wrapInScrollView
        )

        let hostingView = NSHostingView(rootView: chart)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        chartView = hostingView
    }
}

protocol PlotVisualizationDelegate: AnyObject {
    func didTapPlotPoint(at wordPosition: Int)
    func openPlotPopout(_ analysis: PlotAnalysis)
}

// MARK: - SwiftUI Chart

import SwiftUI

@available(macOS 13.0, *)
struct PlotTensionChart: View {
    let plotAnalysis: PlotAnalysis
    let onPointTap: (Int) -> Void
    let onPopout: () -> Void
    var wrapInScrollView: Bool = true

    // Tighten the visible range so low-variance novels don’t hug the bottom of the chart
    private var yDomain: ClosedRange<Double> {
        let curveValues = plotAnalysis.overallTensionCurve.map { $0.tensionLevel }
        let pointValues = plotAnalysis.plotPoints.map { $0.tensionLevel }
        let combined = curveValues + pointValues
        guard let minVal = combined.min(), let maxVal = combined.max() else { return 0...1 }

        // Cap the upper range to leave readable space for labels/annotations (screenplays allow slightly higher peaks)
        let upperCap: Double = plotAnalysis.documentFormat == .screenplay ? 0.86 : 0.78

        var lower = max(0.0, minVal - 0.05)
        var upper = min(upperCap, maxVal + 0.08)

        // Enforce a minimum span so flat curves don’t collapse; then re-clamp to the cap
        let minSpan: Double = 0.35
        if upper - lower < minSpan {
            upper = min(upperCap, lower + minSpan)
            lower = max(0.0, upper - minSpan)
        }

        // Guard against degenerate ranges if data is extremely low
        if lower >= upper {
            lower = max(0.0, upper - minSpan)
        }

        return lower...upper
    }

    // Theme-aware colors
    private var primaryTextColor: Color {
        Color(nsColor: NSColor(calibratedWhite: 0.9, alpha: 1.0))
    }
    private var secondaryTextColor: Color {
        Color(nsColor: NSColor(calibratedWhite: 0.7, alpha: 1.0))
    }

    private var formatColor: Color {
        plotAnalysis.documentFormat == .screenplay ? .purple : .blue
    }

    private var formatIcon: String {
        plotAnalysis.documentFormat == .screenplay ? "🎬" : "📖"
    }

    var body: some View {
        Group {
            if wrapInScrollView {
                ScrollView {
                    content
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
                // Header with format indicator
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(formatIcon)
                                .font(.title2)
                            Text("\(plotAnalysis.documentFormat.rawValue) Structure Analysis")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(primaryTextColor)
                        }

                        Text(plotAnalysis.documentFormat.description)
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                            .lineLimit(2)

                        if plotAnalysis.formatConfidence < 0.7 {
                            Text("⚠️ Format detection confidence: \(Int(plotAnalysis.formatConfidence * 100))%")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Structure Score
                if plotAnalysis.structureScore > 0 {
                    HStack {
                        Text("Structure Score:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(primaryTextColor)
                        Text("\(plotAnalysis.structureScore)%")
                            .font(.subheadline)
                            .foregroundColor(scoreColor(plotAnalysis.structureScore))
                    }
                    .padding(.horizontal)
                }

                // Format-specific metrics
                formatSpecificMetricsView
                    .padding(.horizontal)

                // Structural issues
                if !plotAnalysis.structuralIssues.isEmpty {
                    structuralIssuesView
                        .padding(.horizontal)
                }

                // Missing plot points warning
                if !plotAnalysis.missingPoints.isEmpty {
                    missingPointsView
                        .padding(.horizontal)
                }

                // Tension curve chart
                if !plotAnalysis.overallTensionCurve.isEmpty {
                    tensionChartView
                } else {
                    noDataView
                }

                // Plot points list
                if !plotAnalysis.plotPoints.isEmpty {
                    plotPointsListView
                }
        }
        .padding(.vertical)
    }

    // MARK: - Format-Specific Metrics

    @ViewBuilder
    private var formatSpecificMetricsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch plotAnalysis.documentFormat {
            case .novel:
                novelMetricsView
            case .screenplay:
                screenplayMetricsView
            }
        }
        .padding()
        .background(formatColor.opacity(0.1))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var novelMetricsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("📖 Novel Metrics")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(primaryTextColor)

            HStack(spacing: 16) {
                MetricBadge(
                    title: "Internal Change",
                    value: plotAnalysis.internalChangeScore,
                    icon: "🧠",
                    tooltip: "How well belief systems and internal shifts are tracked"
                )
                MetricBadge(
                    title: "Thematic Resonance",
                    value: plotAnalysis.thematicResonance,
                    icon: "🎭",
                    tooltip: "How well themes echo through the structure"
                )
                MetricBadge(
                    title: "Narrative Momentum",
                    value: plotAnalysis.narrativeMomentum,
                    icon: "📈",
                    tooltip: "Reader engagement across long spans"
                )
            }

            Text("Novel structure is architectural: analyze load-bearing ideas, flow of meaning, reader experience over time.")
                .font(.caption)
                .foregroundColor(secondaryTextColor)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var screenplayMetricsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🎬 Screenplay Metrics")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(primaryTextColor)

            HStack(spacing: 16) {
                MetricBadge(
                    title: "Visual Causality",
                    value: plotAnalysis.visualCausalityScore,
                    icon: "👁️",
                    tooltip: "How well cause-effect chains are visible"
                )
                MetricBadge(
                    title: "Scene Efficiency",
                    value: plotAnalysis.sceneEfficiency,
                    icon: "✂️",
                    tooltip: "Would cutting scenes break causality?"
                )
                MetricBadge(
                    title: "Pacing",
                    value: plotAnalysis.pacingScore,
                    icon: "⏱️",
                    tooltip: "Minute-by-minute tension management"
                )
            }

            if plotAnalysis.estimatedRuntime > 0 {
                Text("⏱️ Estimated runtime: ~\(plotAnalysis.estimatedRuntime) minutes")
                    .font(.caption)
                    .foregroundColor(plotAnalysis.estimatedRuntime >= 85 && plotAnalysis.estimatedRuntime <= 130 ? .green : .orange)
                    .padding(.top, 2)
            }

            Text("Screenplay structure is mechanical: analyze moving parts, timing, visible cause-and-effect.")
                .font(.caption)
                .foregroundColor(secondaryTextColor)
                .padding(.top, 4)
        }
    }

    // MARK: - Structural Issues View

    @ViewBuilder
    private var structuralIssuesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("⚠️ Structural Issues")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)

            ForEach(Array(plotAnalysis.structuralIssues.enumerated()), id: \.offset) { _, issue in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(severityIcon(issue.severity))
                        Text(issue.category.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(severityColor(issue.severity))
                    }

                    Text(issue.description)
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)

                    Text("💡 \(issue.suggestion)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .italic()
                }
                .padding(8)
                .background(severityColor(issue.severity).opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Missing Points View

    @ViewBuilder
    private var missingPointsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("📋 Potentially Missing Story Beats:")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)

            ForEach(plotAnalysis.missingPoints, id: \.self) { pointType in
                Text("• \(pointType)")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Tension Chart View

    @ViewBuilder
    private var tensionChartView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tension Arc")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(primaryTextColor)
                .padding(.horizontal)

            Chart {
                // Tension line
                ForEach(Array(plotAnalysis.overallTensionCurve.enumerated()), id: \.offset) { index, point in
                    LineMark(
                        x: .value("Position", point.position),
                        y: .value("Tension", point.tensionLevel)
                    )
                    .foregroundStyle(formatColor.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    AreaMark(
                        x: .value("Position", point.position),
                        y: .value("Tension", point.tensionLevel)
                    )
                    .foregroundStyle(formatColor.opacity(0.1).gradient)
                }

                // Plot point markers
                ForEach(Array(plotAnalysis.plotPoints.enumerated()), id: \.offset) { index, plotPoint in
                    PointMark(
                        x: .value("Position", plotPoint.percentagePosition),
                        y: .value("Tension", plotPoint.tensionLevel)
                    )
                    .foregroundStyle(Color.red)
                    .symbol(.circle)
                    .symbolSize(120)

                    // Add annotation
                    .annotation(position: .top, alignment: .center) {
                        VStack(spacing: 2) {
                            Text(plotPoint.emoji)
                                .font(.caption)
                            Text(plotPoint.type)
                                .font(.system(size: 8))
                                .foregroundColor(secondaryTextColor)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 70)
                    }
                }
            }
            .chartXScale(domain: 0...1)
              .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(plotAnalysis.documentFormat == .screenplay
                                 ? "p\(Int(doubleValue * 120))"  // Page numbers for screenplays
                                 : "\(Int(doubleValue * 100))%")
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text("\(Int(doubleValue * 100))%")
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }
            }
            .chartXAxisLabel(plotAnalysis.documentFormat == .screenplay ? "Page" : "Story Progress", alignment: .center)
            .chartYAxisLabel("Tension Level", position: .leading)
              .frame(height: plotAnalysis.documentFormat == .screenplay ? 1000 : 880)
              .padding(.top, 60) // extra headroom so peaks don’t crowd text
              .padding(.bottom, plotAnalysis.documentFormat == .screenplay ? 32 : 24)
              .padding(.horizontal)
        }
          .padding(.bottom, 24)
    }

    // MARK: - No Data View

    @ViewBuilder
    private var noDataView: some View {
        VStack(spacing: 12) {
            Text("📊 No Plot Data Available")
                .font(.headline)
                .foregroundColor(secondaryTextColor)
            Text("Write more content to see your story's tension arc and plot structure analysis.")
                .font(.subheadline)
                .foregroundColor(secondaryTextColor)
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Plot Points List

    @ViewBuilder
    private var plotPointsListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Story Beats")
                .font(.headline)
                .foregroundColor(primaryTextColor)
                .padding(.horizontal)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(plotAnalysis.plotPoints.enumerated()), id: \.offset) { index, plotPoint in
                        PlotPointRow(
                            plotPoint: plotPoint,
                            format: plotAnalysis.documentFormat,
                            onTap: {
                                onPointTap(plotPoint.wordPosition)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Helper Functions

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    private func severityIcon(_ severity: StructuralIssue.IssueSeverity) -> String {
        switch severity {
        case .minor: return "⚪️"
        case .moderate: return "🟡"
        case .major: return "🔴"
        }
    }

    private func severityColor(_ severity: StructuralIssue.IssueSeverity) -> Color {
        switch severity {
        case .minor: return .gray
        case .moderate: return .orange
        case .major: return .red
        }
    }
}

// MARK: - Supporting Views

@available(macOS 13.0, *)
struct MetricBadge: View {
    let title: String
    let value: Int
    let icon: String
    let tooltip: String

    private var valueColor: Color {
        switch value {
        case 70...100: return .green
        case 40..<70: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.title3)
            Text("\(value)%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(valueColor)
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(minWidth: 70)
        .help(tooltip)
    }
}

@available(macOS 13.0, *)
struct PlotPointRow: View {
    let plotPoint: PlotPoint
    let format: DocumentFormat
    let onTap: () -> Void

    // Theme-aware colors
    private var primaryTextColor: Color {
        Color(nsColor: NSColor(calibratedWhite: 0.9, alpha: 1.0))
    }
    private var secondaryTextColor: Color {
        Color(nsColor: NSColor(calibratedWhite: 0.65, alpha: 1.0))
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(plotPoint.emoji)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(plotPoint.type)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(primaryTextColor)

                    // Format-specific position display
                    if format == .screenplay {
                        Text("Page ~\(Int(plotPoint.percentagePosition * 120)) • Tension: \(Int(plotPoint.tensionLevel * 100))%")
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                    } else {
                        Text("At \(Int(plotPoint.percentagePosition * 100))% • Tension: \(Int(plotPoint.tensionLevel * 100))%")
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                    }

                    // Analysis question
                    Text(plotPoint.analysisQuestion)
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .italic()

                    if let improvement = plotPoint.suggestedImprovement {
                        Text("⚠️ \(improvement)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.accentColor)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(nsColor: NSColor(calibratedWhite: 0.25, alpha: 1.0)))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
