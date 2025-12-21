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
        NSLog("🔧 Setting analyzeCallback on analysisViewController: \(Unmanaged.passUnretained(analysisViewController).toOpaque())")
        analysisViewController.analyzeCallback = { [weak self] in
            NSLog("🔗 Callback triggered from button")
            self?.performAnalysis()
        }
        analysisViewController.getOutlineEntriesCallback = { [weak self] in
            return self?.editorViewController.buildOutlineEntries() ?? []
        }
        NSLog("✅ analyzeCallback set successfully, is nil? \(analysisViewController.analyzeCallback == nil)")

        // Configure split view
        splitView.dividerStyle = .thin
        splitView.autosaveName = "QuillPilotSplitView"
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

    // MARK: - Analysis

    private var analysisWorkItem: DispatchWorkItem?

    private func performAnalysis() {
        print("🔍 performAnalysis called")

        // Show sidebar if collapsed
        if let analysisItem = splitViewItems.last, analysisItem.isCollapsed {
            print("📂 Opening sidebar")
            analysisItem.animator().isCollapsed = false
        }

        guard let text = editorViewController.getTextContent(), !text.isEmpty else {
            print("❌ No text content")
            // Display empty results to show message
            let emptyResults = analysisEngine.analyzeText("")
            analysisViewController.displayResults(emptyResults)
            return
        }
        print("📝 Text length: \(text.count)")

        // Cancel any pending analysis
        analysisWorkItem?.cancel()

        // Run analysis on background thread to prevent UI freeze
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let results = self.analysisEngine.analyzeText(text)
            print("✅ Analysis complete: wordCount=\(results.wordCount), sentenceCount=\(results.sentenceCount)")

            // Update UI on main thread
            DispatchQueue.main.async { [weak self] in
                self?.analysisViewController.displayResults(results)
                print("✅ displayResults called")
            }
        }
        analysisWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
}

// MARK: - EditorViewControllerDelegate
extension SplitViewController: EditorViewControllerDelegate {
    func textDidChange() {
        NSLog("📝 textDidChange called in SplitViewController")
        // Auto-analyze after a short delay, but only if sidebar is visible
        guard let analysisItem = splitViewItems.last, !analysisItem.isCollapsed else {
            NSLog("⏸️ Auto-analysis skipped: sidebar collapsed")
            return
        }
        NSLog("⏱️ Scheduling auto-analysis in 1.5s")
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performAnalysisDelayed), object: nil)
        perform(#selector(performAnalysisDelayed), with: nil, afterDelay: 1.5)
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
