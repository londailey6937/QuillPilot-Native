//
//  MainWindowController.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa
import UniformTypeIdentifiers
import ObjectiveC

@MainActor
protocol FormattingToolbarDelegate: AnyObject {
    func formattingToolbarDidNewDocument(_ toolbar: FormattingToolbar)
    func formattingToolbarDidOpenDocument(_ toolbar: FormattingToolbar)
    func formattingToolbarDidSaveAs(_ toolbar: FormattingToolbar)
    func formattingToolbarDidPrint(_ toolbar: FormattingToolbar)
    func formattingToolbarDidUndo(_ toolbar: FormattingToolbar)
    func formattingToolbarDidRedo(_ toolbar: FormattingToolbar)
    func formattingToolbarDidCut(_ toolbar: FormattingToolbar)
    func formattingToolbarDidCopy(_ toolbar: FormattingToolbar)
    func formattingToolbarDidPaste(_ toolbar: FormattingToolbar)
    func formattingToolbarDidInsertHyperlink(_ toolbar: FormattingToolbar)

    func formattingToolbarDidIndent(_ toolbar: FormattingToolbar)
    func formattingToolbarDidOutdent(_ toolbar: FormattingToolbar)
    func formattingToolbarDidSave(_ toolbar: FormattingToolbar)

    func formattingToolbar(_ toolbar: FormattingToolbar, didSelectStyle styleName: String)

    func formattingToolbarDidToggleBold(_ toolbar: FormattingToolbar)
    func formattingToolbarDidToggleItalic(_ toolbar: FormattingToolbar)
    func formattingToolbarDidToggleUnderline(_ toolbar: FormattingToolbar)
    func formattingToolbarDidToggleStrikethrough(_ toolbar: FormattingToolbar)
    func formattingToolbarDidToggleSuperscript(_ toolbar: FormattingToolbar)
    func formattingToolbarDidToggleSubscript(_ toolbar: FormattingToolbar)

    func formattingToolbar(_ toolbar: FormattingToolbar, didChangeFontFamily family: String)
    func formattingToolbar(_ toolbar: FormattingToolbar, didChangeFontSize size: CGFloat)

    func formattingToolbarDidAlignLeft(_ toolbar: FormattingToolbar)
    func formattingToolbarDidAlignCenter(_ toolbar: FormattingToolbar)
    func formattingToolbarDidAlignRight(_ toolbar: FormattingToolbar)
    func formattingToolbarDidAlignJustify(_ toolbar: FormattingToolbar)

    func formattingToolbarDidToggleBullets(_ toolbar: FormattingToolbar)
    func formattingToolbarDidToggleNumbering(_ toolbar: FormattingToolbar)

    func formattingToolbarDidInsertColumnBreak(_ toolbar: FormattingToolbar)
    func formattingToolbarDidInsertImage(_ toolbar: FormattingToolbar)
    func formattingToolbarDidColumns(_ toolbar: FormattingToolbar)
    func formattingToolbarDidDeleteColumn(_ toolbar: FormattingToolbar)
    func formattingToolbarDidInsertTable(_ toolbar: FormattingToolbar)
    func formattingToolbarDidClearAll(_ toolbar: FormattingToolbar)
    func formattingToolbarDidFormatPainter(_ toolbar: FormattingToolbar)
    func formattingToolbarDidToggleOutlinePanel(_ toolbar: FormattingToolbar)

    func formattingToolbarDidToggleParagraphMarks(_ toolbar: FormattingToolbar)

    func formattingToolbarDidOpenStyleEditor(_ toolbar: FormattingToolbar)
}

class MainWindowController: NSWindowController {
    private var activePrintOperation: NSPrintOperation?

    private var headerView: HeaderView!
    private var toolbarView: FormattingToolbar!
    private var rulerView: EnhancedRulerView!
    private var rulerHeightConstraint: NSLayoutConstraint?
    private var rulerWidthConstraint: NSLayoutConstraint?
    var mainContentViewController: ContentViewController!
    private var themeObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    private var headerFooterSettingsWindow: HeaderFooterSettingsWindow?
    private var styleEditorWindow: StyleEditorWindowController?
    private var tocIndexWindow: TOCIndexWindowController?
    private var searchPanel: SearchPanelController?

    // Notes
    private var generalNotesWindow: GeneralNotesWindowController?

    // View controllers (referenced in multiple methods)
    private var outlinePanelController: AnalysisViewController!
    private var analysisViewController: AnalysisViewController!

    // Document tracking for auto-save
    private var currentDocumentURL: URL?
    private var currentDocumentFormat: ExportFormat = .docx
    private var autoSaveTimer: Timer?
    private var hasUnsavedChanges = false

    // Sheet field references
    private var columnsSheetField: NSTextField?
    private var tableRowsSheetField: NSTextField?
    private var tableColsSheetField: NSTextField?


    convenience init() {
        let window = NSWindow(
                      contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Quill Pilot"
        window.minSize = NSSize(width: 800, height: 600)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        if let screenFrame = NSScreen.main?.visibleFrame {
            let targetSize = NSSize(width: 1200, height: 800)
            let origin = NSPoint(
                x: screenFrame.midX - targetSize.width / 2,
                y: screenFrame.midY - targetSize.height / 2
            )
            let targetFrame = NSRect(origin: origin, size: targetSize)
            window.setFrame(targetFrame, display: false)
        } else {
            window.center()
        }

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let window = window else { return }

        // Handle close warnings for unsaved (not-yet-auto-saved) changes
        window.delegate = self

        // Create main container view sized to the current content rect
        let initialBounds = window.contentView?.bounds ?? NSRect(origin: .zero, size: window.contentLayoutRect.size)
        let containerView = NSView(frame: initialBounds)
        containerView.autoresizingMask = [.width, .height]
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = ThemeManager.shared.currentTheme.pageAround.cgColor

        // Create header (logo, title, specs, theme toggle) - 60px tall
        headerView = HeaderView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(headerView)

        // Create formatting toolbar - 50px tall
        toolbarView = FormattingToolbar()
        toolbarView.delegate = self
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(toolbarView)

        // Create ruler - 30px tall
        rulerView = EnhancedRulerView()
        // Store page width in points (8.5" = 612pt). The ruler view itself is sized to the
        // scaled width so the marks/handles align with the on-screen page at the editor zoom.
        rulerView.pageWidth = 612
        rulerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(rulerView)

        // Create 3-column content area (outline | editor | analysis)
        mainContentViewController = ContentViewController()
        mainContentViewController.onTitleChange = { [weak self] title in
            self?.headerView.setDocumentTitle(title)
        }
        mainContentViewController.onAuthorChange = { [weak self] author in
            self?.headerView.specsPanel.setAuthor(author)
        }
        mainContentViewController.onStatsUpdate = { [weak self] text in
            self?.headerView.specsPanel.updateStats(text: text)
        }
        mainContentViewController.onSelectionChange = { [weak self] styleName in
            self?.toolbarView.updateSelectedStyle(styleName)
        }
        mainContentViewController.onTextChange = { [weak self] in
            self?.markDocumentDirty()
        }

        mainContentViewController.onNotesTapped = { [weak self] in
            self?.openNotesWindow()
        }

        // Connect manuscript info changes to editor headers/footers
        headerView.specsPanel.onManuscriptInfoChanged = { [weak self] title, author in
            self?.mainContentViewController.editorViewController.setManuscriptInfo(title: title, author: author)
        }

        let contentView = mainContentViewController.view
        contentView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentView)

        rulerView.delegate = mainContentViewController
        mainContentViewController.setRuler(rulerView)

        // Keep the ruler zoom synchronized with the editor zoom.
        rulerView.rulerZoom = mainContentViewController.editorViewController.editorZoom

        // Set up constraints
        var constraints: [NSLayoutConstraint] = [
            // Header at top
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),

            // Toolbar below header
            toolbarView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            toolbarView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            toolbarView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            toolbarView.heightAnchor.constraint(equalToConstant: 50),

            // Ruler vertical placement
            rulerView.topAnchor.constraint(equalTo: toolbarView.bottomAnchor),
            rulerView.heightAnchor.constraint(equalToConstant: 30),

            // Content fills remaining space
            contentView.topAnchor.constraint(equalTo: rulerView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            // (Notes button now lives in the left sidebar under Characters)
        ]

        rulerHeightConstraint = constraints.first(where: { $0.firstItem as AnyObject? === rulerView && $0.firstAttribute == .height })

        if let editorLeading = mainContentViewController.editorLeadingAnchor,
           let editorTrailing = mainContentViewController.editorTrailingAnchor {
            // Keep the ruler aligned to the editor page (not the full 3-column content area).
            let editorCenter = mainContentViewController.editorCenterXAnchor ?? contentView.centerXAnchor
            constraints.append(rulerView.centerXAnchor.constraint(equalTo: editorCenter))
            let width = rulerView.widthAnchor.constraint(equalToConstant: rulerView.scaledPageWidth)
            width.isActive = true
            rulerWidthConstraint = width
            constraints.append(rulerView.leadingAnchor.constraint(greaterThanOrEqualTo: editorLeading))
            constraints.append(rulerView.trailingAnchor.constraint(lessThanOrEqualTo: editorTrailing))
        } else {
            constraints.append(rulerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor))
            constraints.append(rulerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor))
        }

        NSLayoutConstraint.activate(constraints)

        window.contentView = containerView
        applyTheme(ThemeManager.shared.currentTheme)
        themeObserver = NotificationCenter.default.addObserver(forName: .themeDidChange, object: nil, queue: .main) { [weak self] notification in
            guard
                let self,
                let theme = notification.object as? AppTheme
            else { return }
            self.applyTheme(theme)
        }

        settingsObserver = NotificationCenter.default.addObserver(forName: .quillPilotSettingsDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.startAutoSaveTimer()
        }

        // Initialize scene list with no document (clears any persisted scenes)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.mainContentViewController?.documentDidChange(url: nil)
        }

        // Listen for search panel requests
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ShowSearchPanel"), object: nil, queue: .main) { [weak self] _ in
            self?.showSearchPanel()
        }

        // Update stats panel with initial text once the editor is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self,
                  let text = self.mainContentViewController.editorViewController.textView?.string else {
                return
            }
            self.headerView.specsPanel.updateStats(text: text)
            let isShown = self.mainContentViewController.editorViewController.paragraphMarksVisible()
            self.toolbarView.updateParagraphMarksState(isShown)
        }

        // Start auto-save timer (interval set in Preferences)
        startAutoSaveTimer()
    }

    var isRulerVisible: Bool {
        !(rulerView?.isHidden ?? true) && ((rulerHeightConstraint?.constant ?? 0) > 0)
    }

    private func syncRulerZoomToEditor() {
        guard let editor = mainContentViewController?.editorViewController else { return }
        rulerView?.rulerZoom = editor.editorZoom
        if let rulerView {
            rulerWidthConstraint?.constant = rulerView.scaledPageWidth
        }
        window?.contentView?.needsLayout = true
    }

    func syncParagraphMarksToolbarState() {
        let isShown = mainContentViewController.editorViewController.paragraphMarksVisible()
        toolbarView?.updateParagraphMarksState(isShown)
    }

    func zoomIn() {
        mainContentViewController?.editorViewController.zoomIn()
        syncRulerZoomToEditor()
    }

    func zoomOut() {
        mainContentViewController?.editorViewController.zoomOut()
        syncRulerZoomToEditor()
    }

    func zoomActualSize() {
        mainContentViewController?.editorViewController.zoomActualSize()
        syncRulerZoomToEditor()
    }

    @objc func toggleRulerVisibility(_ sender: Any?) {
        let shouldShow = !isRulerVisible
        rulerView.isHidden = !shouldShow
        rulerHeightConstraint?.constant = shouldShow ? 30 : 0
        window?.layoutIfNeeded()
    }

    private func applyTheme(_ theme: AppTheme) {
        guard let containerLayer = window?.contentView?.layer else { return }
        containerLayer.backgroundColor = theme.pageAround.cgColor
        containerLayer.setNeedsDisplay()

        // Set the window's appearance to match the theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window?.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        headerView.applyTheme(theme)
        toolbarView.applyTheme(theme)
        rulerView.applyTheme(theme)
        mainContentViewController.applyTheme(theme)
    }

    private func openNotesWindow() {
        if generalNotesWindow == nil {
            generalNotesWindow = GeneralNotesWindowController()
        }
        generalNotesWindow?.setDocumentURL(currentDocumentURL)
        generalNotesWindow?.showWindow(nil)
        if let parent = window, let notesWindow = generalNotesWindow?.window {
            let alreadyChild = parent.childWindows?.contains(notesWindow) ?? false
            if !alreadyChild {
                parent.addChildWindow(notesWindow, ordered: .above)
            }
            notesWindow.makeKeyAndOrderFront(nil)
        } else {
            generalNotesWindow?.window?.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func notesButtonClicked(_ sender: NSButton) {
        openNotesWindow()
    }

    private func showSearchPanel() {
        if searchPanel == nil {
            searchPanel = SearchPanelController()
            searchPanel?.editorViewController = mainContentViewController.editorViewController
        }
        // Update page info before showing
        searchPanel?.updatePageInfoBeforeShow()
        searchPanel?.showWindow(nil)
        if let parent = window, let child = searchPanel?.window {
            let alreadyChild = parent.childWindows?.contains(child) ?? false
            if !alreadyChild {
                parent.addChildWindow(child, ordered: .above)
            }
            child.makeKeyAndOrderFront(nil)
        } else {
            searchPanel?.window?.makeKeyAndOrderFront(nil)
        }
        // Ensure window becomes key to accept input immediately
        searchPanel?.window?.makeFirstResponder(searchPanel?.window?.contentView)
    }

    // MARK: - Print
    @MainActor
    @objc func printDocument(_ sender: Any?) {
        guard let editorVC = mainContentViewController?.editorViewController else {
            presentErrorAlert(message: "Print Failed", details: "Editor not available")
            return
        }

        guard self.window != nil else {
            presentErrorAlert(message: "Print Failed", details: "No window available for printing")
            return
        }

        guard let pageContainer = editorVC.pageContainer else {
            presentErrorAlert(message: "Print Failed", details: "Document view unavailable")
            return
        }

        let hasWindow = pageContainer.window != nil
        debugLog("Preparing print. pageContainer frame: \(pageContainer.frame) bounds: \(pageContainer.bounds) inWindow: \(hasWindow)")
        guard hasWindow else {
            presentErrorAlert(message: "Print Failed", details: "Document view is not in a window")
            return
        }

        // Ask AppKit to present the native print panel for the laid-out pageContainer
        let printInfoCopy = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfoCopy.jobDisposition = .spool

        let printers = NSPrinter.printerNames
        debugLog("Available printers: \(printers)")

        // Try the user-reported printer name first
        if let userPrinter = NSPrinter(name: "HP LaserJet M110w (8C17D0)") {
            printInfoCopy.printer = userPrinter
            debugLog("Using user-specified printer: HP LaserJet M110w (8C17D0)")
        } else if let hp = printers.first(where: { $0.localizedCaseInsensitiveContains("HP") }) ?? printers.first,
                  let chosen = NSPrinter(name: hp) {
            printInfoCopy.printer = chosen
            debugLog("Using discovered printer: \(hp)")
        } else {
            debugLog("No printer assigned; proceeding with default printInfo.printer")
        }

        let printOperation = NSPrintOperation(view: pageContainer, printInfo: printInfoCopy)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.printPanel.options = [
            .showsPreview,
            .showsCopies,
            .showsPageRange,
            .showsPageSetupAccessory,
            .showsOrientation,
            .showsPaperSize,
            .showsScaling
        ]
        activePrintOperation = printOperation // keep alive while printing
        let previousAppearance = NSApp.appearance
        let isDarkMode = ThemeManager.shared.isDarkMode
        NSApp.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
        defer { NSApp.appearance = previousAppearance }
        let printerName = printOperation.printInfo.printer.name
        debugLog("Starting print operation (printer: \(printerName), shows panel: \(printOperation.showsPrintPanel), shows progress: \(printOperation.showsProgressPanel))")
        let success = printOperation.run()
        debugLog("NSPrintOperation.run returned: \(success)")
        activePrintOperation = nil
    }

    // Note: Removed print(_:) wrapper to avoid conflict with Swift's print() function
    // The printDocument(_:) method already handles @objc print: action from menus

    func showHeaderFooterSettings() {
        guard let editorVC = mainContentViewController?.editorViewController else { return }

        let settingsWindow = HeaderFooterSettingsWindow()
        self.headerFooterSettingsWindow = settingsWindow

        settingsWindow.setCurrentSettings(
            showHeaders: editorVC.showHeaders,
            showFooters: editorVC.showFooters,
            showPageNumbers: editorVC.showPageNumbers,
            hideFirstPageNumber: editorVC.hidePageNumberOnFirstPage,
            centerPageNumbers: editorVC.centerPageNumbers,
            headerLeftText: editorVC.headerText,
            headerRightText: editorVC.headerTextRight,
            footerLeftText: editorVC.footerText,
            footerRightText: editorVC.footerTextRight
        )

        settingsWindow.onApply = { [weak self, weak editorVC] showHeaders, showFooters, showPageNumbers, hideFirstPageNumber, centerPageNumbers, headerLeftText, headerRightText, footerLeftText, footerRightText in
            editorVC?.showHeaders = showHeaders
            editorVC?.showFooters = showFooters
            editorVC?.showPageNumbers = showPageNumbers
            editorVC?.hidePageNumberOnFirstPage = hideFirstPageNumber
            editorVC?.centerPageNumbers = centerPageNumbers
            editorVC?.headerText = headerLeftText
            editorVC?.headerTextRight = headerRightText
            editorVC?.footerText = footerLeftText
            editorVC?.footerTextRight = footerRightText
            editorVC?.updatePageCentering()
            self?.headerFooterSettingsWindow = nil
        }

        settingsWindow.onCancel = { [weak self] in
            self?.headerFooterSettingsWindow = nil
        }

        settingsWindow.showWindow(nil)
        if let parent = window, let child = settingsWindow.window {
            let alreadyChild = parent.childWindows?.contains(child) ?? false
            if !alreadyChild {
                parent.addChildWindow(child, ordered: .above)
            }
            child.makeKeyAndOrderFront(nil)
        } else {
            settingsWindow.window?.makeKeyAndOrderFront(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func showTOCIndex() {
        if tocIndexWindow == nil {
            tocIndexWindow = TOCIndexWindowController()
        }
        // Connect the editor text view and controller
        tocIndexWindow?.editorTextView = mainContentViewController?.editorViewController?.textView
        tocIndexWindow?.editorViewController = mainContentViewController?.editorViewController

        // Auto-scan document for {{index:term}} markers when opening
        if let textStorage = mainContentViewController?.editorViewController?.textView?.textStorage {
            _ = TOCIndexManager.shared.generateIndexFromMarkers(in: textStorage)
        }

        // Refresh the table views to show current state
        tocIndexWindow?.reloadTables()

        tocIndexWindow?.showWindow(nil)
        tocIndexWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    deinit {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }
}

// MARK: - Debug Logging

private extension MainWindowController {
    @inline(__always)
    func debugLog(_ message: @autoclosure () -> String) {
        DebugLog.log(message())
    }
}

// MARK: - Menu Item Validation
extension MainWindowController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(printDocument(_:)) {
            let isValid = mainContentViewController != nil
            debugLog("MainWindowController validateMenuItem for Print: \(isValid)")
            return isValid
        }
        return true
    }
}

@MainActor
extension MainWindowController: FormattingToolbarDelegate {
    func formattingToolbarDidIndent(_ toolbar: FormattingToolbar) {
        mainContentViewController.indent()
    }

    func formattingToolbarDidOutdent(_ toolbar: FormattingToolbar) {
        mainContentViewController.outdent()
    }

    func formattingToolbarDidSave(_ toolbar: FormattingToolbar) {
        performSaveDocument(nil)
    }

    func formattingToolbar(_ toolbar: FormattingToolbar, didSelectStyle styleName: String) {
        mainContentViewController.applyStyle(styleName)

        // Refresh outline if an outline-related style is applied
        let outlineStyles = [
            "Part Title",
            "Chapter Number",
            "Chapter Title",
            "Chapter Subtitle",
            "Heading 1",
            "Heading 2",
            "Heading 3",
            "TOC Title",
            "Index Title",
            "Glossary Title",
            "Appendix Title",
            // Poetry stanza outline drivers
            "Stanza",
            "Verse",
            "Poetry — Stanza",
            "Poetry — Verse",
            "Poetry — Stanza Break"
        ]
        if outlineStyles.contains(styleName) || StyleCatalog.shared.isPoetryTemplate {
            // Delay refresh slightly to allow style to be applied first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: Notification.Name("QuillPilotOutlineRefresh"), object: nil)
            }
        }
    }

    func formattingToolbarDidColumns(_ toolbar: FormattingToolbar) {
        let theme = ThemeManager.shared.currentTheme

        // Create a custom window for the sheet
        let sheetWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        sheetWindow.title = "Column Operations"
        sheetWindow.backgroundColor = theme.toolbarBackground

        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = theme.toolbarBackground.cgColor
        sheetWindow.contentView = containerView

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 16
        stackView.alignment = .leading
        stackView.distribution = .gravityAreas
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 60, right: 20)

        containerView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -60)
        ])

        // Set columns section
        let setLabel = NSTextField(labelWithString: "Set Number of Columns:")
        setLabel.font = NSFont.boldSystemFont(ofSize: 12)
        setLabel.textColor = theme.textColor
        stackView.addArrangedSubview(setLabel)

        let setStack = NSStackView()
        setStack.orientation = .horizontal
        setStack.spacing = 8
        setStack.alignment = .centerY

        let columnsField = NSTextField(string: "2")
        columnsField.placeholderString = "2-4"
        columnsField.alignment = .center
        columnsField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        columnsField.textColor = theme.textColor
        columnsField.backgroundColor = theme.pageBackground

        let setBtn = NSButton(title: "Set Columns", target: nil, action: nil)
        setBtn.bezelStyle = .rounded
        setBtn.contentTintColor = theme.headerBackground

        setStack.addArrangedSubview(columnsField)
        setStack.addArrangedSubview(setBtn)
        stackView.addArrangedSubview(setStack)

        // Separator
        let sep1 = NSBox()
        sep1.boxType = .separator
        stackView.addArrangedSubview(sep1)

        // Column operations
        let insertBtn = NSButton(title: "Insert Column", target: nil, action: nil)
        insertBtn.bezelStyle = .rounded
        insertBtn.contentTintColor = theme.headerBackground
        stackView.addArrangedSubview(insertBtn)

        let breakBtn = NSButton(title: "Insert Column Break", target: nil, action: nil)
        breakBtn.bezelStyle = .rounded
        breakBtn.contentTintColor = theme.headerBackground
        stackView.addArrangedSubview(breakBtn)

        let balanceBtn = NSButton(title: "Balance Columns", target: nil, action: nil)
        balanceBtn.bezelStyle = .rounded
        balanceBtn.contentTintColor = theme.headerBackground
        stackView.addArrangedSubview(balanceBtn)

        let deleteBtn = NSButton(title: "Delete Column at Cursor", target: nil, action: nil)
        deleteBtn.bezelStyle = .rounded
        deleteBtn.contentTintColor = theme.headerBackground
        stackView.addArrangedSubview(deleteBtn)

        // Cancel Button
        let cancelBtn = NSButton(title: "Cancel", target: nil, action: nil)
        cancelBtn.bezelStyle = .rounded
        cancelBtn.contentTintColor = theme.headerBackground
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(cancelBtn)

        NSLayoutConstraint.activate([
            cancelBtn.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            cancelBtn.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            cancelBtn.widthAnchor.constraint(equalToConstant: 80)
        ])

        // Hook up actions
        setBtn.target = self
        setBtn.action = #selector(handleSetColumnsFromSheet(_:))

        insertBtn.target = self
        insertBtn.action = #selector(handleInsertColumnFromSheet)

        breakBtn.target = self
        breakBtn.action = #selector(handleInsertColumnBreakFromDialog)

        balanceBtn.target = self
        balanceBtn.action = #selector(handleBalanceColumnsFromSheet)

        deleteBtn.target = self
        deleteBtn.action = #selector(handleDeleteColumnFromSheet(_:))

        cancelBtn.target = self
        cancelBtn.action = #selector(handleCloseColumnsSheet(_:))

        // Store field reference
        self.columnsSheetField = columnsField

        self.window?.beginSheet(sheetWindow, completionHandler: nil)
    }

    func formattingToolbar(_ toolbar: FormattingToolbar, didChangeFontFamily family: String) {
        mainContentViewController.setFontFamily(family)
    }

    func formattingToolbar(_ toolbar: FormattingToolbar, didChangeFontSize size: CGFloat) {
        mainContentViewController.setFontSize(size)
    }

    func formattingToolbarDidToggleBold(_ toolbar: FormattingToolbar) {
        mainContentViewController.toggleBold()
    }

    func formattingToolbarDidToggleItalic(_ toolbar: FormattingToolbar) {
        mainContentViewController.toggleItalic()
    }

    func formattingToolbarDidToggleUnderline(_ toolbar: FormattingToolbar) {
        mainContentViewController.toggleUnderline()
    }

    func formattingToolbarDidToggleStrikethrough(_ toolbar: FormattingToolbar) {
        mainContentViewController.toggleStrikethrough()
    }

    func formattingToolbarDidToggleSuperscript(_ toolbar: FormattingToolbar) {
        mainContentViewController.editorViewController.toggleSuperscript()
    }

    func formattingToolbarDidToggleSubscript(_ toolbar: FormattingToolbar) {
        mainContentViewController.editorViewController.toggleSubscript()
    }

    func formattingToolbarDidAlignLeft(_ toolbar: FormattingToolbar) {
        mainContentViewController.setAlignment(.left)
    }

    func formattingToolbarDidAlignCenter(_ toolbar: FormattingToolbar) {
        mainContentViewController.setAlignment(.center)
    }

    func formattingToolbarDidAlignRight(_ toolbar: FormattingToolbar) {
        mainContentViewController.setAlignment(.right)
    }

    func formattingToolbarDidAlignJustify(_ toolbar: FormattingToolbar) {
        mainContentViewController.setAlignment(.justified)
    }

    func formattingToolbarDidToggleBullets(_ toolbar: FormattingToolbar) {
        mainContentViewController.editorViewController.toggleBulletedList()
    }

    func formattingToolbarDidToggleNumbering(_ toolbar: FormattingToolbar) {
        mainContentViewController.editorViewController.toggleNumberedList()
    }

    func formattingToolbarDidToggleParagraphMarks(_ toolbar: FormattingToolbar) {
        _ = mainContentViewController.editorViewController.toggleParagraphMarks()
        syncParagraphMarksToolbarState()
    }

    func formattingToolbarDidNewDocument(_ toolbar: FormattingToolbar) {
        performNewDocument(nil)
    }

    func formattingToolbarDidOpenDocument(_ toolbar: FormattingToolbar) {
        performOpenDocument(nil)
    }

    func formattingToolbarDidSaveAs(_ toolbar: FormattingToolbar) {
        performSaveAs(nil)
    }

    func formattingToolbarDidPrint(_ toolbar: FormattingToolbar) {
        printDocument(nil)
    }

    func formattingToolbarDidUndo(_ toolbar: FormattingToolbar) {
        NSApp.sendAction(Selector(("undo:")), to: nil, from: toolbar)
    }

    func formattingToolbarDidRedo(_ toolbar: FormattingToolbar) {
        NSApp.sendAction(Selector(("redo:")), to: nil, from: toolbar)
    }

    func formattingToolbarDidCut(_ toolbar: FormattingToolbar) {
        // Route through responder chain so it hits the active editor text view.
        NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: toolbar)
    }

    func formattingToolbarDidCopy(_ toolbar: FormattingToolbar) {
        NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: toolbar)
    }

    func formattingToolbarDidPaste(_ toolbar: FormattingToolbar) {
        NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: toolbar)
    }

    func formattingToolbarDidInsertHyperlink(_ toolbar: FormattingToolbar) {
        NSApp.sendAction(#selector(NSTextView.orderFrontLinkPanel(_:)), to: nil, from: toolbar)
    }

    @objc func insertHyperlinkFromMenu(_ sender: Any?) {
        formattingToolbarDidInsertHyperlink(toolbarView)
    }

    @objc func openStyleEditorFromMenu(_ sender: Any?) {
        formattingToolbarDidOpenStyleEditor(toolbarView)
    }

    func formattingToolbarDidInsertImage(_ toolbar: FormattingToolbar) {
        mainContentViewController.insertImage()
    }

    func formattingToolbarDidInsertColumnBreak(_ toolbar: FormattingToolbar) {
        mainContentViewController.editorViewController.insertColumnBreak()
    }

    func formattingToolbarDidDeleteColumn(_ toolbar: FormattingToolbar) {
        mainContentViewController.editorViewController.deleteColumnAtCursor()
    }

    func formattingToolbarDidInsertTable(_ toolbar: FormattingToolbar) {
        let theme = ThemeManager.shared.currentTheme

        // Create a custom window for the sheet
        let sheetWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        sheetWindow.title = "Table Operations"
        sheetWindow.backgroundColor = theme.toolbarBackground

        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = theme.toolbarBackground.cgColor
        sheetWindow.contentView = containerView

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 16
        stackView.alignment = .leading
        stackView.distribution = .gravityAreas
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 60, right: 20)

        containerView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -60)
        ])

        // Insert Table Section
        let insertLabel = NSTextField(labelWithString: "Insert New Table:")
        insertLabel.font = NSFont.boldSystemFont(ofSize: 12)
        insertLabel.textColor = theme.textColor
        stackView.addArrangedSubview(insertLabel)

        let insertStack = NSStackView()
        insertStack.orientation = .horizontal
        insertStack.spacing = 8
        insertStack.alignment = .centerY

        let rowsLabel = NSTextField(labelWithString: "Rows:")
        rowsLabel.textColor = theme.textColor
        let rowsField = NSTextField(string: "3")
        rowsField.placeholderString = "3"
        rowsField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        rowsField.textColor = theme.textColor
        rowsField.backgroundColor = theme.pageBackground

        let colsLabel = NSTextField(labelWithString: "Columns:")
        colsLabel.textColor = theme.textColor
        let colsField = NSTextField(string: "3")
        colsField.placeholderString = "3"
        colsField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        colsField.textColor = theme.textColor
        colsField.backgroundColor = theme.pageBackground

        insertStack.addArrangedSubview(rowsLabel)
        insertStack.addArrangedSubview(rowsField)
        insertStack.addArrangedSubview(colsLabel)
        insertStack.addArrangedSubview(colsField)
        stackView.addArrangedSubview(insertStack)

        let insertBtn = NSButton(title: "Insert Table", target: nil, action: nil)
        insertBtn.bezelStyle = .rounded
        insertBtn.contentTintColor = theme.headerBackground
        stackView.addArrangedSubview(insertBtn)

        // Separator
        let separator1 = NSBox()
        separator1.boxType = .separator
        stackView.addArrangedSubview(separator1)

        // Edit Table Section
        let editLabel = NSTextField(labelWithString: "Edit Existing Table:")
        editLabel.font = NSFont.boldSystemFont(ofSize: 12)
        editLabel.textColor = theme.textColor
        stackView.addArrangedSubview(editLabel)

        let addRowBtn = NSButton(title: "Insert Row", target: nil, action: nil)
        addRowBtn.bezelStyle = .rounded
        addRowBtn.contentTintColor = theme.headerBackground

        let addColBtn = NSButton(title: "Insert Column", target: nil, action: nil)
        addColBtn.bezelStyle = .rounded
        addColBtn.contentTintColor = theme.headerBackground

        let deleteRowBtn = NSButton(title: "Delete Row", target: nil, action: nil)
        deleteRowBtn.bezelStyle = .rounded
        deleteRowBtn.contentTintColor = theme.headerBackground

        let deleteColBtn = NSButton(title: "Delete Column", target: nil, action: nil)
        deleteColBtn.bezelStyle = .rounded
        deleteColBtn.contentTintColor = theme.headerBackground

        let deleteTableBtn = NSButton(title: "Delete Table", target: nil, action: nil)
        deleteTableBtn.bezelStyle = .rounded
        deleteTableBtn.contentTintColor = theme.headerBackground

        stackView.addArrangedSubview(addRowBtn)
        stackView.addArrangedSubview(addColBtn)
        stackView.addArrangedSubview(deleteRowBtn)
        stackView.addArrangedSubview(deleteColBtn)
        stackView.addArrangedSubview(deleteTableBtn)

        // Done Button
        let doneBtn = NSButton(title: "Done", target: nil, action: nil)
        doneBtn.bezelStyle = .rounded
        doneBtn.contentTintColor = theme.headerBackground
        doneBtn.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(doneBtn)

        NSLayoutConstraint.activate([
            doneBtn.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            doneBtn.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            doneBtn.widthAnchor.constraint(equalToConstant: 80)
        ])

        // Set up button actions
        insertBtn.target = self
        insertBtn.action = #selector(handleInsertTableFromSheet(_:))

        addRowBtn.target = self
        addRowBtn.action = #selector(handleAddTableRow)

        addColBtn.target = self
        addColBtn.action = #selector(handleAddTableColumn)

        deleteRowBtn.target = self
        deleteRowBtn.action = #selector(handleDeleteTableRow)

        deleteColBtn.target = self
        deleteColBtn.action = #selector(handleDeleteTableColumn)

        deleteTableBtn.target = self
        deleteTableBtn.action = #selector(handleDeleteTable)

        doneBtn.target = self
        doneBtn.action = #selector(handleCloseTableSheet(_:))

        // Store field references
        self.tableRowsSheetField = rowsField
        self.tableColsSheetField = colsField

        self.window?.beginSheet(sheetWindow, completionHandler: nil)
    }

    @objc private func handleSetColumnsFromDialog(_ sender: NSButton) {
        guard let columnsField = objc_getAssociatedObject(sender, "columnsField") as? NSTextField,
              let alert = objc_getAssociatedObject(sender, "alert") as? NSAlert else { return }

        let columns = Int(columnsField.stringValue) ?? 1
        mainContentViewController.editorViewController.setColumnCount(columns)
        alert.window.makeFirstResponder(nil)
    }

    @objc private func handleInsertColumnBreakFromDialog() {
        mainContentViewController.editorViewController.insertColumnBreak()
    }

    @objc private func handleBalanceColumnsFromSheet() {
        mainContentViewController.editorViewController.balanceColumnsAtCursor()
    }

    @objc private func handleDeleteColumnFromDialog() {
        mainContentViewController.editorViewController.deleteColumnAtCursor()
    }

    @objc private func handleSetColumnsFromSheet(_ sender: NSButton) {
        guard let columnsField = self.columnsSheetField else { return }
        let clamped = max(2, min(4, Int(columnsField.stringValue) ?? 2))
        debugLog("handleSetColumnsFromSheet: field value='\(columnsField.stringValue)' clamped=\(clamped)")

        // Close sheet first, then insert after window becomes key
        if let window = sender.window {
            self.window?.endSheet(window)
            self.columnsSheetField = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.mainContentViewController.editorViewController.setColumnCount(clamped)
            }
        }
    }

    @objc private func handleInsertColumnFromSheet() {
        let current = mainContentViewController.editorViewController.getColumnCount()

        // Close sheet first, then add column after window becomes key
        if let window = self.window?.attachedSheet {
            self.window?.endSheet(window)
            self.columnsSheetField = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                if current >= 2 && current < 4 {
                    // Already in a column layout - add one more column
                    self?.mainContentViewController.editorViewController.addColumnToExisting()
                } else if current == 1 {
                    // Not in columns yet - create 2 columns
                    self?.mainContentViewController.editorViewController.setColumnCount(2)
                }
                // If current == 4, do nothing (already at max)
            }
        }
    }

    @objc private func handleDeleteColumnFromSheet(_ sender: NSButton) {
        if let window = sender.window {
            self.window?.endSheet(window)
            self.columnsSheetField = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.mainContentViewController.editorViewController.deleteColumnAtCursor()
            }
        }
    }

    @objc private func handleCloseColumnsSheet(_ sender: NSButton) {
        guard let window = sender.window else { return }
        self.window?.endSheet(window)
        self.columnsSheetField = nil
    }

    @objc private func handleInsertTableFromSheet(_ sender: NSButton) {
        guard let rowsField = self.tableRowsSheetField,
              let colsField = self.tableColsSheetField else { return }

        let rows = max(1, min(10, Int(rowsField.stringValue) ?? 3))
        let cols = max(1, min(6, Int(colsField.stringValue) ?? 3))
        debugLog("handleInsertTableFromSheet: rows='\(rowsField.stringValue)'->\(rows) cols='\(colsField.stringValue)'->\(cols)")

        // Close sheet first, then insert after window becomes key
        if let window = sender.window {
            self.window?.endSheet(window)
            self.tableRowsSheetField = nil
            self.tableColsSheetField = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.mainContentViewController.editorViewController.insertTable(rows: rows, columns: cols)
            }
        }
    }

    @objc private func handleCloseTableSheet(_ sender: NSButton) {
        guard let window = sender.window else { return }
        debugLog("handleCloseTableSheet: closing table sheet without insert")
        self.window?.endSheet(window)
        self.tableRowsSheetField = nil
        self.tableColsSheetField = nil
    }

    @objc private func handleAddTableRow() {
        mainContentViewController.editorViewController.addTableRow()
    }

    @objc private func handleAddTableColumn() {
        mainContentViewController.editorViewController.addTableColumn()
    }

    @objc private func handleDeleteTableRow() {
        debugLog("handleDeleteTableRow: invoked")
        mainContentViewController.editorViewController.deleteTableRow()
    }

    @objc private func handleDeleteTableColumn() {
        mainContentViewController.editorViewController.deleteTableColumn()
    }

    @objc private func handleDeleteTable() {
        mainContentViewController.editorViewController.deleteTable()
    }

    func formattingToolbarDidClearAll(_ toolbar: FormattingToolbar) {
        guard let window = self.window else { return }
        let alert = NSAlert.themedConfirmation(
            title: "Clear All",
            message: "This will remove all text, formatting, and analysis. This action cannot be undone.",
            confirmTitle: "Clear All",
            cancelTitle: "Cancel"
        )
        alert.runThemedSheet(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.mainContentViewController.editorViewController.clearAll()
            // Clear analysis results and Character Library
            self?.mainContentViewController.clearAnalysis()
            CharacterLibrary.shared.clearForNewDocument()
            self?.mainContentViewController.documentDidChange(url: nil)
        }
    }

    func formattingToolbarDidFormatPainter(_ toolbar: FormattingToolbar) {
        mainContentViewController.editorViewController.toggleFormatPainter()
    }

    func formattingToolbarDidToggleOutlinePanel(_ toolbar: FormattingToolbar) {
        mainContentViewController.toggleOutlinePanel()
    }

    func formattingToolbarDidOpenStyleEditor(_ toolbar: FormattingToolbar) {
        if styleEditorWindow == nil {
            styleEditorWindow = StyleEditorWindowController(editor: self)
        }
        guard let sheet = styleEditorWindow?.window, let host = window else { return }
        host.beginSheet(sheet, completionHandler: nil)
    }
}

