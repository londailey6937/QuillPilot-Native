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
        outlineItem.minimumThickness = 280
        outlineItem.maximumThickness = 360
        outlineItem.holdingPriority = .init(260)
        outlineItem.isCollapsed = false
        addSplitViewItem(outlineItem)

        // Editor in the middle
        editorViewController = EditorViewController()
        editorViewController.delegate = self
        let editorItem = NSSplitViewItem(viewController: editorViewController)
        editorItem.canCollapse = false
        editorItem.minimumThickness = 480
        addSplitViewItem(editorItem)

        // Analysis panel on the right (wider for visualizations)
        analysisViewController = AnalysisViewController()
        analysisViewController.isOutlinePanel = false
        let analysisItem = NSSplitViewItem(viewController: analysisViewController)
        analysisItem.canCollapse = true
        analysisItem.minimumThickness = 520
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
        print("[DEBUG] SplitViewController.viewDidLoad - adding observer for ToggleSidebars")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toggleAllSidebars),
            name: NSNotification.Name("ToggleSidebars"),
            object: nil
        )
        print("[DEBUG] SplitViewController.viewDidLoad - observer added")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        guard !didSetInitialSplitPositions else { return }
        didSetInitialSplitPositions = true

        // Aim for a wider analysis panel (30–40% of total), while keeping editor comfortable
        let totalWidth = view.bounds.width
        let outlineWidth: CGFloat = 280
        let targetAnalysis = max(520, min(640, totalWidth * 0.34))
        let remainingForEditor = totalWidth - outlineWidth - targetAnalysis
        let editorWidth = max(700, remainingForEditor)

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
        if let analysisItem = splitViewItems.last {
            analysisItem.animator().isCollapsed = !analysisItem.isCollapsed
        }
    }

    @objc func toggleAllSidebars() {
        // Toggle the icon menu sidebars on both outline (left) and analysis (right) panels
        print("[DEBUG] toggleAllSidebars called")
        print("[DEBUG] outlinePanelController: \(outlinePanelController != nil)")
        print("[DEBUG] analysisViewController: \(analysisViewController != nil)")
        outlinePanelController.toggleMenuSidebar()
        analysisViewController.toggleMenuSidebar()
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

            // Convert to DecisionBeliefLoopAnalyzer.OutlineEntry format
            let analyzerOutlineEntries: [DecisionBeliefLoopAnalyzer.OutlineEntry]? = outlineEntries.isEmpty ? nil : outlineEntries.map { entry in
                DecisionBeliefLoopAnalyzer.OutlineEntry(
                    title: entry.title,
                    level: entry.level,
                    range: entry.range,
                    page: entry.page
                )
            }

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

    func selectionDidChange() {
        // Selection changed in editor (not used in this view controller)
    }

    @objc private func performAnalysisDelayed() {
        performAnalysis()
    }
}
