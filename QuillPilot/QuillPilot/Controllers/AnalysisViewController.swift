//
//  AnalysisViewController.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa
import SwiftUI

// Flipped view so (0,0) is top-left; keeps content pinned at the top of the scroll area
private final class AnalysisFlippedView: NSView {
    override var isFlipped: Bool { true }
}

// Window delegate that closes the window when it loses key status (user clicks elsewhere)
private class AutoCloseWindowDelegate: NSObject, NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            window.close()
        }
    }
}

class AnalysisViewController: NSViewController {

    private var menuSidebar: NSView!
    private var menuSeparator: NSView!
    private var menuButtons: [NSButton] = []
    private var scrollContainer: NSView!
    private var scrollView: NSScrollView!
    private var documentView: NSView!
    private var contentStack: NSStackView!
    private var headerLabel: NSTextField!
    private var updateButton: NSButton!
    private var infoLabel: NSTextField!
    private var resultsStack: NSStackView!
    private var currentTheme: AppTheme = ThemeManager.shared.currentTheme
    private var currentCategory: AnalysisCategory = .basic
    private var isOutlineVisible = false

    // Analysis popout windows
    private var outlinePopoutWindow: NSWindow?
    private var analysisPopoutWindow: NSWindow?
    private var plotPopoutWindow: NSWindow?
    private weak var analysisPopoutStack: NSStackView?
    private weak var analysisPopoutContainer: NSView?

    // Character analysis popouts
    private var emotionalJourneyPopoutWindow: NSWindow?
    private var interactionsPopoutWindow: NSWindow?
    private var presencePopoutWindow: NSWindow?
    private var emotionalTrajectoryPopoutWindow: NSWindow?
    private var beliefShiftMatrixPopoutWindow: NSWindow?
    private var decisionConsequenceChainPopoutWindow: NSWindow?
    private var relationshipMapPopoutWindow: NSWindow?
    private var alignmentChartPopoutWindow: NSWindow?
    private var languageDriftPopoutWindow: NSWindow?
    private var thematicResonanceMapPopoutWindow: NSWindow?
    private var failurePatternChartPopoutWindow: NSWindow?

    // Window delegate for auto-closing popouts
    private let autoCloseDelegate = AutoCloseWindowDelegate()

    // Character Library Window (Navigator panel only)
    private var characterLibraryWindow: CharacterLibraryWindowController?
    private var themeWindow: ThemeWindowController?
    private var storyOutlineWindow: StoryOutlineWindowController?
    private var locationsWindow: LocationsWindowController?
    private var storyDirectionsWindow: StoryDirectionsWindowController?

    // Visualization views (macOS 13+)
    @available(macOS 13.0, *)
    private lazy var plotVisualizationView: PlotVisualizationView = {
        let view = PlotVisualizationView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()

    @available(macOS 13.0, *)
    private lazy var characterArcVisualizationView: CharacterArcVisualizationView = {
        let view = CharacterArcVisualizationView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()

    var outlineViewController: OutlineViewController?
    var isOutlinePanel: Bool = false
    var analyzeCallback: (() -> Void)?
    var getOutlineEntriesCallback: (() -> [EditorViewController.OutlineEntry])?

    private func scrollToTop() {
        guard let scrollView = scrollView else { return }
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    // Navigator panel categories (left side - has Theme, Story Outline, and Characters)
    enum NavigatorCategory: String, CaseIterable {
        case basic = "Outline"
        case theme = "Theme"
        case storyOutline = "Story Outline"
        case locations = "Locations"
        case storyDirections = "Story Directions"
        case characters = "Characters"

        var icon: String {
            switch self {
            case .basic: return "📝"
            case .theme: return "🎭"
            case .storyOutline: return "📚"
            case .locations: return "📍"
            case .storyDirections: return "🔀"
            case .characters: return "👥"
            }
        }
    }

    // Analysis panel categories (right side)
    enum AnalysisCategory: String, CaseIterable {
        case basic = "Analysis"
        case plot = "Plot Structure"
        case characters = "Characters"

        var icon: String {
            switch self {
            case .basic: return "📊"
            case .plot: return "📖"
            case .characters: return "👥"
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

        // Hide inline analysis for the analysis panel; use popout only
        if !isOutlinePanel {
            scrollContainer.isHidden = true
        }

        // Don't auto-switch to category on load - let it stay empty until user clicks
        // Only show content when user explicitly clicks a button

        // Observe main window becoming key to close popups
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainWindowBecameKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )

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

        // Create menu buttons - different for Navigator vs Analysis panel
        var yPosition: CGFloat = 12

        if isOutlinePanel {
            // Navigator panel - show Outline and Characters
            for category in NavigatorCategory.allCases {
                let button = NSButton(frame: NSRect(x: 0, y: 0, width: 44, height: 44))
                button.title = category.icon
                button.font = .systemFont(ofSize: 20)
                button.isBordered = false
                button.bezelStyle = .rounded
                button.target = self
                button.action = #selector(navigatorButtonTapped(_:))
                button.tag = NavigatorCategory.allCases.firstIndex(of: category) ?? 0
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
        } else {
            // Analysis panel - show analysis categories
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

        // For basic analysis, open popout window
        if category == .basic {
            // Kick off analysis if we have no data yet
            if latestAnalysisResults == nil {
                analyzeCallback?()
            }

            if analysisPopoutWindow == nil {
                analysisPopoutWindow = createAnalysisPopoutWindow()
            }
            refreshAnalysisPopoutContent()
            analysisPopoutWindow?.makeKeyAndOrderFront(nil)
            return
        }

        // For plot and characters, open popout windows
        if category == .plot {
            // Trigger analysis if no data exists
            if latestAnalysisResults == nil {
                analyzeCallback?()
                // Give a moment for analysis to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    if self?.plotPopoutWindow == nil {
                        self?.plotPopoutWindow = self?.createPlotPopoutWindow()
                    }
                    self?.plotPopoutWindow?.makeKeyAndOrderFront(nil)
                }
            } else {
                if plotPopoutWindow == nil {
                    plotPopoutWindow = createPlotPopoutWindow()
                }
                plotPopoutWindow?.makeKeyAndOrderFront(nil)
            }
            return
        }

        if category == .characters {
            // Show menu to choose which character analysis to view
            showCharacterAnalysisMenu(sender)
            return
        }
    }

    @objc private func mainWindowBecameKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.windowController is MainWindowController else {
            return
        }

        // Close all analysis popup windows when main window becomes key
        plotPopoutWindow?.close()
        plotPopoutWindow = nil

        outlinePopoutWindow?.close()
        outlinePopoutWindow = nil

        analysisPopoutWindow?.close()
        analysisPopoutWindow = nil

        emotionalJourneyPopoutWindow?.close()
        emotionalJourneyPopoutWindow = nil

        interactionsPopoutWindow?.close()
        interactionsPopoutWindow = nil

        presencePopoutWindow?.close()
        presencePopoutWindow = nil

        relationshipMapPopoutWindow?.close()
        relationshipMapPopoutWindow = nil

        // Also close Navigator popup windows
        storyOutlineWindow?.close()
        storyOutlineWindow = nil

        characterLibraryWindow?.close()
        characterLibraryWindow = nil

        locationsWindow?.close()
        locationsWindow = nil

        storyDirectionsWindow?.close()
        storyDirectionsWindow = nil

        themeWindow?.close()
        themeWindow = nil
    }

    @objc private func navigatorButtonTapped(_ sender: NSButton) {
        let category = NavigatorCategory.allCases[sender.tag]

        if category == .theme {
            // Open Theme window
            if themeWindow == nil {
                themeWindow = ThemeWindowController()
            }
            themeWindow?.showWindow(nil)
            themeWindow?.window?.makeKeyAndOrderFront(nil)
            return
        }

        if category == .storyOutline {
            // Open Story Outline window
            if storyOutlineWindow == nil {
                storyOutlineWindow = StoryOutlineWindowController()
            }
            storyOutlineWindow?.showWindow(nil)
            storyOutlineWindow?.window?.makeKeyAndOrderFront(nil)
            return
        }

        if category == .locations {
            // Open Locations window
            if locationsWindow == nil {
                locationsWindow = LocationsWindowController()
            }
            locationsWindow?.showWindow(nil)
            locationsWindow?.window?.makeKeyAndOrderFront(nil)
            return
        }

        if category == .storyDirections {
            // Open Story Directions window
            if storyDirectionsWindow == nil {
                storyDirectionsWindow = StoryDirectionsWindowController()
            }
            storyDirectionsWindow?.showWindow(nil)
            storyDirectionsWindow?.window?.makeKeyAndOrderFront(nil)
            return
        }

        if category == .characters {
            // Open Character Library window
            if characterLibraryWindow == nil {
                characterLibraryWindow = CharacterLibraryWindowController()
            }
            characterLibraryWindow?.showWindow(nil)
            characterLibraryWindow?.window?.makeKeyAndOrderFront(nil)
            return
        }

        // For outline, toggle it
        if isOutlineVisible {
            // Already showing - hide it immediately
            outlineViewController?.view.isHidden = true
            scrollContainer.isHidden = false
            isOutlineVisible = false
            updateSelectedButton()
        } else {
            // Show it immediately without expensive operations
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
            isOutlineVisible = true
            currentCategory = .basic
            updateSelectedButton()
            // Trigger refresh asynchronously to avoid blocking UI
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("QuillPilotOutlineRefresh"), object: nil)
            }
        }
    }

    @objc private func updateButtonTapped() {
        if let callback = analyzeCallback {
            callback()
        }
    }

    private func updateSelectedButton() {
        for (_, button) in menuButtons.enumerated() {
            // No highlighting for any buttons - they all open popouts or toggle inline content
            button.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    private func switchToCategory(_ category: AnalysisCategory) {
        currentCategory = category

        let showOutline = isOutlinePanel && category == .basic

        if showOutline {
            // Show outline, hide analysis content (navigator panel only)
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

        // For analysis panel showing basic analysis inline
        if !isOutlinePanel && category == .basic {
            scrollContainer.isHidden = false
            outlineViewController?.view.isHidden = true

            // Clear and show basic analysis
            resultsStack.arrangedSubviews.forEach { view in
                resultsStack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }

            headerLabel.stringValue = "Document Analysis"
            updateButton.isHidden = false
            infoLabel.stringValue = "Click Update to refresh all analysis."

            // Add placeholder
            let placeholder = makeLabel("Click Update to analyze your document", size: 13, bold: false)
            placeholder.textColor = .secondaryLabelColor
            resultsStack.addArrangedSubview(placeholder)

            // Make sure scroll content is visible
            scrollContainer.isHidden = false

            updateSelectedButton()
            return
        }

        // Analysis panel buttons (plot, characters) are popouts only - do nothing for inline content
        outlineViewController?.view.isHidden = true
        updateSelectedButton()
    }

    private func setupScrollView() {
        // Simple scroll view setup matching OutlineViewController structure
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.verticalScroller?.isHidden = true
        scrollView.horizontalScroller?.isHidden = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // Document view - simple flipped view, no constraints
        documentView = AnalysisFlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        if let clipView = scrollView.contentView as NSClipView? {
            NSLayoutConstraint.activate([
                documentView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
                documentView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
                documentView.topAnchor.constraint(equalTo: clipView.topAnchor),
                documentView.widthAnchor.constraint(equalTo: clipView.widthAnchor)
            ])
        }

        view.addSubview(scrollView)

        // Position based on panel type
        if isOutlinePanel {
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
                scrollView.trailingAnchor.constraint(equalTo: menuSeparator.leadingAnchor, constant: -8),
                scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
            ])
        } else {
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
                scrollView.leadingAnchor.constraint(equalTo: menuSeparator.trailingAnchor, constant: 8),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
                scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
            ])
        }

        // Keep reference to scrollContainer for show/hide toggling
        scrollContainer = scrollView
    }

