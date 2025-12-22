//
//  DecisionConsequenceChainView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import SwiftUI

@available(macOS 13.0, *)
struct DecisionConsequenceChainView: View {
    let chains: [DecisionConsequenceChain]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Decision-Consequence Chains")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("Map choices, not traits – Ensure growth comes from action, not narration")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Perfect for diagnosing passive protagonists and ensuring causal evolution")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.bottom, 8)

                if chains.isEmpty {
                    emptyState
                } else {
                    ForEach(chains, id: \.characterName) { chain in
                        characterChainView(chain)
                    }
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Decision Chain Data")
                .font(.headline)

            Text("Decision-consequence chains will appear here after analysis")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func characterChainView(_ chain: DecisionConsequenceChain) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Character header with agency score
            HStack {
                Text(chain.characterName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                agencyBadge(chain.agencyScore)
            }

            if chain.entries.isEmpty {
                Text("No decision entries for this character")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding()
            } else {
                // Decision chain table
                decisionTable(chain.entries)
            }

            Divider()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func agencyBadge(_ assessment: DecisionConsequenceChain.AgencyAssessment) -> some View {
        let color: Color
        let icon: String

        switch assessment {
        case .insufficient:
            color = .gray
            icon = "questionmark.circle"
        case .passive:
            color = .red
            icon = "exclamationmark.triangle"
        case .reactive:
            color = .orange
            icon = "arrow.left.arrow.right"
        case .developing:
            color = .blue
            icon = "arrow.up.right"
        case .activeProtagonist:
            color = .green
            icon = "star.circle"
        }

        return HStack(spacing: 4) {
            Image(systemName: icon)
            Text(assessment.rawValue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }

    private func decisionTable(_ entries: [DecisionConsequenceChain.ChainEntry]) -> some View {
        VStack(spacing: 0) {
            // Table header
            HStack(spacing: 0) {
                tableHeaderCell("Chapter", width: 80)
                tableHeaderCell("Decision", width: nil)
                tableHeaderCell("Immediate Outcome", width: nil)
                tableHeaderCell("Long-term Effect", width: nil)
            }
            .background(Color.gray.opacity(0.2))

            // Table rows with visual flow indicators
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        tableCell(
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ch \(entry.chapter)")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                if entry.chapterPage > 0 {
                                    Text("p.\(entry.chapterPage)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            },
                            width: 80
                        )

                        tableCell(
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "hand.point.up.left.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text(entry.decision.isEmpty ? "—" : entry.decision)
                                        .font(.body)
                                        .foregroundColor(entry.decision.isEmpty ? .secondary : .primary)
                                }
                                if entry.decisionPage > 0 {
                                    Text("Page \(entry.decisionPage)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            },
                            width: nil
                        )

                        tableCell(
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text(entry.immediateOutcome.isEmpty ? "—" : entry.immediateOutcome)
                                        .font(.body)
                                        .foregroundColor(entry.immediateOutcome.isEmpty ? .secondary : .primary)
                                }
                                if entry.immediateOutcomePage > 0 {
                                    Text("Page \(entry.immediateOutcomePage)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            },
                            width: nil
                        )

                        tableCell(
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    Text(entry.longTermEffect.isEmpty ? "—" : entry.longTermEffect)
                                        .font(.body)
                                        .foregroundColor(entry.longTermEffect.isEmpty ? .secondary : .primary)
                                }
                                if entry.longTermEffectPage > 0 {
                                    Text("Page \(entry.longTermEffectPage)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            },
                            width: nil
                        )
                    }
                    .background(index % 2 == 0 ? Color.clear : Color.gray.opacity(0.05))

                    // Flow arrow between entries
                    if index < entries.count - 1 {
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.03))
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
    }

    private func tableHeaderCell(_ text: String, width: CGFloat?) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.primary.opacity(0.7))
            .frame(maxWidth: width == nil ? .infinity : width, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
    }

    private func tableCell<Content: View>(_ content: Content, width: CGFloat?) -> some View {
        content
            .frame(maxWidth: width == nil ? .infinity : width, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
    }
}

// MARK: - Example Usage (for previews)

@available(macOS 13.0, *)
struct DecisionConsequenceChainView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleChain = DecisionConsequenceChain(
            characterName: "Alex",
            entries: [
                DecisionConsequenceChain.ChainEntry(
                    chapter: 1,
                    chapterPage: 15,
                    decision: "Refuses help from mentor, chooses solo mission",
                    decisionPage: 15,
                    immediateOutcome: "Nearly fails first objective alone",
                    immediateOutcomePage: 22,
                    longTermEffect: "Develops mistrust of authority figures",
                    longTermEffectPage: 30
                ),
                DecisionConsequenceChain.ChainEntry(
                    chapter: 4,
                    chapterPage: 68,
                    decision: "Accepts dangerous alliance to gain intel",
                    decisionPage: 68,
                    immediateOutcome: "Gets valuable information but makes enemy",
                    immediateOutcomePage: 75,
                    longTermEffect: "Creates secondary antagonist for Act 2",
                    longTermEffectPage: 95
                )
            ]
        )

        DecisionConsequenceChainView(chains: [sampleChain])
            .frame(width: 1200, height: 700)
    }
}
