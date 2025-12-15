//
//  MainWindowController.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa
import UniformTypeIdentifiers

protocol FormattingToolbarDelegate: AnyObject {
    func formattingToolbarDidIndent(_ toolbar: FormattingToolbar)
    func formattingToolbarDidOutdent(_ toolbar: FormattingToolbar)
    func formattingToolbarDidSave(_ toolbar: FormattingToolbar)

    func formattingToolbar(_ toolbar

                           : FormattingToolbar, didSelectStyle styleName: String)

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

    func formattingToolbarDidInsertPageBreak(_ toolbar: FormattingToolbar)
    func formattingToolbarDidInsertColumnBreak(_ toolbar: FormattingToolbar)
    func formattingToolbarDidColumns(_ toolbar: FormattingToolbar)
    func formattingToolbarDidClearAll(_ toolbar: FormattingToolbar)
}

class MainWindowController: NSWindowController {
    private var activePrintOperation: NSPrintOperation?

    private var headerView: HeaderView!
    private var toolbarView: FormattingToolbar!
    private var rulerView: EnhancedRulerView!
    private var mainContentViewController: ContentViewController!
    private var themeObserver: NSObjectProtocol?
    private var headerFooterSettingsWindow: HeaderFooterSettingsWindow?

    convenience init() {
        let window = NSWindow(
              contentRect: NSRect(x: 0, y: 0, width: 1400, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "QuillPilot"
        window.minSize = NSSize(width: 1000, height: 700)
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
        headerView.applyTheme(theme)
        toolbarView.applyTheme(theme)
        rulerView.applyTheme(theme)
        mainContentViewController.applyTheme(theme)
    }


    // MARK: - Print
    @MainActor
    @objc func printDocument(_ sender: Any?) {
        guard let editorVC = mainContentViewController?.editorViewController else {
            presentErrorAlert(message: "Print Failed", details: "Editor not available")
            return
        }

        guard let window = window else {
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

    // Provide standard print: responder that forwards to printDocument
    @MainActor
    @objc func print(_ sender: Any?) {
        printDocument(sender)
    }

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
        if menuItem.action == #selector(print(_:)) || menuItem.action == #selector(printDocument(_:)) {
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

    func formattingToolbarDidToggleBold(_ toolbar: FormattingToolbar) {
        mainContentViewController.toggleBold()
    }

    func formattingToolbarDidToggleItalic(_ toolbar: FormattingToolbar) {
        mainContentViewController.toggleItalic()
    }

    func formattingToolbarDidToggleUnderline(_ toolbar: FormattingToolbar) {
        mainContentViewController.toggleUnderline()
    }

    func formattingToolbar(_ toolbar: FormattingToolbar, didChangeFontFamily family: String) {
        mainContentViewController.setFontFamily(family)
    }

    func formattingToolbar(_ toolbar: FormattingToolbar, didChangeFontSize size: CGFloat) {
        mainContentViewController.setFontSize(size)
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

    func formattingToolbarDidInsertPageBreak(_ toolbar: FormattingToolbar) {
        mainContentViewController.insertPageBreak()
    }

    func formattingToolbarDidInsertColumnBreak(_ toolbar: FormattingToolbar) {
        mainContentViewController.editorViewController.insertColumnBreak()
    }

    func formattingToolbarDidColumns(_ toolbar: FormattingToolbar) {
        // Prompt for number of columns
        let alert = NSAlert()
        alert.messageText = "Multi-Column Layout"
        alert.informativeText = "Enter the number of columns (1-3):"
        alert.alertStyle = .informational

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = "\(mainContentViewController.editorViewController.getColumnCount())"
        input.placeholderString = "1, 2, or 3"
        alert.accessoryView = input

        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            if let columns = Int(input.stringValue), columns >= 1, columns <= 3 {
                mainContentViewController.editorViewController.setColumnCount(columns)
            } else {
                presentErrorAlert(message: "Invalid Input", details: "Please enter a number between 1 and 3.")
            }
        }
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
}

// MARK: - Save / Open
extension MainWindowController {
    @MainActor
    func performSaveDocument(_ sender: Any?) {
        guard let window else { return }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = "Save"

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        ExportFormat.allCases.forEach { popup.addItem(withTitle: $0.displayName) }
        popup.selectItem(at: 0)

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
            do {
                let data = try self.exportData(format: format)
                try data.write(to: url, options: .atomic)
            } catch {
                self.presentErrorAlert(message: "Save failed", details: error.localizedDescription)
            }
        }
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
        guard let window else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Open"
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "md") ?? .plainText, .rtf, .rtfd, UTType(filenameExtension: "docx") ?? .data, .pdf]

        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
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
            return try mainContentViewController.editorRTFData()
        case .markdown:
            return Data(mainContentViewController.editorPlainText().utf8)
        case .pdf:
            return mainContentViewController.editorPDFData()
        case .docx:
            return try DocxBuilder.makeDocxData(fromPlainText: mainContentViewController.editorPlainText())
        case .shunnManuscript:
            return try mainContentViewController.editorShunnManuscriptRTFData(documentTitle: headerView.documentTitle())
        }
    }

    private func importFile(url: URL) throws {
        let ext = url.pathExtension.lowercased()

        if ext == "pdf" {
            presentErrorAlert(message: "PDF import not supported", details: "PDF to editable text import isn't implemented yet.")
            return
        }

        if ext == "docx" {
            do {
                let text = try DocxTextExtractor.extractPlainText(fromDocxFileURL: url)
                mainContentViewController.setEditorPlainText(text)
                // Reset header/footer custom text when loading new document
                mainContentViewController.editorViewController.headerText = ""
                mainContentViewController.editorViewController.footerText = ""
                mainContentViewController.editorViewController.updatePageCentering()
                return
            } catch {
                let docxType = NSAttributedString.DocumentType(rawValue: "org.openxmlformats.wordprocessingml.document")
                do {
                    let attributed = try NSAttributedString(url: url, options: [.documentType: docxType], documentAttributes: nil)
                    mainContentViewController.setEditorAttributedContent(attributed)
                    // Reset header/footer custom text when loading new document
                    mainContentViewController.editorViewController.headerText = ""
                    mainContentViewController.editorViewController.footerText = ""
                    mainContentViewController.editorViewController.updatePageCentering()
                    return
                } catch {
                    throw NSError(domain: "QuillPilot", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to import DOCX.",
                        NSLocalizedFailureReasonErrorKey: "DOCX plain-text extraction and rich-text import both failed.",
                        NSUnderlyingErrorKey: error
                    ])
                }
            }
        }

        if ext == "rtf" || ext == "rtfd" {
            let attributed = try NSAttributedString(url: url, options: [:], documentAttributes: nil)
            mainContentViewController.setEditorAttributedContent(attributed)
            // Reset header/footer custom text when loading new document
            mainContentViewController.editorViewController.headerText = ""
            mainContentViewController.editorViewController.footerText = ""
            mainContentViewController.editorViewController.updatePageCentering()
            return
        }

        let text = try String(contentsOf: url, encoding: .utf8)
        mainContentViewController.setEditorPlainText(text)
        // Reset header/footer custom text when loading new document
        mainContentViewController.editorViewController.headerText = ""
        mainContentViewController.editorViewController.footerText = ""
        mainContentViewController.editorViewController.updatePageCentering()
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
        titleLabel.textColor = NSColor(hex: "#2c3e50")
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

        context.setFillColor(NSColor(hex: "#fef5e7")?.cgColor ?? NSColor.white.cgColor)

        // Quill shape (simplified)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.width * 0.5, y: bounds.height * 0.1))
        path.line(to: NSPoint(x: bounds.width * 0.7, y: bounds.height * 0.9))
        path.line(to: NSPoint(x: bounds.width * 0.5, y: bounds.height * 0.8))
        path.line(to: NSPoint(x: bounds.width * 0.3, y: bounds.height * 0.9))
        path.close()

        NSColor(hex: "#fef5e7")?.setFill()
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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(hex: "#f5f0e8")?.cgColor

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
                .backgroundColor: NSColor(hex: "#7a6f5d") ?? NSColor.darkGray
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
                let alignLeftBtn = createToolbarButton("≡")
                let alignCenterBtn = createToolbarButton("≣")
                let alignRightBtn = createToolbarButton("≡")
                let justifyBtn = createToolbarButton("≣")
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

        // Layout
        let columnsBtn = createToolbarButton("⫼") // Column icon
        let pageBreakBtn = createToolbarButton("⤓") // Page break icon
        let columnBreakBtn = createToolbarButton("⏎") // Column break icon
        columnsBtn.target = self
        columnsBtn.action = #selector(columnsTapped)
        columnsBtn.toolTip = "Insert Columns"
        pageBreakBtn.target = self
        pageBreakBtn.action = #selector(pageBreakTapped)
        pageBreakBtn.toolTip = "Page Break"
        columnBreakBtn.target = self
        columnBreakBtn.action = #selector(columnBreakTapped)
        columnBreakBtn.toolTip = "Column Break"

        // Clear all button
        let clearBtn = createToolbarButton("⌧") // Clear icon
        clearBtn.target = self
        clearBtn.action = #selector(clearAllTapped)
        clearBtn.toolTip = "Clear All"

        // Indentation
        let outdentBtn = registerControl(NSButton(title: "⇤", target: self, action: #selector(outdentTapped)))
        outdentBtn.bezelStyle = .texturedRounded
        outdentBtn.toolTip = "Decrease Indent"
        let indentBtn = registerControl(NSButton(title: "⇥", target: self, action: #selector(indentTapped)))
        indentBtn.bezelStyle = .texturedRounded
        indentBtn.toolTip = "Increase Indent"

        // Add all to stack view (all aligned left)
        let toolbarStack = NSStackView(views: [
            stylePopup, fontPopup, decreaseSizeBtn, sizePopup, increaseSizeBtn,
            boldBtn, italicBtn, underlineBtn,
            alignLeftBtn, alignCenterBtn, alignRightBtn, justifyBtn,
            bulletsBtn, numberingBtn,
            columnsBtn, columnBreakBtn, pageBreakBtn,
            outdentBtn, indentBtn,
            clearBtn
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

    private func createToolbarButton(_ title: String, weight: NSFont.Weight = .regular, isItalic: Bool = false, isUnderlined: Bool = false) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .texturedRounded
        button.setButtonType(.momentaryPushIn)

        var font = NSFont.systemFont(ofSize: 14, weight: weight)
        if isItalic {
            font = NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(.italic), size: 14) ?? font
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
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: theme.textColor,
                    .font: button.font ?? NSFont.systemFont(ofSize: 14)
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

    @objc private func columnsTapped() {
        delegate?.formattingToolbarDidColumns(self)
    }

    @objc private func pageBreakTapped() {
        delegate?.formattingToolbarDidInsertPageBreak(self)
    }

    @objc private func columnBreakTapped() {
        delegate?.formattingToolbarDidInsertColumnBreak(self)
    }

    @objc private func clearAllTapped() {
        delegate?.formattingToolbarDidClearAll(self)
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
}

// MARK: - Ruler View

// MARK: - Content View Controller (3-column layout)
class ContentViewController: NSViewController {
    var onTitleChange: ((String) -> Void)?
    var onStatsUpdate: ((String) -> Void)?

    private var outlineViewController: OutlineViewController!
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
    }

    private func setupLayout() {
        // Create 3-column split view
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitView)

        // Left: Outline panel
        outlineViewController = OutlineViewController()
        splitView.addArrangedSubview(outlineViewController.view)
        outlineViewController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        outlineViewController.view.widthAnchor.constraint(lessThanOrEqualToConstant: 350).isActive = true

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

        // Encourage symmetric sidebars so the editor column (and page) stays centered in the window.
        let equalSidebarWidths = outlineViewController.view.widthAnchor.constraint(equalTo: analysisViewController.view.widthAnchor)
        equalSidebarWidths.priority = .defaultHigh
        equalSidebarWidths.isActive = true
        analysisViewController.view.widthAnchor.constraint(lessThanOrEqualToConstant: 400).isActive = true        // Back to top button (floating)
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

    @objc private func scrollToTop() {
        // Scroll editor to top
        editorViewController.scrollToTop()
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

    func insertPageBreak() {
        editorViewController.insertPageBreak()
    }

    func editorPlainText() -> String {
        editorViewController.plainTextContent()
    }

    func editorPDFData() -> Data {
        editorViewController.pdfData()
    }

    func editorRTFData() throws -> Data {
        try editorViewController.rtfData()
    }

    func editorShunnManuscriptRTFData(documentTitle: String) throws -> Data {
        try editorViewController.shunnManuscriptRTFData(documentTitle: documentTitle)
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

    private var headerLabel: NSTextField!

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(hex: "#f9f4ed")?.cgColor

        headerLabel = NSTextField(labelWithString: "Document Outline")
        headerLabel.font = NSFont.boldSystemFont(ofSize: 14)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])

        applyTheme(ThemeManager.shared.currentTheme)
    }

    func applyTheme(_ theme: AppTheme) {
        view.wantsLayer = true
        view.layer?.backgroundColor = theme.outlineBackground.cgColor
        headerLabel.textColor = theme.textColor
    }
}

// MARK: - Export Formats
private enum ExportFormat: CaseIterable {
    case docx
    case pdf
    case markdown
    case rtf
    case shunnManuscript

    var displayName: String {
        switch self {
        case .docx: return "DOCX"
        case .pdf: return "PDF"
        case .markdown: return "Markdown"
        case .rtf: return "RTF"
        case .shunnManuscript: return "Shunn Manuscript (RTF)"
        }
    }

    var fileExtension: String {
        switch self {
        case .docx: return "docx"
        case .pdf: return "pdf"
        case .markdown: return "md"
        case .rtf: return "rtf"
        case .shunnManuscript: return "rtf"
        }
    }

    var contentTypes: [UTType] {
        switch self {
        case .docx:
            return [UTType(filenameExtension: "docx") ?? .data]
        case .pdf:
            return [.pdf]
        case .markdown:
            return [UTType(filenameExtension: "md") ?? .plainText]
        case .rtf:
            return [.rtf]
        case .shunnManuscript:
            return [.rtf]
        }
    }
}

// MARK: - Minimal DOCX builder (plain text)
private enum DocxBuilder {
    static func makeDocxData(fromPlainText text: String) throws -> Data {
        let contentTypes = """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">
          <Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>
          <Default Extension=\"xml\" ContentType=\"application/xml\"/>
          <Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>
        </Types>
        """

        let rels = """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">
          <Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/>
        </Relationships>
        """

        let docRels = """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"/>
        """

        let documentXml = makeDocumentXml(fromPlainText: text)

        let entries: [(String, Data)] = [
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(rels.utf8)),
            ("word/document.xml", Data(documentXml.utf8)),
            ("word/_rels/document.xml.rels", Data(docRels.utf8))
        ]

        return ZipWriter.makeZip(entries: entries)
    }

    private static func makeDocumentXml(fromPlainText text: String) -> String {
        let paragraphs = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)

        let body = paragraphs.map { line -> String in
            let escaped = xmlEscape(String(line))
            return "<w:p><w:r><w:t xml:space=\"preserve\">\(escaped)</w:t></w:r></w:p>"
        }.joined()

        return """
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">
          <w:body>
            \(body)
            <w:sectPr/>
          </w:body>
        </w:document>
        """
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
    static func extractPlainText(fromDocxFileURL url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return try extractPlainText(fromDocxData: data)
    }

    static func extractPlainText(fromDocxData data: Data) throws -> String {
        let documentXml = try ZipReader.extractFile(named: "word/document.xml", fromZipData: data)
        let collector = DocumentXMLTextCollector()
        let parser = XMLParser(data: documentXml)
        parser.delegate = collector
        guard parser.parse() else {
            throw parser.parserError ?? NSError(domain: "QuillPilot", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse DOCX document.xml"])
        }
        return collector.text
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

            throw NSError(domain: "QuillPilot", code: 5, userInfo: [NSLocalizedDescriptionKey: "DOCX is missing word/document.xml"])
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
}


// MARK: - EditorViewController Delegate
extension ContentViewController: EditorViewControllerDelegate {
    func textDidChange() {
        if let text = editorViewController?.textView?.string {
            onStatsUpdate?(text)
        }
    }

    func titleDidChange(_ title: String) {
        onTitleChange?(title)
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
