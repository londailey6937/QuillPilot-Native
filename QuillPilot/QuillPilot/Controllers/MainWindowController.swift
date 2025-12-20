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
    func formattingToolbarDidIndent(_ toolbar: FormattingToolbar)
    func formattingToolbarDidOutdent(_ toolbar: FormattingToolbar)
    func formattingToolbarDidSave(_ toolbar: FormattingToolbar)

    func formattingToolbar(_ toolbar: FormattingToolbar, didSelectStyle styleName: String)

    func formattingToolbarDidToggleBold(_ toolbar: FormattingToolbar)
    func formattingToolbarDidToggleItalic(_ toolbar: FormattingToolbar)
    func formattingToolbarDidToggleUnderline(_ toolbar: FormattingToolbar)

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

    func formattingToolbarDidOpenStyleEditor(_ toolbar: FormattingToolbar)
}

class MainWindowController: NSWindowController {
    private var activePrintOperation: NSPrintOperation?

    private var headerView: HeaderView!
    private var toolbarView: FormattingToolbar!
    private var rulerView: EnhancedRulerView!
    private var mainContentViewController: ContentViewController!
    private var themeObserver: NSObjectProtocol?
    private var headerFooterSettingsWindow: HeaderFooterSettingsWindow?
    private var styleEditorWindow: StyleEditorWindowController?
    private var searchPanel: SearchPanelController?

    // Document tracking for auto-save
    private var currentDocumentURL: URL?
    private var currentDocumentFormat: ExportFormat = .docx

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

        window.title = "QuillPilot"
        window.minSize = NSSize(width: 900, height: 650)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.center()

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let window = window else { return }

        // Create main container view sized to the current content rect
        let initialBounds = window.contentView?.bounds ?? NSRect(origin: .zero, size: window.contentLayoutRect.size)
        let containerView = NSView(frame: initialBounds)
        containerView.autoresizingMask = [.width, .height]
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = ThemeManager.shared.currentTheme.pageAround.cgColor

        // Create header (logo, title, specs, login) - 60px tall
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
        rulerView.pageWidth = 857 // Match page container width
        rulerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(rulerView)

        // Create 3-column content area (outline | editor | analysis)
        mainContentViewController = ContentViewController()
        mainContentViewController.onTitleChange = { [weak self] title in
            self?.headerView.setDocumentTitle(title)
        }
        mainContentViewController.onStatsUpdate = { [weak self] text in
            self?.headerView.specsPanel.updateStats(text: text)
        }
        mainContentViewController.onSelectionChange = { [weak self] styleName in
            self?.toolbarView.updateSelectedStyle(styleName)
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
            contentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ]

        if let editorLeading = mainContentViewController.editorLeadingAnchor,
           let editorTrailing = mainContentViewController.editorTrailingAnchor {
            // Keep the ruler aligned to the editor page (not the full 3-column content area).
            let editorCenter = mainContentViewController.editorCenterXAnchor ?? contentView.centerXAnchor
            constraints.append(rulerView.centerXAnchor.constraint(equalTo: editorCenter))
            constraints.append(rulerView.widthAnchor.constraint(equalToConstant: rulerView.pageWidth))
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
        }
    }

    private func applyTheme(_ theme: AppTheme) {
        guard let containerLayer = window?.contentView?.layer else { return }
        containerLayer.backgroundColor = theme.pageAround.cgColor
        containerLayer.setNeedsDisplay()

        headerView.applyTheme(theme)
        toolbarView.applyTheme(theme)
        rulerView.applyTheme(theme)
        mainContentViewController.applyTheme(theme)
    }

    private func showSearchPanel() {
        if searchPanel == nil {
            searchPanel = SearchPanelController()
            searchPanel?.editorViewController = mainContentViewController.editorViewController
        }
        searchPanel?.showWindow(nil)
        searchPanel?.window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Print
    @MainActor
    @objc func printDocument(_ sender: Any?) {
        NSLog("=== MainWindowController.printDocument called ===")
        NSLog("STACK TRACE:")
        Thread.callStackSymbols.forEach { NSLog("  \($0)") }
        NSLog("Sender: \(String(describing: sender))")

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
        NSLog("Preparing print. pageContainer frame: \(pageContainer.frame) bounds: \(pageContainer.bounds) inWindow: \(hasWindow)")
        guard hasWindow else {
            presentErrorAlert(message: "Print Failed", details: "Document view is not in a window")
            return
        }

        // Ask AppKit to present the native print panel for the laid-out pageContainer
        let printInfoCopy = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfoCopy.jobDisposition = .spool

        let printers = NSPrinter.printerNames
        NSLog("Available printers: \(printers)")

        // Try the user-reported printer name first
        if let userPrinter = NSPrinter(name: "HP LaserJet M110w (8C17D0)") {
            printInfoCopy.printer = userPrinter
            NSLog("Using user-specified printer: HP LaserJet M110w (8C17D0)")
        } else if let hp = printers.first(where: { $0.localizedCaseInsensitiveContains("HP") }) ?? printers.first,
                  let chosen = NSPrinter(name: hp) {
            printInfoCopy.printer = chosen
            NSLog("Using discovered printer: \(hp)")
        } else {
            NSLog("No printer assigned; proceeding with default printInfo.printer")
        }

        let printOperation = NSPrintOperation(view: pageContainer, printInfo: printInfoCopy)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.printPanel.options = [.showsPreview, .showsPrintSelection, .showsPageSetupAccessory, .showsOrientation, .showsPaperSize, .showsScaling]

        activePrintOperation = printOperation // keep alive while printing
        let printerName = printOperation.printInfo.printer.name
        NSLog("Starting print operation (printer: \(printerName), shows panel: \(printOperation.showsPrintPanel), shows progress: \(printOperation.showsProgressPanel))")
        let success = printOperation.run()
        NSLog("NSPrintOperation.run returned: \(success)")
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
            headerText: editorVC.headerText,
            footerText: editorVC.footerText
        )

        settingsWindow.onApply = { [weak self, weak editorVC] showHeaders, showFooters, showPageNumbers, headerText, footerText in
            editorVC?.showHeaders = showHeaders
            editorVC?.showFooters = showFooters
            editorVC?.showPageNumbers = showPageNumbers
            editorVC?.headerText = headerText
            editorVC?.footerText = footerText
            editorVC?.updatePageCentering()
            self?.headerFooterSettingsWindow = nil
        }

        settingsWindow.onCancel = { [weak self] in
            self?.headerFooterSettingsWindow = nil
        }

        settingsWindow.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }
}

// MARK: - Menu Item Validation
extension MainWindowController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(printDocument(_:)) {
            let isValid = mainContentViewController != nil
            NSLog("MainWindowController validateMenuItem for Print: \(isValid)")
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

