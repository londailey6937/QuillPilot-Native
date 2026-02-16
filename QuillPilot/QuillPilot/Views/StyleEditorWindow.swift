import Cocoa

protocol StyleEditorPresenter: AnyObject {
    func applyStyleFromEditor(named: String)
}

final class StyleEditorWindowController: NSWindowController {
    init(editor: StyleEditorPresenter) {
        let viewController = StyleEditorViewController(editor: editor)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 680),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Style Editor"
        window.contentViewController = viewController
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class StyleEditorViewController: NSViewController {
    private weak var editor: StyleEditorPresenter?

    private var themeObserver: NSObjectProtocol?

    private var templatePopup: NSPopUpButton!
    private var stylePopup: NSPopUpButton!
    private var fontPopup: NSPopUpButton!
    private var sizeField: NSTextField!
    private var boldCheckbox: NSButton!
    private var italicCheckbox: NSButton!
    private var textColorWell: NSColorWell!
    private var backgroundColorWell: NSColorWell!
    private var alignmentButtons: [NSButton] = []
    private var alignmentButtonStack: NSStackView!
    private var alignmentSelectedIndex: Int = 0
    private var lineHeightField: NSTextField!
    private var beforeField: NSTextField!
    private var afterField: NSTextField!
    private var headIndentField: NSTextField!
    private var firstLineField: NSTextField!
    private var tailIndentField: NSTextField!
    private var preview: NSTextView!
    private var previewContainer: NSScrollView!
    private var applyButton: NSButton!
    private var resetButton: NSButton!
    private var closeButton: NSButton!

    init(editor: StyleEditorPresenter) {
        self.editor = editor
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }

    override func loadView() {
        let theme = ThemeManager.shared.currentTheme

        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.layer?.backgroundColor = theme.pageAround.cgColor

        templatePopup = NSPopUpButton()
        templatePopup.target = self
        templatePopup.action = #selector(templateChanged)
        templatePopup.qpApplyDropdownBorder(theme: theme)
        templatePopup.focusRingType = .none

        stylePopup = NSPopUpButton()
        stylePopup.target = self
        stylePopup.action = #selector(styleChanged)
        stylePopup.qpApplyDropdownBorder(theme: theme)
        stylePopup.focusRingType = .none

        fontPopup = NSPopUpButton()
        fontPopup.addItems(withTitles: [
            "Minion Pro",
            "Arial",
            "Times New Roman",
            "Calibre",
            "Inter",
            "Helvetica",
            "Georgia",
            "Courier New",
            "SF Pro"
        ])
        fontPopup.qpApplyDropdownBorder(theme: theme)
        fontPopup.focusRingType = .none

        sizeField = NSTextField(string: "12")
        sizeField.controlSize = .small
        sizeField.focusRingType = .none

        boldCheckbox = NSButton(checkboxWithTitle: "Bold", target: nil, action: nil)
        boldCheckbox.focusRingType = .none
        italicCheckbox = NSButton(checkboxWithTitle: "Italic", target: nil, action: nil)
        italicCheckbox.focusRingType = .none

        textColorWell = NSColorWell()
        textColorWell.focusRingType = .none
        textColorWell.wantsLayer = true
        textColorWell.layer?.borderWidth = 1
        textColorWell.layer?.cornerRadius = 6
        textColorWell.layer?.borderColor = theme.pageBorder.cgColor
        backgroundColorWell = NSColorWell()
        backgroundColorWell.focusRingType = .none
        backgroundColorWell.wantsLayer = true
        backgroundColorWell.layer?.borderWidth = 1
        backgroundColorWell.layer?.cornerRadius = 6
        backgroundColorWell.layer?.borderColor = theme.pageBorder.cgColor

        alignmentButtons = ["Left", "Center", "Right", "Just"].enumerated().map { index, title in
            let button = NSButton(title: title, target: self, action: #selector(alignmentButtonTapped(_:)))
            button.tag = index
            button.setButtonType(.toggle)
            button.isBordered = false
            button.focusRingType = .none
            button.wantsLayer = true
            button.layer?.borderWidth = 1
            button.layer?.cornerRadius = 6
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: 24).isActive = true
            return button
        }

        alignmentButtonStack = NSStackView(views: alignmentButtons)
        alignmentButtonStack.orientation = .horizontal
        alignmentButtonStack.alignment = .centerY
        alignmentButtonStack.distribution = .fillEqually
        alignmentButtonStack.spacing = 6
        alignmentButtonStack.translatesAutoresizingMaskIntoConstraints = false

        lineHeightField = NSTextField(string: "2.0")
        beforeField = NSTextField(string: "0")
        afterField = NSTextField(string: "0")
        headIndentField = NSTextField(string: "0")
        firstLineField = NSTextField(string: "36")
        tailIndentField = NSTextField(string: "0")
        [lineHeightField, beforeField, afterField, headIndentField, firstLineField, tailIndentField].forEach { field in
            field.focusRingType = .none
        }

        preview = NSTextView(frame: NSRect(x: 0, y: 0, width: 480, height: 180))
        preview.isEditable = false
        preview.isSelectable = false
        preview.drawsBackground = true
        preview.string = "Preview sample text."
        preview.textContainerInset = NSSize(width: 12, height: 12)
        preview.isHorizontallyResizable = false
        preview.isVerticallyResizable = true
        preview.autoresizingMask = [.width]
        preview.textColor = theme.textColor
        preview.backgroundColor = theme.pageBackground
        preview.textContainer?.widthTracksTextView = true
        preview.textContainer?.heightTracksTextView = false

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Template:"), templatePopup],
            [NSTextField(labelWithString: "Style:"), stylePopup],
            [NSTextField(labelWithString: "Font:"), fontPopup],
            [NSTextField(labelWithString: "Size:"), sizeField],
            [NSTextField(labelWithString: "Weight:"), boldCheckbox],
            [NSTextField(labelWithString: "Italic:"), italicCheckbox],
            [NSTextField(labelWithString: "Text Color:"), textColorWell],
            [NSTextField(labelWithString: "Background:"), backgroundColorWell],
            [NSTextField(labelWithString: "Alignment:"), alignmentButtonStack],
            [NSTextField(labelWithString: "Line Height:"), lineHeightField],
            [NSTextField(labelWithString: "Before:"), beforeField],
            [NSTextField(labelWithString: "After:"), afterField],
            [NSTextField(labelWithString: "Head Indent:"), headIndentField],
            [NSTextField(labelWithString: "First Line:"), firstLineField],
            [NSTextField(labelWithString: "Tail Indent:"), tailIndentField]
        ])
        grid.rowSpacing = 6
        grid.columnSpacing = 8

