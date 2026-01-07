import Cocoa

protocol StyleEditorPresenter: AnyObject {
    func applyStyleFromEditor(named: String)
}

final class StyleEditorWindowController: NSWindowController {
    init(editor: StyleEditorPresenter) {
        let viewController = StyleEditorViewController(editor: editor)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
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

    private var templatePopup: NSPopUpButton!
    private var stylePopup: NSPopUpButton!
    private var fontPopup: NSPopUpButton!
    private var sizeField: NSTextField!
    private var boldCheckbox: NSButton!
    private var italicCheckbox: NSButton!
    private var textColorWell: NSColorWell!
    private var backgroundColorWell: NSColorWell!
    private var alignmentSegment: NSSegmentedControl!
    private var lineHeightField: NSTextField!
    private var beforeField: NSTextField!
    private var afterField: NSTextField!
    private var headIndentField: NSTextField!
    private var firstLineField: NSTextField!
    private var tailIndentField: NSTextField!
    private var preview: NSTextView!

    init(editor: StyleEditorPresenter) {
        self.editor = editor
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        templatePopup = NSPopUpButton()
        templatePopup.target = self
        templatePopup.action = #selector(templateChanged)

        stylePopup = NSPopUpButton()
        stylePopup.target = self
        stylePopup.action = #selector(styleChanged)

        fontPopup = NSPopUpButton()
        fontPopup.addItems(withTitles: ["Times New Roman", "Georgia", "Inter", "Helvetica", "Courier New", "SF Pro"])

        sizeField = NSTextField(string: "12")
        sizeField.controlSize = .small

        boldCheckbox = NSButton(checkboxWithTitle: "Bold", target: nil, action: nil)
        italicCheckbox = NSButton(checkboxWithTitle: "Italic", target: nil, action: nil)

        textColorWell = NSColorWell()
        backgroundColorWell = NSColorWell()

        alignmentSegment = NSSegmentedControl(labels: ["Left", "Center", "Right", "Just"], trackingMode: .selectOne, target: self, action: #selector(alignmentChanged))

        lineHeightField = NSTextField(string: "2.0")
        beforeField = NSTextField(string: "0")
        afterField = NSTextField(string: "0")
        headIndentField = NSTextField(string: "0")
        firstLineField = NSTextField(string: "36")
        tailIndentField = NSTextField(string: "0")

        preview = NSTextView()
        preview.isEditable = false
        preview.isSelectable = false
        preview.string = "Preview sample text."
        preview.backgroundColor = ThemeManager.shared.currentTheme.pageBackground

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Template:"), templatePopup],
            [NSTextField(labelWithString: "Style:"), stylePopup],
            [NSTextField(labelWithString: "Font:"), fontPopup],
            [NSTextField(labelWithString: "Size:"), sizeField],
            [NSTextField(labelWithString: "Weight:"), boldCheckbox],
            [NSTextField(labelWithString: "Italic:"), italicCheckbox],
            [NSTextField(labelWithString: "Text Color:"), textColorWell],
            [NSTextField(labelWithString: "Background:"), backgroundColorWell],
            [NSTextField(labelWithString: "Alignment:"), alignmentSegment],
            [NSTextField(labelWithString: "Line Height:"), lineHeightField],
            [NSTextField(labelWithString: "Before:"), beforeField],
            [NSTextField(labelWithString: "After:"), afterField],
            [NSTextField(labelWithString: "Head Indent:"), headIndentField],
            [NSTextField(labelWithString: "First Line:"), firstLineField],
            [NSTextField(labelWithString: "Tail Indent:"), tailIndentField]
        ])
        grid.rowSpacing = 6
        grid.columnSpacing = 8

        let previewContainer = NSScrollView()
        previewContainer.hasVerticalScroller = true
        previewContainer.documentView = preview
        previewContainer.borderType = .bezelBorder
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.heightAnchor.constraint(equalToConstant: 180).isActive = true

        let applyButton = NSButton(title: "Apply to Selection", target: self, action: #selector(applyTapped))
        let resetButton = NSButton(title: "Reset to Default", target: self, action: #selector(resetTapped))
        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeTapped))

        let buttonStack = NSStackView(views: [applyButton, resetButton, closeButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 8

        let vStack = NSStackView(views: [grid, previewContainer, buttonStack])
        vStack.orientation = .vertical
        vStack.spacing = 12
        vStack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        vStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(vStack)
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: view.topAnchor),
            vStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            vStack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        reloadTemplates()
        reloadStyles()
        loadCurrentStyle()
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
        if stylePopup.itemTitles.contains("Body Text") {
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
        alignmentSegment.selectedSegment = segmentIndex(for: def.alignmentRawValue)
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
        let alignment = alignmentValue(for: alignmentSegment.selectedSegment)
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
        paragraph.firstLineHeadIndent = def.firstLineIndent
        paragraph.tailIndent = def.tailIndent

        var font = NSFont.quillPilotResolve(nameOrFamily: def.fontName, size: def.fontSize) ?? NSFont.systemFont(ofSize: def.fontSize)
        if def.isBold {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
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

    @objc private func alignmentChanged() {
        // no-op; alignment stored when saving
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
