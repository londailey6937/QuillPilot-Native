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
    private var chartView: NSHostingView<PlotTensionChart>?
    weak var delegate: PlotVisualizationDelegate?

    func configure(with analysis: PlotAnalysis?) {
        self.plotAnalysis = analysis
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
            }
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

    // Theme-aware colors
    private var primaryTextColor: Color {
        Color(nsColor: NSColor(calibratedWhite: 0.9, alpha: 1.0))
    }
    private var secondaryTextColor: Color {
        Color(nsColor: NSColor(calibratedWhite: 0.7, alpha: 1.0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with popout
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Story Tension Arc")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(primaryTextColor)

                    Text("Tap plot points to jump to location in editor")
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Structure Score
            if plotAnalysis.structureScore > 0 {
                HStack {
                    Text("Story Structure Score:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(primaryTextColor)
                    Text("\(plotAnalysis.structureScore)%")
                        .font(.subheadline)
                        .foregroundColor(scoreColor(plotAnalysis.structureScore))
                }
                .padding(.horizontal)
            }

            // Missing plot points warning
            if !plotAnalysis.missingPoints.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("⚠️ Potentially Missing Story Beats:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)

                    ForEach(plotAnalysis.missingPoints, id: \.self) { pointType in
                        Text("• \(pointType.rawValue)")
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            // Tension curve chart
            if !plotAnalysis.overallTensionCurve.isEmpty {
                Chart {
                    // Tension line
                    ForEach(Array(plotAnalysis.overallTensionCurve.enumerated()), id: \.offset) { index, point in
                        LineMark(
                            x: .value("Position", point.position),
                            y: .value("Tension", point.tensionLevel)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 3))

                        AreaMark(
                            x: .value("Position", point.position),
                            y: .value("Tension", point.tensionLevel)
                        )
                        .foregroundStyle(Color.blue.opacity(0.1).gradient)
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
                                Text(plotPoint.type.emoji)
                                    .font(.caption)
                                Text(plotPoint.type.rawValue)
                                    .font(.system(size: 9))
                                    .foregroundColor(secondaryTextColor)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 70)
                        }
                    }
                }
                .chartXScale(domain: 0...1)
                .chartYScale(domain: 0...1)
                .chartXAxis {
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
                .chartXAxisLabel("Story Progress", alignment: .center)
                .chartYAxisLabel("Tension Level", position: .leading)
                .frame(height: 300)
                .padding()
            } else {
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

            // Plot points list
            if !plotAnalysis.plotPoints.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Story Beats")
                        .font(.headline)
                        .foregroundColor(primaryTextColor)
                        .padding(.horizontal)

                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(Array(plotAnalysis.plotPoints.enumerated()), id: \.offset) { index, plotPoint in
                                PlotPointRow(plotPoint: plotPoint, onTap: {
                                    onPointTap(plotPoint.wordPosition)
                                })
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding(.vertical)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

@available(macOS 13.0, *)
struct PlotPointRow: View {
    let plotPoint: PlotPoint
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
                Text(plotPoint.type.emoji)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(plotPoint.type.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(primaryTextColor)

                    Text("At \(Int(plotPoint.percentagePosition * 100))% • Tension: \(Int(plotPoint.tensionLevel * 100))%")
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)

                    if let improvement = plotPoint.suggestedImprovement {
                        Text(improvement)
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
