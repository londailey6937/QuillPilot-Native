//
//  SplitViewController.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class SplitViewController: NSSplitViewController {

    private var editorViewController: EditorViewController!
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
        analysisItem.canCollapse = true
        analysisItem.minimumThickness = 250
        analysisItem.maximumThickness = 400
        addSplitViewItem(analysisItem)

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
        guard let text = editorViewController.getTextContent() else {
            print("❌ No text content")
            return
        }
        print("📝 Text length: \(text.count)")

        let results = analysisEngine.analyzeText(text)
        print("✅ Analysis complete: wordCount=\(results.wordCount), sentenceCount=\(results.sentenceCount)")
        
        analysisViewController.displayResults(results)
        print("✅ displayResults called")

        // Show sidebar if collapsed
        if let analysisItem = splitViewItems.last, analysisItem.isCollapsed {
            print("📂 Opening sidebar")
            analysisItem.animator().isCollapsed = false
        } else {
            print("📂 Sidebar already open")
        }
    }
}

// MARK: - EditorViewControllerDelegate
extension SplitViewController: EditorViewControllerDelegate {
    func textDidChange() {
        // Auto-analyze after a short delay
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performAnalysisDelayed), object: nil)
        perform(#selector(performAnalysisDelayed), with: nil, afterDelay: 1.0)
    }
    
    func titleDidChange(_ title: String) {
        // Title changed in editor
    }

    @objc private func performAnalysisDelayed() {
        performAnalysis()
    }
}
