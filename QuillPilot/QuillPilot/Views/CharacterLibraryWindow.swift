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
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Character Library"
        window.minSize = NSSize(width: 800, height: 600)

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let window = window else { return }

        characterLibraryVC = CharacterLibraryViewController()

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        characterLibraryVC!.view.frame = contentView.bounds
        characterLibraryVC!.view.autoresizingMask = [.width, .height]
        contentView.addSubview(characterLibraryVC!.view)

        window.contentView = contentView
        window.contentViewController = characterLibraryVC
    }
}
