//
//  AnalysisViewController.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa
import ObjectiveC

private class FlippedClipView: NSView {
    override var isFlipped: Bool { true }
}

private var themedLabelColorKey: UInt8 = 0

private extension NSTextField {
    var themedHexColor: String? {
        get { objc_getAssociatedObject(self, &themedLabelColorKey) as? String }
        set { objc_setAssociatedObject(self, &themedLabelColorKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC) }
    }
}

class AnalysisViewController: NSViewController {

    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var documentView: FlippedClipView!
    private var currentTheme: AppTheme = ThemeManager.shared.currentTheme

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true

        documentView = FlippedClipView()
        documentView.wantsLayer = true

        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 16
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let headerLabel = createLabel("Analysis Results", fontSize: 18, bold: true, color: "#2c3e50")
        stackView.addArrangedSubview(headerLabel)

        let placeholderLabel = createLabel("Write some text and click Analyze to see results here.",
                                           fontSize: 14,
                                           bold: false,
                                           color: "#6b7280")
        placeholderLabel.maximumNumberOfLines = 0
        stackView.addArrangedSubview(placeholderLabel)

        documentView.addSubview(stackView)
        scrollView.documentView = documentView
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        view.wantsLayer = true
        updateStackViewFrame()
        applyTheme(currentTheme)
    }

    private func updateStackViewFrame() {
        let scrollWidth = scrollView.contentView.bounds.width
        let fittingSize = stackView.fittingSize
        stackView.frame = NSRect(x: 0, y: 0, width: scrollWidth, height: fittingSize.height)
        documentView.frame = NSRect(x: 0, y: 0, width: scrollWidth, height: fittingSize.height)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateStackViewFrame()
    }

    func displayResults(_ results: AnalysisResults) {
        while stackView.arrangedSubviews.count > 1 {
            if let view = stackView.arrangedSubviews.last {
                stackView.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
        }

        addStatistic("Total Words", value: "\(results.wordCount)")
        addStatistic("Total Sentences", value: "\(results.sentenceCount)")
        addSeparator()

        addSectionHeader("📊 Paragraph Analysis")
        addStatistic("Average Length", value: "\(results.averageParagraphLength) words")
        if !results.longParagraphs.isEmpty {
            addWarning("⚠️ \(results.longParagraphs.count) paragraph(s) may be too long (>150 words)", color: "#f97316")
        }
        addSeparator()

        addSectionHeader("🔍 Passive Voice")
        if results.passiveVoiceCount > 0 {
            addWarning("Found \(results.passiveVoiceCount) instance(s) of passive voice", color: "#8b5cf6")
            for phrase in results.passiveVoicePhrases.prefix(5) {
                addBulletPoint("• \"\(phrase)\"")
            }
        } else {
            addSuccess("✓ No passive voice detected")
        }
        addSeparator()

        addSectionHeader("🌟 Sensory Details")
        addStatistic("Sensory Words", value: "\(results.sensoryDetailCount)")
        if results.missingSensoryDetail {
            addWarning("Consider adding more sensory details to engage readers", color: "#eab308")
        } else {
            addSuccess("✓ Good use of sensory language")
        }

        DispatchQueue.main.async { [weak self] in
            self?.updateStackViewFrame()
        }
    }

    private func addSectionHeader(_ text: String) {
        let label = createLabel(text, fontSize: 15, bold: true, color: "#2c3e50")
        stackView.addArrangedSubview(label)
    }

    private func addStatistic(_ label: String, value: String) {
        let text = "\(label): \(value)"
        let labelView = createLabel(text, fontSize: 13, bold: false, color: "#374151")
        stackView.addArrangedSubview(labelView)
    }

    private func addWarning(_ text: String, color: String) {
        let label = createLabel(text, fontSize: 13, bold: false, color: color)
        label.maximumNumberOfLines = 0
        stackView.addArrangedSubview(label)
    }

    private func addSuccess(_ text: String) {
        let label = createLabel(text, fontSize: 13, bold: false, color: "#10b981")
        stackView.addArrangedSubview(label)
    }

    private func addBulletPoint(_ text: String) {
        let label = createLabel(text, fontSize: 12, bold: false, color: "#6b7280")
        label.maximumNumberOfLines = 0
        stackView.addArrangedSubview(label)
    }

    private func addSeparator() {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalToConstant: 200).isActive = true
        stackView.addArrangedSubview(separator)
    }

    private func createLabel(_ text: String, fontSize: CGFloat, bold: Bool, color: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.isEditable = false
        label.isBezeled = false
        label.drawsBackground = false
        label.isSelectable = false
        label.font = bold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        label.themedHexColor = color
        label.textColor = resolvedColor(for: color)
        return label
    }

    private func resolvedColor(for hex: String) -> NSColor {
        guard let baseColor = NSColor(hex: hex) else { return currentTheme.textColor }
        if currentTheme == .day {
            return baseColor
        }
        return baseColor.blended(withFraction: 0.45, of: .white) ?? currentTheme.textColor
    }

    private func refreshLabelColors(in view: NSView) {
        if let label = view as? NSTextField {
            let hex = label.themedHexColor ?? "#2c3e50"
            label.textColor = resolvedColor(for: hex)
        }
        view.subviews.forEach { refreshLabelColors(in: $0) }
    }

    func applyTheme(_ theme: AppTheme) {
        currentTheme = theme
        view.wantsLayer = true
        view.layer?.backgroundColor = theme.analysisBackground.cgColor
        scrollView?.backgroundColor = theme.analysisBackground
        documentView?.layer?.backgroundColor = theme.analysisBackground.cgColor
        refreshLabelColors(in: stackView)
    }
}
