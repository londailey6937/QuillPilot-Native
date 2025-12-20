//
//  AnalysisViewController.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class AnalysisViewController: NSViewController {

    private var menuSidebar: NSView!
    private var menuSeparator: NSView!
    private var menuButtons: [NSButton] = []
    private var scrollContainer: NSView!
    private var scrollView: NSScrollView!
    private var documentView: NSView!
    private var contentStack: NSStackView!
    private var resultsStack: NSStackView!
    private var currentTheme: AppTheme = ThemeManager.shared.currentTheme
    private var currentCategory: AnalysisCategory = .basic

    // Character Library Window
    private var characterLibraryWindow: CharacterLibraryWindowController?

    var outlineViewController: OutlineViewController?
    var isOutlinePanel: Bool = false
    var analyzeCallback: (() -> Void)?

    enum AnalysisCategory: String, CaseIterable {
        case basic = "Outline"
        case advanced = "Advanced"
        case characters = "Characters"
        case plot = "Plot"

        var icon: String {
            switch self {
            case .basic: return "📝"
            case .advanced: return "🔬"
            case .characters: return "👥"
            case .plot: return "📖"
            }
        }
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSidebarMenu()
        setupScrollView()
        setupContent()
        applyTheme(currentTheme)
        switchToCategory(currentCategory)

        // Listen for theme changes
        NotificationCenter.default.addObserver(forName: .themeDidChange, object: nil, queue: .main) { [weak self] notification in
            if let theme = notification.object as? AppTheme {
                self?.applyTheme(theme)
            }
        }
    }

    private func setupSidebarMenu() {
        menuSidebar = NSView()
        menuSidebar.translatesAutoresizingMaskIntoConstraints = false
        menuSidebar.wantsLayer = true
        view.addSubview(menuSidebar)

        menuSeparator = NSView()
        menuSeparator.translatesAutoresizingMaskIntoConstraints = false
        menuSeparator.wantsLayer = true
        view.addSubview(menuSeparator)

        // Create menu buttons
        var yPosition: CGFloat = 12
        for category in AnalysisCategory.allCases {
            let button = NSButton(frame: NSRect(x: 0, y: 0, width: 44, height: 44))
            button.title = category.icon
            button.font = .systemFont(ofSize: 20)
            button.isBordered = false
            button.bezelStyle = .rounded
            button.target = self
            button.action = #selector(categoryButtonTapped(_:))
            button.tag = AnalysisCategory.allCases.firstIndex(of: category) ?? 0
            button.translatesAutoresizingMaskIntoConstraints = false
            button.toolTip = category.rawValue

            menuSidebar.addSubview(button)
            menuButtons.append(button)

            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: menuSidebar.topAnchor, constant: yPosition),
                button.centerXAnchor.constraint(equalTo: menuSidebar.centerXAnchor),
                button.widthAnchor.constraint(equalToConstant: 44),
                button.heightAnchor.constraint(equalToConstant: 44)
            ])

            yPosition += 52
        }

        if isOutlinePanel {
            NSLayoutConstraint.activate([
                menuSidebar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                menuSidebar.topAnchor.constraint(equalTo: view.topAnchor),
                menuSidebar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                menuSidebar.widthAnchor.constraint(equalToConstant: 56),

                menuSeparator.trailingAnchor.constraint(equalTo: menuSidebar.leadingAnchor),
                menuSeparator.topAnchor.constraint(equalTo: view.topAnchor),
                menuSeparator.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                menuSeparator.widthAnchor.constraint(equalToConstant: 1)
            ])
        } else {
            NSLayoutConstraint.activate([
                menuSidebar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                menuSidebar.topAnchor.constraint(equalTo: view.topAnchor),
                menuSidebar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                menuSidebar.widthAnchor.constraint(equalToConstant: 56),

                menuSeparator.leadingAnchor.constraint(equalTo: menuSidebar.trailingAnchor),
                menuSeparator.topAnchor.constraint(equalTo: view.topAnchor),
                menuSeparator.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                menuSeparator.widthAnchor.constraint(equalToConstant: 1)
            ])
        }

        updateSelectedButton()
    }

    @objc private func categoryButtonTapped(_ sender: NSButton) {
        let category = AnalysisCategory.allCases[sender.tag]
        currentCategory = category
        updateSelectedButton()
        switchToCategory(category)
    }

    @objc private func updateButtonTapped() {
        NSLog("🔄 Update button tapped in analysis panel")
        analyzeCallback?()
    }

    private func updateSelectedButton() {
        for (index, button) in menuButtons.enumerated() {
            if index == AnalysisCategory.allCases.firstIndex(of: currentCategory) {
                button.layer?.backgroundColor = currentTheme.headerBackground.withAlphaComponent(0.3).cgColor
                button.layer?.cornerRadius = 8
            } else {
                button.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
    }

    private func switchToCategory(_ category: AnalysisCategory) {
        currentCategory = category

        let showOutline = isOutlinePanel && category == .basic
        let showCharacters = category == .characters

        if showOutline {
            // Show outline, hide analysis content
            scrollContainer.isHidden = true
            if let outlineVC = outlineViewController {
                if outlineVC.view.superview == nil {
                    view.addSubview(outlineVC.view)
                    outlineVC.view.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        outlineVC.view.topAnchor.constraint(equalTo: view.topAnchor),
                        outlineVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                        outlineVC.view.trailingAnchor.constraint(equalTo: menuSeparator.leadingAnchor),
                        outlineVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                    ])
                }
                outlineVC.view.isHidden = false
            }
            // Trigger a refresh of the outline data when opened via the top button
            NotificationCenter.default.post(name: Notification.Name("QuillPilotOutlineRefresh"), object: nil)
            updateSelectedButton()
            return
        }

        if showCharacters {
            // Open Character Library window
            if characterLibraryWindow == nil {
                characterLibraryWindow = CharacterLibraryWindowController()
            }
            characterLibraryWindow?.showWindow(nil)
            characterLibraryWindow?.window?.makeKeyAndOrderFront(nil)

            // Switch back to the previous category so the button doesn't stay selected
            let previousCategory: AnalysisCategory = (currentCategory == .characters) ? .basic : currentCategory
            switchToCategory(previousCategory)
            return
        }

        // Show analysis content, hide outline
        scrollContainer.isHidden = false
        outlineViewController?.view.isHidden = true

        // Clear current analysis content
        resultsStack.arrangedSubviews.forEach { view in
            resultsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if !isOutlinePanel && category == .basic {
            // Restore basic analysis - trigger a re-analysis
            analyzeCallback?()
        } else {
            // Add placeholder for non-basic categories
            let placeholder = makeLabel("\(category.icon) \(category.rawValue) Analysis\n\nComing soon...", size: 16, bold: true)
            placeholder.alignment = .center
            placeholder.textColor = .secondaryLabelColor
            placeholder.maximumNumberOfLines = 0
            resultsStack.addArrangedSubview(placeholder)
        }

        updateSelectedButton()
    }

    private func setupScrollView() {
        // Outer container - transparent, no styling (contentStack provides the card)
        scrollContainer = NSView()
        scrollContainer.translatesAutoresizingMaskIntoConstraints = false
        scrollContainer.wantsLayer = true
        scrollContainer.layer?.backgroundColor = NSColor.clear.cgColor

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = NSColor.clear.cgColor
        scrollView.contentView.drawsBackground = false
        scrollView.verticalScroller?.isHidden = true
        scrollView.horizontalScroller?.isHidden = true

        // Performance optimizations for scrolling
        scrollView.usesPredominantAxisScrolling = false
        scrollView.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        // Clip view stays transparent
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.layer?.cornerRadius = 0
        scrollView.contentView.layer?.masksToBounds = false
        scrollView.contentView.layer?.backgroundColor = NSColor.clear.cgColor

        documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.wantsLayer = true
        documentView.layer?.backgroundColor = NSColor.clear.cgColor
        scrollView.documentView = documentView

        scrollContainer.addSubview(scrollView)
        view.addSubview(scrollContainer)

        let containerConstraints: [NSLayoutConstraint]
        if isOutlinePanel {
            containerConstraints = [
                scrollContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
                scrollContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
                scrollContainer.trailingAnchor.constraint(equalTo: menuSeparator.leadingAnchor, constant: 0),
                scrollContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
            ]
        } else {
            containerConstraints = [
                scrollContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
                scrollContainer.leadingAnchor.constraint(equalTo: menuSeparator.trailingAnchor, constant: 0),
                scrollContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
                scrollContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
            ]
        }

        NSLayoutConstraint.activate(containerConstraints + [
            scrollView.topAnchor.constraint(equalTo: scrollContainer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: scrollContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: scrollContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: scrollContainer.bottomAnchor),

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
        contentStack.edgeInsets = NSEdgeInsets(top: 24, left: 32, bottom: 24, right: 8)
        contentStack.wantsLayer = true

        // Set background and corner radius so the card shows its rounding
        if let layer = contentStack.layer {
            layer.backgroundColor = currentTheme.toolbarBackground.cgColor
            layer.cornerRadius = 12
            layer.masksToBounds = true
        }

        // Header with update button
        let headerContainer = NSStackView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.orientation = .horizontal
        headerContainer.spacing = 12
        headerContainer.alignment = .centerY

        let header = makeLabel("Document Analysis", size: 18, bold: true)
        headerContainer.addArrangedSubview(header)

        let updateButton = NSButton(title: "Update", target: self, action: #selector(updateButtonTapped))
        updateButton.bezelStyle = .rounded
        updateButton.controlSize = .small
        updateButton.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addArrangedSubview(updateButton)

        contentStack.addArrangedSubview(headerContainer)

        // Info label
        let info = makeLabel("Click Update to refresh all analysis.", size: 13, bold: false)
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
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -32)
        ])

        // Ensure documentView height grows with content
        contentStack.setContentHuggingPriority(.defaultHigh, for: .vertical)
    }

    func displayResults(_ results: AnalysisResults) {
        NSLog("📊 Displaying results: \(results.wordCount) words")

        // Scroll to top first
        scrollView?.documentView?.scroll(NSPoint.zero)


        // Only display if we're on the basic category
        guard currentCategory == .basic else { return }
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
        addStat("Count", "\(results.paragraphCount)")
        addStat("Pages", "~\(results.pageCount)")
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
        let panelBackground = isOutlinePanel ? theme.outlineBackground : theme.toolbarBackground

        // Ensure all views are layer-backed and apply backgrounds
        view.wantsLayer = true
        view.layer?.backgroundColor = panelBackground.cgColor

        menuSidebar?.wantsLayer = true
        menuSidebar?.layer?.backgroundColor = theme.toolbarBackground.cgColor

        menuSeparator?.wantsLayer = true
        menuSeparator?.layer?.backgroundColor = theme.toolbarBackground.withAlphaComponent(0.3).cgColor

        scrollContainer?.wantsLayer = true
        scrollContainer?.layer?.backgroundColor = panelBackground.cgColor

        scrollView?.wantsLayer = true
        scrollView?.drawsBackground = false
        scrollView?.backgroundColor = .clear
        scrollView?.layer?.backgroundColor = NSColor.clear.cgColor

        documentView?.wantsLayer = true
        documentView?.layer?.backgroundColor = NSColor.clear.cgColor

        contentStack?.wantsLayer = true
        contentStack?.layer?.backgroundColor = panelBackground.cgColor

        // Force redisplay
        view.needsDisplay = true
        view.displayIfNeeded()

        outlineViewController?.applyTheme(theme)
        updateSelectedButton()
    }
}

