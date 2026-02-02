//
//  ScansionView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import SwiftUI

/// A view that displays scansion (stress patterns) for poetry lines
struct ScansionView: View {
    let text: String
    @State private var selectedLineIndex: Int? = nil
    @State private var scannedLines: [ScannedLine] = []
    @State private var isScanning: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private struct ScannedLine {
        let line: String
        let wordData: [(word: String, pattern: [ScansionHelper.Stress])]
        let patternString: String
        let syllables: Int
    }

    private var lines: [String] {
        text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var detectedMeter: String {
        ScansionHelper.detectMeter(lines: lines)
    }

    /// Safe index clamped to valid range
    private var safeSelectedIndex: Int {
        guard !lines.isEmpty else { return 0 }
        if let selectedLineIndex {
            return min(selectedLineIndex, lines.count - 1)
        }
        return 0
    }

    private var currentLineInfo: ScannedLine? {
        guard scannedLines.indices.contains(safeSelectedIndex) else { return nil }
        return scannedLines[safeSelectedIndex]
    }

    private func rebuildScansionCache(for sourceLines: [String]) {
        guard !sourceLines.isEmpty else {
            scannedLines = []
            isScanning = false
            return
        }

        isScanning = true
        let linesSnapshot = sourceLines

        DispatchQueue.global(qos: .userInitiated).async {
            let computed: [ScannedLine] = linesSnapshot.map { line in
                let scanned = ScansionHelper.scanLine(line)
                let pattern = scanned.flatMap { $0.pattern.map { $0.rawValue } }.joined(separator: " ")
                let syllables = SyllableCounter.countSyllablesInLine(line)
                return ScannedLine(line: line, wordData: scanned, patternString: pattern, syllables: syllables)
            }

            DispatchQueue.main.async {
                if self.lines == linesSnapshot {
                    self.scannedLines = computed
                    self.isScanning = false
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "waveform.path")
                    .foregroundColor(.secondary)
                Text("Scansion Helper")
                    .font(.headline)
                Spacer()

                // Detected meter badge
                Text(detectedMeter)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.2))
                    )
            }

            // Legend
            HStack(spacing: 16) {
                LegendItem(symbol: "/", label: "Stressed", color: .red)
                LegendItem(symbol: "u", label: "Unstressed", color: .blue)
                LegendItem(symbol: "\\", label: "Secondary", color: .orange)
            }
            .font(.caption)

            Divider()

            if lines.isEmpty {
                Text("No lines to analyze")
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                // Line selector
                Picker("Line", selection: $selectedLineIndex) {
                    ForEach(lines.indices, id: \.self) { index in
                        Text("Line \(index + 1)").tag(Optional(index))
                    }
                }
                .pickerStyle(.menu)
                .onAppear {
                    if selectedLineIndex == nil, !lines.isEmpty {
                        selectedLineIndex = 0
                    }
                    rebuildScansionCache(for: lines)
                }
                .onChange(of: lines) { newLines in
                    if newLines.isEmpty {
                        selectedLineIndex = nil
                    } else if let selectedLineIndex, selectedLineIndex >= newLines.count {
                        self.selectedLineIndex = newLines.count - 1
                    } else if selectedLineIndex == nil {
                        selectedLineIndex = 0
                    }
                    rebuildScansionCache(for: newLines)
                }

                // Scansion display
                if let lineInfo = currentLineInfo {
                    let scanned = lineInfo.wordData

                    VStack(alignment: .leading, spacing: 8) {
                        // Stress marks row
                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(Array(scanned.enumerated()), id: \.offset) { _, wordData in
                                WordScansionView(word: wordData.word, pattern: wordData.pattern)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
                        )

                        // Syllable count for the line
                        HStack {
                            Text("Syllables:")
                                .foregroundColor(.secondary)
                            Text("\(lineInfo.syllables)")
                                .fontWeight(.medium)

                            Spacer()

                            Text("Pattern:")
                                .foregroundColor(.secondary)
                            Text(lineInfo.patternString.replacingOccurrences(of: " ", with: ""))
                                .font(.system(.body, design: .monospaced))
                        }
                        .font(.caption)
                    }
                } else if isScanning {
                    ProgressView("Analyzing...")
                        .frame(maxWidth: .infinity, minHeight: 120)
                }

                // Quick scan of all lines
                Divider()

                Text("All Lines Overview")
                    .font(.subheadline)
                    .fontWeight(.medium)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .trailing)

                                if scannedLines.indices.contains(index) {
                                    let info = scannedLines[index]
                                    Text(info.patternString)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.primary)

                                    Text("(\(info.syllables))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else if isScanning {
                                    Text("...")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 2)
                            .background(safeSelectedIndex == index ? Color.accentColor.opacity(0.1) : Color.clear)
                            .onTapGesture {
                                selectedLineIndex = index
                            }
                        }
                    }
                }
                .frame(height: 150)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.windowBackgroundColor) : Color.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

/// Displays a single word with its stress pattern
struct WordScansionView: View {
    let word: String
    let pattern: [ScansionHelper.Stress]

    var body: some View {
        VStack(spacing: 2) {
            // Stress marks
            HStack(spacing: 1) {
                ForEach(Array(pattern.enumerated()), id: \.offset) { _, stress in
                    Text(stress.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(stressColor(stress))
                }
            }

            // Word
            Text(word)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 4)
    }

    private func stressColor(_ stress: ScansionHelper.Stress) -> Color {
        switch stress {
        case .stressed: return .red
        case .unstressed: return .blue
        case .secondary: return .orange
        }
    }
}

/// Legend item
struct LegendItem: View {
    let symbol: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(symbol)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - NSViewRepresentable for AppKit Integration

struct ScansionHostingView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSHostingView<ScansionView> {
        let view = NSHostingView(rootView: ScansionView(text: text))
        return view
    }

    func updateNSView(_ nsView: NSHostingView<ScansionView>, context: Context) {
        nsView.rootView = ScansionView(text: text)
    }
}

// MARK: - Preview

#if DEBUG
struct ScansionView_Previews: PreviewProvider {
    static var previews: some View {
        ScansionView(text: """
        Shall I compare thee to a summer's day?
        Thou art more lovely and more temperate:
        Rough winds do shake the darling buds of May,
        And summer's lease hath all too short a date.
        """)
        .frame(width: 500)
        .padding()
    }
}
#endif