extension MainWindowController: StyleEditorPresenter {
    func applyStyleFromEditor(named: String) {
        mainContentViewController.applyStyle(named)
    }
}

// MARK: - Save / Open
extension MainWindowController {
    private func closeAndClearTOCIndexWindowForDocumentChange() {
        // Clear shared state
        TOCIndexManager.shared.clearTOC()
        TOCIndexManager.shared.clearIndex()

        // Close the window so stale rows/selection don't carry across documents
        if tocIndexWindow != nil {
            tocIndexWindow?.close()
            tocIndexWindow = nil
        }
    }

    @MainActor
    func performSaveDocument(_ sender: Any?) {
        // If we have a current document URL, save directly without showing panel
        if let url = currentDocumentURL {
            saveToURL(url, format: currentDocumentFormat)
            return
        }

        // Otherwise show save panel for new documents
        performSaveAs(sender)
    }

    @MainActor
    func performExportDocument(_ sender: Any?) {
        performExportAs(sender)
    }

    func performSaveAs(_ sender: Any?) {
        guard let window else { return }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = "Save"

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        ExportFormat.allCases.forEach { popup.addItem(withTitle: $0.displayName) }

        // Default new documents to the Preferences format. Existing documents keep their current format.
        let defaultFormat: ExportFormat = (currentDocumentURL == nil) ? QuillPilotSettings.defaultExportFormat : currentDocumentFormat
        let defaultIndex = ExportFormat.allCases.firstIndex(of: defaultFormat) ?? 0
        popup.selectItem(at: defaultIndex)

        let accessory = NSStackView(views: [NSTextField(labelWithString: "Format:"), popup])
        accessory.orientation = .horizontal
        accessory.spacing = 8
        panel.accessoryView = accessory

        // If we're showing Save As for an imported/unsaved document (e.g. .pages),
        // prefill the filename from the current document title so the user doesn't
        // have to re-enter it.
        if panel.nameFieldStringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let title = headerView.documentTitle().trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                panel.nameFieldStringValue = title
            }
        }

        func applySelection() {
            let format = ExportFormat.allCases[popup.indexOfSelectedItem]
            panel.allowedContentTypes = format.contentTypes
            let baseName: String
            if let existingDot = panel.nameFieldStringValue.lastIndex(of: ".") {
                baseName = String(panel.nameFieldStringValue[..<existingDot])
            } else if panel.nameFieldStringValue.isEmpty {
                baseName = "Untitled"
            } else {
                baseName = panel.nameFieldStringValue
            }
            panel.nameFieldStringValue = baseName + "." + format.fileExtension
        }

        applySelection()
        popup.target = self
        popup.action = #selector(_saveFormatChanged(_:))
        objc_setAssociatedObject(popup, &AssociatedKeys.savePanelKey, panel, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            let format = ExportFormat.allCases[popup.indexOfSelectedItem]
            self.saveToURL(url, format: format)
            // Remember this for auto-save
            self.currentDocumentURL = url
            self.currentDocumentFormat = format
            self.hasUnsavedChanges = false

            // Notify sidebars that the document now has a concrete URL (Save As).
            self.mainContentViewController.documentURLDidUpdate(url: url)
        }
    }

    func performExportAs(_ sender: Any?) {
        guard let window else { return }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = "Export"

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        ExportFormat.allCases.forEach { popup.addItem(withTitle: $0.displayName) }

        let defaultFormat = QuillPilotSettings.defaultExportFormat
        let defaultIndex = ExportFormat.allCases.firstIndex(of: defaultFormat) ?? 0
        popup.selectItem(at: defaultIndex)

        let accessory = NSStackView(views: [NSTextField(labelWithString: "Format:"), popup])
        accessory.orientation = .horizontal
        accessory.spacing = 8
        panel.accessoryView = accessory

        if panel.nameFieldStringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let title = headerView.documentTitle().trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                panel.nameFieldStringValue = title
            }
        }

        func applySelection() {
            let format = ExportFormat.allCases[popup.indexOfSelectedItem]
            panel.allowedContentTypes = format.contentTypes
            let baseName: String
            if let existingDot = panel.nameFieldStringValue.lastIndex(of: ".") {
                baseName = String(panel.nameFieldStringValue[..<existingDot])
            } else if panel.nameFieldStringValue.isEmpty {
                baseName = "Untitled"
            } else {
                baseName = panel.nameFieldStringValue
            }
            panel.nameFieldStringValue = baseName + "." + format.fileExtension
        }

        applySelection()
        popup.target = self
        popup.action = #selector(_saveFormatChanged(_:))
        objc_setAssociatedObject(popup, &AssociatedKeys.savePanelKey, panel, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            let format = ExportFormat.allCases[popup.indexOfSelectedItem]
            self.exportToURL(url, format: format)
        }
    }

    private func writeDocument(to url: URL, format: ExportFormat, content: ExportContent) throws {
        switch format {
        case .docx:
            guard case let .attributed(attributed) = content else { return }
            let stamped = stampImageSizes(in: attributed)
            let data = try DocxBuilder.makeDocxData(from: stamped)
            try data.write(to: url, options: .atomic)
            debugLog("✅ DOCX exported to \(url.path)")

        case .rtf:
            guard case let .attributed(attributed) = content else { return }
            let fullRange = NSRange(location: 0, length: attributed.length)
            let data = try attributed.data(from: fullRange, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            try data.write(to: url, options: .atomic)
            debugLog("✅ RTF exported to \(url.path)")

        case .rtfd:
            guard case let .attributed(attributed) = content else { return }
            let fullRange = NSRange(location: 0, length: attributed.length)
            let wrapper = try attributed.fileWrapper(
                from: fullRange,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )

            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
            debugLog("✅ RTFD exported to \(url.path)")

        case .odt:
            guard case let .attributed(attributed) = content else {
                debugLog("❌ ODT export: no attributed content")
                return
            }
            debugLog("📄 ODT export: normalizing content...")
            let normalized = normalizedTOCIndexForOpenDocument(attributed)
            let fullRange = NSRange(location: 0, length: normalized.length)
            debugLog("📄 ODT export: converting to ODT data...")
            var data = try normalized.data(from: fullRange, documentAttributes: [.documentType: NSAttributedString.DocumentType.openDocument])
            // Post-process the generated ODT to add proper leader-tab stops that OpenOffice/LibreOffice respect.
            // Cocoa's ODT exporter does not reliably preserve leader tabs/right tab stops.
            do {
                data = try postprocessODTForLeaders(data)
                debugLog("📄 ODT export: applied leader-tab postprocess")
            } catch {
                debugLog("⚠️ ODT export: leader-tab postprocess failed, writing original ODT. Error: \(error)")
            }
            debugLog("📄 ODT export: writing \(data.count) bytes to \(url.path)")
            try data.write(to: url)
            debugLog("✅ ODT exported to \(url.path)")

        case .txt:
            guard case let .plainText(text) = content else { return }
            try text.write(to: url, atomically: true, encoding: .utf8)
            debugLog("✅ TXT exported to \(url.path)")

        case .markdown:
            guard case let .plainText(text) = content else { return }
            try text.write(to: url, atomically: true, encoding: .utf8)
            debugLog("✅ Markdown exported to \(url.path)")

        case .html:
            guard case let .attributed(attributed) = content else { return }
            let fullRange = NSRange(location: 0, length: attributed.length)
            let data = try attributed.data(from: fullRange, documentAttributes: [.documentType: NSAttributedString.DocumentType.html])
            try data.write(to: url, options: .atomic)
            debugLog("✅ HTML exported to \(url.path)")

        case .pdf:
            guard case let .pdf(data) = content else { return }
            try data.write(to: url, options: .atomic)
            debugLog("✅ PDF exported to \(url.path)")

        case .epub:
            guard case let .attributed(attributed) = content else { return }
            let epubData = try self.generateEPub(from: attributed, url: url)
            try epubData.write(to: url, options: Data.WritingOptions.atomic)
            debugLog("✅ ePub exported to \(url.path)")

        case .mobi:
            guard case let .attributed(attributed) = content else { return }
            let mobiData = try self.generateMobi(from: attributed, url: url)
            try mobiData.write(to: url, options: Data.WritingOptions.atomic)
            debugLog("✅ Mobi exported to \(url.path)")
        }

        if !FileManager.default.fileExists(atPath: url.path) {
            throw NSError(
                domain: "QuillPilot",
                code: 21,
                userInfo: [NSLocalizedDescriptionKey: "Export failed to create file at \(url.path)"]
            )
        }
    }

    private func normalizedTOCIndexForOpenDocument(_ attributed: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let styleKey = NSAttributedString.Key("QuillStyleName")
        let targetStyles: Set<String> = [
            "TOC Entry",
            "TOC Entry Level 1",
            "TOC Entry Level 2",
            "TOC Entry Level 3",
            "Index Entry"
        ]

        // Collect paragraph ranges first to avoid mutation during iteration
        var paragraphRanges: [NSRange] = []
        var location = 0
        let originalString = attributed.string as NSString
        while location < originalString.length {
            let range = originalString.paragraphRange(for: NSRange(location: location, length: 0))
            paragraphRanges.append(range)
            location = NSMaxRange(range)
        }

        // Regex to find page number at end of line
        let pageRegex = try? NSRegularExpression(pattern: "([0-9A-Za-z]+(?:\\s*,\\s*[0-9A-Za-z]+)*)\\s*$", options: [])

        // Strict leader detection to avoid corrupting body paragraphs.
        // Matches lines that include an obvious leader run (many dots or dot+space patterns) before the trailing page token.
        let leaderRegex = try? NSRegularExpression(pattern: "(\\.{4,}|(?:\\s*\\.\\s*){8,}|[·•]{6,}|[~∼˜]{6,})\\s*[0-9A-Za-z]+\\s*$", options: [])

        debugLog("📄 ODT normalization: processing \(paragraphRanges.count) paragraphs")

        // Process in reverse to preserve earlier ranges when modifying
        for paragraphRange in paragraphRanges.reversed() {
            guard paragraphRange.location < mutable.length else { continue }
            let safeRange = NSRange(location: paragraphRange.location, length: min(paragraphRange.length, mutable.length - paragraphRange.location))
            guard safeRange.length > 0 else { continue }

            let paragraphText = (mutable.string as NSString).substring(with: safeRange)
            let hasTrailingNewline = paragraphText.hasSuffix("\n")
            let trimmed = paragraphText.trimmingCharacters(in: .newlines)
            let normalizedTrimmed = trimmed.replacingOccurrences(of: "\u{00A0}", with: " ")

            let styleName = (mutable.attribute(styleKey, at: safeRange.location, effectiveRange: nil) as? String) ?? ""
            let styleMatch = targetStyles.contains(styleName)
            let hasLeaderRun = leaderRegex?.firstMatch(in: normalizedTrimmed, range: NSRange(location: 0, length: (normalizedTrimmed as NSString).length)) != nil

            var pageText: String?
            var leftPart: String?

            if let tabIndex = normalizedTrimmed.lastIndex(of: "\t") {
                leftPart = String(normalizedTrimmed[..<tabIndex])
                pageText = String(normalizedTrimmed[normalizedTrimmed.index(after: tabIndex)...]).trimmingCharacters(in: .whitespaces)
            } else if let pageRegex, let match = pageRegex.firstMatch(in: normalizedTrimmed, range: NSRange(location: 0, length: (normalizedTrimmed as NSString).length)) {
                let pageRange = match.range(at: 1)
                pageText = (normalizedTrimmed as NSString).substring(with: pageRange).trimmingCharacters(in: .whitespaces)
                leftPart = (normalizedTrimmed as NSString).substring(to: pageRange.location)
            }

            if let pageText, var leftPart {
                leftPart = leftPart.replacingOccurrences(of: "\t", with: " ")
                // Remove trailing leader dots and extra spacing.
                // Use a loop to strip all trailing dots, spaces, and common leader characters
                var cleanedLeft = leftPart
                let leaderChars = CharacterSet(charactersIn: ". ·~∼˜\u{00A0}\u{0303}")
                while let lastChar = cleanedLeft.last, leaderChars.contains(lastChar.unicodeScalars.first!) {
                    cleanedLeft.removeLast()
                }
                let leftText = cleanedLeft.trimmingCharacters(in: .whitespacesAndNewlines)

                // Keep a simple explicit leader marker that we'll later convert into a true ODT leader tab.
                // We use a stable token " .... " so the ODT post-processor can reliably find TOC/Index entries.
                let rebuilt = "\(leftText) .... \(pageText)" + (hasTrailingNewline ? "\n" : "")

                var attrs = mutable.attributes(at: safeRange.location, effectiveRange: nil)
                // Clear any tab stops - they cause issues in ODT
                let mutableStyle: NSMutableParagraphStyle
                if let style = attrs[.paragraphStyle] as? NSParagraphStyle,
                   let msCopy = style.mutableCopy() as? NSMutableParagraphStyle {
                    mutableStyle = msCopy
                } else {
                    mutableStyle = NSMutableParagraphStyle()
                }
                mutableStyle.tabStops = []
                attrs[.paragraphStyle] = mutableStyle.copy() as? NSParagraphStyle

                // Remove underline styling - leader dots often have underlines that cause issues in ODT
                attrs.removeValue(forKey: .underlineStyle)
                attrs.removeValue(forKey: .underlineColor)
                attrs.removeValue(forKey: .strikethroughStyle)
                attrs.removeValue(forKey: .strikethroughColor)

                // Apply normalization ONLY when we have strong evidence this is a TOC/Index line.
                // This prevents rewriting normal body paragraphs.
                if styleMatch || trimmed.contains("\t") || hasLeaderRun {
                    debugLog("📄 Normalizing TOC line: '\(leftText)' -> page \(pageText)")
                    mutable.replaceCharacters(in: safeRange, with: NSAttributedString(string: rebuilt, attributes: attrs))
                }
            }
        }

        return mutable
    }

    // MARK: - ODT Postprocess (Leader Tabs)

    private func postprocessODTForLeaders(_ odtData: Data) throws -> Data {
        // ODT is a ZIP. We patch content.xml to:
        // 1) Convert leader dots into <text:tab/> elements
        // 2) Add leader tab-stops into automatic styles used by TOC/Index paragraphs (P2/P9)
        //
        // We intentionally avoid extra dependencies here and do a simple unzip/patch/rezip
        // using system tools. If this fails for any reason, the caller falls back to the
        // original Cocoa-generated ODT.
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("QuillPilotODT_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let inURL = tempDir.appendingPathComponent("in.odt")
        let outURL = tempDir.appendingPathComponent("out.odt")
        let unpackedDir = tempDir.appendingPathComponent("unpacked", isDirectory: true)
        try fileManager.createDirectory(at: unpackedDir, withIntermediateDirectories: true)
        try odtData.write(to: inURL, options: .atomic)

        func runTool(_ executablePath: String, _ args: [String], cwd: URL) throws {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = args
            process.currentDirectoryURL = cwd

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                throw NSError(
                    domain: "QuillPilot",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: "Tool failed: \(executablePath) \(args.joined(separator: " "))\n\(stderr)"]
                )
            }
        }

        // Unzip
        try runTool("/usr/bin/unzip", ["-q", inURL.path, "-d", unpackedDir.path], cwd: tempDir)

        // Patch content.xml if present
        let contentURL = unpackedDir.appendingPathComponent("content.xml")
        if fileManager.fileExists(atPath: contentURL.path) {
            let xml = try String(contentsOf: contentURL, encoding: .utf8)
            let patched = patchODTContentXMLForLeaderTabs(xml)
            try patched.write(to: contentURL, atomically: true, encoding: .utf8)
        }

        // Rezip with ODT-friendly ordering: mimetype first and stored (uncompressed).
        // Then add the rest deflated.
        if fileManager.fileExists(atPath: outURL.path) {
            try? fileManager.removeItem(at: outURL)
        }

        // zip wants to run from inside the directory being zipped.
        // Store mimetype (no compression) then add everything else.
        if fileManager.fileExists(atPath: unpackedDir.appendingPathComponent("mimetype").path) {
            try runTool("/usr/bin/zip", ["-X0", outURL.path, "mimetype"], cwd: unpackedDir)
            try runTool("/usr/bin/zip", ["-Xr9D", outURL.path, ".", "-x", "mimetype", "./mimetype"], cwd: unpackedDir)
        } else {
            // Fallback: zip everything (some readers still open it, but spec prefers mimetype first).
            try runTool("/usr/bin/zip", ["-Xr9D", outURL.path, "."], cwd: unpackedDir)
        }

        return try Data(contentsOf: outURL)
    }

    private func patchODTContentXMLForLeaderTabs(_ xml: String) -> String {
        var result = xml

        // 1) Identify TOC/Index paragraph styles that actually contain leader runs.
        // Cocoa's ODT exporter uses auto-generated styles (often P2 for TOC and P9+ for Index),
        // but style numbers can vary depending on document contents.
        var stylesNeedingLeaderTabs = Set<String>(["P2", "P9"])

        // Match both span-wrapped and plain paragraphs.
        // We accept a run of common leader characters (dots, middle dots, NBSP, spaces, tildes) before the page number.
        let leaderRun = "(?:[\\.·\\u00B7~∼˜\\u00A0\\s]{3,})"
        let styleNameCapture = "text:style-name=\\\"(P\\d+)\\\""
        let patternSpanStyle = "<text:p[^>]*\\b" + styleNameCapture + "[^>]*>\\s*<text:span[^>]*>[^<]*?" + leaderRun + "\\s*[0-9]+\\s*</text:span>\\s*</text:p>"
        let patternPlainStyle = "<text:p[^>]*\\b" + styleNameCapture + "[^>]*>[^<]*?" + leaderRun + "\\s*[0-9]+\\s*</text:p>"

        for pattern in [patternSpanStyle, patternPlainStyle] {
            if let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let ns = result as NSString
                let range = NSRange(location: 0, length: ns.length)
                re.enumerateMatches(in: result, options: [], range: range) { match, _, _ in
                    guard let match, match.numberOfRanges >= 2 else { return }
                    let styleRange = match.range(at: 1)
                    guard styleRange.location != NSNotFound else { return }
                    stylesNeedingLeaderTabs.insert(ns.substring(with: styleRange))
                }
            }
        }

        // 2) Ensure every identified style has a dotted leader right tab stop.
        // Add/append the leader tab-stop even if other tab-stops are already present.
        for styleName in stylesNeedingLeaderTabs.sorted() {
            result = addLeaderTabStop(toStyleNamed: styleName, in: result)
        }

        // 3) Replace leader runs in paragraphs with <text:tab/> so the leader tab-stop draws dots.
        // Case A: span-wrapped paragraphs (often TOC entries)
        let patternSpan = "<text:p([^>]*)>\\s*<text:span([^>]*)>([^<]*?)" + leaderRun + "\\s*([0-9]+)\\s*</text:span>\\s*</text:p>"
        if let re = try? NSRegularExpression(pattern: patternSpan, options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: (result as NSString).length)
            result = re.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "<text:p$1><text:span$2>$3</text:span><text:tab/><text:span$2>$4</text:span></text:p>")
        }

        // Case B: plain paragraphs (often Index entries)
        let patternPlain = "<text:p([^>]*)>([^<]*?)" + leaderRun + "\\s*([0-9]+)\\s*</text:p>"
        if let re2 = try? NSRegularExpression(pattern: patternPlain, options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: (result as NSString).length)
            result = re2.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "<text:p$1>$2<text:tab/>$3</text:p>")
        }

        return result
    }

    private func addLeaderTabStop(toStyleNamed styleName: String, in xml: String) -> String {
        // Adds a leader dotted right tab stop at the right margin (6.5in for Letter with 1" margins).
        // If the style already contains a matching dotted right tab stop at our position, do nothing.
        let styleStartToken = "<style:style style:name=\"\(styleName)\""
        guard let styleStartRange = xml.range(of: styleStartToken) else { return xml }

        guard let styleEndRange = xml.range(of: "</style:style>", range: styleStartRange.lowerBound..<xml.endIndex) else { return xml }
        let styleBlockRange = styleStartRange.lowerBound..<styleEndRange.upperBound
        let styleBlock = String(xml[styleBlockRange])

        let desiredTabStop = "<style:tab-stop style:position=\"6.5in\" style:type=\"right\" style:leader-style=\"dotted\" style:leader-text=\".\"/>"
        if styleBlock.contains(desiredTabStop) {
            return xml
        }

        let tabStopsXML = "<style:tab-stops>\(desiredTabStop)</style:tab-stops>"

        // If there is already a <style:tab-stops> section, append our desired stop.
        if let tabStopsClose = styleBlock.range(of: "</style:tab-stops>") {
            var updatedBlock = styleBlock
            updatedBlock.insert(contentsOf: desiredTabStop, at: tabStopsClose.lowerBound)
            return xml.replacingCharacters(in: styleBlockRange, with: updatedBlock)
        }

        // Self-closing paragraph-properties: expand to include tab stops.
        let propsSelfClosingPattern = "<style:paragraph-properties([^>]*)/>"
        if let re = try? NSRegularExpression(pattern: propsSelfClosingPattern, options: []) {
            let updatedBlock = re.stringByReplacingMatches(
                in: styleBlock,
                options: [],
                range: NSRange(location: 0, length: (styleBlock as NSString).length),
                withTemplate: "<style:paragraph-properties$1>\(tabStopsXML)</style:paragraph-properties>"
            )
            if updatedBlock != styleBlock {
                return xml.replacingCharacters(in: styleBlockRange, with: updatedBlock)
            }
        }

        // Non-self-closing paragraph-properties: insert tab stops before closing tag.
        if let propsClose = styleBlock.range(of: "</style:paragraph-properties>") {
            var updatedBlock = styleBlock
            updatedBlock.insert(contentsOf: tabStopsXML, at: propsClose.lowerBound)
            return xml.replacingCharacters(in: styleBlockRange, with: updatedBlock)
        }

        return xml
    }

    private func makeLeaderDots(leftText: String, pageText: String, font: NSFont, rightTab: CGFloat, isIndex: Bool) -> String {
        let leftWidth = (leftText as NSString).size(withAttributes: [.font: font]).width
        let pageWidth = (pageText as NSString).size(withAttributes: [.font: font]).width
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        let dotWidth = ((isIndex ? " ." : ". ") as NSString).size(withAttributes: [.font: font]).width

        let available = max(0, rightTab - leftWidth - pageWidth - (spaceWidth * 2))
        let maxDots = max(3, Int(floor(available / max(1, dotWidth))))
        let unit = isIndex ? " ." : ". "
        return " " + String(repeating: unit, count: maxDots)
    }

    private func stripLeaderDotsBeforeFirstTab(in attributed: NSMutableAttributedString, range: NSRange) {
        let ns = attributed.string as NSString
        let paragraphText = ns.substring(with: range) as NSString
        let tabRange = paragraphText.range(of: "\t")
        guard tabRange.location != NSNotFound, tabRange.location > 0 else { return }

        var index = tabRange.location - 1
        var dotCount = 0
        var spaceCount = 0
        while index >= 0 {
            let c = paragraphText.character(at: index)
            if c == 46 { // '.'
                dotCount += 1
            } else if c == 32 { // ' '
                spaceCount += 1
            } else {
                break
            }
            index -= 1
        }

        let leaderStart = index + 1
        let leaderLength = tabRange.location - leaderStart
        guard leaderLength > 0, dotCount >= 6, spaceCount >= 6 else { return }

        let deleteRange = NSRange(location: range.location + leaderStart, length: leaderLength)
        attributed.deleteCharacters(in: deleteRange)
    }

    private enum ExportContent {
        case attributed(NSAttributedString)
        case plainText(String)
        case pdf(Data)
    }

    private func captureExportContent(for format: ExportFormat) -> ExportContent {
        switch format {
        case .txt, .markdown:
            return .plainText(mainContentViewController.editorViewController.plainTextContent())
        case .pdf:
            return .pdf(mainContentViewController.editorPDFData())
        default:
            return .attributed(mainContentViewController.editorExportReadyAttributedContent())
        }
    }

    private func exportToURL(_ url: URL, format: ExportFormat) {
        let content = captureExportContent(for: format)
        let didAccess = url.startAccessingSecurityScopedResource()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                try self?.writeDocument(to: url, format: format, content: content)
                DispatchQueue.main.async {
                    if FileManager.default.fileExists(atPath: url.path) {
                        NSDocumentController.shared.noteNewRecentDocumentURL(url)
                        RecentDocuments.shared.note(url)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.debugLog("❌ Export failed: \(error.localizedDescription)")
                    self?.presentErrorAlert(message: "Export failed", details: error.localizedDescription)
                }
            }
        }
    }

    private func saveToURL(_ url: URL, format: ExportFormat) {
        let content = captureExportContent(for: format)
        let didAccess = url.startAccessingSecurityScopedResource()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                try self?.writeDocument(to: url, format: format, content: content)
                DispatchQueue.main.async {
                    guard let self else { return }
                    // Update per-document sidecars/notes to this URL (covers first Save and Save As).
                    self.mainContentViewController.documentURLDidUpdate(url: url)

                    if format == .docx {
                        // Primary document save: attach sidecars (character library) to this URL.
                        CharacterLibrary.shared.setDocumentURL(url)
                    }

                    // Ensure Welcome recents are populated (this app is not NSDocument-based).
                    if FileManager.default.fileExists(atPath: url.path) {
                        NSDocumentController.shared.noteNewRecentDocumentURL(url)
                        RecentDocuments.shared.note(url)
                    }
                    self.hasUnsavedChanges = false
                }
            } catch {
                DispatchQueue.main.async {
                    self?.debugLog("❌ Save failed: \(error.localizedDescription)")
                    self?.presentErrorAlert(message: "Save failed", details: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Auto-Save
    private func startAutoSaveTimer() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil

        let interval = QuillPilotSettings.autoSaveIntervalSeconds
        guard interval > 0 else {
            return
        }

        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.performAutoSave()
        }
    }

    @objc private func performAutoSave() {
        // Only auto-save if we have a document URL and unsaved changes
        guard hasUnsavedChanges, let url = currentDocumentURL else {
            return
        }

        // Silently save in background
        saveToURL(url, format: currentDocumentFormat)
        debugLog("💾 Auto-saved to \(url.lastPathComponent)")
    }

    func markDocumentDirty() {
        hasUnsavedChanges = true
    }

    private func restoreImageSizes(in attributed: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let fullRange = NSRange(location: 0, length: mutable.length)

        mutable.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            guard let attachment = value as? NSTextAttachment else { return }

            // Check for stored size attribute
            if let sizeString = mutable.attribute(NSAttributedString.Key("QuillPilotImageSize"), at: range.location, effectiveRange: nil) as? String {
                let storedBounds = NSRectFromString(sizeString)
                if storedBounds.width > 0 && storedBounds.height > 0 {
                    attachment.bounds = storedBounds
                    debugLog("📷 Restored image size: \(storedBounds.width) x \(storedBounds.height)")
                }
            } else if let filename = attachment.fileWrapper?.preferredFilename,
                      let parsedSize = parseImageSize(from: filename) {
                let bounds = CGRect(origin: .zero, size: parsedSize)
                attachment.bounds = bounds
                debugLog("📷 Restored image size from filename: \(bounds.width) x \(bounds.height)")
            }
        }

        return mutable
    }

    private func stampImageSizes(in attributed: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let fullRange = NSRange(location: 0, length: mutable.length)

        mutable.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            let bounds = attachment.bounds
            if bounds.width > 0 && bounds.height > 0 {
                mutable.addAttribute(NSAttributedString.Key("QuillPilotImageSize"), value: NSStringFromRect(bounds), range: range)

                if let wrapper = attachment.fileWrapper {
                    let ext = ((wrapper.preferredFilename as NSString?)?.pathExtension).flatMap { $0.isEmpty ? nil : $0 } ?? "png"
                    let filename = encodeImageFilename(size: bounds.size, ext: ext)
                    wrapper.preferredFilename = filename
                }
            }
        }

        return mutable
    }

    private func encodeImageFilename(size: CGSize, ext: String) -> String {
        let cleanExt = ext.lowercased()
        let w = Int(round(size.width * 100))
        let h = Int(round(size.height * 100))
        return "image_w\(w)_h\(h).\(cleanExt)"
    }

    private func parseImageSize(from filename: String) -> CGSize? {
        // Expect format: image_w{int}_h{int}.ext where values are hundredths of a point
        // Example: image_w12345_h6789.png
        let pattern = "_w(\\d+)_h(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: filename.utf16.count)
        guard let match = regex.firstMatch(in: filename, options: [], range: range), match.numberOfRanges == 3 else { return nil }

        func value(_ idx: Int) -> CGFloat? {
            let r = match.range(at: idx)
            guard let swiftRange = Range(r, in: filename) else { return nil }
            let str = String(filename[swiftRange])
            guard let intVal = Int(str) else { return nil }
            return CGFloat(intVal) / 100.0
        }

        if let w = value(1), let h = value(2), w > 0, h > 0 {
            return CGSize(width: w, height: h)
        }
        return nil
    }

    @objc private func _saveFormatChanged(_ sender: NSPopUpButton) {
        guard let panel = objc_getAssociatedObject(sender, &AssociatedKeys.savePanelKey) as? NSSavePanel else { return }
        let format = ExportFormat.allCases[sender.indexOfSelectedItem]
        panel.allowedContentTypes = format.contentTypes
        let baseName: String
        if let existingDot = panel.nameFieldStringValue.lastIndex(of: ".") {
            baseName = String(panel.nameFieldStringValue[..<existingDot])
        } else if panel.nameFieldStringValue.isEmpty {
            baseName = "Untitled"
        } else {
            baseName = panel.nameFieldStringValue
        }
        panel.nameFieldStringValue = baseName + "." + format.fileExtension
    }

    @MainActor
    func performOpenDocument(_ sender: Any?) {
        debugLog("MainWindowController.performOpenDocument called")
        guard let window else {
            debugLog("ERROR: window is nil in performOpenDocument")
            return
        }

        debugLog("Creating NSOpenPanel")
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Open"
        panel.allowsOtherFileTypes = true  // Allow system to show compatible file types
        panel.treatsFilePackagesAsDirectories = false  // Show packages as files

        // Create UTTypes for supported formats
        var allowedTypes: [UTType] = []

        // Add .docx type - try multiple identifiers
        if let docxType = UTType("org.openxmlformats.wordprocessingml.document") {
            allowedTypes.append(docxType)
        } else if let docxType = UTType(filenameExtension: "docx", conformingTo: .data) {
            allowedTypes.append(docxType)
        }

        // Apple Pages (.pages) is a file package. If the UTType is available, include it; otherwise fall back to extension.
        if let pagesType = UTType("com.apple.iwork.pages.pages") {
            allowedTypes.append(pagesType)
        } else if let pagesType = UTType(filenameExtension: "pages", conformingTo: .data) {
            allowedTypes.append(pagesType)
        }

        // Add common rich/text formats
        allowedTypes.append(.rtf)
        allowedTypes.append(.rtfd)
        allowedTypes.append(.plainText)
        allowedTypes.append(.html)

        // OpenDocument Text (.odt)
        if let odtType = UTType("org.oasis-open.opendocument.text") {
            allowedTypes.append(odtType)
        } else if let odtType = UTType(filenameExtension: "odt", conformingTo: .data) {
            allowedTypes.append(odtType)
        }

        // Markdown is not a built-in UTType on every macOS SDK; fall back to extension.
        if let mdType = UTType("net.daringfireball.markdown") {
            allowedTypes.append(mdType)
        } else if let mdType = UTType(filenameExtension: "md", conformingTo: .text) {
            allowedTypes.append(mdType)
        }

        // Fade In screenplay (.fadein) is a ZIP archive (Open Screenplay Format).
        if let fadeInType = UTType("com.quillpilot.fadein") {
            allowedTypes.append(fadeInType)
        } else if let fadeInType = UTType(filenameExtension: "fadein", conformingTo: .data) {
            allowedTypes.append(fadeInType)
        }

        // Safety: include `.data` so legacy/mis-typed files (e.g. old flat .rtfd) still appear in the Open panel
        // even if their UTType isn't recognized correctly.
        if !allowedTypes.isEmpty {
            panel.allowedContentTypes = allowedTypes + [.data]
        }

        debugLog("Allowed content types: \(allowedTypes.map { $0.identifier })")

        panel.beginSheetModal(for: window) { response in
            self.debugLog("Open panel response: \(response.rawValue)")
            guard response == .OK, let url = panel.url else { return }
            self.debugLog("About to import file: \(url.path)")
            do {
                try self.importFile(url: url)
            } catch {
                self.presentErrorAlert(message: "Open failed", details: error.localizedDescription)
            }
        }
    }

    @MainActor
    func performOpenDocumentForURL(_ url: URL) {
        do {
            try self.importFile(url: url)
        } catch {
            self.presentErrorAlert(message: "Open failed", details: error.localizedDescription)
        }
    }

    @MainActor
    func performNewDocument(_ sender: Any?) {
        // Ask user to confirm if document has content
        if let content = mainContentViewController.editorViewController.getTextContent(), !content.isEmpty {
            guard let window = self.window else { return }
            let alert = NSAlert.themedConfirmation(
                title: "Create New Document",
                message: "This will clear the current document and all analysis. Do you want to continue?",
                confirmTitle: "New Document",
                cancelTitle: "Cancel"
            )
            alert.runThemedSheet(for: window) { [weak self] response in
                guard response == .alertFirstButtonReturn else { return }
                self?.clearDocumentAndAnalysis()
            }
            return
        }
        clearDocumentAndAnalysis()
    }

    private func clearDocumentAndAnalysis() {

        closeAndClearTOCIndexWindowForDocumentChange()

        // Clear the document and analysis
        debugLog("🆕 NEW DOCUMENT: Clearing editor content")
        mainContentViewController.editorViewController.clearAll()

        debugLog("🆕 NEW DOCUMENT: Clearing analysis")
        mainContentViewController.clearAnalysis()

        // Clear TOC and Index entries for new document
        debugLog("🆕 NEW DOCUMENT: Clearing TOC and Index")

        // Clear search panel fields
        searchPanel?.clearFields()

        // Clear Character Library for the new document
        debugLog("🆕 NEW DOCUMENT: Starting fresh character library")
        CharacterLibrary.shared.loadCharacters(for: nil)

        // Notify that document changed (clears analysis popouts)
        debugLog("🆕 NEW DOCUMENT: Notifying document changed")
        mainContentViewController.documentDidChange(url: nil)

        // Reset the current file path and window title
        currentDocumentURL = nil
        hasUnsavedChanges = false
        window?.title = "Quill Pilot"
        headerView.setDocumentTitle("")
        headerView.specsPanel.setAuthor("")
        debugLog("🆕 NEW DOCUMENT: Complete")
    }

    private func exportData(format: ExportFormat) throws -> Data {
        switch format {
        case .rtf:
            let content = mainContentViewController.editorExportReadyAttributedContent()
            let fullRange = NSRange(location: 0, length: content.length)
            return try content.data(from: fullRange, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        case .rtfd:
            return try mainContentViewController.editorViewController.rtfdData()
        case .odt:
            let content = mainContentViewController.editorExportReadyAttributedContent()
            let fullRange = NSRange(location: 0, length: content.length)
            return try content.data(from: fullRange, documentAttributes: [.documentType: NSAttributedString.DocumentType.openDocument])
        case .txt:
            return Data(mainContentViewController.editorViewController.plainTextContent().utf8)
        case .markdown:
            return Data(mainContentViewController.editorViewController.plainTextContent().utf8)
        case .html:
            let content = mainContentViewController.editorExportReadyAttributedContent()
            let fullRange = NSRange(location: 0, length: content.length)
            return try content.data(from: fullRange, documentAttributes: [.documentType: NSAttributedString.DocumentType.html])
        case .pdf:
            return mainContentViewController.editorPDFData()
        case .docx:
            let stamped = stampImageSizes(in: mainContentViewController.editorExportReadyAttributedContent())
            return try DocxBuilder.makeDocxData(from: stamped)
        case .epub:
            let content = mainContentViewController.editorExportReadyAttributedContent()
            // Use a temporary URL since generateEPub needs one
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("epub")
            return try self.generateEPub(from: content, url: tempURL)
        case .mobi:
            let content = mainContentViewController.editorExportReadyAttributedContent()
            // Use a temporary URL since generateMobi needs one
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mobi")
            return try self.generateMobi(from: content, url: tempURL)
        }
    }

    private func readTextFromFile(at url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        if data.isEmpty { return "" }

        func decode(_ data: Data, encoding: String.Encoding) -> String? {
            String(data: data, encoding: encoding)
        }

        // BOM-based detection.
        if data.count >= 3, data[0] == 0xEF, data[1] == 0xBB, data[2] == 0xBF {
            if let s = decode(Data(data.dropFirst(3)), encoding: .utf8) { return s }
        }
        if data.count >= 4 {
            // UTF-32 BOM
            if data[0] == 0x00, data[1] == 0x00, data[2] == 0xFE, data[3] == 0xFF {
                if let s = decode(Data(data.dropFirst(4)), encoding: .utf32BigEndian) { return s }
            }
            if data[0] == 0xFF, data[1] == 0xFE, data[2] == 0x00, data[3] == 0x00 {
                if let s = decode(Data(data.dropFirst(4)), encoding: .utf32LittleEndian) { return s }
            }
        }
        if data.count >= 2 {
            // UTF-16 BOM
            if data[0] == 0xFE, data[1] == 0xFF {
                if let s = decode(Data(data.dropFirst(2)), encoding: .utf16BigEndian) { return s }
            }
            if data[0] == 0xFF, data[1] == 0xFE {
                if let s = decode(Data(data.dropFirst(2)), encoding: .utf16LittleEndian) { return s }
            }
        }

        // Heuristic detection for UTF-16 without BOM (common for some editor exports).
        if data.count >= 8 {
            var zeroEven = 0
            var zeroOdd = 0
            var checked = 0
            let limit = min(data.count, 4096)
            for i in 0..<limit {
                let b = data[i]
                if b == 0 {
                    if i % 2 == 0 { zeroEven += 1 } else { zeroOdd += 1 }
                }
                checked += 1
            }

            // If a large portion of bytes are NULs, it likely isn't single-byte text.
            let nulRatio = Double(zeroEven + zeroOdd) / Double(checked)
            if nulRatio > 0.20 {
                // ASCII-in-UTF16LE looks like: 0x41 0x00 (NULs on odd indices).
                if zeroOdd > zeroEven, let s = decode(data, encoding: .utf16LittleEndian) { return s }
                // ASCII-in-UTF16BE looks like: 0x00 0x41 (NULs on even indices).
                if zeroEven > zeroOdd, let s = decode(data, encoding: .utf16BigEndian) { return s }
            }
        }

        // Fallback attempts.
        let fallbackEncodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .utf32,
            .utf32LittleEndian,
            .utf32BigEndian,
            .windowsCP1252,
            .isoLatin1,
            .macOSRoman
        ]

        for encoding in fallbackEncodings {
            if let s = decode(data, encoding: encoding) {
                return s
            }
        }

        throw NSError(
            domain: "QuillPilot.TextDecoding",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Quill Pilot couldn't determine this file's text encoding.",
                NSLocalizedRecoverySuggestionErrorKey: "Try re-saving/exporting it as UTF-8 or UTF-16, then import again."
            ]
        )
    }

    private func importFile(url: URL) throws {
        debugLog("=== importFile called with: \(url.path) ===")
        let ext = url.pathExtension.lowercased()
        debugLog("File extension: \(ext)")

        closeAndClearTOCIndexWindowForDocumentChange()

        // Clear TOC and Index entries before loading new document
        debugLog("📂 OPENING DOCUMENT: Clearing TOC and Index")

        // Clear search panel fields
        searchPanel?.clearFields()

        // Load characters for this document
        debugLog("📂 OPENING DOCUMENT: Loading characters for document")
        CharacterLibrary.shared.loadCharacters(for: url)

        debugLog("📂 OPENING DOCUMENT: Clearing analysis")
        mainContentViewController.clearAnalysis()

        // Support multiple formats
        switch ext {
        case "docx":
            // Import Word document
            let filename = url.deletingPathExtension().lastPathComponent
            headerView.setDocumentTitle(filename)
            // Treat opened DOCX as the current document so Save overwrites without prompting.
            currentDocumentURL = url
            currentDocumentFormat = .docx
            hasUnsavedChanges = false
            mainContentViewController.editorViewController.headerText = ""
            mainContentViewController.editorViewController.headerTextRight = ""
            mainContentViewController.editorViewController.footerText = ""
            mainContentViewController.editorViewController.footerTextRight = ""

            // Notify Navigator that document changed
            mainContentViewController.documentDidChange(url: url)

            // Show placeholder text immediately so user sees the app is working
            mainContentViewController.editorViewController.textView?.string = "Loading document..."

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                // Read once; we may use either the system importer or our custom parser.
                let data: Data
                do {
                    data = try Data(contentsOf: url)
                } catch {
                    DispatchQueue.main.async {
                        self?.presentErrorAlert(message: "Failed to open Word document", details: error.localizedDescription)
                    }
                    return
                }

                // If this DOCX looks like it was generated by QuillPilot, prefer the custom extractor.
                // The system OfficeOpenXML importer can drop paragraph indents and style identity,
                // which causes Body Text to reopen as "Body Text – No Indent".
                let preferCustomExtractor = DocxTextExtractor.seemsQuillPilotGenerated(docxData: data)

                if preferCustomExtractor {
                    do {
                        let attributedString = try DocxTextExtractor.extractAttributedString(fromDocxData: data)
                        let restored = self?.restoreImageSizes(in: attributedString) ?? attributedString
                        DispatchQueue.main.async {
                            guard let self else { return }
                            self.applyImportedContent(restored, url: url)
                            self.currentDocumentFormat = .docx
                        }
                        return
                    } catch {
                        // If our parser fails, fall back to the system importer below.
                    }
                }

                // First try macOS's native Office Open XML importer (no Mammoth / custom XML parsing).
                // This is generally faster and preserves more formatting when supported.
                do {
                    let attributed = try NSAttributedString(
                        url: url,
                        options: [.documentType: NSAttributedString.DocumentType.officeOpenXML],
                        documentAttributes: nil
                    )

                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.applyImportedContent(attributed, url: url)
                        // Default to DOCX when saving after opening a DOCX.
                        self.currentDocumentFormat = .docx
                    }
                    return
                } catch {
                    // Fall through to the existing DOCX extractor below.
                }

                // Get file size for logging
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
                self?.debugLog("📄 File size: \(fileSize) bytes (\(fileSize / 1024 / 1024) MB)")

                // Parse in background, set content directly on main thread
                self?.debugLog("📄 Starting DOCX extraction for: \(url.lastPathComponent)")
                let startTime = CFAbsoluteTimeGetCurrent()
                do {
                    self?.debugLog("📄 File data read: \(data.count) bytes in \(CFAbsoluteTimeGetCurrent() - startTime)s")

                    let parseStart = CFAbsoluteTimeGetCurrent()
                    self?.debugLog("📄 Starting XML parsing...")
                    let attributedString = try DocxTextExtractor.extractAttributedString(fromDocxData: data)
                    self?.debugLog("📄 Parsing complete: \(attributedString.length) chars in \(CFAbsoluteTimeGetCurrent() - parseStart)s")

                    let restoreStart = CFAbsoluteTimeGetCurrent()
                    let restored = self?.restoreImageSizes(in: attributedString) ?? attributedString
                    self?.debugLog("📄 Image restore took \(CFAbsoluteTimeGetCurrent() - restoreStart)s")

                    self?.debugLog("📄 Total extraction time: \(CFAbsoluteTimeGetCurrent() - startTime)s")

                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.debugLog("📄 Setting content on main thread, length: \(restored.length)")
                        let setStart = CFAbsoluteTimeGetCurrent()
                        self.applyImportedContent(restored, url: url)
                        self.currentDocumentFormat = .docx
                        self.debugLog("📄 Content set complete in \(CFAbsoluteTimeGetCurrent() - setStart)s")
                    }
                } catch {
                    self?.debugLog("📄 DOCX extraction failed: \(error)")
                    DispatchQueue.main.async {
                        self?.presentErrorAlert(message: "Failed to open Word document", details: error.localizedDescription)
                    }
                }
            }
            return

        case "pages":
            // Import Apple Pages document.
            // We don't write .pages; after import we treat it like an unsaved document and prompt on Save.
            let filename = url.deletingPathExtension().lastPathComponent
            headerView.setDocumentTitle(filename)
            currentDocumentURL = nil
            currentDocumentFormat = .docx
            hasUnsavedChanges = false
            mainContentViewController.editorViewController.headerText = ""
            mainContentViewController.editorViewController.headerTextRight = ""
            mainContentViewController.editorViewController.footerText = ""
            mainContentViewController.editorViewController.footerTextRight = ""

            mainContentViewController.documentDidChange(url: url)
            mainContentViewController.editorViewController.textView?.string = "Loading document..."

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    // Best-effort: let AppKit try to import directly if a system filter is available.
                    if let attributed = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
                        DispatchQueue.main.async {
                            self?.applyImportedContent(attributed, url: url)
                            self?.currentDocumentFormat = .docx
                        }
                        return
                    }

                    // Fallback: ask Pages.app to export to RTF, then import that.
                    guard let self else { return }
                    let rtfURL = try self.convertPagesDocumentToRTF(pagesURL: url)
                    let attributed = try NSAttributedString(
                        url: rtfURL,
                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                        documentAttributes: nil
                    )

                    DispatchQueue.main.async {
                        self.applyImportedContent(attributed, url: url)
                        self.currentDocumentFormat = .docx
                    }
                } catch {
                    DispatchQueue.main.async {
                        self?.presentErrorAlert(
                            message: "Failed to open Pages document",
                            details: "Quill Pilot can import .pages using macOS conversion filters or Apple Pages.\n\nIf this fails, make sure Pages is installed and allow Quill Pilot to control Pages when macOS asks for permission.\n\nDetails: \(error.localizedDescription)"
                        )
                    }
                }
            }
            return

        case "fadein":
            // Fade In screenplay format is plain text with screenplay semantics.
            // Switch to the Screenplay template so the expected styles exist.
            toolbarView.selectTemplateProgrammatically("Screenplay")

            let filename = url.deletingPathExtension().lastPathComponent
            headerView.setDocumentTitle(filename)
            currentDocumentURL = url
            currentDocumentFormat = .txt
            hasUnsavedChanges = false
            mainContentViewController.editorViewController.headerText = ""
            mainContentViewController.editorViewController.headerTextRight = ""
            mainContentViewController.editorViewController.footerText = ""
            mainContentViewController.editorViewController.footerTextRight = ""

            mainContentViewController.documentDidChange(url: url)
            mainContentViewController.editorViewController.textView?.string = "Loading document..."

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    let attributed: NSAttributedString

                    // Real Fade In `.fadein` files are ZIP archives containing `document.xml`.
                    if FadeInImporter.isZipArchive(at: url) {
                        attributed = try FadeInImporter.attributedString(fromFadeInURL: url)
                    } else {
                        let text = try self?.readTextFromFile(at: url) ?? ""
                        attributed = ScreenplayImporter.attributedString(fromPlainText: text)
                    }

                    DispatchQueue.main.async {
                        self?.applyImportedContent(attributed, url: url)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self?.presentErrorAlert(message: "Failed to open screenplay", details: error.localizedDescription)
                    }
                }
            }
            return

        case "rtf", "rtfd", "odt", "txt", "md", "markdown", "html", "htm":
            let filename = url.deletingPathExtension().lastPathComponent
            headerView.setDocumentTitle(filename)
            currentDocumentURL = url
            hasUnsavedChanges = false
            mainContentViewController.editorViewController.headerText = ""
            mainContentViewController.editorViewController.headerTextRight = ""
            mainContentViewController.editorViewController.footerText = ""
            mainContentViewController.editorViewController.footerTextRight = ""

            // Determine best default save format based on input
            switch ext {
            case "rtf": currentDocumentFormat = .rtf
            case "rtfd": currentDocumentFormat = .rtfd
            case "odt": currentDocumentFormat = .odt
            case "txt": currentDocumentFormat = .txt
            case "md", "markdown": currentDocumentFormat = .markdown
            case "html", "htm": currentDocumentFormat = .html
            default: currentDocumentFormat = .docx
            }

            mainContentViewController.documentDidChange(url: url)
            mainContentViewController.editorViewController.textView?.string = "Loading document..."

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    let attributed: NSAttributedString
                    switch ext {
                    case "rtf":
                        attributed = try NSAttributedString(
                            url: url,
                            options: [.documentType: NSAttributedString.DocumentType.rtf],
                            documentAttributes: nil
                        )
                    case "rtfd":
                        // RTFD is a file *package* (directory). Older builds incorrectly wrote RTFD
                        // as a single flat file. If we detect that case, read as data and migrate.
                        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                        if isDirectory {
                            attributed = try NSAttributedString(
                                url: url,
                                options: [.documentType: NSAttributedString.DocumentType.rtfd],
                                documentAttributes: nil
                            )
                        } else {
                            let data = try Data(contentsOf: url)
                            do {
                                attributed = try NSAttributedString(
                                    data: data,
                                    options: [.documentType: NSAttributedString.DocumentType.rtfd],
                                    documentAttributes: nil
                                )
                            } catch {
                                // If the data isn't parseable as RTFD, try RTF as a last resort.
                                attributed = try NSAttributedString(
                                    data: data,
                                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                                    documentAttributes: nil
                                )
                            }

                            // Best-effort migration: convert legacy flat .rtfd into a proper package.
                            do {
                                let fullRange = NSRange(location: 0, length: attributed.length)
                                let wrapper = try attributed.fileWrapper(
                                    from: fullRange,
                                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
                                )

                                // Replace the old file with the new .rtfd package at the same URL.
                                if FileManager.default.fileExists(atPath: url.path) {
                                    try FileManager.default.removeItem(at: url)
                                }
                                try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
                                self?.debugLog("✅ Migrated legacy flat RTFD to package: \(url.lastPathComponent)")
                            } catch {
                                self?.debugLog("⚠️ Legacy RTFD migration failed: \(error.localizedDescription)")
                            }
                        }
                    case "odt":
                        attributed = try NSAttributedString(
                            url: url,
                            options: [.documentType: NSAttributedString.DocumentType.openDocument],
                            documentAttributes: nil
                        )
                    case "html", "htm":
                        attributed = try NSAttributedString(
                            url: url,
                            options: [.documentType: NSAttributedString.DocumentType.html],
                            documentAttributes: nil
                        )
                    case "txt", "md", "markdown":
                        let text = try self?.readTextFromFile(at: url) ?? ""
                        // Plain-text imports: infer screenplay/poetry by structure.
                        // Screenplay wins first so .txt screenplays don't get pulled into prose.
                        if ScreenplayImporter.looksLikeScreenplay(text) {
                            self?.toolbarView.selectTemplateProgrammatically("Screenplay")
                            attributed = ScreenplayImporter.attributedString(fromPlainText: text)
                        } else if PoetryImporter.looksLikePoetry(text) {
                            self?.toolbarView.selectTemplateProgrammatically("Poetry")
                            attributed = PoetryImporter.attributedString(fromPlainText: text)
                        } else if StyleCatalog.shared.currentTemplateName == "Screenplay" {
                            attributed = ScreenplayImporter.attributedString(fromPlainText: text)
                        } else {
                            attributed = NSAttributedString(string: text)
                        }
                    default:
                        let text = try self?.readTextFromFile(at: url) ?? ""
                        attributed = NSAttributedString(string: text)
                    }

                    DispatchQueue.main.async {
                        self?.applyImportedContent(attributed, url: url)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self?.presentErrorAlert(message: "Failed to open document", details: error.localizedDescription)
                    }
                }
            }

        default:
            presentErrorAlert(
                message: "Unsupported format",
                details: "Quill Pilot opens .docx, .odt, .pages, .rtf, .rtfd, .txt, .md, .html, and .fadein documents.\n\nUse Export to save as Word (.docx), OpenDocument (.odt), RTF/RTFD, PDF, ePub, Kindle, HTML, or Text."
            )
            return
        }
    }

    private func convertPagesDocumentToRTF(pagesURL: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuillPilot-PagesImport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let outURL = tempDir
            .appendingPathComponent(pagesURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("rtf")

        func escapeForAppleScript(_ path: String) -> String {
            path
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
        }

        let inPath = escapeForAppleScript(pagesURL.path)
        let outPath = escapeForAppleScript(outURL.path)

        // Pages scripting dictionary uses export format enumerator name "formatted text" for RTF.
        // (Using "RTF" or "Rich Text" can fail with -2753/-1700 depending on Pages version.)
        let script = """
        tell application "Pages"
            launch
            try
                set visible to false
            end try
            set theDoc to open POSIX file "\(inPath)"
            export theDoc to POSIX file "\(outPath)" as formatted text
            close theDoc saving no
        end tell
        """

        var errorDict: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            throw NSError(domain: "QuillPilot", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create Pages conversion script."])
        }
        appleScript.executeAndReturnError(&errorDict)
        if let errorDict {
            let message = (errorDict[NSAppleScript.errorMessage] as? String) ?? "Pages conversion failed."
            let number = errorDict[NSAppleScript.errorNumber] as? Int
            let details = number.map { "\(message) (AppleScript error \($0))" } ?? message
            throw NSError(domain: "QuillPilot", code: number ?? 1, userInfo: [NSLocalizedDescriptionKey: details])
        }

        guard FileManager.default.fileExists(atPath: outURL.path) else {
            throw NSError(domain: "QuillPilot", code: 2, userInfo: [NSLocalizedDescriptionKey: "Pages did not produce an RTF file."])
        }
        return outURL
    }

    private func presentErrorAlert(message: String, details: String) {
        guard let window else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = details
        alert.beginSheetModal(for: window)
    }

    @MainActor
    private func applyImportedContent(_ attributed: NSAttributedString, url: URL) {
        // If the imported content is already tagged with a template-specific Quill style name,
        // switch templates before we run style retagging/materialization so the style definitions exist.
        if let inferredTemplate = inferTemplateFromImportedContent(in: attributed),
           inferredTemplate != StyleCatalog.shared.currentTemplateName {
            toolbarView.selectTemplateProgrammatically(inferredTemplate)
        }

        mainContentViewController.editorViewController.setAttributedContentDirect(attributed)
        mainContentViewController.editorViewController.applyTheme(ThemeManager.shared.currentTheme)

        // If this is a screenplay and the Character Library is empty for this document,
        // auto-seed it from styled character cue lines so a sidecar is created on first import.
        if StyleCatalog.shared.currentTemplateName == "Screenplay" && CharacterLibrary.shared.characters.isEmpty {
            let cues = mainContentViewController.editorViewController.extractScreenplayCharacterCues()
            CharacterLibrary.shared.seedCharactersIfEmpty(cues)
        } else if CharacterLibrary.shared.characters.isEmpty {
            let cues = mainContentViewController.editorViewController.extractFictionCharacterCues()
            CharacterLibrary.shared.seedCharactersIfEmpty(cues)
        }

        // Ensure TOC/Index paragraphs keep right-tab alignment after DOCX/RTF imports.
        // Some importers drop paragraph tab stops; we repair based on QuillStyleName.
        DispatchQueue.main.async { [weak self] in
            self?.mainContentViewController.editorViewController.repairTOCAndIndexFormattingAfterImport()
        }

        if let textStorage = mainContentViewController.editorViewController.textView?.textStorage {
            _ = TOCIndexManager.shared.generateIndexFromMarkers(in: textStorage)
        }

        if let text = mainContentViewController.editorViewController.textView?.string {
            headerView.specsPanel.updateStats(text: text)
        }

        if QuillPilotSettings.autoAnalyzeOnOpen {
            mainContentViewController.performAnalysis()
        }
        NotificationCenter.default.post(name: Notification.Name("QuillPilotOutlineRefresh"), object: nil)

        // Ensure Welcome recents are populated (this app is not NSDocument-based).
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        RecentDocuments.shared.note(url)
    }

    private func inferTemplateFromImportedContent(in attributed: NSAttributedString) -> String? {
        if let tagged = inferTemplateFromImportedStyleTags(in: attributed) {
            return tagged
        }
        return inferTemplateFromImportedFontsAndStructure(in: attributed)
    }

    private func inferTemplateFromImportedStyleTags(in attributed: NSAttributedString) -> String? {
        let styleKey = NSAttributedString.Key("QuillStyleName")
        let fullRange = NSRange(location: 0, length: attributed.length)

        var inferred: String? = nil
        attributed.enumerateAttribute(styleKey, in: fullRange, options: []) { value, _, stop in
            guard let styleName = value as? String else { return }
            if styleName.hasPrefix("Screenplay —") {
                inferred = "Screenplay"
                stop.pointee = true
                return
            }
            if styleName.hasPrefix("Poetry —") {
                inferred = "Poetry"
                stop.pointee = true
                return
            }

            // Poetry: modern tags used in current builds (no "Poetry —" prefix), plus legacy/container tags.
            if styleName == "Verse" || styleName == "Stanza" || styleName == "Poem" {
                inferred = "Poetry"
                stop.pointee = true
                return
            }
        }

        return inferred
    }

    private func inferTemplateFromImportedFontsAndStructure(in attributed: NSAttributedString) -> String? {
        let preferredProseTemplate = "Palatino"

        // 1) Screenplay: strong structural signal (sluglines/transitions), even if the import lacks font attributes.
        if ScreenplayImporter.looksLikeScreenplay(attributed.string) {
            return "Screenplay"
        }

        // 2) Screenplay: monospaced/Courier-like dominant font.
        let dominantFont = dominantFontForInference(in: attributed)
        if let font = dominantFont, isMonospacedForScreenplay(font) {
            return "Screenplay"
        }

        // 3) Poetry: strong structural signal (many short, hard-wrapped lines).
        if looksLikePoetryByLineStructure(attributed.string) {
            return "Poetry"
        }

        // 4) Prose: choose the closest matching font-family template, if any.
        if let family = dominantFont?.familyName {
            let available = StyleCatalog.shared.availableTemplates()
            if let match = available.first(where: { $0.caseInsensitiveCompare(family) == .orderedSame }) {
                return match
            }
            // Common mismatch: template name includes a qualifier.
            let fuzzyCandidates = available.filter { $0.localizedCaseInsensitiveContains(family) || family.localizedCaseInsensitiveContains($0) }
            if fuzzyCandidates.contains(where: { $0.caseInsensitiveCompare(preferredProseTemplate) == .orderedSame }) {
                return preferredProseTemplate
            }
            if let fuzzy = fuzzyCandidates.first {
                return fuzzy
            }
        }

        // Final fallback: user-preferred prose template.
        if StyleCatalog.shared.availableTemplates().contains(where: { $0.caseInsensitiveCompare(preferredProseTemplate) == .orderedSame }) {
            return preferredProseTemplate
        }

        return nil
    }

    private func dominantFontForInference(in attributed: NSAttributedString) -> NSFont? {
        guard attributed.length > 0 else { return nil }
        let maxSample = min(attributed.length, 8000)
        let sampleRange = NSRange(location: 0, length: maxSample)

        var totals: [String: Int] = [:]
        var representative: [String: NSFont] = [:]
        attributed.enumerateAttribute(.font, in: sampleRange, options: []) { value, range, _ in
            guard let font = value as? NSFont else { return }
            let key = font.familyName ?? font.fontName
            totals[key, default: 0] += range.length
            if representative[key] == nil {
                representative[key] = font
            }
        }

        guard let best = totals.max(by: { $0.value < $1.value })?.key else { return nil }
        return representative[best]
    }

    private func isMonospacedForScreenplay(_ font: NSFont) -> Bool {
        if let family = font.familyName?.lowercased() {
            if family.contains("courier") { return true }
            if family.contains("menlo") { return true }
            if family.contains("monaco") { return true }
        }
        let traits = NSFontManager.shared.traits(of: font)
        return traits.contains(.fixedPitchFontMask)
    }

    private func looksLikePoetryByLineStructure(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Examine only a prefix to keep this fast.
        let prefix = String(trimmed.prefix(6000))
        let lines = prefix.split(whereSeparator: \.isNewline)
        guard lines.count >= 8 else { return false }

        var nonEmpty = 0
        var shortLines = 0
        var totalLen = 0

        for raw in lines.prefix(80) {
            let s = raw.trimmingCharacters(in: .whitespaces)
            guard !s.isEmpty else { continue }
            nonEmpty += 1
            totalLen += s.count
            if s.count <= 50 {
                shortLines += 1
            }
        }

        guard nonEmpty >= 8 else { return false }
        let avg = Double(totalLen) / Double(nonEmpty)
        let shortRatio = Double(shortLines) / Double(nonEmpty)

        // Poetry tends to have many short, deliberate line breaks.
        return avg < 55 && shortRatio >= 0.65
    }

    private enum AssociatedKeys {
        static var savePanelKey: UInt8 = 0
    }
}