// MARK: - Character Library View Controller

class CharacterLibraryViewController: NSViewController {

    private var scrollView: NSScrollView!
    private var contentStack: NSStackView!
    private var characterListStack: NSStackView!
    private var detailView: NSView!
    private var currentTheme: AppTheme = ThemeManager.shared.currentTheme
    private var selectedCharacter: CharacterProfile?
    private var isEditing = false

    // Detail view controls
    private var detailScrollView: NSScrollView!
    private var detailContentStack: NSStackView!
    private var nameField: NSTextField!
    private var nicknameField: NSTextField!
    private var rolePopup: NSPopUpButton!
    private var ageField: NSTextField!
    private var occupationField: NSTextField!
    private var appearanceField: NSTextView!
    private var backgroundField: NSTextView!
    private var educationField: NSTextField!
    private var residenceField: NSTextField!
    private var familyField: NSTextView!
    private var petsField: NSTextField!
    private var traitsField: NSTextView!
    private var principlesField: NSTextView!
    private var skillsField: NSTextView!
    private var motivationsField: NSTextView!
    private var weaknessesField: NSTextView!
    private var connectionsField: NSTextView!
    private var quotesField: NSTextView!
    private var notesField: NSTextView!

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        applyTheme(currentTheme)
        refreshCharacterList()

