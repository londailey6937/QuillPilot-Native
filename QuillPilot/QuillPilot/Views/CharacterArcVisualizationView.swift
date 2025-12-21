//
//  CharacterArcVisualizationView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa
import Charts
import SwiftUI

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
            },
            onEmotionalJourneyPopout: { [weak self] in
                guard let self else { return }
                self.delegate?.openEmotionalJourneyPopout(arcs: self.characterArcs)
            },
            onInteractionsPopout: { [weak self] in
                guard let self else { return }
                self.delegate?.openInteractionsPopout(interactions: self.characterInteractions)
            },
            onPresencePopout: { [weak self] in
                guard let self else { return }
                self.delegate?.openPresencePopout(presence: self.characterPresence)
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
    func openEmotionalJourneyPopout(arcs: [CharacterArc])
    func openInteractionsPopout(interactions: [CharacterInteraction])
    func openPresencePopout(presence: [CharacterPresence])
}

// MARK: - SwiftUI Charts

@available(macOS 13.0, *)
struct CharacterArcCharts: View {
    let arcs: [CharacterArc]
    let interactions: [CharacterInteraction]
    let presence: [CharacterPresence]
    let onSectionTap: (Int) -> Void
    let onEmotionalJourneyPopout: () -> Void
    let onInteractionsPopout: () -> Void
    let onPresencePopout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Emotional Journey Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Character Emotional Journeys")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal)

                EmotionalJourneyChart(arcs: arcs, onSectionTap: onSectionTap)
                    .frame(height: 300)
            }

            Divider()
                .padding(.horizontal)

            // Character Network Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Character Interactions")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal)

                Text("Shows which characters appear together in scenes. Strong connections suggest key relationships and dialogue opportunities. Use this to identify under-developed character pairings or to balance your story's social dynamics.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .fixedSize(horizontal: false, vertical: true)

                CharacterNetworkChart(interactions: interactions)
                    .frame(height: 300)
            }

            Divider()
                .padding(.horizontal)

            // Presence Chart Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Character Presence")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal)

                Text("Shows per-chapter mentions for each character with a clear x/y axis. Use this to ensure pacing is balanced and to spot chapters where key characters drop out.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .fixedSize(horizontal: false, vertical: true)

                CharacterPresenceBarChart(presence: presence)
                    .frame(height: 320)
            }
        }
        .padding(.vertical)
    }
}

@available(macOS 13.0, *)
struct EmotionalJourneyChart: View {
    let arcs: [CharacterArc]
    let onSectionTap: (Int) -> Void

    var body: some View {
        if arcs.isEmpty {
            Text("No character arcs detected")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(arcs.enumerated()), id: \.offset) { _, arc in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(arc.characterName)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            if !arc.emotionalJourney.isEmpty {
                                Chart {
                                    ForEach(Array(arc.emotionalJourney.enumerated()), id: \.offset) { _, state in
                                        LineMark(
                                            x: .value("Section", state.sectionIndex),
                                            y: .value("Sentiment", state.sentiment)
                                        )
                                        .foregroundStyle(Color.blue)

                                        PointMark(
                                            x: .value("Section", state.sectionIndex),
                                            y: .value("Sentiment", state.sentiment)
                                        )
                                        .foregroundStyle(Color.blue)
                                    }
                                }
                                .frame(height: 150)
                                .chartYScale(domain: -1...1)
                            } else {
                                Text("No emotional data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

@available(macOS 13.0, *)
struct CharacterNetworkChart: View {
    let interactions: [CharacterInteraction]

    var body: some View {
        if interactions.isEmpty {
            Text("No character interactions detected")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(interactions.enumerated()), id: \.offset) { _, interaction in
                        HStack {
                            Text(interaction.character1)
                            Image(systemName: "arrow.left.and.right")
                            Text(interaction.character2)
                            Spacer()
                            Text("\(interaction.coAppearances) scenes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

@available(macOS 13.0, *)
struct CharacterPresenceDataPoint: Identifiable {
    let id = UUID()
    let character: String
    let chapter: Int
    let mentions: Int
}

@available(macOS 13.0, *)
struct CharacterPresenceBarChart: View {
    let presence: [CharacterPresence]

    private var dataPoints: [CharacterPresenceDataPoint] {
        let points = presence.flatMap { entry in
            entry.chapterPresence.map { chapter, mentions in
                CharacterPresenceDataPoint(
                    character: entry.characterName,
                    chapter: chapter,
                    mentions: mentions
                )
            }
        }
        return points.sorted { lhs, rhs in
            lhs.chapter == rhs.chapter ? lhs.character < rhs.character : lhs.chapter < rhs.chapter
        }
    }

    private var chapters: [Int] {
        Array(Set(dataPoints.map { $0.chapter })).sorted()
    }

    var body: some View {
        if presence.isEmpty {
            Text("No character presence data")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else if dataPoints.isEmpty {
            Text("No character presence data")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else {
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: true) {
                    Chart(dataPoints) { point in
                        BarMark(
                            x: .value("Chapter", "Ch \(point.chapter)"),
                            y: .value("Mentions", point.mentions)
                        )
                        .foregroundStyle(by: .value("Character", point.character))
                        .annotation(position: .top, alignment: .center) {
                            if point.mentions > 0 {
                                Text("\(point.mentions)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .chartXAxisLabel("Chapter")
                    .chartYAxisLabel("Mentions")
                    .chartXAxis {
                        AxisMarks(values: chapters.map { "Ch \($0)" })
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(width: max(CGFloat(chapters.count) * 90, geometry.size.width), height: 280)
                }
            }
            .frame(height: 320)
        }
    }
}