    private func setupContent() {
        contentStack = NSStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16
        contentStack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)

        // Simple background, no layer manipulation
        contentStack.wantsLayer = true
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

        let headerTitle = isOutlinePanel ? "Navigator" : "Document Analysis"
        headerLabel = makeLabel(headerTitle, size: 18, bold: true)
        headerContainer.addArrangedSubview(headerLabel)

        updateButton = NSButton(title: "Update", target: self, action: #selector(updateButtonTapped))
        updateButton.bezelStyle = .rounded
        updateButton.controlSize = .small
        updateButton.translatesAutoresizingMaskIntoConstraints = false
        updateButton.isEnabled = true
        // Hide update button entirely for analysis popout flow
        updateButton.isHidden = true
        headerContainer.addArrangedSubview(updateButton)

        contentStack.addArrangedSubview(headerContainer)

        // Info label
        infoLabel = makeLabel("Click Update to refresh all analysis.", size: 13, bold: false)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.lineBreakMode = .byWordWrapping
        infoLabel.maximumNumberOfLines = 0
        infoLabel.isHidden = !isOutlinePanel
        contentStack.addArrangedSubview(infoLabel)

        // Results container
        resultsStack = NSStackView()
        resultsStack.translatesAutoresizingMaskIntoConstraints = false
        resultsStack.orientation = .vertical
        resultsStack.alignment = .leading
        resultsStack.spacing = 10
        contentStack.addArrangedSubview(resultsStack)

        NSLayoutConstraint.activate([
            resultsStack.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            resultsStack.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor)
        ])

        // Initial placeholder
        let placeholder = makeLabel("Analysis will appear here as it runs.", size: 13, bold: false)
        placeholder.textColor = .secondaryLabelColor
        placeholder.lineBreakMode = .byWordWrapping
        placeholder.maximumNumberOfLines = 0
        resultsStack.addArrangedSubview(placeholder)

        // Start scrolled to top for empty/initial states
        scrollToTop()

        documentView.addSubview(contentStack)

