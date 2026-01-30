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
    private var chartHostingView: NSView?
    weak var delegate: PlotVisualizationDelegate?

    func configure(with analysis: PlotAnalysis?, wrapInScrollView: Bool = true) {
        self.plotAnalysis = analysis
        self.wrapInScrollView = wrapInScrollView
        setupChartView()
    }

    private func setupChartView() {
        // Remove old chart if exists
        chartHostingView?.removeFromSuperview()

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

        chartHostingView = hostingView
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

    // Use standard 0-1 domain to show full chart without clipping
    private var yDomain: ClosedRange<Double> {
        return 0...1
    }

    // Header text colors: use ThemeManager to detect actual app theme
    // (This affects everything above and including "Story Beats" heading)
    private var primaryTextColor: Color {
        Color(nsColor: ThemeManager.shared.currentTheme.popoutTextColor)
    }
    private var secondaryTextColor: Color {
        Color(nsColor: ThemeManager.shared.currentTheme.popoutSecondaryColor)
    }

    private var cardBackgroundColor: Color {
        // Slightly different from popoutBackground so cards read as distinct surfaces.
        Color(nsColor: ThemeManager.shared.currentTheme.pageBackground)
    }

    private var cardBorderColor: Color {
        Color(nsColor: ThemeManager.shared.currentTheme.pageBorder).opacity(0.25)
    }

    private var formatColor: Color {
        // Avoid non-theme blues/purples; keep chart styling aligned with current app theme.
        plotAnalysis.documentFormat == .screenplay
            ? Color(nsColor: ThemeManager.shared.currentTheme.pageBorder)
            : Color(nsColor: ThemeManager.shared.currentTheme.popoutSecondaryColor)
    }

    private var accentTextColor: Color {
        Color(nsColor: ThemeManager.shared.currentTheme.pageBorder)
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
        // Center the analysis content in popouts/dialogs while keeping the inner layout leading-aligned.
        VStack(alignment: .center, spacing: 0) {
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
                                .foregroundColor(Color(nsColor: .systemOrange))
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
            .frame(maxWidth: 900)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
        .background(cardBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardBorderColor, lineWidth: 1)
        )
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

            Text("Scores: 70-100% = Strong, 40-69% = Adequate, Below 40% = Needs Work")
                .font(.caption2)
                .foregroundColor(secondaryTextColor.opacity(0.8))
                .italic()
                .font(.caption)
                .foregroundColor(secondaryTextColor)
                .padding(.top, 4)

            Text("Scores: 70-100% = Strong, 40-69% = Adequate, Below 40% = Needs Work")
                .font(.caption2)
                .foregroundColor(secondaryTextColor.opacity(0.8))
                .italic()

            Text("Scores: 70-100% = Strong, 40-69% = Adequate, Below 40% = Needs Work")
                .font(.caption2)
                .foregroundColor(secondaryTextColor.opacity(0.8))
                .italic()
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

            Text("Scores: 70-100% = Strong, 40-69% = Adequate, Below 40% = Needs Work")
                .font(.caption2)
                .foregroundColor(secondaryTextColor.opacity(0.8))
                .italic()
        }
    }

    // MARK: - Structural Issues View

    /// Calculate page range string from story position (0.0-1.0) range.
    private func pageRangeString(start: Double, end: Double) -> String {
        let totalPages = max(1, plotAnalysis.pageCount)
        let startPage = max(1, Int(ceil(start * Double(totalPages))))
        let endPage = max(startPage, Int(ceil(end * Double(totalPages))))

        // For whole-story issues, show "Entire document".
        if start <= 0.01 && end >= 0.99 {
            return "Entire document"
        }

        if startPage == endPage {
            return "Page \(startPage)"
        } else {
            return "Pages \(startPage)–\(endPage)"
        }
    }

    @ViewBuilder
    private var structuralIssuesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("⚠️ Structural Issues")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(primaryTextColor)

            ForEach(Array(plotAnalysis.structuralIssues.enumerated()), id: \.offset) { _, issue in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(severityIcon(issue.severity))
                        Text(issue.category.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(primaryTextColor)
                        Spacer()
                        Text(pageRangeString(start: issue.affectedRange.start, end: issue.affectedRange.end))
                            .font(.caption2)
                            .foregroundColor(secondaryTextColor.opacity(0.8))
                    }

                    Text(issue.description)
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)

                    Text("💡 \(issue.suggestion)")
                        .font(.caption2)
                        .foregroundColor(accentTextColor)
                        .italic()
                }
                .padding(8)
                .background(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(severityColor(issue.severity).opacity(0.35), lineWidth: 1)
                )
                .cornerRadius(6)
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .cornerRadius(8)
    }

    // MARK: - Missing Points View

    @ViewBuilder
    private var missingPointsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("📋 Potentially Missing Story Beats:")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(primaryTextColor)

            ForEach(plotAnalysis.missingPoints, id: \.self) { pointType in
                Text("• \(pointType)")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardBorderColor, lineWidth: 1)
        )
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
              .frame(height: 500)
              .padding(.top, 20)
              .padding(.bottom, 20)
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
                .foregroundColor(Color(nsColor: ThemeManager.shared.currentTheme.popoutSecondaryColor))
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

    private var primaryTextColor: Color {
        Color(nsColor: ThemeManager.shared.currentTheme.popoutTextColor)
    }
    private var secondaryTextColor: Color {
        Color(nsColor: ThemeManager.shared.currentTheme.popoutSecondaryColor)
    }
    private var rowBackgroundColor: Color {
        Color(nsColor: ThemeManager.shared.currentTheme.pageBackground)
    }
    private var rowBorderColor: Color {
        Color(nsColor: ThemeManager.shared.currentTheme.pageBorder).opacity(0.25)
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
                        // Rows have a dark background; use light text for readability.
                        .foregroundColor(secondaryTextColor)
                        .italic()

                    if let improvement = plotPoint.suggestedImprovement {
                        Text("⚠️ \(improvement)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                Image(systemName: "arrow.right.circle")
                    .foregroundColor(Color(nsColor: ThemeManager.shared.currentTheme.pageBorder))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(rowBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(rowBorderColor, lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