        let deleteBtn = NSButton(title: "Delete Column at Cursor", target: nil, action: nil)
        deleteBtn.bezelStyle = .rounded
        deleteBtn.contentTintColor = theme.headerBackground
        stackView.addArrangedSubview(deleteBtn)

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

        // Hook up actions
        setBtn.target = self
        setBtn.action = #selector(handleSetColumnsFromSheet(_:))

        insertBtn.target = self
        insertBtn.action = #selector(handleInsertColumnFromSheet)

        deleteBtn.target = self
        deleteBtn.action = #selector(handleDeleteColumnFromDialog)

        doneBtn.target = self
        doneBtn.action = #selector(handleCloseColumnsSheet(_:))

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
        mainContentViewController.toggleBulletedList()
    }

    func formattingToolbarDidToggleNumbering(_ toolbar: FormattingToolbar) {
        mainContentViewController.toggleNumberedList()
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

    @objc private func handleDeleteColumnFromDialog() {
        mainContentViewController.editorViewController.deleteColumnAtCursor()
    }

    @objc private func handleSetColumnsFromSheet(_ sender: NSButton) {
        guard let columnsField = self.columnsSheetField else { return }
        let clamped = max(2, min(4, Int(columnsField.stringValue) ?? 2))
        NSLog("handleSetColumnsFromSheet: field value='\(columnsField.stringValue)' clamped=\(clamped)")

        // Close sheet first, then insert after window becomes key
        if let window = sender.window {
            self.window?.endSheet(window)
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

    @objc private func handleCloseColumnsSheet(_ sender: NSButton) {
        guard let window = sender.window else { return }
        let clamped = max(2, min(4, Int(self.columnsSheetField?.stringValue ?? "2") ?? 2))
        NSLog("handleCloseColumnsSheet: field value='\(self.columnsSheetField?.stringValue ?? "nil")' clamped=\(clamped)")

        self.window?.endSheet(window)
        self.columnsSheetField = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.mainContentViewController.editorViewController.setColumnCount(clamped)
        }
    }

    @objc private func handleInsertTableFromSheet(_ sender: NSButton) {
        guard let rowsField = self.tableRowsSheetField,
              let colsField = self.tableColsSheetField else { return }

        let rows = max(1, min(10, Int(rowsField.stringValue) ?? 3))
        let cols = max(1, min(6, Int(colsField.stringValue) ?? 3))
        NSLog("handleInsertTableFromSheet: rows='\(rowsField.stringValue)'->\(rows) cols='\(colsField.stringValue)'->\(cols)")

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
        let rows = max(1, min(10, Int(self.tableRowsSheetField?.stringValue ?? "3") ?? 3))
        let cols = max(1, min(6, Int(self.tableColsSheetField?.stringValue ?? "3") ?? 3))
        NSLog("handleCloseTableSheet: rows='\(self.tableRowsSheetField?.stringValue ?? "nil")'->\(rows) cols='\(self.tableColsSheetField?.stringValue ?? "nil")'->\(cols)")

        self.window?.endSheet(window)
        self.tableRowsSheetField = nil
        self.tableColsSheetField = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.mainContentViewController.editorViewController.insertTable(rows: rows, columns: cols)
        }
    }

    @objc private func handleAddTableRow() {
        mainContentViewController.editorViewController.addTableRow()
    }

    @objc private func handleAddTableColumn() {
        mainContentViewController.editorViewController.addTableColumn()
    }

    @objc private func handleDeleteTableRow() {
        mainContentViewController.editorViewController.deleteTableRow()
    }

    @objc private func handleDeleteTableColumn() {
        mainContentViewController.editorViewController.deleteTableColumn()
    }

    @objc private func handleDeleteTable() {
        mainContentViewController.editorViewController.deleteTable()
    }

    func formattingToolbarDidClearAll(_ toolbar: FormattingToolbar) {
        let alert = NSAlert()
        alert.messageText = "Clear All"
        alert.informativeText = "This will remove all text and formatting. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            mainContentViewController.editorViewController.clearAll()
        }
    }

    func formattingToolbarDidFormatPainter(_ toolbar: FormattingToolbar) {
        mainContentViewController.editorViewController.toggleFormatPainter()
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

    func performSaveAs(_ sender: Any?) {
        guard let window else { return }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = "Save"

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        ExportFormat.allCases.forEach { popup.addItem(withTitle: $0.displayName) }

        // Default to .docx format
        let defaultFormat: ExportFormat = .docx
        let defaultIndex = ExportFormat.allCases.firstIndex(of: defaultFormat) ?? 0
        popup.selectItem(at: defaultIndex)

        let accessory = NSStackView(views: [NSTextField(labelWithString: "Format:"), popup])
        accessory.orientation = .horizontal
        accessory.spacing = 8
        panel.accessoryView = accessory

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
        }
    }

    private func saveToURL(_ url: URL, format: ExportFormat) {
        do {
            switch format {
            case .docx:
                // Export to DOCX
                let stamped = stampImageSizes(in: mainContentViewController.editorExportReadyAttributedContent())
                let data = try DocxBuilder.makeDocxData(from: stamped)
                try data.write(to: url, options: .atomic)
                NSLog("✅ DOCX exported to \(url.path)")

            case .rtf:
                // Export to RTF (text only, images stripped)
                let content = mainContentViewController.editorExportReadyAttributedContent()
                let fullRange = NSRange(location: 0, length: content.length)
                let data = try content.data(from: fullRange, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                try data.write(to: url, options: .atomic)
                NSLog("✅ RTF exported to \(url.path)")

            case .pdf:
                // Export to PDF
                let data = mainContentViewController.editorPDFData()
                try data.write(to: url, options: .atomic)
                NSLog("✅ PDF exported to \(url.path)")
            }
        } catch {
            NSLog("❌ Save failed: \(error.localizedDescription)")
            self.presentErrorAlert(message: "Save failed", details: error.localizedDescription)
        }
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
                    NSLog("📷 Restored image size: \(storedBounds.width) x \(storedBounds.height)")
                }
            } else if let filename = attachment.fileWrapper?.preferredFilename,
                      let parsedSize = parseImageSize(from: filename) {
                let bounds = CGRect(origin: .zero, size: parsedSize)
                attachment.bounds = bounds
                NSLog("📷 Restored image size from filename: \(bounds.width) x \(bounds.height)")
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
        NSLog("MainWindowController.performOpenDocument called")
        guard let window else {
            NSLog("ERROR: window is nil in performOpenDocument")
            return
        }

        NSLog("Creating NSOpenPanel")
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

        // If we have types, use them; otherwise allow all
        if !allowedTypes.isEmpty {
            panel.allowedContentTypes = allowedTypes
        }

        NSLog("Allowed content types: \(allowedTypes.map { $0.identifier })")

        panel.beginSheetModal(for: window) { response in
            NSLog("Open panel response: \(response.rawValue)")
            guard response == .OK, let url = panel.url else { return }
            NSLog("About to import file: \(url.path)")
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

    private func exportData(format: ExportFormat) throws -> Data {
        switch format {
        case .rtf:
            let content = mainContentViewController.editorExportReadyAttributedContent()
            let fullRange = NSRange(location: 0, length: content.length)
            return try content.data(from: fullRange, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        case .pdf:
            return mainContentViewController.editorPDFData()
        case .docx:
            let stamped = stampImageSizes(in: mainContentViewController.editorExportReadyAttributedContent())
            return try DocxBuilder.makeDocxData(from: stamped)
        }
    }

    private func importFile(url: URL) throws {
        NSLog("=== importFile called with: \(url.path) ===")
        let ext = url.pathExtension.lowercased()
        NSLog("File extension: \(ext)")

        // Support .docx Word documents
        switch ext {
        case "docx":
            // Import Word document
            let filename = url.deletingPathExtension().lastPathComponent
            headerView.setDocumentTitle(filename)
            currentDocumentURL = url
            currentDocumentFormat = .docx
            mainContentViewController.editorViewController.headerText = ""
            mainContentViewController.editorViewController.footerText = ""

            // Show placeholder text immediately so user sees the app is working
            mainContentViewController.editorViewController.textView?.string = "Loading document..."

            // Get file size for logging
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            NSLog("📄 File size: \(fileSize) bytes (\(fileSize / 1024 / 1024) MB)")

            // Parse in background, set content directly on main thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                NSLog("📄 Starting DOCX extraction for: \(url.lastPathComponent)")
                let startTime = CFAbsoluteTimeGetCurrent()
                do {
                    NSLog("📄 Reading file data...")
                    let data = try Data(contentsOf: url)
                    NSLog("📄 File data read: \(data.count) bytes in \(CFAbsoluteTimeGetCurrent() - startTime)s")

                    let parseStart = CFAbsoluteTimeGetCurrent()
                    NSLog("📄 Starting XML parsing...")
                    let attributedString = try DocxTextExtractor.extractAttributedString(fromDocxData: data)
                    NSLog("📄 Parsing complete: \(attributedString.length) chars in \(CFAbsoluteTimeGetCurrent() - parseStart)s")

                    let restoreStart = CFAbsoluteTimeGetCurrent()
                    let restored = self?.restoreImageSizes(in: attributedString) ?? attributedString
                    NSLog("📄 Image restore took \(CFAbsoluteTimeGetCurrent() - restoreStart)s")

                    NSLog("📄 Total extraction time: \(CFAbsoluteTimeGetCurrent() - startTime)s")

                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        NSLog("📄 Setting content on main thread, length: \(restored.length)")
                        let setStart = CFAbsoluteTimeGetCurrent()
                        self.mainContentViewController.editorViewController.setAttributedContentDirect(restored)
                        NSLog("📄 Content set complete in \(CFAbsoluteTimeGetCurrent() - setStart)s")
                    }
                } catch {
                    NSLog("📄 DOCX extraction failed: \(error)")
                    DispatchQueue.main.async {
                        self?.presentErrorAlert(message: "Failed to open Word document", details: error.localizedDescription)
                    }
                }
            }

        default:
            presentErrorAlert(
                message: "Unsupported format",
                details: "QuillPilot opens .docx documents.\n\nUse Export to save as .rtf or .pdf."
            )
            return
        }
    }

    private func presentErrorAlert(message: String, details: String) {
        guard let window else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = details
        alert.beginSheetModal(for: window)
    }

    private enum AssociatedKeys {
        static var savePanelKey: UInt8 = 0
    }
}