        // Simple constraints - just pin to edges with padding
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -32)
        ])
    }

    func displayResults(_ results: AnalysisResults) {

        // Store results for visualization
        storeAnalysisResults(results)

        // For analysis panel we show results only in the popout
        if !isOutlinePanel {
            refreshAnalysisPopoutContent()
            return
        }

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
        addDivider()

        // Dialogue Quality Analysis (10 Tips from The Silent Operator_Dialogue)
        if results.dialogueSegmentCount > 0 {
            addHeader("💬 Dialogue Quality")
            addStat("Overall Score", "\(results.dialogueQualityScore)%")
            addStat("Dialogue Segments", "\(results.dialogueSegmentCount)")

            // Tip #3: Filler Words
            if results.dialogueFillerCount > 0 {
                let fillerPercent = (results.dialogueFillerCount * 100) / results.dialogueSegmentCount
                addWarning("⚠️ Filler words in \(fillerPercent)% of dialogue")
                addDetail("Tip: Remove \"uh\", \"um\", \"well\" unless characterizing speech")
            } else {
                addSuccess("✓ Minimal filler words")
            }

            // Tip #2: Repetition
            if results.dialogueRepetitionScore > 30 {
                addWarning("⚠️ Repetitive dialogue detected (\(results.dialogueRepetitionScore)%)")
                addDetail("Tip: Vary dialogue - characters shouldn't repeat phrases")
            }

            // Tip #5: Predictability
            if !results.dialoguePredictablePhrases.isEmpty {
                addWarning("⚠️ Found \(results.dialoguePredictablePhrases.count) clichéd phrase(s)")
                for phrase in results.dialoguePredictablePhrases.prefix(3) {
                    addDetail("• \"\(phrase)\"")
                }
                addDetail("Tip: Replace predictable dialogue with fresh, character-specific lines")
            }

            // Tip #7: Over-Exposition
            if results.dialogueExpositionCount > 0 {
                let expositionPercent = (results.dialogueExpositionCount * 100) / results.dialogueSegmentCount
                if expositionPercent > 20 {
                    addWarning("⚠️ \(expositionPercent)% of dialogue is info-dumping")
                    addDetail("Tip: Show through action, not lengthy explanations")
                }
            }

            // Tip #8: Conflict/Tension
            if !results.hasDialogueConflict {
                addWarning("⚠️ Dialogue lacks conflict or tension")
                addDetail("Tip: Add disagreement, subtext, or opposing goals")
            } else {
                addSuccess("✓ Good tension in dialogue")
            }

            // Tip #10: Pacing
            addStat("Pacing Variety", "\(results.dialoguePacingScore)%")
            if results.dialoguePacingScore < 40 {
                addWarning("Low pacing variety")
                addDetail("Tip: Mix short, punchy lines with longer speeches")
            } else if results.dialoguePacingScore >= 60 {
                addSuccess("✓ Good pacing variety")
            }

            // Overall quality assessment
            if results.dialogueQualityScore >= 80 {
                addSuccess("✓ Excellent dialogue quality!")
            } else if results.dialogueQualityScore >= 60 {
                addDetail("Good dialogue - minor improvements possible")
            } else {
                addWarning("Consider revising dialogue for more impact")
            }
        }

        // Refresh popout if open
        refreshAnalysisPopoutContent()
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
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        resultsStack.addArrangedSubview(label)

        // Ensure label takes full width for centering to work
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: resultsStack.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: resultsStack.trailingAnchor)
        ])
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

    private func createSentenceGraphForPopout(_ lengths: [Int]) -> NSView {
        // Fixed width for popout
        let graphWidth: CGFloat = 560
        let graphHeight: CGFloat = 180

        let container = NSView(frame: NSRect(x: 0, y: 0, width: graphWidth, height: graphHeight))
        container.wantsLayer = true
        container.translatesAutoresizingMaskIntoConstraints = false
        // Use slightly darker shade of pageAround for graph to match theme
        let graphBackground = currentTheme.pageAround.blended(withFraction: 0.05, of: .black) ?? currentTheme.pageAround
        container.layer?.backgroundColor = graphBackground.cgColor
        container.layer?.cornerRadius = 8
        container.layer?.borderWidth = 1.0
        let borderColor = currentTheme == .day ? NSColor(red: 0.7, green: 0.65, blue: 0.6, alpha: 1.0) : NSColor(white: 0.3, alpha: 1.0)
        container.layer?.borderColor = borderColor.cgColor

        // Create bar chart
        guard !lengths.isEmpty else {
            NSLayoutConstraint.activate([
                container.heightAnchor.constraint(equalToConstant: graphHeight),
                container.widthAnchor.constraint(equalToConstant: graphWidth)
            ])

            // Add "No data" label
            let noDataLabel = NSTextField(labelWithString: "Not enough sentences")
            noDataLabel.isEditable = false
            noDataLabel.isBezeled = false
            noDataLabel.drawsBackground = false
            noDataLabel.font = .systemFont(ofSize: 11)
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
            text.textColor = NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
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

        applyThemeToAnalysisPopout()
        applyThemeToAllPopouts()

        // Force redisplay
        view.needsDisplay = true
        view.displayIfNeeded()

        outlineViewController?.applyTheme(theme)
        updateSelectedButton()
    }

    /// Apply theme to all popout windows
    private func applyThemeToAllPopouts() {
        let windows: [NSWindow?] = [
            emotionalTrajectoryPopoutWindow,
            beliefShiftMatrixPopoutWindow,
            decisionConsequenceChainPopoutWindow,
            emotionalJourneyPopoutWindow,
            interactionsPopoutWindow,
            presencePopoutWindow,
            plotPopoutWindow
        ]

        for window in windows {
            guard let window = window else { continue }
            applyThemeToPopout(window: window, container: window.contentView, stack: nil)

            // Update text colors in the window
            updateTextColorsInView(window.contentView)
        }
    }

    /// Recursively update text colors in a view hierarchy
    private func updateTextColorsInView(_ view: NSView?) {
        guard let view = view else { return }

        if let textField = view as? NSTextField {
            // Don't change text fields that are editable (input fields)
            if !textField.isEditable {
                textField.textColor = currentTheme.textColor
            }
        }

        for subview in view.subviews {
            updateTextColorsInView(subview)
        }
    }

    // MARK: - Visualization Methods

    private var latestAnalysisResults: AnalysisResults?

    func storeAnalysisResults(_ results: AnalysisResults) {
        latestAnalysisResults = results
    }

    @available(macOS 13.0, *)
    private func displayVisualizations() {
        guard let results = latestAnalysisResults else {
            let placeholder = makeLabel("📊 No visualization data available\n\nRun an analysis first to see plot and character graphs", size: 14, bold: true)
            placeholder.alignment = .center
            placeholder.textColor = .secondaryLabelColor
            placeholder.maximumNumberOfLines = 0
            resultsStack.addArrangedSubview(placeholder)
            return
        }

        // Show plot visualization
        if let plotAnalysis = results.plotAnalysis {

            // Remove from previous parent if needed
            plotVisualizationView.removeFromSuperview()
            resultsStack.addArrangedSubview(plotVisualizationView)

            NSLayoutConstraint.activate([
                plotVisualizationView.widthAnchor.constraint(equalTo: resultsStack.widthAnchor),
                plotVisualizationView.heightAnchor.constraint(greaterThanOrEqualToConstant: 600)
            ])

            plotVisualizationView.configure(with: plotAnalysis)
        }

        // Add character visualizations below plot
        if !results.decisionBeliefLoops.isEmpty {
            // Add spacing between sections
            let spacer = NSView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            resultsStack.addArrangedSubview(spacer)
            NSLayoutConstraint.activate([
                spacer.heightAnchor.constraint(equalToConstant: 30)
            ])

            // Remove from previous parent if needed
            characterArcVisualizationView.removeFromSuperview()
            resultsStack.addArrangedSubview(characterArcVisualizationView)

            NSLayoutConstraint.activate([
                characterArcVisualizationView.widthAnchor.constraint(equalTo: resultsStack.widthAnchor),
                characterArcVisualizationView.heightAnchor.constraint(greaterThanOrEqualToConstant: 600)
            ])

            characterArcVisualizationView.configure(
                loops: results.decisionBeliefLoops,
                interactions: results.characterInteractions,
                presence: results.characterPresence
            )
        }

        // Ensure we stay scrolled to the top after injecting content
        scrollToTop()
    }

    @available(macOS 13.0, *)
    private func displayPlotAnalysis() {

        guard let results = latestAnalysisResults else {
            let placeholder = makeLabel("📖 Run analysis first to view plot insights", size: 14, bold: true)
            placeholder.alignment = .center
            placeholder.textColor = .secondaryLabelColor
            placeholder.maximumNumberOfLines = 0
            resultsStack.addArrangedSubview(placeholder)
            return
        }

        guard let plotAnalysis = results.plotAnalysis else {
            let placeholder = makeLabel("📖 No plot points detected yet", size: 14, bold: true)
            placeholder.alignment = .center
            placeholder.textColor = .secondaryLabelColor
            placeholder.maximumNumberOfLines = 0
            resultsStack.addArrangedSubview(placeholder)
            return
        }

        // Remove from previous parent if needed
        plotVisualizationView.removeFromSuperview()
        resultsStack.addArrangedSubview(plotVisualizationView)

        NSLayoutConstraint.activate([
            plotVisualizationView.widthAnchor.constraint(equalTo: resultsStack.widthAnchor),
            plotVisualizationView.heightAnchor.constraint(greaterThanOrEqualToConstant: 720)
        ])

        plotVisualizationView.configure(with: plotAnalysis)
        scrollToTop()
    }

    @available(macOS 13.0, *)
    private func displayCharacterAnalysis() {

        guard let results = latestAnalysisResults else {
            let placeholder = makeLabel("👥 Run analysis first to view character insights", size: 14, bold: true)
            placeholder.alignment = .center
            placeholder.textColor = .secondaryLabelColor
            placeholder.maximumNumberOfLines = 0
            resultsStack.addArrangedSubview(placeholder)
            return
        }

        guard !results.decisionBeliefLoops.isEmpty else {
            let placeholder = makeLabel("👥 No characters detected yet", size: 14, bold: true)
            placeholder.alignment = .center
            placeholder.textColor = .secondaryLabelColor
            placeholder.maximumNumberOfLines = 0
            resultsStack.addArrangedSubview(placeholder)
            return
        }

        // Remove from previous parent if needed
        characterArcVisualizationView.removeFromSuperview()
        resultsStack.addArrangedSubview(characterArcVisualizationView)

        NSLayoutConstraint.activate([
            characterArcVisualizationView.widthAnchor.constraint(equalTo: resultsStack.widthAnchor),
            characterArcVisualizationView.heightAnchor.constraint(greaterThanOrEqualToConstant: 800)
        ])

        characterArcVisualizationView.configure(
            loops: results.decisionBeliefLoops,
            interactions: results.characterInteractions,
            presence: results.characterPresence
        )
        scrollToTop()
    }

    private func displayReadabilityAnalysis() {

        let placeholder = makeLabel("👁️ Readability Analysis\n\nAnalyze sentence complexity, vocabulary diversity, and reading level.\n\nComing soon...", size: 14, bold: false)
        placeholder.alignment = .center
        placeholder.textColor = .secondaryLabelColor
        placeholder.maximumNumberOfLines = 0
        resultsStack.addArrangedSubview(placeholder)
    }

    private func displayPacingAnalysis() {

        let placeholder = makeLabel("⚡ Pacing Analysis\n\nTrack scene lengths, chapter distribution, and narrative rhythm.\n\nComing soon...", size: 14, bold: false)
        placeholder.alignment = .center
        placeholder.textColor = .secondaryLabelColor
        placeholder.maximumNumberOfLines = 0
        resultsStack.addArrangedSubview(placeholder)
    }

    private func displayDialogueAnalysis() {

        let placeholder = makeLabel("💬 Dialogue Analysis\n\nAnalyze speech patterns, conversation balance, and dialogue tags.\n\nComing soon...", size: 14, bold: false)
        placeholder.alignment = .center
        placeholder.textColor = .secondaryLabelColor
        placeholder.maximumNumberOfLines = 0
        resultsStack.addArrangedSubview(placeholder)
    }

    private func displayThemeAnalysis() {

        let placeholder = makeLabel("🎭 Theme Analysis\n\nDetect recurring motifs, symbols, and thematic elements.\n\nComing soon...", size: 14, bold: false)
        placeholder.alignment = .center
        placeholder.textColor = .secondaryLabelColor
        placeholder.maximumNumberOfLines = 0
        resultsStack.addArrangedSubview(placeholder)
    }

    private func displayWorldbuildingAnalysis() {

        let placeholder = makeLabel("🌍 Worldbuilding Analysis\n\nTrack locations, time references, and world consistency.\n\nComing soon...", size: 14, bold: false)
        placeholder.alignment = .center
        placeholder.textColor = .secondaryLabelColor
        placeholder.maximumNumberOfLines = 0
        resultsStack.addArrangedSubview(placeholder)
    }
}

// MARK: - Visualization Delegates

@available(macOS 13.0, *)
extension AnalysisViewController: PlotVisualizationDelegate {
    func didTapPlotPoint(at wordPosition: Int) {
        // Notify the editor to jump to this position
        NotificationCenter.default.post(
            name: Notification.Name("QuillPilotJumpToPosition"),
            object: nil,
            userInfo: ["wordPosition": wordPosition]
        )
    }

