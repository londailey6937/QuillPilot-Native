import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private var documentationWindow: DocumentationWindowController?
    private var dialogueTipsWindow: DialogueTipsWindowController?
    private var aboutWindow: NSWindow?
    private var welcomeWindow: WelcomeWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        NSApp.setActivationPolicy(.regular)

        // Set dock icon programmatically
        NSApp.applicationIconImage = createAppIcon()

        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }

        // Show welcome screen on launch
        showWelcomeWindow()
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
        let featherImage: NSImage?
        if let bundleImage = NSImage(named: "feather") {
            featherImage = bundleImage
        } else if let bundleImage = Bundle.main.image(forResource: "feather") {
            featherImage = bundleImage
        } else {
            let path = "/Users/londailey/QuillPilot_Native/QuillPilot/QuillPilot/Assets.xcassets/feather.imageset/feather.png"
            featherImage = NSImage(contentsOfFile: path)
        }

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
        false
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

    @objc private func applyDropCap(_ sender: Any?) {
        mainWindowController?.mainContentViewController?.editorViewController.applyDropCap(lines: 3)
    }

    @objc private func applyOldStyleNumerals(_ sender: Any?) {
        mainWindowController?.mainContentViewController?.editorViewController.applyOldStyleNumerals(to: nil)
    }

    @objc private func applyOpticalKerning(_ sender: Any?) {
        mainWindowController?.mainContentViewController?.editorViewController.applyOpticalKerning(to: nil)
    }

    @objc private func openDocument(_ sender: Any?) {
        Task { @MainActor [weak self] in
            self?.mainWindowController?.performOpenDocument(sender)
        }
    }

    @objc private func newDocument(_ sender: Any?) {
        Task { @MainActor [weak self] in
            self?.mainWindowController?.performNewDocument(sender)
        }
    }

    @MainActor
    @objc private func printDocument(_ sender: Any?) {
        NSLog("AppDelegate.printDocument called")
        NSLog("mainWindowController exists: \(mainWindowController != nil)")

        guard let controller = mainWindowController else {
            NSLog("ERROR: mainWindowController is nil in AppDelegate")
            return
        }

        NSLog("About to call mainWindowController.printDocument")
        controller.printDocument(sender)
        NSLog("Finished calling mainWindowController.printDocument")
    }

    // Note: Removed print(_:) wrapper to avoid conflict with Swift's print() function
    // Use printDocument(_:) directly from menu items

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        // App Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(NSMenuItem(title: "About QuillPilot", action: #selector(showAboutWindow(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Hide QuillPilot", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit QuillPilot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

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

        fileMenu.addItem(.separator())

        let saveItem = NSMenuItem(title: "Save", action: #selector(saveDocument(_:)), keyEquivalent: "s")
        saveItem.target = self
        fileMenu.addItem(saveItem)

        let saveAsItem = NSMenuItem(title: "Save As…", action: #selector(saveDocumentAs(_:)), keyEquivalent: "S")
        saveAsItem.target = self
        fileMenu.addItem(saveAsItem)

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

        let findInvisibleItem = NSMenuItem(title: "Find Invisible Characters…", action: #selector(findInvisibleCharacters(_:)), keyEquivalent: "")
        findInvisibleItem.target = self
        editMenu.addItem(findInvisibleItem)

        let cleanItem = NSMenuItem(title: "Remove Invisible Characters", action: #selector(cleanInvisibleCharacters(_:)), keyEquivalent: "")
        cleanItem.target = self
        editMenu.addItem(cleanItem)

        // Format Menu
        let formatMenuItem = NSMenuItem()
        mainMenu.addItem(formatMenuItem)
        let formatMenu = NSMenu(title: "Format")
        formatMenuItem.submenu = formatMenu

        // Typography submenu
        let typographyItem = NSMenuItem(title: "Typography", action: nil, keyEquivalent: "")
        let typographyMenu = NSMenu(title: "Typography")
        typographyItem.submenu = typographyMenu
        formatMenu.addItem(typographyItem)

        let dropCapItem = NSMenuItem(title: "Apply Drop Cap", action: #selector(applyDropCap(_:)), keyEquivalent: "")
        dropCapItem.target = self
        typographyMenu.addItem(dropCapItem)

        let oldStyleNumItem = NSMenuItem(title: "Use Old-Style Numerals", action: #selector(applyOldStyleNumerals(_:)), keyEquivalent: "")
        oldStyleNumItem.target = self
        typographyMenu.addItem(oldStyleNumItem)

        let opticalKernItem = NSMenuItem(title: "Apply Optical Kerning", action: #selector(applyOpticalKerning(_:)), keyEquivalent: "")
        opticalKernItem.target = self
        typographyMenu.addItem(opticalKernItem)

        typographyMenu.addItem(.separator())

        let infoItem = NSMenuItem(title: "ℹ️ Ligatures & smart quotes enabled by default", action: nil, keyEquivalent: "")
        infoItem.isEnabled = false
        typographyMenu.addItem(infoItem)

        // View Menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu

        let headerFooterItem = NSMenuItem(title: "Header & Footer Settings…", action: #selector(showHeaderFooterSettings(_:)), keyEquivalent: "")
        headerFooterItem.target = self
        viewMenu.addItem(headerFooterItem)

        let tocIndexItem = NSMenuItem(title: "Table of Contents & Index…", action: #selector(showTOCIndex(_:)), keyEquivalent: "t")
        tocIndexItem.keyEquivalentModifierMask = [.command, .shift]
        tocIndexItem.target = self
        viewMenu.addItem(tocIndexItem)

        // Window Menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)

        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu

        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))

        // Help Menu
        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)

        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu

        let documentationItem = NSMenuItem(title: "QuillPilot Help", action: #selector(showDocumentation(_:)), keyEquivalent: "?")
        documentationItem.target = self
        helpMenu.addItem(documentationItem)

        let dialogueTipsItem = NSMenuItem(title: "Dialogue Writing Tips", action: #selector(showDialogueTips(_:)), keyEquivalent: "")
        dialogueTipsItem.target = self
        helpMenu.addItem(dialogueTipsItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    @objc private func showHeaderFooterSettings(_ sender: Any?) {
        mainWindowController?.showHeaderFooterSettings()
    }

    @objc private func showTOCIndex(_ sender: Any?) {
        mainWindowController?.showTOCIndex()
    }

    @objc private func findInvisibleCharacters(_ sender: Any?) {
        mainWindowController?.mainContentViewController.editorViewController.highlightInvisibleCharacters()
    }

    @objc private func cleanInvisibleCharacters(_ sender: Any?) {
        mainWindowController?.mainContentViewController.editorViewController.removeInvisibleCharacters()
    }

    @objc private func showDocumentation(_ sender: Any?) {
        if documentationWindow == nil {
            documentationWindow = DocumentationWindowController()
        }
        documentationWindow?.showWindow(nil)
        documentationWindow?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func showDialogueTips(_ sender: Any?) {
        if dialogueTipsWindow == nil {
            dialogueTipsWindow = DialogueTipsWindowController()
        }
        dialogueTipsWindow?.showWindow(nil)
        dialogueTipsWindow?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func showAboutWindow(_ sender: Any?) {
        if aboutWindow == nil {
            aboutWindow = createAboutWindow()
        }
        aboutWindow?.center()
        aboutWindow?.makeKeyAndOrderFront(nil)
    }

    private func createAboutWindow() -> NSWindow {
        let windowSize = NSSize(width: 340, height: 380)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About QuillPilot"
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: NSRect(origin: .zero, size: windowSize))
        contentView.wantsLayer = true

        let theme = ThemeManager.shared.currentTheme
        contentView.layer?.backgroundColor = theme.pageAround.cgColor

        // Logo
        let logoSize: CGFloat = 140
        let logoView = LogoView(size: logoSize)
        logoView.frame = NSRect(
            x: (windowSize.width - logoSize) / 2,
            y: windowSize.height - logoSize - 30,
            width: logoSize,
            height: logoSize
        )
        contentView.addSubview(logoView)

        // App name
        let nameLabel = NSTextField(labelWithString: "QuillPilot")
        nameLabel.font = NSFont.systemFont(ofSize: 24, weight: .semibold)
        nameLabel.textColor = theme.textColor
        nameLabel.alignment = .center
        nameLabel.frame = NSRect(x: 0, y: windowSize.height - logoSize - 70, width: windowSize.width, height: 30)
        contentView.addSubview(nameLabel)

        // Version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let versionLabel = NSTextField(labelWithString: "Version \(version) (\(build))")
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        versionLabel.textColor = NSColor.secondaryLabelColor
        versionLabel.alignment = .center
        versionLabel.frame = NSRect(x: 0, y: windowSize.height - logoSize - 95, width: windowSize.width, height: 20)
        contentView.addSubview(versionLabel)

        // Description
        let descriptionLabel = NSTextField(wrappingLabelWithString: "Professional writing software with publication-quality typography, intelligent manuscript analysis, and comprehensive tools for novelists, essayists, and screenwriters.")
        descriptionLabel.font = NSFont.systemFont(ofSize: 11)
        descriptionLabel.textColor = theme.textColor.withAlphaComponent(0.8)
        descriptionLabel.alignment = .center
        descriptionLabel.frame = NSRect(x: 30, y: windowSize.height - logoSize - 160, width: windowSize.width - 60, height: 50)
        contentView.addSubview(descriptionLabel)

        // Copyright
        let year = Calendar.current.component(.year, from: Date())
        let copyrightLabel = NSTextField(labelWithString: "© \(year) QuillPilot. All rights reserved.")
        copyrightLabel.font = NSFont.systemFont(ofSize: 10)
        copyrightLabel.textColor = NSColor.tertiaryLabelColor
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
    }
}

// MARK: - Menu Item Validation
extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(printDocument(_:)) {
            let isValid = mainWindowController != nil
            NSLog("Validating Print menu item: \(isValid)")
            return isValid
        }
        if menuItem.action == #selector(saveDocument(_:)) || menuItem.action == #selector(openDocument(_:)) {
            return mainWindowController != nil
        }
        return true
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

