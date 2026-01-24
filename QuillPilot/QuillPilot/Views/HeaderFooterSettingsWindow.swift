//
//  HeaderFooterSettingsWindow.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class HeaderFooterSettingsWindow: NSWindowController, NSWindowDelegate {

    private var showHeadersCheckbox: NSButton!
    private var showFootersCheckbox: NSButton!
    private var showPageNumbersCheckbox: NSButton!
    private var hideFirstPageNumberCheckbox: NSButton!
    private var facingPagesCheckbox: NSButton!
    private var pageNumberPositionLabel: NSTextField!
    private var pageNumberPositionStack: NSStackView!
    private var pageNumberRightButton: NSButton!
    private var pageNumberCenterButton: NSButton!
    private var centerPageNumbersSelected = false
    private var headerLeftTextField: NSTextField!
    private var headerRightTextField: NSTextField!
    private var footerLeftTextField: NSTextField!
    private var footerRightTextField: NSTextField!

    private var applyButton: NSButton!
    private var cancelButton: NSButton!

    private var themedLabels: [NSTextField] = []
    private var infoLabel: NSTextField?
    private var didApplyOrCancel = false
    private var clickOutsideMonitor: Any?

    /// onApply(showHeaders, showFooters, showPageNumbers, hideFirstPageNumber, centerPageNumbers, facingPages, headerLeftText, headerRightText, footerLeftText, footerRightText)
    var onApply: ((Bool, Bool, Bool, Bool, Bool, Bool, String, String, String, String) -> Void)?
    var onCancel: (() -> Void)?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 410),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Header & Footer Settings"
        window.center()

        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        self.init(window: window)
        window.delegate = self
        setupUI()
        applyTheme()

        // Observe theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil
        )

        // Close when user clicks back into main UI
        clickOutsideMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self, let window = self.window, window.isVisible else { return event }
            if event.window != window {
                self.cancel()
            }
            return event
        }
    }

    private func applyTheme() {
        guard let window = window else { return }
        let theme = ThemeManager.shared.currentTheme
        let isDarkMode = ThemeManager.shared.isDarkMode

        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
        window.backgroundColor = theme.pageAround
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = theme.pageAround.cgColor

        themedLabels.forEach { $0.textColor = theme.textColor }
        infoLabel?.textColor = theme.textColor.withAlphaComponent(0.7)

        // Theme buttons
        if let applyButton = applyButton {
            themeButton(applyButton, theme: theme)
        }
        if let cancelButton = cancelButton {
            themeButton(cancelButton, theme: theme)
        }

        // Theme checkboxes
        themeCheckbox(showHeadersCheckbox, theme: theme)
        themeCheckbox(showFootersCheckbox, theme: theme)
        themeCheckbox(showPageNumbersCheckbox, theme: theme)
        themeCheckbox(hideFirstPageNumberCheckbox, theme: theme)
        themeCheckbox(facingPagesCheckbox, theme: theme)

        // Theme page-number position selector
        updatePageNumberPositionAppearance(theme: theme)
    }

    private func themeSegmentButton(_ button: NSButton, selected: Bool, theme: AppTheme) {
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.borderColor = theme.pageBorder.cgColor
        button.layer?.borderWidth = 1
        button.layer?.cornerRadius = 6
        button.layer?.backgroundColor = (selected ? theme.pageBorder : theme.pageBackground).cgColor

        let font = button.font ?? NSFont.systemFont(ofSize: 13)
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .foregroundColor: selected ? theme.pageBackground : theme.textColor,
                .font: font
            ]
        )
        button.contentTintColor = selected ? theme.pageBackground : theme.textColor
    }

    private func updatePageNumberPositionAppearance(theme: AppTheme) {
        guard pageNumberRightButton != nil, pageNumberCenterButton != nil else { return }
        themeSegmentButton(pageNumberRightButton, selected: !centerPageNumbersSelected, theme: theme)
        themeSegmentButton(pageNumberCenterButton, selected: centerPageNumbersSelected, theme: theme)
    }

    private func setCenterPageNumbersSelected(_ selected: Bool) {
        centerPageNumbersSelected = selected
        if let theme = Optional(ThemeManager.shared.currentTheme) {
            updatePageNumberPositionAppearance(theme: theme)
        }
    }

    private func themeButton(_ button: NSButton, theme: AppTheme) {
        button.contentTintColor = theme.textColor
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = theme.pageBackground.cgColor
        button.layer?.borderColor = theme.pageBorder.cgColor
        button.layer?.borderWidth = 1
        button.layer?.cornerRadius = 6
        let font = button.font ?? NSFont.systemFont(ofSize: 13)
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .foregroundColor: theme.textColor,
                .font: font
            ]
        )
    }

    private func themeCheckbox(_ checkbox: NSButton, theme: AppTheme) {
        checkbox.contentTintColor = theme.textColor
        let font = checkbox.font ?? NSFont.systemFont(ofSize: 13)
        checkbox.attributedTitle = NSAttributedString(
            string: checkbox.title,
            attributes: [
                .foregroundColor: theme.textColor,
                .font: font
            ]
        )
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        contentView.wantsLayer = true

        // Show Headers checkbox
        showHeadersCheckbox = NSButton(checkboxWithTitle: "Show Headers", target: self, action: #selector(checkboxChanged))
        showHeadersCheckbox.state = .on
        showHeadersCheckbox.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(showHeadersCheckbox)

        // Header text fields
        let headerLeftLabel = NSTextField(labelWithString: "Header Left:")
        headerLeftLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerLeftLabel)
        themedLabels.append(headerLeftLabel)

        headerLeftTextField = NSTextField()
        headerLeftTextField.placeholderString = "Left header text (optional)"
        headerLeftTextField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerLeftTextField)

        let headerRightLabel = NSTextField(labelWithString: "Header Right:")
        headerRightLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerRightLabel)
        themedLabels.append(headerRightLabel)

        headerRightTextField = NSTextField()
        headerRightTextField.placeholderString = "Right header text (optional)"
        headerRightTextField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerRightTextField)

        // Show Footers checkbox
        showFootersCheckbox = NSButton(checkboxWithTitle: "Show Footers", target: self, action: #selector(checkboxChanged))
        showFootersCheckbox.state = .on
        showFootersCheckbox.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(showFootersCheckbox)

        // Footer text fields
        let footerLeftLabel = NSTextField(labelWithString: "Footer Left:")
        footerLeftLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(footerLeftLabel)
        themedLabels.append(footerLeftLabel)

        footerLeftTextField = NSTextField()
        footerLeftTextField.placeholderString = "Left footer text (optional)"
        footerLeftTextField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(footerLeftTextField)

        let footerRightLabel = NSTextField(labelWithString: "Footer Right:")
        footerRightLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(footerRightLabel)
        themedLabels.append(footerRightLabel)

        footerRightTextField = NSTextField()
        footerRightTextField.placeholderString = "Right footer text (optional)"
        footerRightTextField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(footerRightTextField)

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

        // Facing pages
        facingPagesCheckbox = NSButton(checkboxWithTitle: "Facing Pages (outer margins)", target: self, action: #selector(checkboxChanged))
        facingPagesCheckbox.state = .off
        facingPagesCheckbox.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(facingPagesCheckbox)

        // Page number position
        pageNumberPositionLabel = NSTextField(labelWithString: "Page Number Position:")
        pageNumberPositionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pageNumberPositionLabel)
        themedLabels.append(pageNumberPositionLabel)

        pageNumberRightButton = NSButton(title: "Right", target: self, action: #selector(pageNumberPositionTapped(_:)))
        pageNumberRightButton.tag = 0
        pageNumberRightButton.translatesAutoresizingMaskIntoConstraints = false

        pageNumberCenterButton = NSButton(title: "Center", target: self, action: #selector(pageNumberPositionTapped(_:)))
        pageNumberCenterButton.tag = 1
        pageNumberCenterButton.translatesAutoresizingMaskIntoConstraints = false

        pageNumberPositionStack = NSStackView(views: [pageNumberRightButton, pageNumberCenterButton])
        pageNumberPositionStack.orientation = .horizontal
        pageNumberPositionStack.spacing = 8
        pageNumberPositionStack.alignment = .centerY
        pageNumberPositionStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pageNumberPositionStack)

        // Info label
        let infoLabel = NSTextField(labelWithString: "Headers and footers are drawn inside the standard page margins.")
        infoLabel.font = NSFont.systemFont(ofSize: 10)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(infoLabel)
        self.infoLabel = infoLabel

        // Buttons
        applyButton = NSButton()
        applyButton.title = "Apply"
        applyButton.target = self
        applyButton.action = #selector(applySettings)
        applyButton.bezelStyle = .rounded
        applyButton.keyEquivalent = "\r"
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(applyButton)

        cancelButton = NSButton()
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

            headerLeftLabel.topAnchor.constraint(equalTo: showHeadersCheckbox.bottomAnchor, constant: 12),
            headerLeftLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),

            headerLeftTextField.centerYAnchor.constraint(equalTo: headerLeftLabel.centerYAnchor),
            headerLeftTextField.leadingAnchor.constraint(equalTo: headerLeftLabel.trailingAnchor, constant: 8),
            headerLeftTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            headerLeftTextField.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),

            headerRightLabel.topAnchor.constraint(equalTo: headerLeftLabel.bottomAnchor, constant: 10),
            headerRightLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),

            headerRightTextField.centerYAnchor.constraint(equalTo: headerRightLabel.centerYAnchor),
            headerRightTextField.leadingAnchor.constraint(equalTo: headerRightLabel.trailingAnchor, constant: 8),
            headerRightTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            headerRightTextField.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),

            showFootersCheckbox.topAnchor.constraint(equalTo: headerRightTextField.bottomAnchor, constant: 20),
            showFootersCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            footerLeftLabel.topAnchor.constraint(equalTo: showFootersCheckbox.bottomAnchor, constant: 12),
            footerLeftLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),

            footerLeftTextField.centerYAnchor.constraint(equalTo: footerLeftLabel.centerYAnchor),
            footerLeftTextField.leadingAnchor.constraint(equalTo: footerLeftLabel.trailingAnchor, constant: 8),
            footerLeftTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            footerLeftTextField.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),

            footerRightLabel.topAnchor.constraint(equalTo: footerLeftLabel.bottomAnchor, constant: 10),
            footerRightLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),

            footerRightTextField.centerYAnchor.constraint(equalTo: footerRightLabel.centerYAnchor),
            footerRightTextField.leadingAnchor.constraint(equalTo: footerRightLabel.trailingAnchor, constant: 8),
            footerRightTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            footerRightTextField.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),

            showPageNumbersCheckbox.topAnchor.constraint(equalTo: footerRightTextField.bottomAnchor, constant: 20),
            showPageNumbersCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            hideFirstPageNumberCheckbox.topAnchor.constraint(equalTo: showPageNumbersCheckbox.bottomAnchor, constant: 10),
            hideFirstPageNumberCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),

            facingPagesCheckbox.topAnchor.constraint(equalTo: hideFirstPageNumberCheckbox.bottomAnchor, constant: 8),
            facingPagesCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),

            pageNumberPositionLabel.topAnchor.constraint(equalTo: facingPagesCheckbox.bottomAnchor, constant: 12),
            pageNumberPositionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),

            pageNumberPositionStack.centerYAnchor.constraint(equalTo: pageNumberPositionLabel.centerYAnchor),
            pageNumberPositionStack.leadingAnchor.constraint(equalTo: pageNumberPositionLabel.trailingAnchor, constant: 8),
            pageNumberRightButton.heightAnchor.constraint(equalToConstant: 26),
            pageNumberCenterButton.heightAnchor.constraint(equalToConstant: 26),

            infoLabel.topAnchor.constraint(equalTo: pageNumberPositionStack.bottomAnchor, constant: 15),
            infoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            cancelButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),

            applyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            applyButton.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -12),
            applyButton.widthAnchor.constraint(equalToConstant: 80)
        ])

        applyTheme()
        checkboxChanged()
    }

    func setCurrentSettings(showHeaders: Bool, showFooters: Bool, showPageNumbers: Bool, hideFirstPageNumber: Bool, centerPageNumbers: Bool, facingPages: Bool, headerLeftText: String, headerRightText: String, footerLeftText: String, footerRightText: String) {
        showHeadersCheckbox.state = showHeaders ? .on : .off
        showFootersCheckbox.state = showFooters ? .on : .off
        showPageNumbersCheckbox.state = showPageNumbers ? .on : .off
        hideFirstPageNumberCheckbox.state = hideFirstPageNumber ? .on : .off
        facingPagesCheckbox.state = facingPages ? .on : .off
        setCenterPageNumbersSelected(centerPageNumbers)
        headerLeftTextField.stringValue = headerLeftText
        headerRightTextField.stringValue = headerRightText
        footerLeftTextField.stringValue = footerLeftText
        footerRightTextField.stringValue = footerRightText
        checkboxChanged()
    }

    @objc private func pageNumberPositionTapped(_ sender: NSButton) {
        setCenterPageNumbersSelected(sender.tag == 1)
        checkboxChanged()
    }

    @objc private func checkboxChanged() {
        headerLeftTextField.isEnabled = showHeadersCheckbox.state == .on
        headerRightTextField.isEnabled = showHeadersCheckbox.state == .on
        footerLeftTextField.isEnabled = showFootersCheckbox.state == .on
        footerRightTextField.isEnabled = showFootersCheckbox.state == .on

        let footerEnabled = showFootersCheckbox.state == .on
        showPageNumbersCheckbox.isEnabled = footerEnabled
        let pageNumbersEnabled = footerEnabled && (showPageNumbersCheckbox.state == .on)
        hideFirstPageNumberCheckbox.isEnabled = pageNumbersEnabled
        facingPagesCheckbox.isEnabled = pageNumbersEnabled
        pageNumberPositionLabel.isEnabled = pageNumbersEnabled
        pageNumberRightButton.isEnabled = pageNumbersEnabled
        pageNumberCenterButton.isEnabled = pageNumbersEnabled
    }

    @objc private func applySettings() {
        didApplyOrCancel = true
        onApply?(
            showHeadersCheckbox.state == .on,
            showFootersCheckbox.state == .on,
            showPageNumbersCheckbox.state == .on,
            hideFirstPageNumberCheckbox.state == .on,
            centerPageNumbersSelected,
            facingPagesCheckbox.state == .on,
            headerLeftTextField.stringValue,
            headerRightTextField.stringValue,
            footerLeftTextField.stringValue,
            footerRightTextField.stringValue
        )
        window?.close()
    }

    @objc private func cancel() {
        didApplyOrCancel = true
        onCancel?()
        window?.close()
    }

    @objc private func themeDidChange() {
        applyTheme()
    }

    func windowWillClose(_ notification: Notification) {
        // Ensure close button behaves like Cancel for cleanup.
        if !didApplyOrCancel {
            onCancel?()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