// MARK: - NSWindowDelegate (close warning)
extension MainWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard hasUnsavedChanges else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Save changes before closing?"
        alert.informativeText = "This document has changes that haven't been auto-saved yet."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runThemedModal()
        switch response {
        case .alertFirstButtonReturn:
            // If we have a URL, save synchronously and allow close only on success.
            if let url = currentDocumentURL {
                saveToURL(url, format: currentDocumentFormat)
                return !hasUnsavedChanges
            }

            // New/unsaved document: show Save As sheet and keep the window open.
            performSaveAs(nil)
            return false

        case .alertSecondButtonReturn:
            // Discard changes
            hasUnsavedChanges = false
            return true

        default:
            return false
        }
    }
}

// MARK: - Header View (Logo, Title, Specs, Theme Toggle)
class HeaderView: NSView {

    private var logoView: LogoView!
    private var titleLabel: NSTextField!
    private var taglineLabel: NSTextField!
    var specsPanel: DocumentInfoPanel!
    private var themeToggleButton: NSButton!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true

        // Logo (left)
        logoView = LogoView(size: 40)
        logoView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logoView)

        // Title
        titleLabel = NSTextField(labelWithString: "Quill Pilot")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .medium)
        titleLabel.textColor = ThemeManager.shared.currentTheme.headerText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Tagline (two lines) next to title
        taglineLabel = NSTextField(labelWithString: "Advanced writing analysis and visualization\nFor Fiction • Nonfiction • Poetry • Screenplays")
        taglineLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        taglineLabel.textColor = ThemeManager.shared.currentTheme.headerText.withAlphaComponent(0.75)
        taglineLabel.lineBreakMode = .byWordWrapping
        taglineLabel.maximumNumberOfLines = 2
        taglineLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(taglineLabel)

        // Specs panel (word count, page count, etc.)
        specsPanel = DocumentInfoPanel()
        specsPanel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(specsPanel)

        // Theme toggle (right) - single button cycles Night → Cream → Day
        themeToggleButton = NSButton(title: "", target: self, action: #selector(themeToggleClicked(_:)))
        themeToggleButton.translatesAutoresizingMaskIntoConstraints = false
        // Borderless icon-only button avoids macOS accent (blue) tint.
        themeToggleButton.bezelStyle = .inline
        themeToggleButton.isBordered = false
        themeToggleButton.controlSize = .small
        themeToggleButton.setButtonType(.momentaryPushIn)
        themeToggleButton.toolTip = "Cycle theme (Night → Cream → Day)"
        themeToggleButton.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(themeToggleButton)

        NSLayoutConstraint.activate([
            // Logo at left - fills height with 4pt padding
            logoView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            logoView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            logoView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            logoView.widthAnchor.constraint(equalTo: logoView.heightAnchor),

            // Title next to logo
            titleLabel.leadingAnchor.constraint(equalTo: logoView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            // Tagline next to title
            taglineLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 12),
            taglineLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            taglineLabel.trailingAnchor.constraint(lessThanOrEqualTo: specsPanel.leadingAnchor, constant: -12),

            // Specs panel centered in header
            specsPanel.centerXAnchor.constraint(equalTo: centerXAnchor),
            specsPanel.centerYAnchor.constraint(equalTo: centerYAnchor),
            specsPanel.widthAnchor.constraint(lessThanOrEqualToConstant: 500),

            // Theme toggle anchored to the right
            themeToggleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            themeToggleButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            // Prevent overlap between centered specs and the right toggle
            specsPanel.trailingAnchor.constraint(lessThanOrEqualTo: themeToggleButton.leadingAnchor, constant: -12)
        ])

        applyTheme(ThemeManager.shared.currentTheme)
    }

    func applyTheme(_ theme: AppTheme) {
        wantsLayer = true
        layer?.backgroundColor = theme.headerBackground.cgColor
        titleLabel.textColor = theme.headerText
        taglineLabel.textColor = theme.headerText.withAlphaComponent(0.75)
        specsPanel.applyTheme(theme)

        // Day theme: apply orange border to header icon button.
        themeToggleButton.wantsLayer = true
        themeToggleButton.layer?.masksToBounds = true
        if theme == .day {
            themeToggleButton.layer?.borderWidth = 1
            themeToggleButton.layer?.borderColor = theme.pageBorder.cgColor
            themeToggleButton.layer?.cornerRadius = 6
        } else {
            themeToggleButton.layer?.borderWidth = 0
        }

        // Icon-only toggle that reflects the current theme.
        if #available(macOS 11.0, *) {
            let imageName: String
            switch theme {
            case .night:
                imageName = "moon.stars.fill"
            case .cream, .day:
                imageName = "sun.max.fill"
            }

            let baseImage = NSImage(systemSymbolName: imageName, accessibilityDescription: "Theme")
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            themeToggleButton.image = baseImage?.withSymbolConfiguration(config)
            themeToggleButton.imagePosition = .imageOnly
            themeToggleButton.title = ""
            themeToggleButton.image?.isTemplate = true
            if #available(macOS 10.14, *) {
                themeToggleButton.contentTintColor = theme.headerText.withAlphaComponent(0.92)
            }
            let label = themeDisplayName(for: theme)
            themeToggleButton.toolTip = "Theme: \(label). Click to cycle (Night → Cream → Day)."
        } else {
            // Fallback for older macOS: show a short text label.
            themeToggleButton.title = themeDisplayName(for: theme)
        }
    }

    private func themeDisplayName(for theme: AppTheme) -> String {
        switch theme {
        case .day:
            return "Day"
        case .cream:
            return "Cream"
        case .night:
            return "Night"
        }
    }

    @objc private func themeToggleClicked(_ sender: Any?) {
        ThemeManager.shared.toggleTheme()
    }

    func setDocumentTitle(_ title: String) {
        specsPanel.setTitle(title)
    }

    func documentTitle() -> String {
        specsPanel.getTitle()
    }
}

