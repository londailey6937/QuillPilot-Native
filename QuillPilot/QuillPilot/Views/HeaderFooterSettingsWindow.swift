//
//  HeaderFooterSettingsWindow.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class HeaderFooterSettingsWindow: NSWindowController {

    private var showHeadersCheckbox: NSButton!
    private var showFootersCheckbox: NSButton!
    private var showPageNumbersCheckbox: NSButton!
    private var hideFirstPageNumberCheckbox: NSButton!
    private var pageNumberPositionLabel: NSTextField!
    private var pageNumberPositionControl: NSSegmentedControl!
    private var headerTextField: NSTextField!
    private var footerTextField: NSTextField!

    /// onApply(showHeaders, showFooters, showPageNumbers, hideFirstPageNumber, centerPageNumbers, headerText, footerText)
    var onApply: ((Bool, Bool, Bool, Bool, Bool, String, String) -> Void)?
    var onCancel: (() -> Void)?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Header & Footer Settings"
        window.center()

        // Apply theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        self.init(window: window)
        setupUI()

        // Observe theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil
        )
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        // Show Headers checkbox
        showHeadersCheckbox = NSButton(checkboxWithTitle: "Show Headers", target: self, action: #selector(checkboxChanged))
        showHeadersCheckbox.state = .on
        showHeadersCheckbox.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(showHeadersCheckbox)

        // Header text field
        let headerLabel = NSTextField(labelWithString: "Header Text:")
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerLabel)

        headerTextField = NSTextField()
        headerTextField.placeholderString = "Header text (optional)"
        headerTextField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerTextField)

        // Show Footers checkbox
        showFootersCheckbox = NSButton(checkboxWithTitle: "Show Footers", target: self, action: #selector(checkboxChanged))
        showFootersCheckbox.state = .on
        showFootersCheckbox.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(showFootersCheckbox)

        // Footer text field
        let footerLabel = NSTextField(labelWithString: "Footer Text:")
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(footerLabel)

        footerTextField = NSTextField()
        footerTextField.placeholderString = "Footer text (optional)"
        footerTextField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(footerTextField)

        // Show Page Numbers checkbox
        showPageNumbersCheckbox = NSButton(checkboxWithTitle: "Show Page Numbers", target: self, action: #selector(checkboxChanged))
        showPageNumbersCheckbox.state = .on
        showPageNumbersCheckbox.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(showPageNumbersCheckbox)

        // Hide page number on first page
        hideFirstPageNumberCheckbox = NSButton(checkboxWithTitle: "Hide Page Number on First Page", target: self, action: #selector(checkboxChanged))
        hideFirstPageNumberCheckbox.state = .on
        hideFirstPageNumberCheckbox.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hideFirstPageNumberCheckbox)

        // Page number position
        pageNumberPositionLabel = NSTextField(labelWithString: "Page Number Position:")
        pageNumberPositionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pageNumberPositionLabel)

        pageNumberPositionControl = NSSegmentedControl(labels: ["Right", "Center"], trackingMode: .selectOne, target: self, action: #selector(checkboxChanged))
        pageNumberPositionControl.selectedSegment = 0
        pageNumberPositionControl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pageNumberPositionControl)

        // Info label
        let infoLabel = NSTextField(labelWithString: "Headers and footers are drawn inside the standard page margins.")
        infoLabel.font = NSFont.systemFont(ofSize: 10)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(infoLabel)

        // Buttons
        let applyButton = NSButton()
        applyButton.title = "Apply"
        applyButton.target = self
        applyButton.action = #selector(applySettings)
        applyButton.bezelStyle = .rounded
        applyButton.keyEquivalent = "\r"
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(applyButton)

        let cancelButton = NSButton()
        cancelButton.title = "Cancel"
        cancelButton.target = self
        cancelButton.action = #selector(cancel)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}" // Escape
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cancelButton)

        // Layout
        NSLayoutConstraint.activate([
            showHeadersCheckbox.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            showHeadersCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            headerLabel.topAnchor.constraint(equalTo: showHeadersCheckbox.bottomAnchor, constant: 12),
            headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),

            headerTextField.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            headerTextField.leadingAnchor.constraint(equalTo: headerLabel.trailingAnchor, constant: 8),
            headerTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            headerTextField.widthAnchor.constraint(greaterThanOrEqualToConstant: 250),

            showFootersCheckbox.topAnchor.constraint(equalTo: headerTextField.bottomAnchor, constant: 20),
            showFootersCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            footerLabel.topAnchor.constraint(equalTo: showFootersCheckbox.bottomAnchor, constant: 12),
            footerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),

            footerTextField.centerYAnchor.constraint(equalTo: footerLabel.centerYAnchor),
            footerTextField.leadingAnchor.constraint(equalTo: footerLabel.trailingAnchor, constant: 8),
            footerTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            footerTextField.widthAnchor.constraint(greaterThanOrEqualToConstant: 250),

            showPageNumbersCheckbox.topAnchor.constraint(equalTo: footerTextField.bottomAnchor, constant: 20),
            showPageNumbersCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            hideFirstPageNumberCheckbox.topAnchor.constraint(equalTo: showPageNumbersCheckbox.bottomAnchor, constant: 10),
            hideFirstPageNumberCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),

            pageNumberPositionLabel.topAnchor.constraint(equalTo: hideFirstPageNumberCheckbox.bottomAnchor, constant: 12),
            pageNumberPositionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),

            pageNumberPositionControl.centerYAnchor.constraint(equalTo: pageNumberPositionLabel.centerYAnchor),
            pageNumberPositionControl.leadingAnchor.constraint(equalTo: pageNumberPositionLabel.trailingAnchor, constant: 8),

            infoLabel.topAnchor.constraint(equalTo: pageNumberPositionControl.bottomAnchor, constant: 15),
            infoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            cancelButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),

            applyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            applyButton.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -12),
            applyButton.widthAnchor.constraint(equalToConstant: 80)
        ])

        checkboxChanged()
    }

    func setCurrentSettings(showHeaders: Bool, showFooters: Bool, showPageNumbers: Bool, hideFirstPageNumber: Bool, centerPageNumbers: Bool, headerText: String, footerText: String) {
        showHeadersCheckbox.state = showHeaders ? .on : .off
        showFootersCheckbox.state = showFooters ? .on : .off
        showPageNumbersCheckbox.state = showPageNumbers ? .on : .off
        hideFirstPageNumberCheckbox.state = hideFirstPageNumber ? .on : .off
        pageNumberPositionControl.selectedSegment = centerPageNumbers ? 1 : 0
        headerTextField.stringValue = headerText
        footerTextField.stringValue = footerText
        checkboxChanged()
    }

    @objc private func checkboxChanged() {
        headerTextField.isEnabled = showHeadersCheckbox.state == .on
        footerTextField.isEnabled = showFootersCheckbox.state == .on

        let footerEnabled = showFootersCheckbox.state == .on
        showPageNumbersCheckbox.isEnabled = footerEnabled
        let pageNumbersEnabled = footerEnabled && (showPageNumbersCheckbox.state == .on)
        hideFirstPageNumberCheckbox.isEnabled = pageNumbersEnabled
        pageNumberPositionLabel.isEnabled = pageNumbersEnabled
        pageNumberPositionControl.isEnabled = pageNumbersEnabled
    }

    @objc private func applySettings() {
        onApply?(
            showHeadersCheckbox.state == .on,
            showFootersCheckbox.state == .on,
            showPageNumbersCheckbox.state == .on,
            hideFirstPageNumberCheckbox.state == .on,
            pageNumberPositionControl.selectedSegment == 1,
            headerTextField.stringValue,
            footerTextField.stringValue
        )
        window?.close()
    }

    @objc private func cancel() {
        onCancel?()
        window?.close()
    }

    @objc private func themeDidChange() {
        let isDarkMode = ThemeManager.shared.isDarkMode
        window?.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
