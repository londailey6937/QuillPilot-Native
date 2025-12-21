//
//  CharacterArcVisualizationView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa
import Charts

@available(macOS 13.0, *)
class CharacterArcVisualizationView: NSView {

    private var characterArcs: [CharacterArc] = []
    private var characterInteractions: [CharacterInteraction] = []
    private var characterPresence: [CharacterPresence] = []

    private var chartView: NSHostingView<CharacterArcCharts>?
    weak var delegate: CharacterArcVisualizationDelegate?

    func configure(
        arcs: [CharacterArc],
        interactions: [CharacterInteraction],
        presence: [CharacterPresence]
    ) {
        self.characterArcs = arcs
        self.characterInteractions = interactions
        self.characterPresence = presence
        setupChartView()
    }

    private func setupChartView() {
        // Remove old chart if exists
        chartView?.removeFromSuperview()

        let chart = CharacterArcCharts(
            arcs: characterArcs,
            interactions: characterInteractions,
            presence: characterPresence,
            onSectionTap: { [weak self] wordPosition in
                self?.delegate?.didTapSection(at: wordPosition)
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

protocol CharacterArcVisualizationDelegate: AnyObject {
    func didTapSection(at wordPosition: Int)
}

// MARK: - SwiftUI Charts

import SwiftUI

@available(macOS 13.0, *)
struct CharacterArcCharts: View {
    let arcs: [CharacterArc]
    let interactions: [CharacterInteraction]
    let presence: [CharacterPresence]
    let onSectionTap: (Int) -> Void

    @State private var selectedTab: ChartTab = .emotionalJourney

    enum ChartTab: String, CaseIterable {
        case emotionalJourney = "Emotional Journey"
        case interactions = "Character Network"
        case presence = "Presence Heatmap"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Tab selector
            Picker("Chart Type", selection: $selectedTab) {
                ForEach(ChartTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Chart content
            ScrollView {
                switch selectedTab {
                case .emotionalJourney:
                    EmotionalJourneyChart(arcs: arcs, onSectionTap: onSectionTap)
                case .interactions:
                    CharacterInteractionChart(interactions: interactions)
                case .presence:
                    CharacterPresenceHeatmap(presence: presence, onChapterTap: onSectionTap)
                }
            }
        }
        .padding()
    }
}

// MARK: - Emotional Journey Chart

@available(macOS 13.0, *)
struct EmotionalJourneyChart: View {
    let arcs: [CharacterArc]
    let onSectionTap: (Int) -> Void

    // Color palette for characters
    private let characterColors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .red, .cyan, .mint
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Emotional Journey")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Track each character's emotional state throughout the story")
                .font(.caption)
                .foregroundColor(.secondary)

            if arcs.isEmpty {
                Text("No character data available. Make sure characters are defined in your Character Library.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(Array(arcs.enumerated()), id: \.offset) { index, arc in
                    CharacterArcSection(
                        arc: arc,
                        color: characterColors[index % characterColors.count],
                        onTap: onSectionTap
                    )
                }
            }
        }
        .padding()
    }
}

@available(macOS 13.0, *)
struct CharacterArcSection: View {
    let arc: CharacterArc
    let color: Color
    let onTap: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Character header
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)

                Text(arc.characterName)
                    .font(.headline)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(arc.arcType.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Strength: \(Int(arc.arcStrength * 100))%")
                        .font(.caption)
                        .foregroundColor(arcStrengthColor(arc.arcStrength))
                }
            }

            // Emotional journey chart
            if !arc.emotionalJourney.isEmpty {
                Chart {
                    ForEach(Array(arc.emotionalJourney.enumerated()), id: \.offset) { index, state in
                        LineMark(
                            x: .value("Section", index),
                            y: .value("Sentiment", state.sentiment)
                        )
                        .foregroundStyle(color.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 3))

                        PointMark(
                            x: .value("Section", index),
                            y: .value("Sentiment", state.sentiment)
                        )
                        .foregroundStyle(color)
                        .symbolSize(80)
                    }
                }
                .chartYScale(domain: -1...1)
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("Sect \(intValue + 1)")
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [-1, -0.5, 0, 0.5, 1]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                if doubleValue > 0 {
                                    Text("Positive")
                                } else if doubleValue < 0 {
                                    Text("Negative")
                                } else {
                                    Text("Neutral")
                                }
                            }
                        }
                    }
                }
                .frame(height: 150)
            }

            // Stats
            HStack(spacing: 20) {
                StatPill(label: "Total Mentions", value: "\(arc.totalMentions)")
                StatPill(label: "Sections Appeared", value: "\(arc.emotionalJourney.count)")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func arcStrengthColor(_ strength: Double) -> Color {
        switch strength {
        case 0.7...1.0: return .green
        case 0.4..<0.7: return .orange
        default: return .red
        }
    }
}

