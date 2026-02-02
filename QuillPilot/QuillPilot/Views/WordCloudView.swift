//
//  WordCloudView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import SwiftUI

/// A view that displays word frequency as a word cloud
struct WordCloudView: View {
    let frequencies: [WordFrequencyAnalyzer.WordFrequency]
    let maxWords: Int

    @State private var hoveredWord: String?
    @Environment(\.colorScheme) private var colorScheme

    init(frequencies: [WordFrequencyAnalyzer.WordFrequency], maxWords: Int = 40) {
        self.frequencies = frequencies
        self.maxWords = maxWords
    }

    private var displayedWords: [WordFrequencyAnalyzer.WordFrequency] {
        Array(frequencies.prefix(maxWords))
    }

    private var maxCount: Int {
        frequencies.first?.count ?? 1
    }

    private var minCount: Int {
        displayedWords.last?.count ?? 1
    }

    private func fontSize(for word: WordFrequencyAnalyzer.WordFrequency) -> CGFloat {
        let range = CGFloat(maxCount - minCount)
        let normalized = range > 0 ? CGFloat(word.count - minCount) / range : 0.5
        return 12 + normalized * 28 // Font size from 12 to 40
    }

    private func color(for index: Int) -> Color {
        let colors: [Color] = [
            .blue, .purple, .pink, .orange, .green,
            .teal, .indigo, .cyan, .mint, .red
        ]
        return colors[index % colors.count]
    }

    private func opacity(for word: WordFrequencyAnalyzer.WordFrequency) -> Double {
        let range = Double(maxCount - minCount)
        let normalized = range > 0 ? Double(word.count - minCount) / range : 0.5
        return 0.6 + normalized * 0.4 // Opacity from 0.6 to 1.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cloud.fill")
                    .foregroundColor(.secondary)
                Text("Word Frequency")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 4)

            if frequencies.isEmpty {
                Text("No significant words found")
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(Array(displayedWords.enumerated()), id: \.element.word) { index, word in
                        WordBadge(
                            word: word.word,
                            count: word.count,
                            percentage: word.percentage,
                            fontSize: fontSize(for: word),
                            color: color(for: index),
                            opacity: opacity(for: word),
                            isHovered: hoveredWord == word.word
                        )
                        .onHover { hovering in
                            hoveredWord = hovering ? word.word : nil
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            if let hovered = hoveredWord, let word = frequencies.first(where: { $0.word == hovered }) {
                HStack {
                    Text("\"\(word.word)\"")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(word.count) occurrences (\(String(format: "%.1f", word.percentage))%)")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
                .padding(.top, 4)
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

/// Individual word badge in the cloud
struct WordBadge: View {
    let word: String
    let count: Int
    let percentage: Double
    let fontSize: CGFloat
    let color: Color
    let opacity: Double
    let isHovered: Bool

    var body: some View {
        Text(word)
            .font(.system(size: fontSize, weight: .medium, design: .rounded))
            .foregroundColor(color.opacity(opacity))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(isHovered ? 0.2 : 0.1))
            )
            .scaleEffect(isHovered ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

/// A simple flow layout for wrapping items
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            if index < arrangement.positions.count {
                let position = arrangement.positions[index]
                subview.place(
                    at: CGPoint(
                        x: bounds.minX + position.x,
                        y: bounds.minY + position.y
                    ),
                    proposal: ProposedViewSize(arrangement.sizes[index])
                )
            }
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint], sizes: [CGSize]) {
        let maxWidth = proposal.width ?? .infinity

        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            if currentX + size.width > maxWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))

            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, currentX - spacing)
        }

        return (
            size: CGSize(width: maxX, height: currentY + lineHeight),
            positions: positions,
            sizes: sizes
        )
    }
}

// MARK: - NSViewRepresentable for AppKit Integration

struct WordCloudHostingView: NSViewRepresentable {
    let frequencies: [WordFrequencyAnalyzer.WordFrequency]

    func makeNSView(context: Context) -> NSHostingView<WordCloudView> {
        let view = NSHostingView(rootView: WordCloudView(frequencies: frequencies))
        return view
    }

    func updateNSView(_ nsView: NSHostingView<WordCloudView>, context: Context) {
        nsView.rootView = WordCloudView(frequencies: frequencies)
    }
}

// MARK: - Preview

#if DEBUG
struct WordCloudView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleFrequencies: [WordFrequencyAnalyzer.WordFrequency] = [
            .init(word: "love", count: 15, percentage: 5.2),
            .init(word: "heart", count: 12, percentage: 4.1),
            .init(word: "dream", count: 10, percentage: 3.4),
            .init(word: "night", count: 9, percentage: 3.1),
            .init(word: "light", count: 8, percentage: 2.7),
            .init(word: "soul", count: 7, percentage: 2.4),
            .init(word: "time", count: 6, percentage: 2.1),
            .init(word: "world", count: 5, percentage: 1.7),
            .init(word: "stars", count: 4, percentage: 1.4),
            .init(word: "moon", count: 3, percentage: 1.0),
        ]

        WordCloudView(frequencies: sampleFrequencies)
            .frame(width: 400, height: 300)
            .padding()
    }
}
#endif