// MARK: - Header View (Logo, Title, Specs, Login)
class HeaderView: NSView {

    private var logoView: AnimatedLogoView!
    private var titleLabel: NSTextField!
    var specsPanel: DocumentInfoPanel!
    private var themeToggle: NSButton!
    private var loginButton: NSButton!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true

        // Animated logo (left)
        logoView = AnimatedLogoView()
        logoView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logoView)

        // Title
        titleLabel = NSTextField(labelWithString: "QuillPilot")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .medium)
        titleLabel.textColor = ThemeManager.shared.currentTheme.headerText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Specs panel (word count, page count, etc.)
        specsPanel = DocumentInfoPanel()
        specsPanel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(specsPanel)

        // Day/Night toggle button
        themeToggle = NSButton(title: "☀️", target: self, action: #selector(HeaderView.toggleTheme(_:)))
        themeToggle.bezelStyle = .rounded
        themeToggle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(themeToggle)

        // Login button (right)
        loginButton = NSButton(title: "Login", target: nil, action: nil)
        loginButton.bezelStyle = .rounded
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(loginButton)

        NSLayoutConstraint.activate([
            // Logo at left
            logoView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            logoView.centerYAnchor.constraint(equalTo: centerYAnchor),
            logoView.widthAnchor.constraint(equalToConstant: 40),
            logoView.heightAnchor.constraint(equalToConstant: 40),

            // Title next to logo
            titleLabel.leadingAnchor.constraint(equalTo: logoView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            // Specs panel centered in header
            specsPanel.centerXAnchor.constraint(equalTo: centerXAnchor),
            specsPanel.centerYAnchor.constraint(equalTo: centerYAnchor),
            specsPanel.widthAnchor.constraint(lessThanOrEqualToConstant: 500),

            // Theme toggle before login
            themeToggle.trailingAnchor.constraint(equalTo: loginButton.leadingAnchor, constant: -12),
            themeToggle.centerYAnchor.constraint(equalTo: centerYAnchor),

            // Login button at right
            loginButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            loginButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        applyTheme(ThemeManager.shared.currentTheme)
    }

    @objc func toggleTheme(_ sender: Any?) {
        ThemeManager.shared.toggleTheme()
        print("Theme toggled to: \(ThemeManager.shared.currentTheme)")
    }

    func applyTheme(_ theme: AppTheme) {
        wantsLayer = true
        layer?.backgroundColor = theme.headerBackground.cgColor
        titleLabel.textColor = theme.headerText
        themeToggle.title = theme == .day ? "☀️" : "🌙"
        themeToggle.contentTintColor = theme.headerText
        let toggleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.headerText,
            .font: themeToggle.font ?? NSFont.systemFont(ofSize: 13)
        ]
        themeToggle.attributedTitle = NSAttributedString(string: themeToggle.title, attributes: toggleAttributes)

        let loginAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.headerText,
            .font: loginButton.font ?? NSFont.systemFont(ofSize: 13)
        ]
        loginButton.attributedTitle = NSAttributedString(string: loginButton.title, attributes: loginAttributes)
        specsPanel.applyTheme(theme)
    }

    func setDocumentTitle(_ title: String) {
        specsPanel.setTitle(title)
    }

    func documentTitle() -> String {
        specsPanel.getTitle()
    }
}