        NotificationCenter.default.addObserver(forName: .characterLibraryDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.refreshCharacterList()
        }

        NotificationCenter.default.addObserver(forName: .themeDidChange, object: nil, queue: .main) { [weak self] notification in
            if let theme = notification.object as? AppTheme {
                self?.applyTheme(theme)
            }
        }
    }

    private func setupUI() {
        let splitContainer = NSStackView()
        splitContainer.translatesAutoresizingMaskIntoConstraints = false
        splitContainer.orientation = .horizontal
        splitContainer.spacing = 1
        splitContainer.distribution = .fill
        view.addSubview(splitContainer)

        let listPanel = createCharacterListPanel()
        listPanel.translatesAutoresizingMaskIntoConstraints = false
        splitContainer.addArrangedSubview(listPanel)

        let separator = NSView()
        separator.wantsLayer = true
        separator.translatesAutoresizingMaskIntoConstraints = false
        splitContainer.addArrangedSubview(separator)

        detailView = createDetailPanel()
        detailView.translatesAutoresizingMaskIntoConstraints = false
        splitContainer.addArrangedSubview(detailView)

        NSLayoutConstraint.activate([
            splitContainer.topAnchor.constraint(equalTo: view.topAnchor),
            splitContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            listPanel.widthAnchor.constraint(equalToConstant: 200),
            separator.widthAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func createCharacterListPanel() -> NSView {
        let container = NSView()
        container.wantsLayer = true

        let header = NSStackView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.orientation = .horizontal
        header.spacing = 8
        header.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        let titleLabel = NSTextField(labelWithString: "📚 Characters")
        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.textColor = .labelColor
        header.addArrangedSubview(titleLabel)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        header.addArrangedSubview(spacer)

        let addButton = NSButton(title: "+", target: self, action: #selector(addCharacterTapped))
        addButton.bezelStyle = .rounded
        addButton.font = .boldSystemFont(ofSize: 14)
        addButton.toolTip = "Add New Character"
        header.addArrangedSubview(addButton)

        container.addSubview(header)

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        characterListStack = NSStackView()
        characterListStack.translatesAutoresizingMaskIntoConstraints = false
        characterListStack.orientation = .vertical
        characterListStack.alignment = .leading
        characterListStack.spacing = 4
        characterListStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(characterListStack)

        scrollView.documentView = documentView
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 40),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            characterListStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            characterListStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            characterListStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            characterListStack.bottomAnchor.constraint(lessThanOrEqualTo: documentView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        return container
    }

    private func createDetailPanel() -> NSView {
        let container = NSView()
        container.wantsLayer = true

        detailScrollView = NSScrollView()
        detailScrollView.translatesAutoresizingMaskIntoConstraints = false
        detailScrollView.hasVerticalScroller = true
        detailScrollView.hasHorizontalScroller = false
        detailScrollView.autohidesScrollers = true
        detailScrollView.borderType = .noBorder
        detailScrollView.drawsBackground = false

        detailContentStack = NSStackView()
        detailContentStack.translatesAutoresizingMaskIntoConstraints = false
        detailContentStack.orientation = .vertical
        detailContentStack.alignment = .leading
        detailContentStack.spacing = 16
        detailContentStack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(detailContentStack)

        detailScrollView.documentView = documentView
        container.addSubview(detailScrollView)

        NSLayoutConstraint.activate([
            detailScrollView.topAnchor.constraint(equalTo: container.topAnchor),
            detailScrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            detailScrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            detailScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            detailContentStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            detailContentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            detailContentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            detailContentStack.bottomAnchor.constraint(lessThanOrEqualTo: documentView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: detailScrollView.widthAnchor)
        ])

        showPlaceholder()
        return container
    }

    private func showPlaceholder() {
        detailContentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let placeholder = NSTextField(labelWithString: "Select a character to view details\nor click + to create a new one")
        placeholder.alignment = .center
        placeholder.textColor = .secondaryLabelColor
        placeholder.font = .systemFont(ofSize: 14)
        placeholder.maximumNumberOfLines = 0
        placeholder.lineBreakMode = .byWordWrapping
        detailContentStack.addArrangedSubview(placeholder)
    }

    private func refreshCharacterList() {
        characterListStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let characters = CharacterLibrary.shared.characters
        let grouped = Dictionary(grouping: characters) { $0.role }
        let roleOrder: [CharacterRole] = [.protagonist, .antagonist, .supporting, .minor]

        for role in roleOrder {
            guard let chars = grouped[role], !chars.isEmpty else { continue }
            let roleHeader = NSTextField(labelWithString: role.rawValue)
            roleHeader.font = NSFont.boldSystemFont(ofSize: 11)
            roleHeader.textColor = role.color
            roleHeader.translatesAutoresizingMaskIntoConstraints = false
            characterListStack.addArrangedSubview(roleHeader)

            for character in chars {
                let button = createCharacterButton(for: character)
                characterListStack.addArrangedSubview(button)
            }

            let spacer = NSView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
            characterListStack.addArrangedSubview(spacer)
        }
    }

    private func createCharacterButton(for character: CharacterProfile) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.cornerRadius = 6

        let isSelected = selectedCharacter?.id == character.id
        container.layer?.backgroundColor = isSelected
            ? currentTheme.headerBackground.withAlphaComponent(0.3).cgColor
            : NSColor.clear.cgColor

        let button = NSButton(title: "", target: self, action: #selector(characterTapped(_:)))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.alignment = .left
        button.tag = CharacterLibrary.shared.characters.firstIndex(where: { $0.id == character.id }) ?? 0

        let displayName = character.fullName.isEmpty ? "New Character" : character.fullName
        let attrTitle = NSMutableAttributedString(string: "● ", attributes: [
            .foregroundColor: character.role.color,
            .font: NSFont.systemFont(ofSize: 8)
        ])
        attrTitle.append(NSAttributedString(string: displayName, attributes: [
            .foregroundColor: currentTheme.textColor,
            .font: NSFont.systemFont(ofSize: 12)
        ]))
        button.attributedTitle = attrTitle

        container.addSubview(button)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            container.heightAnchor.constraint(equalToConstant: 28),
            container.widthAnchor.constraint(equalToConstant: 180)
        ])

        return container
    }

    @objc private func characterTapped(_ sender: NSButton) {
        let characters = CharacterLibrary.shared.characters
        guard sender.tag < characters.count else { return }
        let character = characters[sender.tag]

        if character.isSampleCharacter {
            var cleared = CharacterLibrary.shared.createNewCharacter()
            cleared.id = character.id
            cleared.role = character.role
            selectedCharacter = cleared
            CharacterLibrary.shared.updateCharacter(cleared)
        } else {
            selectedCharacter = character
        }

        refreshCharacterList()
        showCharacterDetail()
    }

    @objc private func addCharacterTapped() {
        let newCharacter = CharacterLibrary.shared.createNewCharacter()
        CharacterLibrary.shared.addCharacter(newCharacter)
        selectedCharacter = newCharacter
        refreshCharacterList()
        showCharacterDetail()
    }

    private func showCharacterDetail() {
        guard let character = selectedCharacter else {
            showPlaceholder()
            return
        }

        detailContentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .centerY
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: character.displayName.isEmpty ? "New Character" : character.displayName)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = character.role.color
        headerStack.addArrangedSubview(titleLabel)

        let spacer = NSView()
        headerStack.addArrangedSubview(spacer)

        let deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteCharacterTapped))
        deleteButton.bezelStyle = .rounded
        deleteButton.controlSize = .small
        headerStack.addArrangedSubview(deleteButton)

        detailContentStack.addArrangedSubview(headerStack)

        addSection("Basic Info")
        nameField = addTextField("Full Name", value: character.fullName)
        nicknameField = addTextField("Nickname", value: character.nickname)
        rolePopup = addRolePopup("Role", selected: character.role)
        ageField = addTextField("Age", value: character.age)
        occupationField = addTextField("Occupation", value: character.occupation)

        addSection("Physical & Living")
        appearanceField = addTextArea("Appearance", value: character.appearance, height: 60)
        residenceField = addTextField("Residence", value: character.residence)
        petsField = addTextField("Pets", value: character.pets)

        addSection("Background")
        backgroundField = addTextArea("Background Story", value: character.background, height: 100)
        educationField = addTextField("Education", value: character.education)
        familyField = addTextArea("Family", value: character.family, height: 60)

        addSection("Personality")
        traitsField = addTextArea("Personality Traits (one per line)", value: character.personalityTraits.joined(separator: "\n"), height: 80)
        principlesField = addTextArea("Principles / Beliefs (one per line)", value: character.principles.joined(separator: "\n"), height: 80)

        addSection("Abilities")
        skillsField = addTextArea("Skills (one per line)", value: character.skills.joined(separator: "\n"), height: 100)

        addSection("Motivation & Conflict")
        motivationsField = addTextArea("Motivations", value: character.motivations, height: 60)
        weaknessesField = addTextArea("Weaknesses", value: character.weaknesses, height: 60)
        connectionsField = addTextArea("Connections / Relationships", value: character.connections, height: 60)

        addSection("Voice")
        quotesField = addTextArea("Characteristic Quotes (one per line)", value: character.quotes.joined(separator: "\n"), height: 80)

        addSection("Notes")
        notesField = addTextArea("Additional Notes", value: character.notes, height: 80)

        let saveButton = NSButton(title: "Save Changes", target: self, action: #selector(saveCharacterTapped))
        saveButton.bezelStyle = .rounded
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        detailContentStack.addArrangedSubview(saveButton)

        NSLayoutConstraint.activate([
            headerStack.widthAnchor.constraint(equalTo: detailContentStack.widthAnchor, constant: -32)
        ])
    }

    private func addSection(_ title: String) {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        detailContentStack.addArrangedSubview(spacer)

        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: 13)
        label.textColor = currentTheme.headerBackground
        detailContentStack.addArrangedSubview(label)

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        detailContentStack.addArrangedSubview(divider)
        divider.widthAnchor.constraint(equalTo: detailContentStack.widthAnchor, constant: -32).isActive = true
    }

    private func addTextField(_ label: String, value: String) -> NSTextField {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 8
        container.alignment = .centerY
        container.translatesAutoresizingMaskIntoConstraints = false

        let labelView = NSTextField(labelWithString: label + ":")
        labelView.font = .systemFont(ofSize: 12)
        labelView.textColor = .secondaryLabelColor
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.widthAnchor.constraint(equalToConstant: 120).isActive = true
        container.addArrangedSubview(labelView)

        let textField = NSTextField(string: value)
        textField.font = .systemFont(ofSize: 12)
        textField.isEditable = true
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(textField)

        detailContentStack.addArrangedSubview(container)
        container.widthAnchor.constraint(equalTo: detailContentStack.widthAnchor, constant: -32).isActive = true

        return textField
    }

    private func addTextArea(_ label: String, value: String, height: CGFloat) -> NSTextView {
        let labelView = NSTextField(labelWithString: label + ":")
        labelView.font = .systemFont(ofSize: 12)
        labelView.textColor = .secondaryLabelColor
        detailContentStack.addArrangedSubview(labelView)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.font = .systemFont(ofSize: 12)
        textView.string = value
        textView.isEditable = true
        textView.isRichText = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        detailContentStack.addArrangedSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.heightAnchor.constraint(equalToConstant: height),
            scrollView.widthAnchor.constraint(equalTo: detailContentStack.widthAnchor, constant: -32)
        ])

        return textView
    }

    private func addRolePopup(_ label: String, selected: CharacterRole) -> NSPopUpButton {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 8
        container.alignment = .centerY
        container.translatesAutoresizingMaskIntoConstraints = false

        let labelView = NSTextField(labelWithString: label + ":")
        labelView.font = .systemFont(ofSize: 12)
        labelView.textColor = .secondaryLabelColor
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.widthAnchor.constraint(equalToConstant: 120).isActive = true
        container.addArrangedSubview(labelView)

        let popup = NSPopUpButton()
        popup.translatesAutoresizingMaskIntoConstraints = false

        for role in CharacterRole.allCases {
            popup.addItem(withTitle: role.rawValue)
        }
        popup.selectItem(withTitle: selected.rawValue)

        container.addArrangedSubview(popup)
        detailContentStack.addArrangedSubview(container)
        container.widthAnchor.constraint(equalTo: detailContentStack.widthAnchor, constant: -32).isActive = true

        return popup
    }

    @objc private func saveCharacterTapped() {
        guard var character = selectedCharacter else { return }

        character.fullName = nameField.stringValue
        character.nickname = nicknameField.stringValue
        character.role = CharacterRole.allCases.first { $0.rawValue == rolePopup.titleOfSelectedItem } ?? .supporting
        character.age = ageField.stringValue
        character.occupation = occupationField.stringValue
        character.appearance = appearanceField.string
        character.residence = residenceField.stringValue
        character.pets = petsField.stringValue
        character.background = backgroundField.string
        character.education = educationField.stringValue
        character.family = familyField.string
        character.personalityTraits = traitsField.string.components(separatedBy: "\n").filter { !$0.isEmpty }
        character.principles = principlesField.string.components(separatedBy: "\n").filter { !$0.isEmpty }
        character.skills = skillsField.string.components(separatedBy: "\n").filter { !$0.isEmpty }
        character.motivations = motivationsField.string
        character.weaknesses = weaknessesField.string
        character.connections = connectionsField.string
        character.quotes = quotesField.string.components(separatedBy: "\n").filter { !$0.isEmpty }
        character.notes = notesField.string
        character.isSampleCharacter = false

        CharacterLibrary.shared.updateCharacter(character)
        selectedCharacter = character

        let alert = NSAlert()
        alert.messageText = "Character Saved"
        alert.informativeText = "\(character.displayName) has been saved to your Character Library."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func deleteCharacterTapped() {
        guard let character = selectedCharacter else { return }

        let alert = NSAlert()
        alert.messageText = "Delete Character?"
        alert.informativeText = "Are you sure you want to delete \(character.displayName)? This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            CharacterLibrary.shared.deleteCharacter(character)
            selectedCharacter = nil
            showPlaceholder()
        }
    }

    func applyTheme(_ theme: AppTheme) {
        currentTheme = theme
        view.layer?.backgroundColor = theme.outlineBackground.cgColor
        scrollView?.drawsBackground = false
        detailScrollView?.drawsBackground = false
        refreshCharacterList()
        if selectedCharacter != nil {
            showCharacterDetail()
        }
    }
}
