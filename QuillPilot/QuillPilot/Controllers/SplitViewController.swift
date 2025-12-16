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
    private var analysisViewController: AnalysisViewController!
    private var analysisEngine: AnalysisEngine!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize analysis engine
        analysisEngine = AnalysisEngine()

        // Create editor view controller
        editorViewController = EditorViewController()
        editorViewController.delegate = self
        let editorItem = NSSplitViewItem(viewController: editorViewController)
        editorItem.canCollapse = false
        editorItem.minimumThickness = 400
        addSplitViewItem(editorItem)

        // Create analysis view controller
        analysisViewController = AnalysisViewController()
        let analysisItem = NSSplitViewItem(sidebarWithViewController: analysisViewController)
        analysisItem.canCollapse = false  // Keep it visible for debugging
        analysisItem.minimumThickness = 320
        analysisItem.maximumThickness = 520
        analysisItem.isCollapsed = false  // Ensure it starts visible
        addSplitViewItem(analysisItem)

        // Set callback AFTER adding to split view to ensure view is loaded
        NSLog("🔧 Setting analyzeCallback on analysisViewController: \(Unmanaged.passUnretained(analysisViewController).toOpaque())")
        analysisViewController.analyzeCallback = { [weak self] in
            NSLog("🔗 Callback triggered from button")
            self?.performAnalysis()
        }
        NSLog("✅ analyzeCallback set successfully, is nil? \(analysisViewController.analyzeCallback == nil)")

        // Configure split view
        splitView.dividerStyle = .thin
        splitView.autosaveName = "QuillPilotSplitView"
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

        let results = analysisEngine.analyzeText(text)
        print("✅ Analysis complete: wordCount=\(results.wordCount), sentenceCount=\(results.sentenceCount)")

        analysisViewController.displayResults(results)
        print("✅ displayResults called")
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

    @objc private func performAnalysisDelayed() {
        performAnalysis()
    }
}
