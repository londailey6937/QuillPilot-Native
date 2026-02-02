//
//  LineLengthGraphView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import SwiftUI

/// A view that displays line length variation as a bar graph
struct LineLengthGraphView: View {
    let data: [LineLengthAnalyzer.LineLengthData]
    @State private var measureBy: MeasureType

    @State private var hoveredLine: Int?
    @Environment(\.colorScheme) private var colorScheme
    private var themeAccent: Color { Color(ThemeManager.shared.currentTheme.pageBorder) }

    enum MeasureType: String, CaseIterable {
        case syllables = "Syllables"
        case words = "Words"
        case characters = "Characters"
    }

    init(data: [LineLengthAnalyzer.LineLengthData], measureBy: MeasureType = .syllables) {
        self.data = data
        self._measureBy = State(initialValue: measureBy)
    }

    private var nonEmptyData: [LineLengthAnalyzer.LineLengthData] {
        data.filter { !$0.text.isEmpty }
    }

    private func value(for line: LineLengthAnalyzer.LineLengthData) -> Int {
        switch measureBy {
        case .syllables: return line.syllables
        case .words: return line.words
        case .characters: return line.characters
        }
    }

    private var maxValue: Int {
        nonEmptyData.map { value(for: $0) }.max() ?? 1
    }

    private func barColor(for value: Int) -> Color {
        let normalized = Double(value) / Double(max(1, maxValue))
        if normalized < 0.3 {
            return .green
        } else if normalized < 0.6 {
            return themeAccent
        } else if normalized < 0.8 {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.secondary)
                Text("Line Length Variation")
                    .font(.headline)
                Spacer()

                Picker("Measure", selection: $measureBy) {
                    ForEach(MeasureType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .tint(themeAccent)
            }
            .padding(.bottom, 4)

            if nonEmptyData.isEmpty {
                Text("No lines to analyze")
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                // Statistics summary
                let stats = LineLengthAnalyzer.statistics(from: nonEmptyData, measure: analyzerMeasure)
                HStack(spacing: 16) {
                    StatBadge(label: "Avg", value: String(format: "%.1f", stats.average))
                    StatBadge(label: "Min", value: "\(stats.min)")
                    StatBadge(label: "Max", value: "\(stats.max)")
                    StatBadge(label: "Var", value: String(format: "%.1f", stats.stdDev))
                }
                .padding(.vertical, 4)

                // Bar graph
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(nonEmptyData, id: \.lineNumber) { line in
                            VStack(spacing: 2) {
                                // Bar
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(barColor(for: value(for: line)))
                                    .frame(
                                        width: max(4, 300 / CGFloat(nonEmptyData.count)),
                                        height: max(4, CGFloat(value(for: line)) / CGFloat(maxValue) * 100)
                                    )
                                    .opacity(hoveredLine == line.lineNumber ? 1.0 : 0.8)

                                // Line number
                                Text("\(line.lineNumber)")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                            .onHover { hovering in
                                hoveredLine = hovering ? line.lineNumber : nil
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 130)

                Text("Tip: Use Shift + mouse wheel to scroll horizontally")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Hovered line info
                if let lineNum = hoveredLine, let line = nonEmptyData.first(where: { $0.lineNumber == lineNum }) {
                    HStack {
                        Text("Line \(line.lineNumber):")
                            .fontWeight(.medium)
                        Text("\(line.syllables) syl, \(line.words) words, \(line.characters) chars")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .font(.caption)

                    Text(line.text)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding()
        .tint(themeAccent)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.windowBackgroundColor) : Color.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }

    private var analyzerMeasure: LineLengthAnalyzer.Measure {
        switch measureBy {
        case .syllables: return .syllables
        case .words: return .words
        case .characters: return .characters
        }
    }
}

/// Small stat badge
struct StatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

// MARK: - NSViewRepresentable for AppKit Integration

struct LineLengthGraphHostingView: NSViewRepresentable {
    let data: [LineLengthAnalyzer.LineLengthData]

    func makeNSView(context: Context) -> NSHostingView<LineLengthGraphView> {
        let view = NSHostingView(rootView: LineLengthGraphView(data: data))
        return view
    }

    func updateNSView(_ nsView: NSHostingView<LineLengthGraphView>, context: Context) {
        nsView.rootView = LineLengthGraphView(data: data)
    }
}

// MARK: - Preview

#if DEBUG
struct LineLengthGraphView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleData: [LineLengthAnalyzer.LineLengthData] = [
            .init(lineNumber: 1, text: "Shall I compare thee to a summer's day?", syllables: 10, words: 8, characters: 40),
            .init(lineNumber: 2, text: "Thou art more lovely and more temperate:", syllables: 10, words: 6, characters: 39),
            .init(lineNumber: 3, text: "Rough winds do shake the darling buds of May,", syllables: 10, words: 9, characters: 44),
            .init(lineNumber: 4, text: "And summer's lease hath all too short a date.", syllables: 10, words: 9, characters: 45),
            .init(lineNumber: 5, text: "", syllables: 0, words: 0, characters: 0),
            .init(lineNumber: 6, text: "Sometime too hot the eye of heaven shines,", syllables: 10, words: 8, characters: 42),
            .init(lineNumber: 7, text: "And often is his gold complexion dimm'd;", syllables: 10, words: 7, characters: 40),
        ]

        LineLengthGraphView(data: sampleData)
            .frame(width: 500, height: 250)
            .padding()
    }
}
#endif