@available(macOS 13.0, *)
struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Character Interaction Chart

@available(macOS 13.0, *)
struct CharacterInteractionChart: View {
    let interactions: [CharacterInteraction]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Character Network")
                .font(.headline)
                .fontWeight(.semibold)

            Text("See which characters appear together most frequently")
                .font(.caption)
                .foregroundColor(.secondary)

            if interactions.isEmpty {
                Text("No character interactions detected")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Bar chart of interactions
                Chart {
                    ForEach(Array(interactions.prefix(10).enumerated()), id: \.offset) { index, interaction in
                        BarMark(
                            x: .value("Co-Appearances", interaction.coAppearances),
                            y: .value("Characters", "\(interaction.character1) & \(interaction.character2)")
                        )
                        .foregroundStyle(strengthGradient(interaction.relationshipStrength))
                    }
                }
                .frame(height: CGFloat(min(interactions.count, 10) * 40 + 40))
                .padding()

                // Detailed list
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(interactions.enumerated()), id: \.offset) { index, interaction in
                        HStack {
                            Text("\(interaction.character1) & \(interaction.character2)")
                                .font(.subheadline)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(interaction.coAppearances) scenes")
                                    .font(.caption)
                                    .fontWeight(.semibold)

                                Text("Strength: \(Int(interaction.relationshipStrength * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .padding()
    }

    private func strengthGradient(_ strength: Double) -> LinearGradient {
        if strength > 0.6 {
            return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        } else if strength > 0.3 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - Character Presence Heatmap

@available(macOS 13.0, *)
struct CharacterPresenceHeatmap: View {
    let presence: [CharacterPresence]
    let onChapterTap: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Character Presence by Chapter")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Heatmap showing how often each character appears")
                .font(.caption)
                .foregroundColor(.secondary)

            if presence.isEmpty || presence.allSatisfy({ $0.chapterPresence.isEmpty }) {
                Text("No chapter data available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Get max chapter number and max mentions for scaling
                let maxChapter = presence.flatMap { $0.chapterPresence.keys }.max() ?? 1
                let maxMentions = presence.flatMap { $0.chapterPresence.values }.max() ?? 1

                // Heatmap grid
                VStack(alignment: .leading, spacing: 8) {
                    // Chapter headers
                    HStack(spacing: 4) {
                        Text("Character")
                            .font(.caption2)
                            .frame(width: 100, alignment: .leading)

                        ForEach(1...maxChapter, id: \.self) { chapter in
                            Text("Ch\(chapter)")
                                .font(.caption2)
                                .frame(width: 40)
                        }
                    }

                    // Character rows
                    ForEach(presence, id: \.characterName) { charPresence in
                        HStack(spacing: 4) {
                            Text(charPresence.characterName)
                                .font(.caption)
                                .frame(width: 100, alignment: .leading)
                                .lineLimit(1)

                            ForEach(1...maxChapter, id: \.self) { chapter in
                                let mentions = charPresence.chapterPresence[chapter] ?? 0
                                let intensity = Double(mentions) / Double(maxMentions)

                                Rectangle()
                                    .fill(heatmapColor(intensity: intensity))
                                    .frame(width: 40, height: 30)
                                    .cornerRadius(4)
                                    .overlay(
                                        Text(mentions > 0 ? "\(mentions)" : "")
                                            .font(.system(size: 9))
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                    }
                }
                .padding()

                // Legend
                HStack(spacing: 8) {
                    Text("Less")
                        .font(.caption2)

                    ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { intensity in
                        Rectangle()
                            .fill(heatmapColor(intensity: intensity))
                            .frame(width: 30, height: 15)
                            .cornerRadius(3)
                    }

                    Text("More")
                        .font(.caption2)
                }
                .padding()
            }
        }
        .padding()
    }

    private func heatmapColor(intensity: Double) -> Color {
        if intensity == 0 {
            return Color.gray.opacity(0.1)
        } else if intensity < 0.3 {
            return Color.blue.opacity(0.3)
        } else if intensity < 0.6 {
            return Color.blue.opacity(0.6)
        } else {
            return Color.blue.opacity(0.9)
        }
    }
}