// MARK: - Animated Logo View
class AnimatedLogoView: NSView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw simple quill feather icon
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(ThemeManager.shared.currentTheme.headerBackground.cgColor)

        // Quill shape (simplified)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.width * 0.5, y: bounds.height * 0.1))
        path.line(to: NSPoint(x: bounds.width * 0.7, y: bounds.height * 0.9))
        path.line(to: NSPoint(x: bounds.width * 0.5, y: bounds.height * 0.8))
        path.line(to: NSPoint(x: bounds.width * 0.3, y: bounds.height * 0.9))
        path.close()

        ThemeManager.shared.currentTheme.headerBackground.setFill()
        path.fill()
    }
}

// MARK: - Specs Panel (Word Count, Page Count)

// MARK: - Formatting Toolbar
class FormattingToolbar: NSView {

    weak var delegate: FormattingToolbarDelegate?

    private var themedControls: [NSControl] = []

    private var fontPopup: NSPopUpButton!
    private var stylePopup: NSPopUpButton!
    private var sizePopup: NSPopUpButton!
    private var editStylesButton: NSButton!
    private var imageButton: NSButton!

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

        // Styles popup
        stylePopup = registerControl(NSPopUpButton(frame: .zero, pullsDown: false))
        let stylesMenu = NSMenu()

        func addHeader(_ title: String) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false

