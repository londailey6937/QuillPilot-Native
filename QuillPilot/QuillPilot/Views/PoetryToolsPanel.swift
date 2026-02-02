//
//  PoetryToolsPanel.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import SwiftUI
import Cocoa

/// A comprehensive panel containing all poetry tools
struct PoetryToolsPanel: View {
    let text: String
    @State private var selectedTool: PoetryTool = .syllables
    @State private var wordFrequencies: [WordFrequencyAnalyzer.WordFrequency] = []
    @State private var lineLengthData: [LineLengthAnalyzer.LineLengthData] = []
    @State private var isComputingWords = false
    @State private var isComputingLines = false
    @Environment(\.colorScheme) private var colorScheme

    var onInsertTemplate: ((String) -> Void)?

    enum PoetryTool: String, CaseIterable {
        case syllables = "Syllables"
        case scansion = "Scansion"
        case soundDevices = "Sound"
        case wordCloud = "Words"
        case lineGraph = "Lines"
        case formTemplates = "Forms"

        var icon: String {
            switch self {
            case .syllables: return "textformat.123"
            case .scansion: return "waveform.path"
            case .soundDevices: return "speaker.wave.3"
            case .wordCloud: return "cloud"
            case .lineGraph: return "chart.bar"
            case .formTemplates: return "text.book.closed"
            }
        }
    }

    private var lines: [String] {
        text.components(separatedBy: .newlines)
    }

    private var themeAccent: Color {
        Color(ThemeManager.shared.currentTheme.pageBorder)
    }

    private func rebuildWordFrequencies(for sourceText: String) {
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            wordFrequencies = []
            isComputingWords = false
            return
        }

