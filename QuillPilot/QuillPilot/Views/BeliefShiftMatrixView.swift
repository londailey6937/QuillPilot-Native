//
//  BeliefShiftMatrixView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import SwiftUI

@available(macOS 13.0, *)
struct BeliefShiftMatrixView: View {
    let matrices: [BeliefShiftMatrix]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Belief / Value Shift Matrices")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("Track how character beliefs evolve through counterpressure and experience")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Ideal for theme-driven and literary fiction where evolution is logical, not just emotional")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.bottom, 8)

                if matrices.isEmpty {
                    emptyState
                } else {
                    ForEach(matrices, id: \.characterName) { matrix in
                        characterMatrixView(matrix)
                    }
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Belief Shift Data")
                .font(.headline)

            Text("Belief shift matrices will appear here after analysis")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func characterMatrixView(_ matrix: BeliefShiftMatrix) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Character header with evolution quality
            HStack {
                Text(matrix.characterName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                evolutionBadge(matrix.evolutionQuality)
            }

            if matrix.entries.isEmpty {
                Text("No belief entries for this character")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding()
            } else {
                // Table view
                beliefTable(matrix.entries)
            }

            Divider()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func evolutionBadge(_ quality: BeliefShiftMatrix.EvolutionQuality) -> some View {
        let color: Color
        let icon: String

        switch quality {
        case .insufficient:
            color = .gray
            icon = "questionmark.circle"
        case .unchanging:
            color = .orange
            icon = "minus.circle"
        case .developing:
            color = .blue
            icon = "arrow.up.circle"
        case .logical:
            color = .green
            icon = "checkmark.circle"
        }

        return HStack(spacing: 4) {
            Image(systemName: icon)
            Text(quality.rawValue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }

    private func beliefTable(_ entries: [BeliefShiftMatrix.BeliefEntry]) -> some View {
        VStack(spacing: 0) {
            // Table header
            HStack(spacing: 0) {
                tableHeaderCell("Chapter", width: 80)
                tableHeaderCell("Core Belief", width: nil)
                tableHeaderCell("Evidence", width: nil)
                tableHeaderCell("Counterpressure", width: nil)
            }
            .background(Color.gray.opacity(0.2))

            // Table rows
            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
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
                            Text(entry.coreBelief.isEmpty ? "—" : entry.coreBelief)
                                .font(.body)
                                .italic()
                                .foregroundColor(entry.coreBelief.isEmpty ? .secondary : .primary)
                        },
                        width: nil
                    )

                    tableCell(
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.evidence.isEmpty ? "—" : entry.evidence)
                                .font(.body)
                                .foregroundColor(entry.evidence.isEmpty ? .secondary : .primary)
                            if entry.evidencePage > 0 {
                                Text("Page \(entry.evidencePage)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        },
                        width: nil
                    )

                    tableCell(
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.counterpressure.isEmpty ? "—" : entry.counterpressure)
                                .font(.body)
                                .foregroundColor(entry.counterpressure.isEmpty ? .secondary : .primary)
                            if entry.counterpressurePage > 0 {
                                Text("Page \(entry.counterpressurePage)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        },
                        width: nil
                    )
                }
                .background(index % 2 == 0 ? Color.clear : Color.gray.opacity(0.05))
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
struct BeliefShiftMatrixView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleMatrix = BeliefShiftMatrix(
            characterName: "Alex",
            entries: [
                BeliefShiftMatrix.BeliefEntry(
                    chapter: 1,
                    chapterPage: 12,
                    coreBelief: "I survive alone.",
                    evidence: "Refuses help from teammates",
                    evidencePage: 15,
                    counterpressure: "Offered protection by mentor",
                    counterpressurePage: 18
                ),
                BeliefShiftMatrix.BeliefEntry(
                    chapter: 6,
                    chapterPage: 87,
                    coreBelief: "Help costs freedom.",
                    evidence: "Accepts dangerous deal",
                    evidencePage: 92,
                    counterpressure: "Loses autonomy in exchange",
                    counterpressurePage: 95
                ),
                BeliefShiftMatrix.BeliefEntry(
                    chapter: 12,
                    chapterPage: 203,
                    coreBelief: "Interdependence is strength.",
                    evidence: "Makes sacrifice for team",
                    evidencePage: 210,
                    counterpressure: "Fear of betrayal resurfaces",
                    counterpressurePage: 215
                )
            ]
        )

        BeliefShiftMatrixView(matrices: [sampleMatrix])
            .frame(width: 1000, height: 600)
    }
}