    func openPlotPopout(_ analysis: PlotAnalysis) {
        // Close existing popout if any
        plotPopoutWindow?.close()
        plotPopoutWindow = nil

        let contentRect = NSRect(x: 0, y: 0, width: 1100, height: 760)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Story Progress"
        window.level = .normal
        window.isMovableByWindowBackground = true
        window.isExcludedFromWindowsMenu = false
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = true

        // Set window appearance to match the current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        let hostingView = NSHostingView(
            rootView: PlotTensionChart(
                plotAnalysis: analysis,
                onPointTap: { [weak self] position in
                    self?.didTapPlotPoint(at: position)
                },
                onPopout: { [weak window] in
                    window?.makeKeyAndOrderFront(nil)
                }
            )
            .preferredColorScheme(isDarkMode ? .dark : .light)
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        window.contentView = container
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        plotPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.plotPopoutWindow = nil
        }
    }
}

@available(macOS 13.0, *)
extension AnalysisViewController: CharacterArcVisualizationDelegate {
    func didTapSection(at wordPosition: Int) {
        // Notify the editor to jump to this position
        NotificationCenter.default.post(
            name: Notification.Name("QuillPilotJumpToPosition"),
            object: nil,
            userInfo: ["wordPosition": wordPosition]
        )
    }
}

// MARK: - Character Analysis Popout Functions

