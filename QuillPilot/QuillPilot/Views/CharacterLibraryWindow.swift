//
//  CharacterLibraryWindow.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class CharacterLibraryWindowController: NSWindowController {

    private var characterLibraryVC: CharacterLibraryViewController?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Character Library"
        window.minSize = NSSize(width: 800, height: 400)

        // Set window background to match theme
        let theme = ThemeManager.shared.currentTheme
        window.backgroundColor = theme.popoutBackground

        // Set window appearance to match theme (light/dark mode)
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Center the window
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let x = (screenFrame.width - 1000) / 2
            let y = (screenFrame.height - 500) / 2
            window.setFrame(NSRect(x: x, y: y, width: 1000, height: 500), display: true)
        }

        self.init(window: window)
        setupUI()

        // Listen for theme changes
        NotificationCenter.default.addObserver(forName: .themeDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.applyTheme()
        }
    }

    private func applyTheme() {
        let theme = ThemeManager.shared.currentTheme
        window?.backgroundColor = theme.popoutBackground

        // Update window appearance to match theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window?.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        if let contentView = window?.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = theme.popoutBackground.cgColor
        }
    }

    private func setupUI() {
        guard let window = window else { return }

        characterLibraryVC = CharacterLibraryViewController()

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true

        // Set initial background color
        let theme = ThemeManager.shared.currentTheme
        contentView.layer?.backgroundColor = theme.popoutBackground.cgColor

        characterLibraryVC!.view.frame = contentView.bounds
        characterLibraryVC!.view.autoresizingMask = [.width, .height]
        contentView.addSubview(characterLibraryVC!.view)

        window.contentView = contentView
        window.contentViewController = characterLibraryVC

        // Make the view controller the first responder so Cmd+S works
        window.initialFirstResponder = characterLibraryVC?.view
        window.makeFirstResponder(characterLibraryVC)
    }
}
