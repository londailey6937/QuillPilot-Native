//
//  GeneralNotesWindow.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2026 QuillPilot. All rights reserved.
//

import Cocoa

class GeneralNotesWindowController: NSWindowController, NSTextViewDelegate {

    private var scrollView: NSScrollView!
    private var textView: NSTextView?
    private var saveTimer: Timer?
    private var currentDocumentURL: URL?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 550),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "General Notes"
        window.minSize = NSSize(width: 500, height: 400)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        // Center the window
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let x = (screenFrame.width - 650) / 2
            let y = (screenFrame.height - 550) / 2
            window.setFrame(NSRect(x: x, y: y, width: 650, height: 550), display: true)
        }

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true

        // Create scroll view
        scrollView = NSScrollView(frame: contentView.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder

        // Create text view
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentView.bounds.width - 20, height: contentView.bounds.height - 20))
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.autoresizingMask = [.width]
        textView.delegate = self
        textView.allowsUndo = true

        scrollView.documentView = textView
        self.textView = textView

        contentView.addSubview(scrollView)
        window.contentView = contentView

        applyTheme()
    }

    func setDocumentURL(_ url: URL?) {
        currentDocumentURL = url
        loadNotes()
    }

    private func applyTheme() {
        let theme = ThemeManager.shared.currentTheme
        textView?.backgroundColor = theme.pageAround
        textView?.textColor = theme.textColor
        textView?.insertionPointColor = theme.insertionPointColor
        scrollView?.backgroundColor = theme.pageAround
        window?.backgroundColor = theme.pageAround
    }

    private func loadNotes() {
        guard let url = currentDocumentURL else {
            textView?.string = ""
            return
        }

        let notesURL = url.deletingPathExtension().appendingPathExtension("generalnotes.json")

        guard FileManager.default.fileExists(atPath: notesURL.path),
              let data = try? Data(contentsOf: notesURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? String else {
            textView?.string = ""
            return
        }

        textView?.string = content
    }

    private func saveNotes() {
        guard let url = currentDocumentURL, let content = textView?.string else { return }

        let notesURL = url.deletingPathExtension().appendingPathExtension("generalnotes.json")
        let json: [String: Any] = ["content": content]

        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]) else { return }
        try? data.write(to: notesURL, options: .atomic)
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.saveNotes()
        }
    }

    deinit {
        saveTimer?.invalidate()
        saveNotes()
    }
}