// MARK: - Formatting Toolbar
class FormattingToolbar: NSView {

    weak var delegate: FormattingToolbarDelegate?

    private var themedControls: [NSControl] = []

    // Combined style/template popup (accordion-style menu)
    private var stylePopup: NSPopUpButton!
    private var sizePopup: NSPopUpButton!
    private var editStylesButton: NSButton!
    private var imageButton: NSButton!
    private var outlinePanelButton: NSButton!
    private var paragraphMarksButton: NSButton!
    private var currentTemplate: String = "Novel"
    private var templateObserver: NSObjectProtocol?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = ThemeManager.shared.currentTheme.toolbarBackground.cgColor

        // Combined Style & Template popup (accordion-style menu)
        stylePopup = registerControl(NSPopUpButton(frame: .zero, pullsDown: false))
        buildCombinedStyleMenu()
        stylePopup.translatesAutoresizingMaskIntoConstraints = false
        stylePopup.target = self
        stylePopup.action = #selector(styleChanged(_:))
        stylePopup.toolTip = "Style & Template"
        stylePopup.setAccessibilityLabel("Style & Template")

        editStylesButton = createToolbarButton("Style Editor")
        editStylesButton.target = self
        editStylesButton.action = #selector(openStyleEditorTapped)
        editStylesButton.toolTip = "Open Style Editor"
        editStylesButton.setAccessibilityLabel("Open Style Editor")

        // Format painter button
        let formatPainterBtn = createSymbolToolbarButton(systemName: "paintbrush", accessibility: "Format Painter")
        formatPainterBtn.target = self
        formatPainterBtn.action = #selector(formatPainterTapped)
        formatPainterBtn.toolTip = "Format Painter (Copy Style)"

        // Font size controls
        let decreaseSizeBtn = registerControl(NSButton(title: "−", target: self, action: #selector(decreaseFontSizeTapped)))
        decreaseSizeBtn.toolTip = "Decrease Font Size"
        decreaseSizeBtn.setAccessibilityLabel("Decrease Font Size")
        sizePopup = registerControl(NSPopUpButton(frame: .zero, pullsDown: false))
        sizePopup.addItems(withTitles: ["8", "9", "10", "11", "12", "14", "16", "18", "20", "24", "28", "32"])
        sizePopup.selectItem(withTitle: "20")
        sizePopup.target = self
        sizePopup.action = #selector(fontSizeChanged(_:))
        sizePopup.toolTip = "Font Size"
        sizePopup.setAccessibilityLabel("Font Size")
        let increaseSizeBtn = registerControl(NSButton(title: "+", target: self, action: #selector(increaseFontSizeTapped)))
        increaseSizeBtn.toolTip = "Increase Font Size"
        increaseSizeBtn.setAccessibilityLabel("Increase Font Size")

        // Text styling
        let boldBtn = createToolbarButton("B", weight: .bold)
        let italicBtn = createToolbarButton("I", isItalic: true)
        let underlineBtn = createToolbarButton("U", isUnderlined: true)
        let strikethroughBtn = createToolbarButton("S", isStrikethrough: true)
        boldBtn.target = self
        boldBtn.action = #selector(boldTapped)
        boldBtn.toolTip = "Bold"
        boldBtn.setAccessibilityLabel("Bold")
        italicBtn.target = self
        italicBtn.action = #selector(italicTapped)
        italicBtn.toolTip = "Italic"
        italicBtn.setAccessibilityLabel("Italic")
        underlineBtn.target = self
        underlineBtn.action = #selector(underlineTapped)
        underlineBtn.toolTip = "Underline"
        underlineBtn.setAccessibilityLabel("Underline")
        strikethroughBtn.target = self
        strikethroughBtn.action = #selector(strikethroughTapped)
        strikethroughBtn.toolTip = "Strikethrough"
        strikethroughBtn.setAccessibilityLabel("Strikethrough")

        // Baseline
        let superscriptBtn = createToolbarButton("x²", fontSize: 13)
        superscriptBtn.target = self
        superscriptBtn.action = #selector(superscriptTapped)
        superscriptBtn.toolTip = "Superscript"
        superscriptBtn.setAccessibilityLabel("Superscript")

        let subscriptBtn = createToolbarButton("x₂", fontSize: 13)
        subscriptBtn.target = self
        subscriptBtn.action = #selector(subscriptTapped)
        subscriptBtn.toolTip = "Subscript"
        subscriptBtn.setAccessibilityLabel("Subscript")

        // Alignment
                let alignLeftBtn = createToolbarButton("≡", fontSize: 20)
                let alignCenterBtn = createToolbarButton("≣", fontSize: 20)
                let alignRightBtn = createToolbarButton("≡", fontSize: 20)
                let justifyBtn = createToolbarButton("≣", fontSize: 20)
                alignLeftBtn.target = self
                alignLeftBtn.action = #selector(alignLeftTapped)
                alignLeftBtn.toolTip = "Align Left"
                alignLeftBtn.setAccessibilityLabel("Align Left")
                alignCenterBtn.target = self
                alignCenterBtn.action = #selector(alignCenterTapped)
                alignCenterBtn.toolTip = "Align Center"
                alignCenterBtn.setAccessibilityLabel("Align Center")
                alignRightBtn.target = self
                alignRightBtn.action = #selector(alignRightTapped)
                alignRightBtn.toolTip = "Align Right"
                alignRightBtn.setAccessibilityLabel("Align Right")
                justifyBtn.target = self
                justifyBtn.action = #selector(justifyTapped)
                justifyBtn.toolTip = "Justify"
                justifyBtn.setAccessibilityLabel("Justify")

        // Lists
        let bulletsBtn = createToolbarButton("•")
        let numberingBtn = createToolbarButton("1.")
        bulletsBtn.target = self
        bulletsBtn.action = #selector(bulletsTapped)
        bulletsBtn.toolTip = "Bulleted List"
        bulletsBtn.setAccessibilityLabel("Bulleted List")
        numberingBtn.target = self
        numberingBtn.action = #selector(numberingTapped)
        numberingBtn.toolTip = "Numbered List"
        numberingBtn.setAccessibilityLabel("Numbered List")

        // Images
        if let baseSymbol = NSImage(systemSymbolName: "photo", accessibilityDescription: "Insert Image") {
            let theme = ThemeManager.shared.currentTheme
            let sizeConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            var symbol = baseSymbol.withSymbolConfiguration(sizeConfig) ?? baseSymbol

            // Force a theme-colored SF Symbol so it never falls back to macOS accent blue.
            // (Some AppKit button/toolbar styles ignore `contentTintColor` unless the image is a plain template.)
            if let colored = symbol.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [theme.textColor])) {
                symbol = colored
                symbol.isTemplate = false
            } else {
                symbol.isTemplate = true
            }

            let btn = registerControl(NSButton(image: symbol, target: self, action: #selector(imageTapped)))
            btn.identifier = NSUserInterfaceItemIdentifier("qp.insertImage")
            btn.bezelStyle = .texturedRounded
            btn.setButtonType(.momentaryPushIn)
            btn.imagePosition = .imageOnly
            btn.title = ""
            // Keep tint set as well (helps if the symbol config falls back to template rendering).
            btn.contentTintColor = theme.textColor
            btn.toolTip = "Insert Image"
            btn.setAccessibilityLabel("Insert Image")
            imageButton = btn
        } else {
            imageButton = createToolbarButton("▭", fontSize: 18)
            imageButton.target = self
            imageButton.action = #selector(imageTapped)
            imageButton.toolTip = "Insert Image"
            imageButton.setAccessibilityLabel("Insert Image")
        }

        // Layout
        let columnsBtn = createToolbarButton("⫼", fontSize: 20) // Column icon
        let tableBtn = createToolbarButton("⊞", fontSize: 20) // Table icon

        columnsBtn.target = self
        columnsBtn.action = #selector(columnsTapped)
        columnsBtn.toolTip = "Columns"
        columnsBtn.setAccessibilityLabel("Columns")
        tableBtn.target = self
        tableBtn.action = #selector(tableTapped)
        tableBtn.toolTip = "Table Operations"
        tableBtn.setAccessibilityLabel("Table Operations")

        // Search & Replace
        let searchBtn = createToolbarButton("🔍", fontSize: 16)
        searchBtn.target = self
        searchBtn.action = #selector(searchTapped)
        searchBtn.toolTip = "Find & Replace"
        searchBtn.setAccessibilityLabel("Find & Replace")

        // Paragraph marks toggle
        let paragraphBtn = createToolbarButton("¶", fontSize: 16)
        paragraphBtn.setButtonType(.toggle)
        paragraphBtn.target = self
        paragraphBtn.action = #selector(paragraphMarksTapped)
        paragraphBtn.toolTip = "Show / Hide paragraph marks"
        paragraphBtn.setAccessibilityLabel("Show / Hide paragraph marks")
        paragraphMarksButton = paragraphBtn

        // Indentation
        let outdentBtn = registerControl(NSButton(title: "⇤", target: self, action: #selector(outdentTapped)))
        outdentBtn.bezelStyle = .texturedRounded
        outdentBtn.toolTip = "Decrease Indent"
        outdentBtn.setAccessibilityLabel("Decrease Indent")
        let indentBtn = registerControl(NSButton(title: "⇥", target: self, action: #selector(indentTapped)))
        indentBtn.bezelStyle = .texturedRounded
        indentBtn.toolTip = "Increase Indent"
        indentBtn.setAccessibilityLabel("Increase Indent")

        // Sidebar toggle button
        let sidebarBtn = createToolbarButton("◨", fontSize: 18)
        sidebarBtn.target = self
        sidebarBtn.action = #selector(sidebarToggleTapped)
        sidebarBtn.toolTip = "Toggle Sidebars"
        sidebarBtn.setAccessibilityLabel("Toggle Sidebars")

        // Outline panel toggle moved into the Outline header (left panel).
        // Keep the toolbar free of an extra outline icon.
        outlinePanelButton = nil

        // File / Clipboard actions
        let undoBtn = createSymbolToolbarButton(systemName: "arrow.uturn.backward", accessibility: "Undo")
        undoBtn.target = self
        undoBtn.action = #selector(undoTapped)
        undoBtn.toolTip = "Undo"

        let redoBtn = createSymbolToolbarButton(systemName: "arrow.uturn.forward", accessibility: "Redo")
        redoBtn.target = self
        redoBtn.action = #selector(redoTapped)
        redoBtn.toolTip = "Redo"

        let newBtn = createSymbolToolbarButton(systemName: "doc.badge.plus", accessibility: "New Document")
        newBtn.target = self
        newBtn.action = #selector(newDocumentTapped)
        newBtn.toolTip = "New Document"

        let openBtn = createSymbolToolbarButton(systemName: "folder", accessibility: "Open Document")
        openBtn.target = self
        openBtn.action = #selector(openDocumentTapped)
        openBtn.toolTip = "Open…"

        let saveAsBtn = createSymbolToolbarButton(systemName: "square.and.arrow.down", accessibility: "Save As")
        saveAsBtn.target = self
        saveAsBtn.action = #selector(saveAsTapped)
        saveAsBtn.toolTip = "Save As…"

        let printBtn = createSymbolToolbarButton(systemName: "printer", accessibility: "Print")
        printBtn.target = self
        printBtn.action = #selector(printTapped)
        printBtn.toolTip = "Print…"

        let cutBtn = createSymbolToolbarButton(systemName: "scissors", accessibility: "Cut")
        cutBtn.target = self
        cutBtn.action = #selector(cutTapped)
        cutBtn.toolTip = "Cut"

        let copyBtn = createSymbolToolbarButton(systemName: "doc.on.doc", accessibility: "Copy")
        copyBtn.target = self
        copyBtn.action = #selector(copyTapped)
        copyBtn.toolTip = "Copy"

        let pasteBtn = createSymbolToolbarButton(systemName: "doc.on.clipboard", accessibility: "Paste")
        pasteBtn.target = self
        pasteBtn.action = #selector(pasteTapped)
        pasteBtn.toolTip = "Paste"

        let hyperlinkBtn = createSymbolToolbarButton(systemName: "link.badge.plus", accessibility: "Insert Hyperlink")
        hyperlinkBtn.target = self
        hyperlinkBtn.action = #selector(insertHyperlinkTapped)
        hyperlinkBtn.toolTip = "Insert Hyperlink…"

        // Add all to stack view (all aligned left)
        let toolbarStack = NSStackView(views: [
            undoBtn, redoBtn, newBtn, openBtn, saveAsBtn, printBtn, cutBtn, copyBtn, pasteBtn,
            stylePopup, formatPainterBtn, decreaseSizeBtn, sizePopup, increaseSizeBtn,
            boldBtn, italicBtn, underlineBtn, strikethroughBtn, superscriptBtn, subscriptBtn,
            alignLeftBtn, alignCenterBtn, alignRightBtn, justifyBtn,
            bulletsBtn, numberingBtn,
            imageButton,
            columnsBtn, tableBtn,
            outdentBtn, indentBtn,
            searchBtn, paragraphBtn, sidebarBtn
        ])
        toolbarStack.orientation = .horizontal
        toolbarStack.spacing = 6
        toolbarStack.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        toolbarStack.translatesAutoresizingMaskIntoConstraints = false

        // Wrap toolbar in a scroll view for narrow windows
        let toolbarScrollView = NSScrollView()
        toolbarScrollView.translatesAutoresizingMaskIntoConstraints = false
        toolbarScrollView.hasHorizontalScroller = true
        toolbarScrollView.hasVerticalScroller = false
        toolbarScrollView.autohidesScrollers = true
        toolbarScrollView.borderType = .noBorder
        toolbarScrollView.drawsBackground = false
        toolbarScrollView.horizontalScrollElasticity = .allowed
        toolbarScrollView.documentView = toolbarStack
        addSubview(toolbarScrollView)

        NSLayoutConstraint.activate([
            toolbarScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbarScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbarScrollView.topAnchor.constraint(equalTo: topAnchor),
            toolbarScrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            toolbarStack.topAnchor.constraint(equalTo: toolbarScrollView.topAnchor),
            toolbarStack.bottomAnchor.constraint(equalTo: toolbarScrollView.bottomAnchor)
        ])
    }

    private func createToolbarButton(_ title: String, weight: NSFont.Weight = .regular, isItalic: Bool = false, isUnderlined: Bool = false, isStrikethrough: Bool = false, fontSize: CGFloat = 14) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .texturedRounded
        button.setButtonType(.momentaryPushIn)

        var font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        if isItalic {
            font = NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(.italic), size: fontSize) ?? font
        }
        button.font = font

        // Apply strikethrough to button title if requested
        if isStrikethrough {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ]
            button.attributedTitle = NSAttributedString(string: title, attributes: attrs)
        }

        return registerControl(button)
    }

    private func createSymbolToolbarButton(systemName: String, accessibility: String) -> NSButton {
        let theme = ThemeManager.shared.currentTheme
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)

        var symbol = (NSImage(systemSymbolName: systemName, accessibilityDescription: accessibility) ?? NSImage())
        symbol = symbol.withSymbolConfiguration(config) ?? symbol

        // Prefer an explicitly colored symbol so it never falls back to macOS accent (blue).
        if let colored = symbol.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [theme.textColor])) {
            symbol = colored
            symbol.isTemplate = false
        } else {
            symbol.isTemplate = true
        }

        let button = NSButton(image: symbol, target: nil, action: nil)
        button.bezelStyle = .texturedRounded
        button.setButtonType(.momentaryPushIn)
        button.imagePosition = .imageOnly
        button.title = ""
        // Still set tint (helps if the symbol config falls back to template rendering on some OS/GPU combos).
        button.contentTintColor = theme.textColor
        // Stash the symbol name so applyTheme can regenerate it when themes change.
        button.identifier = NSUserInterfaceItemIdentifier("qp.symbol.\(systemName)")
        button.setAccessibilityLabel(accessibility)
        return registerControl(button)
    }

    @discardableResult
    private func registerControl<T: NSControl>(_ control: T) -> T {
        themedControls.append(control)
        return control
    }

    func applyTheme(_ theme: AppTheme) {
        wantsLayer = true
        layer?.backgroundColor = theme.toolbarBackground.cgColor

        // Set the view's appearance to match the theme - this is critical for popup menus
        let isDarkMode = ThemeManager.shared.isDarkMode
        self.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Apply theme to all controls
        themedControls.forEach { control in
            // Set appearance on each control as well
            control.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

            // Check for NSPopUpButton FIRST because it's a subclass of NSButton
            if let popup = control as? NSPopUpButton {
                // Set appearance on the popup's menu too
                popup.menu?.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
                popup.contentTintColor = theme.textColor

                // Apply theme to all menu items first
                for item in popup.itemArray {
                    if item.isEnabled {
                        // Regular menu items
                        let attributes: [NSAttributedString.Key: Any] = [
                            .foregroundColor: theme.textColor,
                            .font: popup.font ?? NSFont.systemFont(ofSize: 13)
                        ]
                        item.attributedTitle = NSAttributedString(string: item.title, attributes: attributes)
                    } else {
                        // Disabled header items
                        let attributes: [NSAttributedString.Key: Any] = [
                            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                            .foregroundColor: theme.textColor.withAlphaComponent(0.6)
                        ]
                        item.attributedTitle = NSAttributedString(string: item.title, attributes: attributes)
                    }
                }

                // Set the attributed title on the button itself for the displayed text
                if let selectedTitle = popup.titleOfSelectedItem, !selectedTitle.isEmpty {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .foregroundColor: theme.textColor,
                        .font: popup.font ?? NSFont.systemFont(ofSize: 13)
                    ]
                    let attributedString = NSAttributedString(string: selectedTitle, attributes: attrs)

                    // Set on cell first
                    if let cell = popup.cell as? NSPopUpButtonCell {
                        cell.attributedTitle = attributedString
                    }

                    // Then set on popup - DO NOT call synchronizeTitleAndSelectedItem after this!
                    popup.attributedTitle = attributedString
                } else {
                    // Set text color for the popup button directly for placeholder text
                    if let cell = popup.cell as? NSPopUpButtonCell {
                        let cellTitle = cell.title as String
                        let selectedIndex = popup.indexOfSelectedItem
                        let itemTitle = (selectedIndex >= 0 && selectedIndex < popup.numberOfItems) ? popup.itemTitle(at: selectedIndex) : ""
                        let currentTitle = !cellTitle.isEmpty ? cellTitle : itemTitle
                        cell.attributedTitle = NSAttributedString(
                            string: currentTitle,
                            attributes: [
                                .foregroundColor: theme.textColor,
                                .font: popup.font ?? NSFont.systemFont(ofSize: 13)
                            ]
                        )
                    }
                }

                // Force the popup to redraw
                if theme == .day {
                    popup.wantsLayer = true
                    popup.layer?.borderWidth = 1
                    popup.layer?.borderColor = theme.pageBorder.cgColor
                    popup.layer?.cornerRadius = 6
                } else {
                    popup.layer?.borderWidth = 0
                }
                popup.needsDisplay = true
            } else if let button = control as? NSButton {
                button.contentTintColor = theme.textColor
                if button.identifier?.rawValue == "qp.insertImage" {
                    // Insert Image must be forced to theme color (palette symbol) to avoid system accent blue.
                    if let base = NSImage(systemSymbolName: "photo", accessibilityDescription: "Insert Image") {
                        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                        var symbol = base.withSymbolConfiguration(sizeConfig) ?? base
                        if let colored = symbol.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [theme.textColor])) {
                            symbol = colored
                            symbol.isTemplate = false
                        } else {
                            symbol.isTemplate = true
                        }
                        button.image = symbol
                    }
                } else if let raw = button.identifier?.rawValue, raw.hasPrefix("qp.symbol.") {
                    let systemName = String(raw.dropFirst("qp.symbol.".count))
                    let sizeConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                    var symbol = (NSImage(systemSymbolName: systemName, accessibilityDescription: nil) ?? button.image ?? NSImage())
                    symbol = symbol.withSymbolConfiguration(sizeConfig) ?? symbol
                    if let colored = symbol.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [theme.textColor])) {
                        symbol = colored
                        symbol.isTemplate = false
                    } else {
                        symbol.isTemplate = true
                    }
                    button.image = symbol
                } else {
                    // Ensure SF Symbols render as template images so `contentTintColor` applies (prevents system accent blue).
                    if button.image != nil {
                        button.image?.isTemplate = true
                    }
                }

                // Day theme: apply orange border to all toolbar buttons (icons + text buttons).
                button.wantsLayer = true
                button.layer?.masksToBounds = true
                if theme == .day {
                    button.layer?.borderWidth = 1
                    button.layer?.borderColor = theme.pageBorder.cgColor
                    button.layer?.cornerRadius = 6
                } else {
                    button.layer?.borderWidth = 0
                }

                let currentFontSize = button.font?.pointSize ?? 14
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: theme.textColor,
                    .font: button.font ?? NSFont.systemFont(ofSize: currentFontSize)
                ]
                button.attributedTitle = NSAttributedString(string: button.title, attributes: attributes)
            }
        }

        // Force an additional redraw pass for popups with a slight delay
        // This helps on laptops with different GPU/display configurations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.themedControls.compactMap { $0 as? NSPopUpButton }.forEach { popup in
                if let cell = popup.cell as? NSPopUpButtonCell,
                   let selectedTitle = popup.titleOfSelectedItem, !selectedTitle.isEmpty {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .foregroundColor: theme.textColor,
                        .font: popup.font ?? NSFont.systemFont(ofSize: 13)
                    ]
                    cell.attributedTitle = NSAttributedString(string: selectedTitle, attributes: attrs)
                    popup.attributedTitle = NSAttributedString(string: selectedTitle, attributes: attrs)
                    popup.setNeedsDisplay(popup.bounds)
                }
            }
        }
    }

    @objc private func indentTapped() {
        delegate?.formattingToolbarDidIndent(self)
    }

    @objc private func outdentTapped() {
        delegate?.formattingToolbarDidOutdent(self)
    }

    @objc private func styleChanged(_ sender: NSPopUpButton) {
        let selectedTitle = sender.titleOfSelectedItem ?? ""

        var appliedStyle = selectedTitle
        let persistedUIStyle = selectedTitle
        let displayStyle = selectedTitle

        if StyleCatalog.shared.isPoetryTemplate {
            // Poetry: keep "Verse" as the user-facing default, but apply canonical stanza tagging internally.
            if selectedTitle == "Verse" {
                appliedStyle = "Stanza"
            }
        }

        delegate?.formattingToolbar(self, didSelectStyle: appliedStyle)
        UserDefaults.standard.set(persistedUIStyle, forKey: "LastSelectedStyle")

        // Update the displayed title with theme color
        let theme = ThemeManager.shared.currentTheme
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.textColor,
            .font: sender.font ?? NSFont.systemFont(ofSize: 13)
        ]
        sender.attributedTitle = NSAttributedString(string: displayStyle, attributes: attrs)
        sender.synchronizeTitleAndSelectedItem()
    }

    @objc private func paragraphMarksTapped() {
        delegate?.formattingToolbarDidToggleParagraphMarks(self)
    }

    @objc private func newDocumentTapped() {
        delegate?.formattingToolbarDidNewDocument(self)
    }

    @objc private func openDocumentTapped() {
        delegate?.formattingToolbarDidOpenDocument(self)
    }

    @objc private func saveAsTapped() {
        delegate?.formattingToolbarDidSaveAs(self)
    }

    @objc private func printTapped() {
        delegate?.formattingToolbarDidPrint(self)
    }

    @objc private func cutTapped() {
        delegate?.formattingToolbarDidCut(self)
    }

    @objc private func copyTapped() {
        delegate?.formattingToolbarDidCopy(self)
    }

    @objc private func pasteTapped() {
        delegate?.formattingToolbarDidPaste(self)
    }

    @objc private func undoTapped() {
        delegate?.formattingToolbarDidUndo(self)
    }

    @objc private func redoTapped() {
        delegate?.formattingToolbarDidRedo(self)
    }

    @objc private func insertHyperlinkTapped() {
        delegate?.formattingToolbarDidInsertHyperlink(self)
    }

    @objc private func superscriptTapped() {
        delegate?.formattingToolbarDidToggleSuperscript(self)
    }

    @objc private func subscriptTapped() {
        delegate?.formattingToolbarDidToggleSubscript(self)
    }

    func updateParagraphMarksState(_ isShown: Bool) {
        paragraphMarksButton?.state = isShown ? .on : .off
    }

    // Combined style and template menu builder
    private func buildCombinedStyleMenu() {
        let stylesMenu = NSMenu()
        let currentTheme = ThemeManager.shared.currentTheme
        let isDarkMode = ThemeManager.shared.isDarkMode
        stylesMenu.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Helper to add section headers
        func addHeader(_ title: String) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: currentTheme.textColor.withAlphaComponent(0.6)
            ]
            item.attributedTitle = NSAttributedString(string: "  \(title.uppercased())", attributes: attributes)
            stylesMenu.addItem(item)
        }

        // Helper to add style items
        func addStyle(_ title: String) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            if let styleDefinition = StyleCatalog.shared.style(named: title) {
                let fontName = styleDefinition.fontName
                let fontSize: CGFloat = min(styleDefinition.fontSize, 13)
                let font = NSFont.quillPilotResolve(nameOrFamily: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: currentTheme.textColor
                ]
                item.attributedTitle = NSAttributedString(string: title, attributes: attributes)
            }
            stylesMenu.addItem(item)
        }

        // === TEMPLATE SECTION (accordion submenu) ===
        let templateSubmenu = NSMenu()
        templateSubmenu.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
        for template in StyleCatalog.shared.availableTemplates() {
            let templateItem = NSMenuItem(title: template, action: #selector(templateMenuItemSelected(_:)), keyEquivalent: "")
            templateItem.target = self
            // Mark current template with checkmark
            if template == StyleCatalog.shared.currentTemplateName {
                templateItem.state = .on
            }
            templateSubmenu.addItem(templateItem)
        }

        let templateMenuItem = NSMenuItem(title: "Template: \(StyleCatalog.shared.currentTemplateName)", action: nil, keyEquivalent: "")
        let templateAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: currentTheme.textColor
        ]
        templateMenuItem.attributedTitle = NSAttributedString(string: "  📚 \(StyleCatalog.shared.currentTemplateName.uppercased()) ▸", attributes: templateAttrs)
        templateMenuItem.submenu = templateSubmenu
        stylesMenu.addItem(templateMenuItem)
        stylesMenu.addItem(.separator())

        // === STYLES SECTION ===
        let allStyles = StyleCatalog.shared.getAllStyles()
        let sortedStyleNames = allStyles.keys.sorted()

        if StyleCatalog.shared.isPoetryTemplate {
            func addOrdered(_ names: [String]) {
                for name in names {
                    if name == "— divider —" {
                        if stylesMenu.items.last?.isSeparatorItem != true {
                            stylesMenu.addItem(.separator())
                        }
                        continue
                    }
                    guard allStyles[name] != nil else { continue }
                    addStyle(name)
                }
            }

            addOrdered([
                "Poem Title", "Title", "Poet Name", "Author", "Dedication", "Epigraph",
                "Argument Title", "Argument",
                "— divider —",
                "Poem", "Stanza", "Verse", "Refrain", "Chorus", "Voice", "Speaker",
                "— divider —",
                "Prose Poem", "Verse Paragraph",
                "— divider —",
                "Section / Sequence Title", "Part Number", "Section Break",
                "— divider —",
                "Notes", "Marginal Note", "Footnote", "Revision Variant"
            ])
        } else {
            // Group styles by category
            var titleStyles: [String] = []
            var headingStyles: [String] = []
            var bodyStyles: [String] = []
            var specialStyles: [String] = []
            var screenplayStyles: [String] = []

            for styleName in sortedStyleNames {
                if styleName.contains("Screenplay") {
                    screenplayStyles.append(styleName)
                } else if styleName.contains("Title") || styleName.contains("Author") || styleName.contains("Subtitle") {
                    titleStyles.append(styleName)
                } else if styleName.contains("Heading") || styleName.contains("Chapter") || styleName.contains("Part") {
                    headingStyles.append(styleName)
                } else if styleName.contains("Body") || styleName == "Dialogue" {
                    bodyStyles.append(styleName)
                } else {
                    specialStyles.append(styleName)
                }
            }

            if !titleStyles.isEmpty {
                addHeader("Titles")
                titleStyles.forEach(addStyle)
                stylesMenu.addItem(.separator())
            }

            if !headingStyles.isEmpty {
                addHeader("Headings")
                headingStyles.forEach(addStyle)
                stylesMenu.addItem(.separator())
            }

            if !bodyStyles.isEmpty {
                addHeader("Body")
                bodyStyles.forEach(addStyle)
                stylesMenu.addItem(.separator())
            }

            if !specialStyles.isEmpty {
                addHeader("Special")
                specialStyles.forEach(addStyle)
                stylesMenu.addItem(.separator())
            }

            if !screenplayStyles.isEmpty {
                addHeader("Screenplay")
                screenplayStyles.forEach(addStyle)
                stylesMenu.addItem(.separator())
            }
        }

        stylePopup.menu = stylesMenu

        // Restore last selected style
        var lastStyle = UserDefaults.standard.string(forKey: "LastSelectedStyle") ?? (StyleCatalog.shared.isPoetryTemplate ? "Poem" : "Body Text")
        if StyleCatalog.shared.isPoetryTemplate {
            if lastStyle == "Stanza" || lastStyle == "Poetry — Stanza" || lastStyle == "Poetry — Verse" { lastStyle = "Verse" }
        }
        if stylePopup.itemTitles.contains(lastStyle) {
            stylePopup.selectItem(withTitle: lastStyle)
        } else if StyleCatalog.shared.isPoetryTemplate && stylePopup.itemTitles.contains("Poem") {
            stylePopup.selectItem(withTitle: "Poem")
        } else if stylePopup.itemTitles.contains("Body Text") {
            stylePopup.selectItem(withTitle: "Body Text")
        }
    }

    @objc private func templateMenuItemSelected(_ sender: NSMenuItem) {
        let templateName = sender.title
        currentTemplate = templateName
        StyleCatalog.shared.setCurrentTemplate(templateName)
        buildCombinedStyleMenu()  // Rebuild menu with new template's styles

        // Update displayed selection with theme color
        let theme = ThemeManager.shared.currentTheme
        if let selectedTitle = stylePopup.titleOfSelectedItem {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: theme.textColor,
                .font: stylePopup.font ?? NSFont.systemFont(ofSize: 13)
            ]
            stylePopup.attributedTitle = NSAttributedString(string: selectedTitle, attributes: attrs)
        }
    }

    private func rebuildStylesMenu() {
        // Now just calls the combined builder
        buildCombinedStyleMenu()
    }

    @objc private func boldTapped() {
        delegate?.formattingToolbarDidToggleBold(self)
    }

    @objc private func italicTapped() {
        delegate?.formattingToolbarDidToggleItalic(self)
    }

    @objc private func underlineTapped() {
        delegate?.formattingToolbarDidToggleUnderline(self)
    }

    @objc private func strikethroughTapped() {
        delegate?.formattingToolbarDidToggleStrikethrough(self)
    }

    @objc private func openStyleEditorTapped() {
        delegate?.formattingToolbarDidOpenStyleEditor(self)
    }

    @objc private func alignLeftTapped() {
        delegate?.formattingToolbarDidAlignLeft(self)
    }

    @objc private func alignCenterTapped() {
        delegate?.formattingToolbarDidAlignCenter(self)
    }

    @objc private func alignRightTapped() {
        delegate?.formattingToolbarDidAlignRight(self)
    }

    @objc private func justifyTapped() {
        delegate?.formattingToolbarDidAlignJustify(self)
    }

    @objc private func bulletsTapped() {
        delegate?.formattingToolbarDidToggleBullets(self)
    }

    @objc private func numberingTapped() {
        delegate?.formattingToolbarDidToggleNumbering(self)
    }

    @objc private func imageTapped() {
        delegate?.formattingToolbarDidInsertImage(self)
    }

    @objc private func formatPainterTapped() {
        delegate?.formattingToolbarDidFormatPainter(self)
    }

    @objc private func columnsTapped() {
        delegate?.formattingToolbarDidColumns(self)
    }

    @objc private func columnBreakTapped() {
        delegate?.formattingToolbarDidInsertColumnBreak(self)
    }

    @objc private func deleteColumnTapped() {
        delegate?.formattingToolbarDidDeleteColumn(self)
    }

    @objc private func tableTapped() {
        delegate?.formattingToolbarDidInsertTable(self)
    }

    @objc private func sidebarToggleTapped() {
        // Post notification to toggle sidebars
        DebugLog.log("[DEBUG] sidebarToggleTapped - posting ToggleSidebars notification")
        NotificationCenter.default.post(name: NSNotification.Name("ToggleSidebars"), object: nil)
    }

    @objc private func searchTapped() {
        // Post notification to show search panel
        NotificationCenter.default.post(name: NSNotification.Name("ShowSearchPanel"), object: nil)
    }

    @objc private func outlinePanelToggleTapped() {
        delegate?.formattingToolbarDidToggleOutlinePanel(self)
    }

    deinit {
        if let templateObserver {
            NotificationCenter.default.removeObserver(templateObserver)
        }
    }

    /// Switch the active template and update toolbar UI.
    /// Useful for imports where the file format implies a specific template (e.g. `.fadein` → Screenplay).
    func selectTemplateProgrammatically(_ templateName: String) {
        guard StyleCatalog.shared.availableTemplates().contains(templateName) else { return }
        currentTemplate = templateName
        StyleCatalog.shared.setCurrentTemplate(templateName)
        buildCombinedStyleMenu()  // Rebuild menu with new template's styles

        // Update displayed selection with theme color
        let theme = ThemeManager.shared.currentTheme
        if let selectedTitle = stylePopup.titleOfSelectedItem {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: theme.textColor,
                .font: stylePopup.font ?? NSFont.systemFont(ofSize: 13)
            ]
            stylePopup.attributedTitle = NSAttributedString(string: selectedTitle, attributes: attrs)
        }
    }

    @objc private func fontSizeChanged(_ sender: NSPopUpButton) {
        guard let title = sender.titleOfSelectedItem, let size = Double(title) else { return }
        delegate?.formattingToolbar(self, didChangeFontSize: CGFloat(size))

        // Update the displayed title with theme color
        let theme = ThemeManager.shared.currentTheme
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.textColor,
            .font: sender.font ?? NSFont.systemFont(ofSize: 13)
        ]
        sender.attributedTitle = NSAttributedString(string: title, attributes: attrs)
        sender.synchronizeTitleAndSelectedItem()
    }

    @objc private func decreaseFontSizeTapped() {
        let currentIndex = sizePopup.indexOfSelectedItem
        guard currentIndex > 0 else { return }
        sizePopup.selectItem(at: currentIndex - 1)
        reapplyPopupTheme(sizePopup)
        fontSizeChanged(sizePopup)
    }

    @objc private func increaseFontSizeTapped() {
        let currentIndex = sizePopup.indexOfSelectedItem
        guard currentIndex >= 0, currentIndex + 1 < sizePopup.numberOfItems else { return }
        sizePopup.selectItem(at: currentIndex + 1)
        reapplyPopupTheme(sizePopup)
        fontSizeChanged(sizePopup)
    }

    func updateSelectedStyle(_ styleName: String?) {
        guard let styleName = styleName else {
            // If no style found, pick a sensible default per template.
            if StyleCatalog.shared.isPoetryTemplate,
               let verseIndex = (0..<stylePopup.numberOfItems).first(where: { stylePopup.item(at: $0)?.title == "Verse" }) {
                stylePopup.selectItem(at: verseIndex)
                reapplyPopupTheme(stylePopup)
                return
            }
            // Fallback: select the first item (typically "Normal")
            stylePopup.selectItem(at: 0)
            reapplyPopupTheme(stylePopup)
            return
        }

        // Poetry: normalize internal stanza/legacy tags to the visible picker label.
        let displayStyle: String
        if StyleCatalog.shared.isPoetryTemplate {
            if styleName == "Poem" || styleName == "Stanza" || styleName == "Poetry — Stanza" || styleName == "Poetry — Verse" {
                displayStyle = "Verse"
            } else {
                displayStyle = styleName
            }
        } else {
            displayStyle = styleName
        }

        // Try to find and select the matching style in the popup
        if let index = (0..<stylePopup.numberOfItems).first(where: { stylePopup.item(at: $0)?.title == displayStyle }) {
            stylePopup.selectItem(at: index)
            reapplyPopupTheme(stylePopup)
        }
    }

    /// Reapply theme styling to a popup button after selection changes
    /// (NSPopUpButton resets its displayed title to plain text when selectItem is called)
    private func reapplyPopupTheme(_ popup: NSPopUpButton) {
        let theme = ThemeManager.shared.currentTheme

        guard let cell = popup.cell as? NSPopUpButtonCell else { return }

        // Get the title that should be displayed
        let displayTitle: String
        if let selectedTitle = popup.titleOfSelectedItem, !selectedTitle.isEmpty {
            displayTitle = selectedTitle
        } else {
            displayTitle = cell.title as String
        }

        guard !displayTitle.isEmpty else { return }

        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.textColor,
            .font: popup.font ?? NSFont.systemFont(ofSize: 13)
        ]

        let attributedString = NSAttributedString(string: displayTitle, attributes: attrs)

        // NUCLEAR OPTION: Set attributed title on cell first, BEFORE syncing
        cell.attributedTitle = attributedString

        // DO NOT call synchronizeTitleAndSelectedItem() - it resets attributedTitle!
        // Instead, manually ensure the popup shows the attributed string
        popup.attributedTitle = attributedString

        // Try to access the internal title text field directly (undocumented but works)
        if let contentView = popup.superview {
            for subview in contentView.subviews where subview === popup {
                popup.subviews.compactMap { $0 as? NSTextField }.forEach { textField in
                    textField.attributedStringValue = attributedString
                }
            }
        }

        // Aggressive multi-level redraw
        cell.controlView?.setNeedsDisplay(cell.controlView?.bounds ?? .zero)
        popup.setNeedsDisplay(popup.bounds)
        popup.window?.displayIfNeeded()  // Force immediate window update

        // Multiple delayed redraws at different intervals for different hardware
        for delay in [0.01, 0.05, 0.1] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak popup, weak cell] in
                if let popup = popup, let cell = cell {
                    cell.attributedTitle = attributedString
                    popup.attributedTitle = attributedString
                    popup.setNeedsDisplay(popup.bounds)
                }
            }
        }
    }
}

