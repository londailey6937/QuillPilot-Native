//
//  SplitViewController.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class SplitViewController: NSSplitViewController {

    var editorViewController: EditorViewController!
    private var outlineViewController: OutlineViewController!
    private var outlinePanelController: AnalysisViewController!
    private var analysisViewController: AnalysisViewController!
    private var analysisEngine: AnalysisEngine!
    private var didSetInitialSplitPositions = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize analysis engine
        analysisEngine = AnalysisEngine()

        // Outline panel on the left (mirrors analysis UI but shows outline)
        outlineViewController = OutlineViewController()
        outlinePanelController = AnalysisViewController()
        outlinePanelController.isOutlinePanel = true
        outlinePanelController.outlineViewController = outlineViewController
        let outlineItem = NSSplitViewItem(sidebarWithViewController: outlinePanelController)
        outlineItem.canCollapse = true
        outlineItem.minimumThickness = 160
        outlineItem.maximumThickness = 360
        outlineItem.holdingPriority = .init(260)
        outlineItem.isCollapsed = false
        addSplitViewItem(outlineItem)

        // Editor in the middle
        editorViewController = EditorViewController()
        editorViewController.delegate = self
        let editorItem = NSSplitViewItem(viewController: editorViewController)
        editorItem.canCollapse = false
        editorItem.minimumThickness = 300
        addSplitViewItem(editorItem)

        // Analysis panel on the right (wider for visualizations)
        analysisViewController = AnalysisViewController()
        analysisViewController.isOutlinePanel = false
        let analysisItem = NSSplitViewItem(viewController: analysisViewController)
        analysisItem.canCollapse = true
        analysisItem.minimumThickness = 260
        analysisItem.maximumThickness = 1100
        analysisItem.holdingPriority = .init(200)
        analysisItem.isCollapsed = false
        addSplitViewItem(analysisItem)

        // Set callback AFTER adding to split view to ensure view is loaded
        analysisViewController.analyzeCallback = { [weak self] in
            self?.performAnalysis()
        }
        analysisViewController.getOutlineEntriesCallback = { [weak self] in
            return self?.editorViewController.buildOutlineEntries() ?? []
        }

        // Configure split view
        splitView.dividerStyle = .thin
        splitView.autosaveName = "QuillPilotSplitView"

        // Listen for sidebar toggle notification
        DebugLog.log("[DEBUG] SplitViewController.viewDidLoad - adding observer for ToggleSidebars")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toggleAllSidebars),
            name: NSNotification.Name("ToggleSidebars"),
            object: nil
        )
        DebugLog.log("[DEBUG] SplitViewController.viewDidLoad - observer added")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        guard !didSetInitialSplitPositions else { return }
        didSetInitialSplitPositions = true

        // Responsive split layout that adapts to narrower window widths.
        let totalWidth = view.bounds.width
        let outlineMin: CGFloat = 160
        let outlineMax: CGFloat = 320
        let analysisMin: CGFloat = 260
        let analysisMax: CGFloat = 640
        let editorMin: CGFloat = 300

        var outlineWidth = min(outlineMax, max(outlineMin, totalWidth * 0.20))
        var analysisWidth = min(analysisMax, max(analysisMin, totalWidth * 0.28))
        var remainingForEditor = totalWidth - outlineWidth - analysisWidth

        if remainingForEditor < editorMin {
            var deficit = editorMin - remainingForEditor
            let analysisReducible = analysisWidth - analysisMin
            let reduceAnalysis = min(deficit, analysisReducible)
            analysisWidth -= reduceAnalysis
            deficit -= reduceAnalysis

            let outlineReducible = outlineWidth - outlineMin
            let reduceOutline = min(deficit, outlineReducible)
            outlineWidth -= reduceOutline
            deficit -= reduceOutline

            remainingForEditor = totalWidth - outlineWidth - analysisWidth
        }

        let editorWidth = max(editorMin, remainingForEditor)

        let firstDivider = outlineWidth
        let secondDivider = outlineWidth + editorWidth

        if splitView.subviews.count >= 3 {
            splitView.setPosition(firstDivider, ofDividerAt: 0)
            splitView.setPosition(secondDivider, ofDividerAt: 1)
        }
    }

    // MARK: - Toolbar Actions

    @objc func toggleBold(_ sender: Any?) {
        editorViewController.toggleBold()
    }

    @objc func toggleItalic(_ sender: Any?) {
        editorViewController.toggleItalic()
    }

    @objc func analyzeText(_ sender: Any?) {
        performAnalysis()
    }

    @objc override func toggleSidebar(_ sender: Any?) {
        // Match the app's expected behavior: Toggle Sidebar should toggle *all* sidebars.
        toggleAllSidebars()
    }

    @objc func toggleAllSidebars() {
        // Toggle both sidebar *panels* together.
        guard let outlineItem = splitViewItems.first, let analysisItem = splitViewItems.last else { return }
        let anyVisible = !outlineItem.isCollapsed || !analysisItem.isCollapsed
        outlineItem.animator().isCollapsed = anyVisible
        analysisItem.animator().isCollapsed = anyVisible
    }

    // MARK: - Analysis

    private var analysisWorkItem: DispatchWorkItem?

    private func performAnalysis() {
        // Show sidebar if collapsed
        if let analysisItem = splitViewItems.last, analysisItem.isCollapsed {
            analysisItem.animator().isCollapsed = false
        }

        guard let text = editorViewController.getTextContent(), !text.isEmpty else {
            // Display empty results to show message
            let emptyResults = analysisEngine.analyzeText("")
            analysisViewController.displayResults(emptyResults)
            return
        }

        // Cancel any pending analysis
        analysisWorkItem?.cancel()

        // Run analysis on background thread to prevent UI freeze
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // Get outline entries from editor
            let outlineEntries = self.editorViewController.buildOutlineEntries()

            // Convert to DecisionBeliefLoopAnalyzer.OutlineEntry format (filtered to chapter-relevant headings)
            let analyzerOutlineEntries: [DecisionBeliefLoopAnalyzer.OutlineEntry]? = {
                guard !outlineEntries.isEmpty else { return nil }

                if StyleCatalog.shared.isScreenplayTemplate {
                    // For screenplays, presence is driven by sluglines (scenes), but we also want ACT I/II/III markers
                    // so the UI can aggregate accurately by act.
                    func parseActNumber(from title: String) -> Int? {
                        let t = title.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        guard t.hasPrefix("ACT") else { return nil }

                        // Normalize punctuation and split.
                        let cleaned = t.replacingOccurrences(of: ".", with: " ")
                            .replacingOccurrences(of: ":", with: " ")
                            .replacingOccurrences(of: "-", with: " ")
                        let parts = cleaned.split(whereSeparator: { $0.isWhitespace })
                        guard parts.count >= 2 else { return nil }

                        let token = String(parts[1])
                        switch token {
                        case "I", "1": return 1
                        case "II", "2": return 2
                        case "III", "3": return 3
                        case "IV", "4": return 4
                        case "V", "5": return 5
                        default:
                            if let n = Int(token) { return n }
                            return nil
                        }
                    }

                    func isActHeading(_ title: String) -> Bool {
                        parseActNumber(from: title) != nil
                    }

                    let sorted = outlineEntries.sorted { $0.range.location < $1.range.location }

                    let sceneEntries = sorted.filter { ($0.styleName ?? "") == "Screenplay — Slugline" }
                    let actEntries = sorted.filter { isActHeading($0.title) }

                    let combined = (sceneEntries + actEntries)
                        .sorted { $0.range.location < $1.range.location }

                    guard !combined.isEmpty else { return nil }
                    return combined.map { entry in
                        let level: Int
                        if entry.styleName == "Screenplay — Slugline" {
                            level = 1
                        } else if isActHeading(entry.title) {
                            level = 0
                        } else {
                            level = entry.level
                        }

                        return DecisionBeliefLoopAnalyzer.OutlineEntry(
                            title: entry.title,
                            level: level,
                            range: entry.range,
                            page: entry.page
                        )
                    }
                }

                let bannedStyles: Set<String> = [
                    "TOC Title",
                    "Index Title",
                    "Glossary Title",
                    "Appendix Title"
                ]
                let preferredChapterStyles: Set<String> = [
                    "Chapter Number",
                    "Chapter Title"
                ]

                func isNonChapterTitle(_ title: String) -> Bool {
                    let t = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    return t == "table of contents" || t == "contents" || t == "toc" || t == "index" || t == "glossary" || t == "appendix"
                }

                func looksLikeChapterHeading(_ title: String) -> Bool {
                    let t = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if t.hasPrefix("chapter ") { return true }
                    if t.hasPrefix("ch ") || t.hasPrefix("ch.") { return true }
                    if t.hasPrefix("prologue") || t.hasPrefix("epilogue") { return true }
                    return false
                }

                let sorted = outlineEntries.sorted { $0.range.location < $1.range.location }
                let candidatesLevel1 = sorted.filter {
                    $0.level == 1 && !(($0.styleName).map { bannedStyles.contains($0) } ?? false) && !isNonChapterTitle($0.title)
                }

                // Prefer explicit chapter styles when present.
                let preferred = candidatesLevel1.filter { ($0.styleName).map { preferredChapterStyles.contains($0) } ?? false }
                let chapterEntries: [EditorViewController.OutlineEntry]
                if preferred.count >= 2 {
                    chapterEntries = preferred
                } else {
                    // Otherwise, try to use chapter-ish titles (common for Heading 1).
                    let chapterish = candidatesLevel1.filter { looksLikeChapterHeading($0.title) }
                    if chapterish.count >= 2 {
                        chapterEntries = chapterish
                    } else {
                        // Last resort: use remaining level-1 headings (still excluding TOC/Index/Glossary/Appendix).
                        chapterEntries = candidatesLevel1
                    }
                }

                guard !chapterEntries.isEmpty else { return nil }
                return chapterEntries.map { entry in
                    DecisionBeliefLoopAnalyzer.OutlineEntry(
                        title: entry.title,
                        level: entry.level,
                        range: entry.range,
                        page: entry.page
                    )
                }
            }()

            let results = self.analysisEngine.analyzeText(text, outlineEntries: analyzerOutlineEntries)

            // Update UI on main thread
            DispatchQueue.main.async { [weak self] in
                self?.analysisViewController.displayResults(results)
            }
        }
        analysisWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    // MARK: - Clear Analysis

    func clearAnalysis() {
        // Cancel any pending analysis
        analysisWorkItem?.cancel()
        // Clear the analysis results
        analysisViewController.latestAnalysisResults = nil
        analysisViewController.clearAllAnalysisUI()
    }
}

// MARK: - EditorViewControllerDelegate
extension SplitViewController: EditorViewControllerDelegate {
    func textDidChange() {
        // Auto-analyze after a short delay, but only if sidebar is visible
        guard let analysisItem = splitViewItems.last, !analysisItem.isCollapsed else {
            return
        }
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performAnalysisDelayed), object: nil)
        perform(#selector(performAnalysisDelayed), with: nil, afterDelay: 1.5)
    }

    func suspendAnalysisForLayout() {
        // No-op: analysis already throttled; handled via textDidChange guard
    }

    func resumeAnalysisAfterLayout() {
        textDidChange()
    }

    func applyTheme(_ theme: AppTheme) {
        outlineViewController.applyTheme(theme)
        analysisViewController.applyTheme(theme)
        outlinePanelController.applyTheme(theme)
    }

    func titleDidChange(_ title: String) {
        // Title changed in editor
    }

    func authorDidChange(_ author: String) {
        // Author changed in editor
    }

    func selectionDidChange() {
        // Selection changed in editor (not used in this view controller)
    }

    @objc private func performAnalysisDelayed() {
        performAnalysis()
    }
}
