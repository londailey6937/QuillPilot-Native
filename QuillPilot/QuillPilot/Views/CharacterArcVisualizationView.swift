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

    private var decisionBeliefLoops: [DecisionBeliefLoop] = []
    private var characterInteractions: [CharacterInteraction] = []
    private var characterPresence: [CharacterPresence] = []

    private var chartView: NSHostingView<CharacterArcCharts>?
    weak var delegate: CharacterArcVisualizationDelegate?

    func configure(
        loops: [DecisionBeliefLoop],
        interactions: [CharacterInteraction],
        presence: [CharacterPresence]
    ) {
        self.decisionBeliefLoops = loops
        self.characterInteractions = interactions
        self.characterPresence = presence
        setupChartView()
    }

    private func setupChartView() {
        // Remove old chart if exists
        chartView?.removeFromSuperview()

        let chart = CharacterArcCharts(
            loops: decisionBeliefLoops,
            interactions: characterInteractions,
            presence: characterPresence,
            onDecisionBeliefPopout: { [weak self] in
                guard let self else { return }
                self.delegate?.openDecisionBeliefPopout(loops: self.decisionBeliefLoops)
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
    func openDecisionBeliefPopout(loops: [DecisionBeliefLoop])
    func openInteractionsPopout(interactions: [CharacterInteraction])
    func openPresencePopout(presence: [CharacterPresence])
}

// MARK: - SwiftUI Charts

@available(macOS 13.0, *)
struct CharacterArcCharts: View {
    let loops: [DecisionBeliefLoop]
    let interactions: [CharacterInteraction]
    let presence: [CharacterPresence]
    let onDecisionBeliefPopout: () -> Void
    let onInteractionsPopout: () -> Void
    let onPresencePopout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Decision-Belief Loop Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Decision-Belief Loop Framework")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Button(action: onDecisionBeliefPopout) {
                        Text("Open Full View")
                            .font(.caption)
                    }
                }
                .padding(.horizontal)

                Text("Track how decisions reshape beliefs, and beliefs reshape future decisions. This framework works across all fiction types and scales from one character to an ensemble.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .fixedSize(horizontal: false, vertical: true)

                DecisionBeliefLoopPreview(loops: loops)
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
                    Spacer()
                    Button(action: onInteractionsPopout) {
                        Text("Open Full View")
                            .font(.caption)
                    }
                }
                .padding(.horizontal)

                Text("Shows which characters appear together in scenes. Strong connections suggest key relationships and dialogue opportunities.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .fixedSize(horizontal: false, vertical: true)

                CharacterNetworkChart(interactions: interactions)
                    .frame(height: 250)
            }

            Divider()
                .padding(.horizontal)

            // Presence Chart Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Character Presence")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Button(action: onPresencePopout) {
                        Text("Open Full View")
                            .font(.caption)
                    }
                }
                .padding(.horizontal)

                Text("Shows per-chapter mentions for each character. Use this to ensure pacing is balanced and to spot chapters where key characters drop out.")
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
struct DecisionBeliefLoopPreview: View {
    let loops: [DecisionBeliefLoop]