// MARK: - Ruler View

// MARK: - Content View Controller (3-column layout)
class ContentViewController: NSViewController {
    var onTitleChange: ((String) -> Void)?
    var onAuthorChange: ((String) -> Void)?
    var onStatsUpdate: ((String) -> Void)?
    var onSelectionChange: ((String?) -> Void)?
    var onTextChange: (() -> Void)?
    var onNotesTapped: (() -> Void)?

    private var outlineViewController: OutlineViewController!
    private var outlinePanelController: AnalysisViewController!
    var editorViewController: EditorViewController!
    private var analysisViewController: AnalysisViewController!
    private var backToTopButton: NSButton!
    private var outlineRevealButton: NSButton!

    private var splitView: NSSplitView!
    private var outlineMinWidthConstraint: NSLayoutConstraint?
    private var outlineMaxWidthConstraint: NSLayoutConstraint?
    private var analysisMinWidthConstraint: NSLayoutConstraint?
    private var analysisMaxWidthConstraint: NSLayoutConstraint?
    private var equalSidebarWidthsConstraint: NSLayoutConstraint?
    private var isOutlinePanelHidden = false
    private var cachedOutlineWidth: CGFloat = 280

    private var isAnalysisPanelHidden = false
    private var cachedAnalysisWidth: CGFloat = 320

    // Analysis throttling during layout
    private var analysisSuspended = false
    private var analysisPending = false

    var editorLeadingAnchor: NSLayoutXAxisAnchor? {
        editorViewController?.view.leadingAnchor
    }

    var editorTrailingAnchor: NSLayoutXAxisAnchor? {
        editorViewController?.view.trailingAnchor
    }
    var editorCenterXAnchor: NSLayoutXAxisAnchor? {
        editorViewController?.view.centerXAnchor
    }

    override func loadView() {
        view = NSView()
    }

    @objc func toggleSidebar(_ sender: Any?) {
        // Route View ▸ Toggle Sidebar through our app-wide behavior so it toggles both sidebars.
        NotificationCenter.default.post(name: Notification.Name("ToggleSidebars"), object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        NotificationCenter.default.addObserver(forName: Notification.Name("QuillPilotOutlineRefresh"), object: nil, queue: .main) { [weak self] _ in
            self?.refreshOutline()
        }

        // Listen for sidebar toggle notification
        DebugLog.log("[DEBUG] ContentViewController.viewDidLoad - adding observer for ToggleSidebars")
        NotificationCenter.default.addObserver(forName: Notification.Name("ToggleSidebars"), object: nil, queue: .main) { [weak self] _ in
            DebugLog.log("[DEBUG] ContentViewController received ToggleSidebars notification")
            self?.toggleAllSidebarsPanels()
        }

        refreshOutline()
    }

    private func setupLayout() {
        // Create 3-column split view
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        self.splitView = splitView
        view.addSubview(splitView)

        // When the outline panel is hidden, the header toggle disappears with it.
        // Provide a persistent reveal control so the outline can always be restored.
        let revealImage: NSImage
        if #available(macOS 11.0, *) {
            let base = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "Toggle Outline") ?? NSImage()
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            revealImage = base.withSymbolConfiguration(config) ?? base
        } else {
            revealImage = NSImage(size: NSSize(width: 18, height: 18))
            revealImage.lockFocus()
            NSString(string: "✎").draw(at: NSPoint(x: 2, y: 1), withAttributes: [.font: NSFont.systemFont(ofSize: 14)])
            revealImage.unlockFocus()
        }

        outlineRevealButton = NSButton(image: revealImage, target: self, action: #selector(outlineRevealTapped(_:)))
        outlineRevealButton.bezelStyle = .inline
        outlineRevealButton.isBordered = false
        outlineRevealButton.imagePosition = .imageOnly
        outlineRevealButton.toolTip = "Show Outline"
        outlineRevealButton.translatesAutoresizingMaskIntoConstraints = false
        outlineRevealButton.isHidden = true
        view.addSubview(outlineRevealButton)

        // Left: Mirrored analysis shell showing the outline (📝)
        outlineViewController = OutlineViewController()
        outlineViewController.onSelect = { [weak self] entry in
            self?.scrollToOutlineEntry(entry)
        }
        outlineViewController.onToggleOutlinePanel = { [weak self] in
            self?.outlineViewController.toggleOutlineContents()
        }
        outlinePanelController = AnalysisViewController()
        outlinePanelController.isOutlinePanel = true
        outlinePanelController.outlineViewController = outlineViewController
        outlinePanelController.onNotesTapped = { [weak self] in
            self?.onNotesTapped?()
        }
        splitView.addArrangedSubview(outlinePanelController.view)
        outlineMinWidthConstraint = outlinePanelController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: 240)
        outlineMaxWidthConstraint = outlinePanelController.view.widthAnchor.constraint(lessThanOrEqualToConstant: 360)
        outlineMinWidthConstraint?.isActive = true
        outlineMaxWidthConstraint?.isActive = true

        // Center: Editor
        editorViewController = EditorViewController()
        editorViewController.delegate = self
        splitView.addArrangedSubview(editorViewController.view)
        editorViewController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: 450).isActive = true
        splitView.setHoldingPriority(.defaultLow - 1, forSubviewAt: 1)

        // Right: Analysis panel
        analysisViewController = AnalysisViewController()
        analysisViewController.getManuscriptInfoCallback = { [weak self] in
            guard let editor = self?.editorViewController else { return nil }

            func clean(_ value: String) -> String {
                value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            }

            func isPlaceholder(_ value: String) -> Bool {
                let normalized = value
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    .lowercased()
                    .replacingOccurrences(of: "’", with: "'")
                    .replacingOccurrences(of: "\u{2019}", with: "'")
                if normalized.isEmpty { return true }

                // Common placeholder variants.
                let placeholders: Set<String> = [
                    "untitled",
                    "poem title",
                    "title",
                    "author name",
                    "author's name",
                    "authors name",
                    "author"
                ]
                return placeholders.contains(normalized)
            }

            let title = clean(editor.manuscriptTitle)
            let author = clean(editor.manuscriptAuthor)
            return (
                title: isPlaceholder(title) ? "" : title,
                author: isPlaceholder(author) ? "" : author
            )
        }
        splitView.addArrangedSubview(analysisViewController.view)
        analysisMinWidthConstraint = analysisViewController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: 250)
        analysisMaxWidthConstraint = analysisViewController.view.widthAnchor.constraint(lessThanOrEqualToConstant: 400)
        analysisMinWidthConstraint?.isActive = true
        analysisMaxWidthConstraint?.isActive = true

        // Set up analysis callback
        analysisViewController.analyzeCallback = { [weak self] in
            DebugLog.log("🔗 Analysis callback triggered")
            guard QuillPilotSettings.autoAnalyzeOnOpen else { return }
            self?.performAnalysis()
        }

        // Encourage symmetric sidebars so the editor column (and page) stays centered in the window.
        let equalSidebarWidths = outlinePanelController.view.widthAnchor.constraint(equalTo: analysisViewController.view.widthAnchor)
        equalSidebarWidths.priority = .defaultHigh
        equalSidebarWidths.isActive = true
        equalSidebarWidthsConstraint = equalSidebarWidths
        backToTopButton = NSButton(title: "↑ Top", target: self, action: #selector(scrollToTop))
        backToTopButton.bezelStyle = .rounded
        backToTopButton.translatesAutoresizingMaskIntoConstraints = false
        backToTopButton.isHidden = true
        view.addSubview(backToTopButton)

        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            outlineRevealButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            outlineRevealButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),

            backToTopButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            backToTopButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }

    private func toggleAllSidebarsPanels() {
        guard let splitView else { return }
        guard splitView.subviews.count >= 3 else { return }

        // If either sidebar is visible, hide both. Otherwise, show both.
        let anyVisible = !outlinePanelController.view.isHidden || !analysisViewController.view.isHidden
        let shouldHide = anyVisible

        if shouldHide {
            cachedOutlineWidth = splitView.subviews[0].frame.width
            cachedAnalysisWidth = splitView.subviews[2].frame.width

            equalSidebarWidthsConstraint?.isActive = false
            outlineMinWidthConstraint?.isActive = false
            outlineMaxWidthConstraint?.isActive = false
            analysisMinWidthConstraint?.isActive = false
            analysisMaxWidthConstraint?.isActive = false

            outlinePanelController.view.isHidden = true
            analysisViewController.view.isHidden = true
            outlineRevealButton?.isHidden = true

            isOutlinePanelHidden = true
            isAnalysisPanelHidden = true

            splitView.setPosition(0, ofDividerAt: 0)
            splitView.setPosition(splitView.bounds.width, ofDividerAt: 1)
        } else {
            outlinePanelController.view.isHidden = false
            analysisViewController.view.isHidden = false

            outlineMinWidthConstraint?.isActive = true
            outlineMaxWidthConstraint?.isActive = true
            analysisMinWidthConstraint?.isActive = true
            analysisMaxWidthConstraint?.isActive = true
            equalSidebarWidthsConstraint?.isActive = true

            let restoredOutline = max(240, min(cachedOutlineWidth, 360))
            let restoredAnalysis = max(250, min(cachedAnalysisWidth, 400))

            isOutlinePanelHidden = false
            isAnalysisPanelHidden = false

            splitView.setPosition(restoredOutline, ofDividerAt: 0)
            splitView.setPosition(max(restoredOutline + 450, splitView.bounds.width - restoredAnalysis), ofDividerAt: 1)
        }

        splitView.needsLayout = true
        splitView.layoutSubtreeIfNeeded()
    }

    @objc private func outlineRevealTapped(_ sender: Any?) {
        // Reuse the same behavior as the header toggle.
        toggleOutlinePanel()
    }

    func toggleOutlinePanel() {
        guard let splitView else { return }
        guard splitView.subviews.count >= 3 else { return }

        isOutlinePanelHidden.toggle()

        if isOutlinePanelHidden {
            cachedOutlineWidth = splitView.subviews[0].frame.width
            equalSidebarWidthsConstraint?.isActive = false
            outlineMinWidthConstraint?.isActive = false
            outlineMaxWidthConstraint?.isActive = false
            outlinePanelController.view.isHidden = true
            splitView.setPosition(0, ofDividerAt: 0)
            outlineRevealButton?.isHidden = false
        } else {
            outlinePanelController.view.isHidden = false
            outlineMinWidthConstraint?.isActive = true
            outlineMaxWidthConstraint?.isActive = true
            equalSidebarWidthsConstraint?.isActive = true
            let restored = max(240, min(cachedOutlineWidth, 360))
            splitView.setPosition(restored, ofDividerAt: 0)
            outlineRevealButton?.isHidden = true
        }

        splitView.needsLayout = true
        splitView.layoutSubtreeIfNeeded()
    }

    private func refreshOutline() {
        let entries = editorViewController.buildOutlineEntries()
        outlineViewController.update(with: entries)
    }

    @objc private func scrollToTop() {
        // Scroll editor to top
        editorViewController.scrollToTop()
    }

    private func scrollToOutlineEntry(_ entry: EditorViewController.OutlineEntry) {
        editorViewController.scrollToOutlineEntry(entry)
    }

    func applyTheme(_ theme: AppTheme) {
        outlineViewController?.applyTheme(theme)
        editorViewController?.applyTheme(theme)
        analysisViewController?.applyTheme(theme)
        view.wantsLayer = true
        view.layer?.backgroundColor = theme.pageAround.cgColor

        // Day theme: apply orange border to the persistent outline reveal icon.
        outlineRevealButton?.wantsLayer = true
        outlineRevealButton?.layer?.masksToBounds = true
        outlineRevealButton?.image?.isTemplate = true
        if #available(macOS 10.14, *) {
            outlineRevealButton?.contentTintColor = theme.textColor
        }
        if theme == .day {
            outlineRevealButton?.layer?.borderWidth = 1
            outlineRevealButton?.layer?.borderColor = theme.pageBorder.cgColor
            outlineRevealButton?.layer?.cornerRadius = 8
        } else {
            outlineRevealButton?.layer?.borderWidth = 0
        }
    }

    /// Notify both sidebars that the document has changed
    func documentDidChange(url: URL?) {
        outlinePanelController?.documentDidChange(url: url)
        analysisViewController?.documentDidChange(url: url)

        // Reset manuscript metadata that can otherwise leak across documents.
        editorViewController?.manuscriptTitle = "Untitled"
        editorViewController?.manuscriptAuthor = "Author Name"
        onAuthorChange?("")
    }

    /// Notify sidebars that the document now has a concrete URL (Save / Save As).
    /// Must not clear analysis results/UI.
    func documentURLDidUpdate(url: URL?) {
        outlinePanelController?.documentURLDidUpdate(url: url)
        analysisViewController?.documentURLDidUpdate(url: url)
    }

    func setRuler(_ ruler: EnhancedRulerView) {
        // Industry-standard manuscript defaults: 1" margins and 0.5" first-line indent.
        ruler.leftMargin = 72
        ruler.rightMargin = 72
        ruler.firstLineIndent = 36
        applyRulerToEditor(ruler)
    }

    func indent() {
        editorViewController.indent()
    }

    func outdent() {
        editorViewController.outdent()
    }

    func toggleBold() {
        editorViewController.toggleBold()
    }

    func toggleItalic() {
        editorViewController.toggleItalic()
    }

    func toggleUnderline() {
        editorViewController.toggleUnderline()
    }

    func toggleStrikethrough() {
        editorViewController.toggleStrikethrough()
    }

    func setFontFamily(_ family: String) {
        editorViewController.setFontFamily(family)
    }

    func setFontSize(_ size: CGFloat) {
        editorViewController.setFontSize(size)
    }

    func setAlignment(_ alignment: NSTextAlignment) {
        editorViewController.setAlignment(alignment)
    }

    func applyStyle(_ styleName: String) {
        editorViewController.applyStyle(named: styleName)
    }

    func toggleBulletedList() {
        editorViewController.toggleBulletedList()
    }

    func toggleNumberedList() {
        editorViewController.toggleNumberedList()
    }

    func insertImage() {
        editorViewController.insertImageFromDisk()
    }

    func editorPlainText() -> String {
        editorViewController.plainTextContent()
    }

    func editorPDFData() -> Data {
        editorViewController.pdfData()
    }

    func editorAttributedContent() -> NSAttributedString {
        editorViewController.attributedContent()
    }

    func editorRTFData() throws -> Data {
        try editorViewController.rtfData()
    }

    func editorRTFDData() throws -> Data {
        try editorViewController.rtfdData()
    }

    func editorHasAttachments() -> Bool {
        editorViewController.hasAttachments()
    }

    func editorShunnManuscriptRTFData(documentTitle: String) throws -> Data {
        try editorViewController.shunnManuscriptRTFData(documentTitle: documentTitle)
    }

    func editorExportReadyAttributedContent() -> NSAttributedString {
        editorViewController.exportReadyAttributedContent()
    }

    func setEditorAttributedContent(_ attributed: NSAttributedString) {
        editorViewController.setAttributedContent(attributed)
    }

    func setEditorPlainText(_ text: String) {
        editorViewController.setPlainTextContent(text)
    }

    func clearAnalysis() {
        analysisViewController?.latestAnalysisResults = nil
        analysisViewController?.clearAllAnalysisUI()
    }
    private func applyRulerToEditor(_ ruler: EnhancedRulerView) {
        editorViewController.setPageMargins(left: ruler.leftMargin, right: ruler.rightMargin)
        editorViewController.setFirstLineIndent(ruler.firstLineIndent)
    }

    private var pendingRulerLeftMargin: CGFloat?
    private var pendingRulerRightMargin: CGFloat?
    private var pendingRulerFirstLineIndent: CGFloat?

    @objc private func applyRulerToEditorDeferred() {
        let left = pendingRulerLeftMargin ?? 72
        let right = pendingRulerRightMargin ?? 72
        let indent = pendingRulerFirstLineIndent ?? 36
        editorViewController.setPageMargins(left: left, right: right)
        editorViewController.setFirstLineIndent(indent)
    }

    private func scheduleApplyRulerToEditor(_ ruler: EnhancedRulerView) {
        pendingRulerLeftMargin = ruler.leftMargin
        pendingRulerRightMargin = ruler.rightMargin
        pendingRulerFirstLineIndent = ruler.firstLineIndent

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(applyRulerToEditorDeferred), object: nil)
        perform(#selector(applyRulerToEditorDeferred), with: nil, afterDelay: 0.03)
    }

    private var isAnalyzing = false

    func performAnalysis() {
        DebugLog.log("🔍 performAnalysis called in ContentViewController")

        // Skip if already analyzing to prevent queue buildup
        guard !isAnalyzing else {
            DebugLog.log("⏸️ Analysis already in progress, skipping")
            return
        }

        guard let text = editorViewController.getTextContent(), !text.isEmpty else {
            DebugLog.log("⚠️ No text to analyze")
            return
        }

        // Also verify document storage has content (prevents analyzing during/before import)
        guard editorViewController.textView.textStorage?.length ?? 0 > 0 else {
            DebugLog.log("⚠️ Document storage is empty, skipping analysis")
            return
        }

        isAnalyzing = true
        DebugLog.log("📊 MainWindowController: Starting background analysis thread")

        // Build outline entries on MAIN THREAD before background work
        // (textStorage and layoutManager must be accessed on main thread only)
        let editorOutlines = editorViewController.buildOutlineEntries()
        DebugLog.log("📋 MainWindowController: Built \(editorOutlines.count) outline entries on main thread")
        if !editorOutlines.isEmpty {
            editorOutlines.prefix(3).forEach { entry in
                DebugLog.log("  - '\(entry.title)' level=\(entry.level) range=\(NSStringFromRange(entry.range))")
            }
        }

        // Determine character names on MAIN THREAD.
        // Prefer the per-document CharacterLibrary; for Screenplay, fall back to extracting character cues.
        // Use canonical analysis keys so AnalysisEngine's CharacterLibrary validation doesn't drop everyone
        // (analysis keys are typically the first token of the character's full name).
        let libraryCharacterNames = CharacterLibrary.shared.analysisCharacterKeys

        let isScreenplay = StyleCatalog.shared.currentTemplateName == "Screenplay"
        let extractedScreenplayNames = isScreenplay ? editorViewController.extractScreenplayCharacterCues() : []

        let characterNamesForAnalysis: [String]
        if !libraryCharacterNames.isEmpty {
            characterNamesForAnalysis = libraryCharacterNames
        } else if !extractedScreenplayNames.isEmpty {
            characterNamesForAnalysis = extractedScreenplayNames
        } else {
            characterNamesForAnalysis = []
        }

        // Page mapping no longer needed - page numbers removed from Decision-Belief Loop display
        let pageMapping: [(location: Int, page: Int)] = []

        // Run analysis on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            DebugLog.log("📊 MainWindowController: Inside background thread")
            let analysisEngine = AnalysisEngine()

            // Convert outline entries for AnalysisEngine. Always pass an array (empty means no outline yet).
            let analysisOutlineEntries: [DecisionBeliefLoopAnalyzer.OutlineEntry] = editorOutlines.map {
                DecisionBeliefLoopAnalyzer.OutlineEntry(title: $0.title, level: $0.level, range: $0.range, page: $0.page)
            }

            DebugLog.log("📋 MainWindowController: Passing \(analysisOutlineEntries.count) outline entries to analyzeText")

            var results = analysisEngine.analyzeText(text, outlineEntries: analysisOutlineEntries, pageMapping: pageMapping)

            if !characterNamesForAnalysis.isEmpty {
                DebugLog.log("📋 MainWindowController: Analyzing characters: \(characterNamesForAnalysis.count)")
                let (loops, interactions, presence) = analysisEngine.analyzeCharacterArcs(
                    text: text,
                    characterNames: characterNamesForAnalysis,
                    outlineEntries: analysisOutlineEntries,
                    pageMapping: pageMapping
                )
                results.decisionBeliefLoops = loops
                results.characterInteractions = interactions
                results.characterPresence = presence

                // Populate additional character-centric outputs used by popouts.
                results.beliefShiftMatrices = analysisEngine.generateBeliefShiftMatrices(
                    text: text,
                    characterNames: characterNamesForAnalysis,
                    outlineEntries: analysisOutlineEntries
                )
                results.decisionConsequenceChains = analysisEngine.generateDecisionConsequenceChains(
                    text: text,
                    characterNames: characterNamesForAnalysis,
                    outlineEntries: analysisOutlineEntries
                )
            }

            DebugLog.log("📊 Analysis results: \(results.wordCount) words, \(results.sentenceCount) sentences, \(results.paragraphCount) paragraphs")

            // Update UI on main thread
            DispatchQueue.main.async {
                self?.analysisViewController.displayResults(results)
                self?.isAnalyzing = false
            }
        }
    }
}

extension ContentViewController: RulerViewDelegate {
    func rulerView(_ ruler: EnhancedRulerView, didChangeLeftMargin: CGFloat) {
        scheduleApplyRulerToEditor(ruler)
    }

    func rulerView(_ ruler: EnhancedRulerView, didChangeRightMargin: CGFloat) {
        scheduleApplyRulerToEditor(ruler)
    }

    func rulerView(_ ruler: EnhancedRulerView, didChangeFirstLineIndent: CGFloat) {
        scheduleApplyRulerToEditor(ruler)
    }
}

// MARK: - Outline View Controller
class OutlineViewController: NSViewController {
    private final class ThemedOutlineRowView: NSTableRowView {
        var themeProvider: (() -> AppTheme)?

        override func drawSelection(in dirtyRect: NSRect) {
            guard isSelected, let theme = themeProvider?() else { return }

            let selectionColor: NSColor
            if ThemeManager.shared.isDarkMode {
                selectionColor = theme.pageBorder.withAlphaComponent(0.22)
            } else {
                // Cream selection (avoid macOS accent blue)
                selectionColor = theme.pageBackground
            }

            selectionColor.setFill()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 6, yRadius: 6)
            path.fill()
        }
    }

    final class Node: NSObject {
        let entry: EditorViewController.OutlineEntry
        var children: [Node]

        var title: String { entry.title }
        var level: Int { entry.level }
        var page: Int? { entry.page }
        var range: NSRange { entry.range }

        init(entry: EditorViewController.OutlineEntry, children: [Node] = []) {
            self.entry = entry
            self.children = children
        }
    }

    var onSelect: ((EditorViewController.OutlineEntry) -> Void)?
    var onToggleOutlinePanel: (() -> Void)?
    private var roots: [Node] = []
    private var isUpdating = false  // Prevent scroll during programmatic updates

    private var headerLabel: NSTextField!
    private var outlineView: NSOutlineView!
    private var outlineScrollView: NSScrollView!
    private var helpButton: NSButton!
    private var stanzaHelpPopover: NSPopover?
    private var templateObserver: NSObjectProtocol?

    private var isOutlineContentsHidden = false

    private var currentTheme: AppTheme = ThemeManager.shared.currentTheme

    private func titleColor(forLevel level: Int) -> NSColor {
        // Theme-aware (no green/blue coding). Use subtle alpha changes for hierarchy.
        let base = currentTheme.textColor
        switch level {
        case 0: return base.withAlphaComponent(0.95)
        case 1: return base.withAlphaComponent(0.90)
        case 2: return base.withAlphaComponent(0.75)
        default: return base.withAlphaComponent(0.60)
        }
    }

    private func pageColor() -> NSColor {
        currentTheme.textColor.withAlphaComponent(0.45)
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true

        headerLabel = NSTextField(labelWithString: "Document Outline")
        headerLabel.font = NSFont.boldSystemFont(ofSize: 14)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.isSelectable = false
        headerLabel.isEditable = false
        headerLabel.isBezeled = false
        headerLabel.drawsBackground = false
        headerLabel.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(toggleOutlineFromHeader(_:))))
        view.addSubview(headerLabel)

        let toggleImage: NSImage
        if #available(macOS 11.0, *) {
            let base = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "Toggle Outline") ?? NSImage()
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            toggleImage = base.withSymbolConfiguration(config) ?? base
        } else {
            toggleImage = NSImage(size: NSSize(width: 18, height: 18))
            toggleImage.lockFocus()
            NSString(string: "✎").draw(at: NSPoint(x: 2, y: 1), withAttributes: [.font: NSFont.systemFont(ofSize: 14)])
            toggleImage.unlockFocus()
        }

        helpButton = NSButton(image: toggleImage, target: self, action: #selector(toggleOutlineFromHeader(_:)))
        helpButton.bezelStyle = .inline
        helpButton.isBordered = false
        helpButton.imagePosition = .imageOnly
        helpButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(helpButton)

        // Poetry template hides the "Document Outline" heading.
        applyTemplateVisibility()
        templateObserver = NotificationCenter.default.addObserver(
            forName: .styleTemplateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTemplateVisibility()
        }

        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.rowSizeStyle = .small
        outlineView.allowsEmptySelection = true
        outlineView.allowsMultipleSelection = false
        outlineView.selectionHighlightStyle = .none
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.target = self
        outlineView.action = #selector(outlineRowClicked(_:))
        outlineView.doubleAction = #selector(outlineRowDoubleClicked(_:))

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("OutlineColumn"))
        column.title = ""
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.verticalScroller?.isHidden = true
        scrollView.horizontalScroller?.isHidden = true
        scrollView.documentView = outlineView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        outlineScrollView = scrollView
        view.addSubview(outlineScrollView)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            headerLabel.trailingAnchor.constraint(lessThanOrEqualTo: helpButton.leadingAnchor, constant: -8),

            helpButton.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            helpButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            outlineScrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            outlineScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            outlineScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            outlineScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])

        applyTheme(ThemeManager.shared.currentTheme)
        updateHeaderToggleTooltip()
    }

    deinit {
        if let observer = templateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func applyTemplateVisibility() {
        headerLabel?.isHidden = false

        if StyleCatalog.shared.isPoetryTemplate {
            headerLabel?.stringValue = "Stanza Outline"
            helpButton?.isHidden = false
        } else {
            headerLabel?.stringValue = "Document Outline"
            // Prose templates use the outline panel's vertical toggle button; hide this redundant header toggle.
            helpButton?.isHidden = true
        }

        updateHeaderToggleTooltip()
    }

    @objc private func toggleOutlineFromHeader(_ sender: Any?) {
        // In prose templates, the outline toggle lives in the vertical icon strip.
        guard StyleCatalog.shared.isPoetryTemplate else { return }
        onToggleOutlinePanel?()
    }

    func toggleOutlineContents() {
        isOutlineContentsHidden.toggle()
        outlineScrollView?.isHidden = isOutlineContentsHidden
        headerLabel?.isHidden = isOutlineContentsHidden
        updateHeaderToggleTooltip()
    }

    private func updateHeaderToggleTooltip() {
        let name = StyleCatalog.shared.isPoetryTemplate ? "Stanza Outline" : "Document Outline"
        let tip = isOutlineContentsHidden ? "Show \(name)" : "Hide \(name)"
        helpButton?.toolTip = tip
        headerLabel?.toolTip = tip
    }

    func update(with entries: [EditorViewController.OutlineEntry]) {
        isUpdating = true
        outlineView.deselectAll(nil)  // Clear selection before reload to prevent scrolling
        roots = buildTree(from: entries)
        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: true)
        // Some OS behaviors can re-select row 0 after reload if empty selection isn't allowed.
        // Keep the outline unselected until the user explicitly clicks.
        outlineView.deselectAll(nil)
        isUpdating = false
    }

    @objc private func outlineRowClicked(_ sender: Any?) {
        // Only navigate for genuine mouse interaction; avoid programmatic/restore selection side-effects.
        if let event = NSApp.currentEvent {
            switch event.type {
            case .leftMouseDown, .leftMouseUp:
                break
            default:
                return
            }
        }
        let targetRow = outlineView.clickedRow
        guard targetRow >= 0, let node = outlineView.item(atRow: targetRow) as? Node else { return }
        onSelect?(node.entry)
    }

    @objc private func outlineRowDoubleClicked(_ sender: Any?) {
        let targetRow = outlineView.clickedRow
        guard targetRow >= 0, let node = outlineView.item(atRow: targetRow) as? Node else { return }
        onSelect?(node.entry)
    }

    private func buildTree(from entries: [EditorViewController.OutlineEntry]) -> [Node] {
        var stack: [Node] = []
        var roots: [Node] = []

        for entry in entries {
            let node = Node(entry: entry)

            while let last = stack.last, last.level >= node.level {
                stack.removeLast()
            }

            if let parent = stack.last {
                parent.children.append(node)
            } else {
                roots.append(node)
            }

            stack.append(node)
        }

        return roots
    }

    func applyTheme(_ theme: AppTheme) {
        currentTheme = theme
        view.wantsLayer = true
        view.layer?.backgroundColor = theme.outlineBackground.cgColor
        headerLabel.textColor = theme.textColor
        outlineView.backgroundColor = theme.outlineBackground

        // Day theme: apply orange border to the header outline toggle icon (visible in Poetry).
        helpButton?.wantsLayer = true
        helpButton?.layer?.masksToBounds = true
        helpButton?.image?.isTemplate = true
        if #available(macOS 10.14, *) {
            helpButton?.contentTintColor = theme.textColor
        }
        if theme == .day {
            helpButton?.layer?.borderWidth = 1
            helpButton?.layer?.borderColor = theme.pageBorder.cgColor
            helpButton?.layer?.cornerRadius = 8
        } else {
            helpButton?.layer?.borderWidth = 0
        }

        // Reload data to apply new colors
        outlineView.reloadData()

        // Force refresh of all visible cells to ensure colors update immediately
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let visibleRows = self.outlineView.rows(in: self.outlineView.visibleRect)
            for row in visibleRows.location..<(visibleRows.location + visibleRows.length) {
                if let view = self.outlineView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView,
                   let titleField = view.textField,
                   let node = self.outlineView.item(atRow: row) as? Node {
                    titleField.textColor = self.titleColor(forLevel: node.level)
                    if let stack = view.subviews.first(where: { $0 is NSStackView }) as? NSStackView,
                       let pageField = stack.arrangedSubviews.last as? NSTextField {
                        pageField.textColor = self.pageColor()
                    }
                }
            }
        }
    }
}

