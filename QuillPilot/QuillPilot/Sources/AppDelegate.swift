import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private var documentationWindow: DocumentationWindowController?
    private var dialogueTipsWindow: DialogueTipsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        NSApp.setActivationPolicy(.regular)

        // Set dock icon programmatically
        NSApp.applicationIconImage = createAppIcon()

        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }

        Task { @MainActor [weak self] in
            self?.presentMainWindow(orderingSource: nil)
        }
    }

    /// Creates the QuillPilot app icon programmatically
    private func createAppIcon() -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)

        image.lockFocus()

        // Background - warm cream color
        let bgColor = NSColor(red: 0.97, green: 0.90, blue: 0.82, alpha: 1.0)
        bgColor.setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 80, yRadius: 80).fill()

        // Orange accent color
        let accentColor = NSColor(red: 0.94, green: 0.52, blue: 0.20, alpha: 1.0)

        // Dark color for details
        let darkColor = NSColor(red: 0.17, green: 0.24, blue: 0.31, alpha: 1.0)

        // Draw outer hexagon frame
        let hexPath = NSBezierPath()
        let cx: CGFloat = 256, cy: CGFloat = 256
        let outerRadius: CGFloat = 180
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let x = cx + outerRadius * cos(angle)
            let y = cy + outerRadius * sin(angle)
            if i == 0 {
                hexPath.move(to: NSPoint(x: x, y: y))
            } else {
                hexPath.line(to: NSPoint(x: x, y: y))
            }
        }
        hexPath.close()
        accentColor.withAlphaComponent(0.8).setStroke()
        hexPath.lineWidth = 6
        hexPath.stroke()

        // Draw inner hexagon
        let innerHex = NSBezierPath()
        let innerRadius: CGFloat = 120
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let x = cx + innerRadius * cos(angle)
            let y = cy + innerRadius * sin(angle)
            if i == 0 {
                innerHex.move(to: NSPoint(x: x, y: y))
            } else {
                innerHex.line(to: NSPoint(x: x, y: y))
            }
        }
        innerHex.close()
        darkColor.withAlphaComponent(0.6).setStroke()
        innerHex.lineWidth = 4
        innerHex.stroke()

        // Draw stylized quill/pen
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

        // Quill tip
        let tipPath = NSBezierPath()
        tipPath.move(to: NSPoint(x: 320, y: 180))
        tipPath.line(to: NSPoint(x: 350, y: 145))
        tipPath.line(to: NSPoint(x: 330, y: 170))
        tipPath.close()
        darkColor.setFill()
        tipPath.fill()

        // Neural network dots
        let dotPositions: [(CGFloat, CGFloat)] = [
            (256, 320), (200, 280), (312, 280),
            (180, 220), (256, 240), (332, 220),
            (200, 180), (312, 180)
        ]

        for (x, y) in dotPositions {
            let dotRect = NSRect(x: x - 8, y: y - 8, width: 16, height: 16)
            let dot = NSBezierPath(ovalIn: dotRect)
            accentColor.setFill()
            dot.fill()
        }

        // Connection lines between dots
        darkColor.withAlphaComponent(0.4).setStroke()
        let linePath = NSBezierPath()
        linePath.lineWidth = 2

        // Horizontal connections
        linePath.move(to: NSPoint(x: 200, y: 280))
        linePath.line(to: NSPoint(x: 312, y: 280))

        linePath.move(to: NSPoint(x: 180, y: 220))
        linePath.line(to: NSPoint(x: 332, y: 220))

        linePath.move(to: NSPoint(x: 200, y: 180))
        linePath.line(to: NSPoint(x: 312, y: 180))

        // Diagonal connections
        linePath.move(to: NSPoint(x: 200, y: 280))
        linePath.line(to: NSPoint(x: 256, y: 240))

        linePath.move(to: NSPoint(x: 312, y: 280))
        linePath.line(to: NSPoint(x: 256, y: 240))

        linePath.move(to: NSPoint(x: 256, y: 240))
        linePath.line(to: NSPoint(x: 180, y: 220))

        linePath.move(to: NSPoint(x: 256, y: 240))
        linePath.line(to: NSPoint(x: 332, y: 220))

        linePath.stroke()

        image.unlockFocus()

        return image
    }

    func applicationDidBecomeActive(_ notification: Notification) {
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

    @objc private func openDocument(_ sender: Any?) {
        Task { @MainActor [weak self] in
            self?.mainWindowController?.performOpenDocument(sender)
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

        appMenu.addItem(NSMenuItem(title: "About QuillPilot", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Hide QuillPilot", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit QuillPilot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // File Menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        let openItem = NSMenuItem(title: "Open…", action: #selector(openDocument(_:)), keyEquivalent: "o")
        openItem.target = self
        fileMenu.addItem(openItem)

        let saveItem = NSMenuItem(title: "Save", action: #selector(saveDocument(_:)), keyEquivalent: "s")
        saveItem.target = self
        fileMenu.addItem(saveItem)

        let saveAsItem = NSMenuItem(title: "Save As…", action: #selector(saveDocumentAs(_:)), keyEquivalent: "S")
        saveAsItem.target = self
        fileMenu.addItem(saveAsItem)

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

        // View Menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu

        let headerFooterItem = NSMenuItem(title: "Header & Footer Settings…", action: #selector(showHeaderFooterSettings(_:)), keyEquivalent: "")
        headerFooterItem.target = self
        viewMenu.addItem(headerFooterItem)

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