            // Create attributed title with background color
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 11),
                .foregroundColor: NSColor.white,
                .backgroundColor: ThemeManager.shared.currentTheme.headerBackground
            ]
            item.attributedTitle = NSAttributedString(string: "  \(title)", attributes: attributes)

            stylesMenu.addItem(item)
        }

        func addStyle(_ title: String) {
            stylesMenu.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: ""))
        }

        addHeader("Fiction")
        [
            "Book Title",
            "Book Subtitle",
            "Author Name",
            "Front Matter Heading",
            "Epigraph",
            "Epigraph Attribution",
            "Part Title",
            "Part Subtitle",
            "Chapter Number",
            "Chapter Title",
            "Chapter Subtitle",
            "Body Text",
            "Body Text – No Indent",
            "Scene Break",
            "Dialogue",
            "Internal Thought",
            "Letter / Document",
            "Block Quote",
            "Block Quote Attribution",
            "Sidebar",
            "Back Matter Heading",
            "Notes Entry",
            "Bibliography Entry",
            "Index Entry"
        ].forEach(addStyle)

        stylesMenu.addItem(.separator())
        addHeader("Non-Fiction")
        [
            "Heading 1",
            "Heading 2",
            "Heading 3",
            "Body Text",
            "Body Text – No Indent",
            "Block Quote",
            "Sidebar",
            "Callout",
            "Figure Caption",
            "Table Caption",
            "Footnote / Endnote",
            "Notes Entry",
            "Bibliography Entry",
            "Index Entry"
        ].forEach(addStyle)

        stylesMenu.addItem(.separator())
        addHeader("Screenplay")
        [
            "Screenplay — Slugline",
            "Screenplay — Action",
            "Screenplay — Character",
            "Screenplay — Parenthetical",
            "Screenplay — Dialogue",
            "Screenplay — Transition",
            "Screenplay — Shot"
        ].forEach(addStyle)

        stylesMenu.addItem(.separator())
        addHeader("Inline")
        [
            "Emphasis (Italic)",
            "Strong (Bold)",
            "Small Caps",
            "Superscript",
            "Subscript"
        ].forEach(addStyle)

        stylePopup.menu = stylesMenu
        stylePopup.selectItem(withTitle: "Body Text")
        stylePopup.translatesAutoresizingMaskIntoConstraints = false
        stylePopup.target = self
        stylePopup.action = #selector(styleChanged(_:))
        stylePopup.toolTip = "Paragraph Style"

        editStylesButton = createToolbarButton("Edit…")
        editStylesButton.target = self
        editStylesButton.action = #selector(openStyleEditorTapped)
        editStylesButton.toolTip = "Open Style Editor"

        // Format painter button
        let formatPainterBtn = createToolbarButton("🖌️")
        formatPainterBtn.target = self
        formatPainterBtn.action = #selector(formatPainterTapped)
        formatPainterBtn.toolTip = "Format Painter (Copy Style)"

        // Font family popup
        fontPopup = registerControl(NSPopUpButton(frame: .zero, pullsDown: false))
        fontPopup.addItems(withTitles: ["Inter", "Georgia", "Times New Roman", "Arial", "Courier New"])
        fontPopup.translatesAutoresizingMaskIntoConstraints = false
        fontPopup.target = self
        fontPopup.action = #selector(fontFamilyChanged(_:))
        fontPopup.toolTip = "Font Family"

        // Font size controls
        let decreaseSizeBtn = registerControl(NSButton(title: "−", target: self, action: #selector(decreaseFontSizeTapped)))
        decreaseSizeBtn.toolTip = "Decrease Font Size"
        sizePopup = registerControl(NSPopUpButton(frame: .zero, pullsDown: false))
        sizePopup.addItems(withTitles: ["8", "9", "10", "11", "12", "14", "16", "18", "20", "24", "28", "32"])
        sizePopup.selectItem(at: 4) // 12pt default
        sizePopup.target = self
        sizePopup.action = #selector(fontSizeChanged(_:))
        sizePopup.toolTip = "Font Size"
        let increaseSizeBtn = registerControl(NSButton(title: "+", target: self, action: #selector(increaseFontSizeTapped)))
        increaseSizeBtn.toolTip = "Increase Font Size"

        // Text styling
        let boldBtn = createToolbarButton("B", weight: .bold)
        let italicBtn = createToolbarButton("I", isItalic: true)
        let underlineBtn = createToolbarButton("U", isUnderlined: true)
        boldBtn.target = self
        boldBtn.action = #selector(boldTapped)
        boldBtn.toolTip = "Bold"
        italicBtn.target = self
        italicBtn.action = #selector(italicTapped)
        italicBtn.toolTip = "Italic"
        underlineBtn.target = self
        underlineBtn.action = #selector(underlineTapped)
        underlineBtn.toolTip = "Underline"

        // Alignment
                let alignLeftBtn = createToolbarButton("≡", fontSize: 20)
                let alignCenterBtn = createToolbarButton("≣", fontSize: 20)
                let alignRightBtn = createToolbarButton("≡", fontSize: 20)
                let justifyBtn = createToolbarButton("≣", fontSize: 20)
                alignLeftBtn.target = self
                alignLeftBtn.action = #selector(alignLeftTapped)
                alignLeftBtn.toolTip = "Align Left"
                alignCenterBtn.target = self
                alignCenterBtn.action = #selector(alignCenterTapped)
                alignCenterBtn.toolTip = "Align Center"
                alignRightBtn.target = self
                alignRightBtn.action = #selector(alignRightTapped)
                alignRightBtn.toolTip = "Align Right"
                justifyBtn.target = self
                justifyBtn.action = #selector(justifyTapped)
                justifyBtn.toolTip = "Justify"

        // Lists
        let bulletsBtn = createToolbarButton("•")
        let numberingBtn = createToolbarButton("1.")
        bulletsBtn.target = self
        bulletsBtn.action = #selector(bulletsTapped)
        bulletsBtn.toolTip = "Bulleted List"
        numberingBtn.target = self
        numberingBtn.action = #selector(numberingTapped)
        numberingBtn.toolTip = "Numbered List"

        // Images
        imageButton = createToolbarButton("⧉", fontSize: 20) // Image silhouette icon
        imageButton.target = self
        imageButton.action = #selector(imageTapped)
        imageButton.toolTip = "Insert Image"

        // Layout
        let columnsBtn = createToolbarButton("⫼", fontSize: 20) // Column icon
        let tableBtn = createToolbarButton("⊞", fontSize: 20) // Table icon

        columnsBtn.target = self
        columnsBtn.action = #selector(columnsTapped)
        columnsBtn.toolTip = "Columns"
        tableBtn.target = self
        tableBtn.action = #selector(tableTapped)
        tableBtn.toolTip = "Table Operations"
        let clearBtn = createToolbarButton("⌧") // Clear icon
        clearBtn.target = self
        clearBtn.action = #selector(clearAllTapped)
        clearBtn.toolTip = "Clear All"

        // Search & Replace
        let searchBtn = createToolbarButton("🔍", fontSize: 16)
        searchBtn.target = self
        searchBtn.action = #selector(searchTapped)
        searchBtn.toolTip = "Find & Replace"

        // Indentation
        let outdentBtn = registerControl(NSButton(title: "⇤", target: self, action: #selector(outdentTapped)))
        outdentBtn.bezelStyle = .texturedRounded
        outdentBtn.toolTip = "Decrease Indent"
        let indentBtn = registerControl(NSButton(title: "⇥", target: self, action: #selector(indentTapped)))
        indentBtn.bezelStyle = .texturedRounded
        indentBtn.toolTip = "Increase Indent"

        // Add all to stack view (all aligned left)
        let toolbarStack = NSStackView(views: [
            stylePopup, editStylesButton, formatPainterBtn, fontPopup, decreaseSizeBtn, sizePopup, increaseSizeBtn,
            boldBtn, italicBtn, underlineBtn,
            alignLeftBtn, alignCenterBtn, alignRightBtn, justifyBtn,
            bulletsBtn, numberingBtn,
            imageButton,
            columnsBtn, tableBtn,
            outdentBtn, indentBtn,
            searchBtn, clearBtn
        ])
        toolbarStack.orientation = .horizontal
        toolbarStack.spacing = 8
        toolbarStack.edgeInsets = NSEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        toolbarStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(toolbarStack)

        NSLayoutConstraint.activate([
            toolbarStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbarStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbarStack.topAnchor.constraint(equalTo: topAnchor),
            toolbarStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func createToolbarButton(_ title: String, weight: NSFont.Weight = .regular, isItalic: Bool = false, isUnderlined: Bool = false, fontSize: CGFloat = 14) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .texturedRounded
        button.setButtonType(.momentaryPushIn)

        var font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        if isItalic {
            font = NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(.italic), size: fontSize) ?? font
        }
        button.font = font
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
        themedControls.forEach { control in
            if let button = control as? NSButton {
                button.contentTintColor = theme.textColor
                let currentFontSize = button.font?.pointSize ?? 14
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: theme.textColor,
                    .font: button.font ?? NSFont.systemFont(ofSize: currentFontSize)
                ]
                button.attributedTitle = NSAttributedString(string: button.title, attributes: attributes)
            } else if let popup = control as? NSPopUpButton {
                popup.contentTintColor = theme.textColor
                if let selectedItem = popup.selectedItem {
                    let attributes: [NSAttributedString.Key: Any] = [
                        .foregroundColor: theme.textColor,
                        .font: popup.font ?? NSFont.systemFont(ofSize: 13)
                    ]
                    selectedItem.attributedTitle = NSAttributedString(string: selectedItem.title, attributes: attributes)
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
        delegate?.formattingToolbar(self, didSelectStyle: sender.titleOfSelectedItem ?? "")
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

    @objc private func clearAllTapped() {
        delegate?.formattingToolbarDidClearAll(self)
    }

    @objc private func searchTapped() {
        // Post notification to show search panel
        NotificationCenter.default.post(name: NSNotification.Name("ShowSearchPanel"), object: nil)
    }

    @objc private func fontFamilyChanged(_ sender: NSPopUpButton) {
        guard let family = sender.titleOfSelectedItem, !family.isEmpty else { return }
        delegate?.formattingToolbar(self, didChangeFontFamily: family)
    }

    @objc private func fontSizeChanged(_ sender: NSPopUpButton) {
        guard let title = sender.titleOfSelectedItem, let size = Double(title) else { return }
        delegate?.formattingToolbar(self, didChangeFontSize: CGFloat(size))
    }

    @objc private func decreaseFontSizeTapped() {
        let currentIndex = sizePopup.indexOfSelectedItem
        guard currentIndex > 0 else { return }
        sizePopup.selectItem(at: currentIndex - 1)
        fontSizeChanged(sizePopup)
    }

    @objc private func increaseFontSizeTapped() {
        let currentIndex = sizePopup.indexOfSelectedItem
        guard currentIndex >= 0, currentIndex + 1 < sizePopup.numberOfItems else { return }
        sizePopup.selectItem(at: currentIndex + 1)
        fontSizeChanged(sizePopup)
    }

    func updateSelectedStyle(_ styleName: String?) {
        guard let styleName = styleName else {
            // If no style found, select the first item (typically "Normal")
            stylePopup.selectItem(at: 0)
            return
        }

        // Try to find and select the matching style in the popup
        if let index = (0..<stylePopup.numberOfItems).first(where: { stylePopup.item(at: $0)?.title == styleName }) {
            stylePopup.selectItem(at: index)
        }
    }
}

// MARK: - Ruler View

// MARK: - Content View Controller (3-column layout)
class ContentViewController: NSViewController {
    var onTitleChange: ((String) -> Void)?
    var onStatsUpdate: ((String) -> Void)?
    var onSelectionChange: ((String?) -> Void)?

    private var outlineViewController: OutlineViewController!
    private var outlinePanelController: AnalysisViewController!
    var editorViewController: EditorViewController!
    private var analysisViewController: AnalysisViewController!
    private var backToTopButton: NSButton!

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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        NotificationCenter.default.addObserver(forName: Notification.Name("QuillPilotOutlineRefresh"), object: nil, queue: .main) { [weak self] _ in
            self?.refreshOutline()
        }
        refreshOutline()
    }

    private func setupLayout() {
        // Create 3-column split view
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitView)

        // Left: Mirrored analysis shell showing the outline (📝)
        outlineViewController = OutlineViewController()
        outlineViewController.onSelect = { [weak self] entry in
            self?.scrollToOutlineEntry(entry)
        }
        outlinePanelController = AnalysisViewController()
        outlinePanelController.isOutlinePanel = true
        outlinePanelController.outlineViewController = outlineViewController
        splitView.addArrangedSubview(outlinePanelController.view)
        outlinePanelController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
        outlinePanelController.view.widthAnchor.constraint(lessThanOrEqualToConstant: 360).isActive = true

        // Center: Editor
        editorViewController = EditorViewController()
        editorViewController.delegate = self
        splitView.addArrangedSubview(editorViewController.view)
        editorViewController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: 450).isActive = true
        splitView.setHoldingPriority(.defaultLow - 1, forSubviewAt: 1)

        // Right: Analysis panel
        analysisViewController = AnalysisViewController()
        splitView.addArrangedSubview(analysisViewController.view)
        analysisViewController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: 250).isActive = true
        analysisViewController.view.widthAnchor.constraint(lessThanOrEqualToConstant: 400).isActive = true

        // Set up analysis callback
        analysisViewController.analyzeCallback = { [weak self] in
            NSLog("🔗 Analysis callback triggered")
            self?.performAnalysis()
        }

        // Encourage symmetric sidebars so the editor column (and page) stays centered in the window.
        let equalSidebarWidths = outlinePanelController.view.widthAnchor.constraint(equalTo: analysisViewController.view.widthAnchor)
        equalSidebarWidths.priority = .defaultHigh
        equalSidebarWidths.isActive = true
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

            backToTopButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            backToTopButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
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
        guard let textView = editorViewController.textView else { return }
        textView.scrollRangeToVisible(entry.range)
        textView.showFindIndicator(for: entry.range)
    }

    func applyTheme(_ theme: AppTheme) {
        outlineViewController?.applyTheme(theme)
        editorViewController?.applyTheme(theme)
        analysisViewController?.applyTheme(theme)
        view.wantsLayer = true
        view.layer?.backgroundColor = theme.pageAround.cgColor
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

    private func applyRulerToEditor(_ ruler: EnhancedRulerView) {
        editorViewController.setPageMargins(left: ruler.leftMargin, right: ruler.rightMargin)
        editorViewController.setFirstLineIndent(ruler.firstLineIndent)
    }

    private var isAnalyzing = false

    private func performAnalysis() {
        NSLog("🔍 performAnalysis called in ContentViewController")

        // Skip if already analyzing to prevent queue buildup
        guard !isAnalyzing else {
            NSLog("⏸️ Analysis already in progress, skipping")
            return
        }

        guard let text = editorViewController.getTextContent(), !text.isEmpty else {
            NSLog("⚠️ No text to analyze")
            return
        }

        isAnalyzing = true

        // Run analysis on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let analysisEngine = AnalysisEngine()
            let results = analysisEngine.analyzeText(text)

            NSLog("📊 Analysis results: \(results.wordCount) words, \(results.sentenceCount) sentences, \(results.paragraphCount) paragraphs")

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
        applyRulerToEditor(ruler)
    }

    func rulerView(_ ruler: EnhancedRulerView, didChangeRightMargin: CGFloat) {
        applyRulerToEditor(ruler)
    }

    func rulerView(_ ruler: EnhancedRulerView, didChangeFirstLineIndent: CGFloat) {
        applyRulerToEditor(ruler)
    }
}

// MARK: - Outline View Controller
class OutlineViewController: NSViewController {
    final class Node: NSObject {
        let title: String
        let level: Int
        let page: Int?
        let range: NSRange
        var children: [Node]

        init(title: String, level: Int, page: Int?, range: NSRange, children: [Node] = []) {
            self.title = title
            self.level = level
            self.page = page
            self.range = range
            self.children = children
        }
    }

    var onSelect: ((EditorViewController.OutlineEntry) -> Void)?
    private var roots: [Node] = []

    private var headerLabel: NSTextField!
    private var refreshButton: NSButton!
    private var outlineView: NSOutlineView!

    private let levelColors: [NSColor] = [
        NSColor(calibratedRed: 0.18, green: 0.33, blue: 0.61, alpha: 1.0), // Part
        NSColor(calibratedRed: 0.09, green: 0.52, blue: 0.52, alpha: 1.0), // Chapter / H1
        NSColor(calibratedWhite: 0.2, alpha: 1.0),                         // H2
        NSColor(calibratedWhite: 0.35, alpha: 1.0)                         // H3+
    ]

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true

        headerLabel = NSTextField(labelWithString: "Document Outline")
        headerLabel.font = NSFont.boldSystemFont(ofSize: 14)

        refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshTapped))
        refreshButton.bezelStyle = .rounded

        let headerStack = NSStackView(views: [headerLabel, NSView(), refreshButton])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 8
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerStack)

        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.rowSizeStyle = .small
        outlineView.delegate = self
        outlineView.dataSource = self

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
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])

        applyTheme(ThemeManager.shared.currentTheme)
    }

    func update(with entries: [EditorViewController.OutlineEntry]) {
        roots = buildTree(from: entries)
        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: true)
    }

    private func buildTree(from entries: [EditorViewController.OutlineEntry]) -> [Node] {
        var stack: [Node] = []
        var roots: [Node] = []

        for entry in entries {
            let node = Node(title: entry.title, level: entry.level, page: entry.page, range: entry.range)

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
        view.wantsLayer = true
        view.layer?.backgroundColor = theme.outlineBackground.cgColor
        headerLabel.textColor = theme.textColor
        outlineView.backgroundColor = theme.outlineBackground
    }

    @objc private func refreshTapped() {
        // The content controller will rebuild and call update(with:)
        NotificationCenter.default.post(name: Notification.Name("QuillPilotOutlineRefresh"), object: nil)
    }
}

extension OutlineViewController: NSOutlineViewDataSource, NSOutlineViewDelegate {
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
            pageField.textColor = NSColor.secondaryLabelColor

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

        let color = levelColors[min(node.level, levelColors.count - 1)]
        let fontSize: CGFloat = node.level == 0 ? 13 : (node.level == 1 ? 12 : 11)
        titleField.font = NSFont.systemFont(ofSize: fontSize, weight: node.level <= 1 ? .semibold : .regular)
        titleField.textColor = color
        titleField.stringValue = node.title

        if let page = node.page {
            pageField?.stringValue = "p. \(page)"
        } else {
            pageField?.stringValue = ""
        }

        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = outlineView.selectedRow
        guard selectedRow >= 0, let node = outlineView.item(atRow: selectedRow) as? Node else { return }
        let entry = EditorViewController.OutlineEntry(title: node.title, level: node.level, range: node.range, page: node.page)
        onSelect?(entry)
    }
}

