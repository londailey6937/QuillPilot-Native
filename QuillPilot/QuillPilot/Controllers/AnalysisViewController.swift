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
            documentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
    }

    private func setupContent() {
        contentStack = NSStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16
        contentStack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 40)

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
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        ])
    }

    func displayResults(_ results: AnalysisResults) {
        NSLog("📊 Displaying results: \(results.wordCount) words")

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
            resultsStack.addArrangedSubview(graphView)
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
        box.widthAnchor.constraint(equalToConstant: 180).isActive = true
        resultsStack.addArrangedSubview(box)
    }

    private func createSentenceGraph(_ lengths: [Int]) -> NSView {
        let graphHeight: CGFloat = 80
        let graphWidth: CGFloat = 200

        let container = NSView(frame: NSRect(x: 0, y: 0, width: graphWidth, height: graphHeight))
        container.wantsLayer = true
        container.translatesAutoresizingMaskIntoConstraints = false

        // Create bar chart
        guard !lengths.isEmpty else { return container }

        let maxLength = lengths.max() ?? 1
        let barWidth = min(graphWidth / CGFloat(lengths.count), 12.0)
        let spacing: CGFloat = 2

        for (index, length) in lengths.prefix(Int(graphWidth / (barWidth + spacing))).enumerated() {
            let barHeight = (CGFloat(length) / CGFloat(maxLength)) * (graphHeight - 20)
            let x = CGFloat(index) * (barWidth + spacing)
            let y = graphHeight - barHeight - 10

            let bar = NSView(frame: NSRect(x: x, y: y, width: barWidth, height: barHeight))
            bar.wantsLayer = true

            // Color by length: green (short), yellow (medium), red (long)
            if length < 12 {
                bar.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.6).cgColor
            } else if length < 20 {
                bar.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.6).cgColor
            } else {
                bar.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.6).cgColor
            }

            bar.layer?.cornerRadius = 2
            container.addSubview(bar)
        }

        // Add legend labels
        let legendStack = NSStackView()
        legendStack.translatesAutoresizingMaskIntoConstraints = false
        legendStack.orientation = .horizontal
        legendStack.spacing = 8
        legendStack.alignment = .centerY

        func addLegendItem(_ color: NSColor, _ label: String) {
            let dot = NSView(frame: NSRect(x: 0, y: 0, width: 8, height: 8))
            dot.wantsLayer = true
            dot.layer?.backgroundColor = color.cgColor
            dot.layer?.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true

            let text = makeLabel(label, size: 9, bold: false)
            text.textColor = .tertiaryLabelColor

            legendStack.addArrangedSubview(dot)
            legendStack.addArrangedSubview(text)
        }

        addLegendItem(NSColor.systemGreen.withAlphaComponent(0.6), "Short")
        addLegendItem(NSColor.systemYellow.withAlphaComponent(0.6), "Medium")
        addLegendItem(NSColor.systemRed.withAlphaComponent(0.6), "Long")

        container.addSubview(legendStack)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: graphHeight),
            container.widthAnchor.constraint(equalToConstant: graphWidth),
            legendStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            legendStack.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        ])

        return container
    }

    func applyTheme(_ theme: AppTheme) {
        currentTheme = theme
        view.layer?.backgroundColor = theme.analysisBackground.cgColor
        scrollView?.backgroundColor = theme.analysisBackground
    }
}