extension AnalysisViewController {
    func openDecisionBeliefPopout(loops: [DecisionBeliefLoop]) {
        // Close existing window if open
        emotionalJourneyPopoutWindow?.close()
        emotionalJourneyPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Decision-Belief Loop Framework"
        window.level = .normal
        window.isMovableByWindowBackground = true
        window.isExcludedFromWindowsMenu = false
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = true

        // Apply theme colors and appearance
        let theme = ThemeManager.shared.currentTheme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.backgroundColor = theme.pageBackground
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Use AppKit view for proper theme support
        let decisionBeliefView = DecisionBeliefLoopView(frame: window.contentView!.bounds)
        decisionBeliefView.autoresizingMask = [.width, .height]
        decisionBeliefView.setLoops(loops)

        window.contentView = decisionBeliefView
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        emotionalJourneyPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.emotionalJourneyPopoutWindow = nil
        }
    }

    func openInteractionsPopout(interactions: [CharacterInteraction]) {
        // Close existing window if open
        interactionsPopoutWindow?.close()
        interactionsPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 650),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Character Interactions Network"
        window.minSize = NSSize(width: 800, height: 500)
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = true

        // Create custom view
        let interactionsView = CharacterInteractionsView(frame: window.contentView!.bounds)
        interactionsView.autoresizingMask = [.width, .height]

        // Convert CharacterInteraction to InteractionData
        let interactionData = interactions.map { interaction in
            CharacterInteractionsView.InteractionData(
                character1: interaction.character1,
                character2: interaction.character2,
                coAppearances: interaction.coAppearances,
                relationshipStrength: interaction.relationshipStrength,
                sections: interaction.sections
            )
        }

        interactionsView.setInteractions(interactionData)

        // Create container
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.pageAround.cgColor
        container.addSubview(interactionsView)

        window.contentView = container
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        interactionsPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.interactionsPopoutWindow = nil
        }
    }

    func openRelationshipEvolutionMapPopout(evolutionData: RelationshipEvolutionData) {
        // Close existing window if open
        relationshipMapPopoutWindow?.close()
        relationshipMapPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Relationship Evolution Maps"
        window.minSize = NSSize(width: 900, height: 600)
        window.isReleasedWhenClosed = false
        window.delegate = autoCloseDelegate

        // Set window appearance to match the current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Create custom view
        let mapView = RelationshipEvolutionMapView(frame: window.contentView!.bounds)
        mapView.autoresizingMask = [.width, .height]

        // Convert data to view format
        let nodes = evolutionData.nodes.map { nodeData in
            RelationshipEvolutionMapView.RelationshipNode(
                character: nodeData.character,
                emotionalInvestment: nodeData.emotionalInvestment,
                position: NSPoint(x: nodeData.positionX, y: nodeData.positionY)
            )
        }

        let edges = evolutionData.edges.map { edgeData in
            let powerDirection: RelationshipEvolutionMapView.PowerDirection
            switch edgeData.powerDirection {
            case "fromToTo":
                powerDirection = .fromToTo
            case "toToFrom":
                powerDirection = .toToFrom
            default:
                powerDirection = .balanced
            }

            let evolutionPoints = edgeData.evolution.map { point in
                RelationshipEvolutionMapView.EvolutionPoint(
                    chapter: point.chapter,
                    trustLevel: point.trustLevel,
                    description: point.description
                )
            }

            return RelationshipEvolutionMapView.RelationshipEdge(
                from: edgeData.from,
                to: edgeData.to,
                trustLevel: edgeData.trustLevel,
                powerDirection: powerDirection,
                evolution: evolutionPoints
            )
        }

        mapView.setRelationships(nodes: nodes, edges: edges)

        // Create container
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.pageAround.cgColor
        container.addSubview(mapView)

        window.contentView = container
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        relationshipMapPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.relationshipMapPopoutWindow = nil
        }
    }

    func openInternalExternalAlignmentPopout(alignmentData: InternalExternalAlignmentData) {
        // Close existing window if open
        alignmentChartPopoutWindow?.close()
        alignmentChartPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Internal vs External Alignment Charts"
        window.minSize = NSSize(width: 800, height: 700)
        window.isReleasedWhenClosed = false
        window.delegate = autoCloseDelegate

        // Set window appearance to match the current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Create custom view
        let alignmentView = InternalExternalAlignmentView(frame: window.contentView!.bounds)
        alignmentView.autoresizingMask = [.width, .height]

        // Convert data to view format
        let characterAlignments = alignmentData.characterAlignments.map { charData in
            let dataPoints = charData.dataPoints.map { point in
                InternalExternalAlignmentView.AlignmentDataPoint(
                    chapter: point.chapter,
                    innerTruth: point.innerTruth,
                    outerBehavior: point.outerBehavior,
                    innerLabel: point.innerLabel,
                    outerLabel: point.outerLabel
                )
            }

            let gapTrend: InternalExternalAlignmentView.GapTrend
            switch charData.gapTrend {
            case "widening":
                gapTrend = .widening
            case "stabilizing":
                gapTrend = .stabilizing
            case "closing":
                gapTrend = .closing
            case "collapsing":
                gapTrend = .collapsing
            default:
                gapTrend = .fluctuating
            }

            return InternalExternalAlignmentView.CharacterAlignment(
                characterName: charData.characterName,
                dataPoints: dataPoints,
                gapTrend: gapTrend
            )
        }

        alignmentView.setAlignments(characterAlignments)

        // Create container
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.pageAround.cgColor
        container.addSubview(alignmentView)

        window.contentView = container
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        alignmentChartPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.alignmentChartPopoutWindow = nil
        }
    }

    func openLanguageDriftPopout(driftData: LanguageDriftData) {
        // Close existing window if open
        languageDriftPopoutWindow?.close()
        languageDriftPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 650),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Language Drift Analysis"
        window.minSize = NSSize(width: 800, height: 500)
        window.isReleasedWhenClosed = false
        window.delegate = autoCloseDelegate

        // Set window appearance to match the current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Create custom view
        let driftView = LanguageDriftAnalysisView(frame: window.contentView!.bounds)
        driftView.autoresizingMask = [.width, .height]

        // Convert data to view format
        let characterDrifts = driftData.characterDrifts.map { charData in
            let metrics = charData.metrics.map { m in
                LanguageDriftAnalysisView.LanguageMetrics(
                    chapter: m.chapter,
                    pronounI: m.pronounI,
                    pronounWe: m.pronounWe,
                    modalMust: m.modalMust,
                    modalChoice: m.modalChoice,
                    emotionalDensity: m.emotionalDensity,
                    avgSentenceLength: m.avgSentenceLength,
                    certaintyScore: m.certaintyScore
                )
            }

            let summary = LanguageDriftAnalysisView.DriftSummary(
                pronounShift: charData.driftSummary.pronounShift,
                modalShift: charData.driftSummary.modalShift,
                emotionalTrend: charData.driftSummary.emotionalTrend,
                sentenceTrend: charData.driftSummary.sentenceTrend,
                certaintyTrend: charData.driftSummary.certaintyTrend
            )

            return LanguageDriftAnalysisView.CharacterLanguageDrift(
                characterName: charData.characterName,
                metrics: metrics,
                driftSummary: summary
            )
        }

        driftView.setDriftData(characterDrifts)

        // Create container
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.pageAround.cgColor
        container.addSubview(driftView)

        window.contentView = container
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        languageDriftPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.languageDriftPopoutWindow = nil
        }
    }

    func openThematicResonanceMapPopout() {
        // Close existing window if open
        thematicResonanceMapPopoutWindow?.close()
        thematicResonanceMapPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 650),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Thematic Resonance Map"
        window.minSize = NSSize(width: 800, height: 500)
        window.isReleasedWhenClosed = false
        window.delegate = autoCloseDelegate

        // Set window appearance to match the current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Get story theme from theme window
        let storyTheme = getStoryThemeText()

        // Create custom view
        let resonanceView = ThematicResonanceMapView(frame: window.contentView!.bounds)
        resonanceView.autoresizingMask = [.width, .height]

        // Generate sample thematic data based on characters
        let journeys = generateThematicJourneys()
        resonanceView.setThematicData(journeys, theme: storyTheme)

        // Create container
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.pageAround.cgColor
        container.addSubview(resonanceView)

        window.contentView = container
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        thematicResonanceMapPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.thematicResonanceMapPopoutWindow = nil
        }

        // Listen for theme changes to update the view
        NotificationCenter.default.addObserver(
            forName: .storyThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self, weak resonanceView] _ in
            guard let self = self, let resonanceView = resonanceView else { return }
            let updatedTheme = self.getStoryThemeText()
            let updatedJourneys = self.generateThematicJourneys()
            resonanceView.setThematicData(updatedJourneys, theme: updatedTheme)
        }
    }

    func openFailurePatternChartsPopout() {
        // Close existing window if open
        failurePatternChartPopoutWindow?.close()
        failurePatternChartPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 650),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Failure Pattern Charts"
        window.minSize = NSSize(width: 800, height: 500)
        window.isReleasedWhenClosed = false
        window.delegate = autoCloseDelegate

        // Set window appearance to match the current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Create custom view
        let chartView = FailurePatternChartView(frame: window.contentView!.bounds)
        chartView.autoresizingMask = [.width, .height]

        // Generate failure pattern data based on characters
        let patterns = generateFailurePatterns()
        chartView.setFailureData(patterns)

        // Create container
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.pageAround.cgColor
        container.addSubview(chartView)

        window.contentView = container
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        failurePatternChartPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.failurePatternChartPopoutWindow = nil
        }
    }

    private func generateFailurePatterns() -> [FailurePatternChartView.CharacterFailurePattern] {
        // Colors for different characters
        let colors: [NSColor] = [.systemPurple, .systemTeal, .systemOrange, .systemPink, .systemIndigo, .systemGreen]

        var patterns: [FailurePatternChartView.CharacterFailurePattern] = []

        // Use character library if available
        let library = CharacterLibrary.shared
        if !library.characters.isEmpty {
            for (index, character) in library.characters.prefix(6).enumerated() {
                let failures = generateFailuresForCharacter(characterName: character.displayName, index: index)
                let progression = determineFailureProgression(failures: failures)

                let pattern = FailurePatternChartView.CharacterFailurePattern(
                    characterName: character.displayName,
                    color: colors[index % colors.count],
                    failures: failures,
                    progression: progression
                )
                patterns.append(pattern)
            }
        } else {
            // Default sample data if no characters
            let defaultCharacters = ["Alex", "Allison", "Raymond", "Kessler"]
            for (index, name) in defaultCharacters.enumerated() {
                let failures = generateFailuresForCharacter(characterName: name, index: index)
                let progression = determineFailureProgression(failures: failures)

                let pattern = FailurePatternChartView.CharacterFailurePattern(
                    characterName: name,
                    color: colors[index % colors.count],
                    failures: failures,
                    progression: progression
                )
                patterns.append(pattern)
            }
        }

        return patterns
    }

    private func generateFailuresForCharacter(characterName: String, index: Int) -> [FailurePatternChartView.Failure] {
        var failures: [FailurePatternChartView.Failure] = []

        // Generate failures for chapters 2, 5, 8, 11, 14
        let chapters = [2, 5, 8, 11, 14]

        for (chapterIndex, chapter) in chapters.enumerated() {
            let progress = Double(chapterIndex) / Double(chapters.count - 1)

            // Different patterns for different characters
            let failureType: FailurePatternChartView.FailureType
            let growthScore: Double
            let description: String
            let consequence: String

            switch index {
            case 0: // Protagonist - evolves from naive to principled
                if chapterIndex == 0 {
                    failureType = .naive
                    growthScore = 0.2
                    description = "Trusts wrong person, reveals operation"
                    consequence = "Team compromised, trust broken"
                } else if chapterIndex == 1 {
                    failureType = .reactive
                    growthScore = 0.3
                    description = "Acts without thinking, blows cover"
                    consequence = "Mission delayed, partner injured"
                } else if chapterIndex == 2 {
                    failureType = .misinformed
                    growthScore = 0.45
                    description = "Acts on false intel"
                    consequence = "Wrong target confronted"
                } else if chapterIndex == 3 {
                    failureType = .strategic
                    growthScore = 0.7
                    description = "Calculated risk that doesn't pay off"
                    consequence = "Asset lost but learns from it"
                } else {
                    failureType = .principled
                    growthScore = 0.85
                    description = "Refuses unethical order"
                    consequence = "Career at risk but integrity intact"
                }

            case 1: // Ally - starts reactive, becomes strategic
                if chapterIndex < 2 {
                    failureType = .reactive
                    growthScore = 0.25 + (progress * 0.15)
                    description = "Impulsive decision"
                    consequence = "Minor setback"
                } else if chapterIndex == 2 {
                    failureType = .misinformed
                    growthScore = 0.5
                    description = "Misread situation"
                    consequence = "Relationship strain"
                } else {
                    failureType = .strategic
                    growthScore = 0.65 + (progress * 0.15)
                    description = "Tactical gamble"
                    consequence = "Short-term loss, long-term gain"
                }

            case 2: // Antagonist - strategic failures that escalate
                if chapterIndex < 2 {
                    failureType = .strategic
                    growthScore = 0.4
                    description = "Underestimates opposition"
                    consequence = "Plan partially foiled"
                } else {
                    failureType = .costlyChosen
                    growthScore = 0.5 + (progress * 0.2)
                    description = "Sacrifices ally for goal"
                    consequence = "More isolated but closer to objective"
                }

            case 3: // Mentor - costly failures throughout
                if chapterIndex == 0 {
                    failureType = .naive
                    growthScore = 0.3
                    description = "Old mistake haunts them"
                    consequence = "Past comes back"
                } else {
                    failureType = .costlyChosen
                    growthScore = 0.6 + (progress * 0.25)
                    description = "Protects protagonist at personal cost"
                    consequence = "Reputation/health damaged"
                }

            default:
                failureType = .reactive
                growthScore = 0.3 + (progress * 0.4)
                description = "Generic failure"
                consequence = "Generic consequence"
            }

            let failure = FailurePatternChartView.Failure(
                chapter: chapter,
                type: failureType,
                description: description,
                consequence: consequence,
                growthScore: growthScore
            )
            failures.append(failure)
        }

        return failures
    }

    private func determineFailureProgression(failures: [FailurePatternChartView.Failure]) -> FailurePatternChartView.FailureProgression {
        guard failures.count >= 2 else { return .stagnant }

        let firstGrowth = failures.first!.growthScore
        let lastGrowth = failures.last!.growthScore
        let improvement = lastGrowth - firstGrowth

        // Check if failures are getting "better" (higher growth score)
        if improvement < 0.1 {
            return .stagnant
        } else if improvement < 0.3 {
            return .emerging
        } else if improvement < 0.5 {
            return .transforming
        } else {
            return .evolved
        }
    }

    private func getStoryThemeText() -> String {
        // Always load from persistent storage - ensures consistency across sessions
        return ThemeWindowController.getCurrentTheme()
    }

    private func generateThematicJourneys() -> [ThematicResonanceMapView.CharacterThematicJourney] {
        // Colors for different characters
        let colors: [NSColor] = [.systemPurple, .systemTeal, .systemOrange, .systemPink, .systemIndigo, .systemGreen]

        var journeys: [ThematicResonanceMapView.CharacterThematicJourney] = []

        // Use character library if available
        let library = CharacterLibrary.shared
        if !library.characters.isEmpty {
            for (index, character) in library.characters.prefix(6).enumerated() {
                let stances = generateStancesForCharacter(characterName: character.displayName, index: index)
                let trajectory = determineTrajectory(stances: stances)

                let journey = ThematicResonanceMapView.CharacterThematicJourney(
                    characterName: character.displayName,
                    color: colors[index % colors.count],
                    stances: stances,
                    overallTrajectory: trajectory
                )
                journeys.append(journey)
            }
        } else {
            // Default sample data if no characters
            let defaultCharacters = ["Alex", "Allison", "Raymond", "Kessler"]
            for (index, name) in defaultCharacters.enumerated() {
                let stances = generateStancesForCharacter(characterName: name, index: index)
                let trajectory = determineTrajectory(stances: stances)

                let journey = ThematicResonanceMapView.CharacterThematicJourney(
                    characterName: name,
                    color: colors[index % colors.count],
                    stances: stances,
                    overallTrajectory: trajectory
                )
                journeys.append(journey)
            }
        }

        return journeys
    }

    private func generateStancesForCharacter(characterName: String, index: Int) -> [ThematicResonanceMapView.ThematicStance] {
        var stances: [ThematicResonanceMapView.ThematicStance] = []

        // Generate data for chapters 2, 4, 6, 8, 10, 12, 14
        let chapters = [2, 4, 6, 8, 10, 12, 14]

        for (chapterIndex, chapter) in chapters.enumerated() {
            let progress = Double(chapterIndex) / Double(chapters.count - 1)

            // Different patterns for different characters
            let alignment: Double
            let awareness: Double
            let influence: Double
            let cost: Double

            switch index {
            case 0: // Protagonist - starts opposed, gradually embraces theme
                alignment = -0.8 + (progress * 1.5) // -0.8 to 0.7
                awareness = 0.2 + (progress * 0.7)  // Growing awareness
                influence = 0.4 + (progress * 0.5)  // Growing influence
                cost = 0.3 + (progress * 0.6)       // Increasing cost

            case 1: // Ally - embodies theme, helps protagonist see it
                alignment = 0.6 + (progress * 0.3)  // High, increasing
                awareness = 0.8 - (progress * 0.1)  // High, slight drop
                influence = 0.7 + (progress * 0.2)  // Strong influence
                cost = 0.5 + (progress * 0.3)       // Moderate cost

            case 2: // Antagonist - opposes theme throughout
                alignment = -0.9 + (progress * 0.2) // Stays negative
                awareness = 0.9                      // Fully aware
                influence = 0.8 - (progress * 0.3)  // Losing influence
                cost = 0.2                           // Low personal cost

            case 3: // Mentor - embodies theme but at high cost
                alignment = 0.8
                awareness = 0.95
                influence = 0.6 - (progress * 0.3)  // Diminishing influence
                cost = 0.8 + (progress * 0.15)      // Very high cost

            default: // Other characters
                alignment = sin(progress * .pi) * 0.6
                awareness = progress * 0.8
                influence = 0.5 + (sin(progress * .pi) * 0.3)
                cost = progress * 0.6
            }

            let stance = ThematicResonanceMapView.ThematicStance(
                chapter: chapter,
                alignment: alignment,
                awareness: awareness,
                influence: influence,
                cost: cost
            )
            stances.append(stance)
        }

        return stances
    }

    private func determineTrajectory(stances: [ThematicResonanceMapView.ThematicStance]) -> ThematicResonanceMapView.ThematicTrajectory {
        guard stances.count >= 2 else { return .conflicted }

        let firstAlignment = stances.first!.alignment
        let lastAlignment = stances.last!.alignment
        let change = lastAlignment - firstAlignment

        let lastAwareness = stances.last!.awareness

        if abs(change) < 0.2 {
            if lastAlignment > 0.7 {
                return .embodying
            } else if lastAlignment < -0.5 {
                return .resisting
            } else {
                return .conflicted
            }
        } else if change > 0.5 {
            if lastAwareness > 0.7 {
                return .transforming
            } else {
                return .awakening
            }
        } else if change > 0.2 {
            return .embracing
        } else {
            return .resisting
        }
    }

    func openBeliefShiftMatrixPopout(matrices: [BeliefShiftMatrix]) {
        // Close existing window if open
        beliefShiftMatrixPopoutWindow?.close()
        beliefShiftMatrixPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Belief / Value Shift Matrices"
        window.minSize = NSSize(width: 1000, height: 600)
        window.isReleasedWhenClosed = false
        window.delegate = autoCloseDelegate

        // Set window appearance to match the current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Create SwiftUI view
        let beliefMatrixView = BeliefShiftMatrixView(matrices: matrices)
            .preferredColorScheme(isDarkMode ? .dark : .light)
        let hostingView = NSHostingView(rootView: beliefMatrixView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = window.contentView!.bounds

        // Create container
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.pageAround.cgColor
        container.addSubview(hostingView)

        window.contentView = container

        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        beliefShiftMatrixPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.beliefShiftMatrixPopoutWindow = nil
        }
    }

    func openDecisionConsequenceChainsPopout(chains: [DecisionConsequenceChain]) {
        // Close existing window if open
        decisionConsequenceChainPopoutWindow?.close()
        decisionConsequenceChainPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1300, height: 750),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Decision-Consequence Chains"
        window.minSize = NSSize(width: 1100, height: 650)
        window.isReleasedWhenClosed = false
        window.delegate = autoCloseDelegate

        // Set window appearance to match the current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Create SwiftUI view
        let chainView = DecisionConsequenceChainView(chains: chains)
            .preferredColorScheme(isDarkMode ? .dark : .light)
        let hostingView = NSHostingView(rootView: chainView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = window.contentView!.bounds

        // Create container
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.pageAround.cgColor
        container.addSubview(hostingView)

        window.contentView = container

        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        decisionConsequenceChainPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.decisionConsequenceChainPopoutWindow = nil
        }
    }

    func openPresencePopout(presence: [CharacterPresence]) {
        // Close existing window if open
        presencePopoutWindow?.close()
        presencePopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Character Presence"
        window.level = .normal
        window.isMovableByWindowBackground = true
        window.isExcludedFromWindowsMenu = false
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = true

        // Apply theme colors and appearance
        let theme = ThemeManager.shared.currentTheme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.backgroundColor = theme.pageBackground
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Use AppKit view for proper theme support
        let presenceView = CharacterPresenceView(frame: window.contentView!.bounds)
        presenceView.autoresizingMask = [.width, .height]
        presenceView.setPresence(presence)

        window.contentView = presenceView
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        presencePopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.presencePopoutWindow = nil
        }
    }


    // MARK: - Analysis Popout Windows

    private func refreshAnalysisPopoutContent() {
        guard let stack = analysisPopoutStack else { return }

        // Clear current content
        stack.arrangedSubviews.forEach { view in
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let header = NSTextField(labelWithString: "Document Analysis")
        header.font = NSFont.boldSystemFont(ofSize: 18)
        header.textColor = NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        stack.addArrangedSubview(header)

        guard let results = latestAnalysisResults, results.wordCount > 0 else {
            let placeholder = NSTextField(labelWithString: "No content to analyze.\n\nWrite some text and click Update.")
            placeholder.textColor = NSColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
            placeholder.maximumNumberOfLines = 0
            stack.addArrangedSubview(placeholder)
            return
        }

        // Helper functions for building UI elements in the popout
        func addHeader(_ text: String) {
            let label = makeLabel(text, size: 14, bold: true)
            label.textColor = NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
            label.alignment = .center
            stack.addArrangedSubview(label)
        }

        func addStat(_ name: String, _ value: String) {
            let label = makeLabel("\(name): \(value)", size: 12, bold: false)
            label.textColor = NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
            stack.addArrangedSubview(label)
        }

        func addWarning(_ text: String) {
            let label = makeLabel(text, size: 12, bold: false)
            label.textColor = .systemOrange
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 0
            stack.addArrangedSubview(label)
        }

        func addSuccess(_ text: String) {
            let label = makeLabel(text, size: 12, bold: false)
            label.textColor = .systemGreen
            stack.addArrangedSubview(label)
        }

        func addDetail(_ text: String) {
            let label = makeLabel(text, size: 11, bold: false)
            label.textColor = NSColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 0
            stack.addArrangedSubview(label)
        }

        func addDivider() {
            let box = NSBox()
            box.boxType = .separator
            box.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(box)
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
        if results.missingSensoryDetail {
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

        // Sentence variety
        addHeader("📊 Sentence Variety")
        addStat("Score", "\(results.sentenceVarietyScore)%")
        if !results.sentenceLengths.isEmpty {
            let graphView = createSentenceGraphForPopout(results.sentenceLengths)
            stack.addArrangedSubview(graphView)
        }
        if results.sentenceVarietyScore < 40 {
            addWarning("Low variety - mix short and long sentences")
        } else if results.sentenceVarietyScore < 70 {
            addDetail("Good variety - consider adding more variation")
        } else {
            addSuccess("✓ Excellent variety")
        }
        addDivider()

        // Dialogue Quality Analysis
        if results.dialogueSegmentCount > 0 {
            addHeader("💬 Dialogue Quality")
            addStat("Overall Score", "\(results.dialogueQualityScore)%")
            addStat("Dialogue Segments", "\(results.dialogueSegmentCount)")

            // Tip #3: Filler Words
            if results.dialogueFillerCount > 0 {
                let fillerPercent = (results.dialogueFillerCount * 100) / results.dialogueSegmentCount
                addWarning("⚠️ Filler words in \(fillerPercent)% of dialogue")
                addDetail("Tip: Remove \"uh\", \"um\", \"well\" unless characterizing speech")
            } else {
                addSuccess("✓ Minimal filler words")
            }

            // Tip #2: Repetition
            if results.dialogueRepetitionScore > 30 {
                addWarning("⚠️ Repetitive dialogue detected (\(results.dialogueRepetitionScore)%)")
                addDetail("Tip: Vary dialogue - characters shouldn't repeat phrases")
            }

            // Tip #5: Predictability
            if !results.dialoguePredictablePhrases.isEmpty {
                addWarning("⚠️ Found \(results.dialoguePredictablePhrases.count) clichéd phrase(s)")
                for phrase in results.dialoguePredictablePhrases.prefix(3) {
                    addDetail("• \"\(phrase)\"")
                }
                addDetail("Tip: Replace predictable dialogue with fresh, character-specific lines")
            }

            // Tip #7: Over-Exposition
            if results.dialogueExpositionCount > 0 {
                let expositionPercent = (results.dialogueExpositionCount * 100) / results.dialogueSegmentCount
                if expositionPercent > 20 {
                    addWarning("⚠️ \(expositionPercent)% of dialogue is info-dumping")
                    addDetail("Tip: Show through action, not lengthy explanations")
                }
            }

            // Tip #8: Conflict/Tension
            if !results.hasDialogueConflict {
                addWarning("⚠️ Dialogue lacks conflict or tension")
                addDetail("Tip: Add disagreement, subtext, or opposing goals")
            } else {
                addSuccess("✓ Good tension in dialogue")
            }

            // Tip #10: Pacing
            addStat("Pacing Variety", "\(results.dialoguePacingScore)%")
            if results.dialoguePacingScore < 40 {
                addWarning("Low pacing variety")
                addDetail("Tip: Mix short, punchy lines with longer speeches")
            } else if results.dialoguePacingScore >= 60 {
                addSuccess("✓ Good pacing variety")
            }

            // Overall quality assessment
            if results.dialogueQualityScore >= 80 {
                addSuccess("✓ Excellent dialogue quality!")
            } else if results.dialogueQualityScore >= 60 {
                addDetail("Good dialogue - minor improvements possible")
            } else {
                addWarning("Consider revising dialogue for more impact")
            }
        }
    }

    /// Helper to apply theme colors to any popout window - ensures all analysis popouts match navigator style
    private func applyThemeToPopout(window: NSWindow, container: NSView?, stack: NSStackView?) {
        let backgroundColor = currentTheme.pageAround

        window.backgroundColor = backgroundColor

        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = backgroundColor.cgColor
        }

        if let container = container {
            container.wantsLayer = true
            container.layer?.backgroundColor = backgroundColor.cgColor
        }

        if let stack = stack {
            stack.wantsLayer = true
            stack.layer?.backgroundColor = backgroundColor.cgColor
            stack.layer?.cornerRadius = 10
        }
    }

    private func applyThemeToAnalysisPopout() {
        guard let window = analysisPopoutWindow else { return }
        applyThemeToPopout(window: window, container: analysisPopoutContainer, stack: analysisPopoutStack)
    }

    private func createAnalysisPopoutWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "📊 Analysis"
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = true

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let contentView = AnalysisFlippedView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        scrollView.documentView = contentView

        if let clipView = scrollView.contentView as NSClipView? {
            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: clipView.topAnchor),
                contentView.widthAnchor.constraint(equalTo: clipView.widthAnchor)
            ])
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        window.contentView = container
        window.center()

        // Set references before applying theme
        analysisPopoutStack = stack
        analysisPopoutContainer = container

        // Apply theme colors directly (can't use applyThemeToAnalysisPopout because analysisPopoutWindow isn't set yet)
        let backgroundColor = currentTheme.pageAround
        container.layer?.backgroundColor = backgroundColor.cgColor
        window.backgroundColor = backgroundColor
        stack.wantsLayer = true
        stack.layer?.backgroundColor = backgroundColor.cgColor
        stack.layer?.cornerRadius = 10

        refreshAnalysisPopoutContent()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.analysisPopoutWindow = nil
            self?.analysisPopoutStack = nil
            self?.analysisPopoutContainer = nil
        }

        return window
    }

    private func createOutlinePopoutWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "📝 Document Outline"
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = true

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let contentView = AnalysisFlippedView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let header = NSTextField(labelWithString: "Document Outline")
        header.font = NSFont.boldSystemFont(ofSize: 18)
        stack.addArrangedSubview(header)

        // Get actual outline entries from editor
        if let entries = getOutlineEntriesCallback?(), !entries.isEmpty {
            for entry in entries {
                let indent = String(repeating: "  ", count: entry.level - 1)
                let entryLabel = NSTextField(labelWithString: "\(indent)\(entry.title)")
                entryLabel.font = NSFont.systemFont(ofSize: 13)
                entryLabel.textColor = entry.level == 1 ? .labelColor : .secondaryLabelColor
                entryLabel.lineBreakMode = .byTruncatingTail
                entryLabel.maximumNumberOfLines = 1
                stack.addArrangedSubview(entryLabel)
            }
        } else {
            let info = NSTextField(labelWithString: "No outline entries found\n\nAdd headings to your document to see the outline")
            info.textColor = .secondaryLabelColor
            info.maximumNumberOfLines = 0
            stack.addArrangedSubview(info)
        }

        contentView.addSubview(stack)
        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            stack.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -24)
        ])

        let container = NSView()
        container.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        window.contentView = container
        window.center()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.outlinePopoutWindow = nil
        }

        return window
    }

    private func createPlotPopoutWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "📖 Plot Structure Analysis"
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = true

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let contentView = AnalysisFlippedView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let header = NSTextField(labelWithString: "Plot Structure Analysis")
        header.font = NSFont.boldSystemFont(ofSize: 18)
        stack.addArrangedSubview(header)

        // Add plot visualization if available
        if let results = latestAnalysisResults, let plotAnalysis = results.plotAnalysis {
            let plotView = PlotVisualizationView()
            plotView.translatesAutoresizingMaskIntoConstraints = false
            plotView.configure(with: plotAnalysis)
            stack.addArrangedSubview(plotView)

            NSLayoutConstraint.activate([
                plotView.widthAnchor.constraint(equalTo: stack.widthAnchor),
                plotView.heightAnchor.constraint(greaterThanOrEqualToConstant: 600)
            ])
        } else {
            let info = NSTextField(labelWithString: "Plot structure visualization will appear here\n\nRun an analysis to see plot tension and pacing")
            info.textColor = .secondaryLabelColor
            info.maximumNumberOfLines = 0
            stack.addArrangedSubview(info)
        }

        contentView.addSubview(stack)
        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            stack.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -24)
        ])

        let container = NSView()
        container.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        window.contentView = container
        window.center()

        // Apply theme colors
        applyThemeToPopout(window: window, container: container, stack: stack)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.plotPopoutWindow = nil
        }

        return window
    }

    private func showCharacterAnalysisMenu(_ sender: NSButton) {
        // Trigger analysis if no data exists
        if latestAnalysisResults == nil {
            analyzeCallback?()
            // Give a moment for analysis to complete then show menu
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showCharacterAnalysisMenuAfterAnalysis(sender)
            }
        } else {
            showCharacterAnalysisMenuAfterAnalysis(sender)
        }
    }

    private func showCharacterAnalysisMenuAfterAnalysis(_ sender: NSButton) {
        let menu = NSMenu()

        // Set menu appearance to match current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        menu.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        let trajectoryItem = NSMenuItem(title: "📈 Emotional Trajectory", action: #selector(showEmotionalTrajectory), keyEquivalent: "")
        trajectoryItem.target = self
        menu.addItem(trajectoryItem)

        let loopItem = NSMenuItem(title: "📊 Decision-Belief Loops", action: #selector(showDecisionBeliefLoops), keyEquivalent: "")
        loopItem.target = self
        menu.addItem(loopItem)

        let beliefMatrixItem = NSMenuItem(title: "📋 Belief Shift Matrix", action: #selector(showBeliefShiftMatrix), keyEquivalent: "")
        beliefMatrixItem.target = self
        menu.addItem(beliefMatrixItem)

        let chainItem = NSMenuItem(title: "⛓️ Decision-Consequence Chains", action: #selector(showDecisionConsequenceChains), keyEquivalent: "")
        chainItem.target = self
        menu.addItem(chainItem)

        let relationshipMapItem = NSMenuItem(title: "🔗 Relationship Evolution Maps", action: #selector(showRelationshipEvolutionMaps), keyEquivalent: "")
        relationshipMapItem.target = self
        menu.addItem(relationshipMapItem)

        let alignmentItem = NSMenuItem(title: "🎭 Internal vs External Alignment", action: #selector(showInternalExternalAlignment), keyEquivalent: "")
        alignmentItem.target = self
        menu.addItem(alignmentItem)

        let languageDriftItem = NSMenuItem(title: "📝 Language Drift Analysis", action: #selector(showLanguageDriftAnalysis), keyEquivalent: "")
        languageDriftItem.target = self
        menu.addItem(languageDriftItem)

        let thematicResonanceItem = NSMenuItem(title: "🎯 Thematic Resonance Map", action: #selector(showThematicResonanceMap), keyEquivalent: "")
        thematicResonanceItem.target = self
        menu.addItem(thematicResonanceItem)

        let failurePatternItem = NSMenuItem(title: "📉 Failure Pattern Charts", action: #selector(showFailurePatternCharts), keyEquivalent: "")
        failurePatternItem.target = self
        menu.addItem(failurePatternItem)

        let interactionsItem = NSMenuItem(title: "🤝 Character Interactions", action: #selector(showInteractions), keyEquivalent: "")
        interactionsItem.target = self
        menu.addItem(interactionsItem)

        let presenceItem = NSMenuItem(title: "📍 Character Presence", action: #selector(showPresence), keyEquivalent: "")
        presenceItem.target = self
        menu.addItem(presenceItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @objc private func showDecisionBeliefLoops() {
        if let results = latestAnalysisResults {
            openDecisionBeliefPopout(loops: results.decisionBeliefLoops)
        } else {
            analyzeCallback?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if let results = self?.latestAnalysisResults {
                    self?.openDecisionBeliefPopout(loops: results.decisionBeliefLoops)
                }
            }
        }
    }

    @objc private func showBeliefShiftMatrix() {
        if let results = latestAnalysisResults {
            openBeliefShiftMatrixPopout(matrices: results.beliefShiftMatrices)
        } else {
            analyzeCallback?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if let results = self?.latestAnalysisResults {
                    self?.openBeliefShiftMatrixPopout(matrices: results.beliefShiftMatrices)
                }
            }
        }
    }

    @objc private func showDecisionConsequenceChains() {
        if let results = latestAnalysisResults {
            openDecisionConsequenceChainsPopout(chains: results.decisionConsequenceChains)
        } else {
            analyzeCallback?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if let results = self?.latestAnalysisResults {
                    self?.openDecisionConsequenceChainsPopout(chains: results.decisionConsequenceChains)
                }
            }
        }
    }

    @objc private func showInteractions() {
        if let results = latestAnalysisResults {
            openInteractionsPopout(interactions: results.characterInteractions)
        } else {
            analyzeCallback?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if let results = self?.latestAnalysisResults {
                    self?.openInteractionsPopout(interactions: results.characterInteractions)
                }
            }
        }
    }

    @objc private func showPresence() {
        if let results = latestAnalysisResults {
            openPresencePopout(presence: results.characterPresence)
        } else {
            analyzeCallback?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if let results = self?.latestAnalysisResults {
                    self?.openPresencePopout(presence: results.characterPresence)
                }
            }
        }
    }

    @objc private func showRelationshipEvolutionMaps() {
        if let results = latestAnalysisResults {
            openRelationshipEvolutionMapPopout(evolutionData: results.relationshipEvolutionData)
        } else {
            analyzeCallback?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if let results = self?.latestAnalysisResults {
                    self?.openRelationshipEvolutionMapPopout(evolutionData: results.relationshipEvolutionData)
                }
            }
        }
    }

    @objc private func showInternalExternalAlignment() {
        if let results = latestAnalysisResults {
            openInternalExternalAlignmentPopout(alignmentData: results.internalExternalAlignment)
        } else {
            analyzeCallback?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if let results = self?.latestAnalysisResults {
                    self?.openInternalExternalAlignmentPopout(alignmentData: results.internalExternalAlignment)
                }
            }
        }
    }

    @objc private func showLanguageDriftAnalysis() {
        if let results = latestAnalysisResults {
            openLanguageDriftPopout(driftData: results.languageDriftData)
        } else {
            analyzeCallback?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if let results = self?.latestAnalysisResults {
                    self?.openLanguageDriftPopout(driftData: results.languageDriftData)
                }
            }
        }
    }

    @objc private func showThematicResonanceMap() {
        openThematicResonanceMapPopout()
    }

    @objc private func showFailurePatternCharts() {
        openFailurePatternChartsPopout()
    }

    @objc private func showEmotionalTrajectory() {
        if let results = latestAnalysisResults {
            openEmotionalTrajectoryPopout(results: results)
        } else {
            analyzeCallback?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if let results = self?.latestAnalysisResults {
                    self?.openEmotionalTrajectoryPopout(results: results)
                }
            }
        }
    }

    private func openEmotionalTrajectoryPopout(results: AnalysisResults) {
        // If window exists and is visible, bring it to front and return
        if let existingWindow = emotionalTrajectoryPopoutWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        if emotionalTrajectoryPopoutWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Emotional Trajectory Curves"
            window.minSize = NSSize(width: 700, height: 500)
            window.isReleasedWhenClosed = false
            window.delegate = autoCloseDelegate

            emotionalTrajectoryPopoutWindow = window
        }

        guard let window = emotionalTrajectoryPopoutWindow else { return }

        // Create content view
        let containerView = NSView(frame: window.contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = currentTheme.pageAround.cgColor

        // Create toolbar for metric selection
        let toolbar = NSView(frame: NSRect(x: 0, y: window.contentView!.bounds.height - 50, width: window.contentView!.bounds.width, height: 50))
        toolbar.autoresizingMask = [.width, .minYMargin]
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = currentTheme.headerBackground.cgColor

        let titleLabel = NSTextField(labelWithString: "Emotional Trajectory Curves")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = currentTheme.textColor
        titleLabel.frame = NSRect(x: 20, y: 15, width: 300, height: 24)
        toolbar.addSubview(titleLabel)

        // Metric selector
        let metricLabel = NSTextField(labelWithString: "Metric:")
        metricLabel.font = NSFont.systemFont(ofSize: 12)
        metricLabel.textColor = currentTheme.textColor
        metricLabel.frame = NSRect(x: 350, y: 18, width: 50, height: 20)
        toolbar.addSubview(metricLabel)

        let metricPopup = NSPopUpButton(frame: NSRect(x: 410, y: 13, width: 200, height: 26))
        for metric in EmotionalTrajectoryView.EmotionalMetric.allCases {
            metricPopup.addItem(withTitle: metric.rawValue)
        }
        metricPopup.target = self
        metricPopup.action = #selector(metricChanged(_:))
        toolbar.addSubview(metricPopup)

        containerView.addSubview(toolbar)

        // Create trajectory view
        let trajectoryView = EmotionalTrajectoryView(frame: NSRect(x: 20, y: 20, width: window.contentView!.bounds.width - 40, height: window.contentView!.bounds.height - 90))
        trajectoryView.autoresizingMask = [.width, .height]

        // Generate sample trajectory data from analysis results
        let trajectories = generateEmotionalTrajectories(from: results)
        trajectoryView.setTrajectories(trajectories)

        containerView.addSubview(trajectoryView)

        window.contentView = containerView
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func metricChanged(_ sender: NSPopUpButton) {
        guard let window = emotionalTrajectoryPopoutWindow,
              let containerView = window.contentView,
              let trajectoryView = containerView.subviews.first(where: { $0 is EmotionalTrajectoryView }) as? EmotionalTrajectoryView else {
            return
        }

        let metrics = EmotionalTrajectoryView.EmotionalMetric.allCases
        guard sender.indexOfSelectedItem >= 0 && sender.indexOfSelectedItem < metrics.count else {
            return
        }

        let selectedMetric = metrics[sender.indexOfSelectedItem]
        trajectoryView.setMetric(selectedMetric)
    }

    private func generateEmotionalTrajectories(from results: AnalysisResults) -> [EmotionalTrajectoryView.CharacterTrajectory] {
        var trajectories: [EmotionalTrajectoryView.CharacterTrajectory] = []

        // Get character names from presence data
        let characterNames = results.characterPresence.prefix(3).map { $0.characterName } // Top 3 characters

        let colors: [NSColor] = [.systemBlue, .systemRed, .systemGreen, .systemOrange, .systemPurple]

        for (index, characterName) in characterNames.enumerated() {
            // Generate emotional states based on character presence and arc
            var states: [EmotionalTrajectoryView.EmotionalState] = []

            // Create states at 10% intervals
            for i in 0...10 {
                let position = Double(i) / 10.0

                // Generate emotional values with some variation
                // This is simplified - in a real implementation, you'd analyze actual text
                let baseConfidence = sin(position * .pi * 2) * 0.6
                let baseHope = cos(position * .pi * 1.5) * 0.7 - 0.2
                let baseControl = sin(position * .pi * 3) * 0.5 + 0.2
                let baseAttachment = cos(position * .pi * 2.5) * 0.6

                // Add character-specific variation
                let charVariation = Double(index) * 0.3

                let state = EmotionalTrajectoryView.EmotionalState(
                    position: position,
                    confidence: baseConfidence + charVariation * 0.1,
                    hope: baseHope - charVariation * 0.2,
                    control: baseControl + charVariation * 0.15,
                    attachment: baseAttachment - charVariation * 0.1
                )
                states.append(state)
            }

            let trajectory = EmotionalTrajectoryView.CharacterTrajectory(
                characterName: characterName,
                color: colors[index % colors.count],
                states: states,
                isDashed: false
            )
            trajectories.append(trajectory)

            // Optionally add a "subtext" version (dashed) for the first character
            if index == 0 {
                var subtextStates: [EmotionalTrajectoryView.EmotionalState] = []
                for i in 0...10 {
                    let position = Double(i) / 10.0
                    let baseConfidence = sin(position * .pi * 2 + 0.5) * 0.6 - 0.3
                    let baseHope = cos(position * .pi * 1.5 + 0.5) * 0.7 - 0.5
                    let baseControl = sin(position * .pi * 3 + 0.5) * 0.5 - 0.1
                    let baseAttachment = cos(position * .pi * 2.5 + 0.5) * 0.6 - 0.2

                    let state = EmotionalTrajectoryView.EmotionalState(
                        position: position,
                        confidence: baseConfidence,
                        hope: baseHope,
                        control: baseControl,
                        attachment: baseAttachment
                    )
                    subtextStates.append(state)
                }

                let subtextTrajectory = EmotionalTrajectoryView.CharacterTrajectory(
                    characterName: characterName,
                    color: colors[index % colors.count],
                    states: subtextStates,
                    isDashed: true
                )
                trajectories.append(subtextTrajectory)
            }
        }

        return trajectories
    }
}

// Helper extension for safe array access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