// MARK: - Export Formats
private enum ExportFormat: CaseIterable {
    case docx       // Full support (save + open)
    case rtf        // Export only
    case pdf        // Export only

    var displayName: String {
        switch self {
        case .docx: return "Word Document (.docx)"
        case .rtf: return "Rich Text (.rtf)"
        case .pdf: return "PDF Document (.pdf)"
        }
    }

    var fileExtension: String {
        switch self {
        case .docx: return "docx"
        case .rtf: return "rtf"
        case .pdf: return "pdf"
        }
    }

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
        case .pdf:
            return [.pdf]
        }
    }

    /// Whether this format can be opened (not just exported)
    var canOpen: Bool {
        switch self {
        case .docx: return true
        case .rtf, .pdf: return false
        }
    }
}

// MARK: - DOCX Style Sheet Builder
private enum StyleSheetBuilder {
    static func makeStylesXml() -> String {
        let catalog = StyleCatalog.shared
        let names = catalog.styleNames(for: catalog.currentTemplateName)

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
            guard let def = catalog.style(named: name) else { continue }
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
        let stylesXml = StyleSheetBuilder.makeStylesXml()

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
        return """
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"
                    xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\"
                    xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"
                    xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\"
                    xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">
          <w:body>
            \(body)
            <w:sectPr/>
          </w:body>
        </w:document>
        """
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

                let runs = makeRuns(from: attributed, in: contentRange, images: &images)
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
                let runs = makeRuns(from: attributed, in: contentRange, images: &images)
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

        let escapedText = xmlEscape(text)
        return """
        <w:r>
          \(rPrXml)<w:t xml:space=\"preserve\">\(escapedText)</w:t>
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
    static func extractAttributedString(fromDocxFileURL url: URL) throws -> NSAttributedString {
        let data = try Data(contentsOf: url)
        return try extractAttributedString(fromDocxData: data)
    }

    static func extractAttributedString(fromDocxData data: Data) throws -> NSAttributedString {
        let documentXml = try ZipReader.extractFile(named: "word/document.xml", fromZipData: data)

        NSLog("📄 Extracted document.xml: \(documentXml.count) bytes")

        // Clean the XML data by removing invalid control characters that cause parse errors
        let cleanedXml = cleanXMLData(documentXml)

        NSLog("📄 After cleaning: \(cleanedXml.count) bytes")

        // Debug: Log first 1000 chars to see structure
        if let preview = String(data: cleanedXml.prefix(1000), encoding: .utf8) {
            NSLog("📄 XML preview: \(preview.prefix(500))")
        }

        // Pre-parse relationships to avoid reentrant parsing
        var relationships: [String: String] = [:]
        if let relsData = try? ZipReader.extractFile(named: "word/_rels/document.xml.rels", fromZipData: data) {
            let parser = RelationshipsParser()
            let xmlParser = XMLParser(data: relsData)
            xmlParser.delegate = parser
            xmlParser.parse()
            relationships = parser.relationships
            NSLog("📄 Found \(relationships.count) relationships")
        }

        return try DocumentXMLAttributedCollector.makeAttributedString(from: cleanedXml, docxData: data, relationships: relationships)
    }

    /// Cleans XML data by removing invalid control characters that cause parser errors
    private static func cleanXMLData(_ data: Data) -> Data {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            NSLog("📄 Failed to decode XML as UTF-8, returning original data")
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
            NSLog("📄 Removed \(cleaned.count - withoutInvalidChars.count) invalid XML characters")
            cleaned = withoutInvalidChars
            changesMade = true
        }

        // 2. Fix unclosed tags or malformed attribute syntax
        // Replace common issues like missing quotes, broken tags
        if cleaned.contains("< ") || cleaned.contains(" >") {
            cleaned = cleaned.replacingOccurrences(of: "< ", with: "<")
            cleaned = cleaned.replacingOccurrences(of: " >", with: ">")
            changesMade = true
            NSLog("📄 Fixed malformed tag spacing")
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
                NSLog("📄 Removed embedded binary data from XML content")
                cleaned = result
                changesMade = true
            }
        }

        if changesMade {
            NSLog("📄 XML repair completed")
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
                NSLog("📄 Parser failed but recovered \(output.length) characters")
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
            NSLog("📷 XML Parse Error (code \(nsError.code)): \(parseError)")
            NSLog("📷 Parser line: \(parser.lineNumber), column: \(parser.columnNumber)")

            // For non-fatal errors (like entities, formatting), continue parsing
            // Fatal errors like "no document" will still stop the parser
            if nsError.code == 4 || nsError.code == 9 || nsError.code == 68 {
                // Code 4: Tag mismatch, 9: Undeclared entity, 68: Entity boundary issues
                // These are often recoverable - log but continue
                NSLog("📷 Non-fatal XML error, attempting to continue...")
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
                        let borderColor = NSColor.gray.withAlphaComponent(0.5)
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

            case "w:pStyle", "pStyle":
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
                    case "SceneBreak": mappedName = "Scene Break"
                    case "InternalThought": mappedName = "Internal Thought"
                    case "LetterDocument": mappedName = "Letter / Document"
                    case "BlockQuote": mappedName = "Block Quote"
                    case "Epigraph": mappedName = "Epigraph"
                    case "Dialogue": mappedName = "Dialogue"
                    default: mappedName = val
                    }
                    paragraphStyle.styleName = mappedName
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

            case "w:r", "r":
                finalizeRun()
                runAttributes = RunAttributes()
                currentText = ""

            case "w:rfonts", "rfonts":
                runAttributes.fontName = attributeDict["w:ascii"] ?? attributeDict["w:hansi"] ?? attributeDict["w:cs"] ?? attributeDict["ascii"]

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
                currentText.append("\t")

            case "w:br", "br":
                currentText.append("\n")

            case "w:drawing", "drawing", "wp:inline", "inline":
                inDrawing = true
                NSLog("📷 Found drawing element: \(name)")

            case "wp:extent", "extent":
                // Parse image dimensions in EMU units
                if inDrawing {
                    if let cxStr = attributeDict["cx"], let cx = Int(cxStr) {
                        currentImageWidth = cx
                    }
                    if let cyStr = attributeDict["cy"], let cy = Int(cyStr) {
                        currentImageHeight = cy
                    }
                    NSLog("📷 Parsed extent: cx=\(currentImageWidth ?? 0) cy=\(currentImageHeight ?? 0)")
                }

            case "a:blip", "blip":
                // Extract the relationship ID for the image
                if inDrawing {
                    currentImageRId = attributeDict["r:embed"] ?? attributeDict["embed"]
                    NSLog("📷 Found blip with rId: \(currentImageRId ?? "nil")")
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
            var font = NSFont(name: fontName, size: size) ?? NSFont.systemFont(ofSize: size)
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
                NSLog("📷 finalizeImage: rId=\(currentImageRId ?? "nil"), hasDocxData=\(docxData != nil)")
                return
            }

            let widthEmu = currentImageWidth
            let heightEmu = currentImageHeight
            currentImageRId = nil
            currentImageWidth = nil
            currentImageHeight = nil

            NSLog("📷 Attempting to load image for rId: \(rId), dimensions: \(widthEmu ?? 0) x \(heightEmu ?? 0) EMU")

            // Load and decode image immediately
            guard let imageData = loadImageFromDocx(rId: rId, docxData: docxData) else {
                NSLog("📷 Failed to load image data from DOCX")
                return
            }

            guard let image = NSImage(data: imageData) else {
                NSLog("📷 Failed to decode image data (\(imageData.count) bytes)")
                return
            }

            NSLog("📷 Created NSImage: \(image.size.width) x \(image.size.height)")

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
                NSLog("📷 Using stored dimensions: \(widthPt) x \(heightPt) pt")
            } else {
                let maxWidth: CGFloat = 400
                var bounds = CGRect(origin: .zero, size: image.size)
                if bounds.width > maxWidth {
                    let scale = maxWidth / bounds.width
                    bounds.size.width = maxWidth
                    bounds.size.height *= scale
                }
                finalBounds = bounds
                NSLog("📷 Using intrinsic dimensions: \(bounds.width) x \(bounds.height) pt")
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

            NSLog("📷 Added image to paragraph buffer")
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
                NSLog("📷 Failed to find relationship for rId: \(rId). Available keys: \(relationships.keys.joined(separator: ", "))")
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

            NSLog("📷 Found image path: \(imagePath)")

            // Extract image from zip
            guard let imageData = try? ZipReader.extractFile(named: imagePath, fromZipData: docxData) else {
                NSLog("📷 Failed to extract image from zip at path: \(imagePath)")
                return nil
            }

            NSLog("📷 Successfully extracted image: \(imageData.count) bytes")
            return imageData
        }

        private func finalizeParagraph() {
            guard hasActiveParagraph else { return }
            finalizeRun()

            if paragraphBuffer.length > 0 {
                let paragraph = paragraphStyle.makeParagraphStyle()
                paragraphBuffer.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: paragraphBuffer.length))

                if let styleName = paragraphStyle.styleName {
                    paragraphBuffer.addAttribute(NSAttributedString.Key("QuillStyleName"), value: styleName, range: NSRange(location: 0, length: paragraphBuffer.length))
                }

                result.append(paragraphBuffer)
            }

            // Always add newline to separate paragraphs.
            // Previous logic skipped newline for images, causing them to merge with the next paragraph.
            result.append(NSAttributedString(string: "\n"))

            paragraphBuffer = NSMutableAttributedString()
            hasActiveParagraph = false
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

            func makeParagraphStyle() -> NSParagraphStyle {
                let style = NSMutableParagraphStyle()
                style.alignment = alignment
                style.paragraphSpacingBefore = spacingBefore
                style.paragraphSpacing = spacingAfter
                style.lineHeightMultiple = lineMultiple
                style.headIndent = headIndent
                style.firstLineHeadIndent = headIndent + firstLineIndent
                style.tailIndent = tailIndent
                style.lineBreakMode = .byWordWrapping

                // Add text block if this paragraph is part of a table
                if let block = textBlock {
                    style.textBlocks = [block]
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

            NSLog("📷 ZipReader failed to find: \(targetName). Total entries: \(totalEntries)")
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

        // Trigger auto-analysis after a longer delay
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performAnalysisDelayed), object: nil)
        perform(#selector(performAnalysisDelayed), with: nil, afterDelay: analysisDelay)
    }

    func titleDidChange(_ title: String) {
        onTitleChange?(title)
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

    weak var editorViewController: EditorViewController?

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 220),
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
    }

    private func setupUI() {
        guard let panel = window as? NSPanel else { return }

        let contentView = NSView(frame: panel.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        panel.contentView = contentView

        // Search field
        let searchLabel = NSTextField(labelWithString: "Find:")
        searchLabel.frame = NSRect(x: 20, y: 170, width: 60, height: 20)
        contentView.addSubview(searchLabel)

        searchField = NSTextField(frame: NSRect(x: 90, y: 168, width: 410, height: 24))
        searchField.placeholderString = "Enter search text"
        contentView.addSubview(searchField)

        // Replace field
        let replaceLabel = NSTextField(labelWithString: "Replace:")
        replaceLabel.frame = NSRect(x: 20, y: 138, width: 60, height: 20)
        contentView.addSubview(replaceLabel)

        replaceField = NSTextField(frame: NSRect(x: 90, y: 136, width: 410, height: 24))
        replaceField.placeholderString = "Enter replacement text"
        contentView.addSubview(replaceField)

        // Options
        caseSensitiveCheckbox = NSButton(checkboxWithTitle: "Case sensitive", target: nil, action: nil)
        caseSensitiveCheckbox.frame = NSRect(x: 90, y: 108, width: 140, height: 20)
        contentView.addSubview(caseSensitiveCheckbox)

        wholeWordsCheckbox = NSButton(checkboxWithTitle: "Whole words only", target: nil, action: nil)
        wholeWordsCheckbox.frame = NSRect(x: 90, y: 84, width: 140, height: 20)
        contentView.addSubview(wholeWordsCheckbox)

        // Buttons
        findPreviousButton = NSButton(title: "◀︎ Previous", target: self, action: #selector(findPrevious))
        findPreviousButton.frame = NSRect(x: 20, y: 50, width: 105, height: 28)
        findPreviousButton.bezelStyle = .rounded
        contentView.addSubview(findPreviousButton)

        findNextButton = NSButton(title: "Next ▶︎", target: self, action: #selector(findNext))
        findNextButton.frame = NSRect(x: 135, y: 50, width: 105, height: 28)
        findNextButton.bezelStyle = .rounded
        findNextButton.keyEquivalent = "\r"
        contentView.addSubview(findNextButton)

        replaceButton = NSButton(title: "Replace", target: self, action: #selector(replace))
        replaceButton.frame = NSRect(x: 250, y: 50, width: 120, height: 28)
        replaceButton.bezelStyle = .rounded
        contentView.addSubview(replaceButton)

        replaceAllButton = NSButton(title: "Replace All", target: self, action: #selector(replaceAll))
        replaceAllButton.frame = NSRect(x: 380, y: 50, width: 120, height: 28)
        replaceAllButton.bezelStyle = .rounded
        contentView.addSubview(replaceAllButton)

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

        // Apply background color
        contentView.layer?.backgroundColor = theme.toolbarBackground.cgColor

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
}

private extension Data {
    mutating func appendUInt16(_ v: UInt16) {
        var le = v.littleEndian
        Swift.withUnsafeBytes(of: &le) { append($0.bindMemory(to: UInt8.self)) }
    }

    mutating func appendUInt32(_ v: UInt32) {
        var le = v.littleEndian
        Swift.withUnsafeBytes(of: &le) { append($0.bindMemory(to: UInt8.self)) }
    }
}