        isComputingWords = true
        let snapshot = sourceText
        DispatchQueue.global(qos: .userInitiated).async {
            let computed = WordFrequencyAnalyzer.analyze(text: snapshot)
            DispatchQueue.main.async {
                if self.text == snapshot {
                    self.wordFrequencies = computed
                    self.isComputingWords = false
                }
            }
        }
    }

    private func rebuildLineLengths(for sourceText: String) {
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            lineLengthData = []
            isComputingLines = false
            return
        }

        isComputingLines = true
        let snapshot = sourceText
        DispatchQueue.global(qos: .userInitiated).async {
            let computed = LineLengthAnalyzer.analyze(text: snapshot)
            DispatchQueue.main.async {
                if self.text == snapshot {
                    self.lineLengthData = computed
                    self.isComputingLines = false
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tool selector
            HStack(spacing: 4) {
                ForEach(PoetryTool.allCases, id: \.self) { tool in
                    Button(action: { selectedTool = tool }) {
                        VStack(spacing: 2) {
                            Image(systemName: tool.icon)
                                .font(.system(size: 14))
                            Text(tool.rawValue)
                                .font(.system(size: 9))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(selectedTool == tool ? themeAccent.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))

            Divider()

            // Tool content
            ScrollView {
                toolContent
                    .padding()
            }
        }
        .onAppear {
            rebuildWordFrequencies(for: text)
            rebuildLineLengths(for: text)
        }
        .onChange(of: text) { newText in
            rebuildWordFrequencies(for: newText)
            rebuildLineLengths(for: newText)
        }
    }

    @ViewBuilder
    private var toolContent: some View {
        switch selectedTool {
        case .syllables:
            SyllableAnalysisView(lines: lines)
        case .scansion:
            ScansionView(text: text)
        case .soundDevices:
            SoundDevicesView(devices: SoundDeviceDetector.detectSoundDevices(in: lines))
        case .wordCloud:
            if isComputingWords && wordFrequencies.isEmpty {
                ProgressView("Analyzing words...")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                WordCloudView(frequencies: wordFrequencies)
            }
        case .lineGraph:
            if isComputingLines && lineLengthData.isEmpty {
                ProgressView("Measuring lines...")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                LineLengthGraphView(data: lineLengthData)
            }
        case .formTemplates:
            PoetryFormTemplateView(onInsertTemplate: onInsertTemplate)
        }
    }
}

/// Syllable analysis view showing per-line counts
struct SyllableAnalysisView: View {
    let lines: [String]
    @State private var selectedIndex: Int?

    private var syllableCounts: [(line: String, syllables: Int)] {
        SyllableCounter.syllableCountsPerLine(in: lines.joined(separator: "\n"))
    }

    private var nonEmptyCounts: [(index: Int, line: String, syllables: Int)] {
        syllableCounts.enumerated()
            .filter { !$0.element.line.isEmpty }
            .map { (index: $0.offset, line: $0.element.line, syllables: $0.element.syllables) }
    }

    private var totalSyllables: Int {
        syllableCounts.reduce(0) { $0 + $1.syllables }
    }

    private var averageSyllables: Double {
        let nonEmpty = nonEmptyCounts
        guard !nonEmpty.isEmpty else { return 0 }
        return Double(totalSyllables) / Double(nonEmpty.count)
    }

    private var detectedMeter: String {
        ScansionHelper.detectMeter(lines: lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "textformat.123")
                    .foregroundColor(.secondary)
                Text("Syllable Counter")
                    .font(.headline)
                Spacer()
            }

            // Summary stats
            HStack(spacing: 16) {
                VStack {
                    Text("\(totalSyllables)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text(String(format: "%.1f", averageSyllables))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Avg/Line")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("\(nonEmptyCounts.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Lines")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Detected meter badge
                Text(detectedMeter)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue.opacity(0.2)))
            }
            .padding(.vertical, 8)

            Divider()

            // Per-line breakdown
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(nonEmptyCounts.enumerated()), id: \.offset) { i, data in
                    HStack(alignment: .top, spacing: 8) {
                        // Line number
                        Text("\(data.index + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 24, alignment: .trailing)

                        // Syllable count
                        Text("\(data.syllables)")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(syllableColor(for: data.syllables))
                            .frame(width: 24, alignment: .center)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(syllableColor(for: data.syllables).opacity(0.15))
                            .cornerRadius(4)

                        // Line text
                        Text(data.line)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()
                    }
                    .padding(.vertical, 2)
                    .background(selectedIndex == i ? Color.accentColor.opacity(0.1) : Color.clear)
                    .cornerRadius(4)
                    .onTapGesture {
                        selectedIndex = selectedIndex == i ? nil : i
                    }
                }
            }

            // Selected line detail
            if let idx = selectedIndex, idx < nonEmptyCounts.count {
                let data = nonEmptyCounts[idx]
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Line \(data.index + 1) Details")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(data.line)
                        .font(.body)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)

                    // Word-by-word breakdown
                    let words = data.line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    HStack(spacing: 8) {
                        ForEach(words, id: \.self) { word in
                            VStack(spacing: 2) {
                                Text("\(SyllableCounter.countSyllables(in: word))")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text(word.trimmingCharacters(in: .punctuationCharacters))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func syllableColor(for count: Int) -> Color {
        switch count {
        case 0...4: return .green
        case 5...7: return .blue
        case 8...10: return .orange
        default: return .red
        }
    }
}

// MARK: - AppKit Integration

/// NSView wrapper for PoetryToolsPanel
final class PoetryToolsPanelView: NSView {
    private var hostingView: NSHostingView<PoetryToolsPanel>?

    var text: String = "" {
        didSet {
            updateContent()
        }
    }

    var onInsertTemplate: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        updateContent()
    }

    private func updateContent() {
        hostingView?.removeFromSuperview()

        let panel = PoetryToolsPanel(text: text, onInsertTemplate: onInsertTemplate)
        let hosting = NSHostingView(rootView: panel)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)

        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        hostingView = hosting
    }
}

// MARK: - Poetry Tools Window Controller

final class PoetryToolsWindowController: NSWindowController, NSWindowDelegate {

    private var text: String = ""
    var onInsertTemplate: ((String) -> Void)?

    convenience init(text: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Poetry Tools"
        window.center()
        window.isReleasedWhenClosed = false

        // Apply theme appearance
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        self.init(window: window)
        self.text = text
        window.delegate = self
        updateContent()
    }

    // Close window when it loses key status (user clicks elsewhere)
    // but NOT if a sheet is attached (modal dialog open)
    func windowDidResignKey(_ notification: Notification) {
        guard let window = window else { return }
        // Don't close if a sheet is currently presented
        if window.attachedSheet != nil {
            return
        }
        window.close()
    }

    func updateText(_ newText: String) {
        text = newText
        updateContent()
    }

    private func updateContent() {
        let panel = PoetryToolsPanel(text: text, onInsertTemplate: { [weak self] template in
            self?.onInsertTemplate?(template)
        })
        window?.contentView = FirstMouseHostingView(rootView: panel)
    }

    func showWindow(relativeTo parentWindow: NSWindow?) {
        guard let window = window else { return }

        if let parent = parentWindow {
            let parentFrame = parent.frame
            let windowFrame = window.frame
            let newOrigin = NSPoint(
                x: parentFrame.maxX + 20,
                y: parentFrame.midY - windowFrame.height / 2
            )
            window.setFrameOrigin(newOrigin)
        }

        showWindow(self)
    }
}

// MARK: - Preview

#if DEBUG
struct PoetryToolsPanel_Previews: PreviewProvider {
    static var previews: some View {
        PoetryToolsPanel(text: """
        Shall I compare thee to a summer's day?
        Thou art more lovely and more temperate:
        Rough winds do shake the darling buds of May,
        And summer's lease hath all too short a date.

        Sometime too hot the eye of heaven shines,
        And often is his gold complexion dimm'd;
        And every fair from fair sometime declines,
        By chance, or nature's changing course untrimm'd;

        But thy eternal summer shall not fade,
        Nor lose possession of that fair thou ow'st;
        Nor shall death brag thou wander'st in his shade,
        When in eternal lines to time thou grow'st:

        So long as men can breathe, or eyes can see,
        So long lives this, and this gives life to thee.
        """)
        .frame(width: 500, height: 600)
    }
}
#endif
