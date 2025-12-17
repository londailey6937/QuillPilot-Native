//
//  AnalysisViewController.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class AnalysisViewController: NSViewController {

    private var scrollView: NSScrollView!
    private var documentView: NSView!
    private var contentStack: NSStackView!
    private var resultsStack: NSStackView!
    private var currentTheme: AppTheme = ThemeManager.shared.currentTheme

    var analyzeCallback: (() -> Void)?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupContent()
        applyTheme(currentTheme)
    }

    private func setupScrollView() {
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true

        documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
    }

    private func setupContent() {
        contentStack = NSStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16
        contentStack.edgeInsets = NSEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)

        // Header
        let header = makeLabel("Document Analysis", size: 18, bold: true)
        contentStack.addArrangedSubview(header)

        // Info label
        let info = makeLabel("Analysis updates automatically.", size: 13, bold: false)
        info.textColor = .secondaryLabelColor
        info.lineBreakMode = .byWordWrapping
        info.maximumNumberOfLines = 0
        contentStack.addArrangedSubview(info)

        // Results container
        resultsStack = NSStackView()
        resultsStack.translatesAutoresizingMaskIntoConstraints = false
        resultsStack.orientation = .vertical
        resultsStack.alignment = .leading
        resultsStack.spacing = 10
        contentStack.addArrangedSubview(resultsStack)

        // Initial placeholder
        let placeholder = makeLabel("Analysis will appear here as it runs.", size: 13, bold: false)
        placeholder.textColor = .secondaryLabelColor
        placeholder.lineBreakMode = .byWordWrapping
        placeholder.maximumNumberOfLines = 0
        resultsStack.addArrangedSubview(placeholder)

        documentView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -20)
        ])

        // Ensure documentView height grows with content
        contentStack.setContentHuggingPriority(.defaultHigh, for: .vertical)
    }

    func displayResults(_ results: AnalysisResults) {
        NSLog("📊 Displaying results: \(results.wordCount) words")

        // Scroll to top first
        scrollView?.documentView?.scroll(NSPoint.zero)

        // Clear previous results
        resultsStack.arrangedSubviews.forEach { view in
            resultsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard results.wordCount > 0 else {
            let msg = makeLabel("No content to analyze.", size: 13, bold: false)
            msg.textColor = .secondaryLabelColor
            resultsStack.addArrangedSubview(msg)
            return
        }

        // Basic stats
        addStat("Words", "\(results.wordCount)")
        addStat("Sentences", "\(results.sentenceCount)")
        addStat("Reading Level", results.readingLevel)
        addDivider()

        // Paragraph analysis
        addHeader("📊 Paragraphs")
        addStat("Avg Length", "\(results.averageParagraphLength) words")
        addStat("Dialogue", "\(results.dialoguePercentage)%")
        if !results.longParagraphs.isEmpty {
            addWarning("⚠️ \(results.longParagraphs.count) long paragraph(s)")
        }
        addDivider()

        // Passive voice
        addHeader("🔍 Passive Voice")
        if results.passiveVoiceCount > 0 {
            addWarning("Found \(results.passiveVoiceCount) instance(s)")
            for phrase in results.passiveVoicePhrases.prefix(3) {
                addDetail("• \"\(phrase)\"")
            }
        } else {
            addSuccess("✓ None detected")
        }
        addDivider()

        // Adverbs
        addHeader("🐢 Adverbs")
        if results.adverbCount > 0 {
            addWarning("Found \(results.adverbCount)")
            for phrase in results.adverbPhrases.prefix(3) {
                addDetail("• \"\(phrase)\"")
            }
        } else {
            addSuccess("✓ Minimal usage")
        }
        addDivider()

        // Sensory details
        addHeader("🌟 Sensory Details")
        addStat("Count", "\(results.sensoryDetailCount)")
        if results.wordCount == 0 {
            // Don't show any message for empty documents
        } else if results.missingSensoryDetail {
            addWarning("Consider adding more")
        } else {
            addSuccess("✓ Good usage")
        }
        addDivider()

        // Weak verbs
        addHeader("💪 Weak Verbs")
        if results.weakVerbCount > 0 {
            addWarning("Found \(results.weakVerbCount) instance(s)")
            for phrase in results.weakVerbPhrases.prefix(5) {
                addDetail("• \"\(phrase)\"")
            }
            addDetail("Tip: Use stronger, more specific verbs")
        } else {
            addSuccess("✓ Minimal usage")
        }
        addDivider()

        // Clichés
        addHeader("🚫 Clichés")
        if results.clicheCount > 0 {
            addWarning("Found \(results.clicheCount) cliché(s)")
            for phrase in results.clichePhrases.prefix(3) {
                addDetail("• \"\(phrase)\"")
            }
            addDetail("Tip: Replace with original descriptions")
        } else {
            addSuccess("✓ None detected")
        }
        addDivider()

        // Filter words
        addHeader("🔍 Filter Words")
        if results.filterWordCount > 0 {
            addWarning("Found \(results.filterWordCount) instance(s)")
            for phrase in results.filterWordPhrases.prefix(5) {
                addDetail("• \"\(phrase)\"")
            }
            addDetail("Tip: Show directly instead of filtering through perception")
        } else {
            addSuccess("✓ Minimal usage")
        }
        addDivider()

        // Sentence variety with graph
        addHeader("📊 Sentence Variety")
        addStat("Score", "\(results.sentenceVarietyScore)%")
        if !results.sentenceLengths.isEmpty {
            let graphView = createSentenceGraph(results.sentenceLengths)

            // Wrap in container to ensure proper spacing and visibility
            let graphContainer = NSView()
            graphContainer.translatesAutoresizingMaskIntoConstraints = false
            graphContainer.addSubview(graphView)

            NSLayoutConstraint.activate([
                graphView.topAnchor.constraint(equalTo: graphContainer.topAnchor, constant: 8),
                graphView.leadingAnchor.constraint(equalTo: graphContainer.leadingAnchor),
                graphView.bottomAnchor.constraint(equalTo: graphContainer.bottomAnchor, constant: -8)
            ])

            resultsStack.addArrangedSubview(graphContainer)
        }
        if results.sentenceVarietyScore < 40 {
            addWarning("Low variety - mix short and long sentences")
        } else if results.sentenceVarietyScore < 70 {
            addDetail("Good variety - consider adding more variation")
        } else {
            addSuccess("✓ Excellent variety")
        }
    }

    private func makeLabel(_ text: String, size: CGFloat, bold: Bool) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.isEditable = false
        label.isBezeled = false
        label.drawsBackground = false
        label.isSelectable = false
        label.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
        label.textColor = .labelColor
        return label
    }

    private func addHeader(_ text: String) {
        let label = makeLabel(text, size: 14, bold: true)
        resultsStack.addArrangedSubview(label)
    }

    private func addStat(_ name: String, _ value: String) {
        let label = makeLabel("\(name): \(value)", size: 12, bold: false)
        label.textColor = .secondaryLabelColor
        resultsStack.addArrangedSubview(label)
    }

    private func addWarning(_ text: String) {
        let label = makeLabel(text, size: 12, bold: false)
        label.textColor = .systemOrange
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        resultsStack.addArrangedSubview(label)
    }

    private func addSuccess(_ text: String) {
        let label = makeLabel(text, size: 12, bold: false)
        label.textColor = .systemGreen
        resultsStack.addArrangedSubview(label)
    }

    private func addDetail(_ text: String) {
        let label = makeLabel(text, size: 11, bold: false)
        label.textColor = .tertiaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        resultsStack.addArrangedSubview(label)
    }

    private func addDivider() {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        resultsStack.addArrangedSubview(box)

        // Make divider span the full width of resultsStack
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: resultsStack.leadingAnchor),
            box.trailingAnchor.constraint(equalTo: resultsStack.trailingAnchor)
        ])
    }

    private func createSentenceGraph(_ lengths: [Int]) -> NSView {
        // Make graph responsive to panel width
        let availableWidth = view.frame.width > 0 ? view.frame.width - 32 : 280
        let graphWidth = min(max(availableWidth, 240), 400)  // Between 240-400px
        let graphHeight: CGFloat = 180

        let container = NSView(frame: NSRect(x: 0, y: 0, width: graphWidth, height: graphHeight))
        container.wantsLayer = true
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer?.backgroundColor = currentTheme.textColor.withAlphaComponent(0.08).cgColor
        container.layer?.cornerRadius = 8

        // Create bar chart
        guard !lengths.isEmpty else {
            NSLayoutConstraint.activate([
                container.heightAnchor.constraint(equalToConstant: graphHeight),
                container.widthAnchor.constraint(equalToConstant: graphWidth)
            ])

            // Add "No data" label
            let noDataLabel = makeLabel("Not enough sentences", size: 11, bold: false)
            noDataLabel.textColor = .tertiaryLabelColor
            noDataLabel.frame = NSRect(x: 10, y: graphHeight/2 - 10, width: graphWidth - 20, height: 20)
            container.addSubview(noDataLabel)

            return container
        }

        let maxLength = lengths.max() ?? 1
        let barWidth: CGFloat = max(4.0, min(graphWidth / CGFloat(lengths.count), 12.0))
        let spacing: CGFloat = 2
        let chartWidth = graphWidth - 20
        let maxBars = Int(chartWidth / (barWidth + spacing))
        let chartHeight = graphHeight - 35  // Space for legend at bottom

        // Draw bars directly on container
        for (index, length) in lengths.prefix(maxBars).enumerated() {
            let barHeight = max(4, (CGFloat(length) / CGFloat(maxLength)) * (chartHeight - 10))
            let x = 10 + CGFloat(index) * (barWidth + spacing)
            let y: CGFloat = 25  // Start from bottom, bars grow upward

            let bar = NSView(frame: NSRect(x: x, y: y, width: barWidth, height: barHeight))
            bar.wantsLayer = true

            // Color by length: green (short), yellow (medium), red (long)
            if length < 12 {
                bar.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.85).cgColor
            } else if length < 20 {
                bar.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.85).cgColor
            } else {
                bar.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.85).cgColor
            }

            bar.layer?.cornerRadius = 2
            container.addSubview(bar)
        }

        // Add legend labels at bottom
        let legendY: CGFloat = 8
        let legendX: CGFloat = 10

        func addLegendItem(_ color: NSColor, _ label: String, xOffset: CGFloat) {
            let dot = NSView(frame: NSRect(x: legendX + xOffset, y: legendY, width: 7, height: 7))
            dot.wantsLayer = true
            dot.layer?.backgroundColor = color.cgColor
            dot.layer?.cornerRadius = 3.5
            container.addSubview(dot)

            let text = NSTextField(labelWithString: label)
            text.isEditable = false
            text.isBezeled = false
            text.drawsBackground = false
            text.font = .systemFont(ofSize: 10)
            text.textColor = .secondaryLabelColor
            text.frame = NSRect(x: legendX + xOffset + 10, y: legendY - 2, width: 50, height: 14)
            container.addSubview(text)
        }

        addLegendItem(NSColor.systemGreen.withAlphaComponent(0.85), "Short (<12)", xOffset: 0)
        addLegendItem(NSColor.systemYellow.withAlphaComponent(0.85), "Medium (12-20)", xOffset: 80)
        addLegendItem(NSColor.systemRed.withAlphaComponent(0.85), "Long (20+)", xOffset: 180)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: graphHeight),
            container.widthAnchor.constraint(equalToConstant: graphWidth)
        ])

        return container
    }

    func applyTheme(_ theme: AppTheme) {
        currentTheme = theme
        view.layer?.backgroundColor = theme.analysisBackground.cgColor
        scrollView?.backgroundColor = theme.analysisBackground
    }
}
