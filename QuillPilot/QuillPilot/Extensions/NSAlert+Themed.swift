//
//  NSAlert+Themed.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

extension NSAlert {

    /// Gets the QuillPilot feather icon for alerts
    private static func getQuillPilotIcon() -> NSImage? {
        // Try to get the feather image
        if let featherImage = NSImage.quillPilotFeatherImage() {
            return featherImage
        } else if let appIcon = NSApp.applicationIconImage {
            return appIcon
        }
        return nil
    }

    /// Shows the alert as a sheet attached to the given window, inheriting its theme
    func runThemedSheet(for window: NSWindow, completionHandler: ((NSApplication.ModalResponse) -> Void)? = nil) {
        // Set custom icon
        if let icon = NSAlert.getQuillPilotIcon() {
            self.icon = icon
        }
        applyQuillPilotTheme()
        self.beginSheetModal(for: window) { response in
            completionHandler?(response)
        }
    }

    /// Shows the alert modally with proper theme applied
    @discardableResult
    func runThemedModal() -> NSApplication.ModalResponse {
        // Set custom icon
        if let icon = NSAlert.getQuillPilotIcon() {
            self.icon = icon
        }
        applyQuillPilotTheme()
        return self.runModal()
    }

    /// Creates a pre-configured informational alert with theming
    static func themedInformational(title: String, message: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        if let icon = getQuillPilotIcon() {
            alert.icon = icon
        }
        return alert
    }

    /// Creates a pre-configured warning alert with theming
    static func themedWarning(title: String, message: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        if let icon = getQuillPilotIcon() {
            alert.icon = icon
        }
        return alert
    }

    /// Creates a pre-configured confirmation alert with theming
    static func themedConfirmation(title: String, message: String, confirmTitle: String = "OK", cancelTitle: String = "Cancel") -> NSAlert {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: cancelTitle)
        if let icon = getQuillPilotIcon() {
            alert.icon = icon
        }
        return alert
    }

    private func applyQuillPilotTheme() {
        let theme = ThemeManager.shared.currentTheme
        let isDarkMode = ThemeManager.shared.isDarkMode

        let alertWindow = self.window
        alertWindow.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
        alertWindow.backgroundColor = theme.pageAround

        for (index, button) in buttons.enumerated() {
            let isPrimary = (index == 0)
            button.wantsLayer = true
            button.isBordered = false
            button.layer?.cornerRadius = 8
            button.layer?.borderWidth = 1
            button.layer?.borderColor = theme.pageBorder.cgColor
            button.layer?.backgroundColor = (isPrimary ? theme.pageBorder : theme.pageBackground).cgColor

            let font = button.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let titleColor: NSColor = isPrimary ? .white : theme.textColor
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [
                    .foregroundColor: titleColor,
                    .font: font
                ]
            )
        }
    }
}

// MARK: - Convenience methods for showing alerts

extension NSWindowController {

    /// Shows a themed informational alert as a sheet
    func showThemedAlert(title: String, message: String) {
        guard let window = self.window else { return }
        let alert = NSAlert.themedInformational(title: title, message: message)
        alert.runThemedSheet(for: window)
    }

    /// Shows a themed confirmation alert as a sheet and returns whether confirmed
    func showThemedConfirmation(title: String, message: String, confirmTitle: String = "OK", cancelTitle: String = "Cancel", completion: @escaping (Bool) -> Void) {
        guard let window = self.window else {
            completion(false)
            return
        }
        let alert = NSAlert.themedConfirmation(title: title, message: message, confirmTitle: confirmTitle, cancelTitle: cancelTitle)
        alert.runThemedSheet(for: window) { response in
            completion(response == .alertFirstButtonReturn)
        }
    }
}

extension NSViewController {

    /// Shows a themed informational alert as a sheet
    func showThemedAlert(title: String, message: String) {
        guard let window = self.view.window else { return }
        let alert = NSAlert.themedInformational(title: title, message: message)
        alert.runThemedSheet(for: window)
    }

    /// Shows a themed confirmation alert as a sheet and returns whether confirmed
    func showThemedConfirmation(title: String, message: String, confirmTitle: String = "OK", cancelTitle: String = "Cancel", completion: @escaping (Bool) -> Void) {
        guard let window = self.view.window else {
            completion(false)
            return
        }
        let alert = NSAlert.themedConfirmation(title: title, message: message, confirmTitle: confirmTitle, cancelTitle: cancelTitle)
        alert.runThemedSheet(for: window) { response in
            completion(response == .alertFirstButtonReturn)
        }
    }
}
