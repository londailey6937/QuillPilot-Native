//
//  DocumentInfoPanel.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class DocumentInfoPanel: NSView {

    private var titleField: NSTextField!
    private var authorField: NSTextField!
    private var wordCountLabel: NSTextField!
    private var charactersLabel: NSTextField!
    private var autoSaveStatusLabel: NSTextField!
    private var stackView: NSStackView!
    private var statLabels: [NSTextField] = []

    private var settingsObserver: NSObjectProtocol?

    var onTitleChanged: ((String) -> Void)?
    var onAuthorChanged: ((String) -> Void)?
    var onManuscriptInfoChanged: ((String, String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        startObservingSettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    private func setupUI() {
        // Editable title field
        titleField = NSTextField()
        titleField.isBordered = false
        titleField.isEditable = true
        titleField.backgroundColor = .clear
        titleField.focusRingType = .none
        // Mirror the document "Title" look (publisher-friendly): centered, serif.
        titleField.font = NSFont(name: "Times New Roman", size: 14) ?? NSFont.systemFont(ofSize: 14, weight: .medium)
        titleField.textColor = ThemeManager.shared.currentTheme.textColor
        titleField.alignment = .center
        titleField.placeholderString = "Untitled"
        titleField.delegate = self
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.refusesFirstResponder = true  // Prevent auto-selection on open

        // Author field (hidden per request)
        authorField = NSTextField()
        authorField.isBordered = false
        authorField.isEditable = true
        authorField.backgroundColor = .clear
        authorField.focusRingType = .none
        authorField.font = NSFont(name: "Times New Roman", size: 12) ?? NSFont.systemFont(ofSize: 12)
        authorField.textColor = ThemeManager.shared.currentTheme.textColor
        authorField.alignment = .center
        authorField.placeholderString = "Author Name"
        authorField.delegate = self
        authorField.translatesAutoresizingMaskIntoConstraints = false
        authorField.isHidden = true

        // Word count
        wordCountLabel = createStatLabel("Words: 0")

        // Characters count
        charactersLabel = createStatLabel("Characters: 0")

        // Auto-save indicator (shows interval or Off)
        autoSaveStatusLabel = createStatLabel("Auto-save: --")

        // Horizontal stack for stats (word count | characters | optional auto-save status)
        let statsStack = NSStackView(views: [wordCountLabel, charactersLabel, autoSaveStatusLabel])
        statsStack.orientation = .horizontal
        statsStack.spacing = 16
        statsStack.distribution = .equalSpacing
        statsStack.translatesAutoresizingMaskIntoConstraints = false

        // Vertical stack: title, stats (author hidden)
        stackView = NSStackView(views: [titleField, statsStack])
        stackView.orientation = .vertical
        stackView.spacing = 4
        stackView.alignment = .centerX
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),

            titleField.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            titleField.widthAnchor.constraint(lessThanOrEqualToConstant: 400)
        ])
    }

    private func createStatLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = ThemeManager.shared.currentTheme.textColor.withAlphaComponent(0.75)
        label.alignment = .center
        statLabels.append(label)
        return label
    }

    func updateStats(text: String) {
        // Word count
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        wordCountLabel.stringValue = "Words: \(words.count)"

        // Characters count
        let charCount = text.count
        charactersLabel.stringValue = "Characters: \(charCount)"
    }

    private func startObservingSettings() {
        settingsObserver = NotificationCenter.default.addObserver(forName: .quillPilotSettingsDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.refreshAutoSaveIndicator()
        }
        refreshAutoSaveIndicator()
    }

    private func refreshAutoSaveIndicator() {
        let interval = QuillPilotSettings.autoSaveIntervalSeconds
        let isOff = interval <= 0

        // Use the app's orange accent for the auto-save status (matches Day-mode borders).
        let accent = NSColor.systemOrange

        if isOff {
            autoSaveStatusLabel.stringValue = "Auto-save: Off"
            autoSaveStatusLabel.textColor = accent.withAlphaComponent(0.90)
            return
        }

        autoSaveStatusLabel.stringValue = "Auto-save: \(formatAutoSaveInterval(seconds: interval))"
        autoSaveStatusLabel.textColor = accent
    }

    private func formatAutoSaveInterval(seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "Off" }

        let roundedSeconds = Int(seconds.rounded())
        if roundedSeconds >= 60, roundedSeconds % 60 == 0 {
            let minutes = roundedSeconds / 60
            return minutes == 1 ? "1m" : "\(minutes)m"
        }
        return "\(max(1, roundedSeconds))s"
    }

    func setTitle(_ title: String) {
        titleField.stringValue = title
    }

    func getTitle() -> String {
        return titleField.stringValue
    }

    func setAuthor(_ author: String) {
        authorField.stringValue = author
    }

    func getAuthor() -> String {
        return authorField.stringValue
    }

    func applyTheme(_ theme: AppTheme) {
        titleField.textColor = theme.headerText
        authorField.textColor = theme.headerText
        let statsColor = theme.headerText.withAlphaComponent(0.85)
        statLabels.forEach { $0.textColor = statsColor }
        refreshAutoSaveIndicator()
        let placeholderText = titleField.placeholderAttributedString?.string ?? titleField.placeholderString
        if let placeholder = placeholderText {
            let centered = NSMutableParagraphStyle()
            centered.alignment = .center
            titleField.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [
                    .foregroundColor: statsColor,
                    .font: titleField.font ?? NSFont.boldSystemFont(ofSize: 14),
                    .paragraphStyle: centered
                ]
            )
        }
        let authorPlaceholderText = authorField.placeholderAttributedString?.string ?? authorField.placeholderString
        if let placeholder = authorPlaceholderText {
            let centered = NSMutableParagraphStyle()
            centered.alignment = .center
            authorField.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [
                    .foregroundColor: statsColor,
                    .font: authorField.font ?? NSFont.systemFont(ofSize: 12),
                    .paragraphStyle: centered
                ]
            )
        }
    }

}

extension DocumentInfoPanel: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            if textField == titleField {
                onTitleChanged?(textField.stringValue)
                onManuscriptInfoChanged?(titleField.stringValue, authorField.stringValue)
            } else if textField == authorField {
                onAuthorChanged?(textField.stringValue)
                onManuscriptInfoChanged?(titleField.stringValue, authorField.stringValue)
            }
        }
    }
}
