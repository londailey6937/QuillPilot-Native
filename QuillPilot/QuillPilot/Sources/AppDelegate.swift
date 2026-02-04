import Cocoa

extension NSImage {
    static func quillPilotFeatherImage() -> NSImage? {
        if let image = NSImage(named: NSImage.Name("feather")) {
            return image
        }

        if let image = Bundle.main.image(forResource: "feather") {
            return image
        }

        #if SWIFT_PACKAGE
        if let image = Bundle.module.image(forResource: "feather") {
            return image
        }
        #endif

        return nil
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let brandedAppName = "Quill Pilot"
    private var mainWindowController: MainWindowController?
    private var documentationWindow: DocumentationWindowController?
    private var storyDataStorageHelpWindow: StoryDataStorageHelpWindowController?
    private var preferencesWindow: PreferencesWindowController?
    private var aboutWindow: NSWindow?
    private var welcomeWindow: WelcomeWindowController?
    private var specialCharactersWindow: SpecialCharactersWindowController?
    private var sectionBreaksWindow: SectionBreaksWindowController?
    private var recentlyOpenedMenu: NSMenu?
    private var viewMenu: NSMenu?
    private var windowMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        NSApp.setActivationPolicy(.regular)

        // Disable window tabbing and its automatically-inserted View menu items.
        NSWindow.allowsAutomaticWindowTabbing = false

        // Some systems can re-apply the process/bundle name after menu setup.
        // Re-assert branding a couple of times to ensure consistency.
        enforceBrandedAppMenuTitle()
        Task { @MainActor in
            enforceBrandedAppMenuTitle()
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            enforceBrandedAppMenuTitle()
        }

        // Set dock icon programmatically
        NSApp.applicationIconImage = createAppIcon()

        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }

        // Show welcome screen on launch
        showWelcomeWindow()
    }

    private func pruneAutomaticTabBarMenuItems() {
        guard let viewMenu = self.viewMenu else { return }

        let tabSelectors: Set<Selector> = [
            #selector(NSWindow.toggleTabBar(_:)),
            NSSelectorFromString("toggleTabOverview:"),
            NSSelectorFromString("showTabBar:"),
            NSSelectorFromString("hideTabBar:")
        ]

        // Remove by selector or by title match (covers AppKit variations).
        for item in viewMenu.items.reversed() {
            if let action = item.action, tabSelectors.contains(action) {
                viewMenu.removeItem(item)
                continue
            }
            if item.title.localizedCaseInsensitiveContains("tab bar") {
                viewMenu.removeItem(item)
                continue
            }
        }
    }

    private func showWelcomeWindow() {
        welcomeWindow = WelcomeWindowController()
        welcomeWindow?.onNewDocument = { [weak self] in
            self?.presentMainWindow(orderingSource: nil)
            // Create a truly new document - clear everything
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.mainWindowController?.performNewDocument(nil)
            }
        }
        welcomeWindow?.onOpenDocument = { [weak self] in
            self?.presentMainWindow(orderingSource: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.openDocument(nil)
            }
        }
        welcomeWindow?.onOpenRecent = { [weak self] url in
            self?.presentMainWindow(orderingSource: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.mainWindowController?.performOpenDocumentForURL(url)
            }
        }
        welcomeWindow?.showWindow(nil)
        welcomeWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Creates the QuillPilot app icon programmatically using feather.png
    private func createAppIcon() -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)

        image.lockFocus()

        // Background - warm cream color with smaller corner radius to match dock icons
        let bgColor = NSColor(red: 0.97, green: 0.90, blue: 0.82, alpha: 1.0)
        bgColor.setFill()
        // 64pt radius at 512px = 12.5% of size, matches macOS dock icon styling
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 64, yRadius: 64).fill()

        // Try to load and draw feather.png
        let featherImage = NSImage.quillPilotFeatherImage()

        if let feather = featherImage {
            // Make black transparent
            let processedFeather = makeBlackTransparentForIcon(in: feather)
            // Draw feather large to fill dock icon with minimal padding
            let featherSize: CGFloat = 380
            let featherRect = NSRect(
                x: (size.width - featherSize) / 2,
                y: (size.height - featherSize) / 2,
                width: featherSize,
                height: featherSize
            )
            processedFeather.draw(in: featherRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        } else {
            // Fallback: draw simple quill shape
            let accentColor = NSColor(red: 0.94, green: 0.52, blue: 0.20, alpha: 1.0)
            let darkColor = NSColor(red: 0.17, green: 0.24, blue: 0.31, alpha: 1.0)

            let quillPath = NSBezierPath()
            quillPath.move(to: NSPoint(x: 200, y: 320))
            quillPath.curve(to: NSPoint(x: 320, y: 180),
                           controlPoint1: NSPoint(x: 220, y: 280),
                           controlPoint2: NSPoint(x: 280, y: 220))
            quillPath.line(to: NSPoint(x: 330, y: 170))
            quillPath.curve(to: NSPoint(x: 190, y: 330),
                           controlPoint1: NSPoint(x: 290, y: 230),
                           controlPoint2: NSPoint(x: 230, y: 290))
            quillPath.close()
            accentColor.setFill()
            quillPath.fill()

            let tipPath = NSBezierPath()
            tipPath.move(to: NSPoint(x: 320, y: 180))
            tipPath.line(to: NSPoint(x: 350, y: 145))
            tipPath.line(to: NSPoint(x: 330, y: 170))
            tipPath.close()
            darkColor.setFill()
            tipPath.fill()
        }

        image.unlockFocus()

        return image
    }

    private func makeBlackTransparentForIcon(in image: NSImage) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let pixelBuffer = context.data else {
            return image
        }

        let pixels = pixelBuffer.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                let r = pixels[offset]
                let g = pixels[offset + 1]
                let b = pixels[offset + 2]

                let threshold: UInt8 = 50
                if r < threshold && g < threshold && b < threshold {
                    pixels[offset + 3] = 0
                }
            }
        }

        guard let processedCGImage = context.makeImage() else {
            return image
        }

        return NSImage(cgImage: processedCGImage, size: NSSize(width: width, height: height))
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        enforceBrandedAppMenuTitle()

        // Keep welcome window in front until the user chooses an action
        if welcomeWindow?.window?.isVisible == true {
            return
        }

        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }

        Task { @MainActor [weak self] in
            self?.presentMainWindow(orderingSource: self)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor [weak self] in
            self?.mainWindowController?.performOpenDocumentForURL(url)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc private func saveDocument(_ sender: Any?) {
        Task { @MainActor [weak self] in
            self?.mainWindowController?.performSaveDocument(sender)
        }
    }

    @objc private func saveDocumentAs(_ sender: Any?) {
        Task { @MainActor [weak self] in
            self?.mainWindowController?.performSaveAs(sender)
        }
    }

    @objc private func showFind(_ sender: Any?) {
        NotificationCenter.default.post(name: NSNotification.Name("ShowSearchPanel"), object: nil)
    }

    @objc private func toggleRulerVisibility(_ sender: Any?) {
        mainWindowController?.toggleRulerVisibility(sender)

        // Update the menu item title immediately so it changes while the menu is still open.
        if let menuItem = sender as? NSMenuItem {
            let visible = mainWindowController?.isRulerVisible ?? true
            menuItem.title = visible ? "Hide Ruler" : "Show Ruler"
            menuItem.state = visible ? .on : .off
        }
    }

    @objc private func showSpellingAndGrammar(_ sender: Any?) {
        _ = NSApp.sendAction(#selector(NSTextView.showGuessPanel(_:)), to: nil, from: sender)

        // Best-effort theming of the system spelling panel to match other utility windows.
        DispatchQueue.main.async {
            let isDarkMode = ThemeManager.shared.isDarkMode
            let theme = ThemeManager.shared.currentTheme
            let panel = NSSpellChecker.shared.spellingPanel
            panel.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
            panel.backgroundColor = theme.pageAround
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        }
    }

    @objc private func applyDropCap(_ sender: Any?) {
        mainWindowController?.mainContentViewController?.editorViewController.applyDropCap(lines: 3)
    }

    @objc private func applyOldStyleNumerals(_ sender: Any?) {
        mainWindowController?.mainContentViewController?.editorViewController.applyOldStyleNumerals(to: nil)
    }

    @objc private func applyOpticalKerning(_ sender: Any?) {
        mainWindowController?.mainContentViewController?.editorViewController.applyOpticalKerning(to: nil)
    }

    @objc private func insertFootnote(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.mainContentViewController?.editorViewController.insertFootnote()
    }

    @objc private func insertEndnote(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.mainContentViewController?.editorViewController.insertEndnote()
    }

    @objc private func insertBookmark(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.mainContentViewController?.editorViewController.insertBookmark()
    }

    @objc private func insertCrossReference(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.mainContentViewController?.editorViewController.insertCrossReference()
    }

    @objc private func updateFields(_ sender: Any?) {
        mainWindowController?.mainContentViewController?.editorViewController.updateFields()
    }

    @objc private func insertColumnBreak(_ sender: Any?) {
        mainWindowController?.mainContentViewController?.editorViewController.insertColumnBreak()
    }

    @objc private func insertPageBreak(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.mainContentViewController?.editorViewController.insertPageBreak()
    }

    @objc private func insertSectionBreak(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.mainContentViewController?.editorViewController.insertSectionBreak()
    }

    @objc private func toggleSectionBreaksVisibility(_ sender: Any?) {
        guard let editor = mainWindowController?.mainContentViewController?.editorViewController else { return }
        let visible = editor.toggleSectionBreaksVisibility()
        if let menuItem = sender as? NSMenuItem {
            menuItem.state = visible ? .on : .off
            menuItem.title = visible ? "Hide Section Breaks" : "Show Section Breaks"
        }
    }

    @objc private func togglePageBreaksVisibility(_ sender: Any?) {
        guard let editor = mainWindowController?.mainContentViewController?.editorViewController else { return }
        let visible = editor.togglePageBreaksVisibility()
        if let menuItem = sender as? NSMenuItem {
            menuItem.state = visible ? .on : .off
            menuItem.title = visible ? "Hide Page Breaks" : "Show Page Breaks"
        }
    }

    @objc private func showSectionBreaksManager(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)

        guard let editor = mainWindowController?.mainContentViewController?.editorViewController else { return }

        if sectionBreaksWindow == nil {
            sectionBreaksWindow = SectionBreaksWindowController(
                provider: { [weak editor] in
                    editor?.sectionBreakInfos() ?? []
                },
                onGoTo: { [weak editor] id in
                    editor?.goToSectionBreak(withID: id)
                },
                onEdit: { [weak editor] id in
                    editor?.editSectionBreak(withID: id)
                },
                onRemove: { [weak editor] id in
                    _ = editor?.removeSectionBreak(withID: id)
                }
            )
        }

        sectionBreaksWindow?.reload()
        sectionBreaksWindow?.showWindow(nil)
        sectionBreaksWindow?.window?.makeKeyAndOrderFront(nil)
        sectionBreaksWindow?.window?.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func insertHyperlink(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.insertHyperlinkFromMenu(sender)
    }

    @objc private func showStyleEditor(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.openStyleEditorFromMenu(sender)
    }

    @objc private func toggleAutoNumberOnReturn(_ sender: Any?) {
        QuillPilotSettings.autoNumberOnReturn.toggle()
    }

    @objc private func setBulletStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let style = QuillPilotSettings.BulletStyle(rawValue: raw) else { return }
        QuillPilotSettings.bulletStyle = style
    }

    @MainActor
    @objc private func resetTemplateOverridesPrompt(_ sender: Any?) {
        let templateName = StyleCatalog.shared.currentTemplateName

        let alert = NSAlert.themedConfirmation(
            title: "Reset Template Overrides?",
            message: "This will reset any custom style edits you made for the “\(templateName)” template back to defaults. This can’t be undone.",
            confirmTitle: "Reset",
            cancelTitle: "Cancel"
        )

        if let window = mainWindowController?.window {
            alert.runThemedSheet(for: window) { response in
                guard response == .alertFirstButtonReturn else { return }
                StyleCatalog.shared.resetAllOverridesAndNotify()
            }
        } else {
            let response = alert.runThemedModal()
            guard response == .alertFirstButtonReturn else { return }
            StyleCatalog.shared.resetAllOverridesAndNotify()
        }
    }

    @MainActor
    @objc private func showStyleDiagnostics(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.mainContentViewController?.editorViewController.showStyleDiagnostics(sender)
    }

    @objc private func zoomIn(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.zoomIn()
    }

    @objc private func zoomOut(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.zoomOut()
    }

    @objc private func zoomActualSize(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.zoomActualSize()
    }

    @objc private func showBookmarks(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.mainContentViewController?.editorViewController.showInsertBookmarkDialog()
    }

    @objc private func showCrossReferenceTargets(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.mainContentViewController?.editorViewController.showInsertCrossReferenceDialog()
    }

    @objc private func showFootnotes(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.mainContentViewController?.editorViewController.showInsertNoteDialog(type: .footnote)
    }

    @objc private func showEndnotes(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.mainContentViewController?.editorViewController.showInsertNoteDialog(type: .endnote)
    }

    @objc private func showNotesNavigator(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        // Open footnote dialog as the notes navigator
        mainWindowController?.mainContentViewController?.editorViewController.showInsertNoteDialog(type: .footnote)
    }

    @MainActor
    @objc private func restartNumberingPrompt(_ sender: Any?) {
        guard let editor = mainWindowController?.mainContentViewController?.editorViewController else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Restart Numbering"
        let scheme = QuillPilotSettings.numberingScheme
        alert.informativeText = scheme == .decimalDotted
            ? "Choose the starting number for this list level."
            : "Choose the starting letter (or number) for this list level."
        alert.addButton(withTitle: "Restart")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(string: scheme == .decimalDotted ? "1" : "A")
        field.placeholderString = scheme == .decimalDotted ? "1" : "A"
        field.alignment = .center
        field.frame = NSRect(x: 0, y: 0, width: 120, height: 24)
        alert.accessoryView = field

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let rawValue = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let startAt: Int
        switch scheme {
        case .decimalDotted:
            startAt = Int(rawValue) ?? 1
        case .alphabetUpper, .alphabetLower:
            if let value = alphabeticValue(from: rawValue) {
                startAt = value
            } else {
                startAt = Int(rawValue) ?? 1
            }
        }
        editor.restartNumbering(startAt: startAt)
    }

    private func alphabeticValue(from text: String) -> Int? {
        let letters = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !letters.isEmpty else { return nil }
        var value = 0
        for scalar in letters.unicodeScalars {
            let v = Int(scalar.value)
            guard v >= 65 && v <= 90 else { return nil }
            value = value * 26 + (v - 64)
        }
        return value
    }

    // MARK: - Poetry Tools

    private var poetryToolsWindowController: PoetryToolsWindowController?
    private var poetryFormTemplateWindowController: PoetryFormTemplateWindowController?
    private var poetryCollectionWindowController: PoetryCollectionWindowController?
    private var draftVersionWindowController: DraftVersionWindowController?
    private var submissionTrackerWindowController: SubmissionTrackerWindowController?

    @objc func showPoetryToolsPanel(_ sender: Any?) {
        let text = mainWindowController?.mainContentViewController?.editorViewController.textView.string ?? ""

        if poetryToolsWindowController == nil {
            poetryToolsWindowController = PoetryToolsWindowController(text: text)
            poetryToolsWindowController?.onInsertTemplate = { [weak self] template in
                self?.mainWindowController?.mainContentViewController?.editorViewController.textView.insertText(template, replacementRange: NSRange(location: NSNotFound, length: 0))
            }
        } else {
            poetryToolsWindowController?.updateText(text)
        }

        poetryToolsWindowController?.showWindow(relativeTo: mainWindowController?.window)
    }

    @objc func showPoetryFormTemplates(_ sender: Any?) {
        if poetryFormTemplateWindowController == nil {
            poetryFormTemplateWindowController = PoetryFormTemplateWindowController()
            poetryFormTemplateWindowController?.onInsertTemplate = { [weak self] template in
                self?.mainWindowController?.mainContentViewController?.editorViewController.textView.insertText(template, replacementRange: NSRange(location: NSNotFound, length: 0))
            }
        }

        poetryFormTemplateWindowController?.showWindow(relativeTo: mainWindowController?.window)
    }

    @objc func showPoetryCollections(_ sender: Any?) {
        if poetryCollectionWindowController == nil {
            poetryCollectionWindowController = PoetryCollectionWindowController()
            poetryCollectionWindowController?.onSelectPoem = { [weak self] poem in
                guard let self = self else { return }

                // If there's a file reference, open it properly to preserve formatting
                if let path = poem.fileReference {
                    let url = URL(fileURLWithPath: path)
                    self.presentMainWindow(orderingSource: nil)
                    self.mainWindowController?.performOpenDocumentForURL(url)
                    return
                }

                // For inline content (plain text), load it but warn that formatting wasn't stored
                if let content = poem.content {
                    self.presentMainWindow(orderingSource: nil)
                    self.mainWindowController?.mainContentViewController?.editorViewController.textView.string = content
                    return
                }
            }
            poetryCollectionWindowController?.onAddCurrentPoem = { [weak self] collection in
                guard let self else { return }

                guard let textView = self.mainWindowController?.mainContentViewController?.editorViewController.textView else { return }

                let plainText = textView.string
                let title = self.mainWindowController?.currentDocumentTitle() ?? "Untitled"

                // Best case: the document is saved; store its URL so opening preserves formatting.
                if let url = self.mainWindowController?.currentDocumentURLValue() {
                    PoetryCollectionManager.shared.addPoem(
                        to: collection.id,
                        title: title,
                        content: plainText,
                        fileReference: url.path
                    )
                    return
                }

                // Unsaved document: export a temporary RTFD snapshot so formatting is preserved when opening from the collection.
                do {
                    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                    let snapshotsDir = appSupport?.appendingPathComponent("QuillPilot/CollectionPoems", isDirectory: true)
                    if let snapshotsDir {
                        try FileManager.default.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)

                        let snapshotURL = snapshotsDir.appendingPathComponent("\(UUID().uuidString).rtfd", isDirectory: true)

                        let attributed = textView.textStorage ?? NSTextStorage(attributedString: textView.attributedString())
                        let range = NSRange(location: 0, length: attributed.length)
                        let wrapper = try attributed.fileWrapper(
                            from: range,
                            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
                        )
                        try wrapper.write(to: snapshotURL, options: .atomic, originalContentsURL: nil)

                        PoetryCollectionManager.shared.addPoem(
                            to: collection.id,
                            title: title,
                            content: plainText,
                            fileReference: snapshotURL.path
                        )
                        return
                    }
                } catch {
                    DebugLog.log("Failed to export RTFD snapshot for collection poem: \(error)")
                }

                // Fallback: plain text only.
                PoetryCollectionManager.shared.addPoem(to: collection.id, title: title, content: plainText)
            }
        }

        poetryCollectionWindowController?.showWindow(self)
    }

    @objc func showDraftVersions(_ sender: Any?) {
        guard let textView = mainWindowController?.mainContentViewController?.editorViewController.textView else { return }
        let documentId = mainWindowController?.currentDocumentTitle() ?? "untitled"

        let currentContentProvider: () -> String = { [weak textView] in
            textView?.string ?? ""
        }

        let currentFormattedSnapshotProvider: () -> String? = { [weak textView] in
            guard let textView else { return nil }
            do {
                let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                let snapshotsDir = appSupport?.appendingPathComponent("QuillPilot/DraftVersions", isDirectory: true)
                guard let snapshotsDir else { return nil }
                try FileManager.default.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)

                let snapshotURL = snapshotsDir.appendingPathComponent("\(UUID().uuidString).rtfd", isDirectory: true)
                let attributed = textView.textStorage ?? NSTextStorage(attributedString: textView.attributedString())
                let range = NSRange(location: 0, length: attributed.length)
                let wrapper = try attributed.fileWrapper(
                    from: range,
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
                )
                try wrapper.write(to: snapshotURL, options: .atomic, originalContentsURL: nil)
                return snapshotURL.path
            } catch {
                DebugLog.log("Failed to export RTFD snapshot for draft version: \(error)")
                return nil
            }
        }

        draftVersionWindowController = DraftVersionWindowController(
            documentId: documentId,
            currentContentProvider: currentContentProvider,
            currentFormattedSnapshotProvider: currentFormattedSnapshotProvider
        )
        draftVersionWindowController?.onRestoreDraft = { [weak textView] draft in
            guard let textView else { return }
            if let path = draft.fileReference {
                let url = URL(fileURLWithPath: path)
                do {
                    switch url.pathExtension.lowercased() {
                    case "rtfd":
                        let wrapper = try FileWrapper(url: url, options: .immediate)
                        if let attributed = NSAttributedString(rtfdFileWrapper: wrapper, documentAttributes: nil) {
                            textView.textStorage?.setAttributedString(attributed)
                            return
                        }
                    case "rtf":
                        let attributed = try NSAttributedString(url: url, options: [:], documentAttributes: nil)
                        textView.textStorage?.setAttributedString(attributed)
                        return
                    default:
                        break
                    }
                } catch {
                    DebugLog.log("Failed to restore formatted draft content from \(path): \(error)")
                }
            }

            // Fallback: plain text only.
            textView.string = draft.content
        }

        draftVersionWindowController?.showWindow(self)
    }

    @objc func showSubmissionTracker(_ sender: Any?) {
        if submissionTrackerWindowController == nil {
            submissionTrackerWindowController = SubmissionTrackerWindowController()
        }

        submissionTrackerWindowController?.showWindow(self)
    }

    @objc private func openDocument(_ sender: Any?) {
        Task { @MainActor [weak self] in
            self?.mainWindowController?.performOpenDocument(sender)
        }
    }

    @objc private func openRecentFromMenu(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        presentMainWindow(orderingSource: nil)
        mainWindowController?.performOpenDocumentForURL(url)
    }

    @objc private func clearRecentDocuments(_ sender: Any?) {
        NSDocumentController.shared.clearRecentDocuments(sender)
        RecentDocuments.shared.clear()
        recentlyOpenedMenu?.removeAllItems()
    }

    @objc private func newDocument(_ sender: Any?) {
        Task { @MainActor [weak self] in
            self?.mainWindowController?.performNewDocument(sender)
        }
    }

    @MainActor
    @objc private func printDocument(_ sender: Any?) {
        DebugLog.log("AppDelegate.printDocument called")
        DebugLog.log("mainWindowController exists: \(mainWindowController != nil)")

        guard let controller = mainWindowController else {
            DebugLog.log("ERROR: mainWindowController is nil in AppDelegate")
            return
        }

        DebugLog.log("About to call mainWindowController.printDocument")
        controller.printDocument(sender)
        DebugLog.log("Finished calling mainWindowController.printDocument")
    }

    // Note: Removed print(_:) wrapper to avoid conflict with Swift's print() function
    // Use printDocument(_:) directly from menu items

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        // App Menu
        let appMenuItem = NSMenuItem()
        // This controls the app name shown in the menu bar (next to the  menu).
        // Without setting it explicitly, AppKit can fall back to the process/bundle name ("QuillPilot").
        appMenuItem.title = brandedAppName
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(NSMenuItem(title: "About \(brandedAppName)", action: #selector(showAboutWindow(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())

        let prefs = NSMenuItem(title: "Preferences…", action: #selector(showPreferences(_:)), keyEquivalent: ",")
        prefs.target = self
        appMenu.addItem(prefs)

        appMenu.addItem(.separator())

        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu

        appMenu.addItem(.separator())

        appMenu.addItem(NSMenuItem(title: "Hide \(brandedAppName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))

        appMenu.addItem(.separator())

        appMenu.addItem(NSMenuItem(title: "Quit \(brandedAppName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // File Menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        let newItem = NSMenuItem(title: "New", action: #selector(newDocument(_:)), keyEquivalent: "n")
        newItem.target = self
        fileMenu.addItem(newItem)

        let openItem = NSMenuItem(title: "Open…", action: #selector(openDocument(_:)), keyEquivalent: "o")
        openItem.target = self
        fileMenu.addItem(openItem)

        let recentItem = NSMenuItem(title: "Recently Opened", action: nil, keyEquivalent: "")
        let recentMenu = NSMenu(title: "Recently Opened")
        recentMenu.delegate = self
        recentItem.submenu = recentMenu
        fileMenu.addItem(recentItem)
        recentlyOpenedMenu = recentMenu

        fileMenu.addItem(.separator())

        let saveItem = NSMenuItem(title: "Save", action: #selector(saveDocument(_:)), keyEquivalent: "s")
        saveItem.target = self
        fileMenu.addItem(saveItem)

        let saveAsItem = NSMenuItem(title: "Save As…", action: #selector(saveDocumentAs(_:)), keyEquivalent: "S")
        saveAsItem.target = self
        fileMenu.addItem(saveAsItem)

        let exportItem = NSMenuItem(title: "Export…", action: #selector(exportDocument(_:)), keyEquivalent: "")
        exportItem.target = self
        fileMenu.addItem(exportItem)

        fileMenu.addItem(.separator())

        let printItem = NSMenuItem(title: "Print…", action: #selector(printDocument(_:)), keyEquivalent: "p")
        printItem.target = self
        fileMenu.addItem(printItem)
        fileMenu.addItem(.separator())
        // Edit Menu
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenu.addItem(.separator())

        let findItem = NSMenuItem(title: "Find & Replace…", action: #selector(showFind(_:)), keyEquivalent: "f")
        findItem.target = self
        editMenu.addItem(findItem)

        editMenu.addItem(.separator())

        // Cleanup actions (routed via responder chain to the active editor)
        editMenu.addItem(NSMenuItem(title: "Remove Empty Lines", action: Selector(("qpRemoveExtraBlankLines:")), keyEquivalent: ""))
        editMenu.addItem(NSMenuItem(title: "Remove Hidden Text", action: Selector(("qpRemoveHiddenText:")), keyEquivalent: ""))

        // Insert Menu
        let insertMenuItem = NSMenuItem()
        mainMenu.addItem(insertMenuItem)
        let insertMenu = NSMenu(title: "Insert")
        insertMenuItem.submenu = insertMenu

        let headerFooterItem = NSMenuItem(title: "Header & Footer Settings…", action: #selector(showHeaderFooterSettings(_:)), keyEquivalent: "")
        headerFooterItem.target = self
        insertMenu.addItem(headerFooterItem)

        let tocIndexItem = NSMenuItem(title: "Table of Contents & Index…", action: #selector(showTOCIndex(_:)), keyEquivalent: "t")
        tocIndexItem.keyEquivalentModifierMask = [.command, .shift]
        tocIndexItem.target = self
        insertMenu.addItem(tocIndexItem)

        insertMenu.addItem(.separator())

        let insertSectionBreakItem = NSMenuItem(title: "Section Break…", action: #selector(insertSectionBreak(_:)), keyEquivalent: "")
        insertSectionBreakItem.target = self
        insertMenu.addItem(insertSectionBreakItem)

        let insertPageBreakItem = NSMenuItem(title: "Page Break", action: #selector(insertPageBreak(_:)), keyEquivalent: "")
        insertPageBreakItem.target = self
        insertMenu.addItem(insertPageBreakItem)

        insertMenu.addItem(.separator())

        let insertFootnoteItem = NSMenuItem(title: "Insert Footnote", action: #selector(insertFootnote(_:)), keyEquivalent: "")
        insertFootnoteItem.target = self
        insertMenu.addItem(insertFootnoteItem)

        let insertEndnoteItem = NSMenuItem(title: "Insert Endnote", action: #selector(insertEndnote(_:)), keyEquivalent: "")
        insertEndnoteItem.target = self
        insertMenu.addItem(insertEndnoteItem)

        let insertBookmarkItem = NSMenuItem(title: "Bookmark…", action: #selector(insertBookmark(_:)), keyEquivalent: "")
        insertBookmarkItem.target = self
        insertMenu.addItem(insertBookmarkItem)

        let insertCrossReferenceItem = NSMenuItem(title: "Cross-reference…", action: #selector(insertCrossReference(_:)), keyEquivalent: "")
        insertCrossReferenceItem.target = self
        insertMenu.addItem(insertCrossReferenceItem)

        insertMenu.addItem(.separator())

        let updateFieldsItem = NSMenuItem(title: "Update Fields", action: #selector(updateFields(_:)), keyEquivalent: "")
        updateFieldsItem.keyEquivalentModifierMask = [.command, .shift]
        updateFieldsItem.target = self
        insertMenu.addItem(updateFieldsItem)

        insertMenu.addItem(.separator())

        let insertColumnBreakItem = NSMenuItem(title: "Insert Column Break", action: #selector(insertColumnBreak(_:)), keyEquivalent: "")
        insertColumnBreakItem.target = self
        insertMenu.addItem(insertColumnBreakItem)

        let insertHyperlinkItem = NSMenuItem(title: "Insert Hyperlink…", action: #selector(insertHyperlink(_:)), keyEquivalent: "k")
        insertHyperlinkItem.keyEquivalentModifierMask = [.command]
        insertHyperlinkItem.target = self
        insertMenu.addItem(insertHyperlinkItem)

        insertMenu.addItem(.separator())

        let specialCharactersItem = NSMenuItem(title: "Special Characters…", action: #selector(showSpecialCharacters(_:)), keyEquivalent: "")
        specialCharactersItem.target = self
        insertMenu.addItem(specialCharactersItem)

        // Format Menu
        let formatMenuItem = NSMenuItem()
        mainMenu.addItem(formatMenuItem)
        let formatMenu = NSMenu(title: "Format")
        formatMenuItem.submenu = formatMenu

        let styleEditorItem = NSMenuItem(title: "Style Editor…", action: #selector(showStyleEditor(_:)), keyEquivalent: "")
        styleEditorItem.target = self
        formatMenu.addItem(styleEditorItem)

        let pageNumbersItem = NSMenuItem(title: "Page Numbers…", action: #selector(showPageNumberSettings(_:)), keyEquivalent: "")
        pageNumbersItem.target = self
        formatMenu.addItem(pageNumbersItem)

        formatMenu.addItem(.separator())

        // Lists submenu
        let listsItem = NSMenuItem(title: "Lists", action: nil, keyEquivalent: "")
        let listsMenu = NSMenu(title: "Lists")
        listsItem.submenu = listsMenu
        formatMenu.addItem(listsItem)

        // Route these through the responder chain (first responder is the editor text view).
        // Bullets
        listsMenu.addItem(NSMenuItem(title: "Bulleted List", action: Selector(("qpToggleBulletedList:")), keyEquivalent: ""))

        let bulletStyleItem = NSMenuItem(title: "Bulleted List Style", action: nil, keyEquivalent: "")
        let bulletStyleMenu = NSMenu(title: "Bulleted List Style")
        bulletStyleItem.submenu = bulletStyleMenu
        for style in QuillPilotSettings.BulletStyle.allCases {
            let item = NSMenuItem(title: "\(style.displayName)  \(style.rawValue)", action: #selector(setBulletStyle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style.rawValue
            bulletStyleMenu.addItem(item)
        }
        listsMenu.addItem(bulletStyleItem)
        listsMenu.addItem(.separator())

        // Numbering
        listsMenu.addItem(NSMenuItem(title: "Numbered List", action: Selector(("qpToggleNumberedList:")), keyEquivalent: ""))
        listsMenu.addItem(NSMenuItem(title: "Restart Numbering at 1", action: Selector(("qpRestartNumbering:")), keyEquivalent: ""))
        let restartCustom = NSMenuItem(title: "Restart Numbering…", action: #selector(restartNumberingPrompt(_:)), keyEquivalent: "")
        restartCustom.target = self
        listsMenu.addItem(restartCustom)
        listsMenu.addItem(.separator())

        let autoNumberOnReturnItem = NSMenuItem(title: "Auto-continue lists on Return", action: #selector(toggleAutoNumberOnReturn(_:)), keyEquivalent: "")
        autoNumberOnReturnItem.target = self
        listsMenu.addItem(autoNumberOnReturnItem)

        // Tools Menu
        let toolsMenuItem = NSMenuItem()
        mainMenu.addItem(toolsMenuItem)
        let toolsMenu = NSMenu(title: "Tools")
        toolsMenuItem.submenu = toolsMenu

        let spellingItem = NSMenuItem(title: "Spelling and Grammar…", action: #selector(showSpellingAndGrammar(_:)), keyEquivalent: ";")
        spellingItem.keyEquivalentModifierMask = [.command]
        spellingItem.target = self
        toolsMenu.addItem(spellingItem)

        toolsMenu.addItem(.separator())

        let autoAnalyzeOpenItem = NSMenuItem(title: "Auto-run analysis when opening documents/tools", action: #selector(toggleAutoAnalyzeOnOpen(_:)), keyEquivalent: "")
        autoAnalyzeOpenItem.target = self
        toolsMenu.addItem(autoAnalyzeOpenItem)

        let autoAnalyzeTypingItem = NSMenuItem(title: "Auto-run analysis while typing", action: #selector(toggleAutoAnalyzeWhileTyping(_:)), keyEquivalent: "")
        autoAnalyzeTypingItem.target = self
        toolsMenu.addItem(autoAnalyzeTypingItem)

        toolsMenu.addItem(.separator())

        let resetTemplateOverridesItem = NSMenuItem(title: "Reset Template Overrides…", action: #selector(resetTemplateOverridesPrompt(_:)), keyEquivalent: "")
        resetTemplateOverridesItem.target = self
        toolsMenu.addItem(resetTemplateOverridesItem)

        let styleDiagnosticsItem = NSMenuItem(title: "Style Diagnostics…", action: #selector(showStyleDiagnostics(_:)), keyEquivalent: "")
        styleDiagnosticsItem.target = self
        toolsMenu.addItem(styleDiagnosticsItem)

        toolsMenu.addItem(.separator())

        let purgeCharactersItem = NSMenuItem(title: "Purge Character Library for This Document…", action: #selector(purgeCharacterLibraryForThisDocument(_:)), keyEquivalent: "")
        purgeCharactersItem.target = self
        toolsMenu.addItem(purgeCharactersItem)

        toolsMenu.addItem(.separator())

        // Poetry Tools submenu
        let poetryToolsItem = NSMenuItem(title: "Poetry Tools", action: nil, keyEquivalent: "")
        let poetryToolsMenu = NSMenu(title: "Poetry Tools")
        poetryToolsItem.submenu = poetryToolsMenu
        toolsMenu.addItem(poetryToolsItem)

        let poetryToolsPanelItem = NSMenuItem(title: "Poetry Analysis Tools…", action: #selector(showPoetryToolsPanel(_:)), keyEquivalent: "")
        poetryToolsPanelItem.target = self
        poetryToolsMenu.addItem(poetryToolsPanelItem)

        let formTemplatesItem = NSMenuItem(title: "Form Templates…", action: #selector(showPoetryFormTemplates(_:)), keyEquivalent: "")
        formTemplatesItem.target = self
        poetryToolsMenu.addItem(formTemplatesItem)

        poetryToolsMenu.addItem(.separator())

        let collectionsItem = NSMenuItem(title: "Poetry Collections…", action: #selector(showPoetryCollections(_:)), keyEquivalent: "")
        collectionsItem.target = self
        poetryToolsMenu.addItem(collectionsItem)

        let draftVersionsItem = NSMenuItem(title: "Draft Versions…", action: #selector(showDraftVersions(_:)), keyEquivalent: "")
        draftVersionsItem.target = self
        poetryToolsMenu.addItem(draftVersionsItem)

        let submissionTrackerItem = NSMenuItem(title: "Submission Tracker…", action: #selector(showSubmissionTracker(_:)), keyEquivalent: "")
        submissionTrackerItem.target = self
        poetryToolsMenu.addItem(submissionTrackerItem)

        // View Menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        self.viewMenu = viewMenu
        viewMenu.delegate = self

        let toggleRulerItem = NSMenuItem(title: "Hide Ruler", action: #selector(toggleRulerVisibility(_:)), keyEquivalent: "r")
        toggleRulerItem.keyEquivalentModifierMask = [.command]
        toggleRulerItem.target = self
        viewMenu.addItem(toggleRulerItem)

        let sectionBreaksMenuItem = NSMenuItem(title: "Section Breaks", action: nil, keyEquivalent: "")
        let sectionBreaksMenu = NSMenu(title: "Section Breaks")
        sectionBreaksMenuItem.submenu = sectionBreaksMenu
        viewMenu.addItem(sectionBreaksMenuItem)

        let toggleSectionBreaksItem = NSMenuItem(title: "Show Section Breaks", action: #selector(toggleSectionBreaksVisibility(_:)), keyEquivalent: "")
        toggleSectionBreaksItem.target = self
        sectionBreaksMenu.addItem(toggleSectionBreaksItem)

        let manageSectionBreaksItem = NSMenuItem(title: "Manage Section Breaks…", action: #selector(showSectionBreaksManager(_:)), keyEquivalent: "")
        manageSectionBreaksItem.target = self
        sectionBreaksMenu.addItem(manageSectionBreaksItem)

        let pageBreaksMenuItem = NSMenuItem(title: "Page Breaks", action: nil, keyEquivalent: "")
        let pageBreaksMenu = NSMenu(title: "Page Breaks")
        pageBreaksMenuItem.submenu = pageBreaksMenu
        viewMenu.addItem(pageBreaksMenuItem)

        let togglePageBreaksItem = NSMenuItem(title: "Show Page Breaks", action: #selector(togglePageBreaksVisibility(_:)), keyEquivalent: "")
        togglePageBreaksItem.target = self
        pageBreaksMenu.addItem(togglePageBreaksItem)

        viewMenu.addItem(.separator())

        let zoomInItem = NSMenuItem(title: "Zoom In", action: #selector(zoomIn(_:)), keyEquivalent: "=")
        zoomInItem.keyEquivalentModifierMask = [.command]
        zoomInItem.target = self
        viewMenu.addItem(zoomInItem)

        let zoomOutItem = NSMenuItem(title: "Zoom Out", action: #selector(zoomOut(_:)), keyEquivalent: "-")
        zoomOutItem.keyEquivalentModifierMask = [.command]
        zoomOutItem.target = self
        viewMenu.addItem(zoomOutItem)

        let zoomActualItem = NSMenuItem(title: "Actual Size", action: #selector(zoomActualSize(_:)), keyEquivalent: "0")
        zoomActualItem.keyEquivalentModifierMask = [.command]
        zoomActualItem.target = self
        viewMenu.addItem(zoomActualItem)

        viewMenu.addItem(.separator())

        let showBookmarksItem = NSMenuItem(title: "Show Bookmarks", action: #selector(showBookmarks(_:)), keyEquivalent: "")
        showBookmarksItem.target = self
        viewMenu.addItem(showBookmarksItem)

        let showCrossReferencesItem = NSMenuItem(title: "Show Cross-Reference Targets", action: #selector(showCrossReferenceTargets(_:)), keyEquivalent: "")
        showCrossReferencesItem.target = self
        viewMenu.addItem(showCrossReferencesItem)

        viewMenu.addItem(.separator())

        let showFootnotesItem = NSMenuItem(title: "Show Footnotes", action: #selector(showFootnotes(_:)), keyEquivalent: "")
        showFootnotesItem.target = self
        viewMenu.addItem(showFootnotesItem)

        let showEndnotesItem = NSMenuItem(title: "Show Endnotes", action: #selector(showEndnotes(_:)), keyEquivalent: "")
        showEndnotesItem.target = self
        viewMenu.addItem(showEndnotesItem)

        let showNotesSidebarItem = NSMenuItem(title: "Show Notes Navigator", action: #selector(showNotesNavigator(_:)), keyEquivalent: "")
        showNotesSidebarItem.target = self
        viewMenu.addItem(showNotesSidebarItem)

        // Window Menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)

        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        self.windowMenu = windowMenu

        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(.separator())
        windowMenu.addItem(NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))

        // Help Menu
        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)

        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu

        let documentationItem = NSMenuItem(title: "Quill Pilot Help", action: #selector(showDocumentation(_:)), keyEquivalent: "?")
        documentationItem.target = self
        helpMenu.addItem(documentationItem)

        let storyNotesHelpItem = NSMenuItem(title: "Story Data Storage…", action: #selector(showStoryNotesStorageHelp(_:)), keyEquivalent: "")
        storyNotesHelpItem.target = self
        helpMenu.addItem(storyNotesHelpItem)

        helpMenu.addItem(.separator())

        let supportItem = NSMenuItem(title: "support@quillpilot.ai", action: #selector(openSupportEmail(_:)), keyEquivalent: "")
        supportItem.target = self
        helpMenu.addItem(supportItem)

        NSApp.mainMenu = mainMenu
        enforceBrandedAppMenuTitle()
        NSApp.windowsMenu = windowMenu
        NSApp.helpMenu = helpMenu

        // AppKit can insert "Show/Hide Tab Bar" automatically; prune it after the menu is installed.
        DispatchQueue.main.async { [weak self] in
            self?.pruneAutomaticTabBarMenuItems()
        }
    }

    private func enforceBrandedAppMenuTitle() {
        // The menu bar uses the title of the first item (Application menu).
        NSApp.mainMenu?.item(at: 0)?.title = brandedAppName
        enforcePreferencesMenuTitle()
    }

    private func enforcePreferencesMenuTitle() {
        guard let appMenu = NSApp.mainMenu?.item(at: 0)?.submenu else { return }
        for item in appMenu.items {
            if item.action == #selector(showPreferences(_:)) || item.keyEquivalent == "," {
                item.title = "Preferences…"
                continue
            }
            if item.title == "Settings…" || item.title == "Settings..." {
                item.title = "Preferences…"
            }
        }
    }

    @objc private func showPreferences(_ sender: Any?) {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindowController()
        }
        preferencesWindow?.showWindow(nil)
        preferencesWindow?.window?.makeKeyAndOrderFront(nil)
        preferencesWindow?.window?.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSupportEmail(_ sender: Any?) {
        guard let url = URL(string: "mailto:support@quillpilot.ai") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func exportDocument(_ sender: Any?) {
        mainWindowController?.performExportDocument(sender)
    }

    @objc private func analyzeDocumentNow(_ sender: Any?) {
        // If the user is on the Welcome window, the shortcut should still visibly do something.
        // Bring the main window forward, then run analysis.
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }

        presentMainWindow(orderingSource: sender)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.mainWindowController?.mainContentViewController.performAnalysis()
        }
    }



    @objc private func toggleAutoAnalyzeOnOpen(_ sender: Any?) {
        QuillPilotSettings.autoAnalyzeOnOpen.toggle()
    }

    @objc private func toggleAutoAnalyzeWhileTyping(_ sender: Any?) {
        QuillPilotSettings.autoAnalyzeWhileTyping.toggle()
    }

    @objc private func purgeCharacterLibraryForThisDocument(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.purgeCharacterLibraryForCurrentDocument(sender)
    }

    @objc private func showHeaderFooterSettings(_ sender: Any?) {
        mainWindowController?.showHeaderFooterSettings()
    }

    @objc private func showPageNumberSettings(_ sender: Any?) {
        mainWindowController?.showHeaderFooterSettings()
    }

    @objc private func showTOCIndex(_ sender: Any?) {
        mainWindowController?.showTOCIndex()
    }

    @objc private func showSpecialCharacters(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)

        if specialCharactersWindow == nil {
            specialCharactersWindow = SpecialCharactersWindowController(
                onInsertText: { [weak self] text in
                    self?.mainWindowController?.mainContentViewController.editorViewController.insertTextAtSelection(text)
                },
                onToggleParagraphMarks: { [weak self] in
                    _ = self?.mainWindowController?.mainContentViewController.editorViewController.toggleParagraphMarks()
                    self?.mainWindowController?.syncParagraphMarksToolbarState()
                },
                onFindInvisibleCharacters: { [weak self] in
                    self?.findInvisibleCharacters(nil)
                },
                onRemoveExtraBlankLines: { [weak self] in
                    self?.removeExtraBlankLines(nil)
                },
                onApplyDropCap: { [weak self] in
                    self?.applyDropCap(nil)
                },
                onApplyOldStyleNumerals: { [weak self] in
                    self?.applyOldStyleNumerals(nil)
                },
                onApplyOpticalKerning: { [weak self] in
                    self?.applyOpticalKerning(nil)
                }
            )
        }

        // Show it after activation so it doesn't end up behind the main UI.
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.specialCharactersWindow?.showWindow(nil)
            self.specialCharactersWindow?.window?.level = .floating
            self.specialCharactersWindow?.window?.makeKeyAndOrderFront(nil)
            self.specialCharactersWindow?.window?.orderFrontRegardless()
        }
    }

    @objc private func findInvisibleCharacters(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.mainContentViewController.editorViewController.highlightInvisibleCharacters()
    }

    @objc private func cleanInvisibleCharacters(_ sender: Any?) {
        mainWindowController?.mainContentViewController.editorViewController.removeInvisibleCharacters()
    }

    @objc private func removeExtraBlankLines(_ sender: Any?) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        presentMainWindow(orderingSource: sender)
        mainWindowController?.mainContentViewController.editorViewController.removeExtraBlankLines()
    }

    func openDocumentation(tabIdentifier: String? = nil) {
        if documentationWindow == nil {
            documentationWindow = DocumentationWindowController()
        }
        documentationWindow?.showWindow(nil)
        documentationWindow?.window?.makeKeyAndOrderFront(nil)
        documentationWindow?.window?.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        documentationWindow?.window?.isExcludedFromWindowsMenu = false

        if let tabIdentifier {
            documentationWindow?.selectTab(identifier: tabIdentifier)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showDocumentation(_ sender: Any?) {
        openDocumentation(tabIdentifier: nil)
    }

    @objc private func showStoryNotesStorageHelp(_ sender: Any?) {
        if storyDataStorageHelpWindow == nil {
            storyDataStorageHelpWindow = StoryDataStorageHelpWindowController(
                onRevealStoryNotesFolder: { [weak self] in
                    guard let folder = StoryNotesStore.storyNotesDirectoryURL() else { return }
                    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
                    NSWorkspace.shared.activateFileViewerSelecting([folder])
                    _ = self // keep capture explicit
                },
                onOpenHelp: { [weak self] in
                    self?.openDocumentation(tabIdentifier: "why")
                }
            )
        }

        let host = mainWindowController?.window ?? NSApp.keyWindow
        storyDataStorageHelpWindow?.present(relativeTo: host)
    }

    @objc private func showAboutWindow(_ sender: Any?) {
        if aboutWindow != nil {
            aboutWindow?.close()
            aboutWindow = nil
        }
        aboutWindow = createAboutWindow()
        aboutWindow?.center()
        aboutWindow?.makeKeyAndOrderFront(nil)
    }

    private func createAboutWindow() -> NSWindow {
        let windowSize = NSSize(width: 340, height: 500)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Quill Pilot"
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: NSRect(origin: .zero, size: windowSize))
        contentView.wantsLayer = true

        let theme = ThemeManager.shared.currentTheme
        contentView.layer?.backgroundColor = theme.pageAround.cgColor

        let logoSize: CGFloat = 120
        let topPadding: CGFloat = 26
        let nameSpacing: CGFloat = 14
        let headingSpacing: CGFloat = 8
        let descriptionSpacing: CGFloat = 12
        let descriptionHeight: CGFloat = 120
        let versionSpacing: CGFloat = 12

        let logoTop = windowSize.height - topPadding
        let logoY = logoTop - logoSize

        // Logo
        let logoView = LogoView(size: logoSize)
        logoView.frame = NSRect(
            x: (windowSize.width - logoSize) / 2,
            y: logoY,
            width: logoSize,
            height: logoSize
        )
        contentView.addSubview(logoView)

        // App name
        let nameLabel = NSTextField(labelWithString: "Quill Pilot")
        nameLabel.font = NSFont.systemFont(ofSize: 24, weight: .semibold)
        nameLabel.textColor = theme.textColor
        nameLabel.alignment = .center
        let nameY = logoY - nameSpacing - 30
        nameLabel.frame = NSRect(x: 0, y: nameY, width: windowSize.width, height: 30)
        contentView.addSubview(nameLabel)

        // About heading
        let aboutHeadingLabel = NSTextField(labelWithString: "About Quill Pilot")
        aboutHeadingLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        aboutHeadingLabel.textColor = theme.textColor
        aboutHeadingLabel.alignment = .center
        let headingY = nameY - headingSpacing - 20
        aboutHeadingLabel.frame = NSRect(x: 0, y: headingY, width: windowSize.width, height: 20)
        contentView.addSubview(aboutHeadingLabel)

        // Description (placed directly under About heading)
        let descriptionLabel = NSTextField(wrappingLabelWithString: "Designed for macOS with a fully adaptive interface—from 13-inch MacBooks to expansive desktop displays.\n\nProfessional writing software with publication-quality typography, powerful manuscript analysis across all writing forms, and comprehensive tools for novelists, non-fiction authors, poets, essayists, and screenwriters.")
        descriptionLabel.font = NSFont.systemFont(ofSize: 11)
        descriptionLabel.textColor = theme.textColor.withAlphaComponent(0.8)
        descriptionLabel.alignment = .center
        let descriptionY = headingY - descriptionSpacing - descriptionHeight
        descriptionLabel.frame = NSRect(x: 30, y: descriptionY, width: windowSize.width - 60, height: descriptionHeight)
        contentView.addSubview(descriptionLabel)

        // Version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let versionLabel = NSTextField(labelWithString: "Version \(version) (\(build))")
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        versionLabel.textColor = theme.textColor.withAlphaComponent(0.7)
        versionLabel.alignment = .center
        let versionY = descriptionY - versionSpacing - 20
        versionLabel.frame = NSRect(x: 0, y: versionY, width: windowSize.width, height: 20)
        contentView.addSubview(versionLabel)

        // Copyright
        let year = Calendar.current.component(.year, from: Date())
        let copyrightLabel = NSTextField(labelWithString: "© \(year) Quill Pilot. All rights reserved.")
        copyrightLabel.font = NSFont.systemFont(ofSize: 10)
        copyrightLabel.textColor = theme.textColor.withAlphaComponent(0.55)
        copyrightLabel.alignment = .center
        copyrightLabel.frame = NSRect(x: 0, y: 20, width: windowSize.width, height: 16)
        contentView.addSubview(copyrightLabel)

        window.contentView = contentView
        return window
    }

    @MainActor
    private func presentMainWindow(orderingSource: Any?) {
        guard let controller = mainWindowController else { return }

        controller.showWindow(orderingSource)

        guard let window = controller.window else { return }


        window.isReleasedWhenClosed = false
        window.deminiaturize(nil)
        window.center()
        window.setIsVisible(true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(orderingSource)
        NSApp.activate(ignoringOtherApps: true)

        enforceBrandedAppMenuTitle()
    }
}

extension AppDelegate: NSUserInterfaceValidations {
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(toggleRulerVisibility(_:)) {
            let visible = mainWindowController?.isRulerVisible ?? true
            if let menuItem = item as? NSMenuItem {
                menuItem.title = visible ? "Hide Ruler" : "Show Ruler"
                menuItem.state = visible ? .on : .off
            }
            return true
        }

        if item.action == #selector(toggleSectionBreaksVisibility(_:)) {
            let visible = mainWindowController?.mainContentViewController?.editorViewController.sectionBreaksVisible() ?? false
            if let menuItem = item as? NSMenuItem {
                menuItem.title = visible ? "Hide Section Breaks" : "Show Section Breaks"
                menuItem.state = visible ? .on : .off
            }
            return true
        }

        if item.action == #selector(togglePageBreaksVisibility(_:)) {
            let visible = mainWindowController?.mainContentViewController?.editorViewController.pageBreaksVisible() ?? false
            if let menuItem = item as? NSMenuItem {
                menuItem.title = visible ? "Hide Page Breaks" : "Show Page Breaks"
                menuItem.state = visible ? .on : .off
            }
            return true
        }

        return true
    }
}

// MARK: - Menu Item Validation
extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(showPreferences(_:)) {
            return true
        }

        if menuItem.action == #selector(resetTemplateOverridesPrompt(_:)) {
            return true
        }

        if menuItem.action == #selector(zoomIn(_:)) ||
            menuItem.action == #selector(zoomOut(_:)) ||
            menuItem.action == #selector(zoomActualSize(_:)) {
            return true
        }

        if menuItem.action == #selector(showSpecialCharacters(_:)) {
            return true
        }

        if menuItem.action == #selector(toggleAutoAnalyzeOnOpen(_:)) {
            menuItem.state = QuillPilotSettings.autoAnalyzeOnOpen ? .on : .off
            return true
        }
        if menuItem.action == #selector(toggleAutoAnalyzeWhileTyping(_:)) {
            menuItem.state = QuillPilotSettings.autoAnalyzeWhileTyping ? .on : .off
            return true
        }

        if menuItem.action == #selector(toggleAutoNumberOnReturn(_:)) {
            menuItem.state = QuillPilotSettings.autoNumberOnReturn ? .on : .off
            return true
        }

        if menuItem.action == #selector(setBulletStyle(_:)) {
            if let raw = menuItem.representedObject as? String,
               let style = QuillPilotSettings.BulletStyle(rawValue: raw) {
                menuItem.state = (QuillPilotSettings.bulletStyle == style) ? .on : .off
            } else {
                menuItem.state = .off
            }
            return true
        }

        let requiresWindow: Set<Selector> = [
            #selector(printDocument(_:)),
            #selector(saveDocument(_:)),
            #selector(saveDocumentAs(_:)),
            #selector(openDocument(_:)),
            #selector(exportDocument(_:)),
            #selector(showHeaderFooterSettings(_:)),
            #selector(showTOCIndex(_:)),
            #selector(showFind(_:)),
            #selector(applyDropCap(_:)),
            #selector(applyOldStyleNumerals(_:)),
            #selector(applyOpticalKerning(_:)),
            #selector(analyzeDocumentNow(_:)),
            #selector(insertColumnBreak(_:)),
            #selector(toggleSectionBreaksVisibility(_:)),
            #selector(togglePageBreaksVisibility(_:)),
        ]

        if let action = menuItem.action, requiresWindow.contains(action) {
            return mainWindowController != nil
        }

        return true
    }
}

// MARK: - Recently Opened Menu
extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == viewMenu {
            pruneAutomaticTabBarMenuItems()
            return
        }

        guard menu == recentlyOpenedMenu else { return }

        menu.removeAllItems()

        // Prefer app-managed recents (works even if system recents are disabled).
        let recents = RecentDocuments.shared.recentURLs()
        guard !recents.isEmpty else {
            let none = NSMenuItem(title: "No Recent Documents", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
            return
        }

        for url in recents.prefix(12) {
            let item = NSMenuItem(title: url.lastPathComponent, action: #selector(openRecentFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = url
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let clear = NSMenuItem(title: "Clear Menu", action: #selector(clearRecentDocuments(_:)), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
    }
}

@main
@MainActor

enum QuillPilotMain {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}