extension OutlineViewController: NSOutlineViewDataSource, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        let row = ThemedOutlineRowView()
        row.themeProvider = { [weak self] in self?.currentTheme ?? ThemeManager.shared.currentTheme }
        return row
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? Node { return node.children.count }
        return roots.count
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? Node else { return false }
        return !node.children.isEmpty
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? Node { return node.children[index] }
        return roots[index]
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? Node else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("OutlineCell")
        let cell: NSTableCellView
        if let existing = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = existing
        } else {
            let titleField = NSTextField(labelWithString: "")
            titleField.lineBreakMode = .byTruncatingTail

            let pageField = NSTextField(labelWithString: "")
            pageField.font = NSFont.systemFont(ofSize: 10)
            pageField.textColor = pageColor()

            let stack = NSStackView(views: [titleField, NSView(), pageField])
            stack.orientation = .horizontal
            stack.alignment = .centerY
            stack.spacing = 6
            stack.translatesAutoresizingMaskIntoConstraints = false

            cell = NSTableCellView()
            cell.identifier = identifier
            cell.addSubview(stack)
            cell.textField = titleField

            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                stack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                stack.topAnchor.constraint(equalTo: cell.topAnchor, constant: 2),
                stack.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -2)
            ])

            stack.setHuggingPriority(.defaultLow, for: .horizontal)
            pageField.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        let titleField = cell.textField!
        let pageField = (cell.subviews.first { $0 is NSStackView } as? NSStackView)?.arrangedSubviews.last as? NSTextField

        let color = titleColor(forLevel: node.level)
        let fontSize: CGFloat = node.level == 0 ? 13 : (node.level == 1 ? 12 : 11)
        titleField.font = NSFont.systemFont(ofSize: fontSize, weight: node.level <= 1 ? .semibold : .regular)
        titleField.textColor = color
        titleField.stringValue = node.title

        if let page = node.page {
            pageField?.stringValue = "p. \(page)"
            pageField?.textColor = pageColor()
        } else {
            pageField?.stringValue = ""
        }

        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        // Navigation is handled by click/double-click actions to avoid duplicate calls.
        // This delegate is intentionally empty to prevent scroll conflicts.
    }
}

// MARK: - Export Formats
enum ExportFormat: String, CaseIterable {
    case docx = "docx"       // Full support (save + open)
    case rtf = "rtf"         // Export only
    case rtfd = "rtfd"       // Export + open
    case odt = "odt"         // Export only (LibreOffice)
    case txt = "txt"         // Export + open
    case markdown = "md"     // Export + open
    case html = "html"       // Export + open
    case pdf = "pdf"         // Export only
    case epub = "epub"       // Export only
    case mobi = "mobi"       // Export only (Kindle)

    var displayName: String {
        switch self {
        case .docx: return "Word Document (.docx)"
        case .rtf: return "Rich Text (.rtf)"
        case .rtfd: return "Rich Text with Attachments (.rtfd)"
        case .odt: return "OpenDocument Text (.odt)"
        case .txt: return "Plain Text (.txt)"
        case .markdown: return "Markdown (.md)"
        case .html: return "Web Page (.html)"
        case .pdf: return "PDF Document (.pdf)"
        case .epub: return "ePub (.epub)"
        case .mobi: return "Kindle (.mobi)"
        }
    }

    var fileExtension: String { rawValue }

    var contentTypes: [UTType] {
        switch self {
        case .docx:
            // Use official DOCX identifier, with data as fallback
            if let docxType = UTType("org.openxmlformats.wordprocessingml.document") {
                return [docxType]
            }
            if let docxType = UTType(filenameExtension: "docx", conformingTo: .data) {
                return [docxType]
            }
            return [.data]
        case .rtf:
            return [.rtf]
        case .rtfd:
            return [.rtfd]
        case .odt:
            if let odtType = UTType("org.oasis-open.opendocument.text") {
                return [odtType]
            }
            if let odtType = UTType(filenameExtension: "odt", conformingTo: .data) {
                return [odtType]
            }
            return [.data]
        case .txt:
            return [.plainText]
        case .markdown:
            if let mdType = UTType("net.daringfireball.markdown") {
                return [mdType]
            }
            if let mdType = UTType(filenameExtension: "md", conformingTo: .text) {
                return [mdType]
            }
            return [.text]
        case .html:
            return [.html]
        case .pdf:
            return [.pdf]
        case .epub:
            if let epubType = UTType(filenameExtension: "epub", conformingTo: .data) {
                return [epubType]
            }
            return [.data]
        case .mobi:
            if let mobiType = UTType(filenameExtension: "mobi", conformingTo: .data) {
                return [mobiType]
            }
            return [.data]
        }
    }

    /// Whether this format can be opened (not just exported)
    var canOpen: Bool {
        switch self {
        case .docx, .odt, .rtf, .rtfd, .txt, .markdown, .html: return true
        case .pdf, .epub, .mobi: return false
        }
    }
}