    var body: some View {
        if loops.isEmpty {
            Text("No characters detected")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(loops.enumerated()), id: \.offset) { _, loop in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(loop.characterName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(loop.arcQuality.rawValue)
                                    .font(.caption)
                                    .foregroundColor(arcQualityColor(loop.arcQuality))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(arcQualityColor(loop.arcQuality).opacity(0.2))
                                    .cornerRadius(4)
                            }

                            Text("The Decision–Belief Loop Framework tracks five elements per chapter:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(["Pressure: New forces acting on the character",
                                        "Belief in Play: Core belief being tested",
                                        "Decision: Choice made because of that belief",
                                        "Outcome: Immediate result of the decision",
                                        "Belief Shift: How the belief changes"], id: \.self) { item in
                                    Text("• \(item)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.leading, 8)

                            if loop.entries.count > 0 {
                                Text("\(loop.entries.count) chapter\(loop.entries.count == 1 ? "" : "s") tracked")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }

                    Text("Click 'Open Full View' to see the complete tracking table for all characters.")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal)
                }
                .padding(.horizontal)
            }
        }
    }

    private func arcQualityColor(_ quality: DecisionBeliefLoop.ArcQuality) -> Color {
        switch quality {
        case .insufficient: return .gray
        case .flat: return .orange
        case .developing: return .blue
        case .evolving: return .green
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

// MARK: - Decision-Belief Loop Full View

@available(macOS 13.0, *)
struct DecisionBeliefLoopFullView: View {
    let loops: [DecisionBeliefLoop]

    private var textColor: Color {
        Color(ThemeManager.shared.currentTheme.textColor)
    }

    private var backgroundColor: Color {
        Color(ThemeManager.shared.currentTheme.pageBackground)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with framework explanation
                VStack(alignment: .leading, spacing: 12) {
                    Text("The Decision–Belief Loop Framework")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(textColor)

                    Text("Characters evolve because decisions reshape beliefs, and beliefs reshape future decisions. Everything you track flows through that loop.")
                        .font(.body)
                        .foregroundColor(textColor.opacity(0.7))

                    Divider()
                        .background(textColor.opacity(0.3))

                    Text("The Loop (per chapter or major scene)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(textColor)

                    VStack(alignment: .leading, spacing: 8) {
                        LoopElementRow(number: "1", title: "Pressure", description: "What new force acts on the character here? (external event, emotional demand, moral dilemma)", textColor: textColor)
                        LoopElementRow(number: "2", title: "Belief in Play", description: "Which core belief is being tested? (often unstated in the prose)", textColor: textColor)
                        LoopElementRow(number: "3", title: "Decision", description: "What choice does the character make because of that belief?", textColor: textColor)
                        LoopElementRow(number: "4", title: "Outcome", description: "What happens immediately because of the decision? (success, partial win, failure, avoidance)", textColor: textColor)
                        LoopElementRow(number: "5", title: "Belief Shift", description: "How does the belief change after the outcome? (reinforced, weakened, reframed, contradicted)", textColor: textColor)
                    }
                    .padding(.leading)

                    Divider()
                        .background(textColor.opacity(0.3))

                    Text("How Evolution Emerges")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(textColor)

                    Text("Character growth becomes visible when:")
                        .font(.body)
                        .foregroundColor(textColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Decisions stop being automatic")
                        Text("• Beliefs gain nuance")
                        Text("• Outcomes carry moral or emotional cost")
                        Text("• The same pressure produces different choices later")
                    }
                    .padding(.leading)
                    .foregroundColor(textColor.opacity(0.7))

                    Text("You don't measure intensity—you observe pattern change.")
                        .font(.body)
                        .fontWeight(.medium)
                        .italic()
                        .foregroundColor(textColor)
                }
                .padding()
                .background(textColor.opacity(0.05))
                .cornerRadius(12)

                // Character tracking tables
                ForEach(Array(loops.enumerated()), id: \.offset) { _, loop in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(loop.characterName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(textColor)
                            Spacer()
                            Text(loop.arcQuality.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(arcQualityColor(loop.arcQuality))
                                .cornerRadius(8)
                        }

                        // Table header
                        HStack(spacing: 8) {
                            Text("Ch")
                                .frame(width: 40, alignment: .center)
                                .fontWeight(.semibold)
                            Text("Pressure")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fontWeight(.semibold)
                            Text("Belief in Play")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fontWeight(.semibold)
                            Text("Decision")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fontWeight(.semibold)
                            Text("Outcome")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fontWeight(.semibold)
                            Text("Belief Shift")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .foregroundColor(textColor)
                        .padding(8)
                        .background(textColor.opacity(0.1))
                        .cornerRadius(4)

                        // Table rows
                        ForEach(loop.entries) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(entry.chapter)")
                                    .frame(width: 40, alignment: .center)
                                    .font(.body)
                                    .foregroundColor(textColor)
                                    .textSelection(.enabled)
                                Text(entry.pressure.isEmpty ? "—" : entry.pressure)
                                    .font(.caption)
                                    .foregroundColor(textColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                Text(entry.beliefInPlay.isEmpty ? "—" : entry.beliefInPlay)
                                    .font(.caption)
                                    .foregroundColor(textColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                Text(entry.decision.isEmpty ? "—" : entry.decision)
                                    .font(.caption)
                                    .foregroundColor(textColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                Text(entry.outcome.isEmpty ? "—" : entry.outcome)
                                    .font(.caption)
                                    .foregroundColor(textColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                Text(entry.beliefShift.isEmpty ? "—" : entry.beliefShift)
                                    .font(.caption)
                                    .foregroundColor(textColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .padding(8)
                            .background(textColor.opacity(0.03))
                            .cornerRadius(4)
                        }

                        // Diagnostic hints
                        VStack(alignment: .leading, spacing: 4) {
                            Text("💡 Tracking Tips:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(textColor)
                            Text("• If this table looks repetitive, your arc is flat.")
                                .font(.caption)
                                .foregroundColor(textColor.opacity(0.7))
                            Text("• If the belief shifts feel unearned, the pressure is too weak.")
                                .font(.caption)
                                .foregroundColor(textColor.opacity(0.7))
                            Text("• If a character's belief changes but their decisions don't, the change isn't real.")
                                .font(.caption)
                                .foregroundColor(textColor.opacity(0.7))
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(4)
                    }
                    .padding()
                    .background(textColor.opacity(0.03))
                    .cornerRadius(12)
                }

                // Rule of Thumb
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rule of Thumb")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(textColor)

                    Text("If a character's belief changes but their decisions don't, the change isn't real.")
                        .font(.body)
                        .foregroundColor(textColor)

                    Text("If decisions change without belief change, it's plot convenience.")
                        .font(.body)
                        .foregroundColor(textColor)
                }
                .padding()
                .background(Color.orange.opacity(0.15))
                .cornerRadius(12)
            }
            .padding()
        }
        .background(backgroundColor)
    }

    private func arcQualityColor(_ quality: DecisionBeliefLoop.ArcQuality) -> Color {
        switch quality {
        case .insufficient: return .gray
        case .flat: return .orange
        case .developing: return .blue
        case .evolving: return .green
        }
    }
}

@available(macOS 13.0, *)
struct LoopElementRow: View {
    let number: String
    let title: String
    let description: String
    let textColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.semibold)
                .foregroundColor(textColor)
                .frame(width: 20, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)
                Text(description)
                    .font(.caption)
                    .foregroundColor(textColor.opacity(0.7))
            }
        }
    }
}