        previewContainer = NSScrollView()
        previewContainer.hasVerticalScroller = true
        previewContainer.drawsBackground = true
        previewContainer.backgroundColor = theme.pageAround
        previewContainer.documentView = preview
        previewContainer.borderType = .noBorder
        previewContainer.wantsLayer = true
        previewContainer.layer?.borderWidth = 1
        previewContainer.layer?.cornerRadius = 6
        previewContainer.layer?.borderColor = theme.pageBorder.cgColor
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.heightAnchor.constraint(equalToConstant: 180).isActive = true

        applyButton = NSButton(title: "Apply to Selection", target: self, action: #selector(applyTapped))
        resetButton = NSButton(title: "Reset to Default", target: self, action: #selector(resetTapped))
        closeButton = NSButton(title: "Close", target: self, action: #selector(closeTapped))
        [applyButton, resetButton, closeButton].forEach { button in
            button?.focusRingType = .none
            button?.isBordered = false
            button?.wantsLayer = true
            button?.layer?.borderWidth = 1
            button?.layer?.cornerRadius = 6
            button?.layer?.backgroundColor = theme.pageAround.cgColor
            button?.layer?.borderColor = theme.pageBorder.cgColor
        }

        let buttonStack = NSStackView(views: [applyButton, resetButton, closeButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 8

        let vStack = NSStackView(views: [grid, previewContainer, buttonStack])
        vStack.orientation = .vertical
        vStack.spacing = 12
        vStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(vStack)
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 26),
            vStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 26),
            vStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -26),
            vStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -26)
        ])

        reloadTemplates()
        reloadStyles()
        loadCurrentStyle()
        setAlignmentSelectedIndex(alignmentSelectedIndex)
        applyTheme(theme)

        // Live theme updates (so borders/backgrounds follow theme changes).
        themeObserver = NotificationCenter.default.addObserver(
            forName: .themeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme(ThemeManager.shared.currentTheme)
        }
    }

    private func applyTheme(_ theme: AppTheme) {
        view.layer?.backgroundColor = theme.pageAround.cgColor

        templatePopup?.qpApplyDropdownBorder(theme: theme)
        stylePopup?.qpApplyDropdownBorder(theme: theme)
        fontPopup?.qpApplyDropdownBorder(theme: theme)

        applyAlignmentButtonTheme(theme)

        preview?.textColor = theme.textColor
        preview?.backgroundColor = theme.pageBackground
        previewContainer?.backgroundColor = theme.pageAround
        previewContainer?.layer?.borderColor = theme.pageBorder.cgColor
        textColorWell?.layer?.borderColor = theme.pageBorder.cgColor
        backgroundColorWell?.layer?.borderColor = theme.pageBorder.cgColor

        let fieldBackground = theme.pageBackground
        let borderColor = theme.pageBorder.cgColor
        let fields: [NSTextField?] = [sizeField, lineHeightField, beforeField, afterField, headIndentField, firstLineField, tailIndentField]
        for field in fields {
            guard let field else { continue }
            field.textColor = theme.textColor
            field.backgroundColor = fieldBackground
            field.isBezeled = false
            field.isBordered = false
            field.drawsBackground = true
            field.wantsLayer = true
            field.layer?.borderWidth = 1
            field.layer?.cornerRadius = 4
            field.layer?.borderColor = borderColor
        }

        let buttons: [NSButton?] = [applyButton, resetButton, closeButton]
        for button in buttons {
            guard let button else { continue }
            let font = button.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [
                    .foregroundColor: theme.textColor,
                    .font: font
                ]
            )
            button.layer?.borderColor = theme.pageBorder.cgColor
            // Ensure the background updates with theme changes (prevents white buttons with white text in Night mode).
            button.layer?.backgroundColor = theme.pageBackground.cgColor
        }

        let checkboxes: [NSButton?] = [boldCheckbox, italicCheckbox]
        for checkbox in checkboxes {
            guard let checkbox else { continue }
            checkbox.contentTintColor = theme.pageBorder
            let font = checkbox.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            checkbox.attributedTitle = NSAttributedString(
                string: checkbox.title,
                attributes: [
                    .foregroundColor: theme.textColor,
                    .font: font
                ]
            )
        }

    }

    private func reloadTemplates() {
        templatePopup.removeAllItems()
        let names = StyleCatalog.shared.availableTemplates()
        templatePopup.addItems(withTitles: names)
        templatePopup.selectItem(withTitle: StyleCatalog.shared.currentTemplateName)
    }

    private func reloadStyles() {
        let current = StyleCatalog.shared.currentTemplateName
        let templateName = templatePopup.titleOfSelectedItem ?? current
        let styleNames = StyleCatalog.shared.styleNames(for: templateName)
        stylePopup.removeAllItems()
        stylePopup.addItems(withTitles: styleNames)

        let isPoetry = templateName.lowercased().contains("poetry")
        let isScreenplay = templateName.lowercased().contains("screenplay")

        if isPoetry, stylePopup.itemTitles.contains("Verse") {
            stylePopup.selectItem(withTitle: "Verse")
        } else if isScreenplay, stylePopup.itemTitles.contains("Action") {
            stylePopup.selectItem(withTitle: "Action")
        } else if stylePopup.itemTitles.contains("Body Text") {
            stylePopup.selectItem(withTitle: "Body Text")
        } else if let first = stylePopup.itemTitles.first {
            stylePopup.selectItem(withTitle: first)
        }
    }

    private func loadCurrentStyle() {
        guard let name = stylePopup.titleOfSelectedItem,
              let def = StyleCatalog.shared.style(named: name) else { return }
        populateFields(from: def)
        updatePreview(with: def)
    }

    private func populateFields(from def: StyleDefinition) {
        fontPopup.selectItem(withTitle: def.fontName)
        if fontPopup.indexOfSelectedItem == -1 {
            fontPopup.addItem(withTitle: def.fontName)
            fontPopup.selectItem(withTitle: def.fontName)
        }
        sizeField.stringValue = String(format: "%.1f", def.fontSize)
        boldCheckbox.state = def.isBold ? .on : .off
        italicCheckbox.state = def.isItalic ? .on : .off
        textColorWell.color = color(from: def.textColorHex)
        if let bg = def.backgroundColorHex {
            backgroundColorWell.color = color(from: bg)
        } else {
            backgroundColorWell.color = .clear
        }
        setAlignmentSelectedIndex(segmentIndex(for: def.alignmentRawValue))
        lineHeightField.stringValue = String(format: "%.2f", def.lineHeightMultiple)
        beforeField.stringValue = String(format: "%.1f", def.spacingBefore)
        afterField.stringValue = String(format: "%.1f", def.spacingAfter)
        headIndentField.stringValue = String(format: "%.1f", def.headIndent)
        firstLineField.stringValue = String(format: "%.1f", def.firstLineIndent)
        tailIndentField.stringValue = String(format: "%.1f", def.tailIndent)
    }

    private func buildDefinition() -> StyleDefinition? {
        guard let _ = stylePopup.titleOfSelectedItem else { return nil }
        let fontName = fontPopup.titleOfSelectedItem ?? "Times New Roman"
        let fontSize = CGFloat(sizeField.doubleValue == 0 ? 12 : sizeField.doubleValue)
        let isBold = boldCheckbox.state == .on
        let isItalic = italicCheckbox.state == .on
        let textHex = hex(from: textColorWell.color)
        let bgHex = backgroundColorWell.color.alphaComponent > 0 ? hex(from: backgroundColorWell.color) : nil
        let alignment = alignmentValue(for: alignmentSelectedIndex)
        let lineHeight = CGFloat(max(0.5, lineHeightField.doubleValue))
        let before = CGFloat(beforeField.doubleValue)
        let after = CGFloat(afterField.doubleValue)
        let head = CGFloat(headIndentField.doubleValue)
        let first = CGFloat(firstLineField.doubleValue)
        let tail = CGFloat(tailIndentField.doubleValue)
        return StyleDefinition(
            fontName: fontName,
            fontSize: fontSize,
            isBold: isBold,
            isItalic: isItalic,
            textColorHex: textHex,
            backgroundColorHex: bgHex,
            alignmentRawValue: alignment.rawValue,
            lineHeightMultiple: lineHeight,
            spacingBefore: before,
            spacingAfter: after,
            headIndent: head,
            firstLineIndent: first,
            tailIndent: tail
        )
    }

    private func updatePreview(with def: StyleDefinition) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = NSTextAlignment(rawValue: def.alignmentRawValue) ?? .left
        paragraph.lineHeightMultiple = def.lineHeightMultiple
        paragraph.paragraphSpacingBefore = def.spacingBefore
        paragraph.paragraphSpacing = def.spacingAfter
        paragraph.headIndent = def.headIndent
        paragraph.firstLineHeadIndent = def.headIndent + def.firstLineIndent
        paragraph.tailIndent = def.tailIndent

        var font = NSFont.quillPilotResolve(nameOrFamily: def.fontName, size: def.fontSize) ?? NSFont.systemFont(ofSize: def.fontSize)
        if def.isBold {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
        let theme = ThemeManager.shared.currentTheme
        backgroundColorWell.layer?.backgroundColor = theme.pageBackground.cgColor
        textColorWell.layer?.backgroundColor = theme.pageBackground.cgColor
        if def.isItalic {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }

        let textColor = color(from: def.textColorHex)
        let backgroundColor = def.backgroundColorHex.flatMap { color(from: $0) } ?? .clear

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .backgroundColor: backgroundColor,
            .paragraphStyle: paragraph
        ]

        preview.textStorage?.setAttributedString(NSAttributedString(string: preview.string, attributes: attrs))
    }

    @objc private func templateChanged() {
        if let name = templatePopup.titleOfSelectedItem {
            StyleCatalog.shared.setCurrentTemplate(name)
        }
        reloadStyles()
        loadCurrentStyle()
    }

    @objc private func styleChanged() {
        loadCurrentStyle()
    }

    @objc private func alignmentButtonTapped(_ sender: NSButton) {
        setAlignmentSelectedIndex(sender.tag)
    }

    private func setAlignmentSelectedIndex(_ index: Int) {
        alignmentSelectedIndex = max(0, min(3, index))
        alignmentButtons.enumerated().forEach { idx, button in
            button.state = (idx == alignmentSelectedIndex) ? .on : .off
        }
        applyAlignmentButtonTheme(ThemeManager.shared.currentTheme)
    }

    private func applyAlignmentButtonTheme(_ theme: AppTheme) {
        for (idx, button) in alignmentButtons.enumerated() {
            let isSelected = idx == alignmentSelectedIndex
            button.layer?.borderColor = theme.pageBorder.cgColor
            button.layer?.backgroundColor = (isSelected ? theme.pageBorder : theme.pageBackground).cgColor
            let titleColor: NSColor = isSelected ? .white : theme.textColor
            let font = button.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [
                    .foregroundColor: titleColor,
                    .font: font
                ]
            )
        }
    }

    @objc private func applyTapped() {
        guard let name = stylePopup.titleOfSelectedItem, let def = buildDefinition() else { return }
        StyleCatalog.shared.saveOverride(def, for: name)
        updatePreview(with: def)
        editor?.applyStyleFromEditor(named: name)

        // Close any active color panel to prevent it from lingering after apply
        NSColorPanel.shared.close()
        closeTapped()
    }

    @objc private func resetTapped() {
        guard let name = stylePopup.titleOfSelectedItem else { return }
        StyleCatalog.shared.resetStyle(name)
        loadCurrentStyle()
    }

    @objc private func closeTapped() {
        guard let window = view.window else { return }
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.close()
        }
    }

    private func color(from hex: String) -> NSColor {
        NSColor(hex: hex) ?? .black
    }

    private func hex(from color: NSColor) -> String {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int((rgb.redComponent * 255.0).rounded())
        let g = Int((rgb.greenComponent * 255.0).rounded())
        let b = Int((rgb.blueComponent * 255.0).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func segmentIndex(for raw: Int) -> Int {
        let alignment = NSTextAlignment(rawValue: raw) ?? .left
        switch alignment {
        case .left: return 0
        case .center: return 1
        case .right: return 2
        case .justified: return 3
        default: return 0
        }
    }

    private func alignmentValue(for segment: Int) -> NSTextAlignment {
        switch segment {
        case 1: return .center
        case 2: return .right
        case 3: return .justified
        default: return .left
        }
    }
}