// MARK: - DOCX Style Sheet Builder
private enum StyleSheetBuilder {
    static func makeStylesXml(using styleNames: [String]) -> String {
        let catalog = StyleCatalog.shared
        // Export must include hidden/legacy keys too so style IDs round-trip correctly.
        let names = styleNames.isEmpty
            ? catalog.allStyleKeys(for: catalog.currentTemplateName)
            : styleNames

        var styleNodes: [String] = []

        // Always add a "Normal" style definition as a fallback
        styleNodes.append("""
        <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
          <w:name w:val="Normal"/>
          <w:qFormat/>
        </w:style>
        """)

        // Add "Default Paragraph Font"
        styleNodes.append("""
        <w:style w:type="character" w:default="1" w:styleId="DefaultParagraphFont">
          <w:name w:val="Default Paragraph Font"/>
          <w:uiPriority w:val="1"/>
          <w:semiHidden/>
          <w:unhideWhenUsed/>
        </w:style>
        """)

        for name in names {
            let def = catalog.style(named: name)
                ?? catalog.templateName(containingStyleName: name).flatMap { catalog.style(named: name, inTemplate: $0) }
            guard let def else { continue }
            let styleId = name.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
            if styleId == "Normal" { continue } // Skip if user named a style Normal (unlikely but safe)

            let pPr = makeParagraphProps(from: def)
            let rPr = makeRunProps(from: def)

            styleNodes.append("""
            <w:style w:type="paragraph" w:customStyle="1" w:styleId="\(styleId)">
              <w:name w:val="\(name)"/>
              <w:basedOn w:val="Normal"/>
              <w:qFormat/>
              \(pPr)
              \(rPr)
            </w:style>
            """)
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:docDefaults>
            <w:rPrDefault>
              <w:rPr>
                <w:rFonts w:asciiTheme="minorHAnsi" w:eastAsiaTheme="minorEastAsia" w:hansiTheme="minorHAnsi" w:cstheme="minorBidi"/>
                <w:sz w:val="24"/>
                <w:szCs w:val="24"/>
                <w:lang w:val="en-US" w:eastAsia="en-US" w:bidi="ar-SA"/>
              </w:rPr>
            </w:rPrDefault>
            <w:pPrDefault/>
          </w:docDefaults>
          \(styleNodes.joined(separator: "\n"))
        </w:styles>
        """
    }

    private static func makeParagraphProps(from def: StyleDefinition) -> String {
        var components: [String] = []

        // Alignment
        let alignment: String
        if let align = NSTextAlignment(rawValue: def.alignmentRawValue) {
            switch align {
            case .center: alignment = "center"
            case .right: alignment = "right"
            case .justified: alignment = "both"
            default: alignment = "left"
            }
            components.append("<w:jc w:val=\"\(alignment)\"/>")
        }

        // Spacing
        let before = max(0, Int(round(def.spacingBefore * 20)))
        let after = max(0, Int(round(def.spacingAfter * 20)))
        var spacingAttrs: [String] = []
        if before > 0 { spacingAttrs.append("w:before=\"\(before)\"") }
        if after > 0 { spacingAttrs.append("w:after=\"\(after)\"") }
        if def.lineHeightMultiple > 0 {
            let line = max(120, Int(round(def.lineHeightMultiple * 240)))
            spacingAttrs.append("w:line=\"\(line)\"")
            spacingAttrs.append("w:lineRule=\"auto\"")
        }
        if !spacingAttrs.isEmpty {
            components.append("<w:spacing \(spacingAttrs.joined(separator: " "))/>")
        }

        // Indentation
        let leftIndent = max(0, Int(round(def.headIndent * 20)))
        let indentDiff = Int(round((def.firstLineIndent) * 20)) // StyleDefinition stores relative firstLineIndent directly?
        // Wait, StyleDefinition.firstLineIndent is usually relative in my catalog?
        // Let's check StyleCatalog.baseDefinition: firstLine: CGFloat = 36.
        // And makeParagraphStyle: style.firstLineHeadIndent = headIndent + firstLineIndent.
        // So yes, def.firstLineIndent IS the difference.

        let rightIndent = def.tailIndent > 0 ? Int(round(def.tailIndent * 20)) : 0

        var indentAttrs: [String] = []
        if leftIndent > 0 {
            indentAttrs.append("w:left=\"\(leftIndent)\"")
        }
        if indentDiff > 0 {
            indentAttrs.append("w:firstLine=\"\(indentDiff)\"")
        } else if indentDiff < 0 {
            indentAttrs.append("w:hanging=\"\(abs(indentDiff))\"")
        }
        if rightIndent > 0 {
            indentAttrs.append("w:right=\"\(rightIndent)\"")
        }

        if !indentAttrs.isEmpty {
            components.append("<w:ind \(indentAttrs.joined(separator: " "))/>")
        }

        guard !components.isEmpty else { return "" }
        return "<w:pPr>\n\(components.joined(separator: "\n"))\n</w:pPr>"
    }

    private static func makeRunProps(from def: StyleDefinition) -> String {
        var components: [String] = []

        components.append("<w:rFonts w:ascii=\"\(def.fontName)\" w:hansi=\"\(def.fontName)\"/>")

        if def.isBold { components.append("<w:b/>") }
        if def.isItalic { components.append("<w:i/>") }

        let size = Int(round(def.fontSize * 2))
        components.append("<w:sz w:val=\"\(size)\"/>")

        // Add text color
        let hex = def.textColorHex.replacingOccurrences(of: "#", with: "")
        if !hex.isEmpty && hex.count == 6 {
            components.append("<w:color w:val=\"\(hex)\"/>")
        }

        return "<w:rPr>\n\(components.joined(separator: "\n"))\n</w:rPr>"
    }
}

// MARK: - DOCX builder (rich text with images)
private enum DocxBuilder {
    /// Collected image info during document generation
    private struct ImageInfo {
        let rId: String
        let filename: String
        let data: Data
        let ext: String
    }

    static func makeDocxData(from attributed: NSAttributedString) throws -> Data {
        // First pass: collect images and generate document XML
        var images: [ImageInfo] = []
        let documentXml = makeDocumentXml(from: attributed, images: &images)
        let usedStyleNames = collectStyleNames(from: attributed)
        let stylesXml = StyleSheetBuilder.makeStylesXml(using: usedStyleNames)

        // Build content types with image extensions
        var defaultTypes = """
          <Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>
          <Default Extension=\"xml\" ContentType=\"application/xml\"/>
        """
        let usedExtensions = Set(images.map { $0.ext })
        if usedExtensions.contains("png") {
            defaultTypes += "\n  <Default Extension=\"png\" ContentType=\"image/png\"/>"
        }
        if usedExtensions.contains("jpeg") || usedExtensions.contains("jpg") {
            defaultTypes += "\n  <Default Extension=\"jpeg\" ContentType=\"image/jpeg\"/>"
        }
        if usedExtensions.contains("gif") {
            defaultTypes += "\n  <Default Extension=\"gif\" ContentType=\"image/gif\"/>"
        }
        if usedExtensions.contains("tiff") || usedExtensions.contains("tif") {
            defaultTypes += "\n  <Default Extension=\"tiff\" ContentType=\"image/tiff\"/>"
        }

        let contentTypes = """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">
        \(defaultTypes)
          <Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>
          <Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/>
        </Types>
        """

        let rels = """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">
          <Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/>
        </Relationships>
        """

        // Build document relationships including image references
        var docRelItems: [String] = []
        docRelItems.append("""
          <Relationship Id=\"rIdStyles\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>
        """)

        for img in images {
            docRelItems.append("""
              <Relationship Id=\"\(img.rId)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/\(img.filename)\"/>
            """)
        }
        let docRels = """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">
        \(docRelItems.joined(separator: "\n"))
        </Relationships>
        """

        var entries: [(String, Data)] = [
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(rels.utf8)),
            ("word/document.xml", Data(documentXml.utf8)),
            ("word/styles.xml", Data(stylesXml.utf8)),
            ("word/_rels/document.xml.rels", Data(docRels.utf8))
        ]

        // Add image files
        for img in images {
            entries.append(("word/media/\(img.filename)", img.data))
        }

        return ZipWriter.makeZip(entries: entries)
    }

    private static func makeDocumentXml(from attributed: NSAttributedString, images: inout [ImageInfo]) -> String {
        let body = makeParagraphs(from: attributed, images: &images)
                // Letter size in twips (1 point = 20 twips). Matches editor defaults (8.5" x 11").
                let pageWidthTwips = 612 * 20
                let pageHeightTwips = 792 * 20
                // 1" margins (72pt) -> 1440 twips. Keep headers/footers inside margins.
                let marginTwips = 72 * 20
                let headerFooterTwips = 36 * 20
        return """
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"
                    xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\"
                    xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"
                    xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\"
                    xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">
          <w:body>
            \(body)
                        <w:sectPr>
                            <w:pgSz w:w=\"\(pageWidthTwips)\" w:h=\"\(pageHeightTwips)\"/>
                            <w:pgMar w:top=\"\(marginTwips)\" w:right=\"\(marginTwips)\" w:bottom=\"\(marginTwips)\" w:left=\"\(marginTwips)\" w:header=\"\(headerFooterTwips)\" w:footer=\"\(headerFooterTwips)\" w:gutter=\"0\"/>
                        </w:sectPr>
          </w:body>
        </w:document>
        """
    }

    private static func collectStyleNames(from attributed: NSAttributedString) -> [String] {
        let fullString = attributed.string as NSString
        var location = 0
        var names = Set<String>()

        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
            if let styleName = attributed.attribute(NSAttributedString.Key("QuillStyleName"), at: paragraphRange.location, effectiveRange: nil) as? String,
               !styleName.isEmpty {
                names.insert(styleName)
            }
            location = NSMaxRange(paragraphRange)
        }

        return names.sorted()
    }

    private static func makeParagraphs(from attributed: NSAttributedString, images: inout [ImageInfo]) -> String {
        let fullString = attributed.string as NSString
        var location = 0
        var paragraphs: [String] = []
        var currentTableRef: NSTextTable? = nil
        var currentTableRows: [[String]] = []
        var isCurrentTableColumnLayout = false

        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
            let contentRange = trimTrailingNewlines(in: paragraphRange, string: fullString)
            let paragraphStyle = attributed.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle
            let styleName = attributed.attribute(NSAttributedString.Key("QuillStyleName"), at: paragraphRange.location, effectiveRange: nil) as? String

            // Check if this paragraph is part of a table
            if let blocks = paragraphStyle?.textBlocks as? [NSTextTableBlock], let block = blocks.first {
                let table = block.table
                let row = block.startingRow
                let col = block.startingColumn

                                let runsSource: NSAttributedString
                                let runsRange: NSRange
                                if shouldStripLeaderDotsBeforeTab(styleName: styleName) {
                                        let mutable = NSMutableAttributedString(attributedString: attributed.attributedSubstring(from: contentRange))
                                        stripLeaderDotsBeforeFirstTab(in: mutable)
                                        runsSource = mutable
                                        runsRange = NSRange(location: 0, length: mutable.length)
                                } else {
                                        runsSource = attributed
                                        runsRange = contentRange
                                }

                                let runs = makeRuns(from: runsSource, in: runsRange, images: &images)
                let cellContent = """
                <w:p>
                  \(paragraphPropertiesXml(from: paragraphStyle, styleName: styleName))\(runs.joined())
                </w:p>
                """

                // Check if we're starting a new table or continuing the current one
                if let currentTable = currentTableRef, currentTable === table {
                    // Same table - add to existing rows
                    while currentTableRows.count <= row {
                        currentTableRows.append([])
                    }
                    while currentTableRows[row].count <= col {
                        currentTableRows[row].append("")
                    }
                    currentTableRows[row][col] = cellContent
                } else {
                    // New table - finish previous table if exists
                    if let prevTable = currentTableRef {
                        paragraphs.append(makeTableXml(rows: currentTableRows, columns: prevTable.numberOfColumns, isColumnLayout: isCurrentTableColumnLayout))
                    }
                    // Start new table - check if it's a column layout by checking starting row
                    currentTableRef = table
                    isCurrentTableColumnLayout = (row == 0)  // Column layouts all have row=0
                    currentTableRows = []
                    currentTableRows.append([])
                    while currentTableRows[0].count <= col {
                        currentTableRows[0].append("")
                    }
                    currentTableRows[0][col] = cellContent
                }
            } else {
                // Not in a table - finish any pending table
                if let prevTable = currentTableRef {
                    paragraphs.append(makeTableXml(rows: currentTableRows, columns: prevTable.numberOfColumns, isColumnLayout: isCurrentTableColumnLayout))
                    currentTableRef = nil
                    currentTableRows = []
                    isCurrentTableColumnLayout = false
                }

                // Regular paragraph
                let runsSource: NSAttributedString
                let runsRange: NSRange
                if shouldStripLeaderDotsBeforeTab(styleName: styleName) {
                    let mutable = NSMutableAttributedString(attributedString: attributed.attributedSubstring(from: contentRange))
                    stripLeaderDotsBeforeFirstTab(in: mutable)
                    runsSource = mutable
                    runsRange = NSRange(location: 0, length: mutable.length)
                } else {
                    runsSource = attributed
                    runsRange = contentRange
                }

                let runs = makeRuns(from: runsSource, in: runsRange, images: &images)
                let pPr = paragraphPropertiesXml(from: paragraphStyle, styleName: styleName)
                let paragraphXml = """
                <w:p>
                  \(pPr)\(runs.joined())
                </w:p>
                """
                paragraphs.append(paragraphXml)
            }

            location = NSMaxRange(paragraphRange)
        }

        // Finish any remaining table
        if let prevTable = currentTableRef {
            paragraphs.append(makeTableXml(rows: currentTableRows, columns: prevTable.numberOfColumns, isColumnLayout: isCurrentTableColumnLayout))
        }

        return paragraphs.joined(separator: "\n")
    }

    private static func shouldStripLeaderDotsBeforeTab(styleName: String?) -> Bool {
        guard let name = styleName?.lowercased() else { return false }
        // TOC/Index entries are built using manual dot leaders + a right tab.
        // In DOCX, it's more robust to rely on Word's tab leader dots.
        return name.contains("toc entry") || name.contains("index entry")
    }

    private static func stripLeaderDotsBeforeFirstTab(in attributed: NSMutableAttributedString) {
        let ns = attributed.string as NSString
        let tabRange = ns.range(of: "\t")
        guard tabRange.location != NSNotFound, tabRange.location > 0 else { return }

        // Remove a trailing leader region composed only of spaces + '.' before the first tab.
        // Heuristic: require multiple dots/spaces so we don't accidentally remove legitimate punctuation.
        var index = tabRange.location - 1
        var dotCount = 0
        var spaceCount = 0
        while index >= 0 {
            let c = ns.character(at: index)
            if c == 46 { // '.'
                dotCount += 1
            } else if c == 32 { // ' '
                spaceCount += 1
            } else {
                break
            }
            index -= 1
        }

        let leaderStart = index + 1
        let leaderLength = tabRange.location - leaderStart
        guard leaderLength > 0, dotCount >= 6, spaceCount >= 6 else { return }

        attributed.deleteCharacters(in: NSRange(location: leaderStart, length: leaderLength))
    }

    private static func makeTableXml(rows: [[String]], columns: Int, isColumnLayout: Bool) -> String {
        var rowsXml: [String] = []

        for row in rows {
            var cellsXml: [String] = []
            for col in 0..<columns {
                let content = col < row.count ? row[col] : "<w:p><w:pPr/></w:p>"
                cellsXml.append("""
                <w:tc>
                  <w:tcPr>
                    <w:tcW w:w="0" w:type="auto"/>
                  </w:tcPr>
                  \(content)
                </w:tc>
                """)
            }

            rowsXml.append("""
            <w:tr>
              \(cellsXml.joined(separator: "\n"))
            </w:tr>
            """)
        }

        let styleMarker = isColumnLayout ? "<w:tblStyle w:val=\"QuillPilotColumnLayout\"/>" : ""
        return """
        <w:tbl>
          <w:tblPr>
            \(styleMarker)
            <w:tblW w:w="0" w:type="auto"/>
            <w:tblBorders>
              <w:top w:val="none" w:sz="0" w:space="0" w:color="auto"/>
              <w:left w:val="none" w:sz="0" w:space="0" w:color="auto"/>
              <w:bottom w:val="none" w:sz="0" w:space="0" w:color="auto"/>
              <w:right w:val="none" w:sz="0" w:space="0" w:color="auto"/>
              <w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto"/>
              <w:insideV w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
            </w:tblBorders>
            <w:tblLayout w:type="autofit"/>
          </w:tblPr>
          <w:tblGrid>
        """ + (0..<columns).map { _ in "    <w:gridCol/>" }.joined(separator: "\n") + """

          </w:tblGrid>
          \(rowsXml.joined(separator: "\n"))
        </w:tbl>
        """
    }

    private static func makeRuns(from attributed: NSAttributedString, in range: NSRange, images: inout [ImageInfo]) -> [String] {
        let fullString = attributed.string as NSString
        var runs: [String] = []
        var hasImageAttachment = false

        if range.length == 0 {
            return ["<w:r><w:t/></w:r>"]
        }

        attributed.enumerateAttributes(in: range, options: []) { attrs, subRange, _ in
            // Check for image attachment
            if let attachment = attrs[.attachment] as? NSTextAttachment,
               let imageRunXml = imageRunXml(for: attachment, images: &images) {
                runs.append(imageRunXml)
                hasImageAttachment = true
            } else {
                let text = fullString.substring(with: subRange)
                // Skip the attachment placeholder character (U+FFFC)
                let filteredText = text.replacingOccurrences(of: "\u{FFFC}", with: "")
                if !filteredText.isEmpty {
                    let runXml = runXml(for: filteredText, attributes: attrs)
                    runs.append(runXml)
                }
            }
        }

        // Only add empty run if we have no content AND no image attachments
        if runs.isEmpty && !hasImageAttachment {
            runs.append("<w:r><w:t/></w:r>")
        }

        return runs
    }

    private static func imageRunXml(for attachment: NSTextAttachment, images: inout [ImageInfo]) -> String? {
        // Try to get image data from attachment
        guard let imageData = extractImageData(from: attachment) else { return nil }

        let imageIndex = images.count + 1
        let rId = "rId\(imageIndex + 100)" // Offset to avoid conflicts
        let ext = imageData.ext
        let filename = "image\(imageIndex).\(ext)"

        // Get image dimensions
        let (widthEmu, heightEmu) = imageDimensionsEmu(from: attachment, data: imageData.data)

        images.append(ImageInfo(rId: rId, filename: filename, data: imageData.data, ext: ext))

        // Generate drawing XML for inline image
        return """
        <w:r>
          <w:drawing>
            <wp:inline distT=\"0\" distB=\"0\" distL=\"0\" distR=\"0\">
              <wp:extent cx=\"\(widthEmu)\" cy=\"\(heightEmu)\"/>
              <wp:docPr id=\"\(imageIndex)\" name=\"Picture \(imageIndex)\"/>
              <a:graphic>
                <a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">
                  <pic:pic>
                    <pic:nvPicPr>
                      <pic:cNvPr id=\"\(imageIndex)\" name=\"image\(imageIndex).\(ext)\"/>
                      <pic:cNvPicPr/>
                    </pic:nvPicPr>
                    <pic:blipFill>
                      <a:blip r:embed=\"\(rId)\"/>
                      <a:stretch><a:fillRect/></a:stretch>
                    </pic:blipFill>
                    <pic:spPr>
                      <a:xfrm>
                        <a:off x=\"0\" y=\"0\"/>
                        <a:ext cx=\"\(widthEmu)\" cy=\"\(heightEmu)\"/>
                      </a:xfrm>
                      <a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>
                    </pic:spPr>
                  </pic:pic>
                </a:graphicData>
              </a:graphic>
            </wp:inline>
          </w:drawing>
        </w:r>
        """
    }

    private static func extractImageData(from attachment: NSTextAttachment) -> (data: Data, ext: String)? {
        // Try contents first (file wrapper data)
        if let data = attachment.contents {
            let ext = detectImageExtension(from: data)
            return (data, ext)
        }

        // Try fileWrapper
        if let wrapper = attachment.fileWrapper, let data = wrapper.regularFileContents {
            let ext = detectImageExtension(from: data)
            return (data, ext)
        }

        // Try to render the image from the attachment cell
        if let cell = attachment.attachmentCell as? NSCell, let image = cell.image {
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                return (pngData, "png")
            }
        }

        // Try image property directly
        if let image = attachment.image {
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                return (pngData, "png")
            }
        }

        return nil
    }

    private static func detectImageExtension(from data: Data) -> String {
        guard data.count >= 8 else { return "png" }
        let header = [UInt8](data.prefix(8))

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47 {
            return "png"
        }
        // JPEG: FF D8 FF
        if header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF {
            return "jpeg"
        }
        // GIF: GIF87a or GIF89a
        if header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46 {
            return "gif"
        }
        // TIFF: 49 49 2A 00 (little endian) or 4D 4D 00 2A (big endian)
        if (header[0] == 0x49 && header[1] == 0x49) || (header[0] == 0x4D && header[1] == 0x4D) {
            return "tiff"
        }

        return "png" // Default to PNG
    }

    private static func imageDimensionsEmu(from attachment: NSTextAttachment, data: Data) -> (Int, Int) {
        // EMU = English Metric Units, 914400 EMU = 1 inch, 72 points = 1 inch
        // So 1 point = 914400/72 = 12700 EMU

        var width: CGFloat = 200
        var height: CGFloat = 200

        // Try attachment bounds
        if attachment.bounds.width > 0 && attachment.bounds.height > 0 {
            width = attachment.bounds.width
            height = attachment.bounds.height
        } else if let image = attachment.image {
            width = image.size.width
            height = image.size.height
        } else if let wrapper = attachment.fileWrapper,
                  let imgData = wrapper.regularFileContents,
                  let image = NSImage(data: imgData) {
            width = image.size.width
            height = image.size.height
        } else if let image = NSImage(data: data) {
            width = image.size.width
            height = image.size.height
        }

        // Convert points to EMU (1 point = 12700 EMU)
        let widthEmu = Int(width * 12700)
        let heightEmu = Int(height * 12700)

        return (widthEmu, heightEmu)
    }

    private static func paragraphPropertiesXml(from style: NSParagraphStyle?, styleName: String? = nil) -> String {
        var components: [String] = []

        if let name = styleName {
            // Simple sanitization for style ID (remove spaces/parens)
            // e.g. "Heading 1" -> "Heading1", "Body Text" -> "BodyText"
            let styleId = name.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
            components.append("<w:pStyle w:val=\"\(styleId)\"/>")

            // Keep titles/letters with the following paragraph so headings don't get orphaned at page bottoms.
            let lower = name.lowercased()
            if lower.contains("toc title") || lower.contains("index title") || lower.contains("index letter") {
                components.append("<w:keepNext/>")
            }
        }

        if let style = style {
            let alignment: String
            switch style.alignment {
            case .center: alignment = "center"
            case .right: alignment = "right"
            case .justified: alignment = "both"
            default: alignment = "left"
            }
            components.append("<w:jc w:val=\"\(alignment)\"/>")

            let before = max(0, Int(round(style.paragraphSpacingBefore * 20)))
            let after = max(0, Int(round(style.paragraphSpacing * 20)))
            var spacingAttrs: [String] = []
            if before > 0 { spacingAttrs.append("w:before=\"\(before)\"") }
            if after > 0 { spacingAttrs.append("w:after=\"\(after)\"") }
            let lineMultiple = style.lineHeightMultiple
            if lineMultiple > 0 {
                let line = max(120, Int(round(lineMultiple * 240)))
                spacingAttrs.append("w:line=\"\(line)\"")
                spacingAttrs.append("w:lineRule=\"auto\"")
            }
            if !spacingAttrs.isEmpty {
                components.append("<w:spacing \(spacingAttrs.joined(separator: " "))/>")
            }

            let leftIndent = max(0, Int(round(style.headIndent * 20)))
            let indentDiff = Int(round((style.firstLineHeadIndent - style.headIndent) * 20))
            let rightIndent = style.tailIndent > 0 ? Int(round(style.tailIndent * 20)) : 0

            var indentAttrs: [String] = []
            if leftIndent > 0 {
                indentAttrs.append("w:left=\"\(leftIndent)\"")
                indentAttrs.append("w:start=\"\(leftIndent)\"")
            } else if indentDiff != 0 {
                indentAttrs.append("w:left=\"0\"")
                indentAttrs.append("w:start=\"0\"")
            }

            if indentDiff > 0 {
                indentAttrs.append("w:firstLine=\"\(indentDiff)\"")
            } else if indentDiff < 0 {
                indentAttrs.append("w:hanging=\"\(abs(indentDiff))\"")
            }

            if rightIndent > 0 {
                indentAttrs.append("w:right=\"\(rightIndent)\"")
                indentAttrs.append("w:end=\"\(rightIndent)\"")
            }
            if !indentAttrs.isEmpty {
                components.append("<w:ind \(indentAttrs.joined(separator: " "))/>")
            }

            // Export tab stops (used for right-aligned page columns in TOC/Index)
            if !style.tabStops.isEmpty {
                let useDotLeaders: Bool
                let forcePrintableRightTab: Bool
                if let name = styleName?.lowercased() {
                    useDotLeaders = name.contains("toc entry") || name.contains("index entry")
                    forcePrintableRightTab = useDotLeaders
                } else {
                    useDotLeaders = false
                    forcePrintableRightTab = false
                }

                var tabXml: [String] = []
                if forcePrintableRightTab {
                    // Clamp to printable width (Letter: 612pt - 1" margins each side), with a small right padding.
                    let printableWidth: CGFloat = 612 - (72 * 2)
                    let rightPadding: CGFloat = 10
                    let posTwips = Int(round((printableWidth - rightPadding) * 20))
                    tabXml.append("<w:tab w:val=\"right\" w:pos=\"\(posTwips)\" w:leader=\"dot\"/>")
                } else {
                    for tab in style.tabStops {
                        // Convert points to twentieths of a point (twips)
                        let posTwips = Int(round(tab.location * 20))
                        let tabType: String
                        switch tab.alignment {
                        case .right: tabType = "right"
                        case .center: tabType = "center"
                        default: tabType = "left"
                        }
                        // Add leader dots only for QuillPilot TOC/Index entry styles.
                        if useDotLeaders, tab.alignment == .right {
                            tabXml.append("<w:tab w:val=\"\(tabType)\" w:pos=\"\(posTwips)\" w:leader=\"dot\"/>")
                        } else {
                            tabXml.append("<w:tab w:val=\"\(tabType)\" w:pos=\"\(posTwips)\"/>")
                        }
                    }
                }
                if !tabXml.isEmpty {
                    components.append("<w:tabs>\(tabXml.joined())</w:tabs>")
                }
            }
        }

        guard !components.isEmpty else { return "" }
        return """
        <w:pPr>
          \(components.joined(separator: "\n  "))
        </w:pPr>
        """
    }

    private static func runXml(for text: String, attributes: [NSAttributedString.Key: Any]) -> String {
        let font = (attributes[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 12)
        let color = (attributes[.foregroundColor] as? NSColor) ?? .black
        let background = (attributes[.backgroundColor] as? NSColor)?.usingColorSpace(.sRGB)

        DebugLog.log("📝 Export run: fontName='\(font.fontName)', displayName='\(font.displayName ?? "nil")', size=\(font.pointSize)")

        var rPr: [String] = []
        let escapedFont = xmlEscape(font.fontName)
        rPr.append("<w:rFonts w:ascii=\"\(escapedFont)\" w:hAnsi=\"\(escapedFont)\" w:cs=\"\(escapedFont)\"/>")

        let halfPoints = Int(round(font.pointSize * 2))
        rPr.append("<w:sz w:val=\"\(halfPoints)\"/>")

        let traits = font.fontDescriptor.symbolicTraits
        if traits.contains(.bold) { rPr.append("<w:b/>") }
        if traits.contains(.italic) { rPr.append("<w:i/>") }

        rPr.append("<w:color w:val=\"\(hex(from: color))\"/>")

        if let background, background.alphaComponent > 0.01 {
            rPr.append("<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(hex(from: background))\"/>")
        }

        let rPrXml = rPr.isEmpty ? "" : """
        <w:rPr>
          \(rPr.joined(separator: "\n  "))
        </w:rPr>
        """

                // WordprocessingML represents tabs as a dedicated element (<w:tab/>).
                // Leaving raw '\t' inside <w:t> is unreliable and can break TOC/Index leader tab formatting.
                let parts = text.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                var children: [String] = []

                for (idx, part) in parts.enumerated() {
                        if !part.isEmpty {
                                children.append("<w:t xml:space=\"preserve\">\(xmlEscape(part))</w:t>")
                        } else {
                                // Preserve consecutive tabs by emitting an empty text node between them.
                                children.append("<w:t xml:space=\"preserve\"></w:t>")
                        }

                        if idx < parts.count - 1 {
                                children.append("<w:tab/>")
                        }
                }

                if children.isEmpty {
                        children = ["<w:t/>"]
                }

                return """
                <w:r>
                    \(rPrXml)\(children.joined())
                </w:r>
                """
    }

    private static func trimTrailingNewlines(in range: NSRange, string: NSString) -> NSRange {
        var newRange = range
        while newRange.length > 0 {
            let lastIndex = newRange.location + newRange.length - 1
            let char = string.character(at: lastIndex)
            if char == 10 || char == 13 {
                newRange.length -= 1
            } else {
                break
            }
        }
        return newRange
    }

    private static func hex(from color: NSColor) -> String {
        let rgb = (color.usingColorSpace(.sRGB) ?? color)
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(format: "%02X%02X%02X", r, g, b)
    }

    private static func xmlEscape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - Minimal DOCX text extractor (plain text)
private enum DocxTextExtractor {
    static func seemsQuillPilotGenerated(docxData data: Data) -> Bool {
        guard let docXml = try? ZipReader.extractFile(named: "word/document.xml", fromZipData: data) else { return false }
        guard let xml = String(data: docXml, encoding: .utf8) else { return false }

        // QuillPilot emits a small, predictable set of paragraph style IDs.
        // If present, prefer the custom extractor to preserve indents and style identity.
        let markers = [
            "w:pStyle w:val=\"BodyText\"",
            "w:pStyle w:val=\"BodyTextNoIndent\"",
            "w:pStyle w:val=\"Dialogue\"",
            // Poetry
            "w:pStyle w:val=\"Verse\"",
            "w:pStyle w:val=\"Stanza\"",
            "w:pStyle w:val=\"Poem\"",
            "w:pStyle w:val=\"PoetryVerse\"",
            "w:pStyle w:val=\"PoetryStanza\"",
            "w:pStyle w:val=\"TOCEntry\"",
            "w:pStyle w:val=\"TOCEntryLevel1\"",
            "w:pStyle w:val=\"TOCEntryLevel2\"",
            "w:pStyle w:val=\"TOCEntryLevel3\"",
            "w:pStyle w:val=\"IndexEntry\"",
            "w:pStyle w:val=\"IndexLetter\"",
            "w:pStyle w:val=\"IndexTitle\"",
            "w:pStyle w:val=\"ChapterTitle\"",
            "w:pStyle w:val=\"ChapterNumber\""
        ]
        return markers.contains { xml.contains($0) }
    }

    static func extractAttributedString(fromDocxFileURL url: URL) throws -> NSAttributedString {
        let data = try Data(contentsOf: url)
        return try extractAttributedString(fromDocxData: data)
    }

    static func extractAttributedString(fromDocxData data: Data) throws -> NSAttributedString {
        let documentXml = try ZipReader.extractFile(named: "word/document.xml", fromZipData: data)

        DebugLog.log("📄 Extracted document.xml: \(documentXml.count) bytes")

        // Clean the XML data by removing invalid control characters that cause parse errors
        let cleanedXml = cleanXMLData(documentXml)

        DebugLog.log("📄 After cleaning: \(cleanedXml.count) bytes")

        // Debug: Log first 1000 chars to see structure
        if let preview = String(data: cleanedXml.prefix(1000), encoding: .utf8) {
            DebugLog.log("📄 XML preview: \(preview.prefix(500))")
        }

        // Pre-parse relationships to avoid reentrant parsing
        var relationships: [String: String] = [:]
        if let relsData = try? ZipReader.extractFile(named: "word/_rels/document.xml.rels", fromZipData: data) {
            let parser = RelationshipsParser()
            let xmlParser = XMLParser(data: relsData)
            xmlParser.delegate = parser
            xmlParser.parse()
            relationships = parser.relationships
            DebugLog.log("📄 Found \(relationships.count) relationships")
        }

        return try DocumentXMLAttributedCollector.makeAttributedString(from: cleanedXml, docxData: data, relationships: relationships)
    }

    /// Cleans XML data by removing invalid control characters that cause parser errors
    private static func cleanXMLData(_ data: Data) -> Data {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            DebugLog.log("📄 Failed to decode XML as UTF-8, returning original data")
            return data
        }

        var cleaned = xmlString
        var changesMade = false

        // 1. Remove NULL bytes and other invalid control characters
        let validChars = cleaned.unicodeScalars.filter { scalar in
            let value = scalar.value
            return value == 0x09 || value == 0x0A || value == 0x0D ||
                   (value >= 0x20 && value <= 0xD7FF) ||
                   (value >= 0xE000 && value <= 0xFFFD) ||
                   (value >= 0x10000 && value <= 0x10FFFF)
        }
        let withoutInvalidChars = String(String.UnicodeScalarView(validChars))
        if withoutInvalidChars.count != cleaned.count {
            DebugLog.log("📄 Removed \(cleaned.count - withoutInvalidChars.count) invalid XML characters")
            cleaned = withoutInvalidChars
            changesMade = true
        }

        // 2. Fix unclosed tags or malformed attribute syntax
        // Replace common issues like missing quotes, broken tags
        if cleaned.contains("< ") || cleaned.contains(" >") {
            cleaned = cleaned.replacingOccurrences(of: "< ", with: "<")
            cleaned = cleaned.replacingOccurrences(of: " >", with: ">")
            changesMade = true
            DebugLog.log("📄 Fixed malformed tag spacing")
        }

        // 3. Remove any embedded binary data between tags (non-printable sequences)
        // Look for stretches of non-XML-like content between tags
        let pattern = try! NSRegularExpression(pattern: ">([^<]*?[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F]+[^<]*?)<", options: [])
        let matches = pattern.matches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned))
        if !matches.isEmpty {
            var result = cleaned
            for match in matches.reversed() {
                if let range = Range(match.range(at: 1), in: result) {
                    let problematic = String(result[range])
                    let filtered = problematic.filter { char in
                        let scalar = char.unicodeScalars.first!
                        let value = scalar.value
                        return value >= 0x20 || value == 0x09 || value == 0x0A || value == 0x0D
                    }
                    result.replaceSubrange(range, with: filtered)
                }
            }
            if result != cleaned {
                DebugLog.log("📄 Removed embedded binary data from XML content")
                cleaned = result
                changesMade = true
            }
        }

        if changesMade {
            DebugLog.log("📄 XML repair completed")
        }

        return cleaned.data(using: .utf8) ?? data
    }

    private final class RelationshipsParser: NSObject, XMLParserDelegate {
        var relationships: [String: String] = [:]

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            if (qName ?? elementName).lowercased() == "relationship" {
                if let id = attributeDict["Id"], let target = attributeDict["Target"] {
                    relationships[id] = target
                }
            }
        }
    }

    private final class DocumentXMLTextCollector: NSObject, XMLParserDelegate {
        private(set) var text: String = ""
        private var inText = false

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            let name = (qName ?? elementName).lowercased()
            if name.hasSuffix(":t") || name == "t" {
                inText = true
            } else if name.hasSuffix(":tab") || name == "tab" {
                text.append("\t")
            } else if name.hasSuffix(":br") || name == "br" {
                text.append("\n")
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard inText else { return }
            text.append(string)
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let name = (qName ?? elementName).lowercased()
            if name.hasSuffix(":t") || name == "t" {
                inText = false
            } else if name.hasSuffix(":p") || name == "p" {
                text.append("\n")
            }
        }
    }

    private final class DocumentXMLAttributedCollector: NSObject, XMLParserDelegate {
        private let result = NSMutableAttributedString()
        private var paragraphBuffer = NSMutableAttributedString()
        private var hasActiveParagraph = false
        private var paragraphStyle = ParagraphStyleProps()
        private var runAttributes = RunAttributes()
        private var currentText: String = ""
        private var inText = false
        private var inTabStopsDefinition = false
        private var docxData: Data?
        private var inDrawing = false
        private var currentImageRId: String?
        private var currentImageWidth: Int?
        private var currentImageHeight: Int?
        private var currentParagraphHasImage = false
        private var relationships: [String: String] = [:]

        // Table tracking
        private var currentTable: NSTextTable? = nil
        private var currentTableRow = 0
        private var currentTableCol = 0
        private var inTableCell = false
        private var currentTableIsColumnLayout = false

        struct RunAttributes {
            var fontName: String? = nil
            var fontSize: CGFloat? = nil
            var isBold: Bool = false
            var isItalic: Bool = false
            var foregroundColor: NSColor? = nil
            var backgroundColor: NSColor? = nil
            var themeColorName: String? = nil
            var themeTint: Double? = nil
            var themeShade: Double? = nil
            var shadingThemeColorName: String? = nil
            var shadingThemeTint: Double? = nil
            var shadingThemeShade: Double? = nil

            static func color(fromHex hex: String) -> NSColor? {
                var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                if cString.hasPrefix("#") { cString.remove(at: cString.startIndex) }
                if cString.count != 6 { return nil }
                var rgbValue: UInt64 = 0
                Scanner(string: cString).scanHexInt64(&rgbValue)
                return NSColor(
                    red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                    green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                    blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                    alpha: 1.0
                )
            }

            static func tintShadeFactor(from val: String) -> Double? {
                // Value is hex string of 0-255 (00-FF)
                guard let intVal = Int(val, radix: 16) else { return nil }
                return Double(intVal) / 255.0
            }

            static func color(fromTheme themeName: String?, tint: Double?, shade: Double?) -> NSColor? {
                guard let themeName = themeName else { return nil }
                var baseColor: NSColor?
                switch themeName {
                case "dark1": baseColor = .black
                case "light1": baseColor = .white
                case "dark2": baseColor = NSColor(srgbRed: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
                case "light2": baseColor = NSColor(srgbRed: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
                case "accent1": baseColor = .systemBlue
                case "accent2": baseColor = .systemOrange
                case "accent3": baseColor = .systemGray
                case "accent4": baseColor = .systemYellow
                case "accent5": baseColor = .systemGreen
                case "accent6": baseColor = .systemRed
                default: baseColor = nil
                }

                guard let color = baseColor else { return nil }
                var finalColor = color
                if let tint = tint {
                    finalColor = applyTint(finalColor, factor: tint)
                }
                if let shade = shade {
                    finalColor = applyShade(finalColor, factor: shade)
                }
                return finalColor
            }

            private static func applyTint(_ color: NSColor, factor: Double) -> NSColor {
                let f = max(0.0, min(1.0, factor))
                let srgb = (color.usingColorSpace(.sRGB) ?? color)
                let r = srgb.redComponent + (1.0 - srgb.redComponent) * f
                let g = srgb.greenComponent + (1.0 - srgb.greenComponent) * f
                let b = srgb.blueComponent + (1.0 - srgb.blueComponent) * f
                return NSColor(calibratedRed: r, green: g, blue: b, alpha: srgb.alphaComponent)
            }

            private static func applyShade(_ color: NSColor, factor: Double) -> NSColor {
                let f = max(0.0, min(1.0, factor))
                let srgb = (color.usingColorSpace(.sRGB) ?? color)
                let r = srgb.redComponent * (1.0 - f)
                let g = srgb.greenComponent * (1.0 - f)
                let b = srgb.blueComponent * (1.0 - f)
                return NSColor(calibratedRed: r, green: g, blue: b, alpha: srgb.alphaComponent)
            }
        }

        static func makeAttributedString(from data: Data, docxData: Data, relationships: [String: String]) throws -> NSAttributedString {
            let collector = DocumentXMLAttributedCollector()
            collector.docxData = docxData
            collector.relationships = relationships
            let parser = XMLParser(data: data)
            parser.delegate = collector
            parser.shouldProcessNamespaces = false
            parser.shouldReportNamespacePrefixes = false
            parser.shouldResolveExternalEntities = false

            let parseResult = parser.parse()

            // Always finalize any pending paragraph when parsing ends (even on error)
            if collector.hasActiveParagraph {
                collector.finalizeParagraph()
            }

            let output = collector.output()

            // If parsing failed and we got little/no content, throw error
            if !parseResult && output.length < 10 {
                throw parser.parserError ?? NSError(domain: "QuillPilot", code: 12, userInfo: [NSLocalizedDescriptionKey: "Failed to parse DOCX rich text"])
            }

            // If we got some content despite parse errors, use it
            if !parseResult {
                DebugLog.log("📄 Parser failed but recovered \(output.length) characters")
            }

            return output
        }

        func parserDidEndDocument(_ parser: XMLParser) {
            finalizeParagraph()
            // Trim one trailing newline if present to avoid introducing an extra empty paragraph.
            if result.string.hasSuffix("\n") {
                result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
            }

            // Fallback: ensure readable text color if DOCX lacked explicit colors or used very light ink.
            normalizeTextColors()
        }

        func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
            let nsError = parseError as NSError
            DebugLog.log("📷 XML Parse Error (code \(nsError.code)): \(parseError)")
            DebugLog.log("📷 Parser line: \(parser.lineNumber), column: \(parser.columnNumber)")

            // For non-fatal errors (like entities, formatting), continue parsing
            // Fatal errors like "no document" will still stop the parser
            if nsError.code == 4 || nsError.code == 9 || nsError.code == 68 {
                // Code 4: Tag mismatch, 9: Undeclared entity, 68: Entity boundary issues
                // These are often recoverable - log but continue
                DebugLog.log("📷 Non-fatal XML error, attempting to continue...")
            }
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            let name = (qName ?? elementName).lowercased()

            switch name {
            case "w:tbl", "tbl":
                // Start a new table
                currentTable = NSTextTable()
                currentTable?.numberOfColumns = 1 // Will be adjusted as we encounter cells
                currentTable?.layoutAlgorithm = .automaticLayoutAlgorithm
                currentTable?.collapsesBorders = true  // Collapse borders for consistent width
                currentTableRow = 0
                currentTableCol = 0
                currentTableIsColumnLayout = false

            case "w:tblStyle", "tblStyle":
                // Check if this is a column layout marker
                if let val = attributeDict["w:val"] ?? attributeDict["val"],
                   val == "QuillPilotColumnLayout" {
                    currentTableIsColumnLayout = true
                }

            case "w:tr", "tr":
                // New row in the table
                if currentTable != nil {
                    currentTableCol = 0
                }

            case "w:tc", "tc":
                // New cell in the table
                if let table = currentTable {
                    inTableCell = true
                    // Update table column count if needed
                    if currentTableCol >= table.numberOfColumns {
                        table.numberOfColumns = currentTableCol + 1
                    }
                }

            case "w:p", "p":
                if hasActiveParagraph { finalizeParagraph() }
                paragraphBuffer = NSMutableAttributedString()
                paragraphStyle = ParagraphStyleProps()
                hasActiveParagraph = true
                currentParagraphHasImage = false
                inTabStopsDefinition = false

                // If we're in a table cell, add the text block
                if inTableCell, let table = currentTable {
                    let textBlock = NSTextTableBlock(table: table, startingRow: currentTableRow, rowSpan: 1, startingColumn: currentTableCol, columnSpan: 1)

                    // Style based on whether it's a column layout or regular table
                    if currentTableIsColumnLayout {
                        // Column layout: no visible borders at all
                        textBlock.setBorderColor(.clear, for: .minX)
                        textBlock.setBorderColor(.clear, for: .maxX)
                        textBlock.setBorderColor(.clear, for: .minY)
                        textBlock.setBorderColor(.clear, for: .maxY)
                        textBlock.setWidth(0.0, type: .absoluteValueType, for: .border, edge: .minX)
                        textBlock.setWidth(0.0, type: .absoluteValueType, for: .border, edge: .maxX)
                        textBlock.setWidth(0.0, type: .absoluteValueType, for: .border, edge: .minY)
                        textBlock.setWidth(0.0, type: .absoluteValueType, for: .border, edge: .maxY)

                        textBlock.setWidth(12.0, type: .absoluteValueType, for: .padding, edge: .minX)
                        textBlock.setWidth(12.0, type: .absoluteValueType, for: .padding, edge: .maxX)
                    } else {
                        // Regular table: visible borders on all sides with consistent width
                        let borderColor = ThemeManager.shared.currentTheme.pageBorder.withAlphaComponent(0.55)
                        textBlock.setBorderColor(borderColor, for: .minX)
                        textBlock.setBorderColor(borderColor, for: .maxX)
                        textBlock.setBorderColor(borderColor, for: .minY)
                        textBlock.setBorderColor(borderColor, for: .maxY)
                        textBlock.setWidth(1.0, type: .absoluteValueType, for: .border, edge: .minX)
                        textBlock.setWidth(1.0, type: .absoluteValueType, for: .border, edge: .maxX)
                        textBlock.setWidth(1.0, type: .absoluteValueType, for: .border, edge: .minY)
                        textBlock.setWidth(1.0, type: .absoluteValueType, for: .border, edge: .maxY)

                        // Cell padding
                        textBlock.setWidth(10.0, type: .absoluteValueType, for: .padding, edge: .minX)
                        textBlock.setWidth(10.0, type: .absoluteValueType, for: .padding, edge: .maxX)
                        textBlock.setWidth(8.0, type: .absoluteValueType, for: .padding, edge: .minY)
                        textBlock.setWidth(8.0, type: .absoluteValueType, for: .padding, edge: .maxY)
                    }

                    paragraphStyle.textBlock = textBlock
                }

            case "w:pstyle", "pstyle":
                if let val = attributeDict["w:val"] ?? attributeDict["val"] {
                    // Map DOCX style IDs back to QuillPilot style names
                    // DOCX export removes spaces/special chars, so we need to reverse that
                    let mappedName: String
                    switch val {
                    case "Normal", "normal": mappedName = "Body Text"  // Default DOCX style maps to Body Text
                    case "BodyText": mappedName = "Body Text"
                    case "BodyTextNoIndent": mappedName = "Body Text – No Indent"
                    case "Heading1": mappedName = "Heading 1"
                    case "Heading2": mappedName = "Heading 2"
                    case "Heading3": mappedName = "Heading 3"
                    case "BookTitle": mappedName = "Book Title"
                    case "BookSubtitle": mappedName = "Book Subtitle"
                    case "AuthorName": mappedName = "Author Name"
                    case "FrontMatterHeading": mappedName = "Front Matter Heading"
                    case "EpigraphAttribution": mappedName = "Epigraph Attribution"
                    case "PartTitle": mappedName = "Part Title"
                    case "PartSubtitle": mappedName = "Part Subtitle"
                    case "ChapterNumber": mappedName = "Chapter Number"
                    case "ChapterTitle": mappedName = "Chapter Title"
                    case "ChapterSubtitle": mappedName = "Chapter Subtitle"
                    case "SceneBreak":
                        // Skip Scene Break - it's typically just formatting on empty paragraphs
                        mappedName = ""
                    case "InternalThought": mappedName = "Internal Thought"
                    case "LetterDocument": mappedName = "Letter / Document"
                    case "BlockQuote": mappedName = "Block Quote"
                    case "Epigraph": mappedName = "Epigraph"
                    case "Dialogue": mappedName = "Dialogue"
                    // Poetry (normalize legacy/container tags to Verse)
                    case "Verse": mappedName = "Verse"
                    case "Stanza", "Poem", "PoetryVerse", "PoetryStanza": mappedName = "Verse"
                    case "TOCTitle": mappedName = "TOC Title"
                    case "TOCEntry": mappedName = "TOC Entry"
                    case "TOCEntryLevel1": mappedName = "TOC Entry Level 1"
                    case "TOCEntryLevel2": mappedName = "TOC Entry Level 2"
                    case "TOCEntryLevel3": mappedName = "TOC Entry Level 3"
                    case "IndexTitle": mappedName = "Index Title"
                    case "IndexEntry": mappedName = "Index Entry"
                    case "IndexLetter": mappedName = "Index Letter"
                    default: mappedName = val
                    }
                    // Only set styleName and log if it's not empty (filters out Scene Break)
                    if !mappedName.isEmpty {
                        paragraphStyle.styleName = mappedName
                        DebugLog.log("📝 Read style from DOCX: \(val) -> \(mappedName)")
                    }
                }

            case "w:jc", "jc":
                let val = attributeDict["w:val"] ?? attributeDict["val"] ?? "left"
                paragraphStyle.alignment = ParagraphStyleProps.alignment(from: val)

            case "w:spacing", "spacing":
                if let beforeStr = attributeDict["w:before"] ?? attributeDict["before"], let twips = Double(beforeStr) {
                    paragraphStyle.spacingBefore = CGFloat(twips / 20.0)
                }
                if let afterStr = attributeDict["w:after"] ?? attributeDict["after"], let twips = Double(afterStr) {
                    paragraphStyle.spacingAfter = CGFloat(twips / 20.0)
                }
                if let lineStr = attributeDict["w:line"] ?? attributeDict["line"], let line = Double(lineStr) {
                    paragraphStyle.lineMultiple = max(0.01, CGFloat(line / 240.0))
                }

            case "w:ind", "ind":
                if let leftStr = attributeDict["w:left"] ?? attributeDict["left"] ?? attributeDict["w:start"] ?? attributeDict["start"], let twips = Double(leftStr) {
                    paragraphStyle.headIndent = CGFloat(twips / 20.0)
                }

                // Check for firstLine (standard indent) - handle both camelCase (standard) and lowercase
                if let firstStr = attributeDict["w:firstLine"] ?? attributeDict["firstLine"] ?? attributeDict["w:firstline"] ?? attributeDict["firstline"], let twips = Double(firstStr) {
                    paragraphStyle.firstLineIndent = CGFloat(twips / 20.0)
                }

                // Check for hanging indent (negative first line)
                if let hangingStr = attributeDict["w:hanging"] ?? attributeDict["hanging"], let twips = Double(hangingStr) {
                    paragraphStyle.firstLineIndent = -CGFloat(twips / 20.0)
                }

                if let rightStr = attributeDict["w:right"] ?? attributeDict["right"] ?? attributeDict["w:end"] ?? attributeDict["end"], let twips = Double(rightStr) {
                    paragraphStyle.tailIndent = CGFloat(twips / 20.0)
                }

            case "w:tabs", "tabs":
                // Tab-stop definitions live inside <w:pPr><w:tabs> ... </w:tabs>
                inTabStopsDefinition = true

            case "w:r", "r":
                finalizeRun()
                runAttributes = RunAttributes()
                currentText = ""

            case "w:rfonts", "rfonts":
                let fontName = attributeDict["w:ascii"] ?? attributeDict["w:hAnsi"] ?? attributeDict["w:cs"] ?? attributeDict["ascii"]
                DebugLog.log("📝 Parsing rfonts: attrs=\(attributeDict), extracted fontName='\(fontName ?? "nil")'")
                runAttributes.fontName = fontName

            case "w:sz", "sz":
                if let sizeStr = attributeDict["w:val"] ?? attributeDict["val"], let halfPoints = Double(sizeStr) {
                    runAttributes.fontSize = CGFloat(halfPoints / 2.0)
                }

            case "w:b", "b":
                runAttributes.isBold = true

            case "w:i", "i":
                runAttributes.isItalic = true

            case "w:color", "color":
                if let val = attributeDict["w:val"] ?? attributeDict["val"], let color = RunAttributes.color(fromHex: val) {
                    runAttributes.foregroundColor = color
                }
                runAttributes.themeColorName = attributeDict["w:themeColor"] ?? attributeDict["themeColor"]
                if let tint = attributeDict["w:themeTint"] ?? attributeDict["themeTint"], let dbl = RunAttributes.tintShadeFactor(from: tint) {
                    runAttributes.themeTint = dbl
                }
                if let shade = attributeDict["w:themeShade"] ?? attributeDict["themeShade"], let dbl = RunAttributes.tintShadeFactor(from: shade) {
                    runAttributes.themeShade = dbl
                }

            case "w:shd", "shd":
                if let fill = attributeDict["w:fill"] ?? attributeDict["fill"], let color = RunAttributes.color(fromHex: fill) {
                    runAttributes.backgroundColor = color
                }
                if runAttributes.backgroundColor == nil {
                    runAttributes.shadingThemeColorName = attributeDict["w:themeColor"] ?? attributeDict["themeColor"]
                    if let tint = attributeDict["w:themeTint"] ?? attributeDict["themeTint"], let dbl = RunAttributes.tintShadeFactor(from: tint) {
                        runAttributes.shadingThemeTint = dbl
                    }
                    if let shade = attributeDict["w:themeShade"] ?? attributeDict["themeShade"], let dbl = RunAttributes.tintShadeFactor(from: shade) {
                        runAttributes.shadingThemeShade = dbl
                    }
                }

            case "w:t", "t":
                inText = true

            case "w:tab", "tab":
                if inTabStopsDefinition {
                    // This is a tab STOP definition (not a tab character).
                    if let posStr = attributeDict["w:pos"] ?? attributeDict["pos"], let twips = Double(posStr) {
                        let position = CGFloat(twips / 20.0)
                        let valStr = attributeDict["w:val"] ?? attributeDict["val"] ?? "left"
                        let alignment: NSTextAlignment
                        switch valStr.lowercased() {
                        case "right": alignment = .right
                        case "center": alignment = .center
                        case "decimal": alignment = .right
                        default: alignment = .left
                        }
                        let tabStop = NSTextTab(textAlignment: alignment, location: position, options: [:])
                        paragraphStyle.tabStops.append(tabStop)
                    }
                } else {
                    // This is a tab CHARACTER within the text flow.
                    currentText.append("\t")
                }

            case "w:br", "br":
                currentText.append("\n")

            case "w:drawing", "drawing", "wp:inline", "inline":
                inDrawing = true
                DebugLog.log("📷 Found drawing element: \(name)")

            case "wp:extent", "extent":
                // Parse image dimensions in EMU units
                if inDrawing {
                    if let cxStr = attributeDict["cx"], let cx = Int(cxStr) {
                        currentImageWidth = cx
                    }
                    if let cyStr = attributeDict["cy"], let cy = Int(cyStr) {
                        currentImageHeight = cy
                    }
                    DebugLog.log("📷 Parsed extent: cx=\(currentImageWidth ?? 0) cy=\(currentImageHeight ?? 0)")
                }

            case "a:blip", "blip":
                // Extract the relationship ID for the image
                if inDrawing {
                    currentImageRId = attributeDict["r:embed"] ?? attributeDict["embed"]
                    DebugLog.log("📷 Found blip with rId: \(currentImageRId ?? "nil")")
                }

            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard inText else { return }
            currentText.append(string)
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let name = (qName ?? elementName).lowercased()

            switch name {
            case "w:t", "t":
                inText = false
            case "w:tabs", "tabs":
                inTabStopsDefinition = false
            case "w:r", "r":
                finalizeRun()
            case "w:p", "p":
                finalizeParagraph()
            case "w:tc", "tc":
                // Finished with this cell, move to next column
                if currentTable != nil {
                    inTableCell = false
                    currentTableCol += 1
                }
            case "w:tr", "tr":
                // Finished with this row, move to next row
                if currentTable != nil {
                    currentTableRow += 1
                }
            case "w:tbl", "tbl":
                // Finished with table
                currentTable = nil
                currentTableRow = 0
                currentTableCol = 0
            case "w:drawing", "drawing":
                // Only finalize when we exit the main drawing element
                if inDrawing && currentImageRId != nil && name.hasSuffix("drawing") {
                    finalizeImage()
                }
                if name.hasSuffix("drawing") {
                    inDrawing = false
                }
            default:
                break
            }
        }

        private func finalizeRun() {
            guard !currentText.isEmpty else { return }

            var attrs: [NSAttributedString.Key: Any] = [:]
            let size = runAttributes.fontSize ?? 12
            let fontName = runAttributes.fontName ?? "Times New Roman"
            DebugLog.log("📝 Import run: fontName='\(fontName)', fontSize=\(size), bold=\(runAttributes.isBold), italic=\(runAttributes.isItalic)")
            var font = NSFont(name: fontName, size: size) ?? NSFont.systemFont(ofSize: size)
            if font.fontName != fontName {
                DebugLog.log("⚠️ Font name mismatch: requested '\(fontName)' but got '\(font.fontName)'")
            }
            if runAttributes.isBold {
                font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            }
            if runAttributes.isItalic {
                font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            }
            attrs[.font] = font

            // Resolve foreground color: explicit hex first, then theme-based if present
            if let fg = runAttributes.foregroundColor {
                attrs[.foregroundColor] = fg
            } else if let theme = RunAttributes.color(fromTheme: runAttributes.themeColorName, tint: runAttributes.themeTint, shade: runAttributes.themeShade) {
                attrs[.foregroundColor] = theme
            }

            // Resolve background color from shading
            if let bg = runAttributes.backgroundColor {
                attrs[.backgroundColor] = bg
            } else if let theme = RunAttributes.color(fromTheme: runAttributes.shadingThemeColorName, tint: runAttributes.shadingThemeTint, shade: runAttributes.shadingThemeShade) {
                attrs[.backgroundColor] = theme
            }

            let runString = NSAttributedString(string: currentText, attributes: attrs)
            paragraphBuffer.append(runString)

            currentText = ""
        }

        private func finalizeImage() {
            guard let rId = currentImageRId, let docxData = docxData else {
                DebugLog.log("📷 finalizeImage: rId=\(currentImageRId ?? "nil"), hasDocxData=\(docxData != nil)")
                return
            }

            let widthEmu = currentImageWidth
            let heightEmu = currentImageHeight
            currentImageRId = nil
            currentImageWidth = nil
            currentImageHeight = nil

            DebugLog.log("📷 Attempting to load image for rId: \(rId), dimensions: \(widthEmu ?? 0) x \(heightEmu ?? 0) EMU")

            // Load and decode image immediately
            guard let imageData = loadImageFromDocx(rId: rId, docxData: docxData) else {
                DebugLog.log("📷 Failed to load image data from DOCX")
                return
            }

            guard let image = NSImage(data: imageData) else {
                DebugLog.log("📷 Failed to decode image data (\(imageData.count) bytes)")
                return
            }

            DebugLog.log("📷 Created NSImage: \(image.size.width) x \(image.size.height)")

            // Create attachment with fileWrapper for proper preservation
            let attachment = NSTextAttachment()
            attachment.image = image

            // Set fileWrapper so image data (and size) are preserved on save
            let wrapper = FileWrapper(regularFileWithContents: imageData)
            let encodedName = encodeImageFilename(size: image.size, ext: imageExtension(from: imageData))
            wrapper.preferredFilename = encodedName
            attachment.fileWrapper = wrapper

            // Set bounds from stored dimensions or intrinsic size
            let finalBounds: CGRect
            if let wEmu = widthEmu, let hEmu = heightEmu {
                let widthPt = CGFloat(wEmu) / 12700.0
                let heightPt = CGFloat(hEmu) / 12700.0
                finalBounds = CGRect(x: 0, y: 0, width: widthPt, height: heightPt)
                DebugLog.log("📷 Using stored dimensions: \(widthPt) x \(heightPt) pt")
            } else {
                let maxWidth: CGFloat = 400
                var bounds = CGRect(origin: .zero, size: image.size)
                if bounds.width > maxWidth {
                    let scale = maxWidth / bounds.width
                    bounds.size.width = maxWidth
                    bounds.size.height *= scale
                }
                finalBounds = bounds
                DebugLog.log("📷 Using intrinsic dimensions: \(bounds.width) x \(bounds.height) pt")
            }

            attachment.bounds = finalBounds

            // Create attributed string with the attachment and explicitly store bounds
            let attachmentString = NSMutableAttributedString(attachment: attachment)
            // Store original size as custom attribute so it survives RTFD round-trip
            attachmentString.addAttribute(
                NSAttributedString.Key("QuillPilotImageSize"),
                value: NSStringFromRect(finalBounds),
                range: NSRange(location: 0, length: 1)
            )

            // Add image to paragraph buffer
            paragraphBuffer.append(attachmentString)

            // Mark that this paragraph contains an image
            currentParagraphHasImage = true

            DebugLog.log("📷 Added image to paragraph buffer")
        }

        private func encodeImageFilename(size: CGSize, ext: String) -> String {
            // Store size in hundredths of a point to persist across RTFD round-trips
            let w = Int(round(size.width * 100))
            let h = Int(round(size.height * 100))
            return "image_w\(w)_h\(h).\(ext)"
        }

        private func imageExtension(from data: Data) -> String {
            guard data.count >= 8 else { return "png" }
            let header = data.prefix(8).map { $0 }

            if header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF {
                return "jpg"
            }
            if header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47 {
                return "png"
            }
            if header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46 {
                return "gif"
            }
            return "png"
        }

        private func loadImageFromDocx(rId: String, docxData: Data) -> Data? {
            guard let target = relationships[rId] else {
                DebugLog.log("📷 Failed to find relationship for rId: \(rId). Available keys: \(relationships.keys.joined(separator: ", "))")
                return nil
            }

            // Handle target path
            let cleanTarget = target.replacingOccurrences(of: "\\", with: "/")
            let imagePath: String
            if cleanTarget.hasPrefix("/") {
                // Absolute path from root (remove leading slash)
                imagePath = String(cleanTarget.dropFirst())
            } else if cleanTarget.hasPrefix("../") {
                // Relative to word/ parent -> root
                imagePath = String(cleanTarget.dropFirst(3))
            } else {
                // Relative path from word/ directory
                imagePath = "word/\(cleanTarget)"
            }

            DebugLog.log("📷 Found image path: \(imagePath)")

            // Extract image from zip
            guard let imageData = try? ZipReader.extractFile(named: imagePath, fromZipData: docxData) else {
                DebugLog.log("📷 Failed to extract image from zip at path: \(imagePath)")
                return nil
            }

            DebugLog.log("📷 Successfully extracted image: \(imageData.count) bytes")
            return imageData
        }

        private func finalizeParagraph() {
            guard hasActiveParagraph else { return }
            finalizeRun()

            if paragraphBuffer.length > 0 {
                let paragraph = paragraphStyle.makeParagraphStyle()
                paragraphBuffer.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: paragraphBuffer.length))

                // Determine style name - default to Body Text if none specified
                let styleName = paragraphStyle.styleName ?? "Body Text"

                // Apply QuillStyleName attribute
                paragraphBuffer.addAttribute(NSAttributedString.Key("QuillStyleName"), value: styleName, range: NSRange(location: 0, length: paragraphBuffer.length))
                DebugLog.log("📝 Applied QuillStyleName attribute: \(styleName)")

                // Apply style definition from StyleCatalog to ensure formatting is preserved
                if let styleDefinition = StyleCatalog.shared.style(named: styleName) {
                    DebugLog.log("📝 Applying style definition from catalog for: \(styleName)")

                    // Apply font attributes from style definition
                    let font = makeFont(from: styleDefinition)
                    let textColor = NSColor(hex: styleDefinition.textColorHex) ?? .black

                    // Update all runs in the paragraph buffer with style attributes
                    paragraphBuffer.enumerateAttributes(in: NSRange(location: 0, length: paragraphBuffer.length), options: []) { attrs, range, _ in
                        var newAttrs = attrs

                        // Only override font if not explicitly set (e.g., by bold/italic in run)
                        if let existingFont = attrs[.font] as? NSFont {
                            // Preserve bold/italic traits from the run
                            let traits = existingFont.fontDescriptor.symbolicTraits
                            var updatedFont = font
                            if traits.contains(.bold) {
                                updatedFont = NSFontManager.shared.convert(updatedFont, toHaveTrait: .boldFontMask)
                            }
                            if traits.contains(.italic) {
                                updatedFont = NSFontManager.shared.convert(updatedFont, toHaveTrait: .italicFontMask)
                            }
                            newAttrs[.font] = updatedFont
                        } else {
                            newAttrs[.font] = font
                        }

                        // Apply text color from style if not explicitly set in run
                        if attrs[.foregroundColor] == nil {
                            newAttrs[.foregroundColor] = textColor
                        }

                        // Apply background color if specified
                        if let bgHex = styleDefinition.backgroundColorHex,
                           let bgColor = NSColor(hex: bgHex) {
                            newAttrs[.backgroundColor] = bgColor
                        }

                        paragraphBuffer.setAttributes(newAttrs, range: range)
                    }

                    // Update paragraph style with style definition properties
                    let updatedParagraphStyle = makeParagraphStyle(from: styleDefinition)
                    if let merged = updatedParagraphStyle.mutableCopy() as? NSMutableParagraphStyle {
                        // Preserve imported tab stops for TOC/Index leader-dot formatting.
                        if !paragraph.tabStops.isEmpty {
                            merged.tabStops = paragraph.tabStops
                            merged.defaultTabInterval = paragraph.defaultTabInterval
                        }
                        // Preserve non-wrapping behavior for TOC/Index lines.
                        if paragraph.lineBreakMode == .byClipping {
                            merged.lineBreakMode = .byClipping
                        }
                        paragraphBuffer.addAttribute(.paragraphStyle, value: merged.copy() as! NSParagraphStyle, range: NSRange(location: 0, length: paragraphBuffer.length))
                    } else {
                        paragraphBuffer.addAttribute(.paragraphStyle, value: updatedParagraphStyle, range: NSRange(location: 0, length: paragraphBuffer.length))
                    }
                } else {
                    DebugLog.log("⚠️ Style '\(styleName)' not found in StyleCatalog")
                }

                result.append(paragraphBuffer)
            }

            // Always add newline to separate paragraphs.
            // Previous logic skipped newline for images, causing them to merge with the next paragraph.
            result.append(NSAttributedString(string: "\n"))

            paragraphBuffer = NSMutableAttributedString()
            hasActiveParagraph = false
        }

        private func makeFont(from definition: StyleDefinition) -> NSFont {
            let size = definition.fontSize
            var font = NSFont(name: definition.fontName, size: size) ?? NSFont.systemFont(ofSize: size)

            if definition.isBold {
                font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            }
            if definition.isItalic {
                font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            }

            return font
        }

        private func makeParagraphStyle(from definition: StyleDefinition) -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()

            // Alignment
            if let alignment = NSTextAlignment(rawValue: definition.alignmentRawValue) {
                style.alignment = alignment
            }

            // Line height
            style.lineHeightMultiple = definition.lineHeightMultiple

            // Spacing
            style.paragraphSpacingBefore = definition.spacingBefore
            style.paragraphSpacing = definition.spacingAfter

            // Indents
            style.headIndent = definition.headIndent
            style.firstLineHeadIndent = definition.headIndent + definition.firstLineIndent
            style.tailIndent = definition.tailIndent

            return style.copy() as! NSParagraphStyle
        }

        private func output() -> NSAttributedString {
            return result.copy() as! NSAttributedString
        }

        /// Ensures imported text has a readable foreground color. Some DOCX files omit color or use white text;
        /// we normalize to the current theme's text color when the color is missing, extremely transparent, or very bright.
        private func normalizeTextColors() {
            let fallback = ThemeManager.shared.currentTheme.textColor
            let fullRange = NSRange(location: 0, length: result.length)

            result.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
                if let color = value as? NSColor {
                    let rgb = (color.usingColorSpace(.sRGB) ?? color)
                    let alpha = rgb.alphaComponent
                    let brightness = (0.299 * rgb.redComponent) + (0.587 * rgb.greenComponent) + (0.114 * rgb.blueComponent)

                    if alpha < 0.25 || brightness > 0.92 {
                        result.addAttribute(.foregroundColor, value: fallback, range: range)
                    }
                } else {
                    result.addAttribute(.foregroundColor, value: fallback, range: range)
                }
            }
        }


        private struct ParagraphStyleProps {
            var alignment: NSTextAlignment = .left
            var spacingBefore: CGFloat = 0
            var spacingAfter: CGFloat = 0
            var lineMultiple: CGFloat = 1.0
            var headIndent: CGFloat = 0
            var firstLineIndent: CGFloat = 0
            var tailIndent: CGFloat = 0
            var styleName: String? = "Body Text"  // Default to Body Text for imported paragraphs
            var textBlock: NSTextTableBlock? = nil
            var tabStops: [NSTextTab] = []

            func makeParagraphStyle() -> NSParagraphStyle {
                let style = NSMutableParagraphStyle()
                style.alignment = alignment
                style.paragraphSpacingBefore = spacingBefore
                style.paragraphSpacing = spacingAfter
                style.lineHeightMultiple = lineMultiple
                style.headIndent = headIndent
                style.firstLineHeadIndent = headIndent + firstLineIndent
                style.tailIndent = tailIndent
                if !tabStops.isEmpty || (styleName?.hasPrefix("TOC") == true) || (styleName?.hasPrefix("Index") == true) {
                    style.lineBreakMode = .byClipping
                } else {
                    style.lineBreakMode = .byWordWrapping
                }

                // Add text block if this paragraph is part of a table
                if let block = textBlock {
                    style.textBlocks = [block]
                }

                // Add tab stops (for TOC/Index formatting)
                if !tabStops.isEmpty {
                    style.tabStops = tabStops
                }

                return style.copy() as! NSParagraphStyle
            }

            static func alignment(from xmlValue: String) -> NSTextAlignment {
                switch xmlValue.lowercased() {
                case "center": return .center
                case "right": return .right
                case "both", "justify": return .justified
                default: return .left
                }
            }
        }
    }

    private enum ZipReader {
        static func extractFile(named targetName: String, fromZipData data: Data) throws -> Data {
            let eocdOffset = try findEndOfCentralDirectoryOffset(in: data)
            let totalEntries = Int(data.readUInt16LE(at: eocdOffset + 10))
            let centralDirOffset = Int(data.readUInt32LE(at: eocdOffset + 16))

            var cursor = centralDirOffset
            for _ in 0..<totalEntries {
                guard data.readUInt32LE(at: cursor) == 0x02014b50 else {
                    throw NSError(domain: "QuillPilot", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid ZIP central directory."])
                }

                let compression = data.readUInt16LE(at: cursor + 10)
                let compressedSize = Int(data.readUInt32LE(at: cursor + 20))
                let fileNameLen = Int(data.readUInt16LE(at: cursor + 28))
                let extraLen = Int(data.readUInt16LE(at: cursor + 30))
                let commentLen = Int(data.readUInt16LE(at: cursor + 32))
                let localHeaderOffset = Int(data.readUInt32LE(at: cursor + 42))
                let fileNameData = data.subdata(in: (cursor + 46)..<(cursor + 46 + fileNameLen))
                let fileName = String(data: fileNameData, encoding: .utf8) ?? ""

                if fileName == targetName {
                    return try extractFromLocalHeader(at: localHeaderOffset, compression: compression, compressedSize: compressedSize, in: data)
                }

                cursor += 46 + fileNameLen + extraLen + commentLen
            }

            DebugLog.log("📷 ZipReader failed to find: \(targetName). Total entries: \(totalEntries)")
            throw NSError(domain: "QuillPilot", code: 5, userInfo: [NSLocalizedDescriptionKey: "DOCX is missing \(targetName)"])
        }

        private static func extractFromLocalHeader(at offset: Int, compression: UInt16, compressedSize: Int, in data: Data) throws -> Data {
            guard data.readUInt32LE(at: offset) == 0x04034b50 else {
                throw NSError(domain: "QuillPilot", code: 6, userInfo: [NSLocalizedDescriptionKey: "Invalid ZIP local header."])
            }

            let fileNameLen = Int(data.readUInt16LE(at: offset + 26))
            let extraLen = Int(data.readUInt16LE(at: offset + 28))
            let dataStart = offset + 30 + fileNameLen + extraLen
            let dataEnd = dataStart + compressedSize
            guard dataStart >= 0, dataEnd <= data.count else {
                throw NSError(domain: "QuillPilot", code: 7, userInfo: [NSLocalizedDescriptionKey: "ZIP entry out of bounds."])
            }

            let compressedData = data.subdata(in: dataStart..<dataEnd)

            if compression == 0 {
                // Store (uncompressed)
                return compressedData
            } else if compression == 8 {
                // Deflate compression (most common in DOCX files)
                do {
                    let decompressed = try (compressedData as NSData).decompressed(using: .zlib)
                    return decompressed as Data
                } catch {
                    throw NSError(domain: "QuillPilot", code: 8, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to decompress DOCX entry.",
                        NSUnderlyingErrorKey: error
                    ])
                }
            } else {
                throw NSError(domain: "QuillPilot", code: 9, userInfo: [
                    NSLocalizedDescriptionKey: "Unsupported DOCX compression method: \(compression)",
                    NSLocalizedFailureReasonErrorKey: "Only store (0) and deflate (8) compression are supported."
                ])
            }
        }

        private static func findEndOfCentralDirectoryOffset(in data: Data) throws -> Int {
            // EOCD record minimum length is 22 bytes; comment length can add up to 65535 bytes.
            let minEOCD = 22
            guard data.count >= minEOCD else {
                throw NSError(domain: "QuillPilot", code: 9, userInfo: [NSLocalizedDescriptionKey: "Invalid ZIP: too small."])
            }

            let start = max(0, data.count - minEOCD - 65535)
            var i = data.count - minEOCD
            while i >= start {
                if data.readUInt32LE(at: i) == 0x06054b50 {
                    return i
                }
                i -= 1
            }

            throw NSError(domain: "QuillPilot", code: 10, userInfo: [NSLocalizedDescriptionKey: "Invalid ZIP: missing end of central directory."])
        }
    }
} // End DocxTextExtractor


// MARK: - EditorViewController Delegate
extension ContentViewController: EditorViewControllerDelegate {
    func textDidChange() {
        // Notify auto-save that document has changed
        onTextChange?()

        guard !analysisSuspended else {
            analysisPending = true
            return
        }
        analysisPending = false

        // Throttle stats update and outline refresh to improve typing performance
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateStatsDelayed), object: nil)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(refreshOutlineDelayed), object: nil)

        // Different delays for columns vs tables: columns are simpler text formatting
        let isInColumns = isCurrentlyInColumns()
        let isInTable = isCurrentlyInTable()

        let statsDelay: TimeInterval
        let outlineDelay: TimeInterval
        let analysisDelay: TimeInterval

        if isInTable {
            // Data tables need aggressive throttling
            statsDelay = 3.0
            outlineDelay = 3.0
            analysisDelay = 10.0
        } else if isInColumns {
            // Columns are lighter - just text flow formatting
            statsDelay = 1.0
            outlineDelay = 1.0
            analysisDelay = 3.0
        } else {
            // Normal text
            statsDelay = 0.5
            outlineDelay = 0.5
            analysisDelay = 2.0
        }

        perform(#selector(updateStatsDelayed), with: nil, afterDelay: statsDelay)
        perform(#selector(refreshOutlineDelayed), with: nil, afterDelay: outlineDelay)

        if QuillPilotSettings.autoAnalyzeWhileTyping {
            // Trigger auto-analysis after a longer delay
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performAnalysisDelayed), object: nil)
            perform(#selector(performAnalysisDelayed), with: nil, afterDelay: analysisDelay)
        }
    }

    func suspendAnalysisForLayout() {
        analysisSuspended = true
        analysisPending = false
    }

    func resumeAnalysisAfterLayout() {
        analysisSuspended = false
        if analysisPending {
            textDidChange()
        }
    }

    func titleDidChange(_ title: String) {
        // Keep editor manuscript metadata consistent (used by headers/footers/printing)
        editorViewController?.setManuscriptInfo(title: title, author: editorViewController?.manuscriptAuthor ?? "")
        onTitleChange?(title)
    }

    func authorDidChange(_ author: String) {
        // Keep editor manuscript metadata consistent (used by headers/footers/printing)
        editorViewController?.setManuscriptInfo(title: editorViewController?.manuscriptTitle ?? "", author: author)
        onAuthorChange?(author)
    }

    func selectionDidChange() {
        // Get current style name at cursor and notify
        let styleName = editorViewController?.getCurrentStyleName()
        onSelectionChange?(styleName)
    }

    private func isCurrentlyInTable() -> Bool {
        guard let textStorage = editorViewController?.textView?.textStorage else { return false }
        let location = editorViewController?.textView?.selectedRange().location ?? 0
        guard location < textStorage.length else { return false }

        let attrs = textStorage.attributes(at: location, effectiveRange: nil)
        if let style = attrs[.paragraphStyle] as? NSParagraphStyle,
           let blocks = style.textBlocks as? [NSTextTableBlock],
           let block = blocks.first {
            // Data tables have cells with startingRow > 0
            // Column layouts have all cells with startingRow == 0
            return block.startingRow > 0
        }
        return false
    }

    private func isCurrentlyInColumns() -> Bool {
        guard let textStorage = editorViewController?.textView?.textStorage else { return false }
        let location = editorViewController?.textView?.selectedRange().location ?? 0
        guard location < textStorage.length else { return false }

        let attrs = textStorage.attributes(at: location, effectiveRange: nil)
        if let style = attrs[.paragraphStyle] as? NSParagraphStyle,
           let blocks = style.textBlocks as? [NSTextTableBlock],
           let block = blocks.first {
            // Column layouts: startingRow == 0, multiple columns
            // Data tables: startingRow varies
            return block.startingRow == 0 && block.table.numberOfColumns > 1
        }
        return false
    }

    @objc private func performAnalysisDelayed() {
        performAnalysis()
    }

    @objc private func updateStatsDelayed() {
        if let text = editorViewController?.textView?.string {
            onStatsUpdate?(text)
        }
    }

    @objc private func refreshOutlineDelayed() {
        refreshOutline()
    }
}

private extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        let b0 = UInt16(self[offset])
        let b1 = UInt16(self[offset + 1])
        return b0 | (b1 << 8)
    }

    func readUInt32LE(at offset: Int) -> UInt32 {
        let b0 = UInt32(self[offset])
        let b1 = UInt32(self[offset + 1])
        let b2 = UInt32(self[offset + 2])
        let b3 = UInt32(self[offset + 3])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    mutating func appendUInt16(_ v: UInt16) {
        var le = v.littleEndian
        Swift.withUnsafeBytes(of: &le) { append($0.bindMemory(to: UInt8.self)) }
    }

    mutating func appendUInt32(_ v: UInt32) {
        var le = v.littleEndian
        Swift.withUnsafeBytes(of: &le) { append($0.bindMemory(to: UInt8.self)) }
    }
}

// MARK: - Tiny ZIP writer (store)
private enum ZipWriter {
    static func makeZip(entries: [(String, Data)]) -> Data {
        var fileData = Data()
        var centralDirectory = Data()

        for (path, data) in entries {
            let localOffset = UInt32(fileData.count)
            let crc = CRC32.checksum(data)
            let fileNameData = Data(path.utf8)

            // Local file header
            fileData.appendUInt32(0x04034b50)
            fileData.appendUInt16(20) // version
            fileData.appendUInt16(0)  // flags
            fileData.appendUInt16(0)  // compression: store
            fileData.appendUInt16(0)  // mod time
            fileData.appendUInt16(0)  // mod date
            fileData.appendUInt32(crc)
            fileData.appendUInt32(UInt32(data.count))
            fileData.appendUInt32(UInt32(data.count))
            fileData.appendUInt16(UInt16(fileNameData.count))
            fileData.appendUInt16(0) // extra len
            fileData.append(fileNameData)
            fileData.append(data)

            // Central directory header
            centralDirectory.appendUInt32(0x02014b50)
            centralDirectory.appendUInt16(20) // version made by
            centralDirectory.appendUInt16(20) // version needed to extract
            centralDirectory.appendUInt16(0)  // flags
            centralDirectory.appendUInt16(0)  // compression
            centralDirectory.appendUInt16(0)  // mod time
            centralDirectory.appendUInt16(0)  // mod date
            centralDirectory.appendUInt32(crc)
            centralDirectory.appendUInt32(UInt32(data.count))
            centralDirectory.appendUInt32(UInt32(data.count))
            centralDirectory.appendUInt16(UInt16(fileNameData.count))
            centralDirectory.appendUInt16(0) // extra
            centralDirectory.appendUInt16(0) // comment
            centralDirectory.appendUInt16(0) // disk
            centralDirectory.appendUInt16(0) // int attrs
            centralDirectory.appendUInt32(0) // ext attrs
            centralDirectory.appendUInt32(localOffset)
            centralDirectory.append(fileNameData)
        }

        let centralDirOffset = UInt32(fileData.count)
        fileData.append(centralDirectory)

        // End of central directory
        fileData.appendUInt32(0x06054b50)
        fileData.appendUInt16(0)
        fileData.appendUInt16(0)
        fileData.appendUInt16(UInt16(entries.count))
        fileData.appendUInt16(UInt16(entries.count))
        fileData.appendUInt32(UInt32(centralDirectory.count))
        fileData.appendUInt32(centralDirOffset)
        fileData.appendUInt16(0) // comment length

        return fileData
    }

    private enum CRC32 {
        private static let table: [UInt32] = {
            (0..<256).map { i -> UInt32 in
                var c = UInt32(i)
                for _ in 0..<8 {
                    c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
                }
                return c
            }
        }()

        static func checksum(_ data: Data) -> UInt32 {
            var crc: UInt32 = 0xFFFFFFFF
            for b in data {
                let idx = Int((crc ^ UInt32(b)) & 0xFF)
                crc = table[idx] ^ (crc >> 8)
            }
            return crc ^ 0xFFFFFFFF
        }
    }
}

extension MainWindowController {
    // MARK: - ePub and Mobi Export

    private func generateEPub(from content: NSAttributedString, url: URL) throws -> Data {
        // Create a temporary directory for ePub structure
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create ePub directory structure
        let metaInfDir = tempDir.appendingPathComponent("META-INF")
        let oebpsDir = tempDir.appendingPathComponent("OEBPS")
        try FileManager.default.createDirectory(at: metaInfDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: oebpsDir, withIntermediateDirectories: true)

        // Get document title (from filename or "Untitled")
        let title = url.deletingPathExtension().lastPathComponent

        // Write mimetype (must be first file, uncompressed)
        let mimetypeURL = tempDir.appendingPathComponent("mimetype")
        try "application/epub+zip".write(to: mimetypeURL, atomically: true, encoding: .utf8)

        // Write container.xml
        let containerXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        try containerXML.write(to: metaInfDir.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)

        // Convert attributed string to HTML
        let htmlContent = try convertToHTML(content)
        let contentHTML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <title>\(title)</title>
          <link rel="stylesheet" type="text/css" href="stylesheet.css"/>
        </head>
        <body>
        \(htmlContent)
        </body>
        </html>
        """
        try contentHTML.write(to: oebpsDir.appendingPathComponent("content.html"), atomically: true, encoding: .utf8)

        // Write stylesheet.css
        let css = """
        body { font-family: serif; font-size: 1em; line-height: 1.5; margin: 1em; }
        h1 { font-size: 1.8em; margin-top: 1em; margin-bottom: 0.5em; }
        h2 { font-size: 1.5em; margin-top: 0.8em; margin-bottom: 0.4em; }
        p { margin: 0.5em 0; text-indent: 1.5em; }
        p:first-child, h1 + p, h2 + p { text-indent: 0; }
        """
        try css.write(to: oebpsDir.appendingPathComponent("stylesheet.css"), atomically: true, encoding: .utf8)

        // Write content.opf
        let contentOPF = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>\(title)</dc:title>
            <dc:language>en</dc:language>
            <dc:identifier id="bookid">urn:uuid:\(UUID().uuidString)</dc:identifier>
            <meta property="dcterms:modified">\(ISO8601DateFormatter().string(from: Date()))</meta>
          </metadata>
          <manifest>
            <item id="content" href="content.html" media-type="application/xhtml+xml"/>
            <item id="stylesheet" href="stylesheet.css" media-type="text/css"/>
            <item id="toc" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
          </manifest>
          <spine toc="toc">
            <itemref idref="content"/>
          </spine>
        </package>
        """
        try contentOPF.write(to: oebpsDir.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)

        // Write toc.ncx (navigation)
        let tocNCX = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
          <head>
            <meta name="dtb:uid" content="urn:uuid:\(UUID().uuidString)"/>
            <meta name="dtb:depth" content="1"/>
          </head>
          <docTitle><text>\(title)</text></docTitle>
          <navMap>
            <navPoint id="content" playOrder="1">
              <navLabel><text>\(title)</text></navLabel>
              <content src="content.html"/>
            </navPoint>
          </navMap>
        </ncx>
        """
        try tocNCX.write(to: oebpsDir.appendingPathComponent("toc.ncx"), atomically: true, encoding: .utf8)

        // Create ZIP archive (ePub is a ZIP file)
        let epubData = try createZipArchive(at: tempDir, mimetypeFirst: true)
        return epubData
    }

    private func convertToHTML(_ content: NSAttributedString) throws -> String {
        var html = ""
        let fullRange = NSRange(location: 0, length: content.length)

        content.enumerateAttributes(in: fullRange) { attrs, range, _ in
            let text = (content.string as NSString).substring(with: range)
            let escapedText = text
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")

            // Check for style/formatting
            if let font = attrs[.font] as? NSFont {
                if font.pointSize >= 18 {
                    html += "<h1>\(escapedText)</h1>\n"
                } else if font.pointSize >= 14 && font.fontDescriptor.symbolicTraits.contains(.bold) {
                    html += "<h2>\(escapedText)</h2>\n"
                } else {
                    html += "<p>\(escapedText)</p>\n"
                }
            } else {
                html += "<p>\(escapedText)</p>\n"
            }
        }

        return html
    }

    private func createZipArchive(at directory: URL, mimetypeFirst: Bool = false) throws -> Data {
        // Use the system zip command for reliable compression
        let zipURL = directory.deletingLastPathComponent().appendingPathComponent("output.epub")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")

        if mimetypeFirst {
            // ePub spec requires mimetype to be first and uncompressed
            process.arguments = ["-0", "-X", zipURL.path, "mimetype"]
            process.currentDirectoryURL = directory
            try process.run()
            process.waitUntilExit()

            // Add remaining files with compression
            let process2 = Process()
            process2.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process2.arguments = ["-r", "-9", "-X", zipURL.path, "META-INF", "OEBPS"]
            process2.currentDirectoryURL = directory
            try process2.run()
            process2.waitUntilExit()
        } else {
            process.arguments = ["-r", zipURL.path, "."]
            process.currentDirectoryURL = directory
            try process.run()
            process.waitUntilExit()
        }

        let data = try Data(contentsOf: zipURL)
        try? FileManager.default.removeItem(at: zipURL)
        return data
    }

    // MARK: - Mobi Export

    private func generateMobi(from content: NSAttributedString, url: URL) throws -> Data {
        // Mobi format is complex - we'll generate an HTML file and note that
        // users need KindleGen or Calibre to convert ePub to Mobi

        // For now, create a basic HTML that can be read by Kindle
        let title = url.deletingPathExtension().lastPathComponent
        let htmlContent = try convertToHTML(content)

        let mobiHTML = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <title>\(title)</title>
          <style>
            body { font-family: serif; line-height: 1.5; margin: 1em; }
            h1 { page-break-before: always; }
            p { text-indent: 1.5em; margin: 0.5em 0; }
          </style>
        </head>
        <body>
          <h1>\(title)</h1>
          \(htmlContent)
        </body>
        </html>
        """

        // Note: True .mobi generation requires KindleGen tool
        // This creates an HTML file that can be sent to Kindle via email or converted
        guard let data = mobiHTML.data(using: .utf8) else {
            throw NSError(domain: "QuillPilot", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to generate Mobi HTML"
            ])
        }

        return data
    }
}


// MARK: - Search Panel

class SearchPanelController: NSWindowController {
    private var searchField: NSTextField!
    private var replaceField: NSTextField!
    private var caseSensitiveCheckbox: NSButton!
    private var wholeWordsCheckbox: NSButton!
    private var findNextButton: NSButton!
    private var findPreviousButton: NSButton!
    private var replaceButton: NSButton!
    private var replaceAllButton: NSButton!
    private var statusLabel: NSTextField!

    private var themeObserver: Any?
    private var resignKeyObserver: Any?

    // Go to Page controls
    private var pageNumberField: NSTextField!
    private var goToPageButton: NSButton!
    private var pageInfoLabel: NSTextField!

    weak var editorViewController: EditorViewController?

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 280),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Find & Replace"
        panel.isFloatingPanel = true
        panel.level = .floating

        self.init(window: panel)
        setupUI()
        applyTheme()

        themeObserver = NotificationCenter.default.addObserver(forName: .themeDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.applyTheme()
        }

        resignKeyObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            // Clicking back into the editor (or any other window) should dismiss this utility panel.
            self?.close()
        }
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
        if let resignKeyObserver {
            NotificationCenter.default.removeObserver(resignKeyObserver)
        }
    }

    private func styleInputField(_ field: NSTextField, theme: AppTheme) {
        field.textColor = theme.textColor
        field.drawsBackground = true
        field.backgroundColor = theme.pageBackground
        field.isBezeled = false
        field.isBordered = false
        field.focusRingType = .none
        field.wantsLayer = true
        field.layer?.borderWidth = 1
        field.layer?.cornerRadius = 6
        field.layer?.borderColor = theme.pageBorder.cgColor
    }

    private func styleActionButton(_ button: NSButton, theme: AppTheme) {
        button.wantsLayer = true
        button.isBordered = false
        button.focusRingType = .none
        button.layer?.cornerRadius = 8
        button.layer?.borderWidth = 1
        button.layer?.borderColor = theme.pageBorder.cgColor
        button.layer?.backgroundColor = theme.pageBackground.cgColor

        let font = button.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .foregroundColor: theme.textColor,
                .font: font
            ]
        )
    }

    private func setupUI() {
        guard let panel = window as? NSPanel else { return }

        let contentView = NSView(frame: panel.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        panel.contentView = contentView

        // Search field
        let searchLabel = NSTextField(labelWithString: "Find:")
        searchLabel.frame = NSRect(x: 20, y: 230, width: 60, height: 20)
        contentView.addSubview(searchLabel)

        searchField = NSTextField(frame: NSRect(x: 90, y: 228, width: 410, height: 24))
        searchField.placeholderString = "Enter search text"
        contentView.addSubview(searchField)

        // Replace field
        let replaceLabel = NSTextField(labelWithString: "Replace:")
        replaceLabel.frame = NSRect(x: 20, y: 198, width: 60, height: 20)
        contentView.addSubview(replaceLabel)

        replaceField = NSTextField(frame: NSRect(x: 90, y: 196, width: 410, height: 24))
        replaceField.placeholderString = "Enter replacement text"
        contentView.addSubview(replaceField)

        // Options
        caseSensitiveCheckbox = NSButton(checkboxWithTitle: "Case sensitive", target: nil, action: nil)
        caseSensitiveCheckbox.frame = NSRect(x: 90, y: 168, width: 140, height: 20)
        contentView.addSubview(caseSensitiveCheckbox)

        wholeWordsCheckbox = NSButton(checkboxWithTitle: "Whole words only", target: nil, action: nil)
        wholeWordsCheckbox.frame = NSRect(x: 90, y: 144, width: 140, height: 20)
        contentView.addSubview(wholeWordsCheckbox)

        // Buttons
        findPreviousButton = NSButton(title: "◀︎ Previous", target: self, action: #selector(findPrevious))
        findPreviousButton.frame = NSRect(x: 20, y: 110, width: 105, height: 28)
        findPreviousButton.bezelStyle = .rounded
        contentView.addSubview(findPreviousButton)

        findNextButton = NSButton(title: "Next ▶︎", target: self, action: #selector(findNext))
        findNextButton.frame = NSRect(x: 135, y: 110, width: 105, height: 28)
        findNextButton.bezelStyle = .rounded
        // Keep Enter free for text entry; avoid default-button blue fill.
        contentView.addSubview(findNextButton)

        replaceButton = NSButton(title: "Replace", target: self, action: #selector(replace))
        replaceButton.frame = NSRect(x: 250, y: 110, width: 120, height: 28)
        replaceButton.bezelStyle = .rounded
        contentView.addSubview(replaceButton)

        replaceAllButton = NSButton(title: "Replace All", target: self, action: #selector(replaceAll))
        replaceAllButton.frame = NSRect(x: 380, y: 110, width: 120, height: 28)
        replaceAllButton.bezelStyle = .rounded
        contentView.addSubview(replaceAllButton)

        // Separator line
        let separator = NSBox()
        separator.boxType = .separator
        separator.frame = NSRect(x: 20, y: 92, width: 480, height: 1)
        contentView.addSubview(separator)

        // Go to Page section
        let pageLabel = NSTextField(labelWithString: "Go to Page:")
        pageLabel.frame = NSRect(x: 20, y: 60, width: 80, height: 20)
        contentView.addSubview(pageLabel)

        pageNumberField = NSTextField(frame: NSRect(x: 110, y: 58, width: 80, height: 24))
        pageNumberField.placeholderString = "Page #"
        pageNumberField.target = self
        pageNumberField.action = #selector(goToPage)
        contentView.addSubview(pageNumberField)

        goToPageButton = NSButton(title: "Go", target: self, action: #selector(goToPage))
        goToPageButton.frame = NSRect(x: 200, y: 58, width: 60, height: 28)
        goToPageButton.bezelStyle = .rounded
        contentView.addSubview(goToPageButton)

        pageInfoLabel = NSTextField(labelWithString: "")
        pageInfoLabel.frame = NSRect(x: 270, y: 60, width: 230, height: 20)
        pageInfoLabel.alignment = .left
        pageInfoLabel.isEditable = false
        pageInfoLabel.isBordered = false
        pageInfoLabel.backgroundColor = .clear
        contentView.addSubview(pageInfoLabel)

        // Update page info when panel is shown
        updatePageInfo()

        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: 20, y: 20, width: 480, height: 20)
        statusLabel.alignment = .center
        contentView.addSubview(statusLabel)
    }

    private func applyTheme() {
        guard let panel = window as? NSPanel,
              let contentView = panel.contentView else { return }

        let theme = ThemeManager.shared.currentTheme

        // Ensure native controls render appropriately for dark/light modes.
        let isDarkMode = ThemeManager.shared.isDarkMode
        panel.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Apply background color
        contentView.layer?.backgroundColor = theme.popoutBackground.cgColor

        let inputFields: [NSTextField] = [searchField, replaceField, pageNumberField].compactMap { $0 }
        for field in inputFields {
            styleInputField(field, theme: theme)
        }

        let actionButtons: [NSButton] = [findPreviousButton, findNextButton, replaceButton, replaceAllButton, goToPageButton].compactMap { $0 }
        for button in actionButtons {
            styleActionButton(button, theme: theme)
        }

        let checkboxTitleAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: theme.textColor]
        caseSensitiveCheckbox.attributedTitle = NSAttributedString(string: caseSensitiveCheckbox.title, attributes: checkboxTitleAttributes)
        wholeWordsCheckbox.attributedTitle = NSAttributedString(string: wholeWordsCheckbox.title, attributes: checkboxTitleAttributes)

        // Tint the checkbox control (avoid system accent blue in light mode).
        caseSensitiveCheckbox.contentTintColor = theme.pageBorder
        wholeWordsCheckbox.contentTintColor = theme.pageBorder

        // Apply text colors to labels
        contentView.subviews.forEach { view in
            if let textField = view as? NSTextField, !textField.isEditable {
                textField.textColor = theme.textColor
            }
        }

        // Status label uses secondary color
        statusLabel.textColor = theme.textColor.withAlphaComponent(0.7)
    }

    @objc private func findNext() {
        guard let editor = editorViewController else { return }
        let searchText = searchField.stringValue
        guard !searchText.isEmpty else {
            statusLabel.stringValue = "Enter text to search"
            return
        }

        let found = editor.findNext(
            searchText,
            forward: true,
            caseSensitive: caseSensitiveCheckbox.state == .on,
            wholeWords: wholeWordsCheckbox.state == .on
        )

        statusLabel.stringValue = found ? "Found" : "Not found"
    }

    @objc private func findPrevious() {
        guard let editor = editorViewController else { return }
        let searchText = searchField.stringValue
        guard !searchText.isEmpty else {
            statusLabel.stringValue = "Enter text to search"
            return
        }

        let found = editor.findNext(
            searchText,
            forward: false,
            caseSensitive: caseSensitiveCheckbox.state == .on,
            wholeWords: wholeWordsCheckbox.state == .on
        )

        statusLabel.stringValue = found ? "Found" : "Not found"
    }

    @objc private func replace() {
        guard let editor = editorViewController else { return }
        let searchText = searchField.stringValue
        let replaceText = replaceField.stringValue
        guard !searchText.isEmpty else {
            statusLabel.stringValue = "Enter text to search"
            return
        }

        let replaced = editor.replaceSelection(
            searchText,
            with: replaceText,
            caseSensitive: caseSensitiveCheckbox.state == .on
        )

        if replaced {
            statusLabel.stringValue = "Replaced"
            // Find next after replacing
            findNext()
        } else {
            statusLabel.stringValue = "Selection doesn't match search text"
        }
    }

    @objc private func replaceAll() {
        guard let editor = editorViewController else { return }
        let searchText = searchField.stringValue
        let replaceText = replaceField.stringValue
        guard !searchText.isEmpty else {
            statusLabel.stringValue = "Enter text to search"
            return
        }

        let count = editor.replaceAll(
            searchText,
            with: replaceText,
            caseSensitive: caseSensitiveCheckbox.state == .on,
            wholeWords: wholeWordsCheckbox.state == .on
        )

        statusLabel.stringValue = count > 0 ? "Replaced \(count) occurrence\(count == 1 ? "" : "s")" : "No matches found"
    }

    @objc private func goToPage() {
        guard let editor = editorViewController else { return }

        let pageNumberString = pageNumberField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !pageNumberString.isEmpty else {
            statusLabel.stringValue = "Enter a page number"
            return
        }

        guard let pageNumber = Int(pageNumberString) else {
            statusLabel.stringValue = "Invalid page number"
            return
        }

        let success = editor.goToPage(pageNumber)
        if success {
            statusLabel.stringValue = "Navigated to page \(pageNumber)"
            updatePageInfo()
        } else {
            let pageInfo = editor.getCurrentPageInfo()
            statusLabel.stringValue = "Page \(pageNumber) is out of range (1-\(pageInfo.total))"
        }
    }

    private func updatePageInfo() {
        guard let editor = editorViewController else {
            pageInfoLabel.stringValue = ""
            return
        }

        let pageInfo = editor.getCurrentPageInfo()
        pageInfoLabel.stringValue = "Current: \(pageInfo.current) of \(pageInfo.total)"
    }

    func updatePageInfoBeforeShow() {
        updatePageInfo()
    }

    func clearFields() {
        searchField.stringValue = ""
        replaceField.stringValue = ""
        statusLabel.stringValue = ""
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        applyTheme()
        updatePageInfo()
        // Make the search field first responder to accept input immediately
        window?.makeFirstResponder(searchField)
    }
}
