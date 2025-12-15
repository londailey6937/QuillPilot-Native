import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        NSApp.setActivationPolicy(.regular)

        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }

        Task { @MainActor [weak self] in
            self?.presentMainWindow(orderingSource: nil)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }


    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor [weak self] in
            self?.mainWindowController?.performOpenDocumentForURL(url)
        }
    }
        Task { @MainActor [weak self] in
            self?.presentMainWindow(orderingSource: self)
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

    @objc private func openDocument(_ sender: Any?) {
        Task { @MainActor [weak self] in
            self?.mainWindowController?.performOpenDocument(sender)
        }
    }

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

        let saveItem = NSMenuItem(title: "Save…", action: #selector(saveDocument(_:)), keyEquivalent: "s")
        saveItem.target = self
        fileMenu.addItem(saveItem)

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

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    @objc private func showHeaderFooterSettings(_ sender: Any?) {
        mainWindowController?.showHeaderFooterSettings()
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
